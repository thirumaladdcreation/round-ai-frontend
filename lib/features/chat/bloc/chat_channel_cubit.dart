import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:round_ai/core/errors/failures.dart';
import 'package:round_ai/core/errors/result.dart';
import 'package:round_ai/core/network/api_error.dart';
import 'package:round_ai/core/network/idempotency_key.dart';
import 'package:round_ai/features/chat/models/chat_message.dart';
import 'package:round_ai/features/chat/models/chat_stream_event.dart';
import 'package:round_ai/features/chat/models/chat_timeline_item.dart';
import 'package:round_ai/features/chat/repository/chat_repository.dart';
import 'package:round_ai/features/chat/services/chat_realtime_controller.dart';

class ChatChannelState extends Equatable {
  const ChatChannelState({
    this.loading = true,
    this.loadingOlder = false,
    this.hasMore = true,
    this.items = const <ChatTimelineItem>[],
    this.replyCounts = const <String, int>{},
    this.error,
    this.actionError,
    this.chatDisabled = false,
    this.sending = false,
  });

  final bool loading;
  final bool loadingOlder;
  final bool hasMore;
  final List<ChatTimelineItem> items;

  /// Reply totals for top-level message ids (client-counted; not on the wire).
  final Map<String, int> replyCounts;
  final ApiError? error;
  final ApiError? actionError;
  final bool chatDisabled;
  final bool sending;

  /// Synced + local rows ascending (oldest first / newest at bottom).
  List<ChatTimelineItem> get timeline => items;

  int replyCount(String messageId) => replyCounts[messageId] ?? 0;

  ChatChannelState copyWith({
    bool? loading,
    bool? loadingOlder,
    bool? hasMore,
    List<ChatTimelineItem>? items,
    Map<String, int>? replyCounts,
    ApiError? error,
    bool clearError = false,
    ApiError? actionError,
    bool clearActionError = false,
    bool? chatDisabled,
    bool? sending,
  }) {
    return ChatChannelState(
      loading: loading ?? this.loading,
      loadingOlder: loadingOlder ?? this.loadingOlder,
      hasMore: hasMore ?? this.hasMore,
      items: items ?? this.items,
      replyCounts: replyCounts ?? this.replyCounts,
      error: clearError ? null : error ?? this.error,
      actionError: clearActionError ? null : actionError ?? this.actionError,
      chatDisabled: chatDisabled ?? this.chatDisabled,
      sending: sending ?? this.sending,
    );
  }

  @override
  List<Object?> get props => <Object?>[
    loading,
    loadingOlder,
    hasMore,
    items,
    replyCounts,
    error?.code,
    actionError?.code,
    chatDisabled,
    sending,
  ];
}

/// REST messaging for one channel: list, paginate, optimistic send, edit/delete.
/// Subscribes to [ChatRealtimeController] when provided (H2).
class ChatChannelCubit extends Cubit<ChatChannelState> {
  ChatChannelCubit({
    required ChatRepository chat,
    required this.channelId,
    required this.currentUserId,
    this.pageSize = 50,
    this.threadParentId,
    ChatRealtimeController? realtime,
  }) : _chat = chat,
       _realtime = realtime,
       super(const ChatChannelState()) {
    final ChatRealtimeController? rt = _realtime;
    if (rt != null) {
      rt.setActiveChannel(channelId);
      _eventSub = rt.events.listen(applyStreamEvent);
      _gapSub = rt.gaps.listen((ChatRealtimeGap gap) {
        if (gap.channelId == channelId || gap.channelId.isEmpty) {
          unawaited(refetchAfterGap());
        }
      });
    }
  }

  final ChatRepository _chat;
  final ChatRealtimeController? _realtime;
  final String channelId;
  final String currentUserId;
  final int pageSize;

  /// When set, this cubit shows/sends replies under that parent message.
  final String? threadParentId;

  bool get isThread => threadParentId != null && threadParentId!.isNotEmpty;
  StreamSubscription<ChatStreamEvent>? _eventSub;
  StreamSubscription<ChatRealtimeGap>? _gapSub;

  @override
  Future<void> close() async {
    if (_realtime?.activeChannelId == channelId) {
      _realtime?.setActiveChannel(null);
    }
    await _eventSub?.cancel();
    await _gapSub?.cancel();
    return super.close();
  }

