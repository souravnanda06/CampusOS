import 'dart:async';
import 'dart:convert';
import 'package:cryptography/cryptography.dart';
import 'package:flutter/foundation.dart';

import '../../../auth/services/auth_service.dart';
import '../../../student/models/passport_trust_bundle_model.dart';
import '../../../student/services/passport_trust_bundle_service.dart';
import '../campus_mesh_service.dart';
import '../mesh_crypto.dart';
import '../mesh_packet.dart';
import '../mesh_peer.dart';
import 'mesh_chat_channel.dart';
import 'mesh_chat_delivery_state.dart';
import 'mesh_chat_message.dart';
import 'mesh_chat_repository.dart';
import 'mesh_chat_sync_service.dart';
import 'mesh_moderation_filter.dart';

/// Application service coordinating offline-first + MongoDB-synced P2P mesh chat.
///
/// Features:
/// - Institutional trust-bundle identity resolution & Ed25519 signing.
/// - Persistent Drift/SQLite storage across restarts.
/// - Hybrid catch-up: BLE/UDP store-and-forward + MongoDB cloud sync.
/// - X25519 + ChaCha20-Poly1305 end-to-end encrypted 1-to-1 DMs.
/// - Two-tier content moderation & cryptographic safety flagging.
class MeshChatService {
  final CampusMeshService _meshService;
  final MeshChatRepository _repository;
  final MeshCryptoService? _cryptoService;
  final PassportTrustBundleService? _trustBundleService;
  final PassportTrustBundle? _mockTrustBundle;
  final String? _localDisplayName;
  MeshChatSyncService? _syncService;

  StreamSubscription<MeshPacket>? _meshSubscription;
  StreamSubscription<MeshPeer>? _peerAddedSubscription;
  final List<MeshChatChannel> _channels = List.from(MeshChatChannel.defaultChannels);

  final StreamController<MeshChatMessage> _incomingMessageController =
      StreamController<MeshChatMessage>.broadcast();

  final StreamController<List<MeshChatChannel>> _channelsController =
      StreamController<List<MeshChatChannel>>.broadcast();

  final StreamController<Map<String, int>> _unreadCountsController =
      StreamController<Map<String, int>>.broadcast();

  // E2EE DM session keypair & peer public key cache (X25519)
  final X25519 _x25519 = X25519();
  final Chacha20 _aead = Chacha20.poly1305Aead();
  SimpleKeyPair? _localE2eeKeyPair;
  String? _localE2eePublicKeyB64;
  final Map<String, String> _peerE2eePublicKeys = {};
  final Map<String, DateTime> _lastDigestReplyByPeer = {};
  final Map<String, String> _peerDisplayNames = {};

  /// Retrieves cached peer display name if known.
  String? getPeerDisplayName(String deviceId) => _peerDisplayNames[deviceId];

  MeshChatService({
    required CampusMeshService meshService,
    required MeshChatRepository repository,
    MeshCryptoService? cryptoService,
    PassportTrustBundleService? trustBundleService,
    PassportTrustBundle? mockTrustBundle,
    String? localDisplayName,
    MeshChatSyncService? syncService,
  })  : _meshService = meshService,
        _repository = repository,
        _cryptoService = cryptoService ?? meshService.cryptoService,
        _trustBundleService = trustBundleService,
        _mockTrustBundle = mockTrustBundle,
        _localDisplayName = localDisplayName,
        _syncService = syncService {
    _hookSyncService();
    _meshSubscription = _meshService.receivedPackets.listen(_handleIncomingMeshPacket);
    _peerAddedSubscription = _meshService.peerRegistry.peerAdded.listen(_handlePeerConnected);
  }

  /// Attaches a cloud sync service after construction.
  void attachSyncService(MeshChatSyncService syncService) {
    _syncService = syncService;
    _hookSyncService();
  }

  void _hookSyncService() {
    _syncService?.onMessagesPulled = (pulled) {
      for (final msg in pulled) {
        if (msg.senderDeviceId.isNotEmpty &&
            msg.senderDisplayName.isNotEmpty &&
            msg.senderDisplayName != msg.senderDeviceId &&
            !msg.senderDisplayName.startsWith('Peer (')) {
          _peerDisplayNames[msg.senderDeviceId] = msg.senderDisplayName;
        }
        if (!_incomingMessageController.isClosed) {
          _incomingMessageController.add(msg);
        }
      }
    };
  }

  /// Optional cloud sync coordinator.
  MeshChatSyncService? get syncService => _syncService;

  /// Local user display name configured for this device node.
  String? get localDisplayName => _localDisplayName;

  /// Authenticated local user ID if available.
  String? _localUserId;
  String? get localUserId => _localUserId;

  /// The list of currently active channels.
  List<MeshChatChannel> get channels => List.unmodifiable(_channels);

  /// Reactive stream of available channels.
  Stream<List<MeshChatChannel>> get channelsStream => _channelsController.stream;

  /// Stream of newly received incoming chat messages.
  Stream<MeshChatMessage> get incomingMessages => _incomingMessageController.stream;

  /// Reactive stream of unread counts per channel ID.
  Stream<Map<String, int>> get unreadCountsStream => _unreadCountsController.stream;

  /// Underlying repository instance.
  MeshChatRepository get repository => _repository;

  /// Underlying mesh network service.
  CampusMeshService get meshService => _meshService;

  /// Cryptographic service if configured.
  MeshCryptoService? get cryptoService => _cryptoService;

  /// Resolves local or mock Passport trust bundle.
  Future<PassportTrustBundle?> resolveTrustBundle() => _resolveTrustBundle();

