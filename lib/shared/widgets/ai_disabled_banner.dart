import 'package:flutter/material.dart';
import 'package:round_ai/core/theme/app_colors.dart';
import 'package:round_ai/core/theme/app_typography.dart';

/// Shown above the app when `/me` says `ai_enabled` is false. The chart still
/// works. Only AI drafts are off.
class AiDisabledBanner extends StatelessWidget {
  const AiDisabledBanner({super.key});

  static const String message =
      'AI drafts are turned off for your account. You can still use the chart.';

  @override
  Widget build(BuildContext context) {
    final AppColors colors = AppColors.of(context);
    return Material(
      color: colors.warningSoft,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: <Widget>[
              Icon(Icons.cloud_off_rounded, size: 18, color: colors.warning),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  message,
                  style: AppTypography.medium(
                    fontSize: 12.5,
                    color: colors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
