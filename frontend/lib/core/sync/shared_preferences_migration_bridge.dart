import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:drift/drift.dart' as drift;
import 'package:shared_preferences/shared_preferences.dart';

import '../database/database.dart';

/// Summary of a legacy SharedPreferences queue migration execution.
class MigrationSummary {
  final int migratedSessions;
  final int migratedRecords;
  final int skippedDuplicates;
  final int malformedRecords;

  const MigrationSummary({
    required this.migratedSessions,
    required this.migratedRecords,
    required this.skippedDuplicates,
    required this.malformedRecords,
  });

  bool get hasMigrated => migratedRecords > 0;

  @override
  String toString() =>
      'MigrationSummary(sessions: $migratedSessions, records: $migratedRecords, duplicates: $skippedDuplicates, malformed: $malformedRecords)';
}

/// Migration bridge that safely transitions legacy SharedPreferences attendance queues
/// into durable Drift SQLite attendance_records and sync_outbox tables (Phase 4J).
///
/// Guarantees:
/// 1. Transactional atomicity: A session's records are migrated into SQLite in a single transaction.
/// 2. Zero data loss: Legacy queue keys are deleted ONLY after SQLite transaction commits.
/// 3. Strict idempotency: Running migration multiple times never duplicates records.
/// 4. Resilient to malformed items: Malformed entries are reported and skipped without crashing.
class SharedPreferencesMigrationBridge {
  static const String queuePrefix = 'campus_os.attendance.queue.';

  final DatabaseService _dbService;

  SharedPreferencesMigrationBridge({DatabaseService? dbService})
      : _dbService = dbService ?? DatabaseService.instance;

