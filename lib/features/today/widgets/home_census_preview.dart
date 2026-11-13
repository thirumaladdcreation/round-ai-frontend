import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:round_ai/app/app_colors.dart';
import 'package:round_ai/app/app_typography.dart';
import 'package:round_ai/core/router/app_routes.dart';
import 'package:round_ai/features/today/models/home_snapshot.dart';
import 'package:round_ai/features/today/widgets/home_section_title.dart';
import 'package:round_ai/features/today/widgets/home_surface.dart';

class HomeCensusPreview extends StatelessWidget {
  const HomeCensusPreview({required this.snapshot, super.key});

  final HomeSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final List<HomePatientPreview> preview = snapshot.patients.take(4).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        HomeSectionTitle(
          title: 'Patient census',
          action: snapshot.patients.isEmpty ? null : 'View all patients',
          onAction: () => context.go(AppRoutes.census),
        ),
        if (preview.isEmpty)
          const HomeEmptyLine(message: 'No patients are assigned to this team.')
        else
          ...preview.map(
            (HomePatientPreview patient) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: HomePatientTile(patient: patient),
            ),
          ),
        if (snapshot.hasPartialChart)
          const HomeEmptyLine(
            message:
                'Age is shown only when the chart includes it. Gender is omitted when it is not recorded.',
          ),
      ],
    );
  }
}

class HomePatientTile extends StatelessWidget {
  const HomePatientTile({required this.patient, super.key});

  final HomePatientPreview patient;

  @override
  Widget build(BuildContext context) {
    final AppColors colors = AppColors.of(context);
    final String meta = <String>[
      'Room ${patient.room}',
      if (patient.ageLabel != null) patient.ageLabel!,
      if (patient.genderLabel != null) patient.genderLabel!,
    ].join(' · ');
    return HomeSurface(
      onTap: () => context.push(AppRoutes.patientPath(patient.id)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  patient.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.semiBold(
                    fontSize: 15,
                    color: colors.textPrimary,
                  ),
                ),
              ),
              if (patient.pendingTasks > 0)
                Text(
                  '${patient.pendingTasks} open',
                  style: AppTypography.caption(color: colors.primary),
                ),
              Icon(Icons.chevron_right_rounded, color: colors.textMuted),
            ],
          ),
          const SizedBox(height: 4),
          Text(meta, style: AppTypography.caption(color: colors.textSecondary)),
          const SizedBox(height: 6),
          Text(
            patient.reason,
            style: AppTypography.bodyMedium(color: colors.textPrimary),
          ),
          const SizedBox(height: 4),
          Text(
            patient.latestUpdate.isEmpty
                ? 'No update recorded'
                : patient.latestUpdate,
            style: AppTypography.caption(color: colors.textMuted),
          ),
        ],
      ),
    );
  }
}

class HomeEmptyLine extends StatelessWidget {
  const HomeEmptyLine({required this.message, super.key});

  final String message;

  @override
  Widget build(BuildContext context) {
    final AppColors colors = AppColors.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        message,
        style: AppTypography.bodySmall(color: colors.textSecondary),
      ),
    );
  }
}
