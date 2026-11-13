import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:round_ai/core/errors/result.dart';
import 'package:round_ai/features/team_selection/bloc/team_selection_event.dart';
import 'package:round_ai/features/team_selection/bloc/team_selection_state.dart';
import 'package:round_ai/features/team_selection/models/clinical_team.dart';
import 'package:round_ai/features/team_selection/repository/team_repository.dart';

class TeamSelectionBloc extends Bloc<TeamSelectionEvent, TeamSelectionState> {
  TeamSelectionBloc(this._repository) : super(const TeamSelectionState()) {
    on<TeamSelectionStarted>(_onStarted);
    on<TeamChosen>(_onChosen);
    on<TeamContinuePressed>(_onContinue);
  }

  final TeamRepository _repository;

  Future<void> _onStarted(
    TeamSelectionStarted event,
    Emitter<TeamSelectionState> emit,
  ) async {
    final Result<List<ClinicalTeam>> result = await _repository
        .loadAuthorizedTeams();
    switch (result) {
      case Err<List<ClinicalTeam>>(:final failure):
        emit(state.copyWith(loading: false, error: failure.message));
      case Ok<List<ClinicalTeam>>(:final value):
        await _showTeams(value, emit);
    }
  }

  Future<void> _showTeams(
    List<ClinicalTeam> teams,
    Emitter<TeamSelectionState> emit,
  ) async {
    if (teams.isEmpty) {
      emit(
        state.copyWith(
          loading: false,
          teams: teams,
          error: 'No team is assigned to this account.',
        ),
      );
      return;
    }
    if (teams.length == 1) {
      await _open(teams.first.id, teams, emit);
      return;
    }
    final String? saved = _repository.savedTeamId;
    final bool savedAllowed = teams.any(
      (ClinicalTeam team) => team.id == saved,
    );
    emit(
      state.copyWith(
        loading: false,
        teams: teams,
        selectedId: savedAllowed ? saved : teams.first.id,
        clearError: true,
      ),
    );
  }

  void _onChosen(TeamChosen event, Emitter<TeamSelectionState> emit) {
    final bool allowed = state.teams.any(
      (ClinicalTeam team) => team.id == event.teamId,
    );
    if (!allowed) return;
    emit(state.copyWith(selectedId: event.teamId));
  }

  Future<void> _onContinue(
    TeamContinuePressed event,
    Emitter<TeamSelectionState> emit,
  ) async {
    final String? teamId = state.selectedId;
    if (teamId == null) return;
    await _open(teamId, state.teams, emit);
  }

  Future<void> _open(
    String teamId,
    List<ClinicalTeam> teams,
    Emitter<TeamSelectionState> emit,
  ) async {
    emit(state.copyWith(loading: true, clearError: true));
    final Result<void> saved = await _repository.saveSelectedTeam(teamId);
    saved.when(
      ok: (_) => emit(
        state.copyWith(
          loading: false,
          teams: teams,
          selectedId: teamId,
          openDashboard: true,
          clearError: true,
        ),
      ),
      err: (failure) => emit(
        state.copyWith(loading: false, teams: teams, error: failure.message),
      ),
    );
  }
}
