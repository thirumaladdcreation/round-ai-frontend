import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:round_ai/app/app_colors.dart';
import 'package:round_ai/core/constants/app_assets.dart';

/// Full-screen hospital photograph. The blur stays behind the login form.
class SignInBackdrop extends StatelessWidget {
  const SignInBackdrop({super.key});

  @override
  Widget build(BuildContext context) {
    final bool dark = Theme.of(context).brightness == Brightness.dark;
    return Stack(
      fit: StackFit.expand,
      children: <Widget>[
        ImageFiltered(
          imageFilter: ImageFilter.blur(sigmaX: 2.5, sigmaY: 2.5),
          child: Image.asset(
            dark
                ? AppAssets.loginBackgroundDark
                : AppAssets.loginBackgroundLight,
            fit: BoxFit.cover,
            gaplessPlayback: true,
            filterQuality: FilterQuality.medium,
          ),
        ),
        ColoredBox(
          color: dark
              ? RoundsBrand.charcoal.withValues(alpha: 0.18)
              : RoundsBrand.white.withValues(alpha: 0.08),
        ),
        if (dark)
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: <Color>[Color(0x2E1C3946), Color(0x0015252F)],
              ),
            ),
          ),
      ],
    );
  }
}
