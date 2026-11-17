import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:round_ai/core/di/injection_container.dart';
import 'package:round_ai/core/errors/failures.dart';
import 'package:round_ai/core/errors/result.dart';
import 'package:round_ai/core/network/idempotency_key.dart';
import 'package:round_ai/core/router/app_routes.dart';
import 'package:round_ai/core/theme/app_colors.dart';
import 'package:round_ai/core/theme/app_typography.dart';
import 'package:round_ai/core/utils/external_link.dart';
import 'package:round_ai/features/learning/models/teaching_question.dart';
import 'package:round_ai/features/learning/repository/demo_teaching_repository.dart';
import 'package:round_ai/features/learning/repository/teaching_repository.dart';
import 'package:round_ai/shared/widgets/app_button.dart';

class TopicQuizScreen extends StatefulWidget {
  const TopicQuizScreen({
    required this.topic,
    this.repository,
    super.key,
  });

  final String topic;
  final TeachingRepository? repository;

  @override
  State<TopicQuizScreen> createState() => _TopicQuizScreenState();
}

class _TopicQuizScreenState extends State<TopicQuizScreen> {
  bool _allowGenerate = false;
  bool _loading = true;
  String? _error;
  TeachingQuestion? _question;
  String? _selected;
  McqAnswerResult? _answer;
  bool _submitting = false;
  late String _idempotencyKey = IdempotencyKey.create();
  final Stopwatch _timer = Stopwatch();

