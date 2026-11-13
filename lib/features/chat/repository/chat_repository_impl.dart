import 'package:dio/dio.dart';
import 'package:round_ai/core/errors/failures.dart';
import 'package:round_ai/core/errors/result.dart';
import 'package:round_ai/core/network/api_client.dart';
import 'package:round_ai/core/network/api_endpoints.dart';
import 'package:round_ai/core/network/api_error.dart';
import 'package:round_ai/core/utils/json_utils.dart';
import 'package:round_ai/features/ai/models/ai_envelope.dart';
import 'package:round_ai/features/chat/cache/chat_memory_cache.dart';
import 'package:round_ai/features/chat/models/chat_channel.dart';
import 'package:round_ai/features/chat/models/chat_message.dart';
import 'package:round_ai/features/chat/models/chat_summary_draft.dart';
import 'package:round_ai/features/chat/models/unread_summary.dart';
import 'package:round_ai/features/chat/repository/chat_repository.dart';

class ChatRepositoryImpl implements ChatRepository {
  ChatRepositoryImpl(this._client, {ChatMemoryCache? cache})
    : _cache = cache ?? ChatMemoryCache();

  final ApiClient _client;
  final ChatMemoryCache _cache;

  @override
  void clearLocalState() => _cache.clear();

  @override
  Future<Result<List<ChatChannel>>> listChannels() async {
    try {
      final Response<Object> response = await _client.get<Object>(
        ApiEndpoints.channels,
      );
      return Ok<List<ChatChannel>>(
        Json.itemsOf(response.data, 'channels')
            .map(ChatChannel.fromJson)
            .where((ChatChannel c) => c.id.isNotEmpty)
            .toList(),
      );
    } on ApiError catch (error) {
      return Err<List<ChatChannel>>(ApiFailure(error));
    }
  }

  @override
  Future<Result<UnreadSummary>> unreadSummary() async {
    try {
      final Response<Object> response = await _client.get<Object>(
        ApiEndpoints.channelsUnread,
      );
      return Ok<UnreadSummary>(UnreadSummary.fromJson(Json.map(response.data)));
    } on ApiError catch (error) {
      return Err<UnreadSummary>(ApiFailure(error));
    }
  }

  @override
  Future<Result<ChatChannel>> createChannel({
    required String type,
    String? teamId,
    String? name,
    String? userId,
    List<String>? memberIds,
  }) async {
    try {
      final Response<Object> response = await _client.post<Object>(
        ApiEndpoints.channels,
        data: <String, Object?>{
          'type': type,
          if (teamId != null && teamId.isNotEmpty) 'team_id': teamId,
          if (name != null && name.isNotEmpty) 'name': name,
          if (userId != null && userId.isNotEmpty) 'user_id': userId,
          if (memberIds != null && memberIds.isNotEmpty) 'member_ids': memberIds,
        },
      );
      return Ok<ChatChannel>(ChatChannel.fromJson(Json.map(response.data)));
    } on ApiError catch (error) {
      return Err<ChatChannel>(ApiFailure(error));
    }
  }

  @override
  Future<Result<ChatChannel>> patientChannel(String patientId) async {
    try {
      final Response<Object> response = await _client.get<Object>(
        ApiEndpoints.patientChannel(patientId),
      );
      return Ok<ChatChannel>(ChatChannel.fromJson(Json.map(response.data)));
    } on ApiError catch (error) {
      return Err<ChatChannel>(ApiFailure(error));
    }
  }

  @override
  Future<Result<List<ChatMessage>>> listMessages(
    String channelId, {
    int? beforeSeq,
    int? afterSeq,
    int? limit,
    String? parentId,
  }) async {
    try {
      final Response<Object> response = await _client.get<Object>(
        ApiEndpoints.channelMessages(channelId),
        queryParameters: <String, Object?>{
          'before_seq': ?beforeSeq,
          'after_seq': ?afterSeq,
          'limit': ?limit,
          'parent_id': ?parentId,
        },
      );
      final List<ChatMessage> messages = Json.itemsOf(response.data, 'messages')
          .map(ChatMessage.fromJson)
          .where((ChatMessage m) => m.id.isNotEmpty)
          .toList();
      _cache.putAll(channelId, messages);
      return Ok<List<ChatMessage>>(messages);
    } on ApiError catch (error) {
      return Err<List<ChatMessage>>(ApiFailure(error));
    }
  }

