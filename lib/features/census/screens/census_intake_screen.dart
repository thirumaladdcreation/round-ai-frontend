import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:round_ai/core/di/injection_container.dart';
import 'package:round_ai/core/errors/failures.dart';
import 'package:round_ai/core/errors/result.dart';
import 'package:round_ai/core/media/media_capture.dart';
import 'package:round_ai/core/media/temp_media.dart';
import 'package:round_ai/core/network/api_error.dart';
import 'package:round_ai/core/network/idempotency_key.dart';
import 'package:round_ai/core/router/app_routes.dart';
import 'package:round_ai/core/theme/app_colors.dart';
import 'package:round_ai/core/theme/app_typography.dart';
import 'package:round_ai/features/census/models/census_intake.dart';
import 'package:round_ai/features/census/repository/census_repository.dart';
import 'package:round_ai/features/patient/widgets/chart_entry_scaffold.dart';
import 'package:round_ai/shared/widgets/app_button.dart';

enum CensusIntakeMode { dictate, photo }

/// Capture a census list by voice or photo. Nothing is created until confirm.
class CensusIntakeScreen extends StatefulWidget {
  const CensusIntakeScreen({
    required this.mode,
    this.repository,
    this.capture,
    super.key,
  });

  final CensusIntakeMode mode;
  final CensusRepository? repository;
  final MediaCapture? capture;

  @override
  State<CensusIntakeScreen> createState() => _CensusIntakeScreenState();
}

class _CensusIntakeScreenState extends State<CensusIntakeScreen> {
  late final CensusRepository _repo =
      widget.repository ?? InjectionContainer.instance.censusRepository;
  late final MediaCapture _capture = widget.capture ?? MediaCapture();

  bool _recording = false;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    if (_recording) {
      _capture.cancelRecording();
    }
    if (widget.capture == null) {
      _capture.dispose();
    }
    super.dispose();
  }

  Future<void> _startDictate() async {
    setState(() => _error = null);
    try {
      await _capture.startRecording();
      if (!mounted) return;
      setState(() => _recording = true);
    } on MediaCaptureException catch (e) {
      if (!mounted) return;
      setState(() => _error = e.error.userMessage);
    }
  }

  Future<void> _stopAndUpload() async {
    if (!_recording) return;
    setState(() {
      _recording = false;
      _busy = true;
      _error = null;
    });
    try {
      final TempMedia? media = await _capture.stopRecording();
      if (media == null) {
        if (!mounted) return;
        setState(() {
          _busy = false;
          _error = 'Nothing was recorded.';
        });
        return;
      }
      await _upload(media);
    } on MediaCaptureException catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = e.error.userMessage;
      });
    }
  }

  Future<void> _cancelDictate() async {
    await _capture.cancelRecording();
    if (!mounted) return;
    setState(() => _recording = false);
  }

  Future<void> _pickPhoto(ImageSource source) async {
    setState(() {
      _error = null;
      _busy = true;
    });
    try {
      final TempMedia media = await _capture.pickImage(source: source);
      await _upload(media);
    } on MediaCaptureException catch (e) {
      if (!mounted) return;
      if (e.error.kind == ApiErrorKind.cancelled) {
        setState(() => _busy = false);
        return;
      }
      setState(() {
        _busy = false;
        _error = e.error.userMessage;
      });
    }
  }

  Future<void> _upload(TempMedia media) async {
    final Result<CensusIntakeProposal> result = await _repo.intakeCensus(
      media: media,
      idempotencyKey: IdempotencyKey.create(),
    );
    if (!mounted) return;
    switch (result) {
      case Err(:final failure):
        setState(() {
          _busy = false;
          _error = failure.apiError.userMessage;
        });
      case Ok(:final value):
        setState(() => _busy = false);
        final Object? next = await context.push<Object>(
          AppRoutes.censusProposePath(value.id),
          extra: value,
        );
        if (mounted) context.pop(next ?? true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppColors colors = AppColors.of(context);
    final bool dictate = widget.mode == CensusIntakeMode.dictate;

    return ChartEntryScaffold(
      title: dictate ? 'Dictate census' : 'Scan census',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(
            'Proposed patients only. Nothing is added to the census until you '
            'confirm each row.',
            style: AppTypography.regular(
              fontSize: 13,
              height: 1.4,
              color: colors.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            mediaPrivacyHint,
            style: AppTypography.regular(
              fontSize: 12,
              height: 1.35,
              color: colors.textMuted,
            ),
          ),
          if (dictate) ...<Widget>[
            const SizedBox(height: 6),
            Text(
              recordingPolicyHint,
              style: AppTypography.regular(
                fontSize: 12,
                height: 1.35,
                color: colors.textMuted,
              ),
            ),
          ],
          const SizedBox(height: 24),
          if (dictate)
            if (_recording)
              Row(
                children: <Widget>[
                  const Icon(Icons.mic, color: Colors.red),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Recording…',
                      style: AppTypography.medium(fontSize: 14),
                    ),
                  ),
                  TextButton(
                    onPressed: _busy ? null : _cancelDictate,
                    child: const Text('Cancel'),
                  ),
                  FilledButton(
                    onPressed: _busy ? null : _stopAndUpload,
                    child: const Text('Stop & review'),
                  ),
                ],
              )
            else
              AppButton(
                label: 'Start recording',
                loading: _busy,
                onPressed: _busy ? null : _startDictate,
              )
          else ...<Widget>[
            AppButton(
              label: 'Take photo',
              loading: _busy,
              onPressed: _busy ? null : () => _pickPhoto(ImageSource.camera),
            ),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: _busy ? null : () => _pickPhoto(ImageSource.gallery),
              child: const Text('Choose from gallery'),
            ),
          ],
          if (_error != null) ...<Widget>[
            const SizedBox(height: 16),
            Text(
              _error!,
              style: AppTypography.regular(fontSize: 13, color: colors.error),
            ),
          ],
        ],
      ),
    );
  }
}
