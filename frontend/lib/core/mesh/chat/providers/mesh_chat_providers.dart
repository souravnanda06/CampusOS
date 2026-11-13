import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../mesh_chat_channel.dart';
import '../mesh_chat_delivery_state.dart';
import '../mesh_chat_message.dart';
import '../mesh_chat_service.dart';
import '../mesh_chat_sync_service.dart';
import '../../campus_mesh_manager.dart';
import '../../mesh_peer.dart';

/// Live hardware telemetry & radio status for the CampusOS Hybrid Mesh.
class MeshLiveStatus {
  final int peerCount;
  final bool isBluetoothActive;
  final bool isWifiActive;
  final bool isInternetActive;
  final bool isSyncing;

  const MeshLiveStatus({
    this.peerCount = 1,
    this.isBluetoothActive = true,
    this.isWifiActive = true,
    this.isInternetActive = true,
    this.isSyncing = true,
  });

  MeshLiveStatus copyWith({
    int? peerCount,
    bool? isBluetoothActive,
    bool? isWifiActive,
    bool? isInternetActive,
    bool? isSyncing,
  }) {
    return MeshLiveStatus(
      peerCount: peerCount ?? this.peerCount,
      isBluetoothActive: isBluetoothActive ?? this.isBluetoothActive,
      isWifiActive: isWifiActive ?? this.isWifiActive,
      isInternetActive: isInternetActive ?? this.isInternetActive,
      isSyncing: isSyncing ?? this.isSyncing,
    );
  }
}

/// Discovered nearby peer profile for Direct Messaging and mesh telemetry.
class MeshPeerProfile {
  final String deviceId;
  final String displayName;
  final String role;
  final int rssi;
  final int hopCount;
  final bool isOnline;

  const MeshPeerProfile({
    required this.deviceId,
    required this.displayName,
    required this.role,
    this.rssi = -55,
    this.hopCount = 1,
    this.isOnline = true,
  });
}

/// UI presentation model for a Channel in the Telegram-style channel list.
class ChannelSummary {
  final String id;
  final String name;
  final String lastMessagePreview;
  final String lastMessageTime;
  final bool hasUnread;
  final int unreadCount;
  final String initial;
  final List<Color> avatarGradient;
  final bool isDirectMessage;

  const ChannelSummary({
    required this.id,
    required this.name,
    required this.lastMessagePreview,
    required this.lastMessageTime,
    this.hasUnread = false,
    this.unreadCount = 0,
    required this.initial,
    required this.avatarGradient,
    this.isDirectMessage = false,
  });
}

/// Provider for the underlying real MeshChatService, if initialized.
final meshChatServiceProvider = Provider<MeshChatService?>((ref) {
  try {
    if (CampusMeshManager.instance.isInitialized) {
      return CampusMeshManager.instance.chatService;
    }
  } catch (_) {}
  return null;
});

/// Currently selected active channel identifier.
final activeChannelIdProvider = StateProvider<String>((ref) => 'channel:general');

/// Stream of live mesh telemetry (peer count and active radios).
final meshLiveStatusProvider = StreamProvider<MeshLiveStatus>((ref) {
  final controller = StreamController<MeshLiveStatus>();
  final chatService = ref.watch(meshChatServiceProvider);

  MeshLiveStatus computeStatus() {
    int peers = 0;
    if (chatService != null) {
      final localDevId = chatService.meshService.localDeviceId;
      final localUserId = chatService.localUserId;
      peers = chatService.meshService.peerRegistry.activePeers.where((p) {
        if (p.deviceId == localDevId) return false;
        if (localUserId != null && p.deviceId == localUserId) return false;
        return p.observedRssi != null;
      }).length;
    } else {
      // Headless widget test harness fallback
      peers = 1;
    }

    return MeshLiveStatus(
      peerCount: peers,
      isBluetoothActive: true,
      isWifiActive: true,
      isInternetActive: true,
      isSyncing: true,
    );
  }

  controller.add(computeStatus());

  StreamSubscription? sub;
  if (chatService != null) {
    sub = chatService.meshService.peerRegistry.registryUpdated.listen((_) {
      if (!controller.isClosed) {
        controller.add(computeStatus());
      }
    });
  }

  ref.onDispose(() {
    sub?.cancel();
    controller.close();
  });

  return controller.stream;
});

