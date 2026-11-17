import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:round_ai/app/app_colors.dart';
import 'package:round_ai/app/app_typography.dart';
import 'package:round_ai/core/config/app_features.dart';
import 'package:round_ai/core/router/app_routes.dart';
import 'package:round_ai/features/today/models/home_snapshot.dart';
import 'package:round_ai/features/today/widgets/home_surface.dart';
import 'package:round_ai/shared/widgets/app_button.dart';

/// One primary path into rounds work: the census list.
/// Prepare-for-rounds stays secondary when the feature flag is on.
class HomeRoundsCard extends StatelessWidget {
  const HomeRoundsCard({required this.snapshot, super.key});

  final HomeSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final AppColors colors = AppColors.of(context);
    final String patients = snapshot.patientCount == 1
        ? '1 patient'
        : '${snapshot.patientCount} patients';
    return HomeSurface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
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
          const SizedBox(height: 14),
          AppButton(
            label: 'Open census',
            onPressed: () => context.go(AppRoutes.census),
          ),
          if (AppFeatures.rounds) ...<Widget>[
            const SizedBox(height: 4),
            Align(
              alignment: Alignment.center,
              child: TextButton(
                onPressed: () => context.go(AppRoutes.rounds),
                child: Text(
                  'Prepare for rounds',
                  style: AppTypography.medium(
                    fontSize: 14,
                    color: colors.primary,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
