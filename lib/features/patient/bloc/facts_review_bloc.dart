import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:round_ai/core/errors/result.dart';
import 'package:round_ai/features/patient/models/fact.dart';
import 'package:round_ai/features/patient/repository/chart_data_repository.dart';

sealed class FactsReviewEvent extends Equatable {
  const FactsReviewEvent();

  @override
  List<Object?> get props => <Object?>[];
}

class FactsRequested extends FactsReviewEvent {
  const FactsRequested({this.done});

  /// Completed when the read has finished. Pull-to-refresh waits on it.
  final Completer<void>? done;
}

class FactToggled extends FactsReviewEvent {
  const FactToggled(this.factId);

  final String factId;

  @override
  List<Object?> get props => <Object?>[factId];
}

class AllFactsToggled extends FactsReviewEvent {
  const AllFactsToggled();
}

/// Confirm or reject. With [factId] it is one fact. Without, it is every
/// fact the clinician ticked.
class FactsDecided extends FactsReviewEvent {
  const FactsDecided({required this.confirm, this.factId});

  final bool confirm;
  final String? factId;

  @override
  List<Object?> get props => <Object?>[confirm, factId];
}

class FactsReviewState extends Equatable {
  const FactsReviewState({
    this.loading = true,
    this.facts = const <Fact>[],
    this.selected = const <String>{},
    this.busy = false,
    this.error,
    this.lastDecided = 0,
    this.lastFailed = 0,
  });

  final bool loading;

  /// Pending facts only.
  final List<Fact> facts;
  final Set<String> selected;
  final bool busy;
  final String? error;

  /// How many facts the last decision settled, and how many it could not.
  final int lastDecided;
  final int lastFailed;

  bool get allSelected => facts.isNotEmpty && selected.length == facts.length;

  FactsReviewState copyWith({
    bool? loading,
    List<Fact>? facts,
    Set<String>? selected,
    bool? busy,
    String? error,
    bool clearError = false,
    int? lastDecided,
    int? lastFailed,
  }) {
    return FactsReviewState(
      loading: loading ?? this.loading,
      facts: facts ?? this.facts,
      selected: selected ?? this.selected,
      busy: busy ?? this.busy,
      error: clearError ? null : (error ?? this.error),
      lastDecided: lastDecided ?? this.lastDecided,
      lastFailed: lastFailed ?? this.lastFailed,
    );
  }

  @override
  List<Object?> get props => <Object?>[
    loading,
    facts,
    selected,
    busy,
    error,
    lastDecided,
    lastFailed,
  ];
}

class FactsReviewBloc extends Bloc<FactsReviewEvent, FactsReviewState> {
  FactsReviewBloc(this._repository, this.patientId)
    : super(const FactsReviewState()) {
    on<FactsRequested>(_onRequested);
    on<FactToggled>(_onToggled);
    on<AllFactsToggled>(_onAllToggled);
    on<FactsDecided>(_onDecided);
  }

  final ChartDataRepository _repository;
  final String patientId;

  Future<void> _onRequested(
    FactsRequested event,
    Emitter<FactsReviewState> emit,
  ) async {
    final Result<List<Fact>> result = await _repository.pendingFacts(patientId);
    if (event.done?.isCompleted == false) event.done!.complete();
    switch (result) {
      case Ok<List<Fact>>(:final value):
        emit(
          state.copyWith(
            loading: false,
            facts: value,
            // Drop ticks for facts that are gone.
            selected: state.selected
                .where((String id) => value.any((Fact f) => f.id == id))
                .toSet(),
            clearError: true,
          ),
        );
      case Err<List<Fact>>(:final failure):
        emit(state.copyWith(loading: false, error: failure.message));
    }
  }

  void _onToggled(FactToggled event, Emitter<FactsReviewState> emit) {
    final Set<String> next = Set<String>.of(state.selected);
    if (!next.remove(event.factId)) next.add(event.factId);
    emit(state.copyWith(selected: next));
  }

  void _onAllToggled(AllFactsToggled event, Emitter<FactsReviewState> emit) {
    emit(
      state.copyWith(
        selected: state.allSelected
            ? <String>{}
            : state.facts.map((Fact f) => f.id).toSet(),
      ),
    );
  }

  Future<void> _onDecided(
    FactsDecided event,
    Emitter<FactsReviewState> emit,
  ) async {
    final List<String> ids = event.factId != null
        ? <String>[event.factId!]
        : state.selected.toList();
    if (ids.isEmpty || state.busy) return;
    emit(state.copyWith(busy: true, clearError: true));

    final Result<void> result = await _repository.decide(
      patientId,
      ids,
      confirm: event.confirm,
    );

    // Reload so the list shows what the server now says.
    final Result<List<Fact>> reloaded = await _repository.pendingFacts(
      patientId,
    );
    final List<Fact> facts = reloaded is Ok<List<Fact>>
        ? reloaded.value
        : state.facts;

    switch (result) {
      case Err<void>(:final failure):
        emit(
          state.copyWith(
            busy: false,
            facts: facts,
            selected: state.selected
                .where((String id) => facts.any((Fact f) => f.id == id))
                .toSet(),
            lastDecided: 0,
            lastFailed: ids.length,
            error: failure.message,
          ),
        );
      case Ok<void>():
        emit(
          state.copyWith(
            busy: false,
            facts: facts,
            selected: state.selected
                .where((String id) => facts.any((Fact f) => f.id == id))
                .toSet(),
            lastDecided: ids.length,
            lastFailed: 0,
            clearError: true,
          ),
        );
    }
  }
}
