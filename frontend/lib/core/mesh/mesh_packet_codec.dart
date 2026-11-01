import 'dart:convert';
import 'dart:typed_data';

import 'mesh_packet.dart';

/// Base exception for all mesh codec errors.
abstract class MeshCodecException implements Exception {
  final String message;
  MeshCodecException(this.message);

  @override
  String toString() => '$runtimeType: $message';
}

/// Thrown when a packet's magic byte does not match the expected 0xCA.
class MeshInvalidMagicException extends MeshCodecException {
  final int found;
  final int expected;

  MeshInvalidMagicException({required this.found, this.expected = MeshPacket.magicByte})
      : super('Invalid magic byte: found 0x${found.toRadixString(16).padLeft(2, '0')}, expected 0x${expected.toRadixString(16).padLeft(2, '0')}');
}

/// Thrown when a packet specifies an invalid TTL.
class MeshInvalidTtlException extends MeshCodecException {
  final int ttl;

  MeshInvalidTtlException(this.ttl)
      : super('Invalid TTL: $ttl. TTL must be between 0 and 255.');
}

/// Thrown when a packet is malformed, truncated, or contains invalid offsets.
class MeshMalformedPacketException extends MeshCodecException {
  MeshMalformedPacketException(super.message);
}

/// Thrown when an encoded or decoded packet exceeds the configured transport limit.
class MeshPacketSizeExceededException extends MeshCodecException {
  final int size;
  final int maxAllowed;

  MeshPacketSizeExceededException({required this.size, required this.maxAllowed})
      : super('Packet size ($size bytes) exceeds transport limit of $maxAllowed bytes. Packet cannot be transmitted over current transport.');
}

/// Deterministic binary codec for [MeshPacket] instances.
///
/// Ensures compact, deterministic binary serialization for BLE transmission,
/// strict structure validation, and zero silent data truncation.
class MeshPacketCodec {
  /// Default transport payload ceiling (64 KB, standard for high-throughput BitChat GATT MTU 517+ transport).
  static const int defaultMaxTransportBytes = 65536;

  /// Legacy BLE advertisement payload ceiling (31 bytes total, ~24 bytes max usable payload).
  static const int legacyBleAdvertMaxBytes = 31;

  /// Current protocol version.
  static const int protocolVersion = 0x01;

  /// Minimum header length required to decode a packet.
  static const int minHeaderLength = 35;

  /// The maximum bytes allowed for encoded transport packets.
  final int maxTransportBytes;

  const MeshPacketCodec({
    this.maxTransportBytes = defaultMaxTransportBytes,
  });

  /// Encodes a [MeshPacket] into deterministic binary bytes.
  ///
  /// Throws [MeshPacketSizeExceededException] if the resulting packet exceeds [maxTransportBytes].
  /// Throws [MeshInvalidTtlException] if the packet TTL is out of range.
  Uint8List encode(MeshPacket packet) {
    if (packet.ttl < 0 || packet.ttl > 255) {
      throw MeshInvalidTtlException(packet.ttl);
    }
    if (packet.hopCount < 0 || packet.hopCount > 255) {
      throw MeshMalformedPacketException('Hop count out of range (0-255): ${packet.hopCount}');
    }

    final senderBytes = utf8.encode(packet.senderDeviceId);
    if (senderBytes.length > 255) {
      throw MeshMalformedPacketException('senderDeviceId too long (${senderBytes.length} > 255 bytes)');
    }

    final roleBytes = utf8.encode(packet.senderRole);
    if (roleBytes.length > 255) {
      throw MeshMalformedPacketException('senderRole too long (${roleBytes.length} > 255 bytes)');
    }

    if (packet.payload.length > 65535) {
      throw MeshMalformedPacketException('Payload too large (${packet.payload.length} > 65535 bytes)');
    }

    if (packet.signature.length > 65535) {
      throw MeshMalformedPacketException('Signature too large (${packet.signature.length} > 65535 bytes)');
    }

    // Calculate total size before constructing buffer
    final totalSize = 1 + // magic
        1 + // version
        1 + // type
        1 + // ttl
        1 + // hopCount
        16 + // packetId
        8 + // timestamp ms
        1 + // sender length
        senderBytes.length +
        1 + // role length
        roleBytes.length +
        2 + // payload length
        packet.payload.length +
        2 + // signature length
        packet.signature.length;

    if (totalSize > maxTransportBytes) {
      throw MeshPacketSizeExceededException(size: totalSize, maxAllowed: maxTransportBytes);
    }

    final builder = BytesBuilder(copy: false)
      ..addByte(packet.magic)
      ..addByte(protocolVersion)
      ..addByte(packet.packetType.typeCode)
      ..addByte(packet.ttl)
      ..addByte(packet.hopCount)
      ..add(packet.packetId);

    // 8 bytes timestamp ms
    final tsData = ByteData(8)..setInt64(0, packet.timestamp.millisecondsSinceEpoch);
    builder.add(tsData.buffer.asUint8List());

    // Sender ID
    builder.addByte(senderBytes.length);
    builder.add(senderBytes);

    // Sender Role
    builder.addByte(roleBytes.length);
    builder.add(roleBytes);

    // Payload
    final payloadLenData = ByteData(2)..setUint16(0, packet.payload.length);
    builder.add(payloadLenData.buffer.asUint8List());
    builder.add(packet.payload);

    // Signature
    final sigLenData = ByteData(2)..setUint16(0, packet.signature.length);
    builder.add(sigLenData.buffer.asUint8List());
    builder.add(packet.signature);

    return builder.toBytes();
  }