/// Stream of nearby live mesh peers discovered via Bluetooth / UDP.
final nearbyPeersProvider = StreamProvider<List<MeshPeerProfile>>((ref) {
  final controller = StreamController<List<MeshPeerProfile>>();
  final chatService = ref.watch(meshChatServiceProvider);

  String resolveDisplayName(MeshPeer peer) {
    // 1. Peer registry authenticated/advertised display name
    if (peer.displayName != null &&
        peer.displayName!.trim().isNotEmpty &&
        peer.displayName!.trim() != peer.deviceId &&
        !peer.displayName!.startsWith('Peer (')) {
      return peer.displayName!.trim();
    }

    // 2. ChatService cached historical/incoming message display names
    if (chatService != null) {
      final cached = chatService.getPeerDisplayName(peer.deviceId);
      if (cached != null && cached.isNotEmpty && cached != peer.deviceId) {
        return cached;
      }

      // 3. Existing DM channel name
      for (final ch in chatService.channels) {
        if (ch.isDirectMessage && ch.id.contains(peer.deviceId)) {
          if (ch.name.isNotEmpty && !ch.name.contains(peer.deviceId)) {
            return ch.name;
          }
        }
      }
    }

    // 4. Clean human-readable fallback for long device UUIDs
    if (peer.deviceId.length > 8) {
      return 'Campus Peer (${peer.deviceId.substring(0, 6)})';
    }
    return peer.deviceId;
  }

  List<MeshPeerProfile> computePeers() {
    if (chatService != null) {
      final localDevId = chatService.meshService.localDeviceId;
      final localUserId = chatService.localUserId;
      final active = chatService.meshService.peerRegistry.activePeers.where((p) {
        if (p.deviceId == localDevId) return false;
        if (localUserId != null && p.deviceId == localUserId) return false;
        // Require authentic observed radio contact (RSSI)
        return p.observedRssi != null;
      }).toList();

      if (active.isNotEmpty) {
        return active.map((p) {
          return MeshPeerProfile(
            deviceId: p.deviceId,
            displayName: resolveDisplayName(p),
            role: p.role.toUpperCase(),
            rssi: p.observedRssi!,
            hopCount: p.observedHopCount ?? 1,
            isOnline: p.isActive,
          );
        }).toList();
      }
      // Production with running chat service: NO fake peers!
      return const [];
    }

    // Disconnected / headless widget test harness (chatService == null):
    return const [
      MeshPeerProfile(
        deviceId: 'dev_rahul_01',
        displayName: 'Rahul Sharma',
        role: 'STUDENT',
        rssi: -48,
        hopCount: 1,
        isOnline: true,
      ),
      MeshPeerProfile(
        deviceId: 'dev_ananya_02',
        displayName: 'Ananya Sen',
        role: 'STUDENT',
        rssi: -62,
        hopCount: 1,
        isOnline: true,
      ),
      MeshPeerProfile(
        deviceId: 'dev_warden_01',
        displayName: 'Hostel B Warden',
        role: 'WARDEN',
        rssi: -71,
        hopCount: 2,
        isOnline: true,
      ),
      MeshPeerProfile(
        deviceId: 'dev_prof_verma',
        displayName: 'Dr. P. Verma',
        role: 'FACULTY',
        rssi: -80,
        hopCount: 2,
        isOnline: true,
      ),
    ];
  }

  controller.add(computePeers());

  StreamSubscription? sub1;
  StreamSubscription? sub2;
  if (chatService != null) {
    sub1 = chatService.meshService.peerRegistry.registryUpdated.listen((_) {
      if (!controller.isClosed) {
        controller.add(computePeers());
      }
    });
    sub2 = chatService.meshService.peerUpdates.listen((_) {
      if (!controller.isClosed) {
        controller.add(computePeers());
      }
    });
  }

  ref.onDispose(() {
    sub1?.cancel();
    sub2?.cancel();
    controller.close();
  });

  return controller.stream;
});

/// Default channels definition matching CampusOS specification
final defaultMeshChannels = <MeshChatChannel>[
  const MeshChatChannel(
    id: 'channel:general',
    name: '#general',
    description: 'Campus-wide public discussion channel',
  ),
  const MeshChatChannel(
    id: 'channel:hostel-b',
    name: '#hostel-b',
    description: 'Hostel Block B updates and notices',
  ),
  const MeshChatChannel(
    id: 'channel:study-group',
    name: '#study-group',
    description: 'Peer collaborative study & lab materials',
  ),
  const MeshChatChannel(
    id: 'channel:alerts',
    name: '#alerts',
    description: 'Official institutional priority alerts',
  ),
];

