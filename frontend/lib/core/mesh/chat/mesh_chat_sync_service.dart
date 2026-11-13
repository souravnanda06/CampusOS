import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';

import '../../network/api_client.dart';
import '../../network/connectivity_service.dart';
import '../../network/connectivity_state.dart';
import 'mesh_chat_channel.dart';
import 'mesh_chat_delivery_state.dart';
import 'mesh_chat_message.dart';
import 'mesh_chat_repository.dart';

enum MeshCloudSyncPhase {
  idle,
  syncing,
  synced,
  offline,
  error,
}

class ChatMessageTranslation {
  final String text;
  final String targetLanguage;
  final String targetLanguageName;

  const ChatMessageTranslation({
    required this.text,
    required this.targetLanguage,
    required this.targetLanguageName,
  });
}

class MeshCloudSyncState {
  final MeshCloudSyncPhase phase;
  final int pendingCount;
  final DateTime? lastSyncedAt;
  final String? message;

  const MeshCloudSyncState({
    required this.phase,
    this.pendingCount = 0,
    this.lastSyncedAt,
    this.message,
  });

  static const MeshCloudSyncState initial = MeshCloudSyncState(
    phase: MeshCloudSyncPhase.idle,
  );
}

/// Coordinates MongoDB cloud synchronization for CampusOS Mesh Chat via the Flask API.
///
/// Enables asynchronous delayed delivery:
/// - Device A posts a message (saved locally to SQLite + broadcast over BLE/UDP + synced to MongoDB when online).
/// - Device B opens the channel later (even hours later across campus) and pulls missed messages from MongoDB.
/// - Also syncs offline moderation flags and custom channels.
class MeshChatSyncService {
  final MeshChatRepository _repository;
  final ApiClient _apiClient;
  final ConnectivityService? _connectivityService;
  final String _localDeviceId;
  final Future<void> Function(List<MeshChatChannel> channels)? onChannelsDiscovered;
  void Function(List<MeshChatMessage> messages)? onMessagesPulled;

  final ValueNotifier<MeshCloudSyncState> syncState =
      ValueNotifier<MeshCloudSyncState>(MeshCloudSyncState.initial);

  StreamSubscription<NetworkStatus>? _connectivitySub;
  Timer? _periodicSyncTimer;
  Completer<void>? _activeSyncCompleter;
  bool _isSyncing = false;
  bool _isDisposed = false;

  void _updateSyncState(MeshCloudSyncState newState) {
    if (_isDisposed) return;
    try {
      syncState.value = newState;
    } catch (_) {}
  }

  MeshChatSyncService({
    required MeshChatRepository repository,
    required String localDeviceId,
    ApiClient? apiClient,
    ConnectivityService? connectivityService,
    this.onChannelsDiscovered,
    this.onMessagesPulled,
  })  : _repository = repository,
        _localDeviceId = localDeviceId,
        _apiClient = apiClient ?? ApiClient.instance,
        _connectivityService = connectivityService {
    if (_connectivityService != null) {
      _connectivitySub = _connectivityService!.onStatusChanged.listen((status) {
        if (status.isOnline) {
          unawaited(syncPendingAndPull());
        } else {
          unawaited(_refreshPendingState(phase: MeshCloudSyncPhase.offline));
        }
      });
    }

    // Start background sync polling when internet is available
    startPeriodicSync();
  }

  /// Starts background cloud polling at [interval] (defaults to 10 seconds).
  void startPeriodicSync({Duration interval = const Duration(seconds: 10)}) {
    _periodicSyncTimer?.cancel();
    _periodicSyncTimer = Timer.periodic(interval, (_) {
      if (!_isDisposed && !_isSyncing) {
        unawaited(syncPendingAndPull());
      }
    });
  }

  Future<void> _refreshPendingState({MeshCloudSyncPhase? phase, String? message}) async {
    try {
      final pendingMsgs = await _repository.getPendingSyncMessages(limit: 100);
      final pendingFlags = await _repository.getPendingModerationFlags(limit: 100);
      final count = pendingMsgs.length + pendingFlags.length;
      _updateSyncState(MeshCloudSyncState(
        phase: phase ?? syncState.value.phase,
        pendingCount: count,
        lastSyncedAt: syncState.value.lastSyncedAt,
        message: message,
      ));
    } catch (_) {}
  }