  /// Performs an idempotent migration of all legacy queued attendance records.
  Future<MigrationSummary> migrateLegacyQueues({
    SharedPreferences? sharedPreferences,
  }) async {
    final prefs = sharedPreferences ?? await SharedPreferences.getInstance();
    final allKeys = prefs.getKeys().where((k) => k.startsWith(queuePrefix)).toList();

    int totalSessions = 0;
    int totalRecords = 0;
    int totalDuplicates = 0;
    int totalMalformed = 0;

    final db = _dbService.db;
    final attRepo = _dbService.attendanceRepository;

    for (final key in allKeys) {
      final sessionId = key.substring(queuePrefix.length).trim();
      if (sessionId.isEmpty) continue;

      final rawList = prefs.getStringList(key);
      if (rawList == null || rawList.isEmpty) {
        await prefs.remove(key);
        continue;
      }

      final List<AttendanceRecordsTableCompanion> attRecordsToInsert = [];
      final List<SyncOutboxTableCompanion> outboxItemsToInsert = [];

      for (final rawJson in rawList) {
        Map<String, dynamic> recordMap;
        try {
          recordMap = jsonDecode(rawJson) as Map<String, dynamic>;
        } catch (e) {
          debugPrint('⚠️ [MIGRATION_BRIDGE] Malformed JSON in legacy queue: $e');
          totalMalformed++;
          continue;
        }

        final studentId = recordMap['studentId']?.toString();
        if (studentId == null || studentId.isEmpty) {
          totalMalformed++;
          continue;
        }

        final idempotencyKey = recordMap['idempotencyKey']?.toString() ??
            'att_${sessionId}_${recordMap['deviceKeyId']}_${recordMap['responseNonce']}';

        // Check if already in Drift database to prevent duplicates
        final existing = await attRepo.getAttendanceByIdempotencyKey(idempotencyKey);
        if (existing != null) {
          totalDuplicates++;
          continue;
        }

        final localId = 'att_migrated_${idempotencyKey.replaceAll(RegExp(r'[^a-zA-Z0-9_]'), '_')}';
        final checkInTime = DateTime.tryParse(recordMap['checkInTime']?.toString() ?? '') ??
            DateTime.now();

        attRecordsToInsert.add(
          AttendanceRecordsTableCompanion(
            localId: drift.Value(localId),
            sessionId: drift.Value(sessionId),
            studentId: drift.Value(studentId),
            studentName: drift.Value(recordMap['studentName']?.toString() ?? 'Student'),
            checkInTime: drift.Value(checkInTime),
            status: drift.Value(recordMap['status']?.toString() ?? 'present'),
            idempotencyKey: drift.Value(idempotencyKey),
            deviceKeyId: drift.Value(recordMap['deviceKeyId']?.toString()),
            responseNonce: drift.Value(recordMap['responseNonce']?.toString()),
            verificationMode: drift.Value(recordMap['verificationMode']?.toString() ?? 'BLE_BATCH'),
            proximityTier: drift.Value(recordMap['proximityTier']?.toString() ?? 'NEAR'),
            syncState: const drift.Value('pending'),
          ),
        );

        outboxItemsToInsert.add(
          SyncOutboxTableCompanion(
            localId: drift.Value('op_$localId'),
            entityType: const drift.Value('attendance'),
            entityId: drift.Value(localId),
            endpoint: const drift.Value('/attendance/batch-sync'),
            method: const drift.Value('POST'),
            payload: drift.Value(jsonEncode({
              'sessionId': sessionId,
              'records': [
                {
                  'studentId': studentId,
                  'studentName': recordMap['studentName']?.toString() ?? '',
                  'deviceKeyId': recordMap['deviceKeyId'],
                  'responseNonce': recordMap['responseNonce'],
                  'idempotencyKey': idempotencyKey,
                  'verificationMode': recordMap['verificationMode'] ?? 'BLE_BATCH',
                  'proximityTier': recordMap['proximityTier'] ?? 'NEAR',
                  'checkInTime': checkInTime.toIso8601String(),
                  'status': recordMap['status'] ?? 'present',
                  'couponEarned': recordMap['couponEarned'] ?? false,
                }
              ]
            })),
            idempotencyKey: drift.Value(idempotencyKey),
            status: const drift.Value('pending'),
          ),
        );
      }

      // If items exist to be migrated, insert atomically via Drift transaction
      if (attRecordsToInsert.isNotEmpty) {
        await db.transaction(() async {
          // Ensure a placeholder local session exists if not present to respect foreign key
          final session = await _dbService.sessionRepository.getSessionByLocalId(sessionId);
          if (session == null) {
            await db.into(db.sessionsTable).insert(
              SessionsTableCompanion(
                localId: drift.Value(sessionId),
                teacherId: const drift.Value('migrated_teacher'),
                name: const drift.Value('Migrated Offline Session'),
                startTime: drift.Value(DateTime.now()),
                endTime: drift.Value(DateTime.now().add(const Duration(hours: 1))),
                location: const drift.Value('Classroom'),
                syncState: const drift.Value('pending'),
              ),
              mode: drift.InsertMode.insertOrIgnore,
            );
          }

          for (final record in attRecordsToInsert) {
            // Ensure student exists in studentsTable for foreign key integrity
            final stdId = record.studentId.value;
            final student = await _dbService.rosterRepository.getStudentById(stdId);
            if (student == null) {
              await db.into(db.studentsTable).insert(
                StudentsTableCompanion(
                  studentId: drift.Value(stdId),
                  name: record.studentName,
                  rollNumber: drift.Value(stdId),
                ),
                mode: drift.InsertMode.insertOrIgnore,
              );
            }

            await db.into(db.attendanceRecordsTable).insert(
              record,
              mode: drift.InsertMode.insertOrIgnore,
            );
          }
          for (final item in outboxItemsToInsert) {
            await db.into(db.syncOutboxTable).insertOnConflictUpdate(item);
          }
        });

        totalRecords += attRecordsToInsert.length;
        totalSessions++;
      }

      // ONLY remove legacy SharedPreferences queue once SQLite commit succeeds
      await prefs.remove(key);
      debugPrint('✓ [MIGRATION_BRIDGE] Safely migrated ${attRecordsToInsert.length} records for session: $sessionId');
    }

    return MigrationSummary(
      migratedSessions: totalSessions,
      migratedRecords: totalRecords,
      skippedDuplicates: totalDuplicates,
      malformedRecords: totalMalformed,
    );
  }
}
