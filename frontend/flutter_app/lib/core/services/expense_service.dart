import '../constants/api_constants.dart';
import '../network/api_client.dart';
import '../network/service_result.dart';
import '../security/session_manager.dart';
import '../../features/expenses/models/expense_models.dart';

class ExpenseService {
  ExpenseService._();
  static final ExpenseService instance = ExpenseService._();

  int _nextExpenseSeq = 4;

  final List<ExpenseCategoryModel> _mockCategories = [
    const ExpenseCategoryModel(id: 'cat_rent', name: 'Rent'),
    const ExpenseCategoryModel(id: 'cat_util', name: 'Utilities & Electricity'),
    const ExpenseCategoryModel(id: 'cat_salary', name: 'Salaries & Wages'),
    const ExpenseCategoryModel(id: 'cat_supplies', name: 'Office Supplies'),
    const ExpenseCategoryModel(id: 'cat_travel', name: 'Travel & Logistics'),
    const ExpenseCategoryModel(id: 'cat_maint', name: 'Repairs & Maintenance'),
    const ExpenseCategoryModel(id: 'cat_marketing', name: 'Marketing & Advertising'),
    const ExpenseCategoryModel(id: 'cat_misc', name: 'Miscellaneous'),
  ];

  final List<ExpenseModel> _mockExpenses = [
    ExpenseModel(
      id: 'exp_mock_001',
      expenseNumber: 'EXP-2026-27-0001',
      categoryId: 'cat_rent',
      categoryName: 'Rent',
      date: DateTime.now().subtract(const Duration(days: 10)),
      amount: 25000.0,
      paymentMethod: 'BANK_TRANSFER',
      vendor: 'Shree Real Estate Leasing',
      gstin: '27AABCS1234A1Z5',
      gstAmount: 4500.0,
      isTaxDeductible: true,
      notes: 'Office monthly rent for Main Branch',
    ),
    ExpenseModel(
      id: 'exp_mock_002',
      expenseNumber: 'EXP-2026-27-0002',
      categoryId: 'cat_util',
      categoryName: 'Utilities & Electricity',
      date: DateTime.now().subtract(const Duration(days: 6)),
      amount: 4200.0,
      paymentMethod: 'UPI',
      vendor: 'Maharashtra State Electricity Board',
      gstAmount: 0.0,
      isTaxDeductible: true,
      notes: 'Power bill for workshop',
    ),
    ExpenseModel(
      id: 'exp_mock_003',
      expenseNumber: 'EXP-2026-27-0003',
      categoryId: 'cat_supplies',
      categoryName: 'Office Supplies',
      date: DateTime.now().subtract(const Duration(days: 2)),
      amount: 1850.0,
      paymentMethod: 'CASH',
      vendor: 'Stationery Mart',
      gstAmount: 280.0,
      isTaxDeductible: true,
      notes: 'Printer ink cartridges and paper reams',
    ),
  ];

  /// Get all categories
  Future<ServiceResult<List<ExpenseCategoryModel>>> getCategories() async {
    final mode = SessionManager.instance.authMode;

    if (mode == AuthMode.restBackend) {
      final response = await ApiClient.instance.get(ApiConstants.expenseCategories);
      if (response.statusCode >= 200 && response.statusCode < 300 && response.data != null) {
        final list = (response.data as List<dynamic>?)
                ?.map((c) => ExpenseCategoryModel.fromJson(c as Map<String, dynamic>))
                .toList() ??
            [];
        return ServiceResult(success: true, data: list, statusCode: response.statusCode);
      }
      return ServiceResult(
        success: false,
        errorMessage: response.errorMessage ?? 'Failed to load expense categories',
        statusCode: response.statusCode,
      );
    }

    // Dev Mock mode
    await Future.delayed(const Duration(milliseconds: 60));
    return ServiceResult(success: true, data: List.from(_mockCategories), statusCode: 200);
  }

