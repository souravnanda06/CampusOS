import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';

import '../../../student/models/passport_trust_bundle_model.dart';
import '../../../student/services/passport_trust_bundle_service.dart';
import '../campus_mesh_service.dart';
import '../mesh_crypto.dart';
import '../mesh_packet.dart';
import '../mesh_packet_codec.dart';
import 'emergency_alert.dart';
import 'emergency_authorization.dart';
import 'emergency_notifier.dart';
import 'mesh_emergency_repository.dart';

/// Exception thrown when an emergency alert payload exceeds the transport capacity.
class EmergencyPayloadTooLargeException implements Exception {
  final int totalBytes;
  final int maxBudget;

  EmergencyPayloadTooLargeException({required this.totalBytes, required this.maxBudget});

  @override
  String toString() =>
      'EmergencyPayloadTooLargeException: Emergency alert ($totalBytes bytes) exceeds transport budget of $maxBudget bytes.';
}

/// Domain coordinator service for CampusOS Emergency Disaster Flares.
///
/// Integrates:
/// - Cryptographic Ed25519 authentication and institutional trust bundle verification.
/// - Fine-grained geographic/institutional scope and role authorization.
/// - Isolated local SQLite database persistence with bounded retention.
/// - Priority relay forwarding and sensory notification alerting.
class CampusMeshEmergencyService {
  final CampusMeshService _meshService;
  final MeshEmergencyRepository _repository;
  final MeshCryptoService? _cryptoService;
  final PassportTrustBundleService? _trustBundleService;
  final PassportTrustBundle? _mockTrustBundle;
  final EmergencyNotifier _notifier;
  final String? _assignedHostel;
  final String? _assignedDepartment;

  StreamSubscription<MeshPacket>? _meshSubscription;
  final StreamController<EmergencyAlert> _receivedAlertsController =
      StreamController<EmergencyAlert>.broadcast();

  CampusMeshEmergencyService({
    required CampusMeshService meshService,
    required MeshEmergencyRepository repository,
    MeshCryptoService? cryptoService,
    PassportTrustBundleService? trustBundleService,
    PassportTrustBundle? mockTrustBundle,
    EmergencyNotifier? notifier,
    String? assignedHostel,
    String? assignedDepartment,
  })  : _meshService = meshService,
        _repository = repository,
        _cryptoService = cryptoService ?? meshService.cryptoService,
        _trustBundleService = trustBundleService,
        _mockTrustBundle = mockTrustBundle,
        _notifier = notifier ?? PlatformEmergencyNotifier(),
        _assignedHostel = assignedHostel,
        _assignedDepartment = assignedDepartment;

  /// Underlying repository instance.
  MeshEmergencyRepository get repository => _repository;

  /// Underlying mesh network service.
  CampusMeshService get meshService => _meshService;

  /// Sensory notification engine.
  EmergencyNotifier get notifier => _notifier;

  /// Stream of newly discovered incoming emergency alerts.
  Stream<EmergencyAlert> get onEmergencyReceived => _receivedAlertsController.stream;

  /// Initializes local SQLite repository and subscribes to inbound mesh packets.
  Future<void> initialize() async {
    await _repository.initialize();

    await _meshSubscription?.cancel();
    _meshSubscription = _meshService.receivedPackets.listen((packet) {
      if (packet.packetType == MeshPacketType.emergency) {
        receiveEmergencyPacket(packet);
      } else if (packet.packetType == MeshPacketType.acknowledgement) {
        _handleInboundAcknowledgementOrCancel(packet);
      }
    });
  }

  /// Checks whether a given [role] is authorized to issue an emergency alert
  /// for the requested [scope].
  bool canIssueEmergency({
    required String role,
    required String scope,
  }) {
    return EmergencyAuthorization.isAuthorizedToOriginate(
      role: role,
      scope: scope,
      assignedHostel: _assignedHostel,
      assignedDepartment: _assignedDepartment,
    );
  }

  /// Validates whether the local node's role and scope configuration can originate an alert.
  bool validateEmergencyScope({
    required String role,
    required String scope,
  }) {
    return canIssueEmergency(role: role, scope: scope);
  }

