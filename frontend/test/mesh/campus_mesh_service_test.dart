import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:attendance_app/core/mesh/campus_mesh_service.dart';
import 'package:attendance_app/core/mesh/mesh_deduplication_store.dart';
import 'package:attendance_app/core/mesh/mesh_packet.dart';
import 'package:attendance_app/core/mesh/mesh_packet_codec.dart';
import 'package:attendance_app/core/mesh/mesh_peer.dart';
import 'package:attendance_app/core/mesh/mesh_peer_registry.dart';
import 'package:attendance_app/core/mesh/mesh_relay_engine.dart';

/// Test double simulating the BLE radio layer for deterministic unit tests.
class FakeMeshBleAdapter implements MeshBleAdapter {
  bool bluetoothAvailable = true;
  bool permissionsGranted = true;
  bool scanningSupported = true;
  bool advertisingSupported = true;

  bool isScanning = false;
  bool isAdvertising = false;

  void Function(Uint8List rawBytes, int rssi)? packetDiscoveredCallback;
  final List<Uint8List> advertisedPackets = [];

  @override
  Future<bool> isBluetoothAvailable() async => bluetoothAvailable;

  @override
  Future<bool> requestPermissions() async => permissionsGranted;

  @override
  Future<bool> startScanning({
    required void Function(Uint8List rawBytes, int rssi) onPacketDiscovered,
  }) async {
    if (!scanningSupported) return false;
    isScanning = true;
    packetDiscoveredCallback = onPacketDiscovered;
    return true;
  }

  @override
  Future<void> stopScanning() async {
    isScanning = false;
    packetDiscoveredCallback = null;
  }

  @override
  Future<bool> advertisePacket(Uint8List rawBytes) async {
    if (!advertisingSupported) return false;
    isAdvertising = true;
    advertisedPackets.add(rawBytes);
    return true;
  }

  @override
  Future<void> stopAdvertising() async {
    isAdvertising = false;
  }

  Future<void> pauseAdvertising() async {
    isAdvertising = false;
  }

  Future<void> resumeAdvertising() async {}

  @override
  Future<void> dispose() async {
    await stopScanning();
    await stopAdvertising();
  }

  /// Helper to simulate an incoming BLE advertisement in tests.
  void simulateIncomingAdvertisement(Uint8List rawBytes, {int rssi = -60}) {
    packetDiscoveredCallback?.call(rawBytes, rssi);
  }
}

