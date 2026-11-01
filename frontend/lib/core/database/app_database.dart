import 'package:drift/drift.dart';
import 'connection/connection.dart';
import 'schema/sessions_table.dart';
import 'schema/students_table.dart';
import 'schema/classes_table.dart';
import 'schema/enrollments_table.dart';
import 'schema/attendance_table.dart';
import 'schema/outbox_table.dart';
import 'schema/complaints_table.dart';

part 'app_database.g.dart';

/// CampusOS Local Offline Database (Drift / SQLite).
///
/// Serves as the primary transactional persistence engine for offline-first operations.
@DriftDatabase(tables: [
  SessionsTable,
  StudentsTable,
  ClassesTable,
  EnrollmentsTable,
  AttendanceRecordsTable,
  SyncOutboxTable,
  ComplaintsTable,
])
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor]) : super(executor ?? openConnection());

  /// Convenience constructor for isolated in-memory test databases.
  AppDatabase.inMemory() : super(openConnection(inMemory: true));

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (Migrator m) async {
      await m.createAll();
    },
    onUpgrade: (Migrator m, int from, int to) async {
      if (from < 2) {
        // Phase 6 migration: Add complaints table
        await m.createTable(complaintsTable);
      }
    },
    beforeOpen: (details) async {
      // Enforce relational foreign key constraints in SQLite
      await customStatement('PRAGMA foreign_keys = ON;');
    },
  );
}
