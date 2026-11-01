import 'dart:math';
import 'dart:typed_data';

/// The packet types supported by the CampusOS Mesh protocol.
enum MeshPacketType {
  chat(0x01),
  emergency(0x02),
  fileOffer(0x03),
  fileChunk(0x04),
  acknowledgement(0x05);

  final int typeCode;
  const MeshPacketType(this.typeCode);

  /// Resolves a [MeshPacketType] from its raw 1-byte integer code.
  static MeshPacketType? fromTypeCode(int code) {
    for (final type in MeshPacketType.values) {
      if (type.typeCode == code) return type;
    }
    return null;
  }
}

/// Strongly typed CampusOS Mesh protocol packet.
///
/// Follows the CampusOS Phase M1 specification:
/// - Magic byte: 0xCA
/// - Packet ID: Exactly 16 bytes
/// - Transport payload limit check and strict TTL semantics
class MeshPacket {
  /// Magic byte identifying a CampusOS Mesh packet.
  static const int magicByte = 0xCA;

  /// Default protocol hop count / TTL ceiling.
  static const int defaultTtl = 7;

  /// Required byte length for packet IDs.
  static const int packetIdLength = 16;

  /// Magic byte (must always equal [magicByte] = 0xCA).
  final int magic;

  /// Globally unique 16-byte identifier for this packet.
  final Uint8List packetId;

  /// Protocol packet type.
  final MeshPacketType packetType;

  /// Time-To-Live (remaining allowed hops).
  final int ttl;

  /// Number of hops this packet has traversed so far.
  final int hopCount;

  /// Unique identifier of the originating device.
  final String senderDeviceId;

  /// CampusOS role of the originating sender (e.g., student, teacher, admin).
  final String senderRole;

  /// Timestamp when the packet was created.
  final DateTime timestamp;

  /// Arbitrary payload bytes carried by this packet.
  final Uint8List payload;

  /// Cryptographic signature over the packet contents (optional/ephemeral).
  final Uint8List signature;

  MeshPacket({
    this.magic = magicByte,
    required this.packetId,
    required this.packetType,
    this.ttl = defaultTtl,
    this.hopCount = 0,
    required this.senderDeviceId,
    required this.senderRole,
    required this.timestamp,
    required this.payload,
    Uint8List? signature,
  }) : signature = signature ?? Uint8List(0) {
    if (magic != magicByte) {
      throw ArgumentError.value(
        magic,
        'magic',
        'Invalid magic byte. Expected 0x${magicByte.toRadixString(16)} (202), got $magic',
      );
    }
    if (packetId.length != packetIdLength) {
      throw ArgumentError.value(
        packetId.length,
        'packetId',
        'Packet ID must be exactly $packetIdLength bytes, got ${packetId.length}',
      );
    }
    if (ttl < 0) {
      throw ArgumentError.value(ttl, 'ttl', 'TTL cannot be negative');
    }
    if (hopCount < 0) {
      throw ArgumentError.value(hopCount, 'hopCount', 'Hop count cannot be negative');
    }
    if (senderDeviceId.trim().isEmpty) {
      throw ArgumentError.value(senderDeviceId, 'senderDeviceId', 'Sender device ID cannot be empty');
    }
  }

  /// Generates a cryptographically random 16-byte packet identifier.
  static Uint8List generatePacketId() {
    final random = Random.secure();
    final bytes = Uint8List(packetIdLength);
    for (int i = 0; i < packetIdLength; i++) {
      bytes[i] = random.nextInt(256);
    }
    return bytes;
  }

  /// Hex representation of the 16-byte packet ID.
  String get packetIdHex {
    return packetId.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }

  /// Whether this packet's TTL has reached 0 (no further hops permitted).
  bool get isTtlExpired => ttl <= 0;

  /// The immutable initial hop budget (sum of remaining TTL and traversed hops).
  int get initialHopBudget => ttl + hopCount;

  /// Returns canonical signable bytes for verification (excluding the signature field).
  ///
  /// Uses Approach A (Immutable Envelope Signing):
  /// - Binds the immutable initial hop budget [ttl + hopCount].
  /// - This ensures the signable bytes remain invariant as legitimate relays decrement TTL
  ///   and increment hopCount, while preventing attackers from expanding the hop budget.
  Uint8List getSignableBytes() {
    final builder = BytesBuilder(copy: false)
      ..addByte(magic)
      ..addByte(packetType.typeCode)
      ..addByte(ttl + hopCount)
      ..add(packetId);

    // 8 bytes timestamp ms
    final tsData = ByteData(8)..setInt64(0, timestamp.millisecondsSinceEpoch);
    builder.add(tsData.buffer.asUint8List());

    final senderBytes = Uint8List.fromList(senderDeviceId.codeUnits);
    builder.addByte(senderBytes.length);
    builder.add(senderBytes);

    final roleBytes = Uint8List.fromList(senderRole.codeUnits);
    builder.addByte(roleBytes.length);
    builder.add(roleBytes);

    final payloadLengthData = ByteData(2)..setUint16(0, payload.length);
    builder.add(payloadLengthData.buffer.asUint8List());
    builder.add(payload);

    return builder.toBytes();
  }

  /// Creates a copy of this packet with specified fields modified.
  MeshPacket copyWith({
    int? magic,
    Uint8List? packetId,
    MeshPacketType? packetType,
    int? ttl,
    int? hopCount,
    String? senderDeviceId,
    String? senderRole,
    DateTime? timestamp,
    Uint8List? payload,
    Uint8List? signature,
  }) {
    return MeshPacket(
      magic: magic ?? this.magic,
      packetId: packetId ?? this.packetId,
      packetType: packetType ?? this.packetType,
      ttl: ttl ?? this.ttl,
      hopCount: hopCount ?? this.hopCount,
      senderDeviceId: senderDeviceId ?? this.senderDeviceId,
      senderRole: senderRole ?? this.senderRole,
      timestamp: timestamp ?? this.timestamp,
      payload: payload ?? this.payload,
      signature: signature ?? this.signature,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! MeshPacket) return false;

    if (magic != other.magic ||
        packetType != other.packetType ||
        ttl != other.ttl ||
        hopCount != other.hopCount ||
        senderDeviceId != other.senderDeviceId ||
        senderRole != other.senderRole ||
        timestamp.millisecondsSinceEpoch != other.timestamp.millisecondsSinceEpoch) {
      return false;
    }

    if (!_areByteListsEqual(packetId, other.packetId)) return false;
    if (!_areByteListsEqual(payload, other.payload)) return false;
    if (!_areByteListsEqual(signature, other.signature)) return false;

    return true;
  }

  @override
  int get hashCode {
    return Object.hash(
      magic,
      packetIdHex,
      packetType,
      ttl,
      hopCount,
      senderDeviceId,
      senderRole,
      timestamp.millisecondsSinceEpoch,
    );
  }

  @override
  String toString() {
    return 'MeshPacket(id: $packetIdHex, type: ${packetType.name}, ttl: $ttl, hops: $hopCount, sender: $senderDeviceId ($senderRole), payloadLen: ${payload.length})';
  }

  static bool _areByteListsEqual(Uint8List a, Uint8List b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}
