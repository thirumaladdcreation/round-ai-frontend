import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:round_ai/app/app_colors.dart';
import 'package:round_ai/core/di/injection_container.dart';
import 'package:round_ai/features/authentication/bloc/auth_bloc.dart';
import 'package:round_ai/features/authentication/repository/auth_repository.dart';
import 'package:round_ai/features/authentication/widgets/sign_in_backdrop.dart';
import 'package:round_ai/features/authentication/widgets/sign_in_footer.dart';
import 'package:round_ai/features/authentication/widgets/sign_in_form.dart';
import 'package:round_ai/features/authentication/widgets/sign_in_glass_card.dart';
import 'package:round_ai/features/authentication/widgets/sign_in_lockup.dart';

class SignInScreen extends StatelessWidget {
  const SignInScreen({this.repository, super.key});

  final AuthRepository? repository;

  @override
  Widget build(BuildContext context) {
    final AuthRepository source =
        repository ?? InjectionContainer.instance.authRepository;
    final bool useStoredAccount = repository == null;
    final String? email = useStoredAccount
        ? InjectionContainer.instance.appStorage.rememberedEmail
        : null;
    final bool remember =
        useStoredAccount &&
        InjectionContainer.instance.appStorage.rememberMeEnabled;
    return BlocProvider<AuthBloc>(
      create: (_) => AuthBloc(source),
      child: SignInLayout(initialEmail: email, rememberMe: remember),
    );
  }
}

class SignInLayout extends StatelessWidget {
  const SignInLayout({this.initialEmail, this.rememberMe = false, super.key});

  final String? initialEmail;
  final bool rememberMe;

  @override
  Widget build(BuildContext context) {
    final bool dark = Theme.of(context).brightness == Brightness.dark;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: dark ? Brightness.light : Brightness.dark,
        statusBarBrightness: dark ? Brightness.dark : Brightness.light,
      ),
      child: GestureDetector(
        onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
        behavior: HitTestBehavior.opaque,
        child: Scaffold(
          backgroundColor: dark ? RoundsBrand.charcoal : RoundsBrand.pale,
          resizeToAvoidBottomInset: true,
          body: Stack(
            fit: StackFit.expand,
            children: <Widget>[
              const RepaintBoundary(child: SignInBackdrop()),
              SafeArea(
                child: LayoutBuilder(
                  builder: (BuildContext context, BoxConstraints constraints) {
                    return SingleChildScrollView(
                      keyboardDismissBehavior:
                          ScrollViewKeyboardDismissBehavior.onDrag,
                      padding: const EdgeInsets.fromLTRB(22, 18, 22, 16),
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          minHeight: constraints.maxHeight - 34,
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: <Widget>[
                            const SignInLockup(),
                            const SizedBox(height: 22),
                            SignInGlassCard(
                              child: SignInForm(
                                initialEmail: initialEmail,
                                rememberMe: rememberMe,
                              ),
                            ),
                            const SizedBox(height: 22),
                            const SignInFooter(),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