  /// Pushes pending messages & moderation flags to MongoDB, then refreshes channels.
  Future<void> syncPendingAndPull({String? activeChannelId}) async {
    if (_isDisposed) return;
    if (_isSyncing) {
      await _activeSyncCompleter?.future;
      return;
    }
    _isSyncing = true;
    _activeSyncCompleter = Completer<void>();

    try {
      final pendingMsgs = await _repository.getPendingSyncMessages(limit: 50);
      final pendingFlags = await _repository.getPendingModerationFlags(limit: 50);
      _updateSyncState(MeshCloudSyncState(
        phase: MeshCloudSyncPhase.syncing,
        pendingCount: pendingMsgs.length + pendingFlags.length,
        lastSyncedAt: syncState.value.lastSyncedAt,
      ));

      if (pendingMsgs.isNotEmpty) {
        final payload = pendingMsgs.map((m) => <String, dynamic>{
          'messageId': m.messageId,
          'channelId': m.channelId,
          'senderDeviceId': m.senderDeviceId,
          if (m.senderUserId != null) 'senderUserId': m.senderUserId,
          'senderDisplayName': m.senderDisplayName,
          'senderRole': m.senderRole,
          'text': m.text,
          if (m.imageBase64 != null) 'imageBase64': m.imageBase64,
          'isEncrypted': m.isEncrypted,
          if (m.replyToMessageId != null) 'replyToMessageId': m.replyToMessageId,
          'createdAt': m.createdAt.millisecondsSinceEpoch,
          'hopCount': m.hopCount,
          'ttl': m.ttl,
          'verificationState': m.verificationState,
          if (m.signature != null && m.signature!.isNotEmpty)
            'signatureBase64': base64Encode(m.signature!),
          if (m.signableBytesBase64 != null)
            'signableBytesBase64': m.signableBytesBase64,
        }).toList();

        final res = await _apiClient.post(
          '/mesh-chat/sync',
          body: {'messages': payload},
        );
        if (res.statusCode >= 200 && res.statusCode < 300) {
          final decoded = jsonDecode(res.body) as Map<String, dynamic>;
          final syncedIds = (decoded['syncedIds'] as List?)
                  ?.map((e) => e.toString())
                  .toList() ??
              const <String>[];
          final verdicts = decoded['verdicts'] as Map<String, dynamic>?;
          await _repository.markMessagesSynced(syncedIds, verdicts: verdicts);

          final rejectedList = (decoded['rejected'] as List?)
                  ?.whereType<Map<String, dynamic>>()
                  .map((e) => e['messageId']?.toString())
                  .whereType<String>()
                  .toList() ??
              const <String>[];
          if (rejectedList.isNotEmpty) {
            await _repository.markMessagesRejected(rejectedList);
          }
        } else {
          debugPrint('⚠️ [MESH_SYNC] Sync endpoint error ${res.statusCode}: ${res.body}');
          if (res.statusCode == 401) {
            await _refreshPendingState(
              phase: MeshCloudSyncPhase.error,
              message: 'Authentication required to sync with cloud. Please log in.',
            );
            return;
          }
        }
      }

      if (pendingFlags.isNotEmpty) {
        final syncedFlagIds = <String>[];
        for (final flag in pendingFlags) {
          final res = await _apiClient.post(
            '/mesh-chat/flags',
            body: flag.toApiMap(),
          );
          if (res.statusCode >= 200 && res.statusCode < 300) {
            syncedFlagIds.add(flag.flagId);
          }
        }
        await _repository.markFlagsSynced(syncedFlagIds);
      }

      final discovered = await fetchChannels();

      if (activeChannelId != null && activeChannelId.isNotEmpty) {
        await pullChannelMessages(activeChannelId);
      }

      // Warm and catch-up public channels and direct message channels
      for (final ch in discovered) {
        if (ch.id != MeshChatChannel.emergency.id && ch.id != activeChannelId) {
          await pullChannelMessages(ch.id);
        }
      }

      final remainingMsgs = await _repository.getPendingSyncMessages(limit: 100);
      final remainingFlags = await _repository.getPendingModerationFlags(limit: 100);
      _updateSyncState(MeshCloudSyncState(
        phase: MeshCloudSyncPhase.synced,
        pendingCount: remainingMsgs.length + remainingFlags.length,
        lastSyncedAt: DateTime.now(),
      ));
    } catch (e) {
      debugPrint('ℹ️ [MESH_SYNC] Cloud sync deferred (offline or server unreachable): $e');
      await _refreshPendingState(
        phase: MeshCloudSyncPhase.offline,
        message: 'Queued offline — will sync automatically when connected',
      );
    } finally {
      _isSyncing = false;
      if (_activeSyncCompleter != null && !_activeSyncCompleter!.isCompleted) {
        _activeSyncCompleter!.complete();
      }
    }
  }

