import 'dart:async';
import 'dart:io';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

import 'mesh_airdrop_models.dart';

/// Isolated local database repository for CampusOS Mesh AirDrop transfers.
///
/// Uses Drift / SQLite NativeDatabase with bounded retention and memory safety.
/// Raw file contents are never stored in SQLite; only transfer metadata, chunk
/// bitmaps, and integrity hashes are persisted.
class MeshAirDropRepository {
  /// Maximum number of completed/failed transfers retained in database.
  static const int defaultMaxRetention = 100;

  final QueryExecutor _executor;
  final int maxRetention;
  bool _isInitialized = false;

  final StreamController<List<MeshFileTransferSession>> _transfersUpdateController =
      StreamController<List<MeshFileTransferSession>>.broadcast();

  MeshAirDropRepository({
    QueryExecutor? executor,
    this.maxRetention = defaultMaxRetention,
  }) : _executor = executor ??
            LazyDatabase(() async {
              final dbFolder = await getApplicationDocumentsDirectory();
              final file = File(p.join(dbFolder.path, 'campus_mesh_airdrop.sqlite'));
              return NativeDatabase.createInBackground(file);
            });

  /// Factory for creating an in-memory database instance for fast, isolated tests.
  factory MeshAirDropRepository.inMemory({int maxRetention = defaultMaxRetention}) {
    return MeshAirDropRepository(
      executor: NativeDatabase.memory(),
      maxRetention: maxRetention,
    );
  }

  /// Reactive stream of all tracked file transfer sessions.
  Stream<List<MeshFileTransferSession>> get transfersStream =>
      _transfersUpdateController.stream;

  /// Initializes tables and indices.
  Future<void> initialize() async {
    if (_isInitialized) return;

    await _executor.ensureOpen(_AirDropExecutorUser());

    await _executor.runCustom('''
      CREATE TABLE IF NOT EXISTS mesh_file_transfers (
        transfer_id TEXT PRIMARY KEY,
        file_id TEXT NOT NULL UNIQUE,
        peer_device_id TEXT NOT NULL,
        peer_display_name TEXT,
        peer_role TEXT NOT NULL,
        is_peer_verified INTEGER NOT NULL DEFAULT 1,
        direction TEXT NOT NULL,
        state TEXT NOT NULL,
        filename TEXT NOT NULL,
        mime_type TEXT NOT NULL,
        file_size INTEGER NOT NULL,
        transferred_bytes INTEGER NOT NULL DEFAULT 0,
        total_chunks INTEGER NOT NULL,
        transferred_chunks INTEGER NOT NULL DEFAULT 0,
        sha256 TEXT NOT NULL,
        local_file_path TEXT,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL,
        expires_at INTEGER NOT NULL,
        error_message TEXT,
        hop_count INTEGER NOT NULL DEFAULT 0,
        transport_type TEXT NOT NULL DEFAULT 'bleMesh'
      );
    ''');

    try {
      await _executor.runCustom(
        "ALTER TABLE mesh_file_transfers ADD COLUMN transport_type TEXT NOT NULL DEFAULT 'bleMesh';",
      );
    } catch (_) {
      // Column may already exist
    }

    await _executor.runCustom('''
      CREATE TABLE IF NOT EXISTS mesh_received_chunks (
        file_id TEXT NOT NULL,
        sequence_number INTEGER NOT NULL,
        PRIMARY KEY (file_id, sequence_number)
      );
    ''');

    await _executor.runCustom('''
      CREATE INDEX IF NOT EXISTS idx_mesh_transfers_state 
      ON mesh_file_transfers(state, updated_at DESC);
    ''');

    await _executor.runCustom('''
      CREATE INDEX IF NOT EXISTS idx_mesh_chunks_file 
      ON mesh_received_chunks(file_id, sequence_number);
    ''');

    _isInitialized = true;
  }

