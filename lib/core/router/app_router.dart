import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:round_ai/core/config/app_environment.dart';
import 'package:round_ai/core/config/app_features.dart';
import 'package:round_ai/core/config/shell_tabs.dart';
import 'package:round_ai/core/router/app_routes.dart';
import 'package:round_ai/features/authentication/screens/sign_in_screen.dart';
import 'package:round_ai/features/census/models/census_intake.dart';
import 'package:round_ai/features/census/screens/census_intake_screen.dart';
import 'package:round_ai/features/census/screens/census_propose_screen.dart';
import 'package:round_ai/features/census/screens/census_screen.dart';
import 'package:round_ai/features/census/screens/main_shell.dart';
import 'package:round_ai/features/ai/models/ai_envelope.dart';
import 'package:round_ai/features/chat/models/chat_channel.dart';
import 'package:round_ai/features/chat/models/chat_message.dart';
import 'package:round_ai/features/chat/models/chat_nav_extra.dart';
import 'package:round_ai/features/chat/models/chat_summary_draft.dart';
import 'package:round_ai/features/chat/screens/chat_channel_screen.dart';
import 'package:round_ai/features/chat/screens/chat_channels_screen.dart';
import 'package:round_ai/features/chat/screens/chat_new_conversation_screen.dart';
import 'package:round_ai/features/chat/screens/chat_search_screen.dart';
import 'package:round_ai/features/chat/screens/chat_summary_draft_screen.dart';
import 'package:round_ai/features/chat/screens/chat_thread_screen.dart';
import 'package:round_ai/features/learning/screens/learning_screen.dart';
import 'package:round_ai/features/evidence/screens/evidence_search_screen.dart';
import 'package:round_ai/features/learning/screens/spaced_review_screen.dart';
import 'package:round_ai/features/learning/screens/teach_draft_screen.dart';
import 'package:round_ai/features/learning/screens/teach_queue_screen.dart';
import 'package:round_ai/features/learning/screens/teach_screen.dart';
import 'package:round_ai/features/learning/screens/topic_quiz_screen.dart';
import 'package:round_ai/features/learning/screens/topic_reads_screen.dart';
import 'package:round_ai/features/signout/screens/signout_draft_screen.dart';
import 'package:round_ai/features/tasks/screens/patient_tasks_screen.dart';
import 'package:round_ai/features/tasks/screens/team_tasks_screen.dart';
import 'package:round_ai/features/patient/screens/add_fact_screen.dart';
import 'package:round_ai/features/patient/screens/add_source_screen.dart';
import 'package:round_ai/features/patient/screens/evidence_screen.dart';
import 'package:round_ai/features/patient/screens/facts_review_screen.dart';
import 'package:round_ai/features/patient/screens/plan_editor_screen.dart';
import 'package:round_ai/features/notes/screens/note_draft_screen.dart';
import 'package:round_ai/features/patient/screens/note_screen.dart';
import 'package:round_ai/features/patient/screens/patient_overview_screen.dart';
import 'package:round_ai/features/patient/screens/presentation_screen.dart';
import 'package:round_ai/features/patient/screens/sign_out_screen.dart';
import 'package:round_ai/features/profile/screens/profile_screen.dart';
import 'package:round_ai/features/rounds/screens/rounds_screen.dart';
import 'package:round_ai/features/scribe/screens/patient_intake_screen.dart';
import 'package:round_ai/features/scribe/screens/scribe_hub_screen.dart';
import 'package:round_ai/features/tasks/screens/tasks_screen.dart';
import 'package:round_ai/features/splash/screens/splash_screen.dart';
import 'package:round_ai/features/team_selection/screens/select_team_screen.dart';
import 'package:round_ai/features/today/screens/today_screen.dart';

class AppRouter {
  const AppRouter._();

  static final GlobalKey<NavigatorState> rootNavigatorKey =
      GlobalKey<NavigatorState>(debugLabel: 'root');

