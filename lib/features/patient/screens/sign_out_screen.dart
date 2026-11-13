import 'package:flutter/material.dart';
import 'package:round_ai/core/theme/app_colors.dart';
import 'package:round_ai/core/theme/app_typography.dart';
import 'package:round_ai/features/census/data/demo_patients.dart';
import 'package:round_ai/features/patient/data/patient_workspace.dart';
import 'package:round_ai/shared/widgets/app_button.dart';
import 'package:round_ai/shared/widgets/workflow_page.dart';

class SignOutScreen extends StatefulWidget {
  const SignOutScreen({required this.patientId, super.key});

  final String patientId;

  @override
  State<SignOutScreen> createState() => _SignOutScreenState();
}

class _SignOutScreenState extends State<SignOutScreen> {
  final TextEditingController _contingency = TextEditingController();
  bool _reviewed = false;

  @override
  void dispose() {
    _contingency.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppColors colors = AppColors.of(context);
    final CensusPatient? patient = patientById(widget.patientId);
    final PatientWorkspace? workspace = workspaceFor(widget.patientId);
    if (patient == null || workspace == null) {
      return const WorkflowPage(
        title: 'Sign-out',
        children: <Widget>[Text('This patient is not on your team.')],
      );
    }

    return WorkflowPage(
      title: 'Sign-out',
      status: _reviewed
          ? 'Reviewed · this version'
          : 'Draft ready · requires review',
      children: <Widget>[
        Text(
          '${patient.name} · Room ${patient.room} · ${patient.codeStatus}',
          style: AppTypography.bold(fontSize: 22, color: colors.navy),
        ),
        const SizedBox(height: 16),
        InfoCard(title: 'Draft', label: 'From chart', body: workspace.signOut),
        const SizedBox(height: 12),
        InfoCard(
          title: 'Open issues',
          body: workspace.missing.map((String line) => '• $line').join('\n'),
        ),
        const SizedBox(height: 16),
        Text(
          'Contingency instructions',
          style: AppTypography.medium(fontSize: 14),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _contingency,
          minLines: 3,
          maxLines: 5,
          decoration: InputDecoration(
            filled: true,
            fillColor: colors.inputFill,
            hintText:
                'Clinician writes any rescue instructions. None are invented.',
            hintStyle: AppTypography.regular(
              color: colors.textSecondary,
              fontSize: 13,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: colors.border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: colors.border),
            ),
          ),
        ),
        const SizedBox(height: 16),
        AppButton(
          label: _reviewed ? 'Reviewed' : 'Mark this version reviewed',
          onPressed: _reviewed ? null : () => setState(() => _reviewed = true),
        ),
      ],
    );
  }
}
