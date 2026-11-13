import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

import 'mesh_chat_channel.dart';
import 'mesh_chat_delivery_state.dart';
import 'mesh_chat_message.dart';

/// Offline moderation flag record queued locally until synced to MongoDB.
class MeshModerationFlagRecord {
  final String flagId;
  final String messageId;
  final String channelId;
  final String? reportedUserId;
  final String? reportedDeviceId;
  final String category;
  final String severity;
  final String reason;
  final String messageSnapshot;
  final String? senderSignatureBase64;
  final String source;
  final String syncStatus;
  final int createdAtMs;

  const MeshModerationFlagRecord({
    required this.flagId,
    required this.messageId,
    required this.channelId,
    this.reportedUserId,
    this.reportedDeviceId,
    required this.category,
    required this.severity,
    required this.reason,
    required this.messageSnapshot,
    this.senderSignatureBase64,
    this.source = 'USER_REPORT',
    this.syncStatus = 'PENDING',
    required this.createdAtMs,
  });

  Map<String, dynamic> toApiMap() {
    return {
      'flagId': flagId,
      'messageId': messageId,
      'channelId': channelId,
      if (reportedUserId != null) 'reportedUserId': reportedUserId,
      if (reportedDeviceId != null) 'reportedDeviceId': reportedDeviceId,
      'category': category,
      'severity': severity,
      'reason': reason,
      'messageSnapshot': messageSnapshot,
      if (senderSignatureBase64 != null) 'senderSignature': senderSignatureBase64,
      'source': source,
    };
  }
}

/// Isolated local database repository for CampusOS Mesh chat messages, channels,
/// unread state, and moderation flag outbox.
///
/// Uses Drift / SQLite NativeDatabase with bounded message retention.
class MeshChatRepository {
  /// Maximum number of messages retained locally to prevent unbounded SQLite growth.
  static const int defaultMaxRetention = 500;

  final QueryExecutor _executor;
  final int maxRetention;
  bool _isInitialized = false;
  Future<void>? _initFuture;

  final StreamController<String> _channelChangedController =
      StreamController<String>.broadcast();

  /// Reactive stream emitting channel IDs whenever messages are added, updated, or synced.
  Stream<String> get channelChangedStream => _channelChangedController.stream;

  MeshChatRepository({
    QueryExecutor? executor,
    this.maxRetention = defaultMaxRetention,
  }) : _executor = executor ??
            LazyDatabase(() async {
              final dbFolder = await getApplicationDocumentsDirectory();
              final file = File(p.join(dbFolder.path, 'campus_mesh_chat.sqlite'));
              return NativeDatabase.createInBackground(file);
            });

  /// Creates an in-memory repository instance for fast, isolated testing.
  factory MeshChatRepository.inMemory({int maxRetention = defaultMaxRetention}) {
    return MeshChatRepository(
      executor: NativeDatabase.memory(),
      maxRetention: maxRetention,
    );
  }

  /// Initializes SQLite tables, migrations, and indexes if not already created.
  /// Serializes concurrent initialization callers onto a single future.
  Future<void> initialize() {
    if (_isInitialized) return Future.value();
    return _initFuture ??= _performInitialize();
  }

