import 'dart:async';
import 'dart:io';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

import '../emergency_alert.dart';
import 'emergency_incident.dart';

/// Isolated local database repository managing institutional emergency incidents,
/// active dispatch states, telemetry updates, and history retention.
class MeshEmergencyDispatcherRepository {
  static const int defaultMaxRetention = 200;

  final QueryExecutor _executor;
  final int maxRetention;
  bool _isInitialized = false;

  final StreamController<List<EmergencyIncident>> _incidentsUpdateController =
      StreamController<List<EmergencyIncident>>.broadcast();

  MeshEmergencyDispatcherRepository({
    QueryExecutor? executor,
    this.maxRetention = defaultMaxRetention,
  }) : _executor = executor ??
            LazyDatabase(() async {
              final dbFolder = await getApplicationDocumentsDirectory();
              final file = File(p.join(dbFolder.path, 'campus_mesh_emergency.sqlite'));
              return NativeDatabase.createInBackground(file);
            });

  /// In-memory factory for isolated unit and widget tests.
  factory MeshEmergencyDispatcherRepository.inMemory({int maxRetention = defaultMaxRetention}) {
    return MeshEmergencyDispatcherRepository(
      executor: NativeDatabase.memory(),
      maxRetention: maxRetention,
    );
  }

  /// Initializes the SQLite incident table and indexes.
  Future<void> initialize() async {
    if (_isInitialized) return;

    await _executor.ensureOpen(_IncidentExecutorUser());

    await _executor.runCustom('''
      CREATE TABLE IF NOT EXISTS mesh_emergency_incidents (
        incident_id TEXT PRIMARY KEY,
        alert_id TEXT NOT NULL,
        title TEXT NOT NULL,
        message TEXT NOT NULL,
        category TEXT NOT NULL,
        severity TEXT NOT NULL,
        priority TEXT NOT NULL,
        scope TEXT NOT NULL,
        issuer_device_id TEXT NOT NULL,
        issuer_user_id TEXT,
        issuer_role TEXT NOT NULL,
        created_at INTEGER NOT NULL,
        expires_at INTEGER NOT NULL,
        cancelled_at INTEGER,
        cancel_reason TEXT,
        cancelled_by_device_id TEXT,
        cancelled_by_role TEXT,
        status TEXT NOT NULL,
        hop_count INTEGER NOT NULL DEFAULT 0,
        relay_count INTEGER NOT NULL DEFAULT 1,
        local_delivery_count INTEGER NOT NULL DEFAULT 0,
        acknowledgement_count INTEGER NOT NULL DEFAULT 0,
        last_propagation_at INTEGER,
        signature_verification_state TEXT NOT NULL DEFAULT 'TRUSTED',
        siren_enabled INTEGER NOT NULL DEFAULT 0,
        siren_pattern TEXT NOT NULL DEFAULT 'none'
      );
    ''');

    await _ensureIncidentSirenColumns();

    await _executor.runCustom('''
      CREATE INDEX IF NOT EXISTS idx_mesh_incident_status_expiry 
      ON mesh_emergency_incidents(status, expires_at DESC);
    ''');

    await _executor.runCustom('''
      CREATE INDEX IF NOT EXISTS idx_mesh_incident_created 
      ON mesh_emergency_incidents(created_at DESC);
    ''');

    _isInitialized = true;
  }

