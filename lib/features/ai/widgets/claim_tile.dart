import 'package:flutter/material.dart';
import 'package:round_ai/core/theme/app_colors.dart';
import 'package:round_ai/core/theme/app_typography.dart';
import 'package:round_ai/features/ai/models/ai_envelope.dart';
import 'package:round_ai/features/ai/widgets/placeholder_text.dart';

/// One statement with its label. Tapping it opens the source drawer.
class ClaimTile extends StatelessWidget {
  const ClaimTile({
    required this.claim,
    required this.onTap,
    this.bold = false,
    super.key,
  });

  final Claim claim;
  final VoidCallback onTap;
  final bool bold;

  @override
  Widget build(BuildContext context) {
    final AppColors colors = AppColors.of(context);
    final bool chart = claim.label == ClaimLabel.fromChart;
    final TextStyle body = bold
        ? AppTypography.semiBold(
            fontSize: 15,
            height: 1.4,
            color: colors.textPrimary,
          )
        : AppTypography.regular(height: 1.4, color: colors.textPrimary);
    return Semantics(
      button: true,
      hint: 'Shows where this statement comes from',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 5),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    PlaceholderText(claim.text, style: body),
                    const SizedBox(height: 3),
                    Text(
                      claim.labelText,
                      style: AppTypography.medium(
                        fontSize: 11,
                        color: chart ? colors.success : colors.aiAccent,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Icon(
                  Icons.link_rounded,
                  size: 16,
                  color: colors.textMuted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
