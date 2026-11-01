import 'dart:async';
import 'dart:io';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

import 'mesh_chat_delivery_state.dart';
import 'mesh_chat_message.dart';

/// Isolated local database repository for CampusOS Mesh chat messages.
///
/// Uses Drift / SQLite NativeDatabase with bounded message retention.
/// Completely isolated from main application and passport schemas.
class MeshChatRepository {
  /// Maximum number of messages retained locally to prevent unbounded SQLite growth.
  static const int defaultMaxRetention = 500;

  final QueryExecutor _executor;
  final int maxRetention;
  bool _isInitialized = false;

  final StreamController<List<MeshChatMessage>> _messagesUpdateController =
      StreamController<List<MeshChatMessage>>.broadcast();

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

  /// Initializes the SQLite table and indexes if not already created.
  Future<void> initialize() async {
    if (_isInitialized) return;

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
        image_base64 TEXT
      );
    ''');

    try {
      await _executor.runCustom('ALTER TABLE mesh_chat_messages ADD COLUMN image_base64 TEXT;');
    } catch (_) {}

    await _executor.runCustom('''
      CREATE INDEX IF NOT EXISTS idx_mesh_chat_channel_ts 
      ON mesh_chat_messages(channel_id, created_at ASC);
    ''');

    _isInitialized = true;
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

    // Enforce messageId deduplication
    final exists = await hasMessage(message.messageId);
    if (exists) {
      return false;
    }

    await _executor.runInsert(
      '''
      INSERT INTO mesh_chat_messages (
        message_id, sender_device_id, sender_user_id, sender_display_name,
        sender_role, channel_id, text, created_at, hop_count, ttl,
        delivery_state, verification_state, is_outgoing, image_base64
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
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
      ],
    );

    // Enforce bounded retention
    await _enforceRetention();

    // Notify listeners
    _notifyUpdate(message.channelId);

    return true;
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
      WHERE channel_id = ? 
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

  /// Updates the delivery state of an existing message.
  Future<void> updateDeliveryState(
    String messageId,
    MeshChatDeliveryState state,
  ) async {
    await initialize();
    await _executor.runUpdate(
      'UPDATE mesh_chat_messages SET delivery_state = ? WHERE message_id = ?',
      [state.name, messageId],
    );
  }

  /// Reactive stream watching messages for a channel.
  Stream<List<MeshChatMessage>> watchMessagesForChannel(String channelId) {
    // Return a stream that starts with current messages and emits on changes
    final controller = StreamController<List<MeshChatMessage>>.broadcast();

    void emitLatest() {
      getMessagesForChannel(channelId).then((messages) {
        if (!controller.isClosed) {
          controller.add(messages);
        }
      });
    }

    emitLatest();

    final sub = _messagesUpdateController.stream.listen((_) {
      emitLatest();
    });

    controller.onCancel = () {
      sub.cancel();
      controller.close();
    };

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
    if (!_messagesUpdateController.isClosed) {
      getMessagesForChannel(channelId).then((messages) {
        if (!_messagesUpdateController.isClosed) {
          _messagesUpdateController.add(messages);
        }
      });
    }
  }

  MeshChatMessage _rowToMessage(Map<String, dynamic> row) {
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
      imageBase64: row['image_base64']?.toString(),
    );
  }

  /// Clears all stored messages.
  Future<void> clearAll() async {
    await initialize();
    await _executor.runCustom('DELETE FROM mesh_chat_messages;');
  }

  /// Closes database connection and stream controllers.
  Future<void> close() async {
    await _messagesUpdateController.close();
    await _executor.close();
  }
}

class _ChatExecutorUser extends QueryExecutorUser {
  @override
  int get schemaVersion => 1;

  @override
  Future<void> beforeOpen(QueryExecutor executor, OpeningDetails details) async {}
}
