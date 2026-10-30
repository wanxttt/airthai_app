import 'dart:async';
import 'package:flutter/foundation.dart';
import '../network/api_client.dart';
import '../network/connectivity_service.dart';
import '../security/session_manager.dart';
import 'sync_queue.dart';
import 'sync_repository.dart';
import 'sync_status.dart';

/// Result summary of a synchronization run.
class SyncResult {
  final bool success;
  final int syncedCount;
  final int conflictCount;
  final int failedCount;
  final String? errorMessage;

  const SyncResult({
    required this.success,
    this.syncedCount = 0,
    this.conflictCount = 0,
    this.failedCount = 0,
    this.errorMessage,
  });
}

/// Central synchronization orchestrator for reliable offline-first processing.
///
/// Implements:
/// - Reactive trigger on connectivity restoration
/// - Idempotent server dispatch via stable clientOperationId
/// - Bounded retries with exponential backoff
/// - Optimistic conflict detection and data preservation
/// - Real-time UI sync status monitoring via ValueNotifier
class SyncManager {
  SyncManager._() {
    _initConnectivityListener();
  }
  static final SyncManager instance = SyncManager._();

  final ValueNotifier<SyncStatusInfo> statusNotifier = ValueNotifier<SyncStatusInfo>(
    const SyncStatusInfo(),
  );

  StreamSubscription<bool>? _connectivitySubscription;
  bool _isSyncing = false;

  void _initConnectivityListener() {
    _connectivitySubscription = ConnectivityService.instance.onConnectivityChanged.listen((isOnline) {
      statusNotifier.value = statusNotifier.value.copyWith(isOnline: isOnline);
      if (isOnline) {
        // Automatically synchronize when network connectivity is restored
        syncNow();
      }
    });
  }

  /// Triggers an immediate synchronization run.
  Future<SyncResult> syncNow({String? businessId}) async {
    if (_isSyncing) {
      return const SyncResult(success: false, errorMessage: 'Sync already in progress');
    }

    final activeBizId = businessId ?? SessionManager.instance.currentUser?.businessId ?? 'default_biz';
    final isOnline = ConnectivityService.instance.isOnline;

    if (!isOnline) {
      await _refreshCounts(activeBizId, isOnline: false);
      return const SyncResult(success: false, errorMessage: 'Device is offline');
    }

    _isSyncing = true;
    statusNotifier.value = statusNotifier.value.copyWith(isSyncing: true);

    int syncedCount = 0;
    int conflictCount = 0;
    int failedCount = 0;

    try {
      final pendingOps = await SyncQueue.instance.getPendingOperations(businessId: activeBizId);

      if (pendingOps.isEmpty) {
        _isSyncing = false;
        await _refreshCounts(activeBizId, isOnline: true);
        return const SyncResult(success: true);
      }

      // Mark in progress
      for (final op in pendingOps) {
        await SyncQueue.instance.markInProgress(op.clientOperationId);
      }

      // Build batch payload for NestJS /api/v1/sync/batch
      final batchPayload = {
        'operations': pendingOps.map((op) => {
          'clientOperationId': op.clientOperationId,
          'entityType': op.entityType,
          'operation': op.operation,
          'entityId': op.entityId,
          'version': op.version,
          'payload': op.payload,
        }).toList(),
      };

      // In devMock / mock mode or restBackend mode:
      final authMode = SessionManager.instance.authMode;
      if (authMode == AuthMode.restBackend) {
        final res = await ApiClient.instance.post(
          '/api/v1/sync/batch',
          body: batchPayload,
        );

        if (res.statusCode >= 200 && res.statusCode < 300 && res.data != null) {
          final ackList = (res.data!['data'] as List<dynamic>?) ?? [];
          final ackMap = <String, Map<String, dynamic>>{};
          for (final item in ackList) {
            if (item is Map<String, dynamic>) {
              ackMap[item['clientOperationId']?.toString() ?? ''] = item;
            }
          }

          for (final op in pendingOps) {
            final ack = ackMap[op.clientOperationId];
            if (ack != null) {
              final status = ack['status']?.toString();
              if (status == 'ACKNOWLEDGED') {
                await SyncRepository.instance.applyServerAcknowledgement(op, ack);
                await SyncQueue.instance.markCompleted(op.clientOperationId, ackData: ack);
                syncedCount++;
              } else if (status == 'CONFLICT') {
                await SyncRepository.instance.applyConflict(op, ack);
                await SyncQueue.instance.markConflict(op.clientOperationId, ack['errorMessage']?.toString() ?? 'Conflict');
                conflictCount++;
              } else {
                await SyncQueue.instance.markFailed(
                  op.clientOperationId,
                  ack['errorMessage']?.toString() ?? 'Server rejected operation',
                  canRetry: ack['retryable'] ?? false,
                );
                failedCount++;
              }
            } else {
              await SyncQueue.instance.markFailed(op.clientOperationId, 'No acknowledgement received');
              failedCount++;
            }
          }
        } else {
          // Network error or 5xx server failure: apply bounded exponential retry
          for (final op in pendingOps) {
            await SyncQueue.instance.markFailed(
              op.clientOperationId,
              res.errorMessage ?? 'Network dispatch failed',
              canRetry: true,
            );
            failedCount++;
          }
        }
      } else {
        // DevMock / Local Simulation: Acknowledge successfully with canonical numbers
        for (final op in pendingOps) {
          final fakeCanonicalNumber = _generateMockCanonicalNumber(op.entityType);
          final ack = {
            'clientOperationId': op.clientOperationId,
            'status': 'ACKNOWLEDGED',
            'serverEntityId': 'server_${op.entityId}',
            'canonicalDocumentNumber': fakeCanonicalNumber,
            'serverVersion': op.version,
            'data': op.payload,
          };
          await SyncRepository.instance.applyServerAcknowledgement(op, ack);
          await SyncQueue.instance.markCompleted(op.clientOperationId, ackData: ack);
          syncedCount++;
        }
      }

      await _refreshCounts(activeBizId, isOnline: true);
      return SyncResult(
        success: failedCount == 0 && conflictCount == 0,
        syncedCount: syncedCount,
        conflictCount: conflictCount,
        failedCount: failedCount,
      );
    } catch (e) {
      statusNotifier.value = statusNotifier.value.copyWith(
        isSyncing: false,
        lastError: e.toString(),
      );
      return SyncResult(success: false, errorMessage: e.toString());
    } finally {
      _isSyncing = false;
      statusNotifier.value = statusNotifier.value.copyWith(isSyncing: false);
    }
  }

