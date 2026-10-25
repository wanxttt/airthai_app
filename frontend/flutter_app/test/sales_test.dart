import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:airthai/core/security/session_manager.dart';
import 'package:airthai/core/services/sales_service.dart';
import 'package:airthai/features/sales/models/sales_models.dart';
import 'package:airthai/features/sales/presentation/screens/sales_screen.dart';
import 'package:airthai/features/sales/presentation/screens/create_invoice_screen.dart';
import 'package:airthai/features/sales/presentation/screens/invoice_detail_screen.dart';
import 'package:airthai/shared/widgets/app_shell.dart';

void main() {
  setUp(() async {
    SessionManager.instance.setAuthMode(AuthMode.devMock);
  });

  group('SalesService Unit Tests (Dev Mock Mode)', () {
    test('Invoices retrieval, creation, calculation, and cancellation work correctly', () async {
      final listRes = await SalesService.instance.getInvoices();
      expect(listRes.success, true);
      expect(listRes.data, isNotEmpty);
      final initialCount = listRes.data!.length;

      // 1. Create intra-state invoice (placeOfSupply = '27')
      final createRes = await SalesService.instance.createInvoice({
        'customerName': 'Test Traders Ltd',
        'placeOfSupply': '27',
        'items': [
          {
            'description': 'Hardware Bolts',
            'quantity': 10.0,
            'unitPrice': 100.0, // gross = 1000
            'discountAmount': 50.0, // taxable = 950
            'gstRate': 18.0, // CGST = 85.50, SGST = 85.50
          },
        ],
      });

      expect(createRes.success, true);
      final inv = createRes.data!;
      expect(inv.subtotal, 1000.0);
      expect(inv.taxableAmount, 950.0);
      expect(inv.isInterState, false);
      expect(inv.cgstAmount, 85.50);
      expect(inv.sgstAmount, 85.50);
      expect(inv.igstAmount, 0.0);
      expect(inv.totalAmount, 1121.0); // 950 + 171 = 1121
      expect(inv.status, 'ISSUED');

      // 2. Verify invoice added to list
      final updatedList = await SalesService.instance.getInvoices();
      expect(updatedList.data!.length, initialCount + 1);

      // 3. Cancel the invoice
      final cancelRes = await SalesService.instance.cancelInvoice(
        inv.id,
        'Client requested order cancellation',
      );
      expect(cancelRes.success, true);
      expect(cancelRes.data?.status, 'CANCELLED');
      expect(cancelRes.data?.cancellationReason, 'Client requested order cancellation');
    });

    test('Inter-state invoice calculates IGST correctly', () async {
      final createRes = await SalesService.instance.createInvoice({
        'customerName': 'Bangalore Components',
        'placeOfSupply': '29', // Karnataka (Inter-state)
        'items': [
          {
            'description': 'Circuit Board',
            'quantity': 2.0,
            'unitPrice': 1500.0, // 3000
            'gstRate': 18.0, // IGST 18% = 540
          },
        ],
      });

      expect(createRes.success, true);
      final inv = createRes.data!;
      expect(inv.isInterState, true);
      expect(inv.cgstAmount, 0.0);
      expect(inv.sgstAmount, 0.0);
      expect(inv.igstAmount, 540.0);
      expect(inv.totalAmount, 3540.0);
    });

    test('Quotations CRUD and conversion to invoice work correctly', () async {
      final quoList = await SalesService.instance.getQuotations();
      expect(quoList.success, true);
      expect(quoList.data, isNotEmpty);

      // 1. Create quotation
      final createRes = await SalesService.instance.createQuotation({
        'customerName': 'Apex Infrastructure',
        'items': [
          {
            'description': 'Custom Fabrication Steel',
            'quantity': 5.0,
            'unitPrice': 2000.0,
            'gstRate': 18.0,
          },
        ],
      });

      expect(createRes.success, true);
      final quo = createRes.data!;
      expect(quo.status, 'DRAFT');
      expect(quo.subtotal, 10000.0);

      // 2. Convert quotation to invoice
      final convertRes = await SalesService.instance.convertQuotationToInvoice(quo.id);
      expect(convertRes.success, true);
      expect(convertRes.data?.status, 'ISSUED');
      expect(convertRes.data?.totalAmount, 11800.0);
    });
  });

  group('Sales Widget & Navigation Tests', () {
    testWidgets('SalesScreen renders summary metrics, tabs, and invoice list', (tester) async {
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(const MaterialApp(home: SalesScreen()));
      await tester.pumpAndSettle();

      expect(find.text('Total Invoiced Sales'), findsOneWidget);
      expect(find.text('Total Outstanding Balance'), findsOneWidget);
      expect(find.text('New Tax Invoice'), findsOneWidget);
      expect(find.textContaining('Invoices ('), findsOneWidget);
      expect(find.textContaining('Quotations ('), findsOneWidget);
    });

    testWidgets('AppShell navigates to Sales tab and renders SalesScreen', (tester) async {
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(const MaterialApp(home: AppShell()));
      await tester.pumpAndSettle();

      // Tap Sales in sidebar
      await tester.tap(find.text('Sales'));
      await tester.pumpAndSettle();

      expect(find.byType(SalesScreen), findsOneWidget);
    });

    testWidgets('CreateInvoiceScreen renders customer dropdown, item editor, and live totals', (tester) async {
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(const MaterialApp(home: CreateInvoiceScreen()));
      await tester.pumpAndSettle();

      expect(find.text('Customer & Invoice Details'), findsOneWidget);
      expect(find.text('Line Items'), findsOneWidget);
      expect(find.text('Authoritative Calculation'), findsOneWidget);
      expect(find.text('Generate & Issue Invoice'), findsOneWidget);
    });

    testWidgets('InvoiceDetailScreen displays tax breakdown and print/share actions', (tester) async {
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final mockInvoice = InvoiceModel(
        id: 'inv_mock_001',
        invoiceNumber: 'INV-2026-27-0001',
        invoiceDate: DateTime(2026, 4, 1),
        status: 'ISSUED',
        customerName: 'Shree Ganesh Hardware',
        placeOfSupply: '27',
        isInterState: false,
        subtotal: 10000.0,
        taxableAmount: 10000.0,
        cgstAmount: 900.0,
        sgstAmount: 900.0,
        totalAmount: 11800.0,
        balanceAmount: 11800.0,
        items: const [
          InvoiceItemModel(
            id: 'item_1',
            description: 'Sample Item',
            quantity: 10.0,
            unitPrice: 1000.0,
            taxableAmount: 10000.0,
            gstRate: 18.0,
            cgstAmount: 900.0,
            sgstAmount: 900.0,
            totalAmount: 11800.0,
          ),
        ],
      );

      await tester.pumpWidget(
        MaterialApp(home: InvoiceDetailScreen(invoice: mockInvoice)),
      );
      await tester.pumpAndSettle();

      expect(find.text('TAX INVOICE'), findsOneWidget);
      expect(find.text('INV-2026-27-0001'), findsWidgets);
      expect(find.text('Shree Ganesh Hardware'), findsOneWidget);
      expect(find.byIcon(Icons.print_rounded), findsOneWidget);
    });
  });
}

