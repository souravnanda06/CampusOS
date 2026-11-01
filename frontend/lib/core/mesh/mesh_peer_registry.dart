import 'dart:async';
import 'dart:typed_data';

import 'mesh_peer.dart';

/// Registry tracking discovered peers in the CampusOS BLE Mesh network.
///
/// Features:
/// - Maintains authentic observed peer metrics (RSSI, hop count, last seen).
/// - Exposes reactive streams for peer addition, removal/inactivity, and updates.
/// - Automatically evaluates and manages peer active/inactive lifecycles.
class MeshPeerRegistry {
  /// Default duration of inactivity before a peer is deemed inactive.
  static const Duration defaultActiveTimeout = Duration(seconds: 60);

  /// Default maximum peers to track concurrently.
  static const int defaultMaxPeers = 200;

  /// Duration after which an unobserved peer is considered inactive.
  final Duration peerActiveTimeout;

  /// Maximum peers tracked in the registry.
  final int maxPeers;

  /// Internal storage mapping device ID -> [MeshPeer].
  final Map<String, MeshPeer> _peers = {};

  final StreamController<MeshPeer> _peerAddedController =
      StreamController<MeshPeer>.broadcast();

  final StreamController<MeshPeer> _peerRemovedController =
      StreamController<MeshPeer>.broadcast();

  final StreamController<MeshPeer> _peerUpdatedController =
      StreamController<MeshPeer>.broadcast();

  MeshPeerRegistry({
    this.peerActiveTimeout = defaultActiveTimeout,
    this.maxPeers = defaultMaxPeers,
  });

  /// Total count of all known peers (active and inactive).
  int get peerCount => _peers.length;

  /// List of currently active peers.
  List<MeshPeer> get activePeers {
    return _peers.values.where((p) => p.isActive).toList(growable: false);
  }

  /// List of all peers currently in the registry.
  List<MeshPeer> get allPeers => _peers.values.toList(growable: false);

  /// Broadcast stream fired when a new peer is discovered.
  Stream<MeshPeer> get peerAdded => _peerAddedController.stream;

  /// Broadcast stream fired when a peer transitions to inactive or is removed.
  Stream<MeshPeer> get peerRemoved => _peerRemovedController.stream;

  /// Broadcast stream fired when an existing peer's telemetry is updated.
  Stream<MeshPeer> get peerUpdated => _peerUpdatedController.stream;

  /// Registers a newly discovered peer or updates an existing peer's telemetry.
  ///
  /// Does not fabricate telemetry: RSSI and hop count are only updated if provided.
  MeshPeer registerOrUpdatePeer({
    required String deviceId,
    required String role,
    Uint8List? packetId,
    int? rssi,
    int? hopCount,
    DateTime? seenAt,
  }) {
    if (deviceId.trim().isEmpty) {
      throw ArgumentError.value(deviceId, 'deviceId', 'Device ID cannot be empty');
    }

    final timestamp = seenAt ?? DateTime.now();
    final existingPeer = _peers[deviceId];

    if (existingPeer == null) {
      // Evict oldest inactive peer if at capacity
      if (_peers.length >= maxPeers) {
        _evictOldestPeer();
      }

      final newPeer = MeshPeer(
        deviceId: deviceId,
        role: role,
        firstSeen: timestamp,
        lastSeen: timestamp,
        lastPacketId: packetId,
        observedRssi: rssi,
        observedHopCount: hopCount,
        isActive: true,
      );

      _peers[deviceId] = newPeer;
      _peerAddedController.add(newPeer);
      return newPeer;
    } else {
      final wasActive = existingPeer.isActive;
      final updatedPeer = existingPeer.copyWith(
        role: role.isNotEmpty ? role : existingPeer.role,
        lastSeen: timestamp,
        lastPacketId: packetId ?? existingPeer.lastPacketId,
        observedRssi: rssi ?? existingPeer.observedRssi,
        observedHopCount: hopCount ?? existingPeer.observedHopCount,
        isActive: true,
      );

      _peers[deviceId] = updatedPeer;

      if (!wasActive) {
        // Re-activated peer
        _peerAddedController.add(updatedPeer);
      } else {
        _peerUpdatedController.add(updatedPeer);
      }

      return updatedPeer;
    }
  }

  /// Fetches a peer by device ID if present.
  MeshPeer? getPeer(String deviceId) => _peers[deviceId];

  /// Checks for peers that have exceeded the [peerActiveTimeout] without an update.
  ///
  /// Marks them inactive and notifies [peerRemoved].
  /// Returns the list of peers that transitioned to inactive.
  List<MeshPeer> cleanupInactivePeers([DateTime? now]) {
    final currentTime = now ?? DateTime.now();
    final newlyInactive = <MeshPeer>[];

    for (final entry in _peers.entries) {
      final peer = entry.value;
      if (peer.isActive) {
        final elapsed = currentTime.difference(peer.lastSeen);
        if (elapsed > peerActiveTimeout) {
          final inactivePeer = peer.copyWith(isActive: false);
          _peers[entry.key] = inactivePeer;
          newlyInactive.add(inactivePeer);
          _peerRemovedController.add(inactivePeer);
        }
      }
    }

    return newlyInactive;
  }

  /// Evicts the oldest peer from registry to preserve bound limits.
  void _evictOldestPeer() {
    // Prefer evicting inactive peers first
    String? candidateKey;
    DateTime? oldestSeen;

    for (final entry in _peers.entries) {
      if (!entry.value.isActive) {
        if (oldestSeen == null || entry.value.lastSeen.isBefore(oldestSeen)) {
          oldestSeen = entry.value.lastSeen;
          candidateKey = entry.key;
        }
      }
    }

    // If all are active, evict the peer with oldest lastSeen
    if (candidateKey == null && _peers.isNotEmpty) {
      for (final entry in _peers.entries) {
        if (oldestSeen == null || entry.value.lastSeen.isBefore(oldestSeen)) {
          oldestSeen = entry.value.lastSeen;
          candidateKey = entry.key;
        }
      }
    }

    if (candidateKey != null) {
      final removed = _peers.remove(candidateKey);
      if (removed != null && removed.isActive) {
        _peerRemovedController.add(removed.copyWith(isActive: false));
      }
    }
  }

  /// Clears all registered peers.
  void clear() {
    _peers.clear();
  }

  /// Closes the event stream controllers.
  Future<void> dispose() async {
    await _peerAddedController.close();
    await _peerRemovedController.close();
    await _peerUpdatedController.close();
  }
}
