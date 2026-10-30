import 'dart:async';
import '../database/app_database.dart';
import '../database/database_manager.dart';
import 'sync_operation.dart';

/// Durable local sync queue for transactional offline modifications.
class SyncQueue {
  SyncQueue._();
  static final SyncQueue instance = SyncQueue._();

  static const String tableName = 'local_sync_queue';
  static const int maxRetries = 5;

  /// Enqueues a sync operation atomically.
  ///
  /// Can be passed a [TransactionContext] to ensure the queue item is saved
  /// atomically in the same transaction as the local business entity.
  Future<void> enqueue(SyncOperation operation, {TransactionContext? txn}) async {
    final db = await DatabaseManager.instance.database;
    final context = txn ?? db;
    await context.insert(tableName, operation.toMap());
  }

  /// Retrieves pending operations in FIFO order (up to [limit]).
  Future<List<SyncOperation>> getPendingOperations({String? businessId, int limit = 50}) async {
    final db = await DatabaseManager.instance.database;
    final where = businessId != null ? 'business_id = ? AND status = ?' : 'status = ?';
    final whereArgs = businessId != null ? [businessId, 'PENDING'] : ['PENDING'];

    final rows = await db.query(
      tableName,
      where: where,
      whereArgs: whereArgs,
      orderBy: 'created_at ASC',
      limit: limit,
    );

    return rows.map((r) => SyncOperation.fromMap(r)).toList();
  }

  /// Marks an operation as currently in-flight.
  Future<void> markInProgress(String clientOperationId) async {
    final db = await DatabaseManager.instance.database;
    await db.update(
      tableName,
      {'status': 'IN_PROGRESS'},
      where: 'client_operation_id = ?',
      whereArgs: [clientOperationId],
    );
  }

  /// Marks an operation as successfully acknowledged by the server.
  Future<void> markCompleted(String clientOperationId, {Map<String, dynamic>? ackData}) async {
    final db = await DatabaseManager.instance.database;
    await db.update(
      tableName,
      {
        'status': 'SYNCED',
        'processed_at': DateTime.now().toIso8601String(),
        'error_message': null,
      },
      where: 'client_operation_id = ?',
      whereArgs: [clientOperationId],
    );
  }

  /// Marks an operation as having encountered a version conflict.
  Future<void> markConflict(String clientOperationId, String reason) async {
    final db = await DatabaseManager.instance.database;
    await db.update(
      tableName,
      {
        'status': 'CONFLICT',
        'error_message': reason,
      },
      where: 'client_operation_id = ?',
      whereArgs: [clientOperationId],
    );
  }

  /// Marks an operation as failed with an error, incrementing retry count.
  ///
  /// If [retryCount] reaches [maxRetries], the status transitions to 'FAILED'
  /// requiring user action or manual retry.
  Future<void> markFailed(String clientOperationId, String error, {bool canRetry = true}) async {
    final db = await DatabaseManager.instance.database;
    final ops = await db.query(
      tableName,
      where: 'client_operation_id = ?',
      whereArgs: [clientOperationId],
    );

    if (ops.isNotEmpty) {
      final currentRetry = (ops.first['retry_count'] as int?) ?? 0;
      final nextRetry = currentRetry + 1;
      final newStatus = (canRetry && nextRetry < maxRetries) ? 'PENDING' : 'FAILED';

      await db.update(
        tableName,
        {
          'status': newStatus,
          'retry_count': nextRetry,
          'error_message': error,
        },
        where: 'client_operation_id = ?',
        whereArgs: [clientOperationId],
      );
    }
  }

  /// Resets a failed operation back to PENDING for manual user retry.
  Future<void> retryOperation(String clientOperationId) async {
    final db = await DatabaseManager.instance.database;
    await db.update(
      tableName,
      {
        'status': 'PENDING',
        'retry_count': 0,
        'error_message': null,
      },
      where: 'client_operation_id = ?',
      whereArgs: [clientOperationId],
    );
  }

  /// Resets all failed operations for a tenant to PENDING.
  Future<void> retryAllFailed(String businessId) async {
    final db = await DatabaseManager.instance.database;
    await db.update(
      tableName,
      {
        'status': 'PENDING',
        'retry_count': 0,
        'error_message': null,
      },
      where: 'business_id = ? AND status = ?',
      whereArgs: [businessId, 'FAILED'],
    );
  }

  Future<int> getPendingCount(String businessId) async {
    final db = await DatabaseManager.instance.database;
    final rows = await db.query(
      tableName,
      where: 'business_id = ? AND status = ?',
      whereArgs: [businessId, 'PENDING'],
    );
    return rows.length;
  }

  Future<int> getFailedCount(String businessId) async {
    final db = await DatabaseManager.instance.database;
    final rows = await db.query(
      tableName,
      where: 'business_id = ? AND status = ?',
      whereArgs: [businessId, 'FAILED'],
    );
    return rows.length;
  }

  Future<int> getConflictCount(String businessId) async {
    final db = await DatabaseManager.instance.database;
    final rows = await db.query(
      tableName,
      where: 'business_id = ? AND status = ?',
      whereArgs: [businessId, 'CONFLICT'],
    );
    return rows.length;
  }

  Future<List<SyncOperation>> getAllOperations(String businessId) async {
    final db = await DatabaseManager.instance.database;
    final rows = await db.query(
      tableName,
      where: 'business_id = ?',
      whereArgs: [businessId],
      orderBy: 'created_at DESC',
    );
    return rows.map((r) => SyncOperation.fromMap(r)).toList();
  }
}

