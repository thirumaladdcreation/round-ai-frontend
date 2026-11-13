import 'package:flutter/material.dart';
import 'package:round_ai/core/theme/app_colors.dart';
import 'package:round_ai/core/theme/app_typography.dart';

/// Covers the app with a plain screen whenever it is not in the foreground, so
/// the app switcher never shows patient data. The OS takes its snapshot once
/// the app leaves the `resumed` state, so the cover is up by then.
class PrivacyShield extends StatefulWidget {
  const PrivacyShield({required this.child, super.key});

  final Widget child;

  @override
  State<PrivacyShield> createState() => _PrivacyShieldState();
}

class _PrivacyShieldState extends State<PrivacyShield>
    with WidgetsBindingObserver {
  late bool _covered = _isCovering(
    WidgetsBinding.instance.lifecycleState ?? AppLifecycleState.resumed,
  );

  /// A call or a permission dialog also makes the app `inactive`, and covering
  /// then is fine. Only `resumed` shows the app.
  static bool _isCovering(AppLifecycleState state) =>
      state != AppLifecycleState.resumed;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final bool covered = _isCovering(state);
    if (covered != _covered) setState(() => _covered = covered);
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: <Widget>[widget.child, if (_covered) const _Cover()],
    );
  }
}

class _Cover extends StatelessWidget {
  const _Cover();

  @override
  Widget build(BuildContext context) {
    final AppColors colors = AppColors.of(context);
    return ExcludeSemantics(
      child: ColoredBox(
        key: const ValueKey<String>('privacy-cover'),
        color: colors.background,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(Icons.lock_outline_rounded, size: 32, color: colors.primary),
              const SizedBox(height: 12),
              Text(
                'RoundsAI',
                style: AppTypography.semiBold(
                  fontSize: 18,
                  color: colors.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
