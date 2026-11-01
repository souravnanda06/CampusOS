import 'dart:async';
import 'dart:io';
import 'package:cryptography/cryptography.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'mesh_airdrop_models.dart';

/// Exception thrown when a reassembled file's SHA-256 does not match the signed offer hash.
class MeshAirDropIntegrityException implements Exception {
  final String fileId;
  final String expectedSha256;
  final String actualSha256;

  MeshAirDropIntegrityException({
    required this.fileId,
    required this.expectedSha256,
    required this.actualSha256,
  });

  @override
  String toString() =>
      'MeshAirDropIntegrityException: SHA-256 mismatch for fileId $fileId. Expected $expectedSha256, got $actualSha256.';
}

/// Tracks chunk sequence arrivals and detects missing chunks for a transfer session.
class ReceivedChunkTracker {
  final int totalChunks;
  final Set<int> _receivedSequences = {};

  ReceivedChunkTracker({required this.totalChunks});

  /// Records a chunk sequence number.
  ///
  /// Returns `true` if this sequence was newly registered.
  /// Returns `false` if it is an idempotent duplicate chunk.
  bool markReceived(int sequence) {
    if (sequence < 0 || sequence >= totalChunks) return false;
    return _receivedSequences.add(sequence);
  }

  /// Whether all expected chunks have been recorded.
  bool get isComplete => _receivedSequences.length == totalChunks;

  /// Number of unique chunks received so far.
  int get receivedCount => _receivedSequences.length;

  /// Returns a sorted list of chunk sequences that are still missing.
  List<int> getMissingSequences() {
    final missing = <int>[];
    for (int i = 0; i < totalChunks; i++) {
      if (!_receivedSequences.contains(i)) {
        missing.add(i);
      }
    }
    return missing;
  }
}

/// Disk storage manager and streaming engine for CampusOS Mesh AirDrop.
///
/// Follows memory-bounded design:
/// - Reads source files chunk-by-chunk without loading complete files into RAM.
/// - Writes incoming chunks directly to disk using [RandomAccessFile] at exact byte offsets.
/// - Calculates SHA-256 hashes via streaming without buffering full files.
/// - Enforces safe filenames preventing path traversal vulnerabilities.
class MeshAirDropStorage {
  final Directory? _customBaseDir;

  MeshAirDropStorage({Directory? customBaseDir}) : _customBaseDir = customBaseDir;

  /// Sanitizes a filename to prevent path traversal and filesystem injection attacks.
  static String sanitizeFilename(String filename) {
    var clean = filename.trim();
    // Strip directory separators and path traversal
    clean = clean.replaceAll(RegExp(r'[\\/]'), '_');
    clean = clean.replaceAll(RegExp(r'\.\.+'), '_');
    // Remove null bytes and non-printable control characters
    clean = clean.replaceAll(RegExp(r'[\x00-\x1F\x7F]'), '');
    // Remove illegal Windows characters
    clean = clean.replaceAll(RegExp(r'[:*?"<>|]'), '_');

    if (clean.isEmpty) {
      clean = 'campus_file_${DateTime.now().millisecondsSinceEpoch}';
    }
    return clean;
  }

