import 'package:flutter/foundation.dart';
import 'app_database.dart';
import 'repositories/local_attendance_repository.dart';
import 'repositories/local_outbox_repository.dart';
import 'repositories/local_roster_repository.dart';
import 'repositories/local_session_repository.dart';
import 'repositories/local_complaint_repository.dart';

/// Central service managing the lifecycle and repositories
/// of the Drift SQLite local persistence layer.
///
/// Follows the architecture:
/// UI / Provider -> Repository -> AppDatabase (Drift) -> SQLite File
class DatabaseService {
  static DatabaseService? _instance;

  final AppDatabase _db;
  late final LocalSessionRepository _sessionRepository;
  late final LocalRosterRepository _rosterRepository;
  late final LocalAttendanceRepository _attendanceRepository;
  late final LocalOutboxRepository _outboxRepository;
  late final LocalComplaintRepository _complaintRepository;

  DatabaseService._(this._db) {
    _sessionRepository = LocalSessionRepository(_db);
    _rosterRepository = LocalRosterRepository(_db);
    _attendanceRepository = LocalAttendanceRepository(_db);
    _outboxRepository = LocalOutboxRepository(_db);
    _complaintRepository = LocalComplaintRepository(_db);
  }

  /// Global shared instance.
  /// Automatically initializes with default AppDatabase if not already initialized.
  static DatabaseService get instance {
    _instance ??= DatabaseService._(AppDatabase());
    return _instance!;
  }

  /// Initialize explicitly, optionally supplying a pre-configured AppDatabase.
  static DatabaseService initialize({AppDatabase? customDatabase}) {
    if (_instance != null && !kReleaseMode) {
      debugPrint('[DatabaseService] Re-initializing database instance');
    }
    _instance = DatabaseService._(customDatabase ?? AppDatabase());
    return _instance!;
  }

  /// Dedicated factory for isolated unit/integration tests with an in-memory database.
  factory DatabaseService.forTesting(AppDatabase testDb) {
    return DatabaseService._(testDb);
  }

  /// Underlying Drift database instance.
  AppDatabase get db => _db;

  /// Repository for session persistence.
  LocalSessionRepository get sessionRepository => _sessionRepository;

  /// Repository for student, class, and enrollment persistence.
  LocalRosterRepository get rosterRepository => _rosterRepository;

  /// Repository for offline attendance records.
  LocalAttendanceRepository get attendanceRepository => _attendanceRepository;

  /// Repository for queued outbox sync operations.
  LocalOutboxRepository get outboxRepository => _outboxRepository;

  /// Repository for offline complaints persistence.
  LocalComplaintRepository get complaintRepository => _complaintRepository;

  /// Close database connection safely.
  Future<void> close() async {
    await _db.close();
    if (identical(_instance, this)) {
      _instance = null;
    }
  }

  /// Reset singleton instance (primarily for tests).
  @visibleForTesting
  static Future<void> reset() async {
    if (_instance != null) {
      await _instance!.close();
      _instance = null;
    }
  }
}
