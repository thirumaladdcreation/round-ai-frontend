import 'package:flutter/material.dart';
import 'package:round_ai/core/config/app_environment.dart';

class EnvironmentBanner extends StatelessWidget {
  const EnvironmentBanner({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (!AppEnvironment.showEnvironmentBanner) {
      return child;
    }

    return Banner(
      message: AppEnvironment.name.toUpperCase(),
      location: BannerLocation.topEnd,
      color: const Color(0xFF1D4ED8),
      child: child,
    );
  }
}
