import 'package:dio/dio.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:round_ai/core/errors/failures.dart';
import 'package:round_ai/core/errors/result.dart';
import 'package:round_ai/core/network/api_error.dart';
import 'package:round_ai/core/network/idempotency_key.dart';
import 'package:round_ai/features/patient/models/problem.dart';
import 'package:round_ai/features/problems/repository/problems_repository.dart';

class ProblemsState extends Equatable {
  const ProblemsState({
    this.problems = const <Problem>[],
    this.suggesting = false,
    this.busyId,
    this.error,
    this.suggestedCount,
    this.changes = 0,
  });

  final List<Problem> problems;
  final bool suggesting;

  /// The problem whose decision is being saved.
  final String? busyId;
  final ApiError? error;

  /// How many suggestions the last "Suggest problems" returned. `null` until
  /// it has run. Zero means the model found none.
  final int? suggestedCount;

  /// Goes up when a decision is saved, so the screen around it can reload.
  final int changes;

  ProblemsState copyWith({
    List<Problem>? problems,
    bool? suggesting,
    String? busyId,
    bool clearBusy = false,
    ApiError? error,
    bool clearError = false,
    int? suggestedCount,
    int? changes,
  }) {
    return ProblemsState(
      problems: problems ?? this.problems,
      suggesting: suggesting ?? this.suggesting,
      busyId: clearBusy ? null : busyId ?? this.busyId,
      error: clearError ? null : error ?? this.error,
      suggestedCount: suggestedCount ?? this.suggestedCount,
      changes: changes ?? this.changes,
    );
  }

  @override
  List<Object?> get props => <Object?>[
    problems,
    suggesting,
    busyId,
    error?.code,
    suggestedCount,
    changes,
  ];
}

/// The problem list on the overview. A suggestion from the model stays a
/// suggestion until the clinician taps Accept, Differential or Reject.
class ProblemsCubit extends Cubit<ProblemsState> {
  ProblemsCubit(
    this._repository,
    this.patientId, {
    List<Problem> initial = const <Problem>[],
  }) : super(ProblemsState(problems: initial));

  final ProblemsRepository _repository;
  final String patientId;

  String? _key;
  CancelToken? _cancel;

  /// Reads the saved list. A failed read keeps what is already shown.
  Future<void> load() async {
    final Result<List<Problem>> result = await _repository.list(patientId);
    if (isClosed) return;
    if (result case Ok<List<Problem>>(:final value)) {
      emit(state.copyWith(problems: value));
    }
  }

  Future<void> suggest() async {
    if (state.suggesting) return;
    _key ??= IdempotencyKey.create();
    final CancelToken token = _cancel = CancelToken();
    emit(state.copyWith(suggesting: true, clearError: true));
    final Result<List<Problem>> result = await _repository.suggest(
      patientId,
      idempotencyKey: _key!,
      cancelToken: token,
    );
    if (isClosed) return;
    switch (result) {
      case Err<List<Problem>>(:final failure):
        final ApiError error = failure.apiError;
        if (error.kind == ApiErrorKind.cancelled) {
          _key = null;
          emit(state.copyWith(suggesting: false));
          return;
        }
        if (!error.isRetryable) _key = null;
        emit(state.copyWith(suggesting: false, error: error));
      case Ok<List<Problem>>(:final value):
        _key = null;
        // Show the suggestions at once, then read the saved list.
        emit(
          state.copyWith(
            problems: _merge(state.problems, value),
            suggesting: false,
            suggestedCount: value.length,
          ),
        );
        final Result<List<Problem>> saved = await _repository.list(patientId);
        if (isClosed) return;
        if (saved case Ok<List<Problem>>(value: final List<Problem> list)) {
          // Suggestions the saved list does not have yet are kept.
          emit(state.copyWith(problems: _merge(list, value)));
        }
    }
  }

  void cancel() => _cancel?.cancel();

  /// Saves a decision. Only a successful save changes the state shown.
  Future<void> decide(Problem problem, ProblemAction action) async {
    if (state.busyId != null) return;
    emit(state.copyWith(busyId: problem.id, clearError: true));
    final Result<void> result = await _repository.decide(
      patientId,
      problem.id,
      action,
    );
    if (isClosed) return;
    switch (result) {
      case Err<void>(:final failure):
        emit(state.copyWith(clearBusy: true, error: failure.apiError));
      case Ok<void>():
        emit(
          state.copyWith(
            clearBusy: true,
            problems: <Problem>[
              for (final Problem p in state.problems)
                p.id == problem.id
                    ? Problem(
                        id: p.id,
                        label: p.label,
                        state: action.resultingState,
                        factIds: p.factIds,
                      )
                    : p,
            ],
            changes: state.changes + 1,
          ),
        );
        await load();
    }
  }

  /// [base] plus any of [extra] it does not have, matched by id.
  static List<Problem> _merge(List<Problem> base, List<Problem> extra) {
    final Set<String> ids = base.map((Problem p) => p.id).toSet();
    return <Problem>[
      ...base,
      for (final Problem p in extra)
        if (!ids.contains(p.id)) p,
    ];
  }

  @override
  Future<void> close() {
    _cancel?.cancel();
    return super.close();
  }
}
