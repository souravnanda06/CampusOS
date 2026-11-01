import 'package:drift/drift.dart';
import '../app_database.dart';

/// Lightweight repository for managing Session records in the local Drift SQLite database.
class LocalSessionRepository {
  final AppDatabase _db;

  LocalSessionRepository(this._db);

  /// Upsert a session into local SQLite.
  /// If a session with the same [localId] exists, updates the record.
  Future<void> upsertSession(SessionsTableCompanion session) async {
    await _db.into(_db.sessionsTable).insertOnConflictUpdate(session);
  }

  /// Retrieve a session by its unique local identifier.
  Future<LocalSession?> getSessionByLocalId(String localId) async {
    return (_db.select(_db.sessionsTable)
          ..where((tbl) => tbl.localId.equals(localId)))
        .getSingleOrNull();
  }

  /// Retrieve a session by its backend server ID.
  Future<LocalSession?> getSessionByServerId(String serverId) async {
    return (_db.select(_db.sessionsTable)
          ..where((tbl) => tbl.serverId.equals(serverId)))
        .getSingleOrNull();
  }

  /// Get all active sessions, optionally filtered by teacher.
  Future<List<LocalSession>> getActiveSessions({String? teacherId}) async {
    final query = _db.select(_db.sessionsTable)
      ..where((tbl) => tbl.isActive.equals(true));
    if (teacherId != null) {
      query.where((tbl) => tbl.teacherId.equals(teacherId));
    }
    query.orderBy([(tbl) => OrderingTerm.desc(tbl.startTime)]);
    final list = await query.get();
    final now = DateTime.now();
    return list.where((s) => s.endTime.isAfter(now)).toList();
  }

  /// Get all sessions, optionally filtered by teacher.
  Future<List<LocalSession>> getAllSessions({String? teacherId}) async {
    final query = _db.select(_db.sessionsTable);
    if (teacherId != null) {
      query.where((tbl) => tbl.teacherId.equals(teacherId));
    }
    query.orderBy([(tbl) => OrderingTerm.desc(tbl.createdAt)]);
    return query.get();
  }

  /// Update the synchronization state and optional backend server ID of a local session.
  Future<int> updateSyncState(
    String localId,
    String syncState, {
    String? serverId,
  }) async {
    return (_db.update(_db.sessionsTable)
          ..where((tbl) => tbl.localId.equals(localId)))
        .write(
      SessionsTableCompanion(
        syncState: Value(syncState),
        serverId: serverId != null ? Value(serverId) : const Value.absent(),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  /// Mark a session inactive.
  Future<int> deactivateSession(String localId) async {
    return (_db.update(_db.sessionsTable)
          ..where((tbl) => tbl.localId.equals(localId)))
        .write(
      SessionsTableCompanion(
        isActive: const Value(false),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  /// Increment attendance count on a session.
  Future<void> incrementAttendanceCount(String localId) async {
    final session = await getSessionByLocalId(localId);
    if (session != null) {
      await (_db.update(_db.sessionsTable)
            ..where((tbl) => tbl.localId.equals(localId)))
          .write(
        SessionsTableCompanion(
          attendanceCount: Value(session.attendanceCount + 1),
          updatedAt: Value(DateTime.now()),
        ),
      );
    }
  }

  /// Delete a session by local ID.
  Future<int> deleteSession(String localId) async {
    return (_db.delete(_db.sessionsTable)
          ..where((tbl) => tbl.localId.equals(localId)))
        .go();
  }

  /// Reactive stream of sessions.
  Stream<List<LocalSession>> watchAllSessions({String? teacherId}) {
    final query = _db.select(_db.sessionsTable);
    if (teacherId != null) {
      query.where((tbl) => tbl.teacherId.equals(teacherId));
    }
    query.orderBy([(tbl) => OrderingTerm.desc(tbl.createdAt)]);
    return query.watch();
  }

  /// Transactionally creates an offline session and enqueues its reconciliation outbox operation.
  /// If either fails, both are rolled back atomically (Phase 4C).
  Future<void> createOfflineSessionWithOutbox({
    required SessionsTableCompanion session,
    required SyncOutboxTableCompanion outboxItem,
  }) async {
    await _db.transaction(() async {
      await _db.into(_db.sessionsTable).insertOnConflictUpdate(session);
      await _db.into(_db.syncOutboxTable).insertOnConflictUpdate(outboxItem);
    });
  }
}
