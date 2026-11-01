import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:attendance_app/core/mesh/mesh_peer.dart';
import 'package:attendance_app/core/mesh/mesh_peer_registry.dart';

void main() {
  group('CampusOS Mesh — MeshPeerRegistry Tests', () {
    late MeshPeerRegistry registry;

    setUp(() {
      registry = MeshPeerRegistry(
        peerActiveTimeout: const Duration(seconds: 30),
        maxPeers: 10,
      );
    });

    tearDown(() async {
      await registry.dispose();
    });

    test('TEST 1: Registers a new peer and emits peerAdded stream event', () async {
      final addedEvents = <MeshPeer>[];
      registry.peerAdded.listen(addedEvents.add);

      final packetId = Uint8List(16);
      final registered = registry.registerOrUpdatePeer(
        deviceId: 'node_alpha',
        role: 'student',
        packetId: packetId,
        rssi: -65,
        hopCount: 1,
      );

      // Allow stream to pump
      await pumpEventQueue();

      expect(registry.peerCount, equals(1));
      expect(registry.activePeers.length, equals(1));
      expect(registered.deviceId, equals('node_alpha'));
      expect(registered.observedRssi, equals(-65));
      expect(registered.observedHopCount, equals(1));
      expect(registered.isActive, isTrue);

      expect(addedEvents.length, equals(1));
      expect(addedEvents.first.deviceId, equals('node_alpha'));
    });

    test('TEST 2: Updates existing peer telemetry without fabricating data', () async {
      final updatedEvents = <MeshPeer>[];
      registry.peerUpdated.listen(updatedEvents.add);

      registry.registerOrUpdatePeer(
        deviceId: 'node_beta',
        role: 'teacher',
        rssi: -70,
        hopCount: 2,
      );

      await pumpEventQueue();

      // Update with new RSSI and hop count
      final updated = registry.registerOrUpdatePeer(
        deviceId: 'node_beta',
        role: 'teacher',
        rssi: -55,
        hopCount: 1,
      );

      await pumpEventQueue();

      expect(registry.peerCount, equals(1));
      expect(updated.observedRssi, equals(-55));
      expect(updated.observedHopCount, equals(1));
      expect(updatedEvents.length, equals(1));
      expect(updatedEvents.first.observedRssi, equals(-55));
    });

    test('TEST 3: Inactivity cleanup transitions stale peers to inactive and emits peerRemoved', () async {
      final removedEvents = <MeshPeer>[];
      registry.peerRemoved.listen(removedEvents.add);

      final baseTime = DateTime(2026, 10, 7, 12, 0, 0);

      registry.registerOrUpdatePeer(
        deviceId: 'node_stale',
        role: 'student',
        seenAt: baseTime,
      );

      registry.registerOrUpdatePeer(
        deviceId: 'node_fresh',
        role: 'warden',
        seenAt: baseTime.add(const Duration(seconds: 20)),
      );

      expect(registry.activePeers.length, equals(2));

      // Advance time beyond 30s timeout for node_stale (baseTime + 35s)
      final checkTime = baseTime.add(const Duration(seconds: 35));
      final newlyInactive = registry.cleanupInactivePeers(checkTime);

      await pumpEventQueue();

      expect(newlyInactive.length, equals(1));
      expect(newlyInactive.first.deviceId, equals('node_stale'));
      expect(newlyInactive.first.isActive, isFalse);

      expect(registry.peerCount, equals(2)); // Still in registry
      expect(registry.activePeers.length, equals(1)); // Only node_fresh is active
      expect(registry.activePeers.first.deviceId, equals('node_fresh'));

      expect(removedEvents.length, equals(1));
      expect(removedEvents.first.deviceId, equals('node_stale'));
    });

    test('TEST 4: Enforces bounded capacity limit by evicting oldest peer', () {
      final smallRegistry = MeshPeerRegistry(maxPeers: 3);

      smallRegistry.registerOrUpdatePeer(deviceId: 'peer_1', role: 'student');
      smallRegistry.registerOrUpdatePeer(deviceId: 'peer_2', role: 'student');
      smallRegistry.registerOrUpdatePeer(deviceId: 'peer_3', role: 'student');
      expect(smallRegistry.peerCount, equals(3));

      // 4th peer should evict peer_1
      smallRegistry.registerOrUpdatePeer(deviceId: 'peer_4', role: 'student');
      expect(smallRegistry.peerCount, equals(3));
      expect(smallRegistry.getPeer('peer_1'), isNull);
      expect(smallRegistry.getPeer('peer_4'), isNotNull);

      smallRegistry.dispose();
    });
  });
}
