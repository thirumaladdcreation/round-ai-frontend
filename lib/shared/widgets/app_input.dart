import 'package:flutter/material.dart';
import 'package:round_ai/core/theme/app_colors.dart';
import 'package:round_ai/core/theme/app_typography.dart';

/// Look shared by the data-entry forms.
InputDecoration appInputDecoration(
  BuildContext context, {
  required String label,
  String? hint,
  String? helper,
}) {
  final AppColors colors = AppColors.of(context);
  OutlineInputBorder border(Color color, [double width = 1]) {
    return OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: color, width: width),
    );
  }

  return InputDecoration(
    labelText: label,
    hintText: hint,
    helperText: helper,
    helperMaxLines: 3,
    filled: true,
    fillColor: colors.inputFill,
    labelStyle: AppTypography.regular(
      color: colors.textSecondary,
      fontSize: 14,
    ),
    floatingLabelStyle: AppTypography.medium(
      color: colors.textPrimary,
      fontSize: 14,
    ),
    hintStyle: AppTypography.regular(color: colors.textMuted, fontSize: 15),
    helperStyle: AppTypography.regular(color: colors.textMuted, fontSize: 13),
    border: border(colors.border),
    enabledBorder: border(colors.border),
    focusedBorder: border(colors.primary, 1.4),
  );
}

/// Shown under every field that is sent to a model as typed.
class FreeTextHint extends StatelessWidget {
  const FreeTextHint({super.key});

  static const String text = 'Do not enter names, MRNs or dates of birth.';

  @override
  Widget build(BuildContext context) {
    final AppColors colors = AppColors.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(
        children: <Widget>[
          Icon(Icons.shield_outlined, size: 16, color: colors.textSecondary),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              text,
              style: AppTypography.regular(
                fontSize: 13,
                color: colors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
