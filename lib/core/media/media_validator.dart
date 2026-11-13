import 'package:round_ai/core/media/media_limits.dart';
import 'package:round_ai/core/network/api_error.dart';

/// Client-side checks that mirror the backend upload rules.
class MediaValidator {
  const MediaValidator._();

  /// Normalizes a MIME string the way the backend does (lowercase, no params).
  static String normalizeMime(String? mime) =>
      (mime ?? '').toLowerCase().split(';').first.trim();

  /// Returns null when the file is fine, or an [ApiError] the UI can show.
  static ApiError? check({
    required MediaKind kind,
    required String? mimeType,
    required int byteLength,
  }) {
    if (byteLength <= 0) {
      return const ApiError(code: 'empty_file', message: '', status: 400);
    }
    final String mime = normalizeMime(mimeType);
    if (mime.isEmpty || !MediaLimits.mimesFor(kind).contains(mime)) {
      return const ApiError(code: 'mime_not_allowed', message: '', status: 415);
    }
    if (byteLength > MediaLimits.maxBytesFor(kind)) {
      return const ApiError(code: 'too_large', message: '', status: 413);
    }
    return null;
  }
}
