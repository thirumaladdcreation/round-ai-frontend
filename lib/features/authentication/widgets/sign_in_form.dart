import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:round_ai/app/app_colors.dart';
import 'package:round_ai/app/app_typography.dart';
import 'package:round_ai/core/config/app_environment.dart';
import 'package:round_ai/core/router/app_routes.dart';
import 'package:round_ai/features/authentication/bloc/auth_bloc.dart';
import 'package:round_ai/features/authentication/bloc/auth_event.dart';
import 'package:round_ai/features/authentication/bloc/auth_state.dart';
import 'package:round_ai/features/authentication/widgets/apple_sign_in_notice.dart';
import 'package:round_ai/features/authentication/widgets/sign_in_actions.dart';
import 'package:round_ai/features/authentication/widgets/sign_in_fields.dart';
import 'package:round_ai/shared/widgets/app_button.dart';

class SignInForm extends StatefulWidget {
  const SignInForm({this.initialEmail, this.rememberMe = false, super.key});

  final String? initialEmail;
  final bool rememberMe;

  @override
  State<SignInForm> createState() => SignInFormState();
}

class SignInFormState extends State<SignInForm> {
  late final TextEditingController _emailController;
  final TextEditingController _passwordController = TextEditingController();
  late bool _remember;
  bool _obscure = true;
  String? _validation;

  @override
  void initState() {
    super.initState();
    _emailController = TextEditingController(text: widget.initialEmail ?? '');
    _remember = widget.rememberMe;
  }

  @override
  void dispose() {
    FocusManager.instance.primaryFocus?.unfocus();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool dark = Theme.of(context).brightness == Brightness.dark;
    final Color heading = dark ? RoundsBrand.white : RoundsBrand.charcoal;
    final Color subtitle = dark ? RoundsBrand.pale : RoundsBrand.slate;
    return BlocConsumer<AuthBloc, AuthState>(
      listenWhen: (_, AuthState next) => next.signedIn,
      listener: (BuildContext context, AuthState state) {
        FocusManager.instance.primaryFocus?.unfocus();
        context.go(AppRoutes.selectTeam);
      },
      builder: (BuildContext context, AuthState state) {
        final bool busy = state.loading || state.signedIn;
        final String? message = state.error ?? _validation;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(
              'Welcome Back',
              textAlign: TextAlign.center,
              style: AppTypography.inter(
                AppTypography.bold(fontSize: 26, height: 1.15, color: heading),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Sign in to continue to RoundsAI',
              textAlign: TextAlign.center,
              style: AppTypography.inter(
                AppTypography.regular(color: subtitle, fontSize: 14),
              ),
            ),
            const SizedBox(height: 18),
            if (AppEnvironment.demoHints) ...<Widget>[
              Text(
                'Demo: resident@rounds.test / ChangeMe-12345\n'
                'Admin: admin@rounds.test / ChangeMe-12345\n'
                'Fictional data only — not for real patients.',
                textAlign: TextAlign.center,
                style: AppTypography.inter(
                  AppTypography.regular(color: subtitle, fontSize: 12, height: 1.35),
                ),
              ),
              const SizedBox(height: 14),
            ],
            SignInFields(
              emailController: _emailController,
              passwordController: _passwordController,
              obscure: _obscure,
              rememberMe: _remember,
              onToggleObscure: () => setState(() => _obscure = !_obscure),
              onRememberChanged: (bool value) =>
                  setState(() => _remember = value),
              onPasswordSubmitted: busy ? null : (_) => _submit(),
            ),
            if (message != null) ...<Widget>[
              const SizedBox(height: 8),
              Text(
                message,
                style: AppTypography.inter(
                  AppTypography.regular(color: heading, fontSize: 13),
                ),
              ),
            ],
            const SizedBox(height: 16),
            AppButton(
              label: 'Sign In',
              loading: state.loading,
              useInter: true,
              backgroundColor: RoundsBrand.aqua,
              foregroundColor: RoundsBrand.charcoal,
              glowColor: RoundsBrand.aqua,
              onPressed: busy ? null : _submit,
            ),
            const SizedBox(height: 14),
            const SignInOrDivider(),
            const SizedBox(height: 14),
            AppButton(
              label: 'Continue with Apple',
              useInter: true,
              icon: const Icon(Icons.apple, size: 22),
              backgroundColor: RoundsBrand.white,
              foregroundColor: RoundsBrand.charcoal,
              borderColor: RoundsBrand.slate.withValues(alpha: 0.12),
              onPressed: () => showAppleSignInNotice(context),
            ),
          ],
        );
      },
    );
  }

  void _submit() {
    FocusManager.instance.primaryFocus?.unfocus();
    final String email = _emailController.text.trim();
    final String password = _passwordController.text;
    // The server decides what a valid password is.
    if (email.isEmpty || password.isEmpty) {
      setState(() => _validation = 'Enter your email and password.');
      return;
    }
    setState(() => _validation = null);
    context.read<AuthBloc>().add(
      AuthSignInSubmitted(
        email: email,
        password: password,
        rememberMe: _remember,
      ),
    );
  }
}
