import 'package:round_ai/core/config/app_features.dart';

/// Bottom bar tabs, in order. Router branches and the bar share this list.
///
/// Prompt 8 P3: Patients · Tasks · Learn · Chat. Home/Scribe/Rounds are
/// secondary (drawer / patient Add update / Rounds entry).
enum ShellTab { today, census, scribe, rounds, learn, tasks, chat }

class ShellTabs {
  const ShellTabs._();

  static List<ShellTab> get visible => <ShellTab>[
    ShellTab.census,
    if (AppFeatures.tasks) ShellTab.tasks,
    if (AppFeatures.learning) ShellTab.learn,
    if (AppFeatures.chat) ShellTab.chat,
  ];
}
