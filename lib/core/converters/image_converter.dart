import 'dart:io';
import 'dart:typed_data';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;

import '../engine/tool_resolver.dart';

class ImageConverter {
  static Future<String> convert({
    required String sourcePath,
    required String targetFormat,
    required String outputDir,
  }) async {
    final tf = targetFormat.toUpperCase();
    if (tf == 'TRES') {
      return imageToTres(sourcePath: sourcePath, outputDir: outputDir);
    } else if (tf == 'RES') {
      return imageToRes(sourcePath: sourcePath, outputDir: outputDir);
    }

    final bytes = await File(sourcePath).readAsBytes();
    final decoded = img.decodeImage(bytes);
    if (decoded == null) throw Exception('Could not decode image');

    final baseName = p.basenameWithoutExtension(sourcePath);
    final outPath = p.join(outputDir, '$baseName.${targetFormat.toLowerCase()}');

    List<int> encoded;
    switch (tf) {
      case 'JPG':
      case 'JPEG':
        encoded = img.encodeJpg(decoded, quality: 95);
      case 'PNG':
        encoded = img.encodePng(decoded);
      case 'WEBP':
        encoded = img.encodeJpg(decoded, quality: 95);
      case 'BMP':
        encoded = img.encodeBmp(decoded);
      case 'TIFF':
      case 'TIF':
        encoded = img.encodeTiff(decoded);
      case 'GIF':
        encoded = img.encodeGif(decoded);
      case 'TGA':
        encoded = img.encodeTga(decoded);
      case 'ICO':
        encoded = img.encodeIco(decoded);
      case 'CUR':
        encoded = img.encodeCur(decoded);
      case 'PVR':
        encoded = img.encodePvr(decoded);
      default:
        throw Exception('Unsupported format: $targetFormat');
    }

    await File(outPath).writeAsBytes(encoded);
    return outPath;
  }

  /// Convert image to Godot Text Resource (.tres)
  static Future<String> imageToTres({
    required String sourcePath,
    required String outputDir,
  }) async {
    final bytes = await File(sourcePath).readAsBytes();
    final decoded = img.decodeImage(bytes);
    if (decoded == null) throw Exception('Could not decode image for TRES conversion');

    final width = decoded.width;
    final height = decoded.height;
    final buffer = StringBuffer();

    final byteList = <int>[];
    for (int y = 0; y < height; y++) {
      for (int x = 0; x < width; x++) {
        final pixel = decoded.getPixel(x, y);
        byteList.add(pixel.r.toInt());
        byteList.add(pixel.g.toInt());
        byteList.add(pixel.b.toInt());
        byteList.add(pixel.a.toInt());
      }
    }

    buffer.writeln('[gd_resource type="Image" format=3]');
    buffer.writeln();
    buffer.writeln('[resource]');
    buffer.writeln('data = {');
    buffer.writeln('"data": PackedByteArray(${byteList.join(', ')}),');
    buffer.writeln('"format": "RGBA8",');
    buffer.writeln('"height": $height,');
    buffer.writeln('"mipmaps": false,');
    buffer.writeln('"width": $width');
    buffer.writeln('}');

    final baseName = p.basenameWithoutExtension(sourcePath);
    final outPath = p.join(outputDir, '$baseName.tres');
    await File(outPath).writeAsString(buffer.toString());
    return outPath;
  }

  /// Convert Godot Text Resource (.tres) to target image format
  static Future<String> tresToImage({
    required String sourcePath,
    required String targetFormat,
    required String outputDir,
  }) async {
    final content = await File(sourcePath).readAsString();

    final widthMatch = RegExp(r'"width":\s*(\d+)').firstMatch(content);
    final heightMatch = RegExp(r'"height":\s*(\d+)').firstMatch(content);
    final bytesMatch = RegExp(r'PackedByteArray\(([^)]*)\)').firstMatch(content);

    if (widthMatch == null || heightMatch == null || bytesMatch == null) {
      throw Exception('Invalid or unsupported .tres image resource format');
    }

    final width = int.parse(widthMatch.group(1)!);
    final height = int.parse(heightMatch.group(1)!);
    final rawBytesStr = bytesMatch.group(1)!;

    final byteValues = rawBytesStr
        .split(',')
        .map((s) => int.tryParse(s.trim()) ?? 0)
        .toList();

    final decoded = img.Image(width: width, height: height, numChannels: 4);
    int offset = 0;
    for (int y = 0; y < height; y++) {
      for (int x = 0; x < width; x++) {
        if (offset + 3 < byteValues.length) {
          final r = byteValues[offset++];
          final g = byteValues[offset++];
          final b = byteValues[offset++];
          final a = byteValues[offset++];
          decoded.setPixelRgba(x, y, r, g, b, a);
        }
      }
    }

    final baseName = p.basenameWithoutExtension(sourcePath);
    final outPath = p.join(outputDir, '$baseName.${targetFormat.toLowerCase()}');

    List<int> encoded;
    switch (targetFormat.toUpperCase()) {
      case 'JPG':
      case 'JPEG':
        encoded = img.encodeJpg(decoded, quality: 95);
      case 'PNG':
      default:
        encoded = img.encodePng(decoded);
    }

    await File(outPath).writeAsBytes(encoded);
    return outPath;
  }

