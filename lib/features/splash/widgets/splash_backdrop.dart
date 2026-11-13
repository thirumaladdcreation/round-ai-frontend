import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:round_ai/app/app_colors.dart';
import 'package:round_ai/core/constants/app_assets.dart';

/// Each theme uses its own full-screen splash artwork.
class SplashBackdrop extends StatelessWidget {
  const SplashBackdrop({super.key});

  @override
  Widget build(BuildContext context) {
    final AppColors colors = AppColors.of(context);
    final bool dark = Theme.of(context).brightness == Brightness.dark;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: dark ? Brightness.light : Brightness.dark,
        statusBarBrightness: dark ? Brightness.dark : Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: colors.background,
        body: dark ? const SplashDarkBody() : const SplashLightBody(),
      ),
    );
  }
}

class SplashLightBody extends StatelessWidget {
  const SplashLightBody({super.key});

  @override
  Widget build(BuildContext context) {
    return const SplashArtworkImage(asset: AppAssets.splashScreenLight);
  }
}

class SplashDarkBody extends StatelessWidget {
  const SplashDarkBody({super.key});

  @override
  Widget build(BuildContext context) {
    return const SplashArtworkImage(asset: AppAssets.splashScreen);
  }
}

class SplashArtworkImage extends StatelessWidget {
  const SplashArtworkImage({required this.asset, super.key});

  final String asset;

  @override
  Widget build(BuildContext context) {
    return SizedBox.expand(
      child: Image(
        image: AssetImage(asset),
        fit: BoxFit.cover,
        alignment: Alignment.center,
      ),
    );
  }
}
