/// API Constants for AirthAI Backend Communication
///
/// Phase 1: Authentication & API Contracts
class ApiConstants {
  const ApiConstants._();

  /// Default API base URL for NestJS backend (configurable via environment)
  static const String defaultBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://localhost:3000',
  );

  /// Request timeouts
  static const Duration connectTimeout = Duration(seconds: 10);
  static const Duration receiveTimeout = Duration(seconds: 15);

  /// Authentication endpoints
  static const String authLogin = '/api/v1/auth/login';
  static const String authRegister = '/api/v1/auth/register';
  static const String authRefresh = '/api/v1/auth/refresh';
  static const String authLogout = '/api/v1/auth/logout';
  static const String authForgotPassword = '/api/v1/auth/forgot-password';
  static const String authMe = '/api/v1/auth/me';
  static const String authBusinessSetup = '/api/v1/auth/business-setup';

  /// HTTP Headers
  static const String headerAuthorization = 'Authorization';
  static const String headerContentType = 'Content-Type';
  static const String headerAccept = 'Accept';
  static const String contentTypeJson = 'application/json';
  static const String bearerPrefix = 'Bearer ';
}

