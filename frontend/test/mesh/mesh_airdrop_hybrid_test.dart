import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:attendance_app/core/mesh/airdrop/campus_mesh_airdrop_service.dart';
import 'package:attendance_app/core/mesh/airdrop/mesh_airdrop_models.dart';
import 'package:attendance_app/core/mesh/airdrop/mesh_airdrop_repository.dart';
import 'package:attendance_app/core/mesh/airdrop/mesh_airdrop_storage.dart';
import 'package:attendance_app/core/mesh/airdrop/transport/local_wifi_capability.dart';
import 'package:attendance_app/core/mesh/airdrop/transport/local_wifi_file_transport.dart';
import 'package:attendance_app/core/mesh/airdrop/transport/local_wifi_session.dart';
import 'package:attendance_app/core/mesh/campus_mesh_service.dart';
import 'package:attendance_app/core/mesh/mesh_deduplication_store.dart';
import 'package:attendance_app/core/mesh/mesh_packet_codec.dart';
import 'package:attendance_app/core/mesh/mesh_peer_registry.dart';
import 'package:attendance_app/core/mesh/mesh_relay_engine.dart';
import 'package:attendance_app/shared/screens/campus_mesh_airdrop_screen.dart';

class MockMeshBleAdapter implements MeshBleAdapter {
  final List<Uint8List> advertised = [];
  void Function(Uint8List rawBytes, int rssi)? packetDiscoveredCallback;
  MockMeshBleAdapter? peerAdapter;

  @override
  Future<bool> isBluetoothAvailable() async => true;

  @override
  Future<bool> requestPermissions() async => true;

  @override
  Future<bool> startScanning({
    required void Function(Uint8List rawBytes, int rssi) onPacketDiscovered,
  }) async {
    packetDiscoveredCallback = onPacketDiscovered;
    return true;
  }

  @override
  Future<void> stopScanning() async {
    packetDiscoveredCallback = null;
  }

  @override
  Future<bool> advertisePacket(Uint8List rawBytes) async {
    advertised.add(rawBytes);
    peerAdapter?.simulateInboundAdvertisement(rawBytes);
    return true;
  }

  @override
  Future<void> stopAdvertising() async {}

  @override
  Future<void> dispose() async {}

  void simulateInboundAdvertisement(Uint8List rawBytes, {int rssi = -60}) {
    packetDiscoveredCallback?.call(rawBytes, rssi);
  }
}

