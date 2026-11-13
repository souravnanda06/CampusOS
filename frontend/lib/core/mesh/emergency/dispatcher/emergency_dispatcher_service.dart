import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';

import '../campus_mesh_emergency_service.dart';
import '../emergency_alert.dart';
import '../emergency_authorization.dart';
import '../../campus_mesh_service.dart';
import '../../mesh_crypto.dart';
import '../../mesh_packet.dart';
import 'emergency_audit_event.dart';
import 'emergency_audit_repository.dart';
import 'emergency_dispatcher_repository.dart';
import 'emergency_incident.dart';

/// Institutional emergency command and dispatch coordinator service for CampusOS Mesh.
///
/// Enables authorized Deans, Directors, Admins, Wardens, and Faculty to create,
/// broadcast, monitor, cancel, expire, and audit emergency incidents over the
/// decentralized BLE mesh network without backend or internet dependencies.
class MeshEmergencyDispatcherService {
  final CampusMeshEmergencyService _emergencyService;
  final MeshEmergencyDispatcherRepository _dispatcherRepository;
  final EmergencyAuditRepository _auditRepository;
  final CampusMeshService _meshService;
  final MeshCryptoService? _cryptoService;

  StreamSubscription<MeshPacket>? _packetSubscription;
  Timer? _expiryCheckTimer;
  final Set<String> _observedPeers = {};

  final StreamController<EmergencyIncident> _incidentDispatchedController =
      StreamController<EmergencyIncident>.broadcast();
  final StreamController<EmergencyIncident> _incidentUpdatedController =
      StreamController<EmergencyIncident>.broadcast();

  MeshEmergencyDispatcherService({
    required CampusMeshEmergencyService emergencyService,
    required MeshEmergencyDispatcherRepository dispatcherRepository,
    required EmergencyAuditRepository auditRepository,
    CampusMeshService? meshService,
    MeshCryptoService? cryptoService,
  })  : _emergencyService = emergencyService,
        _dispatcherRepository = dispatcherRepository,
        _auditRepository = auditRepository,
        _meshService = meshService ?? emergencyService.meshService,
        _cryptoService = cryptoService;

  /// Underlying dispatcher incident repository.
  MeshEmergencyDispatcherRepository get repository => _dispatcherRepository;

  /// Underlying append-only audit repository.
  EmergencyAuditRepository get auditRepository => _auditRepository;

  /// Underlying emergency transport service.
  CampusMeshEmergencyService get emergencyService => _emergencyService;

  /// Current local role of this node.
  String get localRole => _meshService.localRole;

  /// Current local device identifier.
  String get localDeviceId => _meshService.localDeviceId;

  /// Stream of newly dispatched incidents originated by this dispatcher.
  Stream<EmergencyIncident> get onIncidentDispatched =>
      _incidentDispatchedController.stream;

  /// Stream of updated incidents (telemetry, ACKs, cancellation, expiration).
  Stream<EmergencyIncident> get onIncidentUpdated =>
      _incidentUpdatedController.stream;

  /// Initializes repositories, starts expiration checker, and listens for mesh packets.
  Future<void> initialize({bool enablePeriodicExpiry = true}) async {
    await _dispatcherRepository.initialize();
    await _auditRepository.initialize();

    // Check and expire any incidents that expired while app was closed
    await checkAndExpireIncidents();

    // Periodic expiration checker (every 15 seconds)
    _expiryCheckTimer?.cancel();
    if (enablePeriodicExpiry) {
      _expiryCheckTimer = Timer.periodic(const Duration(seconds: 15), (_) {
        checkAndExpireIncidents();
      });
    }

    // Listen for mesh telemetry, cancellations, and acknowledgements
    await _packetSubscription?.cancel();
    _packetSubscription = _meshService.receivedPackets.listen((packet) {
      _handleInboundPacket(packet);
    });
  }

  /// Whether the local node is authorized to dispatch an emergency for the given [scope].
  bool isAuthorizedToDispatch([String scope = EmergencyScope.campus]) {
    return _emergencyService.canIssueEmergency(
      role: localRole,
      scope: scope,
    );
  }

  /// List of permitted scopes available to the local user's role.
  List<String> getAvailableScopes() {
    return EmergencyAuthorization.getAvailableScopesForRole(role: localRole);
  }