  /// Initializes local repository, loads persisted channels, generates E2EE keypair,
  /// and subscribes to inbound mesh packets.
  Future<void> initialize() async {
    await _repository.initialize();

    try {
      final user = await AuthService().getUserDataFromStorage();
      if (user != null && user.id.isNotEmpty) {
        _localUserId = user.id;
      }
    } catch (_) {}

    if (_localE2eeKeyPair == null) {
      try {
        _localE2eeKeyPair = await _x25519.newKeyPair();
        final pub = await _localE2eeKeyPair!.extractPublicKey();
        _localE2eePublicKeyB64 = base64Encode(pub.bytes);
      } catch (e) {
        debugPrint('⚠️ [MESH_CHAT] Could not initialize E2EE X25519 keypair: $e');
      }
    }

    // Restore persisted custom & DM channels across restarts
    final savedChannels = await _repository.getSavedChannels();
    mergeChannels(savedChannels);

    // Warm peer display name cache from historical messages in local database
    try {
      final recent = await _repository.getAllMessages(limit: 100);
      for (final msg in recent) {
        if (msg.senderDeviceId.isNotEmpty &&
            msg.senderDisplayName.isNotEmpty &&
            msg.senderDisplayName != msg.senderDeviceId &&
            !msg.senderDisplayName.startsWith('Peer (')) {
          _peerDisplayNames[msg.senderDeviceId] = msg.senderDisplayName;
        }
      }
    } catch (_) {}

    await _meshSubscription?.cancel();
    _meshSubscription = _meshService.receivedPackets.listen(_handleIncomingMeshPacket);

    await _peerAddedSubscription?.cancel();
    _peerAddedSubscription = _meshService.peerRegistry.peerAdded.listen(_handlePeerConnected);

    await _emitUnreadCounts();
  }

  /// Merges discovered or persisted channels into the active channel list.
  void mergeChannels(List<MeshChatChannel> incoming) {
    bool changed = false;
    for (final ch in incoming) {
      if (ch.id.isEmpty) continue;
      final idx = _channels.indexWhere((existing) => existing.id == ch.id);
      if (idx == -1) {
        _channels.add(ch);
        changed = true;
      }
    }
    if (changed && !_channelsController.isClosed) {
      _channelsController.add(List.unmodifiable(_channels));
    }
  }

