import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:round_ai/core/errors/failures.dart';
import 'package:round_ai/core/errors/result.dart';
import 'package:round_ai/core/network/api_error.dart';
import 'package:round_ai/core/network/idempotency_key.dart';
import 'package:round_ai/core/router/app_routes.dart';
import 'package:round_ai/core/theme/app_colors.dart';
import 'package:round_ai/core/theme/app_typography.dart';
import 'package:round_ai/features/ai/models/ai_envelope.dart';
import 'package:round_ai/features/ai/repository/ai_repository.dart';
import 'package:round_ai/features/ai/widgets/source_drawer.dart';
import 'package:round_ai/features/patient/models/problem.dart';
import 'package:round_ai/features/problems/models/coding_suggestion.dart';
import 'package:round_ai/features/problems/repository/problems_repository.dart';

/// Opens ICD suggestions for one confirmed/differential problem.
Future<AcceptedCodeSuggestion?> showCodingSuggestSheet(
  BuildContext context, {
  required String patientId,
  required Problem problem,
  required ProblemsRepository repository,
  required AiRepository aiRepository,
}) {
  return showModalBottomSheet<AcceptedCodeSuggestion>(
    context: context,
    isScrollControlled: true,
    builder: (BuildContext sheet) {
      return _CodingSuggestBody(
        patientId: patientId,
        problem: problem,
        repository: repository,
        aiRepository: aiRepository,
      );
    },
  );
}

class _CodingSuggestBody extends StatefulWidget {
  const _CodingSuggestBody({
    required this.patientId,
    required this.problem,
    required this.repository,
    required this.aiRepository,
  });

  final String patientId;
  final Problem problem;
  final ProblemsRepository repository;
  final AiRepository aiRepository;

  @override
  State<_CodingSuggestBody> createState() => _CodingSuggestBodyState();
}

class _CodingSuggestBodyState extends State<_CodingSuggestBody> {
  bool _loading = true;
  bool _accepting = false;
  String? _acceptingCode;
  ApiError? _error;
  CodingSuggestResult? _result;
  String? _key;
  CancelToken? _cancel;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _cancel?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    _key ??= IdempotencyKey.create();
    final CancelToken token = _cancel = CancelToken();
    setState(() {
      _loading = true;
      _error = null;
    });
    final Result<CodingSuggestResult> result = await widget.repository
        .suggestCoding(
          widget.patientId,
          problemId: widget.problem.id,
          idempotencyKey: _key!,
          cancelToken: token,
        );
    if (!mounted) return;
    switch (result) {
      case Err(:final failure):
        final ApiError error = failure.apiError;
        if (error.kind == ApiErrorKind.cancelled) {
          setState(() => _loading = false);
          return;
        }
        if (!error.isRetryable) _key = null;
        setState(() {
          _loading = false;
          _error = error;
        });
      case Ok(:final value):
        _key = null;
        setState(() {
          _loading = false;
          _result = value;
        });
    }
  }

  Future<void> _accept(IcdCodeSuggestion suggestion) async {
    if (_accepting) return;
    setState(() {
      _accepting = true;
      _acceptingCode = suggestion.code;
      _error = null;
    });
    final Result<AcceptedCodeSuggestion> result = await widget.repository
        .acceptCoding(
          widget.patientId,
          widget.problem.id,
          code: suggestion.code,
          artifactId: _result?.artifactId,
        );
    if (!mounted) return;
    switch (result) {
      case Err(:final failure):
        setState(() {
          _accepting = false;
          _acceptingCode = null;
          _error = failure.apiError;
        });
      case Ok(:final value):
        Navigator.pop(context, value);
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppColors colors = AppColors.of(context);
    final CodingProblemBlock? block = _result?.blockFor(widget.problem.id);
    final String label = block?.label ?? _result?.label ?? codingReviewLabel;

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          16,
          20,
          16 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(
              'Suggest codes',
              style: AppTypography.semiBold(fontSize: 18),
            ),
            const SizedBox(height: 4),
            Text(
              widget.problem.label,
              style: AppTypography.regular(
                fontSize: 13,
                color: colors.textSecondary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: AppTypography.medium(
                fontSize: 12,
                color: colors.aiAccent,
              ),
            ),
            const SizedBox(height: 12),
            if (_loading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 32),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_error != null && _result == null)
              _ErrorBox(
                error: _error!,
                patientId: widget.patientId,
                onRetry: _error!.isRetryable ? _load : null,
              )
            else if (block == null)
              Text(
                'No coding result came back.',
                style: AppTypography.regular(color: colors.textSecondary),
              )
            else ...<Widget>[
              if (block.uncertain ||
                  (block.suggestions.any(
                    (IcdCodeSuggestion s) => s.uncertainNotConfirmed,
                  )))
                _Banner(
                  color: colors.warningSoft,
                  textColor: colors.warning,
                  text:
                      'Uncertain / not confirmed. Do not treat these as a '
                      'final billing code.',
                ),
              for (final String note in block.reviewerNotes)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    note,
                    style: AppTypography.regular(
                      fontSize: 12,
                      height: 1.4,
                      color: colors.textSecondary,
                    ),
                  ),
                ),
              if (block.hasNoCandidates)
                Text(
                  'No codes in the local ICD-10-CM table matched this problem.',
                  style: AppTypography.regular(
                    fontSize: 13,
                    color: colors.textSecondary,
                  ),
                )
              else if (block.suggestions.isEmpty)
                Text(
                  'Candidates were found, but none passed validation.',
                  style: AppTypography.regular(
                    fontSize: 13,
                    color: colors.textSecondary,
                  ),
                )
              else
                ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.sizeOf(context).height * 0.45,
                  ),
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: block.suggestions.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (BuildContext context, int i) {
                      final IcdCodeSuggestion s = block.suggestions[i];
                      final bool busy =
                          _accepting && _acceptingCode == s.code;
                      return _SuggestionTile(
                        suggestion: s,
                        accepting: busy,
                        locked: _accepting,
                        aiRepository: widget.aiRepository,
                        onAccept: () => _accept(s),
                      );
                    },
                  ),
                ),
              if (_error != null) ...<Widget>[
                const SizedBox(height: 8),
                Text(
                  _error!.userMessage,
                  style: AppTypography.regular(
                    fontSize: 13,
                    color: colors.error,
                  ),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }
}