  /// Creates and dispatches an institutional Emergency Incident over CampusOS Mesh.
  ///
  /// Enforces:
  /// 1. Strict institutional role & scope authorization (Deans, Admins, Wardens, Faculty).
  /// 2. Duplicate dispatch suppression.
  /// 3. Append-only audit trail logging (CREATED, SIGNED, SENT).
  /// 4. Cryptographic Ed25519 signing via PassportCryptoService.
  /// 5. Bounded emergency relay priority propagation.
  Future<EmergencyIncident> createAndDispatchIncident({
    required String title,
    required String message,
    required EmergencyCategory category,
    required EmergencySeverity severity,
    required String scope,
    Duration duration = const Duration(minutes: 30),
    EmergencyRelayPriority? relayPriority,
    bool? sendSiren,
    EmergencySirenPattern? sirenPattern,
  }) async {
    final normalizedScope = scope.trim().toLowerCase();

    // 1. Enforce strict role and scope authorization
    if (!isAuthorizedToDispatch(normalizedScope)) {
      final now = DateTime.now();
      final deniedEvent = EmergencyAuditEvent(
        eventId: _generateId(),
        incidentId: 'unauthorized_attempt',
        timestamp: now,
        eventType: EmergencyAuditEventType.verificationFailed,
        actorDeviceId: localDeviceId,
        actorRole: localRole,
        verificationState: 'DENIED',
        details: {
          'reason': 'Role "$localRole" not permitted to dispatch scope "$normalizedScope".',
          'title': title.trim(),
        },
      );
      await _auditRepository.recordEvent(deniedEvent);

      throw EmergencyUnauthorizedException(
        role: localRole,
        scope: normalizedScope,
        reason: 'Institutional security policy prohibits role "$localRole" from dispatching emergencies for scope "$normalizedScope".',
      );
    }

    // 2. Duplicate dispatch protection (reject rapid double-taps within 10s cooldown)
    final duplicate = await _dispatcherRepository.findRecentDuplicate(
      title: title,
      message: message,
      scope: normalizedScope,
      cooldown: const Duration(seconds: 10),
    );
    if (duplicate != null) {
      throw StateError(
        'Duplicate emergency dispatch blocked. An identical incident ("${duplicate.title}") was dispatched ${DateTime.now().difference(duplicate.createdAt).inSeconds}s ago.',
      );
    }

    final now = DateTime.now();
    final expiresAt = now.add(duration);
    final incidentId = _generateId();

    // 3. Record DISPATCH_CREATED audit event
    await _auditRepository.recordEvent(EmergencyAuditEvent(
      eventId: _generateId(),
      incidentId: incidentId,
      timestamp: now,
      eventType: EmergencyAuditEventType.dispatchCreated,
      actorDeviceId: localDeviceId,
      actorRole: localRole,
      details: {
        'title': title.trim(),
        'category': category.name,
        'severity': severity.name,
        'scope': normalizedScope,
        'durationMinutes': duration.inMinutes,
      },
    ));

    // 4. Issue the alert via authoritative CampusMeshEmergencyService
    //    (Signs with local Ed25519 identity key and broadcasts over BLE Mesh)
    EmergencyAlert alert;
    try {
      alert = await _emergencyService.issueEmergencyAlert(
        title: title,
        message: message,
        severity: severity,
        category: category,
        scope: normalizedScope,
        duration: duration,
        relayPriority: relayPriority,
        sendSiren: sendSiren,
        sirenPattern: sirenPattern,
      );
    } catch (e) {
      await _auditRepository.recordEvent(EmergencyAuditEvent(
        eventId: _generateId(),
        incidentId: incidentId,
        timestamp: DateTime.now(),
        eventType: EmergencyAuditEventType.verificationFailed,
        actorDeviceId: localDeviceId,
        actorRole: localRole,
        details: {'error': e.toString()},
      ));
      rethrow;
    }

    // 5. Record DISPATCH_SIGNED & DISPATCH_SENT audit events
    await _auditRepository.recordEvent(EmergencyAuditEvent(
      eventId: _generateId(),
      incidentId: incidentId,
      timestamp: DateTime.now(),
      eventType: EmergencyAuditEventType.dispatchSigned,
      actorDeviceId: localDeviceId,
      actorRole: localRole,
      verificationState: 'TRUSTED',
      details: {'alertId': alert.alertId},
    ));

    await _auditRepository.recordEvent(EmergencyAuditEvent(
      eventId: _generateId(),
      incidentId: incidentId,
      timestamp: DateTime.now(),
      eventType: EmergencyAuditEventType.dispatchSent,
      actorDeviceId: localDeviceId,
      actorRole: localRole,
      hopCount: 0,
      details: {'alertId': alert.alertId, 'deliveryState': alert.deliveryState.name},
    ));

    // 6. Build and persist EmergencyIncident
    final incident = EmergencyIncident(
      incidentId: incidentId,
      alertId: alert.alertId,
      title: title.trim(),
      message: message.trim(),
      category: category,
      severity: severity,
      priority: alert.relayPriority,
      scope: normalizedScope,
      issuerDeviceId: localDeviceId,
      issuerUserId: alert.issuerUserId,
      issuerRole: localRole,
      createdAt: now,
      expiresAt: expiresAt,
      status: EmergencyIncidentStatus.active,
      hopCount: 0,
      relayCount: 1,
      localDeliveryCount: 0,
      acknowledgementCount: 0,
      lastPropagationAt: now,
      signatureVerificationState: 'TRUSTED',
      sirenEnabled: alert.sirenEnabled,
      sirenPattern: alert.sirenPattern,
    );

    await _dispatcherRepository.saveIncident(incident);

    if (!_incidentDispatchedController.isClosed) {
      _incidentDispatchedController.add(incident);
    }

    return incident;
  }

