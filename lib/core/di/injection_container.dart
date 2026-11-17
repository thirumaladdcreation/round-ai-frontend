import 'package:flutter/foundation.dart';
import 'package:round_ai/core/config/app_environment.dart';
import 'package:round_ai/core/network/api_client.dart';
import 'package:round_ai/core/router/app_router.dart';
import 'package:round_ai/core/storage/app_storage.dart';
import 'package:round_ai/core/storage/session_store.dart';
import 'package:round_ai/core/sync/census_sync.dart';
import 'package:round_ai/core/utils/app_log.dart';
import 'package:round_ai/features/ai/repository/ai_repository.dart';
import 'package:round_ai/features/ai/repository/ai_repository_impl.dart';
import 'package:round_ai/features/ai/repository/demo_ai_repository.dart';
import 'package:round_ai/features/authentication/repository/auth_repository.dart';
import 'package:round_ai/features/authentication/repository/auth_repository_impl.dart';
import 'package:round_ai/features/authentication/repository/demo_auth_repository.dart';
import 'package:round_ai/features/authentication/repository/demo_profile_repository.dart';
import 'package:round_ai/features/authentication/repository/profile_repository.dart';
import 'package:round_ai/features/authentication/repository/profile_repository_impl.dart';
import 'package:round_ai/features/census/repository/census_repository.dart';
import 'package:round_ai/features/census/repository/census_repository_impl.dart';
import 'package:round_ai/features/census/repository/demo_census_repository.dart';
import 'package:round_ai/features/chat/cache/chat_people_directory.dart';
import 'package:round_ai/features/chat/chat_unread_badge.dart';
import 'package:round_ai/features/chat/repository/chat_repository.dart';
import 'package:round_ai/features/chat/repository/chat_repository_impl.dart';
import 'package:round_ai/features/chat/repository/demo_chat_repository.dart';
import 'package:round_ai/features/chat/services/chat_push_controller.dart';
import 'package:round_ai/features/chat/services/chat_push_permission.dart';
import 'package:round_ai/features/chat/services/chat_push_token_source.dart';
import 'package:round_ai/features/chat/services/chat_realtime_controller.dart';
import 'package:round_ai/features/chat/services/chat_stream_client.dart';
import 'package:round_ai/features/evidence/repository/demo_evidence_repository.dart';
import 'package:round_ai/features/evidence/repository/evidence_repository.dart';
import 'package:round_ai/features/evidence/repository/evidence_repository_impl.dart';
import 'package:round_ai/features/learning/repository/demo_teach_repository.dart';
import 'package:round_ai/features/learning/repository/demo_teaching_repository.dart';
import 'package:round_ai/features/learning/repository/teach_repository.dart';
import 'package:round_ai/features/learning/repository/teach_repository_impl.dart';
import 'package:round_ai/features/learning/repository/teaching_repository.dart';
import 'package:round_ai/features/learning/repository/teaching_repository_impl.dart';
import 'package:round_ai/features/notes/repository/demo_notes_repository.dart';
import 'package:round_ai/features/notes/repository/notes_repository.dart';
import 'package:round_ai/features/notes/repository/notes_repository_impl.dart';
import 'package:round_ai/features/patient/repository/chart_data_repository.dart';
import 'package:round_ai/features/patient/repository/chart_data_repository_impl.dart';
import 'package:round_ai/features/patient/repository/demo_chart_data_repository.dart';
import 'package:round_ai/features/patient/repository/demo_patient_repository.dart';
import 'package:round_ai/features/patient/repository/patient_repository.dart';
import 'package:round_ai/features/patient/repository/patient_repository_impl.dart';
import 'package:round_ai/features/scribe/repository/demo_intake_repository.dart';
import 'package:round_ai/features/scribe/repository/intake_repository.dart';
import 'package:round_ai/features/scribe/repository/intake_repository_impl.dart';
import 'package:round_ai/features/problems/repository/demo_problems_repository.dart';
import 'package:round_ai/features/problems/repository/problems_repository.dart';
import 'package:round_ai/features/problems/repository/problems_repository_impl.dart';
import 'package:round_ai/features/signout/repository/demo_signout_repository.dart';
import 'package:round_ai/features/signout/repository/signout_repository.dart';
import 'package:round_ai/features/signout/repository/signout_repository_impl.dart';
import 'package:round_ai/features/splash/repository/demo_splash_repository.dart';
import 'package:round_ai/features/splash/repository/splash_repository.dart';
import 'package:round_ai/features/splash/repository/splash_repository_impl.dart';
import 'package:round_ai/features/tasks/repository/demo_tasks_repository.dart';
import 'package:round_ai/features/tasks/repository/tasks_repository.dart';
import 'package:round_ai/features/tasks/repository/tasks_repository_impl.dart';
import 'package:round_ai/features/rounds/repository/demo_round_repository.dart';
import 'package:round_ai/features/rounds/repository/round_repository.dart';
import 'package:round_ai/features/rounds/repository/round_repository_impl.dart';
import 'package:round_ai/features/today/repository/demo_home_repository.dart';
import 'package:round_ai/features/today/repository/home_repository.dart';
import 'package:round_ai/features/today/repository/home_repository_impl.dart';
import 'package:round_ai/features/team_selection/repository/demo_team_repository.dart';
import 'package:round_ai/features/team_selection/repository/team_repository.dart';
import 'package:round_ai/features/team_selection/repository/team_repository_impl.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Manual DI — one place to build data / domain / presentation.
class InjectionContainer {
  InjectionContainer._();

  static final InjectionContainer instance = InjectionContainer._();

