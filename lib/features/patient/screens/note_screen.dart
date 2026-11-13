import 'package:flutter/material.dart';
import 'package:round_ai/core/theme/app_colors.dart';
import 'package:round_ai/core/theme/app_typography.dart';
import 'package:round_ai/features/census/data/demo_patients.dart';
import 'package:round_ai/shared/widgets/app_button.dart';
import 'package:round_ai/shared/widgets/workflow_page.dart';

class NoteScreen extends StatefulWidget {
  const NoteScreen({required this.patientId, super.key});

  final String patientId;

  @override
  State<NoteScreen> createState() => _NoteScreenState();
}

class _NoteScreenState extends State<NoteScreen> {
  final TextEditingController _changes = TextEditingController();
  final TextEditingController _subjective = TextEditingController();
  final TextEditingController _exam = TextEditingController();
  final TextEditingController _plan = TextEditingController();

  String? _subjectiveText;
  String? _objectiveText;
  String? _assessmentText;
  String? _planText;
  bool _planMissing = true;

  @override
  void dispose() {
    _changes.dispose();
    _subjective.dispose();
    _exam.dispose();
    _plan.dispose();
    super.dispose();
  }

  void _generate(CensusPatient patient) {
    final String subjective = _subjective.text.trim();
    final String exam = _exam.text.trim();
    final String plan = _plan.text.trim();
    final String changes = _changes.text.trim();
    setState(() {
      _subjectiveText = subjective.isEmpty
          ? 'Not entered.'
          : changes.isEmpty
          ? subjective
          : '$subjective\n\nToday’s update: $changes';
      _objectiveText = exam.isEmpty
          ? 'Today’s examination was not entered.'
          : exam;
      _assessmentText =
          'Documented problem: ${patient.problem}. ${patient.summary}';
      _planMissing = plan.isEmpty;
      _planText = plan.isEmpty ? null : plan;
    });
  }

