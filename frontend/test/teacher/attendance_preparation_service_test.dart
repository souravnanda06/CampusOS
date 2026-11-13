import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:http/http.dart' as http;
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:attendance_app/auth/models/user_model.dart';
import 'package:attendance_app/core/database/database.dart';
import 'package:attendance_app/core/network/connectivity_service.dart';
import 'package:attendance_app/shared/services/session_service.dart';
import 'package:attendance_app/student/models/passport_trust_bundle_model.dart';
import 'package:attendance_app/student/services/passport_trust_bundle_service.dart';
import 'package:attendance_app/student/models/passport_attendance_model.dart';
import 'package:attendance_app/student/models/passport_proximity_observation.dart';
import 'package:attendance_app/student/services/passport_attendance_ledger_service.dart';
import 'package:attendance_app/teacher/services/attendance_preparation_service.dart';

// ---------------------------------------------------------------------------
// FAKES & TEST DOUBLES
// ---------------------------------------------------------------------------

class FakeConnectivity implements Connectivity {
  final List<ConnectivityResult> _current;

  FakeConnectivity(this._current);

  @override
  Future<List<ConnectivityResult>> checkConnectivity() async => _current;

  @override
  Stream<List<ConnectivityResult>> get onConnectivityChanged =>
      Stream.value(_current);
}

class FakeHttpClient extends http.BaseClient {
  final Future<http.Response> Function(http.BaseRequest request) handler;

  FakeHttpClient(this.handler);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final response = await handler(request);
    return http.StreamedResponse(
      Stream.value(utf8.encode(response.body)),
      response.statusCode,
      headers: response.headers,
    );
  }
}

class MockTrustBundleService extends PassportTrustBundleService {
  bool hasBundle;
  bool downloadSucceeds;

  MockTrustBundleService({
    this.hasBundle = true,
    this.downloadSucceeds = true,
  });

  @override
  Future<bool> hasValidLocalBundle([int? currentTimestampSeconds]) async =>
      hasBundle;

  @override
  Future<PassportTrustBundle> downloadAndSaveBundle({int? ttlSeconds}) async {
    if (!downloadSucceeds) {
      throw PassportTrustBundleException('Network unreachable');
    }
    hasBundle = true;
    return const PassportTrustBundle(
      version: 1,
      issuerKeyId: 'root-key-1',
      generatedAt: 1000,
      expiresAt: 9999999999,
      institution: PassportInstitutionTrust(
        keyId: 'root-key-1',
        publicKey: 'inst-pubkey',
      ),
      identities: [],
      revokedKeyIds: [],
      signature: 'sig',
      rawPayload: {},
    );
  }
}

class MockSessionService extends SessionService {
  bool shouldFail;
  String generatedServerId;

  MockSessionService({
    this.shouldFail = false,
    this.generatedServerId = 'server-sess-uuid-789',
  });

  @override
  Future<String> createSession({
    required String name,
    required String instructorName,
    String? course,
    String? branch,
    String? year,
    required DateTime startTime,
    required DateTime endTime,
    required String location,
    int? txPowerLevel,
    double? latitude,
    double? longitude,
    double? radiusMeters,
  }) async {
    if (shouldFail) {
      throw Exception('Simulated cloud session creation failure');
    }
    return generatedServerId;
  }
}

