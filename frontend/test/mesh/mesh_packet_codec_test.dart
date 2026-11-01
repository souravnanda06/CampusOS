import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:attendance_app/core/mesh/mesh_packet.dart';
import 'package:attendance_app/core/mesh/mesh_packet_codec.dart';

void main() {
  group('CampusOS Mesh — MeshPacket & MeshPacketCodec Tests', () {
    const codec = MeshPacketCodec(maxTransportBytes: 250);

    test('TEST 1: Packet ID generation produces exactly 16 bytes with entropy', () {
      final id1 = MeshPacket.generatePacketId();
      final id2 = MeshPacket.generatePacketId();

      expect(id1.length, equals(16));
      expect(id2.length, equals(16));
      expect(id1, isNot(equals(id2)));
    });

    test('TEST 2: Packet deterministic encode and decode roundtrip', () {
      final packetId = MeshPacket.generatePacketId();
      final timestamp = DateTime.fromMillisecondsSinceEpoch(1775550000000);
      final payload = Uint8List.fromList([1, 2, 3, 4, 5, 42]);
      final signature = Uint8List.fromList(List.generate(64, (i) => i));

      final originalPacket = MeshPacket(
        packetId: packetId,
        packetType: MeshPacketType.chat,
        ttl: 5,
        hopCount: 1,
        senderDeviceId: 'student_node_42',
        senderRole: 'student',
        timestamp: timestamp,
        payload: payload,
        signature: signature,
      );

      final encoded = codec.encode(originalPacket);
      expect(encoded.isNotEmpty, isTrue);
      expect(encoded[0], equals(MeshPacket.magicByte)); // 0xCA

      final decoded = codec.decode(encoded);

      expect(decoded.magic, equals(MeshPacket.magicByte));
      expect(decoded.packetId, equals(packetId));
      expect(decoded.packetType, equals(MeshPacketType.chat));
      expect(decoded.ttl, equals(5));
      expect(decoded.hopCount, equals(1));
      expect(decoded.senderDeviceId, equals('student_node_42'));
      expect(decoded.senderRole, equals('student'));
      expect(decoded.timestamp.millisecondsSinceEpoch, equals(timestamp.millisecondsSinceEpoch));
      expect(decoded.payload, equals(payload));
      expect(decoded.signature, equals(signature));
      expect(decoded, equals(originalPacket));
    });

    test('TEST 3: Rejects invalid magic byte (not 0xCA)', () {
      final packet = MeshPacket(
        packetId: MeshPacket.generatePacketId(),
        packetType: MeshPacketType.emergency,
        senderDeviceId: 'node_1',
        senderRole: 'teacher',
        timestamp: DateTime.now(),
        payload: Uint8List(4),
      );

      final encoded = codec.encode(packet);
      final corrupted = Uint8List.fromList(encoded);
      corrupted[0] = 0xAA; // Corrupt magic byte

      expect(
        () => codec.decode(corrupted),
        throwsA(isA<MeshInvalidMagicException>()),
      );
    });

    test('TEST 4: Rejects packets exceeding transport payload limit', () {
      const smallCodec = MeshPacketCodec(maxTransportBytes: 50);

      final largePayload = Uint8List(60);
      final packet = MeshPacket(
        packetId: MeshPacket.generatePacketId(),
        packetType: MeshPacketType.fileChunk,
        senderDeviceId: 'big_sender',
        senderRole: 'admin',
        timestamp: DateTime.now(),
        payload: largePayload,
      );

      expect(
        () => smallCodec.encode(packet),
        throwsA(isA<MeshPacketSizeExceededException>()),
      );
    });

    test('TEST 5: Rejects malformed or truncated packet bytes', () {
      expect(
        () => codec.decode(Uint8List(10)), // Shorter than minHeaderLength (35)
        throwsA(isA<MeshMalformedPacketException>()),
      );

      // Truncate valid packet in the middle
      final valid = MeshPacket(
        packetId: MeshPacket.generatePacketId(),
        packetType: MeshPacketType.chat,
        senderDeviceId: 'node_truncate',
        senderRole: 'student',
        timestamp: DateTime.now(),
        payload: Uint8List.fromList([10, 20, 30]),
      );
      final validBytes = codec.encode(valid);

      final truncated = Uint8List.fromList(validBytes.sublist(0, validBytes.length - 2));
      expect(
        () => codec.decode(truncated),
        throwsA(isA<MeshMalformedPacketException>()),
      );
    });

    test('TEST 6: Rejects unknown packet type code', () {
      final packet = MeshPacket(
        packetId: MeshPacket.generatePacketId(),
        packetType: MeshPacketType.chat,
        senderDeviceId: 'node_1',
        senderRole: 'student',
        timestamp: DateTime.now(),
        payload: Uint8List(2),
      );
      final encoded = codec.encode(packet);
      final corrupted = Uint8List.fromList(encoded);
      corrupted[2] = 0xFE; // Unknown type code

      expect(
        () => codec.decode(corrupted),
        throwsA(isA<MeshMalformedPacketException>()),
      );
    });

    test('TEST 7: All protocol packet types encode and decode correctly', () {
      for (final type in MeshPacketType.values) {
        final packet = MeshPacket(
          packetId: MeshPacket.generatePacketId(),
          packetType: type,
          senderDeviceId: 'node_type_test',
          senderRole: 'role_${type.name}',
          timestamp: DateTime.now(),
          payload: Uint8List.fromList([type.typeCode]),
        );

        final encoded = codec.encode(packet);
        final decoded = codec.decode(encoded);
        expect(decoded.packetType, equals(type));
      }
    });

    test('TEST 8: Signable bytes are deterministic and exclude signature', () {
      final packetId = MeshPacket.generatePacketId();
      final now = DateTime.now();
      final packetWithoutSig = MeshPacket(
        packetId: packetId,
        packetType: MeshPacketType.acknowledgement,
        senderDeviceId: 'node_sig',
        senderRole: 'student',
        timestamp: now,
        payload: Uint8List.fromList([1, 2, 3]),
      );

      final packetWithSig = packetWithoutSig.copyWith(
        signature: Uint8List.fromList([99, 88, 77]),
      );

      expect(packetWithoutSig.getSignableBytes(), equals(packetWithSig.getSignableBytes()));
    });
  });
}
