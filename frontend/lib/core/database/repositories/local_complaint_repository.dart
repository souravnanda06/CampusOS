import 'package:drift/drift.dart';
import '../app_database.dart';

/// Lightweight persistence repository for the Local Complaints table (Phase 6B).
///
/// Manages SQLite CRUD, local-to-server ID mapping, sync lifecycle transitions,
/// and bounded caching for offline-first complaints.
class LocalComplaintRepository {
  final AppDatabase _db;

  LocalComplaintRepository(this._db);

  /// Upsert a local complaint record.
  Future<void> upsertComplaint(ComplaintsTableCompanion complaint) async {
    await _db.into(_db.complaintsTable).insertOnConflictUpdate(complaint);
  }

  /// Retrieve complaint by local client UUID.
  Future<LocalComplaint?> getComplaintByLocalId(String localId) async {
    return (_db.select(_db.complaintsTable)
          ..where((tbl) => tbl.localId.equals(localId)))
        .getSingleOrNull();
  }

  /// Retrieve complaint by server UUID.
  Future<LocalComplaint?> getComplaintByServerId(String serverId) async {
    return (_db.select(_db.complaintsTable)
          ..where((tbl) => tbl.serverId.equals(serverId)))
        .getSingleOrNull();
  }

  /// Retrieve complaint by client idempotency key.
  Future<LocalComplaint?> getComplaintByIdempotencyKey(String idempotencyKey) async {
    return (_db.select(_db.complaintsTable)
          ..where((tbl) => tbl.idempotencyKey.equals(idempotencyKey)))
        .getSingleOrNull();
  }

  /// Retrieve complaints for a student ordered by creation date descending.
  Future<List<LocalComplaint>> getStudentComplaints(String studentId, {int limit = 50}) async {
    return (_db.select(_db.complaintsTable)
          ..where((tbl) => tbl.studentId.equals(studentId))
          ..orderBy([(tbl) => OrderingTerm.desc(tbl.createdAt)])
          ..limit(limit))
        .get();
  }

