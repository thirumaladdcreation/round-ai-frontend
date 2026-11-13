import 'package:dio/dio.dart';
import 'package:round_ai/core/errors/result.dart';
import 'package:round_ai/features/patient/models/problem.dart';
import 'package:round_ai/features/problems/models/coding_suggestion.dart';

/// What a clinician decides about a problem.
enum ProblemAction {
  accept('accept', ProblemState.confirmed),
  differential('differential', ProblemState.differential),
  reject('reject', ProblemState.rejected);

  const ProblemAction(this.wire, this.resultingState);

  final String wire;
  final ProblemState resultingState;
}

abstract class ProblemsRepository {
  Future<Result<List<Problem>>> list(String patientId);

  /// Asks the model for problems the chart may support. They come back as
  /// suggestions and stay suggestions until a clinician decides.
  Future<Result<List<Problem>>> suggest(
    String patientId, {
    required String idempotencyKey,
    CancelToken? cancelToken,
  });

  Future<Result<void>> decide(
    String patientId,
    String problemId,
    ProblemAction action,
  );

  /// ICD-10-CM suggestions for one problem (draft artifact; not stored yet).
  Future<Result<CodingSuggestResult>> suggestCoding(
    String patientId, {
    required String problemId,
    required String idempotencyKey,
    CancelToken? cancelToken,
  });

  /// Clinician accept writes `problems.code_suggestion`.
  Future<Result<AcceptedCodeSuggestion>> acceptCoding(
    String patientId,
    String problemId, {
    required String code,
    String? artifactId,
  });
}
