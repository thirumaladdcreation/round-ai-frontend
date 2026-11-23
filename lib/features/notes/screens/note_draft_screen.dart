import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'dart:convert';

import 'package:round_ai/core/config/app_environment.dart';
import 'package:round_ai/core/constants/app_constants.dart';
import 'package:round_ai/core/di/injection_container.dart';
import 'package:round_ai/core/errors/result.dart';
import 'package:round_ai/core/network/api_error.dart';
import 'package:round_ai/core/router/app_routes.dart';
import 'package:round_ai/core/storage/app_storage.dart';
import 'package:round_ai/core/theme/app_colors.dart';
import 'package:round_ai/core/theme/app_typography.dart';
import 'package:round_ai/core/utils/date_format.dart';
import 'package:round_ai/core/utils/hospital_clock.dart';
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
import 'package:round_ai/core/sync/census_sync_mark.dart';
import 'package:round_ai/features/patient/models/chart_source.dart';
import 'package:round_ai/features/patient/models/patient_detail.dart';
import 'package:round_ai/features/patient/models/plan_structured.dart';
import 'package:round_ai/features/patient/models/problem.dart';
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

  /// Scribe mode: one transcript → structured note (keeps per-field as advanced).
  bool _scribeMode = true;
  final TextEditingController _transcript = TextEditingController();
  final Map<String, TextEditingController> _clarifyAnswers =
      <String, TextEditingController>{};
  int? _highlightStart;
  int? _highlightEnd;
  String? _patientName;
  String? _patientRoom;

  TextEditingController _field(String id) {
    return _fields.putIfAbsent(id, () {
      final TextEditingController c = TextEditingController();
      c.addListener(() {
        _persistCompose();
        if (mounted && !_scribeMode) setState(() {});
      });
      return c;
    });
  }

  String get _composeCacheKey =>
      '${AppConstants.noteComposeKeyPrefix}${widget.patientId}';

  AppStorage? get _storage {
    try {
      return InjectionContainer.instance.appStorage;
    } catch (_) {
      return null;
    }
  }

  /// Unsaved compose text that would be lost if the clinician leaves.
  bool get _composeDirty {
    if (_transcript.text.trim().length >= 12) return true;
    for (final TextEditingController c in _fields.values) {
      if (c.text.trim().isNotEmpty) return true;
    }
    return false;
  }

  void _persistCompose() {
    final AppStorage? storage = _storage;
    if (storage == null) return;
    final Map<String, String> fields = <String, String>{
      for (final MapEntry<String, TextEditingController> e in _fields.entries)
        if (e.value.text.trim().isNotEmpty) e.key: e.value.text,
    };
    final String transcript = _transcript.text.trim();
    if (transcript.isEmpty && fields.isEmpty) {
      storage.remove(_composeCacheKey);
      return;
    }
    storage.saveString(
      _composeCacheKey,
      jsonEncode(<String, Object>{
        'transcript': transcript,
        'fields': fields,
        'scribe': _scribeMode,
      }),
    );
  }

  void _restoreCompose() {
    final AppStorage? storage = _storage;
    if (storage == null) return;
    final String? raw = storage.readString(_composeCacheKey);
    if (raw == null || raw.isEmpty) return;
    try {
      final Object? decoded = jsonDecode(raw);
      if (decoded is! Map) return;
      final Map<String, dynamic> map = Map<String, dynamic>.from(decoded);
      final String transcript = '${map['transcript'] ?? ''}'.trim();
      if (transcript.isNotEmpty && _transcript.text.trim().isEmpty) {
        _transcript.text = transcript;
      }
      final Object? fieldsRaw = map['fields'];
      if (fieldsRaw is Map) {
        fieldsRaw.forEach((Object? key, Object? value) {
          final String k = '$key';
          final String v = '$value';
          if (k.isEmpty || v.trim().isEmpty) return;
          final TextEditingController c = _field(k);
          if (c.text.trim().isEmpty) c.text = v;
        });
      }
      if (map['scribe'] is bool) _scribeMode = map['scribe'] as bool;
    } catch (_) {}
  }

  void _clearComposeCache() {
    _storage?.remove(_composeCacheKey);
  }

  @override
  void initState() {
    super.initState();
    _transcript.addListener(_onTranscriptChanged);
    _restoreCompose();
    _loadPatientIdentity();
    if (!AppEnvironment.useDemo) {
      _loadFeedSources();
      _loadSavedPlan();
    }
  }

  Future<void> _loadPatientIdentity() async {
    try {
      final Result<PatientDetail> result = await InjectionContainer
          .instance
          .patientRepository
          .loadDetail(widget.patientId);
      if (!mounted) return;
      if (result case Ok<PatientDetail>(:final value)) {
        setState(() {
          _patientName = value.patient.displayName;
          _patientRoom = value.patient.room;
        });
      }
    } catch (_) {}
  }

  void _onTranscriptChanged() {
    _persistCompose();
    if (mounted) setState(() {});
  }

  /// Field has a usable dictation, or an existing draft still has one stored.
  bool _scribeReadyFor(NoteDraftState state) {
    if (_transcript.text.trim().length >= 12) return true;
    final String stored = state.content?.transcript.trim() ?? '';
    return state.hasDraft && stored.length >= 12;
  }

  /// Advanced mode: at least one clinician field or saved plan must have text.
  bool get _advancedReady {
    if (_savedPlan.trim().isNotEmpty) return true;
    for (final TextEditingController c in _fields.values) {
      if (c.text.trim().isNotEmpty) return true;
    }
    return false;
  }

  bool _canGenerateFor(NoteDraftState state) =>
      _scribeMode ? _scribeReadyFor(state) : _advancedReady;

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
        // Prefer server-rendered plan_today (ICD-aware) so note copy matches A&P.
        String text = value.planToday.join('\n').trim();
        if (text.isEmpty &&
            value.planStructured != null &&
            value.planStructured!.items.isNotEmpty) {
          text = value.planStructured!
              .toDisplayLines(
                withIcd: value.planStructured!.includeIcd,
                codeForLabel: (PlanItem item) {
                  for (final Problem p in value.problems) {
                    final String? c = p.codeSuggestion?.code;
                    if (c == null || c.isEmpty) continue;
                    if (item.problemId != null && p.id == item.problemId) {
                      return c;
                    }
                    if (p.label.toLowerCase() == item.label.toLowerCase()) {
                      return c;
                    }
                  }
                  return null;
                },
              )
              .join('\n')
              .trim();
        }
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
    _persistCompose();
    _transcript.removeListener(_onTranscriptChanged);
    for (final TextEditingController c in _fields.values) {
      c.dispose();
    }
    for (final TextEditingController c in _clarifyAnswers.values) {
      c.dispose();
    }
    _transcript.dispose();
    super.dispose();
  }

  Future<bool> _confirmLeaveIfDirty() async {
    if (!_composeDirty) return true;
    final bool? leave = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialog) => AlertDialog(
        title: const Text('Leave note draft?'),
        content: const Text(
          'Your dictation and typed fields are kept on this device until you '
          'return. Continue?',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(dialog, false),
            child: const Text('Stay'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialog, true),
            child: const Text('Leave'),
          ),
        ],
      ),
    );
    return leave == true;
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

  Future<void> _generate(NoteCubit cubit, NoteTemplate template) async {
    final NoteDraftState state = cubit.state;
    if (state.hasDraft) {
      final bool? ok = await showDialog<bool>(
        context: context,
        builder: (BuildContext dialog) => AlertDialog(
          title: const Text('Replace draft?'),
          content: const Text(
            'Regenerating replaces the current draft and any manual edits. '
            'Your dictation text stays. Continue?',
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.pop(dialog, false),
              child: const Text('Keep current'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(dialog, true),
              child: const Text('Regenerate'),
            ),
          ],
        ),
      );
      if (ok != true || !mounted) return;
    }
    if (_scribeMode) {
      if (!_scribeReadyFor(state)) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Enter a usable clinical update (at least a short sentence) before writing the note.',
            ),
          ),
        );
        return;
      }
      // Prefer field text; fall back to last successful draft transcript.
      if (_transcript.text.trim().length < 12) {
        final String stored = state.content?.transcript.trim() ?? '';
        if (stored.length >= 12) _transcript.text = stored;
      }
    } else if (!_advancedReady) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Enter at least one clinician field before generating an advanced draft.',
          ),
        ),
      );
      return;
    }
    if (_scribeMode) {
      final List<Map<String, String>> clarifications = <Map<String, String>>[
        for (final MapEntry<String, TextEditingController> e
            in _clarifyAnswers.entries)
          if (e.value.text.trim().isNotEmpty)
            <String, String>{'phrase': e.key, 'answer': e.value.text.trim()},
      ];
      await cubit.generateFromDictation(
        transcript: _transcript.text,
        clarifications: clarifications.isEmpty ? null : clarifications,
        noteDate: HospitalClock.todayIsoDate(),
      );
      if (!mounted) return;
      // Dictation text stays in the field on success or failure — never cleared here.
      if (cubit.state.hasDraft && cubit.state.error == null) {
        _clearComposeCache();
      } else {
        _persistCompose();
      }
      await _offerPlanBridge(cubit);
      return;
    }
    final List<String> ids = _sourceIds.toList();
    await cubit.generate(
      _inputs(template),
      inputsFromSourceIds: ids.isEmpty ? null : ids,
    );
    if (!mounted) return;
    if (cubit.state.hasDraft && cubit.state.error == null) {
      _clearComposeCache();
    } else {
      _persistCompose();
    }
  }

  /// If dictation produced an Assessment/Plan, offer to save it as today's plan
  /// so the resident does not retype it on the patient page.
  Future<void> _offerPlanBridge(NoteCubit cubit) async {
    final NoteContent? content = cubit.state.content;
    if (content == null) return;
    NoteSection? plan;
    for (final NoteSection s in content.sections) {
      if (s.key == 'assessment_plan' ||
          s.key == 'plan' ||
          s.title.toLowerCase().contains('plan')) {
        plan = s;
        break;
      }
    }
    if (plan == null) return;
    final String text = plan.text.trim();
    if (text.isEmpty || RegExp(r'not entered', caseSensitive: false).hasMatch(text)) {
      return;
    }
    final bool? save = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialog) => AlertDialog(
        title: const Text('Save Assessment and Plan?'),
        content: const Text(
          'Your dictation already includes an Assessment and Plan. Save it to '
          'the patient page (editable by problem) so you do not enter it twice. '
          'You can still edit it later under Assessment and Plan.',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(dialog, false),
            child: const Text('Not now'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialog, true),
            child: const Text('Save to patient page'),
          ),
        ],
      ),
    );
    if (save != true || !mounted) return;
    try {
      final PatientRepository repo =
          InjectionContainer.instance.patientRepository;
      final PlanStructured? parsed = PlanStructured.tryParseNoteText(text);
      PlanStructured? structured;
      final Result<void> result;
      if (parsed != null && parsed.items.isNotEmpty) {
        // Preserve existing ICD toggle preference; do not invent codes here.
        bool includeIcd = false;
        try {
          final Result<PatientDetail> detail =
              await repo.loadDetail(widget.patientId);
          if (detail case Ok<PatientDetail>(:final value)) {
            includeIcd = value.planStructured?.includeIcd ?? false;
          }
        } catch (_) {}
        structured = parsed.copyWith(includeIcd: includeIcd);
        result = await repo.saveStructuredPlan(widget.patientId, structured);
      } else {
        final List<String> lines = text
            .split('\n')
            .map((String l) => l.trim())
            .where((String l) => l.isNotEmpty)
            .toList();
        result = await repo.savePlan(widget.patientId, lines);
      }
      if (!mounted) return;
      if (result is Ok<void>) {
        markCensusDirty();
        final PlanStructured? saved = structured;
        _savedPlan = saved != null && saved.items.isNotEmpty
            ? saved.toDisplayLines().join('\n')
            : text;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              saved != null && saved.items.length > 1
                  ? 'Assessment and Plan saved by problem '
                        '(${saved.items.length} issues).'
                  : 'Assessment and Plan saved.',
            ),
          ),
        );
      }
    } catch (_) {}
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
            // Default / recommended: keep clinician wording (Prompt 8 §5.8).
            FilledButton(
              onPressed: () => Navigator.pop(dialog, false),
              child: const Text('Keep mine'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(dialog, true),
              child: const Text('Use new'),
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
    try {
      await Clipboard.setData(ClipboardData(text: text));
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Note text copied.')));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Clipboard blocked (common on Safari). Select the note text and copy manually.',
          ),
        ),
      );
    }
  }

  Future<void> _showHistory(NoteCubit cubit) async {
    final AppColors colors = AppColors.of(context);
    final List<NoteVersion> versions = await cubit.loadVersions();
    if (!mounted) return;
    if (versions.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No saved versions yet.')),
      );
      return;
    }
    final List<NoteVersion> newestFirst = versions.reversed.toList();
    final int? chosen = await showModalBottomSheet<int>(
      context: context,
      showDragHandle: true,
      builder: (BuildContext sheet) {
        return SafeArea(
          child: ListView(
            shrinkWrap: true,
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                child: Text(
                  'Version history',
                  style: AppTypography.semiBold(
                    fontSize: 16,
                    color: colors.textPrimary,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Text(
                  'Restore replaces the current draft and marks sections as '
                  'manually edited. Review is cleared.',
                  style: AppTypography.regular(
                    fontSize: 12,
                    height: 1.35,
                    color: colors.textSecondary,
                  ),
                ),
              ),
              for (final NoteVersion v in newestFirst)
                ListTile(
                  title: Text('Version ${v.version}'),
                  subtitle: Text(
                    DateFormatter.dateTimeOrUnknown(
                      HospitalClock.parseApiTimestamp(v.createdAt),
                    ),
                  ),
                  trailing: TextButton(
                    onPressed: () => Navigator.pop(sheet, v.version),
                    child: const Text('Restore'),
                  ),
                ),
            ],
          ),
        );
      },
    );
    if (chosen == null || !mounted) return;
    final bool? ok = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialog) => AlertDialog(
        title: const Text('Restore this version?'),
        content: Text(
          'Version $chosen becomes the current draft. You can edit and mark '
          'reviewed again.',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(dialog, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialog, true),
            child: const Text('Restore'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    await cubit.restoreVersion(chosen);
    if (!mounted) return;
    if (cubit.state.error == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Restored version $chosen.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppColors colors = AppColors.of(context);
    return BlocConsumer<NoteCubit, NoteDraftState>(
      listenWhen: (NoteDraftState a, NoteDraftState b) =>
          (b.proposal != null && a.proposal != b.proposal) ||
          ((b.content?.transcript ?? '') != (a.content?.transcript ?? '')),
      listener: (BuildContext context, NoteDraftState state) {
        final String stored = state.content?.transcript.trim() ?? '';
        if (stored.isNotEmpty && _transcript.text.trim().isEmpty) {
          _transcript.text = stored;
        }
        final RewriteProposal? p = state.proposal;
        if (p == null) return;
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
        // Warn only before a server draft exists; after generate, loadLatestNote restores work.
        final bool warnLeave = !state.hasDraft && _composeDirty;
        return PopScope(
          canPop: !warnLeave,
          onPopInvokedWithResult: (bool didPop, Object? result) async {
            if (didPop) return;
            final bool leave = await _confirmLeaveIfDirty();
            if (leave && context.mounted) {
              _persistCompose();
              Navigator.of(context).pop();
            }
          },
          child: ChartEntryScaffold(
          title: 'Draft note',
          patientName: _patientName,
          room: _patientRoom,
          trailing: state.hasDraft
              ? TextButton(
                  onPressed: state.busy ? null : () => _showHistory(cubit),
                  child: const Text('History'),
                )
              : null,
          bottom:
              state.templatesPhase != TemplatesPhase.ready || template == null
              ? null
              : _GenerateBar(
                  state: state,
                  aiOff: widget.aiOff,
                  scribeMode: _scribeMode,
                  canGenerate: _canGenerateFor(state),
                  onGenerate: () {
                    _generate(cubit, template);
                  },
                  onCancel: cubit.cancel,
                ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Wrap(
                spacing: 8,
                runSpacing: 6,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: <Widget>[
                  AiStateChip(state: chip),
                  if (state.outdated)
                    _StatusPill(
                      label: 'Outdated',
                      color: colors.warning,
                      soft: colors.warningSoft,
                    )
                  else if (state.isReviewed)
                    _StatusPill(
                      label: 'Reviewed',
                      color: colors.success,
                      soft: colors.successSoft,
                    )
                  else if (state.hasDraft)
                    _StatusPill(
                      label: state.envelope?.isPartial == true
                          ? 'Partial · edit required'
                          : 'Draft · review required',
                      color: colors.aiAccent,
                      soft: colors.aiCard,
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
              ] else if (!state.hasDraft) ...<Widget>[
                const SizedBox(height: 10),
                Text(
                  _scribeMode
                      ? 'Paste or dictate the update. Empty sections stay '
                            'not entered — nothing is invented.'
                      : 'Type each section. Empty parts stay not entered.',
                  style: AppTypography.regular(
                    fontSize: 14,
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
                  // Always offer retry for generation failures; dictation text is kept.
                  onRetry: template != null &&
                          state.error!.kind != ApiErrorKind.aiDisabled &&
                          state.error!.kind != ApiErrorKind.dailyLimit
                      ? () {
                          _generate(cubit, template);
                        }
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
                if (state.content?.scribeMode == true &&
                    (state.content?.sections.any(
                          (NoteSection s) => s.sentences.isNotEmpty,
                        ) ??
                        false)) ...<Widget>[
                  Text(
                    'Tap a sentence to see its transcript span.',
                    style: AppTypography.regular(
                      fontSize: 12,
                      color: colors.textMuted,
                    ),
                  ),
                  const SizedBox(height: 8),
                  for (final NoteSection section in state.sections)
                    if (section.sentences.isNotEmpty) ...<Widget>[
                      Text(
                        section.title,
                        style: AppTypography.semiBold(
                          fontSize: 13,
                          color: colors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      for (final NoteSentence sent in section.sentences)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: InkWell(
                            onTap: sent.spans.isEmpty
                                ? null
                                : () => setState(() {
                                    _highlightStart = sent.spans.first.start;
                                    _highlightEnd = sent.spans.first.end;
                                  }),
                            child: Text(
                              sent.text,
                              style: AppTypography.regular(
                                fontSize: 14,
                                height: 1.4,
                                color: colors.textPrimary,
                              ),
                            ),
                          ),
                        ),
                      const SizedBox(height: 10),
                    ],
                ],
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
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            children: <Widget>[
              ChoiceChip(
                label: const Text('Write note from dictation'),
                selected: _scribeMode,
                onSelected: state.generating
                    ? null
                    : (_) => setState(() => _scribeMode = true),
              ),
              ChoiceChip(
                label: const Text('Per-field (advanced)'),
                selected: !_scribeMode,
                onSelected: state.generating
                    ? null
                    : (_) => setState(() => _scribeMode = false),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (_scribeMode)
            ..._scribeForm(context, state, enabled: !state.generating)
          else
            ..._form(context, template, enabled: !state.generating),
        ];
    }
  }

  List<Widget> _scribeForm(
    BuildContext context,
    NoteDraftState state, {
    required bool enabled,
  }) {
    final AppColors colors = AppColors.of(context);
    final NoteContent? content = state.content;
    final List<Widget> out = <Widget>[
      TextField(
        controller: _transcript,
        enabled: enabled,
        minLines: 5,
        maxLines: 10,
        keyboardType: TextInputType.multiline,
        style: AppTypography.regular(
          fontSize: 15,
          height: 1.4,
          color: colors.textPrimary,
        ),
        cursorColor: colors.primary,
        decoration: appInputDecoration(
          context,
          label: 'Dictation',
          hint: 'Dictate or paste the full update…',
        ).copyWith(
          suffixIcon: AppEnvironment.useDemo
              ? null
              : FieldMicButton(controller: _transcript, enabled: enabled),
        ),
      ),
      const FreeTextHint(),
    ];
    if (_highlightStart != null &&
        _highlightEnd != null &&
        content != null &&
        content.transcript.isNotEmpty) {
      final String t = content.transcript;
      final int a = _highlightStart!.clamp(0, t.length);
      final int b = _highlightEnd!.clamp(0, t.length);
      out.addAll(<Widget>[
        const SizedBox(height: 12),
        Text(
          'Transcript source',
          style: AppTypography.medium(fontSize: 12, color: colors.textMuted),
        ),
        const SizedBox(height: 4),
        Text.rich(
          TextSpan(
            style: AppTypography.regular(
              fontSize: 13,
              height: 1.4,
              color: colors.textSecondary,
            ),
            children: <InlineSpan>[
              TextSpan(text: t.substring(0, a)),
              TextSpan(
                text: t.substring(a, b),
                style: TextStyle(
                  backgroundColor: colors.aiAccent.withValues(alpha: 0.25),
                  color: colors.textPrimary,
                ),
              ),
              TextSpan(text: t.substring(b)),
            ],
          ),
        ),
      ]);
    }
    final List<NeedsClarification> needs =
        content?.needsClarification ?? const <NeedsClarification>[];
    if (needs.isNotEmpty) {
      out.addAll(<Widget>[
        const SizedBox(height: 16),
        Text(
          'Needs your clarification',
          style: AppTypography.semiBold(
            fontSize: 14,
            color: colors.textPrimary,
          ),
        ),
        const SizedBox(height: 6),
        for (final NeedsClarification n in needs) ...<Widget>[
          Text(
            '"${n.phrase}" — ${n.question}',
            style: AppTypography.regular(
              fontSize: 13,
              height: 1.35,
              color: colors.textSecondary,
            ),
          ),
          const SizedBox(height: 6),
          TextField(
            controller: _clarifyAnswers.putIfAbsent(
              n.phrase,
              TextEditingController.new,
            ),
            enabled: enabled,
            minLines: 1,
            maxLines: 3,
            decoration: appInputDecoration(context, label: 'Your answer'),
          ),
          const SizedBox(height: 10),
        ],
        Text(
          'Answer above, then regenerate to update those sentences.',
          style: AppTypography.regular(fontSize: 12, color: colors.textMuted),
        ),
      ]);
    }
    return out;
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

class _StatusPill extends StatelessWidget {
  const _StatusPill({
    required this.label,
    required this.color,
    required this.soft,
  });

  final String label;
  final Color color;
  final Color soft;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: soft,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: AppTypography.medium(fontSize: 11, color: color),
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
    this.scribeMode = true,
    this.canGenerate = true,
  });

  final NoteDraftState state;
  final bool aiOff;
  final bool scribeMode;
  final bool canGenerate;
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
    final bool enabled = !aiOff && !state.busy && canGenerate;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        if (!canGenerate && !state.hasDraft)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              scribeMode
                  ? 'Add a short clinical update to enable Write note.'
                  : 'Enter at least one field before generating.',
              style: AppTypography.regular(
                fontSize: 13,
                color: colors.textSecondary,
              ),
            ),
          ),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: enabled ? onGenerate : null,
            icon: const Icon(Icons.auto_awesome, size: 20),
            label: Text(
              state.hasDraft
                  ? 'Regenerate draft'
                  : (scribeMode
                        ? 'Write note from dictation'
                        : 'Generate draft'),
              style: AppTypography.semiBold(fontSize: 15),
            ),
          ),
        ),
      ],
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
        if (state.saveError != null)
          _ErrorBox(error: state.saveError!, onRetry: cubit.retrySave),
        if (state.rewriteError != null) _ErrorBox(error: state.rewriteError!),
        if (state.reviewError != null)
          _ErrorBox(
            error: state.reviewError!,
            sections: state.flaggedSections.length,
          ),
        if (state.exportError != null) _ErrorBox(error: state.exportError!),
        const SizedBox(height: 8),
        if (!state.isReviewed) ...<Widget>[
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: state.canMarkReviewed ? cubit.markReviewed : null,
              icon: state.reviewing
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.verified_outlined, size: 20),
              label: Text(
                'Mark reviewed',
                style: AppTypography.semiBold(fontSize: 15),
              ),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: state.canExport ? onCopy : null,
              icon: const Icon(Icons.copy_rounded, size: 20),
              label: Text(
                'Copy note text',
                style: AppTypography.semiBold(fontSize: 15),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              state.canExport
                  ? 'Ready to copy.'
                  : 'Mark reviewed first, then copy.',
              style: AppTypography.regular(
                fontSize: 13,
                color: colors.textSecondary,
              ),
            ),
          ),
        ],
        for (final String reason in blockers)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              reason,
              style: AppTypography.regular(fontSize: 13, color: colors.warning),
            ),
          ),
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
          Builder(
            builder: (BuildContext context) {
              final PlanStructured? plan = _isPlanSection(section)
                  ? PlanStructured.tryParseNoteText(section.text)
                  : null;
              if (plan != null) return _PlanByProblem(plan: plan);
              return PlaceholderText(
                section.text.isEmpty ? 'Not entered' : section.text,
                style: AppTypography.regular(
                  fontSize: 15,
                  height: 1.45,
                  color: section.text.isEmpty
                      ? colors.warning
                      : colors.textPrimary,
                ),
              );
            },
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
                        fontSize: 13,
                        color: colors.warning,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          if (section.factIds.isNotEmpty) ...<Widget>[
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: () => showSourceDrawer(
                context,
                claim: Claim(
                  text: section.title,
                  label: ClaimLabel.fromChart,
                  factIds: section.factIds,
                ),
                repository: aiRepository,
              ),
              icon: const Icon(Icons.link_rounded, size: 18),
              label: Text(
                '${section.factIds.length} source'
                '${section.factIds.length == 1 ? '' : 's'}',
                style: AppTypography.medium(fontSize: 14),
              ),
            ),
          ],
          const SizedBox(height: 2),
          Row(
            children: <Widget>[
              FilledButton.tonal(
                onPressed: locked ? null : onEdit,
                child: const Text('Edit'),
              ),
              const SizedBox(width: 8),
              PopupMenuButton<RewriteMode>(
                tooltip: 'Rewrite this section',
                enabled: !locked && !aiOff,
                onSelected: (RewriteMode mode) async {
                  if (mode == RewriteMode.regenerate &&
                      section.text.trim().isNotEmpty &&
                      !hasPlaceholder(section.text)) {
                    final bool? ok = await showDialog<bool>(
                      context: context,
                      builder: (BuildContext dialog) => AlertDialog(
                        title: const Text('Regenerate this section?'),
                        content: const Text(
                          'This proposes new text for the section. Your current '
                          'wording stays until you tap Apply.',
                        ),
                        actions: <Widget>[
                          TextButton(
                            onPressed: () => Navigator.pop(dialog, false),
                            child: const Text('Cancel'),
                          ),
                          TextButton(
                            onPressed: () => Navigator.pop(dialog, true),
                            child: const Text('Propose rewrite'),
                          ),
                        ],
                      ),
                    );
                    if (ok != true || !context.mounted) return;
                  }
                  await cubit.rewrite(section.key, mode);
                },
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
                    horizontal: 10,
                    vertical: 10,
                  ),
                  child: Text(
                    'More',
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

  bool _isPlanSection(NoteSection section) {
    final String key = section.key.toLowerCase();
    final String title = section.title.toLowerCase();
    return key == 'assessment_plan' ||
        key == 'plan' ||
        title.contains('assessment') ||
        title.contains('plan');
  }
}

class _PlanByProblem extends StatelessWidget {
  const _PlanByProblem({required this.plan});

  final PlanStructured plan;

  @override
  Widget build(BuildContext context) {
    final AppColors colors = AppColors.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        for (int i = 0; i < plan.items.length; i++) ...<Widget>[
          if (i > 0) const SizedBox(height: 12),
          Text(
            plan.items[i].label.isEmpty
                ? 'Problem ${i + 1}'
                : plan.items[i].label,
            style: AppTypography.semiBold(
              fontSize: 14,
              color: colors.textPrimary,
            ),
          ),
          if (plan.items[i].assessment.isNotEmpty) ...<Widget>[
            const SizedBox(height: 4),
            Text(
              'Assessment',
              style: AppTypography.medium(
                fontSize: 12,
                color: colors.textSecondary,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              plan.items[i].assessment,
              style: AppTypography.regular(
                fontSize: 14,
                height: 1.4,
                color: colors.textPrimary,
              ),
            ),
          ],
          if (plan.items[i].plan.isNotEmpty) ...<Widget>[
            const SizedBox(height: 6),
            Text(
              'Plan',
              style: AppTypography.medium(
                fontSize: 12,
                color: colors.textSecondary,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              plan.items[i].plan,
              style: AppTypography.regular(
                fontSize: 14,
                height: 1.4,
                color: colors.textPrimary,
              ),
            ),
          ],
        ],
      ],
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
          if (error.referenceLine != null) ...<Widget>[
            const SizedBox(height: 4),
            Text(
              error.referenceLine!,
              style: AppTypography.regular(
                fontSize: 12,
                color: colors.textSecondary,
              ),
            ),
          ],
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
