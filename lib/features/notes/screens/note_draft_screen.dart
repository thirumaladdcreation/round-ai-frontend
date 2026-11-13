import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:round_ai/core/config/app_environment.dart';
import 'package:round_ai/core/di/injection_container.dart';
import 'package:round_ai/core/errors/result.dart';
import 'package:round_ai/core/network/api_error.dart';
import 'package:round_ai/core/router/app_routes.dart';
import 'package:round_ai/core/theme/app_colors.dart';
import 'package:round_ai/core/theme/app_typography.dart';
import 'package:round_ai/features/ai/models/ai_envelope.dart';
import 'package:round_ai/features/ai/models/summary_content.dart';
import 'package:round_ai/features/ai/repository/ai_repository.dart';
import 'package:round_ai/features/ai/widgets/placeholder_text.dart';
import 'package:round_ai/features/ai/widgets/source_drawer.dart';
import 'package:round_ai/features/authentication/repository/profile_repository.dart';
import 'package:round_ai/features/notes/bloc/note_cubit.dart';
import 'package:round_ai/features/notes/models/note_section.dart';
import 'package:round_ai/features/notes/models/note_template.dart';
import 'package:round_ai/features/notes/repository/notes_repository.dart';
import 'package:round_ai/features/patient/models/chart_source.dart';
import 'package:round_ai/features/patient/models/patient_detail.dart';
import 'package:round_ai/features/patient/repository/chart_data_repository.dart';
import 'package:round_ai/features/patient/repository/patient_repository.dart';
import 'package:round_ai/features/patient/widgets/chart_entry_scaffold.dart';
import 'package:round_ai/features/scribe/widgets/field_mic_button.dart';
import 'package:round_ai/shared/widgets/ai_state.dart';
import 'package:round_ai/shared/widgets/app_input.dart';
import 'package:round_ai/shared/widgets/retry_view.dart';

const String noteAiOffMessage =
    'AI is temporarily off. Manual entry still works.';

/// A note draft on the real backend. The clinician types what only they
/// know. Everything else is written from confirmed chart facts, and nothing
/// is invented for a part that was not entered.
class NoteDraftScreen extends StatelessWidget {
  const NoteDraftScreen({
    required this.patientId,
    this.notesRepository,
    this.aiRepository,
    this.aiOff,
    super.key,
  });

  final String patientId;
  final NotesRepository? notesRepository;
  final AiRepository? aiRepository;

  /// Tests set this. The app reads the profile.
  final bool? aiOff;

  @override
  Widget build(BuildContext context) {
    final InjectionContainer di = InjectionContainer.instance;
    final AiRepository ai = aiRepository ?? di.aiRepository;
    return BlocProvider<NoteCubit>(
      create: (_) =>
          NoteCubit(notesRepository ?? di.notesRepository, ai, patientId)
            ..loadTemplates(),
      child: _NoteView(
        patientId: patientId,
        aiRepository: ai,
        aiOff: aiOff ?? di.profileRepository.aiOff,
      ),
    );
  }
}

class _NoteView extends StatefulWidget {
  const _NoteView({
    required this.patientId,
    required this.aiRepository,
    required this.aiOff,
  });

  final String patientId;
  final AiRepository aiRepository;
  final bool aiOff;

  @override
  State<_NoteView> createState() => _NoteViewState();
}

class _NoteViewState extends State<_NoteView> {
  /// One controller per input, kept while the screen is open so switching
  /// template does not lose what was typed.
  final Map<String, TextEditingController> _fields =
      <String, TextEditingController>{};

  /// Dictation / image sources selected to fill empty fields on generate.
  final Set<String> _sourceIds = <String>{};
  List<ChartSource> _feedSources = const <ChartSource>[];
  bool _sourcesLoaded = false;

  /// Saved chart plan (Today's plan editor). Prefills empty note plan fields.
  String _savedPlan = '';

  TextEditingController _field(String id) =>
      _fields.putIfAbsent(id, TextEditingController.new);

