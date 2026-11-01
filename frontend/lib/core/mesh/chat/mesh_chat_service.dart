import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';

import '../../../student/models/passport_trust_bundle_model.dart';
import '../../../student/services/passport_trust_bundle_service.dart';
import '../campus_mesh_service.dart';
import '../mesh_crypto.dart';
import '../mesh_packet.dart';
import 'mesh_chat_channel.dart';
import 'mesh_chat_delivery_state.dart';
import 'mesh_chat_message.dart';
import 'mesh_chat_repository.dart';

/// Application service coordinating offline P2P mesh chat communications.
///
/// Built on top of [CampusMeshService] transport layer with:
/// - Institutional trust-bundle identity resolution.
/// - Automatic Ed25519 message signing.
/// - Drift local SQLite offline persistence.
/// - Broadcast channel and deterministic 1-to-1 direct messaging.
class MeshChatService {
  final CampusMeshService _meshService;
  final MeshChatRepository _repository;
  final MeshCryptoService? _cryptoService;
  final PassportTrustBundleService? _trustBundleService;
  final PassportTrustBundle? _mockTrustBundle;
  final String? _localDisplayName;

  StreamSubscription<MeshPacket>? _meshSubscription;
  final List<MeshChatChannel> _channels = List.from(MeshChatChannel.defaultChannels);

  final StreamController<MeshChatMessage> _incomingMessageController =
      StreamController<MeshChatMessage>.broadcast();

  final StreamController<List<MeshChatChannel>> _channelsController =
      StreamController<List<MeshChatChannel>>.broadcast();

  MeshChatService({
    required CampusMeshService meshService,
    required MeshChatRepository repository,
    MeshCryptoService? cryptoService,
    PassportTrustBundleService? trustBundleService,
    PassportTrustBundle? mockTrustBundle,
    String? localDisplayName,
  })  : _meshService = meshService,
        _repository = repository,
        _cryptoService = cryptoService ?? meshService.cryptoService,
        _trustBundleService = trustBundleService,
        _mockTrustBundle = mockTrustBundle,
        _localDisplayName = localDisplayName {
    _meshSubscription = _meshService.receivedPackets.listen(_handleIncomingMeshPacket);
  }

  /// The list of currently active channels.
  List<MeshChatChannel> get channels => List.unmodifiable(_channels);

  /// Reactive stream of available channels.
  Stream<List<MeshChatChannel>> get channelsStream => _channelsController.stream;

  /// Stream of newly received incoming chat messages.
  Stream<MeshChatMessage> get incomingMessages => _incomingMessageController.stream;

  /// Underlying repository instance.
  MeshChatRepository get repository => _repository;

  /// Underlying mesh network service.
  CampusMeshService get meshService => _meshService;

  /// Cryptographic service if configured.
  MeshCryptoService? get cryptoService => _cryptoService;

  /// Initializes local repository and subscribes to inbound mesh packets.
  Future<void> initialize() async {
    await _repository.initialize();

    await _meshSubscription?.cancel();
    _meshSubscription = _meshService.receivedPackets.listen(_handleIncomingMeshPacket);
  }