  /// Sends a chat message over the offline BLE mesh network and queues it for MongoDB cloud sync.
  ///
  /// Throws [MeshModerationException] if a `CRITICAL` crime/threat violation is detected.
  Future<MeshChatMessage> sendMessage({
    required String channelId,
    required String text,
    String? recipientDeviceId,
    String? imageBase64,
    String? replyToMessageId,
    String? replyToPreview,
  }) async {
    final trimmedText = text.trim();
    if (trimmedText.isEmpty && (imageBase64 == null || imageBase64.isEmpty)) {
      throw ArgumentError('Chat message text or image must be provided');
    }
    if (channelId == 'channel:emergency' || channelId == 'emergency') {
      throw StateError(
        'Ordinary chat messages cannot be posted to #emergency. Official emergency flares must originate from authorized institutional flows.',
      );
    }

    final packetIdBytes = MeshPacket.generatePacketId();
    final messageIdHex = packetIdBytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();

    // 1. Resolve local user display name from trust bundle if available
    String senderDisplayName = _localDisplayName ?? _meshService.localDeviceId;
    String? senderUserId;

    final bundle = await _resolveTrustBundle();
    if (bundle != null) {
      final identity = bundle.findIdentity(_meshService.localDeviceId) ??
          bundle.identities.cast<PassportTrustIdentity?>().firstWhere(
                (i) => i?.userId == _meshService.localDeviceId,
                orElse: () => null,
              );
      if (identity != null) {
        senderDisplayName = identity.userName ?? identity.userId;
        senderUserId = identity.userId;
      }
    }

    if (senderUserId == null || senderUserId == _meshService.localDeviceId) {
      try {
        final authUser = await AuthService().getUserDataFromStorage();
        if (authUser != null) {
          senderUserId = authUser.id;
          if (senderDisplayName == _meshService.localDeviceId || senderDisplayName.isEmpty) {
            senderDisplayName = authUser.name;
          }
        }
      } catch (_) {}
    }

    // 2. Offline pre-send content moderation check
    final moderation = MeshModerationFilter.evaluate(trimmedText);
    if (moderation.isCritical) {
      final flag = MeshModerationFlagRecord(
        flagId: 'pre_${messageIdHex.substring(0, 16)}',
        messageId: messageIdHex,
        channelId: channelId,
        reportedUserId: senderUserId ?? _meshService.localDeviceId,
        reportedDeviceId: _meshService.localDeviceId,
        category: moderation.category,
        severity: moderation.severity.wireName,
        reason: moderation.reasons.join(', '),
        messageSnapshot: trimmedText,
        source: 'AUTO_RULE',
        createdAtMs: DateTime.now().millisecondsSinceEpoch,
      );
      await _repository.saveModerationFlag(flag);
      unawaited(_syncService?.syncPendingAndPull());
      throw MeshModerationException(
        verdict: moderation,
        message: 'Message blocked & flagged (${moderation.reasons.join(", ")}). Severe threats/illegal activity are prohibited on CampusOS Mesh.',
      );
    }

    // Enforce channel restrictions
    final activeCh = _channels.firstWhere(
      (c) => c.id == channelId,
      orElse: () => MeshChatChannel(id: channelId, name: channelId),
    );
    if (activeCh.isRestricted) {
      throw const MeshModerationException(
        verdict: MeshModerationVerdict(
          status: 'RESTRICTED',
          severity: MeshModerationSeverity.high,
          category: 'COMMUNITY_POLICY',
          reasons: ['Channel restricted by administrators'],
        ),
        message: 'This channel has been restricted/dismantled by administration. Messaging is disabled.',
      );
    }

    // Direct message recipient resolution if channelId is dm:partA:partB
    String? resolvedRecipientId = recipientDeviceId;
    if (resolvedRecipientId == null && channelId.startsWith('dm:')) {
      final parts = channelId.substring(3).split(':');
      if (parts.length >= 2) {
        if (parts[0] == _meshService.localDeviceId) {
          resolvedRecipientId = parts[1];
        } else if (parts[1] == _meshService.localDeviceId) {
          resolvedRecipientId = parts[0];
        } else {
          resolvedRecipientId = parts[1];
        }
      }
    }

    // 3. Optionally E2EE-encrypt DM payload if recipient's X25519 public key is known
    String wireText = trimmedText;
    String? wireImage = imageBase64;
    bool wireEncrypted = false;
    String? wireNonce;

    if (channelId.startsWith('dm:') &&
        resolvedRecipientId != null &&
        _localE2eeKeyPair != null &&
        _peerE2eePublicKeys.containsKey(resolvedRecipientId)) {
      try {
        final peerPubBytes = base64Decode(_peerE2eePublicKeys[resolvedRecipientId]!);
        final sharedKey = await _x25519.sharedSecretKey(
          keyPair: _localE2eeKeyPair!,
          remotePublicKey: SimplePublicKey(peerPubBytes, type: KeyPairType.x25519),
        );
        final secretObj = jsonEncode({
          'txt': trimmedText,
          if (imageBase64 != null && imageBase64.isNotEmpty) 'img': imageBase64,
        });
        final nonce = _aead.newNonce();
        final secretBox = await _aead.encrypt(
          utf8.encode(secretObj),
          secretKey: sharedKey,
          nonce: nonce,
        );
        wireText = base64Encode(secretBox.cipherText + secretBox.mac.bytes);
        wireImage = null;
        wireNonce = base64Encode(nonce);
        wireEncrypted = true;
      } catch (e) {
        debugPrint('⚠️ [MESH_CHAT] DM E2EE encryption failed, falling back to signed payload: $e');
      }
    }

    // 4. Build transport payload
    final payload = MeshChatPayload(
      channelId: channelId,
      text: wireText,
      senderDisplayName: senderDisplayName,
      recipientDeviceId: resolvedRecipientId,
      imageBase64: wireImage,
      isEncrypted: wireEncrypted,
      encryptionNonce: wireNonce,
      senderE2eePublicKey: _localE2eePublicKeyB64,
      replyToMessageId: replyToMessageId,
      replyToPreview: replyToPreview,
    );
    final payloadBytes = payload.toBytes();

    // 5. Construct and sign transport packet
    final now = DateTime.now();
    MeshPacket packet = MeshPacket(
      packetId: packetIdBytes,
      packetType: MeshPacketType.chat,
      ttl: MeshPacket.defaultTtl,
      hopCount: 0,
      senderDeviceId: _meshService.localDeviceId,
      senderRole: _meshService.localRole,
      timestamp: now,
      payload: payloadBytes,
    );

    if (_cryptoService != null) {
      try {
        packet = await _cryptoService!.signPacket(packet);
      } catch (e) {
        debugPrint('⚠️ [MESH_CHAT] Signing skipped/failed: $e');
      }
    }

    final signableB64 = base64Encode(packet.getSignableBytes());

    // 6. Construct local domain message
    final hasConnectedPeers = _meshService.peerRegistry.activePeers.isNotEmpty;
    final initialState = hasConnectedPeers ? MeshChatDeliveryState.relayed : MeshChatDeliveryState.queued;

    MeshChatMessage message = MeshChatMessage(
      messageId: messageIdHex,
      senderDeviceId: _meshService.localDeviceId,
      senderUserId: senderUserId ?? _meshService.localDeviceId,
      senderDisplayName: senderDisplayName,
      senderRole: _meshService.localRole,
      channelId: channelId,
      text: trimmedText,
      createdAt: now,
      hopCount: 0,
      ttl: MeshPacket.defaultTtl,
      deliveryState: initialState,
      verificationState: 'TRUSTED',
      isOutgoing: true,
      signature: packet.signature.isNotEmpty ? packet.signature : null,
      imageBase64: imageBase64,
      moderationStatus: moderation.status,
      moderationSeverity: moderation.severity.wireName,
      moderationCategory: moderation.category == 'NONE' ? null : moderation.category,
      flagReason: moderation.reasons.isNotEmpty ? moderation.reasons.join(', ') : null,
      syncStatus: 'PENDING',
      isEncrypted: wireEncrypted,
      replyToMessageId: replyToMessageId,
      replyToPreview: replyToPreview,
      signableBytesBase64: signableB64,
    );

    // 7. Save to local isolated Drift database
    await _repository.saveMessage(message);
    await _repository.markChannelRead(channelId, now.millisecondsSinceEpoch);

    // Auto-record moderation flag if non-critical inappropriate content was flagged
    if (moderation.isFlaggedOrQuarantined) {
      await _repository.saveModerationFlag(MeshModerationFlagRecord(
        flagId: 'auto_$messageIdHex',
        messageId: messageIdHex,
        channelId: channelId,
        reportedUserId: senderUserId ?? _meshService.localDeviceId,
        reportedDeviceId: _meshService.localDeviceId,
        category: moderation.category,
        severity: moderation.severity.wireName,
        reason: moderation.reasons.join(', '),
        messageSnapshot: trimmedText,
        senderSignatureBase64: packet.signature.isNotEmpty ? base64Encode(packet.signature) : null,
        source: 'AUTO_RULE',
        createdAtMs: now.millisecondsSinceEpoch,
      ));
    }

    // 8. Broadcast through CampusMeshService (BLE + Local UDP)
    final broadcastOk = await _meshService.broadcastPacket(packet);
    if (broadcastOk) {
      await _repository.updateDeliveryState(messageIdHex, MeshChatDeliveryState.relayed);
      message = message.copyWith(deliveryState: MeshChatDeliveryState.relayed);
    } else {
      // Keep as queued while waiting for BLE relay or immediate cloud sync
      await _repository.updateDeliveryState(messageIdHex, MeshChatDeliveryState.queued);
      message = message.copyWith(deliveryState: MeshChatDeliveryState.queued);
    }

    // 9. Auto-register direct message channel if applicable
    if (channelId.startsWith('dm:') && resolvedRecipientId != null) {
      await _ensureDirectMessageChannelExists(resolvedRecipientId);
    }

    // 10. Trigger cloud sync (awaiting quick completion for immediate single-tick status)
    if (_syncService != null) {
      try {
        await _syncService!.syncPendingAndPull(activeChannelId: channelId).timeout(const Duration(seconds: 3));
        final updated = await _repository.getMessageById(messageIdHex);
        if (updated != null &&
            (updated.deliveryState == MeshChatDeliveryState.relayed ||
             updated.deliveryState == MeshChatDeliveryState.received ||
             updated.deliveryState == MeshChatDeliveryState.seen)) {
          message = updated;
        }
      } catch (_) {
        unawaited(_syncService?.syncPendingAndPull(activeChannelId: channelId));
      }
    }

    return message;
  }

