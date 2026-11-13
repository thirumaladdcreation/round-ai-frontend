import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:round_ai/core/config/app_environment.dart';
import 'package:round_ai/core/di/injection_container.dart';
import 'package:round_ai/core/router/app_routes.dart';
import 'package:round_ai/core/theme/app_colors.dart';
import 'package:round_ai/core/theme/app_typography.dart';
import 'package:round_ai/features/authentication/repository/profile_repository.dart';
import 'package:round_ai/features/census/bloc/census_bloc.dart';
import 'package:round_ai/features/census/bloc/census_event.dart';
import 'package:round_ai/features/census/bloc/census_state.dart';
import 'package:round_ai/features/census/models/patient_summary.dart';
import 'package:round_ai/features/census/repository/census_repository.dart';
import 'package:round_ai/features/census/screens/census_export_sheet.dart';
import 'package:round_ai/features/census/widgets/add_patient_sheet.dart';
import 'package:round_ai/shared/widgets/retry_view.dart';
import 'package:round_ai/shared/widgets/skeleton.dart';

/// Filters use chart data only. Priority and discharge are not filters
/// because the backend has no such data, and AI must not rank patients.
enum _CensusFilter { all, unreviewedFacts, outdated }

class CensusScreen extends StatelessWidget {
  const CensusScreen({this.repository, super.key});

  final CensusRepository? repository;

  @override
  Widget build(BuildContext context) {
    final CensusRepository source =
        repository ?? InjectionContainer.instance.censusRepository;
    return BlocProvider<CensusBloc>(
      create: (_) => CensusBloc(source)..add(const CensusRequested()),
      child: const CensusView(),
    );
  }
}

class CensusView extends StatefulWidget {
  const CensusView({super.key});

  @override
  State<CensusView> createState() => _CensusViewState();
}

class _CensusViewState extends State<CensusView> {
  _CensusFilter _filter = _CensusFilter.all;

  List<PatientSummary> _visible(List<PatientSummary> all) {
    return all.where((PatientSummary p) {
      return switch (_filter) {
        _CensusFilter.all => true,
        _CensusFilter.unreviewedFacts => p.unreviewedFacts > 0,
        _CensusFilter.outdated => p.summaryState == SummaryState.outdated,
      };
    }).toList();
  }

  Future<void> _refresh(BuildContext context) async {
    final CensusBloc bloc = context.read<CensusBloc>();
    bloc.add(const CensusRequested());
    // Wait for this load to finish, so the spinner stops at the right time.
    await bloc.stream.firstWhere(
      (CensusState s) => s.status != CensusStatus.loading,
    );
  }