  /// Root directory for app-private mesh file transfers.
  Future<Directory> getBaseDirectory() async {
    if (_customBaseDir != null) {
      if (!await _customBaseDir!.exists()) {
        await _customBaseDir!.create(recursive: true);
      }
      return _customBaseDir!;
    }
    final appDir = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(appDir.path, 'campus_mesh_airdrop'));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  /// Incoming temporary assembly directory.
  Future<Directory> getIncomingDirectory() async {
    final base = await getBaseDirectory();
    final dir = Directory(p.join(base.path, 'incoming'));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  /// Completed downloads directory.
  Future<Directory> getCompletedDirectory() async {
    final base = await getBaseDirectory();
    final dir = Directory(p.join(base.path, 'completed'));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  /// Computes the SHA-256 hash of a file streamingly without loading the full file into RAM.
  Future<String> computeFileSha256(File file) async {
    if (!await file.exists()) {
      throw FileSystemException('File does not exist for hash computation', file.path);
    }
    final sink = Sha256().newHashSink();
    await for (final chunk in file.openRead()) {
      sink.add(chunk);
    }
    sink.close();
    final hash = await sink.hash();
    return hash.bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join().toLowerCase();
  }

  /// Streams chunks from a source file incrementally.
  ///
  /// Memory usage is strictly bounded to a single chunk buffer (~100 bytes).
  Stream<MeshFileChunk> readChunks({
    required File file,
    required String fileId,
    required int chunkSize,
    required int totalChunks,
  }) async* {
    if (!await file.exists()) {
      throw FileSystemException('Source file not found', file.path);
    }

    final raf = await file.open(mode: FileMode.read);
    try {
      final fileLength = await raf.length();
      int sequence = 0;
      int offset = 0;

      while (offset < fileLength && sequence < totalChunks) {
        final toRead = (offset + chunkSize <= fileLength) ? chunkSize : (fileLength - offset);
        final buffer = await raf.read(toRead);

        yield MeshFileChunk(
          fileId: fileId,
          sequence: sequence,
          totalChunks: totalChunks,
          bytes: buffer,
        );

        sequence++;
        offset += toRead;
      }
    } finally {
      await raf.close();
    }
  }

  /// Initializes an incoming temporary file on disk for a new transfer.
  Future<File> createTemporaryIncomingFile(String fileId) async {
    final incomingDir = await getIncomingDirectory();
    final tempFile = File(p.join(incomingDir.path, '$fileId.tmp'));
    if (await tempFile.exists()) {
      await tempFile.delete();
    }
    await tempFile.create(recursive: true);
    return tempFile;
  }

  /// Writes a chunk directly to disk at the calculated byte offset.
  ///
  /// Supports arbitrary out-of-order chunk arrivals.
  Future<void> writeChunkToDisk({
    required File tempFile,
    required MeshFileChunk chunk,
    required int chunkSize,
  }) async {
    final raf = await tempFile.open(mode: FileMode.append);
    try {
      final targetOffset = chunk.sequence * chunkSize;
      await raf.setPosition(targetOffset);
      await raf.writeFrom(chunk.bytes);
    } finally {
      await raf.close();
    }
  }

  /// Finalizes an assembled file:
  /// 1. Verifies SHA-256 against expected hash.
  /// 2. If valid, moves from temporary incoming to completed storage.
  /// 3. If invalid, deletes corrupted temporary file and throws [MeshAirDropIntegrityException].
  Future<File> finalizeAndVerifyFile({
    required File tempFile,
    required String fileId,
    required String originalFilename,
    required String expectedSha256,
  }) async {
    final actualHash = await computeFileSha256(tempFile);
    if (actualHash.toLowerCase() != expectedSha256.toLowerCase()) {
      // Delete corrupted assembly file
      if (await tempFile.exists()) {
        await tempFile.delete();
      }
      throw MeshAirDropIntegrityException(
        fileId: fileId,
        expectedSha256: expectedSha256,
        actualSha256: actualHash,
      );
    }

    final safeFilename = sanitizeFilename(originalFilename);
    final completedDir = await getCompletedDirectory();
    if (!await completedDir.exists()) {
      await completedDir.create(recursive: true);
    }
    final targetPath = p.normalize(p.join(completedDir.path, '${fileId}_$safeFilename'));
    final targetFile = File(targetPath);
    if (await targetFile.exists()) {
      await targetFile.delete();
    }

    File finalFile;
    try {
      finalFile = await tempFile.rename(targetPath);
    } catch (_) {
      finalFile = await tempFile.copy(targetPath);
      if (await tempFile.exists()) {
        await tempFile.delete();
      }
    }
    return finalFile;
  }

  /// Cleans up any expired or abandoned temporary assembly files.
  Future<int> cleanupStaleTemporaryFiles({Duration maxAge = const Duration(hours: 24)}) async {
    final incomingDir = await getIncomingDirectory();
    int cleaned = 0;
    final now = DateTime.now();

    await for (final entity in incomingDir.list()) {
      if (entity is File && entity.path.endsWith('.tmp')) {
        final stat = await entity.stat();
        if (now.difference(stat.modified) > maxAge) {
          await entity.delete();
          cleaned++;
        }
      }
    }
    return cleaned;
  }
}
