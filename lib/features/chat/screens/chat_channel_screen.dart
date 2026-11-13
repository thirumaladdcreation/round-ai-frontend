import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:round_ai/core/di/injection_container.dart';
import 'package:round_ai/core/network/api_error.dart';
import 'package:round_ai/core/router/app_routes.dart';
import 'package:round_ai/core/theme/app_colors.dart';
import 'package:round_ai/core/theme/app_typography.dart';
import 'package:round_ai/features/authentication/repository/profile_repository.dart';
import 'package:round_ai/features/chat/bloc/chat_channel_cubit.dart';
import 'package:round_ai/features/chat/cache/chat_people_directory.dart';
import 'package:round_ai/features/chat/models/chat_channel.dart';
import 'package:round_ai/features/chat/models/chat_message.dart';
import 'package:round_ai/features/chat/models/chat_nav_extra.dart';
import 'package:round_ai/features/chat/models/chat_timeline_item.dart';
import 'package:round_ai/features/chat/repository/chat_repository.dart';
import 'package:round_ai/features/chat/services/chat_realtime_controller.dart';
import 'package:round_ai/features/chat/utils/chat_mention_utils.dart';
import 'package:round_ai/features/chat/utils/summarize_thread_action.dart';
import 'package:round_ai/features/chat/widgets/chat_mention_composer.dart';
import 'package:round_ai/shared/widgets/ai_error_box.dart';
import 'package:round_ai/shared/widgets/chat_disabled_banner.dart';
import 'package:round_ai/shared/widgets/retry_view.dart';
import 'package:round_ai/shared/widgets/skeleton.dart';

/// One channel conversation (REST). Newest messages at the bottom.
///
/// [title] / [channelType] / patient label come from navigation `extra`
/// (not the URL) so patient-related labels are never placed in deep-link paths.
class ChatChannelScreen extends StatelessWidget {
  const ChatChannelScreen({
    required this.channelId,
    this.title,
    this.channelType,
    this.channel,
    this.highlightMessageId,
    this.patientId,
    this.patientLabel,
    this.chatRepository,
    this.realtime,
    this.people,
    this.currentUserId,
    this.chatOff,
    super.key,
  });

  final String channelId;
  final String? title;
  final ChatChannelType? channelType;
  final ChatChannel? channel;
  final String? highlightMessageId;
  final String? patientId;
  final String? patientLabel;
  final ChatRepository? chatRepository;
  final ChatRealtimeController? realtime;
  final ChatPeopleDirectory? people;
  final String? currentUserId;
  final bool? chatOff;

  @override
  Widget build(BuildContext context) {
    final InjectionContainer di = InjectionContainer.instance;
    final bool useDi = chatRepository == null;
    final String userId = currentUserId ??
        (useDi ? di.profileRepository.current?.user.id ?? '' : '');
    final bool off =
        chatOff ?? (useDi ? di.profileRepository.chatOff : false);
    final ChatPeopleDirectory directory =
        people ?? (useDi ? di.chatPeople : ChatPeopleDirectory());
    final String? resolvedPatientId =
        (patientId != null && patientId!.trim().isNotEmpty)
            ? patientId
            : channel?.patientId;
    final String headerTitle = () {
      final String? label = patientLabel?.trim();
      if (label != null && label.isNotEmpty) return label;
      if (title != null && title!.trim().isNotEmpty) return title!.trim();
      return 'Channel';
    }();
    return BlocProvider<ChatChannelCubit>(
      create: (_) => ChatChannelCubit(
        chat: chatRepository ?? di.chatRepository,
        channelId: channelId,
        currentUserId: userId,
        realtime: realtime ?? (useDi ? di.chatRealtime : null),
      )..load(),
      child: _ChannelView(
        channelId: channelId,
        title: headerTitle,
        channel: channel,
        channelType: channelType ?? channel?.type,
        patientId: resolvedPatientId,
        chatOff: off,
        currentUserId: userId,
        people: directory,
        highlightMessageId: highlightMessageId,
        chatRepository: chatRepository ?? (useDi ? di.chatRepository : null),
      ),
    );
  }
}

class _ChannelView extends StatefulWidget {
  const _ChannelView({
    required this.channelId,
    required this.title,
    required this.chatOff,
    required this.currentUserId,
    required this.people,
    this.channel,
    this.channelType,
    this.patientId,
    this.highlightMessageId,
    this.chatRepository,
  });

  final String channelId;
  final String title;
  final ChatChannel? channel;
  final ChatChannelType? channelType;
  final String? patientId;
  final bool chatOff;
  final String currentUserId;
  final ChatPeopleDirectory people;
  final String? highlightMessageId;
  final ChatRepository? chatRepository;

