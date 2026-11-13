import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:round_ai/core/media/media_limits.dart';

/// A local media file that must be deleted after upload (or on cancel/fail).
/// Media is PHI: never copy it to the gallery and never log the path with a
/// patient id.
class TempMedia {
  TempMedia({required this.file, required this.mimeType, required this.kind});

  final File file;
  final String mimeType;
  final MediaKind kind;

  /// Byte length of the file on disk. Throws if the file is gone.
  Future<int> length() => file.length();

  /// Deletes the file if it still exists. Safe to call more than once.
  Future<void> delete() async {
    try {
      if (await file.exists()) await file.delete();
    } on FileSystemException {
      // Already gone or not writable. Nothing left to do.
    }
  }
}

/// Runs [action] and always deletes [media] afterwards — success, throw, or
/// cancel. Use this around every upload.
Future<T> withTempMediaCleanup<T>(
  TempMedia media,
  Future<T> Function(TempMedia media) action,
) async {
  try {
    return await action(media);
  } finally {
    await media.delete();
  }
}

/// Writes [bytes] into a unique file under the app temp directory.
/// The caller owns cleanup via [withTempMediaCleanup] or [TempMedia.delete].
Future<TempMedia> writeTempMedia({
  required List<int> bytes,
  required String mimeType,
  required MediaKind kind,
  String extension = 'bin',
  Directory? directory,
}) async {
  final Directory dir = directory ?? await getTemporaryDirectory();
  final String name =
      'rounds_ai_${DateTime.now().microsecondsSinceEpoch}.$extension';
  final File file = File('${dir.path}${Platform.pathSeparator}$name');
  await file.writeAsBytes(bytes, flush: true);
  return TempMedia(file: file, mimeType: mimeType, kind: kind);
}
