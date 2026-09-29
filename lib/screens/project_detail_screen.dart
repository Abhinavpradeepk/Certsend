import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'full_screen_template_editor.dart';
import '../models/certificate_field.dart';
import '../models/certificate_project.dart';
import '../models/generated_certificate.dart';
import '../models/participant.dart';
import '../providers/project_provider.dart';
import '../services/pdf_download_service.dart';
import '../theme/app_theme.dart';
import '../widgets/excel_import_dialog.dart';
import '../widgets/field_property_dialog.dart';
import '../widgets/template_editor_canvas.dart';

class ProjectDetailScreen extends StatefulWidget {
  const ProjectDetailScreen({super.key, required this.project});
  final CertificateProject project;

  @override
  State<ProjectDetailScreen> createState() => _ProjectDetailScreenState();
}

class _ProjectDetailScreenState extends State<ProjectDetailScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late CertificateProject _project;
  String? _selectedFieldId;
  bool _isGeneratingAll = false;
  bool _isSendingAll = false;
  final Set<String> _sendingParticipantIds = {};

  @override
  void initState() {
    super.initState();
    _project = widget.project;
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _importExcelSheet() async {
    final result = await ExcelImportDialog.show(context);
    if (result != null && result.participants.isNotEmpty && mounted) {
      final provider = context.read<ProjectProvider>();
      await provider.importParticipants(_project.id, result.participants);

      final updated = provider.projects.firstWhere((p) => p.id == _project.id);
      setState(() => _project = updated);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Successfully imported ${result.totalRows} participant(s) from Excel!',
          ),
        ),
      );
    }
  }

  Future<void> _generateAllCertificates() async {
    if (_project.participants.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add or import participants first.')),
      );
      return;
    }

    setState(() => _isGeneratingAll = true);
    try {
      final provider = context.read<ProjectProvider>();
      final count = await provider.generateAllCertificates(_project.id);

      final updated = provider.projects.firstWhere((p) => p.id == _project.id);
      setState(() => _project = updated);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Generated $count individual certificate PDF(s)!'),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error generating certificates: $e')),
      );
    } finally {
      if (mounted) setState(() => _isGeneratingAll = false);
    }
  }

  Future<void> _editEmailTemplate() async {
    final subjectController = TextEditingController(
      text: _project.emailSubject,
    );
    final bodyController = TextEditingController(text: _project.emailBody);
    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Email content'),
        content: SizedBox(
          width: 480,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: subjectController,
                decoration: const InputDecoration(labelText: 'Subject'),
                maxLength: 200,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: bodyController,
                decoration: const InputDecoration(labelText: 'Message'),
                minLines: 4,
                maxLines: 8,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (saved == true && mounted) {
      final updated = _project.copyWith(
        emailSubject: subjectController.text.trim(),
        emailBody: bodyController.text,
      );
      await context.read<ProjectProvider>().updateProject(updated);
      if (mounted) setState(() => _project = updated);
    }
    subjectController.dispose();
    bodyController.dispose();
  }

  Future<void> _sendCertificateEmail(Participant participant) async {
    if (participant.email.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('This participant has no email address.')),
      );
      return;
    }

    setState(() => _sendingParticipantIds.add(participant.id));
    try {
      final provider = context.read<ProjectProvider>();
      final sent = await provider.sendCertificate(_project.id, participant.id);
      final updated = provider.projects.firstWhere(
        (item) => item.id == _project.id,
      );
      if (mounted) setState(() => _project = updated);
      if (!mounted) return;
      final certificate = updated.certificates.firstWhere(
        (item) => item.participantId == participant.id,
      );
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            sent
                ? 'Certificate emailed to ${participant.email}.'
                : 'Email failed: ${certificate.emailFailureReason ?? 'Check the email service setup.'}',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Email failed: $error')));
    } finally {
      if (mounted) {
        setState(() => _sendingParticipantIds.remove(participant.id));
      }
    }
  }

  Future<void> _sendAllCertificateEmails() async {
    setState(() => _isSendingAll = true);
    try {
      final provider = context.read<ProjectProvider>();
      final sentCount = await provider.sendAllCertificates(_project.id);
      final updated = provider.projects.firstWhere(
        (item) => item.id == _project.id,
      );
      final availableCount = updated.certificates
          .where(
            (item) =>
                item.filePath != null && File(item.filePath!).existsSync(),
          )
          .length;
      if (mounted) setState(() => _project = updated);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Emailed $sentCount of $availableCount generated certificate(s).',
            ),
          ),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Email batch failed: $error')));
      }
    } finally {
      if (mounted) setState(() => _isSendingAll = false);
    }
  }

  Future<void> _generateSingleCertificate(Participant participant) async {
    try {
      final provider = context.read<ProjectProvider>();
      final pdfPath = await provider.generateSingleCertificate(
        _project.id,
        participant,
      );

      final updated = provider.projects.firstWhere((p) => p.id == _project.id);
      setState(() => _project = updated);

      if (pdfPath != null && mounted) {
        final name = participant.values['NAME'] ?? 'Participant';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Certificate PDF generated for $name!')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error generating certificate: $e')),
      );
    }
  }

  Future<void> _downloadSinglePdf(String filePath, String fileName) async {
    try {
      await PdfDownloadService.shareOrSavePdf(
        filePath: filePath,
        fileName: fileName,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Download failed: $e')));
    }
  }

  Future<void> _downloadAllPdfs() async {
    final generatedPaths = _project.certificates
        .where((c) => c.filePath != null && File(c.filePath!).existsSync())
        .map((c) => c.filePath!)
        .toList();

    if (generatedPaths.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'No generated certificate PDFs available to download. Click "Generate Certificates" first.',
          ),
        ),
      );
      return;
    }

    try {
      final count = await PdfDownloadService.batchExportPdfs(
        pdfPaths: generatedPaths,
      );

      if (count > 0 && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Successfully exported $count certificate PDF(s)!'),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Export error: $e')));
    }
  }

  Future<void> _pickNewTemplate() async {
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['png', 'jpg', 'jpeg'],
      );
      if (result.isNotEmpty && result.first.path != null) {
        final path = result.first.path!;
        final name = result.first.name;

        if (!mounted) return;
        final provider = context.read<ProjectProvider>();
        final savedPath = await provider.saveTemplateFile(path, name);
        final updated = _project.copyWith(
          templatePath: savedPath,
          templateName: name,
        );
        setState(() => _project = updated);
        await provider.updateProject(updated);

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Template image updated!')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Error updating template: $e')));
    }
  }

  Future<void> _addField({double x = 0.5, double y = 0.5}) async {
    final newField = await FieldPropertyDialog.show(context, x: x, y: y);
    if (newField != null && mounted) {
      final updatedFields = [..._project.fields, newField];
      final updated = _project.copyWith(fields: updatedFields);
      setState(() {
        _project = updated;
        _selectedFieldId = newField.id;
      });
      await context.read<ProjectProvider>().updateProject(updated);
    }
  }

  Future<void> _editField(CertificateField field) async {
    final updatedField = await FieldPropertyDialog.show(context, field: field);
    if (updatedField != null && mounted) {
      final updatedFields = [
        for (final f in _project.fields)
          f.id == updatedField.id ? updatedField : f,
      ];
      final updated = _project.copyWith(fields: updatedFields);
      setState(() => _project = updated);
      await context.read<ProjectProvider>().updateProject(updated);
    }
  }

  Future<void> _deleteField(String id) async {
    final updatedFields = _project.fields.where((f) => f.id != id).toList();
    final updated = _project.copyWith(fields: updatedFields);
    setState(() {
      _project = updated;
      if (_selectedFieldId == id) _selectedFieldId = null;
    });
    if (!mounted) return;
    await context.read<ProjectProvider>().updateProject(updated);
  }

  Future<void> _onFieldMoved(CertificateField field) async {
    final updatedFields = [
      for (final f in _project.fields) f.id == field.id ? field : f,
    ];
    final updated = _project.copyWith(fields: updatedFields);
    setState(() => _project = updated);
    if (!mounted) return;
    await context.read<ProjectProvider>().updateProject(updated);
  }

  Future<void> _openFullScreenEditor() async {
    final updatedFields = await FullScreenTemplateEditor.open(
      context,
      templatePath: _project.templatePath,
      starterTemplateId: _project.templateName ?? 'golden_classic',
      fields: _project.fields,
    );
    if (updatedFields != null && mounted) {
      final updated = _project.copyWith(fields: updatedFields);
      setState(() => _project = updated);
      await context.read<ProjectProvider>().updateProject(updated);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _project.name,
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline, color: Color(0xFFB5443B)),
            tooltip: 'Delete Project',
            onPressed: () async {
              final navigator = Navigator.of(context);
              final provider = context.read<ProjectProvider>();
              final confirm = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Delete Project?'),
                  content: Text(
                    'Are you sure you want to delete "${_project.name}"?',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(ctx).pop(false),
                      child: const Text('Cancel'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.of(ctx).pop(true),
                      child: const Text(
                        'Delete',
                        style: TextStyle(color: Color(0xFFB5443B)),
                      ),
                    ),
                  ],
                ),
              );
              if (confirm == true && mounted) {
                await provider.deleteProject(_project.id);
                if (!mounted) return;
                navigator.pop();
              }
            },
          ),
          const SizedBox(width: 8),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppTheme.ocean,
          unselectedLabelColor: AppTheme.muted,
          indicatorColor: AppTheme.ocean,
          tabs: const [
            Tab(icon: Icon(Icons.palette_outlined), text: 'Template'),
            Tab(icon: Icon(Icons.people_outline), text: 'Participants'),
            Tab(
              icon: Icon(Icons.picture_as_pdf_outlined),
              text: 'PDFs & Download',
            ),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildTemplateTab(),
          _buildParticipantsTab(),
          _buildPdfsTab(),
        ],
      ),
    );
  }

  // TAB 1: Template & Fields
  Widget _buildTemplateTab() {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Certificate Template Designer',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.ink,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _project.templateName != null
                      ? 'Background: ${_project.templateName}'
                      : 'Starter Template Canvas',
                  style: const TextStyle(color: AppTheme.muted, fontSize: 12),
                ),
              ],
            ),
            OutlinedButton.icon(
              onPressed: _pickNewTemplate,
              icon: const Icon(Icons.upload_file, size: 16),
              label: const Text('Change Template Image'),
            ),
          ],
        ),
        const SizedBox(height: 14),

        // Action bar
        Row(
          children: [
            FilledButton.icon(
              onPressed: () => _addField(),
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Add Text Field'),
            ),
            const SizedBox(width: 8),
            OutlinedButton.icon(
              onPressed: _openFullScreenEditor,
              icon: const Icon(Icons.fullscreen, size: 18),
              label: const Text('Full Screen'),
            ),
            const Spacer(),
            Text(
              '${_project.fields.length} text field(s) positioned',
              style: const TextStyle(
                color: AppTheme.muted,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),

        // Interactive Editor Canvas
        TemplateEditorCanvas(
          templatePath: _project.templatePath,
          starterTemplateId: _project.templateName ?? 'golden_classic',
          fields: _project.fields,
          selectedFieldId: _selectedFieldId,
          onFieldSelected: (id) => setState(() => _selectedFieldId = id),
          onFieldChanged: (field) => _onFieldMoved(field),
          onFieldTap: (field) => _editField(field),
          onCanvasTap: (relX, relY) => _addField(x: relX, y: relY),
          onDeleteField: (id) => _deleteField(id),
        ),

        const SizedBox(height: 20),
        const Text(
          'Configured Text Fields',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w800,
            color: AppTheme.ink,
          ),
        ),
        const SizedBox(height: 10),

        if (_project.fields.isEmpty)
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE4EBE9)),
            ),
            child: const Center(
              child: Text(
                'No text fields inside this template yet.\nTap "+ Add Text Field" or tap anywhere on the canvas above to place a text field!',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppTheme.muted),
              ),
            ),
          )
        else
          Column(
            children: _project.fields.map((field) {
              final isSelected = _selectedFieldId == field.id;
              return Card(
                elevation: 0,
                color: isSelected ? const Color(0xFFF0F7F6) : Colors.white,
                margin: const EdgeInsets.only(bottom: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                  side: BorderSide(
                    color: isSelected
                        ? AppTheme.ocean
                        : const Color(0xFFE4EBE9),
                  ),
                ),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Color(field.color).withValues(alpha: 0.15),
                    child: Icon(Icons.text_fields, color: Color(field.color)),
                  ),
                  title: Text(
                    field.placeholder,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: Color(field.color),
                    ),
                  ),
                  subtitle: Text(
                    'Pos: ${(field.x * 100).toInt()}% X, ${(field.y * 100).toInt()}% Y · ${field.fontSize.toInt()}pt · ${field.fontWeight == FontWeight.w700 ? "Bold" : "Normal"}',
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit_outlined, size: 20),
                        onPressed: () => _editField(field),
                      ),
                      IconButton(
                        icon: const Icon(
                          Icons.delete_outline,
                          size: 20,
                          color: Color(0xFFB5443B),
                        ),
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

  // TAB 2: Participants & Excel Sheet Import
  Widget _buildParticipantsTab() {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '${_project.participants.length} Participant(s)',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: AppTheme.ink,
              ),
            ),
            FilledButton.icon(
              onPressed: _importExcelSheet,
              icon: const Icon(Icons.table_chart_outlined, size: 18),
              label: const Text('Import Excel Sheet'),
            ),
          ],
        ),
        const SizedBox(height: 14),

        if (_project.participants.isEmpty)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: Column(
                children: [
                  const Icon(
                    Icons.table_chart_outlined,
                    size: 42,
                    color: AppTheme.teal,
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'No participants added yet',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                      color: AppTheme.ink,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Import an Excel sheet (.xlsx) or CSV containing columns like Name, Class, Event, etc.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppTheme.muted, fontSize: 13),
                  ),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: _importExcelSheet,
                    icon: const Icon(Icons.upload_file),
                    label: const Text('Import Excel / CSV Sheet'),
                  ),
                ],
              ),
            ),
          )
        else
          Column(
            children: _project.participants.map((p) {
              final name =
                  p.values['NAME'] ??
                  p.values['Name'] ??
                  p.values.values.firstOrNull ??
                  'Participant';
              final className =
                  p.values['CLASS'] ??
                  p.values['Class'] ??
                  p.values['DEPARTMENT'] ??
                  '';

              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  leading: const CircleAvatar(
                    backgroundColor: Color(0xFFE6F2F0),
                    child: Icon(Icons.person_outline, color: AppTheme.teal),
                  ),
                  title: Text(
                    name,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                      color: AppTheme.ink,
                    ),
                  ),
                  subtitle: Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: [
                      if (className.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: AppTheme.ocean.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            'Class: $className',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.ocean,
                            ),
                          ),
                        ),
                      ...p.values.entries
                          .where(
                            (e) =>
                                e.key.toUpperCase() != 'NAME' &&
                                e.key.toUpperCase() != 'CLASS' &&
                                e.value.isNotEmpty,
                          )
                          .map(
                            (e) => Text(
                              '${e.key}: ${e.value}',
                              style: const TextStyle(
                                fontSize: 11,
                                color: AppTheme.muted,
                              ),
                            ),
                          ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
      ],
    );
  }

  // TAB 3: Individual PDF Certificate Generation & Downloads
  Widget _buildPdfsTab() {
    final generatedCount = _project.certificates
        .where((c) => c.filePath != null && File(c.filePath!).existsSync())
        .length;

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Generate & Download PDFs',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.ink,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '$generatedCount of ${_project.participants.length} certificate PDF(s) ready',
                  style: const TextStyle(color: AppTheme.muted, fontSize: 12),
                ),
              ],
            ),
            if (generatedCount > 0)
              OutlinedButton.icon(
                onPressed: _downloadAllPdfs,
                icon: const Icon(Icons.folder_zip_outlined, size: 18),
                label: const Text('Download All PDFs'),
              ),
          ],
        ),
        const SizedBox(height: 14),

        // Global Generate Button
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: _isGeneratingAll ? null : _generateAllCertificates,
            icon: _isGeneratingAll
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.picture_as_pdf_rounded),
            label: Text(
              _isGeneratingAll
                  ? 'Generating PDFs...'
                  : 'Generate Certificates for All (${_project.participants.length})',
            ),
          ),
        ),
        const SizedBox(height: 20),

        OutlinedButton.icon(
          onPressed: _editEmailTemplate,
          icon: const Icon(Icons.edit_note_outlined),
          label: Text('Email content: ${_project.emailSubject}'),
        ),
        const SizedBox(height: 8),
        FilledButton.icon(
          onPressed: generatedCount == 0 || _isSendingAll
              ? null
              : _sendAllCertificateEmails,
          icon: _isSendingAll
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Icon(Icons.send_outlined),
          label: Text(
            _isSendingAll
                ? 'Sending certificates...'
                : 'Send individually to all (${_project.sentCount}/$generatedCount sent)',
          ),
        ),
        const SizedBox(height: 20),

        if (_project.participants.isEmpty)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  const Icon(
                    Icons.table_rows_outlined,
                    size: 36,
                    color: AppTheme.teal,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'No participants in project',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Import participants from Excel first to generate certificate PDFs.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppTheme.muted),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: _importExcelSheet,
                    icon: const Icon(Icons.table_chart_outlined),
                    label: const Text('Import Excel Sheet'),
                  ),
                ],
              ),
            ),
          )
        else
          Column(
            children: _project.participants.map((p) {
              final name =
                  p.values['NAME'] ??
                  p.values['Name'] ??
                  p.values.values.firstOrNull ??
                  'Participant';
              final className = p.values['CLASS'] ?? p.values['Class'] ?? '';

              final certRecord = _project.certificates.firstWhere(
                (c) => c.participantId == p.id,
                orElse: () => GeneratedCertificate(
                  participantId: p.id,
                  certificateId: '',
                ),
              );

              final hasPdf =
                  certRecord.filePath != null &&
                  File(certRecord.filePath!).existsSync();
              final fileName =
                  '${_project.certificatePrefix}_${name.replaceAll(RegExp(r'[^A-Za-z0-9]'), '_')}.pdf';

              return Card(
                margin: const EdgeInsets.only(bottom: 10),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(
                    color: hasPdf
                        ? AppTheme.teal.withValues(alpha: 0.5)
                        : const Color(0xFFE4EBE9),
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: hasPdf
                              ? const Color(0xFFE6F2F0)
                              : Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          hasPdf
                              ? Icons.picture_as_pdf
                              : Icons.picture_as_pdf_outlined,
                          color: hasPdf ? AppTheme.teal : Colors.grey.shade400,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              name,
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 15,
                                color: AppTheme.ink,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              p.email.isEmpty ? 'No email address' : p.email,
                              style: const TextStyle(
                                fontSize: 11,
                                color: AppTheme.muted,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 3),
                            Row(
                              children: [
                                if (className.isNotEmpty) ...[
                                  Text(
                                    'Class: $className',
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: AppTheme.ocean,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const Text(
                                    ' · ',
                                    style: TextStyle(color: AppTheme.muted),
                                  ),
                                ],
                                Text(
                                  hasPdf
                                      ? 'Ready (${certRecord.certificateId})'
                                      : 'Not generated',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: hasPdf
                                        ? AppTheme.teal
                                        : AppTheme.muted,
                                    fontWeight: hasPdf
                                        ? FontWeight.w700
                                        : FontWeight.w400,
                                  ),
                                ),
                              ],
                            ),
                            if (hasPdf)
                              Text(
                                certRecord.emailStatus == DeliveryStatus.failed
                                    ? 'Email failed: ${certRecord.emailFailureReason ?? 'Unknown error'}'
                                    : 'Email: ${certRecord.emailStatus.name}',
                                style: TextStyle(
                                  fontSize: 11,
                                  color:
                                      certRecord.emailStatus ==
                                          DeliveryStatus.sent
                                      ? AppTheme.teal
                                      : certRecord.emailStatus ==
                                            DeliveryStatus.failed
                                      ? const Color(0xFFB5443B)
                                      : AppTheme.muted,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),

                      // Action Buttons: Generate / Download / Print
                      if (!hasPdf)
                        IconButton(
                          icon: const Icon(
                            Icons.play_circle_outline,
                            color: AppTheme.ocean,
                          ),
                          tooltip: 'Generate PDF',
                          onPressed: () => _generateSingleCertificate(p),
                        )
                      else ...[
                        IconButton(
                          icon: _sendingParticipantIds.contains(p.id)
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(
                                  Icons.send_outlined,
                                  color: AppTheme.teal,
                                ),
                          tooltip: 'Email certificate individually',
                          onPressed:
                              _isSendingAll ||
                                  _sendingParticipantIds.contains(p.id)
                              ? null
                              : () => _sendCertificateEmail(p),
                        ),
                        IconButton(
                          icon: const Icon(
                            Icons.download_rounded,
                            color: AppTheme.ocean,
                          ),
                          tooltip: 'Download PDF',
                          onPressed: () => _downloadSinglePdf(
                            certRecord.filePath!,
                            fileName,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(
                            Icons.print_outlined,
                            color: AppTheme.ink,
                          ),
                          tooltip: 'Print / Preview PDF',
                          onPressed: () =>
                              PdfDownloadService.printPdf(certRecord.filePath!),
                        ),
                      ],
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
      ],
    );
  }
}
