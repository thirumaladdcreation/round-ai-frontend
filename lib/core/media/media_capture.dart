import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:round_ai/core/media/image_compressor.dart';
import 'package:round_ai/core/media/media_limits.dart';
import 'package:round_ai/core/media/media_permissions.dart';
import 'package:round_ai/core/media/media_validator.dart';
import 'package:round_ai/core/media/temp_media.dart';
import 'package:round_ai/core/network/api_error.dart';

/// Hint shown near every capture and free-text field that can hold
/// dictated text.
const String mediaPrivacyHint =
    'Do not say or write names, MRNs or dates of birth.';

const String recordingPolicyHint = "Follow your hospital's recording policy.";

/// What went wrong before an upload started (permission or local checks).
class MediaCaptureException implements Exception {
  const MediaCaptureException(this.error);

  final ApiError error;

  @override
  String toString() => 'MediaCaptureException(${error.code})';
}

/// Picks a photo or records audio into a [TempMedia] that the caller must
/// clean up with [withTempMediaCleanup].
class MediaCapture {
  MediaCapture({
    ImagePicker? picker,
    AudioRecorder? recorder,
    ImageCompressor? compressor,
    MediaPermissions? permissions,
  }) : _picker = picker ?? ImagePicker(),
       _recorder = recorder ?? AudioRecorder(),
       _compressor = compressor ?? const ImageCompressor(),
       _permissions = permissions ?? const MediaPermissions();

  final ImagePicker _picker;
  final AudioRecorder _recorder;
  final ImageCompressor _compressor;
  final MediaPermissions _permissions;

  /// Camera or gallery. Compresses before returning. HEIC/other → JPEG.
  Future<TempMedia> pickImage({required ImageSource source}) async {
    final MediaPermissionUse need = source == ImageSource.camera
        ? MediaPermissionUse.camera
        : MediaPermissionUse.photos;
    await _require(need);

    final XFile? picked = await _picker.pickImage(
      source: source,
      maxWidth: 1920,
      maxHeight: 1920,
      imageQuality: 85,
      requestFullMetadata: false,
    );
    if (picked == null) {
      throw const MediaCaptureException(ApiError.cancelled());
    }

    final Uint8List raw = await picked.readAsBytes();
    final String mime = MediaValidator.normalizeMime(
      picked.mimeType ?? _mimeFromPath(picked.name) ?? 'image/jpeg',
    );
    final Uint8List? compressed = _compressor.compress(raw, mimeType: mime);
    if (compressed == null) {
      // HEIC/HEIF and other undecodable formats — do not upload mislabeled bytes.
      throw const MediaCaptureException(
        ApiError(code: 'mime_not_allowed', message: '', status: 415),
      );
    }
    final ApiError? bad = MediaValidator.check(
      kind: MediaKind.image,
      mimeType: 'image/jpeg',
      byteLength: compressed.length,
    );
    if (bad != null) throw MediaCaptureException(bad);

    return writeTempMedia(
      bytes: compressed,
      mimeType: 'image/jpeg',
      kind: MediaKind.image,
      extension: 'jpg',
    );
  }

  /// Starts a microphone recording. Call [stopRecording] or [cancelRecording].
  Future<void> startRecording() async {
    await _require(MediaPermissionUse.microphone);
    if (await _recorder.isRecording()) {
      await _recorder.stop();
    }
    // `record` requires a path argument on all platforms; on web it is a
    // placeholder and stop() returns a blob URL.
    final String path;
    if (kIsWeb) {
      path = 'rounds_ai_${DateTime.now().microsecondsSinceEpoch}.wav';
      await _recorder.start(
        const RecordConfig(encoder: AudioEncoder.wav),
        path: path,
      );
    } else {
      final dynamic dir = await getTemporaryDirectory();
      path =
          '${dir.path}/rounds_ai_${DateTime.now().microsecondsSinceEpoch}.m4a';
      await _recorder.start(
        const RecordConfig(encoder: AudioEncoder.aacLc),
        path: path,
      );
    }
  }

  /// Stops recording and returns a validated temp capture, or null if empty.
  Future<TempMedia?> stopRecording() async {
    final String? path = await _recorder.stop();
    if (path == null || path.isEmpty) return null;

    late final Uint8List bytes;
    late final String mime;
    bytes = await XFile(path).readAsBytes();
    mime = kIsWeb ? 'audio/wav' : 'audio/mp4';
    if (!kIsWeb) {
      try {
        await deleteTempPathIfAny(path);
      } catch (_) {
        // Ignore.
      }
    }

    if (bytes.isEmpty) return null;
    final ApiError? bad = MediaValidator.check(
      kind: MediaKind.audio,
      mimeType: mime,
      byteLength: bytes.length,
    );
    if (bad != null) throw MediaCaptureException(bad);

    return writeTempMedia(
      bytes: bytes,
      mimeType: mime,
      kind: MediaKind.audio,
      extension: kIsWeb ? 'wav' : 'm4a',
    );
  }

  /// Aborts an in-progress recording.
  Future<void> cancelRecording() async {
    final String? path = await _recorder.stop();
    if (path == null || kIsWeb) return;
    try {
      // Path cleanup is best-effort on IO; web blob URLs are GC'd.
      await XFile(path).readAsBytes();
    } catch (_) {
      // Ignore.
    }
  }

  Future<void> dispose() => _recorder.dispose();

  Future<void> _require(MediaPermissionUse use) async {
    final MediaPermissionResult result = await _permissions.ensure(use);
    if (result == MediaPermissionResult.granted) return;
    throw MediaCaptureException(
      ApiError(
        code: result == MediaPermissionResult.permanentlyDenied
            ? 'permission_permanently_denied'
            : 'permission_denied',
        message: '',
        status: 403,
      ),
    );
  }

  static String? _mimeFromPath(String path) {
    final String lower = path.toLowerCase();
    if (lower.endsWith('.jpg') || lower.endsWith('.jpeg')) return 'image/jpeg';
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.webp')) return 'image/webp';
    if (lower.endsWith('.gif')) return 'image/gif';
    if (lower.endsWith('.heic') || lower.endsWith('.heif')) return 'image/heic';
    if (lower.endsWith('.m4a')) return 'audio/mp4';
    if (lower.endsWith('.mp3')) return 'audio/mpeg';
    if (lower.endsWith('.wav')) return 'audio/wav';
    if (lower.endsWith('.webm')) return 'audio/webm';
    return null;
  }
}