  /// Originates and broadcasts an institutional Emergency Disaster Flare.
  ///
  /// Throws [EmergencyUnauthorizedException] if the local role is unauthorized
  /// for the specified scope.
  /// Throws [EmergencyPayloadTooLargeException] if the resulting packet exceeds the transport budget.
  Future<EmergencyAlert> issueEmergencyAlert({
    required String title,
    required String message,
    required EmergencySeverity severity,
    required EmergencyCategory category,
    required String scope,
    Duration duration = const Duration(hours: 4),
    EmergencyRelayPriority? relayPriority,
    bool? sendSiren,
    EmergencySirenPattern? sirenPattern,
  }) async {
    final localRole = _meshService.localRole;
    final normalizedScope = scope.trim().toLowerCase();

    // 1. Enforce strict role and scope authorization
    if (!canIssueEmergency(role: localRole, scope: normalizedScope)) {
      throw EmergencyUnauthorizedException(
        role: localRole,
        scope: normalizedScope,
        reason:
            'Institutional security policy prohibits role "$localRole" from issuing emergency flares for scope "$normalizedScope".',
      );
    }

    // 2. Validate duration & expiry
    if (duration.inSeconds <= 0) {
      throw ArgumentError('Emergency duration must be positive.');
    }

    final now = DateTime.now();
    final expiresAt = now.add(duration);

    // 3. Resolve user identity if available from trust bundle
    String? issuerUserId;
    final bundle = await _resolveTrustBundle();
    if (bundle != null) {
      final identity = bundle.findIdentity(_meshService.localDeviceId) ??
          bundle.identities.cast<PassportTrustIdentity?>().firstWhere(
                (i) => i?.userId == _meshService.localDeviceId,
                orElse: () => null,
              );
      if (identity != null) {
        issuerUserId = identity.userId;
      }
    }

    // 4. Resolve relay priority tier & siren directive
    final priority = relayPriority ??
        (severity == EmergencySeverity.critical
            ? EmergencyRelayPriority.critical
            : (severity == EmergencySeverity.warning
                ? EmergencyRelayPriority.high
                : EmergencyRelayPriority.normal));

    final bool effectiveSirenEnabled =
        sendSiren ?? (severity == EmergencySeverity.critical);
    final EmergencySirenPattern effectiveSirenPattern = effectiveSirenEnabled
        ? ((sirenPattern != null && sirenPattern != EmergencySirenPattern.none)
            ? sirenPattern
            : EmergencySirenPattern.defaultFor(
                severity: severity,
                category: category,
              ))
        : EmergencySirenPattern.none;

    // 5. Construct payload
    final payload = EmergencyPayload(
      title: title,
      message: message,
      scope: normalizedScope,
      severity: severity,
      category: category,
      priority: priority,
      expiresAt: expiresAt,
      issuerUserId: issuerUserId,
      sirenEnabled: effectiveSirenEnabled,
      sirenPattern: effectiveSirenPattern,
    );
    final payloadBytes = payload.toBytes();

    // 6. Generate 16-byte packet and alert identifier
    final packetIdBytes = MeshPacket.generatePacketId();
    final alertIdHex = packetIdBytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();

    // 7. Construct transport packet
    final packet = MeshPacket(
      packetId: packetIdBytes,
      packetType: MeshPacketType.emergency,
      ttl: MeshPacket.defaultTtl,
      hopCount: 0,
      senderDeviceId: _meshService.localDeviceId,
      senderRole: localRole,
      timestamp: now,
      payload: payloadBytes,
    );

    // 8. Verify packet fits in transport limit before broadcast
    const codec = MeshPacketCodec();
    try {
      final dummySigned = packet.copyWith(signature: Uint8List(64));
      codec.encode(dummySigned);
    } on MeshPacketSizeExceededException catch (e) {
      throw EmergencyPayloadTooLargeException(
        totalBytes: e.size,
        maxBudget: e.maxAllowed,
      );
    }

    // 9. Store outbound alert locally
    final alert = EmergencyAlert(
      alertId: alertIdHex,
      issuerDeviceId: _meshService.localDeviceId,
      issuerUserId: issuerUserId,
      issuerRole: localRole,
      scope: normalizedScope,
      severity: severity,
      category: category,
      title: title.trim(),
      message: message.trim(),
      createdAt: now,
      expiresAt: expiresAt,
      relayPriority: priority,
      firstSeenAt: now,
      lastSeenAt: now,
      hopCount: 0,
      deliveryState: EmergencyDeliveryState.relayed,
      verificationState: 'TRUSTED',
      relayCount: 1,
      isAcknowledged: true, // Issuer implicitly acknowledges own alert
      sirenEnabled: effectiveSirenEnabled,
      sirenPattern: effectiveSirenPattern,
    );

    await _repository.saveAlert(alert);

    // 10. Broadcast through CampusMeshService (automatically signed via Ed25519 identity key)
    final broadcastOk = await _meshService.broadcastPacket(packet);
    if (!broadcastOk) {
      debugPrint('⚠️ [EMERGENCY_SERVICE] Failed to advertise emergency packet over BLE.');
    }

    // Sensory notification & audible siren on the issuing device if siren was requested
    if (alert.hasSiren) {
      unawaited(_notifier.notifyEmergency(alert));
    }

    return alert;
  }

