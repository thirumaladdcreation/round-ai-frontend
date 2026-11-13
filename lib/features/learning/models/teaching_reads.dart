import 'package:equatable/equatable.dart';
import 'package:round_ai/core/utils/json_utils.dart';
import 'package:round_ai/features/learning/models/teaching_question.dart';

class TeachingReadItem extends Equatable {
  const TeachingReadItem({
    required this.title,
    this.pmid = '',
    this.url = '',
    this.citation = '',
    this.journal = '',
    this.date = '',
    this.label = '',
    this.whyItMatters = '',
    this.note = '',
    this.highYield = false,
    this.curated = false,
    this.verify = '',
    this.organization = '',
    this.publishedDate = '',
    this.id = '',
  });

  factory TeachingReadItem.fromJson(Map<String, dynamic> json) {
    final String pmid = Json.string(json['pmid']);
    String url = Json.string(json['url']);
    if (url.isEmpty && pmid.isNotEmpty) {
      url = 'https://pubmed.ncbi.nlm.nih.gov/$pmid/';
    }
    return TeachingReadItem(
      id: Json.string(json['curated_id'] ?? json['id']),
      title: Json.string(json['title']),
      pmid: pmid,
      url: url,
      citation: Json.string(json['citation']),
      journal: Json.string(json['journal']),
      date: Json.string(json['date'] ?? json['published_date']),
      label: Json.string(json['label']),
      whyItMatters: Json.string(json['why_it_matters'] ?? json['summary_by_admin']),
      note: Json.string(json['note']),
      highYield: Json.boolean(json['high_yield']),
      curated: Json.boolean(json['curated']),
      verify: Json.string(json['verify']),
      organization: Json.string(json['organization']),
      publishedDate: Json.string(json['published_date']),
    );
  }

  final String id;
  final String title;
  final String pmid;
  final String url;
  final String citation;
  final String journal;
  final String date;
  final String label;
  final String whyItMatters;
  final String note;
  final bool highYield;
  final bool curated;
  final String verify;
  final String organization;
  final String publishedDate;

  Uri? get externalUri {
    if (url.isNotEmpty) return Uri.tryParse(url);
    if (pmid.isNotEmpty) {
      return Uri.tryParse('https://pubmed.ncbi.nlm.nih.gov/$pmid/');
    }
    return null;
  }

  bool get canSaveToReadingList => pmid.isNotEmpty;

  @override
  List<Object?> get props => <Object?>[title, pmid, url, highYield];
}

class TeachingReads extends Equatable {
  const TeachingReads({
    required this.topic,
    required this.topicKey,
    this.recent = const <TeachingReadItem>[],
    this.olderHighDesign = const <TeachingReadItem>[],
    this.guidelinesPubmed = const <TeachingReadItem>[],
    this.curatedHighYield = const <TeachingReadItem>[],
    this.guidelineUpdates = const <TeachingReadItem>[],
    this.retrievalError,
    this.note = '',
  });

  factory TeachingReads.fromJson(Map<String, dynamic> json) {
    return TeachingReads(
      topic: Json.string(json['topic']),
      topicKey: Json.string(json['topic_key']),
      recent: Json.maps(json['recent']).map(TeachingReadItem.fromJson).toList(),
      olderHighDesign: Json.maps(
        json['older_high_design'],
      ).map(TeachingReadItem.fromJson).toList(),
      guidelinesPubmed: Json.maps(
        json['guidelines_pubmed'],
      ).map(TeachingReadItem.fromJson).toList(),
      curatedHighYield: Json.maps(json['curated_high_yield'])
          .map(TeachingReadItem.fromJson)
          .map(
            (TeachingReadItem i) => TeachingReadItem(
              id: i.id,
              title: i.title,
              pmid: i.pmid,
              url: i.url,
              citation: i.citation,
              journal: i.journal,
              date: i.date,
              label: i.label.isEmpty ? curatedHighYieldLabel : i.label,
              whyItMatters: i.whyItMatters,
              note: i.note,
              highYield: true,
              curated: true,
              verify: i.verify,
              organization: i.organization,
              publishedDate: i.publishedDate,
            ),
          )
          .toList(),
      guidelineUpdates: Json.maps(
        json['guideline_updates'],
      ).map(TeachingReadItem.fromJson).toList(),
      retrievalError: Json.stringOrNull(json['retrieval_error']),
      note: Json.string(json['note']),
    );
  }

  final String topic;
  final String topicKey;
  final List<TeachingReadItem> recent;
  final List<TeachingReadItem> olderHighDesign;
  final List<TeachingReadItem> guidelinesPubmed;
  final List<TeachingReadItem> curatedHighYield;
  final List<TeachingReadItem> guidelineUpdates;
  final String? retrievalError;
  final String note;

  bool get isEmpty =>
      recent.isEmpty &&
      olderHighDesign.isEmpty &&
      guidelinesPubmed.isEmpty &&
      curatedHighYield.isEmpty &&
      guidelineUpdates.isEmpty;

  @override
  List<Object?> get props => <Object?>[topic, recent, curatedHighYield];
}

class GuidelineUpdatesFeed extends Equatable {
  const GuidelineUpdatesFeed({
    required this.updates,
    this.note = '',
  });

  factory GuidelineUpdatesFeed.fromJson(Map<String, dynamic> json) {
    return GuidelineUpdatesFeed(
      updates: Json.maps(
        json['updates'],
      ).map(TeachingReadItem.fromJson).toList(),
      note: Json.string(json['note']),
    );
  }

  final List<TeachingReadItem> updates;
  final String note;

  @override
  List<Object?> get props => <Object?>[updates];
}

class ReadingListItem extends Equatable {
  const ReadingListItem({
    required this.pmid,
    required this.title,
    required this.url,
    this.createdAt,
  });

  factory ReadingListItem.fromJson(Map<String, dynamic> json) {
    return ReadingListItem(
      pmid: Json.string(json['pmid']),
      title: Json.string(json['title']),
      url: Json.string(json['url']),
      createdAt: Json.date(json['created_at']),
    );
  }

  final String pmid;
  final String title;
  final String url;
  final DateTime? createdAt;

  @override
  List<Object?> get props => <Object?>[pmid, title];
}
