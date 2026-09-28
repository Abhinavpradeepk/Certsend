import 'dart:io';
import 'package:flutter/material.dart' show FontWeight, TextAlign;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../models/certificate_field.dart';
import '../models/certificate_project.dart';
import '../models/participant.dart';
import '../utils/starter_templates.dart';
import 'storage_service.dart';

class PdfGeneratorService {
  PdfGeneratorService(this._storage);
  final StorageService _storage;

  Future<String> generateCertificatePdf({
    required CertificateProject project,
    required Participant participant,
    required String certificateId,
  }) async {
    final pdf = pw.Document();

    // A4 Landscape Page Format: 841.89 x 595.27 points
    const pageFormat = PdfPageFormat.a4;
    final landscapeFormat = pageFormat.landscape;
    final pageWidth = landscapeFormat.width;
    final pageHeight = landscapeFormat.height;

    // Check if custom template image exists
    final hasImage = project.templatePath != null &&
        project.templatePath!.isNotEmpty &&
        File(project.templatePath!).existsSync();

    pw.MemoryImage? templateImage;
    if (hasImage) {
      final imageBytes = await File(project.templatePath!).readAsBytes();
      templateImage = pw.MemoryImage(imageBytes);
    }

    final starterTemplate = StarterTemplate.getById(project.templateName);

    pdf.addPage(
      pw.Page(
        pageFormat: landscapeFormat,
        margin: pw.EdgeInsets.zero,
        build: (pw.Context context) {
          return pw.Stack(
            children: [
              // 1. Background (Custom Image or Vector Starter Template)
              if (templateImage != null)
                pw.Positioned.fill(
                  child: pw.Image(
                    templateImage,
                    fit: pw.BoxFit.contain,
                  ),
                )
              else
                pw.Positioned.fill(
                  child: _buildStarterVectorBackground(
                    starterTemplate,
                    pageWidth,
                    pageHeight,
                  ),
                ),

              // 2. Text Fields Overlay
              ...project.fields.map((field) {
                final textValue = _resolveFieldValue(
                  field: field,
                  participant: participant,
                  certificateId: certificateId,
                  project: project,
                );

                final fieldWidth = pageWidth * field.width;
                final fieldHeight = pageHeight * field.height;
                final left = (pageWidth * field.x) - (fieldWidth / 2);
                final top = (pageHeight * field.y) - (fieldHeight / 2);

                final isBold = field.fontWeight == FontWeight.w700 ||
                    field.fontWeight == FontWeight.w800;
                final pdfColor = PdfColor.fromInt(field.color);

                pw.TextAlign align;
                switch (field.alignment) {
                  case TextAlign.left:
                    align = pw.TextAlign.left;
                    break;
                  case TextAlign.right:
                    align = pw.TextAlign.right;
                    break;
                  case TextAlign.center:
                  default:
                    align = pw.TextAlign.center;
                    break;
                }

                return pw.Positioned(
                  left: left.clamp(0.0, pageWidth - fieldWidth),
                  top: top.clamp(0.0, pageHeight - fieldHeight),
                  child: pw.SizedBox(
                    width: fieldWidth,
                    height: fieldHeight,
                    child: pw.Center(
                      child: pw.Text(
                        textValue,
                        textAlign: align,
                        style: pw.TextStyle(
                          fontSize: field.fontSize * 1.15, // High resolution PDF scale
                          fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal,
                          color: pdfColor,
                        ),
                      ),
                    ),
                  ),
                );
              }),
            ],
          );
        },
      ),
    );

    final pdfBytes = await pdf.save();

    // Store generated PDF in app documents directory
    final fileName = '${project.certificatePrefix}_${certificateId.replaceAll('-', '_')}.pdf';
    final root = await _storage.documentsDirectory;
    final dir = Directory('${root.path}${Platform.pathSeparator}certisend${Platform.pathSeparator}generated');
    await dir.create(recursive: true);

    final destination = File('${dir.path}${Platform.pathSeparator}$fileName');
    await destination.writeAsBytes(pdfBytes);
    return destination.path;
  }

  String _resolveFieldValue({
    required CertificateField field,
    required Participant participant,
    required String certificateId,
    required CertificateProject project,
  }) {
    String placeholder = field.placeholder;

    // Check token replacements like {{NAME}}, {{CLASS}}, etc.
    final tokenRegex = RegExp(r'\{\{([A-Za-z0-9_-]+)\}\}');
    if (tokenRegex.hasMatch(placeholder)) {
      return placeholder.replaceAllMapped(tokenRegex, (match) {
        final key = match.group(1)!.toUpperCase();
        if (key == 'CERTIFICATE_ID' || key == 'ID') return certificateId;
        return participant.values[key] ??
            participant.values.entries
                .firstWhere(
                  (e) => e.key.toUpperCase() == key,
                  orElse: () => MapEntry(key, ''),
                )
                .value;
      });
    }

    // Direct header name match e.g. "NAME", "CLASS", "EVENT"
    final upperKey = placeholder.trim().toUpperCase();
    if (upperKey == 'CERTIFICATE_ID' || upperKey == 'ID') return certificateId;

    if (participant.values.containsKey(upperKey)) {
      return participant.values[upperKey]!;
    }

    // Match case-insensitively
    final match = participant.values.entries.firstWhere(
      (e) => e.key.toUpperCase() == upperKey,
      orElse: () => const MapEntry('', ''),
    );
    if (match.key.isNotEmpty) return match.value;

    return placeholder;
  }

  pw.Widget _buildStarterVectorBackground(
    StarterTemplate template,
    double width,
    double height,
  ) {
    final secondaryColor = PdfColor.fromInt(template.secondaryColor.toARGB32());
    final accentColor = PdfColor.fromInt(template.accentColor.toARGB32());
    final bgColor = PdfColor.fromInt(template.backgroundColor.toARGB32());

    return pw.Container(
      color: bgColor,
      padding: const pw.EdgeInsets.all(24),
      child: pw.Container(
        decoration: pw.BoxDecoration(
          border: pw.Border.all(color: secondaryColor, width: 3),
        ),
        padding: const pw.EdgeInsets.all(8),
        child: pw.Container(
          decoration: pw.BoxDecoration(
            border: pw.Border.all(color: secondaryColor, width: 1),
          ),
          child: pw.Stack(
            children: [
              // Top-Left Accent Corner
              pw.Positioned(
                top: 0,
                left: 0,
                child: pw.Container(
                  width: 40,
                  height: 40,
                  color: accentColor,
                ),
              ),
              // Top-Right Accent Corner
              pw.Positioned(
                top: 0,
                right: 0,
                child: pw.Container(
                  width: 40,
                  height: 40,
                  color: accentColor,
                ),
              ),
              // Bottom-Left Accent Corner
              pw.Positioned(
                bottom: 0,
                left: 0,
                child: pw.Container(
                  width: 40,
                  height: 40,
                  color: accentColor,
                ),
              ),
              // Bottom-Right Accent Corner
              pw.Positioned(
                bottom: 0,
                right: 0,
                child: pw.Container(
                  width: 40,
                  height: 40,
                  color: accentColor,
                ),
              ),
              // Header Watermark Accent Bar
              pw.Positioned(
                top: height * 0.18,
                left: width * 0.25,
                child: pw.Container(
                  width: width * 0.45,
                  height: 4,
                  color: secondaryColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
