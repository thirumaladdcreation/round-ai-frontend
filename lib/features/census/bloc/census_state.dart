import 'package:equatable/equatable.dart';
import 'package:round_ai/features/census/models/patient_summary.dart';

enum CensusStatus { loading, ready, failure }

class CensusState extends Equatable {
  const CensusState({
    this.status = CensusStatus.loading,
    this.patients = const <PatientSummary>[],
    this.error,
    this.adding = false,
    this.addError,
    this.addedCount = 0,
  });

  final CensusStatus status;

  /// Ordered by room.
  final List<PatientSummary> patients;

  /// Plain message for the load failure.
  final String? error;

  final bool adding;
  final String? addError;

  /// Goes up each time a patient is added. The screen closes the sheet on it.
  final int addedCount;

  CensusState copyWith({
    CensusStatus? status,
    List<PatientSummary>? patients,
    String? error,
    bool clearError = false,
    bool? adding,
    String? addError,
    bool clearAddError = false,
    int? addedCount,
  }) {
    return CensusState(
      status: status ?? this.status,
      patients: patients ?? this.patients,
      error: clearError ? null : (error ?? this.error),
      adding: adding ?? this.adding,
      addError: clearAddError ? null : (addError ?? this.addError),
      addedCount: addedCount ?? this.addedCount,
    );
  }

  @override
  List<Object?> get props => <Object?>[
    status,
    patients,
    error,
    adding,
    addError,
    addedCount,
  ];
}
