import 'package:dio/dio.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:round_ai/core/errors/failures.dart';
import 'package:round_ai/core/errors/result.dart';
import 'package:round_ai/core/network/api_error.dart';
import 'package:round_ai/core/network/idempotency_key.dart';
import 'package:round_ai/features/learning/models/mcq_draft.dart';
import 'package:round_ai/features/learning/repository/teach_repository.dart';
import 'package:round_ai/features/patient/models/problem.dart';
import 'package:round_ai/features/problems/repository/problems_repository.dart';

class TeachState extends Equatable {
  const TeachState({
    this.problemsLoading = true,
    this.problems = const <Problem>[],
    this.generating = false,
    this.draft,
    this.selected,
    this.submitting = false,
    this.reveal,
    this.error,
    this.answerError,
    this.reported = false,
    this.reportError,
  });

  final bool problemsLoading;

  /// Confirmed / differential problems. A question is made from one of these.
  final List<Problem> problems;
  final bool generating;
  final McqDraft? draft;

  /// The option chosen so far. Nothing is revealed until it is submitted.
  final int? selected;
  final bool submitting;
  final McqReveal? reveal;
  final ApiError? error;
  final ApiError? answerError;
  final bool reported;
  final ApiError? reportError;

  bool get answered => reveal != null;

  bool get canSubmit =>
      draft != null && selected != null && !submitting && !answered;

  TeachState copyWith({
    bool? problemsLoading,
    List<Problem>? problems,
    bool? generating,
    McqDraft? draft,
    int? selected,
    bool? submitting,
    McqReveal? reveal,
    ApiError? error,
    bool clearError = false,
    ApiError? answerError,
    bool clearAnswerError = false,
    bool? reported,
    ApiError? reportError,
    bool clearReportError = false,
  }) {
    return TeachState(
      problemsLoading: problemsLoading ?? this.problemsLoading,
      problems: problems ?? this.problems,
      generating: generating ?? this.generating,
      draft: draft ?? this.draft,
      selected: selected ?? this.selected,
      submitting: submitting ?? this.submitting,
      reveal: reveal ?? this.reveal,
      error: clearError ? null : error ?? this.error,
      answerError: clearAnswerError ? null : answerError ?? this.answerError,
      reported: reported ?? this.reported,
      reportError: clearReportError ? null : reportError ?? this.reportError,
    );
  }

  @override
  List<Object?> get props => <Object?>[
    problemsLoading,
    problems,
    generating,
    draft,
    selected,
    submitting,
    reveal,
    error?.code,
    answerError?.code,
    reported,
    reportError?.code,
  ];
}

/// Teach me: one question at a time from a confirmed problem. The answer is
/// asked from the server only after the learner submits a choice.
class TeachCubit extends Cubit<TeachState> {
  TeachCubit(this._teach, this._problems, this.patientId)
    : super(const TeachState());

  final TeachRepository _teach;
  final ProblemsRepository _problems;
  final String patientId;

  String? _key;
  String? _lastProblemId;
  CancelToken? _cancel;

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

  /// Makes a question. A retry of the same problem keeps the key.
  Future<void> generate(String problemId) async {
    if (state.generating) return;
    if (problemId != _lastProblemId) _key = null;
    _lastProblemId = problemId;
    _key ??= IdempotencyKey.create();
    final CancelToken token = _cancel = CancelToken();
    emit(
      TeachState(
        problemsLoading: false,
        problems: state.problems,
        generating: true,
        draft: state.draft,
      ),
    );
    final Result<McqDraft> result = await _teach.generate(
      patientId,
      problemId: problemId,
      idempotencyKey: _key!,
      cancelToken: token,
    );
    if (isClosed) return;
    switch (result) {
      case Err<McqDraft>(:final failure):
        final ApiError error = failure.apiError;
        if (error.kind == ApiErrorKind.cancelled) {
          _key = null;
          emit(
            TeachState(
              problemsLoading: false,
              problems: state.problems,
              draft: state.draft,
            ),
          );
          return;
        }
        if (!error.isRetryable) _key = null;
        emit(
          TeachState(
            problemsLoading: false,
            problems: state.problems,
            draft: state.draft,
            error: error,
          ),
        );
      case Ok<McqDraft>(:final value):
        _key = null;
        emit(
          TeachState(
            problemsLoading: false,
            problems: state.problems,
            draft: value,
          ),
        );
    }
  }

  Future<void> retry() {
    final String? id = _lastProblemId;
    return id == null ? Future<void>.value() : generate(id);
  }

  void cancel() => _cancel?.cancel();

  /// Picks an option. It cannot change after the answer is shown.
  void select(int index) {
    if (state.draft == null || state.answered || state.submitting) return;
    if (index < 0 || index >= state.draft!.mcq.options.length) return;
    emit(state.copyWith(selected: index, clearAnswerError: true));
  }

  Future<void> submit() async {
    final McqDraft? draft = state.draft;
    final int? selected = state.selected;
    if (draft == null || selected == null || !state.canSubmit) return;
    emit(state.copyWith(submitting: true, clearAnswerError: true));
    final Result<Map<String, dynamic>> result = await _teach.answer(
      draft.mcq.id,
      selectedIndex: selected,
    );
    if (isClosed) return;
    switch (result) {
      case Err<Map<String, dynamic>>(:final failure):
        emit(state.copyWith(submitting: false, answerError: failure.apiError));
      case Ok<Map<String, dynamic>>(:final value):
        final McqReveal? reveal = McqReveal.from(value, draft.mcq);
        if (reveal == null) {
          // No keyed answer came back. Say so. Never guess one.
          emit(
            state.copyWith(
              submitting: false,
              answerError: const ApiError(
                code: 'ai_invalid_output',
                message: 'No keyed answer',
                status: 502,
              ),
            ),
          );
          return;
        }
        emit(state.copyWith(submitting: false, reveal: reveal));
    }
  }

  Future<void> report(String reason) async {
    final McqDraft? draft = state.draft;
    if (draft == null || state.reported) return;
    emit(state.copyWith(clearReportError: true));
    final Result<void> result = await _teach.report(
      draft.mcq.id,
      reason: reason,
    );
    if (isClosed) return;
    switch (result) {
      case Err<void>(:final failure):
        emit(state.copyWith(reportError: failure.apiError));
      case Ok<void>():
        emit(state.copyWith(reported: true));
    }
  }

  /// Back to choosing a problem for the next question.
  void next() {
    emit(TeachState(problemsLoading: false, problems: state.problems));
  }

  @override
  Future<void> close() {
    _cancel?.cancel();
    return super.close();
  }
}