/// StateNotifier managing dynamic channels list (creation, DM, and persistence).
class ChannelsNotifier extends StateNotifier<List<MeshChatChannel>> {
  final MeshChatService? _chatService;
  StreamSubscription<List<MeshChatChannel>>? _channelsSub;

  ChannelsNotifier(this._chatService) : super(_initialChannels(_chatService)) {
    if (_chatService != null) {
      _channelsSub = _chatService!.channelsStream.listen((channels) {
        state = _mergeWithDefaults(channels);
      });
    }
  }

  static List<MeshChatChannel> _initialChannels(MeshChatService? service) {
    if (service != null && service.channels.isNotEmpty) {
      return _mergeWithDefaults(service.channels);
    }
    return List.from(defaultMeshChannels);
  }

  static List<MeshChatChannel> _mergeWithDefaults(List<MeshChatChannel> source) {
    final list = List<MeshChatChannel>.from(source);
    for (final def in defaultMeshChannels) {
      if (!list.any((c) => c.id == def.id || c.name == def.name)) {
        list.add(def);
      }
    }
    return list;
  }

  /// Creates a new broadcast channel and persists it to the mesh network.
  Future<MeshChatChannel> createChannel({
    required String name,
    String? description,
  }) async {
    final cleanSlug = name
        .trim()
        .replaceFirst(RegExp(r'^#+'), '')
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9\-_]+'), '-')
        .replaceAll(RegExp(r'^-+|-+$'), '');
    final channelId = 'channel:$cleanSlug';
    final displayName = '#$cleanSlug';

    if (_chatService != null) {
      try {
        final created = await _chatService!.createCustomChannel(
          name: displayName,
          description: description,
        );
        state = _mergeWithDefaults([...state, created]);
        return created;
      } catch (e) {
        debugPrint('⚠️ [CREATE_CHANNEL] Service creation error: $e');
      }
    }

    final newChannel = MeshChatChannel(
      id: channelId,
      name: displayName,
      description: description ?? 'Campus mesh channel $displayName',
    );

    if (!state.any((c) => c.id == newChannel.id)) {
      state = [...state, newChannel];
    }
    return newChannel;
  }

  /// Opens or creates a 1-to-1 Direct Message conversation with a peer.
  Future<MeshChatChannel> openDirectMessageWithPeer({
    required String peerDeviceId,
    String? peerDisplayName,
  }) async {
    if (_chatService != null) {
      final dmChannel = _chatService!.getOrCreateDirectChannel(
        peerDeviceId,
        peerDisplayName,
      );
      if (!state.any((c) => c.id == dmChannel.id)) {
        state = [...state, dmChannel];
      }
      return dmChannel;
    }

    final dmChannel = MeshChatChannel.directMessage(
      participantA: 'local_user',
      participantB: peerDeviceId,
      displayName: (peerDisplayName != null && peerDisplayName.isNotEmpty)
          ? 'DM: $peerDisplayName'
          : 'DM: $peerDeviceId',
    );
    if (!state.any((c) => c.id == dmChannel.id)) {
      state = [...state, dmChannel];
    }
    return dmChannel;
  }

  @override
  void dispose() {
    _channelsSub?.cancel();
    super.dispose();
  }
}

/// Provider exposing the reactive, editable list of channels.
final channelsListProvider =
    StateNotifierProvider<ChannelsNotifier, List<MeshChatChannel>>((ref) {
  final chatService = ref.watch(meshChatServiceProvider);
  return ChannelsNotifier(chatService);
});

/// Active channel object derived from activeChannelIdProvider.
final activeChannelProvider = Provider<MeshChatChannel>((ref) {
  final activeId = ref.watch(activeChannelIdProvider);
  final channels = ref.watch(channelsListProvider);
  return channels.firstWhere(
    (c) => c.id == activeId,
    orElse: () => defaultMeshChannels.first,
  );
});

/// Reactive store for local, mesh radio, and mock messages per channel.
class ChannelMessagesNotifier extends StateNotifier<Map<String, List<MeshChatMessage>>> {
  final MeshChatService? _chatService;
  StreamSubscription<MeshChatMessage>? _incomingSub;
  StreamSubscription<String>? _channelChangedSub;

