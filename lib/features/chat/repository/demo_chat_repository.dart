import 'package:dio/dio.dart';
import 'package:round_ai/core/errors/failures.dart';
import 'package:round_ai/core/errors/result.dart';
import 'package:round_ai/core/network/api_error.dart';
import 'package:round_ai/core/network/idempotency_key.dart';
import 'package:round_ai/features/ai/models/ai_envelope.dart';
import 'package:round_ai/features/chat/cache/chat_memory_cache.dart';
import 'package:round_ai/features/chat/models/chat_channel.dart';
import 'package:round_ai/features/chat/models/chat_message.dart';
import 'package:round_ai/features/chat/models/chat_summary_draft.dart';
import 'package:round_ai/features/chat/models/unread_summary.dart';
import 'package:round_ai/features/chat/repository/chat_repository.dart';

/// In-memory chat for `USE_DEMO=true`. No PHI beyond placeholder labels.
class DemoChatRepository implements ChatRepository {
  DemoChatRepository({ChatMemoryCache? cache, String currentUserId = 'demo'})
    : _cache = cache ?? ChatMemoryCache(),
      _userId = currentUserId {
    _seed();
  }

  final ChatMemoryCache _cache;
  final String _userId;
  final Map<String, ChatChannel> _channels = <String, ChatChannel>{};
  final Map<String, List<ChatMessage>> _messages = <String, List<ChatMessage>>{};
  final Map<String, int> _lastRead = <String, int>{};
  int _seq = 0;

  void _seed() {
    final ChatChannel general = ChatChannel(
      id: 'demo-general',
      teamId: 'demo-team',
      name: 'general',
      type: ChatChannelType.team,
      archived: false,
      unread: 1,
      createdAt: DateTime.utc(2026, 11, 12),
    );
    final ChatChannel patient = ChatChannel(
      id: 'demo-patient-1',
      teamId: 'demo-team',
      name: 'Room 509A',
      type: ChatChannelType.patient,
      patientId: 'p-509a',
      archived: false,
      unread: 0,
      createdAt: DateTime.utc(2026, 11, 12),
    );
    final ChatChannel dm = ChatChannel(
      id: 'demo-dm-1',
      teamId: 'demo-team',
      name: 'Jordan Lee',
      type: ChatChannelType.dm,
      archived: false,
      unread: 0,
      createdAt: DateTime.utc(2026, 11, 12),
    );
    _channels[general.id] = general;
    _channels[patient.id] = patient;
    _channels[dm.id] = dm;
    final ChatMessage root = _msg(
      channelId: general.id,
      senderId: 'demo-teammate',
      body: 'Morning handoff is in the workroom at 7. @Alex',
    );
    _messages[general.id] = <ChatMessage>[
      root,
      _msg(
        channelId: general.id,
        senderId: 'demo-alex',
        body: 'On my way.',
        parentId: root.id,
      ),
    ];
    _messages[patient.id] = <ChatMessage>[
      _msg(
        channelId: patient.id,
        senderId: 'demo-teammate',
        body: 'Imaging pending — will update after read.',
      ),
    ];
    _messages[dm.id] = <ChatMessage>[];
    _lastRead[general.id] = 0;
  }

  ChatMessage _msg({
    required String channelId,
    required String senderId,
    required String body,
    String? parentId,
    bool deleted = false,
    DateTime? editedAt,
  }) {
    _seq += 1;
    return ChatMessage(
      id: 'demo-msg-$_seq',
      channelId: channelId,
      senderId: senderId,
      body: deleted ? '' : body,
      seq: _seq,
      parentId: parentId,
      deleted: deleted,
      editedAt: editedAt,
      createdAt: DateTime.now().toUtc(),
    );
  }

  @override
  void clearLocalState() {
    _cache.clear();
    _channels.clear();
    _messages.clear();
    _lastRead.clear();
    _seq = 0;
    _seed();
  }

  @override
  Future<Result<List<ChatChannel>>> listChannels() async {
    return Ok<List<ChatChannel>>(
      _channels.values.map(_withUnread).toList(),
    );
  }

  ChatChannel _withUnread(ChatChannel channel) {
    final List<ChatMessage> msgs =
        _messages[channel.id] ?? const <ChatMessage>[];
    final int last = _lastRead[channel.id] ?? 0;
    final int unread = msgs.where((ChatMessage m) => m.seq > last).length;
    return channel.copyWith(unread: unread);
  }

  @override
  Future<Result<UnreadSummary>> unreadSummary() async {
    final List<ChatChannel> channels = _channels.values.map(_withUnread).toList();
    final int total = channels.fold<int>(
      0,
      (int n, ChatChannel c) => n + c.unread,
    );
    return Ok<UnreadSummary>(
      UnreadSummary(
        totalUnread: total,
        channels: <UnreadChannel>[
          for (final ChatChannel c in channels)
            if (c.unread > 0)
              UnreadChannel(
                id: c.id,
                unread: c.unread,
                type: c.type,
                patientId: c.patientId,
              ),
        ],
      ),
    );
  }

