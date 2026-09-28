import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../models/certificate_field.dart';
import '../theme/app_theme.dart';

class FieldPropertyDialog extends StatefulWidget {
  const FieldPropertyDialog({
    super.key,
    this.initialField,
    this.initialX = 0.5,
    this.initialY = 0.5,
  });

  final CertificateField? initialField;
  final double initialX;
  final double initialY;

  static Future<CertificateField?> show(
    BuildContext context, {
    CertificateField? field,
    double x = 0.5,
    double y = 0.5,
  }) {
    return showModalBottomSheet<CertificateField>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(ctx).viewInsets.bottom,
        ),
        child: FieldPropertyDialog(
          initialField: field,
          initialX: x,
          initialY: y,
        ),
      ),
    );
  }

  @override
  State<FieldPropertyDialog> createState() => _FieldPropertyDialogState();
}

class _FieldPropertyDialogState extends State<FieldPropertyDialog> {
  late TextEditingController _placeholderController;
  late double _fontSize;
  late FontWeight _fontWeight;
  late TextAlign _alignment;
  late int _color;

  static const List<String> _commonTokens = [
    '{{NAME}}',
    '{{EVENT}}',
    '{{DATE}}',
    '{{POSITION}}',
    '{{ORGANIZATION}}',
    '{{CERTIFICATE_ID}}',
  ];

  static const List<int> _colorPresets = [
    0xFF183B4E, // Dark Navy Ink
    0xFF102E43, // Ocean Ink
    0xFF0F172A, // Midnight Slate
    0xFF85586F, // Muted Plum
    0xFF1C8A83, // Teal Accent
    0xFFB5443B, // Crimson Accent
    0xFF000000, // Pitch Black
  ];

  @override
  void initState() {
    super.initState();
    final field = widget.initialField;
    _placeholderController = TextEditingController(
      text: field?.placeholder ?? '{{NAME}}',
    );
    _fontSize = field?.fontSize ?? 28.0;
    _fontWeight = field?.fontWeight ?? FontWeight.w600;
    _alignment = field?.alignment ?? TextAlign.center;
    _color = field?.color ?? 0xFF183B4E;
  }

  @override
  void dispose() {
    _placeholderController.dispose();
    super.dispose();
  }

  void _save() {
    final text = _placeholderController.text.trim();
    if (text.isEmpty) return;

    final existing = widget.initialField;
    final result = CertificateField(
      id: existing?.id ?? const Uuid().v4(),
      placeholder: text,
      x: existing?.x ?? widget.initialX,
      y: existing?.y ?? widget.initialY,
      width: existing?.width ?? 0.5,
      height: existing?.height ?? 0.08,
      fontSize: _fontSize,
      fontWeight: _fontWeight,
      alignment: _alignment,
      color: _color,
    );
    Navigator.of(context).pop(result);
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.initialField != null;

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 38,
              height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                isEditing ? 'Edit Text Field' : 'Add Text Field to Template',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.ink,
                ),
              ),
              IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Field Placeholder
          const Text(
            'Field Placeholder / Value',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppTheme.ink),
          ),
          const SizedBox(height: 6),
          TextField(
            controller: _placeholderController,
            decoration: const InputDecoration(
              hintText: 'e.g. {{NAME}} or Certificate of Completion',
            ),
          ),
          const SizedBox(height: 8),

          // Presets chip list
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: _commonTokens.map((token) {
              return ChoiceChip(
                label: Text(token, style: const TextStyle(fontSize: 11)),
                selected: _placeholderController.text == token,
                onSelected: (selected) {
                  if (selected) {
                    setState(() => _placeholderController.text = token);
                  }
                },
              );
            }).toList(),
          ),
          const SizedBox(height: 16),

          // Font Size Slider
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Font Size',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppTheme.ink),
              ),
              Text(
                '${_fontSize.toInt()} pt',
                style: const TextStyle(fontWeight: FontWeight.w700, color: AppTheme.ocean),
              ),
            ],
          ),
          Slider(
            value: _fontSize,
            min: 12,
            max: 72,
            divisions: 60,
            activeColor: AppTheme.ocean,
            onChanged: (val) => setState(() => _fontSize = val),
          ),

          // Alignment & Font Weight
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Alignment',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppTheme.ink),
                    ),
                    const SizedBox(height: 6),
                    SegmentedButton<TextAlign>(
                      segments: const [
                        ButtonSegment(value: TextAlign.left, icon: Icon(Icons.format_align_left, size: 18)),
                        ButtonSegment(value: TextAlign.center, icon: Icon(Icons.format_align_center, size: 18)),
                        ButtonSegment(value: TextAlign.right, icon: Icon(Icons.format_align_right, size: 18)),
                      ],
                      selected: {_alignment},
                      onSelectionChanged: (set) => setState(() => _alignment = set.first),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Weight',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppTheme.ink),
                    ),
                    const SizedBox(height: 6),
                    SegmentedButton<FontWeight>(
                      segments: const [
                        ButtonSegment(value: FontWeight.w400, label: Text('Normal', style: TextStyle(fontSize: 12))),
                        ButtonSegment(value: FontWeight.w700, label: Text('Bold', style: TextStyle(fontSize: 12))),
                      ],
                      selected: {_fontWeight},
                      onSelectionChanged: (set) => setState(() => _fontWeight = set.first),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Color Palette Selector
          const Text(
            'Text Color',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppTheme.ink),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.start,
            children: _colorPresets.map((c) {
              final isSelected = _color == c;
              return GestureDetector(
                onTap: () => setState(() => _color = c),
                child: Container(
                  margin: const EdgeInsets.only(right: 10),
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: Color(c),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isSelected ? AppTheme.ocean : Colors.grey.shade300,
                      width: isSelected ? 3 : 1,
                    ),
                  ),
                  child: isSelected
                      ? const Icon(Icons.check, size: 18, color: Colors.white)
                      : null,
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 20),

          // Action button
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _save,
              icon: Icon(isEditing ? Icons.check : Icons.add),
              label: Text(isEditing ? 'Update Field' : 'Add Field to Template'),
            ),
          ),
        ],
      ),
    );
  }
}