  /// Saves a new emergency incident or updates an existing one.
  Future<void> saveIncident(EmergencyIncident incident) async {
    await initialize();

    final existing = await getIncident(incident.incidentId);
    if (existing != null) {
      await _executor.runUpdate(
        '''
        UPDATE mesh_emergency_incidents
        SET title = ?, message = ?, category = ?, severity = ?, priority = ?,
            scope = ?, expires_at = ?, cancelled_at = ?, cancel_reason = ?,
            cancelled_by_device_id = ?, cancelled_by_role = ?, status = ?,
            hop_count = ?, relay_count = ?, local_delivery_count = ?,
            acknowledgement_count = ?, last_propagation_at = ?,
            signature_verification_state = ?, siren_enabled = ?, siren_pattern = ?
        WHERE incident_id = ?
        ''',
        [
          incident.title,
          incident.message,
          incident.category.name,
          incident.severity.name,
          incident.priority.code,
          incident.scope,
          incident.expiresAt.millisecondsSinceEpoch,
          incident.cancelledAt?.millisecondsSinceEpoch,
          incident.cancelReason,
          incident.cancelledByDeviceId,
          incident.cancelledByRole,
          incident.status.name,
          incident.hopCount,
          incident.relayCount,
          incident.localDeliveryCount,
          incident.acknowledgementCount,
          incident.lastPropagationAt?.millisecondsSinceEpoch,
          incident.signatureVerificationState,
          incident.sirenEnabled ? 1 : 0,
          incident.sirenPattern.code,
          incident.incidentId,
        ],
      );
    } else {
      await _executor.runInsert(
        '''
        INSERT INTO mesh_emergency_incidents (
          incident_id, alert_id, title, message, category, severity,
          priority, scope, issuer_device_id, issuer_user_id, issuer_role,
          created_at, expires_at, cancelled_at, cancel_reason,
          cancelled_by_device_id, cancelled_by_role, status,
          hop_count, relay_count, local_delivery_count,
          acknowledgement_count, last_propagation_at, signature_verification_state,
          siren_enabled, siren_pattern
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        ''',
        [
          incident.incidentId,
          incident.alertId,
          incident.title,
          incident.message,
          incident.category.name,
          incident.severity.name,
          incident.priority.code,
          incident.scope,
          incident.issuerDeviceId,
          incident.issuerUserId,
          incident.issuerRole,
          incident.createdAt.millisecondsSinceEpoch,
          incident.expiresAt.millisecondsSinceEpoch,
          incident.cancelledAt?.millisecondsSinceEpoch,
          incident.cancelReason,
          incident.cancelledByDeviceId,
          incident.cancelledByRole,
          incident.status.name,
          incident.hopCount,
          incident.relayCount,
          incident.localDeliveryCount,
          incident.acknowledgementCount,
          incident.lastPropagationAt?.millisecondsSinceEpoch,
          incident.signatureVerificationState,
          incident.sirenEnabled ? 1 : 0,
          incident.sirenPattern.code,
        ],
      );
    }

    await _enforceRetentionLimit();
    _notifyIncidentsChanged();
  }

  /// Retrieves an incident by its unique [incidentId].
  Future<EmergencyIncident?> getIncident(String incidentId) async {
    await initialize();
    final rows = await _executor.runSelect(
      'SELECT * FROM mesh_emergency_incidents WHERE incident_id = ? LIMIT 1',
      [incidentId],
    );
    if (rows.isEmpty) return null;
    return _rowToIncident(rows.first);
  }

  /// Retrieves an incident by its underlying mesh packet / alert ID [alertId].
  Future<EmergencyIncident?> getIncidentByAlertId(String alertId) async {
    await initialize();
    final rows = await _executor.runSelect(
      'SELECT * FROM mesh_emergency_incidents WHERE alert_id = ? LIMIT 1',
      [alertId],
    );
    if (rows.isEmpty) return null;
    return _rowToIncident(rows.first);
  }

  /// Retrieves all currently active incidents.
  Future<List<EmergencyIncident>> getActiveIncidents([DateTime? now]) async {
    await initialize();
    final currentEpoch = (now ?? DateTime.now()).millisecondsSinceEpoch;

    final rows = await _executor.runSelect(
      '''
      SELECT * FROM mesh_emergency_incidents
      WHERE status IN ('active', 'partiallyPropagated', 'dispatching')
        AND expires_at > ?
      ORDER BY 
        CASE severity
          WHEN 'critical' THEN 1
          WHEN 'warning' THEN 2
          ELSE 3
        END ASC,
        created_at DESC
      ''',
      [currentEpoch],
    );

    return rows.map(_rowToIncident).toList();
  }

  /// Retrieves all historical and active incidents up to [limit].
  Future<List<EmergencyIncident>> getAllIncidents({int limit = 100}) async {
    await initialize();
    final rows = await _executor.runSelect(
      '''
      SELECT * FROM mesh_emergency_incidents
      ORDER BY created_at DESC
      LIMIT ?
      ''',
      [limit],
    );
    return rows.map(_rowToIncident).toList();
  }

