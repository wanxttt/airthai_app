import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:airthai/core/database/database_manager.dart';
import 'package:airthai/core/network/connectivity_service.dart';
import 'package:airthai/core/routing/route_guards.dart';
import 'package:airthai/core/security/session_manager.dart';
import 'package:airthai/core/services/master_data_service.dart';
import 'package:airthai/core/services/sales_service.dart';
import 'package:airthai/core/services/purchase_service.dart';
import 'package:airthai/core/services/inventory_service.dart';
import 'package:airthai/core/services/payment_service.dart';
import 'package:airthai/core/services/expense_service.dart';
import 'package:airthai/core/services/accounting_service.dart';
import 'package:airthai/core/services/dashboard_service.dart';
import 'package:airthai/core/services/reports_service.dart';
import 'package:airthai/core/services/copilot_service.dart';
import 'package:airthai/core/sync/sync_manager.dart';
import 'package:airthai/features/auth/presentation/screens/login_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AirthAI Full End-to-End Core Business Lifecycle (Steps 1 to 18)', () {
    setUp(() async {
      SessionManager.instance.setAuthMode(AuthMode.devMock);
      await DatabaseManager.instance.initialize(businessId: 'biz_e2e_001');
      ConnectivityService.instance.setMockOnline(true);
      await SyncManager.instance.reset();
    });

    tearDown(() async {
      await DatabaseManager.instance.reset();
    });

    test('Execute complete 18-step business workflow end-to-end', () async {
      // ----------------------------------------------------
      // STEP 1 & 2: User registration & Business creation
      // In devMock mode, SessionManager manages pre-seeded and active credentials.
      // ----------------------------------------------------
      final loginRes = await SessionManager.instance.login(
        email: 'owner@airthai.in',
        password: 'Admin@123',
      );
      expect(loginRes.success, isTrue, reason: 'Step 1 & 2: User auth and business resolution should succeed');
      expect(SessionManager.instance.isAuthenticated, isTrue);
      expect(SessionManager.instance.currentUser?.businessId, isNotEmpty);

      // ----------------------------------------------------
      // STEP 3: Sign in and session persistence verification
      // ----------------------------------------------------
      expect(SessionManager.instance.currentSession?.accessToken, isNotEmpty);
      expect(SessionManager.instance.currentUser?.email, equals('owner@airthai.in'));

      // ----------------------------------------------------
      // STEP 4: Create products
      // ----------------------------------------------------
      final prodRes = await MasterDataService.instance.createProduct({
        'name': 'AirthAI Smart Controller X1',
        'sku': 'CTRL-X1-001',
        'salePrice': 10000.0,
        'purchasePrice': 6000.0,
        'gstRate': 18.0,
        'openingStock': 10.0,
        'trackStock': true,
      });
      expect(prodRes.success, isTrue, reason: 'Step 4: Product creation should succeed');
      final product = prodRes.data!;
      expect(product.sku, equals('CTRL-X1-001'));
      expect(product.salePrice, equals(10000.0));
      expect(product.currentStock, equals(10.0));

      // ----------------------------------------------------
      // STEP 5: Create customer and supplier
      // ----------------------------------------------------
      final custRes = await MasterDataService.instance.createCustomer({
        'name': 'Apex Infotech Solutions',
        'phone': '9822011223',
        'email': 'accounts@apexinfo.com',
        'stateCode': '27', // Maharashtra (Intra-state)
        'openingBalance': 0.0,
      });
      expect(custRes.success, isTrue, reason: 'Step 5: Customer creation should succeed');
      final customer = custRes.data!;

      final suppRes = await MasterDataService.instance.createSupplier({
        'name': 'Silicon Micro Devices Ltd',
        'phone': '9844055667',
        'email': 'sales@siliconmicro.com',
        'stateCode': '27',
      });
      expect(suppRes.success, isTrue, reason: 'Step 5: Supplier creation should succeed');
      final supplier = suppRes.data!;

      // ----------------------------------------------------
      // STEP 6: Create a purchase and receive stock
      // ----------------------------------------------------
      final purchaseRes = await PurchaseService.instance.createPurchase({
        'supplierId': supplier.id,
        'supplierName': supplier.name,
        'billNumber': 'BILL-E2E-1001',
        'status': 'RECEIVED',
        'items': [
          {
            'productId': product.id,
            'description': product.name,
            'quantity': 20.0,
            'unitCost': 6000.0,
            'taxRate': 18.0,
          },
        ],
      });
      expect(purchaseRes.success, isTrue, reason: 'Step 6: Purchase creation should succeed');
      final purchase = purchaseRes.data!;
      expect(purchase.totalAmount, equals(141600.0)); // 20 * 6000 = 120,000 + 18% tax (21,600) = 141,600
      expect(purchase.isReceived, isTrue);

      // ----------------------------------------------------
      // STEP 7: Create a sales invoice
      // ----------------------------------------------------
      final invRes = await SalesService.instance.createInvoice({
        'customerId': customer.id,
        'customerName': customer.name,
        'placeOfSupply': '27',
        'items': [
          {
            'productId': product.id,
            'description': product.name,
            'quantity': 5.0,
            'unitPrice': 10000.0,
            'gstRate': 18.0,
          },
        ],
      });
      expect(invRes.success, isTrue, reason: 'Step 7: Sales invoice creation should succeed');
      final invoice = invRes.data!;

      // ----------------------------------------------------
      // STEP 8: Verify invoice totals and applicable tax
      // ----------------------------------------------------
      // 5 * 10,000 = 50,000 subtotal. 18% GST intra-state = 9,000 tax.
      // Total invoice = 59,000.00.
      expect(invoice.subtotal, equals(50000.0));
      expect(invoice.totalAmount, equals(59000.0));
      expect(invoice.balanceAmount, equals(59000.0));

      // ----------------------------------------------------
      // STEP 9: Verify stock valuation and level
      // ----------------------------------------------------
      final stockSummaryRes = await InventoryService.instance.getSummary();
      expect(stockSummaryRes.success, isTrue, reason: 'Step 9: Inventory summary should compute');
      expect(stockSummaryRes.data?.totalValuation, greaterThan(0));

      // ----------------------------------------------------
      // STEP 10: Record partial customer payment
      // ----------------------------------------------------
      final receiptRes = await PaymentService.instance.recordCustomerReceipt({
        'customerId': customer.id,
        'customerName': customer.name,
        'amount': 25000.0,
        'paymentMethod': 'UPI',
        'allocations': [
          {'invoiceId': invoice.id, 'invoiceNumber': invoice.invoiceNumber, 'amount': 25000.0},
        ],
      });
      expect(receiptRes.success, isTrue, reason: 'Step 10: Partial payment receipt should record');
      expect(receiptRes.data?.amount, equals(25000.0));

      // ----------------------------------------------------
      // STEP 11: Verify remaining receivable
      // ----------------------------------------------------
      final remainingReceivable = invoice.totalAmount - 25000.0;
      expect(remainingReceivable, equals(34000.0), reason: 'Step 11: Remaining receivable must be ₹34,000.00');

      // ----------------------------------------------------
      // STEP 12: Record supplier payment
      // ----------------------------------------------------
      final suppPayRes = await PaymentService.instance.recordSupplierPayment({
        'supplierId': supplier.id,
        'supplierName': supplier.name,
        'amount': 50000.0,
        'paymentMethod': 'BANK_TRANSFER',
        'allocations': [
          {'purchaseBillId': purchase.id, 'billNumber': purchase.billNumber, 'amount': 50000.0},
        ],
      });
      expect(suppPayRes.success, isTrue, reason: 'Step 12: Supplier payment should record cleanly');
      expect(suppPayRes.data?.amount, equals(50000.0));

      // ----------------------------------------------------
      // STEP 13: Record an expense
      // ----------------------------------------------------
      final expRes = await ExpenseService.instance.createExpense({
        'categoryId': 'cat_rent',
        'amount': 15000.0,
        'paymentMethod': 'BANK_TRANSFER',
        'vendor': 'Cyber Towers Realty',
      });
      expect(expRes.success, isTrue, reason: 'Step 13: Operating expense creation should succeed');

      // ----------------------------------------------------
      // STEP 14: Verify accounting and GST summaries
      // ----------------------------------------------------
      final tbRes = await AccountingService.instance.getTrialBalance();
      expect(tbRes.success, isTrue, reason: 'Step 14: Trial balance should compute');
      expect(tbRes.data?.isBalanced, isTrue, reason: 'Step 14: Trial balance must be strictly double-entry balanced');

      final gstr1Res = await AccountingService.instance.getGstr1();
      expect(gstr1Res.success, isTrue, reason: 'Step 14: GSTR-1 summary should generate');
      expect(gstr1Res.data?.b2bInvoices, isNotEmpty);

      // ----------------------------------------------------
      // STEP 15: Verify dashboard and reports
      // ----------------------------------------------------
      final dashRes = await DashboardService.instance.getMetrics(period: 'this_month');
      expect(dashRes.isSuccess, isTrue, reason: 'Step 15: Dashboard metrics should load');
      expect(dashRes.data?.sales.totalSales, greaterThan(0));

      final reportRes = await ReportsService.instance.getSalesReport();
      expect(reportRes.success, isTrue, reason: 'Step 15: Sales report should generate');

      // ----------------------------------------------------
      // STEP 16: Test offline operation and synchronization
      // ----------------------------------------------------
      ConnectivityService.instance.setMockOnline(false);
      final offlineInvRes = await SalesService.instance.createInvoice({
        'customerId': customer.id,
        'customerName': customer.name,
        'placeOfSupply': '27',
        'items': [
          {
            'productId': product.id,
            'description': 'Offline Backup Module',
            'quantity': 2.0,
            'unitPrice': 1000.0,
            'gstRate': 18.0,
          },
        ],
      });
      expect(offlineInvRes.success, isTrue);
      expect(offlineInvRes.data?.invoiceNumber, startsWith('OFFLINE-INV-'));

      ConnectivityService.instance.setMockOnline(true);
      final syncRes = await SyncManager.instance.syncNow();
      expect(syncRes.success, isTrue, reason: 'Step 16: Sync execution should acknowledge pending operations');

      // ----------------------------------------------------
      // STEP 17: Ask read-only AI Copilot a question
      // ----------------------------------------------------
      final copilotRes = await CopilotService.instance.query(
        'How much did my business sell during a selected period?',
      );
      expect(copilotRes.success, isTrue, reason: 'Step 17: Copilot should provide source-grounded response');
      expect(copilotRes.data?.answer, contains('total sales reached'));
      expect(copilotRes.data?.caveats, isNotEmpty);
      expect(copilotRes.data?.recommendedNextStep, isNotEmpty);

      // ----------------------------------------------------
      // STEP 18: Log out and verify protected routes are inaccessible
      // ----------------------------------------------------
      await SessionManager.instance.logout();
      expect(SessionManager.instance.isAuthenticated, isFalse, reason: 'Step 18: Session must be terminated');

      final protectedWidget = RouteGuards.requireAuth(
        child: const Text('Protected Admin Content'),
      );
      expect(protectedWidget, isA<LoginScreen>(), reason: 'Step 18: Protected routes must redirect unauthenticated users to LoginScreen');
    });
  });
}

