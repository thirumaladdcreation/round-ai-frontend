import 'package:dio/dio.dart';
import 'package:round_ai/core/errors/failures.dart';
import 'package:round_ai/core/errors/result.dart';
import 'package:round_ai/core/network/api_error.dart';
import 'package:round_ai/features/census/data/demo_patients.dart';
import 'package:round_ai/features/learning/models/teaching_plan.dart';
import 'package:round_ai/features/learning/models/teaching_question.dart';
import 'package:round_ai/features/learning/models/teaching_reads.dart';
import 'package:round_ai/features/learning/repository/teaching_repository.dart';
import 'package:round_ai/features/patient/data/patient_workspace.dart';

class DemoTeachingRepository implements TeachingRepository {
  DemoTeachingRepository({DateTime Function()? clock})
    : _clock = clock ?? DateTime.now;

  final DateTime Function() _clock;
  final Set<String> _reported = <String>{};
  final List<ReadingListItem> _readingList = <ReadingListItem>[];
  final Map<String, String> _answers = <String, String>{};

  String _day() {
    final DateTime n = _clock();
    return '${n.year}-${n.month.toString().padLeft(2, '0')}-${n.day.toString().padLeft(2, '0')}';
  }

  @override
  Future<Result<TeachingPlan>> loadPlan({String? date}) async {
    final Map<String, TeachingTopic> map = <String, TeachingTopic>{};
    for (final CensusPatient p in demoPatients) {
      final String key = p.problem.toLowerCase().trim();
      final TeachingTopic? existing = map[key];
      map[key] = TeachingTopic(
        topic: p.problem,
        topicKey: key,
        count: (existing?.count ?? 0) + 1,
        confirmed: (existing?.confirmed ?? 0) + 1,
      );
    }
    return Ok<TeachingPlan>(
      TeachingPlan(
        date: date ?? _day(),
        topics: map.values.toList(),
        note:
            'Topics are generic strings derived from confirmed/differential problems. No patient identifiers.',
      ),
    );
  }

  TeachingQuestion _fromWorkspace(String topic) {
    PatientWorkspace? ws;
    final String topicLower = topic.toLowerCase().trim();
    // Prefer exact topic match so "Elevated Pulse" does not fall through empty.
    for (final PatientWorkspace w in demoWorkspaces) {
      if (w.question.topic.toLowerCase().trim() == topicLower) {
        ws = w;
        break;
      }
    }
    if (ws == null) {
      final String needle = topicLower.split(' ').first;
      for (final PatientWorkspace w in demoWorkspaces) {
        if (w.question.topic.toLowerCase().contains(needle)) {
          ws = w;
          break;
        }
      }
    }
    ws ??= demoWorkspaces.isEmpty ? null : demoWorkspaces.first;
    final TeachItem q = ws?.question ??
        const TeachItem(
          topic: 'General',
          vignette: 'A patient presents with the condition under study.',
          leadIn: 'What is the best next step?',
          options: <String>[
            'Fluid challenge',
            'Immediate dialysis',
            'Observation only',
            'Broaden antibiotics',
          ],
          correctIndex: 0,
          correctExplanation: 'Correct.',
          distractorExplanations: <String>['No', 'No', 'No'],
          objective: 'Apply core concepts',
          takeaway: 'Review sources.',
        );
    final String id = 'demo-mcq-${topic.hashCode.abs()}';
    _answers[id] = String.fromCharCode(65 + q.correctIndex);
    return TeachingQuestion(
      mcqId: id,
      topic: q.topic.isEmpty ? topic : q.topic,
      topicKey: topic.toLowerCase(),
      vignette: q.vignette,
      question: q.leadIn,
      options: <McqOption>[
        for (int i = 0; i < q.options.length; i++)
          McqOption(
            letter: String.fromCharCode(65 + i),
            text: q.options[i],
          ),
      ],
      status: 'approved',
      bank: true,
      learnerLabel: 'Approved bank question',
      notice: 'Educational question. Report any issue with the button provided.',
    );
  }

  @override
  Future<Result<TeachingQuestionsResult>> loadQuestions({
    required String topic,
    int count = 1,
    bool allowGenerate = false,
    String? idempotencyKey,
    CancelToken? cancelToken,
  }) async {
    final TeachingQuestion bank = _fromWorkspace(topic);
    final List<TeachingQuestion> qs = <TeachingQuestion>[
      if (!_reported.contains(bank.mcqId)) bank,
    ];
    if (allowGenerate) {
      final TeachingQuestion draft = TeachingQuestion(
        mcqId: 'demo-ai-${topic.hashCode.abs()}',
        topic: topic,
        topicKey: topic.toLowerCase(),
        vignette: 'AI draft vignette for $topic.',
        question: 'Which statement is most accurate?',
        options: const <McqOption>[
          McqOption(letter: 'A', text: 'Option A'),
          McqOption(letter: 'B', text: 'Option B'),
          McqOption(letter: 'C', text: 'Option C'),
          McqOption(letter: 'D', text: 'Option D'),
        ],
        status: 'ai_generated_unreviewed',
        bank: false,
        adminReviewQueue: true,
        learnerLabel:
            'AI-generated (unreviewed). For education only — report issues. Not yet approved for the bank.',
        notice:
            'AI-generated educational question (unreviewed). Report any issue with the button provided.',
      );
      _answers[draft.mcqId] = 'A';
      if (!_reported.contains(draft.mcqId)) qs.add(draft);
    }
    // One at a time: prefer bank, then drafts when allow_generate.
    final List<TeachingQuestion> safe = qs.take(count).toList();
    return Ok<TeachingQuestionsResult>(
      TeachingQuestionsResult(
        topic: topic,
        topicKey: topic.toLowerCase(),
        questions: safe,
        bankServed: safe.where((TeachingQuestion q) => q.bank).length,
        generated: safe.where((TeachingQuestion q) => !q.bank).length,
      ),
    );
  }

