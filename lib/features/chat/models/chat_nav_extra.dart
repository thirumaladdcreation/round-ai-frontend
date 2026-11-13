import 'package:round_ai/features/chat/models/chat_channel.dart';
import 'package:round_ai/features/chat/models/chat_message.dart';
import 'package:round_ai/features/chat/models/chat_summary_draft.dart';

/// go_router `extra` for chat screens — never put labels in the URL.
class ChatChannelExtra {
  const ChatChannelExtra({
    this.channel,
    this.highlightMessageId,
    this.patientId,
    this.patientLabel,
  });

  final ChatChannel? channel;
  final String? highlightMessageId;

  /// When set, the channel header can link back to the patient chart.
  final String? patientId;

  /// Room / display name shown inside the app only (not in deep links).
  final String? patientLabel;
}

class ChatSummaryExtra {
  const ChatSummaryExtra({required this.draft, this.channelTitle});

  final ChatSummaryDraft draft;
  final String? channelTitle;
}

class ChatThreadExtra {
  const ChatThreadExtra({
    required this.parent,
    this.channel,
  });

  final ChatMessage parent;
  final ChatChannel? channel;
}
