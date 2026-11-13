import 'dart:convert';
import 'dart:typed_data';

import '../mesh_packet.dart';
import 'mesh_chat_delivery_state.dart';

/// Compact binary/JSON payload carried within a [MeshPacket] payload for chat.
class MeshChatPayload {
  /// Unique message identifier (if omitted, inferred directly from MeshPacket ID).
  final String messageId;

  /// Target channel identifier (e.g. "channel:general" or "dm:devA:devB").
  final String channelId;

  /// Text content of the chat message (or Base64 ciphertext when [isEncrypted] is true).
  final String text;

  /// Optional unverified display name provided by sender (verified against trust bundle on receipt).
  final String senderDisplayName;

  /// Optional recipient device ID for direct messages.
  final String? recipientDeviceId;

  /// Optional base64-encoded compressed image attachment.
  final String? imageBase64;

  /// Whether [text] / [imageBase64] is end-to-end encrypted (for 1-to-1 DMs).
  final bool isEncrypted;

  /// Optional 12-byte ChaCha20-Poly1305 nonce (base64) when [isEncrypted] is true.
  final String? encryptionNonce;

  /// Optional sender X25519 ephemeral/public key (base64) for E2EE DM decryption.
  final String? senderE2eePublicKey;

  /// Optional parent message ID when replying to another message.
  final String? replyToMessageId;

  /// Optional short quoted snippet of the replied message.
  final String? replyToPreview;

  const MeshChatPayload({
    this.messageId = '',
    required this.channelId,
    required this.text,
    this.senderDisplayName = '',
    this.recipientDeviceId,
    this.imageBase64,
    this.isEncrypted = false,
    this.encryptionNonce,
    this.senderE2eePublicKey,
    this.replyToMessageId,
    this.replyToPreview,
  });

  /// Maximum character length for offline BLE mesh chat messages.
  static const int maxTextLength = 500;

  /// Encodes payload to compact UTF-8 JSON bytes.
  Uint8List toBytes() {
    final sanitizedText = isEncrypted
        ? text
        : (text.length > maxTextLength ? text.substring(0, maxTextLength) : text);
    final map = <String, dynamic>{
      if (messageId.isNotEmpty) 'mid': messageId,
      'cid': channelId,
      'txt': sanitizedText,
      if (senderDisplayName.isNotEmpty) 'name': senderDisplayName,
      if (recipientDeviceId != null) 'rec': recipientDeviceId,
      if (imageBase64 != null && imageBase64!.isNotEmpty) 'img': imageBase64,
      if (isEncrypted) 'enc': true,
      if (encryptionNonce != null && encryptionNonce!.isNotEmpty) 'nonce': encryptionNonce,
      if (senderE2eePublicKey != null && senderE2eePublicKey!.isNotEmpty) 'ekey': senderE2eePublicKey,
      if (replyToMessageId != null && replyToMessageId!.isNotEmpty) 'rep': replyToMessageId,
      if (replyToPreview != null && replyToPreview!.isNotEmpty) 'rprev': replyToPreview,
    };
    return Uint8List.fromList(utf8.encode(jsonEncode(map)));
  }

  /// Decodes payload from raw bytes with optional fallback packet ID.
  static MeshChatPayload fromBytes(Uint8List bytes, [String fallbackMessageId = '']) {
    final str = utf8.decode(bytes);
    final map = jsonDecode(str) as Map<String, dynamic>;

    return MeshChatPayload(
      messageId: map['mid']?.toString() ?? fallbackMessageId,
      channelId: map['cid']?.toString() ?? 'channel:general',
      text: map['txt']?.toString() ?? '',
      senderDisplayName: map['name']?.toString() ?? '',
      recipientDeviceId: map['rec']?.toString(),
      imageBase64: map['img']?.toString(),
      isEncrypted: map['enc'] == true,
      encryptionNonce: map['nonce']?.toString(),
      senderE2eePublicKey: map['ekey']?.toString(),
      replyToMessageId: map['rep']?.toString(),
      replyToPreview: map['rprev']?.toString(),
    );
  }
}

/// Domain model representing a CampusOS Mesh chat message.
class MeshChatMessage {
  /// Unique identifier of the message (corresponds to MeshPacket ID).
  final String messageId;

  /// Physical device identifier of the originating sender.
  final String senderDeviceId;

  /// Certified institutional user identifier (resolved from trust bundle).
  final String? senderUserId;

  /// Certified or verified institutional display name of sender.
  final String senderDisplayName;

  /// Institutional role of the sender (e.g., student, teacher, warden, admin).
  final String senderRole;

  /// Target channel identifier.
  final String channelId;

  /// Message text content.
  final String text;

  /// Timestamp when message was created.
  final DateTime createdAt;

  /// Protocol-level relay count observed on arrival (0 = origin, 1 = direct, >1 = relayed).
  final int hopCount;