  /// Retries broadcasting a queued or failed message over BLE/UDP + triggers cloud sync.
  Future<bool> retryMessage(MeshChatMessage message) async {
    final payload = MeshChatPayload(
      channelId: message.channelId,
      text: message.text,
      senderDisplayName: message.senderDisplayName,
      imageBase64: message.imageBase64,
      senderE2eePublicKey: _localE2eePublicKeyB64,
      replyToMessageId: message.replyToMessageId,
      replyToPreview: message.replyToPreview,
    );

    final idBytes = Uint8List.fromList([
      for (int i = 0; i + 1 < message.messageId.length && i < 32; i += 2)
        int.parse(message.messageId.substring(i, i + 2), radix: 16),
    ]);
    final packetId = idBytes.length == 16 ? idBytes : MeshPacket.generatePacketId();

    final packet = MeshPacket(
      packetId: packetId,
      packetType: MeshPacketType.chat,
      ttl: MeshPacket.defaultTtl,
      hopCount: 0,
      senderDeviceId: _meshService.localDeviceId,
      senderRole: _meshService.localRole,
      timestamp: DateTime.now(),
      payload: payload.toBytes(),
    );

    final ok = await _meshService.broadcastPacket(packet);
    await _repository.updateDeliveryState(
      message.messageId,
      ok ? MeshChatDeliveryState.relayed : MeshChatDeliveryState.failed,
    );
    unawaited(_syncService?.syncPendingAndPull());
    return ok;
  }

  /// Reports / flags a message for inappropriate or criminal content (works offline + syncs to MongoDB).
  Future<void> flagMessage({
    required MeshChatMessage message,
    required String category,
    required String reason,
    String severity = 'HIGH',
  }) async {
    final flag = MeshModerationFlagRecord(
      flagId: 'usr_${message.messageId}_${DateTime.now().millisecondsSinceEpoch}',
      messageId: message.messageId,
      channelId: message.channelId,
      reportedUserId: message.senderUserId ?? message.senderDeviceId,
      reportedDeviceId: message.senderDeviceId,
      category: category,
      severity: severity,
      reason: reason,
      messageSnapshot: message.text,
      senderSignatureBase64: message.signature != null && message.signature!.isNotEmpty
          ? base64Encode(message.signature!)
          : null,
      source: 'USER_REPORT',
      createdAtMs: DateTime.now().millisecondsSinceEpoch,
    );

    if (_syncService != null) {
      await _syncService!.submitFlag(flag);
    } else {
      await _repository.saveModerationFlag(flag);
      await _repository.updateModerationVerdict(
        messageId: message.messageId,
        moderationStatus: severity == 'CRITICAL' || severity == 'HIGH' ? 'QUARANTINED' : 'FLAGGED',
        moderationSeverity: severity,
        moderationCategory: category,
        flagReason: reason,
      );
    }
  }

  /// Creates a custom `#channel` locally and in MongoDB.
  Future<MeshChatChannel> createCustomChannel({
    required String name,
    String? description,
  }) async {
    MeshChatChannel? created;
    if (_syncService != null) {
      created = await _syncService!.createChannel(name: name, description: description);
    }
    if (created == null) {
      final cleanSlug = name
          .trim()
          .replaceFirst(RegExp(r'^#+'), '')
          .toLowerCase()
          .replaceAll(RegExp(r'[^a-z0-9\-_]+'), '-')
          .replaceAll(RegExp(r'^-+|-+$'), '');
      if (cleanSlug.length < 2) {
        throw ArgumentError('Channel name must be at least 2 characters');
      }
      created = MeshChatChannel(
        id: 'channel:$cleanSlug',
        name: '#$cleanSlug',
        description: description?.trim().isNotEmpty == true
            ? description!.trim()
            : 'Campus mesh channel #$cleanSlug',
      );
      await _repository.saveChannel(created);
    }
    mergeChannels([created]);
    return created;
  }