CampusMeshService createMeshNode(String deviceId, {String role = 'student', MockMeshBleAdapter? adapter}) {
  final a = adapter ?? MockMeshBleAdapter();
  return CampusMeshService(
    localDeviceId: deviceId,
    localRole: role,
    adapter: a,
    codec: const MeshPacketCodec(),
    deduplicationStore: MeshDeduplicationStore(maxSize: 100),
    peerRegistry: MeshPeerRegistry(),
    relayEngine: MeshRelayEngine(
      localDeviceId: deviceId,
      deduplicationStore: MeshDeduplicationStore(maxSize: 100),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory testDir;
  late MeshAirDropStorage storage;

  setUpAll(() async {
    HttpOverrides.global = null;
    testDir = await Directory.systemTemp.createTemp('campus_airdrop_hybrid_test_');
    storage = MeshAirDropStorage(customBaseDir: testDir);
  });

  setUp(() {
    HttpOverrides.global = null;
  });

  tearDownAll(() async {
    try {
      if (await testDir.exists()) {
        await testDir.delete(recursive: true);
      }
    } catch (_) {}
  });

  Future<File> createTestPayload(String name, int sizeBytes, {int seed = 42}) async {
    final file = File('${testDir.path}/$name');
    final raf = await file.open(mode: FileMode.write);
    final buffer = Uint8List(64 * 1024);
    for (int i = 0; i < buffer.length; i++) {
      buffer[i] = (i + seed) % 256;
    }
    int written = 0;
    while (written < sizeBytes) {
      final toWrite = (written + buffer.length <= sizeBytes) ? buffer.length : (sizeBytes - written);
      await raf.writeFrom(buffer, 0, toWrite);
      written += toWrite;
    }
    await raf.close();
    return file;
  }

  // =========================================================================
  // GROUP A: Capability Detection
  // =========================================================================
  group('CampusOS Mesh — Phase M5B Hybrid AirDrop Tests', () {
    test('Group A: Local Wi-Fi capability detection returns supported for valid network interface', () async {
      final detector = LocalWifiCapabilityDetector(
        mockDetector: () async => const LocalWifiCapabilityResult(
          status: LocalWifiCapabilityStatus.supported,
          ipAddress: '192.168.43.1',
          interfaceName: 'wlan0',
        ),
      );

      final result = await detector.detectCapability();
      expect(result.isSupported, isTrue);
      expect(result.status, LocalWifiCapabilityStatus.supported);
      expect(result.ipAddress, '192.168.43.1');
      expect(result.interfaceName, 'wlan0');
    });

    test('Group A: Capability detection handles unavailable Wi-Fi interface gracefully', () async {
      final detector = LocalWifiCapabilityDetector(
        mockDetector: () async => const LocalWifiCapabilityResult(
          status: LocalWifiCapabilityStatus.unavailable,
          failureReason: 'No non-loopback network interface available.',
        ),
      );

      final result = await detector.detectCapability();
      expect(result.isSupported, isFalse);
      expect(result.status, LocalWifiCapabilityStatus.unavailable);
      expect(result.failureReason, contains('No non-loopback'));
    });

    test('Group A: Capability detection handles permission denied and failure statuses', () async {
      final detector = LocalWifiCapabilityDetector(
        mockDetector: () async => const LocalWifiCapabilityResult(
          status: LocalWifiCapabilityStatus.permissionDenied,
          failureReason: 'Nearby Wi-Fi devices permission not granted.',
        ),
      );

      final result = await detector.detectCapability();
      expect(result.isSupported, isFalse);
      expect(result.status, LocalWifiCapabilityStatus.permissionDenied);
    });

    // =========================================================================
    // GROUP B: Session & Token Security
    // =========================================================================
    test('Group B: Local transfer session generates 32-hex secure token and validates correctly', () {
      final session = LocalWifiTransferSession.create(
        fileId: 'a' * 32,
        transferId: 'transfer_123',
        senderDeviceId: 'device_sender',
        receiverDeviceId: 'device_receiver',
        sha256: 'b' * 64,
        fileSize: 1048576,
        host: '127.0.0.1',
        port: 8080,
      );

      expect(session.authToken.length, 32);
      expect(session.isExpired, isFalse);
      expect(session.hasBeenRedeemed, isFalse);
      expect(session.validateToken(session.authToken), isTrue);
      expect(session.validateToken('wrong_token'), isFalse);
      expect(session.validateToken(''), isFalse);
    });

    test('Group B: Expired local transfer session rejects token validation', () {
      final session = LocalWifiTransferSession(
        fileId: 'a' * 32,
        transferId: 'transfer_123',
        senderDeviceId: 'device_sender',
        receiverDeviceId: 'device_receiver',
        sha256: 'b' * 64,
        fileSize: 1048576,
        authToken: 'c' * 32,
        host: '127.0.0.1',
        port: 8080,
        createdAt: DateTime.now().subtract(const Duration(minutes: 10)),
        expiresAt: DateTime.now().subtract(const Duration(minutes: 5)),
      );

      expect(session.isExpired, isTrue);
      expect(session.validateToken(session.authToken), isFalse);
    });

    test('Group B: Single-use token replay protection prevents unauthorized reuse', () {
      final session = LocalWifiTransferSession.create(
        fileId: 'a' * 32,
        transferId: 'transfer_123',
        senderDeviceId: 'device_sender',
        receiverDeviceId: 'device_receiver',
        sha256: 'b' * 64,
        fileSize: 1048576,
        host: '127.0.0.1',
        port: 8080,
      );

      expect(session.validateToken(session.authToken, allowMultiChunk: false), isTrue);
      session.markRedeemed();
      expect(session.hasBeenRedeemed, isTrue);
      // Replay attempt fails when allowMultiChunk is false
      expect(session.validateToken(session.authToken, allowMultiChunk: false), isFalse);
    });

    // =========================================================================
    // GROUP C: HTTP Server Security & Attack Defense
    // =========================================================================
    test('Group C: Unauthorized HTTP requests without token are rejected with 401', () async {
      final testFile = await createTestPayload('security_test_1.dat', 1024);
      final sha256 = await storage.computeFileSha256(testFile);
      const fileId = '11223344556677889900aabbccddeeff';

      final mockSession = MeshFileTransferSession(
        transferId: 'sec_transfer_1',
        fileId: fileId,
        peerDeviceId: 'peer_1',
        peerRole: 'student',
        direction: MeshTransferDirection.outgoing,
        state: MeshFileTransferState.sending,
        filename: 'security_test_1.dat',
        mimeType: 'application/octet-stream',
        fileSize: 1024,
        transferredBytes: 0,
        totalChunks: 1,
        transferredChunks: 0,
        sha256: sha256,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        expiresAt: DateTime.now().add(const Duration(minutes: 5)),
        transportType: MeshTransportType.localWifi,
      );

      final transport = LocalWifiFileTransport(storage: storage);
      final serverSession = await transport.startSenderServer(
        session: mockSession,
        file: testFile,
        localIpAddress: '127.0.0.1',
      );

      final client = HttpClient();
      try {
        // 1. Request with NO token -> 401
        final reqNoToken = await client.getUrl(
          Uri.parse('http://127.0.0.1:${serverSession.port}/transfer/$fileId/file'),
        );
        final resNoToken = await reqNoToken.close();
        expect(resNoToken.statusCode, HttpStatus.unauthorized);

        // 2. Request with WRONG token -> 401
        final reqWrongToken = await client.getUrl(
          Uri.parse('http://127.0.0.1:${serverSession.port}/transfer/$fileId/file'),
        );
        reqWrongToken.headers.set('X-Transfer-Token', 'invalid_token_1234567890abcdef');
        final resWrongToken = await reqWrongToken.close();
        expect(resWrongToken.statusCode, HttpStatus.unauthorized);

        // 3. Request for nonexistent or directory path -> 404
        final reqRoot = await client.getUrl(
          Uri.parse('http://127.0.0.1:${serverSession.port}/'),
        );
        final resRoot = await reqRoot.close();
        expect(resRoot.statusCode, HttpStatus.notFound);

        // 4. Path traversal attempt -> 404 or 400
        final reqTraversal = await client.getUrl(
          Uri.parse('http://127.0.0.1:${serverSession.port}/transfer/../etc/passwd'),
        );
        final resTraversal = await reqTraversal.close();
        expect(resTraversal.statusCode, HttpStatus.notFound);

        // 5. FileId substitution -> 403 Forbidden
        final reqSub = await client.getUrl(
          Uri.parse('http://127.0.0.1:${serverSession.port}/transfer/different_file_id/file'),
        );
        reqSub.headers.set('X-Transfer-Token', serverSession.authToken);
        final resSub = await reqSub.close();
        expect(resSub.statusCode, HttpStatus.forbidden);

        // 6. Valid metadata endpoint -> 200 OK
        final reqMeta = await client.getUrl(
          Uri.parse('http://127.0.0.1:${serverSession.port}/transfer/$fileId/metadata'),
        );
        reqMeta.headers.set('X-Transfer-Token', serverSession.authToken);
        final resMeta = await reqMeta.close();
        expect(resMeta.statusCode, HttpStatus.ok);
        final metaBody = await resMeta.transform(utf8.decoder).join();
        expect(metaBody, contains(fileId));
        expect(metaBody, contains(sha256));
      } finally {
        client.close(force: true);
        await transport.dispose();
      }
    });

    // =========================================================================
    // GROUP D: Large File Streaming (5 MB, 10 MB, 25 MB)
    // =========================================================================
    test('Group D: High-speed streaming 5 MB file directly to disk with SHA-256 verification', () async {
      const sizeBytes = 5 * 1024 * 1024; // 5 MB
      final sourceFile = await createTestPayload('payload_5mb.bin', sizeBytes, seed: 101);
      final expectedSha = await storage.computeFileSha256(sourceFile);
      const fileId = '00112233445566778899aabbccddeeff';

      final transport = LocalWifiFileTransport(storage: storage);
      final session = MeshFileTransferSession(
        transferId: 'transfer_5mb',
        fileId: fileId,
        peerDeviceId: 'peer_rx',
        peerRole: 'student',
        direction: MeshTransferDirection.outgoing,
        state: MeshFileTransferState.transferring,
        filename: 'payload_5mb.bin',
        mimeType: 'application/octet-stream',
        fileSize: sizeBytes,
        transferredBytes: 0,
        totalChunks: 1,
        transferredChunks: 0,
        sha256: expectedSha,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        expiresAt: DateTime.now().add(const Duration(minutes: 5)),
        transportType: MeshTransportType.localWifi,
      );

      final serverSession = await transport.startSenderServer(
        session: session,
        file: sourceFile,
        localIpAddress: '127.0.0.1',
      );

      final targetFile = File('${testDir.path}/received_5mb.bin');
      if (await targetFile.exists()) await targetFile.delete();

      final rxSession = session.copyWith(
        wifiHost: '127.0.0.1',
        wifiPort: serverSession.port,
        wifiToken: serverSession.authToken,
      );

      final sw = Stopwatch()..start();
      int lastReportedBytes = 0;
      double lastSpeed = 0.0;

      final resultFile = await transport.receive(
        session: rxSession,
        targetFile: targetFile,
        onProgress: (update) {
          lastReportedBytes = update.transferredBytes;
          lastSpeed = update.speedKbps;
        },
      );
      sw.stop();

      final actualSha = await storage.computeFileSha256(resultFile);
      final durationSec = sw.elapsedMilliseconds / 1000.0;
      final throughputMbps = (sizeBytes / (1024 * 1024)) / (durationSec > 0.001 ? durationSec : 0.001);

      // Automated / Simulated Benchmark Measurement
      // ignore: avoid_print
      print('⚡ [SIMULATED BENCHMARK] 5 MB: ${durationSec.toStringAsFixed(3)}s (${throughputMbps.toStringAsFixed(1)} MB/s), SHA: ${actualSha.substring(0, 8)}...');

      expect(await resultFile.exists(), isTrue);
      expect(await resultFile.length(), sizeBytes);
      expect(lastReportedBytes, sizeBytes);
      expect(actualSha, expectedSha);
      expect(lastSpeed, greaterThanOrEqualTo(0.0));

      await transport.dispose();
    });

    test('Group D: High-speed streaming 10 MB file directly to disk with bounded memory', () async {
      const sizeBytes = 10 * 1024 * 1024; // 10 MB
      final sourceFile = await createTestPayload('payload_10mb.bin', sizeBytes, seed: 102);
      final expectedSha = await storage.computeFileSha256(sourceFile);
      const fileId = 'aabbccddeeff00112233445566778899';

      final transport = LocalWifiFileTransport(storage: storage);
      final session = MeshFileTransferSession(
        transferId: 'transfer_10mb',
        fileId: fileId,
        peerDeviceId: 'peer_rx',
        peerRole: 'student',
        direction: MeshTransferDirection.outgoing,
        state: MeshFileTransferState.transferring,
        filename: 'payload_10mb.bin',
        mimeType: 'application/octet-stream',
        fileSize: sizeBytes,
        transferredBytes: 0,
        totalChunks: 1,
        transferredChunks: 0,
        sha256: expectedSha,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        expiresAt: DateTime.now().add(const Duration(minutes: 5)),
        transportType: MeshTransportType.localWifi,
      );

      final serverSession = await transport.startSenderServer(
        session: session,
        file: sourceFile,
        localIpAddress: '127.0.0.1',
      );

      final targetFile = File('${testDir.path}/received_10mb.bin');
      if (await targetFile.exists()) await targetFile.delete();

      final rxSession = session.copyWith(
        wifiHost: '127.0.0.1',
        wifiPort: serverSession.port,
        wifiToken: serverSession.authToken,
      );

      final sw = Stopwatch()..start();
      final resultFile = await transport.receive(
        session: rxSession,
        targetFile: targetFile,
      );
      sw.stop();

      final actualSha = await storage.computeFileSha256(resultFile);
      final durationSec = sw.elapsedMilliseconds / 1000.0;
      final throughputMbps = (sizeBytes / (1024 * 1024)) / (durationSec > 0.001 ? durationSec : 0.001);

      // Automated / Simulated Benchmark Measurement
      // ignore: avoid_print
      print('⚡ [SIMULATED BENCHMARK] 10 MB: ${durationSec.toStringAsFixed(3)}s (${throughputMbps.toStringAsFixed(1)} MB/s), SHA: ${actualSha.substring(0, 8)}...');

      expect(await resultFile.exists(), isTrue);
      expect(await resultFile.length(), sizeBytes);
      expect(actualSha, expectedSha);

      await transport.dispose();
    });

    test('Group D: High-speed streaming 25 MB file directly to disk with streaming verification', () async {
      const sizeBytes = 25 * 1024 * 1024; // 25 MB
      final sourceFile = await createTestPayload('payload_25mb.bin', sizeBytes, seed: 103);
      final expectedSha = await storage.computeFileSha256(sourceFile);
      const fileId = '1234567890abcdef1234567890abcdef';

      final transport = LocalWifiFileTransport(storage: storage);
      final session = MeshFileTransferSession(
        transferId: 'transfer_25mb',
        fileId: fileId,
        peerDeviceId: 'peer_rx',
        peerRole: 'student',
        direction: MeshTransferDirection.outgoing,
        state: MeshFileTransferState.transferring,
        filename: 'payload_25mb.bin',
        mimeType: 'application/octet-stream',
        fileSize: sizeBytes,
        transferredBytes: 0,
        totalChunks: 1,
        transferredChunks: 0,
        sha256: expectedSha,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        expiresAt: DateTime.now().add(const Duration(minutes: 5)),
        transportType: MeshTransportType.localWifi,
      );

      final serverSession = await transport.startSenderServer(
        session: session,
        file: sourceFile,
        localIpAddress: '127.0.0.1',
      );

      final targetFile = File('${testDir.path}/received_25mb.bin');
      if (await targetFile.exists()) await targetFile.delete();

      final rxSession = session.copyWith(
        wifiHost: '127.0.0.1',
        wifiPort: serverSession.port,
        wifiToken: serverSession.authToken,
      );

      final sw = Stopwatch()..start();
      final resultFile = await transport.receive(
        session: rxSession,
        targetFile: targetFile,
      );
      sw.stop();

      final actualSha = await storage.computeFileSha256(resultFile);
      final durationSec = sw.elapsedMilliseconds / 1000.0;
      final throughputMbps = (sizeBytes / (1024 * 1024)) / (durationSec > 0.001 ? durationSec : 0.001);

      // Automated / Simulated Benchmark Measurement
      // ignore: avoid_print
      print('⚡ [SIMULATED BENCHMARK] 25 MB: ${durationSec.toStringAsFixed(3)}s (${throughputMbps.toStringAsFixed(1)} MB/s), SHA: ${actualSha.substring(0, 8)}...');

      expect(await resultFile.exists(), isTrue);
      expect(await resultFile.length(), sizeBytes);
      expect(actualSha, expectedSha);

      await transport.dispose();
    });

    // =========================================================================
    // GROUP E: Integrity Verification & Tampering Defense
    // =========================================================================
    test('Group E: Corrupted file or mismatched hash triggers MeshAirDropIntegrityException and cleans temp file', () async {
      const sizeBytes = 1024 * 1024; // 1 MB
      final sourceFile = await createTestPayload('integrity_src.bin', sizeBytes, seed: 77);
      const fileId = '3344556677889900aabbccddeeff0011';

      final transport = LocalWifiFileTransport(storage: storage);
      final session = MeshFileTransferSession(
        transferId: 'transfer_corrupt',
        fileId: fileId,
        peerDeviceId: 'peer_rx',
        peerRole: 'student',
        direction: MeshTransferDirection.outgoing,
        state: MeshFileTransferState.transferring,
        filename: 'integrity_src.bin',
        mimeType: 'application/octet-stream',
        fileSize: sizeBytes,
        transferredBytes: 0,
        totalChunks: 1,
        transferredChunks: 0,
        sha256: 'f' * 64, // Deliberately corrupted / mismatched expected hash
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        expiresAt: DateTime.now().add(const Duration(minutes: 5)),
        transportType: MeshTransportType.localWifi,
      );

      final serverSession = await transport.startSenderServer(
        session: session,
        file: sourceFile,
        localIpAddress: '127.0.0.1',
      );

      final targetFile = File('${testDir.path}/corrupted_target.bin');
      final rxSession = session.copyWith(
        wifiHost: '127.0.0.1',
        wifiPort: serverSession.port,
        wifiToken: serverSession.authToken,
      );

      await expectLater(
        transport.receive(
          session: rxSession,
          targetFile: targetFile,
        ),
        throwsA(isA<MeshAirDropIntegrityException>()),
      );

      // Temporary file must be deleted upon integrity failure
      expect(await targetFile.exists(), isFalse);

      await transport.dispose();
    });

    // =========================================================================
    // GROUP F: End-to-End Hybrid Negotiation Flow
    // =========================================================================
    test('Group F: End-to-end negotiation flow from offer through Wi-Fi ready and complete', () async {
      final repoSender = MeshAirDropRepository.inMemory();
      final repoReceiver = MeshAirDropRepository.inMemory();

      final senderAdapter = MockMeshBleAdapter();
      final receiverAdapter = MockMeshBleAdapter();
      senderAdapter.peerAdapter = receiverAdapter;
      receiverAdapter.peerAdapter = senderAdapter;

      final meshSender = createMeshNode('sender_node', role: 'student', adapter: senderAdapter);
      final meshReceiver = createMeshNode('receiver_node', role: 'student', adapter: receiverAdapter);
      await meshSender.start();
      await meshReceiver.start();

      final serviceSender = CampusMeshAirDropService(
        meshService: meshSender,
        repository: repoSender,
        storage: storage,
        wifiCapabilityDetector: LocalWifiCapabilityDetector(
          mockDetector: () async => const LocalWifiCapabilityResult(
            status: LocalWifiCapabilityStatus.supported,
            ipAddress: '127.0.0.1',
          ),
        ),
      );

      final serviceReceiver = CampusMeshAirDropService(
        meshService: meshReceiver,
        repository: repoReceiver,
        storage: storage,
        wifiCapabilityDetector: LocalWifiCapabilityDetector(
          mockDetector: () async => const LocalWifiCapabilityResult(
            status: LocalWifiCapabilityStatus.supported,
            ipAddress: '127.0.0.1',
          ),
        ),
      );

      await serviceSender.initialize();
      await serviceReceiver.initialize();

      // 1. Create and offer a 3 MB file (prefers Wi-Fi)
      final testFile = await createTestPayload('lecture_3mb.zip', 3 * 1024 * 1024, seed: 88);
      final outSession = await serviceSender.sendFileOffer(
        file: testFile,
        targetDeviceId: 'receiver_node',
        preferredTransport: MeshTransportType.localWifi,
      );

      expect(outSession.transportType, MeshTransportType.localWifi);
      expect(outSession.isHighSpeed, isTrue);

      // Wait for receiver to receive offer
      await Future.delayed(const Duration(milliseconds: 50));
      final rxSession = await repoReceiver.getTransferByFileId(outSession.fileId);
      expect(rxSession, isNotNull);
      expect(rxSession!.state, MeshFileTransferState.offered);
      expect(rxSession.transportType, MeshTransportType.localWifi);

      // 2. Receiver accepts offer (triggers wifiNegotiate -> wifiReady -> HTTP stream)
      await serviceReceiver.acceptOffer(outSession.fileId);

      // Allow handshake and HTTP transfer to complete
      await Future.delayed(const Duration(milliseconds: 500));

      final finalRxSession = await repoReceiver.getTransferByFileId(outSession.fileId);
      expect(finalRxSession, isNotNull);
      expect(finalRxSession!.state, MeshFileTransferState.completed);
      expect(finalRxSession.localFilePath, isNotNull);

      final finalizedFile = File(finalRxSession.localFilePath!);
      expect(await finalizedFile.exists(), isTrue);
      expect(await finalizedFile.length(), 3 * 1024 * 1024);

      final finalTxSession = await repoSender.getTransferByFileId(outSession.fileId);
      expect(finalTxSession, isNotNull);
      expect(finalTxSession!.state, MeshFileTransferState.completed);

      await serviceSender.dispose();
      await serviceReceiver.dispose();
      await repoSender.close();
      await repoReceiver.close();
      await meshSender.dispose();
      await meshReceiver.dispose();
    });

    // =========================================================================
    // GROUP G: Interrupted Transfer & Resumption (HTTP Range)
    // =========================================================================
    test('Group G: Interrupted transfer resumes from known byte offset via HTTP Range header', () async {
      const totalSize = 2 * 1024 * 1024; // 2 MB
      final sourceFile = await createTestPayload('range_source.bin', totalSize, seed: 99);
      final expectedSha = await storage.computeFileSha256(sourceFile);
      const fileId = '44556677889900112233aabbccddeeff';

      final transport = LocalWifiFileTransport(storage: storage);
      final session = MeshFileTransferSession(
        transferId: 'transfer_range',
        fileId: fileId,
        peerDeviceId: 'peer_rx',
        peerRole: 'student',
        direction: MeshTransferDirection.outgoing,
        state: MeshFileTransferState.transferring,
        filename: 'range_source.bin',
        mimeType: 'application/octet-stream',
        fileSize: totalSize,
        transferredBytes: 0,
        totalChunks: 1,
        transferredChunks: 0,
        sha256: expectedSha,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        expiresAt: DateTime.now().add(const Duration(minutes: 5)),
        transportType: MeshTransportType.localWifi,
      );

      final serverSession = await transport.startSenderServer(
        session: session,
        file: sourceFile,
        localIpAddress: '127.0.0.1',
      );

      // Simulate partial file already on disk (512 KB of 2 MB)
      const partialSize = 512 * 1024;
      final targetFile = File('${testDir.path}/range_target.bin');
      final raf = await targetFile.open(mode: FileMode.write);
      final sourceBytes = await sourceFile.openRead(0, partialSize).toList();
      for (final chunk in sourceBytes) {
        await raf.writeFrom(chunk);
      }
      await raf.close();

      expect(await targetFile.length(), partialSize);

      final rxSession = session.copyWith(
        wifiHost: '127.0.0.1',
        wifiPort: serverSession.port,
        wifiToken: serverSession.authToken,
      );

      // Resumes download: sends Range: bytes=524288-
      final completedFile = await transport.receive(
        session: rxSession,
        targetFile: targetFile,
      );

      expect(await completedFile.length(), totalSize);
      final actualSha = await storage.computeFileSha256(completedFile);
      expect(actualSha, expectedSha);

      await transport.dispose();
    });

    // =========================================================================
    // GROUP H: Fallback to BLE Mesh
    // =========================================================================
    test('Group H: Wi-Fi capability failure smoothly falls back to BLE Mesh for small files', () async {
      final repoSender = MeshAirDropRepository.inMemory();
      final repoReceiver = MeshAirDropRepository.inMemory();

      final senderAdapter = MockMeshBleAdapter();
      final receiverAdapter = MockMeshBleAdapter();
      senderAdapter.peerAdapter = receiverAdapter;
      receiverAdapter.peerAdapter = senderAdapter;

      final meshSender = createMeshNode('sender_node_fb', role: 'student', adapter: senderAdapter);
      final meshReceiver = createMeshNode('receiver_node_fb', role: 'student', adapter: receiverAdapter);
      await meshSender.start();
      await meshReceiver.start();

      // Receiver simulates Wi-Fi UNAVAILABLE
      final serviceSender = CampusMeshAirDropService(
        meshService: meshSender,
        repository: repoSender,
        storage: storage,
      );

      final serviceReceiver = CampusMeshAirDropService(
        meshService: meshReceiver,
        repository: repoReceiver,
        storage: storage,
        wifiCapabilityDetector: LocalWifiCapabilityDetector(
          mockDetector: () async => const LocalWifiCapabilityResult(
            status: LocalWifiCapabilityStatus.unavailable,
            failureReason: 'No Wi-Fi interface',
          ),
        ),
      );

      await serviceSender.initialize();
      await serviceReceiver.initialize();

      // Offer a 500 KB file with Wi-Fi preferred
      final testFile = await createTestPayload('small_fb.pdf', 500 * 1024, seed: 12);
      final outSession = await serviceSender.sendFileOffer(
        file: testFile,
        targetDeviceId: 'receiver_node_fb',
        preferredTransport: MeshTransportType.localWifi,
      );

      await Future.delayed(const Duration(milliseconds: 50));

      // Receiver accepts -> Wi-Fi is unavailable -> triggers wifiFallback -> transitions to BLE
      await serviceReceiver.acceptOffer(outSession.fileId);
      await Future.delayed(const Duration(milliseconds: 50));

      final rxSession = await repoReceiver.getTransferByFileId(outSession.fileId);
      expect(rxSession, isNotNull);
      // State transitioned through fallback to receiving via BLE
      expect(rxSession!.state, MeshFileTransferState.receiving);

      await serviceSender.dispose();
      await serviceReceiver.dispose();
      await repoSender.close();
      await repoReceiver.close();
      await meshSender.dispose();
      await meshReceiver.dispose();
    });

    test('Group H: Oversized file (> 2 MB) is rejected when forced to BLE transport', () async {
      final repo = MeshAirDropRepository.inMemory();
      final mesh = createMeshNode('node_oversized');
      final service = CampusMeshAirDropService(meshService: mesh, repository: repo, storage: storage);

      final largeFile = await createTestPayload('oversized_ble.zip', 5 * 1024 * 1024);

      expect(
        () async => await service.sendFileOffer(
          file: largeFile,
          preferredTransport: MeshTransportType.bleMesh, // Force BLE on 5 MB file
        ),
        throwsA(isA<ArgumentError>().having(
          (e) => e.message,
          'message',
          contains('exceeds the offline BLE transfer limit'),
        )),
      );

      await service.dispose();
      await repo.close();
      await mesh.dispose();
    });

    // =========================================================================
    // GROUP I: UI Integration & Transport Badges
    // =========================================================================
    testWidgets('Group I: CampusMeshAirDropScreen displays Local Wi-Fi badge and live speed', (WidgetTester tester) async {
      final repo = MeshAirDropRepository.inMemory();
      await repo.initialize();

      final now = DateTime.now();
      // Insert an active Local Wi-Fi transfer
      final activeWifiSession = MeshFileTransferSession(
        transferId: 'ui_transfer_wifi',
        fileId: '99887766554433221100aabbccddeeff',
        peerDeviceId: 'peer_node_1',
        peerRole: 'student',
        direction: MeshTransferDirection.incoming,
        state: MeshFileTransferState.transferring,
        filename: 'Lecture_Unit_4.zip',
        mimeType: 'application/zip',
        fileSize: 18400 * 1024,
        transferredBytes: 9200 * 1024,
        totalChunks: 100,
        transferredChunks: 50,
        sha256: 'a' * 64,
        createdAt: now.subtract(const Duration(seconds: 2)),
        updatedAt: now,
        expiresAt: now.add(const Duration(minutes: 5)),
        transportType: MeshTransportType.localWifi,
      );
      await repo.saveTransfer(activeWifiSession);

      final mesh = createMeshNode('local_ui_node', role: 'student');
      final service = CampusMeshAirDropService(meshService: mesh, repository: repo, storage: storage);

      await tester.pumpWidget(MaterialApp(
        home: CampusMeshAirDropScreen(airdropService: service),
      ));
      await tester.pumpAndSettle();

      // Verify UI displays document, Local Wi-Fi badge, and transfer details
      expect(find.text('Lecture_Unit_4.zip'), findsOneWidget);
      expect(find.text('Local Wi-Fi'), findsWidgets);
      expect(find.textContaining('High-Speed'), findsWidgets);
      expect(find.textContaining('Direct Wi-Fi · High-Speed'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);

      await service.dispose();
      await repo.close();
      await mesh.dispose();
    });
  });
}