  ChannelMessagesNotifier(this._chatService)
      : super(_chatService == null ? _buildInitialSeedMessages() : const {}) {
    _initListener();
    _loadHistoricalMessages();
  }

  static Map<String, List<MeshChatMessage>> _buildInitialSeedMessages() {
    final now = DateTime.now();
    return {
      'channel:general': [
        MeshChatMessage(
          messageId: 'seed_gen_01',
          senderDeviceId: 'dev_rahul_01',
          senderDisplayName: 'Rahul Sharma',
          senderRole: 'STUDENT',
          channelId: 'channel:general',
          text: 'Does anyone have the DBMS lab manual for batch B?',
          createdAt: now.subtract(const Duration(minutes: 24)),
          hopCount: 2,
          deliveryState: MeshChatDeliveryState.relayed,
          verificationState: 'TRUSTED',
        ),
        MeshChatMessage(
          messageId: 'seed_gen_02',
          senderDeviceId: 'dev_rahul_01',
          senderDisplayName: 'Rahul Sharma',
          senderRole: 'STUDENT',
          channelId: 'channel:general',
          text: 'Need to verify exercise 4 queries before 5 PM.',
          createdAt: now.subtract(const Duration(minutes: 23)),
          hopCount: 2,
          deliveryState: MeshChatDeliveryState.relayed,
          verificationState: 'TRUSTED',
        ),
        MeshChatMessage(
          messageId: 'seed_gen_03',
          senderDeviceId: 'dev_ananya_02',
          senderDisplayName: 'Ananya Sen',
          senderRole: 'STUDENT',
          channelId: 'channel:general',
          text: 'Check the mesh airdrop docs, I sent the PDF via BLE relay!',
          createdAt: now.subtract(const Duration(minutes: 18)),
          hopCount: 1,
          deliveryState: MeshChatDeliveryState.received,
          verificationState: 'TRUSTED',
        ),
        MeshChatMessage(
          messageId: 'seed_gen_flagged',
          senderDeviceId: 'dev_spammer_99',
          senderDisplayName: 'Unknown Guest',
          senderRole: 'STUDENT',
          channelId: 'channel:general',
          text: 'Claim free tokens at http://unverified-mesh.internal! Click immediately!',
          createdAt: now.subtract(const Duration(minutes: 10)),
          hopCount: 3,
          deliveryState: MeshChatDeliveryState.relayed,
          verificationState: 'UNVERIFIED',
          moderationStatus: 'FLAGGED',
          moderationSeverity: 'MODERATE',
          flagReason: 'Abusive language or unverified promotional spam detected',
        ),
        MeshChatMessage(
          messageId: 'seed_gen_04',
          senderDeviceId: 'local_user',
          senderDisplayName: 'You',
          senderRole: 'STUDENT',
          channelId: 'channel:general',
          text: 'gui',
          createdAt: DateTime(now.year, now.month, now.day, 17, 24),
          hopCount: 0,
          isOutgoing: true,
          deliveryState: MeshChatDeliveryState.relayed,
          verificationState: 'TRUSTED',
        ),
      ],
      'channel:hostel-b': [],
      'channel:study-group': [],
      'channel:alerts': [],
    };
  }

  Future<void> _loadHistoricalMessages() async {
    if (_chatService == null) return;
    try {
      final channels = _chatService!.channels;
      final allToLoad = <MeshChatMessage>[];
      for (final ch in channels) {
        final messages = await _chatService!.repository.getMessagesForChannel(ch.id);
        allToLoad.addAll(messages);
      }
      if (allToLoad.isNotEmpty) {
        addMessages(allToLoad);
      }
    } catch (e) {
      debugPrint('⚠️ [MESSAGES_HISTORY] Error reading SQLite messages: $e');
    }
  }

  void _initListener() {
    if (_chatService != null) {
      _incomingSub = _chatService!.incomingMessages.listen((incoming) {
        addMessage(incoming);
      });
      _channelChangedSub = _chatService!.repository.channelChangedStream.listen((channelId) async {
        try {
          final msgs = await _chatService!.repository.getMessagesForChannel(channelId);
          final updatedState = Map<String, List<MeshChatMessage>>.from(state);
          updatedState[channelId] = msgs;
          state = updatedState;
        } catch (_) {}
      });
      _chatService!.syncService?.onMessagesPulled = (pulled) {
        addMessages(pulled);
      };
    }
  }

  @override
  void dispose() {
    _incomingSub?.cancel();
    _channelChangedSub?.cancel();
    super.dispose();
  }

