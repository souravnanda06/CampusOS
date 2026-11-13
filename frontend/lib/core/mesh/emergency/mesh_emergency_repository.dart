import 'dart:async';
import 'dart:io';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

import 'emergency_alert.dart';

/// Isolated local database repository for CampusOS Mesh Emergency Disaster Flares.
///
/// Uses Drift / SQLite NativeDatabase with bounded alert retention and audit history.
/// Completely isolated from main application and passport schemas.
class MeshEmergencyRepository {
  /// Maximum number of emergency alerts retained locally to prevent unbounded growth.
  static const int defaultMaxRetention = 200;

  final QueryExecutor _executor;
  final int maxRetention;
  bool _isInitialized = false;

  final StreamController<List<EmergencyAlert>> _alertsUpdateController =
      StreamController<List<EmergencyAlert>>.broadcast();

  MeshEmergencyRepository({
    QueryExecutor? executor,
    this.maxRetention = defaultMaxRetention,
  }) : _executor = executor ??
            LazyDatabase(() async {
              final dbFolder = await getApplicationDocumentsDirectory();
              final file = File(p.join(dbFolder.path, 'campus_mesh_emergency.sqlite'));
              return NativeDatabase.createInBackground(file);
            });

  /// Creates an in-memory repository instance for fast, isolated unit and widget testing.
  factory MeshEmergencyRepository.inMemory({int maxRetention = defaultMaxRetention}) {
    return MeshEmergencyRepository(
      executor: NativeDatabase.memory(),
      maxRetention: maxRetention,
    );
  }

  /// Initializes the SQLite table and indexes if not already created.
  Future<void> initialize() async {
    if (_isInitialized) return;

    await _executor.ensureOpen(_EmergencyExecutorUser());

    await _executor.runCustom('''
      CREATE TABLE IF NOT EXISTS mesh_emergency_alerts (
        alert_id TEXT PRIMARY KEY,
        issuer_device_id TEXT NOT NULL,
        issuer_user_id TEXT,
        issuer_role TEXT NOT NULL,
        scope TEXT NOT NULL,
        severity TEXT NOT NULL,
        category TEXT NOT NULL,
        title TEXT NOT NULL,
        message TEXT NOT NULL,
        created_at INTEGER NOT NULL,
        expires_at INTEGER NOT NULL,
        first_seen_at INTEGER NOT NULL,
        last_seen_at INTEGER NOT NULL,
        hop_count INTEGER NOT NULL,
        delivery_state TEXT NOT NULL,
        verification_state TEXT NOT NULL,
        relay_count INTEGER NOT NULL DEFAULT 1,
        is_acknowledged INTEGER NOT NULL DEFAULT 0,
        siren_enabled INTEGER NOT NULL DEFAULT 0,
        siren_pattern TEXT NOT NULL DEFAULT 'none'
      );
    ''');

    await _ensureSirenColumns();

    await _executor.runCustom('''
      CREATE INDEX IF NOT EXISTS idx_mesh_emergency_expiry 
      ON mesh_emergency_alerts(expires_at DESC, created_at DESC);
    ''');

    _isInitialized = true;
  }

  /// Checks if an alert with [alertId] exists in the local database.
  Future<bool> hasAlert(String alertId) async {
    await initialize();
    final results = await _executor.runSelect(
      'SELECT 1 FROM mesh_emergency_alerts WHERE alert_id = ? LIMIT 1',
      [alertId],
    );
    return results.isNotEmpty;
  }

  /// Retrieves an alert by its unique [alertId].
  Future<EmergencyAlert?> getAlert(String alertId) async {
    await initialize();
    final results = await _executor.runSelect(
      'SELECT * FROM mesh_emergency_alerts WHERE alert_id = ? LIMIT 1',
      [alertId],
    );
    if (results.isEmpty) return null;
    return _rowToAlert(results.first);
  }

