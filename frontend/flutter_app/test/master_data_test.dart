import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:airthai/core/security/session_manager.dart';
import 'package:airthai/core/services/master_data_service.dart';
import 'package:airthai/features/customers/presentation/screens/customers_screen.dart';
import 'package:airthai/features/inventory/presentation/screens/inventory_screen.dart';
import 'package:airthai/features/suppliers/presentation/screens/suppliers_screen.dart';
import 'package:airthai/shared/widgets/app_shell.dart';

void main() {
  setUp(() async {
    SessionManager.instance.setAuthMode(AuthMode.devMock);
  });

  group('MasterDataService Unit Tests (Dev Mock Mode)', () {
    test('Categories CRUD operations work as expected', () async {
      final listRes = await MasterDataService.instance.getCategories();
      expect(listRes.success, true);
      expect(listRes.data, isNotEmpty);
      final initialCount = listRes.data!.length;

      // Create
      final createRes = await MasterDataService.instance.createCategory('Stationery');
      expect(createRes.success, true);
      expect(createRes.data?.name, 'Stationery');

      // Verify added
      final updatedList = await MasterDataService.instance.getCategories();
      expect(updatedList.data!.length, initialCount + 1);

      // Delete
      final delRes = await MasterDataService.instance.deleteCategory(createRes.data!.id);
      expect(delRes.success, true);
    });

    test('Units CRUD operations work as expected', () async {
      final listRes = await MasterDataService.instance.getUnits();
      expect(listRes.success, true);
      expect(listRes.data, isNotEmpty);

      // Create
      final createRes = await MasterDataService.instance.createUnit('Meter', 'm');
      expect(createRes.success, true);
      expect(createRes.data?.symbol, 'm');

      // Delete
      final delRes = await MasterDataService.instance.deleteUnit(createRes.data!.id);
      expect(delRes.success, true);
    });

    test('Products CRUD, search, filter, and archive operations work as expected', () async {
      final listRes = await MasterDataService.instance.getProducts();
      expect(listRes.success, true);
      expect(listRes.data, isNotEmpty);

      // Create product
      final createRes = await MasterDataService.instance.createProduct({
        'name': 'Ergonomic Keyboard',
        'sku': 'KB-001',
        'salePrice': 1500.0,
        'purchasePrice': 900.0,
        'gstRate': 18.0,
        'openingStock': 20.0,
        'trackStock': true,
      });
      expect(createRes.success, true);
      expect(createRes.data?.name, 'Ergonomic Keyboard');
      expect(createRes.data?.currentStock, 20.0);

      final prodId = createRes.data!.id;

      // Update product
      final updateRes = await MasterDataService.instance.updateProduct(prodId, {
        'salePrice': 1650.0,
      });
      expect(updateRes.success, true);
      expect(updateRes.data?.salePrice, 1650.0);

      // Toggle archive
      final archRes = await MasterDataService.instance.toggleArchiveProduct(prodId);
      expect(archRes.success, true);
      expect(archRes.data?.status, 'ARCHIVED');

      // Search
      final searchRes = await MasterDataService.instance.getProducts(search: 'Keyboard', status: 'ALL');
      expect(searchRes.success, true);
      expect(searchRes.data?.any((p) => p.id == prodId), true);

      // Delete
      final delRes = await MasterDataService.instance.deleteProduct(prodId);
      expect(delRes.success, true);
    });

    test('Customers CRUD, balance, and archive operations work as expected', () async {
      final listRes = await MasterDataService.instance.getCustomers();
      expect(listRes.success, true);
      expect(listRes.data, isNotEmpty);

      // Create
      final createRes = await MasterDataService.instance.createCustomer({
        'name': 'Mehta & Sons',
        'phone': '9899887766',
        'openingBalance': 8500.0,
        'creditLimit': 30000.0,
      });
      expect(createRes.success, true);
      expect(createRes.data?.currentBalance, 8500.0);

      final custId = createRes.data!.id;

      // Toggle archive
      final archRes = await MasterDataService.instance.toggleArchiveCustomer(custId);
      expect(archRes.success, true);
      expect(archRes.data?.status, 'ARCHIVED');

      // Delete
      final delRes = await MasterDataService.instance.deleteCustomer(custId);
      expect(delRes.success, true);
    });

    test('Suppliers CRUD, payables balance, and archive operations work as expected', () async {
      final listRes = await MasterDataService.instance.getSuppliers();
      expect(listRes.success, true);
      expect(listRes.data, isNotEmpty);

      // Create
      final createRes = await MasterDataService.instance.createSupplier({
        'name': 'Apex Raw Materials Ltd',
        'phone': '9876543299',
        'openingBalance': 15000.0,
        'gstin': '27ABCDE1234F1Z5',
      });
      expect(createRes.success, true);
      expect(createRes.data?.currentBalance, 15000.0);

      final suppId = createRes.data!.id;

      // Toggle archive
      final archRes = await MasterDataService.instance.toggleArchiveSupplier(suppId);
      expect(archRes.success, true);
      expect(archRes.data?.status, 'ARCHIVED');

      // Delete
      final delRes = await MasterDataService.instance.deleteSupplier(suppId);
      expect(delRes.success, true);
    });
  });

  group('Master Data Widget & Navigation Tests', () {
    testWidgets('InventoryScreen renders tabs, search bar, and product list', (tester) async {
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(const MaterialApp(home: InventoryScreen()));
      await tester.pumpAndSettle();

      expect(find.widgetWithText(Tab, 'Products (3)'), findsOneWidget);
      expect(find.widgetWithText(Tab, 'Categories (3)'), findsOneWidget);
      expect(find.widgetWithText(Tab, 'Units of Measure (3)'), findsOneWidget);
      expect(find.text('Add Product'), findsOneWidget);
      expect(find.byType(TextField), findsOneWidget);
    });

    testWidgets('CustomersScreen renders summary card and customer list', (tester) async {
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(const MaterialApp(home: CustomersScreen()));
      await tester.pumpAndSettle();

      expect(find.text('Total Customers'), findsOneWidget);
      expect(find.text('Total Receivables'), findsOneWidget);
      expect(find.text('Add Customer'), findsOneWidget);
    });

    testWidgets('SuppliersScreen renders summary card and supplier list', (tester) async {
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(const MaterialApp(home: SuppliersScreen()));
      await tester.pumpAndSettle();

      expect(find.text('Total Suppliers'), findsOneWidget);
      expect(find.text('Total Payables'), findsOneWidget);
      expect(find.text('Add Supplier'), findsOneWidget);
    });

    testWidgets('AppShell navigates to Inventory, Customers, and Suppliers tabs', (tester) async {
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(const MaterialApp(home: AppShell()));
      await tester.pumpAndSettle();

      // Tap Inventory in sidebar
      await tester.tap(find.text('Inventory'));
      await tester.pumpAndSettle();
      expect(find.byType(InventoryScreen), findsOneWidget);

      // Tap Customers in sidebar
      await tester.tap(find.text('Customers'));
      await tester.pumpAndSettle();
      expect(find.byType(CustomersScreen), findsOneWidget);

      // Tap Suppliers in sidebar
      await tester.tap(find.text('Suppliers'));
      await tester.pumpAndSettle();
      expect(find.byType(SuppliersScreen), findsOneWidget);
    });
  });
}
