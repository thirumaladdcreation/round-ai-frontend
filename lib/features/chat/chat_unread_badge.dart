import 'package:flutter/foundation.dart';

/// Team-wide unread total for the Chat tab badge. Cleared on sign-out.
/// Values are counts only — never channel or message content.
class ChatUnreadBadge extends ValueNotifier<int> {
  ChatUnreadBadge() : super(0);

  void setTotal(int total) {
    final int next = total < 0 ? 0 : total;
    if (next == value) return;
    value = next;
  }

  void clear() => setTotal(0);

  String? get label {
    if (value <= 0) return null;
    if (value > 9) return '9+';
    return '$value';
  }
}
