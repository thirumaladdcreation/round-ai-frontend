import 'package:round_ai/features/chat/models/chat_message.dart';

/// In-memory, bounded message cache. Cleared on sign-out / 401.
///
/// Offline encrypted persistence is intentionally not implemented — ask before
/// adding it.
class ChatMemoryCache {
  ChatMemoryCache({this.maxMessagesPerChannel = 200});

  final int maxMessagesPerChannel;
  final Map<String, List<ChatMessage>> _byChannel = <String, List<ChatMessage>>{};

  List<ChatMessage> messagesFor(String channelId) =>
      List<ChatMessage>.unmodifiable(_byChannel[channelId] ?? const <ChatMessage>[]);

  void putAll(String channelId, Iterable<ChatMessage> messages) {
    final Map<String, ChatMessage> byId = <String, ChatMessage>{
      for (final ChatMessage m in _byChannel[channelId] ?? const <ChatMessage>[])
        m.id: m,
      for (final ChatMessage m in messages)
        if (m.id.isNotEmpty) m.id: m,
    };
    final List<ChatMessage> sorted = byId.values.toList()
      ..sort((ChatMessage a, ChatMessage b) => a.seq.compareTo(b.seq));
    if (sorted.length > maxMessagesPerChannel) {
      _byChannel[channelId] = sorted.sublist(
        sorted.length - maxMessagesPerChannel,
      );
    } else {
      _byChannel[channelId] = sorted;
    }
  }

  void upsert(ChatMessage message) {
    if (message.channelId.isEmpty || message.id.isEmpty) return;
    putAll(message.channelId, <ChatMessage>[message]);
  }

  void clear() => _byChannel.clear();

  void clearChannel(String channelId) => _byChannel.remove(channelId);
}
