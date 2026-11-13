import 'dart:convert';
import 'dart:typed_data';
import 'package:cryptography/cryptography.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:attendance_app/core/mesh/campus_mesh_service.dart';
import 'package:attendance_app/core/mesh/emergency/campus_mesh_emergency_service.dart';
import 'package:attendance_app/core/mesh/emergency/emergency_alert.dart';
import 'package:attendance_app/core/mesh/emergency/emergency_authorization.dart';
import 'package:attendance_app/core/mesh/emergency/emergency_notifier.dart';
import 'package:attendance_app/core/mesh/emergency/mesh_emergency_repository.dart';
import 'package:attendance_app/core/mesh/mesh_crypto.dart';
import 'package:attendance_app/core/mesh/mesh_deduplication_store.dart';
import 'package:attendance_app/core/mesh/mesh_packet.dart';
import 'package:attendance_app/core/mesh/mesh_packet_codec.dart';
import 'package:attendance_app/core/mesh/mesh_peer_registry.dart';
import 'package:attendance_app/core/mesh/mesh_relay_engine.dart';
import 'package:attendance_app/student/models/passport_trust_bundle_model.dart';

import 'campus_mesh_service_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('CampusOS Mesh — Phase M4: Emergency Disaster Flare Tests', () {
    late Ed25519 algorithm;
    late SimpleKeyPair adminKeyPair;
    late SimpleKeyPair deanKeyPair;
    late SimpleKeyPair directorKeyPair;
    late SimpleKeyPair wardenKeyPair;
    late SimpleKeyPair teacherKeyPair;
    late SimpleKeyPair studentKeyPair;
    late SimpleKeyPair revokedKeyPair;

    late PassportTrustBundle trustBundle;
    late CampusMeshCryptoService adminCryptoService;
    late CampusMeshCryptoService deanCryptoService;
    late CampusMeshCryptoService directorCryptoService;
    late CampusMeshCryptoService wardenCryptoService;
    late CampusMeshCryptoService teacherCryptoService;
    late CampusMeshCryptoService studentCryptoService;
    late CampusMeshCryptoService verifierCryptoService;

    final now = DateTime.now();
    final nowSec = now.toUtc().millisecondsSinceEpoch ~/ 1000;

    setUpAll(() async {
      algorithm = Ed25519();
      adminKeyPair = await algorithm.newKeyPair();
      deanKeyPair = await algorithm.newKeyPair();
      directorKeyPair = await algorithm.newKeyPair();
      wardenKeyPair = await algorithm.newKeyPair();
      teacherKeyPair = await algorithm.newKeyPair();
      studentKeyPair = await algorithm.newKeyPair();
      revokedKeyPair = await algorithm.newKeyPair();

      final rootKeyPair = await algorithm.newKeyPair();
      final rootPubKey = await rootKeyPair.extractPublicKey();

      final adminPubKey = await adminKeyPair.extractPublicKey();
      final deanPubKey = await deanKeyPair.extractPublicKey();
      final directorPubKey = await directorKeyPair.extractPublicKey();
      final wardenPubKey = await wardenKeyPair.extractPublicKey();
      final teacherPubKey = await teacherKeyPair.extractPublicKey();
      final studentPubKey = await studentKeyPair.extractPublicKey();
      final revokedPubKey = await revokedKeyPair.extractPublicKey();

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
            keyId: 'key-admin-main',
            userId: 'admin_sys',
            userName: 'System Administrator',
            publicKey: base64Encode(adminPubKey.bytes),
            certificateId: 'cert-admin-01',
            issuerKeyId: 'campusos-root-test',
            validFrom: nowSec - 3600,
            validTo: nowSec + 86400,
            status: 'ACTIVE',
          ),
          PassportTrustIdentity(
            keyId: 'key-dean-01',
            userId: 'dean_official',
            userName: 'Prof. Dean Sharma',
            publicKey: base64Encode(deanPubKey.bytes),
            certificateId: 'cert-dean-01',
            issuerKeyId: 'campusos-root-test',
            validFrom: nowSec - 3600,
            validTo: nowSec + 86400,
            status: 'ACTIVE',
          ),
          PassportTrustIdentity(
            keyId: 'key-director-01',
            userId: 'director_campus',
            userName: 'Dr. Director Patnaik',
            publicKey: base64Encode(directorPubKey.bytes),
            certificateId: 'cert-dir-01',
            issuerKeyId: 'campusos-root-test',
            validFrom: nowSec - 3600,
            validTo: nowSec + 86400,
            status: 'ACTIVE',
          ),
          PassportTrustIdentity(
            keyId: 'key-warden-b',
            userId: 'warden_hostel_b',
            userName: 'Rahul Warden',
            publicKey: base64Encode(wardenPubKey.bytes),
            certificateId: 'cert-warden-b',
            issuerKeyId: 'campusos-root-test',
            validFrom: nowSec - 3600,
            validTo: nowSec + 86400,
            status: 'ACTIVE',
          ),
          PassportTrustIdentity(
            keyId: 'key-teacher-01',
            userId: 'teacher_smith',
            userName: 'Prof. Smith CSE',
            publicKey: base64Encode(teacherPubKey.bytes),
            certificateId: 'cert-teacher-01',
            issuerKeyId: 'campusos-root-test',
            validFrom: nowSec - 3600,
            validTo: nowSec + 86400,
            status: 'ACTIVE',
          ),
          PassportTrustIdentity(
            keyId: 'key-student-alice',
            userId: 'student_alice',
            userName: 'Alice Student',
            publicKey: base64Encode(studentPubKey.bytes),
            certificateId: 'cert-student-alice',
            issuerKeyId: 'campusos-root-test',
            validFrom: nowSec - 3600,
            validTo: nowSec + 86400,
            status: 'ACTIVE',
          ),
          PassportTrustIdentity(
            keyId: 'key-revoked-user',
            userId: 'user_compromised',
            userName: 'Compromised Node',
            publicKey: base64Encode(revokedPubKey.bytes),
            certificateId: 'cert-compromised',
            issuerKeyId: 'campusos-root-test',
            validFrom: nowSec - 3600,
            validTo: nowSec + 86400,
            status: 'REVOKED',
          ),
        ],
        revokedKeyIds: const ['key-revoked-user'],
        signature: 'dummy_institutional_signature',
        rawPayload: const {},
      );

      adminCryptoService = CampusMeshCryptoService(
        algorithm: algorithm,
        localKeyPair: adminKeyPair,
        mockTrustBundle: trustBundle,
      );

      deanCryptoService = CampusMeshCryptoService(
        algorithm: algorithm,
        localKeyPair: deanKeyPair,
        mockTrustBundle: trustBundle,
      );

      directorCryptoService = CampusMeshCryptoService(
        algorithm: algorithm,
        localKeyPair: directorKeyPair,
        mockTrustBundle: trustBundle,
      );

      wardenCryptoService = CampusMeshCryptoService(
        algorithm: algorithm,
        localKeyPair: wardenKeyPair,
        mockTrustBundle: trustBundle,
      );

      teacherCryptoService = CampusMeshCryptoService(
        algorithm: algorithm,
        localKeyPair: teacherKeyPair,
        mockTrustBundle: trustBundle,
      );

      studentCryptoService = CampusMeshCryptoService(
        algorithm: algorithm,
        localKeyPair: studentKeyPair,
        mockTrustBundle: trustBundle,
      );

      verifierCryptoService = CampusMeshCryptoService(
        algorithm: algorithm,
        localKeyPair: null,
        mockTrustBundle: trustBundle,
      );
    });

    // ==========================================
    // A. PAYLOAD VALIDATION
    // ==========================================
    test('A1: Valid emergency payload serializes and deserializes cleanly', () {
      final payload = EmergencyPayload(
        title: 'Cyclone Alert Level 3',
        message: 'Severe storm incoming. Proceed to shelter immediately.',
        scope: EmergencyScope.campus,
        severity: EmergencySeverity.critical,
        category: EmergencyCategory.cyclone,
        priority: EmergencyRelayPriority.critical,
        expiresAt: DateTime.now().add(const Duration(hours: 3)),
        issuerUserId: 'admin_sys',
      );

      final bytes = payload.toBytes();
      expect(bytes.isNotEmpty, isTrue);

      final deserialized = EmergencyPayload.fromBytes(bytes);
      expect(deserialized.title, equals(payload.title));
      expect(deserialized.message, equals(payload.message));
      expect(deserialized.scope, equals(payload.scope));
      expect(deserialized.severity, equals(EmergencySeverity.critical));
      expect(deserialized.category, equals(EmergencyCategory.cyclone));
      expect(deserialized.priority, equals(EmergencyRelayPriority.critical));
      expect(deserialized.issuerUserId, equals('admin_sys'));
    });

    test('A2: Oversized title (> 48 chars) throws ArgumentError', () {
      expect(
        () => EmergencyPayload(
          title: 'A' * 49,
          message: 'Short message',
          scope: EmergencyScope.campus,
          severity: EmergencySeverity.warning,
          category: EmergencyCategory.weather,
          priority: EmergencyRelayPriority.high,
          expiresAt: DateTime.now().add(const Duration(hours: 1)),
        ),
        throwsArgumentError,
      );
    });

    test('A3: Oversized message (> 180 chars) throws ArgumentError', () {
      expect(
        () => EmergencyPayload(
          title: 'Valid Title',
          message: 'M' * 181,
          scope: EmergencyScope.campus,
          severity: EmergencySeverity.warning,
          category: EmergencyCategory.weather,
          priority: EmergencyRelayPriority.high,
          expiresAt: DateTime.now().add(const Duration(hours: 1)),
        ),
        throwsArgumentError,
      );
    });

    test('A4: Empty title throws ArgumentError', () {
      expect(
        () => EmergencyPayload(
          title: '   ',
          message: 'Valid message',
          scope: EmergencyScope.campus,
          severity: EmergencySeverity.advisory,
          category: EmergencyCategory.other,
          priority: EmergencyRelayPriority.normal,
          expiresAt: DateTime.now().add(const Duration(hours: 1)),
        ),
        throwsArgumentError,
      );
    });

    test('A5: Invalid category code throws ArgumentError', () {
      expect(() => EmergencyCategory.fromCode('unknown_cat'), throwsArgumentError);
    });

    test('A6: Invalid severity code throws ArgumentError', () {
      expect(() => EmergencySeverity.fromCode('z'), throwsArgumentError);
    });

    test('A7: Malformed payload bytes throws FormatException', () {
      final invalidBytes = Uint8List.fromList(utf8.encode('{"t":""}'));
      expect(() => EmergencyPayload.fromBytes(invalidBytes), throwsFormatException);
    });

    // ==========================================
    // B. AUTHORIZATION
    // ==========================================
    test('B1: Student cannot issue emergency in any scope', () {
      expect(
        EmergencyAuthorization.isAuthorizedToOriginate(
          role: 'student',
          scope: EmergencyScope.campus,
        ),
        isFalse,
      );
      expect(
        EmergencyAuthorization.isAuthorizedToOriginate(
          role: 'student',
          scope: EmergencyScope.hostel,
        ),
        isFalse,
      );
      expect(
        studentCryptoService.isRoleAuthorized(
          role: 'student',
          packetType: MeshPacketType.emergency,
        ),
        isFalse,
      );
    });

    test('B2: Teacher cannot issue campus-wide emergency', () {
      expect(
        EmergencyAuthorization.isAuthorizedToOriginate(
          role: 'teacher',
          scope: EmergencyScope.campus,
        ),
        isFalse,
      );
    });

    test('B3: Authorized teacher academic scope succeeds', () {
      expect(
        EmergencyAuthorization.isAuthorizedToOriginate(
          role: 'teacher',
          scope: EmergencyScope.academic,
        ),
        isTrue,
      );
      expect(
        teacherCryptoService.isRoleAuthorized(
          role: 'teacher',
          packetType: MeshPacketType.emergency,
        ),
        isTrue,
      );
    });

    test('B4: Warden hostel scope succeeds', () {
      expect(
        EmergencyAuthorization.isAuthorizedToOriginate(
          role: 'warden',
          scope: EmergencyScope.hostel,
        ),
        isTrue,
      );
      expect(
        EmergencyAuthorization.isAuthorizedToOriginate(
          role: 'warden',
          scope: EmergencyScope.hostelBlock('block-b'),
          assignedHostel: 'block-b',
        ),
        isTrue,
      );
      expect(
        wardenCryptoService.isRoleAuthorized(
          role: 'warden',
          packetType: MeshPacketType.emergency,
        ),
        isTrue,
      );
    });

    test('B5: Warden unauthorized scope fails', () {
      // Warden cannot issue campus-wide
      expect(
        EmergencyAuthorization.isAuthorizedToOriginate(
          role: 'warden',
          scope: EmergencyScope.campus,
        ),
        isFalse,
      );
      // Warden cannot issue for another hostel block
      expect(
        EmergencyAuthorization.isAuthorizedToOriginate(
          role: 'warden',
          scope: EmergencyScope.hostelBlock('block-c'),
          assignedHostel: 'block-b',
        ),
        isFalse,
      );
    });

    test('B6: Admin, Dean, and Director campus emergencies succeed', () {
      expect(
        EmergencyAuthorization.isAuthorizedToOriginate(
          role: 'admin',
          scope: EmergencyScope.campus,
        ),
        isTrue,
      );
      expect(
        EmergencyAuthorization.isAuthorizedToOriginate(
          role: 'dean',
          scope: EmergencyScope.campus,
        ),
        isTrue,
      );
      expect(
        EmergencyAuthorization.isAuthorizedToOriginate(
          role: 'director',
          scope: EmergencyScope.campus,
        ),
        isTrue,
      );
      expect(
        directorCryptoService.isRoleAuthorized(
          role: 'director',
          packetType: MeshPacketType.emergency,
        ),
        isTrue,
      );
    });

    // ==========================================
    // C. CRYPTOGRAPHY
    // ==========================================
    test('C1: Valid signature on emergency packet is verified', () async {
      final payload = EmergencyPayload(
        title: 'Fire Alarm',
        message: 'Evacuate Science Block immediately.',
        scope: EmergencyScope.campus,
        severity: EmergencySeverity.critical,
        category: EmergencyCategory.fire,
        priority: EmergencyRelayPriority.critical,
        expiresAt: DateTime.now().add(const Duration(hours: 1)),
      );

      final packet = MeshPacket(
        packetId: MeshPacket.generatePacketId(),
        packetType: MeshPacketType.emergency,
        senderDeviceId: 'admin_sys',
        senderRole: 'admin',
        timestamp: DateTime.now(),
        payload: payload.toBytes(),
      );

      final signed = await adminCryptoService.signPacket(packet);
      final result = await verifierCryptoService.verifyPacket(signed);

      expect(result.status, equals(MeshVerificationStatus.trusted));
      expect(result.isTrusted, isTrue);
    });

    test('C2: Modified message payload is rejected with invalidSignature', () async {
      final payload = EmergencyPayload(
        title: 'Original Fire Alarm',
        message: 'Evacuate building immediately.',
        scope: EmergencyScope.campus,
        severity: EmergencySeverity.critical,
        category: EmergencyCategory.fire,
        priority: EmergencyRelayPriority.critical,
        expiresAt: DateTime.now().add(const Duration(hours: 1)),
      );

      final packet = MeshPacket(
        packetId: MeshPacket.generatePacketId(),
        packetType: MeshPacketType.emergency,
        senderDeviceId: 'admin_sys',
        senderRole: 'admin',
        timestamp: DateTime.now(),
        payload: payload.toBytes(),
      );

      final signed = await adminCryptoService.signPacket(packet);

      // Attacker tampers with payload
      final tamperedBytes = Uint8List.fromList(signed.payload);
      tamperedBytes[tamperedBytes.length - 1] ^= 0xFF;

      final tamperedPacket = signed.copyWith(payload: tamperedBytes);
      final result = await verifierCryptoService.verifyPacket(tamperedPacket);

      expect(result.status, equals(MeshVerificationStatus.invalidSignature));
    });

    test('C3: Modified sender device ID is rejected with invalidSignature', () async {
      final payload = EmergencyPayload(
        title: 'Power Outage',
        message: 'Backup generators starting.',
        scope: EmergencyScope.campus,
        severity: EmergencySeverity.advisory,
        category: EmergencyCategory.power,
        priority: EmergencyRelayPriority.normal,
        expiresAt: DateTime.now().add(const Duration(hours: 1)),
      );

      final packet = MeshPacket(
        packetId: MeshPacket.generatePacketId(),
        packetType: MeshPacketType.emergency,
        senderDeviceId: 'admin_sys',
        senderRole: 'admin',
        timestamp: DateTime.now(),
        payload: payload.toBytes(),
      );

      final signed = await adminCryptoService.signPacket(packet);
      final tampered = signed.copyWith(senderDeviceId: 'dean_official');
      final result = await verifierCryptoService.verifyPacket(tampered);

      expect(result.status, equals(MeshVerificationStatus.invalidSignature));
    });

    test('C4: Modified packet ID is rejected with invalidSignature', () async {
      final payload = EmergencyPayload(
        title: 'Security Alert',
        message: 'Main gate restricted access.',
        scope: EmergencyScope.campus,
        severity: EmergencySeverity.warning,
        category: EmergencyCategory.security,
        priority: EmergencyRelayPriority.high,
        expiresAt: DateTime.now().add(const Duration(hours: 1)),
      );

      final packet = MeshPacket(
        packetId: MeshPacket.generatePacketId(),
        packetType: MeshPacketType.emergency,
        senderDeviceId: 'admin_sys',
        senderRole: 'admin',
        timestamp: DateTime.now(),
        payload: payload.toBytes(),
      );

      final signed = await adminCryptoService.signPacket(packet);
      final tampered = signed.copyWith(packetId: MeshPacket.generatePacketId());
      final result = await verifierCryptoService.verifyPacket(tampered);

      expect(result.status, equals(MeshVerificationStatus.invalidSignature));
    });

    // ==========================================
    // D. TRUST
    // ==========================================
    test('D1: Unknown issuer not in trust bundle is rejected', () async {
      final payload = EmergencyPayload(
        title: 'Alert',
        message: 'Message from unknown',
        scope: EmergencyScope.campus,
        severity: EmergencySeverity.warning,
        category: EmergencyCategory.other,
        priority: EmergencyRelayPriority.high,
        expiresAt: DateTime.now().add(const Duration(hours: 1)),
      );

      final foreignKey = await algorithm.newKeyPair();
      final foreignService = CampusMeshCryptoService(
        algorithm: algorithm,
        localKeyPair: foreignKey,
        mockTrustBundle: trustBundle,
      );

      final packet = MeshPacket(
        packetId: MeshPacket.generatePacketId(),
        packetType: MeshPacketType.emergency,
        senderDeviceId: 'unknown_intruder_device',
        senderRole: 'admin',
        timestamp: DateTime.now(),
        payload: payload.toBytes(),
      );

      final signed = await foreignService.signPacket(packet);
      final result = await verifierCryptoService.verifyPacket(signed);

      expect(result.status, equals(MeshVerificationStatus.unknownSender));
    });

    test('D2: Revoked issuer is rejected with revokedSender', () async {
      final payload = EmergencyPayload(
        title: 'Compromised Alert',
        message: 'Malicious spoof attempt',
        scope: EmergencyScope.campus,
        severity: EmergencySeverity.critical,
        category: EmergencyCategory.security,
        priority: EmergencyRelayPriority.critical,
        expiresAt: DateTime.now().add(const Duration(hours: 1)),
      );

      final revokedService = CampusMeshCryptoService(
        algorithm: algorithm,
        localKeyPair: revokedKeyPair,
        mockTrustBundle: trustBundle,
      );

      final packet = MeshPacket(
        packetId: MeshPacket.generatePacketId(),
        packetType: MeshPacketType.emergency,
        senderDeviceId: 'user_compromised',
        senderRole: 'admin',
        timestamp: DateTime.now(),
        payload: payload.toBytes(),
      );

      final signed = await revokedService.signPacket(packet);
      final result = await verifierCryptoService.verifyPacket(signed);

      expect(result.status, equals(MeshVerificationStatus.revokedSender));
    });

    // ==========================================
    // E. REPLAY PROTECTION
    // ==========================================
    test('E1: Duplicate alertId is dropped by deduplication store', () async {
      final store = MeshDeduplicationStore(maxSize: 100);
      final alertId = MeshPacket.generatePacketId();

      expect(store.contains(alertId), isFalse);
      store.add(alertId);
      expect(store.contains(alertId), isTrue);
    });

    test('E2: Stale packet outside clock skew is rejected with staleTimestamp', () async {
      final staleTime = DateTime.now().subtract(const Duration(minutes: 10));
      final packet = MeshPacket(
        packetId: MeshPacket.generatePacketId(),
        packetType: MeshPacketType.emergency,
        senderDeviceId: 'admin_sys',
        senderRole: 'admin',
        timestamp: staleTime,
        payload: Uint8List.fromList([1, 2, 3]),
      );

      final signed = await adminCryptoService.signPacket(packet);
      final result = await verifierCryptoService.verifyPacket(signed);

      expect(result.status, equals(MeshVerificationStatus.staleTimestamp));
    });

    // ==========================================
    // F. RELAY PRIORITY
    // ==========================================
    test('F1: Emergency priority sorting orders critical > high > normal', () {
      final normalPacket = MeshPacket(
        packetId: MeshPacket.generatePacketId(),
        packetType: MeshPacketType.chat,
        senderDeviceId: 'dev_1',
        senderRole: 'student',
        timestamp: DateTime.now(),
        payload: Uint8List.fromList([1]),
      );

      final highPayload = EmergencyPayload(
        title: 'Weather Warning',
        message: 'Heavy rain starting.',
        scope: EmergencyScope.campus,
        severity: EmergencySeverity.warning,
        category: EmergencyCategory.weather,
        priority: EmergencyRelayPriority.high,
        expiresAt: DateTime.now().add(const Duration(hours: 1)),
      );
      final highPacket = MeshPacket(
        packetId: MeshPacket.generatePacketId(),
        packetType: MeshPacketType.emergency,
        senderDeviceId: 'dev_2',
        senderRole: 'admin',
        timestamp: DateTime.now(),
        payload: highPayload.toBytes(),
      );

      final criticalPayload = EmergencyPayload(
        title: 'Flash Flood',
        message: 'Danger level critical.',
        scope: EmergencyScope.campus,
        severity: EmergencySeverity.critical,
        category: EmergencyCategory.evacuation,
        priority: EmergencyRelayPriority.critical,
        expiresAt: DateTime.now().add(const Duration(hours: 1)),
      );
      final criticalPacket = MeshPacket(
        packetId: MeshPacket.generatePacketId(),
        packetType: MeshPacketType.emergency,
        senderDeviceId: 'dev_3',
        senderRole: 'admin',
        timestamp: DateTime.now(),
        payload: criticalPayload.toBytes(),
      );

      expect(MeshRelayEngine.getPacketPriority(normalPacket), equals(MeshRelayPriority.normal));
      expect(MeshRelayEngine.getPacketPriority(highPacket), equals(MeshRelayPriority.high));
      expect(MeshRelayEngine.getPacketPriority(criticalPacket), equals(MeshRelayPriority.critical));

      final queue = [normalPacket, criticalPacket, highPacket];
      queue.sort(MeshRelayEngine.compareByPriority);

      expect(queue[0], equals(criticalPacket));
      expect(queue[1], equals(highPacket));
      expect(queue[2], equals(normalPacket));
    });

    test('F2: Critical emergency is not blocked by normal chat cooldown', () {
      final store = MeshDeduplicationStore(maxSize: 100);
      final engine = MeshRelayEngine(
        localDeviceId: 'local_relay_node',
        deduplicationStore: store,
        relayCooldown: const Duration(milliseconds: 100),
      );

      final chat1 = MeshPacket(
        packetId: MeshPacket.generatePacketId(),
        packetType: MeshPacketType.chat,
        senderDeviceId: 'remote_chat_node',
        senderRole: 'student',
        timestamp: DateTime.now(),
        payload: Uint8List(5),
      );

      final r1 = engine.evaluateAndPrepareRelay(chat1);
      expect(r1.isAccepted, isTrue);

      final criticalPayload = EmergencyPayload(
        title: 'Earthquake Alert',
        message: 'Move to open grounds.',
        scope: EmergencyScope.campus,
        severity: EmergencySeverity.critical,
        category: EmergencyCategory.evacuation,
        priority: EmergencyRelayPriority.critical,
        expiresAt: DateTime.now().add(const Duration(hours: 1)),
      );
      final criticalEmergency = MeshPacket(
        packetId: MeshPacket.generatePacketId(),
        packetType: MeshPacketType.emergency,
        senderDeviceId: 'remote_admin_node',
        senderRole: 'admin',
        timestamp: DateTime.now(),
        payload: criticalPayload.toBytes(),
      );

      // Immediately arriving critical emergency is accepted!
      final r2 = engine.evaluateAndPrepareRelay(criticalEmergency);
      expect(r2.isAccepted, isTrue);
      expect(r2.relayedPacket?.ttl, equals(6));
      expect(r2.relayedPacket?.hopCount, equals(1));
    });

    test('F3: Duplicate emergency does not relay again', () {
      final store = MeshDeduplicationStore(maxSize: 100);
      final engine = MeshRelayEngine(
        localDeviceId: 'local_relay_node',
        deduplicationStore: store,
      );

      final payload = EmergencyPayload(
        title: 'Fire Alarm',
        message: 'Evacuate Hostel B.',
        scope: EmergencyScope.hostel,
        severity: EmergencySeverity.critical,
        category: EmergencyCategory.fire,
        priority: EmergencyRelayPriority.critical,
        expiresAt: DateTime.now().add(const Duration(hours: 1)),
      );
      final emergencyPacket = MeshPacket(
        packetId: MeshPacket.generatePacketId(),
        packetType: MeshPacketType.emergency,
        senderDeviceId: 'warden_b',
        senderRole: 'warden',
        timestamp: DateTime.now(),
        payload: payload.toBytes(),
      );

      final firstRelay = engine.evaluateAndPrepareRelay(emergencyPacket);
      expect(firstRelay.isAccepted, isTrue);

      engine.resetCooldown();

      final secondRelay = engine.evaluateAndPrepareRelay(emergencyPacket);
      expect(secondRelay.decision, equals(MeshRelayDecision.droppedDuplicate));
      expect(secondRelay.isAccepted, isFalse);
    });

    // ==========================================
    // G. PERSISTENCE
    // ==========================================
    test('G1: Emergency alert persists and survives repository reload', () async {
      final repo = MeshEmergencyRepository.inMemory();
      await repo.initialize();

      final alert = EmergencyAlert(
        alertId: 'alert_persisted_01',
        issuerDeviceId: 'admin_sys',
        issuerUserId: 'admin_sys',
        issuerRole: 'admin',
        scope: EmergencyScope.campus,
        severity: EmergencySeverity.critical,
        category: EmergencyCategory.cyclone,
        title: 'Cyclone Hudhud Warning',
        message: 'Remain indoors away from windows.',
        createdAt: DateTime.now(),
        expiresAt: DateTime.now().add(const Duration(hours: 5)),
        firstSeenAt: DateTime.now(),
        lastSeenAt: DateTime.now(),
        deliveryState: EmergencyDeliveryState.received,
      );

      final saved = await repo.saveAlert(alert);
      expect(saved, isTrue);

      final loaded = await repo.getAlert('alert_persisted_01');
      expect(loaded, isNotNull);
      expect(loaded!.title, equals('Cyclone Hudhud Warning'));
      expect(loaded.severity, equals(EmergencySeverity.critical));
      expect(loaded.isAcknowledged, isFalse);

      // Local acknowledgement
      final acked = await repo.acknowledgeAlert('alert_persisted_01');
      expect(acked, isTrue);

      final updated = await repo.getAlert('alert_persisted_01');
      expect(updated!.isAcknowledged, isTrue);

      await repo.close();
    });

    test('G2: Duplicate alert insert is idempotent and updates telemetry', () async {
      final repo = MeshEmergencyRepository.inMemory();
      await repo.initialize();

      final alert1 = EmergencyAlert(
        alertId: 'alert_dup_01',
        issuerDeviceId: 'dean_official',
        issuerRole: 'dean',
        scope: EmergencyScope.campus,
        severity: EmergencySeverity.warning,
        category: EmergencyCategory.weather,
        title: 'Heatwave Advisory',
        message: 'Stay hydrated.',
        createdAt: DateTime.now(),
        expiresAt: DateTime.now().add(const Duration(hours: 2)),
        firstSeenAt: DateTime.now(),
        lastSeenAt: DateTime.now(),
        hopCount: 3,
      );

      final firstInsert = await repo.saveAlert(alert1);
      expect(firstInsert, isTrue);

      // Duplicate alert with shorter hop path arriving from alternative route
      final alert2 = alert1.copyWith(hopCount: 1);
      final secondInsert = await repo.saveAlert(alert2);
      expect(secondInsert, isFalse); // Idempotent: marked as duplicate

      final loaded = await repo.getAlert('alert_dup_01');
      expect(loaded!.relayCount, equals(2));
      expect(loaded.hopCount, equals(1)); // Updated to shorter route

      await repo.close();
    });

    test('G3: Expiry filtering returns only active alerts', () async {
      final repo = MeshEmergencyRepository.inMemory();
      await repo.initialize();

      final now = DateTime.now();
      final activeAlert = EmergencyAlert(
        alertId: 'active_alert',
        issuerDeviceId: 'admin_sys',
        issuerRole: 'admin',
        scope: EmergencyScope.campus,
        severity: EmergencySeverity.warning,
        category: EmergencyCategory.security,
        title: 'Active Alert',
        message: 'In effect.',
        createdAt: now,
        expiresAt: now.add(const Duration(hours: 1)),
        firstSeenAt: now,
        lastSeenAt: now,
      );

      final expiredAlert = EmergencyAlert(
        alertId: 'expired_alert',
        issuerDeviceId: 'admin_sys',
        issuerRole: 'admin',
        scope: EmergencyScope.campus,
        severity: EmergencySeverity.warning,
        category: EmergencyCategory.security,
        title: 'Expired Alert',
        message: 'No longer in effect.',
        createdAt: now.subtract(const Duration(hours: 3)),
        expiresAt: now.subtract(const Duration(hours: 1)),
        firstSeenAt: now,
        lastSeenAt: now,
      );

      await repo.saveAlert(activeAlert);
      await repo.saveAlert(expiredAlert);

      final activeList = await repo.getActiveAlerts(now);
      expect(activeList.length, equals(1));
      expect(activeList.first.alertId, equals('active_alert'));

      final fullHistory = await repo.getAlertHistory();
      expect(fullHistory.length, equals(2));

      await repo.close();
    });

    // ==========================================
    // H. NOTIFICATION ABSTRACTION & END-TO-END FLOW
    // ==========================================
    test('H1: End-to-end emergency flow notifies once and ignores duplicates', () async {
      final fakeAdapter = FakeMeshBleAdapter();
      final meshService = CampusMeshService(
        localDeviceId: 'dean_official',
        localRole: 'dean',
        adapter: fakeAdapter,
        deduplicationStore: MeshDeduplicationStore(maxSize: 50),
        peerRegistry: MeshPeerRegistry(),
        relayEngine: MeshRelayEngine(
          localDeviceId: 'dean_official',
          deduplicationStore: MeshDeduplicationStore(maxSize: 50),
        ),
        cryptoService: deanCryptoService,
      );

      final repo = MeshEmergencyRepository.inMemory();
      final notifier = MockEmergencyNotifier();

      final emergencyService = CampusMeshEmergencyService(
        meshService: meshService,
        repository: repo,
        cryptoService: deanCryptoService,
        notifier: notifier,
      );

      await emergencyService.initialize();
      await meshService.start();

      // Issue an emergency alert
      final alert = await emergencyService.issueEmergencyAlert(
        title: 'Evacuation Drill',
        message: 'Mandatory campus evacuation test.',
        severity: EmergencySeverity.critical,
        category: EmergencyCategory.evacuation,
        scope: EmergencyScope.campus,
      );

      expect(alert.alertId.isNotEmpty, isTrue);
      expect(fakeAdapter.advertisedPackets.isNotEmpty, isTrue);

      // Inbound reception of the packet at Node B (e.g. Student Alice)
      final receiverRepo = MeshEmergencyRepository.inMemory();
      final receiverNotifier = MockEmergencyNotifier();
      final receiverMeshService = CampusMeshService(
        localDeviceId: 'student_alice',
        localRole: 'student',
        adapter: FakeMeshBleAdapter(),
        deduplicationStore: MeshDeduplicationStore(maxSize: 50),
        peerRegistry: MeshPeerRegistry(),
        relayEngine: MeshRelayEngine(
          localDeviceId: 'student_alice',
          deduplicationStore: MeshDeduplicationStore(maxSize: 50),
        ),
        cryptoService: verifierCryptoService,
      );

      final receiverEmergencyService = CampusMeshEmergencyService(
        meshService: receiverMeshService,
        repository: receiverRepo,
        cryptoService: verifierCryptoService,
        notifier: receiverNotifier,
      );

      await receiverEmergencyService.initialize();

      final inboundPacket = const MeshPacketCodec().decode(fakeAdapter.advertisedPackets.first);
      final receivedAlert = await receiverEmergencyService.receiveEmergencyPacket(inboundPacket);

      expect(receivedAlert, isNotNull);
      expect(receivedAlert!.title, equals('Evacuation Drill'));
      expect(receiverNotifier.notificationCount, equals(1));

      // Repeated reception of same packet on Node B does not notify again
      final dupReceived = await receiverEmergencyService.receiveEmergencyPacket(inboundPacket);
      expect(dupReceived, isNotNull);
      expect(receiverNotifier.notificationCount, equals(1)); // Still 1!

      await receiverEmergencyService.dispose();
      await receiverMeshService.dispose();
      await receiverRepo.close();

      await emergencyService.dispose();
      await meshService.dispose();
      await repo.close();
    });

    test('H2: PlatformEmergencyNotifier handles calls gracefully without crashing', () async {
      final platformNotifier = PlatformEmergencyNotifier();
      final alert = EmergencyAlert(
        alertId: 'test_alert',
        issuerDeviceId: 'test_dev',
        issuerRole: 'admin',
        scope: EmergencyScope.campus,
        severity: EmergencySeverity.critical,
        category: EmergencyCategory.weather,
        title: 'Platform Test',
        message: 'No crash expected',
        createdAt: DateTime.now(),
        expiresAt: DateTime.now().add(const Duration(hours: 1)),
        firstSeenAt: DateTime.now(),
        lastSeenAt: DateTime.now(),
      );

      // Must complete without unhandled exception
      await expectLater(platformNotifier.notifyEmergency(alert), completes);
    });

    // ==========================================
    // I. SIREN SIGNALING, CANCELLATION & STUDENT SOS
    // ==========================================
    test('I1: Siren payload round-trip & receiver siren lifecycle (play -> ack stops siren)', () async {
      final payload = EmergencyPayload(
        title: 'Fire in Hostel Block B',
        message: 'Evacuate immediately to main ground.',
        scope: EmergencyScope.hostel,
        severity: EmergencySeverity.critical,
        category: EmergencyCategory.fire,
        priority: EmergencyRelayPriority.critical,
        expiresAt: DateTime.now().add(const Duration(hours: 2)),
        sirenEnabled: true,
        sirenPattern: EmergencySirenPattern.yelp,
      );

      final decoded = EmergencyPayload.fromBytes(payload.toBytes());
      expect(decoded.sirenEnabled, isTrue);
      expect(decoded.sirenPattern, equals(EmergencySirenPattern.yelp));

      final senderMesh = CampusMeshService(
        localDeviceId: 'dean_official',
        localRole: 'dean',
        adapter: FakeMeshBleAdapter(),
        deduplicationStore: MeshDeduplicationStore(maxSize: 50),
        peerRegistry: MeshPeerRegistry(),
        relayEngine: MeshRelayEngine(
          localDeviceId: 'dean_official',
          deduplicationStore: MeshDeduplicationStore(maxSize: 50),
        ),
        cryptoService: deanCryptoService,
      );
      final senderRepo = MeshEmergencyRepository.inMemory();
      final senderService = CampusMeshEmergencyService(
        meshService: senderMesh,
        repository: senderRepo,
        cryptoService: deanCryptoService,
        notifier: MockEmergencyNotifier(),
      );

      final receiverMesh = CampusMeshService(
        localDeviceId: 'student_alice',
        localRole: 'student',
        adapter: FakeMeshBleAdapter(),
        deduplicationStore: MeshDeduplicationStore(maxSize: 50),
        peerRegistry: MeshPeerRegistry(),
        relayEngine: MeshRelayEngine(
          localDeviceId: 'student_alice',
          deduplicationStore: MeshDeduplicationStore(maxSize: 50),
        ),
        cryptoService: verifierCryptoService,
      );
      final receiverRepo = MeshEmergencyRepository.inMemory();
      final receiverNotifier = MockEmergencyNotifier();
      final receiverService = CampusMeshEmergencyService(
        meshService: receiverMesh,
        repository: receiverRepo,
        cryptoService: verifierCryptoService,
        notifier: receiverNotifier,
      );

      await senderService.initialize();
      await senderMesh.start();
      await receiverService.initialize();

      final issued = await senderService.issueEmergencyAlert(
        title: 'Fire Evacuation Siren',
        message: 'Proceed to assembly area.',
        severity: EmergencySeverity.critical,
        category: EmergencyCategory.fire,
        scope: EmergencyScope.campus,
        sendSiren: true,
        sirenPattern: EmergencySirenPattern.yelp,
      );

      expect(issued.sirenEnabled, isTrue);
      expect(issued.sirenPattern, equals(EmergencySirenPattern.yelp));

      final sentPacket = const MeshPacketCodec()
          .decode((senderMesh.adapter as FakeMeshBleAdapter).advertisedPackets.last);
      final received = await receiverService.receiveEmergencyPacket(sentPacket);

      expect(received, isNotNull);
      expect(received!.hasSiren, isTrue);
      expect(received.sirenPattern, equals(EmergencySirenPattern.yelp));
      expect(receiverNotifier.activeSirenAlert.value?.alertId, equals(received.alertId));

      await receiverService.acknowledgeEmergency(received.alertId);
      expect(receiverNotifier.stopCount, equals(1));
      expect(receiverNotifier.activeSirenAlert.value, isNull);

      await receiverService.dispose();
      await receiverMesh.dispose();
      await receiverRepo.close();
      await senderService.dispose();
      await senderMesh.dispose();
      await senderRepo.close();
    });

    test('I2: Student SOS beacon broadcasts with siren while keeping student role restricted from official flares', () async {
      final studentMesh = CampusMeshService(
        localDeviceId: 'student_alice',
        localRole: 'student',
        adapter: FakeMeshBleAdapter(),
        deduplicationStore: MeshDeduplicationStore(maxSize: 50),
        peerRegistry: MeshPeerRegistry(),
        relayEngine: MeshRelayEngine(
          localDeviceId: 'student_alice',
          deduplicationStore: MeshDeduplicationStore(maxSize: 50),
        ),
      );
      final repo = MeshEmergencyRepository.inMemory();
      final notifier = MockEmergencyNotifier();
      final service = CampusMeshEmergencyService(
        meshService: studentMesh,
        repository: repo,
        notifier: notifier,
      );

      await service.initialize();
      await studentMesh.start();

      // Official institutional flare remains blocked for student role
      await expectLater(
        service.issueEmergencyAlert(
          title: 'Campus Alert',
          message: 'Unauthorized',
          severity: EmergencySeverity.critical,
          category: EmergencyCategory.security,
          scope: EmergencyScope.campus,
        ),
        throwsA(isA<EmergencyUnauthorizedException>()),
      );

      // Personal Student SOS beacon + siren succeeds and restores student role
      final sos = await service.sendStudentSosBeacon(
        category: EmergencyCategory.hostel,
        details: 'Medical help needed in Block B Room 204',
        sendSiren: true,
        sirenPattern: EmergencySirenPattern.yelp,
      );

      expect(sos.sirenEnabled, isTrue);
      expect(sos.sirenPattern, equals(EmergencySirenPattern.yelp));
      expect(studentMesh.localRole, equals('student'));

      await service.dispose();
      await studentMesh.dispose();
      await repo.close();
    });
  });
}
