import 'dart:async';
import 'app_database.dart';
import 'database_migrations.dart';
import '../storage/local_storage.dart';

/// Central database lifecycle and connection manager.
class DatabaseManager {
  DatabaseManager._();
  static final DatabaseManager instance = DatabaseManager._();

  AppDatabase? _database;
  bool _isInitialized = false;

  /// Returns the active local database instance, initializing if needed.
  Future<AppDatabase> get database async {
    if (_database == null || !_isInitialized) {
      await initialize();
    }
    return _database!;
  }

  /// Initializes the local database and runs baseline schema migrations.
  Future<void> initialize({String? businessId}) async {
    if (_database == null) {
      _database = AppDatabase();
      await DatabaseMigrations.instance.runMigrations(_database!);

      // Restore snapshot from persistent storage (e.g. Web LocalStorage / native store)
      final snapshot = await DatabasePersistenceHelper.loadSnapshot();
      if (snapshot != null) {
        _database!.importSnapshot(snapshot);
      }

      // Automatically mirror mutations to persistent storage
      _database!.onDataChanged = () {
        DatabasePersistenceHelper.saveSnapshot(_database!.exportSnapshot());
      };

      _isInitialized = true;
    }
  }

  /// Manually triggers snapshot persistence to local storage.
  Future<void> persist() async {
    if (_database != null) {
      await DatabasePersistenceHelper.saveSnapshot(_database!.exportSnapshot());
    }
  }

  /// Purges all sensitive offline data for a specific tenant business.
  ///
  /// Executed on user logout or business switching to enforce tenant isolation.
  Future<void> clearTenantData(String businessId) async {
    if (_database != null) {
      await _database!.clearTenantData(businessId);
      await persist();
    }
  }

  /// Completely resets the database instance (useful for test tear-down).
  Future<void> reset() async {
    if (_database != null) {
      _database!.onDataChanged = null;
      await _database!.clearAll();
      _database = null;
      _isInitialized = false;
    }
    await DatabasePersistenceHelper.clearSnapshot();
  }
}
