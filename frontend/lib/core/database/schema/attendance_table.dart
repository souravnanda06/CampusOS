import 'package:drift/drift.dart';
import 'sessions_table.dart';
import 'students_table.dart';

/// Local Attendance Records Ledger Table.
///
/// Provides ACID-compliant transactional persistence for attendance check-ins.
/// Enforces uniqueness constraints on idempotencyKey and (sessionId, studentId).
@DataClassName('LocalAttendanceRecord')
class AttendanceRecordsTable extends Table {
  @override
  String get tableName => 'attendance_records';

  /// Client-generated unique identifier (UUID v4).
  TextColumn get localId => text()();

  /// Central backend attendance record UUID (nullable until confirmed by batch-sync).
  TextColumn get serverId => text().nullable()();

  /// Parent session local identifier.
  TextColumn get sessionId => text().references(SessionsTable, #localId, onDelete: KeyAction.cascade)();

  /// Verified student identifier.
  TextColumn get studentId => text().references(StudentsTable, #studentId, onDelete: KeyAction.cascade)();

  /// Snapshot of student display name.
  TextColumn get studentName => text()();

  /// Attendance status ('present', 'absent', 'inconclusive').
  TextColumn get status => text().withDefault(const Constant('present'))();

  /// Timestamp when verification occurred.
  DateTimeColumn get checkInTime => dateTime()();

  /// Deterministic idempotency key: 'att_${sessionId}_${deviceKeyId}_${responseNonce}'.
  TextColumn get idempotencyKey => text()();

  /// Cryptographic device identity key ID used to sign the response.
  TextColumn get deviceKeyId => text().nullable()();

  /// Student challenge response nonce.
  TextColumn get responseNonce => text().nullable()();

  /// Verification mechanism ('BLE_BATCH', 'QR_FALLBACK', 'MANUAL').
  TextColumn get verificationMode => text().withDefault(const Constant('BLE_BATCH'))();

  /// Proximity tier ('NEAR', 'FAR', 'FALLBACK_VERIFIED').
  TextColumn get proximityTier => text().nullable()();

  /// Synchronization state with backend ('pending', 'synced', 'failed').
  TextColumn get syncState => text().withDefault(const Constant('pending'))();

  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {localId};

  @override
  List<Set<Column>> get uniqueKeys => [
    {idempotencyKey},
    {sessionId, studentId},
  ];
}