  Future<void> _performInitialize() async {
    if (_isInitialized) return;
    try {
      await _executor.ensureOpen(_ChatExecutorUser());

    await _executor.runCustom('''
      CREATE TABLE IF NOT EXISTS mesh_chat_messages (
        message_id TEXT PRIMARY KEY,
        sender_device_id TEXT NOT NULL,
        sender_user_id TEXT,
        sender_display_name TEXT NOT NULL,
        sender_role TEXT NOT NULL,
        channel_id TEXT NOT NULL,
        text TEXT NOT NULL,
        created_at INTEGER NOT NULL,
        hop_count INTEGER NOT NULL,
        ttl INTEGER NOT NULL,
        delivery_state TEXT NOT NULL,
        verification_state TEXT NOT NULL,
        is_outgoing INTEGER NOT NULL DEFAULT 0,
        image_base64 TEXT,
        moderation_status TEXT NOT NULL DEFAULT 'CLEAN',
        moderation_severity TEXT NOT NULL DEFAULT 'NONE',
        moderation_category TEXT,
        flag_reason TEXT,
        sync_status TEXT NOT NULL DEFAULT 'PENDING',
        is_encrypted INTEGER NOT NULL DEFAULT 0,
        reply_to_message_id TEXT,
        reply_to_preview TEXT,
        signature_b64 TEXT,
        signable_bytes_b64 TEXT
      );
    ''');

    const migrations = [
      'ALTER TABLE mesh_chat_messages ADD COLUMN image_base64 TEXT;',
      "ALTER TABLE mesh_chat_messages ADD COLUMN moderation_status TEXT NOT NULL DEFAULT 'CLEAN';",
      "ALTER TABLE mesh_chat_messages ADD COLUMN moderation_severity TEXT NOT NULL DEFAULT 'NONE';",
      'ALTER TABLE mesh_chat_messages ADD COLUMN moderation_category TEXT;',
      'ALTER TABLE mesh_chat_messages ADD COLUMN flag_reason TEXT;',
      "ALTER TABLE mesh_chat_messages ADD COLUMN sync_status TEXT NOT NULL DEFAULT 'PENDING';",
      'ALTER TABLE mesh_chat_messages ADD COLUMN is_encrypted INTEGER NOT NULL DEFAULT 0;',
      'ALTER TABLE mesh_chat_messages ADD COLUMN reply_to_message_id TEXT;',
      'ALTER TABLE mesh_chat_messages ADD COLUMN reply_to_preview TEXT;',
      'ALTER TABLE mesh_chat_messages ADD COLUMN signature_b64 TEXT;',
      'ALTER TABLE mesh_chat_messages ADD COLUMN signable_bytes_b64 TEXT;',
    ];
    for (final sql in migrations) {
      try {
        await _executor.runCustom(sql);
      } catch (_) {}
    }

    await _executor.runCustom('''
      CREATE INDEX IF NOT EXISTS idx_mesh_chat_channel_ts
      ON mesh_chat_messages(channel_id, created_at ASC);
    ''');

    await _executor.runCustom('''
      CREATE INDEX IF NOT EXISTS idx_mesh_chat_sync_status
      ON mesh_chat_messages(sync_status, created_at ASC);
    ''');

    await _executor.runCustom('''
      CREATE TABLE IF NOT EXISTS mesh_chat_channels (
        channel_id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        description TEXT,
        is_dm INTEGER NOT NULL DEFAULT 0,
        participants_json TEXT NOT NULL DEFAULT '[]',
        created_at INTEGER NOT NULL DEFAULT 0
      );
    ''');

    await _executor.runCustom('''
      CREATE TABLE IF NOT EXISTS mesh_moderation_flags (
        flag_id TEXT PRIMARY KEY,
        message_id TEXT NOT NULL,
        channel_id TEXT NOT NULL,
        reported_user_id TEXT,
        reported_device_id TEXT,
        category TEXT NOT NULL,
        severity TEXT NOT NULL,
        reason TEXT NOT NULL,
        message_snapshot TEXT NOT NULL,
        sender_signature_b64 TEXT,
        source TEXT NOT NULL DEFAULT 'USER_REPORT',
        sync_status TEXT NOT NULL DEFAULT 'PENDING',
        created_at INTEGER NOT NULL
      );
    ''');

    await _executor.runCustom('''
      CREATE TABLE IF NOT EXISTS mesh_channel_read_state (
        channel_id TEXT PRIMARY KEY,
        last_read_at INTEGER NOT NULL DEFAULT 0
      );
    ''');

    await _executor.runCustom('''
      CREATE INDEX IF NOT EXISTS idx_mesh_channel_read_ts
      ON mesh_channel_read_state(channel_id);
    ''');

    try {
      await _executor.runCustom("ALTER TABLE mesh_chat_channels ADD COLUMN status TEXT DEFAULT 'ACTIVE';");
    } catch (_) {}
    try {
      await _executor.runCustom("ALTER TABLE mesh_chat_channels ADD COLUMN restricted_reason TEXT;");
    } catch (_) {}

    _isInitialized = true;
    } catch (e) {
      _initFuture = null;
      rethrow;
    }
  }

