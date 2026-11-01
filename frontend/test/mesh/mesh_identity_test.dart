import 'dart:convert';
import 'dart:typed_data';
import 'package:cryptography/cryptography.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:attendance_app/core/mesh/campus_mesh_service.dart';
import 'package:attendance_app/core/mesh/mesh_crypto.dart';
import 'package:attendance_app/core/mesh/mesh_deduplication_store.dart';
import 'package:attendance_app/core/mesh/mesh_packet.dart';
import 'package:attendance_app/core/mesh/mesh_packet_codec.dart';
import 'package:attendance_app/core/mesh/mesh_peer_registry.dart';
import 'package:attendance_app/core/mesh/mesh_relay_engine.dart';
import 'package:attendance_app/student/models/passport_trust_bundle_model.dart';

/// Test BLE adapter for end-to-end integration tests.
class IdentityTestBleAdapter implements MeshBleAdapter {
  final List<Uint8List> advertised = [];
  void Function(Uint8List rawBytes, int rssi)? onPacketDiscovered;

  @override
  Future<bool> isBluetoothAvailable() async => true;

  @override
  Future<bool> requestPermissions() async => true;

  @override
  Future<bool> startScanning({
    required void Function(Uint8List rawBytes, int rssi) onPacketDiscovered,
  }) async {
    this.onPacketDiscovered = onPacketDiscovered;
    return true;
  }

  @override
  Future<void> stopScanning() async {
    onPacketDiscovered = null;
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
}

void main() {
  group('CampusOS Mesh — Phase M2: Cryptographic Identity & Trust Tests', () {
    late Ed25519 algorithm;
    late SimpleKeyPair rootKeyPair;
    late SimpleKeyPair studentKeyPair;
    late SimpleKeyPair adminKeyPair;
    late SimpleKeyPair expiredKeyPair;
    late SimpleKeyPair revokedKeyPair;

    late SimplePublicKey studentPubKey;
    late SimplePublicKey adminPubKey;
    late SimplePublicKey expiredPubKey;
    late SimplePublicKey revokedPubKey;

    late PassportTrustBundle trustBundle;
    late CampusMeshCryptoService studentCryptoService;
    late CampusMeshCryptoService adminCryptoService;
    late CampusMeshCryptoService verifierCryptoService;

    final now = DateTime.now();
    final nowSec = now.toUtc().millisecondsSinceEpoch ~/ 1000;

    setUpAll(() async {
      algorithm = Ed25519();
      rootKeyPair = await algorithm.newKeyPair();
      studentKeyPair = await algorithm.newKeyPair();
      adminKeyPair = await algorithm.newKeyPair();
      expiredKeyPair = await algorithm.newKeyPair();
      revokedKeyPair = await algorithm.newKeyPair();

      final rootPubKey = await rootKeyPair.extractPublicKey();
      studentPubKey = await studentKeyPair.extractPublicKey();
      adminPubKey = await adminKeyPair.extractPublicKey();
      expiredPubKey = await expiredKeyPair.extractPublicKey();
      revokedPubKey = await revokedKeyPair.extractPublicKey();

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
            keyId: 'key-student-alice',
            userId: 'student_alice',
            publicKey: base64Encode(studentPubKey.bytes),
            certificateId: 'cert-student-001',
            issuerKeyId: 'campusos-root-test',
            validFrom: nowSec - 3600,
            validTo: nowSec + 86400,
            status: 'ACTIVE',
            userName: 'Alice Student',
          ),
          PassportTrustIdentity(
            keyId: 'key-admin-dean',
            userId: 'admin_dean',
            publicKey: base64Encode(adminPubKey.bytes),
            certificateId: 'cert-admin-001',
            issuerKeyId: 'campusos-root-test',
            validFrom: nowSec - 3600,
            validTo: nowSec + 86400,
            status: 'ACTIVE',
            userName: 'Dean Academic Affairs',
          ),
          PassportTrustIdentity(
            keyId: 'key-expired-charlie',
            userId: 'student_expired',
            publicKey: base64Encode(expiredPubKey.bytes),
            certificateId: 'cert-expired-001',
            issuerKeyId: 'campusos-root-test',
            validFrom: nowSec - 7200,
            validTo: nowSec - 1800, // Expired 30m ago
            status: 'ACTIVE',
            userName: 'Charlie Expired',
          ),
          PassportTrustIdentity(
            keyId: 'key-revoked-eve',
            userId: 'student_revoked',
            publicKey: base64Encode(revokedPubKey.bytes),
            certificateId: 'cert-revoked-001',
            issuerKeyId: 'campusos-root-test',
            validFrom: nowSec - 3600,
            validTo: nowSec + 86400,
            status: 'REVOKED',
            userName: 'Eve Malicious',
          ),
        ],
        revokedKeyIds: const ['key-revoked-eve'],
        signature: 'dummy_institutional_signature',
        rawPayload: const {},
      );

      studentCryptoService = CampusMeshCryptoService(
        algorithm: algorithm,
        localKeyPair: studentKeyPair,
        mockTrustBundle: trustBundle,
      );

      adminCryptoService = CampusMeshCryptoService(
        algorithm: algorithm,
        localKeyPair: adminKeyPair,
        mockTrustBundle: trustBundle,
      );

      verifierCryptoService = CampusMeshCryptoService(
        algorithm: algorithm,
        mockTrustBundle: trustBundle,
      );
    });

