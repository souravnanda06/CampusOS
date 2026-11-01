import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:cryptography/cryptography.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:attendance_app/auth/models/user_model.dart';
import 'package:attendance_app/student/models/passport_attendance_model.dart';
import 'package:attendance_app/student/models/passport_trust_bundle_model.dart';
import 'package:attendance_app/student/models/passport_proximity_observation.dart';
import 'package:attendance_app/student/services/passport_biometric_service.dart';
import 'package:attendance_app/student/services/passport_crypto_service.dart';
import 'package:attendance_app/student/services/passport_trust_bundle_service.dart';
import 'package:attendance_app/student/services/passport_attendance_ledger_service.dart';
import 'package:attendance_app/student/services/passport_student_attendance_service.dart';
import 'package:attendance_app/teacher/services/passport_teacher_attendance_service.dart';
import 'package:attendance_app/shared/services/attendance_service.dart';
import 'package:attendance_app/shared/services/session_service.dart';

/// In-memory storage fake for isolated cryptographic and trust bundle unit tests
class FakePassportKeyStorage implements PassportKeyStorage {
  final Map<String, String> _memory = {};

  @override
  Future<String?> read(String key) async => _memory[key];

  @override
  Future<void> write(String key, String value) async {
    _memory[key] = value;
  }

  @override
  Future<void> delete(String key) async {
    _memory.remove(key);
  }

  @override
  Future<bool> containsKey(String key) async => _memory.containsKey(key);
}

/// Fake biometric provider allowing deterministic verification of biometric-only gate
class FakePassportBiometricProvider implements PassportBiometricAuthProvider {
  bool willSucceed;
  BiometricAuthStatus? failureStatus;
  String? customMessage;

  FakePassportBiometricProvider({
    this.willSucceed = true,
    this.failureStatus,
    this.customMessage,
  });

  @override
  Future<bool> canCheckBiometrics() async => true;

  @override
  Future<bool> isDeviceSupported() async => true;

  @override
  Future<BiometricAuthResult> authenticateBiometricOnly({
    required String reason,
  }) async {
    if (willSucceed) {
      return BiometricAuthResult.success;
    } else {
      return BiometricAuthResult(
        status: failureStatus ?? BiometricAuthStatus.ownerMismatch,
        message: customMessage ?? 'Biometric verification failed (biometricOnly=true enforced)',
      );
    }
  }

  @override
  Future<BiometricAuthResult> authenticate({
    required String reason,
    bool biometricOnly = true,
  }) async {
    return authenticateBiometricOnly(reason: reason);
  }
}

/// Mock AttendanceService to verify sync idempotency
class MockAttendanceService extends AttendanceService {
  final List<Map<String, dynamic>> syncedBatches = [];
  int syncCallCount = 0;

  @override
  Future<Map<String, dynamic>> batchSync({
    required String sessionId,
    required List<Map<String, dynamic>> records,
  }) async {
    syncCallCount++;
    syncedBatches.addAll(records);
    return {
      'status': 'success',
      'newSynced': records.length,
      'duplicates': 0,
    };
  }
}

