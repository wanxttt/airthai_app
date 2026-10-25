import 'package:flutter/material.dart';

enum AccountType {
  asset,
  liability,
  equity,
  revenue,
  expense;

  static AccountType fromString(String value) {
    switch (value.toUpperCase()) {
      case 'ASSET':
        return AccountType.asset;
      case 'LIABILITY':
        return AccountType.liability;
      case 'EQUITY':
        return AccountType.equity;
      case 'REVENUE':
        return AccountType.revenue;
      case 'EXPENSE':
        return AccountType.expense;
      default:
        return AccountType.asset;
    }
  }

  String toServerString() {
    switch (this) {
      case AccountType.asset:
        return 'ASSET';
      case AccountType.liability:
        return 'LIABILITY';
      case AccountType.equity:
        return 'EQUITY';
      case AccountType.revenue:
        return 'REVENUE';
      case AccountType.expense:
        return 'EXPENSE';
    }
  }

  String get label {
    switch (this) {
      case AccountType.asset:
        return 'Asset';
      case AccountType.liability:
        return 'Liability';
      case AccountType.equity:
        return 'Equity';
      case AccountType.revenue:
        return 'Revenue';
      case AccountType.expense:
        return 'Expense';
    }
  }

  Color get color {
    switch (this) {
      case AccountType.asset:
        return const Color(0xFF0284C7); // Sky blue
      case AccountType.liability:
        return const Color(0xFFD97706); // Amber
      case AccountType.equity:
        return const Color(0xFF7C3AED); // Purple
      case AccountType.revenue:
        return const Color(0xFF10B981); // Emerald green
      case AccountType.expense:
        return const Color(0xFFEF4444); // Rose red
    }
  }

  bool get isDebitNormal => this == AccountType.asset || this == AccountType.expense;
}

class AccountModel {
  final String id;
  final String code;
  final String name;
  final AccountType type;
  final double balance;
  final DateTime createdAt;

  AccountModel({
    required this.id,
    required this.code,
    required this.name,
    required this.type,
    required this.balance,
    required this.createdAt,
  });

  factory AccountModel.fromJson(Map<String, dynamic> json) {
    return AccountModel(
      id: json['id'] ?? '',
      code: json['code'] ?? '',
      name: json['name'] ?? '',
      type: AccountType.fromString(json['type'] ?? 'ASSET'),
      balance: (json['balance'] is num)
          ? (json['balance'] as num).toDouble()
          : double.tryParse(json['balance']?.toString() ?? '0') ?? 0.0,
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt']) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'code': code,
        'name': name,
        'type': type.toServerString(),
        'balance': balance,
        'createdAt': createdAt.toIso8601String(),
      };
}
