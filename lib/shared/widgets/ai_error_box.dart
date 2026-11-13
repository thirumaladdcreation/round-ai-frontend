import 'package:flutter/material.dart';
import 'package:round_ai/core/network/api_error.dart';
import 'package:round_ai/core/theme/app_colors.dart';
import 'package:round_ai/core/theme/app_typography.dart';

/// A failed request in our own words. The server's text is never shown.
class AiErrorBox extends StatelessWidget {
  const AiErrorBox({
    required this.error,
    this.sections = 0,
    this.onRetry,
    this.onReviewFacts,
    super.key,
  });

  final ApiError error;

  /// How many sections are marked on screen, when the server named some.
  final int sections;
  final VoidCallback? onRetry;
  final VoidCallback? onReviewFacts;

  @override
  Widget build(BuildContext context) {
    final AppColors colors = AppColors.of(context);
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: colors.criticalBg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            error.userMessage,
            style: AppTypography.regular(fontSize: 13, color: colors.critical),
          ),
          if (sections > 0)
            Text(
              sections == 1
                  ? '1 section is marked.'
                  : '$sections sections are marked.',
              style: AppTypography.regular(
                fontSize: 12,
                color: colors.critical,
              ),
            ),
          if (onReviewFacts != null)
            TextButton(
              onPressed: onReviewFacts,
              child: const Text('Review chart facts first'),
            ),
          if (onRetry != null)
            TextButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    );
  }
}

/// "Writing... Cancel" row for the long AI calls.
class AiProgressRow extends StatelessWidget {
  const AiProgressRow({
    required this.message,
    required this.onCancel,
    super.key,
  });

  final String message;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final AppColors colors = AppColors.of(context);
    return Row(
      children: <Widget>[
        const SizedBox(
          width: 18,
          height: 18,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            message,
            style: AppTypography.regular(
              fontSize: 12,
              color: colors.textSecondary,
            ),
          ),
        ),
        TextButton(onPressed: onCancel, child: const Text('Cancel')),
      ],
    );
  }
}
