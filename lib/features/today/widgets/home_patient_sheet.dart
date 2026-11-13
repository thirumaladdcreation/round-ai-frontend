import 'package:flutter/material.dart';
import 'package:round_ai/app/app_colors.dart';
import 'package:round_ai/app/app_typography.dart';
import 'package:round_ai/features/today/models/home_snapshot.dart';

/// Asks which authorized patient a patient-specific action should open.
class HomePatientSheet extends StatelessWidget {
  const HomePatientSheet({required this.patients, super.key});

  final List<HomePatientPreview> patients;

  static Future<String?> show(
    BuildContext context,
    List<HomePatientPreview> patients,
  ) {
    return showModalBottomSheet<String>(
      context: context,
      backgroundColor: AppColors.of(context).surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext context) => HomePatientSheet(patients: patients),
    );
  }

  @override
  Widget build(BuildContext context) {
    final AppColors colors = AppColors.of(context);
    return SafeArea(
      child: ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
        children: <Widget>[
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: colors.border,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Choose a patient',
            style: AppTypography.sectionHeading(color: colors.navy),
          ),
          const SizedBox(height: 4),
          Text(
            'This action stays inside the selected patient’s chart.',
            style: AppTypography.bodySmall(color: colors.textSecondary),
          ),
          const SizedBox(height: 12),
          ...patients.map(
            (HomePatientPreview patient) => ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(
                patient.name,
                style: AppTypography.medium(
                  fontSize: 15,
                  color: colors.textPrimary,
                ),
              ),
              subtitle: Text(
                'Room ${patient.room}',
                style: AppTypography.caption(color: colors.textMuted),
              ),
              trailing: Icon(
                Icons.chevron_right_rounded,
                color: colors.textMuted,
              ),
              onTap: () => Navigator.pop(context, patient.id),
            ),
          ),
        ],
      ),
    );
  }
}
