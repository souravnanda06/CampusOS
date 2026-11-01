import 'package:drift/drift.dart';

/// Local Classes / Course Catalog Table.
///
/// Stores curriculum classes and assigned subject metadata for offline selection.
@DataClassName('LocalClass')
class ClassesTable extends Table {
  @override
  String get tableName => 'classes';

  /// Class identifier (e.g. 'class_cs301' or UUID).
  TextColumn get classId => text()();

  /// Subject / course display name (e.g. 'Distributed Systems').
  TextColumn get name => text()();

  /// Subject code (e.g. 'CS301').
  TextColumn get code => text().nullable()();

  /// Academic curriculum metadata.
  TextColumn get course => text().nullable()();
  TextColumn get branch => text().nullable()();
  TextColumn get year => text().nullable()();

  /// Assigned lecture hall or classroom.
  TextColumn get room => text().nullable()();

  /// Assigned teacher UID.
  TextColumn get teacherId => text().nullable()();

  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {classId};
}
