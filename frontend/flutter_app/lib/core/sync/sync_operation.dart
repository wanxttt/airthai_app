import 'dart:convert';

/// Represents a durable, atomic synchronization operation.
class SyncOperation {
  final String id;
  final String clientOperationId;
  final String businessId;
  final String entityType;
  final String entityId;
  final String operation;
  final Map<String, dynamic> payload;
  final String status;
  final int version;
  final int retryCount;
  final String? errorMessage;
  final DateTime createdAt;
  final DateTime? processedAt;

  const SyncOperation({
    required this.id,
    required this.clientOperationId,
    required this.businessId,
    required this.entityType,
    required this.entityId,
    required this.operation,
    required this.payload,
    this.status = 'PENDING',
    this.version = 1,
    this.retryCount = 0,
    this.errorMessage,
    required this.createdAt,
    this.processedAt,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'client_operation_id': clientOperationId,
        'business_id': businessId,
        'entity_type': entityType,
        'entity_id': entityId,
        'operation': operation,
        'payload': jsonEncode(payload),
        'status': status,
        'retry_count': retryCount,
        'error_message': errorMessage,
        'created_at': createdAt.toIso8601String(),
        'processed_at': processedAt?.toIso8601String(),
      };

  factory SyncOperation.fromMap(Map<String, dynamic> map) {
    Map<String, dynamic> parsedPayload = {};
    if (map['payload'] != null) {
      if (map['payload'] is String) {
        try {
          parsedPayload = jsonDecode(map['payload'] as String) as Map<String, dynamic>;
        } catch (_) {
          parsedPayload = {};
        }
      } else if (map['payload'] is Map) {
        parsedPayload = Map<String, dynamic>.from(map['payload'] as Map);
      }
    }

    return SyncOperation(
      id: map['id'] as String,
      clientOperationId: map['client_operation_id'] as String,
      businessId: map['business_id'] as String,
      entityType: map['entity_type'] as String,
      entityId: map['entity_id'] as String,
      operation: map['operation'] as String,
      payload: parsedPayload,
      status: (map['status'] as String?) ?? 'PENDING',
      version: (map['version'] as int?) ?? 1,
      retryCount: (map['retry_count'] as int?) ?? 0,
      errorMessage: map['error_message'] as String?,
      createdAt: DateTime.parse(map['created_at'] as String),
      processedAt: map['processed_at'] != null ? DateTime.parse(map['processed_at'] as String) : null,
    );
  }

  SyncOperation copyWith({
    String? status,
    int? retryCount,
    String? errorMessage,
    DateTime? processedAt,
    Map<String, dynamic>? payload,
  }) {
    return SyncOperation(
      id: id,
      clientOperationId: clientOperationId,
      businessId: businessId,
      entityType: entityType,
      entityId: entityId,
      operation: operation,
      payload: payload ?? this.payload,
      status: status ?? this.status,
      version: version,
      retryCount: retryCount ?? this.retryCount,
      errorMessage: errorMessage ?? this.errorMessage,
      createdAt: createdAt,
      processedAt: processedAt ?? this.processedAt,
    );
  }
}

