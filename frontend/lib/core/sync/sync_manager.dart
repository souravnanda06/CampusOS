import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:flutter/widgets.dart';

import '../database/database.dart';
import '../network/api_client.dart';
import '../network/connectivity_service.dart';
import '../network/connectivity_state.dart';
import 'sync_state.dart';
import '../../student/services/complaint_service.dart';

/// Central offline-first synchronization engine for CampusOS (Phase 4D).
///
/// Responsibilities:
/// 1. Concurrency Locking: Application-level mutex prevents concurrent overlapping sync runs.
/// 2. In-Flight Recovery: Interrupted operations from crash/kill are safely reset to pending.
/// 3. Deterministic FIFO: Processes operations ordered by `createdAt ASC` in bounded batches.
/// 4. Bounded Exponential Backoff: Transient network/5xx errors back off gracefully up to 60s.
/// 5. Permanent Error Dead-Letter: 4xx validation failures do not block the queue.
/// 6. Transactional Acknowledgement: Server ACKs update local entities & outbox atomically.
/// 7. Partial Batch Handling: Partially acknowledged attendance batches are safely resolved.
/// 8. Session Dependency Ordering: Offline sessions are reconciled before their attendance records.
/// 9. Connectivity & Lifecycle Reactive Triggers: Synchronizes automatically on restoration/resume.
class SyncManager extends ChangeNotifier with WidgetsBindingObserver {
  static SyncManager? _instance;

  final DatabaseService _dbService;
  final ConnectivityService _connectivityService;
  final ApiClient _apiClient;

  final int maxRetries;
  final int baseBackoffSeconds;
  final int maxBackoffSeconds;
  final int batchSize;

  bool _isSyncing = false;
  bool _disposed = false;
  SyncStatus _currentStatus = SyncStatus.idle();
  final StreamController<SyncStatus> _statusController =
      StreamController<SyncStatus>.broadcast();

  StreamSubscription<NetworkStatus>? _connectivitySub;

  SyncManager({
    DatabaseService? dbService,
    ConnectivityService? connectivityService,
    ApiClient? apiClient,
    this.maxRetries = 5,
    this.baseBackoffSeconds = 2,
    this.maxBackoffSeconds = 60,
    this.batchSize = 25,
  })  : _dbService = dbService ?? DatabaseService.instance,
        _connectivityService = connectivityService ?? ConnectivityService.instance,
        _apiClient = apiClient ?? ApiClient.instance;

  /// Global shared singleton instance.
  static SyncManager get instance {
    if (_instance == null) {
      _instance = SyncManager();
      _instance!.init();
    }
    return _instance!;
  }

  /// Explicit initializer with custom configuration.
  static SyncManager initialize({
    DatabaseService? dbService,
    ConnectivityService? connectivityService,
    ApiClient? apiClient,
    int? maxRetries,
    int? baseBackoffSeconds,
    int? maxBackoffSeconds,
    int? batchSize,
  }) {
    _instance?.dispose();
    _instance = SyncManager(
      dbService: dbService,
      connectivityService: connectivityService,
      apiClient: apiClient,
      maxRetries: maxRetries ?? 5,
      baseBackoffSeconds: baseBackoffSeconds ?? 2,
      maxBackoffSeconds: maxBackoffSeconds ?? 60,
      batchSize: batchSize ?? 25,
    );
    _instance!.init();
    return _instance!;
  }

  /// Testing factory for isolated unit tests with mock services.
  factory SyncManager.forTesting({
    required DatabaseService dbService,
    required ConnectivityService connectivityService,
    required ApiClient apiClient,
    int maxRetries = 5,
    int baseBackoffSeconds = 1,
    int maxBackoffSeconds = 10,
    int batchSize = 25,
  }) {
    return SyncManager(
      dbService: dbService,
      connectivityService: connectivityService,
      apiClient: apiClient,
      maxRetries: maxRetries,
      baseBackoffSeconds: baseBackoffSeconds,
      maxBackoffSeconds: maxBackoffSeconds,
      batchSize: batchSize,
    );
  }

  SyncStatus get status => _currentStatus;
  SyncState get state => _currentStatus.state;
  bool get isSyncing => _isSyncing;
  Stream<SyncStatus> get onStatusChanged => _statusController.stream;