  /// Pulls delayed/missed channel messages from MongoDB and refreshes local SQLite.
  Future<int> pullChannelFromCloud(String channelId) async {
    if (_syncService == null) return 0;
    final count = await _syncService!.pullChannelMessages(channelId);
    if (count > 0) {
      await _emitUnreadCounts();
    }
    return count;
  }

  /// Marks [channelId] as read and updates unread count badges.
  Future<void> markChannelRead(String channelId) async {
    await _repository.markChannelRead(channelId);
    await _emitUnreadCounts();

    // If 1-to-1 Direct Message, broadcast seen receipt ACK over mesh & notify cloud
    if (channelId.startsWith('dm:')) {
      try {
        final ackPayload = Uint8List.fromList(utf8.encode(jsonEncode({
          'ackChannel': channelId,
          'ackType': 'seen',
        })));
        final ackPacket = MeshPacket(
          packetId: MeshPacket.generatePacketId(),
          packetType: MeshPacketType.acknowledgement,
          ttl: 3,
          hopCount: 0,
          senderDeviceId: _meshService.localDeviceId,
          senderRole: _meshService.localRole,
          timestamp: DateTime.now(),
          payload: ackPayload,
        );
        unawaited(_meshService.broadcastPacket(ackPacket));
      } catch (_) {}
      unawaited(_syncService?.markChannelRead(channelId));
    }
  }

  /// Translates [text] to Odia or English (defaults to auto detection) via Gemini API.
  Future<ChatMessageTranslation?> translateMessage(String text, {String targetLanguage = 'auto'}) {
    return _syncService?.translateMessage(text, targetLanguage: targetLanguage) ??
        Future.value(null);
  }

  Future<void> _emitUnreadCounts() async {
    if (_unreadCountsController.isClosed) return;
    try {
      final counts = await _repository.getUnreadCounts();
      if (!_unreadCountsController.isClosed) {
        _unreadCountsController.add(counts);
      }
    } catch (_) {}
  }

  Future<void> _handlePeerConnected(MeshPeer peer) async {
    if (peer.deviceId == _meshService.localDeviceId) return;

    // 1. Retry queued/failed outbound messages over BLE/UDP
    try {
      final queued = await _repository.getQueuedOutboundMessages(limit: 10);
      for (final msg in queued) {
        await retryMessage(msg);
      }
    } catch (_) {}

    // 2. Broadcast compact store-and-forward digest + E2EE key announcement
    await _broadcastSyncDigest();
  }

  Future<void> _broadcastSyncDigest() async {
    if (!_meshService.isRunning) return;
    try {
      final digests = <String, int>{};
      for (final ch in _channels) {
        if (!ch.isDirectMessage && ch.id != MeshChatChannel.emergency.id) {
          digests[ch.id] = await _repository.getLatestTimestampForChannel(ch.id);
        }
      }
      final payloadBytes = Uint8List.fromList(utf8.encode(jsonEncode({
        'cid': 'system:sync_digest',
        'txt': 'digest',
        if (_localDisplayName != null && _localDisplayName!.isNotEmpty) 'name': _localDisplayName,
        if (_localE2eePublicKeyB64 != null) 'ekey': _localE2eePublicKeyB64,
        'ch': digests,
      })));

      final digestPacket = MeshPacket(
        packetId: MeshPacket.generatePacketId(),
        packetType: MeshPacketType.chat,
        ttl: 2,
        hopCount: 0,
        senderDeviceId: _meshService.localDeviceId,
        senderRole: _meshService.localRole,
        timestamp: DateTime.now(),
        payload: payloadBytes,
      );
      await _meshService.broadcastPacket(digestPacket);
    } catch (_) {}
  }

  Future<void> _handleSyncDigest(MeshPacket packet, Map<String, dynamic> rawMap) async {
    final ekey = rawMap['ekey']?.toString();
    if (ekey != null && ekey.isNotEmpty) {
      _peerE2eePublicKeys[packet.senderDeviceId] = ekey;
    }

    final digestName = rawMap['name']?.toString();
    if (digestName != null &&
        digestName.trim().isNotEmpty &&
        digestName.trim() != packet.senderDeviceId) {
      _peerDisplayNames[packet.senderDeviceId] = digestName.trim();
    }

    // Throttle digest responses per peer to avoid storms
    final lastReply = _lastDigestReplyByPeer[packet.senderDeviceId];
    if (lastReply != null && DateTime.now().difference(lastReply) < const Duration(seconds: 20)) {
      return;
    }
    _lastDigestReplyByPeer[packet.senderDeviceId] = DateTime.now();

    final peerChannels = rawMap['ch'] as Map<String, dynamic>?;
    if (peerChannels == null) return;

    final batch = <Map<String, dynamic>>[];
    for (final entry in peerChannels.entries) {
      if (entry.key.startsWith('dm:') || entry.key == MeshChatChannel.emergency.id) continue;
      final sinceMs = entry.value is int ? entry.value as int : int.tryParse(entry.value.toString()) ?? 0;
      final missing = await _repository.getRecentMessagesForCatchup(
        channelId: entry.key,
        sinceMs: sinceMs,
        limit: 5,
      );
      for (final m in missing) {
        if (m.imageBase64 != null && m.imageBase64!.isNotEmpty) continue; // Keep catch-up batches lightweight
        batch.add({
          'messageId': m.messageId,
          'senderDeviceId': m.senderDeviceId,
          'senderUserId': m.senderUserId,
          'senderDisplayName': m.senderDisplayName,
          'senderRole': m.senderRole,
          'channelId': m.channelId,
          'text': m.text,
          'createdAt': m.createdAt.millisecondsSinceEpoch,
          'hopCount': m.hopCount + 1,
          'ttl': m.ttl,
          'verificationState': m.verificationState,
          if (m.signature != null && m.signature!.isNotEmpty)
            'signatureBase64': base64Encode(m.signature!),
          if (m.replyToMessageId != null) 'replyToMessageId': m.replyToMessageId,
          if (m.replyToPreview != null) 'replyToPreview': m.replyToPreview,
        });
        if (batch.length >= 10) break;
      }
      if (batch.length >= 10) break;
    }

    if (batch.isEmpty) return;

    final batchPayload = Uint8List.fromList(utf8.encode(jsonEncode({
      'cid': 'system:sync_batch',
      'txt': 'batch',
      if (_localE2eePublicKeyB64 != null) 'ekey': _localE2eePublicKeyB64,
      'msgs': batch,
    })));

    final batchPacket = MeshPacket(
      packetId: MeshPacket.generatePacketId(),
      packetType: MeshPacketType.chat,
      ttl: 2,
      hopCount: 0,
      senderDeviceId: _meshService.localDeviceId,
      senderRole: _meshService.localRole,
      timestamp: DateTime.now(),
      payload: batchPayload,
    );
    unawaited(_meshService.broadcastPacket(batchPacket));
  }

