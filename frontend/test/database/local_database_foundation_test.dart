import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:attendance_app/core/database/database.dart';

void main() {
  late AppDatabase db;
  late DatabaseService dbService;

  setUpAll(() {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  });

  setUp(() {
    // Spin up an isolated in-memory SQLite database for each test
    db = AppDatabase.inMemory();
    dbService = DatabaseService.forTesting(db);
  });

  tearDown(() async {
    await dbService.close();
  });

  group('Phase 2 — Drift Local SQLite Database Foundation', () {
    test('1. Database opens cleanly and schema version is 1', () async {
      expect(db.schemaVersion, equals(1));
      // Verify PRAGMA foreign_keys is enabled
      final fkResult = await db.customSelect('PRAGMA foreign_keys;').getSingle();
      expect(fkResult.data.values.first, equals(1));
    });

    test('2. Students CRUD & read/update/delete operations work', () async {
      final rosterRepo = dbService.rosterRepository;

      // Create student
      await rosterRepo.upsertStudent(
        StudentsTableCompanion.insert(
          studentId: 'std-001',
          name: 'Debasish Rout',
          email: const Value('debasish@bput.ac.in'),
          rollNumber: const Value('220101001'),
          course: const Value('B.Tech'),
          branch: const Value('CSE'),
          year: const Value('3rd Year'),
          deviceKeyId: const Value('pubkey-hex-001'),
        ),
      );

      // Read student
      var student = await rosterRepo.getStudentById('std-001');
      expect(student, isNotNull);
      expect(student!.name, equals('Debasish Rout'));
      expect(student.rollNumber, equals('220101001'));
      expect(student.deviceKeyId, equals('pubkey-hex-001'));

      // Update student
      await rosterRepo.upsertStudent(
        const StudentsTableCompanion(
          studentId: Value('std-001'),
          name: Value('Debasish K. Rout'),
          email: Value('debasish.new@bput.ac.in'),
          rollNumber: Value('220101001'),
        ),
      );

      student = await rosterRepo.getStudentById('std-001');
      expect(student!.name, equals('Debasish K. Rout'));
      expect(student.email, equals('debasish.new@bput.ac.in'));

      // Delete student
      final deletedCount = await rosterRepo.deleteStudent('std-001');
      expect(deletedCount, equals(1));
      expect(await rosterRepo.getStudentById('std-001'), isNull);
    });

    test('3. Classes CRUD operations work', () async {
      final rosterRepo = dbService.rosterRepository;

      // Insert class
      await rosterRepo.upsertClass(
        ClassesTableCompanion.insert(
          classId: 'cls-cs301',
          name: 'Operating Systems',
          code: const Value('CS301'),
          course: const Value('B.Tech'),
          branch: const Value('CSE'),
          year: const Value('3rd Year'),
          room: const Value('Lab 3B'),
          teacherId: const Value('tch-prof-smith'),
        ),
      );

      // Read class
      var cls = await rosterRepo.getClassById('cls-cs301');
      expect(cls, isNotNull);
      expect(cls!.name, equals('Operating Systems'));
      expect(cls.code, equals('CS301'));
      expect(cls.room, equals('Lab 3B'));

      // Update class
      await rosterRepo.upsertClass(
        const ClassesTableCompanion(
          classId: Value('cls-cs301'),
          name: Value('Advanced Operating Systems'),
          code: Value('CS301'),
        ),
      );

      cls = await rosterRepo.getClassById('cls-cs301');
      expect(cls!.name, equals('Advanced Operating Systems'));

      // Delete class
      await rosterRepo.deleteClass('cls-cs301');
      expect(await rosterRepo.getClassById('cls-cs301'), isNull);
    });

    test('4. Enrollments & Class Roster relational queries work', () async {
      final rosterRepo = dbService.rosterRepository;

      // Seed 1 class and 3 students
      await rosterRepo.upsertClass(
        ClassesTableCompanion.insert(
          classId: 'cls-dbms',
          name: 'Database Management Systems',
          code: const Value('CS302'),
        ),
      );

      await rosterRepo.upsertStudents([
        StudentsTableCompanion.insert(
          studentId: 'std-alice',
          name: 'Alice Mohanty',
          email: const Value('alice@bput.ac.in'),
        ),
        StudentsTableCompanion.insert(
          studentId: 'std-bob',
          name: 'Bob Nayak',
          email: const Value('bob@bput.ac.in'),
        ),
        StudentsTableCompanion.insert(
          studentId: 'std-charlie',
          name: 'Charlie Das',
          email: const Value('charlie@bput.ac.in'),
        ),
      ]);

      // Enroll students into class
      await rosterRepo.enrollStudents('cls-dbms', [
        'std-alice',
        'std-bob',
        'std-charlie',
      ]);

      // Query enrolled students for class
      final enrolled = await rosterRepo.getStudentsForClass('cls-dbms');
      expect(enrolled.length, equals(3));
      final names = enrolled.map((s) => s.name).toSet();
      expect(names, containsAll(['Alice Mohanty', 'Bob Nayak', 'Charlie Das']));

      // Query classes for a student
      final studentClasses = await rosterRepo.getClassesForStudent('std-bob');
      expect(studentClasses.length, equals(1));
      expect(studentClasses.first.code, equals('CS302'));

      // Duplicate enrollment handling (unique constraint on classId + studentId)
      await rosterRepo.enrollStudent('cls-dbms', 'std-alice');
      final enrolledAfterDup = await rosterRepo.getStudentsForClass('cls-dbms');
      expect(enrolledAfterDup.length, equals(3));

      // Remove single enrollment
      await rosterRepo.removeEnrollment('cls-dbms', 'std-charlie');
      final remaining = await rosterRepo.getStudentsForClass('cls-dbms');
      expect(remaining.length, equals(2));
      expect(remaining.map((s) => s.studentId), isNot(contains('std-charlie')));
    });

    test('5. Session CRUD, local identifier stability, and sync state transition', () async {
      final sessionRepo = dbService.sessionRepository;
      final localUuid = 'sess-local-${DateTime.now().millisecondsSinceEpoch}';

      // 1. Create offline local session (serverId is null, syncState is 'pending')
      final now = DateTime.now();
      await sessionRepo.upsertSession(
        SessionsTableCompanion.insert(
          localId: localUuid,
          teacherId: 'teacher-101',
          name: 'Algorithms Lab Session',
          location: const Value('LH-101'),
          startTime: now,
          endTime: now.add(const Duration(hours: 1)),
          syncState: const Value('pending'),
        ),
      );

      // Verify local session exists
      var session = await sessionRepo.getSessionByLocalId(localUuid);
      expect(session, isNotNull);
      expect(session!.localId, equals(localUuid));
      expect(session.serverId, isNull);
      expect(session.syncState, equals('pending'));
      expect(session.isActive, isTrue);

      // 2. Later sync with backend: localId MUST remain stable, serverId is populated, syncState becomes 'synced'
      const assignedServerId = 'bput-server-sess-88990';
      await sessionRepo.updateSyncState(
        localUuid,
        'synced',
        serverId: assignedServerId,
      );

      session = await sessionRepo.getSessionByLocalId(localUuid);
      expect(session, isNotNull);
      expect(session!.localId, equals(localUuid)); // Local ID unchanged!
      expect(session.serverId, equals(assignedServerId)); // Server ID updated
      expect(session.syncState, equals('synced'));

      // Retrieve by server ID
      final sessionByServer = await sessionRepo.getSessionByServerId(assignedServerId);
      expect(sessionByServer, isNotNull);
      expect(sessionByServer!.localId, equals(localUuid));

      // Active sessions query
      final activeList = await sessionRepo.getActiveSessions(teacherId: 'teacher-101');
      expect(activeList.length, equals(1));

      // Deactivate session
      await sessionRepo.deactivateSession(localUuid);
      session = await sessionRepo.getSessionByLocalId(localUuid);
      expect(session!.isActive, isFalse);

      final activeAfterDeactivate = await sessionRepo.getActiveSessions(teacherId: 'teacher-101');
      expect(activeAfterDeactivate, isEmpty);
    });

    test('6. Attendance records CRUD, idempotency & duplicate constraints', () async {
      final sessionRepo = dbService.sessionRepository;
      final rosterRepo = dbService.rosterRepository;
      final attendanceRepo = dbService.attendanceRepository;

      const sessionId = 'sess-test-attendance-404';
      const studentId = 'std-uuid-555';
      const idempotencyKey = 'att_sess-test-attendance-404_key01_nonce99';

      // Seed parent session
      final now = DateTime.now();
      await sessionRepo.upsertSession(
        SessionsTableCompanion.insert(
          localId: sessionId,
          teacherId: 'tch-42',
          name: 'Physics Lecture',
          startTime: now,
          endTime: now.add(const Duration(hours: 1)),
        ),
      );

      // Seed student for foreign key integrity
      await rosterRepo.upsertStudent(
        StudentsTableCompanion.insert(
          studentId: studentId,
          name: 'Satyajit Mishra',
        ),
      );

      // 1. Insert attendance record
      await attendanceRepo.recordAttendance(
        AttendanceRecordsTableCompanion.insert(
          localId: 'att-rec-001',
          sessionId: sessionId,
          studentId: studentId,
          studentName: 'Satyajit Mishra',
          status: const Value('PRESENT'),
          checkInTime: now,
          idempotencyKey: idempotencyKey,
          deviceKeyId: const Value('dev-key-hex-44'),
          responseNonce: const Value('nonce99'),
          verificationMode: const Value('BLE_BATCH'),
          proximityTier: const Value('NEAR'),
          syncState: const Value('queued'),
        ),
      );

      // 2. Query record
      var record = await attendanceRepo.getAttendanceByLocalId('att-rec-001');
      expect(record, isNotNull);
      expect(record!.studentId, equals(studentId));
      expect(record.studentName, equals('Satyajit Mishra'));
      expect(record.verificationMode, equals('BLE_BATCH'));
      expect(record.proximityTier, equals('NEAR'));
      expect(record.syncState, equals('queued'));

      // Check student check-in helper
      expect(await attendanceRepo.hasStudentCheckedIn(sessionId, studentId), isTrue);
      expect(await attendanceRepo.hasStudentCheckedIn(sessionId, 'other-student'), isFalse);

      // 3. Duplicate protection test:
      // Inserting again with the same idempotency key updates on conflict without duplicating rows
      await attendanceRepo.recordAttendance(
        AttendanceRecordsTableCompanion.insert(
          localId: 'att-rec-001-dup',
          sessionId: sessionId,
          studentId: studentId,
          studentName: 'Satyajit Mishra',
          status: const Value('PRESENT'),
          checkInTime: now,
          idempotencyKey: idempotencyKey,
          syncState: const Value('queued'),
        ),
      );

      final records = await attendanceRepo.getAttendanceForSession(sessionId);
      // Still only 1 record because idempotency key conflict handled safely
      expect(records.length, equals(1));

      // 4. Update sync state
      await attendanceRepo.updateSyncState('att-rec-001', 'synced', serverId: 'srv-att-777');
      record = await attendanceRepo.getAttendanceByLocalId('att-rec-001');
      expect(record!.syncState, equals('synced'));
      expect(record.serverId, equals('srv-att-777'));

      // 5. Delete record
      await attendanceRepo.deleteRecord('att-rec-001');
      expect(await attendanceRepo.getAttendanceByLocalId('att-rec-001'), isNull);
    });

    test('7. Sync Outbox persistence foundation behaves correctly (FIFO & status)', () async {
      final outboxRepo = dbService.outboxRepository;

      // Enqueue 2 items
      await outboxRepo.enqueue(
        SyncOutboxTableCompanion.insert(
          localId: 'outbox-001',
          entityType: 'ATTENDANCE_RECORD',
          entityId: 'att-rec-001',
          endpoint: '/api/v1/attendance/batch-sync',
          method: const Value('POST'),
          payload: '{"student_id":"std-001","status":"PRESENT"}',
          idempotencyKey: const Value('idem-outbox-001'),
        ),
      );

      await outboxRepo.enqueue(
        SyncOutboxTableCompanion.insert(
          localId: 'outbox-002',
          entityType: 'SESSION_CREATE',
          entityId: 'sess-002',
          endpoint: '/api/v1/sessions',
          method: const Value('POST'),
          payload: '{"name":"Math Lab"}',
          idempotencyKey: const Value('idem-outbox-002'),
        ),
      );

      // Check pending count
      expect(await outboxRepo.countPending(), equals(2));

      // Peek pending (FIFO order)
      final pending = await outboxRepo.peekPending();
      expect(pending.length, equals(2));
      expect(pending.first.localId, equals('outbox-001'));
      expect(pending.last.localId, equals('outbox-002'));

      // Mark in-flight
      await outboxRepo.markInFlight('outbox-001');
      var item1 = await outboxRepo.getItemByLocalId('outbox-001');
      expect(item1!.status, equals('in_flight'));
      expect(item1.attemptCount, equals(1));
      expect(item1.lastAttemptedAt, isNotNull);

      // Mark completed
      await outboxRepo.markCompleted('outbox-001');
      item1 = await outboxRepo.getItemByLocalId('outbox-001');
      expect(item1!.status, equals('completed'));

      // Active pending count should now be 1
      expect(await outboxRepo.countPending(), equals(1));

      // Mark second item failed
      await outboxRepo.markFailed('outbox-002', '503 Service Unavailable');
      final item2 = await outboxRepo.getItemByLocalId('outbox-002');
      expect(item2!.status, equals('failed'));
      expect(item2.errorMessage, equals('503 Service Unavailable'));
    });

    test('8. End-to-End Realistic Workflow: Class -> Students -> Session -> Attendance', () async {
      final rosterRepo = dbService.rosterRepository;
      final sessionRepo = dbService.sessionRepository;
      final attendanceRepo = dbService.attendanceRepository;

      // 1. Create Class
      const classId = 'cls-iot-401';
      await rosterRepo.upsertClass(
        ClassesTableCompanion.insert(
          classId: classId,
          name: 'IoT & Embedded Systems Lab',
          code: const Value('IOT401'),
          teacherId: const Value('teacher-prof-pradhan'),
        ),
      );

      // 2. Enroll 3 students
      final students = [
        StudentsTableCompanion.insert(
          studentId: 'std-swastik',
          name: 'Swastik Sahoo',
          email: const Value('swastik@bput.ac.in'),
          rollNumber: const Value('220101010'),
          deviceKeyId: const Value('key-swastik'),
        ),
        StudentsTableCompanion.insert(
          studentId: 'std-sneha',
          name: 'Sneha Patnaik',
          email: const Value('sneha@bput.ac.in'),
          rollNumber: const Value('220101011'),
          deviceKeyId: const Value('key-sneha'),
        ),
        StudentsTableCompanion.insert(
          studentId: 'std-subham',
          name: 'Subham Jena',
          email: const Value('subham@bput.ac.in'),
          rollNumber: const Value('220101012'),
          deviceKeyId: const Value('key-subham'),
        ),
      ];
      await rosterRepo.upsertStudents(students);
      await rosterRepo.enrollStudents(classId, ['std-swastik', 'std-sneha', 'std-subham']);

      final rosterList = await rosterRepo.getStudentsForClass(classId);
      expect(rosterList.length, equals(3));

      // 3. Teacher starts an offline attendance session
      const sessionLocalId = 'sess-local-iot-today';
      final now = DateTime.now();
      await sessionRepo.upsertSession(
        SessionsTableCompanion.insert(
          localId: sessionLocalId,
          classId: const Value(classId),
          teacherId: 'teacher-prof-pradhan',
          name: 'IoT & Embedded Systems Lab - Practical 4',
          location: const Value('IoT Lab 2'),
          startTime: now,
          endTime: now.add(const Duration(hours: 2)),
          sessionNonce: const Value('random_beacon_nonce_123'),
          txPowerLevel: const Value(-12),
          syncState: const Value('pending'),
        ),
      );

      // 4. Students mark attendance offline:
      // Swastik verifies via BLE batch
      await attendanceRepo.recordAttendance(
        AttendanceRecordsTableCompanion.insert(
          localId: 'att-swastik-01',
          sessionId: sessionLocalId,
          studentId: 'std-swastik',
          studentName: 'Swastik Sahoo',
          status: const Value('PRESENT'),
          checkInTime: now,
          idempotencyKey: 'att_${sessionLocalId}_key-swastik_nonceA',
          deviceKeyId: const Value('key-swastik'),
          responseNonce: const Value('nonceA'),
          verificationMode: const Value('BLE_BATCH'),
          proximityTier: const Value('NEAR'),
          syncState: const Value('queued'),
        ),
      );
      await sessionRepo.incrementAttendanceCount(sessionLocalId);

      // Sneha verifies via QR Fallback
      await attendanceRepo.recordAttendance(
        AttendanceRecordsTableCompanion.insert(
          localId: 'att-sneha-01',
          sessionId: sessionLocalId,
          studentId: 'std-sneha',
          studentName: 'Sneha Patnaik',
          status: const Value('PRESENT'),
          checkInTime: now,
          idempotencyKey: 'att_${sessionLocalId}_key-sneha_nonceB',
          deviceKeyId: const Value('key-sneha'),
          responseNonce: const Value('nonceB'),
          verificationMode: const Value('QR_FALLBACK'),
          proximityTier: const Value('MANUAL'),
          syncState: const Value('queued'),
        ),
      );
      await sessionRepo.incrementAttendanceCount(sessionLocalId);

      // 5. Verify local session metrics and attendance count
      final session = await sessionRepo.getSessionByLocalId(sessionLocalId);
      expect(session!.attendanceCount, equals(2));

      final records = await attendanceRepo.getAttendanceForSession(sessionLocalId);
      expect(records.length, equals(2));

      final checkedInIds = records.map((r) => r.studentId).toSet();
      expect(checkedInIds, contains('std-swastik'));
      expect(checkedInIds, contains('std-sneha'));
      expect(checkedInIds, isNot(contains('std-subham'))); // Subham absent

      // Count for session
      expect(await attendanceRepo.countForSession(sessionLocalId), equals(2));

      // Retrieve pending records for future sync
      final pendingToSync = await attendanceRepo.getPendingRecords();
      expect(pendingToSync.length, equals(2));
    });

    test('9. Hard UNIQUE constraint on (sessionId, studentId) throws SqliteException under InsertMode.insert', () async {
      final rosterRepo = dbService.rosterRepository;
      final sessionRepo = dbService.sessionRepository;
      final attendanceRepo = dbService.attendanceRepository;

      const sid = 'sess-strict-unique';
      const stid = 'std-strict-unique';
      final now = DateTime.now();

      await sessionRepo.upsertSession(
        SessionsTableCompanion.insert(
          localId: sid,
          teacherId: 'tch-strict',
          name: 'Strict Session',
          startTime: now,
          endTime: now.add(const Duration(hours: 1)),
        ),
      );

      await rosterRepo.upsertStudent(
        StudentsTableCompanion.insert(
          studentId: stid,
          name: 'Strict Student',
        ),
      );

      // First insert succeeds
      await attendanceRepo.recordAttendance(
        AttendanceRecordsTableCompanion.insert(
          localId: 'att-first',
          sessionId: sid,
          studentId: stid,
          studentName: 'Strict Student',
          status: const Value('PRESENT'),
          checkInTime: now,
          idempotencyKey: 'idem-strict-1',
        ),
        mode: InsertMode.insert,
      );

      // Second raw insert with same (sessionId, studentId) MUST throw SqliteException (unique constraint)
      expect(
        () async => await attendanceRepo.recordAttendance(
          AttendanceRecordsTableCompanion.insert(
            localId: 'att-second',
            sessionId: sid,
            studentId: stid,
            studentName: 'Strict Student',
            status: const Value('PRESENT'),
            checkInTime: now,
            idempotencyKey: 'idem-strict-2',
          ),
          mode: InsertMode.insert,
        ),
        throwsA(isA<SqliteException>()),
      );
    });

    test('10. Foreign Key Cascading: Deleting a class cascades and removes enrollments', () async {
      final rosterRepo = dbService.rosterRepository;

      await rosterRepo.upsertClass(
        ClassesTableCompanion.insert(
          classId: 'cls-to-delete',
          name: 'Temporary Class',
        ),
      );

      await rosterRepo.upsertStudent(
        StudentsTableCompanion.insert(
          studentId: 'std-enrolled',
          name: 'Enrolled Student',
        ),
      );

      await rosterRepo.enrollStudent('cls-to-delete', 'std-enrolled');
      var enrolled = await rosterRepo.getStudentsForClass('cls-to-delete');
      expect(enrolled.length, equals(1));

      // Delete the parent class
      await rosterRepo.deleteClass('cls-to-delete');

      // The enrollment table must be clean via CASCADE delete
      final remainingEnrollments = await db.select(db.enrollmentsTable).get();
      expect(remainingEnrollments.where((e) => e.classId == 'cls-to-delete'), isEmpty);
    });

    test('11. Database survives closing and reopening with file persistence intact', () async {
      final tempDir = Directory.systemTemp.createTempSync('campusos_db_test_');
      final dbFile = File('${tempDir.path}/persistence_test.sqlite');

      try {
        // Open disk-backed database 1
        final diskDb1 = AppDatabase(NativeDatabase(dbFile));
        final service1 = DatabaseService.forTesting(diskDb1);

        // Insert student and session
        await service1.rosterRepository.upsertStudent(
          StudentsTableCompanion.insert(
            studentId: 'std-reopen-test',
            name: 'Reopen Tester',
          ),
        );

        final now = DateTime.now();
        await service1.sessionRepository.upsertSession(
          SessionsTableCompanion.insert(
            localId: 'sess-reopen-test',
            teacherId: 'tch-reopen',
            name: 'Reopen Class',
            startTime: now,
            endTime: now.add(const Duration(hours: 1)),
          ),
        );

        // Close connection 1 completely
        await service1.close();

        // Open disk-backed database 2 on the exact same SQLite file
        final diskDb2 = AppDatabase(NativeDatabase(dbFile));
        final service2 = DatabaseService.forTesting(diskDb2);

        // Verify data survived reopening completely
        final recoveredStudent = await service2.rosterRepository.getStudentById('std-reopen-test');
        expect(recoveredStudent, isNotNull);
        expect(recoveredStudent!.name, equals('Reopen Tester'));

        final recoveredSession = await service2.sessionRepository.getSessionByLocalId('sess-reopen-test');
        expect(recoveredSession, isNotNull);
        expect(recoveredSession!.name, equals('Reopen Class'));

        await service2.close();
      } finally {
        if (tempDir.existsSync()) {
          tempDir.deleteSync(recursive: true);
        }
      }
    });

    test('12. Reactive queries emit real-time stream updates', () async {
      final sessionRepo = dbService.sessionRepository;
      final now = DateTime.now();

      final expectation = expectLater(
        sessionRepo.watchAllSessions(),
        emitsThrough(hasLength(1)),
      );

      // Insert session
      await sessionRepo.upsertSession(
        SessionsTableCompanion.insert(
          localId: 'sess-stream-test',
          teacherId: 'tch-stream',
          name: 'Stream Test Session',
          startTime: now,
          endTime: now.add(const Duration(hours: 1)),
        ),
      );

      await expectation;
    });

    test('13. Migration framework configuration and version checks', () {
      expect(db.schemaVersion, equals(1));
      expect(db.migration, isNotNull);
      expect(db.migration.onCreate, isNotNull);
      expect(db.migration.onUpgrade, isNotNull);
      expect(db.migration.beforeOpen, isNotNull);
    });
  });
}
