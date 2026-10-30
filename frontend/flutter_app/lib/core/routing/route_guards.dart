import 'package:flutter/material.dart';

import '../security/session_manager.dart';
import '../../features/auth/presentation/screens/login_screen.dart';

/// Route guard ensuring protected views require an authenticated session.
///
/// Phase 1: Authentication & Navigation Security
class RouteGuards {
  const RouteGuards._();

  /// Wraps a widget with session authentication verification.
  /// If session is null/unauthenticated, safely redirects to [LoginScreen].
  static Widget requireAuth({
    required Widget child,
    SessionManager? sessionManager,
  }) {
    final session = sessionManager ?? SessionManager.instance;
    if (!session.isAuthenticated) {
      return const LoginScreen();
    }
    return child;
  }

  /// Verifies if a given route name is protected by authentication.
  static bool isProtectedRoute(String routeName) {
    return routeName == '/dashboard' ||
        routeName.startsWith('/sales') ||
        routeName.startsWith('/inventory') ||
        routeName.startsWith('/customers') ||
        routeName.startsWith('/suppliers') ||
        routeName.startsWith('/purchases') ||
        routeName.startsWith('/expenses') ||
        routeName.startsWith('/reports') ||
        routeName.startsWith('/accounting') ||
        routeName.startsWith('/payments') ||
        routeName.startsWith('/copilot') ||
        routeName.startsWith('/audit') ||
        routeName.startsWith('/notifications') ||
        routeName.startsWith('/subscriptions') ||
        routeName.startsWith('/settings');
  }
}

