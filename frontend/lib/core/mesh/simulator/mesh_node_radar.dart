import 'dart:async';
import 'dart:math' as math;

import '../campus_mesh_service.dart';
import '../mesh_peer.dart';
import '../../../../student/models/passport_trust_bundle_model.dart';

/// Representation of a node visualized on the Campus Mesh Radar screen.
class RadarNodeItem {
  final String deviceId;
  final String displayName;
  final String role;
  final bool isTrusted;
  final int rssi;
  final int hopCount;
  final DateTime lastSeen;
  final bool isOnline;

  const RadarNodeItem({
    required this.deviceId,
    required this.displayName,
    required this.role,
    required this.isTrusted,
    required this.rssi,
    required this.hopCount,
    required this.lastSeen,
    this.isOnline = true,
  });

  /// Signal strength normalized between 0.0 (weak/out of range) and 1.0 (strong).
  double get signalStrengthNormalized {
    // Typical BLE RSSI ranges from -100 dBm to -40 dBm
    final clamped = rssi.clamp(-100, -40);
    return (clamped - (-100)) / ((-40) - (-100));
  }

  /// Estimated distance fraction from radar center (0.1 = closest, 0.9 = edge).
  double get radarRadiusFraction {
    return 1.0 - (signalStrengthNormalized * 0.8);
  }

  /// Human-readable signal label.
  String get signalLabel {
    if (rssi >= -60) return 'Strong ($rssi dBm)';
    if (rssi >= -75) return 'Good ($rssi dBm)';
    if (rssi >= -85) return 'Fair ($rssi dBm)';
    return 'Weak ($rssi dBm)';
  }

  /// Display string for institutional verification status.
  String get verificationBadge {
    if (!isTrusted) return 'UNKNOWN · UNVERIFIED';
    return '${role.toUpperCase()} · VERIFIED';
  }
}

/// Service managing Live Node Radar state from physical BLE scanning or simulated nodes.
class MeshNodeRadarService {
  final CampusMeshService? liveMeshService;
  final PassportTrustBundle? trustBundle;

  final StreamController<List<RadarNodeItem>> _radarNodesController =
      StreamController<List<RadarNodeItem>>.broadcast();

  StreamSubscription? _peerSubscription;
  List<RadarNodeItem> _cachedItems = [];
  bool _isScanning = false;

  MeshNodeRadarService({
    this.liveMeshService,
    this.trustBundle,
  });

  Stream<List<RadarNodeItem>> get onRadarNodes => _radarNodesController.stream;
  List<RadarNodeItem> get currentNodes => List.unmodifiable(_cachedItems);
  bool get isScanning => _isScanning;

  /// Starts listening to real BLE peer updates from CampusMeshService.
  Future<void> startLiveRadar() async {
    if (liveMeshService == null) return;

    _isScanning = true;
    await _peerSubscription?.cancel();

    _peerSubscription = liveMeshService!.peerUpdates.listen((peers) {
      _cachedItems = _mapPeersToRadarItems(peers);
      if (!_radarNodesController.isClosed) {
        _radarNodesController.add(_cachedItems);
      }
    });

    // Populate initial peers
    _cachedItems = _mapPeersToRadarItems(liveMeshService!.peerRegistry.activePeers);
    if (!_radarNodesController.isClosed) {
      _radarNodesController.add(_cachedItems);
    }
  }

  /// Injects simulated radar nodes for visual demonstration.
  void setSimulatedNodes(List<RadarNodeItem> nodes) {
    _cachedItems = List.from(nodes);
    if (!_radarNodesController.isClosed) {
      _radarNodesController.add(_cachedItems);
    }
  }

  List<RadarNodeItem> _mapPeersToRadarItems(List<MeshPeer> peers) {
    return peers.map((peer) {
      String resolvedName = peer.deviceId;
      bool isTrusted = false;

      if (trustBundle != null) {
        for (final id in trustBundle!.identities) {
          if (id.userId == peer.deviceId || id.keyId == peer.deviceId) {
            resolvedName = id.userName ?? id.userId;
            isTrusted = id.status.toUpperCase() == 'ACTIVE';
            break;
          }
        }
      }

      return RadarNodeItem(
        deviceId: peer.deviceId,
        displayName: isTrusted ? resolvedName : 'Node ${peer.deviceId.substring(0, math.min(6, peer.deviceId.length))}',
        role: peer.role,
        isTrusted: isTrusted,
        rssi: peer.observedRssi ?? -70,
        hopCount: peer.observedHopCount ?? 0,
        lastSeen: peer.lastSeen,
        isOnline: peer.isActive,
      );
    }).toList();
  }

  Future<void> stop() async {
    _isScanning = false;
    await _peerSubscription?.cancel();
  }

  Future<void> dispose() async {
    await stop();
    await _radarNodesController.close();
  }
}
