import 'package:equatable/equatable.dart';
import 'package:round_ai/features/census/repository/census_repository.dart';

sealed class CensusEvent extends Equatable {
  const CensusEvent();

  @override
  List<Object?> get props => <Object?>[];
}

/// First load, Retry and pull-to-refresh.
class CensusRequested extends CensusEvent {
  const CensusRequested();
}

class PatientAddRequested extends CensusEvent {
  const PatientAddRequested(this.patient);

  final NewPatient patient;

  @override
  List<Object?> get props => <Object?>[
    patient.teamId,
    patient.displayName,
    patient.room,
  ];
}

/// Drag-reorder: [oldIndex] moved to [newIndex] in the visible list.
class CensusReorderRequested extends CensusEvent {
  const CensusReorderRequested({
    required this.oldIndex,
    required this.newIndex,
  });

  final int oldIndex;
  final int newIndex;

  @override
  List<Object?> get props => <Object?>[oldIndex, newIndex];
}
