import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:round_ai/core/di/injection_container.dart';
import 'package:round_ai/core/errors/failures.dart';
import 'package:round_ai/core/errors/result.dart';
import 'package:round_ai/core/network/idempotency_key.dart';
import 'package:round_ai/core/router/app_routes.dart';
import 'package:round_ai/features/authentication/repository/profile_repository.dart';
import 'package:round_ai/features/chat/models/chat_nav_extra.dart';
import 'package:round_ai/features/chat/models/chat_summary_draft.dart';
import 'package:round_ai/features/chat/repository/chat_repository.dart';

/// Explicit "Summarize thread" flow with confirmation. Never auto-posts.
Future<void> runSummarizeThreadAction(
  BuildContext context, {
  required String channelId,
  String? channelTitle,
  ChatRepository? chatRepository,
}) async {
  final InjectionContainer di = InjectionContainer.instance;
  if (di.profileRepository.aiOff) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('AI drafts are turned off for your account.'),
      ),
    );
    return;
  }

  final bool? confirmed = await showDialog<bool>(
    context: context,
    builder: (BuildContext context) {
      return AlertDialog(
        title: const Text('Summarize thread?'),
        content: const Text(
          'Message content in this channel will be sent to the AI service '
          'to draft a private summary for you. The draft is not posted to '
          'the channel. Continue only if your team allows this.',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Summarize'),
          ),
        ],
      );
    },
  );
  if (confirmed != true || !context.mounted) return;

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

  final ChatRepository chat = chatRepository ?? di.chatRepository;
  final String key = IdempotencyKey.create();
  final Result<ChatSummaryDraft> result = await chat.summarizeThread(
    channelId,
    idempotencyKey: key,
  );

  if (!context.mounted) return;
  Navigator.of(context, rootNavigator: true).pop();

  if (result case Err<ChatSummaryDraft>(:final failure)) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(failure.apiError.userMessage)),
    );
    return;
  }

  final ChatSummaryDraft draft = (result as Ok<ChatSummaryDraft>).value;
  if (!context.mounted) return;
  context.push(
    AppRoutes.chatSummaryPath(channelId),
    extra: ChatSummaryExtra(draft: draft, channelTitle: channelTitle),
  );
}
