import 'dart:convert';
import 'dart:typed_data';
import 'package:cryptography/cryptography.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:attendance_app/core/mesh/campus_mesh_service.dart';
import 'package:attendance_app/core/mesh/emergency/campus_mesh_emergency_service.dart';
import 'package:attendance_app/core/mesh/emergency/dispatcher/emergency_audit_event.dart';
import 'package:attendance_app/core/mesh/emergency/dispatcher/emergency_audit_repository.dart';
import 'package:attendance_app/core/mesh/emergency/dispatcher/emergency_dispatcher_repository.dart';
import 'package:attendance_app/core/mesh/emergency/dispatcher/emergency_dispatcher_service.dart';
import 'package:attendance_app/core/mesh/emergency/dispatcher/emergency_incident.dart';
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
import 'package:attendance_app/shared/screens/campus_mesh_emergency_dispatcher_screen.dart';
import 'package:attendance_app/student/models/passport_trust_bundle_model.dart';

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

Uint8List hexToBytes(String hex) {
  final result = Uint8List(hex.length ~/ 2);
  for (int i = 0; i < result.length; i++) {
    result[i] = int.parse(hex.substring(i * 2, i * 2 + 2), radix: 16);
  }
  return result;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('CampusOS Mesh — Phase M6: Dean Emergency Mesh Dispatcher + Audit Tests', () {
    late Ed25519 algorithm;
    late SimpleKeyPair deanKeyPair;
    late SimpleKeyPair adminKeyPair;
    late SimpleKeyPair wardenKeyPair;
    late SimpleKeyPair studentKeyPair;
    late SimpleKeyPair revokedKeyPair;

    late PassportTrustBundle trustBundle;
    late CampusMeshCryptoService deanCryptoService;
    late CampusMeshCryptoService adminCryptoService;
    late CampusMeshCryptoService wardenCryptoService;
    late CampusMeshCryptoService studentCryptoService;
    late CampusMeshCryptoService revokedCryptoService;

    final now = DateTime.now();
    final nowSec = now.toUtc().millisecondsSinceEpoch ~/ 1000;

    setUpAll(() async {
      algorithm = Ed25519();
      deanKeyPair = await algorithm.newKeyPair();
      adminKeyPair = await algorithm.newKeyPair();
      wardenKeyPair = await algorithm.newKeyPair();
      studentKeyPair = await algorithm.newKeyPair();
      revokedKeyPair = await algorithm.newKeyPair();

      final rootKeyPair = await algorithm.newKeyPair();
      final rootPubKey = await rootKeyPair.extractPublicKey();

      final deanPubKey = await deanKeyPair.extractPublicKey();
      final adminPubKey = await adminKeyPair.extractPublicKey();
      final wardenPubKey = await wardenKeyPair.extractPublicKey();
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

      deanCryptoService = CampusMeshCryptoService(
        algorithm: algorithm,
        localKeyPair: deanKeyPair,
        mockTrustBundle: trustBundle,
      );

      adminCryptoService = CampusMeshCryptoService(
        algorithm: algorithm,
        localKeyPair: adminKeyPair,
        mockTrustBundle: trustBundle,
      );

      wardenCryptoService = CampusMeshCryptoService(
        algorithm: algorithm,
        localKeyPair: wardenKeyPair,
        mockTrustBundle: trustBundle,
      );

      studentCryptoService = CampusMeshCryptoService(
        algorithm: algorithm,
        localKeyPair: studentKeyPair,
        mockTrustBundle: trustBundle,
      );

      revokedCryptoService = CampusMeshCryptoService(
        algorithm: algorithm,
        localKeyPair: revokedKeyPair,
        mockTrustBundle: trustBundle,
      );
    });

    CampusMeshService createMeshNode(
      String deviceId, {
      required String role,
      required MeshCryptoService crypto,
      MockMeshBleAdapter? adapter,
    }) {
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
        cryptoService: crypto,
      );
    }

    // =========================================================================
    // GROUP A: Authorization Controls
    // =========================================================================
    test('Group A: Dean has full campus-wide and subordinate emergency authority', () async {
      final mesh = createMeshNode('node_dean', role: 'dean', crypto: deanCryptoService);
      final alertRepo = MeshEmergencyRepository.inMemory();
      final dispRepo = MeshEmergencyDispatcherRepository.inMemory();
      final auditRepo = EmergencyAuditRepository.inMemory();

      final emService = CampusMeshEmergencyService(
        meshService: mesh,
        repository: alertRepo,
        cryptoService: deanCryptoService,
        mockTrustBundle: trustBundle,
        notifier: MockEmergencyNotifier(),
      );

      final dispatcher = MeshEmergencyDispatcherService(
        emergencyService: emService,
        dispatcherRepository: dispRepo,
        auditRepository: auditRepo,
        cryptoService: deanCryptoService,
      );

      await dispatcher.initialize();

      expect(dispatcher.isAuthorizedToDispatch(EmergencyScope.campus), isTrue);
      expect(dispatcher.isAuthorizedToDispatch(EmergencyScope.hostel), isTrue);
      expect(dispatcher.isAuthorizedToDispatch(EmergencyScope.academic), isTrue);
      expect(dispatcher.getAvailableScopes(), contains(EmergencyScope.campus));

      await dispatcher.dispose();
      await alertRepo.close();
      await dispRepo.close();
      await auditRepo.close();
    });

    test('Group A: Student is strictly prohibited from dispatching emergency incidents', () async {
      final mesh = createMeshNode('node_student', role: 'student', crypto: studentCryptoService);
      final alertRepo = MeshEmergencyRepository.inMemory();
      final dispRepo = MeshEmergencyDispatcherRepository.inMemory();
      final auditRepo = EmergencyAuditRepository.inMemory();

      final emService = CampusMeshEmergencyService(
        meshService: mesh,
        repository: alertRepo,
        cryptoService: studentCryptoService,
        mockTrustBundle: trustBundle,
        notifier: MockEmergencyNotifier(),
      );

      final dispatcher = MeshEmergencyDispatcherService(
        emergencyService: emService,
        dispatcherRepository: dispRepo,
        auditRepository: auditRepo,
        cryptoService: studentCryptoService,
      );

      await dispatcher.initialize();

      expect(dispatcher.isAuthorizedToDispatch(EmergencyScope.campus), isFalse);
      expect(dispatcher.getAvailableScopes(), isEmpty);

      // Attempting to dispatch must throw EmergencyUnauthorizedException
      await expectLater(
        dispatcher.createAndDispatchIncident(
          title: 'Student Prank Alert',
          message: 'Campus closed today',
          category: EmergencyCategory.other,
          severity: EmergencySeverity.warning,
          scope: EmergencyScope.campus,
        ),
        throwsA(isA<EmergencyUnauthorizedException>()),
      );

      // Audit trail must record VERIFICATION_FAILED
      final auditEvents = await auditRepo.getAllEvents();
      expect(auditEvents.length, 1);
      expect(auditEvents.first.eventType, EmergencyAuditEventType.verificationFailed);
      expect(auditEvents.first.actorRole, 'student');

      await dispatcher.dispose();
      await alertRepo.close();
      await dispRepo.close();
      await auditRepo.close();
    });

    test('Group A: Warden is authorized for hostel scope but blocked from campus-wide scope', () async {
      final mesh = createMeshNode('node_warden', role: 'warden', crypto: wardenCryptoService);
      final alertRepo = MeshEmergencyRepository.inMemory();
      final dispRepo = MeshEmergencyDispatcherRepository.inMemory();
      final auditRepo = EmergencyAuditRepository.inMemory();

      final emService = CampusMeshEmergencyService(
        meshService: mesh,
        repository: alertRepo,
        cryptoService: wardenCryptoService,
        mockTrustBundle: trustBundle,
        notifier: MockEmergencyNotifier(),
        assignedHostel: 'b',
      );

      final dispatcher = MeshEmergencyDispatcherService(
        emergencyService: emService,
        dispatcherRepository: dispRepo,
        auditRepository: auditRepo,
        cryptoService: wardenCryptoService,
      );

      await dispatcher.initialize();

      expect(dispatcher.isAuthorizedToDispatch(EmergencyScope.hostel), isTrue);
      expect(dispatcher.isAuthorizedToDispatch(EmergencyScope.campus), isFalse);

      // Campus-wide dispatch fails safely
      await expectLater(
        dispatcher.createAndDispatchIncident(
          title: 'Campus Lockdown',
          message: 'Lockdown all gates',
          category: EmergencyCategory.security,
          severity: EmergencySeverity.critical,
          scope: EmergencyScope.campus,
        ),
        throwsA(isA<EmergencyUnauthorizedException>()),
      );

      // Hostel dispatch succeeds
      final incident = await dispatcher.createAndDispatchIncident(
        title: 'Hostel Water Contamination',
        message: 'Do not drink tank water in Block B',
        category: EmergencyCategory.hostel,
        severity: EmergencySeverity.warning,
        scope: EmergencyScope.hostel,
      );

      expect(incident.status, EmergencyIncidentStatus.active);
      expect(incident.scope, EmergencyScope.hostel);

      await dispatcher.dispose();
      await alertRepo.close();
      await dispRepo.close();
      await auditRepo.close();
    });

    // =========================================================================
    // GROUP B: Incident Creation & Validation
    // =========================================================================
    test('Group B: Valid incident creation binds metadata, generates packet, and stores record', () async {
      final mesh = createMeshNode('dean_official', role: 'dean', crypto: deanCryptoService);
      final alertRepo = MeshEmergencyRepository.inMemory();
      final dispRepo = MeshEmergencyDispatcherRepository.inMemory();
      final auditRepo = EmergencyAuditRepository.inMemory();

      final emService = CampusMeshEmergencyService(
        meshService: mesh,
        repository: alertRepo,
        cryptoService: deanCryptoService,
        mockTrustBundle: trustBundle,
        notifier: MockEmergencyNotifier(),
      );

      final dispatcher = MeshEmergencyDispatcherService(
        emergencyService: emService,
        dispatcherRepository: dispRepo,
        auditRepository: auditRepo,
        cryptoService: deanCryptoService,
      );

      await dispatcher.initialize();

      final incident = await dispatcher.createAndDispatchIncident(
        title: 'Cyclone Warning',
        message: 'Move indoors immediately.',
        category: EmergencyCategory.cyclone,
        severity: EmergencySeverity.critical,
        scope: EmergencyScope.campus,
        duration: const Duration(minutes: 45),
      );

      expect(incident.title, 'Cyclone Warning');
      expect(incident.category, EmergencyCategory.cyclone);
      expect(incident.severity, EmergencySeverity.critical);
      expect(incident.scope, EmergencyScope.campus);
      expect(incident.issuerRole, 'dean');
      expect(incident.issuerUserId, 'dean_official');
      expect(incident.isActive(), isTrue);
      expect(incident.hopCount, 0);

      // Verify persistence in dispatcher repository
      final fetched = await dispRepo.getIncident(incident.incidentId);
      expect(fetched, isNotNull);
      expect(fetched!.title, incident.title);

      await dispatcher.dispose();
      await alertRepo.close();
      await dispRepo.close();
      await auditRepo.close();
    });

    test('Group B: Empty or oversized title/message is rejected', () async {
      final mesh = createMeshNode('node_dean_val', role: 'dean', crypto: deanCryptoService);
      final alertRepo = MeshEmergencyRepository.inMemory();
      final dispRepo = MeshEmergencyDispatcherRepository.inMemory();
      final auditRepo = EmergencyAuditRepository.inMemory();

      final emService = CampusMeshEmergencyService(
        meshService: mesh,
        repository: alertRepo,
        cryptoService: deanCryptoService,
        mockTrustBundle: trustBundle,
        notifier: MockEmergencyNotifier(),
      );

      final dispatcher = MeshEmergencyDispatcherService(
        emergencyService: emService,
        dispatcherRepository: dispRepo,
        auditRepository: auditRepo,
        cryptoService: deanCryptoService,
      );

      await dispatcher.initialize();

      // Empty title
      await expectLater(
        dispatcher.createAndDispatchIncident(
          title: '   ',
          message: 'Valid message',
          category: EmergencyCategory.fire,
          severity: EmergencySeverity.critical,
          scope: EmergencyScope.campus,
        ),
        throwsA(isA<ArgumentError>()),
      );

      // Oversized title (> 48 chars)
      await expectLater(
        dispatcher.createAndDispatchIncident(
          title: 'A' * 50,
          message: 'Valid message',
          category: EmergencyCategory.fire,
          severity: EmergencySeverity.critical,
          scope: EmergencyScope.campus,
        ),
        throwsA(isA<ArgumentError>()),
      );

      await dispatcher.dispose();
      await alertRepo.close();
      await dispRepo.close();
      await auditRepo.close();
    });

    // =========================================================================
    // GROUP C: Cryptographic Signing & Revocation
    // =========================================================================
    test('Group C: Dispatched incident is Ed25519 signed and certified against trust bundle', () async {
      final adapter = MockMeshBleAdapter();
      final mesh = CampusMeshService(
        localDeviceId: 'admin_sys',
        localRole: 'admin',
        adapter: adapter,
        codec: const MeshPacketCodec(),
        deduplicationStore: MeshDeduplicationStore(maxSize: 100),
        peerRegistry: MeshPeerRegistry(),
        relayEngine: MeshRelayEngine(
          localDeviceId: 'admin_sys',
          deduplicationStore: MeshDeduplicationStore(maxSize: 100),
        ),
        cryptoService: adminCryptoService,
      );

      final alertRepo = MeshEmergencyRepository.inMemory();
      final dispRepo = MeshEmergencyDispatcherRepository.inMemory();
      final auditRepo = EmergencyAuditRepository.inMemory();

      final emService = CampusMeshEmergencyService(
        meshService: mesh,
        repository: alertRepo,
        cryptoService: adminCryptoService,
        mockTrustBundle: trustBundle,
        notifier: MockEmergencyNotifier(),
      );

      final dispatcher = MeshEmergencyDispatcherService(
        emergencyService: emService,
        dispatcherRepository: dispRepo,
        auditRepository: auditRepo,
        cryptoService: adminCryptoService,
      );

      await dispatcher.initialize();

      final incident = await dispatcher.createAndDispatchIncident(
        title: 'Chemical Spill',
        message: 'Evacuate Chem Lab 3',
        category: EmergencyCategory.evacuation,
        severity: EmergencySeverity.critical,
        scope: EmergencyScope.academic,
      );

      expect(incident.signatureVerificationState, 'TRUSTED');
      expect(adapter.advertised.length, 1);

      // Verify the advertised BLE packet
      final decodedPacket = const MeshPacketCodec().decode(adapter.advertised.first);
      expect(decodedPacket.packetType, MeshPacketType.emergency);
      expect(decodedPacket.signature, isNotNull);

      // Verify signature using crypto service
      final verifyResult = await adminCryptoService.verifyPacket(decodedPacket);
      expect(verifyResult.isValid, isTrue);
      expect(verifyResult.isTrusted, isTrue);
      expect(verifyResult.senderUserId, 'admin_sys');

      await dispatcher.dispose();
      await alertRepo.close();
      await dispRepo.close();
      await auditRepo.close();
    });

    test('Group C: Revoked authority identity is rejected at verification', () async {
      final mesh = createMeshNode('node_revoked', role: 'admin', crypto: revokedCryptoService);
      final alertRepo = MeshEmergencyRepository.inMemory();
      final dispRepo = MeshEmergencyDispatcherRepository.inMemory();
      final auditRepo = EmergencyAuditRepository.inMemory();

      final emService = CampusMeshEmergencyService(
        meshService: mesh,
        repository: alertRepo,
        cryptoService: revokedCryptoService,
        mockTrustBundle: trustBundle,
        notifier: MockEmergencyNotifier(),
      );

      final dispatcher = MeshEmergencyDispatcherService(
        emergencyService: emService,
        dispatcherRepository: dispRepo,
        auditRepository: auditRepo,
        cryptoService: revokedCryptoService,
      );

      await dispatcher.initialize();

      // Revoked user attempts to broadcast an alert packet
      final testPayload = EmergencyPayload(
        title: 'Forged Alert',
        message: 'Compromised admin issuing alert',
        scope: EmergencyScope.campus,
        severity: EmergencySeverity.critical,
        category: EmergencyCategory.security,
        priority: EmergencyRelayPriority.critical,
        expiresAt: DateTime.now().add(const Duration(hours: 1)),
        issuerUserId: 'user_compromised',
      );

      final forgedPacket = MeshPacket(
        packetId: MeshPacket.generatePacketId(),
        packetType: MeshPacketType.emergency,
        ttl: 7,
        hopCount: 0,
        senderDeviceId: 'node_revoked',
        senderRole: 'admin',
        timestamp: DateTime.now(),
        payload: testPayload.toBytes(),
      );

      final signedForged = await revokedCryptoService.signPacket(forgedPacket);

      // Node receiving packet from revoked identity drops it
      final receivedAlert = await emService.receiveEmergencyPacket(signedForged);
      expect(receivedAlert, isNull);

      await dispatcher.dispose();
      await alertRepo.close();
      await dispRepo.close();
      await auditRepo.close();
    });

    // =========================================================================
    // GROUP D: Dispatch Lifecycle & State Machine
    // =========================================================================
    test('Group D: Full lifecycle: create -> active -> cancel -> restart recovery', () async {
      final mesh = createMeshNode('node_dean_life', role: 'dean', crypto: deanCryptoService);
      final alertRepo = MeshEmergencyRepository.inMemory();
      final dispRepo = MeshEmergencyDispatcherRepository.inMemory();
      final auditRepo = EmergencyAuditRepository.inMemory();

      final emService = CampusMeshEmergencyService(
        meshService: mesh,
        repository: alertRepo,
        cryptoService: deanCryptoService,
        mockTrustBundle: trustBundle,
        notifier: MockEmergencyNotifier(),
      );

      var dispatcher = MeshEmergencyDispatcherService(
        emergencyService: emService,
        dispatcherRepository: dispRepo,
        auditRepository: auditRepo,
        cryptoService: deanCryptoService,
      );

      await dispatcher.initialize();

      // 1. Create and dispatch incident
      final incident = await dispatcher.createAndDispatchIncident(
        title: 'Severe Gas Leak',
        message: 'Stay clear of cafeteria kitchen area',
        category: EmergencyCategory.fire,
        severity: EmergencySeverity.critical,
        scope: EmergencyScope.campus,
        duration: const Duration(minutes: 60),
      );

      expect(incident.status, EmergencyIncidentStatus.active);
      expect(incident.isCancelled, isFalse);

      var activeList = await dispatcher.getActiveIncidents();
      expect(activeList.length, 1);
      expect(activeList.first.incidentId, incident.incidentId);

      // 2. Cancel incident
      final cancelledOk = await dispatcher.cancelIncident(
        incident.incidentId,
        reason: 'Gas valve isolated. Area secured.',
      );
      expect(cancelledOk, isTrue);

      final updatedIncident = await dispRepo.getIncident(incident.incidentId);
      expect(updatedIncident!.isCancelled, isTrue);
      expect(updatedIncident.status, EmergencyIncidentStatus.cancelled);
      expect(updatedIncident.cancelReason, 'Gas valve isolated. Area secured.');

      activeList = await dispatcher.getActiveIncidents();
      expect(activeList, isEmpty);

      await dispatcher.dispose();

      // 3. Restart recovery: new dispatcher instance boots up
      final recoveredDispatcher = MeshEmergencyDispatcherService(
        emergencyService: emService,
        dispatcherRepository: dispRepo,
        auditRepository: auditRepo,
        cryptoService: deanCryptoService,
      );

      await recoveredDispatcher.initialize();

      final recovered = await recoveredDispatcher.repository.getIncident(incident.incidentId);
      expect(recovered, isNotNull);
      expect(recovered!.status, EmergencyIncidentStatus.cancelled);

      await recoveredDispatcher.dispose();
      await alertRepo.close();
      await dispRepo.close();
      await auditRepo.close();
    });

    test('Group D: Incident expiration transitions status to EXPIRED and logs audit', () async {
      final mesh = createMeshNode('node_dean_exp', role: 'dean', crypto: deanCryptoService);
      final alertRepo = MeshEmergencyRepository.inMemory();
      final dispRepo = MeshEmergencyDispatcherRepository.inMemory();
      final auditRepo = EmergencyAuditRepository.inMemory();

      final emService = CampusMeshEmergencyService(
        meshService: mesh,
        repository: alertRepo,
        cryptoService: deanCryptoService,
        mockTrustBundle: trustBundle,
        notifier: MockEmergencyNotifier(),
      );

      final dispatcher = MeshEmergencyDispatcherService(
        emergencyService: emService,
        dispatcherRepository: dispRepo,
        auditRepository: auditRepo,
        cryptoService: deanCryptoService,
      );

      await dispatcher.initialize();

      // Create an incident expiring in 1 second
      final incident = await dispatcher.createAndDispatchIncident(
        title: 'Short Drill Alert',
        message: 'Mock drill ending shortly',
        category: EmergencyCategory.other,
        severity: EmergencySeverity.advisory,
        scope: EmergencyScope.campus,
        duration: const Duration(seconds: 1),
      );

      expect(incident.isActive(), isTrue);

      // Fast forward time by 2 seconds
      final futureTime = DateTime.now().add(const Duration(seconds: 2));
      final expiredCount = await dispatcher.checkAndExpireIncidents(futureTime);
      expect(expiredCount, 1);

      final expiredIncident = await dispRepo.getIncident(incident.incidentId);
      expect(expiredIncident!.status, EmergencyIncidentStatus.expired);

      // Verify DISPATCH_EXPIRED audit event was written
      final auditEvents = await auditRepo.getEventsForIncident(incident.incidentId);
      expect(
        auditEvents.any((e) => e.eventType == EmergencyAuditEventType.dispatchExpired),
        isTrue,
      );

      await dispatcher.dispose();
      await alertRepo.close();
      await dispRepo.close();
      await auditRepo.close();
    });

    // =========================================================================
    // GROUP E: Duplicate Protection
    // =========================================================================
    test('Group E: Rapid double-tap dispatch with identical parameters is blocked', () async {
      final mesh = createMeshNode('node_dean_dup', role: 'dean', crypto: deanCryptoService);
      final alertRepo = MeshEmergencyRepository.inMemory();
      final dispRepo = MeshEmergencyDispatcherRepository.inMemory();
      final auditRepo = EmergencyAuditRepository.inMemory();

      final emService = CampusMeshEmergencyService(
        meshService: mesh,
        repository: alertRepo,
        cryptoService: deanCryptoService,
        mockTrustBundle: trustBundle,
        notifier: MockEmergencyNotifier(),
      );

      final dispatcher = MeshEmergencyDispatcherService(
        emergencyService: emService,
        dispatcherRepository: dispRepo,
        auditRepository: auditRepo,
        cryptoService: deanCryptoService,
      );

      await dispatcher.initialize();

      // First dispatch succeeds
      await dispatcher.createAndDispatchIncident(
        title: 'Tornado Watch',
        message: 'Monitor emergency channels',
        category: EmergencyCategory.weather,
        severity: EmergencySeverity.warning,
        scope: EmergencyScope.campus,
      );

      // Immediate duplicate dispatch must throw StateError
      await expectLater(
        dispatcher.createAndDispatchIncident(
          title: 'Tornado Watch',
          message: 'Monitor emergency channels',
          category: EmergencyCategory.weather,
          severity: EmergencySeverity.warning,
          scope: EmergencyScope.campus,
        ),
        throwsA(isA<StateError>()),
      );

      await dispatcher.dispose();
      await alertRepo.close();
      await dispRepo.close();
      await auditRepo.close();
    });

    // =========================================================================
    // GROUP F: Offline Operation (Zero Backend Dependency)
    // =========================================================================
    test('Group F: Dispatch succeeds 100% locally with zero internet or server connection', () async {
      final mesh = createMeshNode('dean_official', role: 'dean', crypto: deanCryptoService);
      final alertRepo = MeshEmergencyRepository.inMemory();
      final dispRepo = MeshEmergencyDispatcherRepository.inMemory();
      final auditRepo = EmergencyAuditRepository.inMemory();

      final emService = CampusMeshEmergencyService(
        meshService: mesh,
        repository: alertRepo,
        cryptoService: deanCryptoService,
        mockTrustBundle: trustBundle,
        notifier: MockEmergencyNotifier(),
      );

      final dispatcher = MeshEmergencyDispatcherService(
        emergencyService: emService,
        dispatcherRepository: dispRepo,
        auditRepository: auditRepo,
        cryptoService: deanCryptoService,
      );

      await dispatcher.initialize();

      // Completely offline execution
      final incident = await dispatcher.createAndDispatchIncident(
        title: 'Total Blackout',
        message: 'Generator down. Lights only.',
        category: EmergencyCategory.power,
        severity: EmergencySeverity.critical,
        scope: EmergencyScope.campus,
      );

      expect(incident.status, EmergencyIncidentStatus.active);
      expect(incident.issuerDeviceId, 'dean_official');

      await dispatcher.dispose();
      await alertRepo.close();
      await dispRepo.close();
      await auditRepo.close();
    });

    // =========================================================================
    // GROUP G: Immutable Append-Only Audit Trail
    // =========================================================================
    test('Group G: Audit trail records each event append-only without mutation', () async {
      final mesh = createMeshNode('node_dean_audit', role: 'dean', crypto: deanCryptoService);
      final alertRepo = MeshEmergencyRepository.inMemory();
      final dispRepo = MeshEmergencyDispatcherRepository.inMemory();
      final auditRepo = EmergencyAuditRepository.inMemory();

      final emService = CampusMeshEmergencyService(
        meshService: mesh,
        repository: alertRepo,
        cryptoService: deanCryptoService,
        mockTrustBundle: trustBundle,
        notifier: MockEmergencyNotifier(),
      );

      final dispatcher = MeshEmergencyDispatcherService(
        emergencyService: emService,
        dispatcherRepository: dispRepo,
        auditRepository: auditRepo,
        cryptoService: deanCryptoService,
      );

      await dispatcher.initialize();

      final incident = await dispatcher.createAndDispatchIncident(
        title: 'Flood Warning',
        message: 'River levels rising near East Gate',
        category: EmergencyCategory.cyclone,
        severity: EmergencySeverity.warning,
        scope: EmergencyScope.campus,
      );

      await dispatcher.cancelIncident(incident.incidentId, reason: 'Water receded');

      final events = await auditRepo.getEventsForIncident(incident.incidentId);

      // Verify sequence: CREATED -> SIGNED -> SENT -> CANCELLED
      expect(events.length, 4);
      expect(events[0].eventType, EmergencyAuditEventType.dispatchCreated);
      expect(events[1].eventType, EmergencyAuditEventType.dispatchSigned);
      expect(events[2].eventType, EmergencyAuditEventType.dispatchSent);
      expect(events[3].eventType, EmergencyAuditEventType.dispatchCancelled);
      expect(events[3].details['reason'], 'Water receded');

      // Records must be immutable
      final allEvents = await auditRepo.getAllEvents();
      expect(allEvents.length, 4);

      await dispatcher.dispose();
      await alertRepo.close();
      await dispRepo.close();
      await auditRepo.close();
    });

    // =========================================================================
    // GROUP H: Truthful Propagation Telemetry
    // =========================================================================
    test('Group H: Telemetry updates real hops, relays, and ACKs without fabrication', () async {
      final mesh = createMeshNode('node_dean_telemetry', role: 'dean', crypto: deanCryptoService);
      final alertRepo = MeshEmergencyRepository.inMemory();
      final dispRepo = MeshEmergencyDispatcherRepository.inMemory();
      final auditRepo = EmergencyAuditRepository.inMemory();

      final emService = CampusMeshEmergencyService(
        meshService: mesh,
        repository: alertRepo,
        cryptoService: deanCryptoService,
        mockTrustBundle: trustBundle,
        notifier: MockEmergencyNotifier(),
      );

      final dispatcher = MeshEmergencyDispatcherService(
        emergencyService: emService,
        dispatcherRepository: dispRepo,
        auditRepository: auditRepo,
        cryptoService: deanCryptoService,
      );

      await dispatcher.initialize();

      final incident = await dispatcher.createAndDispatchIncident(
        title: 'Building 4 Evacuation',
        message: 'Structural hazard detected',
        category: EmergencyCategory.evacuation,
        severity: EmergencySeverity.critical,
        scope: EmergencyScope.campus,
      );

      expect(incident.hopTelemetryDescription, 'Direct Origin (0 hops)');
      expect(incident.acknowledgementSummary, 'ACK telemetry unavailable (0 observed)');

      // Simulate a peer relay packet arriving over mesh
      final relayPayload = EmergencyPayload(
        title: 'Building 4 Evac',
        message: 'Hazard detected',
        scope: EmergencyScope.campus,
        severity: EmergencySeverity.critical,
        category: EmergencyCategory.evacuation,
        priority: EmergencyRelayPriority.critical,
        expiresAt: incident.expiresAt,
        issuerUserId: 'dean_official',
      );

      final relayPacket = MeshPacket(
        packetId: hexToBytes(incident.alertId),
        packetType: MeshPacketType.emergency,
        ttl: 4,
        hopCount: 3,
        senderDeviceId: 'dean_official',
        senderRole: 'dean',
        timestamp: DateTime.now(),
        payload: relayPayload.toBytes(),
      );

      final signedRelay = await deanCryptoService.signPacket(relayPacket);
      mesh.deduplicationStore.clear();
      await mesh.handleIncomingRawData(const MeshPacketCodec().encode(signedRelay));
      await Future.delayed(const Duration(milliseconds: 50));

      var updated = await dispRepo.getIncident(incident.incidentId);
      expect(updated!.hopCount, 3);
      expect(updated.relayCount, 2);
      expect(updated.localDeliveryCount, 1);
      expect(updated.hopTelemetryDescription, '3 hops relayed');

      // Simulate a real peer acknowledgement arriving over mesh
      final ackPayload = {
        'a': 'ack',
        'i': incident.incidentId,
        'al': incident.alertId,
      };

      final ackPacket = MeshPacket(
        packetId: MeshPacket.generatePacketId(),
        packetType: MeshPacketType.acknowledgement,
        ttl: 5,
        hopCount: 2,
        senderDeviceId: 'student_alice',
        senderRole: 'student',
        timestamp: DateTime.now(),
        payload: Uint8List.fromList(utf8.encode(jsonEncode(ackPayload))),
      );

      final signedAck = await studentCryptoService.signPacket(ackPacket);
      await mesh.handleIncomingRawData(const MeshPacketCodec().encode(signedAck));
      await Future.delayed(const Duration(milliseconds: 50));

      updated = await dispRepo.getIncident(incident.incidentId);
      expect(updated!.acknowledgementCount, 1);
      expect(updated.acknowledgementSummary, '1 local ACK observed');

      await dispatcher.dispose();
      await alertRepo.close();
      await dispRepo.close();
      await auditRepo.close();
    });

    // =========================================================================
    // GROUP I: Signed Cancellation Across Mesh
    // =========================================================================
    test('Group I: Remote peer receiving signed cancellation updates incident state', () async {
      final senderAdapter = MockMeshBleAdapter();
      final rxAdapter = MockMeshBleAdapter();
      senderAdapter.peerAdapter = rxAdapter;
      rxAdapter.peerAdapter = senderAdapter;

      final senderMesh = createMeshNode('dean_official', role: 'dean', crypto: deanCryptoService, adapter: senderAdapter);
      final receiverMesh = createMeshNode('admin_sys', role: 'admin', crypto: adminCryptoService, adapter: rxAdapter);
      await senderMesh.start();
      await receiverMesh.start();

      final senderAlertRepo = MeshEmergencyRepository.inMemory();
      final senderDispRepo = MeshEmergencyDispatcherRepository.inMemory();
      final senderAuditRepo = EmergencyAuditRepository.inMemory();

      final rxAlertRepo = MeshEmergencyRepository.inMemory();
      final rxDispRepo = MeshEmergencyDispatcherRepository.inMemory();
      final rxAuditRepo = EmergencyAuditRepository.inMemory();

      final senderEm = CampusMeshEmergencyService(
        meshService: senderMesh,
        repository: senderAlertRepo,
        cryptoService: deanCryptoService,
        mockTrustBundle: trustBundle,
        notifier: MockEmergencyNotifier(),
      );

      final rxEm = CampusMeshEmergencyService(
        meshService: receiverMesh,
        repository: rxAlertRepo,
        cryptoService: adminCryptoService,
        mockTrustBundle: trustBundle,
        notifier: MockEmergencyNotifier(),
      );

      final senderDispatcher = MeshEmergencyDispatcherService(
        emergencyService: senderEm,
        dispatcherRepository: senderDispRepo,
        auditRepository: senderAuditRepo,
        cryptoService: deanCryptoService,
      );

      final rxDispatcher = MeshEmergencyDispatcherService(
        emergencyService: rxEm,
        dispatcherRepository: rxDispRepo,
        auditRepository: rxAuditRepo,
        cryptoService: adminCryptoService,
      );

      await senderDispatcher.initialize();
      await rxDispatcher.initialize();

      // Dean creates incident
      final incident = await senderDispatcher.createAndDispatchIncident(
        title: 'Water Advisory',
        message: 'Boil water before use.',
        category: EmergencyCategory.other,
        severity: EmergencySeverity.advisory,
        scope: EmergencyScope.campus,
      );

      // Clone incident into receiver's repository as observed
      await rxDispRepo.saveIncident(incident);

      // Dean cancels incident
      await senderDispatcher.cancelIncident(
        incident.incidentId,
        reason: 'Water clear',
      );

      await Future.delayed(const Duration(milliseconds: 100));

      // Receiver must reflect cancellation
      final rxIncident = await rxDispRepo.getIncident(incident.incidentId);
      expect(rxIncident, isNotNull);
      expect(rxIncident!.isCancelled, isTrue);

      await senderDispatcher.dispose();
      await rxDispatcher.dispose();
      await senderAlertRepo.close();
      await senderDispRepo.close();
      await senderAuditRepo.close();
      await rxAlertRepo.close();
      await rxDispRepo.close();
      await rxAuditRepo.close();
    });

    // =========================================================================
    // GROUP J: UI Widget Tests
    // =========================================================================
    testWidgets('Group J: CampusMeshEmergencyDispatcherScreen renders authority badge, active incident, and cancel dialog', (tester) async {
      final mesh = createMeshNode('dean_official', role: 'dean', crypto: deanCryptoService);
      final alertRepo = MeshEmergencyRepository.inMemory();
      final dispRepo = MeshEmergencyDispatcherRepository.inMemory();
      final auditRepo = EmergencyAuditRepository.inMemory();

      final emService = CampusMeshEmergencyService(
        meshService: mesh,
        repository: alertRepo,
        cryptoService: deanCryptoService,
        mockTrustBundle: trustBundle,
        notifier: MockEmergencyNotifier(),
      );

      final dispatcher = MeshEmergencyDispatcherService(
        emergencyService: emService,
        dispatcherRepository: dispRepo,
        auditRepository: auditRepo,
        cryptoService: deanCryptoService,
      );

      await dispatcher.initialize(enablePeriodicExpiry: false);

      // Pre-seed an active incident
      await dispatcher.createAndDispatchIncident(
        title: 'Cyclone Alert',
        message: 'Wind > 100km/h. Shelter now.',
        category: EmergencyCategory.cyclone,
        severity: EmergencySeverity.critical,
        scope: EmergencyScope.campus,
      );

      await tester.pumpWidget(MaterialApp(
        home: CampusMeshEmergencyDispatcherScreen(dispatcherService: dispatcher),
      ));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // 1. Verify Authority Banner
      expect(find.text('AUTHORIZED · DEAN'), findsOneWidget);
      expect(find.text('Offline BLE Mesh Ready'), findsOneWidget);

      // 2. Verify Active Incident Card
      expect(find.text('Cyclone Alert'), findsOneWidget);
      expect(find.text('Wind > 100km/h. Shelter now.'), findsOneWidget);
      expect(find.text('CRITICAL'), findsOneWidget);
      expect(find.text('CYCLONE'), findsOneWidget);
      expect(find.text('CAMPUS'), findsOneWidget);
      expect(find.text('Issued by: DEAN • VERIFIED'), findsOneWidget);
      expect(find.text('Cancel Incident'), findsOneWidget);
      expect(find.text('Audit Trail'), findsOneWidget);

      // 3. Open Cancel Incident Dialog
      await tester.tap(find.text('Cancel Incident'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Cancel Emergency Incident'), findsOneWidget);
      expect(find.text('CONFIRM CANCELLATION'), findsOneWidget);

      // Cancel dialog
      await tester.tap(find.text('CANCEL'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Unmount screen before disposing dependencies
      await tester.pumpWidget(const SizedBox());

      await dispatcher.dispose();
      await alertRepo.close();
      await dispRepo.close();
      await auditRepo.close();
    });
  });
}
