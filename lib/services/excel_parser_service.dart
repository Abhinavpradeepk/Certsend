import 'dart:convert';
import 'dart:io';
import 'package:csv/csv.dart';
import 'package:excel/excel.dart';
import 'package:uuid/uuid.dart';

import '../models/participant.dart';

class ExcelParseResult {
  const ExcelParseResult({
    required this.headers,
    required this.participants,
    required this.totalRows,
  });

  final List<String> headers;
  final List<Participant> participants;
  final int totalRows;
}

class ExcelParserService {
  static const _uuid = Uuid();

  Future<ExcelParseResult> parseFile(String filePath, {List<int>? fileBytes}) async {
    List<int> bytes;
    if (fileBytes != null && fileBytes.isNotEmpty) {
      bytes = fileBytes;
    } else {
      final file = File(filePath);
      if (!await file.exists()) {
        throw const FileSystemException('Selected file does not exist or access was denied.');
      }
      bytes = await file.readAsBytes();
    }

    final extension = filePath.split('.').last.toLowerCase();

    if (extension == 'csv') {
      return _parseCsv(bytes);
    } else if (extension == 'xlsx' || extension == 'xls' || extension.isEmpty) {
      return _parseExcel(bytes);
    } else {
      try {
        return _parseExcel(bytes);
      } catch (_) {
        return _parseCsv(bytes);
      }
    }
  }

  ExcelParseResult _parseCsv(List<int> bytes) {
    String content;
    try {
      content = utf8.decode(bytes);
    } catch (_) {
      content = latin1.decode(bytes);
    }

    final rows = csv.decoder.convert(content);
    if (rows.isEmpty) {
      return const ExcelParseResult(headers: [], participants: [], totalRows: 0);
    }

    final rawHeaders = rows.first.map((e) => e.toString().trim()).toList();
    final headers = _normalizeHeaders(rawHeaders);
    final participants = <Participant>[];

    for (var i = 1; i < rows.length; i++) {
      final row = rows[i];
      if (row.isEmpty || row.every((c) => c.toString().trim().isEmpty)) continue;

      final values = <String, String>{};
      for (var j = 0; j < headers.length; j++) {
        final val = j < row.length ? row[j].toString().trim() : '';
        values[headers[j]] = val;
      }

      participants.add(Participant(
        id: _uuid.v4(),
        values: values,
      ));
    }

    return ExcelParseResult(
      headers: headers,
      participants: participants,
      totalRows: participants.length,
    );
  }

  ExcelParseResult _parseExcel(List<int> bytes) {
    Excel excel;
    try {
      excel = Excel.decodeBytes(bytes);
    } catch (e) {
      throw const FormatException('Unable to decode Excel file. Please ensure it is a valid .xlsx spreadsheet.');
    }

    if (excel.tables.isEmpty) {
      return const ExcelParseResult(headers: [], participants: [], totalRows: 0);
    }

    String? sheetName;
    for (final name in excel.tables.keys) {
      final t = excel.tables[name];
      if (t != null && t.rows.isNotEmpty) {
        sheetName = name;
        break;
      }
    }

    if (sheetName == null) {
      return const ExcelParseResult(headers: [], participants: [], totalRows: 0);
    }

    final sheet = excel.tables[sheetName]!;
    if (sheet.rows.isEmpty) {
      return const ExcelParseResult(headers: [], participants: [], totalRows: 0);
    }

    int headerRowIndex = 0;
    List<Data?>? rawHeaderRow;
    for (var i = 0; i < sheet.rows.length; i++) {
      final row = sheet.rows[i];
      if (row.any((cell) => _getCellValueString(cell).isNotEmpty)) {
        headerRowIndex = i;
        rawHeaderRow = row;
        break;
      }
    }

    if (rawHeaderRow == null) {
      return const ExcelParseResult(headers: [], participants: [], totalRows: 0);
    }

    final rawHeaders = rawHeaderRow.map((cell) => _getCellValueString(cell)).toList();
    final headers = _normalizeHeaders(rawHeaders);
    final participants = <Participant>[];

    for (var i = headerRowIndex + 1; i < sheet.rows.length; i++) {
      final row = sheet.rows[i];
      if (row.every((cell) => _getCellValueString(cell).isEmpty)) {
        continue;
      }

      final values = <String, String>{};
      for (var j = 0; j < headers.length; j++) {
        final cell = j < row.length ? row[j] : null;
        final val = _getCellValueString(cell);
        values[headers[j]] = val;
      }

      participants.add(Participant(
        id: _uuid.v4(),
        values: values,
      ));
    }

    return ExcelParseResult(
      headers: headers,
      participants: participants,
      totalRows: participants.length,
    );
  }

  String _getCellValueString(Data? cell) {
    if (cell == null) return '';
    final val = cell.value;
    if (val == null) return '';

    if (val is TextCellValue) {
      return val.value.text?.trim() ?? '';
    }
    if (val is IntCellValue) {
      return val.value.toString().trim();
    }
    if (val is DoubleCellValue) {
      final d = val.value;
      if (d == d.toInt()) {
        return d.toInt().toString();
      }
      return d.toString().trim();
    }
    if (val is DateCellValue) {
      return '${val.year}-${val.month.toString().padLeft(2, '0')}-${val.day.toString().padLeft(2, '0')}';
    }
    if (val is DateTimeCellValue) {
      return '${val.year}-${val.month.toString().padLeft(2, '0')}-${val.day.toString().padLeft(2, '0')}';
    }
    if (val is BoolCellValue) {
      return val.value.toString();
    }
    if (val is FormulaCellValue) {
      return val.formula.trim();
    }

    final str = val.toString().trim();
    final match = RegExp(r'TextSpan\(text:\s*(.*?)(?:,|\))').firstMatch(str);
    if (match != null && match.group(1) != null) {
      return match.group(1)!.trim();
    }
    return str;
  }

  List<String> _normalizeHeaders(List<String> rawHeaders) {
    final headers = <String>[];
    for (var i = 0; i < rawHeaders.length; i++) {
      var h = rawHeaders[i].trim().toUpperCase();
      if (h.isEmpty) h = 'COLUMN_${i + 1}';
      headers.add(h);
    }
    return headers;
  }
}
