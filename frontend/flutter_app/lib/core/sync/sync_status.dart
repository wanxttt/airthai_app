/// Sync state enum representing the operational lifecycle of an entity.
enum SyncState {
  /// Document is a local-only draft not yet submitted to the sync queue.
  localDraft,

  /// Operation is committed locally and enqueued waiting for server sync.
  pending,

  /// Transmission to server is actively in-flight.
  inProgress,

  /// Server has acknowledged and confirmed the transaction with authoritative canonical number.
  synced,

  /// Conflict detected (e.g. concurrent server edit). Data preserved without silent overwrite.
  conflict,

  /// Permanent or retry-exhausted failure requiring user action or manual retry.
  failed;

  String get label {
    switch (this) {
      case SyncState.localDraft:
        return 'Draft';
      case SyncState.pending:
        return 'Pending Sync';
      case SyncState.inProgress:
        return 'Syncing...';
      case SyncState.synced:
        return 'Synced';
      case SyncState.conflict:
        return 'Conflict';
      case SyncState.failed:
        return 'Sync Failed';
    }
  }
}

/// Comprehensive sync status representation for UI visibility and monitoring.
class SyncStatusInfo {
  final bool isOnline;
  final bool isSyncing;
  final int pendingCount;
  final int failedCount;
  final int conflictCount;
  final DateTime? lastSyncTime;
  final String? lastError;

  const SyncStatusInfo({
    this.isOnline = true,
    this.isSyncing = false,
    this.pendingCount = 0,
    this.failedCount = 0,
    this.conflictCount = 0,
    this.lastSyncTime,
    this.lastError,
  });

  bool get hasIssues => failedCount > 0 || conflictCount > 0;
  bool get isFullySynced => pendingCount == 0 && failedCount == 0 && conflictCount == 0;

  SyncStatusInfo copyWith({
    bool? isOnline,
    bool? isSyncing,
    int? pendingCount,
    int? failedCount,
    int? conflictCount,
    DateTime? lastSyncTime,
    String? lastError,
  }) {
    return SyncStatusInfo(
      isOnline: isOnline ?? this.isOnline,
      isSyncing: isSyncing ?? this.isSyncing,
      pendingCount: pendingCount ?? this.pendingCount,
      failedCount: failedCount ?? this.failedCount,
      conflictCount: conflictCount ?? this.conflictCount,
      lastSyncTime: lastSyncTime ?? this.lastSyncTime,
      lastError: lastError,
    );
  }
}

