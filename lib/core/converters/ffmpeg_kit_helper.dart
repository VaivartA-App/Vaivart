/// Conditional export helper for FFmpeg Kit on Flutter Android vs Desktop platforms.
library;

export 'ffmpeg_kit_stub.dart'
    if (dart.library.ui) 'ffmpeg_kit_android.dart';