    test('TEST 1: Valid Ed25519 signature resolves to trusted result with certified metadata', () async {
      final packet = MeshPacket(
        packetId: MeshPacket.generatePacketId(),
        packetType: MeshPacketType.chat,
        senderDeviceId: 'student_alice',
        senderRole: 'student',
        timestamp: DateTime.now(),
        payload: Uint8List.fromList([1, 2, 3, 4]),
      );

      final signedPacket = await studentCryptoService.signPacket(packet);
      expect(signedPacket.signature.length, equals(64));

      final result = await verifierCryptoService.verifyPacket(signedPacket);

      expect(result.status, equals(MeshVerificationStatus.trusted));
      expect(result.isTrusted, isTrue);
      expect(result.senderUserId, equals('student_alice'));
      expect(result.senderName, equals('Alice Student'));
      expect(result.senderKeyId, equals('key-student-alice'));
    });

    test('TEST 2: Modified payload yields invalidSignature', () async {
      final packet = MeshPacket(
        packetId: MeshPacket.generatePacketId(),
        packetType: MeshPacketType.chat,
        senderDeviceId: 'student_alice',
        senderRole: 'student',
        timestamp: DateTime.now(),
        payload: Uint8List.fromList([10, 20, 30]),
      );

      final signedPacket = await studentCryptoService.signPacket(packet);

      // Tamper with payload
      final tampered = signedPacket.copyWith(
        payload: Uint8List.fromList([10, 20, 99]),
      );

      final result = await verifierCryptoService.verifyPacket(tampered);
      expect(result.status, equals(MeshVerificationStatus.invalidSignature));
      expect(result.isTrusted, isFalse);
    });

    test('TEST 3: Modified sender identity yields invalidSignature', () async {
      final packet = MeshPacket(
        packetId: MeshPacket.generatePacketId(),
        packetType: MeshPacketType.chat,
        senderDeviceId: 'student_alice',
        senderRole: 'student',
        timestamp: DateTime.now(),
        payload: Uint8List.fromList([5, 6, 7]),
      );

      final signedPacket = await studentCryptoService.signPacket(packet);

      // Impersonate admin without admin signature
      final impersonated = signedPacket.copyWith(
        senderDeviceId: 'admin_dean',
        senderRole: 'admin',
      );

      final result = await verifierCryptoService.verifyPacket(impersonated);
      expect(result.status, equals(MeshVerificationStatus.invalidSignature));
      expect(result.isTrusted, isFalse);
    });

    test('TEST 4: Modified packet ID yields invalidSignature', () async {
      final packet = MeshPacket(
        packetId: MeshPacket.generatePacketId(),
        packetType: MeshPacketType.chat,
        senderDeviceId: 'student_alice',
        senderRole: 'student',
        timestamp: DateTime.now(),
        payload: Uint8List.fromList([1, 1, 1]),
      );

      final signedPacket = await studentCryptoService.signPacket(packet);

      final modifiedId = Uint8List.fromList(signedPacket.packetId);
      modifiedId[0] ^= 0xFF; // Flip bits

      final tampered = signedPacket.copyWith(packetId: modifiedId);
      final result = await verifierCryptoService.verifyPacket(tampered);

      expect(result.status, equals(MeshVerificationStatus.invalidSignature));
    });

    test('TEST 5: Modified packet type yields invalidSignature', () async {
      final packet = MeshPacket(
        packetId: MeshPacket.generatePacketId(),
        packetType: MeshPacketType.chat,
        senderDeviceId: 'student_alice',
        senderRole: 'student',
        timestamp: DateTime.now(),
        payload: Uint8List.fromList([2, 2, 2]),
      );

      final signedPacket = await studentCryptoService.signPacket(packet);

      final tampered = signedPacket.copyWith(packetType: MeshPacketType.fileOffer);
      final result = await verifierCryptoService.verifyPacket(tampered);

      expect(result.status, equals(MeshVerificationStatus.invalidSignature));
    });

