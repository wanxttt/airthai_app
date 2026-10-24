import 'dart:async';
import 'package:flutter/foundation.dart';

import '../constants/api_constants.dart';
import '../constants/storage_keys.dart';
import '../network/api_client.dart';
import '../storage/secure_storage.dart';
import 'token_manager.dart';

/// User Identity Model for AirthAI Client Session.
class AuthUser {
  final String id;
  final String email;
  final String fullName;
  final String? phone;
  final String? businessId;
  final String role;
  final bool isDevAccount;

  const AuthUser({
    required this.id,
    required this.email,
    required this.fullName,
    this.phone,
    this.businessId,
    this.role = 'OWNER',
    this.isDevAccount = false,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'email': email,
        'fullName': fullName,
        'phone': phone,
        'businessId': businessId,
        'role': role,
        'isDevAccount': isDevAccount,
      };

  factory AuthUser.fromMap(Map<String, dynamic> map) => AuthUser(
        id: map['id'] as String,
        email: map['email'] as String,
        fullName: map['fullName'] as String? ?? 'User',
        phone: map['phone'] as String?,
        businessId: map['businessId'] as String?,
        role: map['role'] as String? ?? 'OWNER',
        isDevAccount: map['isDevAccount'] as bool? ?? false,
      );
}

/// Active Authenticated Session Model.
class AuthSession {
  final String token;
  final String? refreshToken;
  final AuthUser user;
  final DateTime expiresAt;

  const AuthSession({
    required this.token,
    this.refreshToken,
    required this.user,
    required this.expiresAt,
  });
}

/// Authentication Mode Indicator.
enum AuthMode {
  /// Local development mode with validated test accounts.
  /// Clearly flagged for dev/offline testing.
  devMock,

  /// Live connection to NestJS REST backend (/api/v1/auth/*).
  restBackend,
}

/// Authentication Action Result.
class AuthResult {
  final bool success;
  final AuthUser? user;
  final AuthSession? session;
  final String? errorMessage;
  final bool isDevMock;

  const AuthResult({
    required this.success,
    this.user,
    this.session,
    this.errorMessage,
    this.isDevMock = false,
  });

  factory AuthResult.success({
    required AuthUser user,
    required AuthSession session,
    bool isDevMock = false,
  }) =>
      AuthResult(
        success: true,
        user: user,
        session: session,
        isDevMock: isDevMock,
      );

  factory AuthResult.failure(String message, {bool isDevMock = false}) =>
      AuthResult(
        success: false,
        errorMessage: message,
        isDevMock: isDevMock,
      );
}

/// Session & Authentication Manager for AirthAI.
///
/// Phase 1: Real Authentication & Session Lifecycle
/// Implements a clean boundary between Flutter UI and backend services.
/// Supports both REST API operations and local development validation.
class SessionManager extends ChangeNotifier {
  static final SessionManager instance = SessionManager._internal();

  final SecureStorage _storage;
  final TokenManager _tokenManager;
  final ApiClient _apiClient;

  SessionManager._internal({
    SecureStorage? storage,
    TokenManager? tokenManager,
    ApiClient? apiClient,
  })  : _storage = storage ?? SecureStorage.instance,
        _tokenManager = tokenManager ?? TokenManager(),
        _apiClient = apiClient ?? ApiClient();

  factory SessionManager({
    SecureStorage? storage,
    TokenManager? tokenManager,
    ApiClient? apiClient,
  }) {
    return SessionManager._internal(
      storage: storage,
      tokenManager: tokenManager,
      apiClient: apiClient,
    );
  }

  AuthMode _authMode = const String.fromEnvironment('AUTH_MODE') == 'backend'
      ? AuthMode.restBackend
      : AuthMode.devMock;
  AuthSession? _currentSession;
  String? _rememberMeEmail;
  bool _isRememberMeEnabled = false;
  bool _isInitialized = false;

