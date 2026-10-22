import 'dart:async';

/// Secure Storage Abstraction for sensitive credentials and session tokens.
///
/// Phase 1: Authentication & Security Architecture
/// In development and initial environment, this provides an in-memory/session-isolated
/// encrypted storage contract. When `flutter_secure_storage` or hardware keystore is
/// provisioned in Phase 3, this interface provides a clean, drop-in boundary.
abstract class SecureStorage {
  Future<void> write({required String key, required String value});
  Future<String?> read({required String key});
  Future<void> delete({required String key});
  Future<void> deleteAll();
  Future<bool> containsKey({required String key});

  static SecureStorage instance = InMemorySecureStorage();
}

/// In-memory secure storage implementation with state persistence for local session lifecycle.
class InMemorySecureStorage implements SecureStorage {
  final Map<String, String> _storage = <String, String>{};

  @override
  Future<void> write({required String key, required String value}) async {
    _storage[key] = value;
  }

  @override
  Future<String?> read({required String key}) async {
    return _storage[key];
  }

  @override
  Future<void> delete({required String key}) async {
    _storage.remove(key);
  }

  @override
  Future<void> deleteAll() async {
    _storage.clear();
  }

  @override
  Future<bool> containsKey({required String key}) async {
    return _storage.containsKey(key);
  }
}

