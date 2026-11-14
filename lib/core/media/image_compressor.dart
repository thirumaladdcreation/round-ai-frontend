import 'dart:typed_data';

import 'package:image/image.dart' as img;
import 'package:round_ai/core/media/media_limits.dart';

/// Downscales a still image so the longest side is at most
/// [MediaLimits.imageMaxSide], then encodes JPEG at ~80% quality.
///
/// Returns the original bytes when the file is already small enough and is
/// already JPEG. GIF/PNG/WebP are always re-encoded to JPEG for upload size.
class ImageCompressor {
  const ImageCompressor();

  /// Returns JPEG bytes, or null when the image cannot be decoded (e.g. HEIC
  /// on platforms without a decoder). Callers must not upload raw undecoded
  /// bytes labeled as JPEG.
  Uint8List? compress(
    Uint8List bytes, {
    String? mimeType,
    int maxSide = MediaLimits.imageMaxSide,
    int quality = MediaLimits.imageJpegQuality,
  }) {
    final img.Image? decoded = img.decodeImage(bytes);
    if (decoded == null) return null;

    img.Image frame = decoded;
    final int longest = frame.width > frame.height ? frame.width : frame.height;
    if (longest > maxSide) {
      frame = img.copyResize(
        frame,
        width: frame.width >= frame.height ? maxSide : null,
        height: frame.height > frame.width ? maxSide : null,
        interpolation: img.Interpolation.linear,
      );
    }

    final String mime = (mimeType ?? '').toLowerCase();
    final bool alreadyJpeg =
        mime.contains('jpeg') || mime.contains('jpg') || _looksJpeg(bytes);
    if (alreadyJpeg && longest <= maxSide) {
      return bytes;
    }

    return Uint8List.fromList(img.encodeJpg(frame, quality: quality));
  }

  static bool _looksJpeg(Uint8List bytes) =>
      bytes.length >= 3 &&
      bytes[0] == 0xFF &&
      bytes[1] == 0xD8 &&
      bytes[2] == 0xFF;
}
