import 'package:dio/dio.dart';
import 'package:round_ai/core/errors/failures.dart';
import 'package:round_ai/core/errors/result.dart';
import 'package:round_ai/core/network/api_client.dart';
import 'package:round_ai/core/network/api_endpoints.dart';
import 'package:round_ai/core/network/api_error.dart';
import 'package:round_ai/core/utils/json_utils.dart';
import 'package:round_ai/features/ai/models/ai_envelope.dart';
import 'package:round_ai/features/notes/models/note_section.dart';
import 'package:round_ai/features/notes/models/note_template.dart';
import 'package:round_ai/features/notes/repository/notes_repository.dart';

class NotesRepositoryImpl implements NotesRepository {
  NotesRepositoryImpl(this._client);

  final ApiClient _client;

  @override
  Future<Result<List<NoteTemplate>>> templates() async {
    try {
      final Response<Object> response = await _client.get<Object>(
        ApiEndpoints.templates,
      );
      return Ok<List<NoteTemplate>>(
        Json.itemsOf(response.data, 'templates')
            .map(NoteTemplate.fromJson)
            .where((NoteTemplate t) => t.type.isNotEmpty)
            .toList(),
      );
    } on ApiError catch (error) {
      return Err<List<NoteTemplate>>(ApiFailure(error));
    }
  }

  @override
  Future<Result<AiEnvelope?>> latestNote(
    String patientId, {
    String? noteType,
  }) async {
    try {
      final String operation = noteType == null || noteType.isEmpty
          ? 'draft_note'
          : 'draft_note:$noteType';
      final Response<Object> response = await _client.get<Object>(
        ApiEndpoints.patientArtifacts(patientId),
        queryParameters: <String, dynamic>{'operation': operation},
      );
      final List<AiEnvelope> all = Json.itemsOf(
        response.data,
        'artifacts',
      ).map(AiEnvelope.fromJson).toList();
      if (all.isEmpty) return const Ok<AiEnvelope?>(null);
      final DateTime floor = DateTime.fromMillisecondsSinceEpoch(0);
      all.sort(
        (AiEnvelope a, AiEnvelope b) =>
            (b.createdAt ?? floor).compareTo(a.createdAt ?? floor),
      );
      AiEnvelope latest = all.first;
      if (latest.content.isEmpty && latest.artifactId.isNotEmpty) {
        final Response<Object> full = await _client.get<Object>(
          ApiEndpoints.artifact(latest.artifactId),
        );
        latest = AiEnvelope.fromBody(full.data);
      }
      return Ok<AiEnvelope?>(latest);
    } on ApiError catch (error) {
      return Err<AiEnvelope?>(ApiFailure(error));
    }
  }

