import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;

import '../engine/tool_resolver.dart';

Map<String, dynamic> _convertIsolate(Map<String, dynamic> args) {
  final sourcePath = args['sourcePath'] as String;
  final targetFormat = args['targetFormat'] as String;
  final resolution = args['resolution'] as String?;
  final outPath = args['outPath'] as String;

  final bytes = File(sourcePath).readAsBytesSync();
  var decoded = img.decodeImage(bytes);
  if (decoded == null) throw Exception('Could not decode image');

  if (resolution != null && resolution.toLowerCase() != 'original') {
    if (resolution.contains('x')) {
      final parts = resolution.split('x');
      final w = int.tryParse(parts[0]);
      final h = int.tryParse(parts[1]);
      if (w != null && h != null) {
        decoded = img.copyResize(decoded, width: w, height: h);
      }
    }
  }

  List<int> encoded;
  switch (targetFormat.toUpperCase()) {
    case 'JPG':
    case 'JPEG':
      encoded = img.encodeJpg(decoded, quality: 95);
      break;
    case 'PNG':
      encoded = img.encodePng(decoded);
      break;
    case 'WEBP':
      encoded = img.encodeJpg(decoded, quality: 95);
      break;
    case 'BMP':
      encoded = img.encodeBmp(decoded);
      break;
    case 'TIFF':
    case 'TIF':
      encoded = img.encodeTiff(decoded);
      break;
    case 'GIF':
      encoded = img.encodeGif(decoded);
      break;
    case 'TGA':
      encoded = img.encodeTga(decoded);
      break;
    case 'ICO':
      encoded = img.encodeIco(decoded);
      break;
    case 'CUR':
      encoded = img.encodeCur(decoded);
      break;
    case 'PVR':
      encoded = img.encodePvr(decoded);
      break;
    default:
      throw Exception('Unsupported format: $targetFormat');
  }

  File(outPath).writeAsBytesSync(encoded);
  return {'outPath': outPath};
}

Map<String, dynamic> _imageToTresIsolate(Map<String, dynamic> args) {
  final sourcePath = args['sourcePath'] as String;
  final outPath = args['outPath'] as String;

  final bytes = File(sourcePath).readAsBytesSync();
  final decoded = img.decodeImage(bytes);
  if (decoded == null)
    throw Exception('Could not decode image for TRES conversion');

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

  File(outPath).writeAsStringSync(buffer.toString());
  return {'outPath': outPath};
}

Map<String, dynamic> _tresToImageIsolate(Map<String, dynamic> args) {
  final sourcePath = args['sourcePath'] as String;
  final targetFormat = args['targetFormat'] as String;
  final outPath = args['outPath'] as String;

  final content = File(sourcePath).readAsStringSync();
  final widthMatch = RegExp(r'"width":\s*(\d+)').firstMatch(content);
  final heightMatch = RegExp(r'"height":\s*(\d+)').firstMatch(content);
  final bytesMatch = RegExp(r'PackedByteArray\(([^)]*)\)').firstMatch(content);

  if (widthMatch == null || heightMatch == null || bytesMatch == null) {
    throw Exception('Invalid or unsupported .tres image resource format');
  }

  final width = int.parse(widthMatch.group(1)!);
  final height = int.parse(heightMatch.group(1)!);
  final rawBytesStr = bytesMatch.group(1)!;

  final byteValues =
      rawBytesStr.split(',').map((s) => int.tryParse(s.trim()) ?? 0).toList();
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

  List<int> encoded;
  switch (targetFormat.toUpperCase()) {
    case 'JPG':
    case 'JPEG':
      encoded = img.encodeJpg(decoded, quality: 95);
      break;
    case 'PNG':
    default:
      encoded = img.encodePng(decoded);
      break;
  }

  File(outPath).writeAsBytesSync(encoded);
  return {'outPath': outPath};
}

Map<String, dynamic> _imageToResIsolate(Map<String, dynamic> args) {
  final sourcePath = args['sourcePath'] as String;
  final outPath = args['outPath'] as String;

  final bytes = File(sourcePath).readAsBytesSync();
  final decoded = img.decodeImage(bytes);
  if (decoded == null)
    throw Exception('Could not decode image for RES conversion');

  final width = decoded.width;
  final height = decoded.height;
  final header = BytesBuilder();

  header.add([0x52, 0x45, 0x53, 0x31]);
  header.add([
    (width >> 24) & 0xFF,
    (width >> 16) & 0xFF,
    (width >> 8) & 0xFF,
    width & 0xFF
  ]);
  header.add([
    (height >> 24) & 0xFF,
    (height >> 16) & 0xFF,
    (height >> 8) & 0xFF,
    height & 0xFF
  ]);
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

  File(outPath).writeAsBytesSync(header.toBytes());
  return {'outPath': outPath};
}