  /// Saves or updates a transfer session in the database.
  Future<void> saveTransfer(MeshFileTransferSession session) async {
    await initialize();

    await _executor.runInsert(
      '''
      INSERT INTO mesh_file_transfers (
        transfer_id, file_id, peer_device_id, peer_display_name, peer_role,
        is_peer_verified, direction, state, filename, mime_type,
        file_size, transferred_bytes, total_chunks, transferred_chunks,
        sha256, local_file_path, created_at, updated_at, expires_at,
        error_message, hop_count, transport_type
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
      ON CONFLICT(transfer_id) DO UPDATE SET
        peer_display_name = excluded.peer_display_name,
        peer_role = excluded.peer_role,
        is_peer_verified = excluded.is_peer_verified,
        state = excluded.state,
        transferred_bytes = excluded.transferred_bytes,
        transferred_chunks = excluded.transferred_chunks,
        local_file_path = excluded.local_file_path,
        updated_at = excluded.updated_at,
        error_message = excluded.error_message,
        hop_count = excluded.hop_count,
        transport_type = excluded.transport_type;
      ''',
      [
        session.transferId,
        session.fileId,
        session.peerDeviceId,
        session.peerDisplayName,
        session.peerRole,
        session.isPeerVerified ? 1 : 0,
        session.direction.name,
        session.state.name,
        session.filename,
        session.mimeType,
        session.fileSize,
        session.transferredBytes,
        session.totalChunks,
        session.transferredChunks,
        session.sha256,
        session.localFilePath,
        session.createdAt.millisecondsSinceEpoch,
        session.updatedAt.millisecondsSinceEpoch,
        session.expiresAt.millisecondsSinceEpoch,
        session.errorMessage,
        session.hopCount,
        session.transportType.name,
      ],
    );

    await _pruneIfNeeded();
    await _notifyTransfersUpdated();
  }

  /// Updates transfer state and optional error or completion file path.
  Future<void> updateTransferState(
    String transferId,
    MeshFileTransferState state, {
    String? errorMessage,
    String? localFilePath,
  }) async {
    await initialize();
    final now = DateTime.now().millisecondsSinceEpoch;

    if (localFilePath != null) {
      await _executor.runCustom(
        '''
        UPDATE mesh_file_transfers
        SET state = ?, error_message = ?, local_file_path = ?, updated_at = ?
        WHERE transfer_id = ?;
        ''',
        [state.name, errorMessage, localFilePath, now, transferId],
      );
    } else {
      await _executor.runCustom(
        '''
        UPDATE mesh_file_transfers
        SET state = ?, error_message = ?, updated_at = ?
        WHERE transfer_id = ?;
        ''',
        [state.name, errorMessage, now, transferId],
      );
    }

    await _notifyTransfersUpdated();
  }

  /// Updates transfer byte and chunk progress counters.
  Future<void> updateProgress(
    String transferId, {
    required int transferredBytes,
    required int transferredChunks,
  }) async {
    await initialize();
    final now = DateTime.now().millisecondsSinceEpoch;

    await _executor.runCustom(
      '''
      UPDATE mesh_file_transfers
      SET transferred_bytes = ?, transferred_chunks = ?, updated_at = ?
      WHERE transfer_id = ?;
      ''',
      [transferredBytes, transferredChunks, now, transferId],
    );

    await _notifyTransfersUpdated();
  }

  /// Records a chunk sequence number in the chunk bitmap index.
  ///
  /// Returns `true` if the chunk was newly recorded, or `false` if it was already present.
  Future<bool> recordReceivedChunk(String fileId, int sequence) async {
    await initialize();

    try {
      final rows = await _executor.runInsert(
        '''
        INSERT OR IGNORE INTO mesh_received_chunks (file_id, sequence_number)
        VALUES (?, ?);
        ''',
        [fileId, sequence],
      );
      return rows > 0;
    } catch (_) {
      return false;
    }
  }

