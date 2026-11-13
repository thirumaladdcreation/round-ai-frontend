import 'package:flutter/foundation.dart';
import 'package:round_ai/features/chat/models/chat_channel.dart';
import 'package:round_ai/features/chat/models/chat_message.dart';
import 'package:round_ai/features/chat/models/chat_person.dart';

/// In-memory teammate labels. Cleared on sign-out. Never logged.
class ChatPeopleDirectory extends ChangeNotifier {
  final Map<String, ChatPerson> _byId = <String, ChatPerson>{};

  List<ChatPerson> get all {
    final List<ChatPerson> list = _byId.values.toList()
      ..sort(
        (ChatPerson a, ChatPerson b) =>
            a.displayName.toLowerCase().compareTo(b.displayName.toLowerCase()),
      );
    return list;
  }

  ChatPerson? operator [](String id) => _byId[id];

  String labelFor(String userId, {String fallback = 'Teammate'}) {
    final ChatPerson? person = _byId[userId];
    if (person != null && person.displayName.isNotEmpty) {
      return person.displayName;
    }
    if (userId.isEmpty) return fallback;
    if (userId.length <= 8) return userId;
    return userId.substring(0, 8);
  }

  void upsert(ChatPerson person) {
    if (person.id.isEmpty) return;
    final ChatPerson? existing = _byId[person.id];
    if (existing != null &&
        existing.displayName.isNotEmpty &&
        (person.displayName.isEmpty ||
            person.displayName.startsWith('Teammate'))) {
      return;
    }
    _byId[person.id] = person;
    notifyListeners();
  }

  void noteSender(String senderId) {
    if (senderId.isEmpty || _byId.containsKey(senderId)) return;
    upsert(ChatPerson(id: senderId, displayName: labelFor(senderId)));
  }

  void noteMessages(Iterable<ChatMessage> messages) {
    for (final ChatMessage m in messages) {
      noteSender(m.senderId);
    }
  }

  void noteChannels(Iterable<ChatChannel> channels) {
    for (final ChatChannel c in channels) {
      if (c.type == ChatChannelType.dm && c.name.trim().isNotEmpty) {
        // DM title is often the other person's name; id unknown until they post.
        // Keep as a nameless placeholder only if we later learn their id.
      }
    }
  }

  void seedDemo() {
    upsert(const ChatPerson(id: 'demo', displayName: 'You'));
    upsert(const ChatPerson(id: 'demo-teammate', displayName: 'Jordan Lee'));
    upsert(const ChatPerson(id: 'demo-alex', displayName: 'Alex Kim'));
    upsert(const ChatPerson(id: 'demo-sam', displayName: 'Sam Patel'));
  }

  void clear() {
    _byId.clear();
    notifyListeners();
  }

  List<ChatPerson> matchingMention(String query, {String? excludeUserId}) {
    final String q = query.trim().toLowerCase();
    return all.where((ChatPerson p) {
      if (excludeUserId != null && p.id == excludeUserId) return false;
      if (q.isEmpty) return true;
      return p.displayName.toLowerCase().contains(q) ||
          p.mentionToken.toLowerCase().startsWith(q);
    }).toList();
  }
}
