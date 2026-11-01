import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:attendance_app/student/models/passport_attendance_model.dart';
import 'package:attendance_app/student/models/passport_proximity_observation.dart';
import 'package:attendance_app/student/services/passport_attendance_ledger_service.dart';
import 'package:attendance_app/teacher/services/passport_teacher_attendance_service.dart';
import 'package:attendance_app/shared/models/session_model.dart';
import 'package:attendance_app/auth/models/user_model.dart';
import 'package:attendance_app/shared/services/attendance_service.dart';

/// Configurable mock AttendanceService for testing network scenarios
class MockAttendanceSyncService extends AttendanceService {
  bool shouldFail;
  int callCount = 0;
  List<Map<String, dynamic>> lastReceivedRecords = [];

  MockAttendanceSyncService({this.shouldFail = false});

  @override
  Future<Map<String, dynamic>> batchSync({
    required String sessionId,
    required List<Map<String, dynamic>> records,
  }) async {
    callCount++;
    lastReceivedRecords = List.from(records);

    if (shouldFail) {
      throw Exception('Simulated network/backend failure');
    }

    return {
      'status': 'success',
      'sessionId': sessionId,
      'newSynced': records.length,
      'duplicates': 0,
      'totalRecords': records.length,
      'records': records,
    };
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
  });

  group('CampusOS Passport: Offline Attendance Workflow Stabilization Tests', () {
    const testSessionId = 'test-session-uuid-101';
    const student1Id = 'student-uuid-001';
    const student2Id = 'student-uuid-002';
    const student3Id = 'student-uuid-003';

    // -----------------------------------------------------------------------
    // 1. OFFLINE ATTENDANCE PERSISTENCE
    // -----------------------------------------------------------------------
    test('1. Offline attendance records persist to SharedPreferences queue', () async {
      final ledger = PassportAttendanceLedgerService();
      await ledger.clearQueue();

      final res1 = PassportAttendanceVerificationResult(
        valid: true,
        status: PassportAttendanceStatus.verifiedPresent,
        reason: 'Verified present via BLE_BATCH',
        studentId: student1Id,
        studentName: 'Alice Smith',
        deviceKeyId: 'key-alice-01',
        sessionId: testSessionId,
        responseNonce: 'nonce-alice-01',
        idempotencyKey: 'att_${testSessionId}_key-alice-01_nonce-alice-01',
        proximityTier: PassportProximityTier.near,
        verificationMode: 'BLE_BATCH',
        verifiedAt: DateTime.parse('2026-10-01T10:00:00Z'),
      );

      final recorded = await ledger.recordAttendance(res1);
      expect(recorded, isTrue);

      final queue = await ledger.getQueuedRecords(testSessionId);
      expect(queue.length, equals(1));
      expect(queue.first['studentId'], equals(student1Id));
      expect(queue.first['idempotencyKey'], equals(res1.idempotencyKey));
      expect(queue.first['proximityTier'], equals('NEAR'));
      expect(queue.first['verificationMode'], equals('BLE_BATCH'));
    });

    // -----------------------------------------------------------------------
    // 2. QUEUE SERIALIZATION / DESERIALIZATION
    // -----------------------------------------------------------------------
    test('2. Queue serialization & deserialization preserves all required metadata', () async {
      final ledger = PassportAttendanceLedgerService();
      await ledger.clearQueue();

      const record = PassportOfflineAttendanceRecord(
        sessionId: testSessionId,
        studentId: student2Id,
        studentName: 'Bob Jones',
        deviceKeyId: 'key-bob-02',
        responseNonce: 'nonce-bob-02',
        verificationResult: 'VERIFIED_PRESENT',
        timestamp: 1774000000,
        verificationMode: 'QR_FALLBACK',
        proximityTier: 'FALLBACK_VERIFIED',
        idempotencyKey: 'att_${testSessionId}_key-bob-02_nonce-bob-02',
      );

      await ledger.enqueueOfflineRecord(record);

      final prefs = await SharedPreferences.getInstance();
      final rawList = prefs.getStringList('campus_os.attendance.queue.$testSessionId');
      expect(rawList, isNotNull);
      expect(rawList!.length, equals(1));

      final decoded = jsonDecode(rawList.first) as Map<String, dynamic>;
      final restored = PassportOfflineAttendanceRecord.fromMap(decoded);

      expect(restored.sessionId, equals(record.sessionId));
      expect(restored.studentId, equals(record.studentId));
      expect(restored.studentName, equals(record.studentName));
      expect(restored.deviceKeyId, equals(record.deviceKeyId));
      expect(restored.responseNonce, equals(record.responseNonce));
      expect(restored.idempotencyKey, equals(record.idempotencyKey));
      expect(restored.verificationMode, equals('QR_FALLBACK'));
      expect(restored.proximityTier, equals('FALLBACK_VERIFIED'));
    });

    // -----------------------------------------------------------------------
    // 3. APP RESTART / IN-MEMORY RESET PERSISTENCE
    // -----------------------------------------------------------------------
    test('3. App restart survives: new service instance recovers persisted queue & prevents duplicates', () async {
      // Phase A: First run queues student 1
      final ledgerRun1 = PassportAttendanceLedgerService();
      await ledgerRun1.clearQueue();

      final res1 = PassportAttendanceVerificationResult(
        valid: true,
        status: PassportAttendanceStatus.verifiedPresent,
        reason: 'Verified',
        studentId: student1Id,
        studentName: 'Alice Smith',
        deviceKeyId: 'key-alice-01',
        sessionId: testSessionId,
        responseNonce: 'nonce-alice-01',
        idempotencyKey: 'att_${testSessionId}_key-alice-01_nonce-alice-01',
        proximityTier: PassportProximityTier.near,
        verificationMode: 'BLE_BATCH',
        verifiedAt: DateTime.now(),
      );
      await ledgerRun1.recordAttendance(res1);

      // Phase B: Simulate process death / app kill
      // Fresh service instance with completely empty in-memory caches
      final ledgerRun2 = PassportAttendanceLedgerService();

      // Verify persisted records survive in storage
      final queuedAfterRestart = await ledgerRun2.getQueuedRecords(testSessionId);
      expect(queuedAfterRestart.length, equals(1));
      expect(queuedAfterRestart.first['studentId'], equals(student1Id));

      // Attempt to re-record student 1 after restart (replay or repeated BLE packet)
      final duplicateAccepted = await ledgerRun2.recordAttendance(res1);
      expect(duplicateAccepted, isFalse, reason: 'Duplicate after restart must be rejected via persistent check');

      // Verify queue still contains exactly 1 record (no duplicate appended)
      final queueCount = (await ledgerRun2.getQueuedRecords(testSessionId)).length;
      expect(queueCount, equals(1));
    });

    // -----------------------------------------------------------------------
    // 4. CONCURRENT QUEUE SAFETY (RACE CONDITION FIX)
    // -----------------------------------------------------------------------
    test('4. Queue Safety: Item added while batch sync is in-flight is preserved', () async {
      final ledger = PassportAttendanceLedgerService();
      await ledger.clearQueue();

      // Seed student 1 and student 2 in queue
      final res1 = PassportAttendanceVerificationResult(
        valid: true,
        status: PassportAttendanceStatus.verifiedPresent,
        reason: 'Verified',
        studentId: student1Id,
        studentName: 'Student 1',
        deviceKeyId: 'key-1',
        sessionId: testSessionId,
        responseNonce: 'nonce-1',
        idempotencyKey: 'att_${testSessionId}_key-1_nonce-1',
        proximityTier: PassportProximityTier.near,
        verificationMode: 'BLE_BATCH',
        verifiedAt: DateTime.now(),
      );
      final res2 = PassportAttendanceVerificationResult(
        valid: true,
        status: PassportAttendanceStatus.verifiedPresent,
        reason: 'Verified',
        studentId: student2Id,
        studentName: 'Student 2',
        deviceKeyId: 'key-2',
        sessionId: testSessionId,
        responseNonce: 'nonce-2',
        idempotencyKey: 'att_${testSessionId}_key-2_nonce-2',
        proximityTier: PassportProximityTier.near,
        verificationMode: 'BLE_BATCH',
        verifiedAt: DateTime.now(),
      );

      await ledger.recordAttendance(res1);
      await ledger.recordAttendance(res2);

      // Read current batch to send
      final batchToSend = await ledger.getQueuedRecords(testSessionId);
      final sentKeys = batchToSend.map((r) => r['idempotencyKey'] as String).toList();
      expect(sentKeys.length, equals(2));

      // WHILE batchSync is in-flight, a new student (student 3) arrives and is recorded locally
      final res3 = PassportAttendanceVerificationResult(
        valid: true,
        status: PassportAttendanceStatus.verifiedPresent,
        reason: 'Verified',
        studentId: student3Id,
        studentName: 'Student 3 (Late Arrival)',
        deviceKeyId: 'key-3',
        sessionId: testSessionId,
        responseNonce: 'nonce-3',
        idempotencyKey: 'att_${testSessionId}_key-3_nonce-3',
        proximityTier: PassportProximityTier.near,
        verificationMode: 'BLE_BATCH',
        verifiedAt: DateTime.now(),
      );
      await ledger.recordAttendance(res3);

      // batchSync finishes and acknowledged student 1 and student 2
      // Using removeSyncedRecords rather than blind clearQueue:
      await ledger.removeSyncedRecords(testSessionId, sentKeys);

      // Verify student 3 is STILL SAFE in the queue!
      final remainingQueue = await ledger.getQueuedRecords(testSessionId);
      expect(remainingQueue.length, equals(1));
      expect(remainingQueue.first['studentId'], equals(student3Id));
      expect(remainingQueue.first['idempotencyKey'], equals(res3.idempotencyKey));
    });

    // -----------------------------------------------------------------------
    // 5. SUCCESSFUL SYNC
    // -----------------------------------------------------------------------
    test('5. Successful batch sync acknowledges records and clears synced keys', () async {
      final ledger = PassportAttendanceLedgerService();
      await ledger.clearQueue();

      const record1 = PassportOfflineAttendanceRecord(
        sessionId: testSessionId,
        studentId: student1Id,
        deviceKeyId: 'key-1',
        responseNonce: 'nonce-1',
        verificationResult: 'VERIFIED_PRESENT',
        timestamp: 1000,
        verificationMode: 'BLE_BATCH',
        proximityTier: 'NEAR',
        idempotencyKey: 'idem-sync-1',
      );
      await ledger.enqueueOfflineRecord(record1);

      final mockApi = MockAttendanceSyncService(shouldFail: false);
      final syncResult = await ledger.syncQueue(testSessionId, mockApi);

      expect(syncResult, isNotNull);
      expect(syncResult!['newSynced'], equals(1));
      expect(mockApi.callCount, equals(1));

      final remaining = await ledger.getQueuedRecords(testSessionId);
      expect(remaining.isEmpty, isTrue);
    });

    // -----------------------------------------------------------------------
    // 6. FAILED SYNC & RETRY
    // -----------------------------------------------------------------------
    test('6. Network failure preserves queue, subsequent retry succeeds', () async {
      final ledger = PassportAttendanceLedgerService();
      await ledger.clearQueue();

      const record1 = PassportOfflineAttendanceRecord(
        sessionId: testSessionId,
        studentId: student1Id,
        deviceKeyId: 'key-1',
        responseNonce: 'nonce-1',
        verificationResult: 'VERIFIED_PRESENT',
        timestamp: 1000,
        verificationMode: 'BLE_BATCH',
        proximityTier: 'NEAR',
        idempotencyKey: 'idem-retry-1',
      );
      await ledger.enqueueOfflineRecord(record1);

      // Attempt 1: Network failure (offline / timeout)
      final failingApi = MockAttendanceSyncService(shouldFail: true);
      final failedResult = await ledger.syncQueue(testSessionId, failingApi);

      expect(failedResult!['newSynced'], equals(0));
      expect(failingApi.callCount, equals(1));

      // Records must remain safely in storage
      final queueAfterFailure = await ledger.getQueuedRecords(testSessionId);
      expect(queueAfterFailure.length, equals(1));
      expect(queueAfterFailure.first['idempotencyKey'], equals('idem-retry-1'));

      // Attempt 2: Reconnection / retry succeeds
      final workingApi = MockAttendanceSyncService(shouldFail: false);
      final retryResult = await ledger.syncQueue(testSessionId, workingApi);

      expect(retryResult!['newSynced'], equals(1));
      expect(workingApi.callCount, equals(1));

      // After successful retry, queue is cleared
      final queueAfterSuccess = await ledger.getQueuedRecords(testSessionId);
      expect(queueAfterSuccess.isEmpty, isTrue);
    });

    // -----------------------------------------------------------------------
    // 7. DUPLICATE SYNC IDEMPOTENCY
    // -----------------------------------------------------------------------
    test('7. Duplicate sync is idempotent and does not enqueue duplicate records', () async {
      final ledger = PassportAttendanceLedgerService();
      await ledger.clearQueue();

      const record = PassportOfflineAttendanceRecord(
        sessionId: testSessionId,
        studentId: student1Id,
        deviceKeyId: 'key-1',
        responseNonce: 'nonce-1',
        verificationResult: 'VERIFIED_PRESENT',
        timestamp: 1000,
        verificationMode: 'BLE_BATCH',
        proximityTier: 'NEAR',
        idempotencyKey: 'idem-dup-1',
      );

      final firstEnqueue = await ledger.enqueueOfflineRecord(record);
      expect(firstEnqueue, isTrue);

      final secondEnqueue = await ledger.enqueueOfflineRecord(record);
      expect(secondEnqueue, isFalse);

      final queue = await ledger.getQueuedRecords(testSessionId);
      expect(queue.length, equals(1));
    });

    // -----------------------------------------------------------------------
    // 8. UI RESTORATION ACROSS APP RESTART / RESUME
    // -----------------------------------------------------------------------
    test('8. Teacher service restores queued offline results into verifiedResults on resume', () async {
      final ledger = PassportAttendanceLedgerService();
      await ledger.clearQueue();

      // Pre-seed offline queue for the session (as if marked in a prior run before restart)
      final res1 = PassportAttendanceVerificationResult(
        valid: true,
        status: PassportAttendanceStatus.verifiedPresent,
        reason: 'Restored',
        studentId: student1Id,
        studentName: 'Alice Smith',
        deviceKeyId: 'key-alice-01',
        sessionId: testSessionId,
        responseNonce: 'nonce-alice-01',
        idempotencyKey: 'att_${testSessionId}_key-alice-01_nonce-alice-01',
        proximityTier: PassportProximityTier.near,
        verificationMode: 'BLE_BATCH',
        verifiedAt: DateTime.now(),
      );
      await ledger.recordAttendance(res1);

      // Create teacher service (simulating screen reopening)
      final teacherService = PassportTeacherAttendanceService(
        ledgerService: ledger,
      );

      final testSession = SessionModel(
        id: testSessionId,
        name: 'Distributed Systems',
        instructorName: 'Prof. Sharma',
        startTime: DateTime.now(),
        endTime: DateTime.now().add(const Duration(hours: 1)),
        location: 'Room 204',
        isActive: true,
      );
      // restoreQueuedResults restores queued records into _verifiedResults and emits metrics
      await teacherService.restoreQueuedResults(testSessionId);

      expect(teacherService.verifiedResults.containsKey(student1Id), isTrue);
      expect(teacherService.verifiedResults[student1Id]!.studentName, equals('Alice Smith'));
    });
  });
}
