import 'dart:async';
import 'dart:convert';
import 'local_storage_stub.dart'
    if (dart.library.html) 'local_storage_web.dart';

/// Cross-platform local persistence contract for offline database tables and sync queues.
///
/// Ensures offline mutations and queue items survive browser reloads on Web
/// and app process restarts on mobile/desktop.
abstract class LocalStorage {
  Future<void> setItem(String key, String value);
  Future<String?> getItem(String key);
  Future<void> removeItem(String key);
  Future<void> clear();

  static LocalStorage instance = createLocalStorage();
}

/// Fallback in-memory storage implementation for tests and environments without web storage.
class MemoryLocalStorage implements LocalStorage {
  final Map<String, String> _data = {};

  @override
  Future<void> setItem(String key, String value) async {
    _data[key] = value;
  }

  @override
  Future<String?> getItem(String key) async {
    return _data[key];
  }

  @override
  Future<void> removeItem(String key) async {
    _data.remove(key);
  }

  @override
  Future<void> clear() async {
    _data.clear();
  }
}

/// Helper utility for persisting and restoring JSON-serializable database table snapshots.
class DatabasePersistenceHelper {
  static const String snapshotKey = 'airthai_local_db_snapshot';

  /// Saves the complete relational database state to [LocalStorage].
  static Future<void> saveSnapshot(Map<String, dynamic> snapshot) async {
    try {
      final jsonStr = jsonEncode(snapshot);
      await LocalStorage.instance.setItem(snapshotKey, jsonStr);
    } catch (_) {
      // Best-effort persistence: silent fail-safe so operations never throw
    }
  }

  /// Restores a previously saved database state from [LocalStorage].
  static Future<Map<String, dynamic>?> loadSnapshot() async {
    try {
      final jsonStr = await LocalStorage.instance.getItem(snapshotKey);
      if (jsonStr == null || jsonStr.trim().isEmpty) return null;
      final decoded = jsonDecode(jsonStr);
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  /// Purges persisted offline tables (e.g. on user logout).
  static Future<void> clearSnapshot() async {
    await LocalStorage.instance.removeItem(snapshotKey);
  }
}
