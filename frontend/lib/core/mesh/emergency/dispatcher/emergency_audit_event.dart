import 'dart:convert';

/// Types of institutional audit events recorded during the lifecycle of an
/// emergency disaster flare incident.
enum EmergencyAuditEventType {
  dispatchCreated('DISPATCH_CREATED'),
  dispatchSigned('DISPATCH_SIGNED'),
  dispatchSent('DISPATCH_SENT'),
  dispatchRelayed('DISPATCH_RELAYED'),
  dispatchReceived('DISPATCH_RECEIVED'),
  ackReceived('ACK_RECEIVED'),
  verificationFailed('VERIFICATION_FAILED'),
  dispatchCancelled('DISPATCH_CANCELLED'),
  dispatchExpired('DISPATCH_EXPIRED');

  final String code;
  const EmergencyAuditEventType(this.code);

  static EmergencyAuditEventType fromCode(String code) {
    for (final e in EmergencyAuditEventType.values) {
      if (e.code.toLowerCase() == code.toLowerCase() ||
          e.name.toLowerCase() == code.toLowerCase()) {
        return e;
      }
    }
    return EmergencyAuditEventType.dispatchCreated;
  }
}

/// Immutable, append-only audit event capturing an operational transition,
/// cryptographic verification, propagation event, or administrative action
/// taken on an emergency incident.
class EmergencyAuditEvent {
  /// Unique 32-hex identifier for this audit event.
  final String eventId;

  /// Associated incident identifier.
  final String incidentId;

  /// Exact timestamp when the audit event occurred.
  final DateTime timestamp;

  /// Operational event type.
  final EmergencyAuditEventType eventType;

  /// Hardware device ID of the actor or reporting node.
  final String? actorDeviceId;

  /// Institutional user ID of the actor (if certified).
  final String? actorUserId;

  /// Role of the actor (e.g. 'DEAN', 'ADMIN', 'STUDENT').
  final String? actorRole;

  /// Observed hop count at the time of the event (if applicable).
  final int? hopCount;

  /// Cryptographic verification state ('TRUSTED', 'UNVERIFIED', 'REVOKED').
  final String? verificationState;

  /// Structured diagnostic details or payload metadata.
  final Map<String, dynamic> details;

  const EmergencyAuditEvent({
    required this.eventId,
    required this.incidentId,
    required this.timestamp,
    required this.eventType,
    this.actorDeviceId,
    this.actorUserId,
    this.actorRole,
    this.hopCount,
    this.verificationState,
    this.details = const {},
  });

  Map<String, dynamic> toJson() {
    return {
      'eventId': eventId,
      'incidentId': incidentId,
      'timestamp': timestamp.toIso8601String(),
      'eventType': eventType.code,
      'actorDeviceId': actorDeviceId,
      'actorUserId': actorUserId,
      'actorRole': actorRole,
      'hopCount': hopCount,
      'verificationState': verificationState,
      'details': details,
    };
  }

  factory EmergencyAuditEvent.fromJson(Map<String, dynamic> json) {
    dynamic rawDetails = json['details'];
    Map<String, dynamic> parsedDetails = {};
    if (rawDetails is Map) {
      parsedDetails = Map<String, dynamic>.from(rawDetails);
    } else if (rawDetails is String && rawDetails.isNotEmpty) {
      try {
        parsedDetails = Map<String, dynamic>.from(jsonDecode(rawDetails));
      } catch (_) {}
    }

    return EmergencyAuditEvent(
      eventId: json['eventId'] as String,
      incidentId: json['incidentId'] as String,
      timestamp: DateTime.parse(json['timestamp'] as String),
      eventType: EmergencyAuditEventType.fromCode(json['eventType'] as String),
      actorDeviceId: json['actorDeviceId'] as String?,
      actorUserId: json['actorUserId'] as String?,
      actorRole: json['actorRole'] as String?,
      hopCount: json['hopCount'] as int?,
      verificationState: json['verificationState'] as String?,
      details: parsedDetails,
    );
  }
}
