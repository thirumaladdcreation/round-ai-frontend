import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:round_ai/core/network/api_error.dart';
import 'package:round_ai/core/router/app_routes.dart';
import 'package:round_ai/core/theme/app_colors.dart';
import 'package:round_ai/core/theme/app_typography.dart';
import 'package:round_ai/features/ai/models/ai_envelope.dart';
import 'package:round_ai/features/ai/repository/ai_repository.dart';
import 'package:round_ai/features/ai/widgets/source_drawer.dart';
import 'package:round_ai/features/patient/models/problem.dart';
import 'package:round_ai/features/problems/bloc/problems_cubit.dart';
import 'package:round_ai/features/problems/models/coding_suggestion.dart';
import 'package:round_ai/features/problems/repository/problems_repository.dart';
import 'package:round_ai/features/problems/widgets/coding_suggest_sheet.dart';
import 'package:round_ai/core/config/app_environment.dart';

const String problemsAiOffMessage =
    'AI is temporarily off. Manual entry still works.';

/// The problem list on the overview, on the real backend.
///
/// A problem the model suggests is shown as a suggestion, never as
/// confirmed. It changes only when the clinician taps a decision.
class ProblemsCard extends StatelessWidget {
  const ProblemsCard({
    required this.patientId,
    required this.initial,
    required this.aiOff,
    required this.onChanged,
    this.repository,
    this.aiRepository,
    super.key,
  });

  final String patientId;
  final List<Problem> initial;
  final bool aiOff;
  final VoidCallback onChanged;
  final ProblemsRepository? repository;
  final AiRepository? aiRepository;

  @override
  Widget build(BuildContext context) {
    final ProblemsRepository source =
        repository ?? context.read<ProblemsRepository>();
    final AiRepository ai = aiRepository ?? context.read<AiRepository>();
    return BlocProvider<ProblemsCubit>(
      create: (_) => ProblemsCubit(source, patientId, initial: initial)..load(),
      child: _ProblemsView(
        patientId: patientId,
        aiOff: aiOff,
        aiRepository: ai,
        problemsRepository: source,
        onChanged: onChanged,
      ),
    );
  }
}

class _ProblemsView extends StatelessWidget {
  const _ProblemsView({
    required this.patientId,
    required this.aiOff,
    required this.aiRepository,
    required this.problemsRepository,
    required this.onChanged,
  });

