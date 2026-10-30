import 'app_database.dart';
import 'database_tables.dart';

/// Database migration and schema version manager.
class DatabaseMigrations {
  DatabaseMigrations._();
  static final DatabaseMigrations instance = DatabaseMigrations._();

  static const int currentSchemaVersion = 1;

  /// Runs all required migrations to ensure tables and indexes are present.
  Future<void> runMigrations(AppDatabase db) async {
    // Phase 2 / MVP Prompt 8 baseline tables and indexes
    for (final ddl in LocalDatabaseDdl.createTables) {
      await db.execute(ddl);
    }

    for (final idx in LocalDatabaseDdl.createIndexes) {
      await db.execute(idx);
    }
  }
}

