import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:round_ai/core/errors/result.dart';
import 'package:round_ai/features/authentication/repository/auth_repository.dart';
import 'package:round_ai/features/authentication/screens/sign_in_screen.dart';

void main() {
  testWidgets('login screen shows the brand lockup and form', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(393, 852);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(home: SignInScreen(repository: FakeAuthRepository())),
    );
    await tester.pump();

    expect(find.text('Smarter Rounds.'), findsOneWidget);
    expect(find.text('Better Care.'), findsOneWidget);
    expect(find.text('Welcome Back'), findsOneWidget);
    expect(find.text('Sign in to continue to RoundsAI'), findsOneWidget);
    expect(find.text('Email Address'), findsOneWidget);
    expect(find.text('Password'), findsOneWidget);
    expect(find.text('Remember me'), findsOneWidget);
    // No reset flow: the backend has none.
    expect(find.text('Forgot Password?'), findsNothing);
    expect(
      find.text('Forgot your password? Contact your administrator.'),
      findsOneWidget,
    );
    expect(find.text('Sign In'), findsOneWidget);
    expect(find.text('Continue with Apple'), findsOneWidget);
    expect(
      find.text('Secure access for healthcare professionals'),
      findsOneWidget,
    );
    expect(find.text('Continue with Google'), findsNothing);
    expect(find.text('Continue with Microsoft'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('apple button explains that Apple sign-in is not connected', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(393, 852);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(home: SignInScreen(repository: FakeAuthRepository())),
    );
    await tester.pump();

    await tester.ensureVisible(find.text('Continue with Apple'));
    await tester.tap(find.text('Continue with Apple'));
    await tester.pump();

    expect(find.text('Apple sign-in'), findsOneWidget);
    expect(find.textContaining('No Apple ID is contacted'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('empty sign-in stays on the form', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(393, 852);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(home: SignInScreen(repository: FakeAuthRepository())),
    );
    await tester.pump();

    await tester.ensureVisible(find.text('Sign In'));
    await tester.tap(find.text('Sign In'));
    await tester.pump();

    expect(find.text('Enter your email and password.'), findsOneWidget);
    expect(find.text('Welcome Back'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

class FakeAuthRepository implements AuthRepository {
  @override
  Future<Result<void>> signIn({
    required String email,
    required String password,
    required bool rememberMe,
  }) async {
    return const Ok<void>(null);
  }
}
