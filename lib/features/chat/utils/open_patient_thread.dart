import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:round_ai/core/di/injection_container.dart';
import 'package:round_ai/core/errors/failures.dart';
import 'package:round_ai/core/errors/result.dart';
import 'package:round_ai/core/router/app_routes.dart';
import 'package:round_ai/features/chat/models/chat_channel.dart';
import 'package:round_ai/features/chat/models/chat_nav_extra.dart';
import 'package:round_ai/features/chat/repository/chat_repository.dart';

/// Opens (or resolves) the team chat channel for a patient. Labels stay in
/// [ChatChannelExtra], not the URL.
Future<void> openPatientTeamThread(
  BuildContext context, {
  required String patientId,
  required String patientLabel,
  ChatRepository? chatRepository,
}) async {
  final ChatRepository chat =
      chatRepository ?? InjectionContainer.instance.chatRepository;

  showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (BuildContext context) {
      return const Center(
        child: Card(
          child: Padding(
            padding: EdgeInsets.all(20),
            child: SizedBox(
              width: 28,
              height: 28,
              child: CircularProgressIndicator(strokeWidth: 2.5),
            ),
          ),
        ),
      );
    },
  );

  final Result<ChatChannel> result = await chat.patientChannel(patientId);
  if (!context.mounted) return;
  Navigator.of(context, rootNavigator: true).pop();

  if (result case Err<ChatChannel>(:final failure)) {
    final String message = failure.apiError.userMessage;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    return;
  }

  final ChatChannel channel = (result as Ok<ChatChannel>).value;
  final String label = patientLabel.trim().isEmpty
      ? (channel.name.isEmpty ? 'Patient thread' : channel.name)
      : patientLabel.trim();

  if (!context.mounted) return;
  context.push(
    AppRoutes.chatChannelPath(channel.id),
    extra: ChatChannelExtra(
      channel: channel,
      patientId: patientId,
      patientLabel: label,
    ),
  );
}