  /// Pulls missed messages for [channelId] from MongoDB newer than our local latest timestamp.
  Future<int> pullChannelMessages(String channelId) async {
    if (channelId.startsWith('system:')) return 0;
    try {
      final isDm = channelId.startsWith('dm:');
      // For DMs, pull without since constraint to refresh delivery states (seen/blue ticks)
      final latestTs = isDm ? 0 : await _repository.getLatestTimestampForChannel(channelId);
      final res = await _apiClient.get(
        '/mesh-chat/channels/${Uri.encodeComponent(channelId)}/messages',
        queryParameters: {
          'since': latestTs.toString(),
          'limit': '100',
        },
      );
      if (res.statusCode < 200 || res.statusCode >= 300) return 0;

      final decoded = jsonDecode(res.body) as Map<String, dynamic>;
      final rawList = decoded['messages'] as List? ?? const [];
      if (rawList.isEmpty) return 0;

      final messages = <MeshChatMessage>[];
      for (final item in rawList) {
        if (item is! Map<String, dynamic>) continue;
        final senderDevId = item['senderDeviceId']?.toString() ?? '';
        final senderUserId = item['senderUserId']?.toString();
        final isMine = senderDevId == _localDeviceId || senderUserId == _localDeviceId;
        final backendDelivery = item['deliveryState']?.toString();
        final resolvedDeliveryState = backendDelivery != null && backendDelivery.isNotEmpty
            ? MeshChatDeliveryState.fromString(backendDelivery).name
            : (isMine ? MeshChatDeliveryState.relayed.name : MeshChatDeliveryState.received.name);

        final msg = MeshChatMessage.fromMap({
          ...item,
          'isOutgoing': isMine,
          'deliveryState': resolvedDeliveryState,
          'syncStatus': 'SYNCED',
        });
        messages.add(msg);
      }

      final inserted = await _repository.upsertSyncedMessages(messages);
      if (isDm && messages.isNotEmpty) {
        final incoming = messages.where((m) => !m.isOutgoing).toList();
        if (incoming.isNotEmpty) {
          int maxIncomingTs = 0;
          for (final inc in incoming) {
            final ms = inc.createdAt.millisecondsSinceEpoch;
            if (ms > maxIncomingTs) maxIncomingTs = ms;
          }
          if (maxIncomingTs > 0) {
            await _repository.markPriorOutgoingMessagesSeen(channelId, maxIncomingTs);
          }
        }
      }
      if (inserted > 0 && messages.isNotEmpty) {
        onMessagesPulled?.call(messages);
      }
      return inserted;
    } catch (e) {
      debugPrint('ℹ️ [MESH_SYNC] Could not pull channel $channelId: $e');
      return 0;
    }
  }

  /// Fetches custom and DM channels from MongoDB.
  Future<List<MeshChatChannel>> fetchChannels() async {
    try {
      final res = await _apiClient.get('/mesh-chat/channels');
      if (res.statusCode < 200 || res.statusCode >= 300) return const [];
      final decoded = jsonDecode(res.body) as Map<String, dynamic>;
      final raw = decoded['channels'] as List? ?? const [];
      final channels = <MeshChatChannel>[];
      for (final c in raw) {
        if (c is! Map<String, dynamic>) continue;
        final id = c['channelId']?.toString() ?? '';
        if (id.isEmpty) continue;
        final ch = MeshChatChannel(
          id: id,
          name: c['name']?.toString() ?? '#general',
          description: c['description']?.toString(),
          isDirectMessage: c['isDirectMessage'] == true,
          participants: (c['participants'] as List?)?.map((e) => e.toString()).toList() ?? const [],
          status: c['status']?.toString() ?? 'ACTIVE',
          restrictedReason: c['restrictedReason']?.toString(),
        );
        await _repository.saveChannel(ch);
        channels.add(ch);
      }
      if (onChannelsDiscovered != null && channels.isNotEmpty) {
        await onChannelsDiscovered!(channels);
      }
      return channels;
    } catch (_) {
      return const [];
    }
  }

