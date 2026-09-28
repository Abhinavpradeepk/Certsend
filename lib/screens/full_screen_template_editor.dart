import 'package:flutter/material.dart';

import '../models/certificate_field.dart';
import '../theme/app_theme.dart';
import '../widgets/field_property_dialog.dart';
import '../widgets/template_editor_canvas.dart';

class FullScreenTemplateEditor extends StatefulWidget {
  const FullScreenTemplateEditor({
    super.key,
    this.templatePath,
    this.starterTemplateId = 'golden_classic',
    required this.initialFields,
  });

  final String? templatePath;
  final String? starterTemplateId;
  final List<CertificateField> initialFields;

  static Future<List<CertificateField>?> open(
    BuildContext context, {
    String? templatePath,
    String? starterTemplateId = 'golden_classic',
    required List<CertificateField> fields,
  }) {
    return Navigator.of(context).push<List<CertificateField>>(
      MaterialPageRoute(
        builder: (ctx) => FullScreenTemplateEditor(
          templatePath: templatePath,
          starterTemplateId: starterTemplateId,
          initialFields: fields,
        ),
      ),
    );
  }

  @override
  State<FullScreenTemplateEditor> createState() => _FullScreenTemplateEditorState();
}

class _FullScreenTemplateEditorState extends State<FullScreenTemplateEditor> {
  late List<CertificateField> _fields;
  String? _selectedFieldId;
  final TransformationController _transformationController = TransformationController();

  @override
  void initState() {
    super.initState();
    _fields = List.from(widget.initialFields);
    if (_fields.isNotEmpty) {
      _selectedFieldId = _fields.first.id;
    }
  }

  @override
  void dispose() {
    _transformationController.dispose();
    super.dispose();
  }

  Future<void> _addNewField({double x = 0.5, double y = 0.5}) async {
    final newField = await FieldPropertyDialog.show(
      context,
      x: x,
      y: y,
    );
    if (newField != null) {
      setState(() {
        _fields.add(newField);
        _selectedFieldId = newField.id;
      });
    }
  }

  Future<void> _editField(CertificateField field) async {
    final updated = await FieldPropertyDialog.show(
      context,
      field: field,
    );
    if (updated != null) {
      setState(() {
        _fields = [
          for (final f in _fields) f.id == updated.id ? updated : f
        ];
      });
    }
  }

  void _deleteField(String id) {
    setState(() {
      _fields.removeWhere((f) => f.id == id);
      if (_selectedFieldId == id) {
        _selectedFieldId = _fields.isNotEmpty ? _fields.first.id : null;
      }
    });
  }

  void _nudgeSelectedField(double deltaX, double deltaY) {
    if (_selectedFieldId == null) return;
    final index = _fields.indexWhere((f) => f.id == _selectedFieldId);
    if (index == -1) return;

    final field = _fields[index];
    final newX = (field.x + deltaX).clamp(0.02, 0.98);
    final newY = (field.y + deltaY).clamp(0.02, 0.98);

    setState(() {
      _fields[index] = field.copyWith(x: newX, y: newY);
    });
  }

  void _resetZoom() {
    _transformationController.value = Matrix4.identity();
  }

