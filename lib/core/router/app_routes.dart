class AppRoutes {
  const AppRoutes._();

  static const String splash = '/';
  static const String signIn = '/sign-in';
  static const String selectTeam = '/select-team';

  static const String census = '/census';
  static const String censusIntakeDictate = '/census/intake/dictate';
  static const String censusIntakePhoto = '/census/intake/photo';
  static const String censusPropose = '/census/intake/:intakeId/propose';
  static const String today = '/today';
  static const String scribe = '/scribe';
  static const String rounds = '/rounds';
  static const String learning = '/learning';
  static const String learningReviewQueue = '/learning/review-queue';
  static const String learningTopicQuiz = '/learning/topic';
  static const String learningTopicReads = '/learning/topic/reads';
  static const String tasks = '/tasks';
  static const String chat = '/chat';
  static const String chatSearch = '/chat/search';
  static const String chatNewDm = '/chat/new/dm';
  static const String chatNewGroup = '/chat/new/group';
  static const String chatChannel = '/chat/:channelId';
  static const String chatThread = '/chat/:channelId/thread/:messageId';
  static const String chatSummary = '/chat/:channelId/summary';
  static const String profile = '/profile';

  static const String patient = '/patient/:patientId';
  static const String patientNote = '/patient/:patientId/note';
  static const String patientEvidence = '/patient/:patientId/evidence';
  static const String patientPresentation = '/patient/:patientId/presentation';
  static const String patientSignOut = '/patient/:patientId/sign-out';
  static const String patientTeach = '/patient/:patientId/teach';
  static const String patientTeachQueue = '/patient/:patientId/teach/queue';
  static const String patientTasks = '/patient/:patientId/tasks';
  static const String patientAddSource = '/patient/:patientId/sources/new';
  static const String patientIntakeDictate =
      '/patient/:patientId/intake/dictate';
  static const String patientIntakePhoto = '/patient/:patientId/intake/photo';
  static const String patientFacts = '/patient/:patientId/facts';
  static const String patientAddFact = '/patient/:patientId/facts/new';
  static const String patientPlan = '/patient/:patientId/plan';

  static String censusIntakeDictatePath() => censusIntakeDictate;
  static String censusIntakePhotoPath() => censusIntakePhoto;
  static String censusProposePath(String intakeId) =>
      '/census/intake/$intakeId/propose';

  static String chatChannelPath(String channelId) => '/chat/$channelId';
  static String chatThreadPath(String channelId, String messageId) =>
      '/chat/$channelId/thread/$messageId';
  static String chatSummaryPath(String channelId) =>
      '/chat/$channelId/summary';

  static String patientPath(String patientId) => '/patient/$patientId';
  static String notePath(String patientId) => '/patient/$patientId/note';
  static String evidencePath(String patientId) =>
      '/patient/$patientId/evidence';
  static String presentationPath(String patientId) =>
      '/patient/$patientId/presentation';
  static String signOutPath(String patientId) => '/patient/$patientId/sign-out';
  static String teachPath(String patientId) => '/patient/$patientId/teach';
  static String teachQueuePath(String patientId) =>
      '/patient/$patientId/teach/queue';

  static String topicQuizPath(String topic) =>
      '$learningTopicQuiz?topic=${Uri.encodeComponent(topic)}';
  static String topicReadsPath(String topic) =>
      '$learningTopicReads?topic=${Uri.encodeComponent(topic)}';
  static String patientTasksPath(String patientId) =>
      '/patient/$patientId/tasks';
  static String patientAddSourcePath(String patientId) =>
      '/patient/$patientId/sources/new';
  static String patientIntakeDictatePath(String patientId) =>
      '/patient/$patientId/intake/dictate';
  static String patientIntakePhotoPath(String patientId) =>
      '/patient/$patientId/intake/photo';
  static String patientFactsPath(String patientId) =>
      '/patient/$patientId/facts';
  static String patientAddFactPath(String patientId) =>
      '/patient/$patientId/facts/new';
  static String patientPlanPath(String patientId) => '/patient/$patientId/plan';
}
