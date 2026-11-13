import 'package:dio/dio.dart';
import 'package:round_ai/core/errors/result.dart';
import 'package:round_ai/features/learning/models/mcq_draft.dart';

abstract class TeachRepository {
  /// Makes one question from a confirmed problem of this patient.
  Future<Result<McqDraft>> generate(
    String patientId, {
    required String problemId,
    required String idempotencyKey,
    CancelToken? cancelToken,
  });

  /// Submits one choice. The reply is the server's body, which carries the
  /// key and explanations. The screen reads it only after the submit.
  Future<Result<Map<String, dynamic>>> answer(
    String questionId, {
    required int selectedIndex,
  });

  Future<Result<void>> report(String questionId, {required String reason});

  /// Generated questions for this patient, newest first.
  Future<Result<List<McqDraft>>> questions(String patientId);
}