  /// Notifies the cloud server that direct messages in [channelId] have been read (for double blue ticks).
  Future<void> markChannelRead(String channelId) async {
    try {
      await _apiClient.post('/mesh-chat/channels/${Uri.encodeComponent(channelId)}/read');
    } catch (_) {}
  }

  /// Translates [text] to targetLanguage (defaults to auto: Odia <-> English) via backend Gemini API.
  Future<ChatMessageTranslation?> translateMessage(String text, {String targetLanguage = 'auto'}) async {
    try {
      final res = await _apiClient.post(
        '/mesh-chat/translate',
        body: {
          'text': text,
          'targetLanguage': targetLanguage,
        },
      );
      if (res.statusCode >= 200 && res.statusCode < 300) {
        final decoded = jsonDecode(res.body) as Map<String, dynamic>;
        final translated = decoded['translatedText']?.toString();
        if (translated != null && translated.isNotEmpty) {
          return ChatMessageTranslation(
            text: translated,
            targetLanguage: decoded['targetLanguage']?.toString() ?? 'or',
            targetLanguageName: decoded['targetLanguageName']?.toString() ?? 'Odia (ଓଡ଼ିଆ)',
          );
        }
      }
    } catch (e) {
      debugPrint('⚠️ [MESH_TRANSLATE] Error calling Gemini translation: $e');
    }
    return null;
  }

  /// Creates a custom `#channel` in MongoDB (and saves locally).
  Future<MeshChatChannel?> createChannel({
    required String name,
    String? description,
  }) async {
    final cleanSlug = name
        .trim()
        .replaceFirst(RegExp(r'^#+'), '')
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9\-_]+'), '-')
        .replaceAll(RegExp(r'^-+|-+$'), '');
    if (cleanSlug.length < 2) {
      throw ArgumentError('Channel name must be at least 2 alphanumeric characters');
    }

    final localChannel = MeshChatChannel(
      id: 'channel:$cleanSlug',
      name: '#$cleanSlug',
      description: description?.trim().isNotEmpty == true
          ? description!.trim()
          : 'Campus mesh channel #$cleanSlug',
    );
    await _repository.saveChannel(localChannel);

    try {
      final res = await _apiClient.post(
        '/mesh-chat/channels',
        body: {
          'name': cleanSlug,
          if (description != null && description.trim().isNotEmpty)
            'description': description.trim(),
        },
      );
      if (res.statusCode >= 200 && res.statusCode < 300) {
        final decoded = jsonDecode(res.body) as Map<String, dynamic>;
        final chMap = decoded['channel'] as Map<String, dynamic>?;
        if (chMap != null) {
          final serverChannel = MeshChatChannel(
            id: chMap['channelId']?.toString() ?? localChannel.id,
            name: chMap['name']?.toString() ?? localChannel.name,
            description: chMap['description']?.toString() ?? localChannel.description,
          );
          await _repository.saveChannel(serverChannel);
          return serverChannel;
        }
      }
    } catch (_) {
      // Works offline locally too; will still exist in SQLite
    }
    return localChannel;
  }

  /// Records a moderation flag offline-first and triggers cloud sync.
  Future<void> submitFlag(MeshModerationFlagRecord flag) async {
    await _repository.saveModerationFlag(flag);
    final newStatus = (flag.severity == 'CRITICAL' || flag.severity == 'HIGH')
        ? 'QUARANTINED'
        : 'FLAGGED';
    await _repository.updateModerationVerdict(
      messageId: flag.messageId,
      moderationStatus: newStatus,
      moderationSeverity: flag.severity,
      moderationCategory: flag.category,
      flagReason: flag.reason,
    );
    await _refreshPendingState();
    unawaited(syncPendingAndPull());
  }

  Future<void> dispose() async {
    if (_isDisposed) return;
    _isDisposed = true;
    _periodicSyncTimer?.cancel();
    await _connectivitySub?.cancel();
    syncState.dispose();
  }
}
