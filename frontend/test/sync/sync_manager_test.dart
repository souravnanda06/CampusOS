import 'dart:async';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:drift/drift.dart' as drift;
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'package:attendance_app/core/database/database.dart';
import 'package:attendance_app/core/network/api_client.dart';
import 'package:attendance_app/core/network/connectivity_service.dart';
import 'package:attendance_app/core/sync/sync_state.dart';
import 'package:attendance_app/core/sync/sync_manager.dart';
import 'package:attendance_app/core/sync/shared_preferences_migration_bridge.dart';

/// Controllable Fake Connectivity for unit tests.
class FakeConnectivity implements Connectivity {
  List<ConnectivityResult> _current;
  final StreamController<List<ConnectivityResult>> _controller =
      StreamController<List<ConnectivityResult>>.broadcast();

  FakeConnectivity(this._current);

  void emit(List<ConnectivityResult> results) {
    _current = results;
    _controller.add(results);
  }

  @override
  Future<List<ConnectivityResult>> checkConnectivity() async => _current;

  @override
  Stream<List<ConnectivityResult>> get onConnectivityChanged =>
      _controller.stream;

  void dispose() => _controller.close();
}

/// Controllable Fake HTTP Client for unit tests.
class FakeHttpClient extends http.BaseClient {
  Future<http.Response> Function(http.BaseRequest request)? handler;