  /// Gets all received chunk sequence numbers for a specific file transfer.
  Future<Set<int>> getReceivedChunkSequences(String fileId) async {
    await initialize();

    final results = await _executor.runSelect(
      '''
      SELECT sequence_number FROM mesh_received_chunks
      WHERE file_id = ?;
      ''',
      [fileId],
    );

    return results
        .map((r) => r['sequence_number'] as int? ?? int.parse(r['sequence_number'].toString()))
        .toSet();
  }

  /// Gets a specific transfer session by [transferId].
  Future<MeshFileTransferSession?> getTransfer(String transferId) async {
    await initialize();

    final results = await _executor.runSelect(
      '''
      SELECT * FROM mesh_file_transfers
      WHERE transfer_id = ? LIMIT 1;
      ''',
      [transferId],
    );

    if (results.isEmpty) return null;
    return _rowToSession(results.first);
  }

  /// Gets a specific transfer session by [fileId].
  Future<MeshFileTransferSession?> getTransferByFileId(String fileId) async {
    await initialize();

    final results = await _executor.runSelect(
      '''
      SELECT * FROM mesh_file_transfers
      WHERE file_id = ? LIMIT 1;
      ''',
      [fileId],
    );

    if (results.isEmpty) return null;
    return _rowToSession(results.first);
  }

  /// Retrieves all transfer sessions ordered by most recently updated.
  Future<List<MeshFileTransferSession>> getAllTransfers() async {
    await initialize();

    final results = await _executor.runSelect(
      '''
      SELECT * FROM mesh_file_transfers
      ORDER BY updated_at DESC;
      ''',
      [],
    );

    return results.map(_rowToSession).toList();
  }

  /// Retrieves active transfers (non-terminal states).
  Future<List<MeshFileTransferSession>> getActiveTransfers() async {
    await initialize();

    final results = await _executor.runSelect(
      '''
      SELECT * FROM mesh_file_transfers
      WHERE state NOT IN ('completed', 'rejected', 'cancelled', 'expired', 'integrityFailure', 'failed')
      ORDER BY updated_at DESC;
      ''',
      [],
    );

    return results.map(_rowToSession).toList();
  }

  /// Retrieves successfully completed transfers.
  Future<List<MeshFileTransferSession>> getCompletedTransfers() async {
    await initialize();

    final results = await _executor.runSelect(
      '''
      SELECT * FROM mesh_file_transfers
      WHERE state = 'completed'
      ORDER BY updated_at DESC;
      ''',
      [],
    );

    return results.map(_rowToSession).toList();
  }

  /// Deletes a transfer record and its received chunks index.
  Future<void> deleteTransfer(String transferId) async {
    await initialize();

    final transfer = await getTransfer(transferId);
    if (transfer != null) {
      await _executor.runCustom(
        'DELETE FROM mesh_received_chunks WHERE file_id = ?;',
        [transfer.fileId],
      );
    }

    await _executor.runCustom(
      'DELETE FROM mesh_file_transfers WHERE transfer_id = ?;',
      [transferId],
    );

    await _notifyTransfersUpdated();
  }

  /// Prunes completed or terminal transfer sessions past [maxRetention].
  Future<int> _pruneIfNeeded() async {
    final countResult = await _executor.runSelect(
      'SELECT COUNT(*) as cnt FROM mesh_file_transfers;',
      [],
    );
    final total = countResult.first['cnt'] as int? ?? 0;
    if (total <= maxRetention) return 0;

    final excess = total - maxRetention;
    final toDelete = await _executor.runSelect(
      '''
      SELECT transfer_id, file_id FROM mesh_file_transfers
      WHERE state IN ('completed', 'rejected', 'cancelled', 'expired', 'integrityFailure', 'failed')
      ORDER BY updated_at ASC
      LIMIT ?;
      ''',
      [excess],
    );

    for (final row in toDelete) {
      final tid = row['transfer_id']?.toString() ?? '';
      final fid = row['file_id']?.toString() ?? '';
      await _executor.runCustom('DELETE FROM mesh_received_chunks WHERE file_id = ?;', [fid]);
      await _executor.runCustom('DELETE FROM mesh_file_transfers WHERE transfer_id = ?;', [tid]);
    }

    return toDelete.length;
  }