  /// Authenticated cancellation of an active emergency incident.
  ///
  /// Broadcasts a signed cancellation notice across the BLE mesh and appends
  /// a DISPATCH_CANCELLED audit event.
  Future<bool> cancelIncident(
    String incidentId, {
    String? reason,
  }) async {
    final incident = await _dispatcherRepository.getIncident(incidentId);
    if (incident == null) {
      throw ArgumentError('Incident "$incidentId" not found.');
    }

    if (incident.isCancelled) {
      return true; // Already cancelled
    }

    // Authorization check for cancellation
    if (!isAuthorizedToDispatch(incident.scope)) {
      throw EmergencyUnauthorizedException(
        role: localRole,
        scope: incident.scope,
        reason: 'Role "$localRole" is not authorized to cancel incidents for scope "${incident.scope}".',
      );
    }

    final now = DateTime.now();

    // 1. Broadcast signed cancellation notice over BLE Mesh
    final cancelPacketId = MeshPacket.generatePacketId();
    final cancelPayload = {
      'c': true,
      'i': incident.incidentId,
      'al': incident.alertId,
      'r': reason ?? 'Resolved by authority',
    };
    final payloadBytes = Uint8List.fromList(utf8.encode(jsonEncode(cancelPayload)));

    final cancelPacket = MeshPacket(
      packetId: cancelPacketId,
      packetType: MeshPacketType.acknowledgement,
      ttl: MeshPacket.defaultTtl,
      hopCount: 0,
      senderDeviceId: localDeviceId,
      senderRole: localRole,
      timestamp: now,
      payload: payloadBytes,
    );

    final packetToBroadcast = _cryptoService != null
        ? await _cryptoService!.signPacket(cancelPacket)
        : cancelPacket;

    await _meshService.broadcastPacket(packetToBroadcast);
    await _emergencyService.stopActiveSiren(alertId: incident.alertId);

    // 2. Update repository state
    await _dispatcherRepository.markCancelled(
      incidentId,
      cancelledAt: now,
      reason: reason ?? 'Resolved by $localRole',
      cancelledByDeviceId: localDeviceId,
      cancelledByRole: localRole,
    );

    // 3. Record immutable DISPATCH_CANCELLED audit event
    await _auditRepository.recordEvent(EmergencyAuditEvent(
      eventId: _generateId(),
      incidentId: incidentId,
      timestamp: now,
      eventType: EmergencyAuditEventType.dispatchCancelled,
      actorDeviceId: localDeviceId,
      actorRole: localRole,
      details: {
        'reason': reason,
        'cancelledAt': now.toIso8601String(),
      },
    ));

    final updated = await _dispatcherRepository.getIncident(incidentId);
    if (updated != null && !_incidentUpdatedController.isClosed) {
      _incidentUpdatedController.add(updated);
    }

    return true;
  }

