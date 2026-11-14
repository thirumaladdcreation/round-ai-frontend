import 'dart:typed_data';

import 'package:round_ai/core/media/media_limits.dart';
import 'package:round_ai/core/media/temp_media_io.dart'
    if (dart.library.html) 'package:round_ai/core/media/temp_media_web.dart'
    as impl;

/// Local capture bytes that must be cleared after upload (or on cancel/fail).
/// Media is PHI: never copy it to the gallery and never log paths with a
/// patient id. On web there is no temp file — bytes stay in memory only.
class TempMedia {
  TempMedia({
    required this.bytes,
    required this.mimeType,
    required this.kind,
    this.path,
  });

  final Uint8List bytes;
  final String mimeType;
  final MediaKind kind;

  /// Filesystem path when written on IO platforms; null on web.
  final String? path;

  Future<int> length() async => bytes.length;

  /// Clears any on-disk temp file. Safe to call more than once.
  Future<void> delete() async {
    final String? p = path;
    if (p == null) return;
    await impl.deleteTempPathImpl(p);
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

/// Creates a [TempMedia] from bytes. On IO platforms also writes a temp file
/// for plugins that need a path; on web keeps memory only.
Future<TempMedia> writeTempMedia({
  required List<int> bytes,
  required String mimeType,
  required MediaKind kind,
  String extension = 'bin',
}) {
  final Uint8List data = bytes is Uint8List
      ? bytes
      : Uint8List.fromList(bytes);
  return impl.writeTempMediaImpl(
    bytes: data,
    mimeType: mimeType,
    kind: kind,
    extension: extension,
  );
}

/// Best-effort delete of a recorder-created path on IO platforms.
Future<void> deleteTempPathIfAny(String path) =>
    impl.deleteTempPathImpl(path);
