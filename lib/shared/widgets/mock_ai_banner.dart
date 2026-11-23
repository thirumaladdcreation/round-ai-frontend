import 'package:flutter/material.dart';
import 'package:round_ai/core/config/ai_provider_store.dart';
import 'package:round_ai/core/config/app_environment.dart';
import 'package:round_ai/core/di/injection_container.dart';
import 'package:round_ai/core/theme/app_colors.dart';
import 'package:round_ai/core/theme/app_typography.dart';

/// Persistent strip when the API is running with `AI_PROVIDER=mock`.
class MockAiBanner extends StatelessWidget {
  const MockAiBanner({required this.child, super.key});

  final Widget child;

  static const String message = 'MOCK AI: demo output only';

  @override
  Widget build(BuildContext context) {
    if (AppEnvironment.useDemo) {
      // Whole app is offline demo — DemoContentBanner covers that case.
      return child;
    }
    final AiProviderStore store = InjectionContainer.instance.aiProviderStore;
    return AnimatedBuilder(
      animation: store,
      builder: (BuildContext context, Widget? _) {
        if (!store.isMock) return child;
        final AppColors colors = AppColors.of(context);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Material(
              color: colors.warningSoft,
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  child: Row(
                    children: <Widget>[
                      Icon(
                        Icons.science_outlined,
                        size: 16,
                        color: colors.warning,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          message,
                          style: AppTypography.semiBold(
                            fontSize: 12,
                            color: colors.textPrimary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Expanded(child: child),
          ],
        );
      },
    );
  }
}