  Future<void> _regenerateSection({
    required String title,
    required String current,
    required String rebuilt,
    required void Function(String value) apply,
  }) async {
    final bool? replace = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Replace $title?'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text('Before', style: AppTypography.semiBold(fontSize: 13)),
              const SizedBox(height: 4),
              Text(current, style: AppTypography.regular(fontSize: 13)),
              const SizedBox(height: 12),
              Text('After', style: AppTypography.semiBold(fontSize: 13)),
              const SizedBox(height: 4),
              Text(rebuilt, style: AppTypography.regular(fontSize: 13)),
            ],
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Keep'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Replace'),
            ),
          ],
        );
      },
    );
    if (replace == true) apply(rebuilt);
  }

  @override
  Widget build(BuildContext context) {
    final AppColors colors = AppColors.of(context);
    final CensusPatient? patient = patientById(widget.patientId);
    if (patient == null) {
      return const WorkflowPage(
        title: 'Draft note',
        children: <Widget>[Text('This patient is not on your team.')],
      );
    }

    final bool ready = _subjectiveText != null;

    return WorkflowPage(
      title: 'Daily progress note',
      status: ready ? 'Draft ready · requires review' : 'Not generated',
      children: <Widget>[
        Text(
          '${patient.name} · Room ${patient.room}',
          style: AppTypography.bold(fontSize: 22, color: colors.navy),
        ),
        const SizedBox(height: 8),
        Text(
          'The draft uses only what is entered below and the documented chart summary. It does not invent an examination, a patient statement, or a plan.',
          style: AppTypography.regular(
            color: colors.textSecondary,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 16),
        InfoCard(
          title: 'Reviewed context',
          label: 'From chart',
          body: patient.summary,
        ),
        const SizedBox(height: 16),
        _Field(
          label: 'Today’s changes',
          controller: _changes,
          onChanged: () => setState(() {}),
        ),
        const SizedBox(height: 12),
        _Field(
          label: 'Subjective report',
          controller: _subjective,
          onChanged: () => setState(() {}),
        ),
        const SizedBox(height: 12),
        _Field(
          label: 'Examination',
          controller: _exam,
          onChanged: () => setState(() {}),
        ),
        const SizedBox(height: 12),
        _Field(
          label: 'Clinician plan',
          controller: _plan,
          onChanged: () => setState(() {}),
        ),
        const SizedBox(height: 12),
        _Checklist(
          items: <(String, bool)>[
            ('Subjective', _subjective.text.trim().isNotEmpty),
            ('Examination', _exam.text.trim().isNotEmpty),
            ('Plan', _plan.text.trim().isNotEmpty),
          ],
        ),
        const SizedBox(height: 16),
        AppButton(
          label: ready ? 'Update draft' : 'Generate draft',
          onPressed: () => _generate(patient),
        ),
        if (ready) ...<Widget>[
          const SizedBox(height: 20),
          _Section(
            title: 'Subjective',
            text: _subjectiveText!,
            onRegenerate: () => _regenerateSection(
              title: 'Subjective',
              current: _subjectiveText!,
              rebuilt: _subjective.text.trim().isEmpty
                  ? 'Not entered.'
                  : _subjective.text.trim(),
              apply: (String value) => setState(() => _subjectiveText = value),
            ),
          ),
          const SizedBox(height: 12),
          _Section(
            title: 'Objective',
            text: _objectiveText!,
            onRegenerate: () => _regenerateSection(
              title: 'Objective',
              current: _objectiveText!,
              rebuilt: _exam.text.trim().isEmpty
                  ? 'Today’s examination was not entered.'
                  : _exam.text.trim(),
              apply: (String value) => setState(() => _objectiveText = value),
            ),
          ),
          const SizedBox(height: 12),
          _Section(
            title: 'Assessment',
            text: _assessmentText!,
            label: 'From chart',
          ),
          const SizedBox(height: 12),
          if (_planMissing)
            InfoCard(
              title: 'Plan',
              label: 'Missing plan',
              body:
                  'Today’s plan was not entered. A suggested plan is not added to this note.',
              tint: colors.warningSoft,
              border: colors.warning,
            )
          else
            _Section(
              title: 'Plan',
              text: _planText!,
              label: 'Clinician entered',
              onRegenerate: () => _regenerateSection(
                title: 'Plan',
                current: _planText!,
                rebuilt: _plan.text.trim(),
                apply: (String value) => setState(() => _planText = value),
              ),
            ),
        ],
      ],
    );
  }
}

class _Field extends StatelessWidget {
  const _Field({
    required this.label,
    required this.controller,
    required this.onChanged,
  });

  final String label;
  final TextEditingController controller;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final AppColors colors = AppColors.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(label, style: AppTypography.medium(fontSize: 14)),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          onChanged: (_) => onChanged(),
          minLines: 2,
          maxLines: 4,
          decoration: InputDecoration(
            filled: true,
            fillColor: colors.inputFill,
            hintText: 'Enter only what you know',
            hintStyle: AppTypography.regular(color: colors.textSecondary),
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
      ],
    );
  }
}

class _Checklist extends StatelessWidget {
  const _Checklist({required this.items});

  final List<(String, bool)> items;

  @override
  Widget build(BuildContext context) {
    final AppColors colors = AppColors.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text('Completeness', style: AppTypography.semiBold(fontSize: 14)),
        const SizedBox(height: 6),
        ...items.map((item) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(
              children: <Widget>[
                Icon(
                  item.$2 ? Icons.check_circle : Icons.radio_button_unchecked,
                  size: 18,
                  color: item.$2 ? colors.accent : colors.textSecondary,
                ),
                const SizedBox(width: 8),
                Text(item.$1, style: AppTypography.regular(fontSize: 14)),
              ],
            ),
          );
        }),
        Text(
          'A partial draft is still allowed.',
          style: AppTypography.regular(
            color: colors.textSecondary,
            fontSize: 12,
          ),
        ),
      ],
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({
    required this.title,
    required this.text,
    this.label,
    this.onRegenerate,
  });

  final String title;
  final String text;
  final String? label;
  final VoidCallback? onRegenerate;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        InfoCard(title: title, label: label, body: text),
        if (onRegenerate != null)
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: onRegenerate,
              child: const Text('Regenerate section'),
            ),
          ),
      ],
    );
  }
}
