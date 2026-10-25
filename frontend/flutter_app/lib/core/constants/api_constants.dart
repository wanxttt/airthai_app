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

  /// Master Data endpoints
  static const String products = '/api/v1/products';
  static const String categories = '/api/v1/categories';
  static const String units = '/api/v1/units';
  static const String customers = '/api/v1/customers';
  static const String suppliers = '/api/v1/suppliers';

  /// Sales & Invoicing endpoints
  static const String invoices = '/api/v1/invoices';
  static const String quotations = '/api/v1/quotations';

  /// Purchases & Inventory endpoints
  static const String purchases = '/api/v1/purchases';
  static const String inventorySummary = '/api/v1/inventory/summary';
  static const String inventoryProducts = '/api/v1/inventory/products';
  static const String inventoryAdjustments = '/api/v1/inventory/adjustments';

  /// HTTP Headers
  static const String headerAuthorization = 'Authorization';
  static const String headerContentType = 'Content-Type';
  static const String headerAccept = 'Accept';
  static const String contentTypeJson = 'application/json';
  static const String bearerPrefix = 'Bearer ';
}

