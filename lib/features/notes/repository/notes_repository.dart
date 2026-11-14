import 'package:dio/dio.dart';
import 'package:round_ai/core/errors/result.dart';
import 'package:round_ai/features/ai/models/ai_envelope.dart';
import 'package:round_ai/features/notes/models/note_section.dart';
import 'package:round_ai/features/notes/models/note_template.dart';

/// Note drafts. A draft is saved on the backend, so edits go to it with
/// PATCH. Review goes through [AiRepository.markReviewed].
abstract class NotesRepository {
  Future<Result<List<NoteTemplate>>> templates();

  /// Newest saved note for this patient (`draft_note` / `draft_note:progress`).
  /// `null` when nothing has been generated yet.
  Future<Result<AiEnvelope?>> latestNote(
    String patientId, {
    String? noteType,
  });

  /// [inputs] are flat backend fields (`subjective`, `exam`, `plan`,
  /// `history` map, …). Empty ones are left out. Optional source ids fill
  /// empty fields from saved dictation / image extracts.
  Future<Result<AiEnvelope>> generate(
    String patientId, {
    required String noteType,
    required Map<String, Object> inputs,
    List<String>? inputsFromSourceIds,
    List<String>? applyTo,
    required String idempotencyKey,
    CancelToken? cancelToken,
  });

  /// Scribe mode: one transcript (or saved source ids) → structured note.
  Future<Result<AiEnvelope>> generateFromDictation(
    String patientId, {
    required String noteType,
    String? transcript,
    List<String>? sourceIds,
    String? noteDate,
    List<Map<String, String>>? clarifications,
    required String idempotencyKey,
    CancelToken? cancelToken,
  });

  /// Saves the clinician's own text for one section.
  Future<Result<AiEnvelope>> saveSection(
    String artifactId, {
    required String sectionKey,
    required String text,
  });

  /// Asks for new text for one section. The note does not change.
  Future<Result<RewriteProposal>> rewrite(
    String artifactId, {
    required String sectionKey,
    required String before,
    required RewriteMode mode,
    required String idempotencyKey,
    CancelToken? cancelToken,
  });

  /// Clean text of a reviewed note.
  Future<Result<String>> export(String artifactId);
}
