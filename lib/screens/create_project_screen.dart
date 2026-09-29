import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import 'full_screen_template_editor.dart';
import '../models/certificate_field.dart';
import '../providers/project_provider.dart';
import '../theme/app_theme.dart';
import '../utils/starter_templates.dart';
import '../widgets/field_property_dialog.dart';
import '../widgets/template_editor_canvas.dart';

class CreateProjectScreen extends StatefulWidget {
  const CreateProjectScreen({super.key});
  @override
  State<CreateProjectScreen> createState() => _CreateProjectScreenState();
}

class _CreateProjectScreenState extends State<CreateProjectScreen> {
  int _currentStep = 0;
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _prefixController = TextEditingController(text: 'CERT');

  // Template State
  String? _templatePath;
  String? _templateName;
  String _selectedStarterId = 'golden_classic';
  bool _useCustomImage = false;

  // Text Fields State
  List<CertificateField> _fields = [];
  String? _selectedFieldId;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    // Default initial text fields when creating a project
    _fields = [
      CertificateField(
        id: const Uuid().v4(),
        placeholder: '{{NAME}}',
        x: 0.5,
        y: 0.48,
        fontSize: 32,
        fontWeight: FontWeight.w700,
        alignment: TextAlign.center,
        color: 0xFF183B4E,
      ),
      CertificateField(
        id: const Uuid().v4(),
        placeholder: '{{EVENT}}',
        x: 0.5,
        y: 0.62,
        fontSize: 22,
        fontWeight: FontWeight.w600,
        alignment: TextAlign.center,
        color: 0xFF176B87,
      ),
      CertificateField(
        id: const Uuid().v4(),
        placeholder: '{{DATE}}',
        x: 0.3,
        y: 0.80,
        fontSize: 16,
        fontWeight: FontWeight.w400,
        alignment: TextAlign.center,
        color: 0xFF62727A,
      ),
    ];
  }

  @override
  void dispose() {
    _nameController.dispose();
    _prefixController.dispose();
    super.dispose();
  }

  Future<void> _pickTemplateImage() async {
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['png', 'jpg', 'jpeg'],
      );
      if (result.isNotEmpty && result.first.path != null) {
        setState(() {
          _templatePath = result.first.path;
          _templateName = result.first.name;
          _useCustomImage = true;
        });
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not pick template image: $e')),
      );
    }
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
      if (_selectedFieldId == id) _selectedFieldId = null;
    });
  }

  Future<void> _openFullScreenEditor() async {
    final updatedFields = await FullScreenTemplateEditor.open(
      context,
      templatePath: _useCustomImage ? _templatePath : null,
      starterTemplateId: _selectedStarterId,
      fields: _fields,
    );
    if (updatedFields != null) {
      setState(() {
        _fields = updatedFields;
      });
    }
  }

  Future<void> _createProject() async {
    if (!_formKey.currentState!.validate()) {
      setState(() => _currentStep = 0);
      return;
    }

    setState(() => _isSaving = true);
    try {
      await context.read<ProjectProvider>().createProjectWithTemplate(
            name: _nameController.text.trim(),
            templatePath: _useCustomImage ? _templatePath : null,
            templateName: _useCustomImage ? _templateName : _selectedStarterId,
            fields: _fields,
            certificatePrefix: _prefixController.text.trim().toUpperCase(),
          );
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Project & Template saved successfully!')),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not save project. Please try again.')),
      );
      setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create New Project'),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Step Progress Indicator
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Row(
                children: [
                  _StepBadge(number: '1', title: 'Details', isActive: _currentStep == 0, isDone: _currentStep > 0),
                  const _StepDivider(),
                  _StepBadge(number: '2', title: 'Template', isActive: _currentStep == 1, isDone: _currentStep > 1),
                  const _StepDivider(),
                  _StepBadge(number: '3', title: 'Fields', isActive: _currentStep == 2, isDone: _currentStep > 2),
                ],
              ),
            ),
            const Divider(height: 1),

            // Step Content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Form(
                  key: _formKey,
                  child: _buildCurrentStep(),
                ),
              ),
            ),

            // Bottom Navigation Actions Bar
            Container(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(top: BorderSide(color: Color(0xFFE4EBE9))),
              ),
              child: Row(
                children: [
                  if (_currentStep > 0)
                    OutlinedButton(
                      onPressed: () => setState(() => _currentStep--),
                      child: const Text('Back'),
                    ),
                  const Spacer(),
                  if (_currentStep < 2)
                    FilledButton.icon(
                      onPressed: () {
                        if (_currentStep == 0) {
                          if (!_formKey.currentState!.validate()) return;
                        }
                        setState(() => _currentStep++);
                      },
                      icon: const Icon(Icons.arrow_forward_rounded, size: 18),
                      label: const Text('Next'),
                    )
                  else
                    FilledButton.icon(
                      onPressed: _isSaving ? null : _createProject,
                      icon: _isSaving
                          ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Icon(Icons.check_circle_outline_rounded, size: 18),
                      label: const Text('Create Project'),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCurrentStep() {
    switch (_currentStep) {
      case 0:
        return _buildStep1Details();
      case 1:
        return _buildStep2TemplateSelection();
      case 2:
        return _buildStep3FieldPlacement();
      default:
        return const SizedBox.shrink();
    }
  }

  // STEP 1: Project Details
  Widget _buildStep1Details() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Start with a Name & Prefix',
          style: TextStyle(color: AppTheme.ink, fontSize: 24, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 6),
        const Text(
          'Give this certificate distribution batch a recognizable name.',
          style: TextStyle(color: AppTheme.muted, fontSize: 14),
        ),
        const SizedBox(height: 24),
        TextFormField(
          controller: _nameController,
          autofocus: true,
          textCapitalization: TextCapitalization.sentences,
          maxLength: 80,
          decoration: const InputDecoration(
            labelText: 'Project name',
            hintText: "DAKSHA'26 Certificate Distribution",
          ),
          validator: (value) {
            if (value == null || value.trim().isEmpty) return 'Enter a project name.';
            if (value.trim().length < 3) return 'Use at least 3 characters.';
            return null;
          },
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _prefixController,
          textCapitalization: TextCapitalization.characters,
          maxLength: 10,
          decoration: const InputDecoration(
            labelText: 'Certificate Code Prefix',
            hintText: 'CERT',
            helperText: 'Unique serial prefix e.g. CERT-001, DAKSHA-002',
          ),
        ),
      ],
    );
  }

  // STEP 2: Add / Choose Certificate Template
  Widget _buildStep2TemplateSelection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Add Certificate Template',
          style: TextStyle(color: AppTheme.ink, fontSize: 24, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 6),
        const Text(
          'Upload your custom certificate background image or pick a starter layout.',
          style: TextStyle(color: AppTheme.muted, fontSize: 14),
        ),
        const SizedBox(height: 20),

        // Custom Image Upload Card
        Card(
          elevation: _useCustomImage ? 2 : 0,
          color: _useCustomImage ? const Color(0xFFF0F7F6) : Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(
              color: _useCustomImage ? AppTheme.ocean : const Color(0xFFE4EBE9),
              width: _useCustomImage ? 2 : 1,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppTheme.ocean.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.upload_file_rounded, color: AppTheme.ocean),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Upload Custom Template Image',
                            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: AppTheme.ink),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _useCustomImage && _templateName != null
                                ? 'Selected: $_templateName'
                                : 'Supports PNG, JPG background images',
                            style: TextStyle(
                              color: _useCustomImage ? AppTheme.teal : AppTheme.muted,
                              fontSize: 12,
                              fontWeight: _useCustomImage ? FontWeight.w700 : FontWeight.w400,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                OutlinedButton.icon(
                  onPressed: _pickTemplateImage,
                  icon: const Icon(Icons.add_photo_alternate_outlined),
                  label: Text(_templatePath != null ? 'Change Custom Image' : 'Pick Image from Device'),
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 24),
        Row(
          children: const [
            Expanded(child: Divider()),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 12),
              child: Text('OR SELECT STARTER DESIGN', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppTheme.muted)),
            ),
            Expanded(child: Divider()),
          ],
        ),
        const SizedBox(height: 16),

        // Starter Preset Grid
        Column(
          children: StarterTemplate.templates.map((starter) {
            final isSelected = !_useCustomImage && _selectedStarterId == starter.id;
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: GestureDetector(
                onTap: () {
                  setState(() {
                    _useCustomImage = false;
                    _selectedStarterId = starter.id;
                  });
                },
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isSelected ? const Color(0xFFF0F7F6) : Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isSelected ? AppTheme.ocean : const Color(0xFFE4EBE9),
                      width: isSelected ? 2 : 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 44,
                        height: 32,
                        decoration: BoxDecoration(
                          color: starter.backgroundColor,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: starter.secondaryColor),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(starter.name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: AppTheme.ink)),
                            Text(starter.description, style: const TextStyle(color: AppTheme.muted, fontSize: 11)),
                          ],
                        ),
                      ),
                      if (isSelected) const Icon(Icons.check_circle_rounded, color: AppTheme.ocean),
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  // STEP 3: Interactive Visual Text Field Placement
  Widget _buildStep3FieldPlacement() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text(
                  'Place Text Fields Inside Template',
                  style: TextStyle(color: AppTheme.ink, fontSize: 20, fontWeight: FontWeight.w800),
                ),
                SizedBox(height: 2),
                Text(
                  'Tap on template or button below to add text fields manually',
                  style: TextStyle(color: AppTheme.muted, fontSize: 12),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 14),

        // Action Toolbar
        Row(
          children: [
            FilledButton.icon(
              onPressed: () => _addNewField(),
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Add Text Field'),
            ),
            const SizedBox(width: 10),
            OutlinedButton.icon(
              onPressed: _openFullScreenEditor,
              icon: const Icon(Icons.fullscreen, size: 18),
              label: const Text('Full Screen'),
            ),
            const Spacer(),
            Text(
              '${_fields.length} field(s)',
              style: const TextStyle(color: AppTheme.muted, fontSize: 13, fontWeight: FontWeight.w600),
            ),
          ],
        ),
        const SizedBox(height: 14),

        // Interactive Visual Canvas
        TemplateEditorCanvas(
          templatePath: _useCustomImage ? _templatePath : null,
          starterTemplateId: _selectedStarterId,
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

        const SizedBox(height: 16),
        const Text(
          'Fields List (Tap to Edit / Reorder)',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppTheme.ink),
        ),
        const SizedBox(height: 8),

        // Field Chips & Quick Edit List
        if (_fields.isEmpty)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Center(
              child: Text(
                'No text fields added yet. Tap "Add Text Field" or tap anywhere on the certificate template above!',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppTheme.muted, fontSize: 12),
              ),
            ),
          )
        else
          Column(
            children: _fields.map((field) {
              final isSelected = _selectedFieldId == field.id;
              return Card(
                elevation: 0,
                color: isSelected ? const Color(0xFFF0F7F6) : Colors.white,
                margin: const EdgeInsets.only(bottom: 6),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                  side: BorderSide(
                    color: isSelected ? AppTheme.ocean : const Color(0xFFE4EBE9),
                  ),
                ),
                child: ListTile(
                  dense: true,
                  leading: CircleAvatar(
                    radius: 14,
                    backgroundColor: Color(field.color).withValues(alpha: 0.15),
                    child: Icon(Icons.text_fields, size: 14, color: Color(field.color)),
                  ),
                  title: Text(
                    field.placeholder,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: Color(field.color),
                    ),
                  ),
                  subtitle: Text('X: ${(field.x * 100).toInt()}% · Y: ${(field.y * 100).toInt()}% · ${field.fontSize.toInt()}pt'),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit, size: 18),
                        onPressed: () => _editField(field),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline, size: 18, color: Color(0xFFB5443B)),
                        onPressed: () => _deleteField(field.id),
                      ),
                    ],
                  ),
                  onTap: () => setState(() => _selectedFieldId = field.id),
                ),
              );
            }).toList(),
          ),
      ],
    );
  }
}

class _StepBadge extends StatelessWidget {
  const _StepBadge({
    required this.number,
    required this.title,
    required this.isActive,
    required this.isDone,
  });

  final String number;
  final String title;
  final bool isActive;
  final bool isDone;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 26,
          height: 26,
          decoration: BoxDecoration(
            color: isDone
                ? AppTheme.teal
                : isActive
                    ? AppTheme.ocean
                    : Colors.grey.shade300,
            shape: BoxShape.circle,
          ),
          child: Center(
            child: isDone
                ? const Icon(Icons.check, size: 16, color: Colors.white)
                : Text(
                    number,
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                  ),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          title,
          style: TextStyle(
            fontWeight: isActive || isDone ? FontWeight.w800 : FontWeight.w500,
            color: isActive || isDone ? AppTheme.ink : AppTheme.muted,
            fontSize: 13,
          ),
        ),
      ],
    );
  }
}

class _StepDivider extends StatelessWidget {
  const _StepDivider();
  @override
  Widget build(BuildContext context) => const Expanded(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 8),
          child: Divider(thickness: 1.5),
        ),
      );
}
