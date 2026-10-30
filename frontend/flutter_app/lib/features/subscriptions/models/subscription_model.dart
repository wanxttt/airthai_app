/// Plan Domain Model
class PlanModel {
  final String id;
  final String name;
  final int maxUsers;
  final int maxInvoicesMonthly;
  final double priceMonthly;

  const PlanModel({
    required this.id,
    required this.name,
    required this.maxUsers,
    required this.maxInvoicesMonthly,
    this.priceMonthly = 0.0,
  });

  factory PlanModel.fromJson(Map<String, dynamic> json) {
    return PlanModel(
      id: json['id'] as String,
      name: json['name'] as String? ?? 'Starter',
      maxUsers: (json['maxUsers'] as num?)?.toInt() ?? 1,
      maxInvoicesMonthly: (json['maxInvoicesMonthly'] as num?)?.toInt() ?? 50,
      priceMonthly: (json['priceMonthly'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'maxUsers': maxUsers,
        'maxInvoicesMonthly': maxInvoicesMonthly,
        'priceMonthly': priceMonthly,
      };
}

/// Subscription Usage & Entitlements Model
class SubscriptionUsageModel {
  final int currentUsers;
  final int maxUsers;
  final int usersRemaining;
  final int monthlyInvoices;
  final int maxInvoicesMonthly;
  final int invoicesRemaining;

  const SubscriptionUsageModel({
    required this.currentUsers,
    required this.maxUsers,
    required this.usersRemaining,
    required this.monthlyInvoices,
    required this.maxInvoicesMonthly,
    required this.invoicesRemaining,
  });

  factory SubscriptionUsageModel.fromJson(Map<String, dynamic> json) {
    return SubscriptionUsageModel(
      currentUsers: (json['currentUsers'] as num?)?.toInt() ?? 1,
      maxUsers: (json['maxUsers'] as num?)?.toInt() ?? 1,
      usersRemaining: (json['usersRemaining'] as num?)?.toInt() ?? 0,
      monthlyInvoices: (json['monthlyInvoices'] as num?)?.toInt() ?? 0,
      maxInvoicesMonthly: (json['maxInvoicesMonthly'] as num?)?.toInt() ?? 50,
      invoicesRemaining: (json['invoicesRemaining'] as num?)?.toInt() ?? 50,
    );
  }
}

/// Comprehensive active subscription details
class SubscriptionDetailsModel {
  final String id;
  final String businessId;
  final String status;
  final DateTime validUntil;
  final int daysRemaining;
  final PlanModel plan;
  final SubscriptionUsageModel usage;

  const SubscriptionDetailsModel({
    required this.id,
    required this.businessId,
    required this.status,
    required this.validUntil,
    required this.daysRemaining,
    required this.plan,
    required this.usage,
  });

  factory SubscriptionDetailsModel.fromJson(Map<String, dynamic> json) {
    final sub = json['subscription'] as Map<String, dynamic>;
    final usage = json['usage'] as Map<String, dynamic>;

    return SubscriptionDetailsModel(
      id: sub['id'] as String,
      businessId: sub['businessId'] as String? ?? '',
      status: sub['status'] as String? ?? 'ACTIVE',
      validUntil: DateTime.tryParse(sub['validUntil'].toString()) ?? DateTime.now(),
      daysRemaining: (sub['daysRemaining'] as num?)?.toInt() ?? 365,
      plan: PlanModel.fromJson(sub['plan'] as Map<String, dynamic>),
      usage: SubscriptionUsageModel.fromJson(usage),
    );
  }
}