  /// Start lifecycle monitoring and network triggers.
  void init() {
    try {
      WidgetsBinding.instance.addObserver(this);
    } catch (_) {
      // Pure unit test environments without Flutter binding
    }

    // 1. Recover any lingering in-flight operations from an earlier app crash
    _dbService.outboxRepository.resetInFlightToPending();

    // 2. Subscribe to connectivity reachability changes
    _connectivitySub = _connectivityService.onStatusChanged.listen((netStatus) {
      if (netStatus.isOnline) {
        // Backend reachability restored: trigger sync
        syncPending();
      } else if (netStatus.isOffline) {
        _updateStatus(SyncStatus.waitingForNetwork(
          pendingCount: _currentStatus.pendingCount,
        ));
      }
    });

    // 3. Initial check
    refreshStatus();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _connectivityService.isOnline) {
      syncPending();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    try {
      WidgetsBinding.instance.removeObserver(this);
    } catch (_) {}
    _connectivitySub?.cancel();
    _statusController.close();
    super.dispose();
  }

  /// Refreshes pending count and status snapshot from the local database.
  Future<SyncStatus> refreshStatus() async {
    if (_disposed) return _currentStatus;
    final pending = await _dbService.outboxRepository.countPending();
    if (_isSyncing) return _currentStatus;

    if (pending == 0) {
      _updateStatus(SyncStatus.synced(lastSyncTime: _currentStatus.lastSyncTime));
    } else if (_connectivityService.isOffline) {
      _updateStatus(SyncStatus.waitingForNetwork(pendingCount: pending));
    } else {
      _updateStatus(SyncStatus.idle(
        pendingCount: pending,
        lastSyncTime: _currentStatus.lastSyncTime,
      ));
    }
    return _currentStatus;
  }

  /// Manually requested or event-triggered sync execution.
  Future<SyncResult> syncNow() => syncPending();

  /// Primary synchronization pipeline (Phase 4D, 4E, 4F).
  Future<SyncResult> syncPending() async {
    if (_disposed) {
      return const SyncResult(
        success: false,
        message: 'SyncManager is disposed',
        syncedCount: 0,
        failedCount: 0,
      );
    }

    // Concurrency Lock: Prevent multiple concurrent sync processes
    if (_isSyncing) {
      return const SyncResult(
        success: false,
        message: 'Sync already in progress',
        syncedCount: 0,
        failedCount: 0,
      );
    }

    // If not actively marked online, attempt reachability check if an interface is present
    // or if status is unverified (unknown) before rejecting.
    if (!_connectivityService.isOnline &&
        (_connectivityService.hasNetworkInterface ||
            _connectivityService.state == ConnectivityState.unknown)) {
      try {
        await _connectivityService.checkReachability();
      } catch (_) {}
    }

    // If still offline, wait for network restoration
    if (!_connectivityService.isOnline) {
      final pending = await _dbService.outboxRepository.countPending();
      _updateStatus(SyncStatus.waitingForNetwork(pendingCount: pending));
      return const SyncResult(
        success: false,
        message: 'Network unreachable. Sync paused.',
        syncedCount: 0,
        failedCount: 0,
      );
    }

    _isSyncing = true;
    int totalSynced = 0;
    int totalFailed = 0;

    try {
      // 1. Recover interrupted in-flight records before processing
      await _dbService.outboxRepository.resetInFlightToPending();

      final pendingCount = await _dbService.outboxRepository.countPending();
      _updateStatus(SyncStatus.syncing(pendingCount: pendingCount));

      // 2. Fetch candidate operations in FIFO order
      final operations = await _dbService.outboxRepository.peekPending(limit: batchSize);
      if (operations.isEmpty) {
        _updateStatus(SyncStatus.synced());
        return const SyncResult(
          success: true,
          message: 'Outbox is empty',
          syncedCount: 0,
          failedCount: 0,
        );
      }

      final now = DateTime.now();

      // Separate into Sessions, Attendance, and Complaints (Phase 6G)
      final sessionOps = <LocalOutboxOperation>[];
      final attendanceOps = <LocalOutboxOperation>[];
      final complaintOps = <LocalOutboxOperation>[];

      for (final op in operations) {
        // Evaluate backoff delay
        if (op.attemptCount > 0 && op.lastAttemptedAt != null) {
          final backoffSecs = min(
            maxBackoffSeconds,
            baseBackoffSeconds * pow(2, op.attemptCount - 1).toInt(),
          );
          final nextRetry = op.lastAttemptedAt!.add(Duration(seconds: backoffSecs));
          if (now.isBefore(nextRetry)) {
            // Not yet eligible for retry
            continue;
          }
        }

        // Check if exceeded max retries -> permanent failure (dead-letter)
        if (op.attemptCount >= maxRetries) {
          await _dbService.outboxRepository.markPermanentFailure(
            op.localId,
            'Exceeded maximum retry limit ($maxRetries)',
          );
          totalFailed++;
          continue;
        }

        if (op.entityType == 'session') {
          sessionOps.add(op);
        } else if (op.entityType == 'attendance') {
          attendanceOps.add(op);
        } else if (op.entityType == 'complaint') {
          complaintOps.add(op);
        }
      }

      // Step A: Process Session operations first (FIFO)
      for (final op in sessionOps) {
        final success = await _processSessionOperation(op);
        if (success) {
          totalSynced++;
        } else {
          totalFailed++;
        }
      }

      // Step B: Process Attendance operations in session batches
      if (attendanceOps.isNotEmpty) {
        final attendanceBatchResult = await _processAttendanceBatch(attendanceOps);
        totalSynced += attendanceBatchResult.syncedCount;
        totalFailed += attendanceBatchResult.failedCount;
      }

      // Step C: Process Complaint operations (FIFO, Phase 6G)
      for (final op in complaintOps) {
        final success = await _processComplaintOperation(op);
        if (success) {
          totalSynced++;
        } else {
          totalFailed++;
        }
      }

      final remaining = await _dbService.outboxRepository.countPending();
      if (remaining == 0) {
        _updateStatus(SyncStatus.synced());
      } else {
        _updateStatus(SyncStatus.idle(
          pendingCount: remaining,
          lastSyncTime: DateTime.now(),
        ));
      }

      return SyncResult(
        success: totalFailed == 0,
        message: 'Synchronized $totalSynced items ($totalFailed deferred/failed)',
        syncedCount: totalSynced,
        failedCount: totalFailed,
      );
    } catch (e) {
      _updateStatus(SyncStatus.failed(
        error: e.toString(),
        pendingCount: await _dbService.outboxRepository.countPending(),
      ));
      return SyncResult(
        success: false,
        message: 'Sync loop exception: $e',
        syncedCount: totalSynced,
        failedCount: totalFailed,
      );
    } finally {
      _isSyncing = false;
    }
  }

