import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:round_ai/app/app_colors.dart';
import 'package:round_ai/app/app_typography.dart';
import 'package:round_ai/features/team_selection/bloc/team_selection_bloc.dart';
import 'package:round_ai/features/team_selection/bloc/team_selection_event.dart';
import 'package:round_ai/features/team_selection/bloc/team_selection_state.dart';
import 'package:round_ai/features/team_selection/models/clinical_team.dart';
import 'package:round_ai/features/team_selection/widgets/team_card.dart';
import 'package:round_ai/shared/widgets/skeleton.dart';

class TeamSelectionList extends StatelessWidget {
  const TeamSelectionList({super.key});

  @override
  Widget build(BuildContext context) {
    final TeamSelectionState state = context.watch<TeamSelectionBloc>().state;
    final AppPalette palette = AppPalette.of(context);

    if (state.loading && state.teams.isEmpty) {
      return const SkeletonColumn(count: 2);
    }
    if (state.teams.isEmpty) {
      return Text(
        state.error ?? 'No team is assigned to this account.',
        style: AppTypography.bodyMedium(color: palette.textSecondary),
      );
    }

    return ListView.separated(
      itemCount: state.teams.length,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (BuildContext context, int index) {
        final ClinicalTeam team = state.teams[index];
        return TeamCard(
          team: team,
          selected: team.id == state.selectedId,
          onTap: () =>
              context.read<TeamSelectionBloc>().add(TeamChosen(team.id)),
        );
      },
    );
  }
}
