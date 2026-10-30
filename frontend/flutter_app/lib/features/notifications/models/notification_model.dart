import 'package:flutter/material.dart';

/// Notification Domain Model for AirthAI.
class NotificationModel {
  final String id;
  final String type;
  final String title;
  final String message;
  final Map<String, dynamic>? data;
  final bool isRead;
  final DateTime? readAt;
  final DateTime createdAt;
  final String? dedupKey;

  const NotificationModel({
    required this.id,
    required this.type,
    required this.title,
    required this.message,
    this.data,
    this.isRead = false,
    this.readAt,
    required this.createdAt,
    this.dedupKey,
  });

  factory NotificationModel.fromJson(Map<String, dynamic> json) {
    return NotificationModel(
      id: json['id'] as String,
      type: json['type'] as String? ?? 'SYSTEM_ALERT',
      title: json['title'] as String? ?? '',
      message: json['message'] as String? ?? '',
      data: json['data'] != null ? Map<String, dynamic>.from(json['data'] as Map) : null,
      isRead: json['isRead'] as bool? ?? false,
      readAt: json['readAt'] != null ? DateTime.tryParse(json['readAt'].toString()) : null,
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'].toString()) ?? DateTime.now()
          : DateTime.now(),
      dedupKey: json['dedupKey'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type,
        'title': title,
        'message': message,
        'data': data,
        'isRead': isRead,
        'readAt': readAt?.toIso8601String(),
        'createdAt': createdAt.toIso8601String(),
        'dedupKey': dedupKey,
      };

  NotificationModel copyWith({
    bool? isRead,
    DateTime? readAt,
  }) {
    return NotificationModel(
      id: id,
      type: type,
      title: title,
      message: message,
      data: data,
      isRead: isRead ?? this.isRead,
      readAt: readAt ?? this.readAt,
      createdAt: createdAt,
      dedupKey: dedupKey,
    );
  }

  IconData get icon {
    switch (type.toUpperCase()) {
      case 'LOW_STOCK':
        return Icons.inventory_2_outlined;
      case 'OVERDUE_INVOICE':
        return Icons.receipt_long_rounded;
      case 'PAYMENT_RECEIVED':
      case 'PAYMENT':
        return Icons.payments_outlined;
      default:
        return Icons.notifications_active_outlined;
    }
  }

  Color get color {
    switch (type.toUpperCase()) {
      case 'LOW_STOCK':
        return const Color(0xFFD97706); // Amber
      case 'OVERDUE_INVOICE':
        return const Color(0xFFDC2626); // Red
      case 'PAYMENT_RECEIVED':
      case 'PAYMENT':
        return const Color(0xFF059669); // Emerald
      default:
        return const Color(0xFF2563EB); // Blue
    }
  }
}

