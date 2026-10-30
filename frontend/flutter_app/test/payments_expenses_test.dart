import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:airthai/core/security/session_manager.dart';
import 'package:airthai/core/services/payment_service.dart';
import 'package:airthai/core/services/expense_service.dart';
import 'package:airthai/features/payments/models/payment_models.dart';
import 'package:airthai/features/payments/presentation/screens/payments_screen.dart';
import 'package:airthai/features/payments/presentation/screens/record_receipt_screen.dart';
import 'package:airthai/features/payments/presentation/screens/record_supplier_payment_screen.dart';
import 'package:airthai/features/payments/presentation/screens/payment_detail_screen.dart';
import 'package:airthai/features/expenses/presentation/screens/expenses_screen.dart';
import 'package:airthai/features/expenses/presentation/screens/create_expense_screen.dart';
import 'package:airthai/shared/widgets/app_shell.dart';

void main() {
  setUp(() async {
    SessionManager.instance.setAuthMode(AuthMode.devMock);
  });

  group('PaymentService Unit Tests (Dev Mock Mode)', () {
    test('Customer receipts retrieval, creation, allocation, and voiding work correctly', () async {
      // 1. Initial retrieval
      final initialRes = await PaymentService.instance.getPayments(paymentType: 'CUSTOMER_RECEIPT');
      expect(initialRes.success, true);
      expect(initialRes.data, isNotEmpty);
      final initialCount = initialRes.data!.length;

      // 2. Record customer receipt with invoice allocation
      final createRes = await PaymentService.instance.recordCustomerReceipt({
        'customerId': 'cust_001',
        'customerName': 'Shree Ganesh Hardware',
        'amount': 8000.0,
        'paymentMethod': 'UPI',
        'referenceNumber': 'UPI/TEST/998877',
        'allocations': [
          {
            'invoiceId': 'inv_mock_001',
            'invoiceNumber': 'INV-2026-27-0001',
            'amount': 8000.0,
          },
        ],
      });

      expect(createRes.success, true);
      final receipt = createRes.data!;
      expect(receipt.paymentNumber, startsWith('REC-2026-27-'));
      expect(receipt.amount, 8000.0);
      expect(receipt.isCustomerReceipt, true);
      expect(receipt.allocations.length, 1);
      expect(receipt.allocations.first.amount, 8000.0);
      expect(receipt.totalAllocated, 8000.0);
      expect(receipt.unallocatedAmount, 0.0);

      // 3. Verify in list
      final updatedRes = await PaymentService.instance.getPayments(paymentType: 'CUSTOMER_RECEIPT');
      expect(updatedRes.data!.length, initialCount + 1);

      // 4. Void the receipt
      final voidRes = await PaymentService.instance.voidPayment(receipt.id, 'Entry mistake');
      expect(voidRes.success, true);

      final postVoidRes = await PaymentService.instance.getPayments(paymentType: 'CUSTOMER_RECEIPT');
      expect(postVoidRes.data!.length, initialCount);
    });

    test('Customer receipt rejects over-allocation', () async {
      final overAllocRes = await PaymentService.instance.recordCustomerReceipt({
        'customerId': 'cust_001',
        'amount': 5000.0,
        'allocations': [
          {
            'invoiceId': 'inv_mock_001',
            'amount': 6000.0, // 6000 > 5000 receipt amount!
          },
        ],
      });

      expect(overAllocRes.success, false);
      expect(overAllocRes.errorMessage, contains('exceeds receipt amount'));
    });

    test('Supplier payment creation and bill allocation work correctly', () async {
      final payRes = await PaymentService.instance.recordSupplierPayment({
        'supplierId': 'supp_001',
        'supplierName': 'Apex Industrial Parts Ltd',
        'amount': 25000.0,
        'paymentMethod': 'BANK_TRANSFER',
        'referenceNumber': 'NEFT/SBI/112233',
        'allocations': [
          {
            'purchaseId': 'pur_mock_001',
            'billNumber': 'PB-2026-27-0001',
            'amount': 25000.0,
          },
        ],
      });

      expect(payRes.success, true);
      final payment = payRes.data!;
      expect(payment.paymentNumber, startsWith('PAY-2026-27-'));
      expect(payment.amount, 25000.0);
      expect(payment.isSupplierPayment, true);
      expect(payment.allocations.length, 1);
      expect(payment.allocations.first.billNumber, 'PB-2026-27-0001');
    });

    test('Customer and supplier outstanding balance queries return pending documents', () async {
      final custOutstanding = await PaymentService.instance.getCustomerOutstanding('cust_001');
      expect(custOutstanding.success, true);
      expect(custOutstanding.data, isNotEmpty);
      expect(custOutstanding.data!.first.balanceAmount, greaterThan(0));

      final suppOutstanding = await PaymentService.instance.getSupplierOutstanding('supp_001');
      expect(suppOutstanding.success, true);
      expect(suppOutstanding.data, isNotEmpty);
      expect(suppOutstanding.data!.first.balanceAmount, greaterThan(0));
    });
  });

  group('ExpenseService Unit Tests (Dev Mock Mode)', () {
    test('Categories retrieval and creation work correctly', () async {
      final catRes = await ExpenseService.instance.getCategories();
      expect(catRes.success, true);
      expect(catRes.data, isNotEmpty);
      expect(catRes.data!.any((c) => c.name == 'Rent'), true);

      // Create new category
      final createCatRes = await ExpenseService.instance.createCategory('Factory Security');
      expect(createCatRes.success, true);
      expect(createCatRes.data!.name, 'Factory Security');

      // Duplicate prevention
      final dupRes = await ExpenseService.instance.createCategory('Factory Security');
      expect(dupRes.success, false);
      expect(dupRes.statusCode, 409);
    });

    test('Expense creation, summary aggregation, and deletion work correctly', () async {
      final initialSummary = await ExpenseService.instance.getSummary();
      expect(initialSummary.success, true);
      final initialCount = initialSummary.data!.count;

      // 1. Create expense
      final createRes = await ExpenseService.instance.createExpense({
        'categoryId': 'cat_rent',
        'amount': 15000.0,
        'date': DateTime.now().toIso8601String(),
        'paymentMethod': 'BANK_TRANSFER',
        'vendor': 'Skyline Commercial Properties',
        'gstin': '27AAACS1234A1Z5',
        'gstAmount': 2700.0,
        'isTaxDeductible': true,
        'notes': 'Workshop rent for current month',
      });

      expect(createRes.success, true);
      final exp = createRes.data!;
      expect(exp.expenseNumber, startsWith('EXP-2026-27-'));
      expect(exp.amount, 15000.0);
      expect(exp.gstAmount, 2700.0);
      expect(exp.isTaxDeductible, true);

      // 2. Verify summary updated
      final updatedSummary = await ExpenseService.instance.getSummary();
      expect(updatedSummary.data!.count, initialCount + 1);
      expect(updatedSummary.data!.totalExpenses, initialSummary.data!.totalExpenses + 15000.0);
      expect(updatedSummary.data!.totalGstAmount, initialSummary.data!.totalGstAmount + 2700.0);

      // 3. Delete expense
      final delRes = await ExpenseService.instance.deleteExpense(exp.id);
      expect(delRes.success, true);
    });
  });

  group('Payments & Expenses Widget & Navigation Tests', () {
    testWidgets('PaymentsScreen renders summary metrics, tab bar, and voucher cards', (tester) async {
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(const MaterialApp(home: PaymentsScreen()));
      await tester.pumpAndSettle();

      expect(find.text('Total Receipts'), findsOneWidget);
      expect(find.text('Supplier Payments'), findsOneWidget);
      expect(find.text('Net Cash Flow'), findsOneWidget);
      expect(find.text('Vouchers Count'), findsOneWidget);
      expect(find.text('Record Receipt'), findsOneWidget);
      expect(find.text('Supplier Payment'), findsOneWidget);
      expect(find.textContaining('All Payments ('), findsOneWidget);
      expect(find.textContaining('Customer Receipts ('), findsOneWidget);
      expect(find.textContaining('Supplier Payments ('), findsOneWidget);
    });

    testWidgets('AppShell navigates to Payments and Expenses tabs', (tester) async {
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(const MaterialApp(home: AppShell()));
      await tester.pumpAndSettle();

      // Tap Payments in sidebar
      await tester.tap(find.text('Payments'));
      await tester.pumpAndSettle();
      expect(find.byType(PaymentsScreen), findsOneWidget);

      // Tap Expenses in sidebar
      await tester.tap(find.text('Expenses'));
      await tester.pumpAndSettle();
      expect(find.byType(ExpensesScreen), findsOneWidget);
    });

    testWidgets('RecordReceiptScreen renders customer selection and invoice allocation', (tester) async {
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(const MaterialApp(home: RecordReceiptScreen()));
      await tester.pumpAndSettle();

      expect(find.text('Receipt Details'), findsOneWidget);
      expect(find.text('Allocate to Invoices'), findsOneWidget);
      expect(find.text('Total Receipt Amount'), findsOneWidget);
      expect(find.widgetWithText(ElevatedButton, 'Record Customer Receipt'), findsOneWidget);
    });

    testWidgets('RecordSupplierPaymentScreen renders supplier selection and bill allocation', (tester) async {
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(const MaterialApp(home: RecordSupplierPaymentScreen()));
      await tester.pumpAndSettle();

      expect(find.text('Payment Details'), findsOneWidget);
      expect(find.text('Allocate to Purchase Bills'), findsOneWidget);
      expect(find.text('Total Payment Amount'), findsOneWidget);
      expect(find.widgetWithText(ElevatedButton, 'Record Supplier Payment'), findsOneWidget);
    });

    testWidgets('PaymentDetailScreen displays voucher details, method, and allocations', (tester) async {
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final mockPayment = PaymentModel(
        id: 'pay_mock_rec_001',
        paymentNumber: 'REC-2026-27-0001',
        paymentType: 'CUSTOMER_RECEIPT',
        customerId: 'cust_001',
        customerName: 'Shree Ganesh Hardware',
        paymentDate: DateTime(2026, 10, 25),
        amount: 5000.0,
        paymentMethod: 'UPI',
        referenceNumber: 'UPI/AXIS/2026102301',
        notes: 'Advance part payment',
        allocations: const [
          PaymentAllocationModel(
            id: 'alloc_1',
            invoiceId: 'inv_001',
            invoiceNumber: 'INV-2026-27-0001',
            amount: 5000.0,
          ),
        ],
      );

      await tester.pumpWidget(MaterialApp(home: PaymentDetailScreen(payment: mockPayment)));
      await tester.pumpAndSettle();

      expect(find.text('Voucher: REC-2026-27-0001'), findsOneWidget);
      expect(find.text('Shree Ganesh Hardware'), findsOneWidget);
      expect(find.text('CUSTOMER RECEIPT'), findsOneWidget);
      expect(find.text('UPI/AXIS/2026102301'), findsOneWidget);
      expect(find.text('INV-2026-27-0001'), findsOneWidget);
    });

    testWidgets('ExpensesScreen renders metrics header, category chips, and expense cards', (tester) async {
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(const MaterialApp(home: ExpensesScreen()));
      await tester.pumpAndSettle();

      expect(find.text('Total Expenses'), findsOneWidget);
      expect(find.text('Tax Deductible'), findsOneWidget);
      expect(find.text('Input GST Claimable'), findsOneWidget);
      expect(find.text('New Expense'), findsOneWidget);
      expect(find.text('Add Category'), findsOneWidget);
    });

    testWidgets('CreateExpenseScreen renders category dropdown, amount field, and GST toggle', (tester) async {
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(const MaterialApp(home: CreateExpenseScreen()));
      await tester.pumpAndSettle();

      expect(find.text('Expense Details'), findsOneWidget);
      expect(find.text('Save Expense Record'), findsOneWidget);
      expect(find.text('Includes Input GST / Tax Invoice Available'), findsOneWidget);
    });
  });
}
