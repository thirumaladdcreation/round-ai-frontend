import 'package:round_ai/core/config/app_features.dart';

/// Bottom bar tabs, in order. Router branches and the bar share this list.
///
/// Product focus: Home · Census · Scribe · Rounds · Learn.
/// Chat (Slack-like) and team Tasks live in the drawer / patient chart.
enum ShellTab { today, census, scribe, rounds, learn, tasks, chat }

class ShellTabs {
  const ShellTabs._();

  static List<ShellTab> get visible => <ShellTab>[
    ShellTab.today,
    ShellTab.census,
    ShellTab.scribe,
    if (AppFeatures.rounds) ShellTab.rounds,
    if (AppFeatures.learning) ShellTab.learn,
  ];
}
