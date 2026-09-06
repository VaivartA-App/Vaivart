import 'dart:io';
import 'dart:convert';
import 'dart:async';
import 'dart:isolate';
import 'package:excel/excel.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path/path.dart' as p;

Future<R> compute<Q, R>(FutureOr<R> Function(Q message) callback, Q message) {
  return Isolate.run(() => callback(message));
}

Map<String, dynamic> _csvToXlsxIsolate(Map<String, dynamic> args) {
  final sourcePath = args['sourcePath'] as String;
  final outPath = args['outPath'] as String;

  final content = File(sourcePath).readAsStringSync();
  final lines = const LineSplitter().convert(content);
  final rows = lines.map((l) => l.split(',')).toList();

  final excel = Excel.createExcel();
  final sheet = excel['Sheet1'];

  for (final row in rows) {
    sheet.appendRow(row.map((e) => TextCellValue(e)).toList());
  }

  final fileBytes = excel.save();
  if (fileBytes == null) throw Exception('Failed to encode xlsx');
  File(outPath).writeAsBytesSync(fileBytes);
  return {'outPath': outPath};
}

Map<String, dynamic> _xlsxToCsvIsolate(Map<String, dynamic> args) {
  final sourcePath = args['sourcePath'] as String;
  final outPath = args['outPath'] as String;

  final bytes = File(sourcePath).readAsBytesSync();
  final excel = Excel.decodeBytes(bytes);
  final sheet = excel.tables.values.first;

  final rows = sheet.rows
      .map((row) => row.map((cell) => cell?.value?.toString() ?? '').join(','))
      .join('\n');

  File(outPath).writeAsStringSync(rows);
  return {'outPath': outPath};
}

Map<String, dynamic> _jsonToCsvIsolate(Map<String, dynamic> args) {
  final sourcePath = args['sourcePath'] as String;
  final outPath = args['outPath'] as String;

  final content = File(sourcePath).readAsStringSync();
  final decoded = jsonDecode(content);
  if (decoded is! List || decoded.isEmpty) {
    throw Exception('JSON must be an array of objects');
  }

  final headers = (decoded.first as Map<String, dynamic>).keys.toList();
  final buffer = StringBuffer();
  buffer.writeln(headers.map(_csvEscape).join(','));

  for (final item in decoded) {
    if (item is Map<String, dynamic>) {
      buffer.writeln(
          headers.map((h) => _csvEscape(item[h]?.toString() ?? '')).join(','));
    }
  }

  File(outPath).writeAsStringSync(buffer.toString());
  return {'outPath': outPath};
}

Map<String, dynamic> _csvToJsonIsolate(Map<String, dynamic> args) {
  final sourcePath = args['sourcePath'] as String;
  final outPath = args['outPath'] as String;

  final content = File(sourcePath).readAsStringSync();
  final lines = const LineSplitter().convert(content);
  if (lines.isEmpty) throw Exception('CSV file is empty');

  final headers = lines.first.split(',').map((h) => h.trim()).toList();
  final rows = <Map<String, String>>[];

  for (int i = 1; i < lines.length; i++) {
    if (lines[i].trim().isEmpty) continue;
    final values = lines[i].split(',');
    final row = <String, String>{};
    for (int j = 0; j < headers.length; j++) {
      row[headers[j]] = j < values.length ? values[j].trim() : '';
    }
    rows.add(row);
  }

  File(outPath)
      .writeAsStringSync(const JsonEncoder.withIndent('  ').convert(rows));
  return {'outPath': outPath};
}

Map<String, dynamic> _tsvToCsvIsolate(Map<String, dynamic> args) {
  final sourcePath = args['sourcePath'] as String;
  final outPath = args['outPath'] as String;

  final content = File(sourcePath).readAsStringSync();
  final lines = const LineSplitter().convert(content);
  final csvLines = lines.map((line) {
    final fields = line.split('\t');
    return fields.map(_csvEscape).join(',');
  }).join('\n');

  File(outPath).writeAsStringSync(csvLines);
  return {'outPath': outPath};
}

Map<String, dynamic> _csvToTsvIsolate(Map<String, dynamic> args) {
  final sourcePath = args['sourcePath'] as String;
  final outPath = args['outPath'] as String;

  final content = File(sourcePath).readAsStringSync();
  final lines = const LineSplitter().convert(content);
  final tsvLines = lines.map((line) => line.split(',').join('\t')).join('\n');

  File(outPath).writeAsStringSync(tsvLines);
  return {'outPath': outPath};
}