  // Local development registered accounts store
  // Password stored hashed/obfuscated in real backend, stored securely for local dev mock validation
  final Map<String, _DevAccount> _devAccounts = {
    'owner@airthai.in': _DevAccount(
      user: const AuthUser(
        id: 'usr-owner-001',
        email: 'owner@airthai.in',
        fullName: 'Rajesh Sharma',
        phone: '9876543210',
        businessId: 'biz-001',
        role: 'OWNER',
        isDevAccount: true,
      ),
      password: 'Admin@123',
    ),
    'accountant@airthai.in': _DevAccount(
      user: const AuthUser(
        id: 'usr-acct-002',
        email: 'accountant@airthai.in',
        fullName: 'Pooja Verma',
        phone: '9876543211',
        businessId: 'biz-001',
        role: 'ACCOUNTANT',
        isDevAccount: true,
      ),
      password: 'Admin@123',
    ),
    'cashier@airthai.in': _DevAccount(
      user: const AuthUser(
        id: 'usr-cash-003',
        email: 'cashier@airthai.in',
        fullName: 'Amit Kumar',
        phone: '9876543212',
        businessId: 'biz-001',
        role: 'CASHIER',
        isDevAccount: true,
      ),
      password: 'Admin@123',
    ),
  };

  AuthMode get authMode => _authMode;
  bool get isAuthenticated => _currentSession != null;
  AuthUser? get currentUser => _currentSession?.user;
  AuthSession? get currentSession => _currentSession;
  String? get rememberMeEmail => _rememberMeEmail;
  bool get isRememberMeEnabled => _isRememberMeEnabled;
  bool get isInitialized => _isInitialized;

  /// Toggles between development mock mode and production REST backend mode
  void setAuthMode(AuthMode mode) {
    if (_authMode != mode) {
      _authMode = mode;
      notifyListeners();
    }
  }

  /// Initializes session state and loads saved preferences (e.g. Remember Me)
  Future<void> initialize() async {
    if (_isInitialized) return;

    // Load Remember Me email if enabled
    final savedRememberMe = await _storage.read(key: StorageKeys.rememberMeEnabled);
    if (savedRememberMe == 'true') {
      _isRememberMeEnabled = true;
      _rememberMeEmail = await _storage.read(key: StorageKeys.rememberMeEmail);
    }

    // Check for existing valid session token
    final hasToken = await _tokenManager.hasValidAccessToken();
    if (hasToken) {
      final token = await _tokenManager.getAccessToken();
      final refreshToken = await _tokenManager.getRefreshToken();
      final userId = await _storage.read(key: StorageKeys.currentUserId);
      final userEmail = await _storage.read(key: StorageKeys.currentUserEmail);
      final userName = await _storage.read(key: StorageKeys.currentUserName);
      final businessId = await _storage.read(key: StorageKeys.currentBusinessId);
      final userRole = await _storage.read(key: StorageKeys.currentUserRole);

      if (token != null && userId != null && userEmail != null) {
        final user = AuthUser(
          id: userId,
          email: userEmail,
          fullName: userName ?? 'User',
          businessId: businessId,
          role: userRole ?? 'OWNER',
          isDevAccount: _authMode == AuthMode.devMock,
        );

        _currentSession = AuthSession(
          token: token,
          refreshToken: refreshToken,
          user: user,
          expiresAt: DateTime.now().add(const Duration(days: 7)),
        );
      }
    }

    _isInitialized = true;
    notifyListeners();
  }

  /// Authenticates user with email and password
  Future<AuthResult> login({
    required String email,
    required String password,
    bool rememberMe = false,
  }) async {
    final cleanEmail = email.trim().toLowerCase();
    final cleanPassword = password.trim();

    if (cleanEmail.isEmpty || !cleanEmail.contains('@')) {
      return AuthResult.failure('Please enter a valid email address.');
    }

    if (cleanPassword.isEmpty || cleanPassword.length < 6) {
      return AuthResult.failure('Password must be at least 6 characters.');
    }

    if (_authMode == AuthMode.restBackend) {
      return _loginWithBackend(cleanEmail, cleanPassword, rememberMe);
    } else {
      return _loginWithDevMock(cleanEmail, cleanPassword, rememberMe);
    }
  }

  Future<AuthResult> _loginWithBackend(
    String email,
    String password,
    bool rememberMe,
  ) async {
    final response = await _apiClient.post(
      ApiConstants.authLogin,
      body: {
        'email': email,
        'password': password,
      },
    );

    if (response.isSuccess && response.data != null) {
      final data = response.data!;
      final token = data['token'] as String? ?? data['accessToken'] as String?;
      final refreshToken = data['refreshToken'] as String?;
      final userData = data['user'] as Map<String, dynamic>?;

      if (token == null || userData == null) {
        return AuthResult.failure(
          'Server returned incomplete authentication payload.',
        );
      }

      final user = AuthUser.fromMap(userData);
      final session = AuthSession(
        token: token,
        refreshToken: refreshToken,
        user: user,
        expiresAt: DateTime.now().add(const Duration(hours: 24)),
      );

      await _applySession(session, rememberMe, email);
      return AuthResult.success(user: user, session: session);
    } else {
      final message = response.message ??
          (response.statusCode == 401
              ? 'Invalid email or password.'
              : 'Authentication server error (${response.statusCode}).');
      return AuthResult.failure(message);
    }
  }

