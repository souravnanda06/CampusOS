import 'dart:typed_data';

/// Represents a peer node observed in the CampusOS BLE Mesh network.
///
/// Contains genuine observed metrics (RSSI, hop count, timestamps) without fabricated telemetry.
class MeshPeer {
  /// Unique device identifier of the peer.
  final String deviceId;

  /// CampusOS role of the peer (e.g., student, teacher, admin).
  final String role;

  /// Timestamp when this peer was first observed by the local node.
  final DateTime firstSeen;

  /// Timestamp of the most recent advertisement / packet observed from this peer.
  final DateTime lastSeen;

  /// 16-byte identifier of the last packet observed from this peer.
  final Uint8List? lastPacketId;

  /// Last observed RSSI signal strength (dBm) when available.
  final int? observedRssi;

  /// Last observed protocol hop count when available.
  final int? observedHopCount;

  /// Whether this peer is currently considered active.
  final bool isActive;

  const MeshPeer({
    required this.deviceId,
    required this.role,
    required this.firstSeen,
    required this.lastSeen,
    this.lastPacketId,
    this.observedRssi,
    this.observedHopCount,
    this.isActive = true,
  });

  /// Creates a copy of this [MeshPeer] with updated attributes.
  MeshPeer copyWith({
    String? deviceId,
    String? role,
    DateTime? firstSeen,
    DateTime? lastSeen,
    Uint8List? lastPacketId,
    int? observedRssi,
    int? observedHopCount,
    bool? isActive,
  }) {
    return MeshPeer(
      deviceId: deviceId ?? this.deviceId,
      role: role ?? this.role,
      firstSeen: firstSeen ?? this.firstSeen,
      lastSeen: lastSeen ?? this.lastSeen,
      lastPacketId: lastPacketId ?? this.lastPacketId,
      observedRssi: observedRssi ?? this.observedRssi,
      observedHopCount: observedHopCount ?? this.observedHopCount,
      isActive: isActive ?? this.isActive,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! MeshPeer) return false;
    return deviceId == other.deviceId &&
        role == other.role &&
        firstSeen.millisecondsSinceEpoch == other.firstSeen.millisecondsSinceEpoch &&
        lastSeen.millisecondsSinceEpoch == other.lastSeen.millisecondsSinceEpoch &&
        observedRssi == other.observedRssi &&
        observedHopCount == other.observedHopCount &&
        isActive == other.isActive;
  }

  @override
  int get hashCode {
    return Object.hash(
      deviceId,
      role,
      firstSeen.millisecondsSinceEpoch,
      lastSeen.millisecondsSinceEpoch,
      observedRssi,
      observedHopCount,
      isActive,
    );
  }

  @override
  String toString() {
    return 'MeshPeer(id: $deviceId, role: $role, rssi: $observedRssi, hops: $observedHopCount, active: $isActive, lastSeen: $lastSeen)';
  }
}