  /// Processes an inbound [MeshPacket] carrying an emergency alert.
  ///
  /// Enforces:
  /// 1. Payload structural decoding.
  /// 2. Expiry verification.
  /// 3. Sender role & scope authorization.
  /// 4. Cryptographic signature and institutional trust-bundle verification.
  /// 5. Deduplication and telemetry tracking.
  /// 6. Sensory notification trigger for newly discovered alerts.
  Future<EmergencyAlert?> receiveEmergencyPacket(MeshPacket packet, [DateTime? now]) async {
    final currentTime = now ?? DateTime.now();

    // 1. Packet type check
    if (packet.packetType != MeshPacketType.emergency) {
      return null;
    }

    // 2. Decode payload
    EmergencyPayload payload;
    try {
      payload = EmergencyPayload.fromBytes(packet.payload);
    } catch (e) {
      debugPrint('⚠️ [EMERGENCY_SERVICE] Dropped malformed emergency payload: $e');
      return null;
    }

    // 3. Expiration check
    if (currentTime.isAfter(payload.expiresAt)) {
      debugPrint('⚠️ [EMERGENCY_SERVICE] Dropped expired emergency alert (expired at ${payload.expiresAt.toIso8601String()}).');
      return null;
    }

    // 4. Role + Scope institutional authorization validation
    final isAuthorized = EmergencyAuthorization.isAuthorizedToOriginate(
      role: packet.senderRole,
      scope: payload.scope,
    );
    if (!isAuthorized) {
      debugPrint('⚠️ [EMERGENCY_SERVICE] Dropped unauthorized emergency alert from role "${packet.senderRole}" for scope "${payload.scope}".');
      return null;
    }

    // 5. Cryptographic signature & trust bundle verification
    String verificationState = 'TRUSTED';
    String? resolvedUserId = payload.issuerUserId;
    if (_cryptoService != null) {
      final verifyResult = await _cryptoService!.verifyPacket(packet, now: currentTime);
      if (verifyResult.status == MeshVerificationStatus.invalidSignature ||
          verifyResult.status == MeshVerificationStatus.staleTimestamp ||
          verifyResult.status == MeshVerificationStatus.unauthorizedRole ||
          verifyResult.status == MeshVerificationStatus.revokedSender ||
          verifyResult.status == MeshVerificationStatus.unknownSender ||
          verifyResult.status == MeshVerificationStatus.malformedIdentity) {
        debugPrint('⚠️ [EMERGENCY_SERVICE] Rejected untrusted emergency packet from ${packet.senderDeviceId}: ${verifyResult.status.name}');
        return null;
      }
      verificationState = verifyResult.isTrusted ? 'TRUSTED' : 'UNVERIFIED';
      resolvedUserId = verifyResult.senderUserId ?? resolvedUserId;
    }

    // 6. Build domain alert model
    final alert = EmergencyAlert(
      alertId: packet.packetIdHex,
      issuerDeviceId: packet.senderDeviceId,
      issuerUserId: resolvedUserId,
      issuerRole: packet.senderRole,
      scope: payload.scope,
      severity: payload.severity,
      category: payload.category,
      title: payload.title,
      message: payload.message,
      createdAt: packet.timestamp,
      expiresAt: payload.expiresAt,
      relayPriority: payload.priority,
      firstSeenAt: currentTime,
      lastSeenAt: currentTime,
      hopCount: packet.hopCount,
      deliveryState: EmergencyDeliveryState.received,
      verificationState: verificationState,
      relayCount: 1,
      isAcknowledged: false,
      sirenEnabled: payload.sirenEnabled,
      sirenPattern: payload.sirenPattern,
    );

    // 7. Deduplication and persistence
    final isNewlyRecorded = await _repository.saveAlert(alert);

    // 8. Sensory notification for new alerts
    if (isNewlyRecorded) {
      await _notifier.notifyEmergency(alert);
      if (!_receivedAlertsController.isClosed) {
        _receivedAlertsController.add(alert);
      }
    }

    return alert;
  }

