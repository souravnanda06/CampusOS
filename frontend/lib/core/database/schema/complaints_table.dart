import 'package:drift/drift.dart';

/// Local Complaints Table (Drift / SQLite).
///
/// Persists student complaints locally for offline-first submission,
/// reliable transactional queuing, and cached reading.
@DataClassName('LocalComplaint')
class ComplaintsTable extends Table {
  @override
  String get tableName => 'complaints';

  /// Client primary key UUID.
  TextColumn get localId => text()();

  /// Server UUID once acknowledged.
  TextColumn get serverId => text().nullable()();

  /// Client idempotency key for network replay safety.
  TextColumn get idempotencyKey => text().nullable()();

  /// Associated student/user ID.
  TextColumn get studentId => text()();

  /// Category (e.g. 'Hostel/Room', 'Mess', etc.).
  TextColumn get category => text()();

  /// Issue title.
  TextColumn get title => text()();

  /// Issue detailed description.
  TextColumn get description => text()();

  /// Location on campus.
  TextColumn get location => text().withDefault(const Constant('Campus'))();

  /// Priority ('LOW', 'MEDIUM', 'HIGH', 'URGENT').
  TextColumn get priority => text().withDefault(const Constant('MEDIUM'))();

  /// Current workflow status ('PENDING', 'ASSIGNED', 'IN_PROGRESS', 'RESOLVED', 'CLOSED', 'REOPENED', 'REJECTED').
  TextColumn get status => text().withDefault(const Constant('PENDING'))();

  /// Local sync lifecycle state ('pending', 'synced', 'failed').
  TextColumn get syncState => text().withDefault(const Constant('pending'))();

  /// Staff ID assigned to resolve this issue.
  TextColumn get assignedTo => text().nullable()();

  /// Staff name assigned to resolve this issue.
  TextColumn get assignedToName => text().nullable()();

  /// Admin/Staff resolution notes or remarks.
  TextColumn get resolutionRemarks => text().nullable()();

  /// Timestamp when resolved.
  DateTimeColumn get resolvedAt => dateTime().nullable()();

  /// Local creation timestamp.
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  /// Server creation timestamp (when synced or cached from server).
  DateTimeColumn get serverCreatedAt => dateTime().nullable()();

  /// Last updated timestamp.
  DateTimeColumn get updatedAt => dateTime().nullable()();

  /// Repeat issue flag.
  BoolColumn get isRepeat => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {localId};
}
