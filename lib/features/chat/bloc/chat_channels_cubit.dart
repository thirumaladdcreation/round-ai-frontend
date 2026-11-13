import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:round_ai/core/errors/failures.dart';
import 'package:round_ai/core/errors/result.dart';
import 'package:round_ai/core/network/api_error.dart';
import 'package:round_ai/features/chat/cache/chat_people_directory.dart';
import 'package:round_ai/features/chat/chat_unread_badge.dart';
import 'package:round_ai/features/chat/models/chat_channel.dart';
import 'package:round_ai/features/chat/models/chat_stream_event.dart';
import 'package:round_ai/features/chat/repository/chat_repository.dart';
import 'package:round_ai/features/chat/services/chat_realtime_controller.dart';

class ChatChannelSection extends Equatable {
  const ChatChannelSection({required this.title, required this.channels});

  final String title;
  final List<ChatChannel> channels;

  @override
  List<Object> get props => <Object>[title, channels];
}

class ChatChannelsState extends Equatable {
  const ChatChannelsState({
    this.loading = true,
    this.sections = const <ChatChannelSection>[],
    this.error,
    this.chatDisabled = false,
    this.totalUnread = 0,
  });

  final bool loading;
  final List<ChatChannelSection> sections;
  final ApiError? error;
  final bool chatDisabled;
  final int totalUnread;

  bool get isEmpty =>
      sections.every((ChatChannelSection s) => s.channels.isEmpty);

  ChatChannelsState copyWith({
    bool? loading,
    List<ChatChannelSection>? sections,
    ApiError? error,
    bool clearError = false,
    bool? chatDisabled,
    int? totalUnread,
  }) {
    return ChatChannelsState(
      loading: loading ?? this.loading,
      sections: sections ?? this.sections,
      error: clearError ? null : error ?? this.error,
      chatDisabled: chatDisabled ?? this.chatDisabled,
      totalUnread: totalUnread ?? this.totalUnread,
    );
  }

  @override
  List<Object?> get props => <Object?>[
    loading,
    sections,
    error?.code,
    chatDisabled,
    totalUnread,
  ];
}

/// Channel list grouped by type. Backend order is type+name; within a section
/// unread channels are listed first, then name (no `last_activity` on wire).
class ChatChannelsCubit extends Cubit<ChatChannelsState> {
  ChatChannelsCubit(
    this._chat,
    this._badge, {
    ChatRealtimeController? realtime,
    ChatPeopleDirectory? people,
    this.currentUserId,
  }) : _realtime = realtime,
       _people = people,
       super(const ChatChannelsState()) {
    final ChatRealtimeController? rt = _realtime;
    if (rt != null) {
      _eventSub = rt.events.listen(_onStreamEvent);
      _gapSub = rt.gaps.listen((_) {
        unawaited(load());
      });
    }
  }

  final ChatRepository _chat;
  final ChatUnreadBadge _badge;
  final ChatRealtimeController? _realtime;
  final ChatPeopleDirectory? _people;
  final String? currentUserId;
  StreamSubscription<ChatStreamEvent>? _eventSub;
  StreamSubscription<ChatRealtimeGap>? _gapSub;

  @override
  Future<void> close() async {
    await _eventSub?.cancel();
    await _gapSub?.cancel();
    return super.close();
  }

  void _onStreamEvent(ChatStreamEvent event) {
    if (state.chatDisabled || state.loading) return;
    applyStreamEvent(
      event,
      activeChannelId: _realtime?.activeChannelId,
      currentUserId: currentUserId ?? _realtime?.currentUserId,
    );
  }

  /// Live unread + section order. Unknown channels trigger a quiet reload.
  void applyStreamEvent(
    ChatStreamEvent event, {
    String? activeChannelId,
    String? currentUserId,
  }) {
    if (event.type != ChatStreamEventType.message) return;
    final String channelId = event.message.channelId;
    if (channelId.isEmpty) return;

    final List<ChatChannel> flat = <ChatChannel>[
      for (final ChatChannelSection s in state.sections) ...s.channels,
    ];
    final int index = flat.indexWhere((ChatChannel c) => c.id == channelId);
    if (index < 0) {
      unawaited(load());
      return;
    }

    final bool fromSelf =
        currentUserId != null &&
        currentUserId.isNotEmpty &&
        event.message.senderId == currentUserId;
    final bool viewing = activeChannelId == channelId;
    ChatChannel channel = flat[index];
    if (!fromSelf && !viewing) {
      channel = channel.copyWith(unread: channel.unread + 1);
    } else if (viewing) {
      channel = channel.copyWith(unread: 0);
    }
    flat[index] = channel;
    final int total = flat.fold<int>(0, (int n, ChatChannel c) => n + c.unread);
    _badge.setTotal(total);
    emit(
      state.copyWith(
        sections: _group(flat),
        totalUnread: total,
      ),
    );
  }

  Future<void> load() async {
    emit(
      state.copyWith(
        loading: state.sections.isEmpty,
        clearError: true,
        chatDisabled: false,
      ),
    );
    final Result<List<ChatChannel>> result = await _chat.listChannels();
    if (isClosed) return;
    if (result case Err<List<ChatChannel>>(:final failure)) {
      final ApiError error = failure.apiError;
      final bool disabled = error.kind == ApiErrorKind.chatDisabled;
      if (disabled) _badge.clear();
      emit(
        state.copyWith(
          loading: false,
          error: error,
          chatDisabled: disabled,
          totalUnread: disabled ? 0 : state.totalUnread,
        ),
      );
      return;
    }
    final List<ChatChannel> channels =
        (result as Ok<List<ChatChannel>>).value;
    _people?.noteChannels(channels);
    final int total = channels.fold<int>(
      0,
      (int n, ChatChannel c) => n + c.unread,
    );
    _badge.setTotal(total);
    emit(
      state.copyWith(
        loading: false,
        sections: _group(channels),
        totalUnread: total,
        chatDisabled: false,
        clearError: true,
      ),
    );
  }

  static List<ChatChannelSection> _group(List<ChatChannel> channels) {
    List<ChatChannel> of(ChatChannelType type) {
      final List<ChatChannel> list = channels
          .where((ChatChannel c) => c.type == type)
          .toList()
        ..sort((ChatChannel a, ChatChannel b) {
          final int unreadCmp = b.unread.compareTo(a.unread);
          if (unreadCmp != 0) return unreadCmp;
          return a.name.toLowerCase().compareTo(b.name.toLowerCase());
        });
      return list;
    }

    return <ChatChannelSection>[
      ChatChannelSection(title: 'Team', channels: of(ChatChannelType.team)),
      ChatChannelSection(
        title: 'Patients',
        channels: of(ChatChannelType.patient),
      ),
      ChatChannelSection(title: 'Groups', channels: of(ChatChannelType.group)),
      ChatChannelSection(
        title: 'Direct messages',
        channels: of(ChatChannelType.dm),
      ),
    ].where((ChatChannelSection s) => s.channels.isNotEmpty).toList();
  }
}
