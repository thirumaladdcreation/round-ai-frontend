import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:round_ai/core/router/app_routes.dart';
import 'package:round_ai/core/theme/app_colors.dart';
import 'package:round_ai/core/theme/app_typography.dart';
import 'package:round_ai/features/census/models/patient_summary.dart';
import 'package:round_ai/features/scribe/widgets/scribe_patient_picker.dart';

/// Scribe mode hub: census capture + patient notes / ICD / intake shortcuts.
class ScribeHubScreen extends StatelessWidget {
  const ScribeHubScreen({super.key});

  Future<void> _withPatient(
    BuildContext context,
    void Function(String patientId) open,
  ) async {
    final PatientSummary? patient = await pickScribePatient(context);
    if (patient == null || !context.mounted) return;
    open(patient.id);
  }

  @override
  Widget build(BuildContext context) {
    final AppColors colors = AppColors.of(context);
    return Scaffold(
      backgroundColor: colors.background,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
          children: <Widget>[
            Text(
              'Scribe',
              style: AppTypography.bold(fontSize: 28, color: colors.navy),
            ),
            const SizedBox(height: 8),
            Text(
              'Make the census by voice or photo, then add chart data, notes, '
              'and ICD suggestions for a patient.',
              style: AppTypography.regular(
                fontSize: 14,
                height: 1.4,
                color: colors.textSecondary,
              ),
            ),
            const SizedBox(height: 28),
            Text(
              'Make your census',
              style: AppTypography.semiBold(fontSize: 15, color: colors.navy),
            ),
            const SizedBox(height: 10),
            _ScribeAction(
              icon: Icons.mic_none_rounded,
              title: 'Dictate census',
              subtitle:
                  'Speak the ward list. Confirm before patients are created.',
              onTap: () => context.push(AppRoutes.censusIntakeDictatePath()),
            ),
            _ScribeAction(
              icon: Icons.photo_camera_outlined,
              title: 'Photo census',
              subtitle: 'Photograph a handwritten or printed list.',
              onTap: () => context.push(AppRoutes.censusIntakePhotoPath()),
            ),
            _ScribeAction(
              icon: Icons.people_alt_outlined,
              title: 'Open census',
              subtitle: 'Review or manually add patients.',
              onTap: () => context.go(AppRoutes.census),
            ),
            const SizedBox(height: 24),
            Text(
              'On a patient',
              style: AppTypography.semiBold(fontSize: 15, color: colors.navy),
            ),
            const SizedBox(height: 6),
            Text(
              'Pick someone from the census, then continue.',
              style: AppTypography.regular(
                fontSize: 12,
                color: colors.textSecondary,
              ),
            ),
            const SizedBox(height: 10),
            _ScribeAction(
              icon: Icons.record_voice_over_outlined,
              title: 'Dictate into chart',
              subtitle: 'Audio → source + pending facts (confirm before use).',
              onTap: () => _withPatient(
                context,
                (String id) =>
                    context.push(AppRoutes.patientIntakeDictatePath(id)),
              ),
            ),
            _ScribeAction(
              icon: Icons.photo_outlined,
              title: 'Photo into chart',
              subtitle: 'Image extract → source + pending facts.',
              onTap: () => _withPatient(
                context,
                (String id) =>
                    context.push(AppRoutes.patientIntakePhotoPath(id)),
              ),
            ),
            _ScribeAction(
              icon: Icons.note_alt_outlined,
              title: 'Progress / H&P notes',
              subtitle:
                  'Generate templates from reviewed facts. Plan must be entered.',
              onTap: () => _withPatient(
                context,
                (String id) => context.push(AppRoutes.notePath(id)),
              ),
            ),
            _ScribeAction(
              icon: Icons.medical_information_outlined,
              title: 'ICD suggestions',
              subtitle:
                  'Open the chart → Problems → Suggest ICD. Not a billing determination.',
              onTap: () => _withPatient(
                context,
                (String id) => context.push(AppRoutes.patientPath(id)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ScribeAction extends StatelessWidget {
  const _ScribeAction({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final AppColors colors = AppColors.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: colors.surface,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: colors.border),
            ),
            child: Row(
              children: <Widget>[
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: colors.primarySoft,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: colors.primary),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        title,
                        style: AppTypography.semiBold(
                          fontSize: 15,
                          color: colors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: AppTypography.regular(
                          fontSize: 12,
                          height: 1.35,
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
    );
  }
}
