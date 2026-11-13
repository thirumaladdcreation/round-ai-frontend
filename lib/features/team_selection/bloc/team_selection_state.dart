import 'package:equatable/equatable.dart';
import 'package:round_ai/features/team_selection/models/clinical_team.dart';

class TeamSelectionState extends Equatable {
  const TeamSelectionState({
    this.loading = true,
    this.teams = const <ClinicalTeam>[],
    this.selectedId,
    this.error,
    this.openDashboard = false,
  });

  final bool loading;
  final List<ClinicalTeam> teams;
  final String? selectedId;
  final String? error;
  final bool openDashboard;

  TeamSelectionState copyWith({
    bool? loading,
    List<ClinicalTeam>? teams,
    String? selectedId,
    String? error,
    bool clearError = false,
    bool? openDashboard,
  }) {
    return TeamSelectionState(
      loading: loading ?? this.loading,
      teams: teams ?? this.teams,
      selectedId: selectedId ?? this.selectedId,
      error: clearError ? null : error ?? this.error,
      openDashboard: openDashboard ?? this.openDashboard,
    );
  }

  @override
  List<Object?> get props => <Object?>[
    loading,
    teams,
    selectedId,
    error,
    openDashboard,
  ];
}
