import 'dart:async';
import 'package:flutter/foundation.dart';
import '../constants/api_constants.dart';
import '../network/api_client.dart';
import '../network/service_result.dart';
import '../security/session_manager.dart';
import '../../features/notifications/models/notification_model.dart';

/// Central Notification Service for AirthAI.
class NotificationService {
  NotificationService._() {
    _initMockData();
  }
  static final NotificationService instance = NotificationService._();

  final ValueNotifier<int> unreadCountNotifier = ValueNotifier<int>(2);

  final List<NotificationModel> _mockNotifications = [];

  void _initMockData() {
    _mockNotifications.addAll([
      NotificationModel(
        id: 'notif_mock_1',
        type: 'LOW_STOCK',
        title: 'Low Stock: Industrial Safety Helmet',
        message: 'Industrial Safety Helmet has reached 5 units (minimum threshold: 10).',
        isRead: false,
        createdAt: DateTime.now().subtract(const Duration(hours: 2)),
        dedupKey: 'LOW_STOCK:prod_001:today',
      ),
      NotificationModel(
        id: 'notif_mock_2',
        type: 'OVERDUE_INVOICE',
        title: 'Overdue: Invoice INV-2026-27-0001',
        message: 'Invoice INV-2026-27-0001 for Shree Ganesh Hardware of ₹17,700.00 is overdue.',
        isRead: false,
        createdAt: DateTime.now().subtract(const Duration(hours: 6)),
        dedupKey: 'OVERDUE:inv_001:today',
      ),
      NotificationModel(
        id: 'notif_mock_3',
        type: 'PAYMENT_RECEIVED',
        title: 'Payment Received: ₹5,664.00',
        message: 'Receipt REC-2026-27-0002 recorded from Mehta Electronics.',
        isRead: true,
        readAt: DateTime.now().subtract(const Duration(days: 1)),
        createdAt: DateTime.now().subtract(const Duration(days: 1)),
        dedupKey: 'PAYMENT:pay_002:yesterday',
      ),
    ]);
    _recalculateUnread();
  }

  /// Retrieves notifications with pagination.
  Future<ServiceResult<List<NotificationModel>>> getNotifications({
    bool? isRead,
    int limit = 20,
    int offset = 0,
  }) async {
    final mode = SessionManager.instance.authMode;

    if (mode == AuthMode.restBackend) {
      final queryParams = <String, String>{
        'limit': limit.toString(),
        'offset': offset.toString(),
        if (isRead != null) 'isRead': isRead.toString(),
      };

      final response = await ApiClient.instance.get(
        ApiConstants.notifications,
        queryParams: queryParams,
      );

      if (response.statusCode >= 200 && response.statusCode < 300 && response.data != null) {
        final data = response.data!['data'] as Map<String, dynamic>;
        final itemsRaw = (data['items'] as List<dynamic>?) ?? [];
        final items = itemsRaw.map((e) => NotificationModel.fromJson(e as Map<String, dynamic>)).toList();
        final unread = (data['unreadCount'] as int?) ?? 0;
        unreadCountNotifier.value = unread;
        return ServiceResult(success: true, data: items, statusCode: response.statusCode);
      }

      return ServiceResult(
        success: false,
        errorMessage: response.errorMessage ?? 'Failed to load notifications',
        statusCode: response.statusCode,
      );
    }

    // DevMock mode
    await Future.delayed(const Duration(milliseconds: 50));
    var filtered = _mockNotifications;
    if (isRead != null) {
      filtered = filtered.where((n) => n.isRead == isRead).toList();
    }
    return ServiceResult(success: true, data: filtered);
  }

  /// Marks a specific notification as read.
  Future<ServiceResult<NotificationModel>> markAsRead(String id) async {
    final mode = SessionManager.instance.authMode;

    if (mode == AuthMode.restBackend) {
      final response = await ApiClient.instance.patch('${ApiConstants.notifications}/$id/read');
      if (response.statusCode >= 200 && response.statusCode < 300 && response.data != null) {
        final notif = NotificationModel.fromJson(response.data!['data'] as Map<String, dynamic>);
        await getUnreadCount();
        return ServiceResult(success: true, data: notif, statusCode: response.statusCode);
      }
      return ServiceResult(
        success: false,
        errorMessage: response.errorMessage ?? 'Failed to mark notification as read',
        statusCode: response.statusCode,
      );
    }

    // DevMock
    final idx = _mockNotifications.indexWhere((n) => n.id == id);
    if (idx != -1) {
      _mockNotifications[idx] = _mockNotifications[idx].copyWith(
        isRead: true,
        readAt: DateTime.now(),
      );
      _recalculateUnread();
      return ServiceResult(success: true, data: _mockNotifications[idx]);
    }

    return const ServiceResult(success: false, errorMessage: 'Notification not found');
  }

  /// Marks all notifications as read.
  Future<ServiceResult<bool>> markAllAsRead() async {
    final mode = SessionManager.instance.authMode;

    if (mode == AuthMode.restBackend) {
      final response = await ApiClient.instance.post(ApiConstants.notificationsMarkAllRead);
      if (response.statusCode >= 200 && response.statusCode < 300) {
        unreadCountNotifier.value = 0;
        return const ServiceResult(success: true, data: true);
      }
      return ServiceResult(
        success: false,
        errorMessage: response.errorMessage ?? 'Failed to mark all as read',
        statusCode: response.statusCode,
      );
    }

    // DevMock
    for (int i = 0; i < _mockNotifications.length; i++) {
      if (!_mockNotifications[i].isRead) {
        _mockNotifications[i] = _mockNotifications[i].copyWith(
          isRead: true,
          readAt: DateTime.now(),
        );
      }
    }
    _recalculateUnread();
    return const ServiceResult(success: true, data: true);
  }

  /// Refreshes the unread count.
  Future<int> getUnreadCount() async {
    final mode = SessionManager.instance.authMode;

    if (mode == AuthMode.restBackend) {
      final response = await ApiClient.instance.get(ApiConstants.notificationsUnread);
      if (response.statusCode >= 200 && response.statusCode < 300 && response.data != null) {
        final count = (response.data!['data']?['unreadCount'] as int?) ?? 0;
        unreadCountNotifier.value = count;
        return count;
      }
    }

    _recalculateUnread();
    return unreadCountNotifier.value;
  }

  void _recalculateUnread() {
    final count = _mockNotifications.where((n) => !n.isRead).length;
    unreadCountNotifier.value = count;
  }

  /// Resets mock notifications state for testing.
  void resetMockData() {
    _mockNotifications.clear();
    _initMockData();
  }
}

