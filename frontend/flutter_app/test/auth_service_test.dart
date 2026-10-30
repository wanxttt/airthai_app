import 'package:flutter_test/flutter_test.dart';

import 'package:airthai/core/constants/storage_keys.dart';
import 'package:airthai/core/network/api_client.dart';
import 'package:airthai/core/security/session_manager.dart';
import 'package:airthai/core/security/token_manager.dart';
import 'package:airthai/core/storage/secure_storage.dart';

void main() {
  group('SessionManager & TokenManager Unit Tests', () {
    late InMemorySecureStorage storage;
    late TokenManager tokenManager;
    late SessionManager sessionManager;

    setUp(() {
      storage = InMemorySecureStorage();
      tokenManager = TokenManager(storage: storage);
      sessionManager = SessionManager(
        storage: storage,
        tokenManager: tokenManager,
        apiClient: ApiClient(baseUrl: 'http://127.0.0.1:9999'),
      );
    });

    test('Initial state is unauthenticated and initialized with secure default', () async {
      await sessionManager.initialize();
      expect(sessionManager.isAuthenticated, false);
      expect(sessionManager.currentUser, isNull);
      expect(sessionManager.currentSession, isNull);
      expect(sessionManager.authMode, AuthMode.restBackend);
    });

    test('Login with empty or invalid email fails with validation error', () async {
      final res1 = await sessionManager.login(email: '', password: 'Password123');
      expect(res1.success, false);
      expect(res1.errorMessage, contains('valid email'));

      final res2 = await sessionManager.login(email: 'invalid-email', password: 'Password123');
      expect(res2.success, false);
      expect(res2.errorMessage, contains('valid email'));
    });

    test('Login with short password (< 6 chars) fails with validation error', () async {
      final res = await sessionManager.login(email: 'owner@airthai.in', password: '123');
      expect(res.success, false);
      expect(res.errorMessage, contains('at least 6 characters'));
    });

    test('Login with unregistered email in dev mode returns clear error', () async {
      sessionManager.setAuthMode(AuthMode.devMock);
      final res = await sessionManager.login(
        email: 'unknown@example.com',
        password: 'Password123',
      );
      expect(res.success, false);
      expect(res.errorMessage, contains('No account found'));
      expect(sessionManager.isAuthenticated, false);
    });

    test('Login with incorrect password in dev mode is rejected', () async {
      sessionManager.setAuthMode(AuthMode.devMock);
      final res = await sessionManager.login(
        email: 'owner@airthai.in',
        password: 'WrongPassword!',
      );
      expect(res.success, false);
      expect(res.errorMessage, contains('Incorrect password'));
      expect(sessionManager.isAuthenticated, false);
    });

    test('Login with valid dev credentials succeeds and creates session', () async {
      sessionManager.setAuthMode(AuthMode.devMock);
      final res = await sessionManager.login(
        email: 'owner@airthai.in',
        password: 'Admin@123',
        rememberMe: true,
      );

      expect(res.success, true);
      expect(sessionManager.isAuthenticated, true);
      expect(sessionManager.currentUser?.email, 'owner@airthai.in');
      expect(sessionManager.currentUser?.fullName, 'Rajesh Sharma');
      expect(sessionManager.currentUser?.role, 'OWNER');

      // Verify token was stored
      final token = await tokenManager.getAccessToken();
      expect(token, isNotNull);
      expect(token, startsWith('dev_mock_jwt_'));

      // Verify remember me email was stored
      expect(sessionManager.rememberMeEmail, 'owner@airthai.in');
      expect(sessionManager.isRememberMeEnabled, true);
    });

    test('Registration creates user account and signs in', () async {
      sessionManager.setAuthMode(AuthMode.devMock);
      final res = await sessionManager.register(
        name: 'Vikram Malhotra',
        email: 'vikram@malhotratech.com',
        phone: '9811223344',
        password: 'SecurePassword123',
      );

      expect(res.success, true);
      expect(sessionManager.isAuthenticated, true);
      expect(sessionManager.currentUser?.fullName, 'Vikram Malhotra');
      expect(sessionManager.currentUser?.email, 'vikram@malhotratech.com');
      expect(sessionManager.currentUser?.businessId, isNotNull);

      // Verify new user can now login
      await sessionManager.logout();
      expect(sessionManager.isAuthenticated, false);

      final loginRes = await sessionManager.login(
        email: 'vikram@malhotratech.com',
        password: 'SecurePassword123',
      );
      expect(loginRes.success, true);
      expect(sessionManager.isAuthenticated, true);
    });

    test('Registration with existing email is rejected', () async {
      sessionManager.setAuthMode(AuthMode.devMock);
      final res = await sessionManager.register(
        name: 'Duplicate Owner',
        email: 'owner@airthai.in',
        phone: '9876543210',
        password: 'Admin@123',
      );

      expect(res.success, false);
      expect(res.errorMessage, contains('already exists'));
    });

    test('Password reset succeeds for registered email, fails for unknown email', () async {
      sessionManager.setAuthMode(AuthMode.devMock);
      final res1 = await sessionManager.resetPassword(email: 'owner@airthai.in');
      expect(res1.success, true);

      final res2 = await sessionManager.resetPassword(email: 'nobody@example.com');
      expect(res2.success, false);
      expect(res2.errorMessage, contains('No account registered'));
    });

    test('Logout clears session and tokens while preserving Remember Me preference', () async {
      sessionManager.setAuthMode(AuthMode.devMock);
      await sessionManager.login(
        email: 'owner@airthai.in',
        password: 'Admin@123',
        rememberMe: true,
      );
      expect(sessionManager.isAuthenticated, true);

      await sessionManager.logout();
      expect(sessionManager.isAuthenticated, false);
      expect(sessionManager.currentUser, isNull);
      expect(sessionManager.currentSession, isNull);

      final token = await tokenManager.getAccessToken();
      expect(token, isNull);

      // Remember me email is preserved
      expect(sessionManager.rememberMeEmail, 'owner@airthai.in');
    });

    test('REST backend mode gracefully handles unreachable server', () async {
      sessionManager.setAuthMode(AuthMode.restBackend);
      expect(sessionManager.authMode, AuthMode.restBackend);

      final res = await sessionManager.login(
        email: 'test@airthai.in',
        password: 'Password123',
      );

      expect(res.success, false);
      expect(res.errorMessage, contains('Cannot connect to backend server'));
    });

    test('Session restoration initializes active session from secure storage', () async {
      await tokenManager.saveTokens(
        accessToken: 'saved_access_token_123',
        refreshToken: 'saved_refresh_token_123',
        expiry: DateTime.now().add(const Duration(hours: 1)),
      );
      await storage.write(key: StorageKeys.currentUserId, value: 'usr_saved');
      await storage.write(key: StorageKeys.currentUserEmail, value: 'saved@airthai.in');
      await storage.write(key: StorageKeys.currentUserName, value: 'Saved User');
      await storage.write(key: StorageKeys.currentBusinessId, value: 'biz_saved');
      await storage.write(key: StorageKeys.currentUserRole, value: 'OWNER');

      final newSessionManager = SessionManager(
        storage: storage,
        tokenManager: tokenManager,
      );
      await newSessionManager.initialize();

      expect(newSessionManager.isAuthenticated, true);
      expect(newSessionManager.currentUser?.id, 'usr_saved');
      expect(newSessionManager.currentUser?.email, 'saved@airthai.in');
      expect(newSessionManager.currentUser?.businessId, 'biz_saved');
    });

    test('updateBusinessSetup updates business details successfully', () async {
      sessionManager.setAuthMode(AuthMode.devMock);
      await sessionManager.login(
        email: 'owner@airthai.in',
        password: 'Admin@123',
      );
      expect(sessionManager.isAuthenticated, true);

      final res = await sessionManager.updateBusinessSetup(
        businessName: 'Sharma Traders Pvt Ltd',
        gstin: '27AAAAA0000A1Z5',
        state: 'Maharashtra',
        taxType: 'REGULAR',
      );

      expect(res.success, true);
    });

    test('SEC-AI-01: Default authentication mode is restBackend, preventing silent mock bypass', () async {
      final freshManager = SessionManager(
        storage: storage,
        tokenManager: tokenManager,
      );
      expect(freshManager.authMode, AuthMode.restBackend);
    });

    test('SEC-AI-02: Missing or invalid backend authentication never creates an authenticated session', () async {
      final freshManager = SessionManager(
        storage: storage,
        tokenManager: tokenManager,
        apiClient: ApiClient(baseUrl: 'http://127.0.0.1:9999'),
      );
      expect(freshManager.authMode, AuthMode.restBackend);

      final res = await freshManager.login(
        email: 'attacker@airthai.in',
        password: 'Password123',
      );
      expect(res.success, false);
      expect(freshManager.isAuthenticated, false);
      expect(freshManager.currentUser, isNull);
      expect(freshManager.currentSession, isNull);
    });
  });
}