  void addMessage(MeshChatMessage message) {
    addMessages([message]);
  }

  void addMessages(List<MeshChatMessage> newMessages) {
    if (newMessages.isEmpty) return;

    final updatedState = Map<String, List<MeshChatMessage>>.from(state);
    bool changed = false;

    for (final message in newMessages) {
      final channelId = message.channelId;
      final currentList = updatedState[channelId] ?? [];

      // 1. Deduplicate by exact message ID
      final existingIndex = currentList.indexWhere((m) => m.messageId == message.messageId);
      if (existingIndex != -1) {
        if (currentList[existingIndex].deliveryState != message.deliveryState) {
          final listCopy = List<MeshChatMessage>.from(currentList);
          listCopy[existingIndex] = message;
          updatedState[channelId] = listCopy;
          changed = true;
        }
        continue;
      }

      // 2. Reconcile optimistic outgoing message (replace temp 'out_' with genuine wire packet)
      final tempIndex = currentList.indexWhere(
        (m) =>
            m.isOutgoing &&
            m.messageId.startsWith('out_') &&
            m.text == message.text &&
            m.channelId == message.channelId &&
            m.createdAt.difference(message.createdAt).abs() < const Duration(seconds: 30),
      );
      if (tempIndex != -1) {
        final listCopy = List<MeshChatMessage>.from(currentList);
        listCopy[tempIndex] = message;
        updatedState[channelId] = listCopy;
        changed = true;
        continue;
      }

      // 3. New message: append and keep sorted by timestamp
      final listCopy = List<MeshChatMessage>.from(currentList)..add(message);
      listCopy.sort((a, b) => a.createdAt.compareTo(b.createdAt));
      updatedState[channelId] = listCopy;
      changed = true;
    }

    if (changed) {
      state = updatedState;
    }
  }

  Future<void> appendOutgoingMessage({
    required String channelId,
    required String text,
    String? imageBase64,
  }) async {
    final now = DateTime.now();
    final tempId = 'out_${now.millisecondsSinceEpoch}';
    final senderName = _chatService?.localDisplayName ?? 'You';
    final senderRole = _chatService?.meshService.localRole ?? 'STUDENT';
    final senderDeviceId = _chatService?.meshService.localDeviceId ?? 'local_user';

    final tempMsg = MeshChatMessage(
      messageId: tempId,
      senderDeviceId: senderDeviceId,
      senderDisplayName: senderName,
      senderRole: senderRole,
      channelId: channelId,
      text: text,
      createdAt: now,
      hopCount: 0,
      isOutgoing: true,
      deliveryState: MeshChatDeliveryState.queued,
      verificationState: 'TRUSTED',
      imageBase64: imageBase64,
    );

    addMessage(tempMsg);

    // If real chat service is active, dispatch over BLE / UDP / Cloud
    if (_chatService != null) {
      try {
        final confirmed = await _chatService!.sendMessage(
          channelId: channelId,
          text: text,
          imageBase64: imageBase64,
        );

        // Replace temp optimistic message with confirmed packet
        final currentList = state[channelId] ?? [];
        final idx = currentList.indexWhere((m) => m.messageId == tempId);
        if (idx != -1) {
          final listCopy = List<MeshChatMessage>.from(currentList);
          listCopy[idx] = confirmed;
          state = {
            ...state,
            channelId: listCopy,
          };
        }
      } catch (e) {
        debugPrint('⚠️ [MESH_SEND] Error sending message: $e');
        final currentList = state[channelId] ?? [];
        final idx = currentList.indexWhere((m) => m.messageId == tempId);
        if (idx != -1) {
          final listCopy = List<MeshChatMessage>.from(currentList);
          listCopy[idx] = currentList[idx].copyWith(deliveryState: MeshChatDeliveryState.failed);
          state = {
            ...state,
            channelId: listCopy,
          };
        }
      }
    }
  }
}

/// Provider managing the message lists for all channels.
final channelMessagesProvider =
    StateNotifierProvider<ChannelMessagesNotifier, Map<String, List<MeshChatMessage>>>((ref) {
  final chatService = ref.watch(meshChatServiceProvider);
  return ChannelMessagesNotifier(chatService);
});

/// Messages for a specific channel ID (chronological order: oldest to newest).
final messagesByChannelProvider = Provider.family<List<MeshChatMessage>, String>((ref, channelId) {
  final allMessagesMap = ref.watch(channelMessagesProvider);
  return allMessagesMap[channelId] ?? [];
});

