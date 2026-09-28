import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';

import '../models/certificate_field.dart';
import '../theme/app_theme.dart';
import '../utils/starter_templates.dart';

class TemplateEditorCanvas extends StatefulWidget {
  const TemplateEditorCanvas({
    super.key,
    this.templatePath,
    this.starterTemplateId = 'golden_classic',
    required this.fields,
    this.selectedFieldId,
    required this.onFieldSelected,
    required this.onFieldChanged,
    required this.onFieldTap,
    required this.onCanvasTap,
    required this.onDeleteField,
    this.aspectRatio = 1.414, // A4 Landscape default ratio
  });

  final String? templatePath;
  final String? starterTemplateId;
  final List<CertificateField> fields;
  final String? selectedFieldId;
  final ValueChanged<String?> onFieldSelected;
  final ValueChanged<CertificateField> onFieldChanged;
  final ValueChanged<CertificateField> onFieldTap;
  final Function(double relativeX, double relativeY) onCanvasTap;
  final ValueChanged<String> onDeleteField;
  final double aspectRatio;

  @override
  State<TemplateEditorCanvas> createState() => _TemplateEditorCanvasState();
}

class _TemplateEditorCanvasState extends State<TemplateEditorCanvas> {
  final GlobalKey _canvasKey = GlobalKey();
  double? _imageAspectRatio;

  @override
  void initState() {
    super.initState();
    _loadImageAspectRatio();
  }

  @override
  void didUpdateWidget(covariant TemplateEditorCanvas oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.templatePath != widget.templatePath) {
      _loadImageAspectRatio();
    }
  }

  Future<void> _loadImageAspectRatio() async {
    if (widget.templatePath == null || widget.templatePath!.isEmpty || !File(widget.templatePath!).existsSync()) {
      if (mounted) setState(() => _imageAspectRatio = null);
      return;
    }
    try {
      final bytes = await File(widget.templatePath!).readAsBytes();
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      final image = frame.image;
      if (image.height > 0 && mounted) {
        setState(() {
          _imageAspectRatio = image.width / image.height;
        });
      }
    } catch (_) {}
  }

  void _handleCanvasTap(TapUpDetails details, Size canvasSize) {
    if (canvasSize.width <= 0 || canvasSize.height <= 0) return;
    final relX = (details.localPosition.dx / canvasSize.width).clamp(0.05, 0.95);
    final relY = (details.localPosition.dy / canvasSize.height).clamp(0.05, 0.95);
    widget.onCanvasTap(relX, relY);
  }

  @override
  Widget build(BuildContext context) {
    final effectiveAspectRatio = _imageAspectRatio ?? widget.aspectRatio;

    return AspectRatio(
      aspectRatio: effectiveAspectRatio,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final canvasSize = Size(constraints.maxWidth, constraints.maxHeight);
          final hasImage = widget.templatePath != null &&
              widget.templatePath!.isNotEmpty &&
              File(widget.templatePath!).existsSync();

          return Stack(
            key: _canvasKey,
            children: [
              // 1. Background (Uploaded Image or Starter Painter)
              Positioned.fill(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border.all(color: const Color(0xFFD7E1DE)),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: hasImage
                        ? Image.file(
                            File(widget.templatePath!),
                            fit: BoxFit.contain, // Guarantee 100% visible original display!
                            width: canvasSize.width,
                            height: canvasSize.height,
                          )
                        : CustomPaint(
                            size: canvasSize,
                            painter: StarterCertificatePainter(
                              template: StarterTemplate.getById(widget.starterTemplateId),
                            ),
                          ),
                  ),
                ),
              ),

              // 2. Interactive Tap-to-Add Layer
              Positioned.fill(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTapUp: (details) => _handleCanvasTap(details, canvasSize),
                ),
              ),

              // 3. Placed Text Fields Overlay
              ...widget.fields.map((field) {
                final isSelected = widget.selectedFieldId == field.id;
                final fieldWidth = canvasSize.width * field.width;
                final fieldHeight = canvasSize.height * field.height;

                // Center point position calculated relative to canvas
                final left = (canvasSize.width * field.x) - (fieldWidth / 2);
                final top = (canvasSize.height * field.y) - (fieldHeight / 2);

                return Positioned(
                  left: left.clamp(0.0, canvasSize.width - fieldWidth),
                  top: top.clamp(0.0, canvasSize.height - fieldHeight),
                  width: fieldWidth,
                  height: fieldHeight,
                  child: GestureDetector(
                    onTap: () {
                      widget.onFieldSelected(field.id);
                      widget.onFieldTap(field);
                    },
                    onPanUpdate: (details) {
                      final newLeft = left + details.delta.dx;
                      final newTop = top + details.delta.dy;
                      final newCenterX = (newLeft + (fieldWidth / 2)) / canvasSize.width;
                      final newCenterY = (newTop + (fieldHeight / 2)) / canvasSize.height;

                      final updatedField = field.copyWith(
                        x: newCenterX.clamp(0.05, 0.95),
                        y: newCenterY.clamp(0.05, 0.95),
                      );
                      widget.onFieldChanged(updatedField);
                    },
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        // Text Field Container Box
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? AppTheme.teal.withValues(alpha: 0.12)
                                : Colors.blue.withValues(alpha: 0.06),
                            border: Border.all(
                              color: isSelected ? AppTheme.teal : Colors.blue.shade400.withValues(alpha: 0.6),
                              width: isSelected ? 2.0 : 1.0,
                            ),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Center(
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                field.placeholder,
                                textAlign: field.alignment,
                                style: TextStyle(
                                  fontSize: field.fontSize * (canvasSize.height / 500.0), // Responsive preview scaling
                                  fontWeight: field.fontWeight,
                                  color: Color(field.color),
                                ),
                              ),
                            ),
                          ),
                        ),

                        // Position Tag & Controls when Selected
                        if (isSelected) ...[
                          // Top position badge
                          Positioned(
                            top: -24,
                            left: 0,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppTheme.ink,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                '${field.placeholder} (X: ${(field.x * 100).toInt()}%, Y: ${(field.y * 100).toInt()}%)',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),

                          // Quick Action Buttons (Edit & Delete)
                          Positioned(
                            top: -26,
                            right: 0,
                            child: Row(
                              children: [
                                GestureDetector(
                                  onTap: () => widget.onFieldTap(field),
                                  child: Container(
                                    padding: const EdgeInsets.all(3),
                                    decoration: const BoxDecoration(
                                      color: AppTheme.ocean,
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(Icons.edit, size: 14, color: Colors.white),
                                  ),
                                ),
                                const SizedBox(width: 4),
                                GestureDetector(
                                  onTap: () => widget.onDeleteField(field.id),
                                  child: Container(
                                    padding: const EdgeInsets.all(3),
                                    decoration: const BoxDecoration(
                                      color: Color(0xFFB5443B),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(Icons.delete, size: 14, color: Colors.white),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                );
              }),
            ],
          );
        },
      ),
    );
  }
}