  final String patientId;
  final bool aiOff;
  final AiRepository aiRepository;
  final ProblemsRepository problemsRepository;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final AppColors colors = AppColors.of(context);
    return BlocConsumer<ProblemsCubit, ProblemsState>(
      listenWhen: (ProblemsState a, ProblemsState b) => a.changes != b.changes,
      listener: (BuildContext context, ProblemsState state) => onChanged(),
      builder: (BuildContext context, ProblemsState state) {
        final ProblemsCubit cubit = context.read<ProblemsCubit>();
        final ApiError? error = state.error;
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: colors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text('Problems', style: AppTypography.semiBold(fontSize: 15)),
              const SizedBox(height: 8),
              if (state.problems.isEmpty)
                Text(
                  state.suggestedCount == 0
                      ? 'No problems were suggested from the confirmed facts.'
                      : 'No problems yet. Suggestions are built only from '
                            'chart facts you have confirmed.',
                  style: AppTypography.regular(color: colors.textSecondary),
                ),
              for (final Problem problem in state.problems)
                _ProblemRow(
                  patientId: patientId,
                  problem: problem,
                  busy: state.busyId == problem.id,
                  locked: state.busyId != null,
                  aiOff: aiOff,
                  aiRepository: aiRepository,
                  problemsRepository: problemsRepository,
                  onCodingChanged: () async {
                    await cubit.load();
                    onChanged();
                  },
                ),
              if (error != null) ...<Widget>[
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: colors.criticalBg,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        error.userMessage,
                        style: AppTypography.regular(
                          fontSize: 13,
                          color: colors.critical,
                        ),
                      ),
                      if (error.kind == ApiErrorKind.noReviewedFacts)
                        TextButton(
                          onPressed: () async {
                            await context.push<Object>(
                              AppRoutes.patientFactsPath(patientId),
                            );
                            onChanged();
                          },
                          child: const Text('Review chart facts first'),
                        ),
                      if (error.isRetryable)
                        TextButton(
                          onPressed: cubit.suggest,
                          child: const Text('Retry'),
                        ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 8),
              if (state.suggesting)
                Row(
                  children: <Widget>[
                    const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Looking for problems. This can take up to a minute.',
                        style: AppTypography.regular(
                          fontSize: 12,
                          color: colors.textSecondary,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: cubit.cancel,
                      child: const Text('Cancel'),
                    ),
                  ],
                )
              else ...<Widget>[
                TextButton.icon(
                  onPressed: aiOff ? null : cubit.suggest,
                  icon: const Icon(Icons.auto_awesome, size: 18),
                  label: Text(
                    'Suggest problems',
                    style: AppTypography.medium(fontSize: 14),
                  ),
                ),
                if (aiOff)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      problemsAiOffMessage,
                      style: AppTypography.regular(
                        fontSize: 13,
                        color: colors.critical,
                      ),
                    ),
                  ),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _ProblemRow extends StatelessWidget {
  const _ProblemRow({
    required this.patientId,
    required this.problem,
    required this.busy,
    required this.locked,
    required this.aiOff,
    required this.aiRepository,
    required this.problemsRepository,
    required this.onCodingChanged,
  });

  final String patientId;
  final Problem problem;
  final bool busy;
  final bool locked;
  final bool aiOff;
  final AiRepository aiRepository;
  final ProblemsRepository problemsRepository;
  final VoidCallback onCodingChanged;

  Future<void> _suggestCodes(BuildContext context) async {
    final AcceptedCodeSuggestion? accepted = await showCodingSuggestSheet(
      context,
      patientId: patientId,
      problem: problem,
      repository: problemsRepository,
      aiRepository: aiRepository,
    );
    if (accepted != null) onCodingChanged();
  }

  @override
  Widget build(BuildContext context) {
    final AppColors colors = AppColors.of(context);
    final ProblemsCubit cubit = context.read<ProblemsCubit>();
    final bool suggested = problem.state == ProblemState.suggested;
    final bool documented = problem.state == ProblemState.documented;
    final bool rejected = problem.state == ProblemState.rejected;
    final bool decidable = suggested || documented;
    final bool coding =
        problem.state.canSuggestCodes && !AppEnvironment.useDemo;
    final AcceptedCodeSuggestion? code = problem.codeSuggestion;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Expanded(
                child: Text(
                  problem.label,
                  style:
                      AppTypography.regular(
                        height: 1.35,
                        color: rejected ? colors.textMuted : colors.textPrimary,
                      ).copyWith(
                        decoration: rejected
                            ? TextDecoration.lineThrough
                            : null,
                      ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                problem.state.label,
                style: AppTypography.medium(
                  fontSize: 13,
                  color: suggested ? colors.aiAccent : colors.textSecondary,
                ),
              ),
            ],
          ),
          if (suggested)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                'AI draft · review required',
                style: AppTypography.medium(
                  fontSize: 11,
                  color: colors.aiAccent,
                ),
              ),
            ),
          if (code != null) ...<Widget>[
            const SizedBox(height: 4),
            Text(
              '${code.code} · ${code.description}',
              style: AppTypography.semiBold(
                fontSize: 14,
                color: colors.textPrimary,
              ),
            ),
            Text(
              code.label,
              style: AppTypography.regular(
                fontSize: 13,
                color: colors.textSecondary,
              ),
            ),
          ],
          if (problem.factIds.isNotEmpty)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  minimumSize: const Size(0, 32),
                ),
                onPressed: () => showSourceDrawer(
                  context,
                  claim: Claim(
                    text: problem.label,
                    label: ClaimLabel.fromChart,
                    factIds: problem.factIds,
                  ),
                  repository: aiRepository,
                ),
                icon: const Icon(Icons.link_rounded, size: 16),
                label: Text(
                  problem.factIds.length == 1
                      ? 'Source (1 fact)'
                      : 'Sources (${problem.factIds.length} facts)',
                ),
              ),
            ),
          if (decidable)
            busy
                ? const Padding(
                    padding: EdgeInsets.all(8),
                    child: SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                : Wrap(
                    spacing: 8,
                    children: <Widget>[
                      FilledButton.tonal(
                        onPressed: locked
                            ? null
                            : () => cubit.decide(problem, ProblemAction.accept),
                        child: Text(suggested ? 'Accept' : 'Confirm'),
                      ),
                      OutlinedButton(
                        onPressed: locked
                            ? null
                            : () => cubit.decide(
                                problem,
                                ProblemAction.differential,
                              ),
                        child: const Text('Differential'),
                      ),
                      OutlinedButton(
                        onPressed: locked
                            ? null
                            : () => cubit.decide(problem, ProblemAction.reject),
                        child: const Text('Reject'),
                      ),
                    ],
                  ),
          if (coding)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  minimumSize: const Size(0, 36),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                onPressed: aiOff || locked
                    ? null
                    : () => _suggestCodes(context),
                icon: const Icon(Icons.medical_information_outlined, size: 18),
                label: Text(
                  code == null ? 'Suggest codes' : 'Suggest codes again',
                  style: AppTypography.medium(fontSize: 14),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