  /// Create a new category
  Future<ServiceResult<ExpenseCategoryModel>> createCategory(String name) async {
    final mode = SessionManager.instance.authMode;

    if (mode == AuthMode.restBackend) {
      final response = await ApiClient.instance.post(
        ApiConstants.expenseCategories,
        body: {'name': name.trim()},
      );

      if (response.statusCode >= 200 && response.statusCode < 300 && response.data != null) {
        final cat = ExpenseCategoryModel.fromJson(response.data!);
        return ServiceResult(success: true, data: cat, statusCode: response.statusCode);
      }
      return ServiceResult(
        success: false,
        errorMessage: response.errorMessage ?? 'Failed to create expense category',
        statusCode: response.statusCode,
      );
    }

    // Dev Mock mode
    await Future.delayed(const Duration(milliseconds: 80));
    final trimmed = name.trim();
    if (_mockCategories.any((c) => c.name.toLowerCase() == trimmed.toLowerCase())) {
      return const ServiceResult(
        success: false,
        errorMessage: 'Category already exists',
        statusCode: 409,
      );
    }

    final newCat = ExpenseCategoryModel(
      id: 'cat_custom_${DateTime.now().millisecondsSinceEpoch}',
      name: trimmed,
    );
    _mockCategories.add(newCat);
    return ServiceResult(success: true, data: newCat, statusCode: 201);
  }

  /// List expenses
  Future<ServiceResult<List<ExpenseModel>>> getExpenses({
    String? categoryId,
    String? paymentMethod,
    String? search,
    int page = 1,
  }) async {
    final mode = SessionManager.instance.authMode;

    if (mode == AuthMode.restBackend) {
      final queryParams = <String, String>{
        'page': page.toString(),
        if (categoryId != null && categoryId.isNotEmpty) 'categoryId': categoryId,
        if (paymentMethod != null && paymentMethod.isNotEmpty) 'paymentMethod': paymentMethod,
        if (search != null && search.isNotEmpty) 'search': search,
      };

      final response = await ApiClient.instance.get(
        ApiConstants.expenses,
        queryParams: queryParams,
      );

      if (response.statusCode >= 200 && response.statusCode < 300 && response.data != null) {
        final list = (response.data!['data'] as List<dynamic>?)
                ?.map((e) => ExpenseModel.fromJson(e as Map<String, dynamic>))
                .toList() ??
            [];
        return ServiceResult(success: true, data: list, statusCode: response.statusCode);
      }
      return ServiceResult(
        success: false,
        errorMessage: response.errorMessage ?? 'Failed to load expenses',
        statusCode: response.statusCode,
      );
    }

    // Dev Mock mode
    await Future.delayed(const Duration(milliseconds: 100));
    var filtered = List<ExpenseModel>.from(_mockExpenses);

    if (categoryId != null && categoryId.isNotEmpty) {
      filtered = filtered.where((e) => e.categoryId == categoryId).toList();
    }
    if (paymentMethod != null && paymentMethod.isNotEmpty) {
      filtered = filtered.where((e) => e.paymentMethod == paymentMethod).toList();
    }
    if (search != null && search.trim().isNotEmpty) {
      final s = search.trim().toLowerCase();
      filtered = filtered.where((e) {
        return e.expenseNumber.toLowerCase().contains(s) ||
            (e.vendor?.toLowerCase().contains(s) ?? false) ||
            e.categoryName.toLowerCase().contains(s) ||
            (e.notes?.toLowerCase().contains(s) ?? false);
      }).toList();
    }

    filtered.sort((a, b) => b.date.compareTo(a.date));
    return ServiceResult(success: true, data: filtered, statusCode: 200);
  }

