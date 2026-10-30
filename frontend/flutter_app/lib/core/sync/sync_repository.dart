import 'dart:async';
import '../database/database_manager.dart';
import '../database/database_tables.dart';
import 'sync_operation.dart';

/// Repository that synchronizes server acknowledgements with local database records.
class SyncRepository {
  SyncRepository._();
  static final SyncRepository instance = SyncRepository._();

  /// Applies server acknowledgement to the local entity.
  ///
  /// Replaces non-authoritative offline document numbers (e.g. OFFLINE-INV-...)
  /// with authoritative canonical server sequence numbers and marks the entity as synced.
  Future<void> applyServerAcknowledgement(
    SyncOperation op,
    Map<String, dynamic> ackData,
  ) async {
    final db = await DatabaseManager.instance.database;
    final canonicalNumber = ackData['canonicalDocumentNumber']?.toString();
    final serverVersion = (ackData['serverVersion'] as int?) ?? 1;
    final serverId = ackData['serverEntityId']?.toString();

    switch (op.entityType.toUpperCase()) {
      case 'INVOICE':
        final updateValues = <String, dynamic>{
          'sync_status': SyncStatus.synced.code,
          'server_version': serverVersion,
        };
        if (canonicalNumber != null && canonicalNumber.isNotEmpty) {
          updateValues['invoice_number'] = canonicalNumber;
        }
        await db.update(
          'local_invoices',
          updateValues,
          where: 'client_operation_id = ?',
          whereArgs: [op.clientOperationId],
        );
        break;

      case 'PURCHASE':
        final updateValues = <String, dynamic>{
          'sync_status': SyncStatus.synced.code,
          'server_version': serverVersion,
        };
        if (canonicalNumber != null && canonicalNumber.isNotEmpty) {
          updateValues['bill_number'] = canonicalNumber;
        }
        await db.update(
          'local_purchases',
          updateValues,
          where: 'client_operation_id = ?',
          whereArgs: [op.clientOperationId],
        );
        break;

      case 'PAYMENT':
        final updateValues = <String, dynamic>{
          'sync_status': SyncStatus.synced.code,
          'server_version': serverVersion,
        };
        if (canonicalNumber != null && canonicalNumber.isNotEmpty) {
          updateValues['payment_number'] = canonicalNumber;
        }
        await db.update(
          'local_payments',
          updateValues,
          where: 'client_operation_id = ?',
          whereArgs: [op.clientOperationId],
        );
        break;

      case 'CUSTOMER':
        await db.update(
          'local_customers',
          {
            'sync_status': SyncStatus.synced.code,
            'server_version': serverVersion,
            if (serverId != null) 'id': serverId,
          },
          where: 'client_operation_id = ?',
          whereArgs: [op.clientOperationId],
        );
        break;

      case 'SUPPLIER':
        await db.update(
          'local_suppliers',
          {
            'sync_status': SyncStatus.synced.code,
            'server_version': serverVersion,
            if (serverId != null) 'id': serverId,
          },
          where: 'client_operation_id = ?',
          whereArgs: [op.clientOperationId],
        );
        break;

      case 'PRODUCT':
        await db.update(
          'local_products',
          {
            'sync_status': SyncStatus.synced.code,
            'server_version': serverVersion,
            if (serverId != null) 'id': serverId,
          },
          where: 'client_operation_id = ?',
          whereArgs: [op.clientOperationId],
        );
        break;
    }
  }

  /// Flags a local entity as having a sync conflict, preserving both versions for resolution.
  Future<void> applyConflict(
    SyncOperation op,
    Map<String, dynamic> conflictData,
  ) async {
    final db = await DatabaseManager.instance.database;

    switch (op.entityType.toUpperCase()) {
      case 'INVOICE':
        await db.update(
          'local_invoices',
          {'sync_status': SyncStatus.conflict.code},
          where: 'client_operation_id = ?',
          whereArgs: [op.clientOperationId],
        );
        break;
      case 'PURCHASE':
        await db.update(
          'local_purchases',
          {'sync_status': SyncStatus.conflict.code},
          where: 'client_operation_id = ?',
          whereArgs: [op.clientOperationId],
        );
        break;
      case 'PAYMENT':
        await db.update(
          'local_payments',
          {'sync_status': SyncStatus.conflict.code},
          where: 'client_operation_id = ?',
          whereArgs: [op.clientOperationId],
        );
        break;
      case 'CUSTOMER':
        await db.update(
          'local_customers',
          {'sync_status': SyncStatus.conflict.code},
          where: 'client_operation_id = ?',
          whereArgs: [op.clientOperationId],
        );
        break;
      case 'SUPPLIER':
        await db.update(
          'local_suppliers',
          {'sync_status': SyncStatus.conflict.code},
          where: 'client_operation_id = ?',
          whereArgs: [op.clientOperationId],
        );
        break;
      case 'PRODUCT':
        await db.update(
          'local_products',
          {'sync_status': SyncStatus.conflict.code},
          where: 'client_operation_id = ?',
          whereArgs: [op.clientOperationId],
        );
        break;
    }
  }
}