  /// Apply a live / replayed SSE event. Keeps seq order; ignores other channels.
  void applyStreamEvent(ChatStreamEvent event) {
    if (event.message.channelId != channelId) return;
    if (state.loading) return;
    if (event.type == ChatStreamEventType.unknown) return;

    final ChatMessage message = event.message;
    if (isThread) {
      if (message.parentId != threadParentId && message.id != threadParentId) {
        return;
      }
    } else if (message.isThreadReply) {
      final String? parent = message.parentId;
      if (parent == null) return;
      final Map<String, int> counts = Map<String, int>.from(state.replyCounts);
      if (event.type == ChatStreamEventType.message) {
        counts[parent] = (counts[parent] ?? 0) + 1;
        emit(state.copyWith(replyCounts: counts));
      }
      return;
    }

    final List<ChatTimelineItem> locals = state.items
        .where((ChatTimelineItem i) => i.status != ChatSendStatus.synced)
        .toList();
    final List<ChatTimelineItem> synced = state.items
        .where((ChatTimelineItem i) => i.status == ChatSendStatus.synced)
        .toList();

    final int existing = synced.indexWhere(
      (ChatTimelineItem i) => i.message.id == message.id,
    );
    if (existing >= 0) {
      synced[existing] = ChatTimelineItem(message: message);
    } else if (event.type == ChatStreamEventType.message) {
      // Drop matching optimistic row (same sender + body).
      locals.removeWhere(
        (ChatTimelineItem i) =>
            i.message.senderId == message.senderId &&
            i.message.body == message.body,
      );
      synced.add(ChatTimelineItem(message: message));
    } else {
      // Edit/delete for an unknown id — ignore until refetch.
      return;
    }

    synced.sort(
      (ChatTimelineItem a, ChatTimelineItem b) =>
          a.message.seq.compareTo(b.message.seq),
    );
    final List<ChatTimelineItem> next = <ChatTimelineItem>[...synced, ...locals];
    emit(state.copyWith(items: next));
    final ChatRealtimeController? rt = _realtime;
    if (rt == null || rt.isForeground) {
      unawaited(_markReadIfNeeded(next));
    }
  }

  /// After a seq gap, pull messages newer than our newest synced seq.
  Future<void> refetchAfterGap() async {
    final ChatTimelineItem? newest = _newestSynced(state.items);
    final Result<List<ChatMessage>> result = await _chat.listMessages(
      channelId,
      afterSeq: newest?.message.seq,
      limit: pageSize,
      parentId: '',
    );
    if (isClosed) return;
    if (result case Err<List<ChatMessage>>(:final failure)) {
      emit(state.copyWith(actionError: failure.apiError));
      return;
    }
    final List<ChatMessage> fresh = (result as Ok<List<ChatMessage>>).value;
    if (fresh.isEmpty) return;
    List<ChatTimelineItem> items = state.items;
    for (final ChatMessage m in fresh) {
      items = _upsertSynced(items, m);
    }
    emit(state.copyWith(items: items));
    final ChatRealtimeController? rt = _realtime;
    if (rt == null || rt.isForeground) {
      await _markReadIfNeeded(items);
    }
  }

  static List<ChatTimelineItem> _upsertSynced(
    List<ChatTimelineItem> items,
    ChatMessage message,
  ) {
    final List<ChatTimelineItem> locals = items
        .where((ChatTimelineItem i) => i.status != ChatSendStatus.synced)
        .toList();
    final List<ChatTimelineItem> synced = items
        .where((ChatTimelineItem i) => i.status == ChatSendStatus.synced)
        .toList();
    final int idx = synced.indexWhere(
      (ChatTimelineItem i) => i.message.id == message.id,
    );
    if (idx >= 0) {
      synced[idx] = ChatTimelineItem(message: message);
    } else {
      synced.add(ChatTimelineItem(message: message));
    }
    synced.sort(
      (ChatTimelineItem a, ChatTimelineItem b) =>
          a.message.seq.compareTo(b.message.seq),
    );
    return <ChatTimelineItem>[...synced, ...locals];
  }

  Future<void> load() async {
    emit(
      state.copyWith(
        loading: true,
        clearError: true,
        chatDisabled: false,
      ),
    );
    final Result<List<ChatMessage>> result = await _chat.listMessages(
      channelId,
      limit: pageSize,
      parentId: isThread ? threadParentId : null,
    );
    if (isClosed) return;
    if (result case Err<List<ChatMessage>>(:final failure)) {
      final ApiError error = failure.apiError;
      emit(
        state.copyWith(
          loading: false,
          error: error,
          chatDisabled: error.kind == ApiErrorKind.chatDisabled,
        ),
      );
      return;
    }
    final List<ChatMessage> raw = (result as Ok<List<ChatMessage>>).value;
    final ({List<ChatTimelineItem> items, Map<String, int> counts}) partitioned =
        _partition(raw);
    emit(
      state.copyWith(
        loading: false,
        items: partitioned.items,
        replyCounts: partitioned.counts,
        hasMore: raw.length >= pageSize,
        clearError: true,
        chatDisabled: false,
      ),
    );
    await _markReadIfNeeded(partitioned.items);
  }

