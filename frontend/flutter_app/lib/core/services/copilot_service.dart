import 'dart:async';
import '../constants/api_constants.dart';
import '../network/api_client.dart';
import '../network/service_result.dart';
import '../security/session_manager.dart';
import '../../features/copilot/models/copilot_response_model.dart';
import '../../features/copilot/models/copilot_suggestion_model.dart';

/// Read-Only AI Business Copilot Service for AirthAI.
class CopilotService {
  CopilotService._();
  static final CopilotService instance = CopilotService._();

  /// Retrieves Copilot status, model, and availability.
  Future<ServiceResult<Map<String, dynamic>>> getStatus() async {
    final mode = SessionManager.instance.authMode;

    if (mode == AuthMode.restBackend) {
      final response = await ApiClient.instance.get(ApiConstants.copilotStatus);
      if (response.statusCode >= 200 && response.statusCode < 300 && response.data != null) {
        final data = response.data!['data'] as Map<String, dynamic>;
        return ServiceResult(success: true, data: data, statusCode: response.statusCode);
      }
      return ServiceResult(
        success: false,
        errorMessage: response.errorMessage ?? 'Failed to retrieve Copilot status',
        statusCode: response.statusCode,
      );
    }

    // DevMock mode
    return ServiceResult(
      success: true,
      data: {
        'isAvailable': true,
        'model': 'gpt-4o',
        'mode': 'READ_ONLY',
      },
    );
  }

  /// Retrieves suggested canonical questions.
  Future<ServiceResult<List<CopilotSuggestionModel>>> getSuggestions() async {
    final mode = SessionManager.instance.authMode;

    if (mode == AuthMode.restBackend) {
      final response = await ApiClient.instance.get(ApiConstants.copilotSuggestions);
      if (response.statusCode >= 200 && response.statusCode < 300 && response.data != null) {
        final itemsRaw = (response.data!['data'] as List<dynamic>?) ?? [];
        final items = itemsRaw
            .map((e) => CopilotSuggestionModel.fromJson(e as Map<String, dynamic>))
            .toList();
        return ServiceResult(success: true, data: items, statusCode: response.statusCode);
      }
      return ServiceResult(
        success: false,
        errorMessage: response.errorMessage ?? 'Failed to load Copilot suggestions',
        statusCode: response.statusCode,
      );
    }

    // DevMock mode
    return ServiceResult(
      success: true,
      data: const [
        CopilotSuggestionModel(
          id: 'sug_sales',
          category: 'SALES',
          question: 'How much did my business sell during a selected period?',
        ),
        CopilotSuggestionModel(
          id: 'sug_receivables',
          category: 'RECEIVABLES',
          question: 'Which customers have outstanding payments?',
        ),
        CopilotSuggestionModel(
          id: 'sug_inventory',
          category: 'INVENTORY',
          question: 'Which products are low in stock?',
        ),
        CopilotSuggestionModel(
          id: 'sug_expenses',
          category: 'EXPENSES',
          question: 'What were the major recorded expenses?',
        ),
        CopilotSuggestionModel(
          id: 'sug_trends',
          category: 'TRENDS',
          question: "How do this month's sales compare with the previous month?",
        ),
        CopilotSuggestionModel(
          id: 'sug_review',
          category: 'REVIEW',
          question: 'What business issues should I review based on available records?',
        ),
      ],
    );
  }

