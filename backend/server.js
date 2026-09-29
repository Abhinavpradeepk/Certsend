const http = require('node:http');

const port = Number(process.env.PORT || 3000);
const maxRequestBytes = 14 * 1024 * 1024;
const maxAttachmentBytes = 10 * 1024 * 1024;
const requiredEnvironment = [
  'BREVO_API_KEY',
  'BREVO_SENDER_EMAIL',
  'EMAIL_GATEWAY_TOKEN',
];
const missingEnvironment = requiredEnvironment.filter((name) => !process.env[name]);

const rateLimit = new Map();

function sendJson(response, statusCode, payload) {
  response.writeHead(statusCode, { 'content-type': 'application/json; charset=utf-8' });
  response.end(JSON.stringify(payload));
}

function readJson(request) {
  return new Promise((resolve, reject) => {
    let size = 0;
    let settled = false;
    const chunks = [];
    request.on('data', (chunk) => {
      if (settled) return;
      size += chunk.length;
      if (size > maxRequestBytes) {
        settled = true;
        chunks.length = 0;
        reject(Object.assign(new Error('Request exceeds the 14 MB limit.'), { statusCode: 413 }));
        return;
      }
      chunks.push(chunk);
    });
    request.on('end', () => {
      if (settled) return;
      try {
        resolve(JSON.parse(Buffer.concat(chunks).toString('utf8')));
      } catch {
        settled = true;
        reject(Object.assign(new Error('Request body must be valid JSON.'), { statusCode: 400 }));
      }
    });
    request.on('error', reject);
  });
}

function allowRequest(request) {
  const now = Date.now();
  const windowMs = 60 * 60 * 1000;
  const address = request.socket.remoteAddress || 'unknown';
  const current = rateLimit.get(address);
  if (!current || now - current.startedAt >= windowMs) {
    rateLimit.set(address, { startedAt: now, count: 1 });
    return true;
  }
  current.count += 1;
  return current.count <= 60;
}

function isEmail(value) {
  return typeof value === 'string' && /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(value);
}

async function sendThroughBrevo(payload) {
  const attachment = Buffer.from(payload.attachmentContent, 'base64');
  const safeName = payload.attachmentName.replace(/[^A-Za-z0-9._-]/g, '_');
  const response = await fetch('https://api.brevo.com/v3/smtp/email', {
    method: 'POST',
    headers: {
      'api-key': process.env.BREVO_API_KEY,
      'content-type': 'application/json',
      accept: 'application/json',
    },
    body: JSON.stringify({
      sender: {
        email: process.env.BREVO_SENDER_EMAIL,
        name: process.env.BREVO_SENDER_NAME || 'CertiSend',
      },
      to: [{ email: payload.to }],
      subject: payload.subject,
      textContent: payload.body,
      attachment: [{ name: safeName, content: attachment.toString('base64') }],
    }),
    signal: AbortSignal.timeout(30000),
  });

  if (!response.ok) {
    const detail = await response.text();
    throw Object.assign(new Error(`Brevo rejected the email (${response.status}): ${detail.slice(0, 500)}`), {
      statusCode: 502,
    });
  }
  return response.json();
}

const server = http.createServer(async (request, response) => {
  if (request.method === 'GET' && request.url === '/health') {
    return sendJson(response, 200, { status: 'ok', configured: missingEnvironment.length === 0 });
  }
  if (request.method !== 'POST' || request.url !== '/api/send-certificate') {
    return sendJson(response, 404, { error: 'Endpoint not found.' });
  }
  if (missingEnvironment.length > 0) {
    return sendJson(response, 503, {
      error: `Configure these backend environment variables: ${missingEnvironment.join(', ')}.`,
    });
  }
  if (request.headers.authorization !== `Bearer ${process.env.EMAIL_GATEWAY_TOKEN}`) {
    return sendJson(response, 401, { error: 'Email gateway authentication failed.' });
  }
  if (!allowRequest(request)) {
    return sendJson(response, 429, { error: 'Email sending limit reached. Try again later.' });
  }

  try {
    const payload = await readJson(request);
    if (!isEmail(payload.to)) {
      return sendJson(response, 400, { error: 'A valid recipient email is required.' });
    }
    if (typeof payload.subject !== 'string' || !payload.subject.trim() || payload.subject.length > 200) {
      return sendJson(response, 400, { error: 'Email subject must be 1 to 200 characters.' });
    }
    if (typeof payload.body !== 'string' || payload.body.length > 100000) {
      return sendJson(response, 400, { error: 'Email body is required and must be under 100 KB.' });
    }
    if (typeof payload.attachmentName !== 'string' || typeof payload.attachmentContent !== 'string') {
      return sendJson(response, 400, { error: 'A PDF attachment is required.' });
    }
    if (!/^[A-Za-z0-9+/]*={0,2}$/.test(payload.attachmentContent)) {
      return sendJson(response, 400, { error: 'Attachment encoding is invalid.' });
    }
    const attachment = Buffer.from(payload.attachmentContent, 'base64');
    if (attachment.length === 0 || attachment.length > maxAttachmentBytes || attachment.subarray(0, 5).toString() !== '%PDF-') {
      return sendJson(response, 400, { error: 'Attachment must be a PDF no larger than 10 MB.' });
    }

    const result = await sendThroughBrevo(payload);
    return sendJson(response, 200, { messageId: result.messageId || null });
  } catch (error) {
    const statusCode = error.statusCode || 502;
    return sendJson(response, statusCode, { error: error.message || 'Email could not be sent.' });
  }
});

server.listen(port, '0.0.0.0', () => {
  console.log(`CertiSend Brevo gateway listening on port ${port}`);
});