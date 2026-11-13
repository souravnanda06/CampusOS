import 'dart:convert';
import 'dart:math';
import 'package:drift/drift.dart' as drift;
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/database/app_database.dart';
import '../../core/database/database_service.dart';
import '../../core/network/api_client.dart';
import '../../core/network/connectivity_service.dart';
import '../../core/network/connectivity_state.dart';
import '../../core/sync/sync_manager.dart';
import '../models/complaint_model.dart';
import '../models/complaint_history_model.dart';

/// Offline-first Student Complaint Service (Phase 6).
///
/// Implements transactional local persistence, deterministic outbox queuing,
/// stable idempotency key generation, and seamless offline-to-online reconciliation.
class ComplaintService {
  final ApiClient _apiClient;
  final DatabaseService _dbService;
  final ConnectivityService _connectivityService;
  final SyncManager? _syncManager;

  ComplaintService({
    ApiClient? apiClient,
    DatabaseService? dbService,
    ConnectivityService? connectivityService,
    SyncManager? syncManager,
  })  : _apiClient = apiClient ?? ApiClient.instance,
        _dbService = dbService ?? DatabaseService.instance,
        _connectivityService = connectivityService ?? ConnectivityService.instance,
        _syncManager = syncManager;

  static final Map<String, Map<String, dynamic>> _serverComplaintCache = {};
  static bool _cacheHydrated = false;

