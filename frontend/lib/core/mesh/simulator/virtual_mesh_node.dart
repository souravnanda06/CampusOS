import 'dart:typed_data';
import 'package:cryptography/cryptography.dart';
import 'package:flutter/foundation.dart';

import '../campus_mesh_service.dart';
import '../mesh_crypto.dart';
import '../mesh_deduplication_store.dart';
import '../mesh_packet.dart';
import '../mesh_packet_codec.dart';
import '../mesh_peer_registry.dart';
import '../mesh_relay_engine.dart';
import '../../../../student/models/passport_trust_bundle_model.dart';

/// Simulated physical position coordinates for 2D visual topology rendering.
class NodePosition {
  final double x;
  final double y;

  const NodePosition(this.x, this.y);

  @override
  String toString() => '($x, $y)';
}

/// Statistics counter for packets processed by a [VirtualMeshNode].
class VirtualNodeStats {
  int packetsSent = 0;
  int packetsReceived = 0;
  int packetsRelayed = 0;
  int packetsDeduplicated = 0;
  int packetsRejected = 0;

  void reset() {
    packetsSent = 0;
    packetsReceived = 0;
    packetsRelayed = 0;
    packetsDeduplicated = 0;
    packetsRejected = 0;
  }
}

/// Simulated transport adapter connecting a [VirtualMeshNode] to the [SimulatedMeshMedium].
class SimulatedNodeBleAdapter implements MeshBleAdapter {
  final String nodeId;
  void Function(Uint8List rawBytes, int rssi)? packetDiscoveredCallback;
  void Function(String senderNodeId, Uint8List rawBytes)? onTransmit;
  bool isScanningActive = false;
  bool isAdvertisingActive = false;

  SimulatedNodeBleAdapter({required this.nodeId});

  @override
  Future<bool> isBluetoothAvailable() async => true;

  @override
  Future<bool> requestPermissions() async => true;

  @override
  Future<bool> startScanning({
    required void Function(Uint8List rawBytes, int rssi) onPacketDiscovered,
  }) async {
    packetDiscoveredCallback = onPacketDiscovered;
    isScanningActive = true;
    return true;
  }

  @override
  Future<void> stopScanning() async {
    packetDiscoveredCallback = null;
    isScanningActive = false;
  }

  @override
  Future<bool> advertisePacket(Uint8List rawBytes) async {
    isAdvertisingActive = true;
    onTransmit?.call(nodeId, rawBytes);
    return true;
  }

  @override
  Future<void> stopAdvertising() async {
    isAdvertisingActive = false;
  }

  Future<void> pauseAdvertising() async {
    isAdvertisingActive = false;
  }

  Future<void> resumeAdvertising() async {}

  @override
  Future<void> dispose() async {
    packetDiscoveredCallback = null;
    onTransmit = null;
  }

  /// Injects an incoming simulated RF packet.
  void deliverInbound(Uint8List rawBytes, {int rssi = -60}) {
    if (isScanningActive) {
      packetDiscoveredCallback?.call(rawBytes, rssi);
    }
  }
}

/// Represents an autonomous node within the CampusOS Mesh Stage Simulator.
///
/// Crucially, each [VirtualMeshNode] executes the REAL protocol stack:
/// - Real [CampusMeshService]
/// - Real [MeshPacketCodec]
/// - Real [MeshRelayEngine]
/// - Real [MeshDeduplicationStore]
/// - Real Ed25519 [CampusMeshCryptoService] and [PassportTrustBundle]
///
/// Only the physical BLE radio propagation layer is simulated.
class VirtualMeshNode {
  final String nodeId;
  final String displayName;
  final String role;
  final NodePosition position;
  final SimpleKeyPair keyPair;
  final CampusMeshCryptoService cryptoService;
  final SimulatedNodeBleAdapter adapter;
  final CampusMeshService meshService;
  final VirtualNodeStats stats = VirtualNodeStats();

  bool isOnline;
  bool isTrusted;
  String statusMessage;
  MeshPacket? lastProcessedPacket;

  VirtualMeshNode({
    required this.nodeId,
    required this.displayName,
    required this.role,
    required this.position,
    required this.keyPair,
    required this.cryptoService,
    required this.adapter,
    required this.meshService,
    this.isOnline = true,
    this.isTrusted = true,
    this.statusMessage = 'Online · Ready',
  });

  /// Factory constructing a fully configured [VirtualMeshNode] with real cryptographic keypair.
  static Future<VirtualMeshNode> create({
    required String nodeId,
    required String displayName,
    required String role,
    required NodePosition position,
    required PassportTrustBundle trustBundle,
    SimpleKeyPair? customKeyPair,
    bool isTrusted = true,
  }) async {
    final algorithm = Ed25519();
    final keyPair = customKeyPair ?? await algorithm.newKeyPair();

    final cryptoService = CampusMeshCryptoService(
      algorithm: algorithm,
      localKeyPair: keyPair,
      mockTrustBundle: trustBundle,
    );

    final adapter = SimulatedNodeBleAdapter(nodeId: nodeId);
    final deduplicationStore = MeshDeduplicationStore(maxSize: 100);
    final peerRegistry = MeshPeerRegistry();
    final relayEngine = MeshRelayEngine(
      localDeviceId: nodeId,
      deduplicationStore: deduplicationStore,
    );

    final meshService = CampusMeshService(
      localDeviceId: nodeId,
      localRole: role,
      adapter: adapter,
      codec: const MeshPacketCodec(),
      deduplicationStore: deduplicationStore,
      peerRegistry: peerRegistry,
      relayEngine: relayEngine,
      cryptoService: cryptoService,
    );

    return VirtualMeshNode(
      nodeId: nodeId,
      displayName: displayName,
      role: role,
      position: position,
      keyPair: keyPair,
      cryptoService: cryptoService,
      adapter: adapter,
      meshService: meshService,
      isTrusted: isTrusted,
    );
  }

  /// Initializes and starts scanning for the virtual mesh node.
  Future<void> start() async {
    await meshService.start();
  }

  /// Stops scanning and releases resources.
  Future<void> stop() async {
    await meshService.stop();
  }

  Future<void> dispose() async {
    await meshService.dispose();
  }

  void resetStats() {
    stats.reset();
    lastProcessedPacket = null;
    statusMessage = isOnline ? 'Online · Ready' : 'Offline';
  }
}
