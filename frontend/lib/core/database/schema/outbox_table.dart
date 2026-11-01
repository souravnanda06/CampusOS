import 'package:drift/drift.dart';

/// Local Sync Outbox Table.
///
/// Serves as the persistence foundation for asynchronous mutation queuing
/// and deterministic upstream synchronization (to be orchestrated in Phase 4).
@DataClassName('LocalOutboxOperation')
class SyncOutboxTable extends Table {
  @override
  String get tableName => 'sync_outbox';

  /// Client operation UUID.
  TextColumn get localId => text()();

  /// Entity category ('attendance', 'session').
  TextColumn get entityType => text()();

  /// Local identifier of the affected domain entity.
  TextColumn get entityId => text()();

  /// Target REST API endpoint path (e.g. '/attendance/batch-sync').
  TextColumn get endpoint => text()();

  /// HTTP verb ('POST', 'PUT', 'DELETE').
  TextColumn get method => text().withDefault(const Constant('POST'))();

  /// Serialized request body payload (canonical JSON string).
  TextColumn get payload => text()();

  /// Client idempotency key for network replay safety.
  TextColumn get idempotencyKey => text().nullable()();

  /// Creation timestamp.
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  /// Number of transmission attempts.
  IntColumn get attemptCount => integer().withDefault(const Constant(0))();

  /// Timestamp of the most recent transmission attempt.
  DateTimeColumn get lastAttemptedAt => dateTime().nullable()();

  /// Operation synchronization status ('pending', 'in_progress', 'completed', 'failed').
  TextColumn get status => text().withDefault(const Constant('pending'))();

  /// Last error message encountered during synchronization.
  TextColumn get errorMessage => text().nullable()();

  @override
  Set<Column> get primaryKey => {localId};
}