  Future<void> loadOlder() async {
    if (state.loadingOlder || !state.hasMore || state.loading) return;
    final ChatTimelineItem? oldest = _oldestSynced(state.items);
    if (oldest == null) return;
    emit(state.copyWith(loadingOlder: true, clearActionError: true));
    final Result<List<ChatMessage>> result = await _chat.listMessages(
      channelId,
      beforeSeq: oldest.message.seq,
      limit: pageSize,
      parentId: isThread ? threadParentId : null,
    );
    if (isClosed) return;
    if (result case Err<List<ChatMessage>>(:final failure)) {
      emit(
        state.copyWith(
          loadingOlder: false,
          actionError: failure.apiError,
        ),
      );
      return;
    }
    final List<ChatMessage> older = (result as Ok<List<ChatMessage>>).value;
    final ({List<ChatTimelineItem> items, Map<String, int> counts}) part =
        _partition(older);
    final Set<String> existing = <String>{
      for (final ChatTimelineItem i in state.items) i.message.id,
    };
    final List<ChatTimelineItem> prepended = <ChatTimelineItem>[
      for (final ChatTimelineItem i in part.items)
        if (!existing.contains(i.message.id)) i,
      ...state.items,
    ];
    final Map<String, int> counts = Map<String, int>.from(state.replyCounts);
    part.counts.forEach((String id, int n) {
      counts[id] = (counts[id] ?? 0) + n;
    });
    emit(
      state.copyWith(
        loadingOlder: false,
        items: prepended,
        replyCounts: counts,
        hasMore: older.length >= pageSize,
      ),
    );
  }

  Future<void> send(String rawBody) async {
    final String body = rawBody.trim();
    if (body.isEmpty || state.chatDisabled) return;
    if (body.length > kChatMaxBodyLength) {
      emit(
        state.copyWith(
          actionError: const ApiError(
            code: 'too_long',
            message: '',
            status: 400,
          ),
        ),
      );
      return;
    }

    final String localId = 'local:${IdempotencyKey.create()}';
    final ChatMessage optimistic = ChatMessage(
      id: localId,
      channelId: channelId,
      senderId: currentUserId,
      body: body,
      seq: _nextLocalSeq(state.items),
      parentId: threadParentId,
      deleted: false,
      createdAt: DateTime.now().toUtc(),
    );
    emit(
      state.copyWith(
        items: <ChatTimelineItem>[
          ...state.items,
          ChatTimelineItem(
            message: optimistic,
            status: ChatSendStatus.pending,
          ),
        ],
        sending: true,
        clearActionError: true,
      ),
    );

    final Result<ChatMessage> result = await _chat.sendMessage(
      channelId,
      body: body,
      parentId: threadParentId,
    );
    if (isClosed) return;
    if (result case Err<ChatMessage>(:final failure)) {
      final ApiError error = failure.apiError;
      if (error.kind == ApiErrorKind.duplicateMessage) {
        await _reconcileAfterDuplicate(localId);
        return;
      }
      emit(
        state.copyWith(
          sending: false,
          chatDisabled: error.kind == ApiErrorKind.chatDisabled,
          actionError: error,
          items: _mapLocal(
            state.items,
            localId,
            (ChatTimelineItem i) =>
                i.copyWith(status: ChatSendStatus.failed),
          ),
        ),
      );
      return;
    }
    final ChatMessage saved = (result as Ok<ChatMessage>).value;
    final List<ChatTimelineItem> next = _replaceLocal(
      state.items,
      localId,
      saved,
    );
    emit(state.copyWith(sending: false, items: next));
    await _markReadIfNeeded(next);
  }

  Future<void> retry(String localId) async {
    ChatTimelineItem? failed;
    for (final ChatTimelineItem i in state.items) {
      if (i.message.id == localId) {
        failed = i;
        break;
      }
    }
    if (failed == null || failed.status != ChatSendStatus.failed) return;
    final String body = failed.message.body;
    emit(
      state.copyWith(
        items: state.items
            .where((ChatTimelineItem i) => i.message.id != localId)
            .toList(),
      ),
    );
    await send(body);
  }

  Future<void> editMessage(String messageId, String rawBody) async {
    final String body = rawBody.trim();
    if (body.isEmpty) return;
    emit(state.copyWith(clearActionError: true));
    final Result<ChatMessage> result = await _chat.editMessage(
      messageId,
      body: body,
    );
    if (isClosed) return;
    if (result case Err<ChatMessage>(:final failure)) {
      emit(state.copyWith(actionError: failure.apiError));
      return;
    }
    final ChatMessage updated = (result as Ok<ChatMessage>).value;
    emit(
      state.copyWith(
        items: <ChatTimelineItem>[
          for (final ChatTimelineItem i in state.items)
            if (i.message.id == messageId)
              ChatTimelineItem(message: updated)
            else
              i,
        ],
      ),
    );
  }

