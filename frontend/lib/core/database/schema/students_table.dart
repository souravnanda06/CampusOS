import 'package:drift/drift.dart';

/// Local Students Directory Table.
///
/// Stores student identity and academic profiles cached for offline roster resolution.
@DataClassName('LocalStudent')
class StudentsTable extends Table {
  @override
  String get tableName => 'students';

  /// Primary student identifier (UUID or registration UID).
  TextColumn get studentId => text()();

  /// Student display name.
  TextColumn get name => text()();

  /// Institutional email.
  TextColumn get email => text().nullable()();

  /// University registration number / roll number.
  TextColumn get rollNumber => text().nullable()();

  /// Academic curriculum attributes.
  TextColumn get course => text().nullable()();
  TextColumn get branch => text().nullable()();
  TextColumn get year => text().nullable()();

  /// Registered Passport public key identifier for cryptographic authentication.
  TextColumn get deviceKeyId => text().nullable()();

  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {studentId};
}