  FakeHttpClient([this.handler]);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    if (handler != null) {
      final response = await handler!(request);
      return http.StreamedResponse(
        Stream.value(response.bodyBytes),
        response.statusCode,
        headers: response.headers,
      );
    }
    return http.StreamedResponse(
      Stream.value(utf8.encode('{"status":"ok"}')),
      200,
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late DatabaseService dbService;
  late FakeConnectivity fakeConnectivity;
  late FakeHttpClient fakeHttpClient;
  late ConnectivityService connectivityService;
  late ApiClient apiClient;
  late SyncManager syncManager;

  setUpAll(() {
    drift.driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    db = AppDatabase.inMemory();
    dbService = DatabaseService.forTesting(db);

    fakeConnectivity = FakeConnectivity([ConnectivityResult.wifi]);
    fakeHttpClient = FakeHttpClient((req) async {
      if (req.url.path == '/health') {
        return http.Response(jsonEncode({'status': 'healthy'}), 200);
      }
      return http.Response(jsonEncode({'status': 'ok'}), 200);
    });

    connectivityService = ConnectivityService.forTesting(
      connectivity: fakeConnectivity,
      httpClient: fakeHttpClient,
      baseUrl: 'http://127.0.0.1:5000',
    );
    await connectivityService.checkReachability();

    apiClient = ApiClient(
      baseUrl: 'http://127.0.0.1:5000',
      client: fakeHttpClient,
      defaultTimeout: const Duration(seconds: 2),
    );

    syncManager = SyncManager.forTesting(
      dbService: dbService,
      connectivityService: connectivityService,
      apiClient: apiClient,
      maxRetries: 3,
      baseBackoffSeconds: 1,
      maxBackoffSeconds: 5,
    );
  });

  tearDown(() async {
    syncManager.dispose();
    connectivityService.dispose();
    fakeConnectivity.dispose();
    await dbService.close();
  });

  Future<void> ensureStudent(String id, String name) async {
    await db.into(db.studentsTable).insert(
      StudentsTableCompanion(
        studentId: drift.Value(id),
        name: drift.Value(name),
        rollNumber: drift.Value(id),
      ),
      mode: drift.InsertMode.insertOrIgnore,
    );
  }

  group('Phase 4S — Synchronization Engine & Outbox Lifecycle', () {
    test('1. Empty outbox does nothing', () async {
      final result = await syncManager.syncNow();
      expect(result.success, isTrue);
      expect(result.syncedCount, equals(0));
      expect(syncManager.status.isSynced, isTrue);
      expect(syncManager.status.pendingCount, equals(0));
    });

    test('2. Pending operation syncs successfully', () async {
      await ensureStudent('std_1', 'Alice');

      // Setup test session and attendance outbox item
      await dbService.sessionRepository.upsertSession(
        SessionsTableCompanion.insert(
          localId: 'sess_1',
          teacherId: 'teacher_1',
          name: 'CS101 Lecture',
          startTime: DateTime.now(),
          endTime: DateTime.now().add(const Duration(hours: 1)),
          location: const drift.Value('Hall A'),
          syncState: const drift.Value('synced'),
        ),
      );

      final attCompanion = AttendanceRecordsTableCompanion.insert(
        localId: 'att_1',
        sessionId: 'sess_1',
        studentId: 'std_1',
        studentName: 'Alice',
        checkInTime: DateTime.now(),
        idempotencyKey: 'key_att_1',
        syncState: const drift.Value('pending'),
      );

      final outboxCompanion = SyncOutboxTableCompanion.insert(
        localId: 'op_att_1',
        entityType: 'attendance',
        entityId: 'att_1',
        endpoint: '/attendance/batch-sync',
        method: const drift.Value('POST'),
        payload: jsonEncode({
          'sessionId': 'sess_1',
          'records': [
            {
              'studentId': 'std_1',
              'studentName': 'Alice',
              'idempotencyKey': 'key_att_1',
            }
          ]
        }),
        idempotencyKey: const drift.Value('key_att_1'),
        status: const drift.Value('pending'),
      );

      await dbService.attendanceRepository.recordAttendanceWithOutbox(
        attendance: attCompanion,
        outboxItem: outboxCompanion,
      );

      // Mock backend 200 response with acknowledged record
      fakeHttpClient.handler = (req) async {
        if (req.url.path == '/attendance/batch-sync') {
          return http.Response(
            jsonEncode({
              'sessionId': 'sess_1',
              'newSynced': 1,
              'duplicates': 0,
              'totalRecords': 1,
              'records': [
                {
                  'idempotencyKey': 'key_att_1',
                  'userId': 'std_1',
                  'status': 'present',
                }
              ]
            }),
            200,
          );
        }
        return http.Response('{}', 200);
      };

      final result = await syncManager.syncNow();
      expect(result.success, isTrue);
      expect(result.syncedCount, equals(1));

      // Outbox op should be completed
      final op = await dbService.outboxRepository.getItemByLocalId('op_att_1');
      expect(op, isNotNull);
      expect(op!.status, equals('completed'));

      // Attendance record should be synced
      final att = await dbService.attendanceRepository.getAttendanceByLocalId('att_1');
      expect(att, isNotNull);
      expect(att!.syncState, equals('synced'));
    });

    test('3. Completed operation is not resent', () async {
      await dbService.outboxRepository.enqueue(
        SyncOutboxTableCompanion.insert(
          localId: 'op_done_1',
          entityType: 'attendance',
          entityId: 'att_done_1',
          endpoint: '/attendance/batch-sync',
          method: const drift.Value('POST'),
          payload: jsonEncode({'sessionId': 'sess_1', 'records': []}),
          status: const drift.Value('completed'),
        ),
      );

      int callCount = 0;
      fakeHttpClient.handler = (req) async {
        callCount++;
        return http.Response('{}', 200);
      };

      final result = await syncManager.syncNow();
      expect(result.syncedCount, equals(0));
      expect(callCount, equals(0));
    });

    test('4. Sync lock prevents concurrent runs', () async {
      await dbService.sessionRepository.upsertSession(
        SessionsTableCompanion.insert(
          localId: 'sess_slow',
          teacherId: 'teacher_1',
          name: 'Slow Session',
          startTime: DateTime.now(),
          endTime: DateTime.now().add(const Duration(hours: 1)),
          location: const drift.Value('Hall A'),
        ),
      );

      await dbService.outboxRepository.enqueue(
        SyncOutboxTableCompanion.insert(
          localId: 'op_slow',
          entityType: 'attendance',
          entityId: 'att_slow',
          endpoint: '/attendance/batch-sync',
          method: const drift.Value('POST'),
          payload: jsonEncode({
            'sessionId': 'sess_slow',
            'records': [
              {'studentId': 'std_slow', 'idempotencyKey': 'key_slow'}
            ]
          }),
          idempotencyKey: const drift.Value('key_slow'),
          status: const drift.Value('pending'),
        ),
      );

      final completer = Completer<http.Response>();
      fakeHttpClient.handler = (req) async {
        return completer.future;
      };

      // Start first sync (it will hang on completer)
      final future1 = syncManager.syncPending();

      // Attempt second sync concurrently while future1 is in flight
      final result2 = await syncManager.syncPending();
      expect(result2.success, isFalse);
      expect(result2.message, contains('already in progress'));

      // Complete the first sync
      completer.complete(
        http.Response(
          jsonEncode({
            'sessionId': 'sess_slow',
            'records': [{'idempotencyKey': 'key_slow'}]
          }),
          200,
        ),
      );

      final result1 = await future1;
      expect(result1.success, isTrue);
      expect(result1.syncedCount, equals(1));
    });

    test('5. FIFO ordering works', () async {
      final callOrder = <String>[];
      fakeHttpClient.handler = (req) async {
        if (req.url.path == '/sessions/reconcile' || req.url.path == '/sessions/create') {
          final body = jsonDecode((req as http.Request).body) as Map<String, dynamic>;
          callOrder.add(body['name'] as String);
          return http.Response(
            jsonEncode({'id': 'srv_${body['name']}'}),
            201,
          );
        }
        return http.Response('{}', 200);
      };

      final past = DateTime.now().subtract(const Duration(minutes: 10));

      // Insert older op first
      await dbService.outboxRepository.enqueue(
        SyncOutboxTableCompanion.insert(
          localId: 'op_session_first',
          entityType: 'session',
          entityId: 'sess_first',
          endpoint: '/sessions/reconcile',
          method: const drift.Value('POST'),
          payload: jsonEncode({'name': 'FIRST', 'course': 'CSE'}),
          createdAt: drift.Value(past),
          status: const drift.Value('pending'),
        ),
      );

      // Insert newer op second
      await dbService.outboxRepository.enqueue(
        SyncOutboxTableCompanion.insert(
          localId: 'op_session_second',
          entityType: 'session',
          entityId: 'sess_second',
          endpoint: '/sessions/reconcile',
          method: const drift.Value('POST'),
          payload: jsonEncode({'name': 'SECOND', 'course': 'CSE'}),
          createdAt: drift.Value(past.add(const Duration(minutes: 5))),
          status: const drift.Value('pending'),
        ),
      );

      await syncManager.syncNow();
      expect(callOrder, equals(['FIRST', 'SECOND']));
    });

    test('6. Network unavailable pauses sync', () async {
      fakeConnectivity.emit([ConnectivityResult.none]);
      await connectivityService.checkReachability();
      expect(connectivityService.isOffline, isTrue);

      int callCount = 0;
      fakeHttpClient.handler = (req) async {
        callCount++;
        return http.Response('{}', 200);
      };

      await dbService.outboxRepository.enqueue(
        SyncOutboxTableCompanion.insert(
          localId: 'op_offline',
          entityType: 'session',
          entityId: 'sess_off',
          endpoint: '/sessions/reconcile',
          method: const drift.Value('POST'),
          payload: jsonEncode({'name': 'Offline Session'}),
          status: const drift.Value('pending'),
        ),
      );

      final result = await syncManager.syncPending();
      expect(result.success, isFalse);
      expect(result.message, contains('Network unreachable'));
      expect(callCount, equals(0));
      expect(syncManager.status.state, equals(SyncState.waitingForNetwork));
    });

    test('7. Network restoration triggers sync', () async {
      // Start offline
      fakeConnectivity.emit([ConnectivityResult.none]);
      await connectivityService.checkReachability();

      await dbService.sessionRepository.upsertSession(
        SessionsTableCompanion.insert(
          localId: 'sess_auto',
          teacherId: 'teacher_1',
          name: 'Auto Session',
          startTime: DateTime.now(),
          endTime: DateTime.now().add(const Duration(hours: 1)),
          location: const drift.Value('Hall A'),
        ),
      );

      await dbService.outboxRepository.enqueue(
        SyncOutboxTableCompanion.insert(
          localId: 'op_auto',
          entityType: 'session',
          entityId: 'sess_auto',
          endpoint: '/sessions/reconcile',
          method: const drift.Value('POST'),
          payload: jsonEncode({'name': 'Auto Session'}),
          status: const drift.Value('pending'),
        ),
      );

      syncManager.init();

      // Now restore network
      fakeHttpClient.handler = (req) async {
        if (req.url.path == '/health') {
          return http.Response(jsonEncode({'status': 'healthy'}), 200);
        }
        if (req.url.path == '/sessions/reconcile') {
          return http.Response(jsonEncode({'id': 'srv_auto_123'}), 201);
        }
        return http.Response('{}', 200);
      };

      fakeConnectivity.emit([ConnectivityResult.wifi]);
      await connectivityService.checkReachability();

      // Allow async triggers to fire
      await Future<void>.delayed(const Duration(milliseconds: 100));

      final op = await dbService.outboxRepository.getItemByLocalId('op_auto');
      expect(op, isNotNull);
      expect(op!.status, equals('completed'));
    });

    test('8. HTTP 500 retries', () async {
      await dbService.outboxRepository.enqueue(
        SyncOutboxTableCompanion.insert(
          localId: 'op_500',
          entityType: 'session',
          entityId: 'sess_500',
          endpoint: '/sessions/reconcile',
          method: const drift.Value('POST'),
          payload: jsonEncode({'name': 'Server Err Session'}),
          status: const drift.Value('pending'),
        ),
      );

      fakeHttpClient.handler = (req) async {
        return http.Response('Internal Server Error', 500);
      };

      final result = await syncManager.syncNow();
      expect(result.success, isFalse);
      expect(result.failedCount, equals(1));

      final op = await dbService.outboxRepository.getItemByLocalId('op_500');
      expect(op, isNotNull);
      expect(op!.status, equals('failed'));
      expect(op.attemptCount, equals(1));
      expect(op.errorMessage, contains('500'));
    });

    test('9. Timeout retries', () async {
      await dbService.outboxRepository.enqueue(
        SyncOutboxTableCompanion.insert(
          localId: 'op_timeout',
          entityType: 'session',
          entityId: 'sess_to',
          endpoint: '/sessions/reconcile',
          method: const drift.Value('POST'),
          payload: jsonEncode({'name': 'Timeout Session'}),
          status: const drift.Value('pending'),
        ),
      );

      fakeHttpClient.handler = (req) async {
        throw TimeoutException('Client network timeout');
      };

      final result = await syncManager.syncNow();
      expect(result.success, isFalse);

      final op = await dbService.outboxRepository.getItemByLocalId('op_timeout');
      expect(op, isNotNull);
      expect(op!.status, equals('failed'));
      expect(op.attemptCount, equals(1));
      expect(op.errorMessage?.toLowerCase(), anyOf(contains('timeout'), contains('timed out')));
    });

    test('10. Permanent 4xx does not retry forever', () async {
      await dbService.outboxRepository.enqueue(
        SyncOutboxTableCompanion.insert(
          localId: 'op_400',
          entityType: 'session',
          entityId: 'sess_400',
          endpoint: '/sessions/reconcile',
          method: const drift.Value('POST'),
          payload: jsonEncode({'name': 'Bad Request'}),
          status: const drift.Value('pending'),
        ),
      );

      fakeHttpClient.handler = (req) async {
        return http.Response('Bad Request: Invalid params', 400);
      };

      await syncManager.syncNow();

      final op = await dbService.outboxRepository.getItemByLocalId('op_400');
      expect(op, isNotNull);
      expect(op!.status, equals('failed'));
      expect(op.errorMessage, contains('PERMANENT'));

      // Next sync peek will not process dead-lettered op
      int retryCount = 0;
      fakeHttpClient.handler = (req) async {
        retryCount++;
        return http.Response('{}', 200);
      };

      await syncManager.syncNow();
      expect(retryCount, equals(0));
    });

    test('11. Backoff increases correctly', () async {
      // Create an op that already failed once just 100ms ago
      await dbService.outboxRepository.enqueue(
        SyncOutboxTableCompanion.insert(
          localId: 'op_backoff',
          entityType: 'session',
          entityId: 'sess_bo',
          endpoint: '/sessions/reconcile',
          method: const drift.Value('POST'),
          payload: jsonEncode({'name': 'Backoff Session'}),
          status: const drift.Value('pending'),
          attemptCount: const drift.Value(1),
          lastAttemptedAt: drift.Value(DateTime.now()),
        ),
      );

      int dispatchCount = 0;
      fakeHttpClient.handler = (req) async {
        dispatchCount++;
        return http.Response('{}', 200);
      };

      // Immediate sync should skip it because backoff delay (1s) has not elapsed
      await syncManager.syncNow();
      expect(dispatchCount, equals(0));

      // Update lastAttemptedAt to 2 seconds ago (exceeding 1s backoff)
      await (db.update(db.syncOutboxTable)
            ..where((tbl) => tbl.localId.equals('op_backoff')))
          .write(
        SyncOutboxTableCompanion(
          lastAttemptedAt: drift.Value(DateTime.now().subtract(const Duration(seconds: 2))),
        ),
      );

      fakeHttpClient.handler = (req) async {
        dispatchCount++;
        return http.Response(jsonEncode({'id': 'srv_bo'}), 200);
      };

      await syncManager.syncNow();
      expect(dispatchCount, equals(1));
    });

    test('12. App restart recovers pending operations', () async {
      await dbService.outboxRepository.enqueue(
        SyncOutboxTableCompanion.insert(
          localId: 'op_persisted',
          entityType: 'session',
          entityId: 'sess_persisted',
          endpoint: '/sessions/reconcile',
          method: const drift.Value('POST'),
          payload: jsonEncode({'name': 'Persisted Session'}),
          status: const drift.Value('pending'),
        ),
      );

      // Simulate app restart: create a new SyncManager instance referencing the same DB
      final freshSyncManager = SyncManager.forTesting(
        dbService: dbService,
        connectivityService: connectivityService,
        apiClient: apiClient,
      );

      fakeHttpClient.handler = (req) async {
        return http.Response(jsonEncode({'id': 'srv_recovered'}), 200);
      };

      final result = await freshSyncManager.syncNow();
      expect(result.success, isTrue);
      expect(result.syncedCount, equals(1));
    });

    test('13. IN_FLIGHT operations recover safely', () async {
      // Simulate crash while operation was in_flight
      await dbService.outboxRepository.enqueue(
        SyncOutboxTableCompanion.insert(
          localId: 'op_crashed',
          entityType: 'session',
          entityId: 'sess_crashed',
          endpoint: '/sessions/reconcile',
          method: const drift.Value('POST'),
          payload: jsonEncode({'name': 'Crashed Session'}),
          status: const drift.Value('in_flight'),
        ),
      );

      // Verify startup reset
      final resetCount = await dbService.outboxRepository.resetInFlightToPending();
      expect(resetCount, equals(1));

      final op = await dbService.outboxRepository.getItemByLocalId('op_crashed');
      expect(op!.status, equals('pending'));

      fakeHttpClient.handler = (req) async {
        return http.Response(jsonEncode({'id': 'srv_crashed'}), 200);
      };

      final result = await syncManager.syncNow();
      expect(result.syncedCount, equals(1));
    });

    test('14. New operation added during sync is preserved', () async {
      await dbService.sessionRepository.upsertSession(
        SessionsTableCompanion.insert(
          localId: 'sess_active',
          teacherId: 'teacher_1',
          name: 'Active Session',
          startTime: DateTime.now(),
          endTime: DateTime.now().add(const Duration(hours: 1)),
          location: const drift.Value('Hall A'),
        ),
      );

      await dbService.outboxRepository.enqueue(
        SyncOutboxTableCompanion.insert(
          localId: 'op_active_1',
          entityType: 'session',
          entityId: 'sess_active',
          endpoint: '/sessions/reconcile',
          method: const drift.Value('POST'),
          payload: jsonEncode({'name': 'Active 1'}),
          status: const drift.Value('pending'),
        ),
      );

      fakeHttpClient.handler = (req) async {
        if (req.url.path == '/sessions/reconcile') {
          // Enqueue a new operation while the first sync operation is actively in flight
          await dbService.outboxRepository.enqueue(
            SyncOutboxTableCompanion.insert(
              localId: 'op_added_mid_sync',
              entityType: 'session',
              entityId: 'sess_active',
              endpoint: '/sessions/reconcile',
              method: const drift.Value('POST'),
              payload: jsonEncode({'name': 'Active 2'}),
              status: const drift.Value('pending'),
            ),
          );
          return http.Response(jsonEncode({'id': 'srv_act_1'}), 201);
        }
        return http.Response('{}', 200);
      };

      final result = await syncManager.syncPending();
      expect(result.success, isTrue);

      // The new operation must remain safely preserved as pending
      final midOp = await dbService.outboxRepository.getItemByLocalId('op_added_mid_sync');
      expect(midOp, isNotNull);
      expect(midOp!.status, equals('pending'));
    });

    test('15. Successful operation is acknowledged atomically', () async {
      await ensureStudent('std_ack', 'Bob');
      await dbService.sessionRepository.upsertSession(
        SessionsTableCompanion.insert(
          localId: 'sess_ack',
          teacherId: 'teacher_1',
          name: 'Ack Session',
          startTime: DateTime.now(),
          endTime: DateTime.now().add(const Duration(hours: 1)),
          location: const drift.Value('Hall A'),
          syncState: const drift.Value('synced'),
        ),
      );

      final attComp = AttendanceRecordsTableCompanion.insert(
        localId: 'att_ack',
        sessionId: 'sess_ack',
        studentId: 'std_ack',
        studentName: 'Bob',
        checkInTime: DateTime.now(),
        idempotencyKey: 'key_ack',
        syncState: const drift.Value('pending'),
      );

      final outboxComp = SyncOutboxTableCompanion.insert(
        localId: 'op_ack',
        entityType: 'attendance',
        entityId: 'att_ack',
        endpoint: '/attendance/batch-sync',
        method: const drift.Value('POST'),
        payload: jsonEncode({
          'sessionId': 'sess_ack',
          'records': [
            {'studentId': 'std_ack', 'idempotencyKey': 'key_ack'}
          ]
        }),
        idempotencyKey: const drift.Value('key_ack'),
        status: const drift.Value('pending'),
      );

      await dbService.attendanceRepository.recordAttendanceWithOutbox(
        attendance: attComp,
        outboxItem: outboxComp,
      );

      fakeHttpClient.handler = (req) async {
        return http.Response(
          jsonEncode({
            'sessionId': 'sess_ack',
            'records': [{'idempotencyKey': 'key_ack'}]
          }),
          200,
        );
      };

      await syncManager.syncNow();

      final outbox = await dbService.outboxRepository.getItemByLocalId('op_ack');
      final att = await dbService.attendanceRepository.getAttendanceByLocalId('att_ack');

      expect(outbox!.status, equals('completed'));
      expect(att!.syncState, equals('synced'));
    });

    test('16. Failed operation remains durable', () async {
      await dbService.outboxRepository.enqueue(
        SyncOutboxTableCompanion.insert(
          localId: 'op_durable_fail',
          entityType: 'session',
          entityId: 'sess_df',
          endpoint: '/sessions/reconcile',
          method: const drift.Value('POST'),
          payload: jsonEncode({'name': 'Fail Session'}),
          status: const drift.Value('pending'),
        ),
      );

      fakeHttpClient.handler = (req) async {
        return http.Response('Server error', 500);
      };

      await syncManager.syncNow();

      final op = await dbService.outboxRepository.getItemByLocalId('op_durable_fail');
      expect(op, isNotNull);
      expect(op!.status, equals('failed'));
      expect(op.attemptCount, equals(1));
    });

    test('17. Duplicate operation is idempotent', () async {
      final outboxComp = SyncOutboxTableCompanion.insert(
        localId: 'op_idem_1',
        entityType: 'session',
        entityId: 'sess_idem',
        endpoint: '/sessions/reconcile',
        method: const drift.Value('POST'),
        payload: jsonEncode({'name': 'Idem Session'}),
        idempotencyKey: const drift.Value('idem_key_123'),
        status: const drift.Value('pending'),
      );

      // Inserting once
      await dbService.outboxRepository.enqueue(outboxComp);

      // Inserting second time with insertOnConflictUpdate
      await dbService.outboxRepository.enqueue(outboxComp);

      final totalOps = await dbService.outboxRepository.countPending();
      expect(totalOps, equals(1));
    });

    test('18. Legacy SharedPreferences migration is idempotent', () async {
      final prefs = await SharedPreferences.getInstance();
      const legacyKey = '${SharedPreferencesMigrationBridge.queuePrefix}sess_legacy_01';
      final record1 = jsonEncode({
        'studentId': 'std_mig_1',
        'studentName': 'Legacy Student 1',
        'deviceKeyId': 'dev_1',
        'responseNonce': 'nonce_1',
        'idempotencyKey': 'legacy_key_1',
        'verificationMode': 'BLE_BATCH',
        'proximityTier': 'NEAR',
        'checkInTime': DateTime.now().toIso8601String(),
        'status': 'present',
      });
      final record2 = jsonEncode({
        'studentId': 'std_mig_2',
        'studentName': 'Legacy Student 2',
        'deviceKeyId': 'dev_2',
        'responseNonce': 'nonce_2',
        'idempotencyKey': 'legacy_key_2',
        'verificationMode': 'BLE_BATCH',
        'proximityTier': 'NEAR',
        'checkInTime': DateTime.now().toIso8601String(),
        'status': 'present',
      });

      await prefs.setStringList(legacyKey, [record1, record2]);

      final bridge = SharedPreferencesMigrationBridge(dbService: dbService);

      // First migration run
      final summary1 = await bridge.migrateLegacyQueues(sharedPreferences: prefs);
      expect(summary1.migratedRecords, equals(2));
      expect(summary1.migratedSessions, equals(1));
      expect(prefs.containsKey(legacyKey), isFalse);

      // Verify records inserted in Drift DB
      final att1 = await dbService.attendanceRepository.getAttendanceByIdempotencyKey('legacy_key_1');
      expect(att1, isNotNull);
      expect(att1!.studentName, equals('Legacy Student 1'));

      final outbox1 = await dbService.outboxRepository.getItemByLocalId('op_${att1.localId}');
      expect(outbox1, isNotNull);
      expect(outbox1!.status, equals('pending'));

      // Populate again with the same records to simulate re-running or residual data
      await prefs.setStringList(legacyKey, [record1, record2]);

      // Second migration run (Must be strictly idempotent!)
      final summary2 = await bridge.migrateLegacyQueues(sharedPreferences: prefs);
      expect(summary2.migratedRecords, equals(0));
      expect(summary2.skippedDuplicates, equals(2));
      expect(prefs.containsKey(legacyKey), isFalse);
    });

    test('19. Offline session gets server ID after reconciliation', () async {
      await dbService.sessionRepository.createOfflineSessionWithOutbox(
        session: SessionsTableCompanion.insert(
          localId: 'sess_local_777',
          teacherId: 'teacher_1',
          name: 'Physics Lab',
          startTime: DateTime.now(),
          endTime: DateTime.now().add(const Duration(hours: 1)),
          location: const drift.Value('Lab 3'),
          syncState: const drift.Value('pending'),
        ),
        outboxItem: SyncOutboxTableCompanion.insert(
          localId: 'op_sess_local_777',
          entityType: 'session',
          entityId: 'sess_local_777',
          endpoint: '/sessions/reconcile',
          method: const drift.Value('POST'),
          payload: jsonEncode({
            'name': 'Physics Lab',
            'clientSessionId': 'sess_local_777',
            'idempotencyKey': 'key_sess_777',
          }),
          idempotencyKey: const drift.Value('key_sess_777'),
          status: const drift.Value('pending'),
        ),
      );

      fakeHttpClient.handler = (req) async {
        if (req.url.path == '/sessions/reconcile') {
          return http.Response(
            jsonEncode({
              'id': 'srv_uuid_777',
              'name': 'Physics Lab',
            }),
            201,
          );
        }
        return http.Response('{}', 200);
      };

      final result = await syncManager.syncNow();
      expect(result.success, isTrue);

      final session = await dbService.sessionRepository.getSessionByLocalId('sess_local_777');
      expect(session, isNotNull);
      expect(session!.serverId, equals('srv_uuid_777'));
      expect(session.syncState, equals('synced'));
    });

    test('20. Offline session local ID never changes', () async {
      await dbService.sessionRepository.createOfflineSessionWithOutbox(
        session: SessionsTableCompanion.insert(
          localId: 'sess_local_immutable_id',
          teacherId: 'teacher_1',
          name: 'Immutable Session',
          startTime: DateTime.now(),
          endTime: DateTime.now().add(const Duration(hours: 1)),
          location: const drift.Value('Lab 3'),
          syncState: const drift.Value('pending'),
        ),
        outboxItem: SyncOutboxTableCompanion.insert(
          localId: 'op_sess_immutable',
          entityType: 'session',
          entityId: 'sess_local_immutable_id',
          endpoint: '/sessions/reconcile',
          method: const drift.Value('POST'),
          payload: jsonEncode({'name': 'Immutable Session'}),
          status: const drift.Value('pending'),
        ),
      );

      fakeHttpClient.handler = (req) async {
        return http.Response(jsonEncode({'id': 'srv_uuid_assigned'}), 201);
      };

      await syncManager.syncNow();

      final session = await dbService.sessionRepository.getSessionByLocalId('sess_local_immutable_id');
      expect(session, isNotNull);
      expect(session!.localId, equals('sess_local_immutable_id'));
      expect(session.serverId, equals('srv_uuid_assigned'));
    });

    test('21. Attendance batch partial acknowledgement works', () async {
      await ensureStudent('std_p1', 'P1');
      await ensureStudent('std_p2', 'P2');
      await dbService.sessionRepository.upsertSession(
        SessionsTableCompanion.insert(
          localId: 'sess_partial',
          teacherId: 'teacher_1',
          name: 'Partial Ack Session',
          startTime: DateTime.now(),
          endTime: DateTime.now().add(const Duration(hours: 1)),
          location: const drift.Value('Hall B'),
          syncState: const drift.Value('synced'),
        ),
      );

      final att1 = AttendanceRecordsTableCompanion.insert(
        localId: 'att_p1',
        sessionId: 'sess_partial',
        studentId: 'std_p1',
        studentName: 'P1',
        checkInTime: DateTime.now(),
        idempotencyKey: 'key_p1',
        syncState: const drift.Value('pending'),
      );
      final outbox1 = SyncOutboxTableCompanion.insert(
        localId: 'op_p1',
        entityType: 'attendance',
        entityId: 'att_p1',
        endpoint: '/attendance/batch-sync',
        method: const drift.Value('POST'),
        payload: jsonEncode({
          'sessionId': 'sess_partial',
          'records': [{'studentId': 'std_p1', 'idempotencyKey': 'key_p1'}]
        }),
        idempotencyKey: const drift.Value('key_p1'),
        status: const drift.Value('pending'),
      );

      final att2 = AttendanceRecordsTableCompanion.insert(
        localId: 'att_p2',
        sessionId: 'sess_partial',
        studentId: 'std_p2',
        studentName: 'P2',
        checkInTime: DateTime.now(),
        idempotencyKey: 'key_p2',
        syncState: const drift.Value('pending'),
      );
      final outbox2 = SyncOutboxTableCompanion.insert(
        localId: 'op_p2',
        entityType: 'attendance',
        entityId: 'att_p2',
        endpoint: '/attendance/batch-sync',
        method: const drift.Value('POST'),
        payload: jsonEncode({
          'sessionId': 'sess_partial',
          'records': [{'studentId': 'std_p2', 'idempotencyKey': 'key_p2'}]
        }),
        idempotencyKey: const drift.Value('key_p2'),
        status: const drift.Value('pending'),
      );

      await dbService.attendanceRepository.recordAttendanceWithOutbox(
        attendance: att1,
        outboxItem: outbox1,
      );
      await dbService.attendanceRepository.recordAttendanceWithOutbox(
        attendance: att2,
        outboxItem: outbox2,
      );

      // Server acknowledges key_p1, but key_p2 is omitted
      fakeHttpClient.handler = (req) async {
        return http.Response(
          jsonEncode({
            'sessionId': 'sess_partial',
            'records': [
              {'idempotencyKey': 'key_p1', 'userId': 'std_p1'}
            ]
          }),
          200,
        );
      };

      await syncManager.syncNow();

      // Op1 is completed
      final op1 = await dbService.outboxRepository.getItemByLocalId('op_p1');
      expect(op1!.status, equals('completed'));

      // Op2 remains failed/pending for retry
      final op2 = await dbService.outboxRepository.getItemByLocalId('op_p2');
      expect(op2!.status, equals('failed'));
      expect(op2.errorMessage, contains('unacknowledged'));
    });

    test('22. Server timeout after commit is safe to retry', () async {
      await ensureStudent('std_to_c', 'Charlie');
      await dbService.sessionRepository.upsertSession(
        SessionsTableCompanion.insert(
          localId: 'sess_to_commit',
          teacherId: 'teacher_1',
          name: 'Timeout Commit Session',
          startTime: DateTime.now(),
          endTime: DateTime.now().add(const Duration(hours: 1)),
          location: const drift.Value('Hall C'),
          syncState: const drift.Value('synced'),
        ),
      );

      await dbService.attendanceRepository.recordAttendanceWithOutbox(
        attendance: AttendanceRecordsTableCompanion.insert(
          localId: 'att_to_c',
          sessionId: 'sess_to_commit',
          studentId: 'std_to_c',
          studentName: 'Charlie',
          checkInTime: DateTime.now(),
          idempotencyKey: 'key_to_c',
          syncState: const drift.Value('pending'),
        ),
        outboxItem: SyncOutboxTableCompanion.insert(
          localId: 'op_to_c',
          entityType: 'attendance',
          entityId: 'att_to_c',
          endpoint: '/attendance/batch-sync',
          method: const drift.Value('POST'),
          payload: jsonEncode({
            'sessionId': 'sess_to_commit',
            'records': [{'studentId': 'std_to_c', 'idempotencyKey': 'key_to_c'}]
          }),
          idempotencyKey: const drift.Value('key_to_c'),
          status: const drift.Value('pending'),
        ),
      );

      // Attempt 1: Server commits but response times out
      fakeHttpClient.handler = (req) async {
        throw TimeoutException('Network dropped after server committed');
      };

      final result1 = await syncManager.syncNow();
      expect(result1.success, isFalse);

      final opAfterFail = await dbService.outboxRepository.getItemByLocalId('op_to_c');
      expect(opAfterFail!.status, equals('failed'));
      expect(opAfterFail.attemptCount, equals(1));

      // Reset lastAttemptedAt so backoff doesn't delay next attempt
      await (db.update(db.syncOutboxTable)
            ..where((tbl) => tbl.localId.equals('op_to_c')))
          .write(
        SyncOutboxTableCompanion(
          lastAttemptedAt: drift.Value(DateTime.now().subtract(const Duration(seconds: 10))),
        ),
      );

      // Attempt 2: Retry arrives at backend; backend recognizes duplicate idempotency key and returns 200
      fakeHttpClient.handler = (req) async {
        return http.Response(
          jsonEncode({
            'sessionId': 'sess_to_commit',
            'duplicates': 1,
            'records': [
              {'idempotencyKey': 'key_to_c', 'userId': 'std_to_c'}
            ]
          }),
          200,
        );
      };

      final result2 = await syncManager.syncNow();
      expect(result2.success, isTrue);
      expect(result2.syncedCount, equals(1));

      final opAfterSuccess = await dbService.outboxRepository.getItemByLocalId('op_to_c');
      expect(opAfterSuccess!.status, equals('completed'));

      final attAfterSuccess = await dbService.attendanceRepository.getAttendanceByLocalId('att_to_c');
      expect(attAfterSuccess!.syncState, equals('synced'));
    });

    test('23. Transactional Enqueue Atomicity (Phase 4C)', () async {
      await ensureStudent('std_atomic', 'Atomic Student');
      await dbService.sessionRepository.upsertSession(
        SessionsTableCompanion.insert(
          localId: 'sess_atomic',
          teacherId: 'teacher_1',
          name: 'Atomic Session',
          startTime: DateTime.now(),
          endTime: DateTime.now().add(const Duration(hours: 1)),
          location: const drift.Value('Hall A'),
          syncState: const drift.Value('synced'),
        ),
      );
      // Proves that attendance and outbox operation are committed together
      final attCompanion = AttendanceRecordsTableCompanion.insert(
        localId: 'att_atomic',
        sessionId: 'sess_atomic',
        studentId: 'std_atomic',
        studentName: 'Atomic Student',
        checkInTime: DateTime.now(),
        idempotencyKey: 'key_atomic',
        syncState: const drift.Value('pending'),
      );

      final outboxCompanion = SyncOutboxTableCompanion.insert(
        localId: 'op_atomic',
        entityType: 'attendance',
        entityId: 'att_atomic',
        endpoint: '/attendance/batch-sync',
        method: const drift.Value('POST'),
        payload: jsonEncode({'sessionId': 'sess_atomic'}),
        idempotencyKey: const drift.Value('key_atomic'),
        status: const drift.Value('pending'),
      );

      await dbService.attendanceRepository.recordAttendanceWithOutbox(
        attendance: attCompanion,
        outboxItem: outboxCompanion,
      );

      final att = await dbService.attendanceRepository.getAttendanceByLocalId('att_atomic');
      final op = await dbService.outboxRepository.getItemByLocalId('op_atomic');

      expect(att, isNotNull);
      expect(op, isNotNull);
      expect(op!.entityId, equals(att!.localId));
    });
  });
}
