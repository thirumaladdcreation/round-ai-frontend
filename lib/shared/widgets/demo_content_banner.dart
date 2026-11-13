import 'package:flutter/material.dart';
import 'package:round_ai/core/config/app_environment.dart';
import 'package:round_ai/core/theme/app_colors.dart';
import 'package:round_ai/core/theme/app_typography.dart';

/// Marks content that is canned / not from the live backend.
///
/// In full `USE_DEMO` mode the whole app is demo, so the banner is hidden
/// unless [forceShow] is set (for a demo-only pocket inside a live screen).
class DemoContentBanner extends StatelessWidget {
  const DemoContentBanner({this.forceShow = false, super.key});

  /// Show even when `USE_DEMO=true` (e.g. attending question has no API).
  final bool forceShow;

  static const String message =
      'Demo content. Not connected to the backend. '
      'Nothing here is real or AI output.';

  @override
  Widget build(BuildContext context) {
    if (!forceShow && AppEnvironment.useDemo) {
      return const SizedBox.shrink();
    }
    final AppColors colors = AppColors.of(context);
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: colors.warningSoft,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: <Widget>[
          Icon(Icons.science_outlined, size: 16, color: colors.warning),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: AppTypography.medium(
                fontSize: 12,
                color: colors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