  /// Update synchronization state and optional server ID upon acknowledgement.
  Future<int> updateSyncState(
    String localId,
    String syncState, {
    String? serverId,
    DateTime? serverCreatedAt,
  }) async {
    return (_db.update(_db.complaintsTable)
          ..where((tbl) => tbl.localId.equals(localId)))
        .write(
      ComplaintsTableCompanion(
        syncState: Value(syncState),
        serverId: serverId != null ? Value(serverId) : const Value.absent(),
        serverCreatedAt: serverCreatedAt != null ? Value(serverCreatedAt) : const Value.absent(),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  /// Update server-authoritative fields (status, resolution remarks, assignment).
  ///
  /// Preserves server authority: offline clients cannot overwrite status once set by admin/server.
  Future<int> updateStatusFromServer(
    String localId,
    String status, {
    String? resolutionRemarks,
    DateTime? resolvedAt,
    String? assignedTo,
    String? assignedToName,
    DateTime? updatedAt,
  }) async {
    return (_db.update(_db.complaintsTable)
          ..where((tbl) => tbl.localId.equals(localId)))
        .write(
      ComplaintsTableCompanion(
        status: Value(status),
        resolutionRemarks: resolutionRemarks != null ? Value(resolutionRemarks) : const Value.absent(),
        resolvedAt: resolvedAt != null ? Value(resolvedAt) : const Value.absent(),
        assignedTo: assignedTo != null ? Value(assignedTo) : const Value.absent(),
        assignedToName: assignedToName != null ? Value(assignedToName) : const Value.absent(),
        updatedAt: Value(updatedAt ?? DateTime.now()),
      ),
    );
  }

  /// Cache server complaints safely without clobbering pending offline changes.
  ///
  /// Phase 6H & 6P: Bounded cache for student complaints.
  Future<void> cacheServerComplaints(
    String studentId,
    List<Map<String, dynamic>> serverComplaints, {
    int maxCached = 50,
  }) async {
    final boundedList = serverComplaints.take(maxCached).toList();

    await _db.transaction(() async {
      for (final raw in boundedList) {
        final serverId = raw['id']?.toString();
        if (serverId == null || serverId.isEmpty) continue;

        final idempotencyKey = raw['idempotencyKey']?.toString() ?? raw['idempotency_key']?.toString();

        // 1. Check if matching record exists by serverId
        LocalComplaint? existing = await getComplaintByServerId(serverId);

        // 2. Or check by idempotencyKey if previously synced
        if (existing == null && idempotencyKey != null && idempotencyKey.isNotEmpty) {
          existing = await getComplaintByIdempotencyKey(idempotencyKey);
        }

        final category = raw['category']?.toString() ?? 'General';
        final title = raw['title']?.toString() ?? '';
        final description = raw['description']?.toString() ?? '';
        final location = raw['location']?.toString() ?? 'Campus';
        final priority = raw['priority']?.toString() ?? 'MEDIUM';
        final status = raw['status']?.toString() ?? 'PENDING';
        final assignedTo = raw['assignedTo']?.toString();
        final assignedToName = raw['assignedToName']?.toString();
        final resolutionRemarks = raw['resolutionRemarks']?.toString() ?? raw['resolutionNotes']?.toString();
        final resolvedAt = raw['resolvedAt'] != null ? DateTime.tryParse(raw['resolvedAt'].toString()) : null;
        final createdAt = raw['createdAt'] != null
            ? DateTime.tryParse(raw['createdAt'].toString()) ?? DateTime.now()
            : DateTime.now();
        final updatedAt = raw['updatedAt'] != null ? DateTime.tryParse(raw['updatedAt'].toString()) : null;
        final isRepeat = raw['isRepeat'] == true;

        if (existing != null) {
          // If local complaint is pending upload, do not overwrite local title/description,
          // but update server-authoritative fields (status, resolution remarks)
          final isPending = existing.syncState == 'pending';

          await (_db.update(_db.complaintsTable)
                ..where((tbl) => tbl.localId.equals(existing!.localId)))
              .write(
            ComplaintsTableCompanion(
              serverId: Value(serverId),
              status: Value(status),
              resolutionRemarks: Value(resolutionRemarks),
              resolvedAt: Value(resolvedAt),
              assignedTo: Value(assignedTo),
              assignedToName: Value(assignedToName),
              updatedAt: Value(updatedAt ?? DateTime.now()),
              category: isPending ? const Value.absent() : Value(category),
              title: isPending ? const Value.absent() : Value(title),
              description: isPending ? const Value.absent() : Value(description),
              location: isPending ? const Value.absent() : Value(location),
              priority: isPending ? const Value.absent() : Value(priority),
              isRepeat: isPending ? const Value.absent() : Value(isRepeat),
              syncState: isPending ? const Value.absent() : const Value('synced'),
            ),
          );
        } else {
          // Fresh server complaint to cache locally
          await _db.into(_db.complaintsTable).insertOnConflictUpdate(
            ComplaintsTableCompanion.insert(
              localId: 'cached_$serverId',
              serverId: Value(serverId),
              idempotencyKey: Value(idempotencyKey),
              studentId: studentId,
              category: category,
              title: title,
              description: description,
              location: Value(location),
              priority: Value(priority),
              status: Value(status),
              syncState: const Value('synced'),
              assignedTo: Value(assignedTo),
              assignedToName: Value(assignedToName),
              resolutionRemarks: Value(resolutionRemarks),
              resolvedAt: Value(resolvedAt),
              createdAt: Value(createdAt),
              serverCreatedAt: Value(createdAt),
              updatedAt: Value(updatedAt),
              isRepeat: Value(isRepeat),
            ),
          );
        }
      }
    });
  }

  /// Delete a complaint record by local ID.
  Future<int> deleteComplaint(String localId) async {
    return (_db.delete(_db.complaintsTable)
          ..where((tbl) => tbl.localId.equals(localId)))
        .go();
  }

  /// Count number of pending unsynced complaints for a student.
  Future<int> countPending(String studentId) async {
    final countExp = _db.complaintsTable.localId.count();
    final query = _db.selectOnly(_db.complaintsTable)
      ..addColumns([countExp])
      ..where(_db.complaintsTable.studentId.equals(studentId) &
          _db.complaintsTable.syncState.equals('pending'));
    final result = await query.getSingle();
    return result.read(countExp) ?? 0;
  }
}