    test('TEST 6: Modified timestamp yields invalidSignature', () async {
      final packet = MeshPacket(
        packetId: MeshPacket.generatePacketId(),
        packetType: MeshPacketType.chat,
        senderDeviceId: 'student_alice',
        senderRole: 'student',
        timestamp: DateTime.now(),
        payload: Uint8List.fromList([3, 3, 3]),
      );

      final signedPacket = await studentCryptoService.signPacket(packet);

      final tampered = signedPacket.copyWith(
        timestamp: packet.timestamp.add(const Duration(seconds: 10)),
      );
      final result = await verifierCryptoService.verifyPacket(tampered);

      expect(result.status, equals(MeshVerificationStatus.invalidSignature));
    });

    test('TEST 7: Invalid signature bytes yield invalidSignature', () async {
      final packet = MeshPacket(
        packetId: MeshPacket.generatePacketId(),
        packetType: MeshPacketType.chat,
        senderDeviceId: 'student_alice',
        senderRole: 'student',
        timestamp: DateTime.now(),
        payload: Uint8List.fromList([4, 4, 4]),
        signature: Uint8List(64), // all zero signature
      );

      final result = await verifierCryptoService.verifyPacket(packet);
      expect(result.status, equals(MeshVerificationStatus.invalidSignature));
    });

    test('TEST 8: Unknown sender not in trust bundle yields unknownSender', () async {
      final foreignKeyPair = await algorithm.newKeyPair();
      final foreignService = CampusMeshCryptoService(
        algorithm: algorithm,
        localKeyPair: foreignKeyPair,
        mockTrustBundle: trustBundle,
      );

      final packet = MeshPacket(
        packetId: MeshPacket.generatePacketId(),
        packetType: MeshPacketType.chat,
        senderDeviceId: 'unknown_rogue_device',
        senderRole: 'student',
        timestamp: DateTime.now(),
        payload: Uint8List.fromList([9, 9, 9]),
      );

      final signedPacket = await foreignService.signPacket(packet);
      final result = await verifierCryptoService.verifyPacket(signedPacket);

      expect(result.status, equals(MeshVerificationStatus.unknownSender));
      expect(result.isTrusted, isFalse);
    });

    test('TEST 9: Expired trust entry yields expiredTrust', () async {
      final expiredService = CampusMeshCryptoService(
        algorithm: algorithm,
        localKeyPair: expiredKeyPair,
        mockTrustBundle: trustBundle,
      );

      final packet = MeshPacket(
        packetId: MeshPacket.generatePacketId(),
        packetType: MeshPacketType.chat,
        senderDeviceId: 'student_expired',
        senderRole: 'student',
        timestamp: DateTime.now(),
        payload: Uint8List.fromList([1]),
      );

      final signedPacket = await expiredService.signPacket(packet);
      final result = await verifierCryptoService.verifyPacket(signedPacket);

      expect(result.status, equals(MeshVerificationStatus.expiredTrust));
      expect(result.isTrusted, isFalse);
    });

    test('TEST 10: Stale packet outside clock skew is rejected with staleTimestamp', () async {
      final oldTime = DateTime.now().subtract(const Duration(minutes: 15));
      final packet = MeshPacket(
        packetId: MeshPacket.generatePacketId(),
        packetType: MeshPacketType.chat,
        senderDeviceId: 'student_alice',
        senderRole: 'student',
        timestamp: oldTime,
        payload: Uint8List.fromList([1, 2]),
      );

      final signedPacket = await studentCryptoService.signPacket(packet);
      final result = await verifierCryptoService.verifyPacket(signedPacket);

      expect(result.status, equals(MeshVerificationStatus.staleTimestamp));
      expect(result.isTrusted, isFalse);
    });

    test('TEST 11: Replayed packet ID is rejected by deduplication store', () {
      final dedupStore = MeshDeduplicationStore(maxSize: 50);
      final packetId = MeshPacket.generatePacketId();

      expect(dedupStore.contains(packetId), isFalse);
      expect(dedupStore.add(packetId), isTrue);

      // Replay attempt
      expect(dedupStore.contains(packetId), isTrue);
      expect(dedupStore.add(packetId), isFalse); // Replay suppressed
    });