  /// Processes an offline session reconciliation operation.
  Future<bool> _processSessionOperation(LocalOutboxOperation op) async {
    await _dbService.outboxRepository.markInFlight(op.localId);

    try {
      final payloadMap = jsonDecode(op.payload) as Map<String, dynamic>;
      final localSessionId = op.entityId;

      final res = await _apiClient.post(
        op.endpoint,
        body: payloadMap,
      );

      if (res.statusCode == 200 || res.statusCode == 201) {
        final resData = jsonDecode(res.body) as Map<String, dynamic>;
        final serverSessionId = (resData['id'] ??
                (resData['session'] is Map ? resData['session']['id'] : null))
            ?.toString();

        if (serverSessionId != null && serverSessionId.isNotEmpty) {
          // Transactional server acknowledgement (Phase 4M)
          await _dbService.db.transaction(() async {
            // Update local session
            await _dbService.sessionRepository.updateSyncState(
              localSessionId,
              'synced',
              serverId: serverSessionId,
            );
            // Mark outbox operation completed
            await _dbService.outboxRepository.markCompleted(op.localId);
          });
          return true;
        }
      }

      // Permanent 4xx error (e.g. 400 Bad Request, 401 Unauthorized)
      if (res.statusCode >= 400 && res.statusCode < 500) {
        await _dbService.outboxRepository.markPermanentFailure(
          op.localId,
          'HTTP ${res.statusCode}: ${res.body}',
        );
        return false;
      }

      // Transient 5xx error
      await _dbService.outboxRepository.markFailed(
        op.localId,
        'Server error (HTTP ${res.statusCode})',
      );
      return false;
    } catch (e) {
      if (_isTransientNetworkError(e)) {
        await _dbService.outboxRepository.markFailed(op.localId, e.toString());
      } else {
        await _dbService.outboxRepository.markPermanentFailure(op.localId, e.toString());
      }
      return false;
    }
  }

