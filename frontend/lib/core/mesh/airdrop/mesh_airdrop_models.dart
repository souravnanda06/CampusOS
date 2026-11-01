import 'dart:convert';
import 'dart:typed_data';

/// The transfer direction relative to the local mesh node.
enum MeshTransferDirection {
  outgoing,
  incoming,
}

/// The underlying transport mechanism used for delivering file payload bytes.
enum MeshTransportType {
  bleMesh('BLE Mesh'),
  localWifi('Local Wi-Fi');

  final String label;
  const MeshTransportType(this.label);
}

/// Explicit lifecycle state of a mesh file transfer.
enum MeshFileTransferState {
  // Sender-side states
  created('Created'),
  offering('Offering'),
  waitingForAccept('Waiting for Accept'),
  sending('Sending'),

  // Receiver-side states
  offered('Offered'),
  accepted('Accepted'),
  receiving('Receiving'),
  verifying('Verifying Hash'),

  // M5B Hybrid States
  negotiating('Negotiating Transport'),
  connecting('Connecting Local Wi-Fi'),
  transferring('Transferring High-Speed'),
  fallback('Fallback to BLE'),

  // Terminal states
  completed('Transfer Complete ✓'),
  rejected('Rejected'),
  cancelled('Cancelled'),
  expired('Expired'),
  integrityFailure('Integrity Verification Failed'),
  failed('Transfer Failed');

  final String label;
  const MeshFileTransferState(this.label);

  bool get isTerminal =>
      this == completed ||
      this == rejected ||
      this == cancelled ||
      this == expired ||
      this == integrityFailure ||
      this == failed;

  bool get isSuccess => this == completed;
}

/// Types of acknowledgements exchanged during mesh file transfers.
enum MeshFileAckType {
  fileOfferAccept(0x01, 'ACCEPT'),
  fileOfferReject(0x02, 'REJECT'),
  chunkAck(0x03, 'CHUNK_ACK'),
  transferComplete(0x04, 'COMPLETE'),
  transferFailed(0x05, 'FAILED'),
  transferCancelled(0x06, 'CANCELLED'),
  wifiNegotiate(0x07, 'WIFI_NEGOTIATE'),
  wifiReady(0x08, 'WIFI_READY'),
  wifiFallback(0x09, 'WIFI_FALLBACK');

  final int typeCode;
  final String label;
  const MeshFileAckType(this.typeCode, this.label);

  static MeshFileAckType fromCode(int code) {
    for (final t in MeshFileAckType.values) {
      if (t.typeCode == code) return t;
    }
    throw ArgumentError('Invalid file ACK type code: $code');
  }
}

/// Metadata offer describing an academic file available for P2P transfer.
class MeshFileOffer {
  /// Maximum filename length for M5A.
  static const int maxFilenameLength = 120;

  /// Maximum MIME type length.
  static const int maxMimeTypeLength = 80;

  /// Maximum file size supported by M5A over BLE Mesh (2 MB).
  static const int maxFileSizeBytes = 2 * 1024 * 1024;

  /// Protocol ceiling for BLE Mesh transfers (2 MB).
  static const int maxBleFileSizeBytes = 2 * 1024 * 1024;

  /// Application ceiling for high-speed Local Wi-Fi transfers (100 MB).
  static const int maxWifiFileSizeBytes = 100 * 1024 * 1024;

  /// Default chunk size in bytes (calibrated for 250-byte BLE transport budget).
  static const int defaultChunkSize = 100;

  /// 16-byte logical file ID (represented as a 32-character hexadecimal string).
  final String fileId;

  /// Device ID of the originating sender.
  final String senderDeviceId;

  /// Institutional user ID of the sender if resolved.
  final String? senderUserId;

  /// CampusOS verified role of the sender.
  final String senderRole;

  /// Filename (without path).
  final String filename;

  /// MIME type of the file.
  final String mimeType;

  /// Size of the complete file in bytes.
  final int fileSize;

  /// Expected SHA-256 hash of the complete file (64-character lowercase hexadecimal).
  final String sha256;

  /// Byte size of each chunk.
  final int chunkSize;

  /// Total number of chunks required to reassemble the file.
  final int totalChunks;

  /// Creation timestamp.
  final DateTime createdAt;

  /// Timestamp after which the offer expires if not accepted.
  final DateTime expiresAt;

  /// Specific target peer device ID (null or empty for broadcast to nearby peers).
  final String? targetDeviceId;

