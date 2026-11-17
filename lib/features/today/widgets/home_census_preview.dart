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
    final List<HomePatientPreview> preview = snapshot.patients;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        HomeSectionTitle(
          title: 'Patients',
          action: preview.isEmpty ? null : 'Census',
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
      if (patient.room.isNotEmpty) 'Rm ${patient.room}',
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
              if (patient.noteStatus.isNotEmpty)
                Text(
                  patient.noteStatus,
                  style: AppTypography.caption(
                    color: patient.noteStatus == 'Not generated'
                        ? colors.textMuted
                        : colors.primary,
                  ),
                ),
              Icon(Icons.chevron_right_rounded, color: colors.textMuted),
            ],
          ),
          if (meta.isNotEmpty) ...<Widget>[
            const SizedBox(height: 4),
            Text(meta, style: AppTypography.caption(color: colors.textSecondary)),
          ],
          const SizedBox(height: 6),
          Text(
            patient.reason,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.bodyMedium(color: colors.textPrimary),
          ),
          const SizedBox(height: 4),
          Text(
            <String>[
              if (patient.pendingFacts > 0)
                '${patient.pendingFacts} pending fact${patient.pendingFacts == 1 ? '' : 's'}',
              if (patient.pendingTasks > 0)
                '${patient.pendingTasks} open task${patient.pendingTasks == 1 ? '' : 's'}',
              if (patient.pendingFacts == 0 && patient.pendingTasks == 0)
                patient.latestUpdate.isEmpty
                    ? 'Ready for rounds'
                    : patient.latestUpdate,
            ].join(' · '),
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
