import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:round_ai/core/network/api_error.dart';
import 'package:round_ai/core/theme/app_colors.dart';
import 'package:round_ai/core/theme/app_typography.dart';
import 'package:round_ai/features/ai/bloc/ask_cubit.dart';
import 'package:round_ai/features/ai/models/ai_envelope.dart';
import 'package:round_ai/features/ai/models/ask_reply.dart';
import 'package:round_ai/features/ai/repository/ai_repository.dart';
import 'package:round_ai/features/ai/widgets/claim_tile.dart';
import 'package:round_ai/features/ai/widgets/evidence_card_view.dart';
import 'package:round_ai/features/ai/widgets/placeholder_text.dart';
import 'package:round_ai/features/ai/widgets/source_drawer.dart';
import 'package:round_ai/features/census/models/patient_summary.dart';
import 'package:round_ai/shared/widgets/ai_state.dart';
import 'package:round_ai/shared/widgets/app_input.dart';

/// The seven suggested questions. They are shortcuts, not special routes.
const List<String> askSuggestions = <String>[
  'Summarize the hospital course',
  'What changed today?',
  'Draft today’s assessment using my plan',
  'Explain this problem',
  'Find recent studies',
  'Create three questions',
  'What information is missing?',
];

/// Ask about one patient, on the real backend. Read-only: an answer never
/// changes a note, problem, task or order.
Future<void> showAskSheet(
  BuildContext context, {
  required AiRepository repository,
  required PatientSummary patient,
  required bool aiOff,
  List<String> topics = const <String>[],
}) {
  final AppColors colors = AppColors.of(context);
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: colors.surface,
    showDragHandle: true,
    builder: (BuildContext sheetContext) {
      return FractionallySizedBox(
        heightFactor: 0.9,
        child: AskSheet(
          repository: repository,
          patient: patient,
          aiOff: aiOff,
          topics: topics,
        ),
      );
    },
  );
}

class AskSheet extends StatelessWidget {
  const AskSheet({
    required this.repository,
    required this.patient,
    required this.aiOff,
    this.topics = const <String>[],
    super.key,
  });

  final AiRepository repository;
  final PatientSummary patient;
  final bool aiOff;

  /// Confirmed or differential problems the user can pick as a topic.
  final List<String> topics;

  @override
  Widget build(BuildContext context) {
    return BlocProvider<AskCubit>(
      create: (_) => AskCubit(repository, patient.id),
      child: _AskView(
        repository: repository,
        patient: patient,
        aiOff: aiOff,
        topics: topics,
      ),
    );
  }
}

class _AskView extends StatefulWidget {
  const _AskView({
    required this.repository,
    required this.patient,
    required this.aiOff,
    required this.topics,
  });

  final AiRepository repository;
  final PatientSummary patient;
  final bool aiOff;
  final List<String> topics;

  @override
  State<_AskView> createState() => _AskViewState();
}

class _AskViewState extends State<_AskView> {
  final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _ask(String question) {
    final String text = question.trim();
    if (text.isEmpty) return;
    context.read<AskCubit>().ask(text);
    _controller.clear();
  }