  @override
  Future<Result<ChatMessage>> sendMessage(
    String channelId, {
    required String body,
    String? parentId,
  }) async {
    final String trimmed = body.trim();
    if (trimmed.isEmpty) {
      return Err<ChatMessage>(
        ApiFailure(
          const ApiError(code: 'body_required', message: '', status: 400),
        ),
      );
    }
    if (trimmed.length > kChatMaxBodyLength) {
      return Err<ChatMessage>(
        ApiFailure(
          const ApiError(code: 'too_long', message: '', status: 400),
        ),
      );
    }
    try {
      final Response<Object> response = await _client.post<Object>(
        ApiEndpoints.channelMessages(channelId),
        data: <String, Object?>{
          'body': trimmed,
          if (parentId != null && parentId.isNotEmpty) 'parent_id': parentId,
        },
      );
      final ChatMessage message = ChatMessage.fromJson(Json.map(response.data));
      _cache.upsert(message);
      return Ok<ChatMessage>(message);
    } on ApiError catch (error) {
      return Err<ChatMessage>(ApiFailure(error));
    }
  }

  @override
  Future<Result<ChatMessage>> editMessage(
    String messageId, {
    required String body,
  }) async {
    final String trimmed = body.trim();
    if (trimmed.length > kChatMaxBodyLength) {
      return Err<ChatMessage>(
        ApiFailure(
          const ApiError(code: 'too_long', message: '', status: 400),
        ),
      );
    }
    try {
      final Response<Object> response = await _client.patch<Object>(
        ApiEndpoints.message(messageId),
        data: <String, String>{'body': trimmed},
      );
      final ChatMessage message = ChatMessage.fromJson(Json.map(response.data));
      _cache.upsert(message);
      return Ok<ChatMessage>(message);
    } on ApiError catch (error) {
      return Err<ChatMessage>(ApiFailure(error));
    }
  }

  @override
  Future<Result<ChatMessage>> deleteMessage(String messageId) async {
    try {
      final Response<Object> response = await _client.delete<Object>(
        ApiEndpoints.message(messageId),
      );
      final ChatMessage message = ChatMessage.fromJson(Json.map(response.data));
      _cache.upsert(message);
      return Ok<ChatMessage>(message);
    } on ApiError catch (error) {
      return Err<ChatMessage>(ApiFailure(error));
    }
  }

  @override
  Future<Result<ChannelReadResult>> markRead(
    String channelId, {
    required int lastReadSeq,
  }) async {
    try {
      final Response<Object> response = await _client.post<Object>(
        ApiEndpoints.channelRead(channelId),
        data: <String, int>{'last_read_seq': lastReadSeq},
      );
      return Ok<ChannelReadResult>(
        ChannelReadResult.fromJson(Json.map(response.data)),
      );
    } on ApiError catch (error) {
      return Err<ChannelReadResult>(ApiFailure(error));
    }
  }

  @override
  Future<Result<List<ChatMessage>>> search({
    required String query,
    int? limit,
  }) async {
    // Intentionally never logged — queries can contain PHI.
    try {
      final Response<Object> response = await _client.get<Object>(
        ApiEndpoints.channelsSearch,
        queryParameters: <String, Object?>{
          'q': query,
          'limit': ?limit,
        },
      );
      return Ok<List<ChatMessage>>(
        Json.itemsOf(response.data, 'messages')
            .map(ChatMessage.fromJson)
            .where((ChatMessage m) => m.id.isNotEmpty)
            .toList(),
      );
    } on ApiError catch (error) {
      return Err<List<ChatMessage>>(ApiFailure(error));
    }
  }

  @override
  Future<Result<ChatSummaryDraft>> summarizeThread(
    String channelId, {
    required String idempotencyKey,
    CancelToken? cancelToken,
  }) async {
    try {
      final Response<Object> response = await _client.postAi<Object>(
        ApiEndpoints.channelSummarize(channelId),
        idempotencyKey: idempotencyKey,
        cancelToken: cancelToken,
      );
      final AiEnvelope envelope = AiEnvelope.fromBody(response.data);
      return Ok<ChatSummaryDraft>(ChatSummaryDraft.fromEnvelope(envelope));
    } on ApiError catch (error) {
      return Err<ChatSummaryDraft>(ApiFailure(error));
    }
  }

  @override
  Future<Result<void>> registerDevice({
    required String platform,
    required String token,
  }) async {
    try {
      await _client.post<Object>(
        ApiEndpoints.chatDevices,
        data: <String, String>{'platform': platform, 'token': token},
      );
      return const Ok<void>(null);
    } on ApiError catch (error) {
      return Err<void>(ApiFailure(error));
    }
  }
}
