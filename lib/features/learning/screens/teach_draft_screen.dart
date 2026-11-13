import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:round_ai/core/di/injection_container.dart';
import 'package:round_ai/core/router/app_routes.dart';
import 'package:round_ai/core/theme/app_colors.dart';
import 'package:round_ai/core/theme/app_typography.dart';
import 'package:round_ai/features/authentication/repository/profile_repository.dart';
import 'package:round_ai/features/learning/bloc/teach_cubit.dart';
import 'package:round_ai/features/learning/models/mcq.dart';
import 'package:round_ai/features/learning/models/mcq_draft.dart';
import 'package:round_ai/features/learning/repository/teach_repository.dart';
import 'package:round_ai/features/patient/models/problem.dart';
import 'package:round_ai/features/patient/widgets/chart_entry_scaffold.dart';
import 'package:round_ai/features/problems/repository/problems_repository.dart';
import 'package:round_ai/shared/widgets/ai_error_box.dart';
import 'package:round_ai/shared/widgets/app_input.dart';

const String teachAiOffMessage =
    'AI is temporarily off. Manual entry still works.';
const String unreviewedQuestionLabel = 'AI-generated, not yet reviewed';

/// Teach me on the real backend: one question at a time from a confirmed
/// problem. The key and explanations appear only after a choice is
/// submitted.
class TeachDraftScreen extends StatelessWidget {
  const TeachDraftScreen({
    required this.patientId,
    this.teachRepository,
    this.problemsRepository,
    this.aiOff,
    super.key,
  });

  final String patientId;
  final TeachRepository? teachRepository;
  final ProblemsRepository? problemsRepository;

  /// Tests set this. The app reads the profile.
  final bool? aiOff;

  @override
  Widget build(BuildContext context) {
    final InjectionContainer di = InjectionContainer.instance;
    return BlocProvider<TeachCubit>(
      create: (_) => TeachCubit(
        teachRepository ?? di.teachRepository,
        problemsRepository ?? di.problemsRepository,
        patientId,
      )..loadProblems(),
      child: _TeachView(
        patientId: patientId,
        aiOff: aiOff ?? di.profileRepository.aiOff,
      ),
    );
  }
}

class _TeachView extends StatelessWidget {
  const _TeachView({required this.patientId, required this.aiOff});

  final String patientId;
  final bool aiOff;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<TeachCubit, TeachState>(
      builder: (BuildContext context, TeachState state) {
        final TeachCubit cubit = context.read<TeachCubit>();
        final AppColors colors = AppColors.of(context);
        final McqDraft? draft = state.draft;
        return ChartEntryScaffold(
          title: 'Teach me',
          bottom: state.generating
              ? AiProgressRow(
                  message: 'Writing a question. This can take up to a minute.',
                  onCancel: cubit.cancel,
                )
              : null,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              if (draft == null) ...<Widget>[
                Text(
                  'Pick a confirmed problem. One question is written from it. '
                  'The chart text is not used as a source for the answer.',
                  style: AppTypography.regular(
                    fontSize: 13,
                    height: 1.4,
                    color: colors.textSecondary,
                  ),
                ),
                const SizedBox(height: 12),
                if (state.problemsLoading)
                  const Padding(
                    padding: EdgeInsets.all(12),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (state.problems.isEmpty)
                  Text(
                    'No confirmed problems yet. Confirm a problem on the '
                    'overview first.',
                    style: AppTypography.regular(color: colors.textSecondary),
                  )
                else
                  for (final Problem p in state.problems)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Material(
                        color: colors.surface,
                        borderRadius: BorderRadius.circular(12),
                        child: ListTile(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: BorderSide(color: colors.border),
                          ),
                          enabled: !aiOff && !state.generating,
                          title: Text(p.label),
                          trailing: const Icon(Icons.auto_awesome, size: 18),
                          onTap: () => cubit.generate(p.id),
                        ),
                      ),
                    ),
                if (aiOff) ...<Widget>[
                  const SizedBox(height: 8),
                  Text(
                    teachAiOffMessage,
                    style: AppTypography.regular(
                      fontSize: 12,
                      color: colors.critical,
                    ),
                  ),
                ],
                if (state.error != null) ...<Widget>[
                  const SizedBox(height: 12),
                  AiErrorBox(
                    error: state.error!,
                    onRetry: state.error!.isRetryable ? cubit.retry : null,
                  ),
                ],
                TextButton.icon(
                  onPressed: () =>
                      context.push<Object>(AppRoutes.teachQueuePath(patientId)),
                  icon: const Icon(Icons.fact_check_outlined, size: 18),
                  label: const Text('Review queue'),
                ),
              ] else
                _Question(state: state, draft: draft),
            ],
          ),
        );
      },
    );
  }
}

class _Question extends StatelessWidget {
  const _Question({required this.state, required this.draft});

  final TeachState state;
  final McqDraft draft;

  Future<void> _report(BuildContext context) async {
    final TeachCubit cubit = context.read<TeachCubit>();
    final String? reason = await showDialog<String>(
      context: context,
      builder: (BuildContext dialog) => const _ReportDialog(),
    );
    if (reason != null && reason.isNotEmpty) await cubit.report(reason);
  }

