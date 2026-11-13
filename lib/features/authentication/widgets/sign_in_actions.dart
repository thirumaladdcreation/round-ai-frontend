import 'package:flutter/material.dart';
import 'package:round_ai/app/app_colors.dart';
import 'package:round_ai/app/app_typography.dart';

class SignInOrDivider extends StatelessWidget {
  const SignInOrDivider({super.key});

  @override
  Widget build(BuildContext context) {
    final bool dark = Theme.of(context).brightness == Brightness.dark;
    final Color line = dark
        ? RoundsBrand.white.withValues(alpha: 0.16)
        : RoundsBrand.slate.withValues(alpha: 0.16);
    final Color label = dark
        ? RoundsBrand.pale.withValues(alpha: 0.7)
        : RoundsBrand.slate;
    return Row(
      children: <Widget>[
        Expanded(child: Divider(color: line, height: 1)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text(
            'or',
            style: AppTypography.inter(
              AppTypography.regular(color: label, fontSize: 13),
            ),
          ),
        ),
        Expanded(child: Divider(color: line, height: 1)),
      ],
    );
  }
}
