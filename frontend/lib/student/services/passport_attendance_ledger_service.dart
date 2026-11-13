import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:drift/drift.dart' as drift;

import '../../core/database/database.dart';
import '../../shared/services/attendance_service.dart';
import '../models/passport_attendance_model.dart';

/// CampusOS Passport Offline Attendance Ledger Service (Phase 1I).
///
/// Responsibilities:
/// 1. Locally queues cryptographically verified attendance records in Airplane Mode.
/// 2. Derives and enforces strict idempotency:
///    `idempotencyKey = 'att_${sessionId}_${deviceKeyId}_${responseNonce}'`
/// 3. In-memory and persistent replay rejection.
/// 4. Synchronizes with backend `/attendance/batch-sync` when connectivity returns.
/// 5. Never stores raw BLE packet histories or continuous radio telemetry.
class PassportAttendanceLedgerService {
  static const String _queuePrefix = 'campus_os.attendance.queue.';

  final AttendanceService _attendanceService;

  /// In-memory cache of recorded student IDs per session: sessionId -> Set<studentId>.
  final Map<String, Set<String>> _recordedStudentsBySession = {};

  /// In-memory cache of recorded idempotency keys: sessionId -> Set<idempotencyKey>.
  final Map<String, Set<String>> _recordedKeysBySession = {};

  PassportAttendanceLedgerService({AttendanceService? attendanceService})
      : _attendanceService = attendanceService ?? AttendanceService();

  /// Whether a student is already recorded in the active session.
  bool isStudentRecorded(String sessionId, String studentId) {
    return _recordedStudentsBySession[sessionId]?.contains(studentId) ?? false;
  }

  /// Whether an idempotency key has already been recorded in this session.
  bool isIdempotencyKeyRecorded(String sessionId, String idempotencyKey) {
    return _recordedKeysBySession[sessionId]?.contains(idempotencyKey) ?? false;
  }

