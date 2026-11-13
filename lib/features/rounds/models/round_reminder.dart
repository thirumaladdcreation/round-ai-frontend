import 'package:equatable/equatable.dart';
import 'package:round_ai/core/utils/json_utils.dart';

/// Fixed framing for approved check-rules. Never an order or finding.
const String reminderFrame = 'Prompt for your consideration';

const String remindersEmptyMessage =
    'No approved reminders for this patient\'s problems. '
    'In Admin → Reminder rules, approve a draft (for example pneumonia or '
    'stroke) so prompts like CVA tenderness appear here.';

enum ReminderAckState { checked, notApplicable, snoozed }

extension ReminderAckStateWire on ReminderAckState {
  String get wire => switch (this) {
    ReminderAckState.checked => 'checked',
    ReminderAckState.notApplicable => 'not_applicable',
    ReminderAckState.snoozed => 'snoozed',
  };

  String get label => switch (this) {
    ReminderAckState.checked => 'Checked',
    ReminderAckState.notApplicable => 'Not applicable',
    ReminderAckState.snoozed => 'Snooze',
  };

  static ReminderAckState? tryParse(String? raw) {
    switch (raw) {
      case 'checked':
        return ReminderAckState.checked;
      case 'not_applicable':
        return ReminderAckState.notApplicable;
      case 'snoozed':
        return ReminderAckState.snoozed;
      default:
        return null;
    }
  }
}

class ReminderAck extends Equatable {
  const ReminderAck({required this.state, this.note, this.at});

  factory ReminderAck.fromJson(Map<String, dynamic> json) {
    return ReminderAck(
      state:
          ReminderAckStateWire.tryParse(Json.string(json['state'])) ??
          ReminderAckState.checked,
      note: Json.stringOrNull(json['note']),
      at: Json.date(json['at']),
    );
  }

  final ReminderAckState state;
  final String? note;
  final DateTime? at;

  @override
  List<Object?> get props => <Object?>[state, note, at];
}

class ReminderPrompt extends Equatable {
  const ReminderPrompt({required this.text, this.frame = reminderFrame});

  factory ReminderPrompt.fromJson(Map<String, dynamic> json) {
    return ReminderPrompt(
      text: Json.firstString(json, const <String>['text', 'prompt', 'body']),
      frame: Json.string(json['frame'], reminderFrame),
    );
  }

  final String text;
  final String frame;

  @override
  List<Object?> get props => <Object?>[text, frame];
}

class CompareFact extends Equatable {
  const CompareFact({
    required this.factId,
    required this.label,
    required this.value,
    this.unit = '',
    this.eventTime,
    this.sourceId,
    this.sourcePassage,
  });

  factory CompareFact.fromJson(Map<String, dynamic> json) {
    return CompareFact(
      factId: Json.string(json['fact_id'] ?? json['id']),
      label: Json.string(json['label']),
      value: Json.string(json['value']),
      unit: Json.string(json['unit']),
      eventTime: Json.stringOrNull(json['event_time']),
      sourceId: Json.stringOrNull(json['source_id']),
      sourcePassage: Json.stringOrNull(json['source_passage']),
    );
  }

  final String factId;
  final String label;
  final String value;
  final String unit;
  final String? eventTime;
  final String? sourceId;
  final String? sourcePassage;

  String get display => unit.isEmpty ? '$label · $value' : '$label · $value $unit';

  @override
  List<Object?> get props => <Object?>[factId, label, value];
}

class YesterdayCompareBlock extends Equatable {
  const YesterdayCompareBlock({
    this.message = '',
    this.facts = const <CompareFact>[],
  });

  factory YesterdayCompareBlock.fromJson(Map<String, dynamic> json) {
    return YesterdayCompareBlock(
      message: Json.string(json['message']),
      facts: Json.maps(json['facts']).map(CompareFact.fromJson).toList(),
    );
  }

  final String message;
  final List<CompareFact> facts;

  @override
  List<Object?> get props => <Object?>[message, facts];
}

class YesterdayComparison extends Equatable {
  const YesterdayComparison({
    required this.ruleId,
    required this.ruleName,
    this.frame = reminderFrame,
    this.compare,
  });

  factory YesterdayComparison.fromJson(Map<String, dynamic> json) {
    final Map<String, dynamic> compare = Json.map(json['compare']);
    return YesterdayComparison(
      ruleId: Json.string(json['rule_id']),
      ruleName: Json.string(json['rule_name'] ?? json['name']),
      frame: Json.string(json['frame'], reminderFrame),
      compare: compare.isEmpty ? null : YesterdayCompareBlock.fromJson(compare),
    );
  }

  final String ruleId;
  final String ruleName;
  final String frame;
  final YesterdayCompareBlock? compare;

  @override
  List<Object?> get props => <Object?>[ruleId, ruleName, compare];
}

class RoundReminder extends Equatable {
  const RoundReminder({
    required this.ruleId,
    required this.name,
    this.frame = reminderFrame,
    this.prompts = const <ReminderPrompt>[],
    this.matchedProblems = const <String>[],
    this.compareYesterday,
    this.ack,
  });

  factory RoundReminder.fromJson(Map<String, dynamic> json) {
    final Object? compareRaw = json['compare_yesterday'];
    final Map<String, dynamic> compare = Json.map(compareRaw);
    final Map<String, dynamic> ack = Json.map(json['ack']);
    return RoundReminder(
      ruleId: Json.string(json['rule_id']),
      name: Json.string(json['name']),
      frame: Json.string(json['frame'] ?? json['framing'], reminderFrame),
      prompts: Json.maps(json['prompts']).map(ReminderPrompt.fromJson).toList(),
      matchedProblems: Json.strings(json['matched_problems']),
      compareYesterday: compareRaw == null || compare.isEmpty
          ? null
          : YesterdayCompareBlock.fromJson(compare),
      ack: ack.isEmpty ? null : ReminderAck.fromJson(ack),
    );
  }

  final String ruleId;
  final String name;
  final String frame;
  final List<ReminderPrompt> prompts;
  final List<String> matchedProblems;
  final YesterdayCompareBlock? compareYesterday;
  final ReminderAck? ack;

  RoundReminder copyWith({ReminderAck? ack}) {
    return RoundReminder(
      ruleId: ruleId,
      name: name,
      frame: frame,
      prompts: prompts,
      matchedProblems: matchedProblems,
      compareYesterday: compareYesterday,
      ack: ack ?? this.ack,
    );
  }

  @override
  List<Object?> get props => <Object?>[ruleId, name, ack, prompts];
}

class ReminderListResult extends Equatable {
  const ReminderListResult({
    required this.date,
    required this.reminders,
    this.frame = reminderFrame,
    this.note = '',
  });

  factory ReminderListResult.fromJson(Map<String, dynamic> json) {
    return ReminderListResult(
      date: Json.string(json['date']),
      frame: Json.string(json['frame'], reminderFrame),
      reminders: Json.maps(
        json['reminders'],
      ).map(RoundReminder.fromJson).toList(),
      note: Json.string(json['note']),
    );
  }

  final String date;
  final String frame;
  final List<RoundReminder> reminders;
  final String note;

  @override
  List<Object?> get props => <Object?>[date, reminders];
}
