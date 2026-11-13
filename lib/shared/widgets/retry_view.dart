import 'package:flutter/material.dart';
import 'package:round_ai/core/theme/app_colors.dart';
import 'package:round_ai/core/theme/app_typography.dart';
import 'package:round_ai/shared/widgets/app_button.dart';

/// A failed load with a plain message and a retry button.
class RetryView extends StatelessWidget {
  const RetryView({
    required this.title,
    required this.message,
    required this.onRetry,
    super.key,
  });

  final String title;
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final AppColors colors = AppColors.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(Icons.cloud_off_outlined, color: colors.textMuted, size: 28),
            const SizedBox(height: 12),
            Text(
              title,
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
              style: AppTypography.regular(
                fontSize: 13,
                color: colors.textSecondary,
              ),
            ),
            const SizedBox(height: 20),
            AppButton(label: 'Try again', onPressed: onRetry, expand: false),
          ],
        ),
      ),
    );
  }
}
