import 'dart:io';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path/path.dart' as p;
import '../engine/tool_resolver.dart';

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

  static Future<String> pdfToImage({
    required String sourcePath,
    required String targetFormat,
    required String outputDir,
  }) async {
    final baseName = p.basenameWithoutExtension(sourcePath);
    final tf = targetFormat.toLowerCase();
    
    String device;
    if (tf == 'jpg' || tf == 'jpeg') device = 'jpeg';
    else if (tf == 'png') device = 'png16m';
    else if (tf == 'bmp') device = 'bmp16m';
    else if (tf == 'tiff' || tf == 'tif') device = 'tiff24nc';
    else throw Exception('Unsupported PDF to Image target: $targetFormat');

    final outPath = p.join(outputDir, '$baseName.$tf');
    final gs = await ToolResolver.findExecutable('gs') ?? 
               await ToolResolver.findExecutable('gswin64c') ?? 
               await ToolResolver.findExecutable('gswin32c');
    
    if (gs == null) {
      throw Exception('Ghostscript (gs) is required for PDF to Image conversion.');
    }

    final result = await Process.run(gs, [
      '-dSAFER',
      '-dBATCH',
      '-dNOPAUSE',
      '-sDEVICE=$device',
      '-r300',
      '-dFirstPage=1',
      '-dLastPage=1',
      '-sOutputFile=$outPath',
      sourcePath,
    ]);

    if (result.exitCode != 0) {
      throw Exception('Ghostscript error: ${result.stderr}');
    }

    return outPath;
  }
}
