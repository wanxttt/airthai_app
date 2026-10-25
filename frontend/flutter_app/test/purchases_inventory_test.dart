import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:airthai/core/security/session_manager.dart';
import 'package:airthai/core/services/inventory_service.dart';
import 'package:airthai/core/services/purchase_service.dart';
import 'package:airthai/features/inventory/presentation/screens/inventory_screen.dart';
import 'package:airthai/features/purchases/models/purchase_models.dart';
import 'package:airthai/features/purchases/presentation/screens/create_purchase_screen.dart';
import 'package:airthai/features/purchases/presentation/screens/purchase_detail_screen.dart';
import 'package:airthai/features/purchases/presentation/screens/purchases_screen.dart';
import 'package:airthai/shared/widgets/app_shell.dart';

void main() {
  setUp(() async {
    SessionManager.instance.setAuthMode(AuthMode.devMock);
  });

  group('PurchaseService Unit Tests (Dev Mock Mode)', () {
    test('Purchase bills retrieval, creation, receiving, and cancellation work correctly', () async {
      final listRes = await PurchaseService.instance.getPurchases();
      expect(listRes.success, true);
      expect(listRes.data, isNotEmpty);
      final initialCount = listRes.data!.length;

      // 1. Create confirmed purchase bill (status = RECEIVED)
      final createRes = await PurchaseService.instance.createPurchase({
        'supplierId': 'supp_001',
        'supplierName': 'Tata Steel Distribution',
        'billNumber': 'BILL-TEST-999',
        'status': 'RECEIVED',
        'notes': 'Unit test delivery',
        'items': [
          {
            'productId': 'prod_001',
            'description': 'Industrial Fasteners Pack',
            'quantity': 50.0,
            'unitCost': 100.0,
            'taxRate': 18.0,
          },
        ],
      });

      expect(createRes.success, true);
      final p = createRes.data!;
      expect(p.billNumber, 'BILL-TEST-999');
      expect(p.status, 'RECEIVED');
      expect(p.isReceived, true);
      expect(p.subtotal, 5000.0);
      expect(p.taxAmount, 900.0);
      expect(p.totalAmount, 5900.0);
      expect(p.balanceAmount, 5900.0);
      expect(p.isUnpaid, true);

      // Verify added to list
      final updatedList = await PurchaseService.instance.getPurchases();
      expect(updatedList.data!.length, initialCount + 1);

      // 2. Cancel the purchase bill
      final cancelRes = await PurchaseService.instance.cancelPurchase(
        p.id,
        'Vendor returned order',
      );
      expect(cancelRes.success, true);
      expect(cancelRes.data?.status, 'CANCELLED');
      expect(cancelRes.data?.isCancelled, true);
      expect(cancelRes.data?.balanceAmount, 0.0);
    });

    test('Purchase order creation and receiving workflow', () async {
      // 1. Create draft purchase order (status = ORDERED)
      final createRes = await PurchaseService.instance.createPurchase({
        'supplierId': 'supp_002',
        'supplierName': 'Bharat Petroleum Commercial',
        'billNumber': 'PO-TEST-001',
        'status': 'ORDERED',
        'items': [
          {
            'productId': 'prod_002',
            'description': 'Lubricant Drum 200L',
            'quantity': 5.0,
            'unitCost': 4000.0,
            'taxRate': 18.0,
          },
        ],
      });

      expect(createRes.success, true);
      final po = createRes.data!;
      expect(po.status, 'ORDERED');
      expect(po.isOrdered, true);

      // 2. Receive goods against purchase order
      final receiveRes = await PurchaseService.instance.receivePurchase(po.id);
      expect(receiveRes.success, true);
      expect(receiveRes.data?.status, 'RECEIVED');
      expect(receiveRes.data?.isReceived, true);
    });

    test('Purchase search and status filter', () async {
      final searchRes = await PurchaseService.instance.getPurchases(search: 'Tata');
      expect(searchRes.success, true);
      expect(searchRes.data?.every((p) => p.supplierName?.contains('Tata') ?? false), true);

      final statusRes = await PurchaseService.instance.getPurchases(status: 'RECEIVED');
      expect(statusRes.success, true);
      expect(statusRes.data?.every((p) => p.isReceived), true);
    });
  });

  group('InventoryService Unit Tests (Dev Mock Mode)', () {
    test('Inventory summary computes valuation and stock counts accurately', () async {
      final sumRes = await InventoryService.instance.getSummary();
      expect(sumRes.success, true);
      final summary = sumRes.data!;
      expect(summary.totalProducts, greaterThan(0));
      expect(summary.totalStockQuantity, greaterThanOrEqualTo(0));
      expect(summary.totalValuation, greaterThan(0));
      expect(summary.valuationMethod, 'WEIGHTED_AVERAGE_COST');
    });

    test('Inventory products list retrieves stock statuses and unit valuations', () async {
      final prodRes = await InventoryService.instance.getProducts();
      expect(prodRes.success, true);
      expect(prodRes.data, isNotEmpty);
      final item = prodRes.data!.first;
      expect(item.name, isNotEmpty);
      expect(item.trackStock, true);
      expect(item.unitCost, greaterThan(0));
      expect(item.valuation, item.currentStock * item.unitCost);
    });

    test('Stock adjustments: ADD, SUB, and negative stock rejection', () async {
      final prodRes = await InventoryService.instance.getProducts();
      final prod = prodRes.data!.first;
      final initialStock = prod.currentStock;

      // 1. Positive adjustment (ADJUSTMENT_ADD)
      final addRes = await InventoryService.instance.recordAdjustment({
        'productId': prod.id,
        'movementType': 'ADJUSTMENT_ADD',
        'quantity': 15.0,
        'unitCost': prod.unitCost,
        'reason': 'Physical Count Surplus',
      });
      expect(addRes.success, true);
      expect(addRes.data?.movementType, 'ADJUSTMENT_ADD');
      expect(addRes.data?.quantity, 15.0);

      // Check stock increased
      final afterAdd = await InventoryService.instance.getProducts();
      final updatedProd = afterAdd.data!.firstWhere((p) => p.id == prod.id);
      expect(updatedProd.currentStock, initialStock + 15.0);

      // 2. Negative adjustment (ADJUSTMENT_SUB)
      final subRes = await InventoryService.instance.recordAdjustment({
        'productId': prod.id,
        'movementType': 'ADJUSTMENT_SUB',
        'quantity': 5.0,
        'unitCost': prod.unitCost,
        'reason': 'Stock Write-off',
      });
      expect(subRes.success, true);
      expect(subRes.data?.quantity, 5.0);
      expect(subRes.data?.movementType, 'ADJUSTMENT_SUB');

      // 3. Reject adjustment when negative stock is prevented
      final excessiveQty = updatedProd.currentStock + 50000.0;
      final failRes = await InventoryService.instance.recordAdjustment({
        'productId': prod.id,
        'movementType': 'ADJUSTMENT_SUB',
        'quantity': excessiveQty,
        'unitCost': prod.unitCost,
        'reason': 'Invalid excessive reduction',
      });
      expect(failRes.success, false);
      expect(failRes.errorMessage, contains('negative'));
    });

    test('Product stock movement history audit trail', () async {
      final movementsRes = await InventoryService.instance.getProductMovements('prod_001');
      expect(movementsRes.success, true);
      expect(movementsRes.data, isNotEmpty);
      final m = movementsRes.data!.first;
      expect(m.productId, 'prod_001');
      expect(m.movementType, isNotEmpty);
    });
  });

  group('Purchases & Inventory Widget & Navigation Tests', () {
    testWidgets('PurchasesScreen renders metric cards, filters, and bills', (tester) async {
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(const MaterialApp(home: PurchasesScreen()));
      await tester.pumpAndSettle();

      expect(find.text('Total Purchases'), findsOneWidget);
      expect(find.text('Outstanding Payables'), findsOneWidget);
      expect(find.text('Received Bills'), findsOneWidget);
      expect(find.text('Ordered / Pending'), findsOneWidget);
      expect(find.text('New Purchase Bill'), findsOneWidget);
    });

    testWidgets('AppShell navigates to Purchases tab (index 2)', (tester) async {
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(const MaterialApp(home: AppShell()));
      await tester.pumpAndSettle();

      // Tap Purchases in navigation sidebar
      await tester.tap(find.text('Purchases'));
      await tester.pumpAndSettle();

      expect(find.byType(PurchasesScreen), findsOneWidget);
    });

    testWidgets('CreatePurchaseScreen renders supplier dropdown, items editor, and live totals', (tester) async {
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(const MaterialApp(home: CreatePurchaseScreen()));
      await tester.pumpAndSettle();

      expect(find.text('Supplier & Bill Details'), findsOneWidget);
      expect(find.text('Purchased Items'), findsOneWidget);
      expect(find.text('Purchase Bill Summary'), findsOneWidget);
      expect(find.text('Confirm & Receive into Stock'), findsOneWidget);
    });

    testWidgets('PurchaseDetailScreen displays bill details, items list, and actions', (tester) async {
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final mockPurchase = PurchaseModel(
        id: 'pur_mock_001',
        billNumber: 'BILL-2026-001',
        billDate: DateTime(2026, 3, 15),
        status: 'RECEIVED',
        supplierId: 'supp_001',
        supplierName: 'Tata Steel Distribution',
        subtotal: 50000.0,
        taxAmount: 9000.0,
        totalAmount: 59000.0,
        balanceAmount: 59000.0,
        items: const [
          PurchaseItemModel(
            id: 'pitem_001',
            productId: 'prod_001',
            description: 'Industrial Safety Helmet - Yellow',
            quantity: 100.0,
            unitCost: 280.0,
            taxRate: 18.0,
            taxAmount: 5040.0,
            totalAmount: 33040.0,
          ),
        ],
      );

      await tester.pumpWidget(MaterialApp(home: PurchaseDetailScreen(purchase: mockPurchase)));
      await tester.pumpAndSettle();

      expect(find.text('PURCHASE BILL'), findsOneWidget);
      expect(find.text('BILL-2026-001'), findsWidgets);
      expect(find.text('Tata Steel Distribution'), findsOneWidget);
      expect(find.text('PURCHASED ITEMS'), findsOneWidget);
    });

    testWidgets('InventoryScreen displays stock valuation summary and adjust stock action', (tester) async {
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(const MaterialApp(home: InventoryScreen()));
      await tester.pumpAndSettle();

      expect(find.text('Total Inventory Valuation'), findsOneWidget);
      expect(find.text('Adjust Stock'), findsOneWidget);
      expect(find.widgetWithText(Tab, 'Products (3)'), findsOneWidget);
    });
  });
}
