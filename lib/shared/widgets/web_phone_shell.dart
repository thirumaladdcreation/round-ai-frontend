import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:round_ai/core/theme/app_colors.dart';

/// On wide web viewports, centers the app in a phone-width column so the
/// demo matches the mobile layout the client expects.
class WebPhoneShell extends StatelessWidget {
  const WebPhoneShell({required this.child, super.key});

  static const double maxPhoneWidth = 430;

  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (!kIsWeb) return child;
    final double width = MediaQuery.sizeOf(context).width;
    if (width <= maxPhoneWidth + 24) return child;

    final AppColors colors = AppColors.of(context);
    return ColoredBox(
      color: colors.background.withValues(alpha: 0.92),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: maxPhoneWidth),
          child: Material(
            elevation: 8,
            color: colors.background,
            clipBehavior: Clip.antiAlias,
            child: SizedBox(
              height: MediaQuery.sizeOf(context).height,
              width: maxPhoneWidth,
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}