  /// Remaining Time-to-Live on packet arrival.
  final int ttl;

  /// Current delivery lifecycle condition.
  final MeshChatDeliveryState deliveryState;

  /// Verification status from institutional trust bundle ('TRUSTED', 'UNVERIFIED', 'REVOKED').
  final String verificationState;

  /// Whether this message was authored by the local user.
  final bool isOutgoing;

  /// Cryptographic Ed25519 signature bytes.
  final Uint8List? signature;

  /// Optional base64-encoded compressed image attachment.
  final String? imageBase64;

  /// Moderation status: 'CLEAN', 'FLAGGED', 'QUARANTINED', or 'HIDDEN_BY_ADMIN'.
  final String moderationStatus;

  /// Moderation severity: 'NONE', 'MODERATE', 'HIGH', 'CRITICAL'.
  final String moderationSeverity;

  /// Moderation category: 'NONE', 'CRIME_THREAT', 'HARASSMENT', 'EXPLICIT', 'SPAM'.
  final String? moderationCategory;

  /// Human-readable reason(s) explaining why the message was flagged.
  final String? flagReason;

  /// Cloud sync status: 'PENDING', 'SYNCED', 'FAILED'.
  final String syncStatus;

  /// Whether payload was end-to-end encrypted in transit/cloud.
  final bool isEncrypted;

  /// Optional parent message ID being replied to.
  final String? replyToMessageId;

  /// Optional short snippet of the replied message.
  final String? replyToPreview;

  /// Optional Base64 signable packet bytes for backend Ed25519 verification during relay sync.
  final String? signableBytesBase64;

  const MeshChatMessage({
    required this.messageId,
    required this.senderDeviceId,
    this.senderUserId,
    required this.senderDisplayName,
    required this.senderRole,
    required this.channelId,
    required this.text,
    required this.createdAt,
    this.hopCount = 0,
    this.ttl = MeshPacket.defaultTtl,
    this.deliveryState = MeshChatDeliveryState.relayed,
    this.verificationState = 'UNVERIFIED',
    this.isOutgoing = false,
    this.signature,
    this.imageBase64,
    this.moderationStatus = 'CLEAN',
    this.moderationSeverity = 'NONE',
    this.moderationCategory,
    this.flagReason,
    this.syncStatus = 'PENDING',
    this.isEncrypted = false,
    this.replyToMessageId,
    this.replyToPreview,
    this.signableBytesBase64,
  });

  /// User-friendly hop telemetry description.
  String get hopDescription {
    if (hopCount == 0 && isOutgoing) {
      return syncStatus == 'SYNCED' ? 'Cloud Synced' : 'Local';
    }
    if (hopCount <= 1) {
      return '1 hop · Direct';
    }
    return '$hopCount hops · Relayed';
  }

  /// Whether the sender's identity was cryptographically verified against the institutional trust bundle.
  bool get isTrusted => verificationState == 'TRUSTED';

  /// Whether this message belongs to a 1-to-1 direct message conversation.
  bool get isDirectMessage => channelId.startsWith('dm:');

  /// Whether this message has an attached image.
  bool get hasImage => imageBase64 != null && imageBase64!.isNotEmpty;

  /// Whether this message is flagged or quarantined by moderation.
  bool get isFlagged => moderationStatus != 'CLEAN';

  /// Whether this message is quarantined (high/critical severity).
  bool get isQuarantined => moderationStatus == 'QUARANTINED';

  /// Serializes into a database-ready map.
  Map<String, dynamic> toMap() {
    return {
      'messageId': messageId,
      'senderDeviceId': senderDeviceId,
      'senderUserId': senderUserId,
      'senderDisplayName': senderDisplayName,
      'senderRole': senderRole,
      'channelId': channelId,
      'text': text,
      'createdAt': createdAt.millisecondsSinceEpoch,
      'hopCount': hopCount,
      'ttl': ttl,
      'deliveryState': deliveryState.name,
      'verificationState': verificationState,
      'isOutgoing': isOutgoing ? 1 : 0,
      'imageBase64': imageBase64,
      'moderationStatus': moderationStatus,
      'moderationSeverity': moderationSeverity,
      'moderationCategory': moderationCategory,
      'flagReason': flagReason,
      'syncStatus': syncStatus,
      'isEncrypted': isEncrypted ? 1 : 0,
      'replyToMessageId': replyToMessageId,
      'replyToPreview': replyToPreview,
      'signableBytesBase64': signableBytesBase64,
    };
  }

