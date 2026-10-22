import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:airthai/core/security/session_manager.dart';
import 'package:airthai/features/auth/presentation/screens/register_screen.dart';
import 'package:airthai/shared/widgets/app_shell.dart';

void main() {
  setUp(() async {
    await SessionManager.instance.logout();
    SessionManager.instance.setAuthMode(AuthMode.devMock);
  });

  Widget createRegisterTestWidget() {
    return const MaterialApp(
      home: RegisterScreen(),
    );
  }

  testWidgets('RegisterScreen renders all fields and labels', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(createRegisterTestWidget());

    expect(find.text('Create your account'), findsOneWidget);
    expect(find.text('Full name'), findsOneWidget);
    expect(find.text('Business email'), findsOneWidget);
    expect(find.text('Phone number'), findsOneWidget);
    expect(find.text('Password'), findsOneWidget);
    expect(find.text('Confirm password'), findsOneWidget);
    expect(find.byType(Checkbox), findsOneWidget);
    expect(find.text('Create account'), findsOneWidget);
  });

  testWidgets('Submitting empty form triggers validation messages', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(createRegisterTestWidget());

    await tester.tap(find.text('Create account'));
    await tester.pumpAndSettle();

    expect(find.text('Please enter your name'), findsOneWidget);
    expect(find.text('Please enter your email'), findsOneWidget);
    expect(find.text('Please enter your phone number'), findsOneWidget);
    expect(find.text('Please create a password'), findsOneWidget);
    expect(find.text('Please confirm your password'), findsOneWidget);
  });

  testWidgets('Password mismatch validation error', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(createRegisterTestWidget());

    final textFields = find.byType(TextFormField);
    await tester.enterText(textFields.at(0), 'Rohit Sen');
    await tester.enterText(textFields.at(1), 'rohit@example.com');
    await tester.enterText(textFields.at(2), '9876543210');
    await tester.enterText(textFields.at(3), 'Password123');
    await tester.enterText(textFields.at(4), 'DifferentPassword');

    await tester.tap(find.text('Create account'));
    await tester.pumpAndSettle();

    expect(find.text('Passwords do not match'), findsOneWidget);
  });

  testWidgets('Unchecked terms checkbox shows alert snackbar', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(createRegisterTestWidget());

    final textFields = find.byType(TextFormField);
    await tester.enterText(textFields.at(0), 'Rohit Sen');
    await tester.enterText(textFields.at(1), 'rohit@example.com');
    await tester.enterText(textFields.at(2), '9876543210');
    await tester.enterText(textFields.at(3), 'Password123');
    await tester.enterText(textFields.at(4), 'Password123');

    // Do NOT check terms checkbox
    await tester.tap(find.text('Create account'));
    await tester.pumpAndSettle();

    expect(find.text('Please accept the Terms & Conditions to continue.'), findsOneWidget);
  });

  testWidgets('Valid registration form submission navigates to AppShell', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(createRegisterTestWidget());

    final textFields = find.byType(TextFormField);
    await tester.enterText(textFields.at(0), 'Ananya Roy');
    await tester.enterText(textFields.at(1), 'ananya.roy@enterprise.com');
    await tester.enterText(textFields.at(2), '9812345678');
    await tester.enterText(textFields.at(3), 'SecurePass@123');
    await tester.enterText(textFields.at(4), 'SecurePass@123');

    // Check terms checkbox
    await tester.tap(find.byType(Checkbox));
    await tester.pumpAndSettle();

    // Submit
    await tester.tap(find.text('Create account'));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();

    expect(find.byType(AppShell), findsOneWidget);
    expect(SessionManager.instance.isAuthenticated, true);
    expect(SessionManager.instance.currentUser?.fullName, 'Ananya Roy');
  });
}

