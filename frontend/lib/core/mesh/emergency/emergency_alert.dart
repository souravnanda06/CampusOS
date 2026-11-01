import 'dart:convert';
import 'dart:typed_data';

/// Severity level of an institutional emergency disaster flare alert.
enum EmergencySeverity {
  advisory('a', 'ADVISORY'),
  warning('w', 'WARNING'),
  critical('c', 'CRITICAL');

  final String code;
  final String label;
  const EmergencySeverity(this.code, this.label);

  static EmergencySeverity fromCode(String code) {
    for (final s in EmergencySeverity.values) {
      if (s.code == code || s.name.toLowerCase() == code.toLowerCase()) {
        return s;
      }
    }
    throw ArgumentError('Invalid emergency severity code: "$code"');
  }

  static EmergencySeverity? tryFromCode(String? code) {
    if (code == null) return null;
    for (final s in EmergencySeverity.values) {
      if (s.code == code || s.name.toLowerCase() == code.toLowerCase()) {
        return s;
      }
    }
    return null;
  }
}

/// Category of an institutional emergency alert.
enum EmergencyCategory {
  cyclone('cyclone', 'Cyclone'),
  fire('fire', 'Fire Emergency'),
  evacuation('evacuation', 'Campus Evacuation'),
  power('power', 'Power Outage'),
  security('security', 'Security Alert'),
  weather('weather', 'Severe Weather'),
  hostel('hostel', 'Hostel Emergency'),
  other('other', 'General Emergency');

  final String code;
  final String label;
  const EmergencyCategory(this.code, this.label);

  static EmergencyCategory fromCode(String code) {
    for (final c in EmergencyCategory.values) {
      if (c.code == code || c.name.toLowerCase() == code.toLowerCase()) {
        return c;
      }
    }
    throw ArgumentError('Invalid emergency category code: "$code"');
  }

  static EmergencyCategory? tryFromCode(String? code) {
    if (code == null) return null;
    for (final c in EmergencyCategory.values) {
      if (c.code == code || c.name.toLowerCase() == code.toLowerCase()) {
        return c;
      }
    }
    return null;
  }
}

/// Standard emergency scope identifiers for institutional authority delegation.
class EmergencyScope {
  /// Campus-wide broadcast (Dean, Director, Admin only).
  static const String campus = 'campus';

  /// General hostel-wide broadcast.
  static const String hostel = 'hostel';

  /// Academic facilities broadcast.
  static const String academic = 'academic';

  /// Administrative facilities broadcast.
  static const String administrative = 'administrative';

  /// Helper generating a specific hostel block scope (e.g., 'hostel:block-b').
  static String hostelBlock(String block) => 'hostel:${block.trim().toLowerCase()}';

  /// Helper generating a specific department academic scope (e.g., 'department:cse').
  static String department(String dept) => 'department:${dept.trim().toLowerCase()}';
}

/// Relay priority tier for emergency alerts over BLE mesh.
enum EmergencyRelayPriority {
  normal('n', 1),
  high('h', 2),
  critical('c', 3);

  final String code;
  final int rank;
  const EmergencyRelayPriority(this.code, this.rank);

  static EmergencyRelayPriority fromCode(String code) {
    for (final p in EmergencyRelayPriority.values) {
      if (p.code == code || p.name.toLowerCase() == code.toLowerCase()) {
        return p;
      }
    }
    return EmergencyRelayPriority.high;
  }
}

/// Local transmission and delivery status for an emergency alert.
enum EmergencyDeliveryState {
  queued('Queued'),
  broadcasting('Broadcasting'),
  relayed('Relaying'),
  received('Received'),
  failed('Failed'),
  expired('Expired');

  final String label;
  const EmergencyDeliveryState(this.label);

  static EmergencyDeliveryState fromString(String val) {
    for (final s in EmergencyDeliveryState.values) {
      if (s.name.toLowerCase() == val.toLowerCase()) return s;
    }
    return EmergencyDeliveryState.received;
  }
}

/// Domain model representing an official CampusOS Emergency Disaster Flare alert.
class EmergencyAlert {
  /// 16-byte logical alert identifier (32-character hexadecimal string).
  final String alertId;

  /// Identifier of the hardware device that originated the alert.
  final String issuerDeviceId;

  /// Institutional user ID of the issuer (if resolved from trust bundle).
  final String? issuerUserId;

  /// Verified role of the issuer (e.g., 'ADMIN', 'DEAN', 'WARDEN').
  final String issuerRole;

  /// Geographic / institutional scope of the alert (e.g., 'campus', 'hostel:b').
  final String scope;

  /// Severity level of the emergency.
  final EmergencySeverity severity;