  /// Processes an offline student complaint submission operation (Phase 6G).
  Future<bool> _processComplaintOperation(LocalOutboxOperation op) async {
    await _dbService.outboxRepository.markInFlight(op.localId);

    try {
      final payloadMap = jsonDecode(op.payload) as Map<String, dynamic>;
      final localComplaintId = op.entityId;

      final res = await _apiClient.post(
        op.endpoint,
        body: payloadMap,
      );

      if (res.statusCode == 200 || res.statusCode == 201) {
        final resData = jsonDecode(res.body) as Map<String, dynamic>;
        final complaintData = (resData['complaint'] is Map)
            ? resData['complaint'] as Map<String, dynamic>
            : resData;
        final serverComplaintId = complaintData['id']?.toString();
        final serverCreatedAtStr = complaintData['createdAt']?.toString();
        final serverCreatedAt = serverCreatedAtStr != null
            ? DateTime.tryParse(serverCreatedAtStr)
            : null;

        if (serverComplaintId != null && serverComplaintId.isNotEmpty) {
          complaintData['localId'] = localComplaintId;
          ComplaintService.recordServerComplaint(complaintData);
          // Transactional server acknowledgement
          await _dbService.db.transaction(() async {
            // Update local complaint syncState to synced & attach server ID
            await _dbService.complaintRepository.updateSyncState(
              localComplaintId,
              'synced',
              serverId: serverComplaintId,
              serverCreatedAt: serverCreatedAt,
            );
            // Mark outbox operation completed
            await _dbService.outboxRepository.markCompleted(op.localId);
          });
          return true;
        }
      }

      // Permanent 4xx error (e.g. 400 Bad Request, 403 Forbidden, 404 Not Found)
      if (res.statusCode >= 400 && res.statusCode < 500) {
        await _dbService.db.transaction(() async {
          await _dbService.outboxRepository.markPermanentFailure(
            op.localId,
            'HTTP ${res.statusCode}: ${res.body}',
          );
          await _dbService.complaintRepository.updateSyncState(
            op.entityId,
            'failed',
          );
        });
        return false;
      }

      // Transient 5xx error
      await _dbService.outboxRepository.markFailed(
        op.localId,
        'Server error (HTTP ${res.statusCode})',
      );
      return false;
    } catch (e) {
      if (_isTransientNetworkError(e)) {
        await _dbService.outboxRepository.markFailed(op.localId, e.toString());
      } else {
        await _dbService.db.transaction(() async {
          await _dbService.outboxRepository.markPermanentFailure(op.localId, e.toString());
          await _dbService.complaintRepository.updateSyncState(op.entityId, 'failed');
        });
      }
      return false;
    }
  }

