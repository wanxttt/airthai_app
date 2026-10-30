import 'dart:async';
import '../constants/api_constants.dart';
import '../network/api_client.dart';
import '../network/service_result.dart';
import '../security/session_manager.dart';
import '../../features/audit/models/audit_log_model.dart';

/// Central Audit Log Service for AirthAI.
class AuditService {
  AuditService._();
  static final AuditService instance = AuditService._();

  final List<AuditLogModel> _mockLogs = [
    AuditLogModel(
      id: 'log_mock_1',
      action: 'INVOICE_CREATED',
      entityName: 'INVOICE',
      entityId: 'inv_001',
      userName: 'Admin User',
      newValues: {'invoiceNumber': 'INV-2026-27-0001', 'totalAmount': '17700.00'},
      timestamp: DateTime.now().subtract(const Duration(hours: 3)),
    ),
    AuditLogModel(
      id: 'log_mock_2',
      action: 'PAYMENT_RECORDED',
      entityName: 'PAYMENT',
      entityId: 'pay_001',
      userName: 'Admin User',
      newValues: {'paymentNumber': 'REC-2026-27-0001', 'amount': '17700.00'},
      timestamp: DateTime.now().subtract(const Duration(hours: 2)),
    ),
    AuditLogModel(
      id: 'log_mock_3',
      action: 'STOCK_ADJUSTMENT',
      entityName: 'PRODUCT',
      entityId: 'prod_001',
      userName: 'Admin User',
      newValues: {'quantity': 20, 'reason': 'Opening Stock'},
      timestamp: DateTime.now().subtract(const Duration(days: 1)),
    ),
  ];

  /// Retrieves paginated audit logs.
  Future<ServiceResult<List<AuditLogModel>>> getAuditLogs({
    String? entityName,
    String? action,
    int limit = 50,
    int offset = 0,
  }) async {
    final mode = SessionManager.instance.authMode;

    if (mode == AuthMode.restBackend) {
      final queryParams = <String, String>{
        'limit': limit.toString(),
        'offset': offset.toString(),
        if (entityName != null && entityName.isNotEmpty) 'entityName': entityName,
        if (action != null && action.isNotEmpty) 'action': action,
      };

      final response = await ApiClient.instance.get(
        ApiConstants.auditLogs,
        queryParams: queryParams,
      );

      if (response.statusCode >= 200 && response.statusCode < 300 && response.data != null) {
        final data = response.data!['data'] as Map<String, dynamic>;
        final itemsRaw = (data['items'] as List<dynamic>?) ?? [];
        final items = itemsRaw.map((e) => AuditLogModel.fromJson(e as Map<String, dynamic>)).toList();
        return ServiceResult(success: true, data: items, statusCode: response.statusCode);
      }

      return ServiceResult(
        success: false,
        errorMessage: response.errorMessage ?? 'Failed to load audit logs',
        statusCode: response.statusCode,
      );
    }

    // DevMock
    await Future.delayed(const Duration(milliseconds: 50));
    var filtered = _mockLogs;
    if (entityName != null && entityName.isNotEmpty) {
      filtered = filtered.where((l) => l.entityName.toUpperCase() == entityName.toUpperCase()).toList();
    }
    if (action != null && action.isNotEmpty) {
      filtered = filtered.where((l) => l.action.toUpperCase() == action.toUpperCase()).toList();
    }
    return ServiceResult(success: true, data: filtered);
  }
}

