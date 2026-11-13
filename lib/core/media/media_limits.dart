/// Limits and allow-lists that match the backend `config.uploads` defaults.
/// The server still enforces them; the app checks first so we never upload a
/// file that will only bounce as `too_large` / `mime_not_allowed`.
class MediaLimits {
  const MediaLimits._();

  /// Backend default `MAX_AUDIO_BYTES` (25 MiB).
  static const int maxAudioBytes = 25 * 1024 * 1024;

  /// Backend default `MAX_IMAGE_BYTES` (10 MiB).
  static const int maxImageBytes = 10 * 1024 * 1024;

  /// Longest side after downscale, before upload.
  static const int imageMaxSide = 2000;

  /// JPEG quality for downscaled photos (~80%).
  static const int imageJpegQuality = 80;

  static const Set<String> audioMimes = <String>{
    'audio/wav',
    'audio/wave',
    'audio/x-wav',
    'audio/mpeg',
    'audio/mp3',
    'audio/mp4',
    'audio/m4a',
    'audio/x-m4a',
    'audio/webm',
    'audio/ogg',
    'audio/flac',
  };

  static const Set<String> imageMimes = <String>{
    'image/jpeg',
    'image/jpg',
    'image/png',
    'image/webp',
    'image/gif',
  };

  static int maxBytesFor(MediaKind kind) =>
      kind == MediaKind.audio ? maxAudioBytes : maxImageBytes;

  static Set<String> mimesFor(MediaKind kind) =>
      kind == MediaKind.audio ? audioMimes : imageMimes;
}

enum MediaKind { audio, image }

extension MediaKindWire on MediaKind {
  String get wire => switch (this) {
    MediaKind.audio => 'audio',
    MediaKind.image => 'image',
  };
}