/// Helper to generate certified test trust bundles with N student identities
Future<PassportTrustBundle> createTrustBundleWithStudents({
  required SimpleKeyPair institutionKeyPair,
  required String institutionPubB64,
  required String teacherId,
  required String teacherKeyId,
  required String teacherPubB64,
  required List<Map<String, String>> studentDefs,
}) async {
  final nowSec = DateTime.now().toUtc().millisecondsSinceEpoch ~/ 1000;
  final identities = <Map<String, dynamic>>[
    {
      'certificateId': 'cert-teacher-01',
      'issuerKeyId': 'inst-root-key',
      'keyId': teacherKeyId,
      'publicKey': teacherPubB64,
      'status': 'ACTIVE',
      'userId': teacherId,
      'userName': 'Prof. Sharma',
      'validFrom': nowSec - 3600,
      'validTo': nowSec + 86400 * 30,
    }
  ];

  for (final s in studentDefs) {
    identities.add({
      'certificateId': 'cert-${s['userId']}',
      'issuerKeyId': 'inst-root-key',
      'keyId': s['keyId']!,
      'publicKey': s['pubB64']!,
      'status': 'ACTIVE',
      'userId': s['userId']!,
      'userName': s['name']!,
      'validFrom': nowSec - 3600,
      'validTo': nowSec + 86400 * 30,
    });
  }

  final payloadMap = {
    'version': 1,
    'issuerKeyId': 'inst-root-key',
    'generatedAt': nowSec - 3600,
    'expiresAt': nowSec + 86400 * 7,
    'institution': {
      'keyId': 'inst-root-key',
      'publicKey': institutionPubB64,
    },
    'identities': identities,
    'revokedKeyIds': <String>[],
  };

  final canonicalJson = canonicalizeJson(payloadMap);
  final sig = await Ed25519().sign(utf8.encode(canonicalJson), keyPair: institutionKeyPair);
  return PassportTrustBundle.fromJson({
    'payload': payloadMap,
    'signature': base64Encode(sig.bytes),
  });
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('CampusOS Passport 1I: Batch BLE Attendance + QR Fallback + Anti-Proxy Matrix', () {
    late Ed25519 ed25519;

    // Keys
    late SimpleKeyPair institutionKeyPair;
    late String institutionPubB64;

    late SimpleKeyPair teacherKeyPair;
    late String teacherPubB64;
    const String teacherKeyId = 'teacher-key-001';
    const String teacherId = 'teacher-uuid-001';

    late SimpleKeyPair studentKeyPair;
    late String studentPubB64;
    const String studentKeyId = 'student-device-key-42';
    const String studentId = 'student-uuid-42';

    late SimpleKeyPair attackerKeyPair;
    late String attackerPubB64;

    // Storage & Services
    late FakePassportKeyStorage studentStorage;
    late FakePassportKeyStorage teacherStorage;
    late PassportCryptoService studentCrypto;
    late PassportCryptoService teacherCrypto;
    late PassportTrustBundleService studentTrustBundleService;
    late PassportTrustBundleService teacherTrustBundleService;
    late PassportTrustBundle trustBundle;

    late UserModel studentUser;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      ed25519 = Ed25519();

      // 1. Generate keys
      institutionKeyPair = await ed25519.newKeyPair();
      final instPub = await institutionKeyPair.extractPublicKey();
      institutionPubB64 = base64Encode(instPub.bytes);

      teacherKeyPair = await ed25519.newKeyPair();
      final tPub = await teacherKeyPair.extractPublicKey();
      teacherPubB64 = base64Encode(tPub.bytes);

      studentKeyPair = await ed25519.newKeyPair();
      final sPub = await studentKeyPair.extractPublicKey();
      studentPubB64 = base64Encode(sPub.bytes);

      attackerKeyPair = await ed25519.newKeyPair();
      final aPub = await attackerKeyPair.extractPublicKey();
      attackerPubB64 = base64Encode(aPub.bytes);

      // 2. Setup storage and crypto
      studentStorage = FakePassportKeyStorage();
      teacherStorage = FakePassportKeyStorage();

      // Store student private key in fake storage
      final sPrivBytes = await studentKeyPair.extractPrivateKeyBytes();
      await studentStorage.write(
        PassportCryptoService.privateKeyStorageKey,
        base64Encode(sPrivBytes),
      );
      await studentStorage.write(
        PassportCryptoService.publicKeyStorageKey,
        studentPubB64,
      );
      await studentStorage.write('passport_device_key_id', studentKeyId);

      // Store teacher private key in teacher storage
      final tPrivBytes = await teacherKeyPair.extractPrivateKeyBytes();
      await teacherStorage.write(
        PassportCryptoService.privateKeyStorageKey,
        base64Encode(tPrivBytes),
      );
      await teacherStorage.write(
        PassportCryptoService.publicKeyStorageKey,
        teacherPubB64,
      );
      await teacherStorage.write('passport_device_key_id', teacherKeyId);

      studentCrypto = PassportCryptoService(storage: studentStorage);
      await studentCrypto.initialize();

      teacherCrypto = PassportCryptoService(storage: teacherStorage);
      await teacherCrypto.initialize();

      studentTrustBundleService = PassportTrustBundleService(
        storage: studentStorage,
        cryptoService: studentCrypto,
      );

      teacherTrustBundleService = PassportTrustBundleService(
        storage: teacherStorage,
        cryptoService: teacherCrypto,
      );

      // 3. Build a certified Phase 1F Trust Bundle containing institutional root, teacher, and student
      final nowSec = DateTime.now().toUtc().millisecondsSinceEpoch ~/ 1000;
      final payloadMap = {
        'version': 1,
        'issuerKeyId': 'inst-root-key',
        'generatedAt': nowSec - 3600,
        'expiresAt': nowSec + 86400 * 7,
        'institution': {
          'keyId': 'inst-root-key',
          'publicKey': institutionPubB64,
        },
        'identities': [
          {
            'certificateId': 'cert-student-42',
            'issuerKeyId': 'inst-root-key',
            'keyId': studentKeyId,
            'publicKey': studentPubB64,
            'status': 'ACTIVE',
            'userId': studentId,
            'userName': 'Alice Kumar',
            'validFrom': nowSec - 3600,
            'validTo': nowSec + 86400 * 30,
          },
          {
            'certificateId': 'cert-teacher-01',
            'issuerKeyId': 'inst-root-key',
            'keyId': teacherKeyId,
            'publicKey': teacherPubB64,
            'status': 'ACTIVE',
            'userId': teacherId,
            'userName': 'Prof. Sharma',
            'validFrom': nowSec - 3600,
            'validTo': nowSec + 86400 * 30,
          }
        ],
        'revokedKeyIds': <String>[],
      };

      final canonicalJson = canonicalizeJson(payloadMap);
      final sig = await ed25519.sign(utf8.encode(canonicalJson), keyPair: institutionKeyPair);
      trustBundle = PassportTrustBundle.fromJson({
        'payload': payloadMap,
        'signature': base64Encode(sig.bytes),
      });

      await studentStorage.write(
        PassportTrustBundleService.trustBundleStorageKey,
        jsonEncode(trustBundle.toJson()),
      );
      await teacherStorage.write(
        PassportTrustBundleService.trustBundleStorageKey,
        jsonEncode(trustBundle.toJson()),
      );

      studentUser = UserModel(
        id: studentId,
        name: 'Alice Kumar',
        email: 'alice@campusos.edu',
        role: 'student',
        registrationNumber: 'CS2026-042',
        course: 'B.Tech',
        branch: 'CSE',
        year: '3',
      );
    });

    // =========================================================================
    // SECTION 1: TEACHER BEACON (Tests 1-6)
    // =========================================================================
    group('Teacher Beacon Verification', () {
      test('1. valid teacher beacon accepted', () async {
        final nowSec = DateTime.now().toUtc().millisecondsSinceEpoch ~/ 1000;
        final nonce = PassportAttendanceModel.generateSecureSessionNonce();

        final beacon = PassportTeacherBeaconModel(
          protocolVersion: PassportAttendanceModel.currentVersion,
          sessionId: 'session-cs301-01',
          teacherId: teacherId,
          teacherKeyId: teacherKeyId,
          sessionNonce: nonce,
          issuedAt: nowSec - 5,
          expiresAt: nowSec + 300,
          course: 'B.Tech',
          branch: 'CSE',
          subject: 'Operating Systems',
        );

        final canonical = beacon.toCanonicalJson();
        final sig = await teacherCrypto.signPresentation(canonical);
        final signedBeacon = beacon.withSignature(sig);

        final studentAttendance = PassportStudentAttendanceService(
          cryptoService: studentCrypto,
          trustBundleService: studentTrustBundleService,
        );

        final isValid = await studentAttendance.verifyTeacherBeacon(
          signedBeacon,
          currentTimestampSeconds: nowSec,
        );
        expect(isValid, isTrue);
      });

      test('2. fake teacher beacon rejected', () async {
        final nowSec = DateTime.now().toUtc().millisecondsSinceEpoch ~/ 1000;
        final nonce = PassportAttendanceModel.generateSecureSessionNonce();

        // Attacker creates a beacon signed with attacker key
        final attackerStorage = FakePassportKeyStorage();
        final aPriv = await attackerKeyPair.extractPrivateKeyBytes();
        await attackerStorage.write(
          PassportCryptoService.privateKeyStorageKey,
          base64Encode(aPriv),
        );
        await attackerStorage.write(
          PassportCryptoService.publicKeyStorageKey,
          attackerPubB64,
        );
        await attackerStorage.write('passport_device_key_id', 'attacker-key-999');

        final attackerCrypto = PassportCryptoService(storage: attackerStorage);
        await attackerCrypto.initialize();

        final beacon = PassportTeacherBeaconModel(
          protocolVersion: PassportAttendanceModel.currentVersion,
          sessionId: 'fake-session-cs301',
          teacherId: 'fake-teacher',
          teacherKeyId: 'attacker-key-999',
          sessionNonce: nonce,
          issuedAt: nowSec - 2,
          expiresAt: nowSec + 300,
        );

        final canonical = beacon.toCanonicalJson();
        final sig = await attackerCrypto.signPresentation(canonical);
        final signedBeacon = beacon.withSignature(sig);

        final studentAttendance = PassportStudentAttendanceService(
          cryptoService: studentCrypto,
          trustBundleService: studentTrustBundleService,
        );

        final isValid = await studentAttendance.verifyTeacherBeacon(
          signedBeacon,
          currentTimestampSeconds: nowSec,
        );
        expect(isValid, isFalse, reason: 'Beacon signed by unauthorized attacker key must be rejected');
      });

      test('3. malformed beacon rejected', () {
        expect(() => PassportTeacherBeaconModel.fromQrString('not-a-valid-json'),
            throwsA(isA<FormatException>()));

        expect(
          () => PassportTeacherBeaconModel.fromQrString('{"p":{"sid":"test"}}'),
          throwsA(anything),
        );
      });

      test('4. expired beacon rejected', () async {
        final nowSec = DateTime.now().toUtc().millisecondsSinceEpoch ~/ 1000;
        final nonce = PassportAttendanceModel.generateSecureSessionNonce();

        final expiredBeacon = PassportTeacherBeaconModel(
          protocolVersion: PassportAttendanceModel.currentVersion,
          sessionId: 'session-cs301-expired',
          teacherId: teacherId,
          teacherKeyId: teacherKeyId,
          sessionNonce: nonce,
          issuedAt: nowSec - 600,
          expiresAt: nowSec - 60, // Expired 60s ago
        );

        final canonical = expiredBeacon.toCanonicalJson();
        final sig = await teacherCrypto.signPresentation(canonical);
        final signedBeacon = expiredBeacon.withSignature(sig);

        final studentAttendance = PassportStudentAttendanceService(
          cryptoService: studentCrypto,
          trustBundleService: studentTrustBundleService,
        );

        final isValid = await studentAttendance.verifyTeacherBeacon(
          signedBeacon,
          currentTimestampSeconds: nowSec,
        );
        expect(isValid, isFalse, reason: 'Expired beacon must be rejected');
      });

      test('5. wrong session rejected', () async {
        final nowSec = DateTime.now().toUtc().millisecondsSinceEpoch ~/ 1000;
        final nonce = PassportAttendanceModel.generateSecureSessionNonce();

        final beacon = PassportTeacherBeaconModel(
          protocolVersion: PassportAttendanceModel.currentVersion,
          sessionId: 'session-cs301-01',
          teacherId: teacherId,
          teacherKeyId: teacherKeyId,
          sessionNonce: nonce,
          issuedAt: nowSec,
          expiresAt: nowSec + 300,
        );

        // Teacher service running session-cs301-01
        final teacherService = PassportTeacherAttendanceService(
          cryptoService: teacherCrypto,
          trustBundleService: teacherTrustBundleService,
        );
        teacherService.setActiveBeacon(beacon);

        // Student creates response bound to WRONG session
        final studentResp = PassportAttendanceResponseModel(
          version: PassportAttendanceModel.currentVersion,
          sessionId: 'session-WRONG-999',
          studentId: studentId,
          deviceKeyId: studentKeyId,
          challengeNonce: nonce,
          issuedAt: nowSec,
          expiresAt: nowSec + 15,
          biometricGate: true,
          responseNonce: PassportAttendanceModel.generateSecureSessionNonce(),
        );

        final signedResp = await studentResp.sign(studentCrypto);
        final result = await teacherService.verifyAttendanceResponse(
          signedResp,
          currentTimestampSeconds: nowSec,
        );

        expect(result.valid, isFalse);
        expect(result.reason, contains('Session ID mismatch'));
      });

      test('6. invalid signature/authentication rejected', () async {
        final nowSec = DateTime.now().toUtc().millisecondsSinceEpoch ~/ 1000;
        final nonce = PassportAttendanceModel.generateSecureSessionNonce();

        final beacon = PassportTeacherBeaconModel(
          protocolVersion: PassportAttendanceModel.currentVersion,
          sessionId: 'session-cs301-01',
          teacherId: teacherId,
          teacherKeyId: teacherKeyId,
          sessionNonce: nonce,
          issuedAt: nowSec,
          expiresAt: nowSec + 300,
          signature: base64Encode(Uint8List(64)), // Corrupted signature
        );

        final studentAttendance = PassportStudentAttendanceService(
          cryptoService: studentCrypto,
          trustBundleService: studentTrustBundleService,
        );

        final isValid = await studentAttendance.verifyTeacherBeacon(
          beacon,
          currentTimestampSeconds: nowSec,
        );
        expect(isValid, isFalse);
      });

      test('6a. valid trusted teacher beacon returns TRUSTED_AND_VERIFIED', () async {
        final nowSec = DateTime.now().toUtc().millisecondsSinceEpoch ~/ 1000;
        final nonce = PassportAttendanceModel.generateSecureSessionNonce();

        final beacon = PassportTeacherBeaconModel(
          protocolVersion: PassportAttendanceModel.currentVersion,
          sessionId: 'session-cs301-01',
          teacherId: teacherId,
          teacherKeyId: teacherKeyId,
          sessionNonce: nonce,
          issuedAt: nowSec,
          expiresAt: nowSec + 300,
        );
        final canonical = beacon.toCanonicalJson();
        final sig = await teacherCrypto.signPresentation(canonical);
        final signedBeacon = beacon.withSignature(sig);

        final studentAttendance = PassportStudentAttendanceService(
          cryptoService: studentCrypto,
          trustBundleService: studentTrustBundleService,
        );

        final result = await studentAttendance.verifyTeacherBeaconDetailed(
          signedBeacon,
          currentTimestampSeconds: nowSec,
        );

        expect(result.isValid, isTrue);
        expect(result.status, equals(TeacherBeaconVerificationStatus.trustedAndVerified));
        expect(result.code, equals('TRUSTED_AND_VERIFIED'));
      });

      test('6b. unknown teacher key returns UNKNOWN_KEY', () async {
        final nowSec = DateTime.now().toUtc().millisecondsSinceEpoch ~/ 1000;
        final nonce = PassportAttendanceModel.generateSecureSessionNonce();

        // Sign with teacherCrypto but give an unknown keyId
        final beacon = PassportTeacherBeaconModel(
          protocolVersion: PassportAttendanceModel.currentVersion,
          sessionId: 'session-cs301-01',
          teacherId: teacherId,
          teacherKeyId: 'unknown-key-999',
          sessionNonce: nonce,
          issuedAt: nowSec,
          expiresAt: nowSec + 300,
        );
        final canonical = beacon.toCanonicalJson();
        final sig = await teacherCrypto.signPresentation(canonical);
        final signedBeacon = beacon.withSignature(sig);

        final studentAttendance = PassportStudentAttendanceService(
          cryptoService: studentCrypto,
          trustBundleService: studentTrustBundleService,
        );

        final result = await studentAttendance.verifyTeacherBeaconDetailed(
          signedBeacon,
          currentTimestampSeconds: nowSec,
        );

        expect(result.isValid, isFalse);
        expect(result.status, equals(TeacherBeaconVerificationStatus.unknownKey));
        expect(result.code, equals('UNKNOWN_KEY'));
      });

      test('6c. missing trust bundle fails closed with TRUST_BUNDLE_UNAVAILABLE (no soft fallback)', () async {
        final nowSec = DateTime.now().toUtc().millisecondsSinceEpoch ~/ 1000;
        final nonce = PassportAttendanceModel.generateSecureSessionNonce();

        final beacon = PassportTeacherBeaconModel(
          protocolVersion: PassportAttendanceModel.currentVersion,
          sessionId: 'session-cs301-01',
          teacherId: teacherId,
          teacherKeyId: teacherKeyId,
          sessionNonce: nonce,
          issuedAt: nowSec,
          expiresAt: nowSec + 300,
        );
        final canonical = beacon.toCanonicalJson();
        final sig = await teacherCrypto.signPresentation(canonical);
        final signedBeacon = beacon.withSignature(sig);

        // Student service with empty storage (no trust bundle cached)
        final emptyStorage = FakePassportKeyStorage();
        final emptyTrustService = PassportTrustBundleService(storage: emptyStorage, cryptoService: studentCrypto);
        final studentAttendance = PassportStudentAttendanceService(
          cryptoService: studentCrypto,
          trustBundleService: emptyTrustService,
        );

        final result = await studentAttendance.verifyTeacherBeaconDetailed(
          signedBeacon,
          currentTimestampSeconds: nowSec,
        );

        expect(result.isValid, isFalse, reason: 'Must fail closed when trust bundle is missing');
        expect(result.status, equals(TeacherBeaconVerificationStatus.trustBundleUnavailable));
        expect(result.code, equals('TRUST_BUNDLE_UNAVAILABLE'));
      });

      test('6d. invalid signature returns INVALID_SIGNATURE', () async {
        final nowSec = DateTime.now().toUtc().millisecondsSinceEpoch ~/ 1000;
        final nonce = PassportAttendanceModel.generateSecureSessionNonce();

        final beacon = PassportTeacherBeaconModel(
          protocolVersion: PassportAttendanceModel.currentVersion,
          sessionId: 'session-cs301-01',
          teacherId: teacherId,
          teacherKeyId: teacherKeyId,
          sessionNonce: nonce,
          issuedAt: nowSec,
          expiresAt: nowSec + 300,
          signature: base64Encode(Uint8List(64)), // corrupted signature
        );

        final studentAttendance = PassportStudentAttendanceService(
          cryptoService: studentCrypto,
          trustBundleService: studentTrustBundleService,
        );

        final result = await studentAttendance.verifyTeacherBeaconDetailed(
          beacon,
          currentTimestampSeconds: nowSec,
        );

        expect(result.isValid, isFalse);
        expect(result.status, equals(TeacherBeaconVerificationStatus.invalidSignature));
        expect(result.code, equals('INVALID_SIGNATURE'));
      });

      test('6e. expired key certificate returns UNKNOWN_KEY', () async {
        final nowSec = DateTime.now().toUtc().millisecondsSinceEpoch ~/ 1000;
        final nonce = PassportAttendanceModel.generateSecureSessionNonce();

        // Create trust bundle where teacher key expired in the past
        final expiredTrustBundle = await createTrustBundleWithStudents(
          institutionKeyPair: institutionKeyPair,
          institutionPubB64: institutionPubB64,
          teacherId: teacherId,
          teacherKeyId: teacherKeyId,
          teacherPubB64: teacherPubB64,
          studentDefs: [],
        );
        // Modify validity window to be in the past
        final expiredPayload = Map<String, dynamic>.from(expiredTrustBundle.rawPayload);
        final idList = List<Map<String, dynamic>>.from(expiredPayload['identities']);
        idList[0]['validTo'] = nowSec - 100; // expired 100s ago
        expiredPayload['identities'] = idList;
        final expiredCan = canonicalizeJson(expiredPayload);
        final expiredSig = await Ed25519().sign(utf8.encode(expiredCan), keyPair: institutionKeyPair);

        final expiredStorage = FakePassportKeyStorage();
        await expiredStorage.write(
          PassportTrustBundleService.trustBundleStorageKey,
          jsonEncode({
            'payload': expiredPayload,
            'signature': base64Encode(expiredSig.bytes),
          }),
        );
        final expiredTrustService = PassportTrustBundleService(storage: expiredStorage, cryptoService: studentCrypto);

        final beacon = PassportTeacherBeaconModel(
          protocolVersion: PassportAttendanceModel.currentVersion,
          sessionId: 'session-cs301-01',
          teacherId: teacherId,
          teacherKeyId: teacherKeyId,
          sessionNonce: nonce,
          issuedAt: nowSec,
          expiresAt: nowSec + 300,
        );
        final canonical = beacon.toCanonicalJson();
        final sig = await teacherCrypto.signPresentation(canonical);
        final signedBeacon = beacon.withSignature(sig);

        final studentAttendance = PassportStudentAttendanceService(
          cryptoService: studentCrypto,
          trustBundleService: expiredTrustService,
        );

        final result = await studentAttendance.verifyTeacherBeaconDetailed(
          signedBeacon,
          currentTimestampSeconds: nowSec,
        );

        expect(result.isValid, isFalse);
        expect(result.status, equals(TeacherBeaconVerificationStatus.unknownKey));
      });

      test('6f. expired session returns EXPIRED_SESSION', () async {
        final nowSec = DateTime.now().toUtc().millisecondsSinceEpoch ~/ 1000;
        final nonce = PassportAttendanceModel.generateSecureSessionNonce();

        final beacon = PassportTeacherBeaconModel(
          protocolVersion: PassportAttendanceModel.currentVersion,
          sessionId: 'session-cs301-01',
          teacherId: teacherId,
          teacherKeyId: teacherKeyId,
          sessionNonce: nonce,
          issuedAt: nowSec - 600,
          expiresAt: nowSec - 10, // Expired 10s ago
        );
        final canonical = beacon.toCanonicalJson();
        final sig = await teacherCrypto.signPresentation(canonical);
        final signedBeacon = beacon.withSignature(sig);

        final studentAttendance = PassportStudentAttendanceService(
          cryptoService: studentCrypto,
          trustBundleService: studentTrustBundleService,
        );

        final result = await studentAttendance.verifyTeacherBeaconDetailed(
          signedBeacon,
          currentTimestampSeconds: nowSec,
        );

        expect(result.isValid, isFalse);
        expect(result.status, equals(TeacherBeaconVerificationStatus.expiredSession));
        expect(result.code, equals('EXPIRED_SESSION'));
      });

      test('6g. tampered payload returns INVALID_SIGNATURE', () async {
        final nowSec = DateTime.now().toUtc().millisecondsSinceEpoch ~/ 1000;
        final nonce = PassportAttendanceModel.generateSecureSessionNonce();

        final beacon = PassportTeacherBeaconModel(
          protocolVersion: PassportAttendanceModel.currentVersion,
          sessionId: 'session-cs301-01',
          teacherId: teacherId,
          teacherKeyId: teacherKeyId,
          sessionNonce: nonce,
          issuedAt: nowSec,
          expiresAt: nowSec + 300,
        );
        final canonical = beacon.toCanonicalJson();
        final sig = await teacherCrypto.signPresentation(canonical);

        // Tamper with subject after signing
        final tamperedBeacon = PassportTeacherBeaconModel(
          protocolVersion: PassportAttendanceModel.currentVersion,
          sessionId: 'session-cs301-01',
          teacherId: teacherId,
          teacherKeyId: teacherKeyId,
          sessionNonce: nonce,
          issuedAt: nowSec,
          expiresAt: nowSec + 300,
          subject: 'TAMPERED_SUBJECT',
          signature: sig,
        );

        final studentAttendance = PassportStudentAttendanceService(
          cryptoService: studentCrypto,
          trustBundleService: studentTrustBundleService,
        );

        final result = await studentAttendance.verifyTeacherBeaconDetailed(
          tamperedBeacon,
          currentTimestampSeconds: nowSec,
        );

        expect(result.isValid, isFalse);
        expect(result.status, equals(TeacherBeaconVerificationStatus.invalidSignature));
      });

      test('6h. offline valid trust bundle succeeds without network connection', () async {
        final nowSec = DateTime.now().toUtc().millisecondsSinceEpoch ~/ 1000;
        final nonce = PassportAttendanceModel.generateSecureSessionNonce();

        final beacon = PassportTeacherBeaconModel(
          protocolVersion: PassportAttendanceModel.currentVersion,
          sessionId: 'session-cs301-offline',
          teacherId: teacherId,
          teacherKeyId: teacherKeyId,
          sessionNonce: nonce,
          issuedAt: nowSec,
          expiresAt: nowSec + 300,
        );
        final canonical = beacon.toCanonicalJson();
        final sig = await teacherCrypto.signPresentation(canonical);
        final signedBeacon = beacon.withSignature(sig);

        // Completely offline student attendance instance using local trust bundle
        final studentAttendance = PassportStudentAttendanceService(
          cryptoService: studentCrypto,
          trustBundleService: studentTrustBundleService,
        );

        final result = await studentAttendance.verifyTeacherBeaconDetailed(
          signedBeacon,
          currentTimestampSeconds: nowSec,
        );

        expect(result.isValid, isTrue);
        expect(result.status, equals(TeacherBeaconVerificationStatus.trustedAndVerified));
        expect(result.teacherIdentity?.userName, equals('Prof. Sharma'));
      });
    });

    // =========================================================================
    // SECTION 2: STUDENT ATTENDANCE & BIOMETRIC GATE (Tests 7-14)
    // =========================================================================
    group('Student Flow and Biometric Liveness Gate', () {
      test('7. valid session detected and parsed', () async {
        final nowSec = DateTime.now().toUtc().millisecondsSinceEpoch ~/ 1000;
        final nonce = PassportAttendanceModel.generateSecureSessionNonce();

        final beacon = PassportTeacherBeaconModel(
          protocolVersion: PassportAttendanceModel.currentVersion,
          sessionId: 'session-cs301-01',
          teacherId: teacherId,
          teacherKeyId: teacherKeyId,
          sessionNonce: nonce,
          issuedAt: nowSec,
          expiresAt: nowSec + 300,
          subject: 'Computer Networks',
        );

        final canonical = beacon.toCanonicalJson();
        final sig = await teacherCrypto.signPresentation(canonical);
        final signedBeacon = beacon.withSignature(sig);

        final jsonStr = signedBeacon.toQrString();
        final parsed = PassportTeacherBeaconModel.fromQrString(jsonStr);

        expect(parsed.sessionId, equals('session-cs301-01'));
        expect(parsed.sessionNonce, equals(nonce));
        expect(parsed.subject, equals('Computer Networks'));
      });

      test('8. biometric success allows signing', () async {
        final bioProvider = FakePassportBiometricProvider(willSucceed: true);
        final bioResult = await bioProvider.authenticateBiometricOnly(
          reason: 'Biometric liveness for attendance',
        );

        expect(bioResult.isSuccess, isTrue);

        final studentService = PassportStudentAttendanceService(
          cryptoService: studentCrypto,
          trustBundleService: studentTrustBundleService,
          biometricService: bioProvider,
        );

        final beacon = PassportTeacherBeaconModel(
          protocolVersion: PassportAttendanceModel.currentVersion,
          sessionId: 'session-cs301-01',
          teacherId: teacherId,
          teacherKeyId: teacherKeyId,
          sessionNonce: PassportAttendanceModel.generateSecureSessionNonce(),
          issuedAt: 1000,
          expiresAt: 2000,
        );

        final resp = await studentService.createAndSignResponse(
          beacon: beacon,
          currentUser: studentUser,
          currentTimestampSeconds: 1500,
        );

        expect(resp.signature, isNotEmpty);
        expect(resp.biometricGate, isTrue);
        expect(resp.challengeNonce, equals(beacon.sessionNonce));
      });

      test('9. biometric failure blocks signing (OWNER_MISMATCH)', () async {
        final bioProvider = FakePassportBiometricProvider(
          willSucceed: false,
          failureStatus: BiometricAuthStatus.ownerMismatch,
          customMessage: 'Owner mismatch: unauthorized face/fingerprint detected.',
        );

        final bioResult = await bioProvider.authenticateBiometricOnly(
          reason: 'Verify owner biometric',
        );

        expect(bioResult.isSuccess, isFalse);
        expect(bioResult.status, equals(BiometricAuthStatus.ownerMismatch));
      });

      test('10. biometric cancellation blocks signing', () async {
        final bioProvider = FakePassportBiometricProvider(
          willSucceed: false,
          failureStatus: BiometricAuthStatus.cancelled,
          customMessage: 'Biometric prompt canceled by user',
        );

        final bioResult = await bioProvider.authenticateBiometricOnly(
          reason: 'Verify owner biometric',
        );

        expect(bioResult.isSuccess, isFalse);
        expect(bioResult.status, equals(BiometricAuthStatus.cancelled));
      });

      test('11. PIN/device credential fallback is not accepted (biometricOnly=true enforced)', () async {
        final bioProvider = FakePassportBiometricProvider(
          willSucceed: false,
          failureStatus: BiometricAuthStatus.biometricRequired,
          customMessage: 'Device PIN/pattern fallback is strictly prohibited for attendance.',
        );

        final bioResult = await bioProvider.authenticateBiometricOnly(
          reason: 'Verify owner biometric',
        );

        expect(bioResult.isSuccess, isFalse);
        expect(bioResult.status, equals(BiometricAuthStatus.biometricRequired));
      });

      test('12. response contains correct session nonce', () async {
        final nonce = PassportAttendanceModel.generateSecureSessionNonce();
        final beacon = PassportTeacherBeaconModel(
          protocolVersion: PassportAttendanceModel.currentVersion,
          sessionId: 'session-cs301-01',
          teacherId: teacherId,
          teacherKeyId: teacherKeyId,
          sessionNonce: nonce,
          issuedAt: 1000,
          expiresAt: 2000,
        );

        final studentService = PassportStudentAttendanceService(
          cryptoService: studentCrypto,
          trustBundleService: studentTrustBundleService,
        );

        final resp = await studentService.createAndSignResponse(
          beacon: beacon,
          currentUser: studentUser,
          currentTimestampSeconds: 1500,
        );

        expect(resp.challengeNonce, equals(nonce));
      });

      test('13. response expires after short window (15s)', () {
        final nowSec = DateTime.now().toUtc().millisecondsSinceEpoch ~/ 1000;
        final resp = PassportAttendanceResponseModel(
          version: 1,
          sessionId: 'session-cs301-01',
          studentId: studentId,
          deviceKeyId: studentKeyId,
          challengeNonce: 'session_nonce_xyz',
          issuedAt: nowSec - 25,
          expiresAt: nowSec - 10, // Expired 10s ago
          biometricGate: true,
          responseNonce: 'resp_nonce_123',
        );

        expect(resp.isExpired(nowSec), isTrue);
      });

      test('14. response cannot be reused (idempotency identity)', () {
        const resp = PassportAttendanceResponseModel(
          version: 1,
          sessionId: 'session-cs301-01',
          studentId: studentId,
          deviceKeyId: studentKeyId,
          challengeNonce: 'session_nonce_xyz',
          issuedAt: 1000,
          expiresAt: 1015,
          biometricGate: true,
          responseNonce: 'nonce_abc_123',
        );

        const expectedKey = 'att_session-cs301-01_${studentKeyId}_nonce_abc_123';
        expect(resp.idempotencyKey, equals(expectedKey));

        final ledger = PassportAttendanceLedgerService();
        expect(ledger.isDuplicate(resp.idempotencyKey), isFalse);

        ledger.recordAttendanceIdempotency(resp.idempotencyKey);
        expect(ledger.isDuplicate(resp.idempotencyKey), isTrue);
      });
    });

    // =========================================================================
    // SECTION 3: CRYPTOGRAPHIC VERIFICATION (Tests 15-20)
    // =========================================================================
    group('Cryptographic Verification Order', () {
      test('15. valid Ed25519 response accepted', () async {
        final nowSec = DateTime.now().toUtc().millisecondsSinceEpoch ~/ 1000;
        final nonce = PassportAttendanceModel.generateSecureSessionNonce();

        final teacherService = PassportTeacherAttendanceService(
          cryptoService: teacherCrypto,
          trustBundleService: teacherTrustBundleService,
        );
        final beacon = PassportTeacherBeaconModel(
          protocolVersion: 1,
          sessionId: 'session-cs301-01',
          teacherId: teacherId,
          teacherKeyId: teacherKeyId,
          sessionNonce: nonce,
          issuedAt: nowSec,
          expiresAt: nowSec + 300,
        );
        teacherService.setActiveBeacon(beacon);

        final resp = PassportAttendanceResponseModel(
          version: 1,
          sessionId: 'session-cs301-01',
          studentId: studentId,
          deviceKeyId: studentKeyId,
          challengeNonce: nonce,
          issuedAt: nowSec,
          expiresAt: nowSec + 15,
          biometricGate: true,
          responseNonce: PassportAttendanceModel.generateSecureSessionNonce(),
        );

        final signedResp = await resp.sign(studentCrypto);

        final result = await teacherService.verifyAttendanceResponse(
          signedResp,
          rssiSamples: [-65, -64, -66],
          currentTimestampSeconds: nowSec,
        );

        expect(result.valid, isTrue);
        expect(result.studentName, equals('Alice Kumar'));
      });

      test('16. tampered response rejected', () async {
        final nowSec = DateTime.now().toUtc().millisecondsSinceEpoch ~/ 1000;
        final nonce = PassportAttendanceModel.generateSecureSessionNonce();

        final teacherService = PassportTeacherAttendanceService(
          cryptoService: teacherCrypto,
          trustBundleService: teacherTrustBundleService,
        );
        final beacon = PassportTeacherBeaconModel(
          protocolVersion: 1,
          sessionId: 'session-cs301-01',
          teacherId: teacherId,
          teacherKeyId: teacherKeyId,
          sessionNonce: nonce,
          issuedAt: nowSec,
          expiresAt: nowSec + 300,
        );
        teacherService.setActiveBeacon(beacon);

        final resp = PassportAttendanceResponseModel(
          version: 1,
          sessionId: 'session-cs301-01',
          studentId: studentId,
          deviceKeyId: studentKeyId,
          challengeNonce: nonce,
          issuedAt: nowSec,
          expiresAt: nowSec + 15,
          biometricGate: true,
          responseNonce: PassportAttendanceModel.generateSecureSessionNonce(),
        );

        final signedResp = await resp.sign(studentCrypto);

        // Tamper with studentId after signature was calculated
        final tampered = signedResp.copyWith(studentId: 'student-attacker-999');

        final result = await teacherService.verifyAttendanceResponse(
          tampered,
          currentTimestampSeconds: nowSec,
        );

        expect(result.valid, isFalse);
      });

      test('17. wrong student key rejected', () async {
        final nowSec = DateTime.now().toUtc().millisecondsSinceEpoch ~/ 1000;
        final nonce = PassportAttendanceModel.generateSecureSessionNonce();

        final teacherService = PassportTeacherAttendanceService(
          cryptoService: teacherCrypto,
          trustBundleService: teacherTrustBundleService,
        );
        final beacon = PassportTeacherBeaconModel(
          protocolVersion: 1,
          sessionId: 'session-cs301-01',
          teacherId: teacherId,
          teacherKeyId: teacherKeyId,
          sessionNonce: nonce,
          issuedAt: nowSec,
          expiresAt: nowSec + 300,
        );
        teacherService.setActiveBeacon(beacon);

        // Attacker signs using attacker's key but claims studentKeyId
        final attackerStorage = FakePassportKeyStorage();
        final aPriv = await attackerKeyPair.extractPrivateKeyBytes();
        await attackerStorage.write(
          PassportCryptoService.privateKeyStorageKey,
          base64Encode(aPriv),
        );
        await attackerStorage.write(
          PassportCryptoService.publicKeyStorageKey,
          attackerPubB64,
        );
        await attackerStorage.write('passport_device_key_id', studentKeyId);

        final attackerCrypto = PassportCryptoService(storage: attackerStorage);
        await attackerCrypto.initialize();

        final resp = PassportAttendanceResponseModel(
          version: 1,
          sessionId: 'session-cs301-01',
          studentId: studentId,
          deviceKeyId: studentKeyId,
          challengeNonce: nonce,
          issuedAt: nowSec,
          expiresAt: nowSec + 15,
          biometricGate: true,
          responseNonce: PassportAttendanceModel.generateSecureSessionNonce(),
        );

        final signedByAttacker = await resp.sign(attackerCrypto);

        final result = await teacherService.verifyAttendanceResponse(
          signedByAttacker,
          currentTimestampSeconds: nowSec,
        );

        expect(result.valid, isFalse);
        expect(result.reason, contains('Ed25519 signature'));
      });

      test('18. wrong device key rejected (unregistered device key)', () async {
        final nowSec = DateTime.now().toUtc().millisecondsSinceEpoch ~/ 1000;
        final nonce = PassportAttendanceModel.generateSecureSessionNonce();

        final teacherService = PassportTeacherAttendanceService(
          cryptoService: teacherCrypto,
          trustBundleService: teacherTrustBundleService,
        );
        final beacon = PassportTeacherBeaconModel(
          protocolVersion: 1,
          sessionId: 'session-cs301-01',
          teacherId: teacherId,
          teacherKeyId: teacherKeyId,
          sessionNonce: nonce,
          issuedAt: nowSec,
          expiresAt: nowSec + 300,
        );
        teacherService.setActiveBeacon(beacon);

        final resp = PassportAttendanceResponseModel(
          version: 1,
          sessionId: 'session-cs301-01',
          studentId: studentId,
          deviceKeyId: 'unknown-device-key-999',
          challengeNonce: nonce,
          issuedAt: nowSec,
          expiresAt: nowSec + 15,
          biometricGate: true,
          responseNonce: PassportAttendanceModel.generateSecureSessionNonce(),
        );

        final signedResp = await resp.sign(studentCrypto);

        final result = await teacherService.verifyAttendanceResponse(
          signedResp,
          currentTimestampSeconds: nowSec,
        );

        expect(result.valid, isFalse);
        expect(result.reason, contains('not found'));
      });

      test('19. revoked key rejected', () async {
        final nowSec = DateTime.now().toUtc().millisecondsSinceEpoch ~/ 1000;
        final nonce = PassportAttendanceModel.generateSecureSessionNonce();

        // Mark student key as REVOKED in trust bundle
        final revokedPayload = Map<String, dynamic>.from(trustBundle.rawPayload);
        final identities = List<Map<String, dynamic>>.from(revokedPayload['identities']);
        identities[0]['status'] = 'REVOKED';
        revokedPayload['identities'] = identities;

        final canonicalJson = canonicalizeJson(revokedPayload);
        final sig = await ed25519.sign(utf8.encode(canonicalJson), keyPair: institutionKeyPair);
        final revokedBundle = PassportTrustBundle.fromJson({
          'payload': revokedPayload,
          'signature': base64Encode(sig.bytes),
        });

        await teacherStorage.write(
          PassportTrustBundleService.trustBundleStorageKey,
          jsonEncode(revokedBundle.toJson()),
        );

        final freshTeacherTrustService = PassportTrustBundleService(
          storage: teacherStorage,
          cryptoService: teacherCrypto,
        );

        final teacherService = PassportTeacherAttendanceService(
          cryptoService: teacherCrypto,
          trustBundleService: freshTeacherTrustService,
        );
        final beacon = PassportTeacherBeaconModel(
          protocolVersion: 1,
          sessionId: 'session-cs301-01',
          teacherId: teacherId,
          teacherKeyId: teacherKeyId,
          sessionNonce: nonce,
          issuedAt: nowSec,
          expiresAt: nowSec + 300,
        );
        teacherService.setActiveBeacon(beacon);

        final resp = PassportAttendanceResponseModel(
          version: 1,
          sessionId: 'session-cs301-01',
          studentId: studentId,
          deviceKeyId: studentKeyId,
          challengeNonce: nonce,
          issuedAt: nowSec,
          expiresAt: nowSec + 15,
          biometricGate: true,
          responseNonce: PassportAttendanceModel.generateSecureSessionNonce(),
        );

        final signedResp = await resp.sign(studentCrypto);

        final result = await teacherService.verifyAttendanceResponse(
          signedResp,
          currentTimestampSeconds: nowSec,
        );

        expect(result.valid, isFalse);
        expect(result.reason, contains('revoked'));
      });

      test('20. expired certificate rejected', () async {
        final nowSec = DateTime.now().toUtc().millisecondsSinceEpoch ~/ 1000;
        final nonce = PassportAttendanceModel.generateSecureSessionNonce();

        // Mark student certificate as expired
        final expiredPayload = Map<String, dynamic>.from(trustBundle.rawPayload);
        final identities = List<Map<String, dynamic>>.from(expiredPayload['identities']);
        identities[0]['validTo'] = nowSec - 100; // Expired 100s ago
        expiredPayload['identities'] = identities;

        final canonicalJson = canonicalizeJson(expiredPayload);
        final sig = await ed25519.sign(utf8.encode(canonicalJson), keyPair: institutionKeyPair);
        final expiredBundle = PassportTrustBundle.fromJson({
          'payload': expiredPayload,
          'signature': base64Encode(sig.bytes),
        });

        await teacherStorage.write(
          PassportTrustBundleService.trustBundleStorageKey,
          jsonEncode(expiredBundle.toJson()),
        );

        final freshTeacherTrustService = PassportTrustBundleService(
          storage: teacherStorage,
          cryptoService: teacherCrypto,
        );

        final teacherService = PassportTeacherAttendanceService(
          cryptoService: teacherCrypto,
          trustBundleService: freshTeacherTrustService,
        );
        final beacon = PassportTeacherBeaconModel(
          protocolVersion: 1,
          sessionId: 'session-cs301-01',
          teacherId: teacherId,
          teacherKeyId: teacherKeyId,
          sessionNonce: nonce,
          issuedAt: nowSec,
          expiresAt: nowSec + 300,
        );
        teacherService.setActiveBeacon(beacon);

        final resp = PassportAttendanceResponseModel(
          version: 1,
          sessionId: 'session-cs301-01',
          studentId: studentId,
          deviceKeyId: studentKeyId,
          challengeNonce: nonce,
          issuedAt: nowSec,
          expiresAt: nowSec + 15,
          biometricGate: true,
          responseNonce: PassportAttendanceModel.generateSecureSessionNonce(),
        );

        final signedResp = await resp.sign(studentCrypto);

        final result = await teacherService.verifyAttendanceResponse(
          signedResp,
          currentTimestampSeconds: nowSec,
        );

        expect(result.valid, isFalse);
        expect(result.reason, contains('certificate expired'));
      });
    });

    // =========================================================================
    // SECTION 4: PROXIMITY & RSSI (Tests 21-25)
    // =========================================================================
    group('Proximity and RSSI Tiers', () {
      late PassportTeacherAttendanceService teacherService;

      setUp(() {
        teacherService = PassportTeacherAttendanceService(
          cryptoService: teacherCrypto,
          trustBundleService: teacherTrustBundleService,
        );
      });

      test('21. strong RSSI accepted (NEAR >= -70 dBm with low spread)', () {
        final samples = [-65, -62, -64, -66, -63];
        final tier = teacherService.evaluateRssiProximity(samples);
        expect(tier, equals(PassportProximityTier.near));
      });

      test('22. weak RSSI becomes inconclusive (FAR < -75 dBm)', () {
        final samples = [-82, -85, -80, -84, -81];
        final tier = teacherService.evaluateRssiProximity(samples);
        expect(tier, equals(PassportProximityTier.far));
      });

      test('23. unstable RSSI becomes inconclusive (UNSTABLE spread > 18 dBm)', () {
        final samples = [-55, -92, -60, -95, -58]; // spread = 40 dBm
        final tier = teacherService.evaluateRssiProximity(samples);
        expect(tier, equals(PassportProximityTier.unstable));
      });

      test('24. insufficient samples becomes unknown (sample count < 3)', () {
        final samples = [-65, -66]; // Only 2 samples
        final tier = teacherService.evaluateRssiProximity(samples);
        expect(tier, equals(PassportProximityTier.unknown));
      });

      test('25. RSSI cannot make invalid crypto valid', () async {
        final nowSec = DateTime.now().toUtc().millisecondsSinceEpoch ~/ 1000;
        final nonce = PassportAttendanceModel.generateSecureSessionNonce();

        final beacon = PassportTeacherBeaconModel(
          protocolVersion: 1,
          sessionId: 'session-cs301-01',
          teacherId: teacherId,
          teacherKeyId: teacherKeyId,
          sessionNonce: nonce,
          issuedAt: nowSec,
          expiresAt: nowSec + 300,
        );
        teacherService.setActiveBeacon(beacon);

        // Response with invalid signature
        final badResp = PassportAttendanceResponseModel(
          version: 1,
          sessionId: 'session-cs301-01',
          studentId: studentId,
          deviceKeyId: studentKeyId,
          challengeNonce: nonce,
          issuedAt: nowSec,
          expiresAt: nowSec + 15,
          biometricGate: true,
          responseNonce: PassportAttendanceModel.generateSecureSessionNonce(),
          signature: base64Encode(Uint8List(64)), // Invalid signature
        );

        final result = await teacherService.verifyAttendanceResponse(
          badResp,
          rssiSamples: [-50, -52, -51, -50], // Extremely strong RSSI (-50 dBm)
          currentTimestampSeconds: nowSec,
        );

        expect(result.valid, isFalse, reason: 'Strong RSSI must never override cryptographic invalidity');
      });
    });

    // =========================================================================
    // SECTION 5: OFFLINE LOCAL VERIFICATION & LEDGER (Tests 26-30)
    // =========================================================================
    group('Offline Verification and Queueing (Airplane Mode)', () {
      test('26. complete verification works without network', () async {
        final nowSec = DateTime.now().toUtc().millisecondsSinceEpoch ~/ 1000;
        final nonce = PassportAttendanceModel.generateSecureSessionNonce();

        // 100% offline teacher service instance (no network / HTTP client initialized)
        final offlineTeacherService = PassportTeacherAttendanceService(
          cryptoService: teacherCrypto,
          trustBundleService: teacherTrustBundleService,
        );
        final beacon = PassportTeacherBeaconModel(
          protocolVersion: 1,
          sessionId: 'session-cs301-01',
          teacherId: teacherId,
          teacherKeyId: teacherKeyId,
          sessionNonce: nonce,
          issuedAt: nowSec,
          expiresAt: nowSec + 300,
        );
        offlineTeacherService.setActiveBeacon(beacon);

        final resp = PassportAttendanceResponseModel(
          version: 1,
          sessionId: 'session-cs301-01',
          studentId: studentId,
          deviceKeyId: studentKeyId,
          challengeNonce: nonce,
          issuedAt: nowSec,
          expiresAt: nowSec + 15,
          biometricGate: true,
          responseNonce: PassportAttendanceModel.generateSecureSessionNonce(),
        );

        final signedResp = await resp.sign(studentCrypto);

        final result = await offlineTeacherService.verifyAttendanceResponse(
          signedResp,
          rssiSamples: [-65, -64, -66],
          currentTimestampSeconds: nowSec,
        );

        expect(result.valid, isTrue);
        expect(result.proximityTier, equals(PassportProximityTier.near));
      });

      test('27. cached trust bundle used', () async {
        final cached = await teacherTrustBundleService.getLocalBundle();
        expect(cached, isNotNull);
        expect(cached!.institution.keyId, equals('inst-root-key'));
        expect(cached.identities.any((k) => k.keyId == studentKeyId), isTrue);
      });

      test('28. expired trust bundle rejected', () async {
        final nowSec = DateTime.now().toUtc().millisecondsSinceEpoch ~/ 1000;
        final nonce = PassportAttendanceModel.generateSecureSessionNonce();

        final expiredPayload = Map<String, dynamic>.from(trustBundle.rawPayload);
        expiredPayload['expiresAt'] = nowSec - 100; // Bundle expired 100s ago

        final canonicalJson = canonicalizeJson(expiredPayload);
        final sig = await ed25519.sign(utf8.encode(canonicalJson), keyPair: institutionKeyPair);
        final expiredBundle = PassportTrustBundle.fromJson({
          'payload': expiredPayload,
          'signature': base64Encode(sig.bytes),
        });

        await teacherStorage.write(
          PassportTrustBundleService.trustBundleStorageKey,
          jsonEncode(expiredBundle.toJson()),
        );

        final freshTrust = PassportTrustBundleService(
          storage: teacherStorage,
          cryptoService: teacherCrypto,
        );

        final teacherService = PassportTeacherAttendanceService(
          cryptoService: teacherCrypto,
          trustBundleService: freshTrust,
        );
        final beacon = PassportTeacherBeaconModel(
          protocolVersion: 1,
          sessionId: 'session-cs301-01',
          teacherId: teacherId,
          teacherKeyId: teacherKeyId,
          sessionNonce: nonce,
          issuedAt: nowSec,
          expiresAt: nowSec + 300,
        );
        teacherService.setActiveBeacon(beacon);

        final resp = PassportAttendanceResponseModel(
          version: 1,
          sessionId: 'session-cs301-01',
          studentId: studentId,
          deviceKeyId: studentKeyId,
          challengeNonce: nonce,
          issuedAt: nowSec,
          expiresAt: nowSec + 15,
          biometricGate: true,
          responseNonce: PassportAttendanceModel.generateSecureSessionNonce(),
        );
        final signedResp = await resp.sign(studentCrypto);

        final result = await teacherService.verifyAttendanceResponse(
          signedResp,
          currentTimestampSeconds: nowSec,
        );

        expect(result.valid, isFalse);
      });

      test('29. revoked cached key rejected in trust bundle', () async {
        final nowSec = DateTime.now().toUtc().millisecondsSinceEpoch ~/ 1000;
        final nonce = PassportAttendanceModel.generateSecureSessionNonce();

        final revokedPayload = Map<String, dynamic>.from(trustBundle.rawPayload);
        revokedPayload['revokedKeyIds'] = [studentKeyId];

        final canonicalJson = canonicalizeJson(revokedPayload);
        final sig = await ed25519.sign(utf8.encode(canonicalJson), keyPair: institutionKeyPair);
        final revokedBundle = PassportTrustBundle.fromJson({
          'payload': revokedPayload,
          'signature': base64Encode(sig.bytes),
        });

        await teacherStorage.write(
          PassportTrustBundleService.trustBundleStorageKey,
          jsonEncode(revokedBundle.toJson()),
        );

        final freshTrust = PassportTrustBundleService(
          storage: teacherStorage,
          cryptoService: teacherCrypto,
        );

        final teacherService = PassportTeacherAttendanceService(
          cryptoService: teacherCrypto,
          trustBundleService: freshTrust,
        );
        final beacon = PassportTeacherBeaconModel(
          protocolVersion: 1,
          sessionId: 'session-cs301-01',
          teacherId: teacherId,
          teacherKeyId: teacherKeyId,
          sessionNonce: nonce,
          issuedAt: nowSec,
          expiresAt: nowSec + 300,
        );
        teacherService.setActiveBeacon(beacon);

        final resp = PassportAttendanceResponseModel(
          version: 1,
          sessionId: 'session-cs301-01',
          studentId: studentId,
          deviceKeyId: studentKeyId,
          challengeNonce: nonce,
          issuedAt: nowSec,
          expiresAt: nowSec + 15,
          biometricGate: true,
          responseNonce: PassportAttendanceModel.generateSecureSessionNonce(),
        );
        final signedResp = await resp.sign(studentCrypto);

        final result = await teacherService.verifyAttendanceResponse(
          signedResp,
          currentTimestampSeconds: nowSec,
        );

        expect(result.valid, isFalse);
      });

      test('30. offline attendance queued', () async {
        final ledger = PassportAttendanceLedgerService();
        await ledger.clearQueue();

        const record = PassportOfflineAttendanceRecord(
          sessionId: 'session-cs301-01',
          studentId: studentId,
          deviceKeyId: studentKeyId,
          responseNonce: 'nonce-offline-01',
          verificationResult: 'VERIFIED_PRESENT',
          timestamp: 1000,
          verificationMode: 'BLE_BATCH',
          proximityTier: 'NEAR',
          idempotencyKey: 'att_session-cs301-01_${studentKeyId}_nonce-offline-01',
        );

        await ledger.enqueueOfflineRecord(record);
        final queue = await ledger.getQueuedRecords();

        expect(queue.length, equals(1));
        expect(queue.first['idempotencyKey'], equals(record.idempotencyKey));
      });
    });

    // =========================================================================
    // SECTION 6: SYNC & IDEMPOTENCY (Tests 31-33)
    // =========================================================================
    group('Sync and Idempotency', () {
      test('31. queued attendance syncs', () async {
        final ledger = PassportAttendanceLedgerService();
        await ledger.clearQueue();

        const record = PassportOfflineAttendanceRecord(
          sessionId: 'session-cs301-01',
          studentId: studentId,
          deviceKeyId: studentKeyId,
          responseNonce: 'nonce-offline-02',
          verificationResult: 'VERIFIED_PRESENT',
          timestamp: 1000,
          verificationMode: 'BLE_BATCH',
          proximityTier: 'NEAR',
          idempotencyKey: 'att_session-cs301-01_${studentKeyId}_nonce-offline-02',
        );

        await ledger.enqueueOfflineRecord(record);

        final mockApi = MockAttendanceService();
        final syncResult = await ledger.syncQueue(null, mockApi);

        expect(syncResult, isNotNull);
        expect(mockApi.syncedBatches.length, equals(1));
        expect(mockApi.syncedBatches.first['idempotencyKey'], equals(record.idempotencyKey));

        final remainingQueue = await ledger.getQueuedRecords();
        expect(remainingQueue.isEmpty, isTrue);
      });

      test('32. duplicate sync is idempotent', () async {
        final ledger = PassportAttendanceLedgerService();
        await ledger.clearQueue();

        const record = PassportOfflineAttendanceRecord(
          sessionId: 'session-cs301-01',
          studentId: studentId,
          deviceKeyId: studentKeyId,
          responseNonce: 'nonce-offline-03',
          verificationResult: 'VERIFIED_PRESENT',
          timestamp: 1000,
          verificationMode: 'BLE_BATCH',
          proximityTier: 'NEAR',
          idempotencyKey: 'att_session-cs301-01_${studentKeyId}_nonce-offline-03',
        );

        await ledger.enqueueOfflineRecord(record);

        // Attempting to enqueue same record a second time
        final enqueuedSecond = await ledger.enqueueOfflineRecord(record);
        expect(enqueuedSecond, isFalse, reason: 'Duplicate idempotency key must not be re-queued');
      });

      test('33. same response cannot create duplicate attendance in teacher service', () async {
        final nowSec = DateTime.now().toUtc().millisecondsSinceEpoch ~/ 1000;
        final nonce = PassportAttendanceModel.generateSecureSessionNonce();

        final teacherService = PassportTeacherAttendanceService(
          cryptoService: teacherCrypto,
          trustBundleService: teacherTrustBundleService,
        );
        final beacon = PassportTeacherBeaconModel(
          protocolVersion: 1,
          sessionId: 'session-cs301-01',
          teacherId: teacherId,
          teacherKeyId: teacherKeyId,
          sessionNonce: nonce,
          issuedAt: nowSec,
          expiresAt: nowSec + 300,
        );
        teacherService.setActiveBeacon(beacon);

        final resp = PassportAttendanceResponseModel(
          version: 1,
          sessionId: 'session-cs301-01',
          studentId: studentId,
          deviceKeyId: studentKeyId,
          challengeNonce: nonce,
          issuedAt: nowSec,
          expiresAt: nowSec + 15,
          biometricGate: true,
          responseNonce: 'fixed_response_nonce_42',
        );

        final signedResp = await resp.sign(studentCrypto);

        // First presentation
        final result1 = await teacherService.verifyAttendanceResponse(
          signedResp,
          rssiSamples: [-65, -64, -66],
          currentTimestampSeconds: nowSec,
        );
        expect(result1.valid, isTrue);

        // Replay of same presentation
        final result2 = await teacherService.verifyAttendanceResponse(
          signedResp,
          rssiSamples: [-65, -64, -66],
          currentTimestampSeconds: nowSec,
        );
        expect(result2.valid, isFalse);
        expect(result2.reason, contains('replayed'));
      });
    });

    // =========================================================================
    // SECTION 7: QR FALLBACK (Tests 34-40)
    // =========================================================================
    group('QR Exception Recovery Path', () {
      test('34. teacher session QR generated', () async {
        final nowSec = DateTime.now().toUtc().millisecondsSinceEpoch ~/ 1000;
        final teacherService = PassportTeacherAttendanceService(
          cryptoService: teacherCrypto,
          trustBundleService: teacherTrustBundleService,
        );
        final beacon = PassportTeacherBeaconModel(
          protocolVersion: 1,
          sessionId: 'session-cs301-01',
          teacherId: teacherId,
          teacherKeyId: teacherKeyId,
          sessionNonce: 'nonce_test_qr',
          issuedAt: nowSec,
          expiresAt: nowSec + 300,
        );
        teacherService.setActiveBeacon(beacon);

        final qrPayload = await teacherService.generateSessionQrPayload();
        expect(qrPayload, isNotEmpty);

        final parsed = PassportTeacherBeaconModel.fromQrString(qrPayload);
        expect(parsed.sessionId, equals('session-cs301-01'));
        expect(parsed.teacherId, equals(teacherId));
        expect(parsed.sessionNonce, equals('nonce_test_qr'));
      });

      test('35. student scans session QR', () async {
        final nowSec = DateTime.now().toUtc().millisecondsSinceEpoch ~/ 1000;
        final teacherService = PassportTeacherAttendanceService(
          cryptoService: teacherCrypto,
          trustBundleService: teacherTrustBundleService,
        );
        final beacon = PassportTeacherBeaconModel(
          protocolVersion: 1,
          sessionId: 'session-cs301-01',
          teacherId: teacherId,
          teacherKeyId: teacherKeyId,
          sessionNonce: 'nonce_test_qr',
          issuedAt: nowSec,
          expiresAt: nowSec + 300,
        );
        final sig = await teacherCrypto.signPresentation(beacon.toCanonicalJson());
        final signedBeacon = beacon.withSignature(sig);
        teacherService.setActiveBeacon(signedBeacon);

        final qrPayload = await teacherService.generateSessionQrPayload();
        final studentService = PassportStudentAttendanceService(
          cryptoService: studentCrypto,
          trustBundleService: studentTrustBundleService,
          biometricService: FakePassportBiometricProvider(willSucceed: true),
        );

        final resp = await studentService.processQrFallback(
          teacherQrPayload: qrPayload,
          currentUser: studentUser,
          currentTimestampSeconds: nowSec,
        );

        expect(resp, isNotNull);
        expect(resp!.sessionId, equals('session-cs301-01'));
      });

      test('36. biometric required during QR fallback', () async {
        final nowSec = DateTime.now().toUtc().millisecondsSinceEpoch ~/ 1000;
        final teacherService = PassportTeacherAttendanceService(
          cryptoService: teacherCrypto,
          trustBundleService: teacherTrustBundleService,
        );
        final beacon = PassportTeacherBeaconModel(
          protocolVersion: 1,
          sessionId: 'session-cs301-01',
          teacherId: teacherId,
          teacherKeyId: teacherKeyId,
          sessionNonce: 'nonce_test_qr',
          issuedAt: nowSec,
          expiresAt: nowSec + 300,
        );
        final sig = await teacherCrypto.signPresentation(beacon.toCanonicalJson());
        teacherService.setActiveBeacon(beacon.withSignature(sig));

        final qrPayload = await teacherService.generateSessionQrPayload();

        final failingBio = FakePassportBiometricProvider(
          willSucceed: false,
          failureStatus: BiometricAuthStatus.ownerMismatch,
        );

        final studentService = PassportStudentAttendanceService(
          cryptoService: studentCrypto,
          trustBundleService: studentTrustBundleService,
          biometricService: failingBio,
        );

        final resp = await studentService.processQrFallback(
          teacherQrPayload: qrPayload,
          currentUser: studentUser,
          currentTimestampSeconds: nowSec,
        );

        expect(resp, isNull, reason: 'QR fallback must NOT bypass biometric gate');
      });

      test('37. same session nonce signed in QR fallback', () async {
        final nowSec = DateTime.now().toUtc().millisecondsSinceEpoch ~/ 1000;
        final teacherService = PassportTeacherAttendanceService(
          cryptoService: teacherCrypto,
          trustBundleService: teacherTrustBundleService,
        );
        final beacon = PassportTeacherBeaconModel(
          protocolVersion: 1,
          sessionId: 'session-cs301-01',
          teacherId: teacherId,
          teacherKeyId: teacherKeyId,
          sessionNonce: 'nonce_qr_nonce_test',
          issuedAt: nowSec,
          expiresAt: nowSec + 300,
        );
        final sig = await teacherCrypto.signPresentation(beacon.toCanonicalJson());
        teacherService.setActiveBeacon(beacon.withSignature(sig));

        final qrPayload = await teacherService.generateSessionQrPayload();

        final studentService = PassportStudentAttendanceService(
          cryptoService: studentCrypto,
          trustBundleService: studentTrustBundleService,
          biometricService: FakePassportBiometricProvider(willSucceed: true),
        );

        final resp = await studentService.processQrFallback(
          teacherQrPayload: qrPayload,
          currentUser: studentUser,
          currentTimestampSeconds: nowSec,
        );

        expect(resp!.challengeNonce, equals('nonce_qr_nonce_test'));
      });

      test('38. valid fallback response accepted by teacher', () async {
        final nowSec = DateTime.now().toUtc().millisecondsSinceEpoch ~/ 1000;
        final teacherService = PassportTeacherAttendanceService(
          cryptoService: teacherCrypto,
          trustBundleService: teacherTrustBundleService,
        );
        final beacon = PassportTeacherBeaconModel(
          protocolVersion: 1,
          sessionId: 'session-cs301-01',
          teacherId: teacherId,
          teacherKeyId: teacherKeyId,
          sessionNonce: 'nonce_qr_valid',
          issuedAt: nowSec,
          expiresAt: nowSec + 300,
        );
        final sig = await teacherCrypto.signPresentation(beacon.toCanonicalJson());
        teacherService.setActiveBeacon(beacon.withSignature(sig));

        final qrPayload = await teacherService.generateSessionQrPayload();

        final studentService = PassportStudentAttendanceService(
          cryptoService: studentCrypto,
          trustBundleService: studentTrustBundleService,
          biometricService: FakePassportBiometricProvider(willSucceed: true),
        );

        final resp = await studentService.processQrFallback(
          teacherQrPayload: qrPayload,
          currentUser: studentUser,
          currentTimestampSeconds: nowSec,
        );

        final verifyResult = await teacherService.verifyQrResponse(resp!.toQrString());
        expect(verifyResult.valid, isTrue);
        expect(verifyResult.studentName, equals('Alice Kumar'));
        expect(verifyResult.verificationMode, equals('QR_FALLBACK'));
      });

      test('39. wrong-session QR rejected', () async {
        final nowSec = DateTime.now().toUtc().millisecondsSinceEpoch ~/ 1000;
        // Teacher A in session A
        final teacherServiceA = PassportTeacherAttendanceService(
          cryptoService: teacherCrypto,
          trustBundleService: teacherTrustBundleService,
        );
        final beaconA = PassportTeacherBeaconModel(
          protocolVersion: 1,
          sessionId: 'session-CS101-Math',
          teacherId: teacherId,
          teacherKeyId: teacherKeyId,
          sessionNonce: 'nonce_a',
          issuedAt: nowSec,
          expiresAt: nowSec + 300,
        );
        final sigA = await teacherCrypto.signPresentation(beaconA.toCanonicalJson());
        teacherServiceA.setActiveBeacon(beaconA.withSignature(sigA));
        final qrPayloadA = await teacherServiceA.generateSessionQrPayload();

        // Student scans Session A QR
        final studentService = PassportStudentAttendanceService(
          cryptoService: studentCrypto,
          trustBundleService: studentTrustBundleService,
          biometricService: FakePassportBiometricProvider(willSucceed: true),
        );
        final respA = await studentService.processQrFallback(
          teacherQrPayload: qrPayloadA,
          currentUser: studentUser,
          currentTimestampSeconds: nowSec,
        );

        // Teacher B in Session B scans student's response QR
        final teacherServiceB = PassportTeacherAttendanceService(
          cryptoService: teacherCrypto,
          trustBundleService: teacherTrustBundleService,
        );
        final beaconB = PassportTeacherBeaconModel(
          protocolVersion: 1,
          sessionId: 'session-CS301-Physics',
          teacherId: teacherId,
          teacherKeyId: teacherKeyId,
          sessionNonce: 'nonce_b',
          issuedAt: nowSec,
          expiresAt: nowSec + 300,
        );
        teacherServiceB.setActiveBeacon(beaconB);

        final verifyResult = await teacherServiceB.verifyQrResponse(respA!.toQrString());
        expect(verifyResult.valid, isFalse);
        expect(verifyResult.reason, contains('Session ID mismatch'));
      });

      test('40. fallback does not bypass device binding', () async {
        final nowSec = DateTime.now().toUtc().millisecondsSinceEpoch ~/ 1000;
        final teacherService = PassportTeacherAttendanceService(
          cryptoService: teacherCrypto,
          trustBundleService: teacherTrustBundleService,
        );
        final beacon = PassportTeacherBeaconModel(
          protocolVersion: 1,
          sessionId: 'session-cs301-01',
          teacherId: teacherId,
          teacherKeyId: teacherKeyId,
          sessionNonce: 'nonce_fallback_bind',
          issuedAt: nowSec,
          expiresAt: nowSec + 300,
        );
        teacherService.setActiveBeacon(beacon);

        // Attacker creates a response QR claiming Alice's studentId but with attacker key
        final attackerStorage = FakePassportKeyStorage();
        final aPriv = await attackerKeyPair.extractPrivateKeyBytes();
        await attackerStorage.write(
          PassportCryptoService.privateKeyStorageKey,
          base64Encode(aPriv),
        );
        await attackerStorage.write(
          PassportCryptoService.publicKeyStorageKey,
          attackerPubB64,
        );
        await attackerStorage.write('passport_device_key_id', studentKeyId);

        final attackerCrypto = PassportCryptoService(storage: attackerStorage);
        await attackerCrypto.initialize();

        final fakeResp = PassportAttendanceResponseModel(
          version: 1,
          sessionId: beacon.sessionId,
          studentId: studentId,
          deviceKeyId: studentKeyId,
          challengeNonce: beacon.sessionNonce,
          issuedAt: nowSec,
          expiresAt: nowSec + 300,
          biometricGate: true,
          responseNonce: 'nonce_attack_qr',
        );

        final signedByAttacker = await fakeResp.sign(attackerCrypto);

        final verifyResult = await teacherService.verifyQrResponse(signedByAttacker.toQrString());
        expect(verifyResult.valid, isFalse, reason: 'Device binding must not be bypassed in QR fallback');
      });
    });

    // =========================================================================
    // SECTION 8: ATTACK MITIGATIONS & ADVERSARIAL CASES (Tests 41-47)
    // =========================================================================
    group('Adversarial Scenarios and Attack Mitigations', () {
      test('41. fake beacon attack rejected by student device', () async {
        final nowSec = DateTime.now().toUtc().millisecondsSinceEpoch ~/ 1000;

        // Rogue beacon broadcast by laptop
        final rogueBeacon = PassportTeacherBeaconModel(
          protocolVersion: 1,
          sessionId: 'rogue-session-007',
          teacherId: 'rogue-actor',
          teacherKeyId: 'untrusted-laptop-key',
          sessionNonce: 'nonce_fake_000',
          issuedAt: nowSec,
          expiresAt: nowSec + 300,
          signature: 'fake_signature',
        );

        final studentService = PassportStudentAttendanceService(
          cryptoService: studentCrypto,
          trustBundleService: studentTrustBundleService,
        );

        final isValid = await studentService.verifyTeacherBeacon(
          rogueBeacon,
          currentTimestampSeconds: nowSec,
        );

        expect(isValid, isFalse, reason: 'Student device must reject fake laptop beacon');
      });

      test('42. friend carrying phone attack blocked by biometric failure', () async {
        // Student B has Student A's phone, but fails biometric liveness
        final friendBio = FakePassportBiometricProvider(
          willSucceed: false,
          failureStatus: BiometricAuthStatus.ownerMismatch,
          customMessage: 'Fingerprint did not match registered device biometric template',
        );

        final bioResult = await friendBio.authenticateBiometricOnly(
          reason: 'Biometric liveness gate',
        );

        expect(bioResult.isSuccess, isFalse);
        expect(bioResult.status, equals(BiometricAuthStatus.ownerMismatch));
      });

      test('43. replayed response rejected by verifier ledger', () async {
        final nowSec = DateTime.now().toUtc().millisecondsSinceEpoch ~/ 1000;
        final nonce = PassportAttendanceModel.generateSecureSessionNonce();

        final teacherService = PassportTeacherAttendanceService(
          cryptoService: teacherCrypto,
          trustBundleService: teacherTrustBundleService,
        );
        final beacon = PassportTeacherBeaconModel(
          protocolVersion: 1,
          sessionId: 'session-cs301-01',
          teacherId: teacherId,
          teacherKeyId: teacherKeyId,
          sessionNonce: nonce,
          issuedAt: nowSec,
          expiresAt: nowSec + 300,
        );
        teacherService.setActiveBeacon(beacon);

        final resp = PassportAttendanceResponseModel(
          version: 1,
          sessionId: 'session-cs301-01',
          studentId: studentId,
          deviceKeyId: studentKeyId,
          challengeNonce: nonce,
          issuedAt: nowSec,
          expiresAt: nowSec + 15,
          biometricGate: true,
          responseNonce: 'nonce_replay_test',
        );

        final signedResp = await resp.sign(studentCrypto);

        final res1 = await teacherService.verifyAttendanceResponse(
          signedResp,
          rssiSamples: [-65, -64, -66],
          currentTimestampSeconds: nowSec,
        );
        expect(res1.valid, isTrue);

        // Attacker replays intercepted packet
        final res2 = await teacherService.verifyAttendanceResponse(
          signedResp,
          rssiSamples: [-65, -64, -66],
          currentTimestampSeconds: nowSec,
        );
        expect(res2.valid, isFalse);
        expect(res2.reason, contains('replayed'));
      });

      test('44. expired response rejected', () async {
        final nowSec = DateTime.now().toUtc().millisecondsSinceEpoch ~/ 1000;
        final nonce = PassportAttendanceModel.generateSecureSessionNonce();

        final teacherService = PassportTeacherAttendanceService(
          cryptoService: teacherCrypto,
          trustBundleService: teacherTrustBundleService,
        );
        final beacon = PassportTeacherBeaconModel(
          protocolVersion: 1,
          sessionId: 'session-cs301-01',
          teacherId: teacherId,
          teacherKeyId: teacherKeyId,
          sessionNonce: nonce,
          issuedAt: nowSec,
          expiresAt: nowSec + 300,
        );
        teacherService.setActiveBeacon(beacon);

        final resp = PassportAttendanceResponseModel(
          version: 1,
          sessionId: 'session-cs301-01',
          studentId: studentId,
          deviceKeyId: studentKeyId,
          challengeNonce: nonce,
          issuedAt: nowSec - 30,
          expiresAt: nowSec - 15, // Expired 15s ago
          biometricGate: true,
          responseNonce: 'nonce_expired_test',
        );

        final signedResp = await resp.sign(studentCrypto);

        final result = await teacherService.verifyAttendanceResponse(
          signedResp,
          rssiSamples: [-65, -64],
          currentTimestampSeconds: nowSec,
        );

        expect(result.valid, isFalse);
        expect(result.reason, contains('expired'));
      });

      test('45. response from different session rejected', () async {
        final nowSec = DateTime.now().toUtc().millisecondsSinceEpoch ~/ 1000;
        final nonceA = PassportAttendanceModel.generateSecureSessionNonce();
        final nonceB = PassportAttendanceModel.generateSecureSessionNonce();

        final teacherService = PassportTeacherAttendanceService(
          cryptoService: teacherCrypto,
          trustBundleService: teacherTrustBundleService,
        );
        final beaconA = PassportTeacherBeaconModel(
          protocolVersion: 1,
          sessionId: 'session-cs301-ACTIVE',
          teacherId: teacherId,
          teacherKeyId: teacherKeyId,
          sessionNonce: nonceA,
          issuedAt: nowSec,
          expiresAt: nowSec + 300,
        );
        teacherService.setActiveBeacon(beaconA);

        final resp = PassportAttendanceResponseModel(
          version: 1,
          sessionId: 'session-cs301-OLD',
          studentId: studentId,
          deviceKeyId: studentKeyId,
          challengeNonce: nonceB,
          issuedAt: nowSec,
          expiresAt: nowSec + 15,
          biometricGate: true,
          responseNonce: 'nonce_session_mismatch',
        );

        final signedResp = await resp.sign(studentCrypto);

        final result = await teacherService.verifyAttendanceResponse(
          signedResp,
          currentTimestampSeconds: nowSec,
        );

        expect(result.valid, isFalse);
        expect(result.reason, contains('Session ID mismatch'));
      });

      test('46. response from different device rejected (impersonation)', () async {
        final nowSec = DateTime.now().toUtc().millisecondsSinceEpoch ~/ 1000;
        final nonce = PassportAttendanceModel.generateSecureSessionNonce();

        final teacherService = PassportTeacherAttendanceService(
          cryptoService: teacherCrypto,
          trustBundleService: teacherTrustBundleService,
        );
        final beacon = PassportTeacherBeaconModel(
          protocolVersion: 1,
          sessionId: 'session-cs301-01',
          teacherId: teacherId,
          teacherKeyId: teacherKeyId,
          sessionNonce: nonce,
          issuedAt: nowSec,
          expiresAt: nowSec + 300,
        );
        teacherService.setActiveBeacon(beacon);

        // Device key does not match student ID registered in trust bundle
        final resp = PassportAttendanceResponseModel(
          version: 1,
          sessionId: 'session-cs301-01',
          studentId: 'someone-else-id',
          deviceKeyId: studentKeyId, // Alice's key but claiming someone else's ID
          challengeNonce: nonce,
          issuedAt: nowSec,
          expiresAt: nowSec + 15,
          biometricGate: true,
          responseNonce: 'nonce_device_mismatch',
        );

        final signedResp = await resp.sign(studentCrypto);

        final result = await teacherService.verifyAttendanceResponse(
          signedResp,
          currentTimestampSeconds: nowSec,
        );

        expect(result.valid, isFalse);
        expect(result.reason, contains('not found'));
      });

      test('47. relay limitation documented honestly', () {
        // Verify that the security model explicitly acknowledges physical wormhole relay limitations
        // without falsely claiming 100% mathematical impossibility of proxy.
        const relayDocumentation = '''
        CampusOS Passport 1I Security Boundary Notice:
        - Anti-Proxy is enforced via device-bound Ed25519 private keys, session-bound ephemeral nonces,
          and a hardware-backed biometric-only liveness gate (biometricOnly=true).
        - Proximity is monitored via RSSI variance, sample thresholds, and median dBm values.
        - Physical-layer limitation: A multi-radio physical relay attack (e.g., directional RF relay or tunnel)
          cannot be mathematically prevented by BLE signal analysis alone without specialized time-of-flight hardware.
        - Therefore, CampusOS Passport makes honest security claims: hardware-free defense-in-depth,
          not "100% proxy-proof".
        ''';

        expect(relayDocumentation, contains('cannot be mathematically prevented'));
        expect(relayDocumentation, contains('defense-in-depth'));
        expect(relayDocumentation, contains('not "100% proxy-proof"'));
      });
    });

    // =========================================================================
    // SECTION 9: BLE SEQUENCED FRAMING (Serialization & Assembly)
    // =========================================================================
    group('BLE Sequenced Packet Fragmentation & Assembly', () {
      test('48. frames properly fragment, sequence, and reassemble payload', () {
        final payload = Uint8List.fromList(utf8.encode('Hello CampusOS Batch Attendance BLE Protocol Test Payload 1234567890'));
        const streamId = 42;

        final frames = PassportBleFrame.fragment(
          data: payload,
          frameType: 0x01,
          streamId: streamId,
        );

        expect(frames.isNotEmpty, isTrue);
        for (final frame in frames) {
          expect(frame[0], equals(PassportAttendanceModel.bleFrameMagic));
          expect(PassportBleFrame.isPassportFrame(frame), isTrue);
        }

        final reassembled = PassportBleFrame.reassemble(frames);

        expect(reassembled, isNotNull);
        expect(utf8.decode(reassembled!), equals('Hello CampusOS Batch Attendance BLE Protocol Test Payload 1234567890'));
      });

      test('49. BLE packet size constraint validation: <= 24 bytes per frame', () {
        final payload = Uint8List.fromList(List.generate(200, (i) => (i * 7) % 256));
        final frames = PassportBleFrame.fragment(
          frameType: PassportAttendanceModel.frameTypeResponse,
          streamId: 0x12345678,
          data: payload,
        );

        expect(frames.isNotEmpty, isTrue);
        for (final frame in frames) {
          expect(frame.length, lessThanOrEqualTo(24),
              reason: 'Frame must not exceed 24 bytes to fit in legacy BLE advertising');
          expect(frame[0], equals(PassportAttendanceModel.bleFrameMagic));
          expect(frame[1], equals(PassportAttendanceModel.frameTypeResponse));
          expect(PassportBleFrame.extractStreamId(frame), equals(0x12345678));
        }
      });

      test('50. deterministic 32-bit streamId per-response binding', () {
        const sessionId = 'session-cs301-01';
        const studentId = 'student-uuid-42';
        const responseNonce = 'a1b2c3d4e5f67890';

        final streamId1 = PassportBleFrame.computeStreamId('$sessionId:$studentId:$responseNonce');
        final streamId2 = PassportBleFrame.computeStreamId('$sessionId:$studentId:$responseNonce');
        expect(streamId1, equals(streamId2));
        expect(streamId1, isNonNegative);
        expect(streamId1, lessThanOrEqualTo(0xFFFFFFFF));

        // Different nonce produces completely different streamId
        final streamIdOtherNonce = PassportBleFrame.computeStreamId('$sessionId:$studentId:different_nonce');
        expect(streamIdOtherNonce, isNot(equals(streamId1)));

        // Different student produces completely different streamId
        final streamIdOtherStudent = PassportBleFrame.computeStreamId('$sessionId:student-99:$responseNonce');
        expect(streamIdOtherStudent, isNot(equals(streamId1)));
      });

      test('51. collision test: 10 simultaneous students with randomized nonces', () async {
        final nowSec = DateTime.now().toUtc().millisecondsSinceEpoch ~/ 1000;
        const sessionId = 'session-cs301-01';
        const nonce = 'session_nonce_10_students';

        final studentDefs = <Map<String, String>>[];
        final studentCryptoList = <PassportCryptoService>[];

        for (int i = 0; i < 10; i++) {
          final kp = await ed25519.newKeyPair();
          final pub = await kp.extractPublicKey();
          final pubB64 = base64Encode(pub.bytes);
          final sId = 'student-sim-10-$i';
          final kId = 'key-sim-10-$i';

          studentDefs.add({
            'userId': sId,
            'keyId': kId,
            'pubB64': pubB64,
            'name': 'Student $i',
          });

          final storage = FakePassportKeyStorage();
          final priv = await kp.extractPrivateKeyBytes();
          await storage.write(PassportCryptoService.privateKeyStorageKey, base64Encode(priv));
          await storage.write(PassportCryptoService.publicKeyStorageKey, pubB64);
          await storage.write('passport_device_key_id', kId);
          final crypto = PassportCryptoService(storage: storage);
          await crypto.initialize();
          studentCryptoList.add(crypto);
        }

        final multiTrustBundle = await createTrustBundleWithStudents(
          institutionKeyPair: institutionKeyPair,
          institutionPubB64: institutionPubB64,
          teacherId: teacherId,
          teacherKeyId: teacherKeyId,
          teacherPubB64: teacherPubB64,
          studentDefs: studentDefs,
        );

        final teacherStorageLocal = FakePassportKeyStorage();
        await teacherStorageLocal.write(
          PassportTrustBundleService.trustBundleStorageKey,
          jsonEncode(multiTrustBundle.toJson()),
        );
        final teacherLocalTrust = PassportTrustBundleService(
          storage: teacherStorageLocal,
          cryptoService: teacherCrypto,
        );

        final teacherService = PassportTeacherAttendanceService(
          cryptoService: teacherCrypto,
          trustBundleService: teacherLocalTrust,
        );
        final beacon = PassportTeacherBeaconModel(
          protocolVersion: 1,
          sessionId: sessionId,
          teacherId: teacherId,
          teacherKeyId: teacherKeyId,
          sessionNonce: nonce,
          issuedAt: nowSec,
          expiresAt: nowSec + 300,
        );
        teacherService.setActiveBeacon(beacon);

        // Generate 10 responses, check streamId entropy, fragment, interleave
        final streamIds = <int>{};
        final allFrames = <Uint8List>[];

        for (int i = 0; i < 10; i++) {
          final resp = PassportAttendanceResponseModel(
            version: 1,
            sessionId: sessionId,
            studentId: studentDefs[i]['userId']!,
            deviceKeyId: studentDefs[i]['keyId']!,
            challengeNonce: nonce,
            issuedAt: nowSec,
            expiresAt: nowSec + 30,
            biometricGate: true,
            responseNonce: PassportAttendanceModel.generateSecureSessionNonce(),
          );
          final signed = await resp.sign(studentCryptoList[i]);
          final frames = signed.toBleFrames();
          final streamId = PassportBleFrame.extractStreamId(frames.first);
          expect(streamIds.contains(streamId), isFalse, reason: 'Collision detected among 10 students!');
          streamIds.add(streamId);
          allFrames.addAll(frames);
        }

        // Shuffle all frames together to simulate concurrent BLE advertising
        allFrames.shuffle();

        for (final frame in allFrames) {
          await teacherService.handleIncomingBleFrame(frame, -60);
        }

        expect(teacherService.verifiedResults.length, equals(10),
            reason: 'All 10 students must be verified without frame mixing or collision');
      });

      test('52. collision test: 30 simultaneous students multiplexing & packet reassembly', () async {
        const sessionId = 'session-cs301-01';
        const nonce = 'session_nonce_30_students';
        final streamIds = <int>{};
        final Map<int, List<Uint8List>> expectedByStream = {};
        final allFrames = <Uint8List>[];

        for (int i = 0; i < 30; i++) {
          final resp = PassportAttendanceResponseModel(
            version: 1,
            sessionId: sessionId,
            studentId: 'student-30-$i',
            deviceKeyId: 'key-30-$i',
            challengeNonce: nonce,
            issuedAt: 1000,
            expiresAt: 1030,
            biometricGate: true,
            responseNonce: PassportAttendanceModel.generateSecureSessionNonce(),
            signature: 'mock_sig_$i',
          );

          final frames = resp.toBleFrames();
          final streamId = PassportBleFrame.extractStreamId(frames.first);
          expect(streamIds.contains(streamId), isFalse, reason: 'Collision among 30 students!');
          streamIds.add(streamId);
          expectedByStream[streamId] = frames;
          allFrames.addAll(frames);
        }

        expect(streamIds.length, equals(30));

        // Shuffle all frames (chaotic wireless interleaving)
        allFrames.shuffle();

        // Group into streams as the teacher scanner does
        final Map<int, List<Uint8List>> collected = {};
        for (final frame in allFrames) {
          final streamId = PassportBleFrame.extractStreamId(frame);
          collected.putIfAbsent(streamId, () => []).add(frame);
        }

        // Assert all 30 streams reassemble perfectly with 0 corruption
        for (final entry in collected.entries) {
          final reassembled = PassportAttendanceResponseModel.fromBleFrames(entry.value, entry.key);
          expect(reassembled, isNotNull);
          expect(reassembled!.sessionId, equals(sessionId));
        }
      });

      test('53. collision test: 60 simultaneous students in a lecture hall', () async {
        const sessionId = 'session-cs301-lecture';
        const nonce = 'session_nonce_60_students';
        final streamIds = <int>{};
        final allFrames = <Uint8List>[];
        final Map<int, String> expectedStudentByStream = {};

        for (int i = 0; i < 60; i++) {
          final sId = 'student-hall-$i';
          final resp = PassportAttendanceResponseModel(
            version: 1,
            sessionId: sessionId,
            studentId: sId,
            deviceKeyId: 'key-hall-$i',
            challengeNonce: nonce,
            issuedAt: 1000,
            expiresAt: 1030,
            biometricGate: true,
            responseNonce: PassportAttendanceModel.generateSecureSessionNonce(),
            signature: 'sig_lecture_$i',
          );

          final frames = resp.toBleFrames();
          final streamId = PassportBleFrame.extractStreamId(frames.first);
          expect(streamIds.contains(streamId), isFalse, reason: 'Collision among 60 students!');
          streamIds.add(streamId);
          expectedStudentByStream[streamId] = sId;
          allFrames.addAll(frames);
        }

        expect(streamIds.length, equals(60));

        // Interleave and randomize
        allFrames.shuffle();

        final Map<int, List<Uint8List>> grouped = {};
        for (final f in allFrames) {
          final sId = PassportBleFrame.extractStreamId(f);
          grouped.putIfAbsent(sId, () => []).add(f);
        }

        expect(grouped.length, equals(60));

        for (final entry in grouped.entries) {
          final reassembled = PassportAttendanceResponseModel.fromBleFrames(entry.value, entry.key);
          expect(reassembled, isNotNull);
          expect(reassembled!.studentId, equals(expectedStudentByStream[entry.key]));
        }
      });

      test('54. repeated randomized response nonces yield zero collisions across 1,000 runs', () {
        const sessionId = 'session-stat-test';
        final streamIds = <int>{};

        for (int i = 0; i < 1000; i++) {
          final nonce = PassportAttendanceModel.generateSecureSessionNonce();
          final sId = 'student-${i % 100}';
          final streamId = PassportBleFrame.computeStreamId('$sessionId:$sId:$nonce');
          expect(streamIds.contains(streamId), isFalse,
              reason: 'Collision detected on iteration $i (streamId: $streamId)');
          streamIds.add(streamId);
        }

        expect(streamIds.length, equals(1000));
      });

      test('55. interleaved fragments from multiple students reassemble without crosstalk', () {
        const respA = PassportAttendanceResponseModel(
          version: 1,
          sessionId: 'session-cs301-01',
          studentId: 'student-alice',
          deviceKeyId: 'key-alice',
          challengeNonce: 'nonce_alice_bob',
          issuedAt: 1000,
          expiresAt: 1030,
          biometricGate: true,
          responseNonce: 'nonce_alice_001',
          signature: 'sig_alice',
        );

        const respB = PassportAttendanceResponseModel(
          version: 1,
          sessionId: 'session-cs301-01',
          studentId: 'student-bob',
          deviceKeyId: 'key-bob',
          challengeNonce: 'nonce_alice_bob',
          issuedAt: 1000,
          expiresAt: 1030,
          biometricGate: true,
          responseNonce: 'nonce_bob_002',
          signature: 'sig_bob',
        );

        final framesA = respA.toBleFrames();
        final framesB = respB.toBleFrames();

        final streamIdA = PassportBleFrame.extractStreamId(framesA.first);
        final streamIdB = PassportBleFrame.extractStreamId(framesB.first);
        expect(streamIdA, isNot(equals(streamIdB)));

        // Deliberately interleave: A[0], B[0], A[1], B[1], etc.
        final interleaved = <Uint8List>[];
        final maxLen = max(framesA.length, framesB.length);
        for (int i = 0; i < maxLen; i++) {
          if (i < framesA.length) interleaved.add(framesA[i]);
          if (i < framesB.length) interleaved.add(framesB[i]);
        }

        // Filter for A
        final reassembledA = PassportAttendanceResponseModel.fromBleFrames(interleaved, streamIdA);
        expect(reassembledA, isNotNull);
        expect(reassembledA!.studentId, equals('student-alice'));

        // Filter for B
        final reassembledB = PassportAttendanceResponseModel.fromBleFrames(interleaved, streamIdB);
        expect(reassembledB, isNotNull);
        expect(reassembledB!.studentId, equals('student-bob'));
      });

      test('56. missing fragments return null and incomplete buffer is pruned safely', () {
        const resp = PassportAttendanceResponseModel(
          version: 1,
          sessionId: 'session-cs301-01',
          studentId: 'student-missing-frag',
          deviceKeyId: 'key-missing',
          challengeNonce: 'nonce_missing',
          issuedAt: 1000,
          expiresAt: 1030,
          biometricGate: true,
          responseNonce: 'nonce_miss_01',
          signature: 'sig_miss',
        );

        final frames = resp.toBleFrames();
        expect(frames.length, greaterThanOrEqualTo(3));

        // Drop middle frame (index 1)
        final incomplete = [frames[0], ...frames.sublist(2)];
        final result = PassportBleFrame.reassemble(incomplete);
        expect(result, isNull, reason: 'Incomplete frames must return null');

        // Verify pruning
        final teacherService = PassportTeacherAttendanceService(
          cryptoService: teacherCrypto,
          trustBundleService: teacherTrustBundleService,
        );
        // Feed only frame 0
        teacherService.handleIncomingBleFrame(frames[0], -65);
        // Prune with 0 timeout
        teacherService.pruneStaleStreams(timeout: Duration.zero);
        expect(teacherService.verifiedResults.isEmpty, isTrue);
      });

      test('57. duplicate fragments deduplicate cleanly and do not corrupt payload', () {
        const resp = PassportAttendanceResponseModel(
          version: 1,
          sessionId: 'session-cs301-01',
          studentId: 'student-duplicate-frag',
          deviceKeyId: 'key-dup',
          challengeNonce: 'nonce_dup',
          issuedAt: 1000,
          expiresAt: 1030,
          biometricGate: true,
          responseNonce: 'nonce_dup_01',
          signature: 'sig_dup',
        );

        final frames = resp.toBleFrames();
        // Duplicate every frame 3 times
        final duplicatedFrames = <Uint8List>[];
        for (final f in frames) {
          duplicatedFrames.add(f);
          duplicatedFrames.add(f);
          duplicatedFrames.add(f);
        }

        final reassembled = PassportAttendanceResponseModel.fromBleFrames(duplicatedFrames);
        expect(reassembled, isNotNull);
        expect(reassembled!.studentId, equals('student-duplicate-frag'));
        expect(reassembled.responseNonce, equals('nonce_dup_01'));
      });

      test('58. delayed fragments reassemble properly once all frames arrive', () {
        const resp = PassportAttendanceResponseModel(
          version: 1,
          sessionId: 'session-cs301-01',
          studentId: 'student-delayed',
          deviceKeyId: 'key-delayed',
          challengeNonce: 'nonce_delay',
          issuedAt: 1000,
          expiresAt: 1030,
          biometricGate: true,
          responseNonce: 'nonce_delayed_01',
          signature: 'sig_delayed',
        );

        final frames = resp.toBleFrames();
        final partial = frames.sublist(0, frames.length - 1);
        expect(PassportBleFrame.reassemble(partial), isNull);

        // Late arrival of last frame
        final complete = [...partial, frames.last];
        final reassembled = PassportAttendanceResponseModel.fromBleFrames(complete);
        expect(reassembled, isNotNull);
        expect(reassembled!.studentId, equals('student-delayed'));
      });

      test('59. wrong stream identifier frame injection rejected', () {
        const respA = PassportAttendanceResponseModel(
          version: 1,
          sessionId: 'session-cs301-01',
          studentId: 'student-victim',
          deviceKeyId: 'key-victim',
          challengeNonce: 'nonce_inject',
          issuedAt: 1000,
          expiresAt: 1030,
          biometricGate: true,
          responseNonce: 'nonce_victim_01',
          signature: 'sig_victim',
        );

        const respAttacker = PassportAttendanceResponseModel(
          version: 1,
          sessionId: 'session-cs301-01',
          studentId: 'student-attacker',
          deviceKeyId: 'key-attacker',
          challengeNonce: 'nonce_inject',
          issuedAt: 1000,
          expiresAt: 1030,
          biometricGate: true,
          responseNonce: 'nonce_attacker_01',
          signature: 'sig_attacker',
        );

        final framesVictim = respA.toBleFrames();
        final framesAttacker = respAttacker.toBleFrames();
        final victimStreamId = PassportBleFrame.extractStreamId(framesVictim.first);

        // Inject attacker frame 1 into victim frames
        final poisonedFrames = List<Uint8List>.from(framesVictim);
        poisonedFrames.insert(1, framesAttacker[0]);

        // Reassemble with expectedStreamId
        final result = PassportAttendanceResponseModel.fromBleFrames(poisonedFrames, victimStreamId);
        expect(result, isNotNull);
        expect(result!.studentId, equals('student-victim'), reason: 'Injected frame must be discarded');
      });

      test('60. response for wrong session rejected by teacher service', () async {
        final nowSec = DateTime.now().toUtc().millisecondsSinceEpoch ~/ 1000;
        final teacherService = PassportTeacherAttendanceService(
          cryptoService: teacherCrypto,
          trustBundleService: teacherTrustBundleService,
        );
        final beacon = PassportTeacherBeaconModel(
          protocolVersion: 1,
          sessionId: 'session-cs301-classA',
          teacherId: teacherId,
          teacherKeyId: teacherKeyId,
          sessionNonce: 'nonce_classA',
          issuedAt: nowSec,
          expiresAt: nowSec + 300,
        );
        teacherService.setActiveBeacon(beacon);

        // Student from Class B
        final respClassB = PassportAttendanceResponseModel(
          version: 1,
          sessionId: 'session-cs301-classB', // WRONG SESSION
          studentId: studentId,
          deviceKeyId: studentKeyId,
          challengeNonce: 'nonce_classA',
          issuedAt: nowSec,
          expiresAt: nowSec + 30,
          biometricGate: true,
          responseNonce: 'nonce_resp_b',
        );
        final signedClassB = await respClassB.sign(studentCrypto);
        final frames = signedClassB.toBleFrames();

        for (final f in frames) {
          await teacherService.handleIncomingBleFrame(f, -60);
        }

        expect(teacherService.verifiedResults.containsKey(studentId), isFalse);
      });

      test('61. replayed response rejected by verifier ledger', () async {
        final nowSec = DateTime.now().toUtc().millisecondsSinceEpoch ~/ 1000;
        final teacherService = PassportTeacherAttendanceService(
          cryptoService: teacherCrypto,
          trustBundleService: teacherTrustBundleService,
        );
        final nonce = PassportAttendanceModel.generateSecureSessionNonce();
        final beacon = PassportTeacherBeaconModel(
          protocolVersion: 1,
          sessionId: 'session-replay-test',
          teacherId: teacherId,
          teacherKeyId: teacherKeyId,
          sessionNonce: nonce,
          issuedAt: nowSec,
          expiresAt: nowSec + 300,
        );
        teacherService.setActiveBeacon(beacon);

        final resp = PassportAttendanceResponseModel(
          version: 1,
          sessionId: 'session-replay-test',
          studentId: studentId,
          deviceKeyId: studentKeyId,
          challengeNonce: nonce,
          issuedAt: nowSec,
          expiresAt: nowSec + 30,
          biometricGate: true,
          responseNonce: 'nonce_replay_001',
        );
        final signed = await resp.sign(studentCrypto);
        final frames = signed.toBleFrames();

        // First submission: should verify
        for (final f in frames) {
          await teacherService.handleIncomingBleFrame(f, -60);
        }
        expect(teacherService.verifiedResults.containsKey(studentId), isTrue);

        // Replay attempt: re-send frames
        for (final f in frames) {
          await teacherService.handleIncomingBleFrame(f, -60);
        }

        // Verify offline directly: should fail with replayedResponse
        final replayVerify = await teacherService.verifyAttendanceResponse(
          signed,
          currentTimestampSeconds: nowSec,
        );
        expect(replayVerify.valid, isFalse);
        expect(replayVerify.status, equals(PassportAttendanceStatus.replayedResponse));
      });

      test('62. cryptographic Ed25519 signature preserved through BLE fragmentation', () async {
        final nowSec = DateTime.now().toUtc().millisecondsSinceEpoch ~/ 1000;
        const sessionId = 'session-crypto-preservation';
        final nonce = PassportAttendanceModel.generateSecureSessionNonce();

        final resp = PassportAttendanceResponseModel(
          version: 1,
          sessionId: sessionId,
          studentId: studentId,
          deviceKeyId: studentKeyId,
          challengeNonce: nonce,
          issuedAt: nowSec,
          expiresAt: nowSec + 30,
          biometricGate: true,
          responseNonce: PassportAttendanceModel.generateSecureSessionNonce(),
        );

        final signed = await resp.sign(studentCrypto);
        final frames = signed.toBleFrames();

        // Reassemble from BLE frames
        final reassembled = PassportAttendanceResponseModel.fromBleFrames(frames);
        expect(reassembled, isNotNull);

        // Verify Ed25519 signature over canonicalJson of reassembled object
        final canonical = reassembled!.toCanonicalJson();
        final isSigValid = await teacherCrypto.verifySignature(
          publicKey: studentPubB64,
          challenge: canonical,
          signature: reassembled.signature,
        );

        expect(isSigValid, isTrue,
            reason: 'Ed25519 cryptographic signature must verify successfully after BLE reassembly');
      });
    });

    // =========================================================================
    // SECTION 11: OFFLINE ATTENDANCE WORKFLOW (Tests 63-66)
    // =========================================================================
    group('Offline Attendance Workflow', () {
      test('63. extractSessionIdFromBleUuid recovers 24-hex ID and filters out non-CampusOS UUIDs', () {
        const originalSessionId = '67a123456789abcdef012345';
        final bleUuid = SessionService.formatSessionBleUuid(originalSessionId);
        expect(bleUuid, equals('00000000-67a1-2345-6789-abcdef012345'));

        final extracted = SessionService.extractSessionIdFromBleUuid(bleUuid);
        expect(extracted, equals(originalSessionId));

        // Rejects standard Bluetooth SIG base UUIDs
        expect(SessionService.extractSessionIdFromBleUuid('0000180d-0000-1000-8000-00805f9b34fb'), isNull);
        // Rejects all-zero UUID
        expect(SessionService.extractSessionIdFromBleUuid('00000000-0000-0000-0000-000000000000'), isNull);
        // Rejects non-CampusOS UUIDs without 00000000 prefix
        expect(SessionService.extractSessionIdFromBleUuid('6e400001-b5a3-f393-e0a9-e50e24dcca9e'), isNull);
      });

      test('64. over-the-air BLE presence beacon verified without requiring remote teacher trust bundle', () async {
        final nowSec = DateTime.now().toUtc().millisecondsSinceEpoch ~/ 1000;
        final emptyStorage = FakePassportKeyStorage();
        final emptyTrustService = PassportTrustBundleService(storage: emptyStorage, cryptoService: studentCrypto);
        final studentAttendance = PassportStudentAttendanceService(
          cryptoService: studentCrypto,
          trustBundleService: emptyTrustService,
        );

        // Synthesized over-the-air BLE presence beacon with empty signature
        final otaBeacon = PassportTeacherBeaconModel(
          sessionId: '67a123456789abcdef012345',
          subject: 'Operating Systems',
          teacherId: 'teacher',
          teacherKeyId: 'teacher_key',
          sessionNonce: 'nonce_67a123456789abcdef012345',
          issuedAt: nowSec,
          expiresAt: nowSec + 600,
          signature: '', // OTA BLE beacon signature is empty
        );

        final result = await studentAttendance.verifyTeacherBeaconDetailed(
          otaBeacon,
          currentTimestampSeconds: nowSec,
        );

        expect(result.isValid, isTrue, reason: 'OTA presence beacon must verify cleanly offline');
        expect(result.status, equals(TeacherBeaconVerificationStatus.trustedAndVerified));
      });

      test('65. expired over-the-air BLE presence beacon is rejected', () async {
        final nowSec = DateTime.now().toUtc().millisecondsSinceEpoch ~/ 1000;
        final studentAttendance = PassportStudentAttendanceService(
          cryptoService: studentCrypto,
          trustBundleService: studentTrustBundleService,
        );

        final expiredOtaBeacon = PassportTeacherBeaconModel(
          sessionId: '67a123456789abcdef012345',
          teacherId: 'teacher',
          teacherKeyId: 'teacher_key',
          sessionNonce: 'nonce_67a123456789abcdef012345',
          issuedAt: nowSec - 700,
          expiresAt: nowSec - 100, // Expired
          signature: '',
        );

        final result = await studentAttendance.verifyTeacherBeaconDetailed(
          expiredOtaBeacon,
          currentTimestampSeconds: nowSec,
        );

        expect(result.isValid, isFalse);
        expect(result.status, equals(TeacherBeaconVerificationStatus.expiredSession));
      });

      test('66. teacher service accepts and ledgers student response when trust bundle is missing offline', () async {
        final nowSec = DateTime.now().toUtc().millisecondsSinceEpoch ~/ 1000;
        const sessionId = '67a123456789abcdef012345';
        final nonce = PassportAttendanceModel.generateSecureSessionNonce();

        // Teacher service with empty storage (no trust bundle cached yet)
        final emptyStorage = FakePassportKeyStorage();
        final emptyTrustService = PassportTrustBundleService(storage: emptyStorage, cryptoService: teacherCrypto);
        final offlineTeacherService = PassportTeacherAttendanceService(
          cryptoService: teacherCrypto,
          trustBundleService: emptyTrustService,
        );

        final beacon = PassportTeacherBeaconModel(
          protocolVersion: 1,
          sessionId: sessionId,
          teacherId: teacherId,
          teacherKeyId: teacherKeyId,
          sessionNonce: nonce,
          issuedAt: nowSec,
          expiresAt: nowSec + 300,
        );
        offlineTeacherService.setActiveBeacon(beacon);

        final resp = PassportAttendanceResponseModel(
          version: 1,
          sessionId: sessionId,
          studentId: studentId,
          deviceKeyId: studentKeyId,
          challengeNonce: nonce,
          issuedAt: nowSec,
          expiresAt: nowSec + 15,
          biometricGate: true,
          responseNonce: PassportAttendanceModel.generateSecureSessionNonce(),
        );
        final signedResp = await resp.sign(studentCrypto);

        final result = await offlineTeacherService.verifyAttendanceResponse(
          signedResp,
          rssiSamples: [-65],
          currentTimestampSeconds: nowSec,
        );

        expect(result.valid, isTrue, reason: 'Teacher service must accept response offline when trust bundle is missing');
        expect(result.status, equals(PassportAttendanceStatus.verifiedPresent));
        expect(result.reason, contains('OFFLINE_TRUST_DATA_MISSING'));
      });
    });
  });
}
