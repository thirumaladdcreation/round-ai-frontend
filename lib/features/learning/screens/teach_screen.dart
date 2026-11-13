import 'package:flutter/material.dart';
import 'package:round_ai/core/theme/app_colors.dart';
import 'package:round_ai/core/theme/app_typography.dart';
import 'package:round_ai/features/patient/data/patient_workspace.dart';
import 'package:round_ai/shared/widgets/app_button.dart';
import 'package:round_ai/shared/widgets/demo_content_banner.dart';
import 'package:round_ai/shared/widgets/workflow_page.dart';

class TeachScreen extends StatefulWidget {
  const TeachScreen({required this.patientId, super.key});

  final String patientId;

  @override
  State<TeachScreen> createState() => _TeachScreenState();
}

class _TeachScreenState extends State<TeachScreen> {
  int? _selected;
  bool _revealed = false;

  @override
  Widget build(BuildContext context) {
    final AppColors colors = AppColors.of(context);
    final PatientWorkspace? workspace = workspaceFor(widget.patientId);
    if (workspace == null) {
      return const WorkflowPage(
        title: 'Teach me',
        children: <Widget>[Text('This patient is not on your team.')],
      );
    }

    final TeachItem question = workspace.question;
    return WorkflowPage(
      title: 'Teach me',
      status: 'AI-generated educational content',
      children: <Widget>[
        const DemoContentBanner(forceShow: true),
        Text(
          question.topic,
          style: AppTypography.bold(fontSize: 22, color: colors.navy),
        ),
        const SizedBox(height: 6),
        Text(
          'PGY-1 · Basic · Synthetic case · one question',
          style: AppTypography.regular(color: colors.textSecondary),
        ),
        const SizedBox(height: 16),
        Text(question.vignette, style: AppTypography.regular(height: 1.45)),
        const SizedBox(height: 12),
        Text(question.leadIn, style: AppTypography.semiBold(fontSize: 16)),
        const SizedBox(height: 12),
        ...List<Widget>.generate(question.options.length, (int index) {
          final bool selected = _selected == index;
          final bool showKey = _revealed && index == question.correctIndex;
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Material(
              color: showKey ? colors.successSoft : colors.surface,
              borderRadius: BorderRadius.circular(12),
              child: InkWell(
                onTap: _revealed
                    ? null
                    : () => setState(() => _selected = index),
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: selected ? colors.primary : colors.border,
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        '${String.fromCharCode(65 + index)}. ',
                        style: AppTypography.semiBold(fontSize: 14),
                      ),
                      Expanded(
                        child: Text(
                          question.options[index],
                          style: AppTypography.regular(height: 1.35),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }),
        const SizedBox(height: 8),
        if (!_revealed)
          AppButton(
            label: 'Show answer',
            onPressed: _selected == null
                ? null
                : () => setState(() => _revealed = true),
          )
        else ...<Widget>[
          Text(
            _selected == question.correctIndex
                ? 'Correct. ${question.correctExplanation}'
                : 'The keyed answer is ${String.fromCharCode(65 + question.correctIndex)}. ${question.correctExplanation}',
            style: AppTypography.regular(height: 1.45),
          ),
          const SizedBox(height: 12),
          ...List<Widget>.generate(question.distractorExplanations.length, (
            int index,
          ) {
            final int optionIndex = index >= question.correctIndex
                ? index + 1
                : index;
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                '${String.fromCharCode(65 + optionIndex)}. ${question.distractorExplanations[index]}',
                style: AppTypography.regular(
                  color: colors.textSecondary,
                  fontSize: 13,
                  height: 1.4,
                ),
              ),
            );
          }),
          const SizedBox(height: 8),
          Text(question.takeaway, style: AppTypography.semiBold(fontSize: 15)),
          const SizedBox(height: 12),
          TextButton(
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Issue reported for this question.'),
                ),
              );
            },
            child: const Text('Report issue'),
          ),
        ],
      ],
    );
  }
}
