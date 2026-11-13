import 'package:flutter/foundation.dart';
import 'package:round_ai/core/config/app_environment.dart';

/// Which screens run on the real backend yet.
///
/// A feature that is not connected is hidden in the default build. It is not
/// faked. With `USE_DEMO=true` every screen is available on demo data. Each
/// phase switches its own flags on.
class AppFeatures {
  const AppFeatures._();

  /// Tests set this to true to see every demo screen without a dart-define.
  @visibleForTesting
  static bool? forceAll;

  static bool _on(bool connected) =>
      forceAll ?? (AppEnvironment.useDemo || connected);

  /// Oral presentation (`POST /patients/:id/present`).
  static bool get presentation => _on(true);

  /// Round brief, reminders, and prepare presentations (M3).
  static bool get rounds => _on(true);

  /// Teaching mode (plan, quiz, reads, review queue).
  static bool get learning => _on(true);

  /// Team chat (M5). H0 scaffolds repositories; UI ships in H1+ (`_chat`).
  static bool get chat => _on(_chat);

  /// Chat tab + REST + SSE + threads. Push uses a pluggable stub until an
  /// FCM/APNs adapter is wired under a confirmed BAA.
  static const bool _chat = true;

  /// Differential "considerations" exploration. Backend gate is off by default.
  static bool get considerations => false;

  static bool get summary => _on(_summary);
  static bool get ask => _on(_ask);
  static bool get notes => _on(_notes);
  static bool get evidence => _on(_evidence);
  static bool get teach => _on(_teach);
  static bool get tasks => _on(_tasks);
  static bool get signOut => _on(_signOut);

  static const bool _summary = true;
  static const bool _ask = true;
  static const bool _notes = true;
  static const bool _evidence = true;
  static const bool _teach = true;
  static const bool _tasks = true;
  static const bool _signOut = true;
}
