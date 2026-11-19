import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:round_ai/core/config/app_environment.dart';
import 'package:round_ai/core/config/app_features.dart';
import 'package:round_ai/core/di/injection_container.dart';
import 'package:round_ai/core/errors/result.dart';
import 'package:round_ai/core/router/app_routes.dart';
import 'package:round_ai/core/sync/census_sync_mark.dart';
import 'package:round_ai/core/theme/app_colors.dart';
import 'package:round_ai/core/theme/app_typography.dart';
import 'package:round_ai/features/ai/repository/ai_repository.dart';
import 'package:round_ai/features/ai/widgets/ask_sheet.dart';
import 'package:round_ai/features/ai/widgets/summary_card.dart';
import 'package:round_ai/features/authentication/repository/profile_repository.dart';
import 'package:round_ai/features/census/data/demo_patients.dart';
import 'package:round_ai/features/census/models/patient_summary.dart';
import 'package:round_ai/features/patient/bloc/patient_overview_bloc.dart';
import 'package:round_ai/features/patient/models/patient_detail.dart';
import 'package:round_ai/features/patient/models/plan_structured.dart';
import 'package:round_ai/features/patient/models/problem.dart';
import 'package:round_ai/features/patient/repository/patient_repository.dart';
import 'package:round_ai/features/problems/repository/problems_repository.dart';
import 'package:round_ai/features/problems/widgets/problems_card.dart';
import 'package:round_ai/features/chat/utils/open_patient_thread.dart';
import 'package:round_ai/features/patient/widgets/ask_patient_sheet.dart';
import 'package:round_ai/features/patient/widgets/chart_data_card.dart';
import 'package:round_ai/features/patient/widgets/patient_chrome.dart';
import 'package:round_ai/shared/widgets/ai_state.dart';
import 'package:round_ai/shared/widgets/app_button.dart';
import 'package:round_ai/shared/widgets/retry_view.dart';
import 'package:round_ai/shared/widgets/skeleton.dart';

class PatientOverviewScreen extends StatelessWidget {
  const PatientOverviewScreen({
    required this.patientId,
    this.repository,
    this.aiRepository,
    this.problemsRepository,
    super.key,
  });

  final String patientId;
  final PatientRepository? repository;
  final AiRepository? aiRepository;
  final ProblemsRepository? problemsRepository;

  @override
  Widget build(BuildContext context) {
    final PatientRepository source =
        repository ?? InjectionContainer.instance.patientRepository;
    return RepositoryProvider<AiRepository>.value(
      value: aiRepository ?? InjectionContainer.instance.aiRepository,
      child: RepositoryProvider<ProblemsRepository>.value(
        value:
            problemsRepository ??
            InjectionContainer.instance.problemsRepository,
        child: BlocProvider<PatientOverviewBloc>(
          create: (_) =>
              PatientOverviewBloc(source, patientId)
                ..add(const PatientOverviewRequested()),
          child: PatientOverviewView(patientId: patientId),
        ),
      ),
    );
  }
}

class PatientOverviewView extends StatefulWidget {
  const PatientOverviewView({required this.patientId, super.key});

  final String patientId;

  @override
  State<PatientOverviewView> createState() => _PatientOverviewViewState();
}

class _PatientOverviewViewState extends State<PatientOverviewView> {
  ValueNotifier<int>? _sync;
  int _seen = 0;

  @override
  void initState() {
    super.initState();
    try {
      _sync = InjectionContainer.instance.censusSync.revision;
      _seen = _sync!.value;
      _sync!.addListener(_onCensusSync);
    } catch (_) {}
  }

  void _onCensusSync() {
    final ValueNotifier<int>? sync = _sync;
    if (sync == null || !mounted) return;
    if (sync.value == _seen) return;
    _seen = sync.value;
    context.read<PatientOverviewBloc>().add(const PatientOverviewRequested());
  }