  Future<AuthResult> _loginWithDevMock(
    String email,
    String password,
    bool rememberMe,
  ) async {
    // Artificial small delay to simulate asynchronous validation
    await Future.delayed(const Duration(milliseconds: 300));

    final account = _devAccounts[email];
    if (account == null) {
      return AuthResult.failure(
        'No account found with this email. Please check your credentials or register.',
        isDevMock: true,
      );
    }

    if (account.password != password) {
      return AuthResult.failure(
        'Incorrect password. Please try again.',
        isDevMock: true,
      );
    }

    final token = 'dev_mock_jwt_${account.user.id}_${DateTime.now().millisecondsSinceEpoch}';
    final session = AuthSession(
      token: token,
      user: account.user,
      expiresAt: DateTime.now().add(const Duration(days: 7)),
    );

    await _applySession(session, rememberMe, email);
    return AuthResult.success(
      user: account.user,
      session: session,
      isDevMock: true,
    );
  }

  /// Registers a new user and creates an associated business tenant context
  Future<AuthResult> register({
    required String name,
    required String email,
    required String phone,
    required String password,
    String? businessName,
  }) async {
    final cleanName = name.trim();
    final cleanEmail = email.trim().toLowerCase();
    final cleanPhone = phone.trim();
    final cleanPassword = password.trim();

    if (cleanName.length < 2) {
      return AuthResult.failure('Please enter a valid full name.');
    }
    if (cleanEmail.isEmpty || !cleanEmail.contains('@')) {
      return AuthResult.failure('Please enter a valid email address.');
    }
    if (cleanPhone.length != 10) {
      return AuthResult.failure('Please enter a valid 10-digit phone number.');
    }
    if (cleanPassword.length < 6) {
      return AuthResult.failure('Password must be at least 6 characters.');
    }

    if (_authMode == AuthMode.restBackend) {
      final payload = <String, dynamic>{
        'fullName': cleanName,
        'email': cleanEmail,
        'phone': cleanPhone,
        'password': cleanPassword,
      };
      if (businessName != null && businessName.trim().isNotEmpty) {
        payload['businessName'] = businessName.trim();
      }

      final response = await _apiClient.post(
        ApiConstants.authRegister,
        body: payload,
      );

      if (response.isSuccess && response.data != null) {
        final data = response.data!;
        final token = data['token'] as String? ?? data['accessToken'] as String?;
        final refreshToken = data['refreshToken'] as String?;
        final userData = data['user'] as Map<String, dynamic>?;

        if (token != null && userData != null) {
          final user = AuthUser.fromMap(userData);
          final session = AuthSession(
            token: token,
            refreshToken: refreshToken,
            user: user,
            expiresAt: DateTime.now().add(const Duration(hours: 24)),
          );
          await _applySession(session, false, cleanEmail);
          return AuthResult.success(user: user, session: session);
        }

        return AuthResult.success(
          user: AuthUser(
            id: 'registered',
            email: cleanEmail,
            fullName: cleanName,
          ),
          session: AuthSession(
            token: '',
            user: AuthUser(id: 'registered', email: cleanEmail, fullName: cleanName),
            expiresAt: DateTime.now(),
          ),
        );
      } else {
        return AuthResult.failure(
          response.message ?? 'Registration failed on backend server.',
        );
      }
    } else {
      // Dev mock registration
      await Future.delayed(const Duration(milliseconds: 300));

      if (_devAccounts.containsKey(cleanEmail)) {
        return AuthResult.failure(
          'An account with this email already exists. Please sign in.',
          isDevMock: true,
        );
      }

      final newUserId = 'usr-dev-${DateTime.now().millisecondsSinceEpoch}';
      final newBizId = 'biz-dev-${DateTime.now().millisecondsSinceEpoch}';

      final newUser = AuthUser(
        id: newUserId,
        email: cleanEmail,
        fullName: cleanName,
        phone: cleanPhone,
        businessId: newBizId,
        role: 'OWNER',
        isDevAccount: true,
      );

      _devAccounts[cleanEmail] = _DevAccount(
        user: newUser,
        password: cleanPassword,
      );

      final token = 'dev_mock_jwt_${newUser.id}';
      final session = AuthSession(
        token: token,
        user: newUser,
        expiresAt: DateTime.now().add(const Duration(days: 7)),
      );

      await _applySession(session, false, cleanEmail);
      return AuthResult.success(
        user: newUser,
        session: session,
        isDevMock: true,
      );
    }
  }

