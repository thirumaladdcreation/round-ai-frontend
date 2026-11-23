import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:round_ai/core/config/app_environment.dart';
import 'package:round_ai/core/di/injection_container.dart';
import 'package:round_ai/core/router/app_routes.dart';
import 'package:round_ai/core/sync/patient_status_store.dart';
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
    context.read<CensusBloc>().add(const CensusRequested());
  }

  @override
  void dispose() {
    _sync?.removeListener(_onCensusSync);
    super.dispose();
  }

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
            PatientStatusStore? statusStore;
            try {
              statusStore = InjectionContainer.instance.patientStatusStore;
            } catch (_) {}
            Widget listFor(List<PatientSummary> patients) {
              final List<PatientSummary> visible = _visible(patients);
              return RefreshIndicator(
                onRefresh: () => _refresh(context),
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Text(
                                'Patients',
                                style: AppTypography.bold(
                                  fontSize: 26,
                                  color: colors.textPrimary,
                                ),
                              ),
                              Text(
                                '$teamLabel · ${patients.length} total',
                                style: AppTypography.regular(
                                  fontSize: 13,
                                  color: colors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          tooltip: 'Export census',
                          onPressed: () => showCensusExportSheet(context),
                          icon: Icon(
                            Icons.ios_share_rounded,
                            color: colors.textPrimary,
                          ),
                        ),
                        IconButton(
                          tooltip: 'Add patient',
                          onPressed: () => showAddPatientSheet(context),
                          icon: const Icon(
                            Icons.person_add_alt_1_rounded,
                            color: Color(0xFF0A8F9C),
                          ),
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
                            label: const Text('Dictate'),
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
                            label: const Text('Scan'),
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 14),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: <Widget>[
                        _FilterChip(
                          label: 'All (${patients.length})',
                          selected: _filter == _CensusFilter.all,
                          onTap: () =>
                              setState(() => _filter = _CensusFilter.all),
                        ),
                        _FilterChip(
                          label:
                              'Facts (${patients.where((PatientSummary p) => p.unreviewedFacts > 0).length})',
                          selected: _filter == _CensusFilter.unreviewedFacts,
                          onTap: () => setState(
                            () => _filter = _CensusFilter.unreviewedFacts,
                          ),
                        ),
                        _FilterChip(
                          label:
                              'Outdated (${patients.where((PatientSummary p) => p.summaryState == SummaryState.outdated).length})',
                          selected: _filter == _CensusFilter.outdated,
                          onTap: () => setState(
                            () => _filter = _CensusFilter.outdated,
                          ),
                        ),
                      ],
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
                          patients.isEmpty
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
            }

            if (statusStore == null) {
              return listFor(state.patients);
            }
            return ListenableBuilder(
              listenable: statusStore,
              builder: (BuildContext context, Widget? _) {
                return listFor(statusStore!.overlayAll(state.patients));
              },
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
      color: selected ? const Color(0xFF0A8F9C) : colors.surface,
      borderRadius: BorderRadius.circular(24),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: selected ? const Color(0xFF0A8F9C) : colors.border,
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
    final (Color bg, Color fg, String label) = switch (patient.summaryState) {
      SummaryState.notGenerated => (
        colors.criticalBg,
        colors.critical,
        'Not started',
      ),
      SummaryState.draftReady => (
        const Color(0xFFE8F3FF),
        colors.primary,
        'Draft',
      ),
      SummaryState.reviewed => (
        colors.successSoft,
        colors.success,
        'Reviewed',
      ),
      SummaryState.outdated => (
        colors.chipIdle,
        colors.textSecondary,
        'Outdated',
      ),
    };
    final String meta = <String>[
      if (patient.room.isNotEmpty) 'Rm ${patient.room}',
      if (patient.sex.isNotEmpty) patient.sex,
      if (patient.ageBand.isNotEmpty) patient.ageBand,
    ].join(' · ');
    final String oneLiner = patient.oneLiner.trim();
    final List<String> changes = patient.keyChanges
        .map((String s) => s.trim())
        .where((String s) => s.isNotEmpty)
        .take(2)
        .toList(growable: false);
    return Material(
      color: colors.surface,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          decoration: BoxDecoration(
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
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              CircleAvatar(
                radius: 22,
                backgroundColor: const Color(0xFFD6F3F6),
                child: Text(
                  patient.initials,
                  style: AppTypography.bold(
                    fontSize: 14,
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
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.semiBold(
                        fontSize: 15,
                        color: colors.textPrimary,
                      ),
                    ),
                    if (meta.isNotEmpty) ...<Widget>[
                      const SizedBox(height: 2),
                      Text(
                        meta,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.regular(
                          fontSize: 13,
                          color: colors.textSecondary,
                        ),
                      ),
                    ],
                    if (oneLiner.isNotEmpty) ...<Widget>[
                      const SizedBox(height: 4),
                      Text(
                        oneLiner,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.regular(
                          fontSize: 13,
                          height: 1.3,
                          color: colors.textPrimary,
                        ),
                      ),
                    ],
                    if (changes.isNotEmpty) ...<Widget>[
                      const SizedBox(height: 4),
                      for (final String change in changes)
                        Text(
                          '• $change',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.regular(
                            fontSize: 12,
                            height: 1.3,
                            color: colors.textSecondary,
                          ),
                        ),
                    ],
                    if (patient.unreviewedFacts > 0 ||
                        patient.openTasks > 0) ...<Widget>[
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: <Widget>[
                          if (patient.unreviewedFacts > 0)
                            _CensusBadge(
                              label: patient.unreviewedFacts == 1
                                  ? '1 fact to review'
                                  : '${patient.unreviewedFacts} facts to review',
                              background: colors.criticalBg,
                              foreground: colors.critical,
                            ),
                          if (patient.openTasks > 0)
                            _CensusBadge(
                              label: patient.openTasks == 1
                                  ? '1 open task'
                                  : '${patient.openTasks} open tasks',
                              background: const Color(0xFFE8F3FF),
                              foreground: colors.primary,
                            ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: bg,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  label,
                  style: AppTypography.semiBold(color: fg, fontSize: 11),
                ),
              ),
              const SizedBox(width: 4),
              if (dragIndex != null)
                ReorderableDragStartListener(
                  index: dragIndex!,
                  child: Icon(
                    Icons.drag_handle_rounded,
                    color: colors.textSecondary,
                  ),
                )
              else
                Icon(
                  Icons.chevron_right_rounded,
                  color: colors.textSecondary,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CensusBadge extends StatelessWidget {
  const _CensusBadge({
    required this.label,
    required this.background,
    required this.foreground,
  });

  final String label;
  final Color background;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: AppTypography.semiBold(color: foreground, fontSize: 11),
      ),
    );
  }
}
