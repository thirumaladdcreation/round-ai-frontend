import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:round_ai/core/errors/failures.dart';
import 'package:round_ai/core/errors/result.dart';
import 'package:round_ai/core/network/api_error.dart';
import 'package:round_ai/features/patient/models/patient_detail.dart';
import 'package:round_ai/features/patient/repository/patient_repository.dart';

sealed class PatientOverviewEvent extends Equatable {
  const PatientOverviewEvent();

  @override
  List<Object?> get props => <Object?>[];
}

/// First load, Retry, pull-to-refresh, and return from a chart-data screen.
class PatientOverviewRequested extends PatientOverviewEvent {
  const PatientOverviewRequested();
}

enum PatientOverviewStatus { loading, ready, failure }

class PatientOverviewState extends Equatable {
  const PatientOverviewState({
    this.status = PatientOverviewStatus.loading,
    this.detail,
    this.changes,
    this.changesFailed = false,
    this.error,
    this.accessDenied = false,
  });

  final PatientOverviewStatus status;
  final PatientDetail? detail;

  /// Null until loaded. A failed changes call does not hide the patient.
  final PatientChanges? changes;
  final bool changesFailed;
  final String? error;

  /// The user may not open this patient. The screen says so and goes back.
  final bool accessDenied;

  @override
  List<Object?> get props => <Object?>[
    status,
    detail,
    changes,
    changesFailed,
    error,
    accessDenied,
  ];
}

class PatientOverviewBloc
    extends Bloc<PatientOverviewEvent, PatientOverviewState> {
  PatientOverviewBloc(this._repository, this.patientId)
    : super(const PatientOverviewState()) {
    on<PatientOverviewRequested>(_onRequested);
  }

  final PatientRepository _repository;
  final String patientId;

  Future<void> _onRequested(
    PatientOverviewRequested event,
    Emitter<PatientOverviewState> emit,
  ) async {
    if (state.detail == null) emit(const PatientOverviewState());
    final List<Object> results = await Future.wait<Object>(<Future<Object>>[
      _repository.loadDetail(patientId),
      _repository.loadChanges(patientId),
    ]);
    final Result<PatientDetail> detail = results[0] as Result<PatientDetail>;
    final Result<PatientChanges> changes = results[1] as Result<PatientChanges>;

    switch (detail) {
      case Err<PatientDetail>(:final failure):
        final bool denied =
            failure is ApiFailure &&
            failure.error.kind == ApiErrorKind.accessDenied;
        emit(
          PatientOverviewState(
            status: PatientOverviewStatus.failure,
            detail: state.detail,
            error: failure.message,
            accessDenied: denied,
          ),
        );
      case Ok<PatientDetail>(:final value):
        emit(
          PatientOverviewState(
            status: PatientOverviewStatus.ready,
            detail: value,
            changes: changes is Ok<PatientChanges> ? changes.value : null,
            changesFailed: changes is Err<PatientChanges>,
          ),
        );
    }
  }
}