  /// Authorization scope (defaults to 'academic').
  final String scope;

  /// Preferred transport mechanism negotiated for payload delivery.
  final MeshTransportType preferredTransport;

  MeshFileOffer({
    required this.fileId,
    required this.senderDeviceId,
    this.senderUserId,
    required this.senderRole,
    required this.filename,
    required this.mimeType,
    required this.fileSize,
    required this.sha256,
    this.chunkSize = defaultChunkSize,
    required this.totalChunks,
    required this.createdAt,
    required this.expiresAt,
    this.targetDeviceId,
    this.scope = 'academic',
    this.preferredTransport = MeshTransportType.bleMesh,
  }) {
    if (fileId.trim().length != 32) {
      throw ArgumentError('fileId must be exactly 32 hex characters (16 bytes).');
    }
    if (filename.trim().isEmpty) {
      throw ArgumentError('filename cannot be empty.');
    }
    if (filename.trim().length > maxFilenameLength) {
      throw ArgumentError('filename exceeds $maxFilenameLength characters.');
    }
    if (mimeType.trim().length > maxMimeTypeLength) {
      throw ArgumentError('mimeType exceeds $maxMimeTypeLength characters.');
    }
    if (fileSize <= 0) {
      throw ArgumentError('fileSize must be greater than 0.');
    }
    final maxAllowed = preferredTransport == MeshTransportType.localWifi
        ? maxWifiFileSizeBytes
        : maxBleFileSizeBytes;
    if (fileSize > maxAllowed) {
      throw ArgumentError(
        'fileSize ($fileSize bytes) exceeds limit of $maxAllowed bytes for $preferredTransport.',
      );
    }
    if (sha256.trim().length != 64) {
      throw ArgumentError('sha256 must be exactly 64 hex characters.');
    }
    if (chunkSize <= 0 || chunkSize > 140) {
      throw ArgumentError('chunkSize must be between 1 and 140 bytes.');
    }
    if (totalChunks <= 0) {
      throw ArgumentError('totalChunks must be greater than 0.');
    }
    if (!expiresAt.isAfter(createdAt)) {
      throw ArgumentError('expiresAt must be after createdAt.');
    }
  }

  /// Calculates the expected total chunks for a given file size and chunk size.
  static int calculateTotalChunks(int fileSize, int chunkSize) {
    if (fileSize <= 0) return 0;
    return (fileSize / chunkSize).ceil();
  }  /// Deterministically serializes into compact binary bytes for BLE transport.
  Uint8List toBytes() {
    final fileIdBytes = _hexToBytes(fileId);
    final sha256Bytes = _hexToBytes(sha256);
    final filenameUtf8 = utf8.encode(filename.trim());
    final mimeUtf8 = utf8.encode(mimeType.trim());
    final targetUtf8 = targetDeviceId != null && targetDeviceId!.isNotEmpty
        ? utf8.encode(targetDeviceId!.trim())
        : <int>[];
    final userUtf8 = senderUserId != null && senderUserId!.isNotEmpty
        ? utf8.encode(senderUserId!.trim())
        : <int>[];

    final builder = BytesBuilder(copy: false);
    builder.add(fileIdBytes); // 16 bytes

    final flags = (targetUtf8.isNotEmpty ? 1 : 0) |
        (preferredTransport == MeshTransportType.localWifi ? 2 : 0);

    final bdata = ByteData(16);
    bdata.setUint32(0, fileSize, Endian.big);
    bdata.setUint16(4, chunkSize, Endian.big);
    bdata.setUint16(6, totalChunks, Endian.big);
    bdata.setUint32(8, expiresAt.toUtc().millisecondsSinceEpoch ~/ 1000, Endian.big);
    bdata.setUint8(12, flags);
    bdata.setUint8(13, userUtf8.isNotEmpty ? 1 : 0);
    bdata.setUint8(14, filenameUtf8.length);
    bdata.setUint8(15, mimeUtf8.length);
    builder.add(bdata.buffer.asUint8List()); // 16 bytes

    builder.add(sha256Bytes); // 32 bytes
    builder.add(filenameUtf8);
    builder.add(mimeUtf8);

    if (targetUtf8.isNotEmpty) {
      builder.addByte(targetUtf8.length);
      builder.add(targetUtf8);
    }
    if (userUtf8.isNotEmpty) {
      builder.addByte(userUtf8.length);
      builder.add(userUtf8);
    }

    return builder.toBytes();
  }

