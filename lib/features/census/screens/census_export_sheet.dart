import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:round_ai/core/di/injection_container.dart';
import 'package:round_ai/core/errors/failures.dart';
import 'package:round_ai/core/errors/result.dart';
import 'package:round_ai/core/theme/app_colors.dart';
import 'package:round_ai/core/theme/app_typography.dart';
import 'package:round_ai/features/census/models/census_intake.dart';
import 'package:round_ai/features/census/repository/census_repository.dart';
import 'package:share_plus/share_plus.dart';

/// Loads `GET /census/export`, shows preview, then copy or share with a warning.
Future<void> showCensusExportSheet(
  BuildContext context, {
  CensusRepository? repository,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (BuildContext sheet) {
      return _CensusExportBody(
        repository:
            repository ?? InjectionContainer.instance.censusRepository,
      );
    },
  );
}

class _CensusExportBody extends StatefulWidget {
  const _CensusExportBody({required this.repository});

  final CensusRepository repository;

  @override
  State<_CensusExportBody> createState() => _CensusExportBodyState();
}

class _CensusExportBodyState extends State<_CensusExportBody> {
  bool _loading = true;
  String? _error;
  CensusExport? _export;
  bool _ack = false;

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
    final Result<CensusExport> result = await widget.repository.exportCensus();
    if (!mounted) return;
    switch (result) {
      case Err(:final failure):
        setState(() {
          _loading = false;
          _error = failure.apiError.userMessage;
        });
      case Ok(:final value):
        setState(() {
          _loading = false;
          _export = value;
        });
    }
  }

  Future<void> _copy() async {
    final String text = _export?.text ?? '';
    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Census copied.')));
  }

  Future<void> _share() async {
    final String text = _export?.text ?? '';
    await SharePlus.instance.share(ShareParams(text: text, subject: 'Census'));
  }

  @override
  Widget build(BuildContext context) {
    final AppColors colors = AppColors.of(context);
    final CensusExport? exp = _export;
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
            Text('Export census', style: AppTypography.semiBold(fontSize: 18)),
            const SizedBox(height: 8),
            Text(
              'Ordering is clinician sort order, then room — never AI urgency.',
              style: AppTypography.regular(
                fontSize: 12,
                height: 1.4,
                color: colors.textSecondary,
              ),
            ),
            const SizedBox(height: 12),
            if (_loading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_error != null)
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Text(
                    _error!,
                    style: AppTypography.regular(
                      fontSize: 13,
                      color: colors.error,
                    ),
                  ),
                  TextButton(onPressed: _load, child: const Text('Retry')),
                ],
              )
            else ...<Widget>[
              if (exp?.note.isNotEmpty ?? false)
                Text(
                  exp!.note,
                  style: AppTypography.regular(
                    fontSize: 12,
                    color: colors.textMuted,
                  ),
                ),
              const SizedBox(height: 8),
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 280),
                child: SingleChildScrollView(
                  child: SelectableText(
                    exp?.text.isEmpty ?? true
                        ? 'No patients to export.'
                        : exp!.text,
                    style: AppTypography.regular(fontSize: 13, height: 1.45),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                value: _ack,
                onChanged: (bool? v) => setState(() => _ack = v ?? false),
                title: Text(
                  'I understand this list may leave the device if I share it.',
                  style: AppTypography.regular(fontSize: 13, height: 1.35),
                ),
                controlAffinity: ListTileControlAffinity.leading,
              ),
              const SizedBox(height: 8),
              Row(
                children: <Widget>[
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _ack ? _copy : null,
                      child: const Text('Copy'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton(
                      onPressed: _ack ? _share : null,
                      child: const Text('Share'),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
