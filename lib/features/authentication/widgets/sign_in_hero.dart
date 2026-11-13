import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:round_ai/core/constants/app_assets.dart';

/// Blurred clinical hero. The form sheet starts halfway down this image.
class SignInHero extends StatelessWidget {
  const SignInHero({required this.height, super.key});

  final double height;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      width: double.infinity,
      child: ClipRect(
        child: ImageFiltered(
          imageFilter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
          child: Transform.scale(
            scale: 1.08,
            child: const Image(
              image: AssetImage(AppAssets.loginIllustration),
              fit: BoxFit.cover,
              alignment: Alignment.centerRight,
              width: double.infinity,
              height: double.infinity,
            ),
          ),
        ),
      ),
    );
  }
}