  void clearActionError() {
    if (state.actionError == null) return;
    emit(state.copyWith(clearActionError: true));
  }

  Future<void> deleteMessage(String messageId) async {
    emit(state.copyWith(clearActionError: true));
    final Result<ChatMessage> result = await _chat.deleteMessage(messageId);
    if (isClosed) return;
    if (result case Err<ChatMessage>(:final failure)) {
      emit(state.copyWith(actionError: failure.apiError));
      return;
    }
    final ChatMessage deleted = (result as Ok<ChatMessage>).value;
    emit(
      state.copyWith(
        items: <ChatTimelineItem>[
          for (final ChatTimelineItem i in state.items)
            if (i.message.id == messageId)
              ChatTimelineItem(message: deleted)
            else
              i,
        ],
      ),
    );
  }

  ({List<ChatTimelineItem> items, Map<String, int> counts}) _partition(
    List<ChatMessage> raw,
  ) {
    if (isThread) {
      final List<ChatMessage> replies = raw
          .where(
            (ChatMessage m) =>
                m.parentId == threadParentId || m.id == threadParentId,
          )
          .where((ChatMessage m) => m.id != threadParentId)
          .toList();
      return (
        items: replies
            .map((ChatMessage m) => ChatTimelineItem(message: m))
            .toList(),
        counts: const <String, int>{},
      );
    }
    final Map<String, int> counts = <String, int>{};
    final List<ChatTimelineItem> roots = <ChatTimelineItem>[];
    for (final ChatMessage m in raw) {
      if (m.isThreadReply) {
        final String parent = m.parentId!;
        counts[parent] = (counts[parent] ?? 0) + 1;
      } else {
        roots.add(ChatTimelineItem(message: m));
      }
    }
    return (items: roots, counts: counts);
  }

  Future<void> _reconcileAfterDuplicate(String localId) async {
    final Result<List<ChatMessage>> result = await _chat.listMessages(
      channelId,
      limit: pageSize,
      parentId: isThread ? threadParentId : null,
    );
    if (isClosed) return;
    if (result case Ok<List<ChatMessage>>(:final value)) {
      emit(
        state.copyWith(
          sending: false,
          items: value
              .map((ChatMessage m) => ChatTimelineItem(message: m))
              .toList(),
          clearActionError: true,
        ),
      );
      return;
    }
    emit(
      state.copyWith(
        sending: false,
        items: state.items
            .where((ChatTimelineItem i) => i.message.id != localId)
            .toList(),
        actionError: const ApiError(
          code: 'duplicate_message',
          message: '',
          status: 429,
        ),
      ),
    );
  }

  Future<void> _markReadIfNeeded(List<ChatTimelineItem> items) async {
    final ChatTimelineItem? newest = _newestSynced(items);
    if (newest == null) return;
    await _chat.markRead(channelId, lastReadSeq: newest.message.seq);
  }

  static ChatTimelineItem? _oldestSynced(List<ChatTimelineItem> items) {
    for (final ChatTimelineItem i in items) {
      if (i.status == ChatSendStatus.synced && !i.message.id.startsWith('local:')) {
        return i;
      }
    }
    return null;
  }

  static ChatTimelineItem? _newestSynced(List<ChatTimelineItem> items) {
    for (int i = items.length - 1; i >= 0; i--) {
      final ChatTimelineItem item = items[i];
      if (item.status == ChatSendStatus.synced &&
          !item.message.id.startsWith('local:')) {
        return item;
      }
    }
    return null;
  }

  static int _nextLocalSeq(List<ChatTimelineItem> items) {
    int max = 0;
    for (final ChatTimelineItem i in items) {
      if (i.message.seq > max) max = i.message.seq;
    }
    return max + 1;
  }

  static List<ChatTimelineItem> _mapLocal(
    List<ChatTimelineItem> items,
    String localId,
    ChatTimelineItem Function(ChatTimelineItem) map,
  ) {
    return <ChatTimelineItem>[
      for (final ChatTimelineItem i in items)
        if (i.message.id == localId) map(i) else i,
    ];
  }

  static List<ChatTimelineItem> _replaceLocal(
    List<ChatTimelineItem> items,
    String localId,
    ChatMessage saved,
  ) {
    final List<ChatTimelineItem> next = <ChatTimelineItem>[
      for (final ChatTimelineItem i in items)
        if (i.message.id == localId)
          ChatTimelineItem(message: saved)
        else if (i.message.id != saved.id)
          i,
    ];
    // Ensure saved is present even if local row was already gone.
    if (!next.any((ChatTimelineItem i) => i.message.id == saved.id)) {
      next.add(ChatTimelineItem(message: saved));
      next.sort(
        (ChatTimelineItem a, ChatTimelineItem b) =>
            a.message.seq.compareTo(b.message.seq),
      );
    }
    return next;
  }
}