  @override
  Widget build(BuildContext context) {
    final AppColors colors = AppColors.of(context);
    final TeachCubit cubit = context.read<TeachCubit>();
    final Mcq q = draft.mcq;
    final McqReveal? reveal = state.reveal;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        if (!draft.isReviewed)
          Text(
            unreviewedQuestionLabel,
            style: AppTypography.medium(fontSize: 11, color: colors.aiAccent),
          ),
        if (q.topic.isNotEmpty) ...<Widget>[
          const SizedBox(height: 6),
          Text(
            q.topic,
            style: AppTypography.bold(fontSize: 20, color: colors.navy),
          ),
        ],
        if (q.difficulty.isNotEmpty) ...<Widget>[
          const SizedBox(height: 4),
          Text(
            q.difficulty,
            style: AppTypography.regular(color: colors.textSecondary),
          ),
        ],
        const SizedBox(height: 14),
        Text(q.vignette, style: AppTypography.regular(height: 1.45)),
        const SizedBox(height: 12),
        Text(q.leadIn, style: AppTypography.semiBold(fontSize: 16)),
        const SizedBox(height: 12),
        for (int i = 0; i < q.options.length; i++)
          _Option(
            index: i,
            text: q.options[i],
            selected: state.selected == i,
            keyed: reveal != null && reveal.correctIndex == i,
            wrong:
                reveal != null &&
                state.selected == i &&
                reveal.correctIndex != i,
            enabled: reveal == null && !state.submitting,
            onTap: () => cubit.select(i),
          ),
        if (state.answerError != null) ...<Widget>[
          const SizedBox(height: 8),
          AiErrorBox(error: state.answerError!),
        ],
        const SizedBox(height: 8),
        if (reveal == null)
          FilledButton(
            onPressed: state.canSubmit ? cubit.submit : null,
            child: state.submitting
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Submit answer'),
          )
        else
          _Answer(q: q, reveal: reveal, selected: state.selected),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: <Widget>[
            if (state.reported)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text(
                  'Issue reported for this question.',
                  style: AppTypography.regular(
                    fontSize: 13,
                    color: colors.textSecondary,
                  ),
                ),
              )
            else
              TextButton(
                onPressed: () => _report(context),
                child: const Text('Report issue'),
              ),
            if (reveal != null)
              TextButton(
                onPressed: cubit.next,
                child: const Text('Another question'),
              ),
          ],
        ),
        if (state.reportError != null) AiErrorBox(error: state.reportError!),
      ],
    );
  }
}

class _Option extends StatelessWidget {
  const _Option({
    required this.index,
    required this.text,
    required this.selected,
    required this.keyed,
    required this.wrong,
    required this.enabled,
    required this.onTap,
  });

  final int index;
  final String text;
  final bool selected;
  final bool keyed;
  final bool wrong;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final AppColors colors = AppColors.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: keyed
            ? colors.successSoft
            : wrong
            ? colors.criticalBg
            : colors.surface,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: enabled ? onTap : null,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: selected ? colors.primary : colors.border,
                width: selected ? 1.5 : 1,
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
                  child: Text(text, style: AppTypography.regular(height: 1.35)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Answer extends StatelessWidget {
  const _Answer({
    required this.q,
    required this.reveal,
    required this.selected,
  });

  final Mcq q;
  final McqReveal reveal;
  final int? selected;

  @override
  Widget build(BuildContext context) {
    final AppColors colors = AppColors.of(context);
    final String letter = String.fromCharCode(65 + reveal.correctIndex);
    final bool right = selected == reveal.correctIndex;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          right ? 'Correct.' : 'The keyed answer is $letter.',
          style: AppTypography.semiBold(
            fontSize: 15,
            color: right ? colors.success : colors.textPrimary,
          ),
        ),
        if (reveal.explanation != null) ...<Widget>[
          const SizedBox(height: 6),
          Text(reveal.explanation!, style: AppTypography.regular(height: 1.45)),
        ],
        const SizedBox(height: 12),
        for (int i = 0; i < q.options.length; i++)
          if (reveal.explanationFor(i, q.options.length) != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                '${String.fromCharCode(65 + i)}. '
                '${reveal.explanationFor(i, q.options.length)}',
                style: AppTypography.regular(
                  fontSize: 13,
                  height: 1.4,
                  color: colors.textSecondary,
                ),
              ),
            ),
        if (reveal.takeaway != null) ...<Widget>[
          const SizedBox(height: 4),
          Text(reveal.takeaway!, style: AppTypography.semiBold(fontSize: 15)),
        ],
        if (reveal.references.isNotEmpty) ...<Widget>[
          const SizedBox(height: 10),
          Text(
            'References',
            style: AppTypography.semiBold(
              fontSize: 13,
              color: colors.textPrimary,
            ),
          ),
          for (final String ref in reveal.references)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                '• $ref',
                style: AppTypography.regular(
                  fontSize: 12,
                  height: 1.4,
                  color: colors.textSecondary,
                ),
              ),
            ),
        ],
      ],
    );
  }
}

/// Asks what is wrong with a question. It owns its controller, so the
/// controller is disposed only after the dialog has gone.
class _ReportDialog extends StatefulWidget {
  const _ReportDialog();

  @override
  State<_ReportDialog> createState() => _ReportDialogState();
}

class _ReportDialogState extends State<_ReportDialog> {
  final TextEditingController _reason = TextEditingController();

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Report an issue'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          TextField(
            controller: _reason,
            minLines: 3,
            maxLines: 5,
            decoration: appInputDecoration(
              context,
              label: 'What is wrong with this question?',
            ),
          ),
          const FreeTextHint(),
        ],
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, _reason.text.trim()),
          child: const Text('Send'),
        ),
      ],
    );
  }
}
