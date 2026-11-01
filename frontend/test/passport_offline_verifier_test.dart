import 'dart:convert';
import 'package:cryptography/cryptography.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:attendance_app/student/models/passport_presentation_model.dart';
import 'package:attendance_app/student/models/passport_trust_bundle_model.dart';
import 'package:attendance_app/student/services/passport_crypto_service.dart';
import 'package:attendance_app/student/services/passport_trust_bundle_service.dart';
import 'package:attendance_app/student/services/passport_offline_verifier_service.dart';

class FakePassportKeyStorage implements PassportKeyStorage {
  final Map<String, String> _data = {};

  @override
  Future<String?> read(String key) async => _data[key];

  @override
  Future<void> write(String key, String value) async => _data[key] = value;

  @override
  Future<void> delete(String key) async => _data.remove(key);

  @override
  Future<bool> containsKey(String key) async => _data.containsKey(key);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('CampusOS Passport 1F: Offline Verifier Service Tests', () {
    late PassportCryptoService cryptoService;
    late FakePassportKeyStorage keyStorage;
    late PassportTrustBundleService bundleService;
    late PassportOfflineVerifierService offlineVerifier;

    late SimpleKeyPair studentKeyPair;
    late String studentPubB64;

    late SimpleKeyPair otherKeyPair;
    late String otherPubB64;

    late SimpleKeyPair institutionKeyPair;
    late String institutionPubB64;

    const String studentId = 'student-uuid-42';
    const String keyId = 'key-uuid-42';
    const String certId = 'cert-uuid-42';
    const String issuerKeyId = 'campusos-root-2026-v1';

    setUp(() async {
      keyStorage = FakePassportKeyStorage();
      cryptoService = PassportCryptoService(storage: keyStorage);
      await cryptoService.initialize();

      bundleService = PassportTrustBundleService(
        storage: keyStorage,
        cryptoService: cryptoService,
      );

      offlineVerifier = PassportOfflineVerifierService(
        bundleService: bundleService,
        cryptoService: cryptoService,
      );

      final ed25519 = Ed25519();

      // Student keypair
      studentKeyPair = await ed25519.newKeyPair();
      final pub1 = await studentKeyPair.extractPublicKey();
      studentPubB64 = base64Encode(pub1.bytes);

      // Other keypair (unauthorized/mismatched)
      otherKeyPair = await ed25519.newKeyPair();
      final pub2 = await otherKeyPair.extractPublicKey();
      otherPubB64 = base64Encode(pub2.bytes);

      // Institution keypair
      institutionKeyPair = await ed25519.newKeyPair();
      final pubInst = await institutionKeyPair.extractPublicKey();
      institutionPubB64 = base64Encode(pubInst.bytes);

      // Create and store a fresh valid trust bundle
      final now = DateTime.now().toUtc().millisecondsSinceEpoch ~/ 1000;
      final payloadMap = {
        'version': 1,
        'issuerKeyId': issuerKeyId,
        'generatedAt': now - 60,
        'expiresAt': now + 86400,
        'institution': {
          'keyId': issuerKeyId,
          'publicKey': institutionPubB64,
        },
        'identities': [
          {
            'certificateId': certId,
            'issuerKeyId': issuerKeyId,
            'keyId': keyId,
            'publicKey': studentPubB64,
            'status': 'ACTIVE',
            'userId': studentId,
            'userName': 'Sourav Nanda',
            'validFrom': now - 10000,
            'validTo': now + 100000,
          },
          {
            'certificateId': 'cert-revoked-1',
            'issuerKeyId': issuerKeyId,
            'keyId': 'key-revoked-1',
            'publicKey': otherPubB64,
            'status': 'REVOKED',
            'userId': 'student-revoked',
            'validFrom': now - 10000,
            'validTo': now + 100000,
          },
          {
            'certificateId': 'cert-expired-1',
            'issuerKeyId': issuerKeyId,
            'keyId': 'key-expired-1',
            'publicKey': otherPubB64,
            'status': 'ACTIVE',
            'userId': 'student-exp',
            'validFrom': now - 20000,
            'validTo': now - 100, // expired certificate
          }
        ],
        'revokedKeyIds': ['key-revoked-1', 'key-revoked-2'],
      };

      final canonicalJson = canonicalizeJson(payloadMap);
      final sig = await ed25519.sign(utf8.encode(canonicalJson), keyPair: institutionKeyPair);
      final bundle = PassportTrustBundle.fromJson({
        'payload': payloadMap,
        'signature': base64Encode(sig.bytes),
      });

      await keyStorage.write(
        PassportTrustBundleService.trustBundleStorageKey,
        jsonEncode(bundle.toJson()),
      );
    });

    Future<String> createSignedQr({
      int? issuedAt,
      int? expiresAt,
      String? customKeyId,
      String? customCertId,
      String? customUserId,
      String? customIssuerKeyId,
      SimpleKeyPair? signingKey,
    }) async {
      final now = DateTime.now().toUtc().millisecondsSinceEpoch ~/ 1000;
      final iAt = issuedAt ?? (now - 5);
      final eAt = expiresAt ?? (now + 25);

      final presentation = PassportPresentationModel(
        version: 1,
        type: 'PASSPORT_PRESENTATION',
        keyId: customKeyId ?? keyId,
        userId: customUserId ?? studentId,
        certificateId: customCertId ?? certId,
        issuerKeyId: customIssuerKeyId ?? issuerKeyId,
        issuedAt: iAt,
        expiresAt: eAt,
        nonce: 'nonce-12345',
      );

      final canonicalJson = presentation.toCanonicalJson();
      final ed25519 = Ed25519();
      final sig = await ed25519.sign(
        utf8.encode(canonicalJson),
        keyPair: signingKey ?? studentKeyPair,
      );
      final sigB64 = base64Encode(sig.bytes);

      return presentation.withSignature(sigB64).toQrPayload();
    }

    test('1. Valid QR presentation verified 100% offline without network', () async {
      final qr = await createSignedQr();
      final result = await offlineVerifier.verifyOffline(qrPayload: qr);

      expect(result.valid, isTrue);
      expect(result.reason, equals('OFFLINE_VALID'));
      expect(result.isOffline, isTrue);
      expect(result.isOfflineValid, isTrue);
      expect(result.userId, equals(studentId));
      expect(result.keyId, equals(keyId));
      expect(result.user?.name, equals('Sourav Nanda'));
      expect(result.displayTitle, equals('PASSPORT VALID'));
    });

    test('2. QR signed with unauthorized key rejected (OFFLINE_INVALID_SIGNATURE)', () async {
      final qr = await createSignedQr(signingKey: otherKeyPair);
      final result = await offlineVerifier.verifyOffline(qrPayload: qr);

      expect(result.valid, isFalse);
      expect(result.reason, equals('OFFLINE_INVALID_SIGNATURE'));
      expect(result.isInvalidSignature, isTrue);
      expect(result.displayTitle, equals('Passport Could Not Be Verified'));
    });

    test('3. QR with tampered presentation payload rejected (OFFLINE_INVALID_SIGNATURE)', () async {
      final validQr = await createSignedQr();
      final decoded = jsonDecode(validQr) as Map<String, dynamic>;
      final payload = decoded['p'] as Map<String, dynamic>;
      payload['nonce'] = 'altered-tampered-nonce'; // alter after signing

      final tamperedQr = jsonEncode({'p': payload, 's': decoded['s']});
      final result = await offlineVerifier.verifyOffline(qrPayload: tamperedQr);

      expect(result.valid, isFalse);
      expect(result.reason, equals('OFFLINE_INVALID_SIGNATURE'));
    });

    test('4. Unknown identity key rejected (OFFLINE_UNKNOWN_KEY)', () async {
      final qr = await createSignedQr(customKeyId: 'unknown-key-999');
      final result = await offlineVerifier.verifyOffline(qrPayload: qr);

      expect(result.valid, isFalse);
      expect(result.reason, equals('OFFLINE_UNKNOWN_KEY'));
      expect(result.isUnknownKey, isTrue);
      expect(result.displayTitle, equals('Unknown Passport Identity'));
    });

    test('5. Revoked identity key rejected (OFFLINE_REVOKED_KEY)', () async {
      final qr = await createSignedQr(customKeyId: 'key-revoked-1');
      final result = await offlineVerifier.verifyOffline(qrPayload: qr);

      expect(result.valid, isFalse);
      expect(result.reason, equals('OFFLINE_REVOKED_KEY'));
      expect(result.isRevoked, isTrue);
      expect(result.displayTitle, equals('Passport Identity Revoked'));
    });

    test('6. Identity / certificate mismatch rejected (OFFLINE_CERTIFICATE_MISMATCH)', () async {
      final qr = await createSignedQr(customUserId: 'different-student-uuid');
      final result = await offlineVerifier.verifyOffline(qrPayload: qr);

      expect(result.valid, isFalse);
      expect(result.reason, equals('OFFLINE_CERTIFICATE_MISMATCH'));
      expect(result.isMismatch, isTrue);
    });

    test('7. Expired institutional certificate rejected (OFFLINE_CERTIFICATE_EXPIRED)', () async {
      final qr = await createSignedQr(
        customKeyId: 'key-expired-1',
        customCertId: 'cert-expired-1',
        customUserId: 'student-exp',
        signingKey: otherKeyPair,
      );
      final result = await offlineVerifier.verifyOffline(qrPayload: qr);

      expect(result.valid, isFalse);
      expect(result.reason, equals('OFFLINE_CERTIFICATE_EXPIRED'));
      expect(result.displayTitle, equals('Identity Certificate Expired'));
    });

    test('8. Expired dynamic presentation rejected (OFFLINE_EXPIRED)', () async {
      final now = DateTime.now().toUtc().millisecondsSinceEpoch ~/ 1000;
      final qr = await createSignedQr(
        issuedAt: now - 60,
        expiresAt: now - 40, // 40 seconds ago (beyond 30s skew tolerance)
      );
      final result = await offlineVerifier.verifyOffline(qrPayload: qr);

      expect(result.valid, isFalse);
      expect(result.reason, equals('OFFLINE_EXPIRED'));
      expect(result.isExpired, isTrue);
    });

    test('9. Future presentation outside skew tolerance rejected (OFFLINE_NOT_YET_VALID)', () async {
      final now = DateTime.now().toUtc().millisecondsSinceEpoch ~/ 1000;
      final qr = await createSignedQr(
        issuedAt: now + 60, // 60s in future (> 30s clock skew)
        expiresAt: now + 90,
      );
      final result = await offlineVerifier.verifyOffline(qrPayload: qr);

      expect(result.valid, isFalse);
      expect(result.reason, equals('OFFLINE_NOT_YET_VALID'));
      expect(result.displayTitle, equals('Passport Not Yet Valid'));
    });

    test('10. Missing local trust data returns OFFLINE_TRUST_DATA_MISSING', () async {
      await keyStorage.delete(PassportTrustBundleService.trustBundleStorageKey);
      await bundleService.clearLocalBundle();

      final qr = await createSignedQr();
      final result = await offlineVerifier.verifyOffline(qrPayload: qr);

      expect(result.valid, isFalse);
      expect(result.reason, equals('OFFLINE_TRUST_DATA_MISSING'));
      expect(result.isTrustDataMissing, isTrue);
      expect(result.displayTitle, equals('Trust Data Missing'));
    });

    test('11. Expired local trust data returns OFFLINE_TRUST_DATA_EXPIRED', () async {
      const now = 1774480000;
      final expiredPayload = {
        'version': 1,
        'issuerKeyId': issuerKeyId,
        'generatedAt': now - 100000,
        'expiresAt': now - 100, // expired in past
        'institution': {
          'keyId': issuerKeyId,
          'publicKey': institutionPubB64,
        },
        'identities': <Map<String, dynamic>>[],
        'revokedKeyIds': <String>[],
      };
      final canonical = canonicalizeJson(expiredPayload);
      final ed25519 = Ed25519();
      final sig = await ed25519.sign(utf8.encode(canonical), keyPair: institutionKeyPair);
      final expiredBundle = PassportTrustBundle.fromJson({
        'payload': expiredPayload,
        'signature': base64Encode(sig.bytes),
      });

      await bundleService.clearLocalBundle();
      await keyStorage.write(
        PassportTrustBundleService.trustBundleStorageKey,
        jsonEncode(expiredBundle.toJson()),
      );
      // Fresh service instance with no in-memory cache
      bundleService = PassportTrustBundleService(
        storage: keyStorage,
        cryptoService: cryptoService,
      );
      offlineVerifier = PassportOfflineVerifierService(
        bundleService: bundleService,
        cryptoService: cryptoService,
      );

      final qr = await createSignedQr();
      final result = await offlineVerifier.verifyOffline(
        qrPayload: qr,
        currentTimestampSeconds: now,
      );

      expect(result.valid, isFalse);
      expect(result.reason, equals('OFFLINE_TRUST_DATA_EXPIRED'));
      expect(result.isTrustDataExpired, isTrue);
      expect(result.displayTitle, equals('Trust Data Expired'));
    });

    test('12. Security Test: Identical cryptographic verification result offline across repeated runs', () async {
      final qr = await createSignedQr();

      final run1 = await offlineVerifier.verifyOffline(qrPayload: qr);
      final run2 = await offlineVerifier.verifyOffline(qrPayload: qr);

      expect(run1.valid, isTrue);
      expect(run2.valid, isTrue);
      expect(run1.reason, equals(run2.reason));
      expect(run1.userId, equals(run2.userId));
      expect(run1.keyId, equals(run2.keyId));
      expect(run1.expiresAt, equals(run2.expiresAt));
    });
  });
}
