import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:round_ai/app/app_colors.dart';
import 'package:round_ai/app/app_typography.dart';
import 'package:round_ai/features/today/models/home_snapshot.dart';
import 'package:round_ai/features/today/widgets/home_section_title.dart';
import 'package:round_ai/features/today/widgets/home_surface.dart';

class HomeAttentionSection extends StatelessWidget {
  const HomeAttentionSection({required this.snapshot, super.key});

  final HomeSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const HomeSectionTitle(title: 'Needs your attention'),
        if (snapshot.attention.isEmpty)
          const HomeSurface(child: Text('Nothing is waiting on this list.'))
        else
          ...snapshot.attention.map(
            (HomeAttentionItem item) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: HomeAttentionTile(item: item),
            ),
          ),
        if (snapshot.pendingTaskCount == 0)
          Text(
            'No pending tasks.',
            style: AppTypography.bodySmall(
              color: AppColors.of(context).textSecondary,
            ),
          ),
      ],
    );
  }
}

class HomeAttentionTile extends StatelessWidget {
  const HomeAttentionTile({required this.item, super.key});

  final HomeAttentionItem item;

  @override
  Widget build(BuildContext context) {
    final AppColors colors = AppColors.of(context);
    final String? extra = _extra(item);
    return HomeSurface(
      onTap: () => context.push(item.route),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  item.title,
                  style: AppTypography.semiBold(
                    fontSize: 14,
                    color: colors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  item.detail,
                  style: AppTypography.bodySmall(color: colors.textSecondary),
                ),
                if (extra != null) ...<Widget>[
                  const SizedBox(height: 4),
                  Text(
                    extra,
                    style: AppTypography.caption(color: colors.textMuted),
                  ),
                ],
              ],
            ),
          ),
          Icon(Icons.chevron_right_rounded, color: colors.textMuted),
        ],
      ),
    );
  }

  String? _extra(HomeAttentionItem item) {
    final List<String> parts = <String>[
      if (item.owner != null && item.owner!.trim().isNotEmpty)
        'Owner ${item.owner}',
      if (item.dueLabel != null && item.dueLabel!.trim().isNotEmpty)
        'Due ${item.dueLabel}',
    ];
    if (parts.isEmpty) return null;
    return parts.join(' · ');
  }
}