  /// Saves an emergency alert to local persistence.
  ///
  /// Returns `true` if the alert is newly recorded.
  /// Returns `false` if it is a duplicate received via an alternate relay path
  /// (in which case telemetry like [lastSeenAt], [relayCount], and shortest [hopCount] are updated).
  Future<bool> saveAlert(EmergencyAlert alert) async {
    await initialize();

    final existing = await getAlert(alert.alertId);
    if (existing != null) {
      // Update observation telemetry without resetting user acknowledgement
      final newHop = alert.hopCount < existing.hopCount ? alert.hopCount : existing.hopCount;
      final newRelayCount = existing.relayCount + 1;
      final nowMillis = DateTime.now().millisecondsSinceEpoch;

      await _executor.runUpdate(
        '''
        UPDATE mesh_emergency_alerts
        SET last_seen_at = ?,
            relay_count = ?,
            hop_count = ?
        WHERE alert_id = ?
        ''',
        [nowMillis, newRelayCount, newHop, alert.alertId],
      );

      _notifyAlertsChanged();
      return false;
    }

    // Insert new alert
    await _executor.runInsert(
      '''
      INSERT INTO mesh_emergency_alerts (
        alert_id, issuer_device_id, issuer_user_id, issuer_role,
        scope, severity, category, title, message,
        created_at, expires_at, first_seen_at, last_seen_at,
        hop_count, delivery_state, verification_state,
        relay_count, is_acknowledged, siren_enabled, siren_pattern
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
      ''',
      [
        alert.alertId,
        alert.issuerDeviceId,
        alert.issuerUserId,
        alert.issuerRole,
        alert.scope,
        alert.severity.name,
        alert.category.name,
        alert.title,
        alert.message,
        alert.createdAt.millisecondsSinceEpoch,
        alert.expiresAt.millisecondsSinceEpoch,
        alert.firstSeenAt.millisecondsSinceEpoch,
        alert.lastSeenAt.millisecondsSinceEpoch,
        alert.hopCount,
        alert.deliveryState.name,
        alert.verificationState,
        alert.relayCount,
        alert.isAcknowledged ? 1 : 0,
        alert.sirenEnabled ? 1 : 0,
        alert.sirenPattern.code,
      ],
    );

    await _enforceRetentionLimit();
    _notifyAlertsChanged();
    return true;
  }

  /// Marks an emergency alert as locally acknowledged by the device user.
  Future<bool> acknowledgeAlert(String alertId) async {
    await initialize();
    final updated = await _executor.runUpdate(
      'UPDATE mesh_emergency_alerts SET is_acknowledged = 1 WHERE alert_id = ?',
      [alertId],
    );
    if (updated > 0) {
      _notifyAlertsChanged();
      return true;
    }
    return false;
  }

  /// Marks an active alert as cancelled/expired immediately when a signed cancellation arrives.
  Future<bool> cancelAlert(String alertId, [DateTime? cancelledAt]) async {
    await initialize();
    final nowMillis = (cancelledAt ?? DateTime.now()).millisecondsSinceEpoch;
    final updated = await _executor.runUpdate(
      '''
      UPDATE mesh_emergency_alerts
      SET expires_at = ?, delivery_state = 'expired'
      WHERE alert_id = ?
      ''',
      [nowMillis, alertId],
    );
    if (updated > 0) {
      _notifyAlertsChanged();
      return true;
    }
    return false;
  }

  Future<void> _ensureSirenColumns() async {
    try {
      final cols = await _executor.runSelect(
        'PRAGMA table_info(mesh_emergency_alerts)',
        [],
      );
      final colNames = cols.map((c) => c['name']?.toString()).toSet();
      if (!colNames.contains('siren_enabled')) {
        await _executor.runCustom(
          'ALTER TABLE mesh_emergency_alerts ADD COLUMN siren_enabled INTEGER NOT NULL DEFAULT 0',
        );
      }
      if (!colNames.contains('siren_pattern')) {
        await _executor.runCustom(
          "ALTER TABLE mesh_emergency_alerts ADD COLUMN siren_pattern TEXT NOT NULL DEFAULT 'none'",
        );
      }
    } catch (_) {}
  }