  /// Sends a chat message over the offline BLE mesh network.
  ///
  /// Broadcasts to the target channel (or direct message conversation) without requiring
  /// internet connectivity, cellular networks, or centralized backend infrastructure.
  Future<MeshChatMessage> sendMessage({
    required String channelId,
    required String text,
    String? recipientDeviceId,
    String? imageBase64,
  }) async {
    if (text.trim().isEmpty && (imageBase64 == null || imageBase64.isEmpty)) {
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

    // 2. Build compact transport payload (messageId is carried by MeshPacket header)
    final payload = MeshChatPayload(
      channelId: channelId,
      text: text.trim(),
      senderDisplayName: senderDisplayName,
      recipientDeviceId: resolvedRecipientId,
      imageBase64: imageBase64,
    );
    final payloadBytes = payload.toBytes();

    // 3. Construct local domain message
    final now = DateTime.now();
    final message = MeshChatMessage(
      messageId: messageIdHex,
      senderDeviceId: _meshService.localDeviceId,
      senderUserId: senderUserId,
      senderDisplayName: senderDisplayName,
      senderRole: _meshService.localRole,
      channelId: channelId,
      text: text.trim(),
      createdAt: now,
      hopCount: 0,
      ttl: MeshPacket.defaultTtl,
      deliveryState: MeshChatDeliveryState.relayed,
      verificationState: 'TRUSTED',
      isOutgoing: true,
      imageBase64: imageBase64,
    );

    // 4. Save to local isolated Drift database
    await _repository.saveMessage(message);

    // 5. Construct transport packet
    final packet = MeshPacket(
      packetId: packetIdBytes,
      packetType: MeshPacketType.chat,
      ttl: MeshPacket.defaultTtl,
      hopCount: 0,
      senderDeviceId: _meshService.localDeviceId,
      senderRole: _meshService.localRole,
      timestamp: now,
      payload: payloadBytes,
    );

    // 6. Broadcast through CampusMeshService (automatically signed via Ed25519 identity key)
    final broadcastOk = await _meshService.broadcastPacket(packet);
    if (!broadcastOk) {
      await _repository.updateDeliveryState(messageIdHex, MeshChatDeliveryState.failed);
    }

    // 7. Auto-register direct message channel if applicable
    if (channelId.startsWith('dm:')) {
      if (resolvedRecipientId != null) {
        _ensureDirectMessageChannelExists(resolvedRecipientId);
      }
    }

    return message;
  }

  /// Internal handler for verified inbound mesh packets.
  Future<void> _handleIncomingMeshPacket(MeshPacket packet) async {
    // 0. Handle delivery acknowledgements from recipient peers
    if (packet.packetType == MeshPacketType.acknowledgement) {
      try {
        final map = jsonDecode(utf8.decode(packet.payload)) as Map<String, dynamic>;
        final ackMsgId = map['ackMsgId']?.toString();
        if (ackMsgId != null && ackMsgId.isNotEmpty) {
          await _repository.updateDeliveryState(ackMsgId, MeshChatDeliveryState.received);
        }
      } catch (_) {}
      return;
    }

    if (packet.packetType != MeshPacketType.chat) return;

    try {
      final payload = MeshChatPayload.fromBytes(packet.payload, packet.packetIdHex);

      // Heartbeat used exclusively for BitChat-style presence discovery
      if (payload.channelId == 'system:heartbeat') {
        return;
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

      // 1. Resolve authentic institutional identity from trust bundle or valid signature
      String verificationState = packet.signature.length == 64 ? 'TRUSTED' : 'UNVERIFIED';
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

      final incomingMessage = MeshChatMessage(
        messageId: payload.messageId,
        senderDeviceId: packet.senderDeviceId,
        senderUserId: resolvedUserId,
        senderDisplayName: resolvedDisplayName,
        senderRole: packet.senderRole,
        channelId: payload.channelId,
        text: payload.text,
        createdAt: packet.timestamp,
        hopCount: packet.hopCount,
        ttl: packet.ttl,
        deliveryState: MeshChatDeliveryState.received,
        verificationState: verificationState,
        isOutgoing: false,
        signature: packet.signature,
        imageBase64: payload.imageBase64,
      );

      // Save to Drift database
      await _repository.saveMessage(incomingMessage);

      // Send delivery acknowledgement back over mesh so sender transitions from Broadcasted to Delivered
      try {
        final ackPayload = Uint8List.fromList(utf8.encode(jsonEncode({
          'ackMsgId': payload.messageId,
          'ackChannel': payload.channelId,
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

      // Ensure channel exists locally if direct message
      if (payload.channelId.startsWith('dm:')) {
        _ensureDirectMessageChannelExists(packet.senderDeviceId, resolvedDisplayName);
      }

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

  /// Ensures a direct message channel is tracked in the active channel list.
  MeshChatChannel getOrCreateDirectChannel(String remoteDeviceId, [String? remoteDisplayName]) {
    final dmId = MeshChatChannel.computeDirectMessageId(_meshService.localDeviceId, remoteDeviceId);
    for (final channel in _channels) {
      if (channel.id == dmId) return channel;
    }

    final newChannel = MeshChatChannel.directMessage(
      participantA: _meshService.localDeviceId,
      participantB: remoteDeviceId,
      displayName: remoteDisplayName != null ? 'DM: $remoteDisplayName' : 'DM: $remoteDeviceId',
    );

    _channels.add(newChannel);
    if (!_channelsController.isClosed) {
      _channelsController.add(List.unmodifiable(_channels));
    }
    return newChannel;
  }

  void _ensureDirectMessageChannelExists(String remoteDeviceId, [String? remoteDisplayName]) {
    getOrCreateDirectChannel(remoteDeviceId, remoteDisplayName);
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
    await _incomingMessageController.close();
    await _channelsController.close();
  }
}
