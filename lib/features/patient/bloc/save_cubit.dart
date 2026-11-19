import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:round_ai/core/errors/result.dart';
import 'package:round_ai/core/sync/census_sync_mark.dart';
import 'package:round_ai/features/patient/models/plan_structured.dart';
import 'package:round_ai/features/patient/repository/chart_data_repository.dart';
import 'package:round_ai/features/patient/repository/patient_repository.dart';

/// State of a one-shot save: a manual fact or the plan.
class SaveState extends Equatable {
  const SaveState({this.saving = false, this.error, this.saved = false});

  final bool saving;
  final String? error;
  final bool saved;

  @override
  List<Object?> get props => <Object?>[saving, error, saved];
}

class _SaveCubit extends Cubit<SaveState> {
  _SaveCubit() : super(const SaveState());

  Future<void> run(Future<Result<void>> Function() action) async {
    if (state.saving) return;
    emit(const SaveState(saving: true));
    final Result<void> result = await action();
    switch (result) {
      case Err<void>(:final failure):
        emit(SaveState(error: failure.message));
      case Ok<void>():
        markCensusDirty();
        emit(const SaveState(saved: true));
    }
  }
}

/// Manual fact entry. The fact starts as pending like any other.
class ManualFactCubit extends _SaveCubit {
  ManualFactCubit(this._repository, this.patientId);

  final ChartDataRepository _repository;
  final String patientId;

  Future<void> save(NewFact fact) =>
      run(() => _repository.addFact(patientId, fact));
}

/// Plan editor. The plan is typed by the clinician. AI never writes it.
class PlanEditorCubit extends _SaveCubit {
  PlanEditorCubit(this._repository, this.patientId);

  final PatientRepository _repository;
  final String patientId;

  Future<void> save(List<String> lines) =>
      run(() => _repository.savePlan(patientId, lines));

  Future<void> saveStructured(PlanStructured plan) =>
      run(() => _repository.saveStructuredPlan(patientId, plan));
}