  /// Processes attendance records grouped by session into `/attendance/batch-sync` calls.
  Future<SyncResult> _processAttendanceBatch(List<LocalOutboxOperation> ops) async {
    int synced = 0;
    int failed = 0;

    // Group outbox operations by sessionId
    final opsBySession = <String, List<LocalOutboxOperation>>{};
    for (final op in ops) {
      try {
        final data = jsonDecode(op.payload) as Map<String, dynamic>;
        final sId = data['sessionId']?.toString() ?? '';
        if (sId.isNotEmpty) {
          opsBySession.putIfAbsent(sId, () => []).add(op);
        }
      } catch (_) {
        await _dbService.outboxRepository.markPermanentFailure(
          op.localId,
          'Malformed payload JSON',
        );
        failed++;
      }
    }

    for (final entry in opsBySession.entries) {
      final localSessionId = entry.key;
      final sessionOps = entry.value;

      // Mark this batch in_flight
      for (final op in sessionOps) {
        await _dbService.outboxRepository.markInFlight(op.localId);
      }

      // Resolve server session ID: if local session has serverId, use it!
      final localSession = await _dbService.sessionRepository.getSessionByLocalId(localSessionId);
      final resolvedSessionId = localSession?.serverId ?? localSessionId;

      // Flatten attendance records from operations
      final List<Map<String, dynamic>> recordsPayload = [];
      final Map<String, LocalOutboxOperation> opByKey = {};

      for (final op in sessionOps) {
        try {
          final data = jsonDecode(op.payload) as Map<String, dynamic>;
          final recordsList = data['records'] as List?;
          if (recordsList != null && recordsList.isNotEmpty) {
            for (final r in recordsList) {
              final recMap = Map<String, dynamic>.from(r as Map);
              final idKey = recMap['idempotencyKey']?.toString() ?? op.idempotencyKey ?? '';
              recordsPayload.add(recMap);
              if (idKey.isNotEmpty) {
                opByKey[idKey] = op;
              }
            }
          } else if (data.containsKey('studentId') || data.containsKey('userId')) {
            final idKey = data['idempotencyKey']?.toString() ?? op.idempotencyKey ?? '';
            recordsPayload.add(data);
            if (idKey.isNotEmpty) {
              opByKey[idKey] = op;
            }
          }
        } catch (_) {}
      }

      if (recordsPayload.isEmpty) continue;

      try {
        final res = await _apiClient.post(
          '/attendance/batch-sync',
          body: {
            'sessionId': resolvedSessionId,
            'records': recordsPayload,
          },
        );

        if (res.statusCode == 200) {
          final resData = jsonDecode(res.body) as Map<String, dynamic>;
          final serverRecords = resData['records'] as List? ?? [];

          // Set of acknowledged idempotency keys from server response
          final ackedKeys = <String>{};
          for (final sr in serverRecords) {
            final key = sr['idempotencyKey']?.toString() ?? sr['idempotency_key']?.toString();
            if (key != null && key.isNotEmpty) {
              ackedKeys.add(key);
            }
          }

          // Transactional acknowledgement for acknowledged records (Phase 4M, 4N)
          final opsToComplete = <String, LocalOutboxOperation>{};
          final attKeysToSync = <String>{};

          for (final entryKey in opByKey.entries) {
            if (ackedKeys.contains(entryKey.key)) {
              opsToComplete[entryKey.value.localId] = entryKey.value;
              attKeysToSync.add(entryKey.key);
            }
          }

          await _dbService.db.transaction(() async {
            for (final op in opsToComplete.values) {
              await _dbService.outboxRepository.markCompleted(op.localId);
            }
            for (final key in attKeysToSync) {
              final att = await _dbService.attendanceRepository.getAttendanceByIdempotencyKey(key);
              if (att != null) {
                await _dbService.attendanceRepository.updateSyncState(att.localId, 'synced');
              }
            }
          });

          synced += opsToComplete.length;

          // Partial batch result handling (Phase 4N):
          // Any records in this batch that were NOT acknowledged remain pending for retry
          for (final entryKey in opByKey.entries) {
            if (!ackedKeys.contains(entryKey.key) && !opsToComplete.containsKey(entryKey.value.localId)) {
              await _dbService.outboxRepository.markFailed(
                entryKey.value.localId,
                'Partial batch unacknowledged by server',
              );
              failed++;
            }
          }
        } else if (res.statusCode >= 400 && res.statusCode < 500) {
          // Permanent client error (e.g. 404 Session Not Found or 400 Validation)
          for (final op in sessionOps) {
            await _dbService.outboxRepository.markPermanentFailure(
              op.localId,
              'HTTP ${res.statusCode}: ${res.body}',
            );
            failed++;
          }
        } else {
          // Transient 5xx server error
          for (final op in sessionOps) {
            await _dbService.outboxRepository.markFailed(
              op.localId,
              'Server error (HTTP ${res.statusCode})',
            );
            failed++;
          }
        }
      } catch (e) {
        for (final op in sessionOps) {
          if (_isTransientNetworkError(e)) {
            await _dbService.outboxRepository.markFailed(op.localId, e.toString());
          } else {
            await _dbService.outboxRepository.markPermanentFailure(op.localId, e.toString());
          }
          failed++;
        }
      }
    }

    return SyncResult(
      success: failed == 0,
      message: 'Batch completed: $synced synced, $failed deferred',
      syncedCount: synced,
      failedCount: failed,
    );
  }

  /// Categorizes an exception as transient (retryable) vs permanent (dead-letter).
  bool _isTransientNetworkError(Object error) {
    if (error is SocketException ||
        error is TimeoutException ||
        error is HttpException) {
      return true;
    }
    final msg = error.toString().toLowerCase();
    return msg.contains('socket') ||
        msg.contains('timeout') ||
        msg.contains('timed out') ||
        msg.contains('time out') ||
        msg.contains('connection refused') ||
        msg.contains('network') ||
        msg.contains('handshake');
  }

  void _updateStatus(SyncStatus newStatus) {
    _currentStatus = newStatus;
    if (!_statusController.isClosed) {
      _statusController.add(newStatus);
    }
    notifyListeners();
  }
}

/// Result returned by an explicit or automatic synchronization run.
class SyncResult {
  final bool success;
  final String message;
  final int syncedCount;
  final int failedCount;

  const SyncResult({
    required this.success,
    required this.message,
    required this.syncedCount,
    required this.failedCount,
  });

  @override
  String toString() =>
      'SyncResult(success: $success, synced: $syncedCount, failed: $failedCount, message: $message)';
}
