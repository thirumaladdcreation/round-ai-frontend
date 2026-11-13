import 'package:flutter/material.dart';
import 'package:round_ai/core/di/injection_container.dart';
import 'package:round_ai/core/errors/result.dart';
import 'package:round_ai/core/theme/app_colors.dart';
import 'package:round_ai/core/theme/app_typography.dart';
import 'package:round_ai/features/census/models/patient_summary.dart';
import 'package:round_ai/features/census/repository/census_repository.dart';

/// Pick a census patient, then run a Scribe action (notes / ICD / intake).
Future<PatientSummary?> pickScribePatient(BuildContext context) async {
  final CensusRepository repo =
      InjectionContainer.instance.censusRepository;
  final Result<List<PatientSummary>> result = await repo.loadPatients();
  if (!context.mounted) return null;

  switch (result) {
    case Err<List<PatientSummary>>(:final failure):
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(failure.message)));
      return null;
    case Ok<List<PatientSummary>>(:final value):
      if (value.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No patients on the census yet. Add or dictate a census first.'),
          ),
        );
        return null;
      }
      return showModalBottomSheet<PatientSummary>(
        context: context,
        isScrollControlled: true,
        backgroundColor: AppColors.of(context).surface,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        builder: (BuildContext ctx) {
          final AppColors colors = AppColors.of(ctx);
          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Center(
                    child: Container(
                      width: 36,
                      height: 4,
                      decoration: BoxDecoration(
                        color: colors.border,
                        borderRadius: BorderRadius.circular(99),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    'Choose a patient',
                    style: AppTypography.semiBold(
                      fontSize: 18,
                      color: colors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Notes, ICD, and intake need a patient from your census.',
                    style: AppTypography.regular(
                      fontSize: 13,
                      color: colors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  ConstrainedBox(
                    constraints: BoxConstraints(
                      maxHeight: MediaQuery.sizeOf(ctx).height * 0.5,
                    ),
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: value.length,
                      separatorBuilder: (_, _) =>
                          Divider(height: 1, color: colors.border),
                      itemBuilder: (BuildContext context, int index) {
                        final PatientSummary p = value[index];
                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(
                            p.displayName,
                            style: AppTypography.semiBold(
                              fontSize: 15,
                              color: colors.textPrimary,
                            ),
                          ),
                          subtitle: Text(
                            <String>[
                              if (p.room.isNotEmpty) 'Room ${p.room}',
                              if (p.ageBand.isNotEmpty) p.ageBand,
                              if (p.sex.isNotEmpty) p.sex,
                            ].join(' · '),
                            style: AppTypography.regular(
                              fontSize: 12,
                              color: colors.textSecondary,
                            ),
                          ),
                          trailing: Icon(
                            Icons.chevron_right_rounded,
                            color: colors.textMuted,
                          ),
                          onTap: () => Navigator.pop(ctx, p),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      );
  }
}