  @override
  Future<Result<TeachingQuestion>> loadQuestion(String mcqId) async {
    if (_reported.contains(mcqId)) {
      return Err<TeachingQuestion>(
        ApiFailure(
          const ApiError(
            code: 'not_approved',
            message: 'This question was reported and is under review.',
            status: 403,
          ),
        ),
      );
    }
    final Result<TeachingPlan> plan = await loadPlan();
    String topic = 'General';
    if (plan case Ok<TeachingPlan>(value: final TeachingPlan p)) {
      if (p.topics.isNotEmpty) topic = p.topics.first.topic;
    }
    final Result<TeachingQuestionsResult> qs = await loadQuestions(topic: topic);
    if (qs case Ok<TeachingQuestionsResult>(value: final TeachingQuestionsResult r)) {
      for (final TeachingQuestion q in r.questions) {
        if (q.mcqId == mcqId) return Ok<TeachingQuestion>(q);
      }
    }
    return Ok<TeachingQuestion>(_fromWorkspace(topic).copyWithId(mcqId));
  }

  @override
  Future<Result<McqAnswerResult>> answer({
    required String mcqId,
    required String choice,
    int? seconds,
  }) async {
    final String correct = _answers[mcqId] ?? 'A';
    final bool ok = choice.toUpperCase() == correct;
    return Ok<McqAnswerResult>(
      McqAnswerResult(
        correct: ok,
        correctAnswer: correct,
        explanation: ok ? 'Correct based on the chart teaching case.' : 'Review the explanation.',
        optionExplanations: <String, String>{
          'A': 'Explanation for A',
          'B': 'Explanation for B',
          'C': 'Explanation for C',
          'D': 'Explanation for D',
        },
        learningObjective: 'Apply core concepts',
        nextReviewAt: _clock().add(Duration(days: ok ? 3 : 1)),
        references: const <String>['12345678'],
      ),
    );
  }

  @override
  Future<Result<void>> report({required String mcqId, String? note}) async {
    _reported.add(mcqId);
    return const Ok<void>(null);
  }

  @override
  Future<Result<TeachingReads>> loadReads({required String topic}) async {
    return Ok<TeachingReads>(
      TeachingReads(
        topic: topic,
        topicKey: topic.toLowerCase(),
        recent: <TeachingReadItem>[
          TeachingReadItem(
            title: 'Recent study on $topic',
            pmid: '11111111',
            label: 'Recent',
            journal: 'Demo Journal',
            date: '2025-06-01',
          ),
        ],
        olderHighDesign: <TeachingReadItem>[
          TeachingReadItem(
            title: 'Older high-design study',
            pmid: '22222222',
            label: 'Older high-design-level evidence',
            note:
                'Selected by study-design filters outside the recent window. Not a curated landmark list.',
          ),
        ],
        guidelinesPubmed: <TeachingReadItem>[
          TeachingReadItem(
            title: 'Practice guideline',
            pmid: '33333333',
            label: 'Guideline',
          ),
        ],
        curatedHighYield: <TeachingReadItem>[
          TeachingReadItem(
            title: 'Curated landmark (admin)',
            pmid: '44444444',
            label: curatedHighYieldLabel,
            highYield: true,
            curated: true,
            whyItMatters: 'Core teaching article',
          ),
        ],
        note:
            '"High-yield" is shown only for admin-curated entries.',
      ),
    );
  }

  @override
  Future<Result<GuidelineUpdatesFeed>> loadGuidelineUpdates() async {
    return const Ok<GuidelineUpdatesFeed>(
      GuidelineUpdatesFeed(
        updates: <TeachingReadItem>[],
        note:
            'Admin-entered guideline updates for topics on your census. Verify against the source.',
      ),
    );
  }

  @override
  Future<Result<List<ReviewQueueItem>>> loadReviewQueue() async {
    return Ok<List<ReviewQueueItem>>(
      <ReviewQueueItem>[
        ReviewQueueItem(
          mcqId: 'demo-review-1',
          topic: demoPatients.isEmpty ? 'General' : demoPatients.first.problem,
          nextReviewAt: _clock(),
          reviewStage: 0,
        ),
      ],
    );
  }

  @override
  Future<Result<List<ReadingListItem>>> loadReadingList() async =>
      Ok<List<ReadingListItem>>(List<ReadingListItem>.of(_readingList));

  @override
  Future<Result<void>> saveToReadingList({
    required String pmid,
    String? title,
  }) async {
    _readingList.add(
      ReadingListItem(
        pmid: pmid,
        title: title ?? 'PMID $pmid',
        url: 'https://pubmed.ncbi.nlm.nih.gov/$pmid/',
        createdAt: _clock(),
      ),
    );
    return const Ok<void>(null);
  }
}

extension on TeachingQuestion {
  TeachingQuestion copyWithId(String id) => TeachingQuestion(
    mcqId: id,
    topic: topic,
    topicKey: topicKey,
    vignette: vignette,
    question: question,
    options: options,
    difficulty: difficulty,
    stage: stage,
    status: status,
    source: source,
    notice: notice,
    learnerLabel: learnerLabel,
    bank: bank,
    adminReviewQueue: adminReviewQueue,
  );
}