/// Per-channel draft text stored in Riverpod state.
final draftTextProvider = StateProvider.family<String, String>((ref, channelId) => '');

/// Channel summaries derived dynamically from each channel's latest messages.
final channelSummariesProvider = Provider<List<ChannelSummary>>((ref) {
  final channels = ref.watch(channelsListProvider);
  final allMessages = ref.watch(channelMessagesProvider);

  return channels.map((c) {
    final messages = allMessages[c.id] ?? [];
    String lastPreview = 'No messages yet';
    String lastTime = '';

    if (messages.isNotEmpty) {
      final lastMsg = messages.last;
      final prefix = lastMsg.isOutgoing ? 'You: ' : '';
      lastPreview = '$prefix${lastMsg.text}';
      lastTime = DateFormat('HH:mm').format(lastMsg.createdAt);
    }

    final (initial, gradient) = _resolveChannelVisuals(c.name);

    return ChannelSummary(
      id: c.id,
      name: c.name,
      lastMessagePreview: lastPreview,
      lastMessageTime: lastTime,
      hasUnread: false,
      initial: initial,
      avatarGradient: gradient,
      isDirectMessage: c.isDirectMessage,
    );
  }).toList();
});

/// Helper resolving avatar initials and color gradients matching Apple Telegram design.
(String, List<Color>) _resolveChannelVisuals(String channelName) {
  String clean = channelName.trim();
  if (clean.startsWith('DM:')) {
    clean = clean.substring(3).trim();
  }
  clean = clean.replaceAll('#', '').trim();
  final initial = clean.isNotEmpty ? clean[0].toUpperCase() : '#';

  switch (clean.toLowerCase()) {
    case 'general':
      return ('G', const [Color(0xFF6B58F6), Color(0xFF8B76FF)]);
    case 'hostel-b':
      return ('H', const [Color(0xFFFF7063), Color(0xFFFF957B)]);
    case 'study-group':
      return ('S', const [Color(0xFF1EAEBA), Color(0xFF47D1DF)]);
    case 'alerts':
    case 'emergency':
      return ('A', const [Color(0xFFE58B24), Color(0xFFF9B854)]);
    default:
      // Deterministic palette generation for custom channels and peer DMs
      final palettes = [
        const [Color(0xFF6366F1), Color(0xFF8B5CF6)],
        const [Color(0xFF0EA5E9), Color(0xFF06B6D4)],
        const [Color(0xFF10B981), Color(0xFF059669)],
        const [Color(0xFFF59E0B), Color(0xFFD97706)],
        const [Color(0xFFEC4899), Color(0xFFD946EF)],
        const [Color(0xFF8B5CF6), Color(0xFFC084FC)],
        const [Color(0xFF14B8A6), Color(0xFF2DD4BF)],
      ];
      final colors = palettes[channelName.hashCode.abs() % palettes.length];
      return (initial, colors);
  }
}

/// Set of flagged message IDs that the user has chosen to reveal via the amber card toggle.
class RevealedFlaggedNotifier extends StateNotifier<Set<String>> {
  RevealedFlaggedNotifier() : super({});

  void toggle(String messageId) {
    if (state.contains(messageId)) {
      state = Set.from(state)..remove(messageId);
    } else {
      state = Set.from(state)..add(messageId);
    }
  }

  bool isRevealed(String messageId) => state.contains(messageId);
}

final revealedFlaggedMessagesProvider =
    StateNotifierProvider<RevealedFlaggedNotifier, Set<String>>((ref) {
  return RevealedFlaggedNotifier();
});

/// In-memory cache for Gemini-translated messages: messageId -> ChatMessageTranslation
final messageTranslationsProvider =
    StateNotifierProvider<MessageTranslationsNotifier, Map<String, ChatMessageTranslation>>((ref) {
  return MessageTranslationsNotifier();
});

class MessageTranslationsNotifier extends StateNotifier<Map<String, ChatMessageTranslation>> {
  MessageTranslationsNotifier() : super(const {});

  void setTranslation(String messageId, ChatMessageTranslation translation) {
    state = {...state, messageId: translation};
  }

  void removeTranslation(String messageId) {
    final copy = Map<String, ChatMessageTranslation>.from(state);
    copy.remove(messageId);
    state = copy;
  }
}