  Future<void> _handleSyncBatch(MeshPacket packet, Map<String, dynamic> rawMap) async {
    final ekey = rawMap['ekey']?.toString();
    if (ekey != null && ekey.isNotEmpty) {
      _peerE2eePublicKeys[packet.senderDeviceId] = ekey;
    }

    final rawMsgs = rawMap['msgs'] as List?;
    if (rawMsgs == null || rawMsgs.isEmpty) return;

    final bundle = await _resolveTrustBundle();
    final toInsert = <MeshChatMessage>[];

    for (final item in rawMsgs) {
      if (item is! Map<String, dynamic>) continue;
      final text = item['text']?.toString() ?? '';
      final mod = MeshModerationFilter.evaluate(text);
      final senderDevId = item['senderDeviceId']?.toString() ?? '';
      var verState = 'UNVERIFIED';
      if (bundle != null) {
        final id = bundle.findIdentity(senderDevId);
        if (id != null && id.status == 'ACTIVE') verState = 'TRUSTED';
        if (id != null && id.status == 'REVOKED') verState = 'REVOKED';
      }

      toInsert.add(MeshChatMessage.fromMap({
        ...item,
        'isOutgoing': senderDevId == _meshService.localDeviceId,
        'deliveryState': MeshChatDeliveryState.received.name,
        'verificationState': verState,
        'moderationStatus': mod.status,
        'moderationSeverity': mod.severity.wireName,
        'moderationCategory': mod.category == 'NONE' ? null : mod.category,
        'flagReason': mod.reasons.isNotEmpty ? mod.reasons.join(', ') : null,
        'syncStatus': 'PENDING',
      }));
    }

    final inserted = await _repository.upsertSyncedMessages(toInsert);
    if (inserted > 0) {
      await _emitUnreadCounts();
    }
  }