  /// Decodes raw binary bytes into a [MeshPacket].
  ///
  /// Throws [MeshPacketSizeExceededException] if [bytes] exceeds [maxTransportBytes].
  /// Throws [MeshInvalidMagicException] if the magic byte is not 0xCA.
  /// Throws [MeshInvalidTtlException] if TTL is out of range.
  /// Throws [MeshMalformedPacketException] if the binary format is invalid or truncated.
  MeshPacket decode(Uint8List bytes) {
    if (bytes.length > maxTransportBytes) {
      throw MeshPacketSizeExceededException(size: bytes.length, maxAllowed: maxTransportBytes);
    }

    if (bytes.length < minHeaderLength) {
      throw MeshMalformedPacketException(
        'Packet too short (${bytes.length} bytes, minimum required: $minHeaderLength)',
      );
    }

    final byteData = ByteData.sublistView(bytes);
    int offset = 0;

    // 1. Magic byte
    final magic = bytes[offset++];
    if (magic != MeshPacket.magicByte) {
      throw MeshInvalidMagicException(found: magic);
    }

    // 2. Protocol version
    final version = bytes[offset++];
    if (version != protocolVersion) {
      throw MeshMalformedPacketException(
        'Unsupported protocol version: $version (expected $protocolVersion)',
      );
    }

    // 3. Packet type
    final typeCode = bytes[offset++];
    final packetType = MeshPacketType.fromTypeCode(typeCode);
    if (packetType == null) {
      throw MeshMalformedPacketException('Unknown packet type code: $typeCode');
    }

    // 4. TTL
    final ttl = bytes[offset++];
    if (ttl < 0 || ttl > 255) {
      throw MeshInvalidTtlException(ttl);
    }

    // 5. Hop Count
    final hopCount = bytes[offset++];

    // 6. Packet ID (16 bytes)
    final packetId = Uint8List.fromList(bytes.sublist(offset, offset + 16));
    offset += 16;

    // 7. Timestamp (8 bytes)
    final timestampMs = byteData.getInt64(offset);
    final timestamp = DateTime.fromMillisecondsSinceEpoch(timestampMs);
    offset += 8;

    // 8. Sender Device ID
    if (offset >= bytes.length) {
      throw MeshMalformedPacketException('Truncated packet: missing sender device ID length');
    }
    final senderLen = bytes[offset++];
    if (offset + senderLen > bytes.length) {
      throw MeshMalformedPacketException('Truncated packet: sender device ID overflows buffer');
    }
    final senderDeviceId = utf8.decode(bytes.sublist(offset, offset + senderLen));
    offset += senderLen;

    // 9. Sender Role
    if (offset >= bytes.length) {
      throw MeshMalformedPacketException('Truncated packet: missing sender role length');
    }
    final roleLen = bytes[offset++];
    if (offset + roleLen > bytes.length) {
      throw MeshMalformedPacketException('Truncated packet: sender role overflows buffer');
    }
    final senderRole = utf8.decode(bytes.sublist(offset, offset + roleLen));
    offset += roleLen;

    // 10. Payload
    if (offset + 2 > bytes.length) {
      throw MeshMalformedPacketException('Truncated packet: missing payload length bytes');
    }
    final payloadLen = byteData.getUint16(offset);
    offset += 2;
    if (offset + payloadLen > bytes.length) {
      throw MeshMalformedPacketException('Truncated packet: payload data overflows buffer');
    }
    final payload = Uint8List.fromList(bytes.sublist(offset, offset + payloadLen));
    offset += payloadLen;

    // 11. Signature
    if (offset + 2 > bytes.length) {
      throw MeshMalformedPacketException('Truncated packet: missing signature length bytes');
    }
    final sigLen = byteData.getUint16(offset);
    offset += 2;
    if (offset + sigLen > bytes.length) {
      throw MeshMalformedPacketException('Truncated packet: signature data overflows buffer');
    }
    final signature = Uint8List.fromList(bytes.sublist(offset, offset + sigLen));
    offset += sigLen;

    // Ensure no unexpected trailing garbage
    if (offset != bytes.length) {
      throw MeshMalformedPacketException(
        'Malformed packet: ${bytes.length - offset} extraneous trailing bytes found',
      );
    }

    return MeshPacket(
      magic: magic,
      packetId: packetId,
      packetType: packetType,
      ttl: ttl,
      hopCount: hopCount,
      senderDeviceId: senderDeviceId,
      senderRole: senderRole,
      timestamp: timestamp,
      payload: payload,
      signature: signature,
    );
  }
}