  @override
  Widget build(BuildContext context) {
    final selectedField = _fields.firstWhere(
      (f) => f.id == _selectedFieldId,
      orElse: () => _fields.isNotEmpty
          ? _fields.first
          : const CertificateField(id: '', placeholder: '', x: 0, y: 0),
    );
    final hasSelection = _selectedFieldId != null && _fields.any((f) => f.id == _selectedFieldId);

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A), // Dark slate canvas background
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E293B),
        foregroundColor: Colors.white,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            Text(
              'Full-Screen Template Editor',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: Colors.white),
            ),
            Text(
              'Drag fields or use arrow controls to position text inside template',
              style: TextStyle(fontSize: 11, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.zoom_out_map, color: Colors.white),
            tooltip: 'Reset Zoom',
            onPressed: _resetZoom,
          ),
          const SizedBox(width: 4),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
            child: FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: AppTheme.teal,
                foregroundColor: Colors.white,
              ),
              onPressed: () => Navigator.of(context).pop(_fields),
              icon: const Icon(Icons.check, size: 18),
              label: const Text('Save & Exit'),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Top Editor Quick Toolbar
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: const Color(0xFF1E293B),
              child: Row(
                children: [
                  FilledButton.icon(
                    onPressed: () => _addNewField(),
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Add Text Field'),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    '${_fields.length} Field(s)',
                    style: const TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                  const Spacer(),
                  const Icon(Icons.touch_app_outlined, size: 16, color: Colors.grey),
                  const SizedBox(width: 4),
                  const Text(
                    'Tap on template to drop a text field',
                    style: TextStyle(color: Colors.grey, fontSize: 11),
                  ),
                ],
              ),
            ),

            // Main Interactive Full Screen Canvas Viewport
            Expanded(
              child: InteractiveViewer(
                transformationController: _transformationController,
                minScale: 0.8,
                maxScale: 3.5,
                boundaryMargin: const EdgeInsets.all(200),
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Container(
                      decoration: BoxDecoration(
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.5),
                            blurRadius: 24,
                            spreadRadius: 4,
                          ),
                        ],
                      ),
                      child: TemplateEditorCanvas(
                        templatePath: widget.templatePath,
                        starterTemplateId: widget.starterTemplateId,
                        fields: _fields,
                        selectedFieldId: _selectedFieldId,
                        onFieldSelected: (id) => setState(() => _selectedFieldId = id),
                        onFieldChanged: (updated) {
                          setState(() {
                            _fields = [
                              for (final f in _fields) f.id == updated.id ? updated : f
                            ];
                          });
                        },
                        onFieldTap: (field) => _editField(field),
                        onCanvasTap: (relX, relY) => _addNewField(x: relX, y: relY),
                        onDeleteField: (id) => _deleteField(id),
                      ),
                    ),
                  ),
                ),
              ),
            ),

            // Bottom Selected Field Nudge & Property Controls Bar
            if (hasSelection)
              Container(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
                decoration: const BoxDecoration(
                  color: Color(0xFF1E293B),
                  border: Border(top: BorderSide(color: Color(0xFF334155))),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 12,
                          backgroundColor: Color(selectedField.color).withValues(alpha: 0.3),
                          child: Icon(Icons.text_fields, size: 14, color: Color(selectedField.color)),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Selected: ${selectedField.placeholder} (X: ${(selectedField.x * 100).toInt()}%, Y: ${(selectedField.y * 100).toInt()}%)',
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                          ),
                        ),
                        OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.white,
                            side: const BorderSide(color: Colors.white38),
                          ),
                          onPressed: () => _editField(selectedField),
                          icon: const Icon(Icons.edit, size: 14),
                          label: const Text('Edit Styling', style: TextStyle(fontSize: 12)),
                        ),
                        const SizedBox(width: 6),
                        IconButton(
                          icon: const Icon(Icons.delete_outline, color: Color(0xFFEF4444)),
                          tooltip: 'Delete Field',
                          onPressed: () => _deleteField(selectedField.id),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    // Precision Position Nudge Controls (Left, Up, Down, Right)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text(
                          'Precision Position:',
                          style: TextStyle(color: Colors.grey, fontSize: 11, fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(width: 10),
                        _NudgeButton(
                          icon: Icons.arrow_back,
                          label: 'Left',
                          onPressed: () => _nudgeSelectedField(-0.01, 0),
                        ),
                        const SizedBox(width: 6),
                        _NudgeButton(
                          icon: Icons.arrow_upward,
                          label: 'Up',
                          onPressed: () => _nudgeSelectedField(0, -0.01),
                        ),
                        const SizedBox(width: 6),
                        _NudgeButton(
                          icon: Icons.arrow_downward,
                          label: 'Down',
                          onPressed: () => _nudgeSelectedField(0, 0.01),
                        ),
                        const SizedBox(width: 6),
                        _NudgeButton(
                          icon: Icons.arrow_forward,
                          label: 'Right',
                          onPressed: () => _nudgeSelectedField(0.01, 0),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _NudgeButton extends StatelessWidget {
  const _NudgeButton({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: const Color(0xFF334155),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: Colors.white),
            const SizedBox(width: 2),
            Text(label, style: const TextStyle(color: Colors.white, fontSize: 11)),
          ],
        ),
      ),
    );
  }
}
