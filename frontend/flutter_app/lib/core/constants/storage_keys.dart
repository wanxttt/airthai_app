/// Storage keys used for local and secure persistence.
///
/// Phase 1: Authentication & Session Management
class StorageKeys {
  const StorageKeys._();

  static const String accessToken = 'airthai_access_token';
  static const String refreshToken = 'airthai_refresh_token';
  static const String tokenExpiry = 'airthai_token_expiry';
  static const String currentUserId = 'airthai_current_user_id';
  static const String currentUserEmail = 'airthai_current_user_email';
  static const String currentUserName = 'airthai_current_user_name';
  static const String currentBusinessId = 'airthai_current_business_id';
  static const String currentUserRole = 'airthai_current_user_role';
  static const String rememberMeEmail = 'airthai_remember_me_email';
  static const String rememberMeEnabled = 'airthai_remember_me_enabled';
  static const String authMode = 'airthai_auth_mode'; // 'mock' or 'backend'
  static const String registeredUsers = 'airthai_dev_registered_users';
}