  /// Convert image to Binary Resource (.res)
  static Future<String> imageToRes({
    required String sourcePath,
    required String outputDir,
  }) async {
    final bytes = await File(sourcePath).readAsBytes();
    final decoded = img.decodeImage(bytes);
    if (decoded == null) throw Exception('Could not decode image for RES conversion');

    final width = decoded.width;
    final height = decoded.height;

    final header = BytesBuilder();
    // Magic: RES1
    header.add([0x52, 0x45, 0x53, 0x31]);
    // Width (32-bit BE)
    header.add([(width >> 24) & 0xFF, (width >> 16) & 0xFF, (width >> 8) & 0xFF, width & 0xFF]);
    // Height (32-bit BE)
    header.add([(height >> 24) & 0xFF, (height >> 16) & 0xFF, (height >> 8) & 0xFF, height & 0xFF]);
    // Format (4 = RGBA8)
    header.add([0, 0, 0, 4]);

    for (int y = 0; y < height; y++) {
      for (int x = 0; x < width; x++) {
        final pixel = decoded.getPixel(x, y);
        header.addByte(pixel.r.toInt());
        header.addByte(pixel.g.toInt());
        header.addByte(pixel.b.toInt());
        header.addByte(pixel.a.toInt());
      }
    }

    final baseName = p.basenameWithoutExtension(sourcePath);
    final outPath = p.join(outputDir, '$baseName.res');
    await File(outPath).writeAsBytes(header.toBytes());
    return outPath;
  }

  /// Convert Binary Resource (.res) to target image format
  static Future<String> resToImage({
    required String sourcePath,
    required String targetFormat,
    required String outputDir,
  }) async {
    final bytes = await File(sourcePath).readAsBytes();
    if (bytes.length < 16) {
      throw Exception('Invalid .res image file: file too short');
    }

    int width, height;
    int dataOffset = 16;

    if (bytes[0] == 0x52 && bytes[1] == 0x45 && bytes[2] == 0x53 && bytes[3] == 0x31) {
      width = (bytes[4] << 24) | (bytes[5] << 16) | (bytes[6] << 8) | bytes[7];
      height = (bytes[8] << 24) | (bytes[9] << 16) | (bytes[10] << 8) | bytes[11];
    } else {
      final decodedAlt = img.decodeImage(bytes);
      if (decodedAlt != null) {
        return convert(sourcePath: sourcePath, targetFormat: targetFormat, outputDir: outputDir);
      }
      throw Exception('Unrecognized .res image format');
    }

    final decoded = img.Image(width: width, height: height, numChannels: 4);
    int offset = dataOffset;
    for (int y = 0; y < height; y++) {
      for (int x = 0; x < width; x++) {
        if (offset + 3 < bytes.length) {
          final r = bytes[offset++];
          final g = bytes[offset++];
          final b = bytes[offset++];
          final a = bytes[offset++];
          decoded.setPixelRgba(x, y, r, g, b, a);
        }
      }
    }

    final baseName = p.basenameWithoutExtension(sourcePath);
    final outPath = p.join(outputDir, '$baseName.${targetFormat.toLowerCase()}');

    List<int> encoded;
    switch (targetFormat.toUpperCase()) {
      case 'JPG':
      case 'JPEG':
        encoded = img.encodeJpg(decoded, quality: 95);
      case 'PNG':
      default:
        encoded = img.encodePng(decoded);
    }

    await File(outPath).writeAsBytes(encoded);
    return outPath;
  }

  static Future<String> heicToImage({
    required String sourcePath,
    required String targetFormat,
    required String outputDir,
  }) async {
    final baseName = p.basenameWithoutExtension(sourcePath);
    final outPath = p.join(outputDir, '$baseName.${targetFormat.toLowerCase()}');
    final binPath = await ToolResolver.findExecutable('heif-convert');
    if (binPath == null) {
      throw Exception('heif-convert not found. Please install libheif tools or convert on Powerful mode.');
    }

    final result = await Process.run(binPath, [
      sourcePath,
      outPath,
    ]);

    if (result.exitCode != 0) {
      throw Exception('heif-convert error: ${result.stderr}');
    }

    return outPath;
  }

  static Future<String> svgToImage({
    required String sourcePath,
    required String targetFormat,
    required String outputDir,
  }) async {
    final baseName = p.basenameWithoutExtension(sourcePath);
    final outPath = p.join(outputDir, '$baseName.${targetFormat.toLowerCase()}');
    final binPath = await ToolResolver.findExecutable('rsvg-convert');
    if (binPath == null) {
      throw Exception('rsvg-convert not found. Please install librsvg or check your PATH.');
    }

    final result = await Process.run(binPath, [
      '-f', targetFormat.toLowerCase(),
      '-o', outPath,
      sourcePath,
    ]);

    if (result.exitCode != 0) {
      throw Exception('rsvg-convert error: ${result.stderr}');
    }

    return outPath;
  }
}