  /// Get expense summary
  Future<ServiceResult<ExpenseSummaryModel>> getSummary() async {
    final mode = SessionManager.instance.authMode;

    if (mode == AuthMode.restBackend) {
      final response = await ApiClient.instance.get(ApiConstants.expenseSummary);
      if (response.statusCode >= 200 && response.statusCode < 300 && response.data != null) {
        final summary = ExpenseSummaryModel.fromJson(response.data!);
        return ServiceResult(success: true, data: summary, statusCode: response.statusCode);
      }
      return ServiceResult(
        success: false,
        errorMessage: response.errorMessage ?? 'Failed to load expense summary',
        statusCode: response.statusCode,
      );
    }

    // Dev Mock mode
    await Future.delayed(const Duration(milliseconds: 60));
    double total = 0.0;
    double totalGst = 0.0;
    double deductible = 0.0;
    final Map<String, ExpenseCategorySummary> catMap = {};

    for (final exp in _mockExpenses) {
      total += exp.amount;
      totalGst += exp.gstAmount;
      if (exp.isTaxDeductible) deductible += exp.amount;

      final existing = catMap[exp.categoryId] ??
          ExpenseCategorySummary(
            categoryId: exp.categoryId,
            categoryName: exp.categoryName,
            amount: 0.0,
            count: 0,
          );
      catMap[exp.categoryId] = ExpenseCategorySummary(
        categoryId: exp.categoryId,
        categoryName: exp.categoryName,
        amount: existing.amount + exp.amount,
        count: existing.count + 1,
      );
    }

    return ServiceResult(
      success: true,
      data: ExpenseSummaryModel(
        totalExpenses: total,
        totalGstAmount: totalGst,
        totalTaxDeductible: deductible,
        count: _mockExpenses.length,
        categoryBreakdown: catMap.values.toList(),
      ),
      statusCode: 200,
    );
  }

  /// Create a new expense
  Future<ServiceResult<ExpenseModel>> createExpense(Map<String, dynamic> payload) async {
    final mode = SessionManager.instance.authMode;

    if (mode == AuthMode.restBackend) {
      final response = await ApiClient.instance.post(
        ApiConstants.expenses,
        body: payload,
      );

      if (response.statusCode >= 200 && response.statusCode < 300 && response.data != null) {
        final exp = ExpenseModel.fromJson(response.data!);
        return ServiceResult(success: true, data: exp, statusCode: response.statusCode);
      }
      return ServiceResult(
        success: false,
        errorMessage: response.errorMessage ?? 'Failed to create expense',
        statusCode: response.statusCode,
      );
    }

    // Dev Mock mode
    await Future.delayed(const Duration(milliseconds: 120));
    final amount = (payload['amount'] as num?)?.toDouble() ?? 0.0;
    if (amount <= 0) {
      return const ServiceResult(
        success: false,
        errorMessage: 'Expense amount must be greater than zero.',
        statusCode: 400,
      );
    }

    final categoryId = payload['categoryId'] as String? ?? 'cat_misc';
    final category = _mockCategories.firstWhere(
      (c) => c.id == categoryId,
      orElse: () => const ExpenseCategoryModel(id: 'cat_misc', name: 'Miscellaneous'),
    );

    final seq = _nextExpenseSeq++;
    final expNum = 'EXP-2026-27-${seq.toString().padLeft(4, '0')}';

    final newExp = ExpenseModel(
      id: 'exp_${DateTime.now().millisecondsSinceEpoch}',
      expenseNumber: expNum,
      categoryId: category.id,
      categoryName: category.name,
      date: payload['date'] != null
          ? DateTime.tryParse(payload['date'] as String) ?? DateTime.now()
          : DateTime.now(),
      amount: amount,
      paymentMethod: payload['paymentMethod'] as String? ?? 'CASH',
      vendor: payload['vendor'] as String?,
      gstin: payload['gstin'] as String?,
      gstAmount: (payload['gstAmount'] as num?)?.toDouble() ?? 0.0,
      isTaxDeductible: payload['isTaxDeductible'] as bool? ?? true,
      receiptUrl: payload['receiptUrl'] as String?,
      notes: payload['notes'] as String?,
    );

    _mockExpenses.insert(0, newExp);
    return ServiceResult(success: true, data: newExp, statusCode: 201);
  }

  /// Delete an expense
  Future<ServiceResult<bool>> deleteExpense(String id) async {
    final mode = SessionManager.instance.authMode;

    if (mode == AuthMode.restBackend) {
      final response = await ApiClient.instance.delete('${ApiConstants.expenses}/$id');
      if (response.statusCode >= 200 && response.statusCode < 300) {
        return const ServiceResult(success: true, data: true, statusCode: 200);
      }
      return ServiceResult(
        success: false,
        errorMessage: response.errorMessage ?? 'Failed to delete expense',
        statusCode: response.statusCode,
      );
    }

    // Dev Mock mode
    await Future.delayed(const Duration(milliseconds: 80));
    _mockExpenses.removeWhere((e) => e.id == id);
    return const ServiceResult(success: true, data: true, statusCode: 200);
  }
}
