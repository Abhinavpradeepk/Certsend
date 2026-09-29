import 'dart:convert';
import 'dart:io';

class BrevoEmailService {
  static const _baseUrl = String.fromEnvironment('EMAIL_API_BASE_URL');
  static const _gatewayToken = String.fromEnvironment('EMAIL_GATEWAY_TOKEN');
  static const _maxPdfBytes = 10 * 1024 * 1024;

  Future<void> sendCertificate({
    required String recipient,
    required String subject,
    required String body,
    required String attachmentPath,
    required String attachmentName,
  }) async {
    if (_baseUrl.isEmpty) {
      throw StateError('Configure EMAIL_API_BASE_URL when building the app.');
    }
    if (recipient.trim().isEmpty || !recipient.contains('@')) {
      throw const FormatException(
        'This participant does not have a valid email address.',
      );
    }

    final attachment = await File(attachmentPath).readAsBytes();
    if (attachment.length > _maxPdfBytes) {
      throw const FormatException(
        'Certificate PDF exceeds the 10 MB email attachment limit.',
      );
    }

    final baseUrl = _baseUrl.endsWith('/')
        ? _baseUrl.substring(0, _baseUrl.length - 1)
        : _baseUrl;
    final uri = Uri.parse('$baseUrl/api/send-certificate');
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 15);
    try {
      final request = await client
          .postUrl(uri)
          .timeout(const Duration(seconds: 20));
      request.headers.contentType = ContentType.json;
      if (_gatewayToken.isNotEmpty) {
        request.headers.set(
          HttpHeaders.authorizationHeader,
          'Bearer $_gatewayToken',
        );
      }
      request.write(
        jsonEncode({
          'to': recipient.trim(),
          'subject': subject,
          'body': body,
          'attachmentName': attachmentName,
          'attachmentContent': base64Encode(attachment),
        }),
      );

      final response = await request.close().timeout(
        const Duration(seconds: 45),
      );
      final responseBody = await response.transform(utf8.decoder).join();
      if (response.statusCode < 200 || response.statusCode >= 300) {
        var message = 'Email service returned HTTP ${response.statusCode}.';
        try {
          final decoded = jsonDecode(responseBody) as Map<String, dynamic>;
          if (decoded['error'] is String) message = decoded['error'] as String;
        } on FormatException {
          // Keep the status-based message when the server response is not JSON.
        }
        throw HttpException(message, uri: uri);
      }
    } finally {
      client.close(force: true);
    }
  }
}