  @override
  Future<Result<ChatChannel>> createChannel({
    required String type,
    String? teamId,
    String? name,
    String? userId,
    List<String>? memberIds,
  }) async {
    final ChatChannelType parsed = ChatChannelTypeX.parse(type);
    if (parsed == ChatChannelType.patient ||
        parsed == ChatChannelType.unknown) {
      return Err<ChatChannel>(
        ApiFailure(
          const ApiError(code: 'bad_type', message: '', status: 400),
        ),
      );
    }
    final String id = 'demo-${IdempotencyKey.create()}';
    final ChatChannel channel = ChatChannel(
      id: id,
      teamId: teamId ?? 'demo-team',
      name: name?.trim().isNotEmpty == true
          ? name!.trim()
          : (parsed == ChatChannelType.dm ? 'Direct message' : 'Group'),
      type: parsed,
      archived: false,
      unread: 0,
      createdAt: DateTime.now().toUtc(),
    );
    _channels[id] = channel;
    _messages[id] = <ChatMessage>[];
    _lastRead[id] = 0;
    return Ok<ChatChannel>(channel);
  }

  @override
  Future<Result<ChatChannel>> patientChannel(String patientId) async {
    for (final ChatChannel c in _channels.values) {
      if (c.patientId == patientId) return Ok<ChatChannel>(_withUnread(c));
    }
    // Match backend: GET /patients/:id/channel auto-creates the thread.
    final String id = 'demo-patient-$patientId';
    final ChatChannel channel = ChatChannel(
      id: id,
      teamId: 'demo-team',
      name: 'Patient thread',
      type: ChatChannelType.patient,
      patientId: patientId,
      archived: false,
      unread: 0,
      createdAt: DateTime.now().toUtc(),
    );
    _channels[id] = channel;
    _messages[id] = <ChatMessage>[];
    _lastRead[id] = 0;
    return Ok<ChatChannel>(channel);
  }

  @override
  Future<Result<List<ChatMessage>>> listMessages(
    String channelId, {
    int? beforeSeq,
    int? afterSeq,
    int? limit,
    String? parentId,
  }) async {
    if (!_channels.containsKey(channelId)) {
      return Err<List<ChatMessage>>(
        ApiFailure(
          const ApiError(code: 'not_found', message: '', status: 404),
        ),
      );
    }
    Iterable<ChatMessage> list = _messages[channelId] ?? const <ChatMessage>[];
    if (parentId != null) {
      if (parentId.isEmpty) {
        list = list.where(
          (ChatMessage m) => m.parentId == null || m.parentId!.isEmpty,
        );
      } else {
        list = list.where((ChatMessage m) => m.parentId == parentId);
      }
    }
    if (beforeSeq != null) {
      list = list.where((ChatMessage m) => m.seq < beforeSeq);
    }
    if (afterSeq != null) {
      list = list.where((ChatMessage m) => m.seq > afterSeq);
    }
    final List<ChatMessage> sorted = list.toList()
      ..sort((ChatMessage a, ChatMessage b) => a.seq.compareTo(b.seq));
    final int take = limit ?? 50;
    final List<ChatMessage> page = sorted.length <= take
        ? sorted
        : sorted.sublist(sorted.length - take);
    _cache.putAll(channelId, page);
    return Ok<List<ChatMessage>>(page);
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
    if (!_channels.containsKey(channelId)) {
      return Err<ChatMessage>(
        ApiFailure(
          const ApiError(code: 'not_found', message: '', status: 404),
        ),
      );
    }
    final ChatMessage message = _msg(
      channelId: channelId,
      senderId: _userId,
      body: trimmed,
      parentId: parentId,
    );
    _messages.putIfAbsent(channelId, () => <ChatMessage>[]).add(message);
    _cache.upsert(message);
    return Ok<ChatMessage>(message);
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
    final _Located? found = _find(messageId);
    if (found == null) {
      return Err<ChatMessage>(
        ApiFailure(
          const ApiError(code: 'not_found', message: '', status: 404),
        ),
      );
    }
    if (found.message.senderId != _userId) {
      return Err<ChatMessage>(
        ApiFailure(
          const ApiError(code: 'forbidden', message: '', status: 403),
        ),
      );
    }
    final ChatMessage updated = ChatMessage(
      id: found.message.id,
      channelId: found.message.channelId,
      senderId: found.message.senderId,
      body: trimmed,
      seq: found.message.seq,
      parentId: found.message.parentId,
      deleted: false,
      editedAt: DateTime.now().toUtc(),
      createdAt: found.message.createdAt,
    );
    _messages[found.channelId]![found.index] = updated;
    _cache.upsert(updated);
    return Ok<ChatMessage>(updated);
  }

