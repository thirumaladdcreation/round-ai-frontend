import 'package:flutter/material.dart';
import 'package:round_ai/app/app_colors.dart';
import 'package:round_ai/app/app_typography.dart';

enum AppButtonVariant { filled, outline }

/// Filled and outline actions for the whole app.
class AppButton extends StatelessWidget {
  const AppButton({
    required this.label,
    required this.onPressed,
    this.variant = AppButtonVariant.filled,
    this.loading = false,
    this.showArrow = false,
    this.icon,
    this.expand = true,
    this.useInter = false,
    this.backgroundColor,
    this.foregroundColor,
    this.borderColor,
    this.glowColor,
    super.key,
  });

  final String label;
  final VoidCallback? onPressed;
  final AppButtonVariant variant;
  final bool loading;
  final bool showArrow;
  final Widget? icon;
  final bool expand;
  final bool useInter;
  final Color? backgroundColor;
  final Color? foregroundColor;
  final Color? borderColor;
  final Color? glowColor;

  @override
  Widget build(BuildContext context) {
    final AppColors colors = AppColors.of(context);
    final bool filled = variant == AppButtonVariant.filled;
    final bool enabled = onPressed != null && !loading;
    final Color background =
        backgroundColor ?? (filled ? colors.button : Colors.transparent);
    final Color foreground =
        foregroundColor ?? (filled ? colors.white : colors.textPrimary);
    final Color line = borderColor ?? colors.border;
    final bool drawBorder = !filled || borderColor != null;
    final BorderSide side = drawBorder
        ? BorderSide(
            color: enabled ? line : line.withValues(alpha: 0.35),
            width: 1.2,
          )
        : BorderSide.none;

    final Widget button = SizedBox(
      width: expand ? double.infinity : null,
      height: 54,
      child: FilledButton(
        style: FilledButton.styleFrom(
          backgroundColor: background,
          disabledBackgroundColor: filled
              ? background.withValues(alpha: 0.45)
              : Colors.transparent,
          foregroundColor: foreground,
          disabledForegroundColor: loading
              ? foreground
              : foreground.withValues(alpha: 0.55),
          elevation: 0,
          shadowColor: Colors.transparent,
          side: side,
          minimumSize: Size(expand ? double.infinity : 0, 54),
          padding: const EdgeInsets.symmetric(horizontal: 18),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        onPressed: enabled ? onPressed : null,
        child: loading ? _spinner(foreground) : _label(foreground),
      ),
    );

    if (glowColor == null || !enabled) return button;
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: glowColor!.withValues(alpha: 0.28),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: button,
    );
  }

  Widget _spinner(Color color) {
    return SizedBox(
      width: 20,
      height: 20,
      child: CircularProgressIndicator(strokeWidth: 2.2, color: color),
    );
  }

  Widget _label(Color color) {
    final TextStyle style = AppTypography.semiBold(color: color, fontSize: 16);
    final Widget text = Text(
      label,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: useInter ? AppTypography.inter(style) : style,
    );
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
      children: <Widget>[
        if (icon != null) ...<Widget>[
          IconTheme(
            data: IconThemeData(color: color, size: 22),
            child: icon!,
          ),
          const SizedBox(width: 8),
        ],
        if (expand) Flexible(child: text) else text,
        if (showArrow) ...<Widget>[
          const SizedBox(width: 8),
          Icon(Icons.arrow_forward_rounded, size: 18, color: color),
        ],
      ],
    );
  }
}
