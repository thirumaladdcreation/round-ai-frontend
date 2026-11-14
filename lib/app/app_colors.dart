import 'package:flutter/material.dart';

/// Both palettes. Screens read the active one with [AppColors.of].
class AppColors extends ThemeExtension<AppColors> {
  const AppColors({
    required this.background,
    required this.surface,
    required this.navy,
    required this.primary,
    required this.secondary,
    required this.accent,
    required this.textPrimary,
    required this.textSecondary,
    required this.textMuted,
    required this.border,
    required this.inputFill,
    required this.success,
    required this.warning,
    required this.error,
    required this.white,
    required this.button,
    required this.critical,
    required this.criticalBg,
    required this.stable,
    required this.stableBg,
    required this.pending,
    required this.pendingBg,
    required this.aiCard,
    required this.aiBorder,
    required this.aiAccent,
    required this.chipIdle,
    required this.primarySoft,
    required this.successSoft,
    required this.warningSoft,
  });

  final Color background;
  final Color surface;
  final Color navy;
  final Color primary;
  final Color secondary;
  final Color accent;
  final Color textPrimary;
  final Color textSecondary;
  final Color textMuted;
  final Color border;
  final Color inputFill;
  final Color success;
  final Color warning;
  final Color error;
  final Color white;
  final Color button;
  final Color critical;
  final Color criticalBg;
  final Color stable;
  final Color stableBg;
  final Color pending;
  final Color pendingBg;
  final Color aiCard;
  final Color aiBorder;
  final Color aiAccent;
  final Color chipIdle;
  final Color primarySoft;
  final Color successSoft;
  final Color warningSoft;

  // Prototype tokens (rounds-ai-clinical-prototype): --ink/--bg/--blue/--muted/--line.
  static const Color lightNavy = Color(0xFF10232E);
  static const Color lightText = Color(0xFF10232E);
  static const Color lightMuted = Color(0xFF768690);
  static const Color lightWhite = Color(0xFFFFFFFF);

  static const AppColors light = AppColors(
    background: Color(0xFFF3F6F8),
    surface: lightWhite,
    navy: lightNavy,
    primary: Color(0xFF087CFF),
    secondary: Color(0xFF087CFF),
    accent: Color(0xFF2BA577),
    textPrimary: lightText,
    textSecondary: lightMuted,
    textMuted: lightMuted,
    border: Color(0xFFE4EAEE),
    inputFill: Color(0xFFFFFFFF),
    success: Color(0xFF2BA577),
    warning: Color(0xFFE59B38),
    error: Color(0xFFE95B63),
    white: lightWhite,
    button: lightNavy,
    critical: Color(0xFFE95B63),
    criticalBg: Color(0xFFFFF1F2),
    stable: Color(0xFF087CFF),
    stableBg: Color(0xFFEFF6FF),
    pending: Color(0xFFE59B38),
    pendingBg: Color(0xFFFFF7ED),
    // Clinical teal tint for AI surfaces (avoid purple-on-white prototype mismatch).
    aiCard: Color(0xFFF0F7F8),
    aiBorder: Color(0xFFC9E4E8),
    aiAccent: Color(0xFF1C6B74),
    chipIdle: Color(0xFFF1F5F9),
    primarySoft: Color(0xFFE8F3FF),
    successSoft: Color(0xFFE7F6EE),
    warningSoft: Color(0xFFFFF4E8),
  );

  static const AppColors dark = AppColors(
    background: Color(0xFF101B26),
    surface: Color(0xFF1B2A38),
    navy: Color(0xFFF4F7FA),
    primary: Color(0xFF4A9EFF),
    secondary: Color(0xFF4A9EFF),
    accent: Color(0xFF39B8AD),
    textPrimary: Color(0xFFF7FAFC),
    // Brighter secondary/muted so body copy stays readable on navy surfaces.
    textSecondary: Color(0xFFC5D0DA),
    textMuted: Color(0xFFA8B6C4),
    border: Color(0xFF304252),
    inputFill: Color(0xFF1B2A38),
    success: Color(0xFF3DDC97),
    warning: Color(0xFFF0B429),
    error: Color(0xFFFF6B81),
    white: Color(0xFFFFFFFF),
    button: Color(0xFF4A9EFF),
    critical: Color(0xFFFF6B81),
    criticalBg: Color(0xFF3A222C),
    stable: Color(0xFF4A9EFF),
    stableBg: Color(0xFF16324A),
    pending: Color(0xFFF0B429),
    pendingBg: Color(0xFF3A311C),
    aiCard: Color(0xFF241C36),
    aiBorder: Color(0xFF4A3D6B),
    aiAccent: Color(0xFFC4B5FD),
    chipIdle: Color(0xFF243444),
    primarySoft: Color(0xFF16324A),
    successSoft: Color(0xFF14352C),
    warningSoft: Color(0xFF3A2A18),
  );

