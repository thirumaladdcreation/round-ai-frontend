import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:round_ai/core/media/image_compressor.dart';
import 'package:round_ai/core/media/media_limits.dart';
import 'package:round_ai/core/media/media_validator.dart';
import 'package:round_ai/core/media/temp_media.dart';
import 'package:round_ai/core/network/api_error.dart';

void main() {
  group('MediaValidator', () {
    test('accepts an allowed audio mime under the size cap', () {
      expect(
        MediaValidator.check(
          kind: MediaKind.audio,
          mimeType: 'audio/mp4; codecs=mp4a',
          byteLength: 1024,
        ),
        isNull,
      );
    });

    test('rejects an empty file', () {
      final ApiError? error = MediaValidator.check(
        kind: MediaKind.image,
        mimeType: 'image/jpeg',
        byteLength: 0,
      );
      expect(error!.kind, ApiErrorKind.emptyFile);
      expect(error.userMessage, isNot(contains('server')));
    });

    test('rejects a file over the image cap', () {
      final ApiError? error = MediaValidator.check(
        kind: MediaKind.image,
        mimeType: 'image/jpeg',
        byteLength: MediaLimits.maxImageBytes + 1,
      );
      expect(error!.kind, ApiErrorKind.tooLarge);
      expect(error.userMessage, 'That file is too large to upload.');
    });

    test('rejects a file over the audio cap', () {
      final ApiError? error = MediaValidator.check(
        kind: MediaKind.audio,
        mimeType: 'audio/wav',
        byteLength: MediaLimits.maxAudioBytes + 1,
      );
      expect(error!.kind, ApiErrorKind.tooLarge);
    });

    test('rejects a mime the backend does not allow', () {
      final ApiError? error = MediaValidator.check(
        kind: MediaKind.image,
        mimeType: 'image/bmp',
        byteLength: 100,
      );
      expect(error!.kind, ApiErrorKind.mimeNotAllowed);
    });
  });

  group('temp media cleanup', () {
    late Directory dir;

    setUp(() async {
      dir = await Directory.systemTemp.createTemp('rounds_ai_g0_');
    });

    tearDown(() async {
      if (await dir.exists()) await dir.delete(recursive: true);
    });

    test('deletes the file after a successful action', () async {
      final TempMedia media = await writeTempMedia(
        bytes: <int>[1, 2, 3],
        mimeType: 'image/jpeg',
        kind: MediaKind.image,
        extension: 'jpg',
        directory: dir,
      );
      expect(await media.file.exists(), isTrue);

      final int length = await withTempMediaCleanup(media, (TempMedia m) async {
        return m.length();
      });
      expect(length, 3);
      expect(await media.file.exists(), isFalse);
    });

    test('deletes the file when the action throws', () async {
      final TempMedia media = await writeTempMedia(
        bytes: <int>[9, 9],
        mimeType: 'audio/mp4',
        kind: MediaKind.audio,
        extension: 'm4a',
        directory: dir,
      );

      await expectLater(
        withTempMediaCleanup(media, (TempMedia m) async {
          throw StateError('upload failed');
        }),
        throwsA(isA<StateError>()),
      );
      expect(await media.file.exists(), isFalse);
    });

    test('deletes the file when the action is cancelled', () async {
      final TempMedia media = await writeTempMedia(
        bytes: <int>[4],
        mimeType: 'image/png',
        kind: MediaKind.image,
        extension: 'png',
        directory: dir,
      );

      await expectLater(
        withTempMediaCleanup(media, (TempMedia m) async {
          throw const ApiError.cancelled();
        }),
        throwsA(
          isA<ApiError>().having(
            (ApiError e) => e.kind,
            'kind',
            ApiErrorKind.cancelled,
          ),
        ),
      );
      expect(await media.file.exists(), isFalse);
    });

    test('delete is safe to call twice', () async {
      final TempMedia media = await writeTempMedia(
        bytes: <int>[1],
        mimeType: 'image/jpeg',
        kind: MediaKind.image,
        directory: dir,
      );
      await media.delete();
      await media.delete();
      expect(await media.file.exists(), isFalse);
    });
  });

  group('ImageCompressor', () {
    Uint8List pngOf(int w, int h) {
      final img.Image image = img.Image(width: w, height: h);
      img.fill(image, color: img.ColorRgb8(10, 20, 30));
      return Uint8List.fromList(img.encodePng(image));
    }

    test('downscales a large image and returns JPEG', () {
      final Uint8List out = const ImageCompressor().compress(
        pngOf(3000, 1500),
        mimeType: 'image/png',
        maxSide: 1000,
      );
      final img.Image? decoded = img.decodeImage(out);
      expect(decoded, isNotNull);
      expect(decoded!.width, 1000);
      expect(decoded.height, 500);
      expect(out[0], 0xFF);
      expect(out[1], 0xD8);
    });

    test('leaves a small JPEG alone', () {
      final img.Image image = img.Image(width: 40, height: 30);
      img.fill(image, color: img.ColorRgb8(1, 2, 3));
      final Uint8List jpeg = Uint8List.fromList(
        img.encodeJpg(image, quality: 90),
      );
      final Uint8List out = const ImageCompressor().compress(
        jpeg,
        mimeType: 'image/jpeg',
        maxSide: 2000,
      );
      expect(out, same(jpeg));
    });
  });

  group('new error codes', () {
    test('media and teaching codes map to friendly text', () {
      expect(
        const ApiError(code: 'too_large', message: 'x', status: 413).kind,
        ApiErrorKind.tooLarge,
      );
      expect(
        const ApiError(
          code: 'not_approved',
          message: 'server text',
          status: 403,
        ).userMessage,
        'This question was reported and is under review.',
      );
      expect(
        const ApiError(code: 'not_confirmable', message: 'x', status: 409).kind,
        ApiErrorKind.notConfirmable,
      );
      expect(
        const ApiError(code: 'team_required', message: 'x', status: 400).kind,
        ApiErrorKind.teamRequired,
      );
      expect(
        const ApiError(
          code: 'permission_permanently_denied',
          message: '',
        ).userMessage,
        contains('Settings'),
      );
      expect(
        const ApiError(
          code: 'mystery_scribe',
          message: 'leak',
          status: 500,
        ).userMessage,
        'Something went wrong. Try again.',
      );
    });
  });
}
