import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:round_ai/app/app_colors.dart';
import 'package:round_ai/app/app_typography.dart';
import 'package:round_ai/core/di/injection_container.dart';
import 'package:round_ai/core/theme/app_spacing.dart';
import 'package:round_ai/features/today/bloc/home_bloc.dart';
import 'package:round_ai/features/today/bloc/home_event.dart';
import 'package:round_ai/features/today/bloc/home_state.dart';
import 'package:round_ai/features/today/models/home_snapshot.dart';
import 'package:round_ai/features/today/repository/home_repository.dart';
import 'package:round_ai/features/today/widgets/home_attention_section.dart';
import 'package:round_ai/features/today/widgets/home_census_preview.dart';
import 'package:round_ai/features/today/widgets/home_header.dart';
import 'package:round_ai/features/today/widgets/home_morning_brief.dart';
import 'package:round_ai/features/today/widgets/home_overview.dart';
import 'package:round_ai/features/today/widgets/home_quick_actions.dart';
import 'package:round_ai/features/today/widgets/home_rounds_card.dart';
import 'package:round_ai/features/today/widgets/home_status_view.dart';

class TodayScreen extends StatelessWidget {
  const TodayScreen({this.repository, super.key});

  final HomeRepository? repository;

  @override
  Widget build(BuildContext context) {
    final HomeRepository source =
        repository ?? InjectionContainer.instance.homeRepository;
    return BlocProvider<HomeBloc>(
      create: (_) => HomeBloc(source)..add(const HomeRequested()),
      child: const HomeView(),
    );
  }
}

class HomeView extends StatelessWidget {
  const HomeView({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<HomeBloc, HomeState>(
      builder: (BuildContext context, HomeState state) {
        return switch (state) {
          HomeLoading() => const HomeLoadingView(),
          HomeFailure(:final String message) => HomeFailureView(
            message: message,
            onRetry: () => context.read<HomeBloc>().add(const HomeRequested()),
          ),
          HomeReady(:final HomeSnapshot snapshot) => HomeDashboard(
            snapshot: snapshot,
          ),
        };
      },
    );
  }
}

class HomeDashboard extends StatefulWidget {
  const HomeDashboard({required this.snapshot, super.key});

  final HomeSnapshot snapshot;

  @override
  State<HomeDashboard> createState() => HomeDashboardState();
}

class HomeDashboardState extends State<HomeDashboard> {
  final GlobalKey _attentionKey = GlobalKey();

  @override
  Widget build(BuildContext context) {
    final HomeSnapshot snapshot = widget.snapshot;
    final AppColors colors = AppColors.of(context);
    return Material(
      color: colors.background,
      child: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          onRefresh: () {
            final Completer<void> done = Completer<void>();
            context.read<HomeBloc>().add(HomeRefreshed(done: done));
            return done.future;
          },
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              8,
              AppSpacing.md,
              24,
            ),
            children: <Widget>[
              HomeHeader(
                snapshot: snapshot,
                onNotifications: () {
                  final BuildContext? target = _attentionKey.currentContext;
                  if (target == null) return;
                  Scrollable.ensureVisible(
                    target,
                    duration: const Duration(milliseconds: 250),
                  );
                },
              ),
              if (snapshot.isSynthetic) ...<Widget>[
                const SizedBox(height: 8),
                Text(
                  'Synthetic team list. Nothing here is a signed note.',
                  style: AppTypography.caption(color: colors.textMuted),
                ),
              ],
              const SizedBox(height: 20),
              HomeMorningBrief(snapshot: snapshot),
              HomeOverview(snapshot: snapshot),
              const SizedBox(height: 16),
              HomeRoundsCard(snapshot: snapshot),
              const SizedBox(height: 20),
              HomeCensusPreview(snapshot: snapshot),
              const SizedBox(height: 12),
              KeyedSubtree(
                key: _attentionKey,
                child: HomeAttentionSection(snapshot: snapshot),
              ),
              const SizedBox(height: 12),
              HomeQuickActions(snapshot: snapshot),
            ],
          ),
        ),
      ),
    );
  }
}
