import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:airthai/core/theme/app_colors.dart';
import 'package:airthai/core/security/session_manager.dart';
import 'package:airthai/shared/widgets/app_shell.dart';
import 'package:airthai/features/sales/presentation/screens/sales_screen.dart';
import 'package:airthai/features/purchases/presentation/screens/purchases_screen.dart';
import 'package:airthai/features/inventory/presentation/screens/inventory_screen.dart';
import 'package:airthai/features/customers/presentation/screens/customers_screen.dart';
import 'package:airthai/features/suppliers/presentation/screens/suppliers_screen.dart';
import 'package:airthai/features/payments/presentation/screens/payments_screen.dart';
import 'package:airthai/features/expenses/presentation/screens/expenses_screen.dart';
import 'package:airthai/features/reports/presentation/screens/dashboard_screen.dart';
import 'package:airthai/features/reports/presentation/screens/reports_screen.dart';

void main() {
  setUp(() async {
    SessionManager.instance.setAuthMode(AuthMode.devMock);
    await SessionManager.instance.login(
      email: 'owner@airthai.in',
      password: 'Password@123',
    );
  });

  final testTheme = ThemeData(
    useMaterial3: true,
    scaffoldBackgroundColor: AppColors.background,
    fontFamily: 'Inter',
    colorScheme: ColorScheme.fromSeed(
      seedColor: AppColors.primary,
      brightness: Brightness.light,
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        minimumSize: const Size(64, 48),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),
    ),
  );

  testWidgets('AppShell navigates to all screens without layout errors on desktop', (tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(MaterialApp(
      theme: testTheme,
      home: const AppShell(),
    ));
    await tester.pumpAndSettle();

    // 1. Dashboard
    expect(find.byType(AppShell), findsOneWidget);
    expect(find.byType(DashboardScreen), findsOneWidget);

    // 2. Sales
    await tester.tap(find.text('Sales'));
    await tester.pumpAndSettle();
    expect(find.byType(SalesScreen), findsOneWidget);

    // 3. Purchases
    await tester.tap(find.text('Purchases'));
    await tester.pumpAndSettle();
    expect(find.byType(PurchasesScreen), findsOneWidget);

    // 4. Inventory
    await tester.tap(find.text('Inventory'));
    await tester.pumpAndSettle();
    expect(find.byType(InventoryScreen), findsOneWidget);

    // 5. Customers
    await tester.tap(find.text('Customers'));
    await tester.pumpAndSettle();
    expect(find.byType(CustomersScreen), findsOneWidget);

    // 6. Suppliers
    await tester.tap(find.text('Suppliers'));
    await tester.pumpAndSettle();
    expect(find.byType(SuppliersScreen), findsOneWidget);

    // 7. Payments
    await tester.tap(find.text('Payments'));
    await tester.pumpAndSettle();
    expect(find.byType(PaymentsScreen), findsOneWidget);

    // 8. Expenses
    await tester.tap(find.text('Expenses'));
    await tester.pumpAndSettle();
    expect(find.byType(ExpensesScreen), findsOneWidget);

    // 9. Reports
    await tester.tap(find.text('Reports'));
    await tester.pumpAndSettle();
    expect(find.byType(ReportsScreen), findsOneWidget);
  });

  testWidgets('AppShell navigates on narrower tablet browser width (800x600) via Drawer', (tester) async {
    tester.view.physicalSize = const Size(800, 600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(MaterialApp(
      theme: testTheme,
      home: const AppShell(),
    ));
    await tester.pumpAndSettle();

    expect(find.byTooltip('Open navigation menu'), findsOneWidget);

    await tester.tap(find.byTooltip('Open navigation menu'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Sales'));
    await tester.pumpAndSettle();

    expect(find.byType(SalesScreen), findsOneWidget);
  });

  testWidgets('AppShell renders on mobile screen width (400x800) without crashing', (tester) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(MaterialApp(
      theme: testTheme,
      home: const AppShell(),
    ));
    await tester.pumpAndSettle();

    expect(find.byType(AppShell), findsOneWidget);
    expect(find.byType(DashboardScreen), findsOneWidget);
  });
}

