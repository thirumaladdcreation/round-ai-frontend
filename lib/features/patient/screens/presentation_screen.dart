import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:round_ai/core/di/injection_container.dart';
import 'package:round_ai/core/errors/failures.dart';
import 'package:round_ai/core/errors/result.dart';
import 'package:round_ai/core/network/idempotency_key.dart';
import 'package:round_ai/core/theme/app_colors.dart';
import 'package:round_ai/core/theme/app_typography.dart';
import 'package:round_ai/core/utils/clinical_format.dart';
import 'package:round_ai/features/ai/models/ai_envelope.dart';
import 'package:round_ai/features/ai/repository/ai_repository.dart';
import 'package:round_ai/features/ai/repository/demo_ai_repository.dart';
import 'package:round_ai/features/ai/widgets/source_drawer.dart';
import 'package:round_ai/features/census/data/demo_patients.dart';
import 'package:round_ai/features/census/repository/demo_census_repository.dart';
import 'package:round_ai/features/patient/models/patient_detail.dart';
import 'package:round_ai/features/patient/repository/demo_patient_repository.dart';
import 'package:round_ai/features/patient/repository/patient_repository.dart';
import 'package:round_ai/features/rounds/models/presentation_draft.dart';
import 'package:round_ai/features/rounds/repository/demo_round_repository.dart';
import 'package:round_ai/features/rounds/repository/round_repository.dart';
import 'package:round_ai/shared/widgets/app_button.dart';
import 'package:round_ai/shared/widgets/workflow_page.dart';

class PresentationScreen extends StatefulWidget {
  const PresentationScreen({
    required this.patientId,
    this.roundRepository,
    this.aiRepository,
    this.patientRepository,
    super.key,
  });

  final String patientId;
  final RoundRepository? roundRepository;
  final AiRepository? aiRepository;
  final PatientRepository? patientRepository;

  @override
  State<PresentationScreen> createState() => _PresentationScreenState();
}

class _PresentationScreenState extends State<PresentationScreen> {
  PresentationResult? _result;
  String? _patientName;
  String? _room;
  String? _error;
  bool _loading = false;
  bool _reviewing = false;
  late String _idempotencyKey = IdempotencyKey.create();

  RoundRepository get _rounds {
    if (widget.roundRepository != null) return widget.roundRepository!;
    try {
      return InjectionContainer.instance.roundRepository;
    } catch (_) {
      return DemoRoundRepository();
    }
  }

  AiRepository get _ai {
    if (widget.aiRepository != null) return widget.aiRepository!;
    try {
      return InjectionContainer.instance.aiRepository;
    } catch (_) {
      return DemoAiRepository();
    }
  }

  PatientRepository get _patients {
    if (widget.patientRepository != null) return widget.patientRepository!;
    try {
      return InjectionContainer.instance.patientRepository;
    } catch (_) {
      return DemoPatientRepository(DemoCensusRepository());
    }
  }

  @override
  void initState() {
    super.initState();
    final CensusPatient? demo = patientById(widget.patientId);
    if (demo != null) {
      _patientName = demo.name;
      _room = demo.room;
    }
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    final Result<PatientDetail> detail = await _patients.loadDetail(
      widget.patientId,
    );
    if (detail case Ok<PatientDetail>(:final PatientDetail value)) {
      if (mounted) {
        setState(() {
          _patientName = value.patient.displayName;
          _room = value.patient.room;
        });
      }
    }
    await _generate();
  }

