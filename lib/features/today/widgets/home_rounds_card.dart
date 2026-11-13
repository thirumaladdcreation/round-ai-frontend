import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:round_ai/app/app_colors.dart';
import 'package:round_ai/app/app_typography.dart';
import 'package:round_ai/core/config/app_features.dart';
import 'package:round_ai/core/router/app_routes.dart';
import 'package:round_ai/features/today/models/home_snapshot.dart';
import 'package:round_ai/features/today/widgets/home_surface.dart';
import 'package:round_ai/shared/widgets/app_button.dart';

class HomeRoundsCard extends StatelessWidget {
  const HomeRoundsCard({required this.snapshot, super.key});

  final HomeSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final AppColors colors = AppColors.of(context);
    final String patients = snapshot.patientCount == 1
        ? '1 assigned patient'
        : '${snapshot.patientCount} assigned patients';
    return HomeSurface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            "Today's Rounds",
            style: AppTypography.sectionHeading(color: colors.navy),
          ),
          const SizedBox(height: 8),
          Text(
            patients,
            style: AppTypography.semiBold(
              fontSize: 15,
              color: colors.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            snapshot.roundsStatus,
            style: AppTypography.bodyMedium(color: colors.textSecondary),
          ),
          if (snapshot.latestChartStamp.isNotEmpty) ...<Widget>[
            const SizedBox(height: 4),
            Text(
              'Latest chart stamp · ${snapshot.latestChartStamp}',
              style: AppTypography.caption(color: colors.textMuted),
            ),
          ],
          const SizedBox(height: 16),
          // The live-rounds walk-through is demo-only. Without it the census
          // is where rounds start.
          if (AppFeatures.rounds) ...<Widget>[
            AppButton(
              label: 'Prepare for Rounds',
              onPressed: () => context.go(AppRoutes.rounds),
            ),
            const SizedBox(height: 4),
            Align(
              alignment: Alignment.center,
              child: TextButton(
                onPressed: () => context.go(AppRoutes.census),
                child: Text(
                  'View Patient Census',
                  style: AppTypography.medium(
                    fontSize: 14,
                    color: colors.primary,
                  ),
                ),
              ),
            ),
          ] else
            AppButton(
              label: 'View Patient Census',
              onPressed: () => context.go(AppRoutes.census),
            ),
        ],
      ),
    );
  }
}
