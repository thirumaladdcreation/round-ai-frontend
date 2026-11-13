import 'package:flutter/material.dart';
import 'package:round_ai/app/app_colors.dart';
import 'package:round_ai/app/app_typography.dart';
import 'package:round_ai/features/today/models/home_snapshot.dart';
import 'package:round_ai/features/today/widgets/home_surface.dart';

class HomeOverview extends StatelessWidget {
  const HomeOverview({required this.snapshot, super.key});

  final HomeSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(
              child: HomeStatCard(
                icon: Icons.people_alt_outlined,
                value: snapshot.patientCount,
                label: 'Assigned patients',
                emptyLabel: 'None assigned',
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: HomeStatCard(
                icon: Icons.fact_check_outlined,
                value: snapshot.pendingTaskCount,
                label: 'Pending tasks',
                emptyLabel: 'No pending tasks',
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: HomeStatCard(
                icon: Icons.edit_note_outlined,
                value: snapshot.draftsAwaitingReview,
                label: 'Drafts to review',
                emptyLabel: 'No drafts waiting',
              ),
            ),
          ],
        ),
        if (snapshot.draftsAwaitingReview == 0) ...<Widget>[
          const SizedBox(height: 8),
          const HomeDraftNote(),
        ],
      ],
    );
  }
}

class HomeStatCard extends StatelessWidget {
  const HomeStatCard({
    required this.icon,
    required this.value,
    required this.label,
    required this.emptyLabel,
    super.key,
  });

  final IconData icon;
  final int value;
  final String label;
  final String emptyLabel;

  @override
  Widget build(BuildContext context) {
    final AppColors colors = AppColors.of(context);
    return HomeSurface(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(icon, size: 18, color: colors.primary),
          const SizedBox(height: 10),
          Text(
            '$value',
            style: AppTypography.bold(
              fontSize: 22,
              height: 1,
              color: colors.navy,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value == 0 ? emptyLabel : label,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.caption(color: colors.textSecondary),
          ),
        ],
      ),
    );
  }
}

class HomeDraftNote extends StatelessWidget {
  const HomeDraftNote({super.key});

  @override
  Widget build(BuildContext context) {
    final AppColors colors = AppColors.of(context);
    return Text(
      'No generated draft is on this list. A draft stays labeled until a clinician reviews it.',
      style: AppTypography.caption(color: colors.textMuted),
    );
  }
}
