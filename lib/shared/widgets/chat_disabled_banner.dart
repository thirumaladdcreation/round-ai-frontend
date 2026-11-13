import 'package:flutter/material.dart';
import 'package:round_ai/core/theme/app_colors.dart';
import 'package:round_ai/core/theme/app_typography.dart';

/// Calm notice when the admin turned chat off (`chat_enabled=false`).
class ChatDisabledBanner extends StatelessWidget {
  const ChatDisabledBanner({super.key});

  static const String message =
      'Chat is turned off by your administrator.';

  @override
  Widget build(BuildContext context) {
    final AppColors colors = AppColors.of(context);
    return Material(
      color: colors.warningSoft,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: <Widget>[
            Icon(Icons.forum_outlined, size: 18, color: colors.warning),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                message,
                style: AppTypography.medium(
                  fontSize: 12.5,
                  color: colors.textPrimary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