  /// Reconstructs message from database or API JSON map.
  factory MeshChatMessage.fromMap(Map<String, dynamic> map) {
    Uint8List? sig;
    final rawSigB64 = map['signatureBase64']?.toString();
    if (rawSigB64 != null && rawSigB64.isNotEmpty) {
      try {
        sig = Uint8List.fromList(base64Decode(rawSigB64));
      } catch (_) {}
    }

    String? flagReason = map['flagReason']?.toString();
    if ((flagReason == null || flagReason.isEmpty) && map['flagReasons'] is List) {
      final list = (map['flagReasons'] as List).map((e) => e.toString()).where((e) => e.isNotEmpty).toList();
      if (list.isNotEmpty) {
        flagReason = list.join(', ');
      }
    }

    return MeshChatMessage(
      messageId: map['messageId']?.toString() ?? '',
      senderDeviceId: map['senderDeviceId']?.toString() ?? '',
      senderUserId: map['senderUserId']?.toString(),
      senderDisplayName: map['senderDisplayName']?.toString() ?? 'Unknown User',
      senderRole: map['senderRole']?.toString() ?? 'student',
      channelId: map['channelId']?.toString() ?? 'channel:general',
      text: map['text']?.toString() ?? '',
      createdAt: DateTime.fromMillisecondsSinceEpoch(
        map['createdAt'] is int ? map['createdAt'] as int : int.tryParse(map['createdAt']?.toString() ?? '0') ?? 0,
      ),
      hopCount: map['hopCount'] is int ? map['hopCount'] as int : int.tryParse(map['hopCount']?.toString() ?? '0') ?? 0,
      ttl: map['ttl'] is int ? map['ttl'] as int : int.tryParse(map['ttl']?.toString() ?? '7') ?? 7,
      deliveryState: MeshChatDeliveryState.fromString(map['deliveryState']?.toString() ?? 'received'),
      verificationState: map['verificationState']?.toString() ?? 'UNVERIFIED',
      isOutgoing: (map['isOutgoing'] == 1 || map['isOutgoing'] == true),
      signature: sig,
      imageBase64: map['imageBase64']?.toString(),
      moderationStatus: map['moderationStatus']?.toString() ?? 'CLEAN',
      moderationSeverity: map['moderationSeverity']?.toString() ?? 'NONE',
      moderationCategory: map['moderationCategory']?.toString(),
      flagReason: flagReason,
      syncStatus: map['syncStatus']?.toString() ?? 'PENDING',
      isEncrypted: (map['isEncrypted'] == 1 || map['isEncrypted'] == true),
      replyToMessageId: map['replyToMessageId']?.toString(),
      replyToPreview: map['replyToPreview']?.toString(),
      signableBytesBase64: map['signableBytesBase64']?.toString(),
    );
  }

  MeshChatMessage copyWith({
    String? messageId,
    String? senderDeviceId,
    String? senderUserId,
    String? senderDisplayName,
    String? senderRole,
    String? channelId,
    String? text,
    DateTime? createdAt,
    int? hopCount,
    int? ttl,
    MeshChatDeliveryState? deliveryState,
    String? verificationState,
    bool? isOutgoing,
    Uint8List? signature,
    String? imageBase64,
    String? moderationStatus,
    String? moderationSeverity,
    String? moderationCategory,
    String? flagReason,
    String? syncStatus,
    bool? isEncrypted,
    String? replyToMessageId,
    String? replyToPreview,
    String? signableBytesBase64,
  }) {
    return MeshChatMessage(
      messageId: messageId ?? this.messageId,
      senderDeviceId: senderDeviceId ?? this.senderDeviceId,
      senderUserId: senderUserId ?? this.senderUserId,
      senderDisplayName: senderDisplayName ?? this.senderDisplayName,
      senderRole: senderRole ?? this.senderRole,
      channelId: channelId ?? this.channelId,
      text: text ?? this.text,
      createdAt: createdAt ?? this.createdAt,
      hopCount: hopCount ?? this.hopCount,
      ttl: ttl ?? this.ttl,
      deliveryState: deliveryState ?? this.deliveryState,
      verificationState: verificationState ?? this.verificationState,
      isOutgoing: isOutgoing ?? this.isOutgoing,
      signature: signature ?? this.signature,
      imageBase64: imageBase64 ?? this.imageBase64,
      moderationStatus: moderationStatus ?? this.moderationStatus,
      moderationSeverity: moderationSeverity ?? this.moderationSeverity,
      moderationCategory: moderationCategory ?? this.moderationCategory,
      flagReason: flagReason ?? this.flagReason,
      syncStatus: syncStatus ?? this.syncStatus,
      isEncrypted: isEncrypted ?? this.isEncrypted,
      replyToMessageId: replyToMessageId ?? this.replyToMessageId,
      replyToPreview: replyToPreview ?? this.replyToPreview,
      signableBytesBase64: signableBytesBase64 ?? this.signableBytesBase64,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! MeshChatMessage) return false;
    return messageId == other.messageId;
  }

  @override
  int get hashCode => messageId.hashCode;

  @override
  String toString() {
    return 'MeshChatMessage(id: $messageId, sender: $senderDisplayName ($senderRole), channel: $channelId, hops: $hopCount, verified: $isTrusted, mod: $moderationStatus)';
  }
}