  /// Reactive stream of currently active emergency incidents.
  Stream<List<EmergencyIncident>> watchActiveIncidents([DateTime? now]) async* {
    yield await getActiveIncidents(now);
    yield* _incidentsUpdateController.stream.asyncMap((_) => getActiveIncidents(now));
  }

  /// Marks an incident as cancelled with authoritative metadata.
  Future<bool> markCancelled(
    String incidentId, {
    required DateTime cancelledAt,
    String? reason,
    String? cancelledByDeviceId,
    String? cancelledByRole,
  }) async {
    await initialize();
    final updated = await _executor.runUpdate(
      '''
      UPDATE mesh_emergency_incidents
      SET status = 'cancelled',
          cancelled_at = ?,
          cancel_reason = ?,
          cancelled_by_device_id = ?,
          cancelled_by_role = ?
      WHERE incident_id = ? AND status != 'cancelled'
      ''',
      [
        cancelledAt.millisecondsSinceEpoch,
        reason,
        cancelledByDeviceId,
        cancelledByRole,
        incidentId,
      ],
    );

    if (updated > 0) {
      _notifyIncidentsChanged();
      return true;
    }
    return false;
  }

  /// Marks an incident as expired.
  Future<bool> markExpired(String incidentId) async {
    await initialize();
    final updated = await _executor.runUpdate(
      '''
      UPDATE mesh_emergency_incidents
      SET status = 'expired'
      WHERE incident_id = ? AND status != 'cancelled' AND status != 'expired'
      ''',
      [incidentId],
    );

    if (updated > 0) {
      _notifyIncidentsChanged();
      return true;
    }
    return false;
  }

  /// Updates propagation telemetry (hop count, relay count, delivery count).
  Future<void> updatePropagationTelemetry(
    String incidentId, {
    int? hopCount,
    int? relayCountIncrement,
    int? deliveryCountIncrement,
    DateTime? lastPropagationAt,
  }) async {
    await initialize();

    final existing = await getIncident(incidentId);
    if (existing == null) return;

    final newHop = hopCount != null && (existing.hopCount == 0 || hopCount < existing.hopCount)
        ? hopCount
        : existing.hopCount;
    final newRelay = existing.relayCount + (relayCountIncrement ?? 0);
    final newDelivery = existing.localDeliveryCount + (deliveryCountIncrement ?? 0);
    final propTime = lastPropagationAt ?? DateTime.now();

    await _executor.runUpdate(
      '''
      UPDATE mesh_emergency_incidents
      SET hop_count = ?,
          relay_count = ?,
          local_delivery_count = ?,
          last_propagation_at = ?
      WHERE incident_id = ?
      ''',
      [
        newHop,
        newRelay,
        newDelivery,
        propTime.millisecondsSinceEpoch,
        incidentId,
      ],
    );

    _notifyIncidentsChanged();
  }

  /// Increments the verified acknowledgement count for an incident.
  Future<void> incrementAcknowledgementCount(String incidentId) async {
    await initialize();
    await _executor.runUpdate(
      '''
      UPDATE mesh_emergency_incidents
      SET acknowledgement_count = acknowledgement_count + 1,
          last_propagation_at = ?
      WHERE incident_id = ?
      ''',
      [DateTime.now().millisecondsSinceEpoch, incidentId],
    );

    _notifyIncidentsChanged();
  }

  /// Checks whether an identical active incident was dispatched within [cooldown] window.
  Future<EmergencyIncident?> findRecentDuplicate({
    required String title,
    required String message,
    required String scope,
    Duration cooldown = const Duration(seconds: 15),
  }) async {
    await initialize();
    final cutoffEpoch = DateTime.now().subtract(cooldown).millisecondsSinceEpoch;

    final rows = await _executor.runSelect(
      '''
      SELECT * FROM mesh_emergency_incidents
      WHERE title = ? AND message = ? AND scope = ? AND created_at >= ?
      LIMIT 1
      ''',
      [title.trim(), message.trim(), scope.trim().toLowerCase(), cutoffEpoch],
    );

    if (rows.isEmpty) return null;
    return _rowToIncident(rows.first);
  }

