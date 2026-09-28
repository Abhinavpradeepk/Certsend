import 'package:flutter/material.dart';

class StarterTemplate {
  const StarterTemplate({
    required this.id,
    required this.name,
    required this.description,
    required this.primaryColor,
    required this.secondaryColor,
    required this.accentColor,
    required this.backgroundColor,
    required this.style,
  });

  final String id;
  final String name;
  final String description;
  final Color primaryColor;
  final Color secondaryColor;
  final Color accentColor;
  final Color backgroundColor;
  final String style;

  static const List<StarterTemplate> templates = [
    StarterTemplate(
      id: 'golden_classic',
      name: 'Golden Classic',
      description: 'Elegant golden border with formal certificate styling',
      primaryColor: Color(0xFF1B263B),
      secondaryColor: Color(0xFFD4AF37),
      accentColor: Color(0xFFA67C00),
      backgroundColor: Color(0xFFFCFAF5),
      style: 'classic',
    ),
    StarterTemplate(
      id: 'corporate_navy',
      name: 'Corporate Navy',
      description: 'Clean modern corporate design with geometric accents',
      primaryColor: Color(0xFF0F172A),
      secondaryColor: Color(0xFF2563EB),
      accentColor: Color(0xFF38BDF8),
      backgroundColor: Color(0xFFF8FAFC),
      style: 'corporate',
    ),
    StarterTemplate(
      id: 'emerald_achievement',
      name: 'Emerald Distinction',
      description: 'Sophisticated deep emerald and gold certificate',
      primaryColor: Color(0xFF064E3B),
      secondaryColor: Color(0xFF10B981),
      accentColor: Color(0xFFF59E0B),
      backgroundColor: Color(0xFFF0FDF4),
      style: 'emerald',
    ),
    StarterTemplate(
      id: 'minimal_teal',
      name: 'Minimalist Teal',
      description: 'Sleek modern design with clean lines and subtle gradients',
      primaryColor: Color(0xFF102E43),
      secondaryColor: Color(0xFF176B87),
      accentColor: Color(0xFF1C8A83),
      backgroundColor: Color(0xFFF5F8F7),
      style: 'minimal',
    ),
  ];

  static StarterTemplate getById(String? id) {
    return templates.firstWhere(
      (t) => t.id == id,
      orElse: () => templates.first,
    );
  }
}

class StarterCertificatePainter extends CustomPainter {
  StarterCertificatePainter({required this.template});
  final StarterTemplate template;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;

    // 1. Background
    final bgPaint = Paint()..color = template.backgroundColor;
    canvas.drawRect(rect, bgPaint);

    // 2. Outer Border
    final borderMargin = size.width * 0.035;
    final outerRect = Rect.fromLTWH(
      borderMargin,
      borderMargin,
      size.width - (borderMargin * 2),
      size.height - (borderMargin * 2),
    );
    final outerBorderPaint = Paint()
      ..color = template.secondaryColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0;
    canvas.drawRect(outerRect, outerBorderPaint);

    // 3. Inner Fine Border
    final innerMargin = borderMargin + 6;
    final innerRect = Rect.fromLTWH(
      innerMargin,
      innerMargin,
      size.width - (innerMargin * 2),
      size.height - (innerMargin * 2),
    );
    final innerBorderPaint = Paint()
      ..color = template.secondaryColor.withValues(alpha: 0.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;
    canvas.drawRect(innerRect, innerBorderPaint);

    // 4. Decorative Corner Accents
    final cornerSize = size.width * 0.05;
    final accentPaint = Paint()
      ..color = template.accentColor
      ..style = PaintingStyle.fill;

    // Top-Left Corner
    final tlPath = Path()
      ..moveTo(borderMargin, borderMargin)
      ..lineTo(borderMargin + cornerSize, borderMargin)
      ..lineTo(borderMargin, borderMargin + cornerSize)
      ..close();
    canvas.drawPath(tlPath, accentPaint);

    // Top-Right Corner
    final trPath = Path()
      ..moveTo(size.width - borderMargin, borderMargin)
      ..lineTo(size.width - borderMargin - cornerSize, borderMargin)
      ..lineTo(size.width - borderMargin, borderMargin + cornerSize)
      ..close();
    canvas.drawPath(trPath, accentPaint);

    // Bottom-Left Corner
    final blPath = Path()
      ..moveTo(borderMargin, size.height - borderMargin)
      ..lineTo(borderMargin + cornerSize, size.height - borderMargin)
      ..lineTo(borderMargin, size.height - borderMargin - cornerSize)
      ..close();
    canvas.drawPath(blPath, accentPaint);

    // Bottom-Right Corner
    final brPath = Path()
      ..moveTo(size.width - borderMargin, size.height - borderMargin)
      ..lineTo(size.width - borderMargin - cornerSize, size.height - borderMargin)
      ..lineTo(size.width - borderMargin, size.height - borderMargin - cornerSize)
      ..close();
    canvas.drawPath(brPath, accentPaint);

    // 5. Header Watermark / Title Banner Accent
    final bannerHeight = size.height * 0.008;
    final bannerPaint = Paint()..color = template.secondaryColor;
    canvas.drawRect(
      Rect.fromLTWH(
        size.width * 0.25,
        size.height * 0.18,
        size.width * 0.5,
        bannerHeight,
      ),
      bannerPaint,
    );
  }

  @override
  bool shouldRepaint(covariant StarterCertificatePainter oldDelegate) =>
      oldDelegate.template.id != template.id;
}