  /// Checks if a message with the given [messageId] is already stored locally.
  Future<bool> hasMessage(String messageId) async {
    await initialize();
    final results = await _executor.runSelect(
      'SELECT 1 FROM mesh_chat_messages WHERE message_id = ? LIMIT 1',
      [messageId],
    );
    return results.isNotEmpty;
  }

  /// Saves a chat message to local SQLite storage.
  ///
  /// Returns `true` if the message was newly recorded.
  /// Returns `false` if the message ID already exists (deduplication suppression).
  Future<bool> saveMessage(MeshChatMessage message) async {
    await initialize();

    final exists = await hasMessage(message.messageId);
    if (exists) {
      return false;
    }

    await _insertMessageRow(message);
    await _enforceRetention();
    _notifyUpdate(message.channelId);
    return true;
  }

  /// Merges a batch of cloud-synced or store-and-forward messages idempotently.
  /// Returns the number of newly inserted messages.
  Future<int> upsertSyncedMessages(List<MeshChatMessage> messages) async {
    await initialize();
    int inserted = 0;
    final touchedChannels = <String>{};

    for (final msg in messages) {
      if (msg.messageId.isEmpty) continue;
      final existing = await _executor.runSelect(
        'SELECT moderation_status, delivery_state FROM mesh_chat_messages WHERE message_id = ? LIMIT 1',
        [msg.messageId],
      );
      if (existing.isEmpty) {
        await _insertMessageRow(msg);
        inserted++;
        touchedChannels.add(msg.channelId);
      } else {
        bool needsUpdate = false;
        final curMod = existing.first['moderation_status']?.toString() ?? 'CLEAN';
        final curDeliv = existing.first['delivery_state']?.toString() ?? 'queued';

        String newDeliv = curDeliv;
        if (msg.deliveryState == MeshChatDeliveryState.seen && curDeliv != 'seen') {
          newDeliv = 'seen';
          needsUpdate = true;
        } else if (msg.deliveryState == MeshChatDeliveryState.received &&
            (curDeliv == 'queued' || curDeliv == 'failed' || curDeliv == 'relayed')) {
          newDeliv = 'received';
          needsUpdate = true;
        } else if (msg.deliveryState == MeshChatDeliveryState.relayed &&
            (curDeliv == 'queued' || curDeliv == 'failed')) {
          newDeliv = 'relayed';
          needsUpdate = true;
        }

        final newMod = (msg.moderationStatus != 'CLEAN' && curMod == 'CLEAN') ? msg.moderationStatus : curMod;
        if (newMod != curMod) needsUpdate = true;

        if (needsUpdate) {
          await _executor.runUpdate(
            '''
            UPDATE mesh_chat_messages
            SET moderation_status = ?, moderation_severity = ?, moderation_category = ?, flag_reason = ?, sync_status = ?, delivery_state = ?
            WHERE message_id = ?
            ''',
            [
              newMod,
              msg.moderationSeverity,
              msg.moderationCategory,
              msg.flagReason,
              'SYNCED',
              newDeliv,
              msg.messageId,
            ],
          );
          touchedChannels.add(msg.channelId);
        }
      }
    }

    if (inserted > 0) {
      await _enforceRetention();
    }
    for (final cid in touchedChannels) {
      _notifyUpdate(cid);
    }
    return inserted;
  }

  Future<void> _insertMessageRow(MeshChatMessage message) async {
    final sigB64 = (message.signature != null && message.signature!.isNotEmpty)
        ? base64Encode(message.signature!)
        : null;

    await _executor.runInsert(
      '''
      INSERT INTO mesh_chat_messages (
        message_id, sender_device_id, sender_user_id, sender_display_name,
        sender_role, channel_id, text, created_at, hop_count, ttl,
        delivery_state, verification_state, is_outgoing, image_base64,
        moderation_status, moderation_severity, moderation_category, flag_reason,
        sync_status, is_encrypted, reply_to_message_id, reply_to_preview,
        signature_b64, signable_bytes_b64
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
      ''',
      [
        message.messageId,
        message.senderDeviceId,
        message.senderUserId,
        message.senderDisplayName,
        message.senderRole,
        message.channelId,
        message.text,
        message.createdAt.millisecondsSinceEpoch,
        message.hopCount,
        message.ttl,
        message.deliveryState.name,
        message.verificationState,
        message.isOutgoing ? 1 : 0,
        message.imageBase64,
        message.moderationStatus,
        message.moderationSeverity,
        message.moderationCategory,
        message.flagReason,
        message.syncStatus,
        message.isEncrypted ? 1 : 0,
        message.replyToMessageId,
        message.replyToPreview,
        sigB64,
        message.signableBytesBase64,
      ],
    );
  }

