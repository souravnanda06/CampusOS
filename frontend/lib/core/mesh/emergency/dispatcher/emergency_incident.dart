import '../emergency_alert.dart';

/// Lifecycle states for an emergency incident dispatched over CampusOS Mesh.
enum EmergencyIncidentStatus {
  draft('Draft'),
  ready('Ready'),
  dispatching('Dispatching'),
  active('Active'),
  partiallyPropagated('Partially Propagated'),
  cancelled('Cancelled'),
  expired('Expired'),
  failed('Failed');

  final String label;
  const EmergencyIncidentStatus(this.label);

  static EmergencyIncidentStatus fromString(String val) {
    for (final s in EmergencyIncidentStatus.values) {
      if (s.name.toLowerCase() == val.toLowerCase()) return s;
    }
    return EmergencyIncidentStatus.active;
  }
}

/// Domain model representing an institutional emergency incident dispatched by
/// a Dean or authorized campus authority over the CampusOS Mesh network.
class EmergencyIncident {
  /// Unique 32-hex incident identifier.
  final String incidentId;

  /// Underlying 16-byte mesh packet / alert identifier (32-hex).
  final String alertId;

  /// Headline title of the incident (maximum 48 characters).
  final String title;

  /// Detailed emergency advisory message (maximum 180 characters).
  final String message;

  /// Classification category of the emergency.
  final EmergencyCategory category;

  /// Severity level of the incident.
  final EmergencySeverity severity;

  /// Mesh relay priority tier.
  final EmergencyRelayPriority priority;

  /// Geographic / institutional scope (e.g. 'campus', 'hostel:block-b', 'academic').
  final String scope;

  /// Hardware device ID of the originating authority.
  final String issuerDeviceId;

  /// Verified institutional user ID of the issuer (if resolved from trust bundle).
  final String? issuerUserId;

  /// Institutional role of the originating authority (e.g. 'DEAN', 'ADMIN', 'WARDEN').
  final String issuerRole;

  /// Timestamp when the incident was created and dispatched.
  final DateTime createdAt;

  /// Timestamp after which the incident automatically expires.
  final DateTime expiresAt;

  /// Timestamp when the incident was cancelled (null if not cancelled).
  final DateTime? cancelledAt;

  /// Explanatory reason for cancellation (null if not cancelled).
  final String? cancelReason;

  /// Device ID of the authority that cancelled the incident.
  final String? cancelledByDeviceId;

  /// Role of the authority that cancelled the incident.
  final String? cancelledByRole;

  /// Current lifecycle state of the incident.
  final EmergencyIncidentStatus status;

  /// Observed shortest relay hop count (0 = direct origin).
  final int hopCount;

  /// Total number of relay packet observations recorded by local mesh nodes.
  final int relayCount;

  /// Number of distinct local peer nodes observed carrying / receiving this incident.
  final int localDeliveryCount;

  /// Number of verifiable cryptographic acknowledgements received from peer nodes.
  final int acknowledgementCount;

  /// Timestamp of the most recent propagation telemetry observation.
  final DateTime? lastPropagationAt;

  /// Cryptographic signature verification status ('TRUSTED', 'UNVERIFIED', 'REVOKED').
  final String signatureVerificationState;

  /// Whether this incident broadcast an audible siren directive.
  final bool sirenEnabled;

  /// Audible siren pattern associated with this incident.
  final EmergencySirenPattern sirenPattern;

  const EmergencyIncident({
    required this.incidentId,
    required this.alertId,
    required this.title,
    required this.message,
    required this.category,
    required this.severity,
    required this.priority,
    required this.scope,
    required this.issuerDeviceId,
    this.issuerUserId,
    required this.issuerRole,
    required this.createdAt,
    required this.expiresAt,
    this.cancelledAt,
    this.cancelReason,
    this.cancelledByDeviceId,
    this.cancelledByRole,
    this.status = EmergencyIncidentStatus.active,
    this.hopCount = 0,
    this.relayCount = 1,
    this.localDeliveryCount = 0,
    this.acknowledgementCount = 0,
    this.lastPropagationAt,
    this.signatureVerificationState = 'TRUSTED',
    this.sirenEnabled = false,
    this.sirenPattern = EmergencySirenPattern.none,
  });

  bool get hasSiren =>
      sirenEnabled && sirenPattern != EmergencySirenPattern.none;

  /// Whether the incident is currently active.
  bool isActive([DateTime? now]) {
    if (status == EmergencyIncidentStatus.cancelled ||
        status == EmergencyIncidentStatus.expired ||
        status == EmergencyIncidentStatus.failed) {
      return false;
    }
    final checkTime = now ?? DateTime.now();
    return checkTime.isBefore(expiresAt);
  }

  /// Whether the incident has been officially cancelled.
  bool get isCancelled => status == EmergencyIncidentStatus.cancelled || cancelledAt != null;

  /// Whether the incident has expired.
  bool isExpired([DateTime? now]) {
    if (status == EmergencyIncidentStatus.expired) return true;
    final checkTime = now ?? DateTime.now();
    return checkTime.isAfter(expiresAt);
  }

  /// Formatted remaining duration until expiration.
  String get remainingTimeFormatted {
    final now = DateTime.now();
    if (now.isAfter(expiresAt)) return 'Expired';
    final diff = expiresAt.difference(now);
    if (diff.inHours > 0) {
      final mins = diff.inMinutes % 60;
      return '${diff.inHours}h ${mins}m';
    }
    final secs = diff.inSeconds % 60;
    return '${diff.inMinutes}m ${secs}s';
  }

  /// Truthful hop telemetry summary.
  String get hopTelemetryDescription {
    if (hopCount == 0) return 'Direct Origin (0 hops)';
    return '$hopCount ${hopCount == 1 ? 'hop' : 'hops'} relayed';
  }

