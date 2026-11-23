import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:round_ai/core/config/app_environment.dart';
import 'package:round_ai/core/config/app_features.dart';
import 'package:round_ai/core/di/injection_container.dart';
import 'package:round_ai/core/router/app_routes.dart';
import 'package:round_ai/core/theme/app_colors.dart';
import 'package:round_ai/core/theme/app_typography.dart';
import 'package:round_ai/features/ai/models/ai_envelope.dart';
import 'package:round_ai/features/ai/repository/ai_repository.dart';
import 'package:round_ai/features/ai/widgets/ask_sheet.dart';
import 'package:round_ai/features/ai/widgets/source_drawer.dart';
import 'package:round_ai/features/ai/widgets/summary_card.dart';
import 'package:round_ai/features/authentication/repository/profile_repository.dart';
import 'package:round_ai/features/census/data/demo_patients.dart';
import 'package:round_ai/features/census/models/patient_summary.dart';
import 'package:round_ai/features/patient/bloc/patient_overview_bloc.dart';
import 'package:round_ai/features/patient/models/patient_detail.dart';
import 'package:round_ai/features/patient/models/problem.dart';
import 'package:round_ai/features/patient/repository/patient_repository.dart';
import 'package:round_ai/features/problems/repository/problems_repository.dart';
import 'package:round_ai/features/problems/widgets/problems_card.dart';
import 'package:round_ai/features/chat/utils/open_patient_thread.dart';
import 'package:round_ai/features/patient/widgets/ask_patient_sheet.dart';
import 'package:round_ai/features/patient/widgets/chart_data_card.dart';
import 'package:round_ai/features/patient/widgets/inline_plan_card.dart';
import 'package:round_ai/features/patient/widgets/patient_chrome.dart';
import 'package:round_ai/shared/widgets/ai_state.dart';
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
                                // metaLine already includes Room — do not prefix Rm again.
                                patient.metaLine,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppTypography.regular(
                                  fontSize: 13,
                                  color: colors.textSecondary,
                                ),
                              ),
                          ],
                        ),
                      ),
                      if (patient != null && detail != null)
                        _MoreMenu(
                          patient: patient,
                          problems: detail.problems,
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
                  Material(
                    color: colors.surface,
                    elevation: 0,
                    child: Container(
                      padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
                      decoration: BoxDecoration(
                        border: Border(top: BorderSide(color: colors.border)),
                      ),
                      child: Row(
                        children: <Widget>[
                          Expanded(
                            child: OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                foregroundColor: const Color(0xFF0A8F9C),
                                side: const BorderSide(
                                  color: Color(0xFF0A8F9C),
                                  width: 1.4,
                                ),
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(999),
                                ),
                              ),
                              onPressed: () =>
                                  showAddUpdateSheet(context, patient.id),
                              icon: const Icon(Icons.add_rounded, size: 18),
                              label: const Text('Add update'),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: FilledButton(
                              style: FilledButton.styleFrom(
                                backgroundColor: const Color(0xFF0A8F9C),
                                foregroundColor: colors.white,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(999),
                                ),
                              ),
                              onPressed: () => context.push(
                                AppFeatures.notes
                                    ? AppRoutes.notePath(patient.id)
                                    : AppRoutes.patientPlanPath(patient.id),
                              ),
                              child: Text(
                                AppFeatures.notes ? 'Create note' : 'Open plan',
                              ),
                            ),
                          ),
                        ],
                      ),
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
    // Priority: one-liner → overnight changes → vitals → problems → A&P.
    // Create note / Add update stay pinned in the footer (no scroll required).
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
        InlinePlanCard(
          patientId: patient.id,
          lines: detail.planToday,
          structured: detail.planStructured,
          problems: detail.problems,
        ),
        if (patient.unreviewedFacts > 0) ...<Widget>[
          const SizedBox(height: 12),
          ChartDataCard(
            patientId: patient.id,
            unreviewedFacts: patient.unreviewedFacts,
            onChanged: () => context.read<PatientOverviewBloc>().add(
              const PatientOverviewRequested(),
            ),
          ),
        ],
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
        if (detail.missingInformation.isNotEmpty) ...<Widget>[
          const SizedBox(height: 12),
          _MissingCard(items: detail.missingInformation),
        ],
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
    final (Color bg, Color fg, String label, IconData icon) =
        switch (patient.summaryState) {
          SummaryState.notGenerated => (
            colors.criticalBg,
            colors.critical,
            'Not started',
            Icons.error_outline_rounded,
          ),
          SummaryState.draftReady => (
            const Color(0xFFE8F3FF),
            colors.primary,
            'Draft',
            Icons.timelapse_rounded,
          ),
          SummaryState.reviewed => (
            colors.successSoft,
            colors.success,
            'Reviewed',
            Icons.check_circle_outline,
          ),
          SummaryState.outdated => (
            colors.chipIdle,
            colors.textSecondary,
            'Outdated',
            Icons.schedule_rounded,
          ),
        };
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.border),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: colors.navy.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: <Widget>[
          CircleAvatar(
            radius: 26,
            backgroundColor: const Color(0xFFD6F3F6),
            child: Text(
              patient.initials,
              style: AppTypography.bold(
                fontSize: 15,
                color: const Color(0xFF0A8F9C),
              ),
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
                    fontSize: 18,
                    color: colors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  patient.metaLine,
                  style: AppTypography.regular(
                    color: colors.textSecondary,
                    fontSize: 13,
                  ),
                ),
                if (patient.oneLiner.trim().isNotEmpty) ...<Widget>[
                  const SizedBox(height: 8),
                  Text(
                    patient.oneLiner.trim(),
                    style: AppTypography.medium(
                      fontSize: 14,
                      height: 1.35,
                      color: colors.textPrimary,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Icon(icon, size: 13, color: fg),
                const SizedBox(width: 4),
                Text(
                  label,
                  style: AppTypography.semiBold(color: fg, fontSize: 11),
                ),
              ],
            ),
          ),
        ],
      ),
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
            padding: const EdgeInsets.only(bottom: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  '• ${_line(item)}',
                  style: AppTypography.regular(height: 1.35),
                ),
                if (item.factIds.isNotEmpty)
                  TextButton(
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.only(left: 12, top: 2),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    onPressed: () {
                      try {
                        showSourceDrawer(
                          context,
                          claim: Claim(
                            text: _line(item),
                            label: ClaimLabel.fromChart,
                            factIds: item.factIds,
                          ),
                          repository:
                              InjectionContainer.instance.aiRepository,
                        );
                      } catch (_) {}
                    },
                    child: Text(
                      item.factIds.length == 1
                          ? 'Review source'
                          : 'Review ${item.factIds.length} sources',
                      style: AppTypography.semiBold(
                        fontSize: 12,
                        color: const Color(0xFF0A8F9C),
                      ),
                    ),
                  ),
              ],
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

