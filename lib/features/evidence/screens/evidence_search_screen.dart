import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:round_ai/core/di/injection_container.dart';
import 'package:round_ai/core/network/api_error.dart';
import 'package:round_ai/core/router/app_routes.dart';
import 'package:round_ai/core/theme/app_colors.dart';
import 'package:round_ai/core/theme/app_typography.dart';
import 'package:round_ai/features/authentication/repository/profile_repository.dart';
import 'package:round_ai/features/evidence/bloc/evidence_cubit.dart';
import 'package:round_ai/features/evidence/models/evidence_result.dart';
import 'package:round_ai/features/evidence/repository/evidence_repository.dart';
import 'package:round_ai/features/ai/widgets/evidence_card_view.dart';
import 'package:round_ai/features/patient/models/evidence_card.dart';
import 'package:round_ai/features/patient/models/problem.dart';
import 'package:round_ai/features/patient/widgets/chart_entry_scaffold.dart';
import 'package:round_ai/features/problems/repository/problems_repository.dart';
import 'package:round_ai/shared/widgets/ai_error_box.dart';
import 'package:round_ai/shared/widgets/ai_state.dart';
import 'package:round_ai/shared/widgets/app_input.dart';

const String evidenceAiOffMessage =
    'AI is temporarily off. Manual entry still works.';

/// Evidence search on the real backend. Studies come only from the
/// retrieved list. An empty search says so and shows nothing else.
class EvidenceSearchScreen extends StatelessWidget {
  const EvidenceSearchScreen({
    required this.patientId,
    this.evidenceRepository,
    this.problemsRepository,
    this.aiOff,
    this.onOpen,
    super.key,
  });

  final String patientId;
  final EvidenceRepository? evidenceRepository;
  final ProblemsRepository? problemsRepository;

  /// Tests set this. The app reads the profile.
  final bool? aiOff;

  /// Opens a PMID link. Tests pass their own.
  final Future<bool> Function(Uri uri)? onOpen;

  @override
  Widget build(BuildContext context) {
    final InjectionContainer di = InjectionContainer.instance;
    return BlocProvider<EvidenceCubit>(
      create: (_) => EvidenceCubit(
        evidenceRepository ?? di.evidenceRepository,
        problemsRepository ?? di.problemsRepository,
        patientId,
      )..loadProblems(),
      child: _EvidenceView(
        patientId: patientId,
        aiOff: aiOff ?? di.profileRepository.aiOff,
        onOpen: onOpen,
      ),
    );
  }
}

class _EvidenceView extends StatefulWidget {
  const _EvidenceView({
    required this.patientId,
    required this.aiOff,
    required this.onOpen,
  });

  final String patientId;
  final bool aiOff;
  final Future<bool> Function(Uri uri)? onOpen;

  @override
  State<_EvidenceView> createState() => _EvidenceViewState();
}

class _EvidenceViewState extends State<_EvidenceView> {
  final TextEditingController _topic = TextEditingController();
  String? _problemId;

  @override
  void dispose() {
    _topic.dispose();
    super.dispose();
  }

  bool get _ready => _problemId != null || _topic.text.trim().isNotEmpty;

  void _search() {
    context.read<EvidenceCubit>().search(
      problemId: _problemId,
      topic: _topic.text,
    );
  }

