import 'package:flutter/material.dart';
import 'package:round_ai/core/theme/app_colors.dart';
import 'package:round_ai/core/theme/app_typography.dart';
import 'package:round_ai/features/census/data/demo_patients.dart';
import 'package:round_ai/features/patient/data/patient_workspace.dart';
import 'package:round_ai/shared/widgets/app_button.dart';
import 'package:round_ai/shared/widgets/workflow_page.dart';

class EvidenceScreen extends StatefulWidget {
  const EvidenceScreen({required this.patientId, super.key});

  final String patientId;

  @override
  State<EvidenceScreen> createState() => _EvidenceScreenState();
}

class _EvidenceScreenState extends State<EvidenceScreen> {
  String? _refreshMessage;

  @override
  Widget build(BuildContext context) {
    final AppColors colors = AppColors.of(context);
    final CensusPatient? patient = patientById(widget.patientId);
    final PatientWorkspace? workspace = workspaceFor(widget.patientId);
    if (patient == null || workspace == null) {
      return const WorkflowPage(
        title: 'Evidence',
        children: <Widget>[Text('This patient is not on your team.')],
      );
    }

    return WorkflowPage(
      title: 'Evidence',
      status: 'No relevant evidence',
      children: <Widget>[
        Text(
          workspace.evidenceTopic,
          style: AppTypography.bold(fontSize: 22, color: colors.navy),
        ),
        const SizedBox(height: 8),
        Text(
          'Search uses the condition only. The patient name, room, and chart text are not sent.',
          style: AppTypography.regular(
            color: colors.textSecondary,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 8,
          children: const <Widget>[
            _FilterChip(label: 'Previous 24 months'),
            _FilterChip(label: '90-day filter'),
          ],
        ),
        const SizedBox(height: 16),
        const InfoCard(
          title: 'Searched sources',
          label: 'Not retrieved',
          body:
              'No relevant recent studies found in the searched sources. PubMed is not connected in this build, so no citation, date, or identifier is shown.',
        ),
        if (_refreshMessage != null) ...<Widget>[
          const SizedBox(height: 12),
          InfoCard(title: 'Refresh now', body: _refreshMessage!),
        ],
        const SizedBox(height: 16),
        AppButton(
          label: 'Refresh now',
          onPressed: () {
            setState(() {
              _refreshMessage =
                  'Retrieval is not connected, so no studies were fetched. Last checked just now.';
            });
          },
        ),
        const SizedBox(height: 12),
        Text(
          'Why this topic may matter for this case',
          style: AppTypography.semiBold(fontSize: 15),
        ),
        const SizedBox(height: 8),
        Text(
          'The chart documents ${patient.problem}. That is a reason to look up this topic later. It is not a treatment recommendation, and it does not change the plan.',
          style: AppTypography.regular(height: 1.45),
        ),
      ],
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final AppColors colors = AppColors.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: colors.border),
      ),
      child: Text(label, style: AppTypography.medium(fontSize: 12)),
    );
  }
}
