import 'package:dio/dio.dart';
import 'package:round_ai/core/errors/failures.dart';
import 'package:round_ai/core/errors/result.dart';
import 'package:round_ai/core/network/api_error.dart';
import 'package:round_ai/features/ai/models/ai_envelope.dart';
import 'package:round_ai/features/notes/models/note_section.dart';
import 'package:round_ai/features/notes/models/note_template.dart';
import 'package:round_ai/features/notes/repository/notes_repository.dart';

/// Demo builds keep the old note screen with its canned text. This only
/// answers honestly if something asks for a real draft.
class DemoNotesRepository implements NotesRepository {
  static Failure get _off => ApiFailure(
    const ApiError(code: 'ai_disabled', message: 'Demo build', status: 503),
  );

  @override
  Future<Result<List<NoteTemplate>>> templates() async =>
      const Ok<List<NoteTemplate>>(<NoteTemplate>[]);

  @override
  Future<Result<AiEnvelope?>> latestNote(
    String patientId, {
    String? noteType,
  }) async => const Ok<AiEnvelope?>(null);

  @override
  Future<Result<AiEnvelope>> generate(
    String patientId, {
    required String noteType,
    required Map<String, Object> inputs,
    List<String>? inputsFromSourceIds,
    List<String>? applyTo,
    required String idempotencyKey,
    CancelToken? cancelToken,
  }) async => Err<AiEnvelope>(_off);

  @override
  Future<Result<AiEnvelope>> generateFromDictation(
    String patientId, {
    required String noteType,
    String? transcript,
    List<String>? sourceIds,
    String? noteDate,
    List<Map<String, String>>? clarifications,
    required String idempotencyKey,
    CancelToken? cancelToken,
  }) async => Err<AiEnvelope>(_off);

  @override
  Future<Result<AiEnvelope>> saveSection(
    String artifactId, {
    required String sectionKey,
    required String text,
  }) async => Err<AiEnvelope>(_off);

  @override
  Future<Result<RewriteProposal>> rewrite(
    String artifactId, {
    required String sectionKey,
    required String before,
    required RewriteMode mode,
    required String idempotencyKey,
    CancelToken? cancelToken,
  }) async => Err<RewriteProposal>(_off);

  @override
  Future<Result<String>> export(String artifactId) async => Err<String>(_off);
}