  @override
  Widget build(BuildContext context) {
    final AppColors colors = AppColors.of(context);
    return BlocBuilder<EvidenceCubit, EvidenceState>(
      builder: (BuildContext context, EvidenceState state) {
        final EvidenceCubit cubit = context.read<EvidenceCubit>();
        final ApiError? error = state.error;
        return ChartEntryScaffold(
          title: 'Explore evidence',
          bottom: state.searching
              ? AiProgressRow(
                  message: 'Searching. This can take up to a minute.',
                  onCancel: cubit.cancel,
                )
              : SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: widget.aiOff || !_ready ? null : _search,
                    icon: const Icon(Icons.search_rounded, size: 18),
                    label: const Text('Search evidence'),
                  ),
                ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              AiStateChip(state: state.aiState),
              const SizedBox(height: 10),
              Text(
                'Search uses the condition or topic only. The patient name, '
                'room and chart text are not sent.',
                style: AppTypography.regular(
                  fontSize: 13,
                  height: 1.4,
                  color: colors.textSecondary,
                ),
              ),
              const SizedBox(height: 14),
              Text(
                'A problem on this patient',
                style: AppTypography.semiBold(fontSize: 14),
              ),
              const SizedBox(height: 8),
              if (state.problemsLoading)
                const Padding(
                  padding: EdgeInsets.all(8),
                  child: SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
              else if (state.problems.isEmpty)
                Text(
                  'No confirmed or differential problems yet. Confirm one on '
                  'the overview, or type a topic below.',
                  style: AppTypography.regular(
                    fontSize: 13,
                    color: colors.textSecondary,
                  ),
                )
              else
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: <Widget>[
                    for (final Problem p in state.problems)
                      ChoiceChip(
                        label: Text(p.label),
                        selected: _problemId == p.id,
                        onSelected: state.searching
                            ? null
                            : (bool on) => setState(() {
                                _problemId = on ? p.id : null;
                                if (on) _topic.clear();
                              }),
                      ),
                  ],
                ),
              const SizedBox(height: 14),
              TextField(
                controller: _topic,
                enabled: !state.searching,
                onChanged: (String _) => setState(() {
                  if (_topic.text.isNotEmpty) _problemId = null;
                }),
                decoration: appInputDecoration(
                  context,
                  label: 'Or type a topic',
                  hint: 'A generic clinical topic',
                ),
              ),
              const FreeTextHint(),
              if (widget.aiOff) ...<Widget>[
                const SizedBox(height: 10),
                Text(
                  evidenceAiOffMessage,
                  style: AppTypography.regular(
                    fontSize: 12,
                    color: colors.critical,
                  ),
                ),
              ],
              if (error != null) ...<Widget>[
                const SizedBox(height: 12),
                AiErrorBox(
                  error: error,
                  onRetry: error.isRetryable ? cubit.retry : null,
                  onReviewFacts: error.kind == ApiErrorKind.noReviewedFacts
                      ? () => context.push<Object>(
                          AppRoutes.patientFactsPath(widget.patientId),
                        )
                      : null,
                ),
              ],
              if (state.result != null) ...<Widget>[
                const SizedBox(height: 18),
                _Results(
                  result: state.result!,
                  label: state.searchedLabel,
                  onOpen: widget.onOpen,
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _Results extends StatelessWidget {
  const _Results({
    required this.result,
    required this.label,
    required this.onOpen,
  });

  final EvidenceResult result;
  final String? label;
  final Future<bool> Function(Uri uri)? onOpen;

  @override
  Widget build(BuildContext context) {
    final AppColors colors = AppColors.of(context);
    final String topic = (label == null || label!.isEmpty)
        ? result.topic
        : label!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        if (topic.isNotEmpty)
          Text(
            topic,
            style: AppTypography.bold(fontSize: 18, color: colors.navy),
          ),
        const SizedBox(height: 6),
        // The studies are retrieved records. How they apply to this patient
        // is written by a model, so it is a draft.
        Text(
          'AI draft · review required',
          style: AppTypography.medium(fontSize: 11, color: colors.aiAccent),
        ),
        Text(
          'Studies are retrieved records. The notes on how they apply to '
          'your patient are a draft. This is not a treatment recommendation.',
          style: AppTypography.regular(
            fontSize: 12,
            height: 1.4,
            color: colors.textSecondary,
          ),
        ),
        const SizedBox(height: 10),
        if (result.isEmpty)
          Text(
            noEvidenceMessage,
            style: AppTypography.regular(
              height: 1.45,
              color: colors.textPrimary,
            ),
          )
        else
          for (final EvidenceCard card in result.cards)
            onOpen == null
                ? EvidenceCardView(card: card)
                : EvidenceCardView(card: card, onOpen: onOpen!),
        if (result.retrieval != null)
          EvidenceRetrievalView(retrieval: result.retrieval!),
      ],
    );
  }
}