    test('TEST 12: Private key never appears in serialized packet or logs', () async {
      final packet = MeshPacket(
        packetId: MeshPacket.generatePacketId(),
        packetType: MeshPacketType.chat,
        senderDeviceId: 'student_alice',
        senderRole: 'student',
        timestamp: DateTime.now(),
        payload: Uint8List.fromList([42]),
      );

      final signedPacket = await studentCryptoService.signPacket(packet);
      const codec = MeshPacketCodec();
      final encoded = codec.encode(signedPacket);

      // Extract raw private key bytes
      final privKeyBytes = await studentKeyPair.extractPrivateKeyBytes();
      final privKeyHex = privKeyBytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
      final privKeyB64 = base64Encode(privKeyBytes);

      // Serialized binary bytes check
      final encodedHex = encoded.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
      expect(encodedHex.contains(privKeyHex), isFalse);

      // String representation check
      final stringRepresentation = signedPacket.toString();
      expect(stringRepresentation.contains(privKeyHex), isFalse);
      expect(stringRepresentation.contains(privKeyB64), isFalse);
    });

    test('TEST 13: Signing does not mutate original packet fields unexpectedly', () async {
      final packet = MeshPacket(
        packetId: MeshPacket.generatePacketId(),
        packetType: MeshPacketType.chat,
        senderDeviceId: 'student_alice',
        senderRole: 'student',
        timestamp: DateTime.now(),
        payload: Uint8List.fromList([10, 20, 30]),
      );

      final signedPacket = await studentCryptoService.signPacket(packet);

      expect(signedPacket.packetId, equals(packet.packetId));
      expect(signedPacket.packetType, equals(packet.packetType));
      expect(signedPacket.ttl, equals(packet.ttl));
      expect(signedPacket.hopCount, equals(packet.hopCount));
      expect(signedPacket.senderDeviceId, equals(packet.senderDeviceId));
      expect(signedPacket.senderRole, equals(packet.senderRole));
      expect(signedPacket.timestamp, equals(packet.timestamp));
      expect(signedPacket.payload, equals(packet.payload));
      expect(signedPacket.signature.length, equals(64));
    });

    test('TEST 14: Verification succeeds after serialization and deserialization', () async {
      final packet = MeshPacket(
        packetId: MeshPacket.generatePacketId(),
        packetType: MeshPacketType.chat,
        senderDeviceId: 'student_alice',
        senderRole: 'student',
        timestamp: DateTime.now(),
        payload: Uint8List.fromList([7, 14, 21]),
      );

      final signed = await studentCryptoService.signPacket(packet);

      const codec = MeshPacketCodec();
      final serialized = codec.encode(signed);
      final deserialized = codec.decode(serialized);

      expect(deserialized, equals(signed));

      final result = await verifierCryptoService.verifyPacket(deserialized);
      expect(result.status, equals(MeshVerificationStatus.trusted));
    });

    test('TEST 15: Relay behavior preserves end-to-end authentication model (Approach A)', () async {
      final originatorPacket = MeshPacket(
        packetId: MeshPacket.generatePacketId(),
        packetType: MeshPacketType.chat,
        ttl: 7,
        hopCount: 0,
        senderDeviceId: 'student_alice',
        senderRole: 'student',
        timestamp: DateTime.now(),
        payload: Uint8List.fromList([8, 16, 32]),
      );

      final signedOriginator = await studentCryptoService.signPacket(originatorPacket);

      // Verify origin packet
      final originResult = await verifierCryptoService.verifyPacket(signedOriginator);
      expect(originResult.status, equals(MeshVerificationStatus.trusted));

      // Simulate Hop 1 Relay (TTL decremented to 6, hopCount incremented to 1)
      final hop1Packet = signedOriginator.copyWith(
        ttl: 6,
        hopCount: 1,
      );

      // Verify at Hop 1 node without needing a relay signature
      final hop1Result = await verifierCryptoService.verifyPacket(hop1Packet);
      expect(hop1Result.status, equals(MeshVerificationStatus.trusted));

      // Simulate Hop 2 Relay (TTL decremented to 5, hopCount incremented to 2)
      final hop2Packet = signedOriginator.copyWith(
        ttl: 5,
        hopCount: 2,
      );
      final hop2Result = await verifierCryptoService.verifyPacket(hop2Packet);
      expect(hop2Result.status, equals(MeshVerificationStatus.trusted));

      // If an attacker tampers with TTL (e.g. changing TTL to 10 without matching hopCount)
      final tamperedTtlPacket = hop1Packet.copyWith(ttl: 10);
      final tamperedResult = await verifierCryptoService.verifyPacket(tamperedTtlPacket);
      expect(tamperedResult.status, equals(MeshVerificationStatus.invalidSignature));
    });

