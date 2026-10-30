import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:airthai/core/theme/app_colors.dart';
import 'package:airthai/core/security/session_manager.dart';
import 'package:airthai/core/services/dashboard_service.dart';
import 'package:airthai/core/services/reports_service.dart';
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
      ),
    ),
  );

  group('Reports & Dashboard Services Unit Tests', () {
    test('DashboardService returns comprehensive business metrics', () async {
      final res = await DashboardService.instance.getMetrics(period: 'this_month');
      expect(res.isSuccess, isTrue);
      final data = res.data!;

      expect(data.sales.totalSales, greaterThan(0));
      expect(data.purchases.totalPurchases, greaterThan(0));
      expect(data.expenses.totalExpenses, greaterThan(0));
      expect(data.cashFlow.netCashFlow, equals(data.cashFlow.totalCollections - data.cashFlow.totalDisbursements));
      expect(data.profitability.netProfit, equals(data.profitability.grossProfit - data.profitability.operatingExpenses));
      expect(data.inventory.totalValuation, greaterThan(0));
      expect(data.alerts.isNotEmpty, isTrue);
      expect(data.recentActivity.invoices.isNotEmpty, isTrue);
    });

    test('ReportsService returns sales report with authoritative financial totals', () async {
      final res = await ReportsService.instance.getSalesReport();
      expect(res.isSuccess, isTrue);
      final report = res.data!;

      expect(report.summary.totalInvoiced, greaterThan(0));
      expect(report.summary.totalReceived + report.summary.totalOutstanding, equals(report.summary.totalInvoiced));
      expect(report.items.isNotEmpty, isTrue);
    });

    test('ReportsService returns receivables ageing with verified GL reconciliation', () async {
      final res = await ReportsService.instance.getReceivablesAgeing();
      expect(res.isSuccess, isTrue);
      final report = res.data!;

      expect(report.summary.isReconciled, isTrue);
      expect(report.summary.discrepancy, equals(0.0));
      expect(report.summary.bucket0to30, greaterThan(0));
      expect(report.customers.isNotEmpty, isTrue);
    });

    test('ReportsService returns payables ageing report', () async {
      final res = await ReportsService.instance.getPayablesAgeing();
      expect(res.isSuccess, isTrue);
      final report = res.data!;

      expect(report.summary.isReconciled, isTrue);
      expect(report.summary.totalReceivables, greaterThan(0));
      expect(report.suppliers.isNotEmpty, isTrue);
    });

    test('ReportsService returns stock summary valuation and low stock indicators', () async {
      final res = await ReportsService.instance.getStockSummary();
      expect(res.isSuccess, isTrue);
      final report = res.data!;

      expect(report.summary.totalProducts, greaterThan(0));
      expect(report.summary.totalValuation, greaterThan(0));
      expect(report.items.any((i) => i.stockStatus == 'LOW_STOCK'), isTrue);
    });

    test('ReportsService returns GST statutory preparation summary with Outward vs ITC', () async {
      final res = await ReportsService.instance.getGstSummary();
      expect(res.isSuccess, isTrue);
      final report = res.data!;

      expect(report.outwardSupplies.totalOutwardTaxLiability, greaterThan(0));
      expect(report.inwardSupplies.totalEligibleItc, greaterThan(0));
      expect(report.netGstPayable, equals(report.outwardSupplies.totalOutwardTaxLiability - report.inwardSupplies.totalEligibleItc));
    });
  });

  group('Reports & Dashboard UI Widget Tests', () {
    testWidgets('DashboardScreen renders real KPI cards, alerts, and opens profit assumption modal', (tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      int navigatedTab = -1;

      await tester.pumpWidget(MaterialApp(
        theme: testTheme,
        home: Scaffold(
          body: DashboardScreen(
            onNavigateToTab: (index) => navigatedTab = index,
          ),
        ),
      ));
      await tester.pumpAndSettle();

      // Check Header & Controls
      expect(find.textContaining('Welcome back'), findsOneWidget);
      expect(find.text('PERIOD FILTER: '), findsOneWidget);
      expect(find.text('This Month'), findsOneWidget);

      // Check Alerts
      expect(find.text('BUSINESS NOTIFICATIONS & ALERTS'), findsOneWidget);
      expect(find.text('Low Stock Alert'), findsOneWidget);
      expect(find.text('Overdue Invoices'), findsOneWidget);

      // Check Key KPI Cards
      expect(find.text('Sales for Period'), findsOneWidget);
      expect(find.text('Customer Receivables'), findsOneWidget);
      expect(find.text('Net Cash Flow'), findsOneWidget);
      expect(find.text('Inventory Health'), findsOneWidget);
      expect(find.text('Net Profit Indicator'), findsOneWidget);

      // Tap Profit Indicator Card to trigger Calculation Assumptions Modal
      await tester.ensureVisible(find.text('Net Profit Indicator'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Net Profit Indicator'));
      await tester.pumpAndSettle();
      expect(find.text('Profit Calculation Assumptions'), findsOneWidget);
      expect(find.textContaining('Accrual Basis'), findsOneWidget);

      // Close modal
      await tester.tap(find.text('Close'));
      await tester.pumpAndSettle();
      expect(find.text('Profit Calculation Assumptions'), findsNothing);

      // Check Quick Action Navigation
      await tester.ensureVisible(find.text('Sales & Invoices'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Sales & Invoices'));
      expect(navigatedTab, equals(1));
    });

    testWidgets('ReportsScreen renders report tabs and displays sales report view', (tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(MaterialApp(
        theme: testTheme,
        home: const Scaffold(
          body: ReportsScreen(),
        ),
      ));
      await tester.pumpAndSettle();

      // Check Header & Tabs
      expect(find.text('Business Reports & Intelligence'), findsOneWidget);
      expect(find.text('Sales Report'), findsOneWidget);
      expect(find.text('Purchase Report'), findsOneWidget);
      expect(find.text('Expense Report'), findsOneWidget);
      expect(find.text('Receivables Ageing'), findsOneWidget);
      expect(find.text('Stock Valuation'), findsOneWidget);

      // Default tab is Sales Report
      expect(find.text('Total Invoiced'), findsOneWidget);
      expect(find.text('Total Collections'), findsOneWidget);
      expect(find.text('Outstanding Receivables'), findsOneWidget);

      // Switch to Receivables Ageing tab
      await tester.tap(find.text('Receivables Ageing'));
      await tester.pumpAndSettle();

      expect(find.text('Current (0-30 Days)'), findsOneWidget);
      expect(find.text('31 - 60 Days'), findsOneWidget);
      expect(find.text('61 - 90 Days'), findsOneWidget);
      expect(find.text('90+ Days (Severe)'), findsOneWidget);
      expect(find.textContaining('Reconciled: Customer Ledger Total'), findsOneWidget);
    });
  });
}