  @override
  State<_ChannelView> createState() => _ChannelViewState();
}

class _ChannelViewState extends State<_ChannelView> {
  final TextEditingController _composer = TextEditingController();
  final ScrollController _scroll = ScrollController();
  final FocusNode _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scroll.removeListener(_onScroll);
    _scroll.dispose();
    _composer.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scroll.hasClients) return;
    if (_scroll.position.pixels <= 80) {
      context.read<ChatChannelCubit>().loadOlder();
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      _scroll.jumpTo(_scroll.position.maxScrollExtent);
    });
  }

  Future<void> _send() async {
    final String text = _composer.text;
    _composer.clear();
    await context.read<ChatChannelCubit>().send(text);
    _scrollToBottom();
  }

  @override
  Widget build(BuildContext context) {
    final AppColors colors = AppColors.of(context);
    return BlocConsumer<ChatChannelCubit, ChatChannelState>(
      listenWhen: (ChatChannelState a, ChatChannelState b) =>
          a.items.length != b.items.length || a.sending != b.sending,
      listener: (BuildContext context, ChatChannelState state) {
        if (!state.loading) _scrollToBottom();
      },
      builder: (BuildContext context, ChatChannelState state) {
        final ChatChannelCubit cubit = context.read<ChatChannelCubit>();
        final bool disabled = widget.chatOff || state.chatDisabled;
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
              widget.title,
              style: AppTypography.semiBold(
                fontSize: 17,
                color: colors.textPrimary,
              ),
            ),
            actions: <Widget>[
              if (!disabled)
                PopupMenuButton<String>(
                  tooltip: 'Channel actions',
                  onSelected: (String value) {
                    if (value == 'summarize') {
                      runSummarizeThreadAction(
                        context,
                        channelId: widget.channelId,
                        channelTitle: widget.title,
                        chatRepository: widget.chatRepository,
                      );
                    }
                  },
                  itemBuilder: (BuildContext context) =>
                      const <PopupMenuEntry<String>>[
                        PopupMenuItem<String>(
                          value: 'summarize',
                          child: Text('Summarize thread'),
                        ),
                      ],
                ),
            ],
          ),
          body: Column(
            children: <Widget>[
              if (widget.patientId != null &&
                  widget.patientId!.trim().isNotEmpty)
                Material(
                  color: colors.surface,
                  child: InkWell(
                    onTap: () => context.push(
                      AppRoutes.patientPath(widget.patientId!),
                    ),
                    child: Semantics(
                      button: true,
                      label: 'View patient chart',
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                        child: Row(
                          children: <Widget>[
                            Icon(
                              Icons.person_outline,
                              size: 16,
                              color: colors.primary,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'View patient',
                              style: AppTypography.semiBold(
                                fontSize: 13,
                                color: colors.primary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              if (disabled) const ChatDisabledBanner(),
              if (state.actionError != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                  child: AiErrorBox(
                    error: state.actionError!,
                    onRetry: state.actionError!.kind == ApiErrorKind.rateLimited
                        ? null
                        : cubit.clearActionError,
                  ),
                ),
              Expanded(
                child: disabled
                    ? const SizedBox.shrink()
                    : state.loading
                    ? const SkeletonList(count: 6)
                    : state.error != null && state.items.isEmpty
                    ? RetryView(
                        title: 'Messages could not be loaded.',
                        message: state.error!.userMessage,
                        onRetry: cubit.load,
                      )
                    : _MessageList(
                        scroll: _scroll,
                        items: state.items,
                        replyCounts: state.replyCounts,
                        loadingOlder: state.loadingOlder,
                        currentUserId: widget.currentUserId,
                        people: widget.people,
                        highlightMessageId: widget.highlightMessageId,
                        onRetry: cubit.retry,
                        onEdit: (ChatTimelineItem item) =>
                            _edit(context, item),
                        onDelete: (ChatTimelineItem item) =>
                            _confirmDelete(context, item),
                        onOpenThread: (ChatTimelineItem item) {
                          widget.people.noteSender(item.message.senderId);
                          context.push(
                            AppRoutes.chatThreadPath(
                              widget.channelId,
                              item.message.id,
                            ),
                            extra: ChatThreadExtra(
                              parent: item.message,
                              channel: widget.channel,
                            ),
                          );
                        },
                      ),
              ),
              if (!disabled)
                ChatMentionComposer(
                  controller: _composer,
                  focusNode: _focus,
                  enabled: !state.sending,
                  showPatientReminder:
                      widget.channelType == ChatChannelType.patient,
                  onSend: _send,
                  people: widget.people,
                  excludeUserId: widget.currentUserId,
                ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _edit(BuildContext context, ChatTimelineItem item) async {
    final TextEditingController edit = TextEditingController(
      text: item.message.body,
    );
    final String? next = await showDialog<String>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Edit message'),
          content: TextField(
            controller: edit,
            maxLength: kChatMaxBodyLength,
            maxLines: 4,
            autofocus: true,
            decoration: const InputDecoration(border: OutlineInputBorder()),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, edit.text),
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
    edit.dispose();
    if (next == null || !context.mounted) return;
    await context.read<ChatChannelCubit>().editMessage(item.message.id, next);
  }

  Future<void> _confirmDelete(
    BuildContext context,
    ChatTimelineItem item,
  ) async {
    final bool? ok = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Delete message?'),
          content: const Text(
            'It will show as deleted for the team. Permanent removal is '
            'controlled by your administrator.',
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );
    if (ok != true || !context.mounted) return;
    await context.read<ChatChannelCubit>().deleteMessage(item.message.id);
  }
}

class _MessageList extends StatelessWidget {
  const _MessageList({
    required this.scroll,
    required this.items,
    required this.replyCounts,
    required this.loadingOlder,
    required this.currentUserId,
    required this.people,
    required this.onRetry,
    required this.onEdit,
    required this.onDelete,
    required this.onOpenThread,
    this.highlightMessageId,
  });

  final ScrollController scroll;
  final List<ChatTimelineItem> items;
  final Map<String, int> replyCounts;
  final bool loadingOlder;
  final String currentUserId;
  final ChatPeopleDirectory people;
  final String? highlightMessageId;
  final ValueChanged<String> onRetry;
  final ValueChanged<ChatTimelineItem> onEdit;
  final ValueChanged<ChatTimelineItem> onDelete;
  final ValueChanged<ChatTimelineItem> onOpenThread;

  @override
  Widget build(BuildContext context) {
    final AppColors colors = AppColors.of(context);
    if (items.isEmpty) {
      return Center(
        child: Text(
          'No messages yet. Say hello to the team.',
          style: AppTypography.regular(fontSize: 14, color: colors.textMuted),
        ),
      );
    }

    final List<_Row> rows = _buildRows(items);
    return ListView.builder(
      controller: scroll,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      itemCount: rows.length + (loadingOlder ? 1 : 0),
      itemBuilder: (BuildContext context, int index) {
        if (loadingOlder && index == 0) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Center(
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          );
        }
        final int rowIndex = loadingOlder ? index - 1 : index;
        final _Row row = rows[rowIndex];
        if (row.separator != null) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Center(
              child: Text(
                row.separator!,
                style: AppTypography.medium(
                  fontSize: 12,
                  color: colors.textMuted,
                ),
              ),
            ),
          );
        }
        final ChatTimelineItem item = row.item!;
        people.noteSender(item.message.senderId);
        return _MessageBubble(
          item: item,
          isMine: item.message.senderId == currentUserId,
          people: people,
          replyCount: replyCounts[item.message.id] ?? 0,
          highlighted: item.message.id == highlightMessageId,
          onRetry: () => onRetry(item.message.id),
          onEdit: () => onEdit(item),
          onDelete: () => onDelete(item),
          onOpenThread: () => onOpenThread(item),
        );
      },
    );
  }

  static List<_Row> _buildRows(List<ChatTimelineItem> items) {
    final List<_Row> rows = <_Row>[];
    DateTime? lastDay;
    for (final ChatTimelineItem item in items) {
      final DateTime? at = item.message.createdAt?.toLocal();
      if (at != null) {
        final DateTime day = DateTime(at.year, at.month, at.day);
        if (lastDay == null || day != lastDay) {
          rows.add(_Row.separator(_dayLabel(day)));
          lastDay = day;
        }
      }
      rows.add(_Row.message(item));
    }
    return rows;
  }

  static String _dayLabel(DateTime day) {
    final DateTime now = DateTime.now();
    final DateTime today = DateTime(now.year, now.month, now.day);
    final DateTime yesterday = today.subtract(const Duration(days: 1));
    if (day == today) return 'Today';
    if (day == yesterday) return 'Yesterday';
    return '${day.year}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}';
  }
}

class _Row {
  const _Row._({this.item, this.separator});
  factory _Row.message(ChatTimelineItem item) => _Row._(item: item);
  factory _Row.separator(String label) => _Row._(separator: label);

  final ChatTimelineItem? item;
  final String? separator;
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({
    required this.item,
    required this.isMine,
    required this.people,
    required this.replyCount,
    required this.onRetry,
    required this.onEdit,
    required this.onDelete,
    required this.onOpenThread,
    this.highlighted = false,
  });

  final ChatTimelineItem item;
  final bool isMine;
  final ChatPeopleDirectory people;
  final int replyCount;
  final bool highlighted;
  final VoidCallback onRetry;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onOpenThread;

  @override
  Widget build(BuildContext context) {
    final AppColors colors = AppColors.of(context);
    final ChatMessage m = item.message;
    final String time = m.createdAt == null ? '' : _time(m.createdAt!.toLocal());
    final String senderLabel =
        isMine ? 'You' : people.labelFor(m.senderId);

    final Widget body = m.deleted
        ? Text(
            'Message deleted',
            style: AppTypography.regular(
              fontSize: 14,
              color: colors.textMuted,
            ).copyWith(fontStyle: FontStyle.italic),
          )
        : Text.rich(buildMentionSpans(m.body, colors: colors));

    final String meta = m.deleted
        ? 'Deleted message from $senderLabel'
        : 'Message from $senderLabel${time.isEmpty ? '' : ', $time'}'
            '${m.editedAt != null ? ', edited' : ''}'
            '${replyCount > 0 ? ', $replyCount replies' : ''}';
    return Semantics(
      // Body is exposed to the screen reader only — never to logs or push.
      label: meta,
      value: m.deleted ? null : m.body,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Align(
          alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.sizeOf(context).width * 0.82,
            ),
            child: GestureDetector(
              onTap: m.deleted ? null : onOpenThread,
              onLongPress:
                  m.deleted ||
                      !isMine ||
                      item.status != ChatSendStatus.synced
                  ? null
                  : () => _menu(context),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: isMine
                      ? colors.primary.withValues(alpha: 0.12)
                      : colors.surface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: highlighted ? colors.primary : colors.border,
                    width: highlighted ? 1.5 : 1,
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Row(
                        children: <Widget>[
                          Text(
                            senderLabel,
                            style: AppTypography.semiBold(
                              fontSize: 12,
                              color: colors.textMuted,
                            ),
                          ),
                          const Spacer(),
                          if (time.isNotEmpty)
                            Text(
                              time,
                              style: AppTypography.regular(
                                fontSize: 11,
                                color: colors.textMuted,
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      body,
                      if (m.isEdited) ...<Widget>[
                        const SizedBox(height: 4),
                        Text(
                          'edited',
                          style: AppTypography.regular(
                            fontSize: 11,
                            color: colors.textMuted,
                          ),
                        ),
                      ],
                      if (replyCount > 0) ...<Widget>[
                        const SizedBox(height: 6),
                        Text(
                          replyCount == 1
                              ? '1 reply'
                              : '$replyCount replies',
                          style: AppTypography.semiBold(
                            fontSize: 12,
                            color: colors.primary,
                          ),
                        ),
                      ],
                      if (item.status == ChatSendStatus.pending) ...<Widget>[
                        const SizedBox(height: 4),
                        Text(
                          'Sending…',
                          style: AppTypography.regular(
                            fontSize: 11,
                            color: colors.textMuted,
                          ),
                        ),
                      ],
                      if (item.status == ChatSendStatus.failed) ...<Widget>[
                        const SizedBox(height: 6),
                        TextButton(
                          onPressed: onRetry,
                          style: TextButton.styleFrom(
                            padding: EdgeInsets.zero,
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          child: Text(
                            'Failed · Retry',
                            style: AppTypography.semiBold(
                              fontSize: 12,
                              color: colors.error,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _menu(BuildContext context) async {
    final String? action = await showModalBottomSheet<String>(
      context: context,
      builder: (BuildContext context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              ListTile(
                leading: const Icon(Icons.forum_outlined),
                title: const Text('Reply in thread'),
                onTap: () => Navigator.pop(context, 'thread'),
              ),
              ListTile(
                leading: const Icon(Icons.edit_outlined),
                title: const Text('Edit'),
                onTap: () => Navigator.pop(context, 'edit'),
              ),
              ListTile(
                leading: const Icon(Icons.delete_outline),
                title: const Text('Delete'),
                onTap: () => Navigator.pop(context, 'delete'),
              ),
            ],
          ),
        );
      },
    );
    if (action == 'thread') onOpenThread();
    if (action == 'edit') onEdit();
    if (action == 'delete') onDelete();
  }

  static String _time(DateTime at) {
    final int h24 = at.hour;
    final int hour = h24 % 12 == 0 ? 12 : h24 % 12;
    final String minute = at.minute.toString().padLeft(2, '0');
    final String suffix = h24 >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $suffix';
  }
}