  static Future<void> _ensureCacheHydrated() async {
    if (_cacheHydrated) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('complaint_server_cache_v1');
      if (raw != null) {
        final decoded = jsonDecode(raw) as Map<String, dynamic>;
        for (final entry in decoded.entries) {
          if (entry.value is Map) {
            _serverComplaintCache[entry.key] =
                Map<String, dynamic>.from(entry.value as Map);
          }
        }
      }
    } catch (_) {}
    _cacheHydrated = true;
  }

  static void _persistCache() {
    SharedPreferences.getInstance().then((prefs) {
      prefs.setString(
          'complaint_server_cache_v1', jsonEncode(_serverComplaintCache));
    }).catchError((_) {});
  }

  static void recordServerComplaint(Map<String, dynamic> data) {
    final id = data['id']?.toString() ?? data['serverId']?.toString() ?? '';
    final localId = data['localId']?.toString();
    final idemKey = data['idempotencyKey']?.toString() ??
        data['idempotency_key']?.toString();
    if (id.isNotEmpty) _serverComplaintCache[id] = data;
    if (localId != null && localId.isNotEmpty) {
      _serverComplaintCache[localId] = data;
    }
    if (idemKey != null && idemKey.isNotEmpty) {
      _serverComplaintCache[idemKey] = data;
    }
    _persistCache();
  }

  /// Submit a new complaint transactionally into local SQLite + outbox (Phase 6C, 6D).
  ///
  /// - Generates stable idempotency key: `complaint_<timestamp>_<random>`
  /// - Atomically inserts local complaint + outbox operation
  /// - Pre-populates Proof-of-Fix OTP so student receives it immediately
  /// - If online: immediately kicks off background SyncManager upload
  /// - Returns ComplaintModel with accurate syncState and closureOtp
  Future<ComplaintModel> createComplaint({
    required String studentId,
    required String category,
    required String title,
    required String description,
    String? location,
    String? priority,
    String? customIdempotencyKey,
  }) async {
    await _ensureCacheHydrated();
    final now = DateTime.now();
    final randomSuffix = '${Random().nextInt(999999)}_${Random().nextInt(999999)}';
    final idempotencyKey = customIdempotencyKey ??
        'complaint_${now.millisecondsSinceEpoch}_$randomSuffix';
    final localId = 'comp_$idempotencyKey';
    final effectiveLocation = location?.trim().isNotEmpty == true ? location!.trim() : 'Campus';
    final effectivePriority = (priority ?? 'MEDIUM').toUpperCase();
    final clientOtp = (1000 + Random().nextInt(9000)).toString();

    // 1. Transactional Creation: Local complaint + Outbox operation (Phase 6C)
    await _dbService.db.transaction(() async {
      // Insert local complaint
      await _dbService.complaintRepository.upsertComplaint(
        ComplaintsTableCompanion.insert(
          localId: localId,
          serverId: const drift.Value.absent(),
          idempotencyKey: drift.Value(idempotencyKey),
          studentId: studentId,
          category: category,
          title: title,
          description: description,
          location: drift.Value(effectiveLocation),
          priority: drift.Value(effectivePriority),
          status: const drift.Value('PENDING'),
          syncState: const drift.Value('pending'),
          createdAt: drift.Value(now),
        ),
      );

      // Insert transactional outbox record with closureOtp
      final payload = jsonEncode({
        'studentId': studentId,
        'category': category,
        'title': title,
        'description': description,
        'location': effectiveLocation,
        'priority': effectivePriority,
        'idempotencyKey': idempotencyKey,
        'closureOtp': clientOtp,
      });

      await _dbService.outboxRepository.enqueue(
        SyncOutboxTableCompanion.insert(
          localId: 'op_$localId',
          entityType: 'complaint',
          entityId: localId,
          endpoint: '/complaints',
          method: const drift.Value('POST'),
          payload: payload,
          idempotencyKey: drift.Value(idempotencyKey),
          status: const drift.Value('pending'),
          createdAt: drift.Value(now),
        ),
      );
    });

    // Pre-record in cache so closureOtp is never null even before server sync
    recordServerComplaint({
      'id': localId,
      'localId': localId,
      'idempotencyKey': idempotencyKey,
      'studentId': studentId,
      'category': category,
      'title': title,
      'description': description,
      'location': effectiveLocation,
      'priority': effectivePriority,
      'status': 'PENDING',
      'syncState': 'pending',
      'createdAt': now.toIso8601String(),
      'closureOtp': clientOtp,
    });

    // 2. Fetch created local complaint
    final localComplaint = await _dbService.complaintRepository.getComplaintByLocalId(localId);
    ComplaintModel complaintModel = ComplaintModel.fromLocal(localComplaint!).copyWith(
      closureOtp: clientOtp,
    );

    // 3. If online or network interface is active, trigger synchronization immediately
    final canAttemptSync = _connectivityService.isOnline ||
        _connectivityService.hasNetworkInterface ||
        _connectivityService.state == ConnectivityState.unknown;
    if (canAttemptSync) {
      try {
        final syncMgr = _syncManager ?? SyncManager.instance;
        await syncMgr.syncNow();
        final refreshed = await _dbService.complaintRepository.getComplaintByLocalId(localId);
        if (refreshed != null) {
          final cached = _serverComplaintCache[refreshed.serverId ?? ''] ??
              _serverComplaintCache[refreshed.localId] ??
              _serverComplaintCache[refreshed.idempotencyKey ?? ''];
          if (cached != null) {
            complaintModel = ComplaintModel.fromMap(cached, refreshed.localId);
            if (complaintModel.closureOtp == null || complaintModel.closureOtp!.isEmpty) {
              complaintModel = complaintModel.copyWith(closureOtp: clientOtp);
            }
          } else {
            complaintModel = ComplaintModel.fromLocal(refreshed).copyWith(
              closureOtp: clientOtp,
            );
          }
        }
      } catch (e) {
        debugPrint("ℹ️ [COMPLAINT_SERVICE] Immediate sync deferred: $e");
      }
    }

    return complaintModel;
  }

  /// Get student's complaints with offline-first local cache fallback (Phase 6H).
  Future<List<ComplaintModel>> getStudentComplaints(
    String studentId, {
    String? requesterId,
    bool forceCacheOnly = false,
  }) async {
    await _ensureCacheHydrated();
    // 1. If online/interface present and not forced cache, refresh from server
    final canFetchServer = !forceCacheOnly &&
        (_connectivityService.isOnline ||
            _connectivityService.hasNetworkInterface ||
            _connectivityService.state == ConnectivityState.unknown);
    if (canFetchServer) {
      try {
        final query = requesterId != null ? '?requesterId=$requesterId' : '';
        final response = await _apiClient.get('/complaints/$studentId$query');

        if (response.statusCode == 200) {
          final List<dynamic> data = jsonDecode(response.body);
          final serverList = data.map((item) {
            final map = Map<String, dynamic>.from(item as Map);
            recordServerComplaint(map);
            return map;
          }).toList();

          // Cache in local SQLite database without clobbering pending offline items
          await _dbService.complaintRepository.cacheServerComplaints(studentId, serverList);
        }
      } catch (e) {
        debugPrint("ℹ️ [COMPLAINT_SERVICE] Server fetch failed, falling back to local cache: $e");
      }
    }

    // 2. Read merged view from local SQLite database enriched with live server metadata (closureOtp, ratings, escalation)
    final localRecords = await _dbService.complaintRepository.getStudentComplaints(studentId);
    return localRecords.map((r) {
      final base = ComplaintModel.fromLocal(r);
      final cached = _serverComplaintCache[r.serverId ?? ''] ??
          _serverComplaintCache[r.localId] ??
          _serverComplaintCache[r.idempotencyKey ?? ''];
      if (cached != null) {
        return ComplaintModel.fromMap(cached, r.localId);
      }
      return base;
    }).toList();
  }

  /// Get single complaint details from cache or server
  Future<ComplaintModel> getComplaint(String id, {String? requesterId}) async {
    await _ensureCacheHydrated();
    final cleanId = id.startsWith('cached_') ? id.substring(7) : id;
    LocalComplaint? local = await _dbService.complaintRepository.getComplaintByServerId(cleanId);
    local ??= await _dbService.complaintRepository.getComplaintByLocalId(id);
    local ??= await _dbService.complaintRepository.getComplaintByLocalId(cleanId);

    final queryId = (local?.serverId != null && local!.serverId!.isNotEmpty)
        ? local.serverId!
        : cleanId;

    // 2. If online/interface present and complaint exists on server, fetch fresh server details
    final canFetchServer = !queryId.startsWith('comp_') &&
        (_connectivityService.isOnline ||
            _connectivityService.hasNetworkInterface ||
            _connectivityService.state == ConnectivityState.unknown);
    if (canFetchServer) {
      try {
        final query = requesterId != null ? '?requesterId=$requesterId' : '';
        final response = await _apiClient.get('/complaints/$queryId$query');

        if (response.statusCode == 200) {
          final Map<String, dynamic> data = jsonDecode(response.body);
          if (local != null) data['localId'] = local.localId;
          recordServerComplaint(data);

          if (local != null) {
            await _dbService.complaintRepository.updateStatusFromServer(
              local.localId,
              data['status']?.toString() ?? local.status,
              resolutionRemarks: data['resolutionRemarks']?.toString() ?? data['resolutionNotes']?.toString(),
              resolvedAt: data['resolvedAt'] != null ? DateTime.tryParse(data['resolvedAt'].toString()) : null,
              assignedTo: data['assignedTo']?.toString(),
              assignedToName: data['assignedToName']?.toString(),
            );
          } else {
            final studentId = data['studentId']?.toString() ?? '';
            await _dbService.complaintRepository.cacheServerComplaints(studentId, [data]);
          }

          // Return server model with full closureOtp and Feature 2 metadata
          return ComplaintModel.fromMap(data, local?.localId);
        }
      } catch (e) {
        debugPrint("ℹ️ [COMPLAINT_SERVICE] getComplaint server fetch failed: $e");
      }
    }

    final cached = _serverComplaintCache[queryId] ??
        _serverComplaintCache[cleanId] ??
        (local != null ? _serverComplaintCache[local.localId] : null) ??
        (local?.idempotencyKey != null ? _serverComplaintCache[local!.idempotencyKey!] : null);

    if (cached != null) {
      return ComplaintModel.fromMap(cached, local?.localId);
    }

    if (local != null) {
      return ComplaintModel.fromLocal(local);
    }
    throw 'Complaint details not available offline';
  }

  /// Get complaint status history timeline
  Future<List<ComplaintHistoryModel>> getComplaintHistory(String id, {String? requesterId}) async {
    await _ensureCacheHydrated();
    final cleanId = id.startsWith('cached_') ? id.substring(7) : id;
    LocalComplaint? local = await _dbService.complaintRepository.getComplaintByServerId(cleanId);
    local ??= await _dbService.complaintRepository.getComplaintByLocalId(id);
    local ??= await _dbService.complaintRepository.getComplaintByLocalId(cleanId);

    final queryId = (local?.serverId != null && local!.serverId!.isNotEmpty)
        ? local.serverId!
        : cleanId;

    if (queryId.startsWith('comp_') && local?.serverId == null) {
      return [
        ComplaintHistoryModel(
          id: 'local_hist_${local?.localId ?? id}',
          complaintId: id,
          changedBy: local?.studentId ?? requesterId ?? '',
          actorName: 'You (Student)',
          actorRole: 'student',
          oldStatus: null,
          newStatus: local?.status ?? 'PENDING',
          remarks: 'Complaint submitted locally',
          timestamp: local?.createdAt ?? DateTime.now(),
        ),
      ];
    }

    final canFetchServer = _connectivityService.isOnline ||
        _connectivityService.hasNetworkInterface ||
        _connectivityService.state == ConnectivityState.unknown;

    if (canFetchServer) {
      try {
        final query = requesterId != null ? '?requesterId=$requesterId' : '';
        final response = await _apiClient.get('/complaints/$queryId/history$query');

        if (response.statusCode == 200) {
          final List<dynamic> data = jsonDecode(response.body);
          final historyList = data
              .map((item) => ComplaintHistoryModel.fromMap(item as Map<String, dynamic>))
              .toList();

          if (historyList.isNotEmpty) {
            return historyList;
          }
        }
      } catch (e) {
        debugPrint("ℹ️ [COMPLAINT_SERVICE] getComplaintHistory error: $e");
      }
    }

    // Fallback: Synthesize initial PENDING submission history if server returned empty or network unavailable
    return [
      ComplaintHistoryModel(
        id: 'fallback_hist_$queryId',
        complaintId: queryId,
        changedBy: local?.studentId ?? requesterId ?? '',
        actorName: 'Student',
        actorRole: 'student',
        oldStatus: null,
        newStatus: local?.status ?? 'PENDING',
        remarks: 'Complaint submitted',
        timestamp: local?.createdAt ?? DateTime.now(),
      ),
    ];
  }

  /// Take action on complaint (requires server connectivity)
  Future<ComplaintModel> takeAction({
    required String complaintId,
    required String actorId,
    required String action,
    String? remarks,
    String? assignedTo,
  }) async {
    final cleanId = complaintId.startsWith('cached_') ? complaintId.substring(7) : complaintId;
    LocalComplaint? local = await _dbService.complaintRepository.getComplaintByServerId(cleanId);
    local ??= await _dbService.complaintRepository.getComplaintByLocalId(complaintId);
    local ??= await _dbService.complaintRepository.getComplaintByLocalId(cleanId);
    final targetId = local?.serverId ?? cleanId;

    if (!_connectivityService.isOnline &&
        (_connectivityService.hasNetworkInterface ||
            _connectivityService.state == ConnectivityState.unknown)) {
      try {
        await _connectivityService.checkReachability();
      } catch (_) {}
    }
    if (!_connectivityService.isOnline) {
      throw 'Cannot perform complaint action while offline. Connection required.';
    }
    try {
      final response = await _apiClient.post(
        '/complaints/$targetId/action',
        body: {
          'actorId': actorId,
          'action': action.toUpperCase(),
          if (remarks != null && remarks.isNotEmpty) 'remarks': remarks,
          if (assignedTo != null && assignedTo.isNotEmpty) 'assignedTo': assignedTo,
        },
      );

      final data = jsonDecode(response.body);
      if (response.statusCode == 200) {
        final updatedModel = ComplaintModel.fromMap(data['complaint']);
        recordServerComplaint(data['complaint']);
        // Update local status as well
        if (local != null) {
          await _dbService.complaintRepository.updateStatusFromServer(
            local.localId,
            updatedModel.status,
            resolutionRemarks: updatedModel.resolutionRemarks,
            resolvedAt: updatedModel.resolvedAt,
            assignedTo: updatedModel.assignedTo,
            assignedToName: updatedModel.assignedToName,
          );
        }
        return updatedModel;
      } else {
        throw data['message'] ?? 'Failed to perform action on complaint';
      }
    } catch (e) {
      debugPrint("❌ [COMPLAINT_SERVICE] takeAction error: $e");
      rethrow;
    }
  }

  /// Feature 2: Dedicated Proof-of-Fix 2-Way OTP Verification & Resolution
  Future<ComplaintModel> verifyResolve({
    required String complaintId,
    required String actorId,
    required String otp,
    required String remarks,
  }) async {
    final cleanId = complaintId.startsWith('cached_') ? complaintId.substring(7) : complaintId;
    LocalComplaint? local = await _dbService.complaintRepository.getComplaintByServerId(cleanId);
    local ??= await _dbService.complaintRepository.getComplaintByLocalId(complaintId);
    local ??= await _dbService.complaintRepository.getComplaintByLocalId(cleanId);
    final targetId = local?.serverId ?? cleanId;

    if (!_connectivityService.isOnline &&
        (_connectivityService.hasNetworkInterface ||
            _connectivityService.state == ConnectivityState.unknown)) {
      try {
        await _connectivityService.checkReachability();
      } catch (_) {}
    }
    if (!_connectivityService.isOnline) {
      throw 'Cannot verify closure OTP while offline. Online connection required.';
    }
    try {
      final response = await _apiClient.post(
        '/complaints/$targetId/verify-resolve',
        body: {
          'actorId': actorId,
          'otp': otp.trim(),
          'remarks': remarks.trim(),
        },
      );

      final data = jsonDecode(response.body);
      if (response.statusCode == 200) {
        final updatedModel = ComplaintModel.fromMap(data['complaint']);
        recordServerComplaint(data['complaint']);
        if (local != null) {
          await _dbService.complaintRepository.updateStatusFromServer(
            local.localId,
            updatedModel.status,
            resolutionRemarks: updatedModel.resolutionRemarks,
            resolvedAt: updatedModel.resolvedAt,
            assignedTo: updatedModel.assignedTo,
            assignedToName: updatedModel.assignedToName,
          );
        }
        return updatedModel;
      } else {
        throw data['message'] ?? 'Failed to verify and resolve complaint';
      }
    } catch (e) {
      debugPrint("❌ [COMPLAINT_SERVICE] verifyResolve error: $e");
      rethrow;
    }
  }

  /// Feature 2: Submit post-resolution student rating (1-5) and feedback
  Future<ComplaintModel> submitFeedback({
    required String complaintId,
    required String studentId,
    required int rating,
    String? feedback,
  }) async {
    final cleanId = complaintId.startsWith('cached_') ? complaintId.substring(7) : complaintId;
    LocalComplaint? local = await _dbService.complaintRepository.getComplaintByServerId(cleanId);
    local ??= await _dbService.complaintRepository.getComplaintByLocalId(complaintId);
    local ??= await _dbService.complaintRepository.getComplaintByLocalId(cleanId);
    final targetId = local?.serverId ?? cleanId;

    if (!_connectivityService.isOnline &&
        (_connectivityService.hasNetworkInterface ||
            _connectivityService.state == ConnectivityState.unknown)) {
      try {
        await _connectivityService.checkReachability();
      } catch (_) {}
    }
    if (!_connectivityService.isOnline) {
      throw 'Cannot submit feedback while offline.';
    }
    try {
      final response = await _apiClient.post(
        '/complaints/$targetId/feedback',
        body: {
          'studentId': studentId,
          'rating': rating,
          if (feedback != null && feedback.trim().isNotEmpty) 'feedback': feedback.trim(),
        },
      );

      final data = jsonDecode(response.body);
      if (response.statusCode == 200) {
        recordServerComplaint(data['complaint']);
        return ComplaintModel.fromMap(data['complaint']);
      } else {
        throw data['message'] ?? 'Failed to submit feedback';
      }
    } catch (e) {
      debugPrint("❌ [COMPLAINT_SERVICE] submitFeedback error: $e");
      rethrow;
    }
  }
}
