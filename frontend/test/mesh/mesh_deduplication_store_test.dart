import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:attendance_app/core/mesh/mesh_deduplication_store.dart';
import 'package:attendance_app/core/mesh/mesh_packet.dart';

void main() {
  group('CampusOS Mesh — MeshDeduplicationStore Tests', () {
    test('TEST 1: Store registers a new 16-byte packet ID successfully', () {
      final store = MeshDeduplicationStore(maxSize: 10);
      final id = MeshPacket.generatePacketId();

      expect(store.contains(id), isFalse);
      final added = store.add(id);
      expect(added, isTrue);
      expect(store.contains(id), isTrue);
      expect(store.count, equals(1));
    });

    test('TEST 2: Store detects duplicate packet ID and rejects duplicate add', () {
      final store = MeshDeduplicationStore(maxSize: 10);
      final id = MeshPacket.generatePacketId();

      expect(store.add(id), isTrue);
      expect(store.add(id), isFalse); // Duplicate
      expect(store.contains(id), isTrue);
      expect(store.count, equals(1));
    });

    test('TEST 3: Enforces bounded capacity and evicts oldest entry', () {
      final store = MeshDeduplicationStore(maxSize: 3);
      final id1 = Uint8List.fromList(List.filled(16, 1));
      final id2 = Uint8List.fromList(List.filled(16, 2));
      final id3 = Uint8List.fromList(List.filled(16, 3));
      final id4 = Uint8List.fromList(List.filled(16, 4));

      store.add(id1);
      store.add(id2);
      store.add(id3);
      expect(store.count, equals(3));
      expect(store.contains(id1), isTrue);

      // Adding 4th element should evict the oldest (id1)
      store.add(id4);
      expect(store.count, equals(3));
      expect(store.contains(id1), isFalse); // Evicted
      expect(store.contains(id2), isTrue);
      expect(store.contains(id3), isTrue);
      expect(store.contains(id4), isTrue);
    });

    test('TEST 4: Expired entries are recognized and removed by cleanupExpired', () {
      final store = MeshDeduplicationStore(
        maxSize: 10,
        entryTtl: const Duration(minutes: 2),
      );
      final baseTime = DateTime(2026, 10, 7, 12, 0, 0);
      final id1 = MeshPacket.generatePacketId();
      final id2 = MeshPacket.generatePacketId();

      store.add(id1, baseTime);
      store.add(id2, baseTime.add(const Duration(minutes: 1)));

      // At baseTime + 1 min: both valid
      expect(store.contains(id1, baseTime.add(const Duration(minutes: 1))), isTrue);
      expect(store.contains(id2, baseTime.add(const Duration(minutes: 1))), isTrue);

      // At baseTime + 2 min 30 sec: id1 expired (age 2.5 min > 2 min TTL)
      final checkTime = baseTime.add(const Duration(minutes: 2, seconds: 30));
      expect(store.contains(id1, checkTime), isFalse); // proactively cleared on contains
      expect(store.contains(id2, checkTime), isTrue);

      final removedCount = store.cleanupExpired(checkTime);
      expect(removedCount, equals(0)); // id1 was already removed during contains check

      // Advance to baseTime + 4 min: id2 also expired
      final laterTime = baseTime.add(const Duration(minutes: 4));
      final laterRemoved = store.cleanupExpired(laterTime);
      expect(laterRemoved, equals(1));
      expect(store.count, equals(0));
    });

    test('TEST 5: Clear empties the store completely', () {
      final store = MeshDeduplicationStore(maxSize: 10);
      store.add(MeshPacket.generatePacketId());
      store.add(MeshPacket.generatePacketId());
      expect(store.count, equals(2));

      store.clear();
      expect(store.count, equals(0));
    });
  });
}
