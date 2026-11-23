import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:round_ai/app/app_colors.dart';
import 'package:round_ai/app/app_typography.dart';
import 'package:round_ai/core/constants/app_assets.dart';
import 'package:round_ai/core/di/injection_container.dart';
import 'package:round_ai/core/router/app_routes.dart';
import 'package:round_ai/features/team_selection/bloc/team_selection_bloc.dart';
import 'package:round_ai/features/team_selection/bloc/team_selection_event.dart';
import 'package:round_ai/features/team_selection/bloc/team_selection_state.dart';
import 'package:round_ai/features/team_selection/repository/team_repository.dart';
import 'package:round_ai/features/team_selection/widgets/team_selection_list.dart';
import 'package:round_ai/shared/widgets/app_button.dart';

class SelectTeamScreen extends StatelessWidget {
  const SelectTeamScreen({this.repository, super.key});

  final TeamRepository? repository;

  @override
  Widget build(BuildContext context) {
    final TeamRepository source =
        repository ?? InjectionContainer.instance.teamRepository;
    return BlocProvider<TeamSelectionBloc>(
      create: (_) =>
          TeamSelectionBloc(source)..add(const TeamSelectionStarted()),
      child: const TeamSelectionView(),
    );
  }
}

class TeamSelectionView extends StatelessWidget {
  const TeamSelectionView({super.key});

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = AppPalette.of(context);
    return BlocListener<TeamSelectionBloc, TeamSelectionState>(
      listenWhen: (_, TeamSelectionState next) => next.openDashboard,
      listener: (BuildContext context, TeamSelectionState state) {
        context.go(AppRoutes.census);
      },
      child: Scaffold(
        backgroundColor: palette.background,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                IconButton(
                  tooltip: 'Back',
                  onPressed: () => context.go(AppRoutes.signIn),
                  icon: Icon(
                    Icons.arrow_back_rounded,
                    color: palette.textPrimary,
                  ),
                ),
                const TeamSelectionBanner(),
                const SizedBox(height: 16),
                Text(
                  'Select Your Team',
                  style: AppTypography.screenHeading(color: palette.navy),
                ),
                const SizedBox(height: 6),
                Text(
                  'Choose the team to access patient information.',
                  style: AppTypography.bodyMedium(color: palette.textSecondary),
                ),
                const SizedBox(height: 18),
                const Expanded(child: TeamSelectionList()),
                const SizedBox(height: 12),
                const TeamSelectionContinueButton(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class TeamSelectionBanner extends StatelessWidget {
  const TeamSelectionBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: const SizedBox(
        height: 120,
        width: double.infinity,
        child: Image(
          image: AssetImage(AppAssets.loginIllustration),
          fit: BoxFit.cover,
          alignment: Alignment.topRight,
        ),
      ),
    );
  }
}

class TeamSelectionContinueButton extends StatelessWidget {
  const TeamSelectionContinueButton({super.key});

  @override
  Widget build(BuildContext context) {
    final TeamSelectionState state = context.watch<TeamSelectionBloc>().state;
    final bool canContinue = state.selectedId != null && state.teams.isNotEmpty;
    return AppButton(
      label: 'Continue',
      showArrow: true,
      loading: state.loading && state.teams.isNotEmpty,
      onPressed: canContinue && !state.loading
          ? () => context.read<TeamSelectionBloc>().add(
              const TeamContinuePressed(),
            )
          : null,
    );
  }
}