  @override
  Future<Result<AiEnvelope>> generate(
    String patientId, {
    required String noteType,
    required Map<String, Object> inputs,
    List<String>? inputsFromSourceIds,
    List<String>? applyTo,
    required String idempotencyKey,
    CancelToken? cancelToken,
  }) async {
    try {
      final Map<String, Object> data = <String, Object>{
        'note_type': noteType,
        ...inputs,
        if (inputsFromSourceIds != null && inputsFromSourceIds.isNotEmpty)
          'inputs_from_source_ids': inputsFromSourceIds,
        if (applyTo != null && applyTo.isNotEmpty) 'apply_to': applyTo,
      };
      final Response<Object> response = await _client.postAi<Object>(
        ApiEndpoints.patientNotes(patientId),
        idempotencyKey: idempotencyKey,
        data: data,
        cancelToken: cancelToken,
      );
      return Ok<AiEnvelope>(AiEnvelope.fromBody(response.data));
    } on ApiError catch (error) {
      return Err<AiEnvelope>(ApiFailure(error));
    }
  }

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
  }) async {
    try {
      final Map<String, Object> data = <String, Object>{
        'note_type': noteType,
        if (transcript != null && transcript.trim().isNotEmpty)
          'transcript': transcript.trim(),
        if (sourceIds != null && sourceIds.isNotEmpty) 'source_ids': sourceIds,
        if (noteDate != null && noteDate.isNotEmpty) 'note_date': noteDate,
        if (clarifications != null && clarifications.isNotEmpty)
          'clarifications': clarifications,
      };
      final Response<Object> response = await _client.postAi<Object>(
        ApiEndpoints.patientNotesFromDictation(patientId),
        idempotencyKey: idempotencyKey,
        data: data,
        cancelToken: cancelToken,
      );
      return Ok<AiEnvelope>(AiEnvelope.fromBody(response.data));
    } on ApiError catch (error) {
      return Err<AiEnvelope>(ApiFailure(error));
    }
  }

  @override
  Future<Result<AiEnvelope>> saveSection(
    String artifactId, {
    required String sectionKey,
    required String text,
  }) async {
    try {
      // Backend: PATCH /artifacts/:id with `{ sections: [{ key, text }] }`.
      final Response<Object> response = await _client.patch<Object>(
        ApiEndpoints.artifact(artifactId),
        data: <String, Object>{
          'sections': <Object>[
            <String, String>{'key': sectionKey, 'text': text},
          ],
        },
      );
      final Map<String, dynamic> body = Json.map(response.data);
      if (body['artifact_id'] != null || body['artifact'] is Map) {
        return Ok<AiEnvelope>(AiEnvelope.fromBody(body));
      }
      // The reply is only an acknowledgement. Read the saved version.
      final Response<Object> saved = await _client.get<Object>(
        ApiEndpoints.artifact(artifactId),
      );
      return Ok<AiEnvelope>(AiEnvelope.fromBody(saved.data));
    } on ApiError catch (error) {
      return Err<AiEnvelope>(ApiFailure(error));
    }
  }

  @override
  Future<Result<RewriteProposal>> rewrite(
    String artifactId, {
    required String sectionKey,
    required String before,
    required RewriteMode mode,
    required String idempotencyKey,
    CancelToken? cancelToken,
  }) async {
    try {
      final Response<Object> response = await _client.postAi<Object>(
        ApiEndpoints.artifactSectionRewrite(artifactId, sectionKey),
        idempotencyKey: idempotencyKey,
        data: <String, String>{'mode': mode.wire},
        cancelToken: cancelToken,
      );
      final Map<String, dynamic> body = Json.map(response.data);
      final Map<String, dynamic> content = Json.map(body['content']);
      const List<String> keys = <String>[
        'after',
        'text',
        'rewritten',
        'proposed',
        'suggestion',
      ];
      String after = Json.firstString(content, keys);
      if (after.isEmpty) after = Json.firstString(body, keys);
      if (after.isEmpty) {
        // Nothing usable came back. Never show an empty "after".
        return Err<RewriteProposal>(
          ApiFailure(
            const ApiError(
              code: 'ai_invalid_output',
              message: 'Empty rewrite',
              status: 502,
            ),
          ),
        );
      }
      final String sent = Json.firstString(content, const <String>['before']);
      return Ok<RewriteProposal>(
        RewriteProposal(
          sectionKey: sectionKey,
          mode: mode,
          before: sent.isEmpty ? before : sent,
          after: after,
        ),
      );
    } on ApiError catch (error) {
      return Err<RewriteProposal>(ApiFailure(error));
    }
  }

  @override
  Future<Result<String>> export(String artifactId) async {
    try {
      final Response<Object> response = await _client.get<Object>(
        ApiEndpoints.artifactExport(artifactId),
      );
      final Object? data = response.data;
      if (data is String) return Ok<String>(data);
      final Map<String, dynamic> map = Json.map(data);
      final String text = Json.firstString(map, const <String>[
        'text',
        'content',
        'note',
      ]);
      return Ok<String>(text);
    } on ApiError catch (error) {
      return Err<String>(ApiFailure(error));
    }
  }
}