  @override
  void initState() {
    super.initState();
    if (!AppEnvironment.useDemo) {
      _loadFeedSources();
      _loadSavedPlan();
    }
  }

  Future<void> _loadSavedPlan() async {
    final PatientRepository? repo;
    try {
      repo = InjectionContainer.instance.patientRepository;
    } catch (_) {
      return;
    }
    final Result<PatientDetail> result = await repo.loadDetail(widget.patientId);
    if (!mounted) return;
    switch (result) {
      case Err<PatientDetail>():
        return;
      case Ok<PatientDetail>(:final value):
        final String text = value.planToday.join('\n').trim();
        if (text.isEmpty) return;
        setState(() => _savedPlan = text);
        // Prefill empty Assessment/Plan inputs for every template type.
        for (final String type in const <String>['progress', 'icu', 'admit_hp']) {
          final TextEditingController c = _field('$type/plan');
          if (c.text.trim().isEmpty) c.text = text;
        }
    }
  }

  Future<void> _loadFeedSources() async {
    final ChartDataRepository? repo;
    try {
      repo = InjectionContainer.instance.chartDataRepository;
    } catch (_) {
      // Widget tests pump the screen without DI.
      if (mounted) setState(() => _sourcesLoaded = true);
      return;
    }
    final Result<List<ChartSource>> result = await repo.listSources(
      widget.patientId,
    );
    if (!mounted) return;
    switch (result) {
      case Err<List<ChartSource>>():
        setState(() => _sourcesLoaded = true);
      case Ok<List<ChartSource>>(:final value):
        setState(() {
          _sourcesLoaded = true;
          _feedSources = value
              .where((ChartSource s) => s.kind.feedsNotes)
              .toList();
        });
    }
  }

  @override
  void dispose() {
    for (final TextEditingController c in _fields.values) {
      c.dispose();
    }
    super.dispose();
  }

  /// Flat backend fields. Empty ones are left out so the server marks them
  /// "not entered". History keys use each section's own key.
  Map<String, Object> _inputs(NoteTemplate template) {
    final Map<String, Object> inputs = <String, Object>{};
    final Map<String, String> history = <String, String>{};
    for (final TemplateSection s in template.typedSections) {
      if (s.source == SectionSource.history) {
        final String text = _field(
          '${template.type}/history/${s.key}',
        ).text.trim();
        if (text.isNotEmpty) history[s.key] = text;
      } else {
        final String? wire = s.source.wireField;
        if (wire == null) continue;
        final String text = _field('${template.type}/$wire').text.trim();
        if (text.isNotEmpty) inputs[wire] = text;
      }
    }
    // Chart "Today's plan" fills Assessment/Plan when the note field is empty.
    if (!inputs.containsKey('plan') && _savedPlan.isNotEmpty) {
      inputs['plan'] = _savedPlan;
    }
    if (history.isNotEmpty) inputs['history'] = history;
    return inputs;
  }

  void _generate(NoteCubit cubit, NoteTemplate template) {
    final List<String> ids = _sourceIds.toList();
    cubit.generate(
      _inputs(template),
      inputsFromSourceIds: ids.isEmpty ? null : ids,
    );
  }

  Future<void> _edit(NoteSection section) async {
    final NoteCubit cubit = context.read<NoteCubit>();
    final String? text = await showDialog<String>(
      context: context,
      builder: (BuildContext dialog) => _EditDialog(section: section),
    );
    if (text != null && text.isNotEmpty && text != section.text) {
      await cubit.saveSection(section.key, text);
    }
  }