Map<String, dynamic> _xlsxToJsonIsolate(Map<String, dynamic> args) {
  final sourcePath = args['sourcePath'] as String;
  final outPath = args['outPath'] as String;

  final bytes = File(sourcePath).readAsBytesSync();
  final excel = Excel.decodeBytes(bytes);
  final sheet = excel.tables.values.first;
  if (sheet.rows.isEmpty) throw Exception('Excel file is empty');

  final headers =
      sheet.rows.first.map((cell) => cell?.value?.toString() ?? '').toList();
  final rows = <Map<String, String>>[];

  for (int i = 1; i < sheet.rows.length; i++) {
    final row = <String, String>{};
    for (int j = 0; j < headers.length; j++) {
      row[headers[j]] = j < sheet.rows[i].length
          ? (sheet.rows[i][j]?.value?.toString() ?? '')
          : '';
    }
    rows.add(row);
  }

  File(outPath)
      .writeAsStringSync(const JsonEncoder.withIndent('  ').convert(rows));
  return {'outPath': outPath};
}

Future<Map<String, dynamic>> _csvToPdfIsolate(Map<String, dynamic> args) async {
  final sourcePath = args['sourcePath'] as String;
  final outPath = args['outPath'] as String;

  final content = File(sourcePath).readAsStringSync();
  final lines = const LineSplitter().convert(content);
  final rows = lines.map((l) => l.split(',')).toList();

  final pdf = pw.Document();
  // Split into chunks of 30 rows per page
  for (var i = 0; i < rows.length; i += 30) {
    final chunk = rows.sublist(i, i + 30 > rows.length ? rows.length : i + 30);
    pdf.addPage(pw.Page(
      pageFormat: PdfPageFormat.a4,
      orientation: pw.PageOrientation.landscape,
      margin: const pw.EdgeInsets.all(24),
      build: (_) => pw.TableHelper.fromTextArray(
        data: chunk,
        headerCount: i == 0 ? 1 : 0,
        cellStyle: const pw.TextStyle(fontSize: 8),
        headerStyle: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold),
      ),
    ));
  }

  File(outPath).writeAsBytesSync(await pdf.save());
  return {'outPath': outPath};
}

String _csvEscape(String value) {
  if (value.contains(',') || value.contains('"') || value.contains('\n')) {
    return '"${value.replaceAll('"', '""')}"';
  }
  return value;
}

/// Handles structured data conversions utilizing background isolates for compute optimization.
class DataConverter {
  static Future<String> csvToXlsx({
    required String sourcePath,
    required String outputDir,
  }) async {
    final baseName = p.basenameWithoutExtension(sourcePath);
    final outPath = p.join(outputDir, '$baseName.xlsx');
    await compute(
        _csvToXlsxIsolate, {'sourcePath': sourcePath, 'outPath': outPath});
    return outPath;
  }

  static Future<String> xlsxToCsv({
    required String sourcePath,
    required String outputDir,
  }) async {
    final baseName = p.basenameWithoutExtension(sourcePath);
    final outPath = p.join(outputDir, '$baseName.csv');
    await compute(
        _xlsxToCsvIsolate, {'sourcePath': sourcePath, 'outPath': outPath});
    return outPath;
  }

  static Future<String> jsonToCsv({
    required String sourcePath,
    required String outputDir,
  }) async {
    final baseName = p.basenameWithoutExtension(sourcePath);
    final outPath = p.join(outputDir, '$baseName.csv');
    await compute(
        _jsonToCsvIsolate, {'sourcePath': sourcePath, 'outPath': outPath});
    return outPath;
  }

  static Future<String> csvToJson({
    required String sourcePath,
    required String outputDir,
  }) async {
    final baseName = p.basenameWithoutExtension(sourcePath);
    final outPath = p.join(outputDir, '$baseName.json');
    await compute(
        _csvToJsonIsolate, {'sourcePath': sourcePath, 'outPath': outPath});
    return outPath;
  }

  static Future<String> tsvToCsv({
    required String sourcePath,
    required String outputDir,
  }) async {
    final baseName = p.basenameWithoutExtension(sourcePath);
    final outPath = p.join(outputDir, '$baseName.csv');
    await compute(
        _tsvToCsvIsolate, {'sourcePath': sourcePath, 'outPath': outPath});
    return outPath;
  }

  static Future<String> csvToTsv({
    required String sourcePath,
    required String outputDir,
  }) async {
    final baseName = p.basenameWithoutExtension(sourcePath);
    final outPath = p.join(outputDir, '$baseName.tsv');
    await compute(
        _csvToTsvIsolate, {'sourcePath': sourcePath, 'outPath': outPath});
    return outPath;
  }

  static Future<String> xlsxToJson({
    required String sourcePath,
    required String outputDir,
  }) async {
    final baseName = p.basenameWithoutExtension(sourcePath);
    final outPath = p.join(outputDir, '$baseName.json');
    await compute(
        _xlsxToJsonIsolate, {'sourcePath': sourcePath, 'outPath': outPath});
    return outPath;
  }

  static Future<String> csvToPdf({
    required String sourcePath,
    required String outputDir,
  }) async {
    final baseName = p.basenameWithoutExtension(sourcePath);
    final outPath = p.join(outputDir, '$baseName.pdf');
    await compute(
        _csvToPdfIsolate, {'sourcePath': sourcePath, 'outPath': outPath});
    return outPath;
  }
}
