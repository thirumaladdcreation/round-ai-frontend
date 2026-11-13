import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:round_ai/app/app_colors.dart';
import 'package:round_ai/app/app_typography.dart';
import 'package:round_ai/core/config/app_features.dart';
import 'package:round_ai/core/router/app_routes.dart';
import 'package:round_ai/features/rounds/models/round_brief.dart';
import 'package:round_ai/features/today/models/home_snapshot.dart';

/// Morning brief from deterministic `GET /round/brief` counts.
/// No urgency language — only chart-derived counts.
class HomeMorningBrief extends StatelessWidget {
  const HomeMorningBrief({required this.snapshot, super.key});

  final HomeSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    if (snapshot.patientCount == 0 && snapshot.briefCounts.patients == 0) {
      return const SizedBox.shrink();
    }
    final AppColors colors = AppColors.of(context);
    final RoundBriefCounts counts = snapshot.briefCounts;
    final List<String> lines = counts.lines;
    final String headline = counts.headline;
    final HomePatientPreview? next =
        snapshot.patients.isEmpty ? null : snapshot.patients.first;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: RoundsBrand.slate,
            borderRadius: BorderRadius.circular(22),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  const Icon(
                    Icons.auto_awesome_rounded,
                    size: 14,
                    color: RoundsBrand.aqua,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'MORNING BRIEF',
                    style: AppTypography.semiBold(
                      fontSize: 11,
                      color: RoundsBrand.aqua,
                    ),
                  ),
                  const Spacer(),
                  if (snapshot.latestChartStamp.isNotEmpty)
                    Text(
                      snapshot.latestChartStamp,
                      style: AppTypography.regular(
                        fontSize: 11,
                        color: RoundsBrand.white.withValues(alpha: 0.7),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                headline,
                style: AppTypography.bold(
                  fontSize: 20,
                  height: 1.25,
                  color: RoundsBrand.white,
                ),
              ),
              if (lines.length > 1) ...<Widget>[
                const SizedBox(height: 8),
                ...lines.skip(1).map(
                  (String line) => Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text(
                      line,
                      style: AppTypography.regular(
                        fontSize: 13,
                        height: 1.4,
                        color: RoundsBrand.white.withValues(alpha: 0.85),
                      ),
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 12),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: RoundsBrand.aqua,
                  foregroundColor: RoundsBrand.charcoal,
                ),
                onPressed: () => context.go(
                  AppFeatures.rounds ? AppRoutes.rounds : AppRoutes.census,
                ),
                child: Text(
                  AppFeatures.rounds ? 'Open rounds' : 'View census',
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Counts are assembled from the chart. No urgency ranking.',
                style: AppTypography.regular(
                  fontSize: 11,
                  color: RoundsBrand.white.withValues(alpha: 0.6),
                ),
              ),
            ],
          ),
        ),
        if (next != null) ...<Widget>[
          const SizedBox(height: 12),
          Material(
            color: colors.surface,
            borderRadius: BorderRadius.circular(18),
            child: InkWell(
              borderRadius: BorderRadius.circular(18),
              onTap: () => context.push(AppRoutes.patientPath(next.id)),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: colors.border),
                ),
                child: Row(
                  children: <Widget>[
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            next.room.isEmpty
                                ? 'NEXT UP'
                                : 'NEXT UP · ROOM ${next.room}',
                            style: AppTypography.semiBold(
                              fontSize: 11,
                              color: colors.textMuted,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            next.name,
                            style: AppTypography.semiBold(
                              fontSize: 17,
                              color: colors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            next.reason,
                            style: AppTypography.regular(
                              fontSize: 13,
                              color: colors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(Icons.chevron_right_rounded, color: colors.textMuted),
                  ],
                ),
              ),
            ),
          ),
        ],
        const SizedBox(height: 20),
      ],
    );
  }
}
