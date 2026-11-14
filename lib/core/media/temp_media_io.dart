import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';
import 'package:round_ai/core/media/media_limits.dart';
import 'package:round_ai/core/media/temp_media_base.dart';

Future<TempMedia> writeTempMediaImpl({
  required Uint8List bytes,
  required String mimeType,
  required MediaKind kind,
  String extension = 'bin',
}) async {
  final Directory dir = await getTemporaryDirectory();
  final String name =
      'rounds_ai_${DateTime.now().microsecondsSinceEpoch}.$extension';
  final String path = '${dir.path}${Platform.pathSeparator}$name';
  final File file = File(path);
  await file.writeAsBytes(bytes, flush: true);
  return TempMedia(
    bytes: bytes,
    mimeType: mimeType,
    kind: kind,
    path: path,
  );
}

Future<void> deleteTempPathImpl(String path) async {
  try {
    final File file = File(path);
    if (await file.exists()) await file.delete();
  } on FileSystemException {
    // Already gone.
  }
}
