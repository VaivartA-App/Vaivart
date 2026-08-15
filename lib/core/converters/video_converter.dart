import 'dart:io';
import 'package:path/path.dart' as p;
import 'ffmpeg_kit_helper.dart';

import '../engine/tool_resolver.dart';

/// Handles video format conversions, resolution scaling, GIF generation, and audio stream extraction.
class VideoConverter {
  static Future<String> convert({
    required String sourcePath,
    required String targetFormat,
    required String outputDir,
    String? resolution,
  }) async {
    final baseName = p.basenameWithoutExtension(sourcePath);
    final outPath = p.join(outputDir, '$baseName.${targetFormat.toLowerCase()}');
    final args = _buildArgs(
      sourcePath: sourcePath,
      outPath: outPath,
      targetFormat: targetFormat.toUpperCase(),
      resolution: resolution,
    );

    if (Platform.isAndroid) {
      // Use ffmpeg_kit on Android
      final cmd = args.join(' ');
      final session = await FFmpegKit.execute(cmd);
      final rc = await session.getReturnCode();
      if (!ReturnCode.isSuccess(rc)) {
        final logs = await session.getLogsAsString();
        throw Exception('ffmpeg error: $logs');
      }
    } else {
      // Desktop: ffmpeg resolved dynamically
      final ffmpegPath = await ToolResolver.findExecutable('ffmpeg');
      if (ffmpegPath == null) {
        throw Exception('ffmpeg not found. Please install ffmpeg or check Settings.');
      }
      final result = await Process.run(ffmpegPath, args);
      if (result.exitCode != 0) {
        throw Exception('ffmpeg error: ${result.stderr}');
      }
    }

    return outPath;
  }

  static String? _getScaleFilter(String? resolution) {
    if (resolution == null || resolution.toLowerCase() == 'original') {
      return null;
    }
    switch (resolution.toLowerCase()) {
      case '4k':
      case '2160p':
        return 'scale=3840:-2';
      case '1080p':
        return 'scale=1920:-2';
      case '720p':
        return 'scale=1280:-2';
      case '480p':
        return 'scale=854:-2';
      case '360p':
        return 'scale=640:-2';
      case '240p':
        return 'scale=426:-2';
      default:
        if (resolution.contains('x')) {
          final parts = resolution.split('x');
          if (parts.length == 2) {
            final w = int.tryParse(parts[0]);
            final h = int.tryParse(parts[1]);
            if (w != null && h != null) {
              return 'scale=$w:$h';
            }
          }
        }
        return null;
    }
  }

  static List<String> _buildArgs({
    required String sourcePath,
    required String outPath,
    required String targetFormat,
    String? resolution,
  }) {
    final scaleFilter = _getScaleFilter(resolution);
    final base = ['-i', sourcePath, '-y'];

    if (scaleFilter != null && targetFormat != 'GIF' && targetFormat != '3GP') {
      base.addAll(['-vf', scaleFilter]);
    }

    switch (targetFormat) {
      case 'MP4':
        return [...base, '-c:v', 'libx264', '-c:a', 'aac', outPath];
      case 'AVI':
        return [...base, '-c:v', 'libxvid', '-c:a', 'mp3', outPath];
      case 'MKV':
        return [...base, '-c:v', 'libx264', '-c:a', 'aac', outPath];
      case 'GIF':
        final width = switch (resolution?.toLowerCase()) {
          '1080p' => '1080',
          '720p' => '720',
          '360p' => '360',
          '240p' => '240',
          _ => '480',
        };
        return [
          '-i',
          sourcePath,
          '-y',
          '-vf',
          'fps=10,scale=$width:-1:flags=lanczos,split[s0][s1];[s0]palettegen[p];[s1][p]paletteuse',
          '-loop',
          '0',
          outPath,
        ];
      case 'WEBM':
        return [...base, '-c:v', 'libvpx-vp9', '-c:a', 'libopus', '-b:v', '2M', outPath];
      case 'MOV':
        return [...base, '-c:v', 'libx264', '-c:a', 'aac', outPath];
      case 'FLV':
        return [...base, '-c:v', 'libx264', '-c:a', 'aac', '-f', 'flv', outPath];
      case 'WMV':
        return [...base, '-c:v', 'wmv2', '-c:a', 'wmav2', outPath];
      case '3GP':
        final size = switch (resolution?.toLowerCase()) {
          '240p' => '176x144',
          _ => '352x288',
        };
        return [...base, '-c:v', 'h263', '-c:a', 'aac', '-s', size, outPath];
      case 'VOB':
        return [...base, '-c:v', 'mpeg2video', '-c:a', 'mp2', '-f', 'vob', outPath];
      case 'MTS':
      case 'M2TS':
        return [...base, '-c:v', 'libx264', '-c:a', 'aac', '-f', 'mpegts', outPath];
      case 'TS':
        return [...base, '-c:v', 'libx264', '-c:a', 'aac', '-f', 'mpegts', outPath];
      case 'ASF':
        return [...base, '-c:v', 'wmv2', '-c:a', 'wmav2', '-f', 'asf', outPath];
      default:
        return [...base, outPath];
    }
  }

  static Future<String> extractAudio({
    required String sourcePath,
    required String targetFormat,
    required String outputDir,
  }) async {
    final baseName = p.basenameWithoutExtension(sourcePath);
    final outPath = p.join(outputDir, '$baseName.${targetFormat.toLowerCase()}');
    final args = ['-i', sourcePath, '-y', '-vn', '-codec:a', 'copy', outPath];

    if (Platform.isAndroid) {
      final cmd = args.join(' ');
      final session = await FFmpegKit.execute(cmd);
      final rc = await session.getReturnCode();
      if (!ReturnCode.isSuccess(rc)) {
        final logs = await session.getLogsAsString();
        throw Exception('ffmpeg extract audio error: $logs');
      }
    } else {
      final ffmpegPath = await ToolResolver.findExecutable('ffmpeg');
      if (ffmpegPath == null) {
        throw Exception('ffmpeg not found. Please install ffmpeg or check Settings.');
      }
      final result = await Process.run(ffmpegPath, args);
      if (result.exitCode != 0) {
        throw Exception('ffmpeg extract audio error: ${result.stderr}');
      }
    }

    return outPath;
  }
}