  /// Retrieves messages for a specific channel ordered chronologically.
  Future<List<MeshChatMessage>> getMessagesForChannel(
    String channelId, {
    int limit = 100,
  }) async {
    await initialize();
    final rows = await _executor.runSelect(
      '''
      SELECT * FROM mesh_chat_messages
      WHERE channel_id = ? AND moderation_status != 'HIDDEN_BY_ADMIN'
      ORDER BY created_at ASC
      LIMIT ?
      ''',
      [channelId, limit],
    );

    return rows.map(_rowToMessage).toList(growable: false);
  }

  /// Retrieves all messages across all channels.
  Future<List<MeshChatMessage>> getAllMessages({int limit = 500}) async {
    await initialize();
    final rows = await _executor.runSelect(
      '''
      SELECT * FROM mesh_chat_messages
      ORDER BY created_at ASC
      LIMIT ?
      ''',
      [limit],
    );

    return rows.map(_rowToMessage).toList(growable: false);
  }

  /// Returns unsynced messages waiting for cloud upload.
  Future<List<MeshChatMessage>> getPendingSyncMessages({int limit = 50}) async {
    await initialize();
    final rows = await _executor.runSelect(
      '''
      SELECT * FROM mesh_chat_messages
      WHERE sync_status = 'PENDING' AND channel_id NOT LIKE 'system:%'
      ORDER BY created_at ASC
      LIMIT ?
      ''',
      [limit],
    );
    return rows.map(_rowToMessage).toList(growable: false);
  }

  /// Returns queued or failed outbound messages eligible for BLE retry when a peer connects.
  Future<List<MeshChatMessage>> getQueuedOutboundMessages({int limit = 20}) async {
    await initialize();
    final rows = await _executor.runSelect(
      '''
      SELECT * FROM mesh_chat_messages
      WHERE is_outgoing = 1 AND delivery_state IN ('queued', 'failed')
      ORDER BY created_at ASC
      LIMIT ?
      ''',
      [limit],
    );
    return rows.map(_rowToMessage).toList(growable: false);
  }

  /// Returns recent public channel messages newer than [sinceMs] for BLE store-and-forward catch-up.
  Future<List<MeshChatMessage>> getRecentMessagesForCatchup({
    required String channelId,
    int sinceMs = 0,
    int limit = 15,
  }) async {
    await initialize();
    final rows = await _executor.runSelect(
      '''
      SELECT * FROM mesh_chat_messages
      WHERE channel_id = ? AND created_at > ? AND is_encrypted = 0 AND moderation_status != 'HIDDEN_BY_ADMIN'
      ORDER BY created_at ASC
      LIMIT ?
      ''',
      [channelId, sinceMs, limit],
    );
    return rows.map(_rowToMessage).toList(growable: false);
  }

  /// Returns latest message timestamp (ms) stored locally for [channelId].
  Future<int> getLatestTimestampForChannel(String channelId) async {
    await initialize();
    final rows = await _executor.runSelect(
      'SELECT MAX(created_at) AS max_ts FROM mesh_chat_messages WHERE channel_id = ?',
      [channelId],
    );
    if (rows.isEmpty) return 0;
    final val = rows.first['max_ts'];
    if (val is int) return val;
    return int.tryParse(val?.toString() ?? '0') ?? 0;
  }

