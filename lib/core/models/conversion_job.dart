import 'package:path/path.dart' as p;

enum JobStatus { waiting, converting, done, failed }

/// Represents a single file conversion job and its available target formats.
class ConversionJob {
  final String sourcePath;
  final String fileName;
  final String extension;
  final String fileSize;
  final String? targetFormat;
  final String? videoResolution;
  final JobStatus status;

  static const List<String> videoResolutions = [
    'Original',
    '1080p',
    '720p',
    '480p',
    '360p',
    '240p',
  ];

  const ConversionJob({
    required this.sourcePath,
    required this.fileName,
    required this.extension,
    required this.fileSize,
    this.targetFormat,
    this.videoResolution,
    this.status = JobStatus.waiting,
  });

  bool get isVideo {
    final ext = extension.toLowerCase();
    return const {
      'mp4', 'avi', 'mkv', 'mov', 'webm', 'flv', 'wmv', '3gp', 'vob', 'mts', 'm2ts', 'ts', 'divx', 'asf'
    }.contains(ext);
  }

  factory ConversionJob.fromFile(String path) {
    final name = p.basename(path);
    final ext = p.extension(path).replaceAll('.', '').toUpperCase();
    final job = ConversionJob(
      sourcePath: path,
      fileName: name,
      extension: ext,
      fileSize: '',
    );
    return job.copyWith(targetFormat: job.availableFormats.isNotEmpty ? job.availableFormats.first : null);
  }