  late final SharedPreferences _sharedPreferences;
  late final AppStorage appStorage;
  late final CensusSync censusSync;
  late final ApiClient apiClient;
  late final AuthRepository authRepository;
  late final ProfileRepository profileRepository;
  late final SplashRepository splashRepository;
  late final TeamRepository teamRepository;
  late final CensusRepository censusRepository;
  late final PatientRepository patientRepository;
  late final ChartDataRepository chartDataRepository;
  late final HomeRepository homeRepository;
  late final RoundRepository roundRepository;
  late final AiRepository aiRepository;
  late final NotesRepository notesRepository;
  late final IntakeRepository intakeRepository;
  late final ProblemsRepository problemsRepository;
  late final EvidenceRepository evidenceRepository;
  late final TeachRepository teachRepository;
  late final TeachingRepository teachingRepository;
  late final TasksRepository tasksRepository;
  late final SignOutRepository signOutRepository;
  late final ChatRepository chatRepository;
  late final ChatStreamClient chatStreamClient;
  late final ChatRealtimeController chatRealtime;
  late final ChatPushController chatPush;
  late final ChatUnreadBadge chatUnreadBadge;
  late final ChatPeopleDirectory chatPeople;

  /// Bumps when the backend rejects the token (401). The app listens and
  /// returns to sign-in.
  final ValueNotifier<int> sessionEnded = ValueNotifier<int>(0);

  /// [tokenStore] is only passed by tests. The app uses secure storage.
  Future<void> init({TokenStore? tokenStore}) async {
    _sharedPreferences = await SharedPreferences.getInstance();
    final SessionStore session = SessionStore(tokenStore ?? SecureTokenStore());
    appStorage = AppStorage(_sharedPreferences, session: session);
    await appStorage.purgeLegacyToken();
    await session.restore();
    censusSync = CensusSync();
    chatUnreadBadge = ChatUnreadBadge();
    chatPeople = ChatPeopleDirectory();
    apiClient = ApiClient(session: session, onUnauthorized: _endSession);
    if (AppEnvironment.useDemo) {
      profileRepository = DemoProfileRepository(appStorage);
      authRepository = DemoAuthRepository(appStorage);
      teamRepository = DemoTeamRepository(appStorage);
      splashRepository = DemoSplashRepository(appStorage);
      final DemoCensusRepository census = DemoCensusRepository();
      censusRepository = census;
      patientRepository = DemoPatientRepository(census);
      chartDataRepository = DemoChartDataRepository();
      roundRepository = DemoRoundRepository();
      homeRepository = DemoHomeRepository(
        appStorage,
        roundRepository: roundRepository,
      );
      aiRepository = DemoAiRepository();
      notesRepository = DemoNotesRepository();
      intakeRepository = DemoIntakeRepository();
      problemsRepository = DemoProblemsRepository();
      evidenceRepository = DemoEvidenceRepository();
      teachRepository = DemoTeachRepository();
      teachingRepository = DemoTeachingRepository();
      tasksRepository = DemoTasksRepository();
      signOutRepository = DemoSignOutRepository();
      chatRepository = DemoChatRepository();
      chatStreamClient = NoOpChatStreamClient();
      chatRealtime = ChatRealtimeController(client: chatStreamClient);
      chatPeople.seedDemo();
      _initChatPush();
    } else {
      profileRepository = ProfileRepositoryImpl(apiClient, appStorage);
      authRepository = AuthRepositoryImpl(
        apiClient,
        appStorage,
        profileRepository,
      );
      teamRepository = TeamRepositoryImpl(profileRepository, appStorage);
      splashRepository = SplashRepositoryImpl(appStorage, profileRepository);
      censusRepository = CensusRepositoryImpl(apiClient, appStorage);
      patientRepository = PatientRepositoryImpl(apiClient);
      chartDataRepository = ChartDataRepositoryImpl(apiClient);
      roundRepository = RoundRepositoryImpl(apiClient);
      homeRepository = HomeRepositoryImpl(
        censusRepository,
        appStorage,
        roundRepository: roundRepository,
      );
      aiRepository = AiRepositoryImpl(apiClient);
      notesRepository = NotesRepositoryImpl(apiClient);
      intakeRepository = IntakeRepositoryImpl(apiClient);
      problemsRepository = ProblemsRepositoryImpl(apiClient);
      evidenceRepository = EvidenceRepositoryImpl(apiClient);
      teachRepository = TeachRepositoryImpl(apiClient);
      teachingRepository = TeachingRepositoryImpl(apiClient);
      tasksRepository = TasksRepositoryImpl(apiClient);
      signOutRepository = SignOutRepositoryImpl(apiClient);
      chatRepository = ChatRepositoryImpl(apiClient);
      chatStreamClient = DioChatStreamClient(apiClient);
      chatRealtime = ChatRealtimeController(client: chatStreamClient);
      _initChatPush();
    }
    AppLog.line('[DI] ready (${AppEnvironment.useDemo ? 'demo' : 'backend'})');
  }

  void _initChatPush() {
    chatPush = ChatPushController(
      chat: chatRepository,
      storage: appStorage,
      tokenSource: StubChatPushTokenSource(storage: appStorage),
      permission: const PermissionHandlerChatPushPermission(),
      isLoggedIn: () => isLoggedIn,
      navigate: (String path) => AppRouter.router.go(path),
    );
  }

  bool get isLoggedIn => appStorage.hasAuthToken;

  /// Ends the session: token (memory and secure storage), saved team, the
  /// loaded profile. Cached patient data is cleared here too once it exists.
  Future<void> logout() async {
    chatRealtime.clear();
    chatStreamClient.clear();
    chatRepository.clearLocalState();
    chatUnreadBadge.clear();
    chatPeople.clear();
    await chatPush.clear();
    profileRepository.clear();
    await appStorage.clearAuthSession();
  }

  Future<void> _endSession() async {
    await logout();
    sessionEnded.value++;
  }
}