  /// Marks messages as synced and applies any server moderation verdicts.
  Future<void> markMessagesSynced(
    List<String> messageIds, {
    Map<String, dynamic>? verdicts,
  }) async {
    if (messageIds.isEmpty) return;
    await initialize();
    final touchedChannels = <String>{};

    for (final id in messageIds) {
      final rows = await _executor.runSelect(
        'SELECT channel_id, moderation_status FROM mesh_chat_messages WHERE message_id = ? LIMIT 1',
        [id],
      );
      if (rows.isEmpty) continue;
      final cid = rows.first['channel_id']?.toString();

      final verdict = verdicts?[id] as Map<String, dynamic>?;
      if (verdict != null) {
        final status = verdict['moderationStatus']?.toString() ?? 'CLEAN';
        final severity = verdict['moderationSeverity']?.toString() ?? 'NONE';
        final reasonsList = verdict['flagReasons'] is List
            ? (verdict['flagReasons'] as List).map((e) => e.toString()).join(', ')
            : null;
        await _executor.runUpdate(
          '''
          UPDATE mesh_chat_messages
          SET sync_status = 'SYNCED',
              delivery_state = CASE WHEN delivery_state = 'queued' OR delivery_state = 'failed' THEN 'relayed' ELSE delivery_state END,
              moderation_status = CASE WHEN ? != 'CLEAN' THEN ? ELSE moderation_status END,
              moderation_severity = CASE WHEN ? != 'NONE' THEN ? ELSE moderation_severity END,
              flag_reason = COALESCE(?, flag_reason)
          WHERE message_id = ?
          ''',
          [status, status, severity, severity, reasonsList?.isNotEmpty == true ? reasonsList : null, id],
        );
      } else {
        await _executor.runUpdate(
          '''
          UPDATE mesh_chat_messages
          SET sync_status = 'SYNCED',
              delivery_state = CASE WHEN delivery_state = 'queued' OR delivery_state = 'failed' THEN 'relayed' ELSE delivery_state END
          WHERE message_id = ?
          ''',
          [id],
        );
      }

      if (cid != null) touchedChannels.add(cid);
    }

    for (final cid in touchedChannels) {
      _notifyUpdate(cid);
    }
  }

  /// Marks messages as REJECTED so they do not block the cloud outbox queue indefinitely.
  Future<void> markMessagesRejected(List<String> messageIds) async {
    if (messageIds.isEmpty) return;
    await initialize();
    final touchedChannels = <String>{};

    for (final id in messageIds) {
      final rows = await _executor.runSelect(
        'SELECT channel_id FROM mesh_chat_messages WHERE message_id = ? LIMIT 1',
        [id],
      );
      if (rows.isEmpty) continue;
      final cid = rows.first['channel_id']?.toString();

      await _executor.runUpdate(
        "UPDATE mesh_chat_messages SET sync_status = 'REJECTED' WHERE message_id = ?",
        [id],
      );

      if (cid != null) touchedChannels.add(cid);
    }

    for (final cid in touchedChannels) {
      _notifyUpdate(cid);
    }
  }

  /// Returns known mapping of deviceId -> displayName from historical messages.
  Future<Map<String, String>> getKnownPeerDisplayNames() async {
    await initialize();
    try {
      final rows = await _executor.runSelect(
        '''
        SELECT sender_device_id, sender_display_name
        FROM mesh_chat_messages
        WHERE sender_display_name IS NOT NULL
          AND sender_display_name != ''
          AND sender_display_name != sender_device_id
          AND sender_display_name NOT LIKE 'Peer (%'
          AND sender_display_name NOT LIKE 'Revoked User (%'
        GROUP BY sender_device_id
        ''',
        [],
      );
      final map = <String, String>{};
      for (final r in rows) {
        final devId = r['sender_device_id']?.toString();
        final name = r['sender_display_name']?.toString();
        if (devId != null && name != null && name.isNotEmpty) {
          map[devId] = name;
        }
      }
      return map;
    } catch (_) {
      return const {};
    }
  }

  /// Updates the moderation verdict for a message (e.g. after a user flags it locally).
  Future<void> updateModerationVerdict({
    required String messageId,
    required String moderationStatus,
    required String moderationSeverity,
    String? moderationCategory,
    String? flagReason,
  }) async {
    await initialize();
    final rows = await _executor.runSelect(
      'SELECT channel_id FROM mesh_chat_messages WHERE message_id = ? LIMIT 1',
      [messageId],
    );
    await _executor.runUpdate(
      '''
      UPDATE mesh_chat_messages
      SET moderation_status = ?, moderation_severity = ?, moderation_category = COALESCE(?, moderation_category), flag_reason = COALESCE(?, flag_reason)
      WHERE message_id = ?
      ''',
      [moderationStatus, moderationSeverity, moderationCategory, flagReason, messageId],
    );
    if (rows.isNotEmpty) {
      final cid = rows.first['channel_id']?.toString();
      if (cid != null) _notifyUpdate(cid);
    }
  }

