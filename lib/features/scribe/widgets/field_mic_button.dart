import 'package:flutter/material.dart';
import 'package:round_ai/core/di/injection_container.dart';
import 'package:round_ai/core/errors/failures.dart';
import 'package:round_ai/core/errors/result.dart';
import 'package:round_ai/core/media/media_capture.dart';
import 'package:round_ai/core/media/temp_media.dart';
import 'package:round_ai/core/network/api_error.dart';
import 'package:round_ai/core/network/idempotency_key.dart';
import 'package:round_ai/core/theme/app_colors.dart';
import 'package:round_ai/features/scribe/models/intake_result.dart';
import 'package:round_ai/features/scribe/repository/intake_repository.dart';

/// Mic control that posts audio to `/transcribe` and inserts text into [controller].
class FieldMicButton extends StatefulWidget {
  const FieldMicButton({
    required this.controller,
    this.enabled = true,
    this.repository,
    this.capture,
    super.key,
  });

  final TextEditingController controller;
  final bool enabled;
  final IntakeRepository? repository;
  final MediaCapture? capture;

  @override
  State<FieldMicButton> createState() => _FieldMicButtonState();
}

class _FieldMicButtonState extends State<FieldMicButton> {
  late final IntakeRepository _repo =
      widget.repository ?? InjectionContainer.instance.intakeRepository;
  late final MediaCapture _capture = widget.capture ?? MediaCapture();

  bool _recording = false;
  bool _busy = false;

  @override
  void dispose() {
    if (_recording) {
      _capture.cancelRecording();
    }
    // Only dispose capture we created.
    if (widget.capture == null) {
      _capture.dispose();
    }
    super.dispose();
  }

  Future<void> _toggle() async {
    if (!widget.enabled || _busy) return;
    final AppColors colors = AppColors.of(context);
    if (_recording) {
      setState(() {
        _recording = false;
        _busy = true;
      });
      try {
        final TempMedia? media = await _capture.stopRecording();
        if (media == null) {
          if (mounted) setState(() => _busy = false);
          return;
        }
        final Result<TranscribeResult> result = await _repo.transcribe(
          media: media,
          idempotencyKey: IdempotencyKey.create(),
        );
        if (!mounted) return;
        setState(() => _busy = false);
        switch (result) {
          case Err(:final failure):
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(failure.apiError.userMessage)),
            );
          case Ok(:final value):
            final String text = value.text.trim();
            if (text.isEmpty) return;
            final TextEditingController c = widget.controller;
            final String existing = c.text.trim();
            c.text = existing.isEmpty ? text : '$existing\n$text';
            c.selection = TextSelection.collapsed(offset: c.text.length);
        }
      } on MediaCaptureException catch (e) {
        if (!mounted) return;
        setState(() => _busy = false);
        if (e.error.kind != ApiErrorKind.cancelled) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(e.error.userMessage)));
        }
      }
      return;
    }

    try {
      await _capture.startRecording();
      if (!mounted) return;
      setState(() => _recording = true);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Recording… tap mic again to stop. $mediaPrivacyHint',
            style: TextStyle(color: colors.surface),
          ),
          duration: const Duration(seconds: 3),
        ),
      );
    } on MediaCaptureException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.error.userMessage)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppColors colors = AppColors.of(context);
    final IconData icon = _busy
        ? Icons.hourglass_top
        : _recording
        ? Icons.stop_circle_outlined
        : Icons.mic_none_outlined;
    return IconButton(
      tooltip: _recording ? 'Stop and insert' : 'Dictate into field',
      onPressed: widget.enabled && !_busy ? _toggle : null,
      icon: Icon(
        icon,
        color: _recording ? colors.error : colors.primary,
      ),
    );
  }
}
