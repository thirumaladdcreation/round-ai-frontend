/// Safe fields from a chat push. Display copy is always generic (rule 2).
///
/// Remote title/body are ignored for UI so a misconfigured provider cannot
/// leak sender, channel, or message text into the notification surface.
class ChatPushPayload {
  const ChatPushPayload({this.channelId});

  /// Opaque channel id only. Never a patient name or room label.
  final String? channelId;

  static const String displayTitle = 'New message';
  static const String displayBody = 'Open RoundsAI';

  /// Parses provider data. Only [channel_id] / [channelId] are used for routing.
  factory ChatPushPayload.parse(Map<Object?, Object?>? data) {
    if (data == null || data.isEmpty) return const ChatPushPayload();
    final Object? raw = data['channel_id'] ?? data['channelId'];
    final String id = raw == null ? '' : raw.toString().trim();
    if (id.isEmpty || id.length > 80) return const ChatPushPayload();
    // Reject values that look like labels rather than ids.
    if (id.contains(' ') || id.contains('@')) return const ChatPushPayload();
    return ChatPushPayload(channelId: id);
  }

  /// Path for go_router after auth. Null when there is nowhere specific to go.
  String? get routePath {
    final String? id = channelId;
    if (id == null || id.isEmpty) return null;
    return '/chat/$id';
  }
}