  ConversionJob copyWith({
    String? targetFormat,
    String? videoResolution,
    JobStatus? status,
  }) {
    return ConversionJob(
      sourcePath: sourcePath,
      fileName: fileName,
      extension: extension,
      fileSize: fileSize,
      targetFormat: targetFormat ?? this.targetFormat,
      videoResolution: videoResolution ?? this.videoResolution,
      status: status ?? this.status,
    );
  }

List<String> get availableFormats {
  switch (extension.toLowerCase()) {
    // ── Images ──
    case 'jpg':
    case 'jpeg': return ['PNG', 'WEBP', 'BMP', 'TIFF', 'GIF', 'TGA', 'ICO', 'RES', 'TRES', 'PDF'];
    case 'png': return ['JPG', 'WEBP', 'BMP', 'TIFF', 'GIF', 'TGA', 'ICO', 'RES', 'TRES', 'PDF'];
    case 'webp': return ['JPG', 'PNG', 'BMP', 'TIFF', 'TGA', 'RES', 'TRES', 'PDF'];
    case 'bmp': return ['JPG', 'PNG', 'WEBP', 'TIFF', 'TGA', 'RES', 'TRES', 'PDF'];
    case 'tiff':
    case 'tif': return ['JPG', 'PNG', 'WEBP', 'BMP', 'TGA', 'RES', 'TRES', 'PDF'];
    case 'gif': return ['JPG', 'PNG', 'WEBP', 'BMP', 'TIFF', 'TGA', 'RES', 'TRES'];
    case 'ico': return ['PNG', 'JPG', 'BMP', 'TGA', 'RES', 'TRES'];
    case 'heic': return ['JPG', 'PNG', 'WEBP', 'BMP', 'RES', 'TRES'];
    case 'svg': return ['PNG', 'JPG', 'RES', 'TRES', 'PDF'];
    case 'tga': return ['PNG', 'JPG', 'BMP', 'TIFF', 'WEBP', 'RES', 'TRES'];
    case 'psd': return ['PNG', 'JPG', 'BMP', 'TIFF', 'WEBP', 'TGA', 'RES', 'TRES'];
    case 'pnm':
    case 'pbm':
    case 'pgm':
    case 'ppm': return ['PNG', 'JPG', 'BMP', 'TIFF', 'WEBP', 'TGA', 'RES', 'TRES'];
    case 'exr': return ['PNG', 'JPG', 'BMP', 'TIFF', 'WEBP', 'TGA', 'RES', 'TRES'];
    case 'pvr': return ['PNG', 'JPG', 'BMP', 'TIFF', 'RES', 'TRES'];
    case 'cur': return ['PNG', 'JPG', 'BMP', 'RES', 'TRES'];
    case 'res': return ['PNG', 'JPG', 'WEBP', 'BMP', 'TIFF', 'TGA'];
    case 'tres': return ['PNG', 'JPG', 'WEBP', 'BMP', 'TIFF', 'TGA'];

    // ── Video ──
    case 'mp4': return ['AVI', 'MKV', 'WEBM', 'MOV', 'FLV', 'WMV', '3GP', 'VOB', 'TS', 'GIF', 'MP3'];
    case 'avi': return ['MP4', 'MKV', 'WEBM', 'MOV', 'FLV', 'WMV', '3GP', 'VOB', 'TS', 'GIF', 'MP3'];
    case 'mkv': return ['MP4', 'AVI', 'WEBM', 'MOV', 'FLV', 'WMV', '3GP', 'VOB', 'TS', 'GIF', 'MP3'];
    case 'mov': return ['MP4', 'AVI', 'MKV', 'WEBM', 'FLV', 'WMV', '3GP', 'VOB', 'TS', 'GIF', 'MP3'];
    case 'webm': return ['MP4', 'AVI', 'MKV', 'MOV', 'FLV', 'WMV', '3GP', 'VOB', 'TS', 'GIF', 'MP3'];
    case 'flv': return ['MP4', 'AVI', 'MKV', 'WEBM', 'MOV', 'WMV', '3GP', 'VOB', 'TS', 'GIF', 'MP3'];
    case 'wmv': return ['MP4', 'AVI', 'MKV', 'WEBM', 'MOV', 'FLV', '3GP', 'VOB', 'TS', 'GIF', 'MP3'];
    case '3gp': return ['MP4', 'AVI', 'MKV', 'WEBM', 'MOV', 'FLV', 'WMV', 'VOB', 'TS', 'GIF', 'MP3'];
    case 'vob': return ['MP4', 'AVI', 'MKV', 'WEBM', 'MOV', 'FLV', 'WMV', '3GP', 'TS', 'GIF', 'MP3'];
    case 'mts':
    case 'm2ts': return ['MP4', 'AVI', 'MKV', 'WEBM', 'MOV', 'FLV', 'WMV', 'GIF', 'MP3'];
    case 'ts': return ['MP4', 'AVI', 'MKV', 'WEBM', 'MOV', 'FLV', 'WMV', 'GIF', 'MP3'];
    case 'divx': return ['MP4', 'AVI', 'MKV', 'WEBM', 'MOV', 'FLV', 'WMV', 'GIF', 'MP3'];
    case 'asf': return ['MP4', 'AVI', 'MKV', 'WEBM', 'MOV', 'FLV', 'WMV', 'GIF', 'MP3'];

    // ── Audio ──
    case 'mp3': return ['WAV', 'OGG', 'FLAC', 'AAC', 'M4A', 'WMA', 'AIFF', 'OPUS', 'AC3', 'AU'];
    case 'wav': return ['MP3', 'OGG', 'FLAC', 'AAC', 'M4A', 'WMA', 'AIFF', 'OPUS', 'AC3', 'AU'];
    case 'ogg': return ['MP3', 'WAV', 'FLAC', 'AAC', 'M4A', 'WMA', 'AIFF', 'OPUS', 'AC3', 'AU'];
    case 'flac': return ['MP3', 'WAV', 'OGG', 'AAC', 'M4A', 'WMA', 'AIFF', 'OPUS', 'AC3', 'AU'];
    case 'aac': return ['MP3', 'WAV', 'OGG', 'FLAC', 'M4A', 'WMA', 'AIFF', 'OPUS', 'AC3', 'AU'];
    case 'm4a': return ['MP3', 'WAV', 'OGG', 'FLAC', 'AAC', 'WMA', 'AIFF', 'OPUS', 'AC3', 'AU'];
    case 'wma': return ['MP3', 'WAV', 'OGG', 'FLAC', 'AAC', 'M4A', 'AIFF', 'OPUS', 'AC3', 'AU'];
    case 'aiff': return ['MP3', 'WAV', 'OGG', 'FLAC', 'AAC', 'M4A', 'WMA', 'OPUS', 'AC3', 'AU'];
    case 'opus': return ['MP3', 'WAV', 'OGG', 'FLAC', 'AAC', 'M4A', 'WMA', 'AIFF', 'AC3', 'AU'];
    case 'amr': return ['MP3', 'WAV', 'OGG', 'FLAC', 'AAC', 'M4A', 'OPUS'];
    case 'ac3': return ['MP3', 'WAV', 'OGG', 'FLAC', 'AAC', 'M4A', 'WMA', 'AIFF', 'OPUS'];
    case 'au':
    case 'snd': return ['MP3', 'WAV', 'OGG', 'FLAC', 'AAC', 'M4A', 'OPUS'];
    case 'dts': return ['MP3', 'WAV', 'OGG', 'FLAC', 'AAC', 'M4A', 'AC3'];
    case 'ra':
    case 'ram': return ['MP3', 'WAV', 'OGG', 'FLAC', 'AAC'];

    // ── Documents ──
    case 'pdf': return ['DOCX', 'PNG', 'JPG'];
    case 'docx': case 'doc': return ['PDF'];
    case 'txt': return ['PDF'];
    case 'md':
    case 'markdown': return ['PDF'];
    case 'html':
    case 'htm': return ['PDF'];
    case 'rtf': return ['PDF'];
    case 'odt': return ['PDF'];
    case 'odp': return ['PDF'];
    case 'pptx':
    case 'ppt': return ['PDF'];
    case 'epub': return ['PDF'];
    case 'xml': return ['PDF'];
    case 'json': return ['PDF', 'CSV'];
    case 'yaml':
    case 'yml': return ['PDF'];
    case 'log': return ['PDF'];
    case 'ps': return ['PDF'];
    case 'xps':
    case 'oxps': return ['PDF'];
    case 'djvu':
    case 'djv': return ['PDF'];

    // ── Data ──
    case 'csv': return ['XLSX', 'JSON', 'TSV', 'PDF'];
    case 'xlsx': return ['CSV', 'JSON'];
    case 'tsv': return ['CSV'];
    case 'ods': return ['CSV', 'XLSX'];

    default: return [];
  }
}
}