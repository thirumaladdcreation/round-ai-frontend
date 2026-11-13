import 'package:flutter/material.dart';
import 'package:round_ai/app/app_colors.dart';
import 'package:round_ai/app/app_typography.dart';

/// Shared frosted input. Email and password each use their own instance.
class GlassTextField extends StatefulWidget {
  const GlassTextField({
    required this.controller,
    required this.hint,
    this.icon,
    this.obscureText = false,
    this.keyboardType,
    this.textInputAction,
    this.autofillHints,
    this.suffix,
    this.style,
    this.hintStyle,
    this.onSubmitted,
    super.key,
  });

  final TextEditingController controller;
  final String hint;
  final IconData? icon;
  final bool obscureText;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final Iterable<String>? autofillHints;
  final Widget? suffix;
  final TextStyle? style;
  final TextStyle? hintStyle;
  final ValueChanged<String>? onSubmitted;

  @override
  State<GlassTextField> createState() => _GlassTextFieldState();
}

class _GlassTextFieldState extends State<GlassTextField> {
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(_onFocus);
  }

  void _onFocus() => setState(() {});

  @override
  void dispose() {
    _focusNode
      ..removeListener(_onFocus)
      ..dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool dark = Theme.of(context).brightness == Brightness.dark;
    final Color fill = dark
        ? RoundsBrand.white.withValues(alpha: 0.1)
        : RoundsBrand.white.withValues(alpha: 0.55);
    final Color border = RoundsBrand.white.withValues(alpha: dark ? 0.28 : 0.7);
    final Color text = dark ? RoundsBrand.white : RoundsBrand.charcoal;
    final Color hintColor = dark
        ? RoundsBrand.pale.withValues(alpha: 0.62)
        : RoundsBrand.slate.withValues(alpha: 0.62);
    final TextStyle fieldStyle =
        widget.style ?? AppTypography.medium(fontSize: 15, color: text);
    final TextStyle placeholder =
        widget.hintStyle ??
        AppTypography.regular(color: hintColor, fontSize: 14);
    final bool focused = _focusNode.hasFocus;

    return Semantics(
      textField: true,
      label: widget.hint,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: fill,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: focused ? RoundsBrand.aqua : border),
        ),
        child: SizedBox(
          height: 56,
          child: Row(
            children: <Widget>[
              if (widget.icon != null) ...<Widget>[
                const SizedBox(width: 14),
                Icon(widget.icon, color: hintColor, size: 20),
                const SizedBox(width: 10),
              ] else
                const SizedBox(width: 16),
              Expanded(
                child: TextField(
                  focusNode: _focusNode,
                  controller: widget.controller,
                  obscureText: widget.obscureText,
                  keyboardType: widget.keyboardType,
                  textInputAction: widget.textInputAction,
                  autofillHints: widget.autofillHints,
                  style: fieldStyle,
                  cursorColor: RoundsBrand.aqua,
                  onTapOutside: (_) => _focusNode.unfocus(),
                  onSubmitted: widget.onSubmitted,
                  decoration: InputDecoration(
                    isCollapsed: true,
                    hintText: widget.hint,
                    hintStyle: placeholder,
                    filled: false,
                    contentPadding: EdgeInsets.zero,
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    disabledBorder: InputBorder.none,
                    errorBorder: InputBorder.none,
                    focusedErrorBorder: InputBorder.none,
                  ),
                ),
              ),
              if (widget.suffix != null)
                widget.suffix!
              else
                const SizedBox(width: 14),
            ],
          ),
        ),
      ),
    );
  }
}
