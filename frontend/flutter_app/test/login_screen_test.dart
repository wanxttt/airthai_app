import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:airthai/core/security/session_manager.dart';
import 'package:airthai/features/auth/presentation/screens/login_screen.dart';
import 'package:airthai/shared/widgets/app_shell.dart';

void main() {
  setUp(() async {
    await SessionManager.instance.logout();
    SessionManager.instance.setAuthMode(AuthMode.devMock);
  });

  Widget createLoginTestWidget() {
    return const MaterialApp(
      home: LoginScreen(),
    );
  }

  testWidgets('LoginScreen renders all essential UI controls', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(createLoginTestWidget());

    expect(find.text('Welcome back'), findsOneWidget);
    expect(find.text('Email address'), findsOneWidget);
    expect(find.text('Password'), findsOneWidget);
    expect(find.text('Remember me'), findsOneWidget);
    expect(find.text('Forgot password?'), findsOneWidget);
    expect(find.text('Sign in'), findsOneWidget);
    expect(find.text('Continue with Google'), findsOneWidget);
    expect(find.text('Create account'), findsOneWidget);
  });

  testWidgets('Validation errors show when submitting empty form', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(createLoginTestWidget());

    await tester.tap(find.text('Sign in'));
    await tester.pumpAndSettle();

    expect(find.text('Please enter your email'), findsOneWidget);
    expect(find.text('Please enter your password'), findsOneWidget);
  });

  testWidgets('Validation error for invalid email and short password', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(createLoginTestWidget());

    await tester.enterText(find.byType(TextFormField).first, 'bad-email');
    await tester.enterText(find.byType(TextFormField).last, '123');
    await tester.tap(find.text('Sign in'));
    await tester.pumpAndSettle();

    expect(find.text('Please enter a valid email address'), findsOneWidget);
    expect(find.text('Password must be at least 6 characters'), findsOneWidget);
  });

  testWidgets('Google sign-in button displays configuration explanation dialog', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(createLoginTestWidget());

    await tester.tap(find.text('Continue with Google'));
    await tester.pumpAndSettle();

    expect(find.text('Google Sign-In'), findsOneWidget);
    expect(find.textContaining('GOOGLE_CLIENT_ID'), findsOneWidget);

    await tester.tap(find.text('Understood'));
    await tester.pumpAndSettle();

    expect(find.text('Google Sign-In'), findsNothing);
  });

  testWidgets('Forgot password opens reset dialog', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(createLoginTestWidget());

    await tester.tap(find.text('Forgot password?'));
    await tester.pumpAndSettle();

    expect(find.text('Reset Password'), findsOneWidget);
    expect(find.text('Send Reset Link'), findsOneWidget);

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(find.text('Reset Password'), findsNothing);
  });

  testWidgets('Valid login credentials navigate to AppShell', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(createLoginTestWidget());

    await tester.enterText(find.byType(TextFormField).first, 'owner@airthai.in');
    await tester.enterText(find.byType(TextFormField).last, 'Admin@123');
    await tester.tap(find.text('Sign in'));

    // Wait for auth delay and navigation
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();

    expect(find.byType(AppShell), findsOneWidget);
    expect(SessionManager.instance.isAuthenticated, true);
  });
}