    test('TEST 16: Unauthorized emergency-originating role is rejected', () async {
      // Student attempting to originate emergency alert
      final studentEmergency = MeshPacket(
        packetId: MeshPacket.generatePacketId(),
        packetType: MeshPacketType.emergency,
        senderDeviceId: 'student_alice',
        senderRole: 'student',
        timestamp: DateTime.now(),
        payload: Uint8List.fromList([99, 99]),
      );

      final signedStudentEmergency = await studentCryptoService.signPacket(studentEmergency);
      final studentResult = await verifierCryptoService.verifyPacket(signedStudentEmergency);

      expect(studentResult.status, equals(MeshVerificationStatus.unauthorizedRole));
      expect(studentResult.isTrusted, isFalse);

      // Admin Dean originating emergency alert
      final adminEmergency = MeshPacket(
        packetId: MeshPacket.generatePacketId(),
        packetType: MeshPacketType.emergency,
        senderDeviceId: 'admin_dean',
        senderRole: 'admin',
        timestamp: DateTime.now(),
        payload: Uint8List.fromList([1, 1, 1]),
      );

      final signedAdminEmergency = await adminCryptoService.signPacket(adminEmergency);
      final adminResult = await verifierCryptoService.verifyPacket(signedAdminEmergency);

      expect(adminResult.status, equals(MeshVerificationStatus.trusted));
      expect(adminResult.isTrusted, isTrue);
    });

    test('TEST 17: Revoked key is rejected with revokedSender status', () async {
      final revokedService = CampusMeshCryptoService(
        algorithm: algorithm,
        localKeyPair: revokedKeyPair,
        mockTrustBundle: trustBundle,
      );

      final packet = MeshPacket(
        packetId: MeshPacket.generatePacketId(),
        packetType: MeshPacketType.chat,
        senderDeviceId: 'student_revoked',
        senderRole: 'student',
        timestamp: DateTime.now(),
        payload: Uint8List.fromList([1, 2, 3]),
      );

      final signedPacket = await revokedService.signPacket(packet);
      final result = await verifierCryptoService.verifyPacket(signedPacket);

      expect(result.status, equals(MeshVerificationStatus.revokedSender));
      expect(result.isTrusted, isFalse);
    });

    test('TEST 18: CampusMeshService integrates cryptoService to drop unverified inbound packets', () async {
      final fakeAdapter = IdentityTestBleAdapter();
      final dedupStore = MeshDeduplicationStore(maxSize: 50);
      final peerRegistry = MeshPeerRegistry();
      final relayEngine = MeshRelayEngine(
        localDeviceId: 'local_verifier_node',
        deduplicationStore: dedupStore,
      );

      final meshService = CampusMeshService(
        localDeviceId: 'local_verifier_node',
        localRole: 'student',
        adapter: fakeAdapter,
        deduplicationStore: dedupStore,
        peerRegistry: peerRegistry,
        relayEngine: relayEngine,
        cryptoService: verifierCryptoService,
      );

      await meshService.start();

      final receivedPackets = <MeshPacket>[];
      meshService.receivedPackets.listen(receivedPackets.add);

      const codec = MeshPacketCodec();

      // 1. Ingest untrusted packet (invalid signature)
      final invalidPacket = MeshPacket(
        packetId: MeshPacket.generatePacketId(),
        packetType: MeshPacketType.chat,
        senderDeviceId: 'student_alice',
        senderRole: 'student',
        timestamp: DateTime.now(),
        payload: Uint8List.fromList([1]),
        signature: Uint8List(64), // invalid signature
      );
      fakeAdapter.onPacketDiscovered?.call(codec.encode(invalidPacket), -60);

      await pumpEventQueue();
      expect(receivedPackets.isEmpty, isTrue); // Dropped!

      // 2. Ingest trusted packet (valid signature from Alice)
      final validPacket = MeshPacket(
        packetId: MeshPacket.generatePacketId(),
        packetType: MeshPacketType.chat,
        senderDeviceId: 'student_alice',
        senderRole: 'student',
        timestamp: DateTime.now(),
        payload: Uint8List.fromList([42]),
      );
      final signedValid = await studentCryptoService.signPacket(validPacket);
      fakeAdapter.onPacketDiscovered?.call(codec.encode(signedValid), -60);

      await pumpEventQueue();
      expect(receivedPackets.length, equals(1));
      expect(receivedPackets.first.senderDeviceId, equals('student_alice'));

      await meshService.dispose();
    });
  });
}