  /// Deserializes from raw binary bytes.
  factory MeshFileOffer.fromBytes({
    required Uint8List bytes,
    required String senderDeviceId,
    required String senderRole,
    required DateTime createdAt,
  }) {
    if (bytes.length < 64) {
      throw const FormatException('File offer payload truncated (< 64 bytes).');
    }

    final byteData = ByteData.sublistView(bytes);
    final fileIdBytes = bytes.sublist(0, 16);
    final fileIdHex = _bytesToHex(fileIdBytes);

    final fileSize = byteData.getUint32(16, Endian.big);
    final chunkSize = byteData.getUint16(20, Endian.big);
    final totalChunks = byteData.getUint16(22, Endian.big);
    final expiresUnix = byteData.getUint32(24, Endian.big);
    final flags = byteData.getUint8(28);
    final hasTarget = (flags & 1) != 0;
    final preferredTransport = (flags & 2) != 0
        ? MeshTransportType.localWifi
        : MeshTransportType.bleMesh;
    final hasUser = byteData.getUint8(29) == 1;
    final fnLen = byteData.getUint8(30);
    final mimeLen = byteData.getUint8(31);

    final sha256Bytes = bytes.sublist(32, 64);
    final sha256Hex = _bytesToHex(sha256Bytes);

    int offset = 64;
    if (bytes.length < offset + fnLen + mimeLen) {
      throw const FormatException('File offer payload strings truncated.');
    }

    final filename = utf8.decode(bytes.sublist(offset, offset + fnLen));
    offset += fnLen;

    final mimeType = utf8.decode(bytes.sublist(offset, offset + mimeLen));
    offset += mimeLen;

    String? targetDeviceId;
    if (hasTarget && offset < bytes.length) {
      final tLen = bytes[offset++];
      if (offset + tLen <= bytes.length) {
        targetDeviceId = utf8.decode(bytes.sublist(offset, offset + tLen));
        offset += tLen;
      }
    }

    String? senderUserId;
    if (hasUser && offset < bytes.length) {
      final uLen = bytes[offset++];
      if (offset + uLen <= bytes.length) {
        senderUserId = utf8.decode(bytes.sublist(offset, offset + uLen));
      }
    }

    final expiresAt = DateTime.fromMillisecondsSinceEpoch(expiresUnix * 1000, isUtc: true);

    return MeshFileOffer(
      fileId: fileIdHex,
      senderDeviceId: senderDeviceId,
      senderUserId: senderUserId,
      senderRole: senderRole,
      filename: filename,
      mimeType: mimeType,
      fileSize: fileSize,
      sha256: sha256Hex,
      chunkSize: chunkSize,
      totalChunks: totalChunks,
      createdAt: createdAt,
      expiresAt: expiresAt,
      targetDeviceId: targetDeviceId,
      preferredTransport: preferredTransport,
    );
  }

  static Uint8List _hexToBytes(String hex) {
    final clean = hex.replaceAll(' ', '');
    final result = Uint8List(clean.length ~/ 2);
    for (int i = 0; i < clean.length; i += 2) {
      result[i ~/ 2] = int.parse(clean.substring(i, i + 2), radix: 16);
    }
    return result;
  }

  static String _bytesToHex(List<int> bytes) {
    return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }
}

/// An individual chunk of binary data transported over BLE mesh.
class MeshFileChunk {
  /// 16-byte logical file ID (32 hex characters).
  final String fileId;

  /// 0-indexed sequence number of this chunk (0 <= sequence < totalChunks).
  final int sequence;

  /// Total number of chunks in the file.
  final int totalChunks;

  /// Raw chunk payload bytes.
  final Uint8List bytes;

  MeshFileChunk({
    required this.fileId,
    required this.sequence,
    required this.totalChunks,
    required this.bytes,
  }) {
    if (fileId.length != 32) {
      throw ArgumentError('fileId must be exactly 32 hex characters.');
    }
    if (sequence < 0 || sequence >= totalChunks) {
      throw ArgumentError('sequence ($sequence) out of bounds (0 <= seq < $totalChunks).');
    }
    if (totalChunks <= 0) {
      throw ArgumentError('totalChunks must be greater than 0.');
    }
    if (bytes.isEmpty) {
      throw ArgumentError('chunk bytes cannot be empty.');
    }
  }