  /// Truthful acknowledgement summary.
  String get acknowledgementSummary {
    if (acknowledgementCount == 0) {
      return 'ACK telemetry unavailable (0 observed)';
    }
    return '$acknowledgementCount local ${acknowledgementCount == 1 ? 'ACK' : 'ACKs'} observed';
  }

  EmergencyIncident copyWith({
    String? incidentId,
    String? alertId,
    String? title,
    String? message,
    EmergencyCategory? category,
    EmergencySeverity? severity,
    EmergencyRelayPriority? priority,
    String? scope,
    String? issuerDeviceId,
    String? issuerUserId,
    String? issuerRole,
    DateTime? createdAt,
    DateTime? expiresAt,
    DateTime? cancelledAt,
    String? cancelReason,
    String? cancelledByDeviceId,
    String? cancelledByRole,
    EmergencyIncidentStatus? status,
    int? hopCount,
    int? relayCount,
    int? localDeliveryCount,
    int? acknowledgementCount,
    DateTime? lastPropagationAt,
    String? signatureVerificationState,
    bool? sirenEnabled,
    EmergencySirenPattern? sirenPattern,
  }) {
    return EmergencyIncident(
      incidentId: incidentId ?? this.incidentId,
      alertId: alertId ?? this.alertId,
      title: title ?? this.title,
      message: message ?? this.message,
      category: category ?? this.category,
      severity: severity ?? this.severity,
      priority: priority ?? this.priority,
      scope: scope ?? this.scope,
      issuerDeviceId: issuerDeviceId ?? this.issuerDeviceId,
      issuerUserId: issuerUserId ?? this.issuerUserId,
      issuerRole: issuerRole ?? this.issuerRole,
      createdAt: createdAt ?? this.createdAt,
      expiresAt: expiresAt ?? this.expiresAt,
      cancelledAt: cancelledAt ?? this.cancelledAt,
      cancelReason: cancelReason ?? this.cancelReason,
      cancelledByDeviceId: cancelledByDeviceId ?? this.cancelledByDeviceId,
      cancelledByRole: cancelledByRole ?? this.cancelledByRole,
      status: status ?? this.status,
      hopCount: hopCount ?? this.hopCount,
      relayCount: relayCount ?? this.relayCount,
      localDeliveryCount: localDeliveryCount ?? this.localDeliveryCount,
      acknowledgementCount: acknowledgementCount ?? this.acknowledgementCount,
      lastPropagationAt: lastPropagationAt ?? this.lastPropagationAt,
      signatureVerificationState: signatureVerificationState ?? this.signatureVerificationState,
      sirenEnabled: sirenEnabled ?? this.sirenEnabled,
      sirenPattern: sirenPattern ?? this.sirenPattern,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'incidentId': incidentId,
      'alertId': alertId,
      'title': title,
      'message': message,
      'category': category.name,
      'severity': severity.name,
      'priority': priority.code,
      'scope': scope,
      'issuerDeviceId': issuerDeviceId,
      'issuerUserId': issuerUserId,
      'issuerRole': issuerRole,
      'createdAt': createdAt.toIso8601String(),
      'expiresAt': expiresAt.toIso8601String(),
      'cancelledAt': cancelledAt?.toIso8601String(),
      'cancelReason': cancelReason,
      'cancelledByDeviceId': cancelledByDeviceId,
      'cancelledByRole': cancelledByRole,
      'status': status.name,
      'hopCount': hopCount,
      'relayCount': relayCount,
      'localDeliveryCount': localDeliveryCount,
      'acknowledgementCount': acknowledgementCount,
      'lastPropagationAt': lastPropagationAt?.toIso8601String(),
      'signatureVerificationState': signatureVerificationState,
      'sirenEnabled': sirenEnabled,
      'sirenPattern': sirenPattern.code,
    };
  }

  factory EmergencyIncident.fromJson(Map<String, dynamic> json) {
    return EmergencyIncident(
      incidentId: json['incidentId'] as String,
      alertId: json['alertId'] as String,
      title: json['title'] as String,
      message: json['message'] as String,
      category: EmergencyCategory.fromCode(json['category'] as String),
      severity: EmergencySeverity.fromCode(json['severity'] as String),
      priority: EmergencyRelayPriority.fromCode(json['priority'] as String? ?? 'h'),
      scope: json['scope'] as String,
      issuerDeviceId: json['issuerDeviceId'] as String,
      issuerUserId: json['issuerUserId'] as String?,
      issuerRole: json['issuerRole'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      expiresAt: DateTime.parse(json['expiresAt'] as String),
      cancelledAt: json['cancelledAt'] != null ? DateTime.parse(json['cancelledAt'] as String) : null,
      cancelReason: json['cancelReason'] as String?,
      cancelledByDeviceId: json['cancelledByDeviceId'] as String?,
      cancelledByRole: json['cancelledByRole'] as String?,
      status: EmergencyIncidentStatus.fromString(json['status'] as String),
      hopCount: json['hopCount'] as int? ?? 0,
      relayCount: json['relayCount'] as int? ?? 1,
      localDeliveryCount: json['localDeliveryCount'] as int? ?? 0,
      acknowledgementCount: json['acknowledgementCount'] as int? ?? 0,
      lastPropagationAt: json['lastPropagationAt'] != null ? DateTime.parse(json['lastPropagationAt'] as String) : null,
      signatureVerificationState: json['signatureVerificationState'] as String? ?? 'TRUSTED',
      sirenEnabled: json['sirenEnabled'] == true,
      sirenPattern: EmergencySirenPattern.fromCode(json['sirenPattern']?.toString()),
    );
  }
}