// ---------------------------------------------------------------------------
// MAIN TEST SUITE
// ---------------------------------------------------------------------------

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late DatabaseService dbService;
  late LocalRosterRepository rosterRepo;
  late LocalSessionRepository sessionRepo;

  final testTeacher = UserModel(
    id: 'teacher-uid-101',
    name: 'Dr. Debasish Rout',
    email: 'drout@bput.ac.in',
    role: 'teacher',
  );

  setUpAll(() {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    db = AppDatabase.inMemory();
    dbService = DatabaseService.forTesting(db);
    rosterRepo = dbService.rosterRepository;
    sessionRepo = dbService.sessionRepository;
  });

  tearDown(() async {
    await dbService.close();
  });

  group('Phase 3 — Offline Attendance Data Preparation Tests', () {
    test('1. Class is cached correctly in local Drift database', () async {
      final prepService = AttendancePreparationService(
        sessionRepo: sessionRepo,
        rosterRepo: rosterRepo,
        trustBundleService: MockTrustBundleService(hasBundle: true),
      );

      await prepService.cacheClassRoster(
        classId: 'class-cs301',
        className: 'Operating Systems',
        teacherId: testTeacher.uid,
        course: 'B.Tech',
        branch: 'CSE',
        year: '3rd Year',
        room: 'Lab 4B',
        manualStudents: [
          {'id': 'std-1', 'name': 'Aditya', 'rollNumber': '220101'},
        ],
      );

      final cachedClass = await rosterRepo.getClassById('class-cs301');
      expect(cachedClass, isNotNull);
      expect(cachedClass!.name, equals('Operating Systems'));
      expect(cachedClass.course, equals('B.Tech'));
      expect(cachedClass.branch, equals('CSE'));
      expect(cachedClass.room, equals('Lab 4B'));
      expect(cachedClass.teacherId, equals(testTeacher.uid));
    });

    test('2. Students are cached correctly in local Drift database', () async {
      final prepService = AttendancePreparationService(
        sessionRepo: sessionRepo,
        rosterRepo: rosterRepo,
        trustBundleService: MockTrustBundleService(hasBundle: true),
      );

      await prepService.cacheClassRoster(
        classId: 'class-cs301',
        className: 'Operating Systems',
        teacherId: testTeacher.uid,
        course: 'B.Tech',
        branch: 'CSE',
        year: '3rd Year',
        manualStudents: [
          {
            'id': 'std-1',
            'name': 'Aditya Verma',
            'rollNumber': '220101001',
            'deviceKeyId': 'key-aditya-1',
          },
          {
            'id': 'std-2',
            'name': 'Priyanka Das',
            'rollNumber': '220101002',
            'deviceKeyId': 'key-priyanka-2',
          },
        ],
      );

      final student1 = await rosterRepo.getStudentById('std-1');
      final student2 = await rosterRepo.getStudentById('std-2');

      expect(student1, isNotNull);
      expect(student1!.name, equals('Aditya Verma'));
      expect(student1.rollNumber, equals('220101001'));
      expect(student1.deviceKeyId, equals('key-aditya-1'));

      expect(student2, isNotNull);
      expect(student2!.name, equals('Priyanka Das'));
      expect(student2.rollNumber, equals('220101002'));
      expect(student2.deviceKeyId, equals('key-priyanka-2'));
    });

    test('3. Enrollment relationships are cached correctly', () async {
      final prepService = AttendancePreparationService(
        sessionRepo: sessionRepo,
        rosterRepo: rosterRepo,
        trustBundleService: MockTrustBundleService(hasBundle: true),
      );

      await prepService.cacheClassRoster(
        classId: 'class-cs301',
        className: 'Operating Systems',
        teacherId: testTeacher.uid,
        manualStudents: [
          {'id': 'std-1', 'name': 'Aditya'},
          {'id': 'std-2', 'name': 'Priyanka'},
        ],
      );

      final enrolled = await rosterRepo.getStudentsForClass('class-cs301');
      expect(enrolled.length, equals(2));
      expect(enrolled.map((s) => s.studentId), containsAll(['std-1', 'std-2']));
    });

    test('4. Duplicate cache operation is idempotent and safe', () async {
      final prepService = AttendancePreparationService(
        sessionRepo: sessionRepo,
        rosterRepo: rosterRepo,
        trustBundleService: MockTrustBundleService(hasBundle: true),
      );

      final studentList = [
        {'id': 'std-1', 'name': 'Aditya Verma', 'rollNumber': '220101001'},
      ];

      // Run caching twice
      await prepService.cacheClassRoster(
        classId: 'class-cs301',
        className: 'Operating Systems',
        teacherId: testTeacher.uid,
        manualStudents: studentList,
      );

      await prepService.cacheClassRoster(
        classId: 'class-cs301',
        className: 'Operating Systems (Updated)',
        teacherId: testTeacher.uid,
        manualStudents: studentList,
      );

      final enrolled = await rosterRepo.getStudentsForClass('class-cs301');
      expect(enrolled.length, equals(1));

      final updatedClass = await rosterRepo.getClassById('class-cs301');
      expect(updatedClass!.name, equals('Operating Systems (Updated)'));
    });

    test('5. Offline roster query works without network connection', () async {
      final prepService = AttendancePreparationService(
        sessionRepo: sessionRepo,
        rosterRepo: rosterRepo,
        trustBundleService: MockTrustBundleService(hasBundle: true),
      );

      // Populate local SQLite database
      await prepService.cacheClassRoster(
        classId: 'class-ee101',
        className: 'Basic Electrical',
        teacherId: testTeacher.uid,
        manualStudents: [
          {'id': 'std-10', 'name': 'Rohan Tripathy', 'rollNumber': '220102010'},
          {'id': 'std-11', 'name': 'Sneha Sahu', 'rollNumber': '220102011'},
        ],
      );

      // Now query completely offline from Drift repository
      final offlineStudents = await rosterRepo.getStudentsForClass('class-ee101');
      expect(offlineStudents.length, equals(2));
      expect(offlineStudents[0].name, equals('Rohan Tripathy'));
      expect(offlineStudents[1].name, equals('Sneha Sahu'));
    });

    test('6. Session can be prepared locally when completely offline', () async {
      final connectivity = ConnectivityService.forTesting(
        connectivity: FakeConnectivity([ConnectivityResult.none]),
        httpClient: FakeHttpClient((_) async => http.Response('', 500)),
      );

      final prepService = AttendancePreparationService(
        sessionRepo: sessionRepo,
        rosterRepo: rosterRepo,
        trustBundleService: MockTrustBundleService(hasBundle: true),
        sessionService: MockSessionService(shouldFail: true),
        connectivityService: connectivity,
      );

      final localSession = await prepService.prepareSession(
        classId: 'class-cs301',
        teacher: testTeacher,
        subjectName: 'Computer Networks',
        forceOffline: true,
      );

      expect(localSession.localId, startsWith('sess_local_'));
      expect(localSession.serverId, isNull);
      expect(localSession.syncState, equals('pending'));
      expect(localSession.isActive, isTrue);
      expect(localSession.teacherId, equals(testTeacher.uid));
    });

    test('7. Local session ID remains stable across updates', () async {
      final prepService = AttendancePreparationService(
        sessionRepo: sessionRepo,
        rosterRepo: rosterRepo,
        trustBundleService: MockTrustBundleService(hasBundle: true),
      );

      final session = await prepService.prepareSession(
        classId: 'class-cs301',
        teacher: testTeacher,
        subjectName: 'Distributed Systems',
        forceOffline: true,
      );

      final originalLocalId = session.localId;

      // Update session status (deactivate)
      await sessionRepo.deactivateSession(originalLocalId);

      final fetched = await sessionRepo.getSessionByLocalId(originalLocalId);
      expect(fetched, isNotNull);
      expect(fetched!.localId, equals(originalLocalId));
      expect(fetched.isActive, isFalse);
    });

    test('8. Server ID can later be associated without changing local ID', () async {
      final prepService = AttendancePreparationService(
        sessionRepo: sessionRepo,
        rosterRepo: rosterRepo,
        trustBundleService: MockTrustBundleService(hasBundle: true),
      );

      final session = await prepService.prepareSession(
        classId: 'class-cs301',
        teacher: testTeacher,
        subjectName: 'Algorithms',
        forceOffline: true,
      );

      final originalLocalId = session.localId;
      expect(session.serverId, isNull);
      expect(session.syncState, equals('pending'));

      // Simulate Phase 4 sync association: server ID received after synchronization
      await sessionRepo.updateSyncState(
        originalLocalId,
        'synced',
        serverId: 'srv-sess-777',
      );

      final syncedSession = await sessionRepo.getSessionByLocalId(originalLocalId);
      expect(syncedSession, isNotNull);
      expect(syncedSession!.localId, equals(originalLocalId));
      expect(syncedSession.serverId, equals('srv-sess-777'));
      expect(syncedSession.syncState, equals('synced'));
    });

    test('9. Missing roster produces explicit PreparationStatus.missingRoster failure', () async {
      final offlineConn = ConnectivityService.forTesting(
        connectivity: FakeConnectivity([ConnectivityResult.none]),
        httpClient: FakeHttpClient((_) async => http.Response('', 500)),
      );

      final prepService = AttendancePreparationService(
        sessionRepo: sessionRepo,
        rosterRepo: rosterRepo,
        trustBundleService: MockTrustBundleService(hasBundle: true),
        connectivityService: offlineConn,
      );

      // Attempt to prepare a class with NO cached roster while offline
      final result = await prepService.prepareAttendance(
        classId: 'uncached-class-999',
        subjectName: 'Cloud Computing',
        teacher: testTeacher,
        forceOffline: true,
      );

      expect(result.status, equals(PreparationStatus.missingRoster));
      expect(result.isOfflineReady, isFalse);
      expect(result.isReady, isFalse);
      expect(result.message, contains('Connect to campus Wi-Fi'));
    });

    test('10. Missing trust bundle produces explicit PreparationStatus.missingTrustBundle failure', () async {
      final offlineConn = ConnectivityService.forTesting(
        connectivity: FakeConnectivity([ConnectivityResult.none]),
        httpClient: FakeHttpClient((_) async => http.Response('', 500)),
      );

      final prepService = AttendancePreparationService(
        sessionRepo: sessionRepo,
        rosterRepo: rosterRepo,
        trustBundleService: MockTrustBundleService(
          hasBundle: false,
          downloadSucceeds: false,
        ),
        connectivityService: offlineConn,
      );

      final result = await prepService.prepareAttendance(
        classId: 'class-cs301',
        subjectName: 'Operating Systems',
        teacher: testTeacher,
        forceOffline: true,
      );

      expect(result.status, equals(PreparationStatus.missingTrustBundle));
      expect(result.isOfflineReady, isFalse);
      expect(result.isReady, isFalse);
      expect(result.message, contains('trust bundle is missing or expired'));
    });

    test('11. Existing attendance offline flow remains functional with prepared local session', () async {
      final prepService = AttendancePreparationService(
        sessionRepo: sessionRepo,
        rosterRepo: rosterRepo,
        trustBundleService: MockTrustBundleService(hasBundle: true),
      );

      // Pre-cache roster
      await prepService.cacheClassRoster(
        classId: 'class-cs301',
        className: 'Database Engineering',
        teacherId: testTeacher.uid,
        manualStudents: [
          {'id': 'std-99', 'name': 'Rahul Mishra', 'rollNumber': '220101099'},
        ],
      );

      // Prepare attendance session
      final prepResult = await prepService.prepareAttendance(
        classId: 'class-cs301',
        subjectName: 'Database Engineering',
        teacher: testTeacher,
        forceOffline: true,
      );

      expect(prepResult.status, equals(PreparationStatus.ready));
      expect(prepResult.isOfflineReady, isTrue);
      expect(prepResult.session, isNotNull);

      // Convert prepared LocalSession to SessionModel using adaptor
      final sessionModel = AttendancePreparationService.toSessionModel(prepResult.session!, testTeacher);
      expect(sessionModel.id, equals(prepResult.session!.localId));
      expect(sessionModel.name, equals('Database Engineering'));

      // Use offline ledger to record offline attendance against the prepared session
      final ledger = PassportAttendanceLedgerService();
      await ledger.clearQueue();

      final verificationResult = PassportAttendanceVerificationResult(
        valid: true,
        status: PassportAttendanceStatus.verifiedPresent,
        reason: 'Verified present via BLE_BATCH with offline prepared roster',
        studentId: 'std-99',
        studentName: 'Rahul Mishra',
        deviceKeyId: 'key-rahul-01',
        sessionId: sessionModel.id,
        responseNonce: 'nonce-prep-001',
        idempotencyKey: 'att_${sessionModel.id}_key-rahul-01_nonce-prep-001',
        proximityTier: PassportProximityTier.near,
        verificationMode: 'BLE_BATCH',
        verifiedAt: DateTime.parse('2026-10-01T10:30:00Z'),
      );

      final recorded = await ledger.recordAttendance(verificationResult);
      expect(recorded, isTrue);

      // Verify the record is in the offline ledger queue
      final queued = await ledger.getQueuedRecords(sessionModel.id);
      expect(queued.length, equals(1));
      expect(queued.first['studentId'], equals('std-99'));
      expect(queued.first['sessionId'], equals(sessionModel.id));
      expect(queued.first['idempotencyKey'], equals(verificationResult.idempotencyKey));
      expect(queued.first['proximityTier'], equals('NEAR'));

      // Verify SharedPreferences baseline queue persistence remains intact
      final prefs = await SharedPreferences.getInstance();
      final queueKey = 'campus_os.attendance.queue.${sessionModel.id}';
      final queueList = prefs.getStringList(queueKey);
      expect(queueList, isNotNull);
      expect(queueList!.length, equals(1));

      final firstRecord = jsonDecode(queueList.first) as Map<String, dynamic>;
      expect(firstRecord['studentId'], equals('std-99'));
      expect(firstRecord['sessionId'], equals(sessionModel.id));
    });
  });
}