  /// Performs token refresh with the backend using the stored refresh token.
  /// Rotates tokens on success or logs out safely if token is expired/revoked.
  Future<bool> refreshSession() async {
    if (_authMode != AuthMode.restBackend) {
      return true;
    }

    final currentRefreshToken = _currentSession?.refreshToken ??
        await _tokenManager.getRefreshToken();

    if (currentRefreshToken == null || currentRefreshToken.isEmpty) {
      return false;
    }

    final response = await _apiClient.post(
      ApiConstants.authRefresh,
      body: {'refreshToken': currentRefreshToken},
    );

    if (response.isSuccess && response.data != null) {
      final data = response.data!;
      final newAccessToken =
          data['accessToken'] as String? ?? data['token'] as String?;
      final newRefreshToken = data['refreshToken'] as String?;
      final expiresIn = data['expiresIn'] as int? ?? 3600;

      if (newAccessToken != null && _currentSession != null) {
        final updatedSession = AuthSession(
          token: newAccessToken,
          refreshToken: newRefreshToken ?? currentRefreshToken,
          user: _currentSession!.user,
          expiresAt: DateTime.now().add(Duration(seconds: expiresIn)),
        );

        _currentSession = updatedSession;
        await _tokenManager.saveTokens(
          accessToken: updatedSession.token,
          refreshToken: updatedSession.refreshToken,
          expiry: updatedSession.expiresAt,
        );
        notifyListeners();
        return true;
      }
    }

    // Refresh failed or revoked: clear invalid session
    if (response.statusCode == 401 || response.statusCode == 403) {
      await logout();
    }
    return false;
  }

  /// Updates business profile, legal info, and tax/GST settings.
  Future<AuthResult> updateBusinessSetup({
    required String businessName,
    String? legalName,
    String? gstin,
    String? pan,
    String? addressLine1,
    String? city,
    String? state,
    String? stateCode,
    String? pincode,
    String? taxType,
    String? defaultBillFormat,
  }) async {
    if (businessName.trim().isEmpty) {
      return AuthResult.failure('Business name cannot be empty.');
    }

    if (_authMode == AuthMode.restBackend) {
      final payload = <String, dynamic>{
        'businessName': businessName.trim(),
        if (legalName != null && legalName.trim().isNotEmpty)
          'legalName': legalName.trim(),
        if (gstin != null && gstin.trim().isNotEmpty)
          'gstin': gstin.trim().toUpperCase(),
        if (pan != null && pan.trim().isNotEmpty)
          'pan': pan.trim().toUpperCase(),
        if (addressLine1 != null && addressLine1.trim().isNotEmpty)
          'addressLine1': addressLine1.trim(),
        if (city != null && city.trim().isNotEmpty) 'city': city.trim(),
        if (state != null && state.trim().isNotEmpty) 'state': state.trim(),
        if (stateCode != null && stateCode.trim().isNotEmpty)
          'stateCode': stateCode.trim(),
        if (pincode != null && pincode.trim().isNotEmpty)
          'pincode': pincode.trim(),
        if (taxType != null && taxType.trim().isNotEmpty)
          'taxType': taxType.trim(),
        if (defaultBillFormat != null && defaultBillFormat.trim().isNotEmpty)
          'defaultBillFormat': defaultBillFormat.trim(),
      };

      var response = await _apiClient.patch(
        ApiConstants.authBusinessSetup,
        body: payload,
        token: _currentSession?.token,
      );

      // Handle 401 with automatic token refresh attempt
      if (response.statusCode == 401) {
        final refreshed = await refreshSession();
        if (refreshed) {
          response = await _apiClient.patch(
            ApiConstants.authBusinessSetup,
            body: payload,
            token: _currentSession?.token,
          );
        }
      }

      if (response.isSuccess) {
        return AuthResult.success(
          user: _currentSession?.user ??
              const AuthUser(id: '', email: '', fullName: ''),
          session: _currentSession ??
              AuthSession(
                token: '',
                user: const AuthUser(id: '', email: '', fullName: ''),
                expiresAt: DateTime.now(),
              ),
        );
      } else {
        return AuthResult.failure(
          response.message ??
              'Failed to update business configuration (${response.statusCode}).',
        );
      }
    } else {
      // Mock mode
      await Future.delayed(const Duration(milliseconds: 300));
      return AuthResult.success(
        user: _currentSession?.user ??
            const AuthUser(id: '', email: '', fullName: ''),
        session: _currentSession ??
            AuthSession(
              token: '',
              user: const AuthUser(id: '', email: '', fullName: ''),
              expiresAt: DateTime.now(),
            ),
        isDevMock: true,
      );
    }
  }

