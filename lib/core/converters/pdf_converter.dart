import 'dart:io';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path/path.dart' as p;

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
}