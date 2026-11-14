import 'package:flutter/material.dart';
import 'package:round_ai/app/app_colors.dart';
import 'package:round_ai/app/app_typography.dart';
import 'package:round_ai/core/theme/app_radii.dart';

/// One light theme and one dark theme. Screens pick colors from [AppPalette].
class AppTheme {
  const AppTheme._();

  static ThemeData get lightTheme =>
      _build(brightness: Brightness.light, palette: AppColors.light);

  static ThemeData get darkTheme =>
      _build(brightness: Brightness.dark, palette: AppColors.dark);

  static ThemeData get light => lightTheme;

  static ThemeData get dark => darkTheme;

  static ThemeData _build({
    required Brightness brightness,
    required AppColors palette,
  }) {
    final ColorScheme scheme = ColorScheme(
      brightness: brightness,
      primary: palette.primary,
      onPrimary: palette.white,
      secondary: palette.accent,
      onSecondary: palette.white,
      error: palette.error,
      onError: palette.white,
      surface: palette.surface,
      onSurface: palette.textPrimary,
    );
    final TextTheme textTheme = TextTheme(
      displayLarge: AppTypography.display(color: palette.navy),
      headlineMedium: AppTypography.screenHeading(color: palette.navy),
      titleLarge: AppTypography.sectionHeading(color: palette.textPrimary),
      titleMedium: AppTypography.headingSemiBold(color: palette.textPrimary),
      bodyLarge: AppTypography.bodyLarge(color: palette.textPrimary),
      bodyMedium: AppTypography.bodyMedium(color: palette.textPrimary),
      bodySmall: AppTypography.bodySmall(color: palette.textSecondary),
      labelLarge: AppTypography.button(color: palette.textPrimary),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      fontFamily: AppTypography.fontFamily,
      colorScheme: scheme,
      textTheme: textTheme,
      scaffoldBackgroundColor: palette.background,
      iconTheme: IconThemeData(color: palette.textPrimary),
      extensions: <ThemeExtension<dynamic>>[palette],
      appBarTheme: AppBarTheme(
        centerTitle: false,
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: palette.background,
        foregroundColor: palette.textPrimary,
      ),
      cardTheme: CardThemeData(
        color: palette.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.xl),
          side: BorderSide(color: palette.border),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: palette.chipIdle,
        selectedColor: palette.navy,
        disabledColor: palette.chipIdle,
        labelStyle: AppTypography.medium(fontSize: 12, color: palette.textPrimary),
        secondaryLabelStyle: AppTypography.medium(
          fontSize: 12,
          color: palette.white,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.pill),
          side: BorderSide(color: palette.border),
        ),
        side: BorderSide(color: palette.border),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: palette.surface,
        indicatorColor: palette.primarySoft,
        labelTextStyle: WidgetStateProperty.resolveWith((
          Set<WidgetState> states,
        ) {
          final bool selected = states.contains(WidgetState.selected);
          return AppTypography.medium(
            fontSize: 11,
            color: selected ? palette.primary : palette.textMuted,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((Set<WidgetState> states) {
          final bool selected = states.contains(WidgetState.selected);
          return IconThemeData(
            size: 22,
            color: selected ? palette.primary : palette.textMuted,
          );
        }),
      ),
      dividerColor: palette.border,
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: palette.surface,
        hintStyle: AppTypography.bodyMedium(color: palette.textSecondary),
        labelStyle: AppTypography.label(color: palette.textPrimary),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.lg),
          borderSide: BorderSide(color: palette.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.lg),
          borderSide: BorderSide(color: palette.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.lg),
          borderSide: BorderSide(color: palette.primary, width: 1.4),
        ),
      ),
    );
  }
}
