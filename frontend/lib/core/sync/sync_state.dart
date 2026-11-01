/// Operational synchronization state machine states (Phase 4O).
enum SyncState {
  /// Engine is resting, no active sync or pending operations.
  idle,

  /// Currently executing upstream synchronization batch.
  syncing,

  /// All outbox operations successfully synchronized with server.
  synced,

  /// Pending operations exist, but waiting for backend reachability.
  waitingForNetwork,

  /// Last synchronization batch encountered an error or reached max retries.
  failed,
}

/// Structured snapshot of the synchronization engine state.
class SyncStatus {
  final SyncState state;
  final int pendingCount;
  final DateTime? lastSyncTime;
  final String? lastError;
  final int inFlightCount;

  const SyncStatus({
    required this.state,
    this.pendingCount = 0,
    this.lastSyncTime,
    this.lastError,
    this.inFlightCount = 0,
  });

  factory SyncStatus.idle({int pendingCount = 0, DateTime? lastSyncTime}) {
    return SyncStatus(
      state: pendingCount > 0 ? SyncState.idle : SyncState.synced,
      pendingCount: pendingCount,
      lastSyncTime: lastSyncTime,
    );
  }

  factory SyncStatus.syncing({int pendingCount = 0, int inFlightCount = 0}) {
    return SyncStatus(
      state: SyncState.syncing,
      pendingCount: pendingCount,
      inFlightCount: inFlightCount,
    );
  }

  factory SyncStatus.synced({DateTime? lastSyncTime}) {
    return SyncStatus(
      state: SyncState.synced,
      pendingCount: 0,
      lastSyncTime: lastSyncTime ?? DateTime.now(),
    );
  }

  factory SyncStatus.waitingForNetwork({int pendingCount = 0}) {
    return SyncStatus(
      state: SyncState.waitingForNetwork,
      pendingCount: pendingCount,
    );
  }

  factory SyncStatus.failed({
    required String error,
    int pendingCount = 0,
    DateTime? lastSyncTime,
  }) {
    return SyncStatus(
      state: SyncState.failed,
      pendingCount: pendingCount,
      lastError: error,
      lastSyncTime: lastSyncTime,
    );
  }

  bool get isSyncing => state == SyncState.syncing;
  bool get isSynced => state == SyncState.synced;
  bool get isWaiting => state == SyncState.waitingForNetwork;
  bool get hasError => state == SyncState.failed;

  @override
  String toString() =>
      'SyncStatus(state: $state, pending: $pendingCount, inFlight: $inFlightCount, error: $lastError)';
}
