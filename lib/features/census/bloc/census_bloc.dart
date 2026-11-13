import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:round_ai/core/errors/result.dart';
import 'package:round_ai/features/census/bloc/census_event.dart';
import 'package:round_ai/features/census/bloc/census_state.dart';
import 'package:round_ai/features/census/models/patient_summary.dart';
import 'package:round_ai/features/census/repository/census_repository.dart';

class CensusBloc extends Bloc<CensusEvent, CensusState> {
  CensusBloc(this._repository) : super(const CensusState()) {
    on<CensusRequested>(_onRequested);
    on<PatientAddRequested>(_onAdd);
    on<CensusReorderRequested>(_onReorder);
  }

  final CensusRepository _repository;

  Future<void> _onRequested(
    CensusRequested event,
    Emitter<CensusState> emit,
  ) async {
    // A refresh keeps the old list on screen while it loads.
    if (state.status != CensusStatus.ready) {
      emit(state.copyWith(status: CensusStatus.loading, clearError: true));
    }
    final Result<List<PatientSummary>> result = await _repository
        .loadPatients();
    switch (result) {
      case Ok<List<PatientSummary>>(:final value):
        emit(
          state.copyWith(
            status: CensusStatus.ready,
            patients: value,
            clearError: true,
          ),
        );
      case Err<List<PatientSummary>>(:final failure):
        emit(
          state.copyWith(status: CensusStatus.failure, error: failure.message),
        );
    }
  }

  Future<void> _onAdd(
    PatientAddRequested event,
    Emitter<CensusState> emit,
  ) async {
    emit(state.copyWith(adding: true, clearAddError: true));
    final Result<PatientSummary> result = await _repository.addPatient(
      event.patient,
    );
    switch (result) {
      case Ok<PatientSummary>():
        emit(state.copyWith(adding: false, addedCount: state.addedCount + 1));
        add(const CensusRequested());
      case Err<PatientSummary>(:final failure):
        emit(state.copyWith(adding: false, addError: failure.message));
    }
  }

  Future<void> _onReorder(
    CensusReorderRequested event,
    Emitter<CensusState> emit,
  ) async {
    final List<PatientSummary> list = List<PatientSummary>.of(state.patients);
    if (event.oldIndex < 0 ||
        event.oldIndex >= list.length ||
        event.newIndex < 0 ||
        event.newIndex >= list.length ||
        event.oldIndex == event.newIndex) {
      return;
    }
    final PatientSummary moved = list.removeAt(event.oldIndex);
    list.insert(event.newIndex, moved);
    final List<PatientSummary> ordered = <PatientSummary>[
      for (int i = 0; i < list.length; i++) list[i].copyWith(sortOrder: i),
    ];
    emit(state.copyWith(patients: ordered, clearError: true));
    for (final PatientSummary p in ordered) {
      final Result<void> result = await _repository.setSortOrder(
        p.id,
        p.sortOrder,
      );
      if (result is Err<void>) {
        emit(
          state.copyWith(
            error: result.failure.message,
          ),
        );
        add(const CensusRequested());
        return;
      }
    }
  }
}
