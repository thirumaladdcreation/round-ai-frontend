import 'package:dio/dio.dart';
import 'package:round_ai/core/errors/failures.dart';
import 'package:round_ai/core/errors/result.dart';
import 'package:round_ai/core/network/api_error.dart';
import 'package:round_ai/features/learning/models/mcq_draft.dart';
import 'package:round_ai/features/learning/repository/teach_repository.dart';

/// Demo builds keep the old Teach screen. This answers honestly.
class DemoTeachRepository implements TeachRepository {
  static Failure get _off => ApiFailure(
    const ApiError(code: 'ai_disabled', message: 'Demo build', status: 503),
  );

  @override
  Future<Result<McqDraft>> generate(
    String patientId, {
    required String problemId,
    required String idempotencyKey,
    CancelToken? cancelToken,
  }) async => Err<McqDraft>(_off);

  @override
  Future<Result<Map<String, dynamic>>> answer(
    String questionId, {
    required int selectedIndex,
  }) async => Err<Map<String, dynamic>>(_off);

  @override
  Future<Result<void>> report(
    String questionId, {
    required String reason,
  }) async => Err<void>(_off);

  @override
  Future<Result<List<McqDraft>>> questions(String patientId) async =>
      const Ok<List<McqDraft>>(<McqDraft>[]);
}