  Future<void> _showProposal(RewriteProposal proposal, String title) async {
    final NoteCubit cubit = context.read<NoteCubit>();
    final bool? apply = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialog) {
        final AppColors colors = AppColors.of(dialog);
        return AlertDialog(
          title: Text('${proposal.mode.label}: $title'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'AI draft · review required',
                  style: AppTypography.medium(
                    fontSize: 11,
                    color: colors.aiAccent,
                  ),
                ),
                const SizedBox(height: 10),
                Text('Before', style: AppTypography.semiBold(fontSize: 13)),
                const SizedBox(height: 4),
                PlaceholderText(
                  proposal.before,
                  style: AppTypography.regular(fontSize: 13, height: 1.4),
                ),
                const SizedBox(height: 12),
                Text('After', style: AppTypography.semiBold(fontSize: 13)),
                const SizedBox(height: 4),
                PlaceholderText(
                  proposal.after,
                  style: AppTypography.regular(fontSize: 13, height: 1.4),
                ),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.pop(dialog, false),
              child: const Text('Keep current'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(dialog, true),
              child: const Text('Apply'),
            ),
          ],
        );
      },
    );
    if (apply == true) {
      await cubit.applyProposal();
    } else {
      cubit.dismissProposal();
    }
  }

  Future<void> _copy(NoteCubit cubit) async {
    final String? text = await cubit.export();
    if (!mounted) return;
    if (text == null) return;
    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Note text copied.')));
  }

  @override
  Widget build(BuildContext context) {
    final AppColors colors = AppColors.of(context);
    return BlocConsumer<NoteCubit, NoteDraftState>(
      listenWhen: (NoteDraftState a, NoteDraftState b) =>
          b.proposal != null && a.proposal != b.proposal,
      listener: (BuildContext context, NoteDraftState state) {
        final RewriteProposal p = state.proposal!;
        final String title = state.sections
            .firstWhere(
              (NoteSection s) => s.key == p.sectionKey,
              orElse: () => NoteSection(
                key: p.sectionKey,
                title: humanizeKey(p.sectionKey),
                text: '',
              ),
            )
            .title;
        _showProposal(p, title);
      },
      builder: (BuildContext context, NoteDraftState state) {
        final NoteCubit cubit = context.read<NoteCubit>();
        final NoteTemplate? template = state.template;
        final AiState chip = state.generating
            ? AiState.loading
            : state.envelope == null
            ? (state.error == null
                  ? AiState.notGenerated
                  : AiState.fromError(state.error!))
            : AiState.fromEnvelope(state.envelope);
        return ChartEntryScaffold(
          title: 'Draft note',
          bottom:
              state.templatesPhase != TemplatesPhase.ready || template == null
              ? null
              : _GenerateBar(
                  state: state,
                  aiOff: widget.aiOff,
                  onGenerate: () => _generate(cubit, template),
                  onCancel: cubit.cancel,
                ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Wrap(
                spacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: <Widget>[
                  AiStateChip(state: chip),
                  if (state.hasDraft && !state.isReviewed)
                    Text(
                      'AI draft · review required',
                      style: AppTypography.medium(
                        fontSize: 11,
                        color: colors.aiAccent,
                      ),
                    ),
                ],
              ),
              if (state.isReviewed) ...<Widget>[
                const SizedBox(height: 12),
                Text(
                  'This note is reviewed. Scroll the sections below, or copy '
                  'the full text here.',
                  style: AppTypography.regular(
                    fontSize: 13,
                    height: 1.4,
                    color: colors.textSecondary,
                  ),
                ),
                const SizedBox(height: 10),
                Align(
                  alignment: Alignment.centerLeft,
                  child: OutlinedButton.icon(
                    onPressed: state.canExport ? () => _copy(cubit) : null,
                    icon: state.exporting
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.copy_rounded, size: 18),
                    label: const Text('Copy note text'),
                  ),
                ),
                if (!state.canExport && state.outdated)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      'Chart changed after review. Regenerate, then mark '
                      'reviewed again before copying.',
                      style: AppTypography.regular(
                        fontSize: 12,
                        color: colors.warning,
                      ),
                    ),
                  ),
              ] else ...<Widget>[
                const SizedBox(height: 10),
                Text(
                  'The draft uses only what you type below and the chart facts '
                  'you have confirmed. A part you leave empty stays "not '
                  'entered". It is never filled in for you.',
                  style: AppTypography.regular(
                    fontSize: 13,
                    height: 1.4,
                    color: colors.textSecondary,
                  ),
                ),
              ],
              const SizedBox(height: 14),
              ..._templates(context, state, cubit, template),
              if (state.error != null) ...<Widget>[
                const SizedBox(height: 12),
                _ErrorBox(
                  error: state.error!,
                  onRetry: state.error!.isRetryable
                      ? () => _generate(cubit, template!)
                      : null,
                  onReviewFacts:
                      state.error!.kind == ApiErrorKind.noReviewedFacts
                      ? () => context.push<Object>(
                          AppRoutes.patientFactsPath(widget.patientId),
                        )
                      : null,
                ),
              ],
              if (widget.aiOff) ...<Widget>[
                const SizedBox(height: 12),
                Text(
                  noteAiOffMessage,
                  style: AppTypography.regular(
                    fontSize: 12,
                    color: colors.critical,
                  ),
                ),
              ],
              if (state.hasDraft) ...<Widget>[
                const SizedBox(height: 20),
                _Draft(
                  state: state,
                  aiOff: widget.aiOff,
                  aiRepository: widget.aiRepository,
                  onEdit: _edit,
                  onCopy: () => _copy(cubit),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  List<Widget> _templates(
    BuildContext context,
    NoteDraftState state,
    NoteCubit cubit,
    NoteTemplate? template,
  ) {
    final AppColors colors = AppColors.of(context);
    switch (state.templatesPhase) {
      case TemplatesPhase.loading:
        return const <Widget>[
          Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: CircularProgressIndicator(),
            ),
          ),
        ];
      case TemplatesPhase.failed:
        return <Widget>[
          SizedBox(
            height: 260,
            child: RetryView(
              title: 'Note templates could not be loaded.',
              message: state.templatesError?.userMessage ?? '',
              onRetry: cubit.loadTemplates,
            ),
          ),
        ];
      case TemplatesPhase.ready:
        if (template == null) {
          return <Widget>[
            Text(
              'No note templates are available.',
              style: AppTypography.regular(color: colors.textSecondary),
            ),
          ];
        }
        return <Widget>[
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              for (final NoteTemplate t in state.templates)
                ChoiceChip(
                  label: Text(t.name),
                  selected: t.type == state.selectedType,
                  // A draft belongs to its template. Start a new one to
                  // use another.
                  onSelected: state.hasDraft || state.generating
                      ? null
                      : (_) => cubit.selectTemplate(t.type),
                ),
            ],
          ),
          const SizedBox(height: 16),
          ..._form(context, template, enabled: !state.generating),
        ];
    }
  }

  List<Widget> _form(
    BuildContext context,
    NoteTemplate template, {
    required bool enabled,
  }) {
    final AppColors colors = AppColors.of(context);
    final List<Widget> out = <Widget>[];
    if (!AppEnvironment.useDemo && (_sourcesLoaded || _feedSources.isNotEmpty)) {
      out.addAll(_sourcePicker(context, enabled: enabled));
    }
    for (final TemplateSection s in template.sections) {
      if (s.source == SectionSource.history) {
        out.add(
          _input(
            context,
            id: '${template.type}/history/${s.key}',
            label: s.title,
            enabled: enabled,
            lines: 2,
          ),
        );
      } else if (s.source.isTyped) {
        final String wire = s.source.wireField ?? s.key;
        out.add(
          _input(
            context,
            id: '${template.type}/$wire',
            label: s.title,
            enabled: enabled,
          ),
        );
      }
    }
    final List<String> generated = <String>[
      for (final TemplateSection s in template.sections)
        if (!s.source.isTyped) s.title,
    ];
    if (generated.isNotEmpty) {
      out.add(
        Text(
          'Written from confirmed chart facts: ${generated.join(', ')}.',
          style: AppTypography.regular(
            fontSize: 12,
            height: 1.4,
            color: colors.textSecondary,
          ),
        ),
      );
    }
    if (_savedPlan.isNotEmpty) {
      out.add(const SizedBox(height: 8));
      out.add(
        Text(
          "Using saved Today's plan for Assessment and Plan. Regenerate after editing the plan.",
          style: AppTypography.regular(
            fontSize: 12,
            height: 1.4,
            color: colors.textSecondary,
          ),
        ),
      );
    }
    return out;
  }

  List<Widget> _sourcePicker(BuildContext context, {required bool enabled}) {
    final AppColors colors = AppColors.of(context);
    if (_feedSources.isEmpty) {
      return <Widget>[
        Text(
          'No saved dictations or photo extracts yet. Use Add info on the '
          'patient screen, or dictate into a field below.',
          style: AppTypography.regular(
            fontSize: 12,
            height: 1.4,
            color: colors.textSecondary,
          ),
        ),
        const SizedBox(height: 14),
      ];
    }
    return <Widget>[
      Text(
        'Fill empty fields from saved dictation / photo',
        style: AppTypography.semiBold(
          fontSize: 13,
          color: colors.textPrimary,
        ),
      ),
      const SizedBox(height: 6),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: <Widget>[
          for (final ChartSource s in _feedSources)
            FilterChip(
              label: Text(s.title ?? s.kind.label),
              selected: _sourceIds.contains(s.id),
              onSelected: enabled
                  ? (bool on) {
                      setState(() {
                        if (on) {
                          _sourceIds.add(s.id);
                        } else {
                          _sourceIds.remove(s.id);
                        }
                      });
                    }
                  : null,
            ),
        ],
      ),
      const SizedBox(height: 14),
    ];
  }

  Widget _input(
    BuildContext context, {
    required String id,
    required String label,
    required bool enabled,
    int lines = 3,
  }) {
    final TextEditingController controller = _field(id);
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          TextField(
            controller: controller,
            enabled: enabled,
            minLines: lines,
            maxLines: lines + 3,
            keyboardType: TextInputType.multiline,
            decoration: appInputDecoration(
              context,
              label: label,
              hint: 'Enter only what you know',
            ).copyWith(
              suffixIcon: AppEnvironment.useDemo
                  ? null
                  : FieldMicButton(controller: controller, enabled: enabled),
            ),
          ),
          const FreeTextHint(),
        ],
      ),
    );
  }
}

