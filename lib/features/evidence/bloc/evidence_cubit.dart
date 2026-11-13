import 'package:dio/dio.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:round_ai/core/errors/failures.dart';
import 'package:round_ai/core/errors/result.dart';
import 'package:round_ai/core/network/api_error.dart';
import 'package:round_ai/core/network/idempotency_key.dart';
import 'package:round_ai/features/evidence/models/evidence_result.dart';
import 'package:round_ai/features/evidence/repository/evidence_repository.dart';
import 'package:round_ai/features/patient/models/problem.dart';
import 'package:round_ai/features/problems/repository/problems_repository.dart';
import 'package:round_ai/shared/widgets/ai_state.dart';

class EvidenceState extends Equatable {
  const EvidenceState({
    this.problemsLoading = true,
    this.problems = const <Problem>[],
    this.searching = false,
    this.result,
    this.searchedLabel,
    this.error,
  });

  final bool problemsLoading;

  /// Confirmed and differential problems. Nothing else can start a search.
  final List<Problem> problems;
  final bool searching;
  final EvidenceResult? result;

  /// What the shown result was searched on: the problem label or the topic.
  final String? searchedLabel;
  final ApiError? error;

  AiState get aiState {
    if (searching) return AiState.loading;
    final EvidenceResult? r = result;
    if (r == null) {
      final ApiError? e = error;
      return e == null ? AiState.notGenerated : AiState.fromError(e);
    }
    if (r.isEmpty) return AiState.noEvidence;
    return AiState.fromEnvelope(r.envelope);
  }

  EvidenceState copyWith({
    bool? problemsLoading,
    List<Problem>? problems,
    bool? searching,
    EvidenceResult? result,
    String? searchedLabel,
    ApiError? error,
    bool clearError = false,
  }) {
    return EvidenceState(
      problemsLoading: problemsLoading ?? this.problemsLoading,
      problems: problems ?? this.problems,
      searching: searching ?? this.searching,
      result: result ?? this.result,
      searchedLabel: searchedLabel ?? this.searchedLabel,
      error: clearError ? null : error ?? this.error,
    );
  }

  @override
  List<Object?> get props => <Object?>[
    problemsLoading,
    problems,
    searching,
    result,
    searchedLabel,
    error?.code,
  ];
}

/// Evidence search for one patient. It needs a confirmed or differential
/// problem, or a typed topic.
class EvidenceCubit extends Cubit<EvidenceState> {
  EvidenceCubit(this._evidence, this._problems, this.patientId)
    : super(const EvidenceState());

  final EvidenceRepository _evidence;
  final ProblemsRepository _problems;
  final String patientId;

  String? _key;
  CancelToken? _cancel;
  String? _lastProblemId;
  String? _lastTopic;

  /// A failed read leaves the list empty. A typed topic still works.
  Future<void> loadProblems() async {
    emit(state.copyWith(problemsLoading: true));
    final Result<List<Problem>> result = await _problems.list(patientId);
    if (isClosed) return;
    emit(
      state.copyWith(
        problemsLoading: false,
        problems: switch (result) {
          Ok<List<Problem>>(:final value) => <Problem>[
            for (final Problem p in value)
              if (p.state == ProblemState.confirmed ||
                  p.state == ProblemState.differential)
                p,
          ],
          Err<List<Problem>>() => state.problems,
        },
      ),
    );
  }

  /// Searches on [problemId], or on [topic] when no problem is given. An
  /// empty request does nothing. The Idempotency-Key is kept for a retry of
  /// the same search.
  Future<void> search({String? problemId, String? topic}) async {
    if (state.searching) return;
    final String typed = topic?.trim() ?? '';
    final String? problem = problemId == null || problemId.isEmpty
        ? null
        : problemId;
    if (problem == null && typed.isEmpty) return;
    if (problem != _lastProblemId || typed != (_lastTopic ?? '')) {
      // A different search is a different action.
      _key = null;
    }
    _lastProblemId = problem;
    _lastTopic = typed;
    _key ??= IdempotencyKey.create();
    final CancelToken token = _cancel = CancelToken();
    emit(state.copyWith(searching: true, clearError: true));
    final Result<EvidenceResult> result = await _evidence.search(
      patientId,
      problemId: problem,
      topic: problem == null ? typed : null,
      idempotencyKey: _key!,
      cancelToken: token,
    );
    if (isClosed) return;
    switch (result) {
      case Err<EvidenceResult>(:final failure):
        final ApiError error = failure.apiError;
        if (error.kind == ApiErrorKind.cancelled) {
          _key = null;
          emit(state.copyWith(searching: false));
          return;
        }
        if (!error.isRetryable) _key = null;
        emit(state.copyWith(searching: false, error: error));
      case Ok<EvidenceResult>(:final value):
        _key = null;
        emit(
          EvidenceState(
            problemsLoading: false,
            problems: state.problems,
            result: value,
            searchedLabel: problem == null
                ? typed
                : state.problems
                      .firstWhere(
                        (Problem p) => p.id == problem,
                        orElse: () => Problem(
                          id: problem,
                          label: value.topic,
                          state: ProblemState.confirmed,
                        ),
                      )
                      .label,
          ),
        );
    }
  }

  /// Runs the last search again, with the same key.
  Future<void> retry() => search(problemId: _lastProblemId, topic: _lastTopic);

  void cancel() => _cancel?.cancel();

  @override
  Future<void> close() {
    _cancel?.cancel();
    return super.close();
  }
}
