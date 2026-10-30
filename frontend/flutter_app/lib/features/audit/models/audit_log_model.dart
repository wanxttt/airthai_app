/// Audit Log Model
class AuditLogModel {
  final String id;
  final String action;
  final String entityName;
  final String entityId;
  final String? userId;
  final String? userName;
  final Map<String, dynamic>? oldValues;
  final Map<String, dynamic>? newValues;
  final DateTime timestamp;
  final String? ipAddress;

  const AuditLogModel({
    required this.id,
    required this.action,
    required this.entityName,
    required this.entityId,
    this.userId,
    this.userName,
    this.oldValues,
    this.newValues,
    required this.timestamp,
    this.ipAddress,
  });

  factory AuditLogModel.fromJson(Map<String, dynamic> json) {
    final user = json['user'] as Map<String, dynamic>?;

    return AuditLogModel(
      id: json['id'] as String,
      action: json['action'] as String? ?? 'UNKNOWN',
      entityName: json['entityName'] as String? ?? 'SYSTEM',
      entityId: json['entityId'] as String? ?? '',
      userId: json['userId'] as String?,
      userName: user?['fullName'] as String? ?? user?['email'] as String?,
      oldValues: json['oldValues'] != null ? Map<String, dynamic>.from(json['oldValues'] as Map) : null,
      newValues: json['newValues'] != null ? Map<String, dynamic>.from(json['newValues'] as Map) : null,
      timestamp: json['timestamp'] != null
          ? DateTime.tryParse(json['timestamp'].toString()) ?? DateTime.now()
          : DateTime.now(),
      ipAddress: json['ipAddress'] as String?,
    );
  }
}