  /// Serializes into compact binary bytes for [MeshPacket] payload.
  Uint8List toBytes() {
    final fileIdBytes = MeshFileOffer._hexToBytes(fileId);
    final builder = BytesBuilder(copy: false);
    builder.add(fileIdBytes); // 16 bytes

    final header = ByteData(5);
    header.setUint16(0, sequence, Endian.big);
    header.setUint16(2, totalChunks, Endian.big);
    header.setUint8(4, bytes.length);
    builder.add(header.buffer.asUint8List()); // 5 bytes

    builder.add(bytes); // N bytes
    return builder.toBytes();
  }

  /// Deserializes from raw binary bytes.
  factory MeshFileChunk.fromBytes(Uint8List rawBytes) {
    if (rawBytes.length < 21) {
      throw const FormatException('Chunk payload truncated (< 21 bytes header).');
    }

    final fileId = MeshFileOffer._bytesToHex(rawBytes.sublist(0, 16));
    final header = ByteData.sublistView(rawBytes, 16, 21);
    final sequence = header.getUint16(0, Endian.big);
    final totalChunks = header.getUint16(2, Endian.big);
    final dataLen = header.getUint8(4);

    if (rawBytes.length < 21 + dataLen) {
      throw const FormatException('Chunk payload data truncated.');
    }

    final chunkData = Uint8List.fromList(rawBytes.sublist(21, 21 + dataLen));

    return MeshFileChunk(
      fileId: fileId,
      sequence: sequence,
      totalChunks: totalChunks,
      bytes: chunkData,
    );
  }
}

/// Acknowledgement packet payload for file transfer signaling.
class MeshFileAck {
  final String fileId;
  final MeshFileAckType ackType;
  final int sequence;
  final int reasonCode;
  final String? wifiHost;
  final int? wifiPort;
  final String? wifiToken;

  const MeshFileAck({
    required this.fileId,
    required this.ackType,
    this.sequence = 0,
    this.reasonCode = 0,
    this.wifiHost,
    this.wifiPort,
    this.wifiToken,
  });

  Uint8List toBytes() {
    final builder = BytesBuilder(copy: false);
    builder.add(MeshFileOffer._hexToBytes(fileId)); // 16 bytes

    final header = ByteData(4);
    header.setUint8(0, ackType.typeCode);
    header.setUint16(1, sequence, Endian.big);
    header.setUint8(3, reasonCode);
    builder.add(header.buffer.asUint8List());

    if (wifiHost != null || wifiPort != null || wifiToken != null) {
      final hostUtf8 = wifiHost != null ? utf8.encode(wifiHost!) : <int>[];
      final tokenUtf8 = wifiToken != null ? utf8.encode(wifiToken!) : <int>[];
      final wifiData = ByteData(4);
      wifiData.setUint16(0, wifiPort ?? 0, Endian.big);
      wifiData.setUint8(2, hostUtf8.length);
      wifiData.setUint8(3, tokenUtf8.length);
      builder.add(wifiData.buffer.asUint8List());
      builder.add(hostUtf8);
      builder.add(tokenUtf8);
    }

    return builder.toBytes();
  }

  factory MeshFileAck.fromBytes(Uint8List rawBytes) {
    if (rawBytes.length < 20) {
      throw const FormatException('File ACK payload truncated (< 20 bytes).');
    }

    final fileId = MeshFileOffer._bytesToHex(rawBytes.sublist(0, 16));
    final header = ByteData.sublistView(rawBytes, 16, 20);
    final ackType = MeshFileAckType.fromCode(header.getUint8(0));
    final sequence = header.getUint16(1, Endian.big);
    final reasonCode = header.getUint8(3);

    String? wifiHost;
    int? wifiPort;
    String? wifiToken;

    if (rawBytes.length >= 24) {
      final wifiData = ByteData.sublistView(rawBytes, 20, 24);
      wifiPort = wifiData.getUint16(0, Endian.big);
      final hostLen = wifiData.getUint8(2);
      final tokenLen = wifiData.getUint8(3);
      int offset = 24;
      if (rawBytes.length >= offset + hostLen) {
        wifiHost = utf8.decode(rawBytes.sublist(offset, offset + hostLen));
        offset += hostLen;
      }
      if (rawBytes.length >= offset + tokenLen) {
        wifiToken = utf8.decode(rawBytes.sublist(offset, offset + tokenLen));
      }
    }

    return MeshFileAck(
      fileId: fileId,
      ackType: ackType,
      sequence: sequence,
      reasonCode: reasonCode,
      wifiHost: wifiHost,
      wifiPort: wifiPort,
      wifiToken: wifiToken,
    );
  }
}