  /// Classification category of the emergency.
  final EmergencyCategory category;

  /// High-visibility headline title (maximum 48 characters).
  final String title;

  /// Detailed emergency advisory message (maximum 180 characters).
  final String message;

  /// Origin creation timestamp.
  final DateTime createdAt;

  /// Timestamp after which the alert is no longer active.
  final DateTime expiresAt;

  /// Associated mesh channel identifier (defaults to '#emergency').
  final String channelId;

  /// Relay priority tier for mesh forwarding.
  final EmergencyRelayPriority relayPriority;

  /// Local timestamp when this alert was first observed by this node.
  final DateTime firstSeenAt;

  /// Local timestamp when this alert was most recently received/forwarded.
  final DateTime lastSeenAt;

  /// Observed protocol-level relay hop count (0 = direct origin).
  final int hopCount;

  /// Local transmission/delivery status.
  final EmergencyDeliveryState deliveryState;

  /// Cryptographic verification status against institutional trust bundle ('TRUSTED', 'UNVERIFIED', 'REVOKED').
  final String verificationState;

  /// Number of times this alert has been observed/relayed locally.
  final int relayCount;

  /// Whether the local user has explicitly acknowledged reading this emergency alert.
  final bool isAcknowledged;

  const EmergencyAlert({
    required this.alertId,
    required this.issuerDeviceId,
    this.issuerUserId,
    required this.issuerRole,
    required this.scope,
    required this.severity,
    required this.category,
    required this.title,
    required this.message,
    required this.createdAt,
    required this.expiresAt,
    this.channelId = 'channel:emergency',
    this.relayPriority = EmergencyRelayPriority.high,
    required this.firstSeenAt,
    required this.lastSeenAt,
    this.hopCount = 0,
    this.deliveryState = EmergencyDeliveryState.received,
    this.verificationState = 'TRUSTED',
    this.relayCount = 1,
    this.isAcknowledged = false,
  });

  /// Whether this alert is still active (not yet expired).
  bool isActive([DateTime? now]) {
    final checkTime = now ?? DateTime.now();
    return checkTime.isBefore(expiresAt);
  }

  /// Whether this alert is critical severity.
  bool get isCritical => severity == EmergencySeverity.critical;

  /// Whether this alert is cryptographically certified and verified.
  bool get isTrusted => verificationState == 'TRUSTED';

  /// Human-readable hop telemetry description.
  String get hopDescription {
    if (hopCount == 0) return '1 hop · Direct';
    return '${hopCount + 1} hops · Relayed';
  }

  EmergencyAlert copyWith({
    String? alertId,
    String? issuerDeviceId,
    String? issuerUserId,
    String? issuerRole,
    String? scope,
    EmergencySeverity? severity,
    EmergencyCategory? category,
    String? title,
    String? message,
    DateTime? createdAt,
    DateTime? expiresAt,
    String? channelId,
    EmergencyRelayPriority? relayPriority,
    DateTime? firstSeenAt,
    DateTime? lastSeenAt,
    int? hopCount,
    EmergencyDeliveryState? deliveryState,
    String? verificationState,
    int? relayCount,
    bool? isAcknowledged,
  }) {
    return EmergencyAlert(
      alertId: alertId ?? this.alertId,
      issuerDeviceId: issuerDeviceId ?? this.issuerDeviceId,
      issuerUserId: issuerUserId ?? this.issuerUserId,
      issuerRole: issuerRole ?? this.issuerRole,
      scope: scope ?? this.scope,
      severity: severity ?? this.severity,
      category: category ?? this.category,
      title: title ?? this.title,
      message: message ?? this.message,
      createdAt: createdAt ?? this.createdAt,
      expiresAt: expiresAt ?? this.expiresAt,
      channelId: channelId ?? this.channelId,
      relayPriority: relayPriority ?? this.relayPriority,
      firstSeenAt: firstSeenAt ?? this.firstSeenAt,
      lastSeenAt: lastSeenAt ?? this.lastSeenAt,
      hopCount: hopCount ?? this.hopCount,
      deliveryState: deliveryState ?? this.deliveryState,
      verificationState: verificationState ?? this.verificationState,
      relayCount: relayCount ?? this.relayCount,
      isAcknowledged: isAcknowledged ?? this.isAcknowledged,
    );
  }
}

/// Compact wire payload carried inside a [MeshPacket] of type [MeshPacketType.emergency].
class EmergencyPayload {
  /// Maximum allowed title characters.
  static const int maxTitleLength = 48;

  /// Maximum allowed message characters.
  static const int maxMessageLength = 180;

