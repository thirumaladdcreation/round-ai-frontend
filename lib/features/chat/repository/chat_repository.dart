import 'package:dio/dio.dart';
import 'package:round_ai/core/errors/result.dart';
import 'package:round_ai/features/chat/models/chat_channel.dart';
import 'package:round_ai/features/chat/models/chat_message.dart';
import 'package:round_ai/features/chat/models/chat_summary_draft.dart';
import 'package:round_ai/features/chat/models/unread_summary.dart';

/// Team chat REST surface (M5). SSE lives in [ChatStreamClient] (H2).
abstract class ChatRepository {
  /// Drops in-memory message cache. Called on sign-out and 401.
  void clearLocalState();

  Future<Result<List<ChatChannel>>> listChannels();

  Future<Result<UnreadSummary>> unreadSummary();

  /// Creates a `team`, `group`, or `dm` channel. Patient threads use
  /// [patientChannel] instead.
  Future<Result<ChatChannel>> createChannel({
    required String type,
    String? teamId,
    String? name,
    String? userId,
    List<String>? memberIds,
  });

  Future<Result<ChatChannel>> patientChannel(String patientId);

  /// Messages ascending by `seq`. Pass [parentId] empty string for top-level
  /// only, a uuid for replies, or null for all.
  Future<Result<List<ChatMessage>>> listMessages(
    String channelId, {
    int? beforeSeq,
    int? afterSeq,
    int? limit,
    String? parentId,
  });

  /// Posts a message. Backend has no `client_message_id`; optimistic retry
  /// must tolerate `duplicate_message` (429).
  Future<Result<ChatMessage>> sendMessage(
    String channelId, {
    required String body,
    String? parentId,
  });

  Future<Result<ChatMessage>> editMessage(String messageId, {required String body});

  Future<Result<ChatMessage>> deleteMessage(String messageId);

  Future<Result<ChannelReadResult>> markRead(
    String channelId, {
    required int lastReadSeq,
  });

  /// Search across the user's channels. Do not log [query].
  Future<Result<List<ChatMessage>>> search({
    required String query,
    int? limit,
  });

  /// Explicit AI action. Result is a private draft — never auto-posted.
  Future<Result<ChatSummaryDraft>> summarizeThread(
    String channelId, {
    required String idempotencyKey,
    CancelToken? cancelToken,
  });

  /// Registers a push device token (`POST /chat/devices`). Backend stores a
  /// hash only. Payloads must stay generic ("New message") with no PHI.
  Future<Result<void>> registerDevice({
    required String platform,
    required String token,
  });
}