  /// Internal handler for verified inbound mesh packets.
  Future<void> _handleIncomingMeshPacket(MeshPacket packet) async {
    // 0. Handle delivery acknowledgements from recipient peers
    if (packet.packetType == MeshPacketType.acknowledgement) {
      try {
        final map = jsonDecode(utf8.decode(packet.payload)) as Map<String, dynamic>;
        final ackMsgId = map['ackMsgId']?.toString();
        final ackChannel = map['ackChannel']?.toString();
        final ackType = map['ackType']?.toString() ?? 'delivered';
        final state = (ackType == 'seen')
            ? MeshChatDeliveryState.seen
            : MeshChatDeliveryState.received;

        if (ackMsgId != null && ackMsgId.isNotEmpty) {
          await _repository.updateDeliveryState(ackMsgId, state);
        } else if (ackChannel != null && ackChannel.startsWith('dm:')) {
          // If channel acknowledged as seen, update all unread outbound messages in that channel
          final msgs = await _repository.getMessagesForChannel(ackChannel);
          for (final m in msgs) {
            if (m.isOutgoing && m.deliveryState != MeshChatDeliveryState.seen) {
              await _repository.updateDeliveryState(m.messageId, state);
            }
          }
        }
      } catch (_) {}
      return;
    }

    if (packet.packetType != MeshPacketType.chat) return;

    try {
      final rawMap = jsonDecode(utf8.decode(packet.payload)) as Map<String, dynamic>;
      final cid = rawMap['cid']?.toString() ?? 'channel:general';

      // System control payloads (heartbeat + store-and-forward catch-up)
      if (cid == 'system:heartbeat') {
        final ekey = rawMap['ekey']?.toString();
        if (ekey != null && ekey.isNotEmpty) {
          _peerE2eePublicKeys[packet.senderDeviceId] = ekey;
        }
        final hbName = rawMap['name']?.toString().trim();
        if (hbName != null && hbName.isNotEmpty && hbName != packet.senderDeviceId) {
          _peerDisplayNames[packet.senderDeviceId] = hbName;
        }
        return;
      }
      if (cid == 'system:sync_digest') {
        await _handleSyncDigest(packet, rawMap);
        return;
      }
      if (cid == 'system:sync_batch') {
        await _handleSyncBatch(packet, rawMap);
        return;
      }

      final payload = MeshChatPayload.fromBytes(packet.payload, packet.packetIdHex);
      if (payload.senderE2eePublicKey != null && payload.senderE2eePublicKey!.isNotEmpty) {
        _peerE2eePublicKeys[packet.senderDeviceId] = payload.senderE2eePublicKey!;
      }
      if (payload.senderDisplayName.isNotEmpty &&
          payload.senderDisplayName != packet.senderDeviceId &&
          !payload.senderDisplayName.startsWith('Peer (')) {
        _peerDisplayNames[packet.senderDeviceId] = payload.senderDisplayName;
      }

      // Deduplication: ignore if message already exists locally
      final alreadyStored = await _repository.hasMessage(payload.messageId);
      if (alreadyStored) {
        return;
      }

      // If DM, ensure this device is the designated recipient or a channel participant
      if (payload.recipientDeviceId != null) {
        final isForLocalDevice = payload.recipientDeviceId == _meshService.localDeviceId;
        final isParticipant = payload.channelId.startsWith('dm:') &&
            payload.channelId.split(':').skip(1).contains(_meshService.localDeviceId);
        if (!isForLocalDevice && !isParticipant) {
          return;
        }
      } else if (payload.channelId.startsWith('dm:')) {
        final isParticipant = payload.channelId.split(':').skip(1).contains(_meshService.localDeviceId);
        if (!isParticipant) {
          return;
        }
      }

      // Decrypt E2EE DM payload if encrypted
      String plainText = payload.text;
      String? plainImage = payload.imageBase64;
      if (payload.isEncrypted &&
          payload.encryptionNonce != null &&
          _localE2eeKeyPair != null) {
        final senderPubB64 = payload.senderE2eePublicKey ?? _peerE2eePublicKeys[packet.senderDeviceId];
        if (senderPubB64 != null && senderPubB64.isNotEmpty) {
          try {
            final sharedKey = await _x25519.sharedSecretKey(
              keyPair: _localE2eeKeyPair!,
              remotePublicKey: SimplePublicKey(base64Decode(senderPubB64), type: KeyPairType.x25519),
            );
            final rawCipher = base64Decode(payload.text);
            if (rawCipher.length > 16) {
              final cipherText = rawCipher.sublist(0, rawCipher.length - 16);
              final mac = Mac(rawCipher.sublist(rawCipher.length - 16));
              final box = SecretBox(cipherText, nonce: base64Decode(payload.encryptionNonce!), mac: mac);
              final clearBytes = await _aead.decrypt(box, secretKey: sharedKey);
              final clearMap = jsonDecode(utf8.decode(clearBytes)) as Map<String, dynamic>;
              plainText = clearMap['txt']?.toString() ?? '';
              plainImage = clearMap['img']?.toString();
            }
          } catch (e) {
            debugPrint('⚠️ [MESH_CHAT] DM decryption failed: $e');
          }
        }
      }

      // 1. Resolve authentic institutional identity from trust bundle (no blind TRUSTED fallback)
      String verificationState = 'UNVERIFIED';
      String resolvedDisplayName = payload.senderDisplayName.isNotEmpty
          ? payload.senderDisplayName
          : 'Peer (${packet.senderDeviceId})';
      String? resolvedUserId;

      final bundle = await _resolveTrustBundle();
      if (bundle != null) {
        final identity = bundle.findIdentity(packet.senderDeviceId) ??
            bundle.identities.cast<PassportTrustIdentity?>().firstWhere(
                  (i) => i?.userId == packet.senderDeviceId,
                  orElse: () => null,
                );

        if (identity != null && identity.status == 'ACTIVE') {
          verificationState = 'TRUSTED';
          resolvedDisplayName = identity.userName ?? identity.userId;
          resolvedUserId = identity.userId;
        } else if (identity != null && identity.status == 'REVOKED') {
          verificationState = 'REVOKED';
          resolvedDisplayName = 'Revoked User (${packet.senderDeviceId})';
        }
      }

      if (resolvedDisplayName.isNotEmpty &&
          !resolvedDisplayName.startsWith('Peer (') &&
          !resolvedDisplayName.startsWith('Revoked User (')) {
        _peerDisplayNames[packet.senderDeviceId] = resolvedDisplayName;
      }

      // 2. Run on-device content moderation on inbound text
      final moderation = MeshModerationFilter.evaluate(plainText);

      final incomingMessage = MeshChatMessage(
        messageId: payload.messageId,
        senderDeviceId: packet.senderDeviceId,
        senderUserId: resolvedUserId,
        senderDisplayName: resolvedDisplayName,
        senderRole: packet.senderRole,
        channelId: payload.channelId,
        text: plainText,
        createdAt: packet.timestamp,
        hopCount: packet.hopCount,
        ttl: packet.ttl,
        deliveryState: MeshChatDeliveryState.received,
        verificationState: verificationState,
        isOutgoing: false,
        signature: packet.signature,
        imageBase64: plainImage,
        moderationStatus: moderation.status,
        moderationSeverity: moderation.severity.wireName,
        moderationCategory: moderation.category == 'NONE' ? null : moderation.category,
        flagReason: moderation.reasons.isNotEmpty ? moderation.reasons.join(', ') : null,
        syncStatus: 'PENDING',
        isEncrypted: payload.isEncrypted,
        replyToMessageId: payload.replyToMessageId,
        replyToPreview: payload.replyToPreview,
        signableBytesBase64: base64Encode(packet.getSignableBytes()),
      );

      // Save to Drift database
      await _repository.saveMessage(incomingMessage);

      // In DMs: an incoming reply from the peer confirms all our prior outgoing messages were seen!
      if (payload.channelId.startsWith('dm:')) {
        await _repository.markPriorOutgoingMessagesSeen(
          payload.channelId,
          incomingMessage.createdAt.millisecondsSinceEpoch,
        );
      }

      // Auto-queue moderation flag if inbound message violates safety rules
      if (moderation.isFlaggedOrQuarantined) {
        await _repository.saveModerationFlag(MeshModerationFlagRecord(
          flagId: 'rx_${payload.messageId}',
          messageId: payload.messageId,
          channelId: payload.channelId,
          reportedUserId: resolvedUserId ?? packet.senderDeviceId,
          reportedDeviceId: packet.senderDeviceId,
          category: moderation.category,
          severity: moderation.severity.wireName,
          reason: moderation.reasons.join(', '),
          messageSnapshot: plainText,
          senderSignatureBase64: packet.signature.isNotEmpty ? base64Encode(packet.signature) : null,
          source: 'AUTO_RULE',
          createdAtMs: DateTime.now().millisecondsSinceEpoch,
        ));
      }

      // Send delivery acknowledgement ONLY for direct messages to prevent group ACK storms
      if (payload.channelId.startsWith('dm:')) {
        try {
          final ackPayload = Uint8List.fromList(utf8.encode(jsonEncode({
            'ackMsgId': payload.messageId,
            'ackChannel': payload.channelId,
            'ackType': 'delivered',
          })));
          final ackPacket = MeshPacket(
            packetId: MeshPacket.generatePacketId(),
            packetType: MeshPacketType.acknowledgement,
            ttl: 3,
            hopCount: 0,
            senderDeviceId: _meshService.localDeviceId,
            senderRole: _meshService.localRole,
            timestamp: DateTime.now(),
            payload: ackPayload,
          );
          unawaited(_meshService.broadcastPacket(ackPacket));
        } catch (_) {}
      }

      // Ensure channel exists locally if direct message or custom channel
      if (payload.channelId.startsWith('dm:')) {
        await _ensureDirectMessageChannelExists(packet.senderDeviceId, resolvedDisplayName);
      } else if (!_channels.any((c) => c.id == payload.channelId)) {
        final slug = payload.channelId.replaceFirst('channel:', '');
        final customCh = MeshChatChannel(
          id: payload.channelId,
          name: '#$slug',
          description: 'Discovered campus mesh channel',
        );
        await _repository.saveChannel(customCh);
        mergeChannels([customCh]);
      }

      await _emitUnreadCounts();

      // Opportunistic BLE-to-Internet bridge: if this device has internet,
      // upload offline peers' signed BLE messages so remote devices catch up too.
      unawaited(_syncService?.syncPendingAndPull());

      // Notify incoming message stream
      if (!_incomingMessageController.isClosed) {
        _incomingMessageController.add(incomingMessage);
      }
    } catch (e) {
      debugPrint('⚠️ [MESH_CHAT] Malformed chat packet payload ignored: $e');
    }
  }

