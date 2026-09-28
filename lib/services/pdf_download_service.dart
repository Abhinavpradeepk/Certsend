import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:printing/printing.dart';

class PdfDownloadService {
  /// Opens native print/share/save preview for an individual PDF file
  static Future<void> shareOrSavePdf({
    required String filePath,
    required String fileName,
  }) async {
    final file = File(filePath);
    if (!await file.exists()) {
      throw const FileSystemException('Certificate PDF file not found.');
    }
    final bytes = await file.readAsBytes();

    await Printing.sharePdf(
      bytes: bytes,
      filename: fileName,
    );
  }

  /// Print directly to printer
  static Future<void> printPdf(String filePath) async {
    final file = File(filePath);
    if (!await file.exists()) {
      throw const FileSystemException('Certificate PDF file not found.');
    }
    final bytes = await file.readAsBytes();

    await Printing.layoutPdf(
      onLayout: (format) async => bytes,
    );
  }

  /// Download/Save PDF to a custom folder selected by user
  static Future<String?> savePdfToFolder({
    required String filePath,
    required String fileName,
  }) async {
    final source = File(filePath);
    if (!await source.exists()) return null;

    final selectedDirectory = await FilePicker.getDirectoryPath(
      dialogTitle: 'Select Folder to Save Certificate PDF',
    );

    if (selectedDirectory == null || selectedDirectory.isEmpty) return null;

    final destination = File('$selectedDirectory${Platform.pathSeparator}$fileName');
    await source.copy(destination.path);
    return destination.path;
  }

  /// Export / Batch Download all PDF files to a folder
  static Future<int> batchExportPdfs({
    required List<String> pdfPaths,
    String? folderPath,
  }) async {
    String? targetFolder = folderPath;
    if (targetFolder == null || targetFolder.isEmpty) {
      targetFolder = await FilePicker.getDirectoryPath(
        dialogTitle: 'Select Folder to Save All Certificate PDFs',
      );
    }

    if (targetFolder == null || targetFolder.isEmpty) return 0;

    int exportedCount = 0;
    for (final path in pdfPaths) {
      final file = File(path);
      if (await file.exists()) {
        final name = path.split(Platform.pathSeparator).last;
        final dest = File('$targetFolder${Platform.pathSeparator}$name');
        await file.copy(dest.path);
        exportedCount++;
      }
    }
    return exportedCount;
  }
}
