import 'package:drift/drift.dart';
import '../app_database.dart';

/// Lightweight repository for managing local attendance record persistence in SQLite.
class LocalAttendanceRepository {
  final AppDatabase _db;

  LocalAttendanceRepository(this._db);

  /// Record a single attendance entry into local SQLite.
  /// If the record already exists (e.g. matching idempotencyKey or sessionId+studentId),
  /// the duplicate insert is ignored and the original record is preserved.
  Future<int> recordAttendance(
    AttendanceRecordsTableCompanion record, {
    InsertMode mode = InsertMode.insertOrIgnore,
  }) async {
    return _db.into(_db.attendanceRecordsTable).insert(record, mode: mode);
  }

  /// Bulk insert attendance records inside a transaction.
  Future<void> recordAttendanceBatch(
    List<AttendanceRecordsTableCompanion> records, {
    InsertMode mode = InsertMode.insertOrIgnore,
  }) async {
    await _db.batch((batch) {
      batch.insertAll(_db.attendanceRecordsTable, records, mode: mode);
    });
  }

  /// Retrieve all attendance records for a specific session.
  Future<List<LocalAttendanceRecord>> getAttendanceForSession(
    String sessionId,
  ) async {
    return (_db.select(_db.attendanceRecordsTable)
          ..where((tbl) => tbl.sessionId.equals(sessionId))
          ..orderBy([(tbl) => OrderingTerm.desc(tbl.checkInTime)]))
        .get();
  }

  /// Retrieve an attendance record by its local UUID.
  Future<LocalAttendanceRecord?> getAttendanceByLocalId(String localId) async {
    return (_db.select(_db.attendanceRecordsTable)
          ..where((tbl) => tbl.localId.equals(localId)))
        .getSingleOrNull();
  }

  /// Retrieve an attendance record by client idempotency key.
  Future<LocalAttendanceRecord?> getAttendanceByIdempotencyKey(
    String idempotencyKey,
  ) async {
    return (_db.select(_db.attendanceRecordsTable)
          ..where((tbl) => tbl.idempotencyKey.equals(idempotencyKey)))
        .getSingleOrNull();
  }

  /// Check whether a student has already been marked for a given session.
  Future<bool> hasStudentCheckedIn(String sessionId, String studentId) async {
    final record = await (_db.select(_db.attendanceRecordsTable)
          ..where((tbl) =>
              tbl.sessionId.equals(sessionId) &
              tbl.studentId.equals(studentId)))
        .getSingleOrNull();
    return record != null;
  }

  /// Count attendance records for a session.
  Future<int> countForSession(String sessionId) async {
    final countExp = _db.attendanceRecordsTable.localId.count();
    final query = _db.selectOnly(_db.attendanceRecordsTable)
      ..addColumns([countExp])
      ..where(_db.attendanceRecordsTable.sessionId.equals(sessionId));
    final result = await query.getSingle();
    return result.read(countExp) ?? 0;
  }

  /// Retrieve pending unsynced attendance records.
  Future<List<LocalAttendanceRecord>> getPendingRecords({
    int limit = 100,
  }) async {
    return (_db.select(_db.attendanceRecordsTable)
          ..where((tbl) => tbl.syncState.isNotValue('synced'))
          ..orderBy([(tbl) => OrderingTerm.asc(tbl.checkInTime)])
          ..limit(limit))
        .get();
  }

  /// Update synchronization status and optional server ID.
  Future<int> updateSyncState(
    String localId,
    String syncState, {
    String? serverId,
  }) async {
    return (_db.update(_db.attendanceRecordsTable)
          ..where((tbl) => tbl.localId.equals(localId)))
        .write(
      AttendanceRecordsTableCompanion(
        syncState: Value(syncState),
        serverId: serverId != null ? Value(serverId) : const Value.absent(),
      ),
    );
  }

  /// Batch update sync state for multiple records.
  Future<void> updateSyncStateBatch(
    List<String> localIds,
    String syncState,
  ) async {
    await (_db.update(_db.attendanceRecordsTable)
          ..where((tbl) => tbl.localId.isIn(localIds)))
        .write(
      AttendanceRecordsTableCompanion(
        syncState: Value(syncState),
      ),
    );
  }

  /// Delete a record by local ID.
  Future<int> deleteRecord(String localId) async {
    return (_db.delete(_db.attendanceRecordsTable)
          ..where((tbl) => tbl.localId.equals(localId)))
        .go();
  }

  /// Reactive stream of attendance records for a session.
  Stream<List<LocalAttendanceRecord>> watchAttendanceForSession(
    String sessionId,
  ) {
    return (_db.select(_db.attendanceRecordsTable)
          ..where((tbl) => tbl.sessionId.equals(sessionId))
          ..orderBy([(tbl) => OrderingTerm.desc(tbl.checkInTime)]))
        .watch();
  }

  /// Transactionally records an attendance entry and enqueues a sync outbox operation.
  /// If either write fails, both are rolled back atomically (Phase 4C).
  Future<void> recordAttendanceWithOutbox({
    required AttendanceRecordsTableCompanion attendance,
    required SyncOutboxTableCompanion outboxItem,
  }) async {
    await _db.transaction(() async {
      await _db.into(_db.attendanceRecordsTable).insert(
        attendance,
        mode: InsertMode.insertOrIgnore,
      );
      await _db.into(_db.syncOutboxTable).insertOnConflictUpdate(outboxItem);
    });
  }

  /// Transactionally records a batch of attendance entries and outbox operations.
  Future<void> recordAttendanceBatchWithOutbox({
    required List<AttendanceRecordsTableCompanion> attendances,
    required List<SyncOutboxTableCompanion> outboxItems,
  }) async {
    await _db.transaction(() async {
      for (final att in attendances) {
        await _db.into(_db.attendanceRecordsTable).insert(
          att,
          mode: InsertMode.insertOrIgnore,
        );
      }
      for (final item in outboxItems) {
        await _db.into(_db.syncOutboxTable).insertOnConflictUpdate(item);
      }
    });
  }
}
