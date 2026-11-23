import 'package:flutter/material.dart';
import 'package:round_ai/core/utils/screen_utils.dart';

/// Plus Jakarta Sans across Home, Patients, Patient detail, Rounds, etc.
///
/// Weights: headings 700, names/sections/buttons 600, body 400, labels 400–500.
/// Omit [color] so the style inherits [DefaultTextStyle] / the active theme.
class AppTypography {
  const AppTypography._();

  static const String fontFamily = 'PlusJakartaSans';
  static const String interFamily = 'Inter';

  static TextStyle inter(TextStyle style) {
    return style.copyWith(fontFamily: interFamily);
  }

  static double _scaled(double size) {
    return ScreenUtils.isInitialized ? ScreenUtils.sp(size) : size;
  }

  static TextStyle _style({
    required FontWeight weight,
    required double fontSize,
    required double height,
    Color? color,
    double letterSpacing = 0,
  }) {
    return TextStyle(
      fontFamily: fontFamily,
      fontWeight: weight,
      fontSize: _scaled(fontSize),
      height: height,
      letterSpacing: letterSpacing,
      color: color,
    );
  }

  static TextStyle display({Color? color}) {
    return _style(
      weight: FontWeight.w700,
      fontSize: 32,
      height: 1.15,
      color: color,
      letterSpacing: -0.4,
    );
  }

  static TextStyle screenHeading({Color? color}) {
    return _style(
      weight: FontWeight.w700,
      fontSize: 28,
      height: 1.15,
      color: color,
      letterSpacing: -0.3,
    );
  }

  /// Design-system roles (Prompt 8 §4). Prefer these over ad-hoc sizes.
  static TextStyle screenTitle({Color? color}) {
    return _style(
      weight: FontWeight.w600,
      fontSize: 24,
      height: 30 / 24,
      color: color,
      letterSpacing: -0.2,
    );
  }

  static TextStyle sectionHeading({Color? color}) {
    return _style(
      weight: FontWeight.w600,
      fontSize: 18,
      height: 24 / 18,
      color: color,
    );
  }

  /// Alias of [sectionHeading] for the locked 18/24 role.
  static TextStyle sectionHeader({Color? color}) => sectionHeading(color: color);

  /// Body / clinical values — 16 / 22.
  static TextStyle clinicalBody({Color? color}) {
    return _style(
      weight: FontWeight.w400,
      fontSize: 16,
      height: 22 / 16,
      color: color,
    );
  }

  /// Secondary text — 14 / 20.
  static TextStyle secondaryText({Color? color}) {
    return _style(
      weight: FontWeight.w400,
      fontSize: 14,
      height: 20 / 14,
      color: color,
    );
  }

  /// Caption / metadata only — 12 / 16 (never clinical values).
  static TextStyle captionMeta({Color? color}) {
    return _style(
      weight: FontWeight.w400,
      fontSize: 12,
      height: 16 / 12,
      color: color,
    );
  }

  static TextStyle headingSemiBold({Color? color}) {
    return _style(
      weight: FontWeight.w600,
      fontSize: 16,
      height: 1.25,
      color: color,
    );
  }

  static TextStyle headingMedium({Color? color}) {
    return _style(
      weight: FontWeight.w500,
      fontSize: 16,
      height: 1.25,
      color: color,
    );
  }

  static TextStyle bodyLarge({Color? color}) {
    return _style(
      weight: FontWeight.w400,
      fontSize: 16,
      height: 1.4,
      color: color,
    );
  }

  static TextStyle bodyMedium({Color? color}) {
    return _style(
      weight: FontWeight.w400,
      fontSize: 14,
      height: 1.4,
      color: color,
    );
  }

  static TextStyle bodySmall({Color? color}) {
    return _style(
      weight: FontWeight.w400,
      fontSize: 13,
      height: 1.35,
      color: color,
    );
  }

  static TextStyle caption({Color? color}) {
    return _style(
      weight: FontWeight.w400,
      fontSize: 12,
      height: 1.3,
      color: color,
    );
  }

  static TextStyle label({Color? color}) {
    return _style(
      weight: FontWeight.w500,
      fontSize: 14,
      height: 1.25,
      color: color,
    );
  }

  static TextStyle button({Color? color}) {
    return _style(
      weight: FontWeight.w600,
      fontSize: 16,
      height: 1.2,
      color: color,
    );
  }

  /// Existing screens call these four helpers.
  static TextStyle regular({
    Color? color,
    double fontSize = 14,
    double height = 1.35,
  }) {
    return _style(
      weight: FontWeight.w400,
      fontSize: fontSize,
      height: height,
      color: color,
    );
  }

  static TextStyle medium({
    Color? color,
    double fontSize = 16,
    double height = 1.25,
  }) {
    return _style(
      weight: FontWeight.w500,
      fontSize: fontSize,
      height: height,
      color: color,
    );
  }

  static TextStyle semiBold({
    Color? color,
    double fontSize = 16,
    double height = 1.2,
  }) {
    return _style(
      weight: FontWeight.w600,
      fontSize: fontSize,
      height: height,
      color: color,
    );
  }

  static TextStyle bold({
    Color? color,
    double fontSize = 28,
    double height = 1.1,
  }) {
    return _style(
      weight: FontWeight.w700,
      fontSize: fontSize,
      height: height,
      color: color,
      letterSpacing: -0.3,
    );
  }
}