  /// Sends a cryptographically signed acknowledgement for an emergency incident.
  Future<void> sendAcknowledgement(String incidentId) async {
    final incident = await _dispatcherRepository.getIncident(incidentId);
    if (incident == null) return;

    final now = DateTime.now();
    final ackPacketId = MeshPacket.generatePacketId();
    final ackPayload = {
      'a': 'ack',
      'i': incident.incidentId,
      'al': incident.alertId,
    };

    final packet = MeshPacket(
      packetId: ackPacketId,
      packetType: MeshPacketType.acknowledgement,
      ttl: MeshPacket.defaultTtl,
      hopCount: 0,
      senderDeviceId: localDeviceId,
      senderRole: localRole,
      timestamp: now,
      payload: Uint8List.fromList(utf8.encode(jsonEncode(ackPayload))),
    );

    final ackToBroadcast = _cryptoService != null
        ? await _cryptoService!.signPacket(packet)
        : packet;

    await _meshService.broadcastPacket(ackToBroadcast);

    // Also mark locally acknowledged in repository
    await _emergencyService.acknowledgeEmergency(incident.alertId);
  }

  /// Checks for any active incidents that have passed their expiration timestamp,
  /// transitions their status to EXPIRED, and records DISPATCH_EXPIRED audit events.
  Future<int> checkAndExpireIncidents([DateTime? now]) async {
    final currentTime = now ?? DateTime.now();
    final activeIncidents = await _dispatcherRepository.getActiveIncidents();

    int expiredCount = 0;
    for (final inc in activeIncidents) {
      if (currentTime.isAfter(inc.expiresAt)) {
        await _dispatcherRepository.markExpired(inc.incidentId);

        await _auditRepository.recordEvent(EmergencyAuditEvent(
          eventId: _generateId(),
          incidentId: inc.incidentId,
          timestamp: currentTime,
          eventType: EmergencyAuditEventType.dispatchExpired,
          actorDeviceId: localDeviceId,
          details: {
            'expiredAt': inc.expiresAt.toIso8601String(),
            'checkedAt': currentTime.toIso8601String(),
          },
        ));

        expiredCount++;
        final updated = await _dispatcherRepository.getIncident(inc.incidentId);
        if (updated != null && !_incidentUpdatedController.isClosed) {
          _incidentUpdatedController.add(updated);
        }
      }
    }

    return expiredCount;
  }

  /// Retrieves active emergency incidents.
  Future<List<EmergencyIncident>> getActiveIncidents([DateTime? now]) {
    return _dispatcherRepository.getActiveIncidents(now);
  }

  /// Retrieves all incidents (active, cancelled, expired).
  Future<List<EmergencyIncident>> getAllIncidents({int limit = 100}) {
    return _dispatcherRepository.getAllIncidents(limit: limit);
  }

  /// Reactive stream of currently active emergency incidents.
  Stream<List<EmergencyIncident>> watchActiveIncidents([DateTime? now]) {
    return _dispatcherRepository.watchActiveIncidents(now);
  }

  /// Retrieves full audit event history for an incident.
  Future<List<EmergencyAuditEvent>> getAuditEvents(String incidentId) {
    return _auditRepository.getEventsForIncident(incidentId);
  }

