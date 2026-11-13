import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:round_ai/core/config/app_environment.dart';
import 'package:round_ai/core/router/app_routes.dart';
import 'package:round_ai/core/theme/app_colors.dart';
import 'package:round_ai/core/theme/app_typography.dart';

/// Entry points for chart data: source text, fact review, manual facts and
/// the plan. It explains why this comes first: AI only uses confirmed facts.
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
    // A screen can hand back the next one to open, such as fact review
    // after reading facts from a source.
    if (next is String && context.mounted) await context.push<Object>(next);
    onChanged();
  }

  @override
  Widget build(BuildContext context) {
    final AppColors colors = AppColors.of(context);
    final bool intake = !AppEnvironment.useDemo;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text('Chart data', style: AppTypography.semiBold(fontSize: 15)),
          const SizedBox(height: 6),
          Text(
            'AI only uses chart facts you have confirmed. Add the chart text, '
            'check the facts read from it, then confirm them.',
            style: AppTypography.regular(
              fontSize: 13,
              height: 1.4,
              color: colors.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          if (intake) ...<Widget>[
            Text(
              'Add info',
              style: AppTypography.semiBold(
                fontSize: 13,
                color: colors.textPrimary,
              ),
            ),
            _Row(
              icon: Icons.mic_none_outlined,
              label: 'Dictate',
              onTap: () => _open(
                context,
                AppRoutes.patientIntakeDictatePath(patientId),
              ),
            ),
            _Row(
              icon: Icons.photo_camera_outlined,
              label: 'Photo',
              onTap: () =>
                  _open(context, AppRoutes.patientIntakePhotoPath(patientId)),
            ),
          ],
          _Row(
            icon: Icons.note_add_outlined,
            label: 'Add source text',
            onTap: () =>
                _open(context, AppRoutes.patientAddSourcePath(patientId)),
          ),
          _Row(
            icon: Icons.fact_check_outlined,
            label: unreviewedFacts == 0
                ? 'Review chart facts'
                : 'Review chart facts ($unreviewedFacts waiting)',
            highlight: unreviewedFacts > 0,
            onTap: () => _open(context, AppRoutes.patientFactsPath(patientId)),
          ),
          _Row(
            icon: Icons.edit_outlined,
            label: 'Add a fact by hand',
            onTap: () =>
                _open(context, AppRoutes.patientAddFactPath(patientId)),
          ),
          _Row(
            icon: Icons.checklist_rounded,
            label: "Edit today's plan",
            onTap: () => _open(context, AppRoutes.patientPlanPath(patientId)),
          ),
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({
    required this.icon,
    required this.label,
    required this.onTap,
    this.highlight = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final AppColors colors = AppColors.of(context);
    return ListTile(
      contentPadding: EdgeInsets.zero,
      dense: true,
      leading: Icon(icon, color: highlight ? colors.warning : colors.primary),
      title: Text(
        label,
        style: AppTypography.medium(fontSize: 14, color: colors.textPrimary),
      ),
      trailing: Icon(Icons.chevron_right_rounded, color: colors.textMuted),
      onTap: onTap,
    );
  }
}
