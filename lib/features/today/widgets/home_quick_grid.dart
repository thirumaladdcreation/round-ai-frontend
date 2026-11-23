import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:round_ai/app/app_colors.dart';
import 'package:round_ai/app/app_typography.dart';
import 'package:round_ai/core/router/app_routes.dart';

/// Four quick actions in one horizontal row.
class HomeQuickGrid extends StatelessWidget {
  const HomeQuickGrid({super.key});

  @override
  Widget build(BuildContext context) {
    final AppColors colors = AppColors.of(context);
    final bool dark = Theme.of(context).brightness == Brightness.dark;
    final List<_QuickItem> items = <_QuickItem>[
      _QuickItem(
        label: 'My Patients',
        icon: Icons.assignment_outlined,
        tint: const Color(0xFF087CFF),
        soft: const Color(0xFFE8F3FF),
        onTap: () => context.go(AppRoutes.census),
      ),
      _QuickItem(
        label: 'AI Monitoring',
        icon: Icons.monitor_heart_outlined,
        tint: const Color(0xFF0A8F9C),
        soft: const Color(0xFFD6F3F6),
        onTap: () => context.go(AppRoutes.rounds),
      ),
      _QuickItem(
        label: 'Analytics',
        icon: Icons.insights_outlined,
        tint: const Color(0xFF6B5CE7),
        soft: const Color(0xFFF0EEFF),
        onTap: () => context.go(AppRoutes.learning),
      ),
      _QuickItem(
        label: 'Settings',
        icon: Icons.settings_outlined,
        tint: const Color(0xFF5B6B7A),
        soft: const Color(0xFFEEF2F5),
        onTap: () => context.go(AppRoutes.profile),
      ),
    ];

    return Row(
      children: <Widget>[
        for (int i = 0; i < items.length; i++) ...<Widget>[
          if (i > 0) const SizedBox(width: 8),
          Expanded(
            child: Material(
              color: colors.surface,
              borderRadius: BorderRadius.circular(16),
              child: InkWell(
                onTap: items[i].onTap,
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  padding: const EdgeInsets.fromLTRB(6, 12, 6, 10),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: colors.border),
                    boxShadow: <BoxShadow>[
                      BoxShadow(
                        color: colors.navy.withValues(alpha: 0.05),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: dark
                              ? items[i].tint.withValues(alpha: 0.18)
                              : items[i].soft,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          items[i].icon,
                          color: items[i].tint,
                          size: 22,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        items[i].label,
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.semiBold(
                          fontSize: 11,
                          height: 1.2,
                          color: colors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _QuickItem {
  const _QuickItem({
    required this.label,
    required this.icon,
    required this.tint,
    required this.soft,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final Color tint;
  final Color soft;
  final VoidCallback onTap;
}
