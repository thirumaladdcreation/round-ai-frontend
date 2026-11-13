import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:round_ai/core/di/injection_container.dart';
import 'package:round_ai/core/theme/app_colors.dart';
import 'package:round_ai/core/theme/app_typography.dart';
import 'package:round_ai/features/chat/bloc/chat_channel_cubit.dart';
import 'package:round_ai/features/chat/cache/chat_people_directory.dart';
import 'package:round_ai/features/chat/models/chat_channel.dart';
import 'package:round_ai/features/chat/models/chat_message.dart';
import 'package:round_ai/features/chat/models/chat_timeline_item.dart';
import 'package:round_ai/features/chat/repository/chat_repository.dart';
import 'package:round_ai/features/chat/services/chat_realtime_controller.dart';
import 'package:round_ai/features/chat/utils/chat_mention_utils.dart';
import 'package:round_ai/features/chat/widgets/chat_mention_composer.dart';
import 'package:round_ai/shared/widgets/ai_error_box.dart';
import 'package:round_ai/shared/widgets/retry_view.dart';
import 'package:round_ai/shared/widgets/skeleton.dart';

/// Replies under one parent message.
class ChatThreadScreen extends StatelessWidget {
  const ChatThreadScreen({
    required this.channelId,
    required this.parent,
    this.channel,
    this.chatRepository,
    this.realtime,
    this.people,
    this.currentUserId,
    super.key,
  });

  final String channelId;
  final ChatMessage parent;
  final ChatChannel? channel;
  final ChatRepository? chatRepository;
  final ChatRealtimeController? realtime;
  final ChatPeopleDirectory? people;
  final String? currentUserId;

  @override
  Widget build(BuildContext context) {
    final InjectionContainer di = InjectionContainer.instance;
    final bool useDi = chatRepository == null;
    final String userId = currentUserId ??
        (useDi ? di.profileRepository.current?.user.id ?? '' : '');
    final ChatPeopleDirectory directory =
        people ?? (useDi ? di.chatPeople : ChatPeopleDirectory());
    return BlocProvider<ChatChannelCubit>(
      create: (_) => ChatChannelCubit(
        chat: chatRepository ?? di.chatRepository,
        channelId: channelId,
        currentUserId: userId,
        threadParentId: parent.id,
        realtime: realtime ?? (useDi ? di.chatRealtime : null),
      )..load(),
      child: _ThreadView(
        parent: parent,
        currentUserId: userId,
        people: directory,
        channelType: channel?.type,
      ),
    );
  }
}

class _ThreadView extends StatefulWidget {
  const _ThreadView({
    required this.parent,
    required this.currentUserId,
    required this.people,
    this.channelType,
  });

  final ChatMessage parent;
  final String currentUserId;
  final ChatPeopleDirectory people;
  final ChatChannelType? channelType;

  @override
  State<_ThreadView> createState() => _ThreadViewState();
}

class _ThreadViewState extends State<_ThreadView> {
  final TextEditingController _composer = TextEditingController();
  final FocusNode _focus = FocusNode();

  @override
  void dispose() {
    _composer.dispose();
    _focus.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final String text = _composer.text;
    _composer.clear();
    await context.read<ChatChannelCubit>().send(text);
  }

