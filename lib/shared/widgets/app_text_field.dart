import 'package:flutter/material.dart';
import 'package:round_ai/app/app_colors.dart';
import 'package:round_ai/core/theme/app_typography.dart';

class AppTextField extends StatelessWidget {
  const AppTextField({
    required this.controller,
    required this.hint,
    this.label,
    this.icon,
    this.obscureText = false,
    this.keyboardType,
    this.suffix,
    super.key,
  });

  final TextEditingController controller;
  final String hint;
  final String? label;
  final IconData? icon;
  final bool obscureText;
  final TextInputType? keyboardType;
  final Widget? suffix;

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = AppPalette.of(context);
    final Widget field = TextField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      style: AppTypography.medium(fontSize: 15, color: palette.textPrimary),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: AppTypography.regular(
          color: palette.textSecondary,
          fontSize: 14,
        ),
        prefixIcon: icon == null
            ? null
            : Icon(icon, color: palette.textSecondary, size: 20),
        suffixIcon: suffix,
        filled: true,
        fillColor: palette.surface,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
        border: _border(palette.border),
        enabledBorder: _border(palette.border),
        focusedBorder: _border(palette.primary, width: 1.4),
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        if (label != null) ...<Widget>[
          Text(
            label!,
            style: AppTypography.medium(
              color: palette.textPrimary,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 8),
        ],
        SizedBox(height: 56, child: field),
      ],
    );
  }

  OutlineInputBorder _border(Color color, {double width = 1}) {
    return OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: color, width: width),
    );
  }
}
