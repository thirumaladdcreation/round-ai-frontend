import 'package:flutter/material.dart';
import 'package:round_ai/app/app_colors.dart';
import 'package:round_ai/app/app_typography.dart';
import 'package:round_ai/shared/widgets/glass_text_field.dart';

class SignInFields extends StatelessWidget {
  const SignInFields({
    required this.emailController,
    required this.passwordController,
    required this.obscure,
    required this.rememberMe,
    required this.onToggleObscure,
    required this.onRememberChanged,
    this.onPasswordSubmitted,
    super.key,
  });

  final TextEditingController emailController;
  final TextEditingController passwordController;
  final bool obscure;
  final bool rememberMe;
  final VoidCallback onToggleObscure;
  final ValueChanged<bool> onRememberChanged;
  final ValueChanged<String>? onPasswordSubmitted;

  @override
  Widget build(BuildContext context) {
    final bool dark = Theme.of(context).brightness == Brightness.dark;
    final Color muted = dark
        ? RoundsBrand.pale.withValues(alpha: 0.72)
        : RoundsBrand.slate;
    return Column(
      children: <Widget>[
        GlassTextField(
          controller: emailController,
          hint: 'Email Address',
          icon: Icons.mail_outline_rounded,
          keyboardType: TextInputType.emailAddress,
          textInputAction: TextInputAction.next,
          autofillHints: const <String>[AutofillHints.email],
          style: _fieldStyle(dark),
          hintStyle: _hintStyle(dark),
        ),
        const SizedBox(height: 12),
        GlassTextField(
          controller: passwordController,
          hint: 'Password',
          icon: Icons.lock_outline_rounded,
          obscureText: obscure,
          textInputAction: TextInputAction.done,
          autofillHints: const <String>[AutofillHints.password],
          style: _fieldStyle(dark),
          hintStyle: _hintStyle(dark),
          onSubmitted: onPasswordSubmitted,
          suffix: IconButton(
            tooltip: obscure ? 'Show password' : 'Hide password',
            onPressed: onToggleObscure,
            icon: Icon(
              obscure
                  ? Icons.visibility_outlined
                  : Icons.visibility_off_outlined,
              color: muted,
              size: 20,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: <Widget>[
            SizedBox(
              width: 24,
              height: 24,
              child: Checkbox(
                value: rememberMe,
                activeColor: RoundsBrand.aqua,
                checkColor: RoundsBrand.charcoal,
                side: BorderSide(color: muted),
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                visualDensity: VisualDensity.compact,
                onChanged: (bool? value) => onRememberChanged(value ?? false),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: GestureDetector(
                onTap: () => onRememberChanged(!rememberMe),
                child: Text(
                  'Remember me',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.inter(
                    AppTypography.regular(color: muted, fontSize: 13),
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        // The backend has no password reset.
        Text(
          'Forgot your password? Contact your administrator.',
          textAlign: TextAlign.center,
          style: AppTypography.inter(
            AppTypography.regular(color: muted, fontSize: 12.5),
          ),
        ),
      ],
    );
  }

  TextStyle _fieldStyle(bool dark) {
    return AppTypography.inter(
      AppTypography.medium(
        fontSize: 15,
        color: dark ? RoundsBrand.white : RoundsBrand.charcoal,
      ),
    );
  }

  TextStyle _hintStyle(bool dark) {
    return AppTypography.inter(
      AppTypography.regular(
        color: dark
            ? RoundsBrand.pale.withValues(alpha: 0.62)
            : RoundsBrand.slate.withValues(alpha: 0.62),
        fontSize: 14,
      ),
    );
  }
}
