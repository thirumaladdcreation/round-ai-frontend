import 'package:dio/dio.dart';
import 'package:round_ai/core/errors/failures.dart';
import 'package:round_ai/core/errors/result.dart';
import 'package:round_ai/core/network/api_error.dart';
import 'package:round_ai/features/patient/models/problem.dart';
import 'package:round_ai/features/problems/models/coding_suggestion.dart';
import 'package:round_ai/features/problems/repository/problems_repository.dart';

/// Demo screens keep their read-only problem list. This answers honestly.
class DemoProblemsRepository implements ProblemsRepository {
  static Failure get _off => ApiFailure(
    const ApiError(code: 'ai_disabled', message: 'Demo build', status: 503),
  );

  @override
  Future<Result<List<Problem>>> list(String patientId) async =>
      const Ok<List<Problem>>(<Problem>[]);

  @override
  Future<Result<List<Problem>>> suggest(
    String patientId, {
    required String idempotencyKey,
    CancelToken? cancelToken,
  }) async => Err<List<Problem>>(_off);

  @override
  Future<Result<void>> decide(
    String patientId,
    String problemId,
    ProblemAction action,
  ) async => Err<void>(_off);

  @override
  Future<Result<CodingSuggestResult>> suggestCoding(
    String patientId, {
    required String problemId,
    required String idempotencyKey,
    CancelToken? cancelToken,
  }) async => Err<CodingSuggestResult>(_off);

  @override
  Future<Result<AcceptedCodeSuggestion>> acceptCoding(
    String patientId,
    String problemId, {
    required String code,
    String? artifactId,
  }) async => Err<AcceptedCodeSuggestion>(_off);
}
