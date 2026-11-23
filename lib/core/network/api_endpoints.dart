/// All REST paths. Keep base URL in env; keep paths here.
///
/// Paths match `roundsai-backend` `src/routes/*.js`. When the backend
/// differs, the backend is the truth.
class ApiEndpoints {
  const ApiEndpoints._();

  static const String health = '/health';
  static const String login = '/auth/login';
  static const String me = '/me';
  static const String templates = '/templates';
  static const String patients = '/patients';

  static String patient(String id) => '/patients/$id';
  static String patientSources(String id) => '/patients/$id/sources';
  static String sourceExtract(String patientId, String sourceId) =>
      '/patients/$patientId/sources/$sourceId/extract';
  static String patientFacts(String id) => '/patients/$id/facts';
  static String patientPlan(String id) => '/patients/$id/plan';

  /// Confirm or reject facts: `{ "fact_ids": [...], "status": "confirmed"|"rejected" }`.
  static String patientFactsReview(String patientId) =>
      '/patients/$patientId/facts/review';

  static String factPatch(String factId) => '/facts/$factId';

  static String patientPlanProposals(String id) =>
      '/patients/$id/plan-proposals';

  static String patientPlanProposalsAccept(String id) =>
      '/patients/$id/plan-proposals/accept';
  static String patientSummary(String id) => '/patients/$id/summary';
  static String patientChanges(String id) => '/patients/$id/changes';
  static String patientAsk(String id) => '/patients/$id/ask';
  static String artifact(String id) => '/artifacts/$id';
  static String artifactReview(String id) => '/artifacts/$id/review';

  /// `GET ?operation=summarize_patient`: saved summaries, newest is current.
  static String patientArtifacts(String id) => '/patients/$id/artifacts';

  /// `POST { note_type, inputs }` makes a note draft.
  static String patientNotes(String id) => '/patients/$id/notes';

  /// Scribe: one dictation → structured note with transcript spans.
  static String patientNotesFromDictation(String id) =>
      '/patients/$id/notes/from-dictation';

  /// `PATCH` note sections. `POST .../sections/:key/rewrite` proposes new text
  /// without applying it. `GET .../export` is the clean text.
  static String artifactSectionRewrite(String id, String sectionKey) =>
      '/artifacts/$id/sections/$sectionKey/rewrite';
  static String artifactExport(String id) => '/artifacts/$id/export';
  static String artifactVersions(String id) => '/artifacts/$id/versions';
  static String artifactVersionRestore(String id, int version) =>
      '/artifacts/$id/versions/$version/restore';

  static String patientProblems(String id) => '/patients/$id/problems';
  static String problemsSuggest(String id) => '/patients/$id/problems/suggest';

  /// `{ "action": "accept" | "differential" | "reject" }`.
  static String problemDecision(String patientId, String problemId) =>
      '/patients/$patientId/problems/$problemId/decision';

  /// The passage and source behind one chart fact.
  static String factSource(String factId) => '/facts/$factId/source';

  /// POST { problem_id } or { topic } searches the literature. Only
  /// retrieved studies come back.
  static String patientEvidence(String id) => '/patients/$id/evidence';

  /// POST { problem_id } makes a question. POST .../answer submits one
  /// choice and returns the key. POST .../report reports a problem.
  static String patientMcq(String id) => '/patients/$id/mcq';
  static String mcqAnswer(String id) => '/mcq/$id/answer';
  static String mcqReport(String id) => '/mcq/$id/report';
  static String mcqGet(String id) => '/mcq/$id';

  /// GET lists, POST { title, owner?, due_at? } adds one by hand.
  /// POST .../propose suggests tasks from the saved plan.
  static String patientTaskList(String id) => '/patients/$id/tasks';
  static String tasksPropose(String id) => '/patients/$id/tasks/propose';
  static String taskAccept(String id) => '/tasks/$id/accept';
  static String taskDismiss(String id) => '/tasks/$id/dismiss';
  static String taskComplete(String id) => '/tasks/$id/complete';

  /// POST { contingencies: [{ if, then }] }.
  static String patientSignout(String id) => '/patients/$id/signout';

  // ---- M2 Scribe ----

  /// Multipart or JSON base64: audio|image → source + pending facts.
  static String patientIntake(String id) => '/patients/$id/intake';

  /// Audio → text only (for note field dictation).
  static const String transcribe = '/transcribe';

  /// Photo/voice → proposed patients only (nothing created yet).
  static const String censusIntake = '/census/intake';

  /// Confirm or skip proposed rows from a census intake.
  static String censusIntakeConfirm(String intakeId) =>
      '/census/intake/$intakeId/confirm';

  /// JSON + plain-text printable list. Never AI-ranked.
  static const String censusExport = '/census/export';

  /// ICD-10-CM suggestions (draft artifact; not on the problem yet).
  static String codingSuggest(String id) => '/patients/$id/coding/suggest';

  /// Clinician accept writes `problems.code_suggestion`.
  static String codingAccept(String patientId, String problemId) =>
      '/patients/$patientId/problems/$problemId/coding/accept';

  // ---- M3 Round ----

  /// Oral presentation draft (~150–220 words).
  static String patientPresent(String id) => '/patients/$id/present';

  /// Approved checklist reminders ("Prompt for your consideration").
  static String patientReminders(String id) => '/patients/$id/reminders';

  static String reminderAck(String patientId, String ruleId) =>
      '/patients/$patientId/reminders/$ruleId/ack';

  /// Deterministic day brief for the team.
  static const String roundBrief = '/round/brief';

  /// Bulk pre-generate presentations; partial failures are explicit.
  static const String roundBriefPrepare = '/round/brief/prepare';

  // ---- M4 Teaching ----

  static const String teachingPlan = '/teaching/plan';
  static const String teachingQuestions = '/teaching/questions';
  static const String teachingReads = '/teaching/reads';
  static const String teachingGuidelineUpdates = '/teaching/guideline-updates';

  static const String learningReviewQueue = '/learning/review-queue';
  static const String learningStats = '/learning/stats';
  static const String learningGenerate = '/learning/generate';
  static const String readingList = '/reading-list';

  // ---- M5 Team chat ----

  static const String channels = '/channels';
  static const String channelsUnread = '/channels/unread';
  static const String channelsSearch = '/channels/search';
  static const String chatStream = '/stream';
  static const String chatDevices = '/chat/devices';

  static String channelMessages(String id) => '/channels/$id/messages';
  static String channelRead(String id) => '/channels/$id/read';
  static String channelSummarize(String id) => '/channels/$id/summarize';
  static String message(String id) => '/messages/$id';
  static String patientChannel(String patientId) =>
      '/patients/$patientId/channel';
}
