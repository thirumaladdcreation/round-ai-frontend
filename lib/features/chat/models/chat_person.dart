import 'package:equatable/equatable.dart';

/// A teammate known to the client for @ mentions and DM/group pickers.
///
/// The backend has no non-admin teammates list. The directory is filled from
/// demo seeds and from senders / DM titles seen in-session.
class ChatPerson extends Equatable {
  const ChatPerson({
    required this.id,
    required this.displayName,
  });

  final String id;

  /// First token is what `@Mention` matches on the server.
  final String displayName;

  String get mentionToken {
    final String trimmed = displayName.trim();
    if (trimmed.isEmpty) return id;
    return trimmed.split(RegExp(r'\s+')).first;
  }

  @override
  List<Object> get props => <Object>[id, displayName];
}