class _GenerateBar extends StatelessWidget {
  const _GenerateBar({
    required this.state,
    required this.aiOff,
    required this.onGenerate,
    required this.onCancel,
  });

  final NoteDraftState state;
  final bool aiOff;
  final VoidCallback onGenerate;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final AppColors colors = AppColors.of(context);
    if (state.generating) {
      return Row(
        children: <Widget>[
          const SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Writing the draft. This can take up to a minute.',
              style: AppTypography.regular(
                fontSize: 12,
                color: colors.textSecondary,
              ),
            ),
          ),
          TextButton(onPressed: onCancel, child: const Text('Cancel')),
        ],
      );
    }
    return SizedBox(
      width: double.infinity,
      child: FilledButton.icon(
        onPressed: aiOff || state.busy ? null : onGenerate,
        icon: const Icon(Icons.auto_awesome, size: 18),
        label: Text(state.hasDraft ? 'Regenerate draft' : 'Generate draft'),
      ),
    );
  }
}

class _Draft extends StatelessWidget {
  const _Draft({
    required this.state,
    required this.aiOff,
    required this.aiRepository,
    required this.onEdit,
    required this.onCopy,
  });

  final NoteDraftState state;
  final bool aiOff;
  final AiRepository aiRepository;
  final void Function(NoteSection section) onEdit;
  final VoidCallback onCopy;

