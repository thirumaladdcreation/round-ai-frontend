import 'package:flutter/material.dart';
import 'package:round_ai/app/app_colors.dart';
import 'package:round_ai/app/app_typography.dart';
import 'package:round_ai/shared/widgets/rounds_logo.dart';

class SignInBrand extends StatelessWidget {
  const SignInBrand({super.key});

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = AppPalette.of(context);
    return Row(
      children: <Widget>[
        const SizedBox(width: 52, height: 52, child: RoundsLogo(size: 52)),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                'RoundsAI',
                style: AppTypography.bold(fontSize: 22, color: palette.navy),
              ),
              const SizedBox(height: 2),
              Text.rich(
                TextSpan(
                  style: AppTypography.regular(
                    color: palette.textSecondary,
                    fontSize: 14,
                  ),
                  children: <InlineSpan>[
                    const TextSpan(text: 'Smarter Rounds. '),
                    TextSpan(
                      text: 'Better Care.',
                      style: AppTypography.semiBold(
                        color: palette.primary,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