  /// Sends password reset request
  Future<AuthResult> resetPassword({required String email}) async {
    final cleanEmail = email.trim().toLowerCase();

    if (cleanEmail.isEmpty || !cleanEmail.contains('@')) {
      return AuthResult.failure('Please enter a valid email address.');
    }

    if (_authMode == AuthMode.restBackend) {
      final response = await _apiClient.post(
        ApiConstants.authForgotPassword,
        body: {'email': cleanEmail},
      );
      if (response.isSuccess) {
        return AuthResult.success(
          user: AuthUser(id: '', email: cleanEmail, fullName: ''),
          session: AuthSession(
            token: '',
            user: AuthUser(id: '', email: cleanEmail, fullName: ''),
            expiresAt: DateTime.now(),
          ),
        );
      } else {
        return AuthResult.failure(
          response.message ??
              'Password reset service is unavailable on the backend.',
        );
      }
    } else {
      await Future.delayed(const Duration(milliseconds: 300));
      if (!_devAccounts.containsKey(cleanEmail)) {
        return AuthResult.failure(
          'No account registered with this email address.',
          isDevMock: true,
        );
      }
      return AuthResult.success(
        user: _devAccounts[cleanEmail]!.user,
        session: AuthSession(
          token: '',
          user: _devAccounts[cleanEmail]!.user,
          expiresAt: DateTime.now(),
        ),
        isDevMock: true,
      );
    }
  }

  /// Clears active session and token storage
  Future<void> logout() async {
    if (_authMode == AuthMode.restBackend && _currentSession != null) {
      try {
        await _apiClient.post(
          ApiConstants.authLogout,
          token: _currentSession?.token,
        );
      } catch (_) {
        // Silently handle backend network failure during logout
      }
    }

    await _tokenManager.clearTokens();
    await _storage.delete(key: StorageKeys.currentUserId);
    await _storage.delete(key: StorageKeys.currentUserEmail);
    await _storage.delete(key: StorageKeys.currentUserName);
    await _storage.delete(key: StorageKeys.currentBusinessId);
    await _storage.delete(key: StorageKeys.currentUserRole);

    _currentSession = null;
    notifyListeners();
  }

  Future<void> _applySession(
    AuthSession session,
    bool rememberMe,
    String email,
  ) async {
    _currentSession = session;

    // Save tokens securely
    await _tokenManager.saveTokens(
      accessToken: session.token,
      refreshToken: session.refreshToken,
      expiry: session.expiresAt,
    );

    // Save user session metadata
    await _storage.write(key: StorageKeys.currentUserId, value: session.user.id);
    await _storage.write(key: StorageKeys.currentUserEmail, value: session.user.email);
    await _storage.write(key: StorageKeys.currentUserName, value: session.user.fullName);
    if (session.user.businessId != null) {
      await _storage.write(
        key: StorageKeys.currentBusinessId,
        value: session.user.businessId!,
      );
    }
    await _storage.write(key: StorageKeys.currentUserRole, value: session.user.role);

    // Handle Remember Me (remembers only email, never password)
    _isRememberMeEnabled = rememberMe;
    if (rememberMe) {
      _rememberMeEmail = email;
      await _storage.write(key: StorageKeys.rememberMeEnabled, value: 'true');
      await _storage.write(key: StorageKeys.rememberMeEmail, value: email);
    } else {
      _rememberMeEmail = null;
      await _storage.write(key: StorageKeys.rememberMeEnabled, value: 'false');
      await _storage.delete(key: StorageKeys.rememberMeEmail);
    }

    notifyListeners();
  }
}

class _DevAccount {
  final AuthUser user;
  final String password;

  const _DevAccount({required this.user, required this.password});
}

