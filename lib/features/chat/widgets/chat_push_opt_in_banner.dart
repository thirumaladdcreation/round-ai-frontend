import 'package:flutter/material.dart';
import 'package:round_ai/core/di/injection_container.dart';
import 'package:round_ai/core/theme/app_colors.dart';
import 'package:round_ai/core/theme/app_typography.dart';
import 'package:round_ai/features/chat/services/chat_push_controller.dart';

/// Soft opt-in on the Chat tab. OS permission is requested only after Accept.
class ChatPushOptInBanner extends StatelessWidget {
  const ChatPushOptInBanner({this.controller, super.key});

  final ChatPushController? controller;

  @override
  Widget build(BuildContext context) {
    final ChatPushController push =
        controller ?? InjectionContainer.instance.chatPush;
    final AppColors colors = AppColors.of(context);
    return ValueListenableBuilder<bool>(
      valueListenable: push.optInVisible,
      builder: (BuildContext context, bool visible, Widget? child) {
        if (!visible) return const SizedBox.shrink();
        return child!;
      },
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: colors.primarySoft,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: colors.border),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Text(
                  'Get notified of new messages',
                  style: AppTypography.semiBold(
                    fontSize: 14,
                    color: colors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Alerts say only "New message" — never a name, room, or '
                  'message text. You can turn this off in system settings.',
                  style: AppTypography.regular(
                    fontSize: 13,
                    color: colors.textMuted,
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: <Widget>[
                    TextButton(
                      onPressed: () => push.dismissOptIn(),
                      child: const Text('Not now'),
                    ),
                    const Spacer(),
                    FilledButton(
                      onPressed: () => push.acceptOptInAndRegister(),
                      child: const Text('Enable'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
