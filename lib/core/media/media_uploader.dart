import 'package:dio/dio.dart';
import 'package:http_parser/http_parser.dart';
import 'package:round_ai/core/media/media_limits.dart';
import 'package:round_ai/core/media/media_validator.dart';
import 'package:round_ai/core/media/temp_media.dart';
import 'package:round_ai/core/network/api_client.dart';
import 'package:round_ai/core/network/api_error.dart';

/// Builds the multipart body the backend `resolveMediaPayload` expects and
/// posts it. The temp capture is **not** deleted here — wrap the call in
/// [withTempMediaCleanup].
class MediaUploader {
  MediaUploader(this._client);

  final ApiClient _client;

  /// Field name for the file part. Backend busboy accepts any single file.
  static const String fileField = 'file';

  /// Validates then uploads. [filename] must not contain a patient name.
  Future<Response<Object>> upload({
    required String path,
    required String idempotencyKey,
    required TempMedia media,
    String? eventTime,
    String? sourceKind,
    String? teamId,
    String filename = 'capture.bin',
    CancelToken? cancelToken,
    void Function(int sent, int total)? onSendProgress,
  }) async {
    final int length = await media.length();
    final ApiError? bad = MediaValidator.check(
      kind: media.kind,
      mimeType: media.mimeType,
      byteLength: length,
    );
    if (bad != null) throw bad;

    final FormData data = FormData.fromMap(<String, dynamic>{
      'kind': media.kind.wire,
      'mime_type': media.mimeType,
      if (eventTime != null && eventTime.isNotEmpty) 'event_time': eventTime,
      if (sourceKind != null && sourceKind.isNotEmpty)
        'source_kind': sourceKind,
      if (teamId != null && teamId.isNotEmpty) 'team_id': teamId,
      // Always from bytes so web (no File path) and IO share one path.
      // Set part Content-Type explicitly — Dio defaults to octet-stream, which
      // the backend used to reject even when mime_type field was correct.
      fileField: MultipartFile.fromBytes(
        media.bytes,
        filename: filename,
        contentType: _mediaType(media.mimeType),
      ),
    });

    return _client.postAiMultipart<Object>(
      path,
      idempotencyKey: idempotencyKey,
      data: data,
      cancelToken: cancelToken,
      onSendProgress: onSendProgress,
    );
  }

  static MediaType _mediaType(String mime) {
    final String normalized = MediaValidator.normalizeMime(mime);
    final List<String> parts = normalized.split('/');
    if (parts.length == 2 && parts[0].isNotEmpty && parts[1].isNotEmpty) {
      return MediaType(parts[0], parts[1]);
    }
    return MediaType('application', 'octet-stream');
  }
}
