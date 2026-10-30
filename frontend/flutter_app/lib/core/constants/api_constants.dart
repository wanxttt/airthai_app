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

  /// Payments & Receipts endpoints
  static const String payments = '/api/v1/payments';
  static const String customerReceipts = '/api/v1/payments/receipts';
  static const String supplierPayments = '/api/v1/payments/supplier-payments';
  static const String customerOutstanding = '/api/v1/payments/outstanding/customer';
  static const String supplierOutstanding = '/api/v1/payments/outstanding/supplier';

  /// Expenses endpoints
  static const String expenses = '/api/v1/expenses';
  static const String expenseCategories = '/api/v1/expenses/categories';
  static const String expenseSummary = '/api/v1/expenses/summary';

  /// Accounting endpoints
  static const String accountingAccounts = '/api/v1/accounting/accounts';
  static const String accountingJournals = '/api/v1/accounting/journals';
  static const String accountingTrialBalance = '/api/v1/accounting/reports/trial-balance';
  static const String accountingProfitLoss = '/api/v1/accounting/reports/profit-and-loss';
  static const String accountingReceivables = '/api/v1/accounting/reports/receivables';
  static const String accountingPayables = '/api/v1/accounting/reports/payables';

  /// GST statutory preparation endpoints
  static const String gstGstr1 = '/api/v1/gst/gstr-1';
  static const String gstGstr3b = '/api/v1/gst/gstr-3b';
  static const String gstSummary = '/api/v1/gst/summary';

  /// Dashboard & Reports endpoints
  static const String dashboardMetrics = '/api/v1/dashboard/metrics';
  static const String reportsSales = '/api/v1/reports/sales';
  static const String reportsPurchases = '/api/v1/reports/purchases';
  static const String reportsExpenses = '/api/v1/reports/expenses';
  static const String reportsPayments = '/api/v1/reports/payments';
  static const String reportsReceivablesAgeing = '/api/v1/reports/receivables-ageing';
  static const String reportsPayablesAgeing = '/api/v1/reports/payables-ageing';
  static const String reportsStockSummary = '/api/v1/reports/stock-summary';
  static const String reportsStockMovements = '/api/v1/reports/stock-movements';
  static const String reportsProductPerformance = '/api/v1/reports/product-performance';
  static const String reportsGstSummary = '/api/v1/reports/gst-summary';

  /// Audit, Notifications & Subscriptions endpoints
  static const String notifications = '/api/v1/notifications';
  static const String notificationsUnread = '/api/v1/notifications/unread-count';
  static const String notificationsMarkAllRead = '/api/v1/notifications/mark-all-read';
  static const String notificationsScan = '/api/v1/notifications/scan';
  static const String auditLogs = '/api/v1/audit-logs';
  static const String subscriptionsCurrent = '/api/v1/subscriptions/current';
  static const String subscriptionsPlans = '/api/v1/subscriptions/plans';
  static const String subscriptionsChangePlan = '/api/v1/subscriptions/change-plan';

  /// AI Business Copilot endpoints
  static const String copilotStatus = '/api/v1/copilot/status';
  static const String copilotSuggestions = '/api/v1/copilot/suggestions';
  static const String copilotQuery = '/api/v1/copilot/query';

  /// HTTP Headers
  static const String headerAuthorization = 'Authorization';
  static const String headerContentType = 'Content-Type';
  static const String headerAccept = 'Accept';
  static const String contentTypeJson = 'application/json';
  static const String bearerPrefix = 'Bearer ';
}