  @override
  Future<Result<ChatMessage>> deleteMessage(String messageId) async {
    final _Located? found = _find(messageId);
    if (found == null) {
      return Err<ChatMessage>(
        ApiFailure(
          const ApiError(code: 'not_found', message: '', status: 404),
        ),
      );
    }
    if (found.message.senderId != _userId) {
      return Err<ChatMessage>(
        ApiFailure(
          const ApiError(code: 'forbidden', message: '', status: 403),
        ),
      );
    }
    final ChatMessage deleted = ChatMessage(
      id: found.message.id,
      channelId: found.message.channelId,
      senderId: found.message.senderId,
      body: '',
      seq: found.message.seq,
      parentId: found.message.parentId,
      deleted: true,
      editedAt: found.message.editedAt,
      deletedAt: DateTime.now().toUtc(),
      createdAt: found.message.createdAt,
    );
    _messages[found.channelId]![found.index] = deleted;
    _cache.upsert(deleted);
    return Ok<ChatMessage>(deleted);
  }

  @override
  Future<Result<ChannelReadResult>> markRead(
    String channelId, {
    required int lastReadSeq,
  }) async {
    if (!_channels.containsKey(channelId)) {
      return Err<ChannelReadResult>(
        ApiFailure(
          const ApiError(code: 'not_found', message: '', status: 404),
        ),
      );
    }
    final int prev = _lastRead[channelId] ?? 0;
    _lastRead[channelId] = lastReadSeq > prev ? lastReadSeq : prev;
    final ChatChannel updated = _withUnread(_channels[channelId]!);
    _channels[channelId] = updated;
    return Ok<ChannelReadResult>(
      ChannelReadResult(
        channelId: channelId,
        lastReadSeq: _lastRead[channelId]!,
        unread: updated.unread,
      ),
    );
  }

  @override
  Future<Result<List<ChatMessage>>> search({
    required String query,
    int? limit,
  }) async {
    final String q = query.trim().toLowerCase();
    if (q.length < 2) {
      return Err<List<ChatMessage>>(
        ApiFailure(
          const ApiError(code: 'query_required', message: '', status: 400),
        ),
      );
    }
    final List<ChatMessage> hits = <ChatMessage>[];
    for (final List<ChatMessage> list in _messages.values) {
      for (final ChatMessage m in list) {
        if (!m.deleted && m.body.toLowerCase().contains(q)) {
          hits.add(m);
        }
      }
    }
    hits.sort((ChatMessage a, ChatMessage b) => b.seq.compareTo(a.seq));
    final int take = limit ?? 50;
    return Ok<List<ChatMessage>>(hits.take(take).toList());
  }

  @override
  Future<Result<ChatSummaryDraft>> summarizeThread(
    String channelId, {
    required String idempotencyKey,
    CancelToken? cancelToken,
  }) async {
    final List<ChatMessage> msgs = (_messages[channelId] ?? const <ChatMessage>[])
        .where((ChatMessage m) => !m.deleted)
        .toList();
    if (msgs.isEmpty) {
      return Err<ChatSummaryDraft>(
        ApiFailure(
          const ApiError(code: 'empty_thread', message: '', status: 422),
        ),
      );
    }
    return Ok<ChatSummaryDraft>(
      ChatSummaryDraft.fromEnvelope(
        AiEnvelope.fromJson(<String, dynamic>{
          'artifact_id': 'demo-sum-$idempotencyKey',
          'operation': 'summarize_chat_thread',
          'patient_id': '',
          'context_revision': 0,
          'status': 'draft',
          'review_state': 'draft',
          'outdated': false,
          'requires_review': true,
          'provider': 'demo',
          'model': 'demo',
          'prompt_version': '1',
          'generation_ms': 1,
          'created_at': DateTime.now().toUtc().toIso8601String(),
          'content': <String, dynamic>{
            'bullets': <Object>[
              <String, Object>{
                'text': 'Demo summary of this thread.',
                'message_ids': <String>[msgs.last.id],
              },
            ],
            'open_questions': <String>[],
            'missing_information': <String>[],
            'channel_id': channelId,
            'disclaimer': 'AI draft · review required',
          },
        }),
      ),
    );
  }

  @override
  Future<Result<void>> registerDevice({
    required String platform,
    required String token,
  }) async {
    final String p = platform.trim().toLowerCase();
    final String t = token.trim();
    if (t.length < 8) {
      return Err<void>(
        ApiFailure(
          const ApiError(code: 'token_required', message: '', status: 400),
        ),
      );
    }
    if (!const <String>{'ios', 'android', 'web', 'unknown'}.contains(p)) {
      return Err<void>(
        ApiFailure(
          const ApiError(code: 'bad_platform', message: '', status: 400),
        ),
      );
    }
    return const Ok<void>(null);
  }

  _Located? _find(String messageId) {
    for (final MapEntry<String, List<ChatMessage>> entry in _messages.entries) {
      for (int i = 0; i < entry.value.length; i++) {
        if (entry.value[i].id == messageId) {
          return _Located(entry.key, i, entry.value[i]);
        }
      }
    }
    return null;
  }
}

class _Located {
  const _Located(this.channelId, this.index, this.message);
  final String channelId;
  final int index;
  final ChatMessage message;
}
