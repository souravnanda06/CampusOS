import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

import 'emergency_audit_event.dart';

/// Isolated local database repository for immutable emergency incident audit trails.
///
/// Uses Drift / SQLite NativeDatabase with append-only semantics. Records are
/// never mutated or deleted by cancellation or expiration operations.
class EmergencyAuditRepository {
  static const int defaultMaxRetention = 500;

  final QueryExecutor _executor;
  final int maxRetention;
  bool _isInitialized = false;

  final StreamController<String> _auditUpdateController =
      StreamController<String>.broadcast();

  EmergencyAuditRepository({
    QueryExecutor? executor,
    this.maxRetention = defaultMaxRetention,
  }) : _executor = executor ??
            LazyDatabase(() async {
              final dbFolder = await getApplicationDocumentsDirectory();
              final file = File(p.join(dbFolder.path, 'campus_mesh_emergency.sqlite'));
              return NativeDatabase.createInBackground(file);
            });

  /// In-memory factory for isolated unit and widget tests.
  factory EmergencyAuditRepository.inMemory({int maxRetention = defaultMaxRetention}) {
    return EmergencyAuditRepository(
      executor: NativeDatabase.memory(),
      maxRetention: maxRetention,
    );
  }

  /// Initializes the SQLite audit table and indexes.
  Future<void> initialize() async {
    if (_isInitialized) return;

    await _executor.ensureOpen(_AuditExecutorUser());

    await _executor.runCustom('''
      CREATE TABLE IF NOT EXISTS mesh_emergency_audit_events (
        event_id TEXT PRIMARY KEY,
        incident_id TEXT NOT NULL,
        timestamp INTEGER NOT NULL,
        event_type TEXT NOT NULL,
        actor_device_id TEXT,
        actor_user_id TEXT,
        actor_role TEXT,
        hop_count INTEGER,
        verification_state TEXT,
        details TEXT
      );
    ''');

    await _executor.runCustom('''
      CREATE INDEX IF NOT EXISTS idx_mesh_emergency_audit_incident 
      ON mesh_emergency_audit_events(incident_id, timestamp ASC);
    ''');

    _isInitialized = true;
  }

  /// Appends an immutable audit event to local storage.
  Future<void> recordEvent(EmergencyAuditEvent event) async {
    await initialize();

    await _executor.runInsert(
      '''
      INSERT INTO mesh_emergency_audit_events (
        event_id, incident_id, timestamp, event_type,
        actor_device_id, actor_user_id, actor_role,
        hop_count, verification_state, details
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
      ''',
      [
        event.eventId,
        event.incidentId,
        event.timestamp.millisecondsSinceEpoch,
        event.eventType.code,
        event.actorDeviceId,
        event.actorUserId,
        event.actorRole,
        event.hopCount,
        event.verificationState,
        jsonEncode(event.details),
      ],
    );

    await _enforceRetentionLimit();

    if (!_auditUpdateController.isClosed) {
      _auditUpdateController.add(event.incidentId);
    }
  }

  /// Retrieves all recorded audit events for a specific [incidentId] in chronological order.
  Future<List<EmergencyAuditEvent>> getEventsForIncident(String incidentId) async {
    await initialize();

    final rows = await _executor.runSelect(
      '''
      SELECT * FROM mesh_emergency_audit_events
      WHERE incident_id = ?
      ORDER BY timestamp ASC
      ''',
      [incidentId],
    );

    return rows.map(_rowToEvent).toList();
  }

  /// Retrieves recent audit events across all incidents up to [limit].
  Future<List<EmergencyAuditEvent>> getAllEvents({int limit = 200}) async {
    await initialize();

    final rows = await _executor.runSelect(
      '''
      SELECT * FROM mesh_emergency_audit_events
      ORDER BY timestamp DESC
      LIMIT ?
      ''',
      [limit],
    );

    return rows.map(_rowToEvent).toList();
  }

  /// Reactive stream of audit events for a specific [incidentId].
  Stream<List<EmergencyAuditEvent>> watchEventsForIncident(String incidentId) async* {
    yield await getEventsForIncident(incidentId);
    yield* _auditUpdateController.stream
        .where((id) => id == incidentId)
        .asyncMap((_) => getEventsForIncident(incidentId));
  }

  Future<void> _enforceRetentionLimit() async {
    final countResult = await _executor.runSelect(
      'SELECT COUNT(*) as cnt FROM mesh_emergency_audit_events',
      [],
    );
    final count = countResult.first['cnt'] as int? ?? 0;
    if (count > maxRetention) {
      final excess = count - maxRetention;
      await _executor.runDelete(
        '''
        DELETE FROM mesh_emergency_audit_events
        WHERE event_id IN (
          SELECT event_id FROM mesh_emergency_audit_events
          ORDER BY timestamp ASC
          LIMIT ?
        )
        ''',
        [excess],
      );
    }
  }

  EmergencyAuditEvent _rowToEvent(Map<String, dynamic> row) {
    Map<String, dynamic> details = {};
    final rawDetails = row['details'] as String?;
    if (rawDetails != null && rawDetails.isNotEmpty) {
      try {
        details = Map<String, dynamic>.from(jsonDecode(rawDetails));
      } catch (_) {}
    }

    return EmergencyAuditEvent(
      eventId: row['event_id'] as String,
      incidentId: row['incident_id'] as String,
      timestamp: DateTime.fromMillisecondsSinceEpoch(row['timestamp'] as int),
      eventType: EmergencyAuditEventType.fromCode(row['event_type'] as String),
      actorDeviceId: row['actor_device_id'] as String?,
      actorUserId: row['actor_user_id'] as String?,
      actorRole: row['actor_role'] as String?,
      hopCount: row['hop_count'] as int?,
      verificationState: row['verification_state'] as String?,
      details: details,
    );
  }

  Future<void> close() async {
    if (!_auditUpdateController.isClosed) {
      _auditUpdateController.close();
    }
    await _executor.close();
  }
}

class _AuditExecutorUser extends QueryExecutorUser {
  @override
  int get schemaVersion => 1;

  @override
  Future<void> beforeOpen(QueryExecutor executor, OpeningDetails details) async {}
}