  final String title;
  final String message;
  final String scope;
  final EmergencySeverity severity;
  final EmergencyCategory category;
  final EmergencyRelayPriority priority;
  final DateTime expiresAt;
  final String? issuerUserId;

  EmergencyPayload({
    required this.title,
    required this.message,
    required this.scope,
    required this.severity,
    required this.category,
    required this.priority,
    required this.expiresAt,
    this.issuerUserId,
  }) {
    final trimmedTitle = title.trim();
    final trimmedMessage = message.trim();
    if (trimmedTitle.isEmpty) {
      throw ArgumentError('Emergency title cannot be empty.');
    }
    if (trimmedTitle.length > maxTitleLength) {
      throw ArgumentError(
        'Emergency title exceeds $maxTitleLength characters (got ${trimmedTitle.length}).',
      );
    }
    if (trimmedMessage.isEmpty) {
      throw ArgumentError('Emergency message cannot be empty.');
    }
    if (trimmedMessage.length > maxMessageLength) {
      throw ArgumentError(
        'Emergency message exceeds $maxMessageLength characters (got ${trimmedMessage.length}).',
      );
    }
    if (scope.trim().isEmpty) {
      throw ArgumentError('Emergency scope cannot be empty.');
    }
  }

  /// Serializes into compact UTF-8 JSON bytes for BLE advertisement transport.
  Uint8List toBytes() {
    final map = <String, dynamic>{
      't': title.trim(),
      'm': message.trim(),
      's': scope.trim().toLowerCase(),
      'v': severity.code,
      'c': category.code,
      'p': priority.code,
      'e': expiresAt.toUtc().millisecondsSinceEpoch ~/ 1000,
    };
    if (issuerUserId != null && issuerUserId!.isNotEmpty) {
      map['u'] = issuerUserId;
    }
    return Uint8List.fromList(utf8.encode(jsonEncode(map)));
  }

  /// Deserializes from raw payload bytes with strict validation.
  factory EmergencyPayload.fromBytes(Uint8List bytes) {
    if (bytes.isEmpty) {
      throw const FormatException('Emergency payload bytes cannot be empty.');
    }

    dynamic decoded;
    try {
      final jsonStr = utf8.decode(bytes);
      decoded = jsonDecode(jsonStr);
    } catch (e) {
      throw FormatException('Failed to decode emergency payload JSON: $e');
    }

    if (decoded is! Map) {
      throw const FormatException('Emergency payload JSON must be an object.');
    }

    final rawTitle = decoded['t']?.toString() ?? '';
    final rawMessage = decoded['m']?.toString() ?? '';
    final rawScope = decoded['s']?.toString() ?? '';
    final rawSeverity = decoded['v']?.toString() ?? '';
    final rawCategory = decoded['c']?.toString() ?? '';
    final rawPriority = decoded['p']?.toString() ?? 'h';
    final rawExpiresAt = decoded['e'];

    if (rawTitle.trim().isEmpty) {
      throw const FormatException('Emergency payload missing title ("t").');
    }
    if (rawTitle.length > maxTitleLength) {
      throw const FormatException('Emergency title exceeds $maxTitleLength characters.');
    }
    if (rawMessage.trim().isEmpty) {
      throw const FormatException('Emergency payload missing message ("m").');
    }
    if (rawMessage.length > maxMessageLength) {
      throw const FormatException('Emergency message exceeds $maxMessageLength characters.');
    }
    if (rawScope.trim().isEmpty) {
      throw const FormatException('Emergency payload missing scope ("s").');
    }

    final severity = EmergencySeverity.tryFromCode(rawSeverity);
    if (severity == null) {
      throw FormatException('Invalid emergency severity ("v"): "$rawSeverity"');
    }

    final category = EmergencyCategory.tryFromCode(rawCategory);
    if (category == null) {
      throw FormatException('Invalid emergency category ("c"): "$rawCategory"');
    }

    final priority = EmergencyRelayPriority.fromCode(rawPriority);

    int expiresUnixSeconds;
    if (rawExpiresAt is int) {
      expiresUnixSeconds = rawExpiresAt;
    } else if (rawExpiresAt is num) {
      expiresUnixSeconds = rawExpiresAt.toInt();
    } else {
      throw const FormatException('Emergency payload missing valid expiresAt epoch ("e").');
    }

    final expiresAt = DateTime.fromMillisecondsSinceEpoch(
      expiresUnixSeconds * 1000,
      isUtc: true,
    );

    return EmergencyPayload(
      title: rawTitle,
      message: rawMessage,
      scope: rawScope,
      severity: severity,
      category: category,
      priority: priority,
      expiresAt: expiresAt,
      issuerUserId: decoded['u']?.toString(),
    );
  }
}
