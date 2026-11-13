import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:round_ai/core/config/app_environment.dart';
import 'package:round_ai/core/di/injection_container.dart';
import 'package:round_ai/core/errors/failures.dart';
import 'package:round_ai/core/errors/result.dart';
import 'package:round_ai/core/router/app_routes.dart';
import 'package:round_ai/core/theme/app_colors.dart';
import 'package:round_ai/core/theme/app_typography.dart';
import 'package:round_ai/features/patient/data/patient_workspace.dart';
import 'package:round_ai/features/rounds/models/round_brief.dart';
import 'package:round_ai/features/rounds/repository/demo_round_repository.dart';
import 'package:round_ai/features/rounds/repository/round_repository.dart';
import 'package:round_ai/features/rounds/widgets/prepare_sheet.dart';
import 'package:round_ai/features/rounds/widgets/reminder_section.dart';
import 'package:round_ai/shared/widgets/app_button.dart';
import 'package:round_ai/shared/widgets/demo_content_banner.dart';

/// Live rounds from `GET /round/brief` (sort_order / room).
class RoundsScreen extends StatefulWidget {
  const RoundsScreen({this.repository, super.key});

  final RoundRepository? repository;

  @override
  State<RoundsScreen> createState() => _RoundsScreenState();
}

class _RoundsScreenState extends State<RoundsScreen> {
  RoundBrief? _brief;
  String? _error;
  bool _loading = true;
  int _index = 0;
  final Set<String> _rounded = <String>{};
  bool _revealed = false;