class _SuggestionTile extends StatelessWidget {
  const _SuggestionTile({
    required this.suggestion,
    required this.accepting,
    required this.locked,
    required this.aiRepository,
    required this.onAccept,
  });

  final IcdCodeSuggestion suggestion;
  final bool accepting;
  final bool locked;
  final AiRepository aiRepository;
  final VoidCallback onAccept;

  @override
  Widget build(BuildContext context) {
    final AppColors colors = AppColors.of(context);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            suggestion.code,
            style: AppTypography.semiBold(fontSize: 15),
          ),
          const SizedBox(height: 2),
          Text(
            suggestion.description,
            style: AppTypography.regular(fontSize: 13, height: 1.35),
          ),
          if (suggestion.uncertainNotConfirmed)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                'uncertain_not_confirmed',
                style: AppTypography.medium(
                  fontSize: 11,
                  color: colors.warning,
                ),
              ),
            ),
          if (suggestion.rationale.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                suggestion.rationale,
                style: AppTypography.regular(
                  fontSize: 12,
                  height: 1.35,
                  color: colors.textSecondary,
                ),
              ),
            ),
          if (suggestion.missingForSpecificity.isNotEmpty) ...<Widget>[
            const SizedBox(height: 6),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              decoration: BoxDecoration(
                color: colors.criticalBg,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    'Needs more detail',
                    style: AppTypography.semiBold(
                      fontSize: 12,
                      color: colors.critical,
                    ),
                  ),
                  for (final String m in suggestion.missingForSpecificity)
                    Text(
                      '· $m',
                      style: AppTypography.regular(
                        fontSize: 12,
                        color: colors.textSecondary,
                      ),
                    ),
                ],
              ),
            ),
          ],
          if (suggestion.factIds.isNotEmpty)
            Wrap(
              spacing: 6,
              children: <Widget>[
                for (final String id in suggestion.factIds)
                  ActionChip(
                    label: const Text('View chart source'),
                    onPressed: () => showSourceDrawer(
                      context,
                      claim: Claim(
                        text: suggestion.description,
                        label: ClaimLabel.fromChart,
                        factIds: <String>[id],
                      ),
                      repository: aiRepository,
                    ),
                  ),
              ],
            ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: accepting
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : FilledButton(
                    onPressed: locked ? null : onAccept,
                    child: const Text('Accept'),
                  ),
          ),
        ],
      ),
    );
  }
}

class _Banner extends StatelessWidget {
  const _Banner({
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

class _ErrorBox extends StatelessWidget {
  const _ErrorBox({
    required this.error,
    required this.patientId,
    this.onRetry,
  });

  final ApiError error;
  final String patientId;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final AppColors colors = AppColors.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Text(
          error.userMessage,
          style: AppTypography.regular(fontSize: 13, color: colors.error),
        ),
        if (error.kind == ApiErrorKind.noReviewedFacts)
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              context.push(AppRoutes.patientFactsPath(patientId));
            },
            child: const Text('Review chart facts first'),
          ),
        if (onRetry != null)
          TextButton(onPressed: onRetry, child: const Text('Retry')),
      ],
    );
  }
}