  static const LinearGradient logoGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: <Color>[Color(0xFF1E40AF), Color(0xFF3B82F6)],
  );

  static AppColors of(BuildContext context) {
    return Theme.of(context).extension<AppColors>() ?? light;
  }

  @override
  AppColors copyWith({
    Color? background,
    Color? surface,
    Color? navy,
    Color? primary,
    Color? secondary,
    Color? accent,
    Color? textPrimary,
    Color? textSecondary,
    Color? textMuted,
    Color? border,
    Color? inputFill,
    Color? success,
    Color? warning,
    Color? error,
    Color? white,
    Color? button,
    Color? critical,
    Color? criticalBg,
    Color? stable,
    Color? stableBg,
    Color? pending,
    Color? pendingBg,
    Color? aiCard,
    Color? aiBorder,
    Color? aiAccent,
    Color? chipIdle,
    Color? primarySoft,
    Color? successSoft,
    Color? warningSoft,
  }) {
    return AppColors(
      background: background ?? this.background,
      surface: surface ?? this.surface,
      navy: navy ?? this.navy,
      primary: primary ?? this.primary,
      secondary: secondary ?? this.secondary,
      accent: accent ?? this.accent,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      textMuted: textMuted ?? this.textMuted,
      border: border ?? this.border,
      inputFill: inputFill ?? this.inputFill,
      success: success ?? this.success,
      warning: warning ?? this.warning,
      error: error ?? this.error,
      white: white ?? this.white,
      button: button ?? this.button,
      critical: critical ?? this.critical,
      criticalBg: criticalBg ?? this.criticalBg,
      stable: stable ?? this.stable,
      stableBg: stableBg ?? this.stableBg,
      pending: pending ?? this.pending,
      pendingBg: pendingBg ?? this.pendingBg,
      aiCard: aiCard ?? this.aiCard,
      aiBorder: aiBorder ?? this.aiBorder,
      aiAccent: aiAccent ?? this.aiAccent,
      chipIdle: chipIdle ?? this.chipIdle,
      primarySoft: primarySoft ?? this.primarySoft,
      successSoft: successSoft ?? this.successSoft,
      warningSoft: warningSoft ?? this.warningSoft,
    );
  }

  @override
  AppColors lerp(ThemeExtension<AppColors>? other, double t) {
    if (other is! AppColors) return this;
    Color mix(Color a, Color b) => Color.lerp(a, b, t) ?? a;
    return AppColors(
      background: mix(background, other.background),
      surface: mix(surface, other.surface),
      navy: mix(navy, other.navy),
      primary: mix(primary, other.primary),
      secondary: mix(secondary, other.secondary),
      accent: mix(accent, other.accent),
      textPrimary: mix(textPrimary, other.textPrimary),
      textSecondary: mix(textSecondary, other.textSecondary),
      textMuted: mix(textMuted, other.textMuted),
      border: mix(border, other.border),
      inputFill: mix(inputFill, other.inputFill),
      success: mix(success, other.success),
      warning: mix(warning, other.warning),
      error: mix(error, other.error),
      white: mix(white, other.white),
      button: mix(button, other.button),
      critical: mix(critical, other.critical),
      criticalBg: mix(criticalBg, other.criticalBg),
      stable: mix(stable, other.stable),
      stableBg: mix(stableBg, other.stableBg),
      pending: mix(pending, other.pending),
      pendingBg: mix(pendingBg, other.pendingBg),
      aiCard: mix(aiCard, other.aiCard),
      aiBorder: mix(aiBorder, other.aiBorder),
      aiAccent: mix(aiAccent, other.aiAccent),
      chipIdle: mix(chipIdle, other.chipIdle),
      primarySoft: mix(primarySoft, other.primarySoft),
      successSoft: mix(successSoft, other.successSoft),
      warningSoft: mix(warningSoft, other.warningSoft),
    );
  }
}

/// Existing screens use this name. It is the same palette as [AppColors].
typedef AppPalette = AppColors;

/// Client brand colors for RoundsAI. Login and other brand surfaces use these.
class RoundsBrand {
  const RoundsBrand._();

  static const Color charcoal = Color(0xFF15252F);
  static const Color slate = Color(0xFF1C3946);
  static const Color aqua = Color(0xFF88D3DA);
  static const Color pale = Color(0xFFF3F5F7);
  static const Color white = Color(0xFFFFFFFF);
}
