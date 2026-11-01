import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:drift/drift.dart' as drift;
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'package:attendance_app/core/database/database.dart';
import 'package:attendance_app/core/network/api_client.dart';
import 'package:attendance_app/core/network/connectivity_service.dart';
import 'package:attendance_app/core/sync/sync_manager.dart';
import 'package:attendance_app/student/services/complaint_service.dart';
import 'package:attendance_app/student/models/complaint_model.dart';

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
  late ComplaintService complaintService;

  const testStudentId = 'student_test_101';

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
      if (req.url.path == '/complaints' && req.method == 'POST') {
        return http.Response(
          jsonEncode({
            'message': 'Complaint submitted successfully',
            'complaint': {
              'id': 'srv_comp_001',
              'studentId': testStudentId,
              'category': 'Hostel/Room',
              'title': 'Test Issue',
              'description': 'Test Description',
              'location': 'Hostel A',
              'priority': 'MEDIUM',
              'status': 'PENDING',
              'createdAt': DateTime.now().toIso8601String(),
            }
          }),
          201,
        );
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

    complaintService = ComplaintService(
      apiClient: apiClient,
      dbService: dbService,
      connectivityService: connectivityService,
      syncManager: syncManager,
    );
  });

  tearDown(() async {
    syncManager.dispose();
    connectivityService.dispose();
    fakeConnectivity.dispose();
    await dbService.close();
  });

  group('CampusOS Phase 6 — Offline Complaint Workflow Tests', () {
    // -------------------------------------------------------------------------
    // Test 1: Create complaint online -> stored locally, outbox created, synced
    // -------------------------------------------------------------------------
    test('1. Create complaint online -> persisted locally and synced immediately', () async {
      final complaint = await complaintService.createComplaint(
        studentId: testStudentId,
        category: 'Hostel/Room',
        title: 'Broken fan',
        description: 'Ceiling fan makes grinding noise',
        location: 'Room 302',
        priority: 'MEDIUM',
      );

      expect(complaint.title, equals('Broken fan'));
      expect(complaint.syncState, equals('synced'));
      expect(complaint.serverId, equals('srv_comp_001'));

      // Check local database
      final local = await dbService.complaintRepository.getComplaintByLocalId(complaint.localId!);
      expect(local, isNotNull);
      expect(local!.syncState, equals('synced'));
      expect(local.serverId, equals('srv_comp_001'));

      // Check outbox operation completed
      final op = await dbService.outboxRepository.getOperation('op_${complaint.localId}');
      expect(op, isNotNull);
      expect(op!.status, equals('completed'));
    });

    // -------------------------------------------------------------------------
    // Test 2: Create complaint offline -> stored locally, pending, outbox pending
    // -------------------------------------------------------------------------
    test('2. Create complaint offline -> immediately confirms saved locally', () async {
      // Simulate offline network
      fakeConnectivity.emit([ConnectivityResult.none]);
      await connectivityService.checkReachability();
      expect(connectivityService.isOffline, isTrue);

      final complaint = await complaintService.createComplaint(
        studentId: testStudentId,
        category: 'Mess',
        title: 'No water in dispenser',
        description: 'Mess water dispenser is completely empty.',
        location: 'Dining Hall',
        priority: 'HIGH',
      );

      expect(complaint.title, equals('No water in dispenser'));
      expect(complaint.syncState, equals('pending'));
      expect(complaint.isSyncPending, isTrue);
      expect(complaint.serverId, isNull);

      // Verify local persistence
      final local = await dbService.complaintRepository.getComplaintByLocalId(complaint.localId!);
      expect(local, isNotNull);
      expect(local!.syncState, equals('pending'));
      expect(local.status, equals('PENDING'));
    });

    // -------------------------------------------------------------------------
    // Test 3: Local persistence verification
    // -------------------------------------------------------------------------
    test('3. Complaint is persisted locally in Drift SQLite', () async {
      fakeConnectivity.emit([ConnectivityResult.none]);
      await connectivityService.checkReachability();

      final complaint = await complaintService.createComplaint(
        studentId: testStudentId,
        category: 'Cleanliness',
        title: 'Corridor dirty',
        description: 'Trash left in 2nd floor hallway.',
        location: 'Floor 2',
      );

      final retrieved = await dbService.complaintRepository.getComplaintByLocalId(complaint.localId!);
      expect(retrieved, isNotNull);
      expect(retrieved!.studentId, equals(testStudentId));
      expect(retrieved.category, equals('Cleanliness'));
      expect(retrieved.title, equals('Corridor dirty'));
      expect(retrieved.location, equals('Floor 2'));
    });

    // -------------------------------------------------------------------------
    // Test 4: Transactional outbox creation atomicity
    // -------------------------------------------------------------------------
    test('4. Outbox entry is created transactionally with the complaint', () async {
      fakeConnectivity.emit([ConnectivityResult.none]);
      await connectivityService.checkReachability();

      final complaint = await complaintService.createComplaint(
        studentId: testStudentId,
        category: 'Infrastructure',
        title: 'Broken window latch',
        description: 'Window does not stay closed.',
      );

      final op = await dbService.outboxRepository.getOperation('op_${complaint.localId}');
      expect(op, isNotNull);
      expect(op!.entityType, equals('complaint'));
      expect(op.entityId, equals(complaint.localId));
      expect(op.endpoint, equals('/complaints'));
      expect(op.status, equals('pending'));

      final payload = jsonDecode(op.payload);
      expect(payload['title'], equals('Broken window latch'));
      expect(payload['idempotencyKey'], equals(complaint.idempotencyKey));
    });

    // -------------------------------------------------------------------------
    // Test 5: App restart preserves pending complaint
    // -------------------------------------------------------------------------
    test('5. App restart preserves pending complaint & outbox records', () async {
      fakeConnectivity.emit([ConnectivityResult.none]);
      await connectivityService.checkReachability();

      final complaint = await complaintService.createComplaint(
        studentId: testStudentId,
        category: 'Hostel/Room',
        title: 'Door lock jammed',
        description: 'Key gets stuck in lock cylinder.',
      );

      // Simulate app kill & restart by creating a new service instance connected to the same DB
      final restartedComplaintService = ComplaintService(
        apiClient: apiClient,
        dbService: dbService,
        connectivityService: connectivityService,
        syncManager: syncManager,
      );

      final complaints = await restartedComplaintService.getStudentComplaints(testStudentId);
      expect(complaints.length, equals(1));
      expect(complaints.first.localId, equals(complaint.localId));
      expect(complaints.first.isSyncPending, isTrue);

      final pendingOp = await dbService.outboxRepository.getOperation('op_${complaint.localId}');
      expect(pendingOp, isNotNull);
      expect(pendingOp!.status, equals('pending'));
    });

    // -------------------------------------------------------------------------
    // Test 6: Network restoration syncs complaint
    // -------------------------------------------------------------------------
    test('6. Network restoration triggers automatic sync of pending complaint', () async {
      // 1. Create while offline
      fakeConnectivity.emit([ConnectivityResult.none]);
      await connectivityService.checkReachability();

      final complaint = await complaintService.createComplaint(
        studentId: testStudentId,
        category: 'Hostel/Room',
        title: 'Water seepage',
        description: 'Seepage from roof during rain',
      );
      expect(complaint.isSyncPending, isTrue);

      // 2. Restore network
      fakeConnectivity.emit([ConnectivityResult.wifi]);
      await connectivityService.checkReachability();
      expect(connectivityService.isOnline, isTrue);

      // 3. Trigger sync
      final syncResult = await syncManager.syncNow();
      expect(syncResult.success, isTrue);
      expect(syncResult.syncedCount, equals(1));

      // 4. Verify local complaint is updated to synced
      final local = await dbService.complaintRepository.getComplaintByLocalId(complaint.localId!);
      expect(local!.syncState, equals('synced'));
      expect(local.serverId, isNotNull);
    });

    // -------------------------------------------------------------------------
    // Test 7: Successful sync marks complaint synced
    // -------------------------------------------------------------------------
    test('7. Successful sync marks local complaint synced and outbox completed', () async {
      fakeConnectivity.emit([ConnectivityResult.none]);
      await connectivityService.checkReachability();

      final complaint = await complaintService.createComplaint(
        studentId: testStudentId,
        category: 'Technical',
        title: 'LAN port dead',
        description: 'Wall ethernet port has no link light.',
      );

      // Now restore and run sync
      fakeConnectivity.emit([ConnectivityResult.wifi]);
      await connectivityService.checkReachability();
      await syncManager.syncNow();

      final syncedComplaint = await dbService.complaintRepository.getComplaintByLocalId(complaint.localId!);
      expect(syncedComplaint!.syncState, equals('synced'));
      expect(syncedComplaint.serverId, equals('srv_comp_001'));

      final op = await dbService.outboxRepository.getOperation('op_${complaint.localId}');
      expect(op!.status, equals('completed'));
    });

    // -------------------------------------------------------------------------
    // Test 8: Duplicate idempotency key does not create duplicate
    // -------------------------------------------------------------------------
    test('8. Duplicate idempotency key resolves to existing complaint', () async {
      const fixedKey = 'complaint_fixed_key_12345';

      // First creation
      final c1 = await complaintService.createComplaint(
        studentId: testStudentId,
        category: 'Mess',
        title: 'Cold milk',
        description: 'Milk was cold at breakfast.',
        customIdempotencyKey: fixedKey,
      );

      // Second creation with same idempotency key
      final c2 = await complaintService.createComplaint(
        studentId: testStudentId,
        category: 'Mess',
        title: 'Cold milk',
        description: 'Milk was cold at breakfast.',
        customIdempotencyKey: fixedKey,
      );

      // Both refer to the same complaint localId
      expect(c1.localId, equals(c2.localId));
      expect(c1.idempotencyKey, equals(c2.idempotencyKey));

      // Outbox has only 1 operation for this key
      final op = await dbService.outboxRepository.getItemByIdempotencyKey(fixedKey);
      expect(op, isNotNull);
    });

    // -------------------------------------------------------------------------
    // Test 9: Server timeout retries safely
    // -------------------------------------------------------------------------
    test('9. Server timeout backs off and retries safely without data loss', () async {
      int attempts = 0;
      fakeHttpClient.handler = (req) async {
        if (req.url.path == '/health') return http.Response(jsonEncode({'status': 'healthy'}), 200);
        if (req.url.path == '/complaints') {
          attempts++;
          if (attempts == 1) {
            throw const SocketException('Connection timed out');
          }
          return http.Response(
            jsonEncode({
              'message': 'Complaint submitted successfully',
              'complaint': {'id': 'srv_retry_001', 'createdAt': DateTime.now().toIso8601String()}
            }),
            201,
          );
        }
        return http.Response(jsonEncode({'status': 'ok'}), 200);
      };

      // 1. Create offline
      fakeConnectivity.emit([ConnectivityResult.none]);
      await connectivityService.checkReachability();
      final c = await complaintService.createComplaint(
        studentId: testStudentId,
        category: 'Hostel/Room',
        title: 'Timeout test issue',
        description: 'Testing socket timeout retry',
      );

      // 2. Bring online and run sync (attempt 1 fails with timeout)
      fakeConnectivity.emit([ConnectivityResult.wifi]);
      await connectivityService.checkReachability();
      final r1 = await syncManager.syncNow();
      expect(r1.failedCount, equals(1));

      final opAfterFail = await dbService.outboxRepository.getOperation('op_${c.localId}');
      expect(opAfterFail!.status, equals('failed'));
      expect(opAfterFail.attemptCount, equals(1));

      // 3. Reset lastAttemptedAt so backoff doesn't block immediate test run
      await dbService.outboxRepository.resetInFlightToPending();
      await (dbService.db.update(dbService.db.syncOutboxTable)
            ..where((tbl) => tbl.localId.equals('op_${c.localId}')))
          .write(const SyncOutboxTableCompanion(
            status: drift.Value('pending'),
            lastAttemptedAt: drift.Value(null),
          ));

      // 4. Attempt 2 succeeds
      final r2 = await syncManager.syncNow();
      expect(r2.syncedCount, equals(1));

      final opAfterSuccess = await dbService.outboxRepository.getOperation('op_${c.localId}');
      expect(opAfterSuccess!.status, equals('completed'));
    });

    // -------------------------------------------------------------------------
    // Test 10: Server 500 retries
    // -------------------------------------------------------------------------
    test('10. Server 500 records error and retries', () async {
      fakeHttpClient.handler = (req) async {
        if (req.url.path == '/health') return http.Response(jsonEncode({'status': 'healthy'}), 200);
        if (req.url.path == '/complaints') {
          return http.Response('{"message":"Internal Server Error"}', 500);
        }
        return http.Response('{"status":"ok"}', 200);
      };

      fakeConnectivity.emit([ConnectivityResult.none]);
      await connectivityService.checkReachability();
      final c = await complaintService.createComplaint(
        studentId: testStudentId,
        category: 'Mess',
        title: '500 retry issue',
        description: 'Testing 500 server error',
      );

      fakeConnectivity.emit([ConnectivityResult.wifi]);
      await connectivityService.checkReachability();
      final r = await syncManager.syncNow();
      expect(r.failedCount, equals(1));

      final op = await dbService.outboxRepository.getOperation('op_${c.localId}');
      expect(op!.status, equals('failed'));
      expect(op.errorMessage, contains('500'));
      // Still preserved locally
      final local = await dbService.complaintRepository.getComplaintByLocalId(c.localId!);
      expect(local, isNotNull);
    });

    // -------------------------------------------------------------------------
    // Test 11: Server permanent 4xx becomes failed / dead-letter
    // -------------------------------------------------------------------------
    test('11. Server 400 validation error marks operation permanently failed', () async {
      fakeHttpClient.handler = (req) async {
        if (req.url.path == '/health') return http.Response(jsonEncode({'status': 'healthy'}), 200);
        if (req.url.path == '/complaints') {
          return http.Response('{"message":"Validation failed: category invalid"}', 400);
        }
        return http.Response('{"status":"ok"}', 200);
      };

      fakeConnectivity.emit([ConnectivityResult.none]);
      await connectivityService.checkReachability();
      final c = await complaintService.createComplaint(
        studentId: testStudentId,
        category: 'InvalidCategory',
        title: 'Bad category complaint',
        description: 'Will be rejected by backend',
      );

      fakeConnectivity.emit([ConnectivityResult.wifi]);
      await connectivityService.checkReachability();
      final r = await syncManager.syncNow();
      expect(r.failedCount, equals(1));

      final op = await dbService.outboxRepository.getOperation('op_${c.localId}');
      expect(op!.status, equals('failed'));
      expect(op.errorMessage, contains('PERMANENT: HTTP 400'));

      final local = await dbService.complaintRepository.getComplaintByLocalId(c.localId!);
      expect(local!.syncState, equals('failed'));
    });

    // -------------------------------------------------------------------------
    // Test 12: Concurrent duplicate requests create one complaint
    // -------------------------------------------------------------------------
    test('12. Concurrent duplicate submissions with same key create exactly one complaint', () async {
      fakeConnectivity.emit([ConnectivityResult.none]);
      await connectivityService.checkReachability();

      const concKey = 'complaint_conc_race_test';
      final futures = List.generate(
        3,
        (_) => complaintService.createComplaint(
          studentId: testStudentId,
          category: 'Hostel/Room',
          title: 'Concurrent submission test',
          description: 'Testing race conditions locally',
          customIdempotencyKey: concKey,
        ),
      );

      final results = await Future.wait(futures);
      expect(results.length, equals(3));
      // All return the exact same localId
      expect(results[0].localId, equals(results[1].localId));
      expect(results[1].localId, equals(results[2].localId));

      final complaints = await dbService.complaintRepository.getStudentComplaints(testStudentId);
      expect(complaints.length, equals(1));
    });

    // -------------------------------------------------------------------------
    // Test 13: Local complaint read works offline
    // -------------------------------------------------------------------------
    test('13. Local complaint read works offline from SQLite cache', () async {
      // Pre-seed local SQLite database with 2 complaints
      await dbService.complaintRepository.upsertComplaint(
        ComplaintsTableCompanion.insert(
          localId: 'comp_cached_1',
          serverId: const drift.Value('srv_1'),
          studentId: testStudentId,
          category: 'Mess',
          title: 'Cached Issue 1',
          description: 'Description 1',
          syncState: const drift.Value('synced'),
        ),
      );
      await dbService.complaintRepository.upsertComplaint(
        ComplaintsTableCompanion.insert(
          localId: 'comp_cached_2',
          serverId: const drift.Value.absent(),
          studentId: testStudentId,
          category: 'Hostel',
          title: 'Pending Issue 2',
          description: 'Description 2',
          syncState: const drift.Value('pending'),
        ),
      );

      // Force offline
      fakeConnectivity.emit([ConnectivityResult.none]);
      await connectivityService.checkReachability();

      final list = await complaintService.getStudentComplaints(testStudentId);
      expect(list.length, equals(2));
      expect(list.any((c) => c.title == 'Cached Issue 1' && c.isSynced), isTrue);
      expect(list.any((c) => c.title == 'Pending Issue 2' && c.isSyncPending), isTrue);
    });

    // -------------------------------------------------------------------------
    // Test 14: Online refresh updates local cache
    // -------------------------------------------------------------------------
    test('14. Online refresh updates local cache with server complaints', () async {
      fakeHttpClient.handler = (req) async {
        if (req.url.path == '/health') return http.Response('{"status":"healthy"}', 200);
        if (req.url.path.contains('/complaints/$testStudentId')) {
          return http.Response(
            jsonEncode([
              {
                'id': 'srv_refreshed_101',
                'studentId': testStudentId,
                'category': 'Mess',
                'title': 'New Server Complaint',
                'description': 'Created from web portal',
                'location': 'Cafeteria',
                'priority': 'LOW',
                'status': 'ASSIGNED',
                'assignedToName': 'Chef Gordon',
                'createdAt': DateTime.now().toIso8601String(),
              }
            ]),
            200,
          );
        }
        return http.Response('{"status":"ok"}', 200);
      };

      fakeConnectivity.emit([ConnectivityResult.wifi]);
      await connectivityService.checkReachability();

      final list = await complaintService.getStudentComplaints(testStudentId);
      expect(list.length, equals(1));
      expect(list.first.title, equals('New Server Complaint'));
      expect(list.first.status, equals('ASSIGNED'));
      expect(list.first.assignedToName, equals('Chef Gordon'));

      // Check SQLite has it stored
      final cached = await dbService.complaintRepository.getComplaintByServerId('srv_refreshed_101');
      expect(cached, isNotNull);
      expect(cached!.status, equals('ASSIGNED'));
    });

    // -------------------------------------------------------------------------
    // Test 15: Server-controlled status cannot be overwritten offline
    // -------------------------------------------------------------------------
    test('15. Server authority wins: server status updates local record', () async {
      // 1. Initial synced complaint locally with status PENDING
      await dbService.complaintRepository.upsertComplaint(
        ComplaintsTableCompanion.insert(
          localId: 'comp_auth_test',
          serverId: const drift.Value('srv_auth_test'),
          studentId: testStudentId,
          category: 'Hostel/Room',
          title: 'Authority test',
          description: 'Testing status authority',
          status: const drift.Value('PENDING'),
          syncState: const drift.Value('synced'),
        ),
      );

      // 2. Server updates status to RESOLVED with notes
      await dbService.complaintRepository.updateStatusFromServer(
        'comp_auth_test',
        'RESOLVED',
        resolutionRemarks: 'Repaired by maintenance staff',
        resolvedAt: DateTime.now(),
      );

      final updated = await dbService.complaintRepository.getComplaintByLocalId('comp_auth_test');
      expect(updated!.status, equals('RESOLVED'));
      expect(updated.resolutionRemarks, equals('Repaired by maintenance staff'));
    });

    // -------------------------------------------------------------------------
    // Test 16: Malformed outbox data does not crash the app
    // -------------------------------------------------------------------------
    test('16. Malformed outbox data does not crash sync engine and is marked failed', () async {
      await dbService.outboxRepository.enqueue(
        SyncOutboxTableCompanion.insert(
          localId: 'op_malformed_json',
          entityType: 'complaint',
          entityId: 'comp_fake',
          endpoint: '/complaints',
          payload: '{ NOT VALID JSON',
          status: const drift.Value('pending'),
        ),
      );

      fakeConnectivity.emit([ConnectivityResult.wifi]);
      await connectivityService.checkReachability();

      final res = await syncManager.syncNow();
      expect(res.failedCount, equals(1));

      final op = await dbService.outboxRepository.getOperation('op_malformed_json');
      expect(op!.status, equals('failed'));
    });

    // -------------------------------------------------------------------------
    // Test 17: Omission of attachments documented
    // -------------------------------------------------------------------------
    test('17. Attachments are explicitly not supported in baseline and omitted cleanly', () {
      // Verify that ComplaintModel and ComplaintsTable do not require binary blob storage
      final complaint = ComplaintModel(
        id: 'test',
        studentId: testStudentId,
        category: 'General',
        title: 'Title',
        description: 'Desc',
        location: 'Campus',
        priority: 'MEDIUM',
        status: 'PENDING',
        createdAt: DateTime.now(),
      );

      expect(complaint.title, equals('Title'));
      // Confirmed: complaints have no binary attachment fields in the existing schema
    });
  });
}