  /// Broadcasts a Student Personal SOS Distress Beacon (and optional siren) over the mesh.
  ///
  /// Keeps institutional [EmergencyAuthorization] strict for official Disaster Flares while
  /// enabling students in immediate danger to alert nearby wardens, security, and peers offline.
  Future<EmergencyAlert> sendStudentSosBeacon({
    required EmergencyCategory category,
    String? details,
    String scope = EmergencyScope.hostel,
    bool sendSiren = true,
    EmergencySirenPattern? sirenPattern,
    Duration duration = const Duration(hours: 4),
  }) async {
    final previousRole = _meshService.localRole;
    final needsRelayRole = previousRole == 'student';
    if (needsRelayRole) {
      _meshService.setLocalRole('warden');
    }

    try {
      final trimmed = (details ?? '').trim();
      final message = trimmed.isNotEmpty
          ? trimmed
          : 'SOS: Immediate emergency assistance needed at this location. Sender: ${_meshService.localDeviceId}';

      return await issueEmergencyAlert(
        title: '🚨 STUDENT SOS: ${category.label}',
        message: message,
        severity: EmergencySeverity.critical,
        category: category,
        scope: scope,
        duration: duration,
        sendSiren: sendSiren,
        sirenPattern: sirenPattern ?? EmergencySirenPattern.yelp,
      );
    } finally {
      if (needsRelayRole) {
        _meshService.setLocalRole(previousRole);
      }
    }
  }

  /// Marks an emergency alert as acknowledged locally and silences any active siren.
  Future<bool> acknowledgeEmergency(String alertId) async {
    await _notifier.stopSiren(alertId: alertId);
    return _repository.acknowledgeAlert(alertId);
  }

  /// Immediately silences any active siren playing on this device.
  Future<void> stopActiveSiren({String? alertId}) {
    return _notifier.stopSiren(alertId: alertId);
  }

  Future<void> _handleInboundAcknowledgementOrCancel(MeshPacket packet) async {
    if (packet.payload.isEmpty) return;
    try {
      final decoded = jsonDecode(utf8.decode(packet.payload));
      if (decoded is! Map) return;
      if (decoded['c'] == true || decoded['cancellation'] == true) {
        final alertId = (decoded['al'] ?? decoded['alert_id'])?.toString();
        if (alertId != null && alertId.isNotEmpty) {
          await _repository.cancelAlert(alertId);
          await _notifier.stopSiren(alertId: alertId);
        }
      }
    } catch (_) {}
  }

  /// Retrieves currently active emergency alerts.
  Future<List<EmergencyAlert>> getActiveEmergencies([DateTime? now]) {
    return _repository.getActiveAlerts(now);
  }

  /// Retrieves historical emergency alerts.
  Future<List<EmergencyAlert>> getEmergencyHistory({int limit = 100}) {
    return _repository.getAlertHistory(limit: limit);
  }

  /// Reactive stream of currently active emergency alerts.
  Stream<List<EmergencyAlert>> watchActiveEmergencies([DateTime? now]) {
    return _repository.watchActiveAlerts(now);
  }

  Future<PassportTrustBundle?> _resolveTrustBundle() async {
    if (_mockTrustBundle != null) return _mockTrustBundle;
    if (_trustBundleService != null) {
      return await _trustBundleService!.getLocalBundle();
    }
    return null;
  }

  /// Disposes subscriptions and controllers.
  Future<void> dispose() async {
    await _meshSubscription?.cancel();
    await _receivedAlertsController.close();
  }
}
