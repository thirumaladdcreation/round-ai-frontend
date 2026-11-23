import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:round_ai/core/router/app_routes.dart';
import 'package:round_ai/core/theme/app_colors.dart';
import 'package:round_ai/core/theme/app_typography.dart';
import 'package:round_ai/features/census/models/patient_summary.dart';
import 'package:round_ai/features/patient/widgets/patient_chrome.dart';
import 'package:round_ai/features/scribe/widgets/scribe_patient_picker.dart';

/// Secondary entry for census capture / patient Add update (not a bottom tab).
class ScribeHubScreen extends StatelessWidget {
  const ScribeHubScreen({super.key});

  Future<void> _addUpdate(BuildContext context) async {
    final PatientSummary? patient = await pickScribePatient(context);
    if (patient == null || !context.mounted) return;
    await showAddUpdateSheet(context, patient.id);
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
              'Add update',
              style: AppTypography.bold(fontSize: 24, color: colors.navy),
            ),
            const SizedBox(height: 8),
            Text(
              'Pick a patient, then dictate, photograph, or paste chart text. '
              'Census capture stays available below.',
              style: AppTypography.regular(
                fontSize: 14,
                height: 1.4,
                color: colors.textSecondary,
              ),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: () => _addUpdate(context),
              icon: const Icon(Icons.add_rounded),
              label: const Text('Choose patient'),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF0A8F9C),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
            const SizedBox(height: 28),
            Text(
              'Census capture',
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
              title: 'Open patients',
              subtitle: 'Review or manually add patients.',
              onTap: () => context.go(AppRoutes.census),
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
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: <Widget>[
                Icon(icon, color: const Color(0xFF0A8F9C)),
                const SizedBox(width: 12),
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
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: AppTypography.regular(
                          fontSize: 12,
                          height: 1.3,
                          color: colors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right_rounded, color: colors.textSecondary),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
