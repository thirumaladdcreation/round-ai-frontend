import 'dart:typed_data';

import 'package:round_ai/core/media/media_limits.dart';
import 'package:round_ai/core/media/temp_media_base.dart';

Future<TempMedia> writeTempMediaImpl({
  required Uint8List bytes,
  required String mimeType,
  required MediaKind kind,
  String extension = 'bin',
}) async {
  return TempMedia(bytes: bytes, mimeType: mimeType, kind: kind);
}

Future<void> deleteTempPathImpl(String path) async {
  // No filesystem temp files on web.
}