  RoundRepository get _repo {
    if (widget.repository != null) return widget.repository!;
    try {
      return InjectionContainer.instance.roundRepository;
    } catch (_) {
      return DemoRoundRepository();
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
    });
    final Result<RoundBrief> result = await _repo.loadBrief();
    if (!mounted) return;
    switch (result) {
      case Ok<RoundBrief>(:final RoundBrief value):
        setState(() {
          _brief = value;
          _loading = false;
          if (_index >= value.patients.length) {
            _index = value.patients.isEmpty ? 0 : value.patients.length - 1;
          }
        });
      case Err<RoundBrief>(:final Failure failure):
        setState(() {
          _error = failure.message;
          _loading = false;
        });
    }
  }

  void _go(int index) {
    final RoundBrief? brief = _brief;
    if (brief == null || brief.patients.isEmpty) return;
    setState(() {
      _index = index.clamp(0, brief.patients.length - 1);
      _revealed = false;
    });
  }

  void _markRounded(RoundPatientCard card) {
    setState(() => _rounded.add(card.patientId));
    final RoundBrief? brief = _brief;
    if (brief == null) return;
    final bool last = _index >= brief.patients.length - 1;
    if (!last) _go(_index + 1);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          last
              ? 'Last patient marked rounded.'
              : 'Marked rounded. Next: ${brief.patients[_index].displayName}.',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final AppColors colors = AppColors.of(context);
    if (_loading) {
      return Scaffold(
        backgroundColor: colors.background,
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    if (_error != null) {
      return Scaffold(
        backgroundColor: colors.background,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(_error!, textAlign: TextAlign.center),
                const SizedBox(height: 12),
                AppButton(label: 'Try again', onPressed: _load),
              ],
            ),
          ),
        ),
      );
    }

    final RoundBrief brief = _brief!;
    if (brief.patients.isEmpty) {
      return Scaffold(
        backgroundColor: colors.background,
        body: Center(
          child: Text(
            'No patients on the day brief.',
            style: AppTypography.regular(color: colors.textSecondary),
          ),
        ),
      );
    }

    final RoundPatientCard card = brief.patients[_index];
    final PatientWorkspace? workspace =
        AppEnvironment.useDemo ? workspaceFor(card.patientId) : null;

    return Scaffold(
      backgroundColor: colors.background,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _load,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
            children: <Widget>[
              Text(
                'LIVE ROUNDS · ${_index + 1} OF ${brief.patients.length}',
                style: AppTypography.semiBold(
                  fontSize: 11,
                  color: colors.textMuted,
                ),
              ),
              const SizedBox(height: 6),
              Row(
                children: <Widget>[
                  IconButton(
                    tooltip: 'Previous patient',
                    onPressed: _index == 0 ? null : () => _go(_index - 1),
                    icon: const Icon(Icons.chevron_left_rounded),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          card.displayName,
                          style: AppTypography.bold(
                            fontSize: 26,
                            color: colors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          card.metaLine,
                          style: AppTypography.regular(
                            fontSize: 12,
                            color: colors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Next patient',
                    onPressed: _index == brief.patients.length - 1
                        ? null
                        : () => _go(_index + 1),
                    icon: const Icon(Icons.chevron_right_rounded),
                  ),
                ],
              ),
              if (_rounded.contains(card.patientId)) ...<Widget>[
                const SizedBox(height: 6),
                Row(
                  children: <Widget>[
                    Icon(
                      Icons.check_circle_rounded,
                      size: 16,
                      color: colors.success,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Rounded',
                      style: AppTypography.semiBold(
                        fontSize: 12,
                        color: colors.success,
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () => showPreparePresentationsSheet(
                    context: context,
                    patients: brief.patients,
                    repository: _repo,
                  ),
                  icon: const Icon(Icons.auto_awesome_outlined, size: 18),
                  label: const Text('Prepare presentations'),
                ),
              ),
              const SizedBox(height: 8),
              _PresentationBuilder(
                summary: card.whatChanged.summaryLine,
                onPractice: () =>
                    context.push(AppRoutes.presentationPath(card.patientId)),
              ),
              const SizedBox(height: 20),
              _Section(
                title: 'What changed',
                body: card.whatChanged.summaryLine,
                footnote: card.whatChanged.computedInCode
                    ? 'Computed in code from the chart'
                    : null,
              ),
              if (card.trends.isNotEmpty)
                _BulletSection(
                  title: 'Trends',
                  lines: card.trends
                      .map((Map<String, dynamic> t) => _mapLine(t))
                      .toList(),
                ),
              if (card.conflicts.isNotEmpty)
                _BulletSection(
                  title: 'Conflicts',
                  lines: card.conflicts
                      .map((Map<String, dynamic> t) => _mapLine(t))
                      .toList(),
                ),
              if (card.pendingItems.isNotEmpty)
                _BulletSection(
                  title: 'Pending items',
                  lines: card.pendingItems
                      .map((RoundPendingItem p) => p.display)
                      .toList(),
                ),
              if (card.tasks.isNotEmpty)
                _BulletSection(
                  title: 'Tasks',
                  lines: card.tasks.map(_taskLine).toList(),
                ),
              if (card.missingInformation.isNotEmpty)
                _BulletSection(
                  title: 'Missing information',
                  lines: card.missingInformation,
                ),
              if (card.planToday != null && card.planToday!.isNotEmpty)
                _Section(title: 'Plan', body: card.planToday!),
              if (card.problems.isNotEmpty)
                _BulletSection(
                  title: 'Problems',
                  lines: card.problems
                      .map((RoundProblemItem p) => '${p.label} · ${p.state}')
                      .toList(),
                ),
              const SizedBox(height: 12),
              ReminderSection(
                patientId: card.patientId,
                reminders: card.reminders,
                comparisons: card.yesterdayComparisons,
                repository: _repo,
              ),
              if (workspace != null) ...<Widget>[
                const SizedBox(height: 20),
                const DemoContentBanner(forceShow: true),
                const SizedBox(height: 8),
                _AttendingQuestion(
                  question: workspace.attendingQuestion,
                  framework: workspace.attendingFramework,
                  revealed: _revealed,
                  onReveal: () => setState(() => _revealed = !_revealed),
                ),
              ],
              const SizedBox(height: 20),
              Row(
                children: <Widget>[
                  Expanded(
                    child: AppButton(
                      label: 'Open chart',
                      variant: AppButtonVariant.outline,
                      onPressed: () =>
                          context.push(AppRoutes.patientPath(card.patientId)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: AppButton(
                      label: 'Mark rounded',
                      onPressed: () => _markRounded(card),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String _mapLine(Map<String, dynamic> map) {
    final String label = '${map['label'] ?? map['name'] ?? ''}'.trim();
    final String value = '${map['value'] ?? map['message'] ?? ''}'.trim();
    if (label.isEmpty) return value.isEmpty ? map.toString() : value;
    if (value.isEmpty) return label;
    return '$label · $value';
  }

  static String _taskLine(RoundTaskItem t) {
    final List<String> bits = <String>[t.text];
    if (t.overdue) bits.add('overdue');
    if (t.dueToday) bits.add('due today');
    if (t.due.isNotEmpty) bits.add(t.due);
    return bits.join(' · ');
  }
}

class _PresentationBuilder extends StatelessWidget {
  const _PresentationBuilder({
    required this.summary,
    required this.onPractice,
  });

  final String summary;
  final VoidCallback onPractice;

  @override
  Widget build(BuildContext context) {
    final AppColors colors = AppColors.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: colors.aiCard,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: colors.aiBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(Icons.mic_rounded, size: 16, color: colors.aiAccent),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  'PRESENTATION BUILDER',
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.semiBold(
                    fontSize: 11,
                    color: colors.aiAccent,
                  ),
                ),
              ),
              const Spacer(),
              Text(
                'AI draft',
                style: AppTypography.regular(
                  fontSize: 11,
                  color: colors.textMuted,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'What changed',
            style: AppTypography.semiBold(
              fontSize: 13,
              color: colors.textSecondary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            summary,
            style: AppTypography.regular(
              fontSize: 15,
              height: 1.45,
              color: colors.textPrimary,
            ),
          ),
          const SizedBox(height: 14),
          AppButton(
            label: 'Practice presentation',
            expand: false,
            onPressed: onPractice,
          ),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.body, this.footnote});

  final String title;
  final String body;
  final String? footnote;

  @override
  Widget build(BuildContext context) {
    final AppColors colors = AppColors.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            title,
            style: AppTypography.semiBold(
              fontSize: 17,
              color: colors.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            body,
            style: AppTypography.regular(
              fontSize: 14,
              height: 1.4,
              color: colors.textPrimary,
            ),
          ),
          if (footnote != null) ...<Widget>[
            const SizedBox(height: 4),
            Text(
              footnote!,
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

class _BulletSection extends StatelessWidget {
  const _BulletSection({required this.title, required this.lines});

  final String title;
  final List<String> lines;

  @override
  Widget build(BuildContext context) {
    final AppColors colors = AppColors.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            title,
            style: AppTypography.semiBold(
              fontSize: 17,
              color: colors.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          ...lines.map(
            (String line) => Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(
                '• $line',
                style: AppTypography.regular(
                  fontSize: 14,
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

class _AttendingQuestion extends StatelessWidget {
  const _AttendingQuestion({
    required this.question,
    required this.framework,
    required this.revealed,
    required this.onReveal,
  });

  final String question;
  final List<String> framework;
  final bool revealed;
  final VoidCallback onReveal;

  @override
  Widget build(BuildContext context) {
    final AppColors colors = AppColors.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'ATTENDING QUESTION · DEMO CONTENT',
            style: AppTypography.semiBold(
              fontSize: 11,
              color: colors.textMuted,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            question,
            style: AppTypography.semiBold(
              fontSize: 16,
              height: 1.35,
              color: colors.textPrimary,
            ),
          ),
          if (revealed) ...<Widget>[
            const SizedBox(height: 12),
            ...framework.map(
              (String line) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text(
                  '• $line',
                  style: AppTypography.regular(
                    height: 1.4,
                    color: colors.textPrimary,
                  ),
                ),
              ),
            ),
          ],
          TextButton(
            onPressed: onReveal,
            style: TextButton.styleFrom(padding: EdgeInsets.zero),
            child: Text(
              revealed ? 'Hide framework' : 'Reveal answer framework',
            ),
          ),
        ],
      ),
    );
  }
}