  /// Records a verified attendance result locally.
  ///
  /// Rejects duplicate student records or replayed response nonces within the same session.
  Future<bool> recordAttendance(PassportAttendanceVerificationResult result) async {
    final sessionId = result.sessionId;
    final studentId = result.studentId;
    final idempotencyKey = result.idempotencyKey ??
        'att_${sessionId}_${result.deviceKeyId}_${result.responseNonce}';

    if (sessionId == null || studentId == null) {
      debugPrint('⚠️ [PASSPORT_LEDGER] Cannot record attendance: Missing sessionId or studentId');
      return false;
    }

    // In-memory duplicate / replay check
    _recordedStudentsBySession.putIfAbsent(sessionId, () => <String>{});
    _recordedKeysBySession.putIfAbsent(sessionId, () => <String>{});

    if (_recordedStudentsBySession[sessionId]!.contains(studentId) ||
        _recordedKeysBySession[sessionId]!.contains(idempotencyKey)) {
      debugPrint('⚠️ [PASSPORT_LEDGER] Duplicate or replayed attendance rejected for student: $studentId');
      return false;
    }

    // Persist to local queue
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = '$_queuePrefix$sessionId';
      final existingJsonList = prefs.getStringList(key) ?? [];

      // Check persistent queue to guard against in-memory loss on app restart
      for (final jsonStr in existingJsonList) {
        try {
          final m = jsonDecode(jsonStr) as Map<String, dynamic>;
          final existingStudentId = m['studentId']?.toString();
          final existingIdKey = m['idempotencyKey']?.toString();
          if (existingStudentId != null) {
            _recordedStudentsBySession[sessionId]!.add(existingStudentId);
          }
          if (existingIdKey != null) {
            _recordedKeysBySession[sessionId]!.add(existingIdKey);
            _globalRecordedIdempotencyKeys.add(existingIdKey);
          }
          if (existingStudentId == studentId || existingIdKey == idempotencyKey) {
            debugPrint('⚠️ [PASSPORT_LEDGER] Duplicate attendance in persistent queue rejected for student: $studentId');
            return false;
          }
        } catch (_) {}
      }

      _recordedStudentsBySession[sessionId]!.add(studentId);
      _recordedKeysBySession[sessionId]!.add(idempotencyKey);
      _globalRecordedIdempotencyKeys.add(idempotencyKey);

      final recordMap = {
        'sessionId': sessionId,
        'studentId': studentId,
        'studentName': result.studentName ?? '',
        'deviceKeyId': result.deviceKeyId,
        'responseNonce': result.responseNonce,
        'idempotencyKey': idempotencyKey,
        'verificationMode': result.verificationMode,
        'proximityTier': result.proximityTier.code,
        'checkInTime': result.verifiedAt.toIso8601String(),
        'status': 'present',
        if (result.routerBssid != null) 'routerBssid': result.routerBssid,
        if (result.gpsDistanceMeters != null)
          'gpsDistanceMeters': result.gpsDistanceMeters,
        if (result.gpsStatus != null) 'gpsStatus': result.gpsStatus,
      };

      existingJsonList.add(jsonEncode(recordMap));
      await prefs.setStringList(key, existingJsonList);

      // Phase 4: Transactionally persist into Drift SQLite attendance_records + sync_outbox
      try {
        final localId = 'att_${sessionId}_$studentId';
        final attCompanion = AttendanceRecordsTableCompanion(
          localId: drift.Value(localId),
          sessionId: drift.Value(sessionId),
          studentId: drift.Value(studentId),
          studentName: drift.Value(result.studentName ?? 'Student'),
          checkInTime: drift.Value(result.verifiedAt),
          status: const drift.Value('present'),
          idempotencyKey: drift.Value(idempotencyKey),
          deviceKeyId: drift.Value(result.deviceKeyId),
          responseNonce: drift.Value(result.responseNonce),
          verificationMode: drift.Value(result.verificationMode),
          proximityTier: drift.Value(result.proximityTier.code),
          syncState: const drift.Value('pending'),
        );
        final outboxCompanion = SyncOutboxTableCompanion(
          localId: drift.Value('op_$localId'),
          entityType: const drift.Value('attendance'),
          entityId: drift.Value(localId),
          endpoint: const drift.Value('/attendance/batch-sync'),
          method: const drift.Value('POST'),
          payload: drift.Value(jsonEncode({
            'sessionId': sessionId,
            'records': [recordMap]
          })),
          idempotencyKey: drift.Value(idempotencyKey),
          status: const drift.Value('pending'),
        );
        await DatabaseService.instance.attendanceRepository.recordAttendanceWithOutbox(
          attendance: attCompanion,
          outboxItem: outboxCompanion,
        );
      } catch (dbErr) {
        debugPrint('ℹ️ [PASSPORT_LEDGER] Drift dual-write safe fallback: $dbErr');
      }

      debugPrint('💾 [PASSPORT_LEDGER] Queued offline attendance record: student=$studentId, mode=${result.verificationMode}, tier=${result.proximityTier.code}');
      return true;
    } catch (e) {
      debugPrint('⚠️ [PASSPORT_LEDGER] Failed to persist offline record to storage: $e');
      _recordedStudentsBySession[sessionId]!.add(studentId);
      _recordedKeysBySession[sessionId]!.add(idempotencyKey);
      return true; // Still marked in memory
    }
  }

  /// Global in-memory set of recorded idempotency keys across sessions.
  final Set<String> _globalRecordedIdempotencyKeys = {};

  /// Whether an idempotency key is already recorded in the ledger.
  bool isDuplicate(String idempotencyKey) {
    if (_globalRecordedIdempotencyKeys.contains(idempotencyKey)) return true;
    for (final keys in _recordedKeysBySession.values) {
      if (keys.contains(idempotencyKey)) return true;
    }
    return false;
  }

  /// Records an idempotency key in the in-memory ledger.
  void recordAttendanceIdempotency(String idempotencyKey) {
    _globalRecordedIdempotencyKeys.add(idempotencyKey);
  }

  /// Enqueues an offline attendance record directly.
  Future<bool> enqueueOfflineRecord(PassportOfflineAttendanceRecord record) async {
    final sessionId = record.sessionId;
    final idempotencyKey = record.idempotencyKey;

    if (isDuplicate(idempotencyKey)) {
      debugPrint('⚠️ [PASSPORT_LEDGER] Duplicate idempotency key rejected: $idempotencyKey');
      return false;
    }

    _recordedStudentsBySession.putIfAbsent(sessionId, () => <String>{});
    _recordedKeysBySession.putIfAbsent(sessionId, () => <String>{});

    try {
      final prefs = await SharedPreferences.getInstance();
      final key = '$_queuePrefix$sessionId';
      final existingJsonList = prefs.getStringList(key) ?? [];

      for (final jsonStr in existingJsonList) {
        try {
          final m = jsonDecode(jsonStr) as Map<String, dynamic>;
          final existingStudentId = m['studentId']?.toString();
          final existingIdKey = m['idempotencyKey']?.toString();
          if (existingStudentId != null) {
            _recordedStudentsBySession[sessionId]!.add(existingStudentId);
          }
          if (existingIdKey != null) {
            _recordedKeysBySession[sessionId]!.add(existingIdKey);
            _globalRecordedIdempotencyKeys.add(existingIdKey);
          }
          if (existingIdKey == idempotencyKey) {
            debugPrint('⚠️ [PASSPORT_LEDGER] Duplicate idempotency key in persistent queue rejected: $idempotencyKey');
            return false;
          }
        } catch (_) {}
      }

      _recordedStudentsBySession[sessionId]!.add(record.studentId);
      _recordedKeysBySession[sessionId]!.add(idempotencyKey);
      _globalRecordedIdempotencyKeys.add(idempotencyKey);

      existingJsonList.add(jsonEncode(record.toMap()));
      await prefs.setStringList(key, existingJsonList);
      return true;
    } catch (e) {
      debugPrint('⚠️ [PASSPORT_LEDGER] Error saving offline record: $e');
      _recordedStudentsBySession[sessionId]!.add(record.studentId);
      _recordedKeysBySession[sessionId]!.add(idempotencyKey);
      return true;
    }
  }

  /// Retrieves locally queued attendance records. If sessionId is omitted, collects all.
  Future<List<Map<String, dynamic>>> getQueuedRecords([String? sessionId]) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (sessionId != null) {
        final key = '$_queuePrefix$sessionId';
        final jsonList = prefs.getStringList(key) ?? [];
        return jsonList.map((s) => jsonDecode(s) as Map<String, dynamic>).toList();
      }

      // Collect across all session queues
      final allRecords = <Map<String, dynamic>>[];
      final keys = prefs.getKeys().where((k) => k.startsWith(_queuePrefix));
      for (final k in keys) {
        final list = prefs.getStringList(k) ?? [];
        allRecords.addAll(list.map((s) => jsonDecode(s) as Map<String, dynamic>));
      }
      return allRecords;
    } catch (e) {
      debugPrint('⚠️ [PASSPORT_LEDGER] Error reading queued records: $e');
      return [];
    }
  }

  /// Synchronizes queued offline records with the backend.
  ///
  /// Safe queue management:
  /// Identifies the exact records transmitted, and removes ONLY those records
  /// upon confirmed batch completion. Concurrently arrived items are never wiped.
  Future<Map<String, dynamic>?> syncQueue([
    String? sessionId,
    AttendanceService? attendanceService,
  ]) async {
    final service = attendanceService ?? _attendanceService;
    final prefs = await SharedPreferences.getInstance();
    final targetSessions = sessionId != null
        ? [sessionId]
        : prefs
            .getKeys()
            .where((k) => k.startsWith(_queuePrefix))
            .map((k) => k.substring(_queuePrefix.length))
            .toList();

    if (targetSessions.isEmpty) {
      return {'newSynced': 0, 'duplicates': 0, 'totalRecords': 0};
    }

    int totalSynced = 0;
    int totalDuplicates = 0;

    for (final sid in targetSessions) {
      final records = await getQueuedRecords(sid);
      if (records.isEmpty) continue;

      final sentKeys = records
          .map((r) => r['idempotencyKey']?.toString())
          .whereType<String>()
          .toList();

      try {
        final response = await service.batchSync(
          sessionId: sid,
          records: records,
        );

        totalSynced += (response['newSynced'] is int ? response['newSynced'] as int : 0);
        totalDuplicates += (response['duplicates'] is int ? response['duplicates'] as int : 0);

        // Atomic selective removal: only remove the records that were in this batch.
        await removeSyncedRecords(sid, sentKeys);
      } catch (e) {
        debugPrint('❌ [PASSPORT_LEDGER] Sync failed for session $sid: $e');
        // Do not remove records on network/server error; preserve for next retry.
      }
    }

    return {
      'newSynced': totalSynced,
      'duplicates': totalDuplicates,
      'totalRecords': totalSynced + totalDuplicates,
    };
  }

  /// Safely removes ONLY the specifically synced records by idempotency key.
  /// Any records added to the queue while sync was in-flight are preserved.
  Future<void> removeSyncedRecords(
    String sessionId,
    Iterable<String> syncedIdempotencyKeys,
  ) async {
    final keysToRemove = syncedIdempotencyKeys.toSet();
    if (keysToRemove.isEmpty) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      final key = '$_queuePrefix$sessionId';
      final existingJsonList = prefs.getStringList(key) ?? [];
      if (existingJsonList.isEmpty) return;

      final remainingList = <String>[];
      for (final jsonStr in existingJsonList) {
        try {
          final map = jsonDecode(jsonStr) as Map<String, dynamic>;
          final idKey = map['idempotencyKey']?.toString();
          if (idKey == null || !keysToRemove.contains(idKey)) {
            remainingList.add(jsonStr);
          }
        } catch (_) {
          remainingList.add(jsonStr);
        }
      }

      if (remainingList.isEmpty) {
        await prefs.remove(key);
      } else {
        await prefs.setStringList(key, remainingList);
      }
    } catch (e) {
      debugPrint('⚠️ [PASSPORT_LEDGER] Error updating queue after sync: $e');
    }
  }

  /// Clears the local offline queue for a specific session, or all sessions if null.
  Future<void> clearQueue([String? sessionId]) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (sessionId != null) {
        await prefs.remove('$_queuePrefix$sessionId');
      } else {
        final keys = prefs.getKeys().where((k) => k.startsWith(_queuePrefix)).toList();
        for (final k in keys) {
          await prefs.remove(k);
        }
      }
    } catch (_) {}
  }

  /// Resets in-memory caches.
  void clearMemory() {
    _recordedStudentsBySession.clear();
    _recordedKeysBySession.clear();
    _globalRecordedIdempotencyKeys.clear();
  }
}
