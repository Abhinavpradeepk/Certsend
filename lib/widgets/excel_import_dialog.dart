import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../services/excel_parser_service.dart';
import '../theme/app_theme.dart';

class ExcelImportDialog extends StatefulWidget {
  const ExcelImportDialog({super.key});

  static Future<ExcelParseResult?> show(BuildContext context) {
    return showModalBottomSheet<ExcelParseResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: const ExcelImportDialog(),
      ),
    );
  }

  @override
  State<ExcelImportDialog> createState() => _ExcelImportDialogState();
}

class _ExcelImportDialogState extends State<ExcelImportDialog> {
  final ExcelParserService _parser = ExcelParserService();
  String? _selectedFileName;
  ExcelParseResult? _parseResult;
  bool _isLoading = false;
  String? _errorMessage;

  Future<void> _pickExcelFile() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['xlsx', 'xls', 'csv'],
      );

      if (!mounted) return;

      if (result.isNotEmpty && result.first.path != null) {
        final platformFile = result.first;
        final name = platformFile.name;
        final path = platformFile.path!;

        final parsed = await _parser.parseFile(path);

        if (!mounted) return;
        setState(() {
          _selectedFileName = name;
          _parseResult = parsed;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Could not read spreadsheet: $e';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
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
              const Text(
                'Import Excel Sheet / CSV',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppTheme.ink),
              ),
              IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            'Fetch Name, Class, Event, and other fields directly from an Excel spreadsheet.',
            style: TextStyle(color: AppTheme.muted, fontSize: 13),
          ),
          const SizedBox(height: 16),

          // File Picker Button / Picked Card
          if (_parseResult == null)
            Card(
              elevation: 0,
              color: const Color(0xFFF5F8F7),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: const BorderSide(color: Color(0xFFD7E1DE)),
              ),
              child: InkWell(
                onTap: _isLoading ? null : _pickExcelFile,
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 30),
                  child: Column(
                    children: [
                      if (_isLoading)
                        const CircularProgressIndicator()
                      else ...[
                        const Icon(Icons.table_chart_outlined, size: 42, color: AppTheme.ocean),
                        const SizedBox(height: 10),
                        const Text(
                          'Choose Excel or CSV File',
                          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: AppTheme.ink),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Supports .xlsx, .xls and .csv files with headers like NAME, CLASS, etc.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: AppTheme.muted, fontSize: 12),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            )
          else ...[
            // Parsed Info Card
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFF0F7F6),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.ocean),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.description_outlined, color: AppTheme.ocean),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _selectedFileName ?? 'Spreadsheet',
                              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: AppTheme.ink),
                            ),
                            Text(
                              'Found ${_parseResult!.totalRows} participant record(s)',
                              style: const TextStyle(color: AppTheme.teal, fontSize: 12, fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      ),
                      TextButton(
                        onPressed: _pickExcelFile,
                        child: const Text('Change File'),
                      ),
                    ],
                  ),
                  const Divider(height: 20),
                  const Text(
                    'Detected Columns / Fields:',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppTheme.ink),
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: _parseResult!.headers.map((h) {
                      return Chip(
                        visualDensity: VisualDensity.compact,
                        backgroundColor: Colors.white,
                        label: Text(h, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppTheme.ink)),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // Preview Table snippet (First 3 participants)
            if (_parseResult!.participants.isNotEmpty) ...[
              const Text(
                'Data Sample Preview (First 3 Rows):',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppTheme.ink),
              ),
              const SizedBox(height: 6),
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFE4EBE9)),
                ),
                child: Column(
                  children: _parseResult!.participants.take(3).map((p) {
                    final previewText = p.values.entries.map((e) => '${e.key}: ${e.value}').join('  ·  ');
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: const BoxDecoration(
                        border: Border(bottom: BorderSide(color: Color(0xFFE4EBE9))),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.person_outline, size: 14, color: AppTheme.muted),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              previewText,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 11, color: AppTheme.ink),
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          ],

          if (_errorMessage != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF1EF),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error_outline, color: Color(0xFFB5443B), size: 18),
                  const SizedBox(width: 8),
                  Expanded(child: Text(_errorMessage!, style: const TextStyle(color: Color(0xFFB5443B), fontSize: 12))),
                ],
              ),
            ),
          ],

          const SizedBox(height: 20),

          // Action Button
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _parseResult != null && _parseResult!.participants.isNotEmpty
                  ? () => Navigator.of(context).pop(_parseResult)
                  : null,
              icon: const Icon(Icons.file_download_done_rounded),
              label: Text(_parseResult == null
                  ? 'Select Excel Sheet'
                  : 'Import ${_parseResult!.totalRows} Participants'),
            ),
          ),
        ],
      ),
    );
  }
}
