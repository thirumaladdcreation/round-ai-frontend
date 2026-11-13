import 'package:flutter/material.dart';
import 'package:round_ai/core/di/injection_container.dart';
import 'package:round_ai/core/errors/failures.dart';
import 'package:round_ai/core/errors/result.dart';
import 'package:round_ai/core/network/idempotency_key.dart';
import 'package:round_ai/core/theme/app_colors.dart';
import 'package:round_ai/core/theme/app_typography.dart';
import 'package:round_ai/features/rounds/models/prepare_result.dart';
import 'package:round_ai/features/rounds/models/round_brief.dart';
import 'package:round_ai/features/rounds/repository/round_repository.dart';
import 'package:round_ai/shared/widgets/app_button.dart';

Future<void> showPreparePresentationsSheet({
  required BuildContext context,
  required List<RoundPatientCard> patients,
  RoundRepository? repository,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (BuildContext ctx) => PreparePresentationsSheet(
      patients: patients,
      repository: repository,
    ),
  );
}

class PreparePresentationsSheet extends StatefulWidget {
  const PreparePresentationsSheet({
    required this.patients,
    this.repository,
    super.key,
  });

  final List<RoundPatientCard> patients;
  final RoundRepository? repository;

  @override
  State<PreparePresentationsSheet> createState() =>
      _PreparePresentationsSheetState();
}

class _PreparePresentationsSheetState extends State<PreparePresentationsSheet> {
  late final Set<String> _selected = widget.patients
      .map((RoundPatientCard p) => p.patientId)
      .toSet();
  bool _running = false;
  PreparePresentationsResult? _result;
  String? _error;
  late final String _idempotencyKey = IdempotencyKey.create();

  RoundRepository get _repo =>
      widget.repository ?? InjectionContainer.instance.roundRepository;

  String _name(String id) {
    for (final RoundPatientCard p in widget.patients) {
      if (p.patientId == id) return p.displayName;
    }
    return id;
  }

  Future<void> _run() async {
    if (_selected.isEmpty || _running) return;
    setState(() {
      _running = true;
      _error = null;
      _result = null;
    });
    final Result<PreparePresentationsResult> result = await _repo
        .preparePresentations(
          patientIds: _selected.toList(),
          idempotencyKey: _idempotencyKey,
        );
    if (!mounted) return;
    setState(() => _running = false);
    switch (result) {
      case Ok<PreparePresentationsResult>(:final PreparePresentationsResult value):
        setState(() => _result = value);
      case Err<PreparePresentationsResult>(:final Failure failure):
        setState(() => _error = failure.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppColors colors = AppColors.of(context);
    final MediaQueryData mq = MediaQuery.of(context);
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: mq.viewInsets.bottom + 24,
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(
              'Prepare presentations',
              style: AppTypography.bold(fontSize: 20, color: colors.textPrimary),
            ),
            const SizedBox(height: 4),
            Text(
              'Drafts stay AI-generated until you review them. Failures are listed.',
              style: AppTypography.regular(
                fontSize: 13,
                color: colors.textSecondary,
              ),
            ),
            const SizedBox(height: 12),
            ...widget.patients.map((RoundPatientCard p) {
              final bool on = _selected.contains(p.patientId);
              return CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                value: on,
                title: Text(p.displayName),
                subtitle: Text(p.metaLine),
                onChanged: _running
                    ? null
                    : (bool? v) {
                        setState(() {
                          if (v ?? false) {
                            _selected.add(p.patientId);
                          } else {
                            _selected.remove(p.patientId);
                          }
                        });
                      },
              );
            }),
            const SizedBox(height: 8),
            AppButton(
              label: _running ? 'Preparing…' : 'Prepare selected',
              onPressed: _running || _selected.isEmpty ? null : _run,
            ),
            if (_error != null) ...<Widget>[
              const SizedBox(height: 12),
              Text(
                _error!,
                style: AppTypography.regular(color: colors.critical),
              ),
            ],
            if (_result != null) ...<Widget>[
              const SizedBox(height: 16),
              Text(
                'Generated ${_result!.generated} of ${_result!.requested}'
                '${_result!.failed > 0 ? ' · ${_result!.failed} failed' : ''}',
                style: AppTypography.semiBold(
                  fontSize: 14,
                  color: colors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              ..._result!.results.map((PreparePatientResult r) {
                final String name = _name(r.patientId);
                if (r.ok) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Text(
                      '✓ $name · ${r.wordCount ?? '—'} words · requires review',
                      style: AppTypography.regular(
                        fontSize: 13,
                        color: colors.textPrimary,
                      ),
                    ),
                  );
                }
                return Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text(
                    '✗ $name · ${r.failureReason}',
                    style: AppTypography.regular(
                      fontSize: 13,
                      color: colors.critical,
                    ),
                  ),
                );
              }),
            ],
          ],
        ),
      ),
    );
  }
}