  /// Fetches a single message by its unique ID.
  Future<MeshChatMessage?> getMessageById(String messageId) async {
    await initialize();
    final rows = await _executor.runSelect(
      'SELECT * FROM mesh_chat_messages WHERE message_id = ? LIMIT 1',
      [messageId],
    );
    if (rows.isEmpty) return null;
    return _rowToMessage(rows.first);
  }

  /// Updates the delivery state of an existing message and notifies channel listeners.
  Future<void> updateDeliveryState(
    String messageId,
    MeshChatDeliveryState state,
  ) async {
    await initialize();
    final rows = await _executor.runSelect(
      'SELECT channel_id FROM mesh_chat_messages WHERE message_id = ? LIMIT 1',
      [messageId],
    );
    await _executor.runUpdate(
      'UPDATE mesh_chat_messages SET delivery_state = ? WHERE message_id = ?',
      [state.name, messageId],
    );
    if (rows.isNotEmpty) {
      final cid = rows.first['channel_id']?.toString();
      if (cid != null) {
        _notifyUpdate(cid);
      }
    }
  }

  /// Saves or updates a channel (custom #channel or DM) in persistent SQLite.
  Future<void> saveChannel(MeshChatChannel channel) async {
    await initialize();
    await _executor.runCustom(
      '''
      INSERT INTO mesh_chat_channels (channel_id, name, description, is_dm, participants_json, created_at, status, restricted_reason)
      VALUES (?, ?, ?, ?, ?, ?, ?, ?)
      ON CONFLICT(channel_id) DO UPDATE SET
        name = excluded.name,
        description = COALESCE(excluded.description, mesh_chat_channels.description),
        participants_json = excluded.participants_json,
        status = excluded.status,
        restricted_reason = excluded.restricted_reason
      ''',
      [
        channel.id,
        channel.name,
        channel.description,
        channel.isDirectMessage ? 1 : 0,
        jsonEncode(channel.participants),
        DateTime.now().millisecondsSinceEpoch,
        channel.status,
        channel.restrictedReason,
      ],
    );
  }

  /// Loads persisted custom channels and DM threads from SQLite.
  Future<List<MeshChatChannel>> getSavedChannels() async {
    await initialize();
    final rows = await _executor.runSelect(
      'SELECT * FROM mesh_chat_channels ORDER BY created_at ASC',
      [],
    );
    return rows.map((row) {
      List<String> participants = const [];
      try {
        final decoded = jsonDecode(row['participants_json']?.toString() ?? '[]');
        if (decoded is List) {
          participants = decoded.map((e) => e.toString()).toList();
        }
      } catch (_) {}
      return MeshChatChannel(
        id: row['channel_id']?.toString() ?? '',
        name: row['name']?.toString() ?? '#channel',
        description: row['description']?.toString(),
        isDirectMessage: row['is_dm'] == 1 || row['is_dm'] == true,
        participants: participants,
        status: row['status']?.toString() ?? 'ACTIVE',
        restrictedReason: row['restricted_reason']?.toString(),
      );
    }).toList(growable: false);
  }

  /// Marks [channelId] as read up to [timestampMs].
  Future<void> markChannelRead(String channelId, [int? timestampMs]) async {
    await initialize();
    final ts = timestampMs ?? DateTime.now().millisecondsSinceEpoch;
    await _executor.runCustom(
      '''
      INSERT INTO mesh_channel_read_state (channel_id, last_read_at)
      VALUES (?, ?)
      ON CONFLICT(channel_id) DO UPDATE SET last_read_at = MAX(mesh_channel_read_state.last_read_at, excluded.last_read_at)
      ''',
      [channelId, ts],
    );
  }

  /// Marks all prior outgoing messages in [channelId] created at or before [beforeTsMs] as seen.
  Future<int> markPriorOutgoingMessagesSeen(String channelId, int beforeTsMs) async {
    await initialize();
    final updated = await _executor.runUpdate(
      '''
      UPDATE mesh_chat_messages
      SET delivery_state = 'seen'
      WHERE channel_id = ?
        AND is_outgoing = 1
        AND created_at <= ?
        AND delivery_state != 'seen'
      ''',
      [channelId, beforeTsMs],
    );
    if (updated > 0) {
      _channelChangedController.add(channelId);
    }
    return updated;
  }

