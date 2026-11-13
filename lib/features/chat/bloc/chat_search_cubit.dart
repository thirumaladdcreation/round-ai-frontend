import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:round_ai/core/errors/failures.dart';
import 'package:round_ai/core/errors/result.dart';
import 'package:round_ai/core/network/api_error.dart';
import 'package:round_ai/features/chat/models/chat_channel.dart';
import 'package:round_ai/features/chat/models/chat_message.dart';
import 'package:round_ai/features/chat/repository/chat_repository.dart';

class ChatSearchState extends Equatable {
  const ChatSearchState({
    this.query = '',
    this.loading = false,
    this.results = const <ChatMessage>[],
    this.channelTitles = const <String, String>{},
    this.error,
  });

  final String query;
  final bool loading;
  final List<ChatMessage> results;
  final Map<String, String> channelTitles;
  final ApiError? error;

  String titleFor(String channelId) {
    final String? title = channelTitles[channelId];
    if (title != null && title.trim().isNotEmpty) return title;
    return 'Conversation';
  }

  ChatSearchState copyWith({
    String? query,
    bool? loading,
    List<ChatMessage>? results,
    Map<String, String>? channelTitles,
    ApiError? error,
    bool clearError = false,
  }) {
    return ChatSearchState(
      query: query ?? this.query,
      loading: loading ?? this.loading,
      results: results ?? this.results,
      channelTitles: channelTitles ?? this.channelTitles,
      error: clearError ? null : error ?? this.error,
    );
  }

  @override
  List<Object?> get props => <Object?>[
    query,
    loading,
    results,
    channelTitles,
    error?.code,
  ];
}

/// Debounced search. Never logs [query] (may contain PHI).
class ChatSearchCubit extends Cubit<ChatSearchState> {
  ChatSearchCubit(this._chat) : super(const ChatSearchState()) {
    unawaited(_loadTitles());
  }

  final ChatRepository _chat;
  Timer? _debounce;

  Future<void> _loadTitles() async {
    final Result<List<ChatChannel>> result = await _chat.listChannels();
    if (isClosed) return;
    if (result case Ok<List<ChatChannel>>(:final value)) {
      emit(
        state.copyWith(
          channelTitles: <String, String>{
            for (final ChatChannel c in value)
              if (c.id.isNotEmpty) c.id: c.name,
          },
        ),
      );
    }
  }

  void onQueryChanged(String raw) {
    final String query = raw.trim();
    emit(state.copyWith(query: query, clearError: true));
    _debounce?.cancel();
    if (query.length < 2) {
      emit(state.copyWith(loading: false, results: const <ChatMessage>[]));
      return;
    }
    emit(state.copyWith(loading: true));
    _debounce = Timer(const Duration(milliseconds: 350), () {
      unawaited(_run(query));
    });
  }

  Future<void> _run(String query) async {
    final Result<List<ChatMessage>> result = await _chat.search(query: query);
    if (isClosed) return;
    if (query != state.query) return;
    if (result case Err<List<ChatMessage>>(:final failure)) {
      emit(
        state.copyWith(
          loading: false,
          error: failure.apiError,
          results: const <ChatMessage>[],
        ),
      );
      return;
    }
    emit(
      state.copyWith(
        loading: false,
        results: (result as Ok<List<ChatMessage>>).value,
        clearError: true,
      ),
    );
  }

  @override
  Future<void> close() {
    _debounce?.cancel();
    return super.close();
  }
}