  @override
  Widget build(BuildContext context) {
    final AppColors colors = AppColors.of(context);
    final InjectionContainer di = InjectionContainer.instance;
    final String teamLabel =
        (di.profileRepository.teamById(di.appStorage.selectedTeamId)?.name ??
                'Team')
            .toUpperCase();

    return Scaffold(
      backgroundColor: colors.background,
      body: SafeArea(
        child: BlocBuilder<CensusBloc, CensusState>(
          builder: (BuildContext context, CensusState state) {
            if (state.status == CensusStatus.loading &&
                state.patients.isEmpty) {
              return const SkeletonList(count: 5);
            }
            if (state.status == CensusStatus.failure &&
                state.patients.isEmpty) {
              return RetryView(
                title: 'The census could not be loaded.',
                message: state.error ?? '',
                onRetry: () =>
                    context.read<CensusBloc>().add(const CensusRequested()),
              );
            }
            final List<PatientSummary> visible = _visible(state.patients);
            return RefreshIndicator(
              onRefresh: () => _refresh(context),
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
                children: <Widget>[
                  Text(
                    '$teamLabel · ${state.patients.length} PATIENTS',
                    style: AppTypography.semiBold(
                      fontSize: 11,
                      color: colors.textMuted,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: Text(
                          'My Census',
                          style: AppTypography.bold(
                            fontSize: 28,
                            color: colors.textPrimary,
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: 'Export census',
                        onPressed: () => showCensusExportSheet(context),
                        icon: const Icon(Icons.ios_share_rounded),
                      ),
                      IconButton.filled(
                        tooltip: 'Add patient',
                        onPressed: () => showAddPatientSheet(context),
                        icon: const Icon(Icons.person_add_alt_1_rounded),
                      ),
                    ],
                  ),
                  if (!AppEnvironment.useDemo) ...<Widget>[
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: <Widget>[
                        OutlinedButton.icon(
                          onPressed: () async {
                            final Object? next = await context.push<Object>(
                              AppRoutes.censusIntakeDictate,
                            );
                            if (!context.mounted) return;
                            await _afterIntake(context, next);
                          },
                          icon: const Icon(Icons.mic_none_outlined, size: 18),
                          label: const Text('Dictate census'),
                        ),
                        OutlinedButton.icon(
                          onPressed: () async {
                            final Object? next = await context.push<Object>(
                              AppRoutes.censusIntakePhoto,
                            );
                            if (!context.mounted) return;
                            await _afterIntake(context, next);
                          },
                          icon: const Icon(
                            Icons.document_scanner_outlined,
                            size: 18,
                          ),
                          label: const Text('Scan census'),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: <Widget>[
                      _FilterChip(
                        label: 'All',
                        selected: _filter == _CensusFilter.all,
                        onTap: () =>
                            setState(() => _filter = _CensusFilter.all),
                      ),
                      _FilterChip(
                        label: 'Unreviewed facts',
                        selected: _filter == _CensusFilter.unreviewedFacts,
                        onTap: () => setState(
                          () => _filter = _CensusFilter.unreviewedFacts,
                        ),
                      ),
                      _FilterChip(
                        label: 'Outdated summary',
                        selected: _filter == _CensusFilter.outdated,
                        onTap: () =>
                            setState(() => _filter = _CensusFilter.outdated),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _filter == _CensusFilter.all
                        ? 'Drag to reorder · sort order, then room'
                        : 'Filtered view · reorder on All',
                    style: AppTypography.regular(
                      fontSize: 12,
                      color: colors.textMuted,
                    ),
                  ),
                  if (state.status == CensusStatus.failure) ...<Widget>[
                    const SizedBox(height: 8),
                    Text(
                      'Could not refresh. Showing the last list. ${state.error ?? ''}',
                      style: AppTypography.regular(
                        fontSize: 12,
                        color: colors.error,
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  if (visible.isEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 32),
                      child: Text(
                        state.patients.isEmpty
                            ? 'No patients on this team yet. Use the add button to add one.'
                            : 'No patients match this view.',
                        textAlign: TextAlign.center,
                        style: AppTypography.regular(
                          color: colors.textSecondary,
                        ),
                      ),
                    )
                  else if (_filter == _CensusFilter.all)
                    ReorderableListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: visible.length,
                      onReorder: (int oldIndex, int newIndex) {
                        if (newIndex > oldIndex) newIndex -= 1;
                        context.read<CensusBloc>().add(
                          CensusReorderRequested(
                            oldIndex: oldIndex,
                            newIndex: newIndex,
                          ),
                        );
                      },
                      itemBuilder: (BuildContext context, int index) {
                        final PatientSummary patient = visible[index];
                        return Padding(
                          key: ValueKey<String>(patient.id),
                          padding: const EdgeInsets.only(bottom: 12),
                          child: PatientCard(
                            patient: patient,
                            dragIndex: index,
                            onTap: () => _openPatient(context, patient),
                          ),
                        );
                      },
                    )
                  else
                    ...visible.map(
                      (PatientSummary patient) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: PatientCard(
                          patient: patient,
                          onTap: () => _openPatient(context, patient),
                        ),
                      ),
                    ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Future<void> _afterIntake(BuildContext context, Object? next) async {
    if (next is String && context.mounted) {
      await context.push<Object>(next);
    }
    if (context.mounted) {
      context.read<CensusBloc>().add(const CensusRequested());
    }
  }

  Future<void> _openPatient(
    BuildContext context,
    PatientSummary patient,
  ) async {
    await context.push(AppRoutes.patientPath(patient.id));
    if (context.mounted) {
      context.read<CensusBloc>().add(const CensusRequested());
    }
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final AppColors colors = AppColors.of(context);
    return Material(
      color: selected ? colors.primary : colors.surface,
      borderRadius: BorderRadius.circular(24),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: selected ? colors.primary : colors.border,
            ),
          ),
          child: Text(
            label,
            style: AppTypography.semiBold(
              color: selected ? colors.white : colors.textSecondary,
              fontSize: 13,
            ),
          ),
        ),
      ),
    );
  }
}

/// One census row. The pill is the summary state, nothing else.
class PatientCard extends StatelessWidget {
  const PatientCard({
    required this.patient,
    required this.onTap,
    this.dragIndex,
    super.key,
  });

  final PatientSummary patient;
  final VoidCallback onTap;

  /// When set, shows a drag handle for [ReorderableListView].
  final int? dragIndex;

  @override
  Widget build(BuildContext context) {
    final AppColors colors = AppColors.of(context);
    final (Color bg, Color fg) = switch (patient.summaryState) {
      SummaryState.notGenerated => (colors.chipIdle, colors.textSecondary),
      SummaryState.draftReady => (colors.pendingBg, colors.pending),
      SummaryState.reviewed => (colors.successSoft, colors.success),
      SummaryState.outdated => (colors.warningSoft, colors.warning),
    };
    final int facts = patient.unreviewedFacts;
    final int tasks = patient.openTasks;
    return Material(
      color: colors.surface,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: colors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  CircleAvatar(
                    radius: 22,
                    backgroundColor: colors.primarySoft,
                    child: Text(
                      patient.initials,
                      style: AppTypography.bold(
                        fontSize: 14,
                        color: colors.primary,
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
                          style: AppTypography.semiBold(
                            fontSize: 16,
                            color: colors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          patient.metaLine,
                          style: AppTypography.regular(
                            fontSize: 12,
                            color: colors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (dragIndex != null)
                    ReorderableDragStartListener(
                      index: dragIndex!,
                      child: Icon(
                        Icons.drag_handle_rounded,
                        color: colors.textMuted,
                      ),
                    )
                  else
                    Icon(Icons.chevron_right_rounded, color: colors.textMuted),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: <Widget>[
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: bg,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      patient.summaryState.label,
                      style: AppTypography.semiBold(color: fg, fontSize: 11),
                    ),
                  ),
                  const Spacer(),
                  Flexible(
                    child: Text(
                      <String>[
                        facts == 0
                            ? 'No facts to review'
                            : '$facts ${facts == 1 ? 'fact' : 'facts'} to review',
                        tasks == 0
                            ? 'No open tasks'
                            : '$tasks ${tasks == 1 ? 'task' : 'tasks'}',
                      ].join(' · '),
                      textAlign: TextAlign.end,
                      style: AppTypography.regular(
                        fontSize: 12,
                        color: colors.textMuted,
                      ),
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
}
