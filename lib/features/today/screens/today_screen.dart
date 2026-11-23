import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:round_ai/app/app_colors.dart';
import 'package:round_ai/core/constants/app_assets.dart';
import 'package:round_ai/core/di/injection_container.dart';
import 'package:round_ai/core/theme/app_spacing.dart';
import 'package:round_ai/features/today/bloc/home_bloc.dart';
import 'package:round_ai/features/today/bloc/home_event.dart';
import 'package:round_ai/features/today/bloc/home_state.dart';
import 'package:round_ai/features/today/models/home_snapshot.dart';
import 'package:round_ai/features/today/repository/home_repository.dart';
import 'package:round_ai/features/today/widgets/home_census_preview.dart';
import 'package:round_ai/features/today/widgets/home_header.dart';
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

class HomeView extends StatefulWidget {
  const HomeView({super.key});

  @override
  State<HomeView> createState() => _HomeViewState();
}

class _HomeViewState extends State<HomeView> {
  ValueNotifier<int>? _sync;
  int _seen = 0;

  @override
  void initState() {
    super.initState();
    try {
      _sync = InjectionContainer.instance.censusSync.revision;
      _seen = _sync!.value;
      _sync!.addListener(_onCensusSync);
    } catch (_) {}
  }

  void _onCensusSync() {
    final ValueNotifier<int>? sync = _sync;
    if (sync == null || !mounted) return;
    if (sync.value == _seen) return;
    _seen = sync.value;
    context.read<HomeBloc>().add(const HomeRefreshed());
  }

  @override
  void dispose() {
    _sync?.removeListener(_onCensusSync);
    super.dispose();
  }

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
  @override
  Widget build(BuildContext context) {
    final HomeSnapshot snapshot = widget.snapshot;
    final AppColors colors = AppColors.of(context);
    final bool dark = Theme.of(context).brightness == Brightness.dark;
    final String bg = dark
        ? AppAssets.loginBackgroundDark
        : AppAssets.loginIllustration;

    return Material(
      color: colors.background,
      child: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          Align(
            alignment: Alignment.topCenter,
            child: SizedBox(
              height: 240,
              width: double.infinity,
              child: Stack(
                fit: StackFit.expand,
                children: <Widget>[
                  Image.asset(
                    bg,
                    fit: BoxFit.cover,
                    alignment: Alignment.centerRight,
                  ),
                  BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 2, sigmaY: 2),
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: <Color>[
                            colors.background.withValues(
                              alpha: dark ? 0.55 : 0.35,
                            ),
                            colors.background.withValues(
                              alpha: dark ? 0.72 : 0.55,
                            ),
                            colors.background.withValues(alpha: 0.92),
                            colors.background,
                          ],
                          stops: const <double>[0, 0.35, 0.72, 1],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          SafeArea(
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
                  4,
                  AppSpacing.md,
                  28,
                ),
                children: <Widget>[
                  HomeHeader(
                    snapshot: snapshot,
                    onNotifications: () {},
                  ),
                  const SizedBox(height: 18),
                  // Patient list is the only focus on Today (P3).
                  HomeCensusPreview(snapshot: snapshot),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
