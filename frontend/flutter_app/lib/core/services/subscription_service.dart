import 'dart:async';
import '../constants/api_constants.dart';
import '../network/api_client.dart';
import '../network/service_result.dart';
import '../security/session_manager.dart';
import '../../features/subscriptions/models/subscription_model.dart';

/// Subscription Foundation Service for AirthAI.
class SubscriptionService {
  SubscriptionService._();
  static final SubscriptionService instance = SubscriptionService._();

  final List<PlanModel> _mockPlans = [
    const PlanModel(
      id: 'plan_starter_dev',
      name: 'Starter (Free Dev)',
      maxUsers: 1,
      maxInvoicesMonthly: 50,
      priceMonthly: 0.0,
    ),
    const PlanModel(
      id: 'plan_professional_dev',
      name: 'Professional',
      maxUsers: 5,
      maxInvoicesMonthly: 500,
      priceMonthly: 999.0,
    ),
    const PlanModel(
      id: 'plan_enterprise_dev',
      name: 'Enterprise',
      maxUsers: 50,
      maxInvoicesMonthly: 10000,
      priceMonthly: 2999.0,
    ),
  ];

  PlanModel _currentPlan = const PlanModel(
    id: 'plan_starter_dev',
    name: 'Starter (Free Dev)',
    maxUsers: 1,
    maxInvoicesMonthly: 50,
    priceMonthly: 0.0,
  );

  /// Retrieves the current active subscription and usage entitlements.
  Future<ServiceResult<SubscriptionDetailsModel>> getCurrentSubscription() async {
    final mode = SessionManager.instance.authMode;

    if (mode == AuthMode.restBackend) {
      final response = await ApiClient.instance.get(ApiConstants.subscriptionsCurrent);
      if (response.statusCode >= 200 && response.statusCode < 300 && response.data != null) {
        final data = SubscriptionDetailsModel.fromJson(response.data!['data'] as Map<String, dynamic>);
        return ServiceResult(success: true, data: data, statusCode: response.statusCode);
      }
      return ServiceResult(
        success: false,
        errorMessage: response.errorMessage ?? 'Failed to load subscription details',
        statusCode: response.statusCode,
      );
    }

    // DevMock
    await Future.delayed(const Duration(milliseconds: 50));
    final details = SubscriptionDetailsModel(
      id: 'sub_mock_active',
      businessId: SessionManager.instance.currentUser?.businessId ?? 'biz_dev_001',
      status: 'ACTIVE',
      validUntil: DateTime.now().add(const Duration(days: 330)),
      daysRemaining: 330,
      plan: _currentPlan,
      usage: SubscriptionUsageModel(
        currentUsers: 1,
        maxUsers: _currentPlan.maxUsers,
        usersRemaining: _currentPlan.maxUsers - 1,
        monthlyInvoices: 8,
        maxInvoicesMonthly: _currentPlan.maxInvoicesMonthly,
        invoicesRemaining: _currentPlan.maxInvoicesMonthly - 8,
      ),
    );
    return ServiceResult(success: true, data: details);
  }

  /// Lists all available development subscription plans.
  Future<ServiceResult<List<PlanModel>>> getPlans() async {
    final mode = SessionManager.instance.authMode;

    if (mode == AuthMode.restBackend) {
      final response = await ApiClient.instance.get(ApiConstants.subscriptionsPlans);
      if (response.statusCode >= 200 && response.statusCode < 300 && response.data != null) {
        final list = (response.data!['data'] as List<dynamic>?) ?? [];
        final plans = list.map((e) => PlanModel.fromJson(e as Map<String, dynamic>)).toList();
        return ServiceResult(success: true, data: plans, statusCode: response.statusCode);
      }
      return ServiceResult(
        success: false,
        errorMessage: response.errorMessage ?? 'Failed to load subscription plans',
        statusCode: response.statusCode,
      );
    }

    return ServiceResult(success: true, data: _mockPlans);
  }

  /// Switches active development plan.
  Future<ServiceResult<bool>> changePlan(String planId) async {
    final mode = SessionManager.instance.authMode;

    if (mode == AuthMode.restBackend) {
      final response = await ApiClient.instance.post(
        ApiConstants.subscriptionsChangePlan,
        body: {'planId': planId},
      );
      if (response.statusCode >= 200 && response.statusCode < 300) {
        return const ServiceResult(success: true, data: true);
      }
      return ServiceResult(
        success: false,
        errorMessage: response.errorMessage ?? 'Failed to update plan',
        statusCode: response.statusCode,
      );
    }

    final match = _mockPlans.firstWhere((p) => p.id == planId, orElse: () => _mockPlans.first);
    _currentPlan = match;
    return const ServiceResult(success: true, data: true);
  }

  /// Resets active plan to Starter default for testing.
  void resetMockData() {
    _currentPlan = _mockPlans.first;
  }
}