  /// Queries the Read-Only AI Copilot.
  Future<ServiceResult<CopilotResponseModel>> query(
    String queryText, {
    String? period,
  }) async {
    final mode = SessionManager.instance.authMode;

    if (mode == AuthMode.restBackend) {
      final response = await ApiClient.instance.post(
        ApiConstants.copilotQuery,
        body: {
          'query': queryText,
          if (period != null) 'period': period,
        },
      );

      if (response.statusCode >= 200 && response.statusCode < 300 && response.data != null) {
        final data = response.data!['data'] as Map<String, dynamic>;
        final model = CopilotResponseModel.fromJson(data);
        return ServiceResult(success: true, data: model, statusCode: response.statusCode);
      }

      return ServiceResult(
        success: false,
        errorMessage: response.errorMessage ?? 'Copilot query failed',
        statusCode: response.statusCode,
      );
    }

    // DevMock Mode: Deterministic grounding & safety rules
    await Future.delayed(const Duration(milliseconds: 60));
    final q = queryText.toLowerCase();

    // Check mutation
    final isActionMutation = RegExp(r'\b(create|add|record|make|update|delete|drop|insert|alter|remove|cancel|adjust)\b').hasMatch(q) &&
        RegExp(r'\b(invoice|bill|payment|expense|stock)\b').hasMatch(q) &&
        !q.contains('which') && !q.contains('how much') && !q.contains('what');

    if (isActionMutation) {
      return ServiceResult(
        success: true,
        data: CopilotResponseModel(
          answer: 'The AI Copilot is strictly read-only and cannot create records, make payments, or adjust stock. Please use the appropriate Sales, Payments, or Inventory screens.',
          periodAnalyzed: 'N/A',
          dataUsed: const [],
          calculationDefinition: 'Mutation Prevention Guard: All write operations are blocked.',
          caveats: const ['Read-only safety policy strictly enforced.'],
          recommendedNextStep: 'Navigate to the relevant section to execute the required action.',
          dataFreshness: DateTime.now().toIso8601String(),
          isAvailable: true,
        ),
      );
    }

    // Check canonical questions
    if (q.contains('outstanding') || q.contains('unpaid') || q.contains('receivable')) {
      return ServiceResult(
        success: true,
        data: CopilotResponseModel(
          answer: 'There is 1 customer with outstanding balance totaling ₹17,700.00: Shree Ganesh Hardware (1 overdue invoice).',
          periodAnalyzed: 'All open transactions to date',
          dataUsed: const ['1 active sales invoice with balanceAmount > 0', 'Customer master records'],
          calculationDefinition: 'Customer Outstanding = Sum of balanceAmount for unpaid/partially paid invoices.',
          caveats: const ['Unapplied customer advances are not factored in this invoice total.'],
          recommendedNextStep: 'Send a payment reminder for invoice INV-2026-27-0001.',
          dataFreshness: DateTime.now().toIso8601String(),
          isAvailable: true,
          deterministicFigures: const {'totalReceivables': 17700.0, 'customerCount': 1},
        ),
      );
    }

    if (q.contains('low') || q.contains('stock') || q.contains('inventory') || q.contains('reorder')) {
      return ServiceResult(
        success: true,
        data: CopilotResponseModel(
          answer: '1 product is currently below minimum reorder threshold: Industrial Safety Helmet (Stock: 5, Min: 10).',
          periodAnalyzed: 'Current real-time stock levels',
          dataUsed: const ['1 low-stock item out of 5 tracked products'],
          calculationDefinition: 'Low Stock Deficit = minStockLevel - currentStock where currentStock <= minStockLevel.',
          caveats: const ['Pending purchase bills in draft status do not increment currentStock.'],
          recommendedNextStep: 'Create a purchase bill in the Purchases section to restock.',
          dataFreshness: DateTime.now().toIso8601String(),
          isAvailable: true,
          deterministicFigures: const {'lowStockCount': 1, 'totalTracked': 5},
        ),
      );
    }

    if (q.contains('expense') || q.contains('spend') || q.contains('cost')) {
      return ServiceResult(
        success: true,
        data: CopilotResponseModel(
          answer: 'Total recorded expenses for the current month amount to ₹28,500.00 across 3 entries. Top expense category: Warehouse Rent (₹20,000.00, 70.2%).',
          periodAnalyzed: 'Current Month',
          dataUsed: const ['3 operating expense vouchers', 'Expense category master records'],
          calculationDefinition: 'Total Expenses = Sum of expense vouchers recorded in the period.',
          caveats: const ['Capital expenditures and inventory purchases are tracked under Purchases.'],
          recommendedNextStep: 'Review recurring monthly rent and utility expenses.',
          dataFreshness: DateTime.now().toIso8601String(),
          isAvailable: true,
          deterministicFigures: const {'totalExpenses': 28500.0, 'expenseCount': 3},
        ),
      );
    }

    if (q.contains('compare') || q.contains('previous month') || q.contains('last month') || q.contains('growth')) {
      return ServiceResult(
        success: true,
        data: CopilotResponseModel(
          answer: "Current month sales stand at ₹142,500.00 compared to ₹118,000.00 in the previous month. Absolute change: +₹24,500.00 (+20.8% growth).",
          periodAnalyzed: 'Current Month vs Previous Month',
          dataUsed: const ['Current month posted invoices', 'Prior month posted invoices'],
          calculationDefinition: 'Growth % = ((Current Month Sales - Previous Month Sales) / Previous Month Sales) * 100',
          caveats: ['Current month is ongoing and compares month-to-date with a completed prior month.'],
          recommendedNextStep: 'Continue current sales promotion and monitor stock availability.',
          dataFreshness: DateTime.now().toIso8601String(),
          isAvailable: true,
          deterministicFigures: const {'currentMonthSales': 142500.0, 'previousMonthSales': 118000.0, 'growthPercentage': 20.8},
        ),
      );
    }

    if (q.contains('issue') || q.contains('review') || q.contains('health') || q.contains('alert')) {
      return ServiceResult(
        success: true,
        data: CopilotResponseModel(
          answer: 'We identified 2 operational areas needing your review: (1) 1 product is low in stock (Industrial Safety Helmet), (2) 1 customer invoice (₹17,700.00) is overdue.',
          periodAnalyzed: 'Real-time operational records snapshot',
          dataUsed: const ['Inventory stock thresholds', 'Customer receivables ageing', 'Supplier payables ledger'],
          calculationDefinition: 'Operational health scan evaluates low-stock deficits, overdue debts, and unpaid obligations.',
          caveats: ['Based exclusively on recorded data in AirThai.'],
          recommendedNextStep: 'Prioritize collecting overdue receivables and order low-stock safety helmets.',
          dataFreshness: DateTime.now().toIso8601String(),
          isAvailable: true,
          deterministicFigures: const {'lowStockCount': 1, 'overdueCount': 1, 'overdueAmount': 17700.0},
        ),
      );
    }

    // Default: Sales summary
    return ServiceResult(
      success: true,
      data: CopilotResponseModel(
        answer: 'For the selected period, total sales reached ₹142,500.00 across 8 posted invoices, with an average invoice value of ₹17,812.50. Tax collected: ₹21,737.28.',
        periodAnalyzed: 'Current Month',
        dataUsed: const ['8 non-cancelled posted sales invoices', 'Tax and subtotal breakdown from line items'],
        calculationDefinition: 'Total Sales = Sum(totalAmount) of all non-cancelled invoices issued in the period.',
        caveats: const ['Draft and cancelled invoices are excluded.', 'Amounts reflect invoiced revenue regardless of collection.'],
        recommendedNextStep: 'Follow up on uncollected invoice balances in the Payments section.',
        dataFreshness: DateTime.now().toIso8601String(),
        isAvailable: true,
        deterministicFigures: const {'totalSales': 142500.0, 'invoiceCount': 8, 'averageValue': 17812.5},
      ),
    );
  }
}