  static final GlobalKey<NavigatorState> _todayNavigatorKey =
      GlobalKey<NavigatorState>(debugLabel: 'today');
  static final GlobalKey<NavigatorState> _censusNavigatorKey =
      GlobalKey<NavigatorState>(debugLabel: 'census');
  static final GlobalKey<NavigatorState> _scribeNavigatorKey =
      GlobalKey<NavigatorState>(debugLabel: 'scribe');
  static final GlobalKey<NavigatorState> _roundsNavigatorKey =
      GlobalKey<NavigatorState>(debugLabel: 'rounds');
  static final GlobalKey<NavigatorState> _learningNavigatorKey =
      GlobalKey<NavigatorState>(debugLabel: 'learning');
  static final GlobalKey<NavigatorState> _profileNavigatorKey =
      GlobalKey<NavigatorState>(debugLabel: 'profile');
  static final GlobalKey<NavigatorState> _tasksNavigatorKey =
      GlobalKey<NavigatorState>(debugLabel: 'tasks');
  static final GlobalKey<NavigatorState> _chatNavigatorKey =
      GlobalKey<NavigatorState>(debugLabel: 'chat');

  static final GoRouter router = GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: AppRoutes.splash,
    redirect: (BuildContext context, GoRouterState state) =>
        redirectFor(state.uri.path),
    routes: <RouteBase>[
      GoRoute(path: AppRoutes.splash, builder: (_, _) => const SplashScreen()),
      GoRoute(path: AppRoutes.signIn, builder: (_, _) => const SignInScreen()),
      GoRoute(
        path: AppRoutes.selectTeam,
        builder: (_, _) => const SelectTeamScreen(),
      ),
      GoRoute(
        path: AppRoutes.censusIntakeDictate,
        parentNavigatorKey: rootNavigatorKey,
        builder: (_, _) =>
            const CensusIntakeScreen(mode: CensusIntakeMode.dictate),
      ),
      GoRoute(
        path: AppRoutes.censusIntakePhoto,
        parentNavigatorKey: rootNavigatorKey,
        builder: (_, _) =>
            const CensusIntakeScreen(mode: CensusIntakeMode.photo),
      ),
      GoRoute(
        path: AppRoutes.censusPropose,
        parentNavigatorKey: rootNavigatorKey,
        builder: (BuildContext context, GoRouterState state) {
          final Object? extra = state.extra;
          if (extra is! CensusIntakeProposal) {
            return const Scaffold(
              body: Center(child: Text('Missing census proposal.')),
            );
          }
          return CensusProposeScreen(proposal: extra);
        },
      ),
      GoRoute(
        path: AppRoutes.patientAddSource,
        parentNavigatorKey: rootNavigatorKey,
        builder: (BuildContext context, GoRouterState state) {
          return AddSourceScreen(
            patientId: state.pathParameters['patientId'] ?? '',
          );
        },
      ),
      GoRoute(
        path: AppRoutes.patientIntakeDictate,
        parentNavigatorKey: rootNavigatorKey,
        builder: (BuildContext context, GoRouterState state) {
          return PatientIntakeScreen(
            patientId: state.pathParameters['patientId'] ?? '',
            mode: IntakeMode.dictate,
          );
        },
      ),
      GoRoute(
        path: AppRoutes.patientIntakePhoto,
        parentNavigatorKey: rootNavigatorKey,
        builder: (BuildContext context, GoRouterState state) {
          return PatientIntakeScreen(
            patientId: state.pathParameters['patientId'] ?? '',
            mode: IntakeMode.photo,
          );
        },
      ),
      GoRoute(
        path: AppRoutes.patientFacts,
        parentNavigatorKey: rootNavigatorKey,
        builder: (BuildContext context, GoRouterState state) {
          return FactsReviewScreen(
            patientId: state.pathParameters['patientId'] ?? '',
          );
        },
      ),
      GoRoute(
        path: AppRoutes.patientAddFact,
        parentNavigatorKey: rootNavigatorKey,
        builder: (BuildContext context, GoRouterState state) {
          return AddFactScreen(
            patientId: state.pathParameters['patientId'] ?? '',
          );
        },
      ),
      GoRoute(
        path: AppRoutes.patientPlan,
        parentNavigatorKey: rootNavigatorKey,
        builder: (BuildContext context, GoRouterState state) {
          return PlanEditorScreen(
            patientId: state.pathParameters['patientId'] ?? '',
          );
        },
      ),
      GoRoute(
        path: AppRoutes.patientNote,
        parentNavigatorKey: rootNavigatorKey,
        builder: (BuildContext context, GoRouterState state) {
          final String patientId = state.pathParameters['patientId'] ?? '';
          // Demo builds keep the canned note screen.
          return AppEnvironment.useDemo
              ? NoteScreen(patientId: patientId)
              : NoteDraftScreen(patientId: patientId);
        },
      ),
      GoRoute(
        path: AppRoutes.patientEvidence,
        parentNavigatorKey: rootNavigatorKey,
        builder: (BuildContext context, GoRouterState state) {
          final String patientId = state.pathParameters['patientId'] ?? '';
          return AppEnvironment.useDemo
              ? EvidenceScreen(patientId: patientId)
              : EvidenceSearchScreen(patientId: patientId);
        },
      ),
      GoRoute(
        path: AppRoutes.patientPresentation,
        parentNavigatorKey: rootNavigatorKey,
        builder: (BuildContext context, GoRouterState state) {
          return PresentationScreen(
            patientId: state.pathParameters['patientId'] ?? '',
          );
        },
      ),
      GoRoute(
        path: AppRoutes.patientSignOut,
        parentNavigatorKey: rootNavigatorKey,
        builder: (BuildContext context, GoRouterState state) {
          final String patientId = state.pathParameters['patientId'] ?? '';
          return AppEnvironment.useDemo
              ? SignOutScreen(patientId: patientId)
              : SignOutDraftScreen(patientId: patientId);
        },
      ),
      GoRoute(
        path: AppRoutes.patientTeach,
        parentNavigatorKey: rootNavigatorKey,
        builder: (BuildContext context, GoRouterState state) {
          final String patientId = state.pathParameters['patientId'] ?? '';
          return AppEnvironment.useDemo
              ? TeachScreen(patientId: patientId)
              : TeachDraftScreen(patientId: patientId);
        },
      ),
      GoRoute(
        path: AppRoutes.patientTeachQueue,
        parentNavigatorKey: rootNavigatorKey,
        builder: (BuildContext context, GoRouterState state) {
          return TeachQueueScreen(
            patientId: state.pathParameters['patientId'] ?? '',
          );
        },
      ),
      GoRoute(
        path: AppRoutes.learningReviewQueue,
        parentNavigatorKey: rootNavigatorKey,
        builder: (_, _) => const SpacedReviewScreen(),
      ),
      GoRoute(
        path: AppRoutes.learningTopicQuiz,
        parentNavigatorKey: rootNavigatorKey,
        builder: (BuildContext context, GoRouterState state) {
          final String topic =
              state.uri.queryParameters['topic'] ?? 'General';
          return TopicQuizScreen(topic: topic);
        },
      ),
      GoRoute(
        path: AppRoutes.learningTopicReads,
        parentNavigatorKey: rootNavigatorKey,
        builder: (BuildContext context, GoRouterState state) {
          final String topic =
              state.uri.queryParameters['topic'] ?? 'General';
          return TopicReadsScreen(topic: topic);
        },
      ),
      GoRoute(
        path: AppRoutes.patientTasks,
        parentNavigatorKey: rootNavigatorKey,
        builder: (BuildContext context, GoRouterState state) {
          final String patientId = state.pathParameters['patientId'] ?? '';
          return AppEnvironment.useDemo
              ? TasksScreen(patientId: patientId)
              : PatientTasksScreen(patientId: patientId);
        },
      ),
      GoRoute(
        path: AppRoutes.patient,
        parentNavigatorKey: rootNavigatorKey,
        builder: (BuildContext context, GoRouterState state) {
          final String patientId = state.pathParameters['patientId'] ?? '';
          return PatientOverviewScreen(patientId: patientId);
        },
      ),
      GoRoute(
        path: AppRoutes.chatSearch,
        parentNavigatorKey: rootNavigatorKey,
        builder: (_, _) => const ChatSearchScreen(),
      ),
      GoRoute(
        path: AppRoutes.chatNewDm,
        parentNavigatorKey: rootNavigatorKey,
        builder: (_, _) =>
            const ChatNewConversationScreen(kind: ChatNewKind.dm),
      ),
      GoRoute(
        path: AppRoutes.chatNewGroup,
        parentNavigatorKey: rootNavigatorKey,
        builder: (_, _) =>
            const ChatNewConversationScreen(kind: ChatNewKind.group),
      ),
      GoRoute(
        path: AppRoutes.chatThread,
        parentNavigatorKey: rootNavigatorKey,
        builder: (BuildContext context, GoRouterState state) {
          final String channelId = state.pathParameters['channelId'] ?? '';
          final String messageId = state.pathParameters['messageId'] ?? '';
          final Object? extra = state.extra;
          final ChatThreadExtra? thread =
              extra is ChatThreadExtra ? extra : null;
          final ChatMessage parent =
              thread?.parent ??
              ChatMessage(
                id: messageId,
                channelId: channelId,
                senderId: '',
                body: '',
                seq: 0,
                deleted: false,
              );
          return ChatThreadScreen(
            channelId: channelId,
            parent: parent,
            channel: thread?.channel,
          );
        },
      ),
      GoRoute(
        path: AppRoutes.chatSummary,
        parentNavigatorKey: rootNavigatorKey,
        builder: (BuildContext context, GoRouterState state) {
          final Object? extra = state.extra;
          final ChatSummaryExtra? packed =
              extra is ChatSummaryExtra ? extra : null;
          final ChatSummaryDraft draft = packed?.draft ??
              ChatSummaryDraft.fromEnvelope(
                AiEnvelope.fromJson(<String, dynamic>{
                  'artifact_id': '',
                  'operation': 'summarize_chat_thread',
                  'patient_id': '',
                  'context_revision': 0,
                  'status': 'draft',
                  'review_state': 'draft',
                  'outdated': false,
                  'requires_review': true,
                  'provider': '',
                  'model': '',
                  'prompt_version': '',
                  'generation_ms': 0,
                  'created_at': DateTime.fromMillisecondsSinceEpoch(
                    0,
                    isUtc: true,
                  ).toIso8601String(),
                  'content': <String, dynamic>{
                    'channel_id': state.pathParameters['channelId'] ?? '',
                    'bullets': <Object>[],
                    'open_questions': <Object>[],
                    'missing_information': <Object>[],
                    'disclaimer': 'AI draft · review required.',
                  },
                }),
              );
          return ChatSummaryDraftScreen(
            draft: draft,
            channelTitle: packed?.channelTitle,
          );
        },
      ),
      GoRoute(
        path: AppRoutes.chatChannel,
        parentNavigatorKey: rootNavigatorKey,
        builder: (BuildContext context, GoRouterState state) {
          final String channelId = state.pathParameters['channelId'] ?? '';
          final Object? extra = state.extra;
          final ChatChannelExtra? packed =
              extra is ChatChannelExtra ? extra : null;
          final ChatChannel? channel = packed?.channel ??
              (extra is ChatChannel ? extra : null);
          return ChatChannelScreen(
            channelId: channelId,
            title: packed?.patientLabel ?? channel?.name,
            channelType: channel?.type,
            channel: channel,
            highlightMessageId: packed?.highlightMessageId,
            patientId: packed?.patientId ?? channel?.patientId,
            patientLabel: packed?.patientLabel,
          );
        },
      ),
      StatefulShellRoute.indexedStack(
        builder:
            (
              BuildContext context,
              GoRouterState state,
              StatefulNavigationShell navigationShell,
            ) {
              return MainShell(navigationShell: navigationShell);
            },
        branches: <StatefulShellBranch>[
          for (final ShellTab tab in ShellTabs.visible) _branch(tab),
          // Drawer / deep-link destinations (not in the bottom bar).
          if (!ShellTabs.visible.contains(ShellTab.tasks))
            _branch(ShellTab.tasks),
          if (AppFeatures.chat && !ShellTabs.visible.contains(ShellTab.chat))
            _branch(ShellTab.chat),
          StatefulShellBranch(
            navigatorKey: _profileNavigatorKey,
            routes: <RouteBase>[
              GoRoute(
                path: AppRoutes.profile,
                pageBuilder: (BuildContext context, GoRouterState state) {
                  return const NoTransitionPage<void>(child: ProfileScreen());
                },
              ),
            ],
          ),
        ],
      ),
    ],
  );

  /// Screens that are demo-only are not in the real build. A link to one
  /// goes to the census. Returns null when the path is fine.
  static String? redirectFor(String path) {
    if (path == AppRoutes.rounds && !AppFeatures.rounds) {
      return AppRoutes.census;
    }
    if (!AppFeatures.learning &&
        (path == AppRoutes.learning ||
            path.startsWith('${AppRoutes.learning}/'))) {
      return AppRoutes.census;
    }
    if (!AppFeatures.chat &&
        (path == AppRoutes.chat || path.startsWith('${AppRoutes.chat}/'))) {
      return AppRoutes.census;
    }
    return null;
  }

  /// One tab of the bottom bar.
  static StatefulShellBranch _branch(ShellTab tab) {
    switch (tab) {
      case ShellTab.today:
        return StatefulShellBranch(
          navigatorKey: _todayNavigatorKey,
          routes: <RouteBase>[
            GoRoute(
              path: AppRoutes.today,
              pageBuilder: (BuildContext context, GoRouterState state) {
                return const NoTransitionPage<void>(child: TodayScreen());
              },
            ),
          ],
        );
      case ShellTab.census:
        return StatefulShellBranch(
          navigatorKey: _censusNavigatorKey,
          routes: <RouteBase>[
            GoRoute(
              path: AppRoutes.census,
              pageBuilder: (BuildContext context, GoRouterState state) {
                return const NoTransitionPage<void>(child: CensusScreen());
              },
            ),
          ],
        );
      case ShellTab.scribe:
        return StatefulShellBranch(
          navigatorKey: _scribeNavigatorKey,
          routes: <RouteBase>[
            GoRoute(
              path: AppRoutes.scribe,
              pageBuilder: (BuildContext context, GoRouterState state) {
                return const NoTransitionPage<void>(child: ScribeHubScreen());
              },
            ),
          ],
        );
      case ShellTab.rounds:
        return StatefulShellBranch(
          navigatorKey: _roundsNavigatorKey,
          routes: <RouteBase>[
            GoRoute(
              path: AppRoutes.rounds,
              pageBuilder: (BuildContext context, GoRouterState state) {
                return const NoTransitionPage<void>(child: RoundsScreen());
              },
            ),
          ],
        );
      case ShellTab.tasks:
        return StatefulShellBranch(
          navigatorKey: _tasksNavigatorKey,
          routes: <RouteBase>[
            GoRoute(
              path: AppRoutes.tasks,
              pageBuilder: (BuildContext context, GoRouterState state) {
                return NoTransitionPage<void>(
                  child: AppEnvironment.useDemo
                      ? const TasksScreen()
                      : const TeamTasksScreen(),
                );
              },
            ),
          ],
        );
      case ShellTab.chat:
        return StatefulShellBranch(
          navigatorKey: _chatNavigatorKey,
          routes: <RouteBase>[
            GoRoute(
              path: AppRoutes.chat,
              pageBuilder: (BuildContext context, GoRouterState state) {
                return const NoTransitionPage<void>(
                  child: ChatChannelsScreen(),
                );
              },
            ),
          ],
        );
      case ShellTab.learn:
        return StatefulShellBranch(
          navigatorKey: _learningNavigatorKey,
          routes: <RouteBase>[
            GoRoute(
              path: AppRoutes.learning,
              pageBuilder: (BuildContext context, GoRouterState state) {
                return const NoTransitionPage<void>(child: LearningScreen());
              },
            ),
          ],
        );
    }
  }
}