  Future<void> _enforceRetentionLimit() async {
    final countResult = await _executor.runSelect(
      'SELECT COUNT(*) as cnt FROM mesh_emergency_incidents',
      [],
    );
    final count = countResult.first['cnt'] as int? ?? 0;
    if (count > maxRetention) {
      final excess = count - maxRetention;
      await _executor.runDelete(
        '''
        DELETE FROM mesh_emergency_incidents
        WHERE incident_id IN (
          SELECT incident_id FROM mesh_emergency_incidents
          WHERE status IN ('expired', 'cancelled', 'failed')
          ORDER BY created_at ASC
          LIMIT ?
        )
        ''',
        [excess],
      );
    }
  }

  void _notifyIncidentsChanged() {
    if (!_incidentsUpdateController.isClosed) {
      getActiveIncidents().then((incidents) {
        if (!_incidentsUpdateController.isClosed) {
          _incidentsUpdateController.add(incidents);
        }
      });
    }
  }

  EmergencyIncident _rowToIncident(Map<String, dynamic> row) {
    final catName = row['category']?.toString() ?? 'other';
    final sevName = row['severity']?.toString() ?? 'advisory';
    final priCode = row['priority']?.toString() ?? 'h';
    final statusName = row['status']?.toString() ?? 'active';

    final category = EmergencyCategory.tryFromCode(catName) ?? EmergencyCategory.other;
    final severity = EmergencySeverity.tryFromCode(sevName) ?? EmergencySeverity.advisory;
    final priority = EmergencyRelayPriority.fromCode(priCode);
    final status = EmergencyIncidentStatus.fromString(statusName);

    return EmergencyIncident(
      incidentId: row['incident_id'] as String,
      alertId: row['alert_id'] as String,
      title: row['title'] as String,
      message: row['message'] as String,
      category: category,
      severity: severity,
      priority: priority,
      scope: row['scope'] as String,
      issuerDeviceId: row['issuer_device_id'] as String,
      issuerUserId: row['issuer_user_id'] as String?,
      issuerRole: row['issuer_role'] as String,
      createdAt: DateTime.fromMillisecondsSinceEpoch(row['created_at'] as int),
      expiresAt: DateTime.fromMillisecondsSinceEpoch(row['expires_at'] as int),
      cancelledAt: row['cancelled_at'] != null
          ? DateTime.fromMillisecondsSinceEpoch(row['cancelled_at'] as int)
          : null,
      cancelReason: row['cancel_reason'] as String?,
      cancelledByDeviceId: row['cancelled_by_device_id'] as String?,
      cancelledByRole: row['cancelled_by_role'] as String?,
      status: status,
      hopCount: row['hop_count'] as int? ?? 0,
      relayCount: row['relay_count'] as int? ?? 1,
      localDeliveryCount: row['local_delivery_count'] as int? ?? 0,
      acknowledgementCount: row['acknowledgement_count'] as int? ?? 0,
      lastPropagationAt: row['last_propagation_at'] != null
          ? DateTime.fromMillisecondsSinceEpoch(row['last_propagation_at'] as int)
          : null,
      signatureVerificationState:
          row['signature_verification_state'] as String? ?? 'TRUSTED',
      sirenEnabled: (row['siren_enabled'] as int? ?? 0) == 1,
      sirenPattern: EmergencySirenPattern.fromCode(
        row['siren_pattern']?.toString(),
      ),
    );
  }

  Future<void> _ensureIncidentSirenColumns() async {
    try {
      final cols = await _executor.runSelect(
        'PRAGMA table_info(mesh_emergency_incidents)',
        [],
      );
      final colNames = cols.map((c) => c['name']?.toString()).toSet();
      if (!colNames.contains('siren_enabled')) {
        await _executor.runCustom(
          'ALTER TABLE mesh_emergency_incidents ADD COLUMN siren_enabled INTEGER NOT NULL DEFAULT 0',
        );
      }
      if (!colNames.contains('siren_pattern')) {
        await _executor.runCustom(
          "ALTER TABLE mesh_emergency_incidents ADD COLUMN siren_pattern TEXT NOT NULL DEFAULT 'none'",
        );
      }
    } catch (_) {}
  }

  Future<void> close() async {
    if (!_incidentsUpdateController.isClosed) {
      _incidentsUpdateController.close();
    }
    await _executor.close();
  }
}

class _IncidentExecutorUser extends QueryExecutorUser {
  @override
  int get schemaVersion => 1;

  @override
  Future<void> beforeOpen(QueryExecutor executor, OpeningDetails details) async {}
}
