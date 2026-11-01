import 'package:drift/drift.dart';

/// Local Sessions Table.
///
/// Encapsulates classroom attendance sessions created both online and offline.
/// Distinguishes between local client UUIDs and reconciled server UUIDs.
@DataClassName('LocalSession')
class SessionsTable extends Table {
  @override
  String get tableName => 'sessions';

  /// Client-generated unique identifier (UUID v4).
  TextColumn get localId => text()();

  /// Central backend session UUID (nullable for sessions created offline).
  TextColumn get serverId => text().nullable()();

  /// Faculty UID of the instructor.
  TextColumn get teacherId => text()();

  /// Optional link to normalized class catalog entry.
  TextColumn get classId => text().nullable()();

  /// Subject or session title (e.g. 'CS301 Distributed Systems').
  TextColumn get name => text()();

  /// Academic curriculum metadata.
  TextColumn get course => text().nullable()();
  TextColumn get branch => text().nullable()();
  TextColumn get year => text().nullable()();

  /// Classroom / lecture hall location.
  TextColumn get location => text().withDefault(const Constant('Room 204'))();

  /// Scheduled or actual session timestamps.
  DateTimeColumn get startTime => dateTime()();
  DateTimeColumn get endTime => dateTime()();

  /// Whether the session is currently broadcasting / collecting responses.
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();

  /// Ble broadcast transmit power setting (0: Low, 1: Medium, 2: High).
  IntColumn get txPowerLevel => integer().nullable()();

  /// Ephemeral session nonce generated for cryptographic challenge binding.
  TextColumn get sessionNonce => text().nullable()();

  /// Cumulative verified count.
  IntColumn get attendanceCount => integer().withDefault(const Constant(0))();

  /// Synchronization state with backend ('synced', 'pending_create', 'pending_stop').
  TextColumn get syncState => text().withDefault(const Constant('synced'))();

  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {localId};
}