  /// Observes messages for a specific channel.
  Stream<List<MeshChatMessage>> watchChannel(String channelId) {
    return _repository.watchMessagesForChannel(channelId);
  }

  /// Retrieves messages for a specific channel.
  Future<List<MeshChatMessage>> getMessagesForChannel(String channelId, {int limit = 100}) {
    return _repository.getMessagesForChannel(channelId, limit: limit);
  }

  /// Ensures a direct message channel is tracked in the active channel list and persisted in SQLite.
  MeshChatChannel getOrCreateDirectChannel(String remoteDeviceId, [String? remoteDisplayName]) {
    final dmId = MeshChatChannel.computeDirectMessageId(_meshService.localDeviceId, remoteDeviceId);
    for (int i = 0; i < _channels.length; i++) {
      final channel = _channels[i];
      if (channel.id == dmId) {
        if (remoteDisplayName != null &&
            remoteDisplayName.trim().isNotEmpty &&
            remoteDisplayName.trim() != remoteDeviceId &&
            (channel.name == 'DM: $remoteDeviceId' || channel.name == remoteDeviceId || channel.name.startsWith('DM: $remoteDeviceId'))) {
          final updatedChannel = MeshChatChannel(
            id: channel.id,
            name: 'DM: ${remoteDisplayName.trim()}',
            description: channel.description,
            isDirectMessage: true,
            participants: channel.participants,
          );
          _channels[i] = updatedChannel;
          unawaited(_repository.saveChannel(updatedChannel));
          if (!_channelsController.isClosed) {
            _channelsController.add(List.unmodifiable(_channels));
          }
          return updatedChannel;
        }
        return channel;
      }
    }

    final newChannel = MeshChatChannel.directMessage(
      participantA: _meshService.localDeviceId,
      participantB: remoteDeviceId,
      displayName: (remoteDisplayName != null && remoteDisplayName.trim().isNotEmpty && remoteDisplayName.trim() != remoteDeviceId)
          ? 'DM: ${remoteDisplayName.trim()}'
          : 'DM: $remoteDeviceId',
    );

    _channels.add(newChannel);
    unawaited(_repository.saveChannel(newChannel));
    if (!_channelsController.isClosed) {
      _channelsController.add(List.unmodifiable(_channels));
    }
    return newChannel;
  }

  Future<void> _ensureDirectMessageChannelExists(String remoteDeviceId, [String? remoteDisplayName]) async {
    final ch = getOrCreateDirectChannel(remoteDeviceId, remoteDisplayName);
    await _repository.saveChannel(ch);
  }

  Future<PassportTrustBundle?> _resolveTrustBundle() async {
    if (_mockTrustBundle != null) return _mockTrustBundle;
    final tbs = _trustBundleService;
    if (tbs != null) {
      return await tbs.getLocalBundle();
    }
    return null;
  }

  /// Releases stream subscriptions and internal controllers.
  Future<void> dispose() async {
    await _meshSubscription?.cancel();
    await _peerAddedSubscription?.cancel();
    await _syncService?.dispose();
    await _incomingMessageController.close();
    await _channelsController.close();
    await _unreadCountsController.close();
  }
}