  @override
  Widget build(BuildContext context) {
    final AppColors colors = AppColors.of(context);
    final PatientSummary patient = widget.patient;
    return BlocBuilder<AskCubit, AskState>(
      builder: (BuildContext context, AskState state) {
        final bool blocked = widget.aiOff || state.busy;
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.viewInsetsOf(context).bottom,
          ),
          child: Column(
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        'Ask about this patient',
                        style: AppTypography.bold(
                          fontSize: 20,
                          color: colors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        <String>[
                          patient.displayName,
                          if (patient.room.isNotEmpty) 'Room ${patient.room}',
                        ].join(' · '),
                        style: AppTypography.regular(
                          fontSize: 12,
                          color: colors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Scope: this patient and this team only. Read-only.',
                        style: AppTypography.regular(
                          fontSize: 12,
                          color: colors.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                  children: <Widget>[
                    if (widget.aiOff)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Text(
                          'AI is temporarily off. Manual entry still works.',
                          style: AppTypography.regular(
                            fontSize: 13,
                            color: colors.critical,
                          ),
                        ),
                      ),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: <Widget>[
                        for (final String prompt in askSuggestions)
                          ActionChip(
                            label: Text(prompt),
                            onPressed: blocked ? null : () => _ask(prompt),
                          ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    for (final AskTurn turn in state.turns)
                      _TurnCard(
                        turn: turn,
                        repository: widget.repository,
                        topics: widget.topics,
                        canRetry: !blocked,
                      ),
                  ],
                ),
              ),
              SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Row(
                        children: <Widget>[
                          Expanded(
                            child: TextField(
                              controller: _controller,
                              enabled: !blocked,
                              textInputAction: TextInputAction.send,
                              onSubmitted: _ask,
                              decoration: const InputDecoration(
                                hintText: 'Ask about this patient',
                              ),
                            ),
                          ),
                          IconButton(
                            tooltip: 'Send',
                            onPressed: blocked
                                ? null
                                : () => _ask(_controller.text),
                            icon: const Icon(Icons.send_rounded),
                          ),
                        ],
                      ),
                      const FreeTextHint(),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _TurnCard extends StatelessWidget {
  const _TurnCard({
    required this.turn,
    required this.repository,
    required this.topics,
    required this.canRetry,
  });

  final AskTurn turn;
  final AiRepository repository;
  final List<String> topics;
  final bool canRetry;

  @override
  Widget build(BuildContext context) {
    final AppColors colors = AppColors.of(context);
    final AskCubit cubit = context.read<AskCubit>();
    final AskReply? reply = turn.reply;
    final ApiError? error = turn.error;
    final AiState chip = switch (turn.status) {
      TurnStatus.loading => AiState.loading,
      TurnStatus.failed => AiState.fromError(error!),
      TurnStatus.done => switch (reply!.status) {
        AskStatus.refused => AiState.refused,
        AskStatus.needsTopic => AiState.partial,
        AskStatus.ok => reply.partial ? AiState.partial : AiState.draftReady,
      },
    };
    final bool aiContent =
        turn.status == TurnStatus.done && reply!.status == AskStatus.ok;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colors.aiCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.aiBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            turn.topic == null
                ? turn.question
                : '${turn.question} · Topic: ${turn.topic}',
            style: AppTypography.semiBold(
              fontSize: 14,
              color: colors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: <Widget>[
              AiStateChip(state: chip),
              if (aiContent)
                Text(
                  'AI draft · review required',
                  style: AppTypography.medium(
                    fontSize: 11,
                    color: colors.aiAccent,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          switch (turn.status) {
            TurnStatus.loading => Row(
              children: <Widget>[
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Working on it. This can take up to a minute.',
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
            ),
            TurnStatus.failed => Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  error!.userMessage,
                  style: AppTypography.regular(color: colors.critical),
                ),
                if (error.isRetryable && canRetry)
                  TextButton(
                    onPressed: () => cubit.retry(turn.id),
                    child: const Text('Retry'),
                  ),
              ],
            ),
            TurnStatus.done => _Reply(
              turn: turn,
              reply: reply!,
              repository: repository,
              topics: topics,
              canAsk: canRetry,
            ),
          },
        ],
      ),
    );
  }
}

class _Reply extends StatefulWidget {
  const _Reply({
    required this.turn,
    required this.reply,
    required this.repository,
    required this.topics,
    required this.canAsk,
  });

  final AskTurn turn;
  final AskReply reply;
  final AiRepository repository;
  final List<String> topics;
  final bool canAsk;

  @override
  State<_Reply> createState() => _ReplyState();
}

class _ReplyState extends State<_Reply> {
  final TextEditingController _topic = TextEditingController();

  @override
  void dispose() {
    _topic.dispose();
    super.dispose();
  }

  void _useTopic(String topic) {
    if (topic.trim().isEmpty) return;
    context.read<AskCubit>().answerTopic(widget.turn.id, topic);
  }

  @override
  Widget build(BuildContext context) {
    final AppColors colors = AppColors.of(context);
    final AskReply reply = widget.reply;
    final TextStyle body = AppTypography.regular(
      height: 1.4,
      color: colors.textPrimary,
    );
    switch (reply.status) {
      case AskStatus.refused:
        return Text(
          reply.message.isEmpty
              ? 'This question cannot be answered for this patient.'
              : reply.message,
          style: body,
        );
      case AskStatus.needsTopic:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              reply.message.isEmpty
                  ? 'Which topic should this be about? Pick a confirmed '
                        'problem or type a topic.'
                  : reply.message,
              style: body,
            ),
            if (widget.topics.isNotEmpty) ...<Widget>[
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: <Widget>[
                  for (final String t in widget.topics)
                    ActionChip(
                      label: Text(t),
                      onPressed: widget.canAsk ? () => _useTopic(t) : null,
                    ),
                ],
              ),
            ],
            const SizedBox(height: 8),
            TextField(
              controller: _topic,
              enabled: widget.canAsk,
              decoration: appInputDecoration(
                context,
                label: 'Topic',
                hint: 'A generic clinical topic',
              ),
              onSubmitted: _useTopic,
            ),
            const FreeTextHint(),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: widget.canAsk ? () => _useTopic(_topic.text) : null,
                child: const Text('Ask with this topic'),
              ),
            ),
          ],
        );
      case AskStatus.ok:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            if (reply.message.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: PlaceholderText(reply.message, style: body),
              ),
            for (final Claim claim in reply.claims)
              ClaimTile(
                claim: claim,
                onTap: () => showSourceDrawer(
                  context,
                  claim: claim,
                  repository: widget.repository,
                  evidence: reply.evidence,
                ),
              ),
            if (reply.partial)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  reply.issueCount == 0
                      ? 'Partial result. Some parts were withheld by validation.'
                      : 'Partial result. ${reply.issueCount} '
                            '${reply.issueCount == 1 ? 'part was' : 'parts were'} '
                            'withheld by validation.',
                  style: AppTypography.regular(
                    fontSize: 12,
                    color: colors.warning,
                  ),
                ),
              ),
            if (reply.evidence.isNotEmpty ||
                reply.retrieval != null) ...<Widget>[
              const SizedBox(height: 10),
              Text(
                'External evidence',
                style: AppTypography.semiBold(
                  fontSize: 13,
                  color: colors.textPrimary,
                ),
              ),
              const SizedBox(height: 6),
              if (reply.evidence.isEmpty)
                Text(
                  noEvidenceMessage,
                  style: AppTypography.regular(color: colors.textSecondary),
                )
              else
                for (final card in reply.evidence) EvidenceCardView(card: card),
              if (reply.retrieval != null)
                EvidenceRetrievalView(retrieval: reply.retrieval!),
            ],
          ],
        );
    }
  }
}
