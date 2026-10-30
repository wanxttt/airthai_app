import 'package:flutter_test/flutter_test.dart';
import 'package:airthai/core/database/app_database.dart';
import 'package:airthai/core/database/database_manager.dart';
import 'package:airthai/core/storage/local_storage.dart';
import 'package:airthai/core/sync/sync_operation.dart';
import 'package:airthai/core/sync/sync_queue.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    LocalStorage.instance = MemoryLocalStorage();
    await DatabaseManager.instance.reset();
  });

  tearDown(() async {
    await DatabaseManager.instance.reset();
  });

  group('Offline Storage & Web Persistence Failure-Recovery', () {
    test('Offline table mutations and sync queue items survive database re-initialization', () async {
      const businessId = 'biz_persist_test_001';

      // 1. Initialize fresh local database
      await DatabaseManager.instance.initialize(businessId: businessId);
      final db = await DatabaseManager.instance.database;

      // 2. Insert offline products and an invoice
      await db.insert('products', {
        'id': 'prod_persist_1',
        'business_id': businessId,
        'name': 'Stainless Steel Valves 1/2 inch',
        'selling_price': 850.0,
      });

      // 3. Enqueue an offline sync operation
      final operation = SyncOperation(
        id: 'sync_op_001',
        clientOperationId: 'op_persist_001',
        businessId: businessId,
        entityType: 'INVOICE',
        entityId: 'inv_001',
        operation: 'CREATE',
        payload: {
          'invoiceNumber': 'INV-OFFLINE-001',
          'totalAmount': 1003.0,
        },
        createdAt: DateTime.now(),
      );
      await SyncQueue.instance.enqueue(operation);

      // Verify records exist in memory before simulated restart
      final queuedBefore = await SyncQueue.instance.getPendingOperations(businessId: businessId);
      expect(queuedBefore.length, equals(1));
      expect(queuedBefore.first.clientOperationId, equals('op_persist_001'));

      // 4. Simulate browser reload or app process restart:
      // Verify snapshot was automatically saved to LocalStorage
      final snapshot = await DatabasePersistenceHelper.loadSnapshot();
      expect(snapshot, isNotNull);
      expect(snapshot!.containsKey('products'), isTrue);
      expect(snapshot.containsKey('local_sync_queue'), isTrue);

      // Create new database instance and import snapshot (simulating clean startup restoration)
      final newDb = AppDatabase();
      newDb.importSnapshot(snapshot);

      final restoredProducts = await newDb.query('products', where: 'business_id = ?', whereArgs: [businessId]);
      expect(restoredProducts.length, equals(1));
      expect(restoredProducts.first['name'], equals('Stainless Steel Valves 1/2 inch'));

      final restoredQueue = await newDb.query('local_sync_queue', where: 'business_id = ?', whereArgs: [businessId]);
      expect(restoredQueue.length, equals(1));
      expect(restoredQueue.first['client_operation_id'], equals('op_persist_001'));
    });

    test('User logout / clearTenantData purges all tenant records from persisted storage', () async {
      const businessId1 = 'biz_tenant_alpha';
      const businessId2 = 'biz_tenant_beta';

      await DatabaseManager.instance.initialize(businessId: businessId1);
      final db = await DatabaseManager.instance.database;

      await db.insert('products', {'id': 'prod_a', 'business_id': businessId1, 'name': 'Item A'});
      await db.insert('products', {'id': 'prod_b', 'business_id': businessId2, 'name': 'Item B'});

      // Purge tenant alpha
      await DatabaseManager.instance.clearTenantData(businessId1);

      // Check in-memory database
      final remainingDb = await db.query('products');
      expect(remainingDb.length, equals(1));
      expect(remainingDb.first['business_id'], equals(businessId2));

      // Check persisted snapshot
      final snapshot = await DatabasePersistenceHelper.loadSnapshot();
      expect(snapshot, isNotNull);
      final persistedProducts = snapshot!['products'] as List;
      expect(persistedProducts.length, equals(1));
      expect(persistedProducts.first['business_id'], equals(businessId2));
    });
  });
}