  @override
  Widget build(BuildContext context) {
    final AppColors colors = AppColors.of(context);
    final NoteCubit cubit = context.read<NoteCubit>();
    final AiEnvelope envelope = state.envelope!;
    final Set<String> marked = state.markedSections;
    final List<String> blockers = state.reviewBlockers;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        if (state.outdated)
          _Notice(
            color: colors.warningSoft,
            textColor: colors.warning,
            text:
                'Outdated. The chart changed after this draft was written. '
                'Regenerate to update it.',
          ),
        if (envelope.isPartial)
          _Notice(
            color: colors.warningSoft,
            textColor: colors.warning,
            text: envelope.validationIssues.isEmpty
                ? 'Partial result. Some parts were withheld by validation.'
                : 'Partial result. ${envelope.validationIssues.length} '
                      '${envelope.validationIssues.length == 1 ? 'part was' : 'parts were'} '
                      'withheld by validation.',
          ),
        if (state.content?.fedFromSources.isNotEmpty ?? false)
          _Notice(
            color: colors.primarySoft,
            textColor: colors.textSecondary,
            text:
                'Filled empty fields from ${state.content!.fedFromSources.length} '
                'saved source${state.content!.fedFromSources.length == 1 ? '' : 's'} '
                '(${state.content!.fedFromSources.map((FedFromSource f) => f.field).toSet().join(', ')}).',
          ),
        for (final NoteSection section in state.sections)
          _SectionCard(
            section: section,
            marked: marked.contains(section.key),
            saving: state.savingKey == section.key,
            rewriting: state.rewritingKey == section.key,
            locked: state.busy,
            aiOff: aiOff,
            aiRepository: aiRepository,
            onEdit: () => onEdit(section),
          ),
        if (state.rewritingKey != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    'Rewriting the section. This can take up to a minute.',
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
          ),
        if (state.saveError != null) _ErrorBox(error: state.saveError!),
        if (state.rewriteError != null) _ErrorBox(error: state.rewriteError!),
        if (state.reviewError != null)
          _ErrorBox(
            error: state.reviewError!,
            sections: state.flaggedSections.length,
          ),
        if (state.exportError != null) _ErrorBox(error: state.exportError!),
        const SizedBox(height: 4),
        if (!state.isReviewed)
          Align(
            alignment: Alignment.centerLeft,
            child: FilledButton.icon(
              onPressed: state.canMarkReviewed ? cubit.markReviewed : null,
              icon: state.reviewing
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.verified_outlined, size: 18),
              label: const Text('Mark reviewed'),
            ),
          ),
        for (final String reason in blockers)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              reason,
              style: AppTypography.regular(fontSize: 12, color: colors.warning),
            ),
          ),
        // Reviewed notes show Copy near the top of the screen. Drafts keep
        // the button here with the "after review" hint.
        if (!state.isReviewed) ...<Widget>[
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton.icon(
              onPressed: state.canExport ? onCopy : null,
              icon: const Icon(Icons.copy_rounded, size: 18),
              label: const Text('Copy note text'),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              'Copying is available after the note is reviewed.',
              style: AppTypography.regular(
                fontSize: 12,
                color: colors.textMuted,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.section,
    required this.marked,
    required this.saving,
    required this.rewriting,
    required this.locked,
    required this.aiOff,
    required this.aiRepository,
    required this.onEdit,
  });

  final NoteSection section;
  final bool marked;
  final bool saving;
  final bool rewriting;
  final bool locked;
  final bool aiOff;
  final AiRepository aiRepository;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final AppColors colors = AppColors.of(context);
    final NoteCubit cubit = context.read<NoteCubit>();
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: marked ? colors.warning : colors.border,
          width: marked ? 1.5 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  section.title,
                  style: AppTypography.semiBold(
                    fontSize: 15,
                    color: colors.textPrimary,
                  ),
                ),
              ),
              if (saving || rewriting)
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
            ],
          ),
          if (section.originLabel != null)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                section.originLabel!,
                style: AppTypography.medium(
                  fontSize: 11,
                  color: section.source == SectionSource.facts
                      ? colors.success
                      : colors.primary,
                ),
              ),
            ),
          const SizedBox(height: 8),
          PlaceholderText(
            section.text.isEmpty ? 'Not entered' : section.text,
            style: AppTypography.regular(
              height: 1.45,
              color: section.text.isEmpty ? colors.warning : colors.textPrimary,
            ),
          ),
          for (final NoteFlag flag in section.flags)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Icon(Icons.flag_rounded, size: 16, color: colors.warning),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      flag.text,
                      style: AppTypography.regular(
                        fontSize: 12,
                        color: colors.warning,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          if (section.factIds.isNotEmpty) ...<Widget>[
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: <Widget>[
                for (int i = 0; i < section.factIds.length; i++)
                  ActionChip(
                    avatar: const Icon(Icons.link_rounded, size: 14),
                    label: Text('Source ${i + 1}'),
                    onPressed: () => showSourceDrawer(
                      context,
                      claim: Claim(
                        text: section.title,
                        label: ClaimLabel.fromChart,
                        factIds: <String>[section.factIds[i]],
                      ),
                      repository: aiRepository,
                    ),
                  ),
              ],
            ),
          ],
          const SizedBox(height: 4),
          Row(
            children: <Widget>[
              TextButton(
                onPressed: locked ? null : onEdit,
                child: const Text('Edit'),
              ),
              PopupMenuButton<RewriteMode>(
                tooltip: 'Rewrite this section',
                enabled: !locked && !aiOff,
                onSelected: (RewriteMode mode) =>
                    cubit.rewrite(section.key, mode),
                itemBuilder: (BuildContext context) =>
                    <PopupMenuEntry<RewriteMode>>[
                      for (final RewriteMode mode in RewriteMode.values)
                        PopupMenuItem<RewriteMode>(
                          value: mode,
                          child: Text(mode.label),
                        ),
                    ],
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  child: Text(
                    'Rewrite',
                    style: AppTypography.medium(
                      fontSize: 14,
                      color: locked || aiOff
                          ? colors.textMuted
                          : colors.primary,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ErrorBox extends StatelessWidget {
  const _ErrorBox({
    required this.error,
    this.sections = 0,
    this.onRetry,
    this.onReviewFacts,
  });

  final ApiError error;
  final int sections;
  final VoidCallback? onRetry;
  final VoidCallback? onReviewFacts;

  @override
  Widget build(BuildContext context) {
    final AppColors colors = AppColors.of(context);
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 8),
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
            style: AppTypography.regular(fontSize: 13, color: colors.critical),
          ),
          if (sections > 0)
            Text(
              sections == 1
                  ? '1 section is marked above.'
                  : '$sections sections are marked above.',
              style: AppTypography.regular(
                fontSize: 12,
                color: colors.critical,
              ),
            ),
          if (onReviewFacts != null)
            TextButton(
              onPressed: onReviewFacts,
              child: const Text('Review chart facts first'),
            ),
          if (onRetry != null)
            TextButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    );
  }
}

class _Notice extends StatelessWidget {
  const _Notice({
    required this.color,
    required this.textColor,
    required this.text,
  });

  final Color color;
  final Color textColor;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        text,
        style: AppTypography.regular(
          fontSize: 12,
          height: 1.4,
          color: textColor,
        ),
      ),
    );
  }
}

/// The edit dialog owns its controller, so it is disposed only after the
/// dialog has left the screen.
class _EditDialog extends StatefulWidget {
  const _EditDialog({required this.section});

  final NoteSection section;

  @override
  State<_EditDialog> createState() => _EditDialogState();
}

class _EditDialogState extends State<_EditDialog> {
  late final TextEditingController _controller = TextEditingController(
    // Placeholders are not real content — start blank so Save replaces them.
    text: hasPlaceholder(widget.section.text) ? '' : widget.section.text,
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Edit ${widget.section.title}'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          TextField(
            controller: _controller,
            minLines: 4,
            maxLines: 10,
            keyboardType: TextInputType.multiline,
            decoration: appInputDecoration(
              context,
              label: widget.section.title,
            ),
          ),
          const FreeTextHint(),
        ],
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, _controller.text.trim()),
          child: const Text('Save'),
        ),
      ],
    );
  }
}
