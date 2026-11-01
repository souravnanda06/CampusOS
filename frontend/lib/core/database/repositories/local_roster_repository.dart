import 'package:drift/drift.dart';
import '../app_database.dart';

/// Lightweight repository for managing Student, Class, and Enrollment records
/// in the local Drift SQLite database.
class LocalRosterRepository {
  final AppDatabase _db;

  LocalRosterRepository(this._db);

  // ---------------------------------------------------------------------------
  // Student operations
  // ---------------------------------------------------------------------------

  /// Upsert a single student into SQLite.
  Future<void> upsertStudent(StudentsTableCompanion student) async {
    await _db.into(_db.studentsTable).insertOnConflictUpdate(student);
  }

  /// Bulk upsert multiple students inside a single transaction.
  Future<void> upsertStudents(List<StudentsTableCompanion> students) async {
    await _db.batch((batch) {
      batch.insertAllOnConflictUpdate(_db.studentsTable, students);
    });
  }

  /// Retrieve a student by studentId.
  Future<LocalStudent?> getStudentById(String studentId) async {
    return (_db.select(_db.studentsTable)
          ..where((tbl) => tbl.studentId.equals(studentId)))
        .getSingleOrNull();
  }

  /// Retrieve all students.
  Future<List<LocalStudent>> getAllStudents() async {
    return _db.select(_db.studentsTable).get();
  }

  // ---------------------------------------------------------------------------
  // Class / Course operations
  // ---------------------------------------------------------------------------

  /// Upsert a class into SQLite.
  Future<void> upsertClass(ClassesTableCompanion cls) async {
    await _db.into(_db.classesTable).insertOnConflictUpdate(cls);
  }

  /// Bulk upsert multiple classes inside a transaction.
  Future<void> upsertClasses(List<ClassesTableCompanion> classes) async {
    await _db.batch((batch) {
      batch.insertAllOnConflictUpdate(_db.classesTable, classes);
    });
  }

  /// Retrieve a class by its classId.
  Future<LocalClass?> getClassById(String classId) async {
    return (_db.select(_db.classesTable)
          ..where((tbl) => tbl.classId.equals(classId)))
        .getSingleOrNull();
  }

  /// Retrieve all classes, optionally filtered by teacher.
  Future<List<LocalClass>> getAllClasses({String? teacherId}) async {
    final query = _db.select(_db.classesTable);
    if (teacherId != null) {
      query.where((tbl) => tbl.teacherId.equals(teacherId));
    }
    return query.get();
  }

  // ---------------------------------------------------------------------------
  // Enrollment operations
  // ---------------------------------------------------------------------------

  /// Enroll a student in a class.
  Future<void> enrollStudent(String classId, String studentId) async {
    await _db.into(_db.enrollmentsTable).insertOnConflictUpdate(
          EnrollmentsTableCompanion.insert(
            id: '${classId}_$studentId',
            classId: classId,
            studentId: studentId,
          ),
        );
  }

  /// Enroll multiple students in a class.
  Future<void> enrollStudents(String classId, List<String> studentIds) async {
    await _db.batch((batch) {
      final entries = studentIds
          .map(
            (sid) => EnrollmentsTableCompanion.insert(
              id: '${classId}_$sid',
              classId: classId,
              studentId: sid,
            ),
          )
          .toList();
      batch.insertAllOnConflictUpdate(_db.enrollmentsTable, entries);
    });
  }

  /// Get all students enrolled in a specific class.
  Future<List<LocalStudent>> getStudentsForClass(String classId) async {
    final query = _db.select(_db.studentsTable).join([
      innerJoin(
        _db.enrollmentsTable,
        _db.enrollmentsTable.studentId.equalsExp(_db.studentsTable.studentId),
      ),
    ])..where(_db.enrollmentsTable.classId.equals(classId));

    final rows = await query.get();
    return rows.map((row) => row.readTable(_db.studentsTable)).toList();
  }

  /// Get all classes a student is enrolled in.
  Future<List<LocalClass>> getClassesForStudent(String studentId) async {
    final query = _db.select(_db.classesTable).join([
      innerJoin(
        _db.enrollmentsTable,
        _db.enrollmentsTable.classId.equalsExp(_db.classesTable.classId),
      ),
    ])..where(_db.enrollmentsTable.studentId.equals(studentId));

    final rows = await query.get();
    return rows.map((row) => row.readTable(_db.classesTable)).toList();
  }

  /// Remove a student's enrollment from a class.
  Future<int> removeEnrollment(String classId, String studentId) async {
    return (_db.delete(_db.enrollmentsTable)
          ..where((tbl) =>
              tbl.classId.equals(classId) & tbl.studentId.equals(studentId)))
        .go();
  }

  /// Delete student by studentId.
  Future<int> deleteStudent(String studentId) async {
    return (_db.delete(_db.studentsTable)
          ..where((tbl) => tbl.studentId.equals(studentId)))
        .go();
  }

  /// Delete class by classId.
  Future<int> deleteClass(String classId) async {
    return (_db.delete(_db.classesTable)
          ..where((tbl) => tbl.classId.equals(classId)))
        .go();
  }
}
