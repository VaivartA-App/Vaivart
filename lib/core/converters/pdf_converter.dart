import 'dart:io';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path/path.dart' as p;

import '../engine/tool_resolver.dart';
import 'image_converter.dart';

/// Performs PDF document generation from image sequences and document rendering.
class PdfConverter {
  static Future<String> imageToPdf({
    required List<String> imagePaths,
    required String outputDir,
    required String baseName,
  }) async {
    final pdf = pw.Document();

    for (final imgPath in imagePaths) {
      final bytes = await File(imgPath).readAsBytes();
      final image = pw.MemoryImage(bytes);
      pdf.addPage(pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (_) => pw.Center(child: pw.Image(image, fit: pw.BoxFit.contain)),
      ));
    }

    final outPath = p.join(outputDir, '$baseName.pdf');
    await File(outPath).writeAsBytes(await pdf.save());
    return outPath;
  }

  /// Convert PDF pages to image (PNG, JPG, WEBP, BMP, etc.)
  static Future<String> pdfToImage({
    required String sourcePath,
    required String targetFormat,
    required String outputDir,
  }) async {
    final baseName = p.basenameWithoutExtension(sourcePath);
    final fmt = targetFormat.toLowerCase();
    final outPath = p.join(outputDir, '$baseName.$fmt');

    // 1. Try pdftoppm (poppler utility — fast & accurate)
    final pdftoppmPath = await ToolResolver.findExecutable('pdftoppm');
    if (pdftoppmPath != null) {
      final outPrefix = p.join(outputDir, baseName);
      final flag = (fmt == 'jpg' || fmt == 'jpeg') ? '-jpeg' : '-png';
      final result = await Process.run(pdftoppmPath, [
        flag,
        '-r',
        '150',
        '-singlefile',
        sourcePath,
        outPrefix,
      ]);
      if (result.exitCode == 0) {
        final generatedPath = (fmt == 'jpg' || fmt == 'jpeg')
            ? '$outPrefix.jpg'
            : '$outPrefix.png';
        if (await File(generatedPath).exists()) {
          if (fmt == 'png' || fmt == 'jpg' || fmt == 'jpeg') {
            if (generatedPath != outPath) {
              await File(generatedPath).rename(outPath);
            }
            return outPath;
          } else {
            // For WEBP, BMP, etc., convert generated PNG -> targetFormat via ImageConverter
            final finalPath = await ImageConverter.convert(
              sourcePath: generatedPath,
              targetFormat: targetFormat,
              outputDir: outputDir,
            );
            if (await File(generatedPath).exists()) {
              await File(generatedPath).delete();
            }
            return finalPath;
          }
        }
      }
    }

    // 2. Fallback to LibreOffice (soffice)
    final sofficePath = await ToolResolver.findExecutable('soffice');
    if (sofficePath != null) {
      final result = await Process.run(sofficePath, [
        '--headless',
        '--convert-to',
        'png',
        '--outdir',
        outputDir,
        sourcePath,
      ]);
      if (result.exitCode == 0) {
        final generatedPng = p.join(outputDir, '$baseName.png');
        if (await File(generatedPng).exists()) {
          if (fmt == 'png') return generatedPng;
          final finalPath = await ImageConverter.convert(
            sourcePath: generatedPng,
            targetFormat: targetFormat,
            outputDir: outputDir,
          );
          await File(generatedPng).delete();
          return finalPath;
        }
      }
    }

    throw Exception(
      'PDF image conversion requires pdftoppm (poppler-utils) or LibreOffice.\n'
      'Please install poppler-utils (pdftoppm) or LibreOffice.',
    );
  }

  /// Convert PDF to plain text (.txt)
  static Future<String> pdfToTxt({
    required String sourcePath,
    required String outputDir,
  }) async {
    final baseName = p.basenameWithoutExtension(sourcePath);
    final outPath = p.join(outputDir, '$baseName.txt');

    // 1. Try pdftotext (poppler utility)
    final pdftotextPath = await ToolResolver.findExecutable('pdftotext');
    if (pdftotextPath != null) {
      final result = await Process.run(pdftotextPath, [sourcePath, outPath]);
      if (result.exitCode == 0 && await File(outPath).exists()) {
        final content = await File(outPath).readAsString();
        if (content.trim().isNotEmpty) return outPath;
      }
    }

    // 2. Pure Dart fallback for text extraction from PDF
    try {
      final bytes = await File(sourcePath).readAsBytes();
      final raw = String.fromCharCodes(bytes);
      final matches = RegExp(r'BT(.*?)ET', dotAll: true)
          .allMatches(raw)
          .map((m) => m.group(1) ?? '')
          .join('\n');
      final cleaned = matches
          .replaceAll(RegExp(r'\(([^)]*)\)\s*Tj'), r'$1')
          .replaceAll(RegExp(r'[^\x20-\x7E\n]'), '')
          .trim();
      final text = cleaned.isEmpty ? 'Could not extract text from this PDF.' : cleaned;
      await File(outPath).writeAsString(text);
      return outPath;
    } catch (e) {
      if (await File(outPath).exists()) return outPath;
      throw Exception('Failed to extract text from PDF: $e');
    }
  }
}