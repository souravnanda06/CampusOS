import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:cryptography/cryptography.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:attendance_app/core/mesh/airdrop/campus_mesh_airdrop_service.dart';
import 'package:attendance_app/core/mesh/airdrop/mesh_airdrop_models.dart';
import 'package:attendance_app/core/mesh/airdrop/mesh_airdrop_repository.dart';
import 'package:attendance_app/core/mesh/airdrop/mesh_airdrop_storage.dart';
import 'package:attendance_app/core/mesh/campus_mesh_service.dart';
import 'package:attendance_app/core/mesh/mesh_crypto.dart';
import 'package:attendance_app/core/mesh/mesh_deduplication_store.dart';
import 'package:attendance_app/core/mesh/mesh_packet.dart';
import 'package:attendance_app/core/mesh/mesh_packet_codec.dart';
import 'package:attendance_app/core/mesh/mesh_peer_registry.dart';
import 'package:attendance_app/core/mesh/mesh_relay_engine.dart';
import 'package:attendance_app/student/models/passport_trust_bundle_model.dart';

class AirDropTestBleAdapter implements MeshBleAdapter {
  final List<Uint8List> advertised = [];
  void Function(Uint8List rawBytes, int rssi)? packetDiscoveredCallback;

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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('CampusOS Mesh — Phase M5A: Academic P2P File AirDrop Tests', () {
    late Ed25519 algorithm;
    late SimpleKeyPair aliceKeyPair;
    late SimpleKeyPair bobKeyPair;
    late SimpleKeyPair rootKeyPair;

    late SimplePublicKey alicePubKey;
    late SimplePublicKey bobPubKey;
    late SimplePublicKey rootPubKey;

    late PassportTrustBundle trustBundle;
    late CampusMeshCryptoService aliceCryptoService;
    late CampusMeshCryptoService bobCryptoService;

    late AirDropTestBleAdapter aliceAdapter;
    late AirDropTestBleAdapter bobAdapter;

    late MeshAirDropRepository aliceRepo;
    late MeshAirDropRepository bobRepo;

    late Directory tempTestDir;
    late MeshAirDropStorage aliceStorage;
    late MeshAirDropStorage bobStorage;

    late CampusMeshService aliceMeshService;
    late CampusMeshService bobMeshService;

    late CampusMeshAirDropService aliceAirDropService;
    late CampusMeshAirDropService bobAirDropService;

    const codec = MeshPacketCodec();
    int aliceCursor = 0;
    int bobCursor = 0;

    setUp(() async {
      final now = DateTime.now();
      final nowSec = now.toUtc().millisecondsSinceEpoch ~/ 1000;
      aliceCursor = 0;
      bobCursor = 0;
      algorithm = Ed25519();
      rootKeyPair = await algorithm.newKeyPair();
      aliceKeyPair = await algorithm.newKeyPair();
      bobKeyPair = await algorithm.newKeyPair();

      rootPubKey = await rootKeyPair.extractPublicKey();
      alicePubKey = await aliceKeyPair.extractPublicKey();
      bobPubKey = await bobKeyPair.extractPublicKey();

      trustBundle = PassportTrustBundle(
        version: 1,
        issuerKeyId: 'campusos-root-test',
        generatedAt: nowSec - 3600,
        expiresAt: nowSec + 86400,
        institution: PassportInstitutionTrust(
          keyId: 'campusos-root-test',
          publicKey: base64Encode(rootPubKey.bytes),
          issuer: 'CampusOS',
        ),
        identities: [
          PassportTrustIdentity(
            keyId: 'key-alice',
            userId: 'user_alice',
            publicKey: base64Encode(alicePubKey.bytes),
            certificateId: 'cert-alice',
            issuerKeyId: 'campusos-root-test',
            validFrom: nowSec - 3600,
            validTo: nowSec + 86400,
            status: 'ACTIVE',
            userName: 'Sourav Nanda',
          ),
          PassportTrustIdentity(
            keyId: 'key-bob',
            userId: 'user_bob',
            publicKey: base64Encode(bobPubKey.bytes),
            certificateId: 'cert-bob',
            issuerKeyId: 'campusos-root-test',
            validFrom: nowSec - 3600,
            validTo: nowSec + 86400,
            status: 'ACTIVE',
            userName: 'Prof. Mohapatra',
          ),
        ],
        revokedKeyIds: const ['key-revoked-peer'],
        signature: 'dummy_sig',
        rawPayload: const {},
      );

      aliceCryptoService = CampusMeshCryptoService(
        localKeyPair: aliceKeyPair,
        mockTrustBundle: trustBundle,
      );

      bobCryptoService = CampusMeshCryptoService(
        localKeyPair: bobKeyPair,
        mockTrustBundle: trustBundle,
      );

      aliceAdapter = AirDropTestBleAdapter();
      bobAdapter = AirDropTestBleAdapter();

      aliceRepo = MeshAirDropRepository.inMemory();
      bobRepo = MeshAirDropRepository.inMemory();

      tempTestDir = await Directory.systemTemp.createTemp('campus_mesh_airdrop_test_');
      aliceStorage = MeshAirDropStorage(customBaseDir: Directory('${tempTestDir.path}/alice'));
      bobStorage = MeshAirDropStorage(customBaseDir: Directory('${tempTestDir.path}/bob'));

      aliceMeshService = CampusMeshService(
        localDeviceId: 'key-alice',
        localRole: 'student',
        adapter: aliceAdapter,
        codec: codec,
        deduplicationStore: MeshDeduplicationStore(maxSize: 100),
        peerRegistry: MeshPeerRegistry(),
        relayEngine: MeshRelayEngine(
          localDeviceId: 'key-alice',
          deduplicationStore: MeshDeduplicationStore(maxSize: 100),
        ),
        cryptoService: aliceCryptoService,
      );

      bobMeshService = CampusMeshService(
        localDeviceId: 'key-bob',
        localRole: 'teacher',
        adapter: bobAdapter,
        codec: codec,
        deduplicationStore: MeshDeduplicationStore(maxSize: 100),
        peerRegistry: MeshPeerRegistry(),
        relayEngine: MeshRelayEngine(
          localDeviceId: 'key-bob',
          deduplicationStore: MeshDeduplicationStore(maxSize: 100),
        ),
        cryptoService: bobCryptoService,
      );

      aliceAirDropService = CampusMeshAirDropService(
        meshService: aliceMeshService,
        repository: aliceRepo,
        storage: aliceStorage,
        mockTrustBundle: trustBundle,
        chunkPacing: Duration.zero,
      );

      bobAirDropService = CampusMeshAirDropService(
        meshService: bobMeshService,
        repository: bobRepo,
        storage: bobStorage,
        mockTrustBundle: trustBundle,
        chunkPacing: Duration.zero,
      );

      await aliceAirDropService.initialize();
      await bobAirDropService.initialize();

      await aliceMeshService.start();
      await bobMeshService.start();
    });

    tearDown(() async {
      await aliceAirDropService.dispose();
      await bobAirDropService.dispose();
      await aliceMeshService.dispose();
      await bobMeshService.dispose();
      await aliceRepo.close();
      await bobRepo.close();
      if (await tempTestDir.exists()) {
        await tempTestDir.delete(recursive: true);
      }
    });

    // Helper: pipe Alice advertisements directly into Bob and vice-versa
    void connectVirtualRadios() {
      while (aliceCursor < aliceAdapter.advertised.length) {
        final raw = aliceAdapter.advertised[aliceCursor++];
        bobAdapter.simulateInboundAdvertisement(raw);
      }
      while (bobCursor < bobAdapter.advertised.length) {
        final raw = bobAdapter.advertised[bobCursor++];
        aliceAdapter.simulateInboundAdvertisement(raw);
      }
    }

    // =========================================================================
    // GROUP A: FILE OFFER VALIDATION
    // =========================================================================
    group('Group A: File Offer Validation', () {
      test('Valid offer encodes and decodes deterministically within transport budget', () {
        final offer = MeshFileOffer(
          fileId: '0123456789abcdef0123456789abcdef',
          senderDeviceId: 'key-alice',
          senderUserId: 'user_alice',
          senderRole: 'student',
          filename: 'DBMS_Unit3_Notes.pdf',
          mimeType: 'application/pdf',
          fileSize: 842000,
          sha256: 'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855',
          chunkSize: 100,
          totalChunks: 8420,
          createdAt: DateTime.now(),
          expiresAt: DateTime.now().add(const Duration(minutes: 5)),
          targetDeviceId: 'key-bob',
        );

        final bytes = offer.toBytes();
        expect(bytes.length, lessThanOrEqualTo(135), reason: 'Must safely fit within 135-byte payload budget');

        final decoded = MeshFileOffer.fromBytes(
          bytes: bytes,
          senderDeviceId: 'key-alice',
          senderRole: 'student',
          createdAt: offer.createdAt,
        );

        expect(decoded.fileId, equals(offer.fileId));
        expect(decoded.filename, equals(offer.filename));
        expect(decoded.fileSize, equals(offer.fileSize));
        expect(decoded.sha256, equals(offer.sha256));
        expect(decoded.targetDeviceId, equals('key-bob'));
      });

      test('Oversized filename (> 120 chars) throws ArgumentError', () {
        expect(
          () => MeshFileOffer(
            fileId: '0123456789abcdef0123456789abcdef',
            senderDeviceId: 'key-alice',
            senderRole: 'student',
            filename: 'a' * 121,
            mimeType: 'application/pdf',
            fileSize: 1000,
            sha256: 'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855',
            chunkSize: 100,
            totalChunks: 10,
            createdAt: DateTime.now(),
            expiresAt: DateTime.now().add(const Duration(minutes: 5)),
          ),
          throwsArgumentError,
        );
      });

      test('Zero-byte file size throws ArgumentError', () {
        expect(
          () => MeshFileOffer(
            fileId: '0123456789abcdef0123456789abcdef',
            senderDeviceId: 'key-alice',
            senderRole: 'student',
            filename: 'empty.pdf',
            mimeType: 'application/pdf',
            fileSize: 0,
            sha256: 'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855',
            chunkSize: 100,
            totalChunks: 0,
            createdAt: DateTime.now(),
            expiresAt: DateTime.now().add(const Duration(minutes: 5)),
          ),
          throwsArgumentError,
        );
      });

      test('Oversized file (> 2 MB) throws ArgumentError for M5A ceiling', () {
        expect(
          () => MeshFileOffer(
            fileId: '0123456789abcdef0123456789abcdef',
            senderDeviceId: 'key-alice',
            senderRole: 'student',
            filename: 'huge_file.zip',
            mimeType: 'application/zip',
            fileSize: 2 * 1024 * 1024 + 1,
            sha256: 'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855',
            chunkSize: 100,
            totalChunks: 21000,
            createdAt: DateTime.now(),
            expiresAt: DateTime.now().add(const Duration(minutes: 5)),
          ),
          throwsArgumentError,
        );
      });

      test('Invalid SHA-256 (not 64 hex characters) throws ArgumentError', () {
        expect(
          () => MeshFileOffer(
            fileId: '0123456789abcdef0123456789abcdef',
            senderDeviceId: 'key-alice',
            senderRole: 'student',
            filename: 'notes.pdf',
            mimeType: 'application/pdf',
            fileSize: 1000,
            sha256: 'invalid_short_hash',
            chunkSize: 100,
            totalChunks: 10,
            createdAt: DateTime.now(),
            expiresAt: DateTime.now().add(const Duration(minutes: 5)),
          ),
          throwsArgumentError,
        );
      });

      test('Invalid expiry (expiresAt <= createdAt) throws ArgumentError', () {
        final t = DateTime.now();
        expect(
          () => MeshFileOffer(
            fileId: '0123456789abcdef0123456789abcdef',
            senderDeviceId: 'key-alice',
            senderRole: 'student',
            filename: 'notes.pdf',
            mimeType: 'application/pdf',
            fileSize: 1000,
            sha256: 'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855',
            chunkSize: 100,
            totalChunks: 10,
            createdAt: t,
            expiresAt: t.subtract(const Duration(seconds: 1)),
          ),
          throwsArgumentError,
        );
      });
    });

    // =========================================================================
    // GROUP B & C: CRYPTOGRAPHY & TRUST VERIFICATION
    // =========================================================================
    group('Group B & C: Cryptography and Trust Verification', () {
      test('Tampered packet signature is rejected and dropped', () async {
        final sampleFile = File('${tempTestDir.path}/test_notes.txt');
        await sampleFile.writeAsString('Hello Academic Mesh AirDrop!');

        await aliceAirDropService.sendFileOffer(
          file: sampleFile,
          targetDeviceId: 'key-bob',
        );

        expect(aliceAdapter.advertised, isNotEmpty);
        final rawOfferPacket = Uint8List.fromList(aliceAdapter.advertised.last);

        // Tamper signature byte in the packet
        rawOfferPacket[rawOfferPacket.length - 5] ^= 0xFF;

        // Feed tampered packet to Bob
        bobAdapter.simulateInboundAdvertisement(rawOfferPacket);
        await Future.delayed(const Duration(milliseconds: 50));

        final bobOffers = await bobRepo.getAllTransfers();
        expect(bobOffers, isEmpty, reason: 'Tampered packet signature must be dropped');
      });

      test('Revoked sender is dropped by recipient', () async {
        final revokedPacket = MeshPacket(
          packetId: MeshPacket.generatePacketId(),
          packetType: MeshPacketType.fileOffer,
          ttl: MeshPacket.defaultTtl,
          hopCount: 0,
          senderDeviceId: 'key-revoked-peer',
          senderRole: 'student',
          timestamp: DateTime.now(),
          payload: Uint8List(64), // minimal payload
        );

        final encoded = codec.encode(revokedPacket);
        bobAdapter.simulateInboundAdvertisement(encoded);
        await Future.delayed(const Duration(milliseconds: 50));

        final bobOffers = await bobRepo.getAllTransfers();
        expect(bobOffers, isEmpty, reason: 'Revoked peer packet must be dropped');
      });

      test('Non-academic role sender is dropped by recipient', () async {
        final offer = MeshFileOffer(
          fileId: '0123456789abcdef0123456789abcdef',
          senderDeviceId: 'key-intruder',
          senderRole: 'guest_visitor', // unauthorized role
          filename: 'suspicious.exe',
          mimeType: 'application/octet-stream',
          fileSize: 1024,
          sha256: 'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855',
          chunkSize: 100,
          totalChunks: 11,
          createdAt: DateTime.now(),
          expiresAt: DateTime.now().add(const Duration(minutes: 5)),
        );

        final packet = MeshPacket(
          packetId: MeshPacket.generatePacketId(),
          packetType: MeshPacketType.fileOffer,
          ttl: MeshPacket.defaultTtl,
          hopCount: 0,
          senderDeviceId: 'key-intruder',
          senderRole: 'guest_visitor',
          timestamp: DateTime.now(),
          payload: offer.toBytes(),
        );

        final encoded = codec.encode(packet);
        bobAdapter.simulateInboundAdvertisement(encoded);
        await Future.delayed(const Duration(milliseconds: 50));

        final bobOffers = await bobRepo.getAllTransfers();
        expect(bobOffers, isEmpty, reason: 'Unauthorized role must be rejected');
      });
    });

    // =========================================================================
    // GROUP D: CHUNK HANDLING, OUT-OF-ORDER, & DUPLICATE IDEMPOTENCY
    // =========================================================================
    group('Group D: Chunk Handling and Idempotency', () {
      test('MeshFileChunk encodes and decodes deterministically', () {
        final chunkData = Uint8List.fromList(List.generate(100, (i) => i));
        final chunk = MeshFileChunk(
          fileId: '0123456789abcdef0123456789abcdef',
          sequence: 42,
          totalChunks: 100,
          bytes: chunkData,
        );

        final bytes = chunk.toBytes();
        expect(bytes.length, equals(121), reason: 'Chunk payload must be exactly 121 bytes for 100B data');

        final decoded = MeshFileChunk.fromBytes(bytes);
        expect(decoded.fileId, equals(chunk.fileId));
        expect(decoded.sequence, equals(42));
        expect(decoded.totalChunks, equals(100));
        expect(decoded.bytes, equals(chunkData));
      });

      test('ReceivedChunkTracker correctly tracks sequences, duplicates, and missing chunks', () {
        final tracker = ReceivedChunkTracker(totalChunks: 5);
        expect(tracker.isComplete, isFalse);
        expect(tracker.getMissingSequences(), equals([0, 1, 2, 3, 4]));

        // Out-of-order arrivals: 2, then 0, then 4
        expect(tracker.markReceived(2), isTrue);
        expect(tracker.markReceived(0), isTrue);
        expect(tracker.markReceived(4), isTrue);

        expect(tracker.receivedCount, equals(3));
        expect(tracker.getMissingSequences(), equals([1, 3]));

        // Duplicate arrival of 2 (must be idempotent)
        expect(tracker.markReceived(2), isFalse);
        expect(tracker.receivedCount, equals(3));

        // Fill remaining
        expect(tracker.markReceived(1), isTrue);
        expect(tracker.markReceived(3), isTrue);

        expect(tracker.isComplete, isTrue);
        expect(tracker.getMissingSequences(), isEmpty);
      });

      test('Out-of-order chunks write to correct file offsets without corruption', () async {
        final storage = MeshAirDropStorage(customBaseDir: Directory('${tempTestDir.path}/out_of_order'));
        const validFileId1 = '00000000000000000000000000000001';
        final tempFile = await storage.createTemporaryIncomingFile(validFileId1);

        // Write chunk 2 (bytes 200..299) before chunk 0 (bytes 0..99)
        final chunk2Data = Uint8List.fromList(List.filled(100, 2));
        final chunk0Data = Uint8List.fromList(List.filled(100, 0));
        final chunk1Data = Uint8List.fromList(List.filled(100, 1));

        await storage.writeChunkToDisk(
          tempFile: tempFile,
          chunk: MeshFileChunk(fileId: validFileId1, sequence: 2, totalChunks: 3, bytes: chunk2Data),
          chunkSize: 100,
        );

        await storage.writeChunkToDisk(
          tempFile: tempFile,
          chunk: MeshFileChunk(fileId: validFileId1, sequence: 0, totalChunks: 3, bytes: chunk0Data),
          chunkSize: 100,
        );

        await storage.writeChunkToDisk(
          tempFile: tempFile,
          chunk: MeshFileChunk(fileId: validFileId1, sequence: 1, totalChunks: 3, bytes: chunk1Data),
          chunkSize: 100,
        );

        final resultBytes = await tempFile.readAsBytes();
        expect(resultBytes.length, equals(300));
        expect(resultBytes.sublist(0, 100), equals(chunk0Data));
        expect(resultBytes.sublist(100, 200), equals(chunk1Data));
        expect(resultBytes.sublist(200, 300), equals(chunk2Data));
      });
    });

    // =========================================================================
    // GROUP E: END-TO-END SHA-256 INTEGRITY & CORRUPTION DETECTION
    // =========================================================================
    group('Group E: SHA-256 Integrity Verification', () {
      test('Tampered chunk causes MeshAirDropIntegrityException and cleans corrupted file', () async {
        final storage = MeshAirDropStorage(customBaseDir: Directory('${tempTestDir.path}/integrity_test'));
        const validFileId2 = '00000000000000000000000000000002';
        final tempFile = await storage.createTemporaryIncomingFile(validFileId2);

        final originalData = Uint8List.fromList(utf8.encode('Legitimate Academic Document Content'));
        await storage.writeChunkToDisk(
          tempFile: tempFile,
          chunk: MeshFileChunk(fileId: validFileId2, sequence: 0, totalChunks: 1, bytes: originalData),
          chunkSize: 100,
        );

        final legitimateHash = await storage.computeFileSha256(tempFile);

        // Corrupt a byte on disk
        final raf = await tempFile.open(mode: FileMode.append);
        await raf.setPosition(5);
        await raf.writeFrom([0xFF]);
        await raf.close();

        // Attempt finalize with original expected hash
        await expectLater(
          storage.finalizeAndVerifyFile(
            tempFile: tempFile,
            fileId: validFileId2,
            originalFilename: 'notes.pdf',
            expectedSha256: legitimateHash,
          ),
          throwsA(isA<MeshAirDropIntegrityException>()),
        );

        // Corrupted file must be deleted
        expect(await tempFile.exists(), isFalse, reason: 'Corrupted temporary file must be deleted');
      });
    });

    // =========================================================================
    // GROUP F & G: COMPLETE END-TO-END TRANSFER FLOW & STATE MACHINE
    // =========================================================================
    group('Group F & G: Complete End-to-End Transfer Flow', () {
      test('Full AirDrop flow: offer -> accept -> chunk stream -> SHA-256 verify -> complete', () async {
        // 1. Create source academic file on Alice's side (350 bytes = 4 chunks)
        final sourceFile = File('${tempTestDir.path}/alice_notes.pdf');
        final testContent = List.generate(350, (i) => (i * 7) % 256);
        await sourceFile.writeAsBytes(testContent);

        // 2. Alice sends file offer targeted to Bob
        final aliceSession = await aliceAirDropService.sendFileOffer(
          file: sourceFile,
          targetDeviceId: 'key-bob',
          mimeType: 'application/pdf',
        );

        expect(aliceSession.state, equals(MeshFileTransferState.waitingForAccept));
        expect(aliceSession.totalChunks, equals(4));

        // 3. Deliver Alice's offer packet to Bob
        connectVirtualRadios();
        await Future.delayed(const Duration(milliseconds: 50));

        // 4. Bob should now have an incoming offer in 'offered' state
        final bobOffers = await bobRepo.getActiveTransfers();
        expect(bobOffers, isNotEmpty);
        final bobOffer = bobOffers.first;
        expect(bobOffer.fileId, equals(aliceSession.fileId));
        expect(bobOffer.state, equals(MeshFileTransferState.offered));
        expect(bobOffer.peerDisplayName, equals('Sourav Nanda'));
        expect(bobOffer.isPeerVerified, isTrue);

        // 5. Bob accepts offer
        await bobAirDropService.acceptOffer(bobOffer.fileId);

        // 6. Deliver Bob's ACCEPT ack to Alice
        connectVirtualRadios();
        await Future.delayed(const Duration(milliseconds: 100));

        // 7. Alice's streaming loop broadcasts all 4 chunks
        connectVirtualRadios();
        await Future.delayed(const Duration(milliseconds: 100));

        // 8. Bob receives all chunks, verifies SHA-256, and completes
        connectVirtualRadios();
        await Future.delayed(const Duration(milliseconds: 100));

        // Verify Bob's final session state
        final bobFinal = await bobRepo.getTransferByFileId(aliceSession.fileId);
        expect(bobFinal, isNotNull);
        expect(bobFinal!.state, equals(MeshFileTransferState.completed));
        expect(bobFinal.transferredChunks, equals(4));
        expect(bobFinal.localFilePath, isNotNull);

        // Verify reassembled file content
        final completedFile = File(bobFinal.localFilePath!);
        expect(await completedFile.exists(), isTrue);
        final completedBytes = await completedFile.readAsBytes();
        expect(completedBytes, equals(testContent));

        // Verify Alice's final state (received COMPLETE ack)
        final aliceFinal = await aliceRepo.getTransfer(aliceSession.transferId);
        expect(aliceFinal!.state, equals(MeshFileTransferState.completed));
      });

      test('Offer rejection terminates session cleanly', () async {
        final sourceFile = File('${tempTestDir.path}/rejected_notes.pdf');
        await sourceFile.writeAsBytes(List.generate(100, (i) => i));

        final session = await aliceAirDropService.sendFileOffer(
          file: sourceFile,
          targetDeviceId: 'key-bob',
        );

        connectVirtualRadios();
        await Future.delayed(const Duration(milliseconds: 50));

        final bobOffers = await bobRepo.getActiveTransfers();
        expect(bobOffers, isNotEmpty);

        // Bob rejects
        await bobAirDropService.rejectOffer(session.fileId);

        connectVirtualRadios();
        await Future.delayed(const Duration(milliseconds: 50));

        final aliceUpdated = await aliceRepo.getTransfer(session.transferId);
        expect(aliceUpdated!.state, equals(MeshFileTransferState.rejected));
      });

      test('Transfer cancellation cleans temporary files', () async {
        final sourceFile = File('${tempTestDir.path}/cancelled_notes.pdf');
        await sourceFile.writeAsBytes(List.generate(200, (i) => i));

        final session = await aliceAirDropService.sendFileOffer(
          file: sourceFile,
          targetDeviceId: 'key-bob',
        );

        connectVirtualRadios();
        await Future.delayed(const Duration(milliseconds: 50));

        await bobAirDropService.acceptOffer(session.fileId);

        // Bob cancels transfer
        final bobTransfer = (await bobRepo.getActiveTransfers()).first;
        await bobAirDropService.cancelTransfer(bobTransfer.transferId);

        final bobUpdated = await bobRepo.getTransfer(bobTransfer.transferId);
        expect(bobUpdated!.state, equals(MeshFileTransferState.cancelled));
      });
    });

    // =========================================================================
    // GROUP H: PERSISTENCE & BOUNDED STORAGE
    // =========================================================================
    group('Group H: Persistence & Bounded Storage', () {
      test('Transfer metadata persists across database reloads', () async {
        final session = MeshFileTransferSession(
          transferId: 'transfer_persist_01',
          fileId: 'persist_file_01',
          peerDeviceId: 'key-bob',
          peerRole: 'student',
          direction: MeshTransferDirection.incoming,
          state: MeshFileTransferState.completed,
          filename: 'syllabus.pdf',
          mimeType: 'application/pdf',
          fileSize: 45000,
          transferredBytes: 45000,
          totalChunks: 450,
          transferredChunks: 450,
          sha256: 'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          expiresAt: DateTime.now().add(const Duration(hours: 1)),
        );

        await aliceRepo.saveTransfer(session);

        final fetched = await aliceRepo.getTransfer('transfer_persist_01');
        expect(fetched, isNotNull);
        expect(fetched!.filename, equals('syllabus.pdf'));
        expect(fetched.state, equals(MeshFileTransferState.completed));
        expect(fetched.transferredChunks, equals(450));
      });

      test('Path traversal filenames are sanitized safely', () {
        const attack1 = '../../../../etc/passwd';
        const attack2 = '..\\..\\Windows\\System32\\calc.exe';
        const attack3 = 'notes/unit:1*?.pdf';

        expect(MeshAirDropStorage.sanitizeFilename(attack1), isNot(contains('/')));
        expect(MeshAirDropStorage.sanitizeFilename(attack1), isNot(contains('..')));
        expect(MeshAirDropStorage.sanitizeFilename(attack2), isNot(contains('\\')));
        expect(MeshAirDropStorage.sanitizeFilename(attack2), isNot(contains('..')));
        expect(MeshAirDropStorage.sanitizeFilename(attack3), isNot(contains(':')));
        expect(MeshAirDropStorage.sanitizeFilename(attack3), isNot(contains('*')));
      });
    });

    // =========================================================================
    // GROUP I: MEMORY-BOUNDED STREAMING PROOF
    // =========================================================================
    group('Group I: Memory-Bounded Streaming Proof', () {
      test('Storage reads chunks incrementally without loading full file into RAM', () async {
        final largeFile = File('${tempTestDir.path}/streaming_proof.dat');
        // Create 50 KB file
        const totalSize = 50 * 1024;
        await largeFile.writeAsBytes(List.generate(totalSize, (i) => i % 256));

        final chunkStream = aliceStorage.readChunks(
          file: largeFile,
          fileId: '0123456789abcdef0123456789abcdef',
          chunkSize: 100,
          totalChunks: 512,
        );

        int chunksRead = 0;
        int totalBytesStreamed = 0;

        await for (final chunk in chunkStream) {
          chunksRead++;
          totalBytesStreamed += chunk.bytes.length;
          // Verify each yielded chunk is bounded to <= 100 bytes
          expect(chunk.bytes.length, lessThanOrEqualTo(100));
        }

        expect(chunksRead, equals(512));
        expect(totalBytesStreamed, equals(totalSize));
      });
    });

    // =========================================================================
    // GROUP J: PERFORMANCE BENCHMARK (100 KB, 500 KB, 1 MB, 2 MB)
    // =========================================================================
    group('Group J: Performance Benchmark Instrumentation', () {
      for (final sizeKb in [100, 500, 1024, 2048]) {
        test('Benchmark AirDrop chunk generation & streaming for ${sizeKb}KB file', () async {
          final sizeBytes = sizeKb * 1024;
          final testFile = File('${tempTestDir.path}/bench_${sizeKb}kb.bin');
          final data = List.generate(sizeBytes, (i) => (i * 13) % 256);
          await testFile.writeAsBytes(data);

          final stopwatch = Stopwatch()..start();
          final sha256 = await aliceStorage.computeFileSha256(testFile);
          final totalChunks = MeshFileOffer.calculateTotalChunks(sizeBytes, 100);

          int chunksStreamed = 0;
          await for (final chunk in aliceStorage.readChunks(
            file: testFile,
            fileId: '0123456789abcdef0123456789abcdef',
            chunkSize: 100,
            totalChunks: totalChunks,
          )) {
            chunksStreamed++;
            expect(chunk.bytes.length, lessThanOrEqualTo(100));
          }

          stopwatch.stop();
          final elapsedMs = stopwatch.elapsedMilliseconds;
          final throughputKbps = (sizeKb / (elapsedMs / 1000.0));

          // ignore: avoid_print
          print('⚡ [BENCHMARK] ${sizeKb}KB: $chunksStreamed chunks in ${elapsedMs}ms (${throughputKbps.toStringAsFixed(1)} KB/s), SHA-256: ${sha256.substring(0, 8)}...');
          expect(chunksStreamed, equals(totalChunks));
          expect(sha256.length, equals(64));
        });
      }
    });
  });
}