  TeachingRepository get _repo {
    if (widget.repository != null) return widget.repository!;
    try {
      return InjectionContainer.instance.teachingRepository;
    } catch (_) {
      return DemoTeachingRepository();
    }
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
      _question = null;
      _answer = null;
      _selected = null;
    });
    final Result<TeachingQuestionsResult> result = await _repo.loadQuestions(
      topic: widget.topic,
      count: 1,
      allowGenerate: _allowGenerate,
      idempotencyKey: _idempotencyKey,
    );
    if (!mounted) return;
    setState(() => _loading = false);
    switch (result) {
      case Ok<TeachingQuestionsResult>(:final TeachingQuestionsResult value):
        if (value.questions.isEmpty) {
          setState(
            () => _error = _allowGenerate
                ? 'No questions came back. Try again, or leave AI drafts off '
                    'and use the admin-approved bank.'
                : 'No approved questions for “${widget.topic}” yet. '
                    'Re-seed the demo DB (npm run seed after deleting the SQLite file) '
                    'so Elevated Pulse / AKI banks load, or ask an admin to approve '
                    'questions. You can also enable “Include AI-generated drafts” '
                    'for labeled, unreviewed practice only.',
          );
        } else {
          setState(() {
            _question = value.questions.first;
            _timer
              ..reset()
              ..start();
          });
        }
      case Err<TeachingQuestionsResult>(:final Failure failure):
        setState(() => _error = failure.message);
    }
  }

  Future<void> _submit() async {
    final TeachingQuestion? q = _question;
    final String? choice = _selected;
    if (q == null || choice == null || _submitting) return;
    setState(() => _submitting = true);
    final Result<McqAnswerResult> result = await _repo.answer(
      mcqId: q.mcqId,
      choice: choice,
      seconds: _timer.elapsed.inSeconds,
    );
    if (!mounted) return;
    setState(() => _submitting = false);
    switch (result) {
      case Ok<McqAnswerResult>(:final McqAnswerResult value):
        _timer.stop();
        setState(() => _answer = value);
      case Err<McqAnswerResult>(:final Failure failure):
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(failure.message)));
    }
  }

  Future<void> _report() async {
    final TeachingQuestion? q = _question;
    if (q == null) return;
    final String? note = await showDialog<String>(
      context: context,
      builder: (BuildContext ctx) => const _ReportDialog(),
    );
    if (note == null) return;
    final Result<void> result = await _repo.report(
      mcqId: q.mcqId,
      note: note.isEmpty ? null : note,
    );
    if (!mounted) return;
    switch (result) {
      case Ok<void>():
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Issue reported. This question is under review.'),
          ),
        );
        _idempotencyKey = IdempotencyKey.create();
        await _load();
      case Err<void>(:final Failure failure):
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(failure.message)));
    }
  }

  Future<void> _next() async {
    _idempotencyKey = IdempotencyKey.create();
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final AppColors colors = AppColors.of(context);
    final TeachingQuestion? q = _question;
    final McqAnswerResult? answer = _answer;

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        title: Text(widget.topic),
        actions: <Widget>[
          TextButton(
            onPressed: () => context.push(
              AppRoutes.topicReadsPath(widget.topic),
            ),
            child: const Text('Reads'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
        children: <Widget>[
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(
              'Include AI-generated drafts',
              style: AppTypography.semiBold(
                fontSize: 14,
                color: colors.textPrimary,
              ),
            ),
            subtitle: Text(
              'Drafts are labeled unreviewed and are for education only.',
              style: AppTypography.regular(
                fontSize: 12,
                color: colors.textSecondary,
              ),
            ),
            value: _allowGenerate,
            onChanged: _loading
                ? null
                : (bool v) {
                    setState(() => _allowGenerate = v);
                    _idempotencyKey = IdempotencyKey.create();
                    _load();
                  },
          ),
          const SizedBox(height: 8),
          if (_loading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 40),
              child: Center(child: CircularProgressIndicator()),
            ),
          if (_error != null) ...<Widget>[
            Text(
              _error!,
              style: AppTypography.regular(color: colors.critical),
            ),
            const SizedBox(height: 12),
            AppButton(label: 'Try again', onPressed: _load, expand: false),
          ],
          if (q != null) ...<Widget>[
            if (q.isUnreviewed || q.learnerLabel.isNotEmpty)
              Container(
                width: double.infinity,
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: colors.aiCard,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: colors.aiBorder),
                ),
                child: Text(
                  q.learnerLabel.isNotEmpty
                      ? q.learnerLabel
                      : 'AI-generated (unreviewed)',
                  style: AppTypography.semiBold(
                    fontSize: 12,
                    color: colors.aiAccent,
                  ),
                ),
              ),
            if (q.vignette.isNotEmpty) ...<Widget>[
              Text(
                q.vignette,
                style: AppTypography.regular(height: 1.45, color: colors.textPrimary),
              ),
              const SizedBox(height: 12),
            ],
            Text(
              q.question,
              style: AppTypography.semiBold(
                fontSize: 16,
                color: colors.textPrimary,
              ),
            ),
            const SizedBox(height: 12),
            ...q.options.map((McqOption o) {
              final bool selected = _selected == o.letter;
              final bool showKey =
                  answer != null && o.letter == answer.correctAnswer;
              final bool wrongPick =
                  answer != null && selected && !answer.correct;
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Material(
                  color: showKey
                      ? colors.successSoft
                      : wrongPick
                      ? colors.critical.withValues(alpha: 0.08)
                      : colors.surface,
                  borderRadius: BorderRadius.circular(12),
                  child: InkWell(
                    onTap: answer != null
                        ? null
                        : () => setState(() => _selected = o.letter),
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: selected ? colors.primary : colors.border,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            '${o.letter}. ${o.text}',
                            style: AppTypography.regular(
                              height: 1.4,
                              color: colors.textPrimary,
                            ),
                          ),
                          if (answer != null &&
                              answer.optionExplanations[o.letter] !=
                                  null) ...<Widget>[
                            const SizedBox(height: 6),
                            Text(
                              answer.optionExplanations[o.letter]!,
                              style: AppTypography.regular(
                                fontSize: 12,
                                color: colors.textSecondary,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              );
            }),
            if (answer == null) ...<Widget>[
              const SizedBox(height: 8),
              AppButton(
                label: _submitting ? 'Submitting…' : 'Submit',
                onPressed: _selected == null || _submitting ? null : _submit,
              ),
            ] else ...<Widget>[
              const SizedBox(height: 12),
              Text(
                answer.correct ? 'Correct' : 'Not correct',
                style: AppTypography.bold(
                  fontSize: 18,
                  color: answer.correct ? colors.success : colors.critical,
                ),
              ),
              if (answer.explanation.isNotEmpty) ...<Widget>[
                const SizedBox(height: 8),
                Text(
                  answer.explanation,
                  style: AppTypography.regular(
                    height: 1.4,
                    color: colors.textPrimary,
                  ),
                ),
              ],
              if (answer.learningObjective.isNotEmpty) ...<Widget>[
                const SizedBox(height: 8),
                Text(
                  'Objective · ${answer.learningObjective}',
                  style: AppTypography.regular(
                    fontSize: 13,
                    color: colors.textSecondary,
                  ),
                ),
              ],
              if (answer.references.isNotEmpty) ...<Widget>[
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: answer.references
                      .map(
                        (String pmid) => TextButton(
                          onPressed: () => openExternally(
                            Uri.parse(
                              'https://pubmed.ncbi.nlm.nih.gov/$pmid/',
                            ),
                          ),
                          child: Text('PMID $pmid'),
                        ),
                      )
                      .toList(),
                ),
              ],
              if (answer.nextReviewAt != null) ...<Widget>[
                const SizedBox(height: 6),
                Text(
                  'Next review scheduled (1 / 3 / 7 day spacing).',
                  style: AppTypography.regular(
                    fontSize: 12,
                    color: colors.textMuted,
                  ),
                ),
              ],
              const SizedBox(height: 16),
              AppButton(label: 'Next question', onPressed: _next),
            ],
            const SizedBox(height: 12),
            TextButton(
              onPressed: _report,
              child: const Text('Report issue'),
            ),
            if (q.notice.isNotEmpty)
              Text(
                q.notice,
                style: AppTypography.regular(
                  fontSize: 11,
                  color: colors.textMuted,
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class _ReportDialog extends StatefulWidget {
  const _ReportDialog();

  @override
  State<_ReportDialog> createState() => _ReportDialogState();
}

class _ReportDialogState extends State<_ReportDialog> {
  final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Report issue'),
      content: TextField(
        controller: _controller,
        maxLines: 3,
        decoration: const InputDecoration(
          hintText: 'What is wrong with this question?',
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(_controller.text.trim()),
          child: const Text('Report'),
        ),
      ],
    );
  }
}
