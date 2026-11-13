import 'package:flutter/material.dart';
import 'package:round_ai/app/app_colors.dart';

/// Frosted panel without live BackdropFilter — keeps keyboard resize smooth.
class SignInGlassCard extends StatelessWidget {
  const SignInGlassCard({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final bool dark = Theme.of(context).brightness == Brightness.dark;
    final Color fill = dark
        ? RoundsBrand.charcoal.withValues(alpha: 0.72)
        : RoundsBrand.white.withValues(alpha: 0.78);
    final Color border = RoundsBrand.white.withValues(
      alpha: dark ? 0.22 : 0.55,
    );
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: dark
                ? RoundsBrand.charcoal.withValues(alpha: 0.38)
                : RoundsBrand.slate.withValues(alpha: 0.14),
            blurRadius: 28,
            offset: const Offset(0, 14),
          ),
          if (dark)
            BoxShadow(
              color: RoundsBrand.aqua.withValues(alpha: 0.14),
              blurRadius: 24,
              spreadRadius: -6,
            ),
        ],
      ),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: fill,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: border),
        ),
        child: Padding(padding: const EdgeInsets.all(22), child: child),
      ),
    );
  }
}