  /// Retrieves active (non-expired) alerts, ordered by severity and creation time.
  Future<List<EmergencyAlert>> getActiveAlerts([DateTime? now]) async {
    await initialize();
    final currentEpoch = (now ?? DateTime.now()).millisecondsSinceEpoch;

    final rows = await _executor.runSelect(
      '''
      SELECT * FROM mesh_emergency_alerts
      WHERE expires_at > ?
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

    return rows.map(_rowToAlert).toList();
  }

  /// Retrieves all historical emergency alerts up to [limit].
  Future<List<EmergencyAlert>> getAlertHistory({int limit = 100}) async {
    await initialize();
    final rows = await _executor.runSelect(
      '''
      SELECT * FROM mesh_emergency_alerts
      ORDER BY created_at DESC
      LIMIT ?
      ''',
      [limit],
    );
    return rows.map(_rowToAlert).toList();
  }

  /// Reactive stream of currently active emergency alerts.
  Stream<List<EmergencyAlert>> watchActiveAlerts([DateTime? now]) async* {
    yield await getActiveAlerts(now);
    yield* _alertsUpdateController.stream.asyncMap((_) => getActiveAlerts(now));
  }

  /// Prunes expired alerts exceeding the retention duration.
  Future<int> cleanupExpired({Duration maxRetentionWindow = const Duration(days: 7)}) async {
    await initialize();
    final cutoffEpoch =
        DateTime.now().subtract(maxRetentionWindow).millisecondsSinceEpoch;

    final deleted = await _executor.runDelete(
      'DELETE FROM mesh_emergency_alerts WHERE expires_at < ?',
      [cutoffEpoch],
    );
    if (deleted > 0) {
      _notifyAlertsChanged();
    }
    return deleted;
  }

  Future<void> _enforceRetentionLimit() async {
    final countResult = await _executor.runSelect(
      'SELECT COUNT(*) as cnt FROM mesh_emergency_alerts',
      [],
    );
    final count = countResult.first['cnt'] as int? ?? 0;
    if (count > maxRetention) {
      final excess = count - maxRetention;
      // Delete oldest non-critical expired alerts first, or oldest alerts
      await _executor.runDelete(
        '''
        DELETE FROM mesh_emergency_alerts
        WHERE alert_id IN (
          SELECT alert_id FROM mesh_emergency_alerts
          ORDER BY is_acknowledged DESC, created_at ASC
          LIMIT ?
        )
        ''',
        [excess],
      );
    }
  }

  void _notifyAlertsChanged() {
    if (!_alertsUpdateController.isClosed) {
      getActiveAlerts().then((alerts) {
        if (!_alertsUpdateController.isClosed) {
          _alertsUpdateController.add(alerts);
        }
      });
    }
  }

  EmergencyAlert _rowToAlert(Map<String, dynamic> row) {
    final sevName = row['severity']?.toString() ?? 'advisory';
    final catName = row['category']?.toString() ?? 'other';
    final delStateName = row['delivery_state']?.toString() ?? 'received';

    EmergencySeverity severity;
    try {
      severity = EmergencySeverity.values.firstWhere(
        (s) => s.name.toLowerCase() == sevName.toLowerCase(),
      );
    } catch (_) {
      severity = EmergencySeverity.advisory;
    }

    EmergencyCategory category;
    try {
      category = EmergencyCategory.values.firstWhere(
        (c) => c.name.toLowerCase() == catName.toLowerCase(),
      );
    } catch (_) {
      category = EmergencyCategory.other;
    }

    final priority = severity == EmergencySeverity.critical
        ? EmergencyRelayPriority.critical
        : (severity == EmergencySeverity.warning
            ? EmergencyRelayPriority.high
            : EmergencyRelayPriority.normal);

    return EmergencyAlert(
      alertId: row['alert_id'] as String,
      issuerDeviceId: row['issuer_device_id'] as String,
      issuerUserId: row['issuer_user_id'] as String?,
      issuerRole: row['issuer_role'] as String,
      scope: row['scope'] as String,
      severity: severity,
      category: category,
      title: row['title'] as String,
      message: row['message'] as String,
      createdAt: DateTime.fromMillisecondsSinceEpoch(row['created_at'] as int),
      expiresAt: DateTime.fromMillisecondsSinceEpoch(row['expires_at'] as int),
      firstSeenAt: DateTime.fromMillisecondsSinceEpoch(row['first_seen_at'] as int),
      lastSeenAt: DateTime.fromMillisecondsSinceEpoch(row['last_seen_at'] as int),
      hopCount: row['hop_count'] as int? ?? 0,
      deliveryState: EmergencyDeliveryState.fromString(delStateName),
      verificationState: row['verification_state'] as String? ?? 'TRUSTED',
      relayPriority: priority,
      relayCount: row['relay_count'] as int? ?? 1,
      isAcknowledged: (row['is_acknowledged'] as int? ?? 0) == 1,
      sirenEnabled: (row['siren_enabled'] as int? ?? 0) == 1,
      sirenPattern: EmergencySirenPattern.fromCode(
        row['siren_pattern']?.toString(),
      ),
    );
  }

  Future<void> close() async {
    await _alertsUpdateController.close();
    await _executor.close();
  }
}

class _EmergencyExecutorUser extends QueryExecutorUser {
  @override
  int get schemaVersion => 1;

  @override
  Future<void> beforeOpen(QueryExecutor executor, OpeningDetails details) async {}
}