Map<String, dynamic> _resToImageIsolate(Map<String, dynamic> args) {
  final sourcePath = args['sourcePath'] as String;
  final targetFormat = args['targetFormat'] as String;
  final outPath = args['outPath'] as String;

  final bytes = File(sourcePath).readAsBytesSync();
  if (bytes.length < 16)
    throw Exception('Invalid .res image file: file too short');

  int width, height;
  int dataOffset = 16;
  img.Image? decoded;

  if (bytes[0] == 0x52 &&
      bytes[1] == 0x45 &&
      bytes[2] == 0x53 &&
      bytes[3] == 0x31) {
    width = (bytes[4] << 24) | (bytes[5] << 16) | (bytes[6] << 8) | bytes[7];
    height = (bytes[8] << 24) | (bytes[9] << 16) | (bytes[10] << 8) | bytes[11];
    decoded = img.Image(width: width, height: height, numChannels: 4);
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
  } else {
    decoded = img.decodeImage(bytes);
    if (decoded == null) throw Exception('Unrecognized .res image format');
  }

  List<int> encoded;
  switch (targetFormat.toUpperCase()) {
    case 'JPG':
    case 'JPEG':
      encoded = img.encodeJpg(decoded, quality: 95);
      break;
    case 'PNG':
    default:
      encoded = img.encodePng(decoded);
      break;
  }

  File(outPath).writeAsBytesSync(encoded);
  return {'outPath': outPath};
}

/// Handles image conversions utilizing background isolates for compute and memory optimization.
class ImageConverter {
  static Future<String> convert({
    required String sourcePath,
    required String targetFormat,
    required String outputDir,
    String? resolution,
  }) async {
    final tf = targetFormat.toUpperCase();
    if (tf == 'TRES') {
      return imageToTres(sourcePath: sourcePath, outputDir: outputDir);
    } else if (tf == 'RES') {
      return imageToRes(sourcePath: sourcePath, outputDir: outputDir);
    }

    final baseName = p.basenameWithoutExtension(sourcePath);
    final outPath =
        p.join(outputDir, '$baseName.${targetFormat.toLowerCase()}');

    await compute(_convertIsolate, {
      'sourcePath': sourcePath,
      'targetFormat': targetFormat,
      'resolution': resolution,
      'outPath': outPath,
    });

    return outPath;
  }

  static Future<String> imageToTres({
    required String sourcePath,
    required String outputDir,
  }) async {
    final baseName = p.basenameWithoutExtension(sourcePath);
    final outPath = p.join(outputDir, '$baseName.tres');
    await compute(
        _imageToTresIsolate, {'sourcePath': sourcePath, 'outPath': outPath});
    return outPath;
  }

  static Future<String> tresToImage({
    required String sourcePath,
    required String targetFormat,
    required String outputDir,
  }) async {
    final baseName = p.basenameWithoutExtension(sourcePath);
    final outPath =
        p.join(outputDir, '$baseName.${targetFormat.toLowerCase()}');
    await compute(_tresToImageIsolate, {
      'sourcePath': sourcePath,
      'targetFormat': targetFormat,
      'outPath': outPath,
    });
    return outPath;
  }

  static Future<String> imageToRes({
    required String sourcePath,
    required String outputDir,
  }) async {
    final baseName = p.basenameWithoutExtension(sourcePath);
    final outPath = p.join(outputDir, '$baseName.res');
    await compute(
        _imageToResIsolate, {'sourcePath': sourcePath, 'outPath': outPath});
    return outPath;
  }

  static Future<String> resToImage({
    required String sourcePath,
    required String targetFormat,
    required String outputDir,
  }) async {
    final baseName = p.basenameWithoutExtension(sourcePath);
    final outPath =
        p.join(outputDir, '$baseName.${targetFormat.toLowerCase()}');
    await compute(_resToImageIsolate, {
      'sourcePath': sourcePath,
      'targetFormat': targetFormat,
      'outPath': outPath,
    });
    return outPath;
  }

  static Future<String> heicToImage({
    required String sourcePath,
    required String targetFormat,
    required String outputDir,
  }) async {
    final baseName = p.basenameWithoutExtension(sourcePath);
    final outPath =
        p.join(outputDir, '$baseName.${targetFormat.toLowerCase()}');
    final binPath = await ToolResolver.findExecutable('heif-convert');
    if (binPath == null) {
      throw Exception('heif-convert not found. Please install libheif tools.');
    }
    final result = await Process.run(binPath, [sourcePath, outPath]);
    if (result.exitCode != 0)
      throw Exception('heif-convert error: ${result.stderr}');
    return outPath;
  }

  static Future<String> svgToImage({
    required String sourcePath,
    required String targetFormat,
    required String outputDir,
  }) async {
    final baseName = p.basenameWithoutExtension(sourcePath);
    final outPath =
        p.join(outputDir, '$baseName.${targetFormat.toLowerCase()}');
    final binPath = await ToolResolver.findExecutable('rsvg-convert');
    if (binPath == null) {
      throw Exception('rsvg-convert not found. Please install librsvg.');
    }
    final result = await Process.run(
        binPath, ['-f', targetFormat.toLowerCase(), '-o', outPath, sourcePath]);
    if (result.exitCode != 0)
      throw Exception('rsvg-convert error: ${result.stderr}');
    return outPath;
  }
}
