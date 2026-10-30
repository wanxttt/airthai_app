import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:airthai/core/routing/route_guards.dart';
import 'package:airthai/core/security/session_manager.dart';
import 'package:airthai/core/security/token_manager.dart';
import 'package:airthai/core/storage/secure_storage.dart';
import 'package:airthai/features/auth/presentation/screens/login_screen.dart';

void main() {
  group('RouteGuards Tests', () {
    late InMemorySecureStorage storage;
    late TokenManager tokenManager;
    late SessionManager sessionManager;

    setUp(() {
      storage = InMemorySecureStorage();
      tokenManager = TokenManager(storage: storage);
      sessionManager = SessionManager(
        storage: storage,
        tokenManager: tokenManager,
      );
      sessionManager.setAuthMode(AuthMode.devMock);
    });

    test('isProtectedRoute correctly classifies protected vs public routes', () {
      expect(RouteGuards.isProtectedRoute('/dashboard'), true);
      expect(RouteGuards.isProtectedRoute('/sales'), true);
      expect(RouteGuards.isProtectedRoute('/inventory'), true);
      expect(RouteGuards.isProtectedRoute('/customers'), true);
      expect(RouteGuards.isProtectedRoute('/suppliers'), true);
      expect(RouteGuards.isProtectedRoute('/purchases'), true);
      expect(RouteGuards.isProtectedRoute('/expenses'), true);
      expect(RouteGuards.isProtectedRoute('/reports'), true);
      expect(RouteGuards.isProtectedRoute('/accounting'), true);
      expect(RouteGuards.isProtectedRoute('/payments'), true);
      expect(RouteGuards.isProtectedRoute('/copilot'), true);
      expect(RouteGuards.isProtectedRoute('/audit'), true);
      expect(RouteGuards.isProtectedRoute('/notifications'), true);
      expect(RouteGuards.isProtectedRoute('/subscriptions'), true);
      expect(RouteGuards.isProtectedRoute('/login'), false);
      expect(RouteGuards.isProtectedRoute('/register'), false);
      expect(RouteGuards.isProtectedRoute('/'), false);
      expect(RouteGuards.isProtectedRoute('/home'), false);
      expect(RouteGuards.isProtectedRoute('/privacy'), false);
      expect(RouteGuards.isProtectedRoute('/terms'), false);
    });

    testWidgets('requireAuth redirects unauthenticated session to LoginScreen', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      expect(sessionManager.isAuthenticated, false);

      await tester.pumpWidget(
        MaterialApp(
          home: RouteGuards.requireAuth(
            sessionManager: sessionManager,
            child: const Scaffold(
              body: Text('Protected Secret Content'),
            ),
          ),
        ),
      );

      // Must NOT show protected content
      expect(find.text('Protected Secret Content'), findsNothing);
      // Must show LoginScreen
      expect(find.byType(LoginScreen), findsOneWidget);
    });

    testWidgets('requireAuth allows authenticated session through to protected widget', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      // Login using runAsync to handle real asynchronous future
      await tester.runAsync(() async {
        final loginRes = await sessionManager.login(
          email: 'owner@airthai.in',
          password: 'Admin@123',
        );
        expect(loginRes.success, true);
      });
      expect(sessionManager.isAuthenticated, true);

      await tester.pumpWidget(
        MaterialApp(
          home: RouteGuards.requireAuth(
            sessionManager: sessionManager,
            child: const Scaffold(
              body: Text('Protected Secret Content'),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Must show protected content
      expect(find.text('Protected Secret Content'), findsOneWidget);
      expect(find.byType(LoginScreen), findsNothing);
    });
  });
}
