import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:attendance_app/core/mesh/mesh_deduplication_store.dart';
import 'package:attendance_app/core/mesh/mesh_packet.dart';
import 'package:attendance_app/core/mesh/mesh_relay_engine.dart';

void main() {
  group('CampusOS Mesh — MeshRelayEngine Tests', () {
    late MeshDeduplicationStore deduplicationStore;
    late MeshRelayEngine relayEngine;
    const localId = 'local_node_device_99';

    setUp(() {
      deduplicationStore = MeshDeduplicationStore(maxSize: 100);
      relayEngine = MeshRelayEngine(
        localDeviceId: localId,
        deduplicationStore: deduplicationStore,
        relayCooldown: const Duration(milliseconds: 50),
        maxPacketAge: const Duration(minutes: 5),
      );
    });

    tearDown(() async {
      await relayEngine.dispose();
    });

    test('TEST 1: Originating-device rejection (never relay own packets)', () {
      final packet = MeshPacket(
        packetId: MeshPacket.generatePacketId(),
        packetType: MeshPacketType.chat,
        senderDeviceId: localId, // Same as local device
        senderRole: 'student',
        timestamp: DateTime.now(),
        payload: Uint8List(5),
      );

      final result = relayEngine.evaluateAndPrepareRelay(packet);
      expect(result.decision, equals(MeshRelayDecision.droppedSelfOrigin));
      expect(result.isAccepted, isFalse);
      expect(result.relayedPacket, isNull);
    });

    test('TEST 2: Rejects incoming packet with TTL <= 0', () {
      final packet = MeshPacket(
        packetId: MeshPacket.generatePacketId(),
        packetType: MeshPacketType.emergency,
        ttl: 0,
        senderDeviceId: 'remote_node',
        senderRole: 'student',
        timestamp: DateTime.now(),
        payload: Uint8List(5),
      );

      final result = relayEngine.evaluateAndPrepareRelay(packet);
      expect(result.decision, equals(MeshRelayDecision.droppedTtlExpired));
      expect(result.isAccepted, isFalse);
    });

    test('TEST 3: Successfully accepts valid packet, decrements TTL and increments hop count', () {
      final packet = MeshPacket(
        packetId: MeshPacket.generatePacketId(),
        packetType: MeshPacketType.chat,
        ttl: 7,
        hopCount: 0,
        senderDeviceId: 'remote_node_1',
        senderRole: 'teacher',
        timestamp: DateTime.now(),
        payload: Uint8List.fromList([1, 2, 3]),
      );

      final result = relayEngine.evaluateAndPrepareRelay(packet);
      expect(result.decision, equals(MeshRelayDecision.acceptedForRelay));
      expect(result.isAccepted, isTrue);
      expect(result.relayedPacket, isNotNull);

      final relayed = result.relayedPacket!;
      expect(relayed.ttl, equals(6)); // Decremented
      expect(relayed.hopCount, equals(1)); // Incremented
      expect(relayed.packetId, equals(packet.packetId));
      expect(relayed.senderDeviceId, equals(packet.senderDeviceId));

      // Packet ID must now be registered in deduplication store
      expect(deduplicationStore.contains(packet.packetId), isTrue);
    });

    test('TEST 4: Stops forwarding when decremented TTL reaches 0', () {
      final packet = MeshPacket(
        packetId: MeshPacket.generatePacketId(),
        packetType: MeshPacketType.chat,
        ttl: 1, // Only 1 hop remaining
        hopCount: 2,
        senderDeviceId: 'remote_node_border',
        senderRole: 'warden',
        timestamp: DateTime.now(),
        payload: Uint8List(5),
      );

      final result = relayEngine.evaluateAndPrepareRelay(packet);
      // Decremented TTL = 0, so forward relay is halted
      expect(result.decision, equals(MeshRelayDecision.droppedTtlExpired));
      expect(result.isAccepted, isFalse);
      expect(result.relayedPacket, isNull);
    });

    test('TEST 5: Duplicate relay prevention drops already seen packet IDs', () {
      final packet = MeshPacket(
        packetId: MeshPacket.generatePacketId(),
        packetType: MeshPacketType.emergency,
        ttl: 5,
        hopCount: 1,
        senderDeviceId: 'remote_node_dup',
        senderRole: 'admin',
        timestamp: DateTime.now(),
        payload: Uint8List(8),
      );

      // First relay succeeds
      final firstResult = relayEngine.evaluateAndPrepareRelay(packet);
      expect(firstResult.decision, equals(MeshRelayDecision.acceptedForRelay));

      // Reset cooldown so cooldown does not mask duplicate detection
      relayEngine.resetCooldown();

      // Second identical relay must be dropped as duplicate
      final secondResult = relayEngine.evaluateAndPrepareRelay(packet);
      expect(secondResult.decision, equals(MeshRelayDecision.droppedDuplicate));
      expect(secondResult.isAccepted, isFalse);
    });

    test('TEST 6: Relay loop prevention drops packet exceeding max protocol hops', () {
      final packet = MeshPacket(
        packetId: MeshPacket.generatePacketId(),
        packetType: MeshPacketType.chat,
        ttl: 5,
        hopCount: 16, // Equal to maxProtocolHops ceiling
        senderDeviceId: 'loop_origin',
        senderRole: 'student',
        timestamp: DateTime.now(),
        payload: Uint8List(4),
      );

      final result = relayEngine.evaluateAndPrepareRelay(packet);
      expect(result.decision, equals(MeshRelayDecision.droppedLoop));
      expect(result.isAccepted, isFalse);
    });

    test('TEST 7: Drops expired/stale packets based on timestamp', () {
      final staleTimestamp = DateTime.now().subtract(const Duration(minutes: 10));
      final packet = MeshPacket(
        packetId: MeshPacket.generatePacketId(),
        packetType: MeshPacketType.chat,
        ttl: 4,
        senderDeviceId: 'remote_stale',
        senderRole: 'student',
        timestamp: staleTimestamp,
        payload: Uint8List(4),
      );

      final result = relayEngine.evaluateAndPrepareRelay(packet);
      expect(result.decision, equals(MeshRelayDecision.droppedPacketExpired));
    });

    test('TEST 8: Applies relay cooldown to prevent rapid relay storms', () {
      final p1 = MeshPacket(
        packetId: MeshPacket.generatePacketId(),
        packetType: MeshPacketType.chat,
        ttl: 5,
        senderDeviceId: 'remote_1',
        senderRole: 'student',
        timestamp: DateTime.now(),
        payload: Uint8List(2),
      );

      final p2 = MeshPacket(
        packetId: MeshPacket.generatePacketId(),
        packetType: MeshPacketType.chat,
        ttl: 5,
        senderDeviceId: 'remote_2',
        senderRole: 'student',
        timestamp: DateTime.now(),
        payload: Uint8List(2),
      );

      // p1 is accepted
      final r1 = relayEngine.evaluateAndPrepareRelay(p1);
      expect(r1.decision, equals(MeshRelayDecision.acceptedForRelay));

      // Immediately sending p2 (within 50ms cooldown) is dropped by cooldown
      final r2 = relayEngine.evaluateAndPrepareRelay(p2);
      expect(r2.decision, equals(MeshRelayDecision.droppedCooldown));
    });

    test('TEST 9: Emits relay events on relayEvents stream', () async {
      final events = <MeshRelayEvent>[];
      relayEngine.relayEvents.listen(events.add);

      final packet = MeshPacket(
        packetId: MeshPacket.generatePacketId(),
        packetType: MeshPacketType.chat,
        ttl: 4,
        senderDeviceId: 'remote_event',
        senderRole: 'teacher',
        timestamp: DateTime.now(),
        payload: Uint8List(2),
      );

      relayEngine.evaluateAndPrepareRelay(packet);
      await pumpEventQueue();

      expect(events.length, equals(1));
      expect(events.first.decision, equals(MeshRelayDecision.acceptedForRelay));
      expect(events.first.relayedPacket?.ttl, equals(3));
    });
  });
}
