import 'package:drift/drift.dart';
import '../app_database.dart';

/// Lightweight persistence repository for the Sync Outbox table.
///
/// NOTE: This provides purely the persistence abstraction for queued offline operations.
/// Background processing, retry loops, network listeners, and sync orchestration are
/// intentionally deferred to Phase 4.
class LocalOutboxRepository {
  final AppDatabase _db;

  LocalOutboxRepository(this._db);

  /// Enqueue an item into the sync outbox.
  Future<void> enqueue(SyncOutboxTableCompanion item) async {
    await _db.into(_db.syncOutboxTable).insertOnConflictUpdate(item);
  }

  /// Alias for enqueue.
  Future<void> enqueueOperation(SyncOutboxTableCompanion item) => enqueue(item);

  /// Alias for getItemByLocalId.
  Future<LocalOutboxOperation?> getOperation(String localId) => getItemByLocalId(localId);

  /// Retrieve pending items sorted by creation time (FIFO).
  Future<List<LocalOutboxOperation>> peekPending({int limit = 50}) async {
    return (_db.select(_db.syncOutboxTable)
          ..where((tbl) => tbl.status.equals('pending') | tbl.status.equals('failed'))
          ..orderBy([(tbl) => OrderingTerm.asc(tbl.createdAt)])
          ..limit(limit))
        .get();
  }

  /// Mark an item as in-flight / attempting.
  Future<int> markInFlight(String localId) async {
    final item = await getItemByLocalId(localId);
    final attempts = (item?.attemptCount ?? 0) + 1;
    return (_db.update(_db.syncOutboxTable)
          ..where((tbl) => tbl.localId.equals(localId)))
        .write(
      SyncOutboxTableCompanion(
        status: const Value('in_flight'),
        attemptCount: Value(attempts),
        lastAttemptedAt: Value(DateTime.now()),
      ),
    );
  }

  /// Mark an item as successfully completed.
  Future<int> markCompleted(String localId) async {
    return (_db.update(_db.syncOutboxTable)
          ..where((tbl) => tbl.localId.equals(localId)))
        .write(
      const SyncOutboxTableCompanion(
        status: Value('completed'),
      ),
    );
  }

  /// Mark an item as failed with an error message.
  Future<int> markFailed(String localId, String errorMessage) async {
    return (_db.update(_db.syncOutboxTable)
          ..where((tbl) => tbl.localId.equals(localId)))
        .write(
      SyncOutboxTableCompanion(
        status: const Value('failed'),
        errorMessage: Value(errorMessage),
      ),
    );
  }

  /// Get item by its local UUID.
  Future<LocalOutboxOperation?> getItemByLocalId(String localId) async {
    return (_db.select(_db.syncOutboxTable)
          ..where((tbl) => tbl.localId.equals(localId)))
        .getSingleOrNull();
  }

  /// Get item by client idempotency key.
  Future<LocalOutboxOperation?> getItemByIdempotencyKey(String idempotencyKey) async {
    return (_db.select(_db.syncOutboxTable)
          ..where((tbl) => tbl.idempotencyKey.equals(idempotencyKey)))
        .getSingleOrNull();
  }

  /// Count number of pending outbox items.
  Future<int> countPending() async {
    final countExp = _db.syncOutboxTable.localId.count();
    final query = _db.selectOnly(_db.syncOutboxTable)
      ..addColumns([countExp])
      ..where(_db.syncOutboxTable.status.isNotValue('completed'));
    final result = await query.getSingle();
    return result.read(countExp) ?? 0;
  }

  /// Delete an outbox item.
  Future<int> deleteItem(String localId) async {
    return (_db.delete(_db.syncOutboxTable)
          ..where((tbl) => tbl.localId.equals(localId)))
        .go();
  }

  /// Resets interrupted in_flight records back to pending upon startup/recovery.
  Future<int> resetInFlightToPending() async {
    return (_db.update(_db.syncOutboxTable)
          ..where((tbl) => tbl.status.equals('in_flight')))
        .write(
      const SyncOutboxTableCompanion(
        status: Value('pending'),
      ),
    );
  }

  /// Mark multiple outbox items completed in a single write.
  Future<int> markCompletedBatch(List<String> localIds) async {
    if (localIds.isEmpty) return 0;
    return (_db.update(_db.syncOutboxTable)
          ..where((tbl) => tbl.localId.isIn(localIds)))
        .write(
      const SyncOutboxTableCompanion(
        status: Value('completed'),
      ),
    );
  }

  /// Mark an operation as permanent failure (dead-letter queue).
  Future<int> markPermanentFailure(String localId, String errorMessage) async {
    return (_db.update(_db.syncOutboxTable)
          ..where((tbl) => tbl.localId.equals(localId)))
        .write(
      SyncOutboxTableCompanion(
        status: const Value('failed'),
        errorMessage: Value('PERMANENT: $errorMessage'),
      ),
    );
  }
}