  /// Retries a single failed operation.
  Future<void> retryOperation(String clientOperationId) async {
    await SyncQueue.instance.retryOperation(clientOperationId);
    await syncNow();
  }

  /// Retries all failed operations for the tenant.
  Future<void> retryAllFailed() async {
    final activeBizId = SessionManager.instance.currentUser?.businessId ?? 'default_biz';
    await SyncQueue.instance.retryAllFailed(activeBizId);
    await syncNow();
  }

  /// Refreshes queue counts in the status notifier.
  Future<void> _refreshCounts(String businessId, {required bool isOnline}) async {
    final pending = await SyncQueue.instance.getPendingCount(businessId);
    final failed = await SyncQueue.instance.getFailedCount(businessId);
    final conflict = await SyncQueue.instance.getConflictCount(businessId);

    statusNotifier.value = statusNotifier.value.copyWith(
      isOnline: isOnline,
      isSyncing: _isSyncing,
      pendingCount: pending,
      failedCount: failed,
      conflictCount: conflict,
      lastSyncTime: DateTime.now(),
      lastError: null,
    );
  }

  /// Resets sync manager state and pending subscriptions.
  Future<void> reset() async {
    _isSyncing = false;
    statusNotifier.value = const SyncStatusInfo();
  }

  void dispose() {
    _connectivitySubscription?.cancel();
  }

  String _generateMockCanonicalNumber(String entityType) {
    final hex = DateTime.now().millisecondsSinceEpoch.toRadixString(16).substring(4).toUpperCase();
    switch (entityType.toUpperCase()) {
      case 'INVOICE':
        return 'INV-2026-27-$hex';
      case 'PURCHASE':
        return 'PUR-2026-27-$hex';
      case 'PAYMENT':
        return 'PAY-2026-27-$hex';
      case 'EXPENSE':
        return 'EXP-2026-27-$hex';
      default:
        return 'DOC-$hex';
    }
  }
}
