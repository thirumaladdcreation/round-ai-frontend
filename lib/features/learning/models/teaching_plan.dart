import 'package:equatable/equatable.dart';
import 'package:round_ai/core/utils/json_utils.dart';

/// Generic census-derived topic. Never carries patient ids or names.
class TeachingTopic extends Equatable {
  const TeachingTopic({
    required this.topic,
    required this.topicKey,
    required this.count,
    this.confirmed = 0,
    this.differential = 0,
    this.bankCount = 0,
  });

  factory TeachingTopic.fromJson(Map<String, dynamic> json) {
    return TeachingTopic(
      topic: Json.string(json['topic']),
      topicKey: Json.string(json['topic_key']),
      count: Json.integer(json['count']),
      confirmed: Json.integer(json['confirmed']),
      differential: Json.integer(json['differential']),
      bankCount: Json.integer(json['bank_count']),
    );
  }

  final String topic;
  final String topicKey;
  final int count;
  final int confirmed;
  final int differential;

  /// Approved bank questions available for this topic.
  final int bankCount;

  String get countLabel {
    final String n = count == 1 ? '1 related problem' : '$count related problems';
    if (bankCount <= 0) return n;
    final String bank = bankCount == 1
        ? '1 bank question'
        : '$bankCount bank questions';
    return '$n · $bank';
  }

  @override
  List<Object?> get props => <Object?>[topicKey, topic, count, bankCount];
}

class TeachingPlan extends Equatable {
  const TeachingPlan({
    required this.date,
    required this.topics,
    this.note = '',
  });

  factory TeachingPlan.fromJson(Map<String, dynamic> json) {
    return TeachingPlan(
      date: Json.string(json['date']),
      topics: Json.maps(json['topics']).map(TeachingTopic.fromJson).toList(),
      note: Json.string(json['note']),
    );
  }

  final String date;
  final List<TeachingTopic> topics;
  final String note;

  @override
  List<Object?> get props => <Object?>[date, topics];
}