  /// Computes unread inbound message counts per channel.
  Future<Map<String, int>> getUnreadCounts() async {
    await initialize();
    final rows = await _executor.runSelect(
      '''
      SELECT m.channel_id AS channel_id, COUNT(*) AS unread_count
      FROM mesh_chat_messages m
      LEFT JOIN mesh_channel_read_state r ON m.channel_id = r.channel_id
      WHERE m.is_outgoing = 0
        AND m.moderation_status != 'HIDDEN_BY_ADMIN'
        AND m.created_at > COALESCE(r.last_read_at, 0)
      GROUP BY m.channel_id
      ''',
      [],
    );
    final result = <String, int>{};
    for (final row in rows) {
      final cid = row['channel_id']?.toString();
      final count = row['unread_count'] is int
          ? row['unread_count'] as int
          : int.tryParse(row['unread_count']?.toString() ?? '0') ?? 0;
      if (cid != null && count > 0) {
        result[cid] = count;
      }
    }
    return result;
  }

  /// Saves a moderation flag into the offline outbox.
  Future<void> saveModerationFlag(MeshModerationFlagRecord flag) async {
    await initialize();
    await _executor.runCustom(
      '''
      INSERT OR IGNORE INTO mesh_moderation_flags (
        flag_id, message_id, channel_id, reported_user_id, reported_device_id,
        category, severity, reason, message_snapshot, sender_signature_b64,
        source, sync_status, created_at
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
      ''',
      [
        flag.flagId,
        flag.messageId,
        flag.channelId,
        flag.reportedUserId,
        flag.reportedDeviceId,
        flag.category,
        flag.severity,
        flag.reason,
        flag.messageSnapshot,
        flag.senderSignatureBase64,
        flag.source,
        flag.syncStatus,
        flag.createdAtMs,
      ],
    );
  }

  /// Retrieves pending offline moderation flags waiting to sync to MongoDB.
  Future<List<MeshModerationFlagRecord>> getPendingModerationFlags({int limit = 50}) async {
    await initialize();
    final rows = await _executor.runSelect(
      '''
      SELECT * FROM mesh_moderation_flags
      WHERE sync_status != 'SYNCED'
      ORDER BY created_at ASC
      LIMIT ?
      ''',
      [limit],
    );
    return rows.map((r) => MeshModerationFlagRecord(
      flagId: r['flag_id']?.toString() ?? '',
      messageId: r['message_id']?.toString() ?? '',
      channelId: r['channel_id']?.toString() ?? '',
      reportedUserId: r['reported_user_id']?.toString(),
      reportedDeviceId: r['reported_device_id']?.toString(),
      category: r['category']?.toString() ?? 'OTHER',
      severity: r['severity']?.toString() ?? 'MODERATE',
      reason: r['reason']?.toString() ?? '',
      messageSnapshot: r['message_snapshot']?.toString() ?? '',
      senderSignatureBase64: r['sender_signature_b64']?.toString(),
      source: r['source']?.toString() ?? 'USER_REPORT',
      syncStatus: r['sync_status']?.toString() ?? 'PENDING',
      createdAtMs: r['created_at'] is int
          ? r['created_at'] as int
          : int.tryParse(r['created_at']?.toString() ?? '0') ?? 0,
    )).toList(growable: false);
  }

  /// Marks moderation flags as synced to backend.
  Future<void> markFlagsSynced(List<String> flagIds) async {
    if (flagIds.isEmpty) return;
    await initialize();
    for (final fid in flagIds) {
      await _executor.runUpdate(
        "UPDATE mesh_moderation_flags SET sync_status = 'SYNCED' WHERE flag_id = ?",
        [fid],
      );
    }
  }