  Future<void> _generate() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final Result<PresentationResult> result = await _rounds.present(
      widget.patientId,
      idempotencyKey: _idempotencyKey,
    );
    if (!mounted) return;
    setState(() => _loading = false);
    switch (result) {
      case Ok<PresentationResult>(:final PresentationResult value):
        setState(() => _result = value);
      case Err<PresentationResult>(:final Failure failure):
        setState(() {
          _error = failure is ApiFailure
              ? failure.error.userMessage
              : failure.message;
        });
    }
  }

  Future<void> _regenerate() async {
    _idempotencyKey = IdempotencyKey.create();
    await _generate();
  }

  Future<void> _markReviewed() async {
    final PresentationResult? current = _result;
    if (current == null || current.isReviewed) return;
    setState(() => _reviewing = true);
    final Result<AiEnvelope> result = await _ai.markReviewed(current.artifactId);
    if (!mounted) return;
    setState(() => _reviewing = false);
    switch (result) {
      case Ok<AiEnvelope>(:final AiEnvelope value):
        setState(() {
          _result = PresentationResult(
            envelope: value,
            draft: PresentationDraft.fromContent(
              value.content.isEmpty ? current.draft._asMap() : value.content,
            ),
          );
        });
      case Err<AiEnvelope>(:final Failure failure):
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(failure.message)));
    }
  }

  Future<void> _copy() async {
    final String text = _result?.draft.spokenText ?? '';
    if (text.isEmpty) return;
    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Copied presentation text.')));
  }

  void _openClaim(Claim claim) {
    if (claim.factIds.isEmpty) return;
    showSourceDrawer(context, claim: claim, repository: _ai);
  }

  @override
  Widget build(BuildContext context) {
    final AppColors colors = AppColors.of(context);
    final PresentationResult? result = _result;
    final PresentationDraft? draft = result?.draft;
    final String status = result == null
        ? (_loading ? 'Generating…' : 'Not generated')
        : result.isReviewed
        ? 'Reviewed'
        : 'Draft · requires review';

    return WorkflowPage(
      title: 'Presentation',
      status: status,
      children: <Widget>[
        Text(
          _patientName == null
              ? 'Patient'
              : _room == null || _room!.isEmpty
              ? _patientName!
              : '$_patientName · Room $_room',
          style: AppTypography.bold(fontSize: 22, color: colors.navy),
        ),
        const SizedBox(height: 6),
        Text(
          'About 60–90 seconds. Target $presentationWordMin–$presentationWordMax words.',
          style: AppTypography.regular(color: colors.textSecondary),
        ),
        const SizedBox(height: 16),
        if (_loading)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Center(child: CircularProgressIndicator()),
          ),
        if (_error != null) ...<Widget>[
          Text(
            _error!,
            style: AppTypography.regular(color: colors.critical),
          ),
          const SizedBox(height: 12),
          AppButton(
            label: 'Try again',
            onPressed: _regenerate,
            expand: false,
          ),
        ],
        if (draft != null) ...<Widget>[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: result!.isReviewed
                  ? colors.success.withValues(alpha: 0.12)
                  : colors.aiCard,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: result.isReviewed ? colors.success : colors.aiBorder,
              ),
            ),
            child: Text(
              result.isReviewed ? 'Reviewed' : draft.label,
              style: AppTypography.semiBold(
                fontSize: 12,
                color: result.isReviewed ? colors.success : colors.aiAccent,
              ),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            draft.wordCountLabel,
            style: AppTypography.semiBold(
              fontSize: 13,
              color: draft.inBudget ? colors.textSecondary : colors.warning,
            ),
          ),
          if (draft.estimatedSeconds > 0) ...<Widget>[
            const SizedBox(height: 2),
            Text(
              '~${draft.estimatedSeconds}s · ${draft.targetDuration}',
              style: AppTypography.regular(
                fontSize: 12,
                color: colors.textMuted,
              ),
            ),
          ],
          const SizedBox(height: 14),
          Text(
            'Oral draft',
            style: AppTypography.semiBold(
              fontSize: 15,
              color: colors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          ...draft.allSentences.map(
            (Claim c) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: InkWell(
                onTap: c.factIds.isEmpty ? null : () => _openClaim(c),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: colors.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: colors.border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        c.text,
                        style: AppTypography.regular(
                          fontSize: 14,
                          height: 1.45,
                          color: colors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 6,
                        children: <Widget>[
                          _Chip(label: c.labelText),
                          if (c.factIds.isNotEmpty)
                            _Chip(
                              label: c.factIds.length == 1
                                  ? '1 source'
                                  : '${c.factIds.length} sources',
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          if (draft.spokenText.trim().isEmpty ||
              draft.sentences.isEmpty) ...<Widget>[
            const SizedBox(height: 8),
            Text(
              "Confirm facts and save Today's plan, then regenerate. "
              'A short or empty presentation usually means the chart is incomplete.',
              style: AppTypography.regular(
                fontSize: 13,
                height: 1.4,
                color: colors.warning,
              ),
            ),
          ],
          if (draft.missingInformation.isNotEmpty) ...<Widget>[
            const SizedBox(height: 8),
            Text(
              'Missing',
              style: AppTypography.semiBold(
                fontSize: 15,
                color: colors.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            ...draft.missingInformation.map(
              (String m) => Text(
                '• ${humanizeMissingToken(m)}',
                style: AppTypography.regular(color: colors.textSecondary),
              ),
            ),
          ],
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              AppButton(
                label: 'Regenerate',
                variant: AppButtonVariant.outline,
                expand: false,
                onPressed: _loading ? null : _regenerate,
              ),
              if (!result.isReviewed)
                AppButton(
                  label: _reviewing ? 'Saving…' : 'Mark reviewed',
                  expand: false,
                  onPressed: _reviewing || _loading ? null : _markReviewed,
                ),
              AppButton(
                label: 'Copy',
                variant: AppButtonVariant.outline,
                expand: false,
                onPressed: draft.spokenText.isEmpty ? null : _copy,
              ),
            ],
          ),
        ],
      ],
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final AppColors colors = AppColors.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: colors.chipIdle,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: AppTypography.semiBold(fontSize: 11, color: colors.textSecondary),
      ),
    );
  }
}

extension on PresentationDraft {
  Map<String, dynamic> _asMap() => <String, dynamic>{
    'sentences': sentences
        .map(
          (Claim c) => <String, dynamic>{
            'text': c.text,
            'label': c.labelText,
            'fact_ids': c.factIds,
          },
        )
        .toList(),
    'plan_sentences': planSentences
        .map(
          (Claim c) => <String, dynamic>{
            'text': c.text,
            'source': 'clinician_plan',
          },
        )
        .toList(),
    'spoken_text': spokenText,
    'word_count': wordCount,
    'word_budget': <String, int>{'min': wordBudgetMin, 'max': wordBudgetMax},
    'estimated_seconds': estimatedSeconds,
    'target_duration': targetDuration,
    'flags': flags,
    'missing_information': missingInformation,
    'label': label,
  };
}
