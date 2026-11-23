import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:round_ai/core/router/app_routes.dart';
import 'package:round_ai/core/theme/app_colors.dart';
import 'package:round_ai/core/theme/app_typography.dart';

/// Compact chart-facts entry. Dictation / photo / paste live under Add update.
class ChartDataCard extends StatelessWidget {
  const ChartDataCard({
    required this.patientId,
    required this.unreviewedFacts,
    required this.onChanged,
    super.key,
  });

  final String patientId;
  final int unreviewedFacts;

  /// Called when a data-entry screen closes, so the overview can reload.
  final VoidCallback onChanged;

  Future<void> _open(BuildContext context, String path) async {
    final Object? next = await context.push<Object>(path);
    if (next is String && context.mounted) await context.push<Object>(next);
    onChanged();
  }

  @override
  Widget build(BuildContext context) {
    final AppColors colors = AppColors.of(context);
    if (unreviewedFacts <= 0) {
      return const SizedBox.shrink();
    }
    return Material(
      color: colors.warningSoft,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _open(context, AppRoutes.patientFactsPath(patientId)),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: colors.border),
          ),
          child: Row(
            children: <Widget>[
              Icon(Icons.fact_check_outlined, color: colors.warning),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  '$unreviewedFacts chart fact${unreviewedFacts == 1 ? '' : 's'} waiting for review',
                  style: AppTypography.semiBold(
                    fontSize: 14,
                    color: colors.textPrimary,
                  ),
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: colors.textSecondary),
            ],
          ),
        ),
      ),
    );
  }
}