/// Secondary patient tools — Evidence, Teach, Presentation, Chat, Ask, Tasks.
class _MoreMenu extends StatelessWidget {
  const _MoreMenu({required this.patient, required this.problems});

  final PatientSummary patient;
  final List<Problem> problems;

  String get patientId => patient.id;

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

  @override
  Widget build(BuildContext context) {
    final List<PopupMenuEntry<String>> items = <PopupMenuEntry<String>>[
      const PopupMenuItem<String>(value: 'tasks', child: Text('Tasks')),
      if (AppFeatures.presentation)
        const PopupMenuItem<String>(
          value: 'presentation',
          child: Text('Prepare presentation'),
        ),
      if (AppFeatures.evidence)
        const PopupMenuItem<String>(
          value: 'evidence',
          child: Text('Explore evidence'),
        ),
      if (AppFeatures.teach)
        const PopupMenuItem<String>(value: 'teach', child: Text('Teach me')),
      if (AppFeatures.chat)
        const PopupMenuItem<String>(
          value: 'chat',
          child: Text('Open team thread'),
        ),
      if (AppFeatures.ask)
        const PopupMenuItem<String>(
          value: 'ask',
          child: Text('Ask about this patient'),
        ),
      if (AppFeatures.signOut)
        const PopupMenuItem<String>(
          value: 'signout',
          child: Text('Sign-out checklist'),
        ),
    ];
    if (items.isEmpty) return const SizedBox.shrink();
    return PopupMenuButton<String>(
      tooltip: 'More',
      icon: const Icon(Icons.more_horiz_rounded),
      onSelected: (String value) {
        switch (value) {
          case 'tasks':
            context.push(AppRoutes.patientTasksPath(patientId));
          case 'presentation':
            context.push(AppRoutes.presentationPath(patientId));
          case 'evidence':
            context.push(AppRoutes.evidencePath(patientId));
          case 'teach':
            context.push(AppRoutes.teachPath(patientId));
          case 'chat':
            openPatientTeamThread(
              context,
              patientId: patientId,
              patientLabel: _teamThreadLabel,
            );
          case 'ask':
            _ask(context);
          case 'signout':
            context.push(AppRoutes.signOutPath(patientId));
        }
      },
      itemBuilder: (BuildContext context) => items,
    );
  }
}
