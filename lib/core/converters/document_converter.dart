import 'dart:io';
import 'dart:convert';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path/path.dart' as p;

import 'package:archive/archive.dart';
import '../engine/tool_resolver.dart';

/// Handles document conversions for text, markdown, HTML, office formats, e-books, and code files.
class DocumentConverter {
  static Future<String> _getSoffice() async {
    final path = await ToolResolver.findExecutable('soffice');
    if (path == null) {
      throw Exception(
        'LibreOffice (soffice) not found. Please install LibreOffice or check your PATH in Settings.',
      );
    }
    return path;
  }

  static Future<String> _getEbookConvert() async {
    final path = await ToolResolver.findExecutable('ebook-convert');
    if (path == null) {
      throw Exception(
        'Calibre (ebook-convert) not found. Please install Calibre or check your PATH in Settings.',
      );
    }
    return path;
  }

  static Future<String> txtToPdf({
    required String sourcePath,
    required String outputDir,
  }) async {
    final content = await File(sourcePath).readAsString();
    final pdf = pw.Document();
    final lines = content.split('\n');
    final chunks = <List<String>>[];

    for (var i = 0; i < lines.length; i += 40) {
      chunks
          .add(lines.sublist(i, i + 40 > lines.length ? lines.length : i + 40));
    }

    for (final chunk in chunks) {
      pdf.addPage(pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(40),
        build: (_) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: chunk
              .map((line) =>
                  pw.Text(line, style: const pw.TextStyle(fontSize: 11)))
              .toList(),
        ),
      ));
    }

    final baseName = p.basenameWithoutExtension(sourcePath);
    final outPath = p.join(outputDir, '$baseName.pdf');
    await File(outPath).writeAsBytes(await pdf.save());
    return outPath;
  }

  static Future<String> docxToPdf({
    required String sourcePath,
    required String outputDir,
  }) async {
    final soffice = await _getSoffice();
    final result = await Process.run(soffice, [
      '--headless',
      '--convert-to',
      'pdf',
      '--outdir',
      outputDir,
      sourcePath,
    ]);

    if (result.exitCode != 0) {
      throw Exception('LibreOffice error: ${result.stderr}');
    }

    final baseName = p.basenameWithoutExtension(sourcePath);
    return p.join(outputDir, '$baseName.pdf');
  }

  static Future<String> pdfToDocx({
    required String sourcePath,
    required String outputDir,
  }) async {
    final text = await _extractTextFromPdf(sourcePath: sourcePath);
    final baseName = p.basenameWithoutExtension(sourcePath);
    final outPath = p.join(outputDir, '$baseName.docx');
    await File(outPath).writeAsString(text);
    return outPath;
  }

  static Future<String> pdfToMd({
    required String sourcePath,
    required String outputDir,
  }) async {
    final text = await _extractTextFromPdf(sourcePath: sourcePath);
    final baseName = p.basenameWithoutExtension(sourcePath);
    final outPath = p.join(outputDir, '$baseName.md');
    await File(outPath).writeAsString(text);
    return outPath;
  }

  static Future<String> _extractTextFromPdf({
    required String sourcePath,
  }) async {
    // 1. Try poppler pdftotext (highest fidelity, preserves layout & tables)
    try {
      final pdftotext = await ToolResolver.findExecutable('pdftotext');
      if (pdftotext != null) {
        final result =
            await Process.run(pdftotext, ['-layout', sourcePath, '-']);
        if (result.exitCode == 0 && result.stdout is String) {
          final out = (result.stdout as String).trim();
          if (out.isNotEmpty) {
            return out;
          }
        }
      }
    } catch (_) {}

    // 2. Try Ghostscript txtwrite device (gs / gswin64c / gswin32c)
    try {
      final gs = await ToolResolver.findExecutable('gs') ??
          await ToolResolver.findExecutable('gswin64c') ??
          await ToolResolver.findExecutable('gswin32c');
      if (gs != null) {
        final result = await Process.run(gs, [
          '-sDEVICE=txtwrite',
          '-dBATCH',
          '-dNOPAUSE',
          '-dSAFER',
          '-q',
          '-sOutputFile=-',
          sourcePath,
        ]);
        if (result.exitCode == 0 && result.stdout is String) {
          final out = (result.stdout as String).trim();
          if (out.isNotEmpty) {
            return out;
          }
        }
      }
    } catch (_) {}

    // 3. Try pure Dart stream decompression using archive (FlateDecode)
    try {
      final fileBytes = await File(sourcePath).readAsBytes();
      final pureText = _extractTextPureDart(fileBytes);
      if (pureText.trim().isNotEmpty) {
        return pureText.trim();
      }
    } catch (_) {}

    // 4. Try Tesseract OCR if scanned PDF
    try {
      final tesseract = await ToolResolver.findExecutable('tesseract');
      final gs = await ToolResolver.findExecutable('gs') ??
          await ToolResolver.findExecutable('gswin64c') ??
          await ToolResolver.findExecutable('gswin32c');
      if (tesseract != null && gs != null) {
        final ocrText = await _extractViaOcr(
          sourcePath: sourcePath,
          gs: gs,
          tesseract: tesseract,
        );
        if (ocrText.trim().isNotEmpty) {
          return ocrText.trim();
        }
      }
    } catch (_) {}

    return 'Could not extract text from this PDF.';
  }

  static String _extractTextPureDart(List<int> bytes) {
    final buffer = StringBuffer();
    final latinString = latin1.decode(bytes, allowInvalid: true);
    final streamRegExp = RegExp(r'stream\r?\n');

    for (final match in streamRegExp.allMatches(latinString)) {
      final streamStart = match.end;
      final endIdx = latinString.indexOf('endstream', streamStart);
      if (endIdx == -1) continue;

      final streamBytes = bytes.sublist(streamStart, endIdx);
      List<int>? decompressed;
      try {
        decompressed = ZLibDecoder().decodeBytes(streamBytes);
      } catch (_) {}

      final content = decompressed != null
          ? latin1.decode(decompressed, allowInvalid: true)
          : latin1.decode(streamBytes, allowInvalid: true);

      final extracted = _extractTextFromContentStream(content);
      if (extracted.isNotEmpty) {
        buffer.writeln(extracted);
      }
    }

    return buffer.toString().trim();
  }

  static String _extractTextFromContentStream(String stream) {
    final sb = StringBuffer();
    final btMatches = RegExp(r'BT(.*?)ET', dotAll: true).allMatches(stream);
    for (final bt in btMatches) {
      final block = bt.group(1) ?? '';
      final tjMatches = RegExp(r"\(([^)]*)\)\s*(?:Tj|')").allMatches(block);
      for (final tj in tjMatches) {
        final t = tj.group(1)?.trim();
        if (t != null && t.isNotEmpty) sb.writeln(t);
      }

      final tjArrayMatches = RegExp(r'\[(.*?)\]\s*TJ').allMatches(block);
      for (final arrayMatch in tjArrayMatches) {
        final inner = arrayMatch.group(1) ?? '';
        final strParts = RegExp(r'\(([^)]*)\)')
            .allMatches(inner)
            .map((m) => m.group(1) ?? '')
            .join();
        if (strParts.trim().isNotEmpty) {
          sb.writeln(strParts.trim());
        }
      }
    }
    return sb.toString();
  }

  static Future<String> _extractViaOcr({
    required String sourcePath,
    required String gs,
    required String tesseract,
  }) async {
    final tempDir = await Directory.systemTemp.createTemp('vaivart_ocr_');
    try {
      final pagePattern = p.join(tempDir.path, 'page_%03d.png');
      final gsResult = await Process.run(gs, [
        '-dSAFER',
        '-dBATCH',
        '-dNOPAUSE',
        '-sDEVICE=png16m',
        '-r300',
        '-sOutputFile=$pagePattern',
        sourcePath,
      ]);
      if (gsResult.exitCode != 0) return '';

      final pngFiles = tempDir
          .listSync()
          .whereType<File>()
          .where((f) => f.path.endsWith('.png'))
          .toList()
        ..sort((a, b) => a.path.compareTo(b.path));

      final sb = StringBuffer();
      for (final png in pngFiles) {
        final tessResult = await Process.run(tesseract, [
          png.path,
          'stdout',
        ]);
        if (tessResult.exitCode == 0 && tessResult.stdout is String) {
          sb.writeln(tessResult.stdout as String);
          sb.writeln('\n---\n');
        }
      }
      return sb.toString().trim();
    } catch (_) {
      return '';
    } finally {
      try {
        await tempDir.delete(recursive: true);
      } catch (_) {}
    }
  }

  static Future<String> epubToPdf({
    required String sourcePath,
    required String outputDir,
  }) async {
    final baseName = p.basenameWithoutExtension(sourcePath);
    final outPath = p.join(outputDir, '$baseName.pdf');
    final ebookConvert = await _getEbookConvert();

    final result = await Process.run(ebookConvert, [
      sourcePath,
      outPath,
    ]);

    if (result.exitCode != 0) {
      throw Exception('ebook-convert error: ${result.stderr}');
    }

    return outPath;
  }

  static Future<String> pptxToPdf({
    required String sourcePath,
    required String outputDir,
  }) async {
    final soffice = await _getSoffice();
    final result = await Process.run(soffice, [
      '--headless',
      '--convert-to',
      'pdf',
      '--outdir',
      outputDir,
      sourcePath,
    ]);

    if (result.exitCode != 0) {
      throw Exception('LibreOffice error: ${result.stderr}');
    }

    final baseName = p.basenameWithoutExtension(sourcePath);
    return p.join(outputDir, '$baseName.pdf');
  }

  static Future<String> htmlToPdf({
    required String sourcePath,
    required String outputDir,
  }) async {
    final soffice = await _getSoffice();
    final result = await Process.run(soffice, [
      '--headless',
      '--convert-to',
      'pdf',
      '--outdir',
      outputDir,
      sourcePath,
    ]);

    if (result.exitCode != 0) {
      throw Exception('LibreOffice error: ${result.stderr}');
    }

    final baseName = p.basenameWithoutExtension(sourcePath);
    return p.join(outputDir, '$baseName.pdf');
  }

  /// ──────────── Markdown → PDF ────────────
  static Future<String> mdToPdf({
    required String sourcePath,
    required String outputDir,
  }) async {
    final content = await File(sourcePath).readAsString();
    final lines = content.split('\n');
    final pdf = pw.Document();

    // Collect all widgets, then paginate
    final widgets = <pw.Widget>[];
    bool inCodeBlock = false;
    final codeBuffer = StringBuffer();

    for (final rawLine in lines) {
      // ── fenced code blocks ───
      if (rawLine.trimLeft().startsWith('```')) {
        if (inCodeBlock) {
          // Close block
          widgets.add(
            pw.Container(
              padding: const pw.EdgeInsets.all(8),
              color: PdfColor.fromHex('#F5F5F5'),
              width: double.infinity,
              child: pw.Text(
                codeBuffer.toString().trimRight(),
                style: pw.TextStyle(
                  font: pw.Font.courier(),
                  fontSize: 9,
                ),
              ),
            ),
          );
          widgets.add(pw.SizedBox(height: 6));
          codeBuffer.clear();
          inCodeBlock = false;
        } else {
          inCodeBlock = true;
        }
        continue;
      }
      if (inCodeBlock) {
        codeBuffer.writeln(rawLine);
        continue;
      }

      final line = rawLine.trimRight();

      // ── blank line → spacer ───
      if (line.trim().isEmpty) {
        widgets.add(pw.SizedBox(height: 8));
        continue;
      }

      // ── horizontal rule ───
      if (RegExp(r'^(\*{3,}|-{3,}|_{3,})$').hasMatch(line.trim())) {
        widgets.add(pw.Divider(thickness: 1));
        widgets.add(pw.SizedBox(height: 4));
        continue;
      }

      // ── headings ───
      final headingMatch = RegExp(r'^(#{1,6})\s+(.*)').firstMatch(line);
      if (headingMatch != null) {
        final level = headingMatch.group(1)!.length;
        final text = headingMatch.group(2)!;
        final sizes = {1: 24.0, 2: 20.0, 3: 17.0, 4: 15.0, 5: 13.0, 6: 12.0};
        widgets.add(pw.SizedBox(height: level <= 2 ? 12.0 : 8.0));
        widgets.add(pw.RichText(
          text: pw.TextSpan(
            text: text,
            style: pw.TextStyle(
              fontSize: sizes[level] ?? 12,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
        ));
        if (level <= 2) widgets.add(pw.Divider(thickness: 0.5));
        widgets.add(pw.SizedBox(height: 4));
        continue;
      }

      // ── blockquote ───
      if (line.trimLeft().startsWith('> ')) {
        final quoteText = line.trimLeft().substring(2);
        widgets.add(
          pw.Container(
            padding: const pw.EdgeInsets.only(left: 12, top: 4, bottom: 4),
            decoration: pw.BoxDecoration(
              border: pw.Border(
                  left: pw.BorderSide(width: 3, color: PdfColors.grey400)),
            ),
            child: pw.RichText(
                text: pw.TextSpan(
              children: _parseInlineSpans(
                  quoteText,
                  pw.TextStyle(
                    fontSize: 11,
                    color: PdfColors.grey700,
                    fontStyle: pw.FontStyle.italic,
                  )),
            )),
          ),
        );
        widgets.add(pw.SizedBox(height: 4));
        continue;
      }

      // ── unordered list ───
      final ulMatch = RegExp(r'^(\s*)[-*+]\s+(.*)').firstMatch(line);
      if (ulMatch != null) {
        final indent = (ulMatch.group(1)!.length / 2).clamp(0, 4).toDouble();
        final text = ulMatch.group(2)!;
        widgets.add(pw.Padding(
          padding: pw.EdgeInsets.only(left: 16 + indent * 12),
          child: pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text('•  ', style: const pw.TextStyle(fontSize: 11)),
              pw.Expanded(
                  child: pw.RichText(
                      text: pw.TextSpan(
                children:
                    _parseInlineSpans(text, const pw.TextStyle(fontSize: 11)),
              ))),
            ],
          ),
        ));
        widgets.add(pw.SizedBox(height: 2));
        continue;
      }

      // ── ordered list ───
      final olMatch = RegExp(r'^(\s*)(\d+)\.\s+(.*)').firstMatch(line);
      if (olMatch != null) {
        final indent = (olMatch.group(1)!.length / 2).clamp(0, 4).toDouble();
        final number = olMatch.group(2)!;
        final text = olMatch.group(3)!;
        widgets.add(pw.Padding(
          padding: pw.EdgeInsets.only(left: 16 + indent * 12),
          child: pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text('$number. ', style: const pw.TextStyle(fontSize: 11)),
              pw.Expanded(
                  child: pw.RichText(
                      text: pw.TextSpan(
                children:
                    _parseInlineSpans(text, const pw.TextStyle(fontSize: 11)),
              ))),
            ],
          ),
        ));
        widgets.add(pw.SizedBox(height: 2));
        continue;
      }

      // ── normal paragraph ───
      widgets.add(pw.RichText(
          text: pw.TextSpan(
        children: _parseInlineSpans(line, const pw.TextStyle(fontSize: 11)),
      )));
      widgets.add(pw.SizedBox(height: 4));
    }

    // Flush any unclosed code block
    if (inCodeBlock && codeBuffer.isNotEmpty) {
      widgets.add(
        pw.Container(
          padding: const pw.EdgeInsets.all(8),
          color: PdfColor.fromHex('#F5F5F5'),
          width: double.infinity,
          child: pw.Text(
            codeBuffer.toString().trimRight(),
            style: pw.TextStyle(font: pw.Font.courier(), fontSize: 9),
          ),
        ),
      );
    }

    // Use MultiPage so long docs auto-paginate
    pdf.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(40),
      build: (_) => widgets,
    ));

    final baseName = p.basenameWithoutExtension(sourcePath);
    final outPath = p.join(outputDir, '$baseName.pdf');
    await File(outPath).writeAsBytes(await pdf.save());
    return outPath;
  }

  /// Parse inline Markdown spans: **bold**, *italic*, ***both***, `code`
  static List<pw.InlineSpan> _parseInlineSpans(String text, pw.TextStyle base) {
    final spans = <pw.InlineSpan>[];
    final pattern = RegExp(r'(`[^`]+`)' // inline code
        r'|(\*\*\*[^*]+\*\*\*)' // bold+italic
        r'|(\*\*[^*]+\*\*)' // bold
        r'|(\*[^*]+\*)' // italic
        );

    int cursor = 0;
    for (final match in pattern.allMatches(text)) {
      // Text before this match
      if (match.start > cursor) {
        spans.add(pw.TextSpan(
            text: text.substring(cursor, match.start), style: base));
      }

      final raw = match.group(0)!;
      if (raw.startsWith('`')) {
        // inline code
        spans.add(pw.TextSpan(
          text: raw.substring(1, raw.length - 1),
          style: base.copyWith(
              font: pw.Font.courier(), fontSize: (base.fontSize ?? 11) - 1),
        ));
      } else if (raw.startsWith('***')) {
        spans.add(pw.TextSpan(
          text: raw.substring(3, raw.length - 3),
          style: base.copyWith(
              fontWeight: pw.FontWeight.bold, fontStyle: pw.FontStyle.italic),
        ));
      } else if (raw.startsWith('**')) {
        spans.add(pw.TextSpan(
          text: raw.substring(2, raw.length - 2),
          style: base.copyWith(fontWeight: pw.FontWeight.bold),
        ));
      } else if (raw.startsWith('*')) {
        spans.add(pw.TextSpan(
          text: raw.substring(1, raw.length - 1),
          style: base.copyWith(fontStyle: pw.FontStyle.italic),
        ));
      }
      cursor = match.end;
    }

    // Remaining text
    if (cursor < text.length) {
      spans.add(pw.TextSpan(text: text.substring(cursor), style: base));
    }

    return spans.isEmpty ? [pw.TextSpan(text: text, style: base)] : spans;
  }

  /// Pure Dart HTML → PDF fallback (strips tags, renders as plain text PDF)
  /// Used on Android where LibreOffice is unavailable.
  static Future<String> htmlToPdfDart({
    required String sourcePath,
    required String outputDir,
  }) async {
    final html = await File(sourcePath).readAsString();
    // Strip HTML tags for basic text extraction
    final text = html
        .replaceAll(RegExp(r'<style[^>]*>.*?</style>', dotAll: true), '')
        .replaceAll(RegExp(r'<script[^>]*>.*?</script>', dotAll: true), '')
        .replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n')
        .replaceAll(RegExp(r'<p[^>]*>', caseSensitive: false), '\n')
        .replaceAll(RegExp(r'<[^>]+>'), '')
        .replaceAll(RegExp(r'&nbsp;'), ' ')
        .replaceAll(RegExp(r'&amp;'), '&')
        .replaceAll(RegExp(r'&lt;'), '<')
        .replaceAll(RegExp(r'&gt;'), '>')
        .replaceAll(RegExp(r'\n{3,}'), '\n\n')
        .trim();

    // Reuse txtToPdf logic by writing to a temp file
    final tempTxt = File('${sourcePath}_temp.txt');
    await tempTxt.writeAsString(text);
    final result =
        await txtToPdf(sourcePath: tempTxt.path, outputDir: outputDir);
    await tempTxt.delete();

    // Rename output to match original html filename
    final baseName = p.basenameWithoutExtension(sourcePath);
    final finalPath = p.join(outputDir, '$baseName.pdf');
    await File(result).rename(finalPath);
    return finalPath;
  }

  static Future<String> rtfToPdf({
    required String sourcePath,
    required String outputDir,
  }) async {
    final soffice = await _getSoffice();
    final result = await Process.run(soffice, [
      '--headless',
      '--convert-to',
      'pdf',
      '--outdir',
      outputDir,
      sourcePath,
    ]);

    if (result.exitCode != 0) {
      throw Exception('LibreOffice error: ${result.stderr}');
    }

    final baseName = p.basenameWithoutExtension(sourcePath);
    return p.join(outputDir, '$baseName.pdf');
  }

  static Future<String> odtToPdf({
    required String sourcePath,
    required String outputDir,
  }) async {
    final soffice = await _getSoffice();
    final result = await Process.run(soffice, [
      '--headless',
      '--convert-to',
      'pdf',
      '--outdir',
      outputDir,
      sourcePath,
    ]);

    if (result.exitCode != 0) {
      throw Exception('LibreOffice error: ${result.stderr}');
    }

    final baseName = p.basenameWithoutExtension(sourcePath);
    return p.join(outputDir, '$baseName.pdf');
  }

  static Future<String> odpToPdf({
    required String sourcePath,
    required String outputDir,
  }) async {
    final soffice = await _getSoffice();
    final result = await Process.run(soffice, [
      '--headless',
      '--convert-to',
      'pdf',
      '--outdir',
      outputDir,
      sourcePath,
    ]);

    if (result.exitCode != 0) {
      throw Exception('LibreOffice error: ${result.stderr}');
    }

    final baseName = p.basenameWithoutExtension(sourcePath);
    return p.join(outputDir, '$baseName.pdf');
  }

  static Future<String> jsonToPdf({
    required String sourcePath,
    required String outputDir,
  }) async {
    final raw = await File(sourcePath).readAsString();
    String prettyJson;
    try {
      final decoded = jsonDecode(raw);
      prettyJson = const JsonEncoder.withIndent('  ').convert(decoded);
    } catch (_) {
      prettyJson = raw;
    }

    final tempTxt = File('${sourcePath}_temp.txt');
    await tempTxt.writeAsString(prettyJson);
    final result =
        await txtToPdf(sourcePath: tempTxt.path, outputDir: outputDir);
    await tempTxt.delete();

    final baseName = p.basenameWithoutExtension(sourcePath);
    final finalPath = p.join(outputDir, '$baseName.pdf');
    if (result != finalPath) await File(result).rename(finalPath);
    return finalPath;
  }

  static Future<String> xmlToPdf({
    required String sourcePath,
    required String outputDir,
  }) async {
    return txtToPdf(sourcePath: sourcePath, outputDir: outputDir);
  }

  static Future<String> yamlToPdf({
    required String sourcePath,
    required String outputDir,
  }) async {
    return txtToPdf(sourcePath: sourcePath, outputDir: outputDir);
  }

  static Future<String> logToPdf({
    required String sourcePath,
    required String outputDir,
  }) async {
    return txtToPdf(sourcePath: sourcePath, outputDir: outputDir);
  }
}