  @override
  void dispose() {
    _sync?.removeListener(_onCensusSync);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppColors colors = AppColors.of(context);
    return BlocConsumer<PatientOverviewBloc, PatientOverviewState>(
      listenWhen: (PatientOverviewState a, PatientOverviewState b) =>
          b.accessDenied && !a.accessDenied,
      listener: (BuildContext context, PatientOverviewState state) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('You do not have access to this patient.'),
          ),
        );
        if (context.canPop()) context.pop();
      },
      builder: (BuildContext context, PatientOverviewState state) {
        final PatientDetail? detail = state.detail;
        final PatientSummary? patient = detail?.patient;
        return Scaffold(
          backgroundColor: colors.background,
          body: SafeArea(
            child: Column(
              children: <Widget>[
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 4, 8, 0),
                  child: Row(
                    children: <Widget>[
                      IconButton(
                        tooltip: 'Back',
                        onPressed: () => context.pop(),
                        icon: const Icon(Icons.arrow_back_rounded),
                      ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              patient?.displayName ?? 'Patient',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTypography.semiBold(
                                fontSize: 16,
                                color: colors.textPrimary,
                              ),
                            ),
                            if (patient != null)
                              Text(
                                patient.room.trim().isEmpty
                                    ? patient.metaLine
                                    : 'Rm ${patient.room} · ${patient.metaLine}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppTypography.regular(
                                  fontSize: 12,
                                  color: colors.textSecondary,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: switch (state.status) {
                    PatientOverviewStatus.loading when detail == null =>
                      const SkeletonList(count: 4),
                    PatientOverviewStatus.failure when detail == null =>
                      RetryView(
                        title: 'This patient could not be loaded.',
                        message: state.error ?? '',
                        onRetry: () => context.read<PatientOverviewBloc>().add(
                          const PatientOverviewRequested(),
                        ),
                      ),
                    _ => RefreshIndicator(
                      onRefresh: () async {
                        final PatientOverviewBloc bloc = context
                            .read<PatientOverviewBloc>();
                        bloc.add(const PatientOverviewRequested());
                        await bloc.stream.firstWhere(
                          (PatientOverviewState s) =>
                              s.status != PatientOverviewStatus.loading,
                        );
                      },
                      child: _Content(state: state, detail: detail!),
                    ),
                  },
                ),
                if (patient != null)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                    child: Row(
                      children: <Widget>[
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () =>
                                showAddUpdateSheet(context, patient.id),
                            icon: const Icon(Icons.add_rounded, size: 18),
                            label: const Text('Add update'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: AppButton(
                            label: AppFeatures.notes
                                ? 'Create note'
                                : 'Open plan',
                            onPressed: () => context.push(
                              AppFeatures.notes
                                  ? AppRoutes.notePath(patient.id)
                                  : AppRoutes.patientPlanPath(patient.id),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _Content extends StatelessWidget {
  const _Content({required this.state, required this.detail});

  final PatientOverviewState state;
  final PatientDetail detail;

  @override
  Widget build(BuildContext context) {
    final PatientSummary patient = detail.patient;
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: <Widget>[
        _Header(patient: patient),
        const SizedBox(height: 12),
        _ChangesCard(state: state),
        if (detail.trends.isNotEmpty) ...<Widget>[
          const SizedBox(height: 12),
          _InsightCard(title: 'Key vitals & labs', items: detail.trends),
        ],
        const SizedBox(height: 12),
        ChartDataCard(
          patientId: patient.id,
          unreviewedFacts: patient.unreviewedFacts,
          onChanged: () => context.read<PatientOverviewBloc>().add(
            const PatientOverviewRequested(),
          ),
        ),
        if (detail.demoSummary == null) ...<Widget>[
          const SizedBox(height: 12),
          ProblemsCard(
            patientId: patient.id,
            initial: detail.problems,
            aiOff: InjectionContainer.instance.profileRepository.aiOff,
            onChanged: () => context.read<PatientOverviewBloc>().add(
              const PatientOverviewRequested(),
            ),
          ),
        ] else if (detail.problems.isNotEmpty) ...<Widget>[
          const SizedBox(height: 12),
          _ProblemsCard(problems: detail.problems),
        ],
        const SizedBox(height: 12),
        _PlanCard(
          patientId: patient.id,
          lines: detail.planToday,
          structured: detail.planStructured,
          problems: detail.problems,
        ),
        const SizedBox(height: 12),
        if (AppFeatures.summary && detail.demoSummary == null)
          SummaryCard(
            patientId: patient.id,
            revision: detail.revision,
            aiOff: InjectionContainer.instance.profileRepository.aiOff,
            onChanged: () => context.read<PatientOverviewBloc>().add(
              const PatientOverviewRequested(),
            ),
          )
        else
          _AiSummaryCard(detail: detail),
        if (detail.conflicts.isNotEmpty) ...<Widget>[
          const SizedBox(height: 12),
          _InsightCard(
            title: 'Conflicts in the chart',
            items: detail.conflicts,
          ),
        ],
        const SizedBox(height: 12),
        _MissingCard(items: detail.missingInformation),
        const SizedBox(height: 16),
        Text(
          'More tools',
          style: AppTypography.semiBold(
            fontSize: 13,
            color: AppColors.of(context).textMuted,
          ),
        ),
        const SizedBox(height: 8),
        _Actions(patient: patient, problems: detail.problems),
      ],
    );
  }

}

class _Header extends StatelessWidget {
  const _Header({required this.patient});

  final PatientSummary patient;

  @override
  Widget build(BuildContext context) {
    final AppColors colors = AppColors.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        CircleAvatar(
          radius: 28,
          backgroundColor: colors.primary.withValues(alpha: 0.12),
          child: Text(
            patient.initials,
            style: AppTypography.bold(fontSize: 16, color: colors.primary),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                patient.displayName,
                style: AppTypography.bold(
                  fontSize: 22,
                  color: colors.textPrimary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                patient.metaLine,
                style: AppTypography.regular(
                  color: colors.textSecondary,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// The AI summary card. In demo mode it simulates a generation. On the
/// backend it only shows the state until summaries are connected.
class _AiSummaryCard extends StatefulWidget {
  const _AiSummaryCard({required this.detail});

  final PatientDetail detail;

  @override
  State<_AiSummaryCard> createState() => _AiSummaryCardState();
}

class _AiSummaryCardState extends State<_AiSummaryCard> {
  bool _refreshing = false;
  late AiState _aiState = AiState.fromSummary(
    widget.detail.patient.summaryState,
  );
  String? _generatedLabel;

  bool get _demo => widget.detail.demoSummary != null;

  Future<void> _refresh() async {
    setState(() {
      _refreshing = true;
      _aiState = AiState.loading;
    });
    await Future<void>.delayed(const Duration(milliseconds: 700));
    if (!mounted) return;
    setState(() {
      _refreshing = false;
      _aiState = AiState.draftReady;
      _generatedLabel = 'Draft ready · just now · requires review';
    });
  }

  void _markReviewed() {
    setState(() {
      _aiState = AiState.reviewed;
      _generatedLabel = 'Reviewed · this version only';
    });
  }

  String _body() {
    if (_demo) return widget.detail.demoSummary!;
    final PatientSummary p = widget.detail.patient;
    return switch (p.summaryState) {
      SummaryState.notGenerated =>
        'No summary yet. A summary is built only from chart facts you have confirmed.',
      _ => 'A summary was generated for this patient.',
    };
  }

  @override
  Widget build(BuildContext context) {
    final AppColors colors = AppColors.of(context);
    final bool showsAiText = _demo || _aiState != AiState.notGenerated;
    final bool unreviewed = _aiState != AiState.reviewed;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.aiCard,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: colors.aiBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(Icons.auto_awesome, size: 16, color: colors.aiAccent),
              const SizedBox(width: 6),
              Text(
                'AI Patient Summary',
                style: AppTypography.semiBold(
                  color: colors.aiAccent,
                  fontSize: 14,
                ),
              ),
            ],
          ),
          if (showsAiText && unreviewed) ...<Widget>[
            const SizedBox(height: 8),
            Text(
              'AI draft · review required',
              style: AppTypography.medium(color: colors.aiAccent, fontSize: 11),
            ),
          ],
          const SizedBox(height: 6),
          Text(
            _body(),
            style: AppTypography.regular(
              height: 1.45,
              color: colors.textPrimary,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: <Widget>[
              AiStateChip(state: _aiState),
              if (_generatedLabel != null) ...<Widget>[
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _generatedLabel!,
                    style: AppTypography.regular(
                      color: colors.textMuted,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ],
          ),
          if (_demo) ...<Widget>[
            const SizedBox(height: 8),
            Wrap(
              children: <Widget>[
                TextButton.icon(
                  onPressed: _refreshing ? null : _refresh,
                  icon: _refreshing
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.refresh_rounded, size: 18),
                  label: Text(
                    _refreshing ? 'Refreshing summary' : 'Refresh Summary',
                  ),
                ),
                if (_aiState.canReview)
                  TextButton.icon(
                    onPressed: _markReviewed,
                    icon: const Icon(Icons.verified_outlined, size: 18),
                    label: const Text('Mark reviewed'),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _PlanCard extends StatefulWidget {
  const _PlanCard({
    required this.patientId,
    required this.lines,
    this.structured,
    this.problems = const <Problem>[],
  });

  final String patientId;
  final List<String> lines;
  final PlanStructured? structured;
  final List<Problem> problems;

  @override
  State<_PlanCard> createState() => _PlanCardState();
}

class _PlanCardState extends State<_PlanCard> {
  late bool _includeIcd;
  bool _savingIcd = false;

  @override
  void initState() {
    super.initState();
    _includeIcd = widget.structured?.includeIcd ?? false;
  }

  @override
  void didUpdateWidget(covariant _PlanCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.structured?.includeIcd != widget.structured?.includeIcd &&
        !_savingIcd) {
      _includeIcd = widget.structured?.includeIcd ?? false;
    }
  }

  String? _codeFor(String label) {
    for (final Problem p in widget.problems) {
      final String? code = p.codeSuggestion?.code;
      if (code == null || code.isEmpty) continue;
      if (p.label.toLowerCase() == label.toLowerCase() ||
          label.toLowerCase().contains(p.label.toLowerCase())) {
        return code.trim();
      }
    }
    return null;
  }

  List<String> get _previewLines {
    final PlanStructured? structured = widget.structured;
    if (structured != null && structured.items.isNotEmpty) {
      return structured.toDisplayLines(withIcd: _includeIcd);
    }
    if (!_includeIcd) return widget.lines;
    return <String>[
      for (final String line in widget.lines)
        () {
          final String? code = _codeFor(line);
          if (code == null || line.contains(code)) return line;
          return '$line ($code)';
        }(),
    ];
  }

  Future<void> _onIcdChanged(bool value) async {
    setState(() {
      _includeIcd = value;
      _savingIcd = true;
    });
    final PlanStructured base = widget.structured ??
        PlanStructured(
          includeIcd: value,
          items: <PlanItem>[
            for (final String line in widget.lines)
              if (line.trim().isNotEmpty)
                PlanItem(label: line.trim()),
          ],
        );
    // Prefer flipping include_icd only; keep codes on items so toggling back on
    // does not invent new codes and still uses clinician-accepted ones.
    final PlanStructured next = base.copyWith(
      includeIcd: value,
      items: <PlanItem>[
        for (final PlanItem item in base.items)
          item.copyWith(
            code: item.code?.isNotEmpty == true
                ? item.code
                : _codeFor(item.label),
          ),
      ],
    );
    try {
      final Result<void> result = await InjectionContainer
          .instance
          .patientRepository
          .saveStructuredPlan(widget.patientId, next);
      if (!mounted) return;
      if (result case Err<void>()) {
        setState(() {
          _includeIcd = !value;
          _savingIcd = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not save ICD preference.')),
        );
        return;
      }
      markCensusDirty();
      context.read<PatientOverviewBloc>().add(const PatientOverviewRequested());
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _includeIcd = !value;
        _savingIcd = false;
      });
    } finally {
      if (mounted) setState(() => _savingIcd = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppColors colors = AppColors.of(context);
    final bool hasCodes = widget.problems.any(
      (Problem p) =>
          p.codeSuggestion?.code != null &&
          p.codeSuggestion!.code.trim().isNotEmpty,
    );
    final List<String> lines = _previewLines;
    return _CardShell(
      title: 'Assessment and Plan',
      trailing: TextButton(
        onPressed: () => context.push(AppRoutes.patientPlanPath(widget.patientId)),
        child: Text(
          'Edit',
          style: AppTypography.semiBold(fontSize: 12, color: colors.primary),
        ),
      ),
      children: <Widget>[
        SwitchListTile.adaptive(
          contentPadding: EdgeInsets.zero,
          dense: true,
          title: Text(
            'Include ICD-10 codes',
            style: AppTypography.regular(fontSize: 13, color: colors.textPrimary),
          ),
          subtitle: Text(
            hasCodes
                ? 'Codes appear beside matching diagnoses. Preference is saved with the plan.'
                : 'No accepted codes yet — confirm problems, then Suggest codes under Problems.',
            style: AppTypography.regular(fontSize: 11, color: colors.textMuted),
          ),
          value: _includeIcd,
          onChanged: _savingIcd ? null : _onIcdChanged,
        ),
        if (lines.isEmpty)
          Text(
            "Edit to enter today's Assessment and Plan by problem. "
            'A plan from dictation can prefill this after you review the note — no need to type it twice.',
            style: AppTypography.regular(
              fontSize: 13,
              color: colors.textSecondary,
            ),
          )
        else
          for (final String line in lines)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text(
                '• $line',
                style: AppTypography.regular(height: 1.35),
              ),
            ),
      ],
    );
  }
}

class _ProblemsCard extends StatelessWidget {
  const _ProblemsCard({required this.problems});

  final List<Problem> problems;

  @override
  Widget build(BuildContext context) {
    final AppColors colors = AppColors.of(context);
    return _CardShell(
      title: 'Problems',
      children: <Widget>[
        for (final Problem problem in problems)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    problem.label,
                    style: AppTypography.regular(height: 1.35),
                  ),
                ),
                const SizedBox(width: 8),
                // A suggestion is never shown as confirmed.
                Text(
                  problem.state.label,
                  style: AppTypography.medium(
                    fontSize: 11,
                    color: problem.state == ProblemState.suggested
                        ? colors.aiAccent
                        : colors.textMuted,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _ChangesCard extends StatelessWidget {
  const _ChangesCard({required this.state});

  final PatientOverviewState state;

  @override
  Widget build(BuildContext context) {
    final AppColors colors = AppColors.of(context);
    final PatientChanges? changes = state.changes;
    final List<Widget> body;
    if (state.changesFailed || changes == null) {
      body = <Widget>[
        Text(
          'Changes could not be loaded. Pull down to try again.',
          style: AppTypography.regular(color: colors.textSecondary),
        ),
      ];
    } else if (!changes.hasBaseline) {
      body = <Widget>[
        Text(
          'Review a summary to set the baseline.',
          style: AppTypography.regular(color: colors.textSecondary),
        ),
      ];
    } else if (changes.items.isEmpty) {
      body = <Widget>[
        Text(
          'No changes since the baseline.',
          style: AppTypography.regular(color: colors.textSecondary),
        ),
      ];
    } else {
      body = <Widget>[
        for (final InsightItem item in changes.items)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Text(
              '• ${item.label.isEmpty ? '' : '${item.label}: '}${item.text}',
              style: AppTypography.regular(height: 1.35),
            ),
          ),
      ];
    }
    return _CardShell(
      title: 'What changed',
      trailing: Text(
        'From chart',
        style: AppTypography.regular(fontSize: 11, color: colors.textMuted),
      ),
      children: body,
    );
  }
}

class _MissingCard extends StatelessWidget {
  const _MissingCard({required this.items});

  final List<String> items;

  @override
  Widget build(BuildContext context) {
    final AppColors colors = AppColors.of(context);
    return _CardShell(
      title: 'Missing information',
      children: items.isEmpty
          ? <Widget>[
              Text(
                'Nothing is flagged as missing.',
                style: AppTypography.regular(color: colors.textSecondary),
              ),
            ]
          : <Widget>[for (final String item in items) _NotEntered(label: item)],
    );
  }
}

class _InsightCard extends StatelessWidget {
  const _InsightCard({required this.title, required this.items});

  final String title;
  final List<InsightItem> items;

  static String _line(InsightItem item) {
    final String text = item.text.trim();
    final String label = item.label.trim();
    if (text.isEmpty) return label;
    if (label.isEmpty) return text;
    // Avoid "Creatinine: Creatinine increased from…"
    if (text.toLowerCase().startsWith(label.toLowerCase())) return text;
    return '$label: $text';
  }

  @override
  Widget build(BuildContext context) {
    final AppColors colors = AppColors.of(context);
    return _CardShell(
      title: title,
      trailing: Text(
        'From chart',
        style: AppTypography.regular(fontSize: 11, color: colors.textMuted),
      ),
      children: <Widget>[
        for (final InsightItem item in items)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Text(
              '• ${_line(item)}',
              style: AppTypography.regular(height: 1.35),
            ),
          ),
      ],
    );
  }
}

/// A value the chart does not have. It is shown, never filled in.
class _NotEntered extends StatelessWidget {
  const _NotEntered({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final AppColors colors = AppColors.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: <Widget>[
          Icon(
            Icons.report_gmailerrorred_rounded,
            size: 16,
            color: colors.warning,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(label, style: AppTypography.regular(height: 1.35)),
          ),
          const SizedBox(width: 8),
          Text(
            'Not entered',
            style: AppTypography.semiBold(fontSize: 11, color: colors.warning),
          ),
        ],
      ),
    );
  }
}

class _CardShell extends StatelessWidget {
  const _CardShell({
    required this.title,
    required this.children,
    this.trailing,
  });

  final String title;
  final List<Widget> children;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final AppColors colors = AppColors.of(context);
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
          Row(
            children: <Widget>[
              Expanded(
                child: Text(title, style: AppTypography.semiBold(fontSize: 15)),
              ),
              ?trailing,
            ],
          ),
          const SizedBox(height: 8),
          ...children,
        ],
      ),
    );
  }
}

class _Actions extends StatelessWidget {
  const _Actions({required this.patient, required this.problems});

  final PatientSummary patient;
  final List<Problem> problems;

  String get patientId => patient.id;

  /// Topics the user can pick for a question: only problems a clinician
  /// confirmed or marked as differential. A suggestion is not offered.
  List<String> get _topics => <String>[
    for (final Problem p in problems)
      if (p.state == ProblemState.confirmed ||
          p.state == ProblemState.differential)
        p.label,
  ];

  void _ask(BuildContext context) {
    if (AppEnvironment.useDemo) {
      final CensusPatient? demo = patientById(patientId);
      if (demo != null) showAskPatientSheet(context, demo);
      return;
    }
    showAskSheet(
      context,
      repository: context.read<AiRepository>(),
      patient: patient,
      aiOff: InjectionContainer.instance.profileRepository.aiOff,
      topics: _topics,
    );
  }

  String get _teamThreadLabel {
    final String room = patient.room.trim();
    final String name = patient.displayName.trim();
    if (room.isNotEmpty && name.isNotEmpty) return '$name · Room $room';
    if (room.isNotEmpty) return 'Room $room';
    if (name.isNotEmpty) return name;
    return 'Patient thread';
  }

  Future<void> _openTeamThread(BuildContext context) {
    return openPatientTeamThread(
      context,
      patientId: patientId,
      patientLabel: _teamThreadLabel,
    );
  }

  @override
  Widget build(BuildContext context) {
    final List<Widget> tiles = <Widget>[
      if (AppFeatures.presentation)
        _ActionTile(
          icon: Icons.campaign_outlined,
          label: 'Prepare\nPresentation',
          onTap: () => context.push(AppRoutes.presentationPath(patientId)),
        ),
      if (AppFeatures.evidence)
        _ActionTile(
          icon: Icons.menu_book_outlined,
          label: 'Explore\nEvidence',
          onTap: () => context.push(AppRoutes.evidencePath(patientId)),
        ),
      if (AppFeatures.teach)
        _ActionTile(
          icon: Icons.school_outlined,
          label: 'Teach Me',
          onTap: () => context.push(AppRoutes.teachPath(patientId)),
        ),
      if (AppFeatures.chat)
        _ActionTile(
          icon: Icons.forum_outlined,
          label: 'Open team\nthread',
          onTap: () => _openTeamThread(context),
        ),
    ];
    return Column(
      children: <Widget>[
        if (tiles.isNotEmpty)
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 1.7,
            children: tiles,
          ),
        if (AppFeatures.ask) ...<Widget>[
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => _ask(context),
              icon: const Icon(Icons.chat_bubble_outline_rounded, size: 18),
              label: const Text('Ask about this patient'),
            ),
          ),
        ],
      ],
    );
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final AppColors colors = AppColors.of(context);
    return Material(
      color: colors.surface,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: colors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Icon(icon, color: colors.primary),
              const SizedBox(height: 8),
              Text(
                label,
                style: AppTypography.semiBold(fontSize: 13, height: 1.2),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