  Future<void> _notifyTransfersUpdated() async {
    if (_transfersUpdateController.isClosed) return;
    final all = await getAllTransfers();
    _transfersUpdateController.add(all);
  }

  MeshFileTransferSession _rowToSession(Map<String, dynamic> row) {
    return MeshFileTransferSession(
      transferId: row['transfer_id']?.toString() ?? '',
      fileId: row['file_id']?.toString() ?? '',
      peerDeviceId: row['peer_device_id']?.toString() ?? '',
      peerDisplayName: row['peer_display_name']?.toString(),
      peerRole: row['peer_role']?.toString() ?? 'student',
      isPeerVerified: (row['is_peer_verified'] == 1 || row['is_peer_verified'] == true),
      direction: row['direction']?.toString() == 'incoming'
          ? MeshTransferDirection.incoming
          : MeshTransferDirection.outgoing,
      state: MeshFileTransferState.values.firstWhere(
        (s) => s.name == row['state']?.toString(),
        orElse: () => MeshFileTransferState.failed,
      ),
      filename: row['filename']?.toString() ?? '',
      mimeType: row['mime_type']?.toString() ?? 'application/octet-stream',
      fileSize: row['file_size'] is int
          ? row['file_size'] as int
          : int.tryParse(row['file_size']?.toString() ?? '0') ?? 0,
      transferredBytes: row['transferred_bytes'] is int
          ? row['transferred_bytes'] as int
          : int.tryParse(row['transferred_bytes']?.toString() ?? '0') ?? 0,
      totalChunks: row['total_chunks'] is int
          ? row['total_chunks'] as int
          : int.tryParse(row['total_chunks']?.toString() ?? '0') ?? 0,
      transferredChunks: row['transferred_chunks'] is int
          ? row['transferred_chunks'] as int
          : int.tryParse(row['transferred_chunks']?.toString() ?? '0') ?? 0,
      sha256: row['sha256']?.toString() ?? '',
      localFilePath: row['local_file_path']?.toString(),
      createdAt: DateTime.fromMillisecondsSinceEpoch(
        row['created_at'] is int
            ? row['created_at'] as int
            : int.tryParse(row['created_at']?.toString() ?? '0') ?? 0,
      ),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(
        row['updated_at'] is int
            ? row['updated_at'] as int
            : int.tryParse(row['updated_at']?.toString() ?? '0') ?? 0,
      ),
      expiresAt: DateTime.fromMillisecondsSinceEpoch(
        row['expires_at'] is int
            ? row['expires_at'] as int
            : int.tryParse(row['expires_at']?.toString() ?? '0') ?? 0,
      ),
      errorMessage: row['error_message']?.toString(),
      hopCount: row['hop_count'] is int
          ? row['hop_count'] as int
          : int.tryParse(row['hop_count']?.toString() ?? '0') ?? 0,
      transportType: MeshTransportType.values.firstWhere(
        (t) => t.name == row['transport_type']?.toString(),
        orElse: () => MeshTransportType.bleMesh,
      ),
    );
  }

  /// Clears all transfers and chunk indexes.
  Future<void> clearAll() async {
    await initialize();
    await _executor.runCustom('DELETE FROM mesh_received_chunks;');
    await _executor.runCustom('DELETE FROM mesh_file_transfers;');
    await _notifyTransfersUpdated();
  }

  /// Closes database connection.
  Future<void> close() async {
    _isInitialized = false;
    await _transfersUpdateController.close();
    await _executor.close();
  }
}

class _AirDropExecutorUser extends QueryExecutorUser {
  @override
  int get schemaVersion => 1;

  @override
  Future<void> beforeOpen(QueryExecutor executor, OpeningDetails details) async {}
}
