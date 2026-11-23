import 'package:round_ai/core/config/app_features.dart';

/// Bottom bar tabs, in order. Router branches and the bar share this list.
///
/// Today (home) first, then Patients · Tasks · Learn · Chat.
/// Scribe/Rounds stay secondary (patient Add update / drawer).
enum ShellTab { today, census, scribe, rounds, learn, tasks, chat }

class ShellTabs {
  const ShellTabs._();

  static List<ShellTab> get visible => <ShellTab>[
    ShellTab.today,
    ShellTab.census,
    if (AppFeatures.tasks) ShellTab.tasks,
    if (AppFeatures.learning) ShellTab.learn,
    if (AppFeatures.chat) ShellTab.chat,
  ];
}