void main() {
  group('CampusOS Mesh — CampusMeshService Tests', () {
    late FakeMeshBleAdapter fakeAdapter;
    late MeshPacketCodec codec;
    late MeshDeduplicationStore deduplicationStore;
    late MeshPeerRegistry peerRegistry;
    late MeshRelayEngine relayEngine;
    late CampusMeshService service;

    const localDeviceId = 'local_device_001';
    const localRole = 'student';

    setUp(() {
      fakeAdapter = FakeMeshBleAdapter();
      codec = const MeshPacketCodec();
      deduplicationStore = MeshDeduplicationStore(maxSize: 100);
      peerRegistry = MeshPeerRegistry(peerActiveTimeout: const Duration(seconds: 30));
      relayEngine = MeshRelayEngine(
        localDeviceId: localDeviceId,
        deduplicationStore: deduplicationStore,
        relayCooldown: const Duration(milliseconds: 10),
      );

      service = CampusMeshService(
        localDeviceId: localDeviceId,
        localRole: localRole,
        adapter: fakeAdapter,
        codec: codec,
        deduplicationStore: deduplicationStore,
        peerRegistry: peerRegistry,
        relayEngine: relayEngine,
      );
    });

    tearDown(() async {
      await service.dispose();
    });

    test('TEST 1: Initial state is disabled and idle', () {
      expect(service.currentState.status, equals(MeshStateStatus.disabled));
      expect(service.currentState.reason, equals(MeshStateReason.idle));
      expect(service.isRunning, isFalse);
    });

    test('TEST 2: start() transitions state to active when Bluetooth and permissions are valid', () async {
      final states = <MeshServiceState>[];
      service.meshState.listen(states.add);

      final started = await service.start();
      expect(started, isTrue);
      expect(service.isRunning, isTrue);
      expect(service.currentState.status, equals(MeshStateStatus.active));
      expect(service.currentState.reason, equals(MeshStateReason.activeMesh));
      expect(fakeAdapter.isScanning, isTrue);

      await pumpEventQueue();
      expect(states.any((s) => s.status == MeshStateStatus.initializing), isTrue);
      expect(states.last.status, equals(MeshStateStatus.active));
    });

    test('TEST 3: Distinguishes Bluetooth unavailable and transitions to unavailable', () async {
      fakeAdapter.bluetoothAvailable = false;

      final started = await service.start();
      expect(started, isFalse);
      expect(service.isRunning, isFalse);
      expect(service.currentState.status, equals(MeshStateStatus.unavailable));
      expect(service.currentState.reason, equals(MeshStateReason.bluetoothUnavailable));
    });

    test('TEST 4: Distinguishes Bluetooth permission denied and transitions to unavailable', () async {
      fakeAdapter.bluetoothAvailable = true;
      fakeAdapter.permissionsGranted = false;

      final started = await service.start();
      expect(started, isFalse);
      expect(service.isRunning, isFalse);
      expect(service.currentState.status, equals(MeshStateStatus.unavailable));
      expect(service.currentState.reason, equals(MeshStateReason.bluetoothPermissionDenied));
    });

    test('TEST 5: Distinguishes scanning unavailable and transitions to degraded', () async {
      fakeAdapter.bluetoothAvailable = true;
      fakeAdapter.permissionsGranted = true;
      fakeAdapter.scanningSupported = false;

      final started = await service.start();
      expect(started, isFalse);
      expect(service.currentState.status, equals(MeshStateStatus.degraded));
      expect(service.currentState.reason, equals(MeshStateReason.scanningUnavailable));
    });

    test('TEST 6: Ingests incoming valid advertisement, decodes, registers peer, and emits packet', () async {
      await service.start();

      final receivedPackets = <MeshPacket>[];
      service.receivedPackets.listen(receivedPackets.add);

      final peerUpdates = <List<MeshPeer>>[];
      service.peerUpdates.listen(peerUpdates.add);

      final inboundPacket = MeshPacket(
        packetId: MeshPacket.generatePacketId(),
        packetType: MeshPacketType.chat,
        ttl: 4,
        hopCount: 0,
        senderDeviceId: 'remote_peer_1',
        senderRole: 'teacher',
        timestamp: DateTime.now(),
        payload: Uint8List.fromList([1, 2, 3]),
      );

      final rawBytes = codec.encode(inboundPacket);
      fakeAdapter.simulateIncomingAdvertisement(rawBytes, rssi: -58);

      await pumpEventQueue();

      expect(receivedPackets.length, equals(1));
      expect(receivedPackets.first.packetId, equals(inboundPacket.packetId));
      expect(receivedPackets.first.senderDeviceId, equals('remote_peer_1'));

      // Peer was tracked in registry
      final peer = peerRegistry.getPeer('remote_peer_1');
      expect(peer, isNotNull);
      expect(peer!.observedRssi, equals(-58));
      expect(peer.role, equals('teacher'));
    });

    test('TEST 7: Automatically relays inbound packet from remote peer with decremented TTL and incremented hopCount', () async {
      await service.start();

      final relayedPackets = <MeshPacket>[];
      service.relayedPackets.listen(relayedPackets.add);

      final inboundPacket = MeshPacket(
        packetId: MeshPacket.generatePacketId(),
        packetType: MeshPacketType.emergency,
        ttl: 5,
        hopCount: 1,
        senderDeviceId: 'remote_peer_emergency',
        senderRole: 'student',
        timestamp: DateTime.now(),
        payload: Uint8List.fromList([9, 9, 9]),
      );

      final rawBytes = codec.encode(inboundPacket);
      fakeAdapter.simulateIncomingAdvertisement(rawBytes, rssi: -65);

      await pumpEventQueue();

      // Check relayed stream
      expect(relayedPackets.length, equals(1));
      final relayed = relayedPackets.first;
      expect(relayed.packetId, equals(inboundPacket.packetId));
      expect(relayed.ttl, equals(4)); // Decremented from 5
      expect(relayed.hopCount, equals(2)); // Incremented from 1

      // Verify BLE advertiser was called with relayed packet
      expect(fakeAdapter.advertisedPackets.isNotEmpty, isTrue);
      final lastAdvertised = codec.decode(fakeAdapter.advertisedPackets.last);
      expect(lastAdvertised.ttl, equals(4));
      expect(lastAdvertised.hopCount, equals(2));
    });

    test('TEST 8: Inbound duplicate packet is dropped and not emitted or relayed twice', () async {
      await service.start();

      final receivedPackets = <MeshPacket>[];
      service.receivedPackets.listen(receivedPackets.add);

      final relayedPackets = <MeshPacket>[];
      service.relayedPackets.listen(relayedPackets.add);

      final inboundPacket = MeshPacket(
        packetId: MeshPacket.generatePacketId(),
        packetType: MeshPacketType.chat,
        ttl: 4,
        hopCount: 0,
        senderDeviceId: 'remote_peer_dup',
        senderRole: 'student',
        timestamp: DateTime.now(),
        payload: Uint8List.fromList([7, 8, 9]),
      );

      final rawBytes = codec.encode(inboundPacket);

      // First delivery
      fakeAdapter.simulateIncomingAdvertisement(rawBytes);
      await pumpEventQueue();
      expect(receivedPackets.length, equals(1));
      expect(relayedPackets.length, equals(1));

      // Second delivery of same packet
      fakeAdapter.simulateIncomingAdvertisement(rawBytes);
      await pumpEventQueue();

      // Still only 1 packet received and relayed
      expect(receivedPackets.length, equals(1));
      expect(relayedPackets.length, equals(1));
    });

    test('TEST 9: broadcastPacket() sends outbound packet and records in deduplication store', () async {
      final outboundPacket = MeshPacket(
        packetId: MeshPacket.generatePacketId(),
        packetType: MeshPacketType.chat,
        ttl: 7,
        hopCount: 0,
        senderDeviceId: localDeviceId,
        senderRole: localRole,
        timestamp: DateTime.now(),
        payload: Uint8List.fromList([42, 43, 44]),
      );

      final ok = await service.broadcastPacket(outboundPacket);
      expect(ok, isTrue);

      expect(fakeAdapter.advertisedPackets.length, equals(1));
      final advertised = codec.decode(fakeAdapter.advertisedPackets.first);
      expect(advertised.packetId, equals(outboundPacket.packetId));

      // Must be present in deduplication store
      expect(deduplicationStore.contains(outboundPacket.packetId), isTrue);
    });

    test('TEST 10: Gracefully handles malformed advertisement without crashing or emitting error', () async {
      await service.start();

      final receivedPackets = <MeshPacket>[];
      service.receivedPackets.listen(receivedPackets.add);

      // Random garbage bytes (not starting with 0xCA)
      final garbage = Uint8List.fromList([0x12, 0x34, 0x56, 0x78]);
      fakeAdapter.simulateIncomingAdvertisement(garbage);

      await pumpEventQueue();
      expect(receivedPackets.isEmpty, isTrue);
    });

    test('TEST 11: stop() stops scanning and advertising, transitions state to disabled', () async {
      await service.start();
      expect(service.isRunning, isTrue);

      await service.stop();
      expect(service.isRunning, isFalse);
      expect(service.currentState.status, equals(MeshStateStatus.disabled));
      expect(service.currentState.reason, equals(MeshStateReason.idle));
      expect(fakeAdapter.isScanning, isFalse);
      expect(fakeAdapter.isAdvertising, isFalse);
    });
  });
}