  /// Handles incoming mesh packets for telemetry, ACKs, and cancellations.
  Future<void> _handleInboundPacket(MeshPacket packet) async {
    // 1. Process Acknowledgements / Cancellations
    if (packet.packetType == MeshPacketType.acknowledgement && packet.payload.isNotEmpty) {
      try {
        final decoded = jsonDecode(utf8.decode(packet.payload));
        if (decoded is Map) {
          // A. Handle Emergency Acknowledgement
          if (decoded['a'] == 'ack' || decoded['ack_type'] == 'emergency_ack') {
            final incidentId = (decoded['i'] ?? decoded['incident_id'])?.toString();
            final alertId = (decoded['al'] ?? decoded['alert_id'])?.toString();
            if (incidentId != null || alertId != null) {
              EmergencyIncident? incident;
              if (incidentId != null) {
                incident = await _dispatcherRepository.getIncident(incidentId);
              }
              if (incident == null && alertId != null) {
                incident = await _dispatcherRepository.getIncidentByAlertId(alertId);
              }

              if (incident != null) {
                // Verify signature if crypto service available
                String verificationState = 'TRUSTED';
                if (_cryptoService != null) {
                  final verify = await _cryptoService!.verifyPacket(packet);
                  if (!verify.isValid) return; // Drop unverified ACK
                  verificationState = verify.isTrusted ? 'TRUSTED' : 'UNVERIFIED';
                }

                await _dispatcherRepository.incrementAcknowledgementCount(incident.incidentId);

                await _auditRepository.recordEvent(EmergencyAuditEvent(
                  eventId: _generateId(),
                  incidentId: incident.incidentId,
                  timestamp: DateTime.now(),
                  eventType: EmergencyAuditEventType.ackReceived,
                  actorDeviceId: packet.senderDeviceId,
                  actorRole: packet.senderRole,
                  hopCount: packet.hopCount,
                  verificationState: verificationState,
                  details: {
                    'respondingDevice': packet.senderDeviceId,
                  },
                ));

                final updated = await _dispatcherRepository.getIncident(incident.incidentId);
                if (updated != null && !_incidentUpdatedController.isClosed) {
                  _incidentUpdatedController.add(updated);
                }
              }
            }
          }

          // B. Handle Cancellation Notice
          if (decoded['c'] == true || decoded['cancellation'] == true) {
            final incidentId = (decoded['i'] ?? decoded['incident_id'])?.toString();
            final alertId = (decoded['al'] ?? decoded['alert_id'])?.toString();
            if (incidentId != null || alertId != null) {
              EmergencyIncident? incident;
              if (incidentId != null) {
                incident = await _dispatcherRepository.getIncident(incidentId);
              }
              if (incident == null && alertId != null) {
                incident = await _dispatcherRepository.getIncidentByAlertId(alertId);
              }

              if (incident != null && !incident.isCancelled) {
                final reason = (decoded['r'] ?? decoded['reason'])?.toString() ?? 'Cancelled via mesh notification';
                final cancelledByDevice = (decoded['by'] ?? decoded['cancelled_by'] ?? packet.senderDeviceId).toString();
                final cancelledRole = (decoded['role'] ?? decoded['cancelled_role'] ?? packet.senderRole).toString();

                await _dispatcherRepository.markCancelled(
                  incident.incidentId,
                  cancelledAt: DateTime.now(),
                  reason: reason,
                  cancelledByDeviceId: cancelledByDevice,
                  cancelledByRole: cancelledRole,
                );

                await _auditRepository.recordEvent(EmergencyAuditEvent(
                  eventId: _generateId(),
                  incidentId: incident.incidentId,
                  timestamp: DateTime.now(),
                  eventType: EmergencyAuditEventType.dispatchCancelled,
                  actorDeviceId: packet.senderDeviceId,
                  actorRole: packet.senderRole,
                  details: {'remoteCancellation': true, 'reason': reason},
                ));

                final updated = await _dispatcherRepository.getIncident(incident.incidentId);
                if (updated != null && !_incidentUpdatedController.isClosed) {
                  _incidentUpdatedController.add(updated);
                }
              }
            }
          }
        }
      } catch (e) {
        debugPrint('⚠️ [DISPATCHER_SERVICE] Malformed acknowledgement payload: $e');
      }
    }

    // 2. Process Emergency Alert Packets for Telemetry Observation
    if (packet.packetType == MeshPacketType.emergency) {
      final alertId = packet.packetIdHex;
      final incident = await _dispatcherRepository.getIncidentByAlertId(alertId);

      if (incident != null) {
        final isNewPeer = _observedPeers.add('${incident.incidentId}:${packet.senderDeviceId}');
        final deliveryInc = isNewPeer ? 1 : 0;

        await _dispatcherRepository.updatePropagationTelemetry(
          incident.incidentId,
          hopCount: packet.hopCount,
          relayCountIncrement: 1,
          deliveryCountIncrement: deliveryInc,
          lastPropagationAt: DateTime.now(),
        );

        await _auditRepository.recordEvent(EmergencyAuditEvent(
          eventId: _generateId(),
          incidentId: incident.incidentId,
          timestamp: DateTime.now(),
          eventType: EmergencyAuditEventType.dispatchRelayed,
          actorDeviceId: packet.senderDeviceId,
          actorRole: packet.senderRole,
          hopCount: packet.hopCount,
          details: {
            'relayPeer': packet.senderDeviceId,
            'isNewPeer': isNewPeer,
          },
        ));

        final updated = await _dispatcherRepository.getIncident(incident.incidentId);
        if (updated != null && !_incidentUpdatedController.isClosed) {
          _incidentUpdatedController.add(updated);
        }
      }
    }
  }

  String _generateId() {
    return MeshPacket.generatePacketId()
        .map((b) => b.toRadixString(16).padLeft(2, '0'))
        .join();
  }

  /// Disposes timers, subscriptions, and stream controllers.
  Future<void> dispose() async {
    _expiryCheckTimer?.cancel();
    _expiryCheckTimer = null;
    _packetSubscription?.cancel();
    _packetSubscription = null;
    if (!_incidentDispatchedController.isClosed) {
      _incidentDispatchedController.close();
    }
    if (!_incidentUpdatedController.isClosed) {
      _incidentUpdatedController.close();
    }
  }
}
