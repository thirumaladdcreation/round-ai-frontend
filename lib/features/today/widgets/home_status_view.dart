import 'package:flutter/material.dart';
import 'package:round_ai/app/app_colors.dart';
import 'package:round_ai/app/app_typography.dart';
import 'package:round_ai/shared/widgets/app_button.dart';
import 'package:round_ai/shared/widgets/skeleton.dart';

class HomeLoadingView extends StatelessWidget {
  const HomeLoadingView({super.key});

  @override
  Widget build(BuildContext context) {
    final AppColors colors = AppColors.of(context);
    return Material(
      color: colors.background,
      child: const SafeArea(child: SkeletonList(count: 4)),
    );
  }
}

class HomeFailureView extends StatelessWidget {
  const HomeFailureView({
    required this.message,
    required this.onRetry,
    super.key,
  });

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final AppColors colors = AppColors.of(context);
    return Material(
      color: colors.background,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Icon(Icons.cloud_off_outlined, color: colors.textMuted, size: 28),
              const SizedBox(height: 12),
              Text(
                'The home list could not be loaded.',
                textAlign: TextAlign.center,
                style: AppTypography.semiBold(
                  fontSize: 16,
                  color: colors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                message,
                textAlign: TextAlign.center,
                style: AppTypography.bodySmall(color: colors.textSecondary),
              ),
              const SizedBox(height: 20),
              AppButton(label: 'Try again', onPressed: onRetry),
            ],
          ),
        ),
      ),
    );
  }
}
