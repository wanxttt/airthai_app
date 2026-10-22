import '../constants/storage_keys.dart';
import '../storage/secure_storage.dart';

/// Token Manager
///
/// Phase 1: Authentication & Token Management
/// Responsible for secure handling, retrieval, expiry checking,
/// and invalidation of JWT access and refresh tokens.
class TokenManager {
  final SecureStorage _storage;

  TokenManager({SecureStorage? storage})
      : _storage = storage ?? SecureStorage.instance;

  /// Saves access token, refresh token, and optional expiry
  Future<void> saveTokens({
    required String accessToken,
    String? refreshToken,
    DateTime? expiry,
  }) async {
    await _storage.write(key: StorageKeys.accessToken, value: accessToken);
    if (refreshToken != null) {
      await _storage.write(key: StorageKeys.refreshToken, value: refreshToken);
    }
    if (expiry != null) {
      await _storage.write(
        key: StorageKeys.tokenExpiry,
        value: expiry.toIso8601String(),
      );
    }
  }

  /// Retrieves the current access token
  Future<String?> getAccessToken() async {
    return _storage.read(key: StorageKeys.accessToken);
  }

  /// Retrieves the current refresh token
  Future<String?> getRefreshToken() async {
    return _storage.read(key: StorageKeys.refreshToken);
  }

  /// Checks if a valid, non-expired access token exists
  Future<bool> hasValidAccessToken() async {
    final token = await getAccessToken();
    if (token == null || token.trim().isEmpty) {
      return false;
    }

    final expiryStr = await _storage.read(key: StorageKeys.tokenExpiry);
    if (expiryStr != null) {
      final expiry = DateTime.tryParse(expiryStr);
      if (expiry != null && DateTime.now().isAfter(expiry)) {
        return false;
      }
    }

    return true;
  }

  /// Clears all stored tokens upon logout or session invalidation
  Future<void> clearTokens() async {
    await _storage.delete(key: StorageKeys.accessToken);
    await _storage.delete(key: StorageKeys.refreshToken);
    await _storage.delete(key: StorageKeys.tokenExpiry);
  }
}

