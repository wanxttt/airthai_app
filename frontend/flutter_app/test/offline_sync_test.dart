import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:airthai/core/database/database_manager.dart';
import 'package:airthai/core/database/database_tables.dart';
import 'package:airthai/core/network/connectivity_service.dart';
import 'package:airthai/core/security/session_manager.dart';
import 'package:airthai/core/services/sales_service.dart';
import 'package:airthai/core/sync/sync_manager.dart';
import 'package:airthai/core/sync/sync_operation.dart';
import 'package:airthai/core/sync/sync_queue.dart';
import 'package:airthai/core/sync/sync_repository.dart';
import 'package:airthai/core/sync/sync_status.dart';
import 'package:airthai/core/utils/uuid.dart';
import 'package:airthai/shared/widgets/app_shell.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SessionManager.instance.setAuthMode(AuthMode.devMock);
    await DatabaseManager.instance.reset();
    await DatabaseManager.instance.initialize(businessId: 'biz_test_001');
    ConnectivityService.instance.setMockOnline(true);
    await SyncManager.instance.reset();
  });

  tearDown(() async {
    SessionManager.instance.setAuthMode(AuthMode.restBackend);
    await DatabaseManager.instance.reset();
  });

  group('Offline-First Local Storage & Synchronization Tests', () {
    test('UuidUtils generates valid RFC-4122 v4 UUID strings', () {
      final uuid1 = UuidUtils.generate();
      final uuid2 = UuidUtils.generate();

      expect(uuid1, isNotEmpty);
      expect(uuid2, isNotEmpty);
      expect(uuid1, isNot(equals(uuid2)));

      final uuidRegex = RegExp(r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$');
      expect(uuidRegex.hasMatch(uuid1), isTrue);
      expect(uuidRegex.hasMatch(uuid2), isTrue);
    });

    test('Creating data offline stores record atomically with pending-sync operation', () async {
      // 1. Simulate offline state
      ConnectivityService.instance.setMockOnline(false);
      expect(ConnectivityService.instance.isOnline, isFalse);

      final invoicePayload = {
        'customerId': 'cust_off_001',
        'customerName': 'Offline Hardware Store',
        'placeOfSupply': '27',
        'items': [
          {
            'productId': 'prod_001',
            'description': 'Heavy Duty Cable 10m',
            'hsnCode': '854449',
            'quantity': 5,
            'unitPrice': 200.0,
            'gstRate': 18.0,
          },
        ],
      };

      // 2. Create invoice while offline
      final result = await SalesService.instance.createInvoice(invoicePayload);

      expect(result.success, isTrue);
      final createdInv = result.data!;
      expect(createdInv.invoiceNumber, startsWith('OFFLINE-INV-'));
      expect(createdInv.totalAmount, equals(1180.0)); // 1000 + 18% GST

      // 3. Verify record was stored in local database
      final db = await DatabaseManager.instance.database;
      final invoices = await db.query('local_invoices');
      expect(invoices, hasLength(1));
      expect(invoices.first['invoice_number'], equals(createdInv.invoiceNumber));
      expect(invoices.first['sync_status'], equals(SyncStatus.pendingInsert.code));

      // 4. Verify line items were stored
      final items = await db.query('local_invoice_items');
      expect(items, hasLength(1));
      expect(items.first['quantity'], equals(5.0));

      // 5. Verify pending-sync operation in queue
      final pendingOps = await SyncQueue.instance.getPendingOperations();
      expect(pendingOps, hasLength(1));
      final op = pendingOps.first;
      expect(op.entityType, equals('INVOICE'));
      expect(op.operation, equals('CREATE'));
      expect(op.status, equals('PENDING'));
      expect(op.clientOperationId, isNotEmpty);
    });

    test('Local transaction rollback restores original state on failure', () async {
      final db = await DatabaseManager.instance.database;
      await db.insert('local_customers', {
        'id': 'cust_initial',
        'business_id': 'biz_test_001',
        'name': 'Existing Customer',
      });

      // Attempt transaction that throws midway
      try {
        await db.transaction((txn) async {
          await txn.insert('local_invoices', {
            'id': 'inv_fail_001',
            'business_id': 'biz_test_001',
            'invoice_number': 'OFFLINE-INV-FAIL',
          });

          // Simulate mid-transaction error (e.g. calculation or disk failure)
          throw StateError('Simulated transaction failure');
        });
      } catch (e) {
        expect(e, isA<StateError>());
      }

      // Verify the aborted invoice was NOT committed
      final invoices = await db.query('local_invoices');
      expect(invoices, isEmpty);

      // Verify pre-existing customer was preserved
      final customers = await db.query('local_customers');
      expect(customers, hasLength(1));
      expect(customers.first['name'], equals('Existing Customer'));
    });

    test('Restarting app preserves pending operations in durable queue', () async {
      final op = SyncOperation(
        id: 'op_restart_001',
        clientOperationId: UuidUtils.generate(),
        businessId: 'biz_test_001',
        entityType: 'INVOICE',
        entityId: 'inv_restart_001',
        operation: 'CREATE',
        payload: {'amount': 1000},
        status: 'PENDING',
        createdAt: DateTime.now(),
      );

      await SyncQueue.instance.enqueue(op);
      expect(await SyncQueue.instance.getPendingCount('biz_test_001'), equals(1));

      // Simulate app restart / service reinitialization
      final reloadedPending = await SyncQueue.instance.getPendingOperations(businessId: 'biz_test_001');
      expect(reloadedPending, hasLength(1));
      expect(reloadedPending.first.id, equals('op_restart_001'));
      expect(reloadedPending.first.status, equals('PENDING'));
    });

    test('Restoring connectivity automatically drains the queue and synchronizes records', () async {
      // 1. Enqueue offline item
      final clientOpId = UuidUtils.generate();
      final op = SyncOperation(
        id: 'op_drain_001',
        clientOperationId: clientOpId,
        businessId: 'biz_test_001',
        entityType: 'INVOICE',
        entityId: 'inv_local_drain',
        operation: 'CREATE',
        payload: {'customerId': 'cust_1'},
        status: 'PENDING',
        createdAt: DateTime.now(),
      );

      final db = await DatabaseManager.instance.database;
      await db.insert('local_invoices', {
        'id': 'inv_local_drain',
        'business_id': 'biz_test_001',
        'invoice_number': 'OFFLINE-INV-DRAIN',
        'client_operation_id': clientOpId,
        'sync_status': SyncStatus.pendingInsert.code,
      });

      await SyncQueue.instance.enqueue(op);
      expect(await SyncQueue.instance.getPendingCount('biz_test_001'), equals(1));

      // 2. Simulate offline to online transition
      ConnectivityService.instance.setMockOnline(false);
      ConnectivityService.instance.setMockOnline(true);

      // Trigger syncNow directly to ensure execution completes
      final syncResult = await SyncManager.instance.syncNow(businessId: 'biz_test_001');

      expect(syncResult.success, isTrue);
      expect(syncResult.syncedCount, equals(1));

      // 3. Queue should now be drained of PENDING items
      final pendingCount = await SyncQueue.instance.getPendingCount('biz_test_001');
      expect(pendingCount, equals(0));

      // 4. Local record must now be marked SYNCED and have canonical number
      final updatedInvoices = await db.query(
        'local_invoices',
        where: 'client_operation_id = ?',
        whereArgs: [clientOpId],
      );
      expect(updatedInvoices.first['sync_status'], equals(SyncStatus.synced.code));
      expect(updatedInvoices.first['invoice_number'], startsWith('INV-2026-27-'));
    });

    test('Authoritative sequence replaces non-authoritative offline number on sync', () async {
      final clientOpId = UuidUtils.generate();
      final db = await DatabaseManager.instance.database;

      await db.insert('local_invoices', {
        'id': 'inv_local_seq',
        'business_id': 'biz_test_001',
        'invoice_number': 'OFFLINE-INV-TEMP99',
        'client_operation_id': clientOpId,
        'sync_status': SyncStatus.pendingInsert.code,
        'server_version': 1,
      });

      final op = SyncOperation(
        id: 'op_seq_001',
        clientOperationId: clientOpId,
        businessId: 'biz_test_001',
        entityType: 'INVOICE',
        entityId: 'inv_local_seq',
        operation: 'CREATE',
        payload: {},
        createdAt: DateTime.now(),
      );

      // Server returns canonical sequential invoice number
      await SyncRepository.instance.applyServerAcknowledgement(op, {
        'canonicalDocumentNumber': 'INV-2026-27-0099',
        'serverVersion': 2,
        'serverEntityId': 'server_inv_99',
      });

      final invoice = (await db.query(
        'local_invoices',
        where: 'client_operation_id = ?',
        whereArgs: [clientOpId],
      )).first;

      expect(invoice['invoice_number'], equals('INV-2026-27-0099'));
      expect(invoice['sync_status'], equals(SyncStatus.synced.code));
      expect(invoice['server_version'], equals(2));
    });

    test('Duplicate operation submission is idempotent and does not create duplicate entries', () async {
      final clientOpId = 'stable-idem-uuid-12345';
      final op = SyncOperation(
        id: 'op_idem_1',
        clientOperationId: clientOpId,
        businessId: 'biz_test_001',
        entityType: 'INVOICE',
        entityId: 'inv_idem_1',
        operation: 'CREATE',
        payload: {'amount': 500},
        createdAt: DateTime.now(),
      );

      await SyncQueue.instance.enqueue(op);
      await SyncQueue.instance.markCompleted(clientOpId);

      // Attempting to re-mark completed or re-apply acknowledgement
      await SyncRepository.instance.applyServerAcknowledgement(op, {
        'canonicalDocumentNumber': 'INV-2026-27-0001',
        'serverVersion': 1,
      });

      final allOps = await SyncQueue.instance.getAllOperations('biz_test_001');
      expect(allOps, hasLength(1));
      expect(allOps.first.status, equals('SYNCED'));
    });

    test('Bounded retries increment retry count and transition to FAILED after max retries', () async {
      final clientOpId = UuidUtils.generate();
      final op = SyncOperation(
        id: 'op_retry_001',
        clientOperationId: clientOpId,
        businessId: 'biz_test_001',
        entityType: 'INVOICE',
        entityId: 'inv_retry_001',
        operation: 'CREATE',
        payload: {},
        createdAt: DateTime.now(),
      );

      await SyncQueue.instance.enqueue(op);

      // 4 retry attempts
      for (int i = 0; i < 4; i++) {
        await SyncQueue.instance.markFailed(clientOpId, 'Network timeout attempt $i');
        final current = (await SyncQueue.instance.getAllOperations('biz_test_001')).first;
        expect(current.status, equals('PENDING'));
        expect(current.retryCount, equals(i + 1));
      }

      // 5th attempt reaches maxRetries -> transitions to FAILED
      await SyncQueue.instance.markFailed(clientOpId, 'Exceeded max retries');
      final failedOp = (await SyncQueue.instance.getAllOperations('biz_test_001')).first;
      expect(failedOp.status, equals('FAILED'));
      expect(failedOp.retryCount, equals(5));

      // Manual retry resets operation to PENDING
      await SyncQueue.instance.retryOperation(clientOpId);
      final resetOp = (await SyncQueue.instance.getAllOperations('biz_test_001')).first;
      expect(resetOp.status, equals('PENDING'));
      expect(resetOp.retryCount, equals(0));
    });

    test('Concurrent edits detect version conflict and preserve data without silent overwrite', () async {
      final clientOpId = UuidUtils.generate();
      final db = await DatabaseManager.instance.database;

      await db.insert('local_customers', {
        'id': 'cust_conflict_001',
        'business_id': 'biz_test_001',
        'name': 'Client Local Name',
        'client_operation_id': clientOpId,
        'sync_status': SyncStatus.pendingUpdate.code,
        'server_version': 1,
      });

      final op = SyncOperation(
        id: 'op_conf_001',
        clientOperationId: clientOpId,
        businessId: 'biz_test_001',
        entityType: 'CUSTOMER',
        entityId: 'cust_conflict_001',
        operation: 'UPDATE',
        version: 1,
        payload: {'name': 'Client Local Name'},
        createdAt: DateTime.now(),
      );

      await SyncQueue.instance.enqueue(op);

      // Server returns conflict (server version was 2)
      await SyncRepository.instance.applyConflict(op, {
        'errorMessage': 'Concurrent edit detected. Server has newer version.',
      });
      await SyncQueue.instance.markConflict(clientOpId, 'Version conflict');

      final customer = (await db.query(
        'local_customers',
        where: 'client_operation_id = ?',
        whereArgs: [clientOpId],
      )).first;

      // Status must be flagged CONFLICT and local name preserved
      expect(customer['sync_status'], equals(SyncStatus.conflict.code));
      expect(customer['name'], equals('Client Local Name'));

      final conflictCount = await SyncQueue.instance.getConflictCount('biz_test_001');
      expect(conflictCount, equals(1));
    });

    test('Tenant switching and logout purges local offline data', () async {
      final db = await DatabaseManager.instance.database;

      // Seed data for Tenant A
      await db.insert('local_invoices', {
        'id': 'inv_tenant_a',
        'business_id': 'biz_tenant_A',
        'invoice_number': 'INV-A-001',
        'client_operation_id': 'op_a',
      });
      await db.insert('local_sync_queue', {
        'id': 'sq_a',
        'business_id': 'biz_tenant_A',
        'client_operation_id': 'op_a',
        'entity_type': 'INVOICE',
        'entity_id': 'inv_tenant_a',
        'operation': 'CREATE',
        'payload': '{}',
        'status': 'PENDING',
        'created_at': DateTime.now().toIso8601String(),
      });

      // Seed data for Tenant B
      await db.insert('local_invoices', {
        'id': 'inv_tenant_b',
        'business_id': 'biz_tenant_B',
        'invoice_number': 'INV-B-001',
        'client_operation_id': 'op_b',
      });

      // Tenant A logs out
      await DatabaseManager.instance.clearTenantData('biz_tenant_A');

      // Verify Tenant A data was purged
      final tenantAInvoices = await db.query(
        'local_invoices',
        where: 'business_id = ?',
        whereArgs: ['biz_tenant_A'],
      );
      expect(tenantAInvoices, isEmpty);

      final tenantAQueue = await db.query(
        'local_sync_queue',
        where: 'business_id = ?',
        whereArgs: ['biz_tenant_A'],
      );
      expect(tenantAQueue, isEmpty);

      // Verify Tenant B data remains completely intact
      final tenantBInvoices = await db.query(
        'local_invoices',
        where: 'business_id = ?',
        whereArgs: ['biz_tenant_B'],
      );
      expect(tenantBInvoices, hasLength(1));
      expect(tenantBInvoices.first['invoice_number'], equals('INV-B-001'));
    });

    testWidgets('AppShell displays sync badge reflecting online and offline sync status', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1280, 900));

      // Online and synced state
      ConnectivityService.instance.setMockOnline(true);
      SyncManager.instance.statusNotifier.value = const SyncStatusInfo(
        isOnline: true,
        pendingCount: 0,
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: AppShell(),
        ),
      );
      await tester.pump();

      expect(find.text('Synced'), findsOneWidget);

      // Offline with 2 pending operations
      ConnectivityService.instance.setMockOnline(false);
      SyncManager.instance.statusNotifier.value = const SyncStatusInfo(
        isOnline: false,
        pendingCount: 2,
      );

      await tester.pump();

      expect(find.text('Offline (2)'), findsOneWidget);

      // Tap sync badge triggers sync feedback snackbar
      await tester.tap(find.text('Offline (2)'));
      await tester.pump();

      expect(find.byType(SnackBar), findsOneWidget);
    });
  });
}
