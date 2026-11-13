import 'package:flutter/material.dart';
import 'package:round_ai/core/theme/app_colors.dart';
import 'package:round_ai/core/theme/app_typography.dart';
import 'package:round_ai/features/census/data/demo_patients.dart';
import 'package:round_ai/features/patient/data/patient_workspace.dart';
import 'package:round_ai/shared/widgets/ai_state.dart';

/// Patient-scoped drawer. It only reads the selected patient's workspace and
/// never changes a note, problem, task, or order.
Future<void> showAskPatientSheet(BuildContext context, CensusPatient patient) {
  final AppColors colors = AppColors.of(context);
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: colors.surface,
    showDragHandle: true,
    builder: (BuildContext sheetContext) {
      return FractionallySizedBox(
        heightFactor: 0.85,
        child: AskPatientSheet(patient: patient),
      );
    },
  );
}

class AskAnswer {
  const AskAnswer({
    required this.question,
    required this.label,
    required this.lines,
    required this.state,
  });

  final String question;

  /// `From chart`, `AI interpretation`, `External evidence`, or `Suggested question`.
  final String label;
  final List<String> lines;
  final AiState state;
}

/// Routes a question to a workflow instead of one open prompt.
AskAnswer answerFor(
  String question,
  CensusPatient patient,
  PatientWorkspace? workspace,
) {
  final String q = question.toLowerCase();
  if (workspace == null) {
    return AskAnswer(
      question: question,
      label: 'Access denied',
      lines: const <String>['This patient is not on your team.'],
      state: AiState.accessDenied,
    );
  }
  final bool asksEvidence = RegExp(
    r'stud(y|ies)|evidence|trial|guideline|research|literature',
  ).hasMatch(q);
  final bool asksChart = RegExp(
    r'course|chart|changed|today|missing|summar',
  ).hasMatch(q);

  if (asksEvidence && asksChart) {
    return AskAnswer(
      question: question,
      label: 'Chart and evidence, kept separate',
      lines: <String>[
        'From chart: ${workspace.changes.join(' ')}',
        'External evidence: No relevant recent studies found in the searched sources.',
      ],
      state: AiState.partial,
    );
  }
  if (asksEvidence) {
    return AskAnswer(
      question: question,
      label: 'External evidence',
      lines: const <String>[
        'No relevant recent studies found in the searched sources.',
        'Evidence search is not connected in this build, so nothing is claimed as current.',
      ],
      state: AiState.noEvidence,
    );
  }
  if (q.contains('missing')) {
    return AskAnswer(
      question: question,
      label: 'From chart',
      lines: workspace.missing,
      state: AiState.draftReady,
    );
  }
  if (q.contains('changed') || q.contains('what changed')) {
    return AskAnswer(
      question: question,
      label: 'From chart',
      lines: workspace.changes,
      state: AiState.draftReady,
    );
  }
  if (q.contains('course') || q.contains('summar')) {
    return AskAnswer(
      question: question,
      label: 'From chart',
      lines: workspace.expandedReview,
      state: AiState.draftReady,
    );
  }
  if (q.contains('assessment') || q.contains('plan')) {
    return AskAnswer(
      question: question,
      label: 'Missing plan',
      lines: const <String>[
        'Today’s clinician plan is not entered. A draft assessment needs your plan first.',
        'Add the plan in Draft note, then ask again.',
      ],
      state: AiState.partial,
    );
  }
  if (q.contains('explain') || q.contains('problem')) {
    return AskAnswer(
      question: question,
      label: 'AI interpretation',
      lines: <String>[
        '${patient.problem}. ${patient.summary}',
        'This is an explanation of the chart, not a diagnosis or an order.',
      ],
      state: AiState.draftReady,
    );
  }
  if (q.contains('question') || q.contains('mcq') || q.contains('quiz')) {
    return AskAnswer(
      question: question,
      label: 'Suggested question',
      lines: <String>[
        'Open Teach me for a case-inspired question on: ${workspace.question.topic}.',
        'Questions are shown one at a time.',
      ],
      state: AiState.draftReady,
    );
  }
  return AskAnswer(
    question: question,
    label: 'Clarifying question',
    lines: const <String>[
      'Do you want chart facts for this patient, or recent evidence on the topic?',
    ],
    state: AiState.partial,
  );
}

class AskPatientSheet extends StatefulWidget {
  const AskPatientSheet({required this.patient, super.key});

  final CensusPatient patient;

  @override
  State<AskPatientSheet> createState() => _AskPatientSheetState();
}

class _AskPatientSheetState extends State<AskPatientSheet> {
  static const List<String> _prompts = <String>[
    'Summarize the hospital course',
    'What changed today?',
    'Draft today’s assessment using my plan',
    'Explain this problem',
    'Find recent studies',
    'Create three questions',
    'What information is missing?',
  ];

  final TextEditingController _controller = TextEditingController();
  final List<AskAnswer> _thread = <AskAnswer>[];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _ask(String question) {
    final String text = question.trim();
    if (text.isEmpty) return;
    setState(() {
      _thread.add(
        answerFor(text, widget.patient, workspaceFor(widget.patient.id)),
      );
      _controller.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final AppColors colors = AppColors.of(context);
    final CensusPatient patient = widget.patient;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: Column(
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
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
                  '${patient.name} · Room ${patient.room} · ${patient.updatedLabel}',
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
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
              children: <Widget>[
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _prompts
                      .map(
                        (String p) => ActionChip(
                          label: Text(p),
                          onPressed: () => _ask(p),
                        ),
                      )
                      .toList(),
                ),
                const SizedBox(height: 16),
                ..._thread.map((AskAnswer a) => _AnswerCard(answer: a)),
              ],
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      textInputAction: TextInputAction.send,
                      onSubmitted: _ask,
                      decoration: const InputDecoration(
                        hintText: 'Ask about this patient',
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Send',
                    onPressed: () => _ask(_controller.text),
                    icon: const Icon(Icons.send_rounded),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AnswerCard extends StatelessWidget {
  const _AnswerCard({required this.answer});

  final AskAnswer answer;

  @override
  Widget build(BuildContext context) {
    final AppColors colors = AppColors.of(context);
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
            answer.question,
            style: AppTypography.semiBold(
              fontSize: 14,
              color: colors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: <Widget>[
              AiStateChip(state: answer.state),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  answer.label,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.medium(
                    fontSize: 11,
                    color: colors.aiAccent,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ...answer.lines.map(
            (String line) => Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(
                line,
                style: AppTypography.regular(
                  height: 1.4,
                  color: colors.textPrimary,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