  /// Reactive stream watching messages for a channel.
  Stream<List<MeshChatMessage>> watchMessagesForChannel(String channelId) {
    StreamSubscription? sub;
    late final StreamController<List<MeshChatMessage>> controller;

    void emitLatest() {
      getMessagesForChannel(channelId).then((messages) {
        if (!controller.isClosed) {
          controller.add(messages);
        }
      }).catchError((_) {
        if (!controller.isClosed) {
          controller.add(const <MeshChatMessage>[]);
        }
      });
    }

    controller = StreamController<List<MeshChatMessage>>.broadcast(
      onListen: () {
        emitLatest();
        sub = _channelChangedController.stream
            .where((changedChannel) => changedChannel == channelId || changedChannel == '*')
            .listen((_) {
          emitLatest();
        });
      },
      onCancel: () {
        sub?.cancel();
        controller.close();
      },
    );

    return controller.stream;
  }

  /// Deletes oldest messages if total count exceeds [maxRetention].
  Future<void> _enforceRetention() async {
    await _executor.runCustom('''
      DELETE FROM mesh_chat_messages
      WHERE message_id IN (
        SELECT message_id FROM mesh_chat_messages
        ORDER BY created_at ASC
        LIMIT MAX(0, (SELECT COUNT(*) FROM mesh_chat_messages) - $maxRetention)
      );
    ''');
  }

  void _notifyUpdate(String channelId) {
    if (!_channelChangedController.isClosed) {
      _channelChangedController.add(channelId);
    }
  }

  MeshChatMessage _rowToMessage(Map<String, dynamic> row) {
    Uint8List? sig;
    final rawSig = row['signature_b64']?.toString();
    if (rawSig != null && rawSig.isNotEmpty) {
      try {
        sig = Uint8List.fromList(base64Decode(rawSig));
      } catch (_) {}
    }

    return MeshChatMessage(
      messageId: row['message_id']?.toString() ?? '',
      senderDeviceId: row['sender_device_id']?.toString() ?? '',
      senderUserId: row['sender_user_id']?.toString(),
      senderDisplayName: row['sender_display_name']?.toString() ?? 'Unknown User',
      senderRole: row['sender_role']?.toString() ?? 'student',
      channelId: row['channel_id']?.toString() ?? 'channel:general',
      text: row['text']?.toString() ?? '',
      createdAt: DateTime.fromMillisecondsSinceEpoch(
        row['created_at'] is int
            ? row['created_at'] as int
            : int.tryParse(row['created_at']?.toString() ?? '0') ?? 0,
      ),
      hopCount: row['hop_count'] is int
          ? row['hop_count'] as int
          : int.tryParse(row['hop_count']?.toString() ?? '0') ?? 0,
      ttl: row['ttl'] is int
          ? row['ttl'] as int
          : int.tryParse(row['ttl']?.toString() ?? '7') ?? 7,
      deliveryState: MeshChatDeliveryState.fromString(
        row['delivery_state']?.toString() ?? 'received',
      ),
      verificationState: row['verification_state']?.toString() ?? 'UNVERIFIED',
      isOutgoing: (row['is_outgoing'] == 1 || row['is_outgoing'] == true),
      signature: sig,
      imageBase64: row['image_base64']?.toString(),
      moderationStatus: row['moderation_status']?.toString() ?? 'CLEAN',
      moderationSeverity: row['moderation_severity']?.toString() ?? 'NONE',
      moderationCategory: row['moderation_category']?.toString(),
      flagReason: row['flag_reason']?.toString(),
      syncStatus: row['sync_status']?.toString() ?? 'PENDING',
      isEncrypted: (row['is_encrypted'] == 1 || row['is_encrypted'] == true),
      replyToMessageId: row['reply_to_message_id']?.toString(),
      replyToPreview: row['reply_to_preview']?.toString(),
      signableBytesBase64: row['signable_bytes_b64']?.toString(),
    );
  }

  /// Clears all stored messages.
  Future<void> clearAll() async {
    await initialize();
    await _executor.runCustom('DELETE FROM mesh_chat_messages;');
    _notifyUpdate('*');
  }

  /// Closes database connection and stream controllers.
  Future<void> close() async {
    await _channelChangedController.close();
    await _executor.close();
  }

  /// Disposes database resources (alias for [close]).
  Future<void> dispose() => close();
}

class _ChatExecutorUser extends QueryExecutorUser {
  @override
  int get schemaVersion => 2;

  @override
  Future<void> beforeOpen(QueryExecutor executor, OpeningDetails details) async {}
}