  @override
  Widget build(BuildContext context) {
    final AppColors colors = AppColors.of(context);
    return BlocBuilder<ChatChannelCubit, ChatChannelState>(
      builder: (BuildContext context, ChatChannelState state) {
        final ChatChannelCubit cubit = context.read<ChatChannelCubit>();
        return Scaffold(
          backgroundColor: colors.background,
          appBar: AppBar(
            backgroundColor: colors.surface,
            elevation: 0,
            leading: IconButton(
              tooltip: 'Back',
              icon: const Icon(Icons.arrow_back),
              onPressed: () => context.pop(),
            ),
            title: Text(
              'Thread',
              style: AppTypography.semiBold(
                fontSize: 17,
                color: colors.textPrimary,
              ),
            ),
          ),
          body: Column(
            children: <Widget>[
              if (state.actionError != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                  child: AiErrorBox(
                    error: state.actionError!,
                    onRetry: cubit.clearActionError,
                  ),
                ),
              Expanded(
                child: state.loading
                    ? const SkeletonList(count: 4)
                    : state.error != null && state.items.isEmpty
                    ? RetryView(
                        title: 'Thread could not be loaded.',
                        message: state.error!.userMessage,
                        onRetry: cubit.load,
                      )
                    : ListView(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                        children: <Widget>[
                          _ParentCard(
                            message: widget.parent,
                            people: widget.people,
                            isMine:
                                widget.parent.senderId == widget.currentUserId,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Replies',
                            style: AppTypography.semiBold(
                              fontSize: 12,
                              color: colors.textMuted,
                            ),
                          ),
                          const SizedBox(height: 8),
                          if (state.items.isEmpty)
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 24),
                              child: Text(
                                'No replies yet.',
                                style: AppTypography.regular(
                                  fontSize: 14,
                                  color: colors.textMuted,
                                ),
                              ),
                            )
                          else
                            for (final ChatTimelineItem item in state.items)
                              _ReplyTile(
                                item: item,
                                people: widget.people,
                                isMine:
                                    item.message.senderId ==
                                    widget.currentUserId,
                                onRetry: () => cubit.retry(item.message.id),
                              ),
                        ],
                      ),
              ),
              ChatMentionComposer(
                controller: _composer,
                focusNode: _focus,
                enabled: !state.sending && !state.chatDisabled,
                onSend: _send,
                people: widget.people,
                excludeUserId: widget.currentUserId,
                showPatientReminder:
                    widget.channelType == ChatChannelType.patient,
                hintText: 'Reply',
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ParentCard extends StatelessWidget {
  const _ParentCard({
    required this.message,
    required this.people,
    required this.isMine,
  });

  final ChatMessage message;
  final ChatPeopleDirectory people;
  final bool isMine;

  @override
  Widget build(BuildContext context) {
    final AppColors colors = AppColors.of(context);
    final String who = isMine ? 'You' : people.labelFor(message.senderId);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              who,
              style: AppTypography.semiBold(
                fontSize: 12,
                color: colors.textMuted,
              ),
            ),
            const SizedBox(height: 6),
            if (message.deleted)
              Text(
                'Message deleted',
                style: AppTypography.regular(
                  fontSize: 14,
                  color: colors.textMuted,
                ).copyWith(fontStyle: FontStyle.italic),
              )
            else
              Text.rich(buildMentionSpans(message.body, colors: colors)),
          ],
        ),
      ),
    );
  }
}

class _ReplyTile extends StatelessWidget {
  const _ReplyTile({
    required this.item,
    required this.people,
    required this.isMine,
    required this.onRetry,
  });

  final ChatTimelineItem item;
  final ChatPeopleDirectory people;
  final bool isMine;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final AppColors colors = AppColors.of(context);
    final ChatMessage m = item.message;
    final String who = isMine ? 'You' : people.labelFor(m.senderId);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: isMine
              ? colors.primary.withValues(alpha: 0.10)
              : colors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: colors.border),
        ),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                who,
                style: AppTypography.semiBold(
                  fontSize: 12,
                  color: colors.textMuted,
                ),
              ),
              const SizedBox(height: 4),
              if (m.deleted)
                Text(
                  'Message deleted',
                  style: AppTypography.regular(
                    fontSize: 14,
                    color: colors.textMuted,
                  ).copyWith(fontStyle: FontStyle.italic),
                )
              else
                Text.rich(buildMentionSpans(m.body, colors: colors)),
              if (item.status == ChatSendStatus.failed)
                TextButton(
                  onPressed: onRetry,
                  child: Text(
                    'Failed · Retry',
                    style: AppTypography.semiBold(
                      fontSize: 12,
                      color: colors.error,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