/// Complete in-memory domain transfer session.
class MeshFileTransferSession {
  final String transferId;
  final String fileId;
  final String peerDeviceId;
  final String? peerDisplayName;
  final String peerRole;
  final bool isPeerVerified;
  final MeshTransferDirection direction;
  final MeshFileTransferState state;
  final String filename;
  final String mimeType;
  final int fileSize;
  final int transferredBytes;
  final int totalChunks;
  final int transferredChunks;
  final String sha256;
  final String? localFilePath;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime expiresAt;
  final String? errorMessage;
  final int hopCount;
  final MeshTransportType transportType;
  final String? wifiHost;
  final int? wifiPort;
  final String? wifiToken;

  const MeshFileTransferSession({
    required this.transferId,
    required this.fileId,
    required this.peerDeviceId,
    this.peerDisplayName,
    required this.peerRole,
    this.isPeerVerified = true,
    required this.direction,
    required this.state,
    required this.filename,
    required this.mimeType,
    required this.fileSize,
    required this.transferredBytes,
    required this.totalChunks,
    required this.transferredChunks,
    required this.sha256,
    this.localFilePath,
    required this.createdAt,
    required this.updatedAt,
    required this.expiresAt,
    this.errorMessage,
    this.hopCount = 0,
    this.transportType = MeshTransportType.bleMesh,
    this.wifiHost,
    this.wifiPort,
    this.wifiToken,
  });

  /// Progress percentage from 0.0 to 1.0.
  double get progress {
    if (fileSize <= 0) return 0.0;
    final p = transferredBytes / fileSize;
    return p.clamp(0.0, 1.0);
  }

  /// Transfer speed in KB/s based on elapsed duration.
  double get speedKbps {
    final durationSeconds = updatedAt.difference(createdAt).inMilliseconds / 1000.0;
    if (durationSeconds <= 0.1 || transferredBytes <= 0) return 0.0;
    return (transferredBytes / 1024.0) / durationSeconds;
  }

  /// Formatted speed label (e.g. '12.4 MB/s' or '450.0 KB/s').
  String get formattedSpeed {
    if (speedKbps >= 1024.0) {
      return '${(speedKbps / 1024.0).toStringAsFixed(1)} MB/s';
    }
    return '${speedKbps.toStringAsFixed(1)} KB/s';
  }

  /// True if using high-speed Local Wi-Fi transport.
  bool get isHighSpeed => transportType == MeshTransportType.localWifi;

  /// Human-readable hop description.
  String get hopDescription {
    if (isHighSpeed) return 'Direct Wi-Fi · High-Speed';
    if (hopCount == 0) return '1 hop · Direct BLE';
    return '${hopCount + 1} hops · BLE Relayed';
  }

  MeshFileTransferSession copyWith({
    MeshFileTransferState? state,
    int? transferredBytes,
    int? transferredChunks,
    String? localFilePath,
    DateTime? updatedAt,
    String? errorMessage,
    int? hopCount,
    MeshTransportType? transportType,
    String? wifiHost,
    int? wifiPort,
    String? wifiToken,
  }) {
    return MeshFileTransferSession(
      transferId: transferId,
      fileId: fileId,
      peerDeviceId: peerDeviceId,
      peerDisplayName: peerDisplayName,
      peerRole: peerRole,
      isPeerVerified: isPeerVerified,
      direction: direction,
      state: state ?? this.state,
      filename: filename,
      mimeType: mimeType,
      fileSize: fileSize,
      transferredBytes: transferredBytes ?? this.transferredBytes,
      totalChunks: totalChunks,
      transferredChunks: transferredChunks ?? this.transferredChunks,
      sha256: sha256,
      localFilePath: localFilePath ?? this.localFilePath,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      expiresAt: expiresAt,
      errorMessage: errorMessage ?? this.errorMessage,
      hopCount: hopCount ?? this.hopCount,
      transportType: transportType ?? this.transportType,
      wifiHost: wifiHost ?? this.wifiHost,
      wifiPort: wifiPort ?? this.wifiPort,
      wifiToken: wifiToken ?? this.wifiToken,
    );
  }
}
