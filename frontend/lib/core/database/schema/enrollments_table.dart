import 'package:drift/drift.dart';
import 'classes_table.dart';
import 'students_table.dart';

/// Local Enrollments / Class Roster Table.
///
/// Normalizes the student roster for each class, enabling offline roster verification.
@DataClassName('LocalEnrollment')
class EnrollmentsTable extends Table {
  @override
  String get tableName => 'enrollments';

  /// Primary enrollment UUID.
  TextColumn get id => text()();

  /// Target class identifier.
  TextColumn get classId => text().references(ClassesTable, #classId, onDelete: KeyAction.cascade)();

  /// Enrolled student identifier.
  TextColumn get studentId => text().references(StudentsTable, #studentId, onDelete: KeyAction.cascade)();

  /// Enrollment timestamp.
  DateTimeColumn get enrolledAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};

  @override
  List<Set<Column>> get uniqueKeys => [
    {classId, studentId},
  ];
}
