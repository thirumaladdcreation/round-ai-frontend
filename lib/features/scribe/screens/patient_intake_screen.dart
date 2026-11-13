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
import 'package:round_ai/features/patient/widgets/chart_entry_scaffold.dart';
import 'package:round_ai/features/scribe/models/intake_result.dart';
import 'package:round_ai/features/scribe/repository/intake_repository.dart';
import 'package:round_ai/shared/widgets/app_button.dart';

enum IntakeMode { dictate, photo }

/// Add info via dictate or photo. Creates a chart source + pending facts.
class PatientIntakeScreen extends StatefulWidget {
  const PatientIntakeScreen({
    required this.patientId,
    required this.mode,
    this.repository,
    this.capture,
    super.key,
  });

  final String patientId;
  final IntakeMode mode;
  final IntakeRepository? repository;
  final MediaCapture? capture;

  @override
  State<PatientIntakeScreen> createState() => _PatientIntakeScreenState();
}

class _PatientIntakeScreenState extends State<PatientIntakeScreen> {
  late final IntakeRepository _repo =
      widget.repository ?? InjectionContainer.instance.intakeRepository;
  late final MediaCapture _capture = widget.capture ?? MediaCapture();

  bool _recording = false;
  bool _busy = false;
  String? _error;
  IntakeResult? _done;

  @override
  void dispose() {
    if (_recording) {
      _capture.cancelRecording();
    }
    _capture.dispose();
    super.dispose();
  }

  Future<void> _startDictate() async {
    setState(() {
      _error = null;
      _done = null;
    });
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
      _done = null;
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
    final result = await _repo.intake(
      widget.patientId,
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
        setState(() {
          _busy = false;
          _done = value;
        });
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppColors colors = AppColors.of(context);
    final bool dictate = widget.mode == IntakeMode.dictate;
    final IntakeResult? done = _done;

    return ChartEntryScaffold(
      title: dictate ? 'Dictate' : 'Photo',
      bottom: done == null
          ? null
          : AppButton(
              label: done.pendingFactCount == 0
                  ? 'Done'
                  : 'Review ${done.pendingFactCount} pending fact'
                        '${done.pendingFactCount == 1 ? '' : 's'}',
              onPressed: () {
                if (done.pendingFactCount == 0) {
                  context.pop();
                } else {
                  context.pop(AppRoutes.patientFactsPath(widget.patientId));
                }
              },
            ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(
            dictate
                ? 'Record what you know. This becomes a chart source; '
                      'facts stay pending until you confirm them.'
                : 'Photograph a chart page or list. Text is extracted into a '
                      'source; facts stay pending until you confirm them.',
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
          if (done != null) ...<Widget>[
            Text(
              'Saved as a source.',
              style: AppTypography.semiBold(
                fontSize: 14,
                color: colors.textPrimary,
              ),
            ),
            if (done.text.trim().isNotEmpty) ...<Widget>[
              const SizedBox(height: 12),
              Text(
                dictate ? 'What you said' : 'Extracted text',
                style: AppTypography.medium(
                  fontSize: 12,
                  color: colors.textMuted,
                ),
              ),
              const SizedBox(height: 6),
              SelectableText(
                done.text.trim(),
                style: AppTypography.regular(
                  fontSize: 14,
                  height: 1.45,
                  color: colors.textPrimary,
                ),
              ),
            ],
            const SizedBox(height: 12),
            Text(
              done.pendingFactCount == 0
                  ? 'No pending facts were extracted. You can still use this '
                        'dictation when writing a note.'
                  : '${done.pendingFactCount} fact'
                        '${done.pendingFactCount == 1 ? '' : 's'} waiting for review.',
              style: AppTypography.regular(
                fontSize: 13,
                height: 1.4,
                color: colors.textSecondary,
              ),
            ),
            if (done.lowLegibilityLines.isNotEmpty) ...<Widget>[
              const SizedBox(height: 12),
              Text(
                'Some lines were hard to read. Check them in fact review.',
                style: AppTypography.regular(
                  fontSize: 12,
                  color: colors.warning,
                ),
              ),
            ],
          ] else if (dictate) ...<Widget>[
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
                    child: const Text('Stop & save'),
                  ),
                ],
              )
            else
              AppButton(
                label: 'Start recording',
                loading: _busy,
                onPressed: _busy ? null : _startDictate,
              ),
          ] else ...<Widget>[
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
