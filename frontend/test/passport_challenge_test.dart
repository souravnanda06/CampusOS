import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:attendance_app/student/models/passport_challenge_model.dart';
import 'package:attendance_app/student/models/passport_identity_model.dart';
import 'package:attendance_app/student/models/passport_presentation_model.dart';
import 'package:attendance_app/student/models/passport_verification_result.dart';
import 'package:attendance_app/student/services/passport_crypto_service.dart';
import 'package:attendance_app/student/services/passport_presentation_service.dart';
import 'package:attendance_app/student/services/passport_identity_service.dart';
import 'package:attendance_app/student/services/passport_challenge_service.dart';
import 'package:attendance_app/student/services/passport_offline_verifier_service.dart';
import 'package:attendance_app/student/services/passport_trust_bundle_service.dart';
import 'package:attendance_app/student/models/passport_trust_bundle_model.dart';

/// In-memory storage fake for fast, isolated unit testing.
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

/// Fake identity service that returns a controllable enrollment status.
class FakePassportIdentityService extends PassportIdentityService {
  PassportEnrollmentStatus status;

  FakePassportIdentityService(this.status);

  @override
  Future<PassportEnrollmentStatus> getIdentity({String? userId}) async => status;
}

/// Fake trust bundle service for offline verifier testing.
class FakeTrustBundleService extends PassportTrustBundleService {
  PassportTrustBundle? bundle;

  FakeTrustBundleService({this.bundle});

  @override
  Future<PassportTrustBundle?> getLocalBundle() async => bundle;
}

/// Test subclass of PassportOfflineVerifierService to test verifyOfflineWithChallenge.
class TestOfflineVerifierService extends PassportOfflineVerifierService {
  PassportVerificationResult? mockBaseResult;

  TestOfflineVerifierService({PassportTrustBundleService? bundleService})
      : super(bundleService: bundleService);

  @override
  Future<PassportVerificationResult> verifyOffline({
    required String qrPayload,
    int? currentTimestampSeconds,
    int maxClockSkewSeconds = 30,
  }) async {
    return mockBaseResult ??
        const PassportVerificationResult(
          valid: true,
          reason: 'OFFLINE_VALID',
          verificationSource: 'OFFLINE',
          userId: 'test_user_001',
          keyId: 'test_key_001',
          certificateId: 'test_cert_001',
          trustSnapshotTime: 1700000000,
        );
  }
}

void main() {
  group('CampusOS Passport 1G — BLE Challenge-Bound Presentation Tests', () {
    // ═══════════════════════════════════════════════════════════════════
    // SECTION 1: PassportChallengeModel Tests
    // ═══════════════════════════════════════════════════════════════════
    group('PassportChallengeModel', () {
      test('1. generate() creates challenge with valid nonce', () {
        final challenge = PassportChallengeModel.generate(
          verifierId: 'verifier-001',
          currentTimestampSeconds: 1700000000,
        );

        expect(challenge.nonce, isNotEmpty);
        expect(challenge.nonce.length, equals(16)); // 8 bytes = 16 hex chars
        expect(challenge.verifierId, equals('verifier-001'));
        expect(challenge.issuedAt, equals(1700000000));
        expect(challenge.expiresAt, equals(1700000060)); // default 60s validity
      });

      test('2. generate() produces unique nonces across invocations', () {
        final nonces = <String>{};
        for (int i = 0; i < 100; i++) {
          final c = PassportChallengeModel.generate(
            verifierId: 'v1',
            currentTimestampSeconds: 1700000000 + i,
          );
          nonces.add(c.nonce);
        }
        expect(nonces.length, equals(100)); // All unique
      });

      test('3. isExpired() correctly detects expired challenge', () {
        const challenge = PassportChallengeModel(
          nonce: 'abc123def456aabb',
          verifierId: 'v1',
          issuedAt: 1700000000,
          expiresAt: 1700000060,
        );

        expect(challenge.isExpired(1700000059), isFalse);
        expect(challenge.isExpired(1700000060), isTrue);
        expect(challenge.isExpired(1700000100), isTrue);
      });

      test('4. remainingSeconds() returns correct countdown', () {
        const challenge = PassportChallengeModel(
          nonce: 'abc123def456aabb',
          verifierId: 'v1',
          issuedAt: 1700000000,
          expiresAt: 1700000060,
        );

        expect(challenge.remainingSeconds(1700000030), equals(30));
        expect(challenge.remainingSeconds(1700000060), equals(0));
        expect(challenge.remainingSeconds(1700000100), equals(0)); // clamped
      });

      test('5. toPayloadMap() contains all required fields sorted alphabetically', () {
        const challenge = PassportChallengeModel(
          nonce: 'aabbccddeeff0011',
          verifierId: 'verifier-001',
          issuedAt: 1700000000,
          expiresAt: 1700000060,
        );

        final map = challenge.toPayloadMap();
        expect(map['nonce'], equals('aabbccddeeff0011'));
        expect(map['verifierId'], equals('verifier-001'));
        expect(map['issuedAt'], equals(1700000000));
        expect(map['expiresAt'], equals(1700000060));
        expect(map.keys.toList()..sort(), equals(map.keys.toList())); // sorted
      });

      test('6. toBleServiceData() produces exactly 20 bytes', () {
        const challenge = PassportChallengeModel(
          nonce: 'aabbccddeeff0011',
          verifierId: 'verifier-001',
          issuedAt: 1700000000,
          expiresAt: 1700000060,
        );

        final data = challenge.toBleServiceData();
        expect(data.length, equals(20));
      });

      test('7. BLE roundtrip: toBleServiceData → fromBleServiceData preserves nonce and timestamps', () {
        const original = PassportChallengeModel(
          nonce: 'aabbccddeeff0011',
          verifierId: 'test',
          issuedAt: 1700000000,
          expiresAt: 1700000060,
        );

        final data = original.toBleServiceData();
        final decoded = PassportChallengeModel.fromBleServiceData(data);

        expect(decoded.nonce, equals(original.nonce));
        expect(decoded.issuedAt, equals(original.issuedAt));
        expect(decoded.expiresAt, equals(original.expiresAt));
      });

      test('8. fromBleServiceData() rejects data shorter than 16 bytes', () {
        expect(
          () => PassportChallengeModel.fromBleServiceData(Uint8List(10)),
          throwsA(isA<FormatException>()),
        );
      });

      test('9. fromMap() correctly parses JSON challenge data', () {
        final map = {
          'nonce': 'abc123',
          'verifierId': 'v-42',
          'issuedAt': 1700000000,
          'expiresAt': 1700000060,
        };

        final challenge = PassportChallengeModel.fromMap(map);
        expect(challenge.nonce, equals('abc123'));
        expect(challenge.verifierId, equals('v-42'));
        expect(challenge.issuedAt, equals(1700000000));
        expect(challenge.expiresAt, equals(1700000060));
      });

      test('10. custom validity duration is respected', () {
        final challenge = PassportChallengeModel.generate(
          verifierId: 'v1',
          validity: const Duration(seconds: 120),
          currentTimestampSeconds: 1700000000,
        );

        expect(challenge.expiresAt, equals(1700000120));
      });

      test('11. equality operator works correctly', () {
        const c1 = PassportChallengeModel(
          nonce: 'abc', verifierId: 'v1', issuedAt: 100, expiresAt: 200,
        );
        const c2 = PassportChallengeModel(
          nonce: 'abc', verifierId: 'v1', issuedAt: 100, expiresAt: 200,
        );
        const c3 = PassportChallengeModel(
          nonce: 'xyz', verifierId: 'v1', issuedAt: 100, expiresAt: 200,
        );

        expect(c1, equals(c2));
        expect(c1, isNot(equals(c3)));
      });

      test('12. passportChallengeServiceUuid is distinct from attendance UUID format', () {
        // Attendance uses session IDs as UUIDs (v4 format). Passport challenge uses a
        // fixed BLE SIG-reserved UUID.
        expect(
          PassportChallengeModel.passportChallengeServiceUuid,
          contains('FE10'),
        );
      });
    });

    // ═══════════════════════════════════════════════════════════════════
    // SECTION 2: PassportPresentationModel Challenge Binding Tests
    // ═══════════════════════════════════════════════════════════════════
    group('PassportPresentationModel with Challenge', () {
      test('13. toPayloadMap() includes challenge when present', () {
        final model = PassportPresentationModel(
          keyId: 'k1',
          userId: 'u1',
          certificateId: 'c1',
          issuerKeyId: 'ik1',
          issuedAt: 1700000000,
          expiresAt: 1700000030,
          nonce: 'n1',
          challenge: {
            'nonce': 'challenge-nonce',
            'verifierId': 'v1',
            'issuedAt': 1700000000,
            'expiresAt': 1700000060,
          },
        );

        final payload = model.toPayloadMap();
        expect(payload['challenge'], isA<Map<String, dynamic>>());
        expect(payload['challenge']['nonce'], equals('challenge-nonce'));
      });

      test('14. toPayloadMap() omits challenge when null', () {
        final model = PassportPresentationModel(
          keyId: 'k1',
          userId: 'u1',
          certificateId: 'c1',
          issuerKeyId: 'ik1',
          issuedAt: 1700000000,
          expiresAt: 1700000030,
          nonce: 'n1',
        );

        final payload = model.toPayloadMap();
        expect(payload.containsKey('challenge'), isFalse);
      });

      test('15. isChallengebound getter works correctly', () {
        final withChallenge = PassportPresentationModel(
          keyId: 'k1', userId: 'u1', certificateId: 'c1', issuerKeyId: 'ik1',
          issuedAt: 100, expiresAt: 130, nonce: 'n1',
          challenge: {'nonce': 'cn1', 'verifierId': 'v1', 'issuedAt': 100, 'expiresAt': 160},
        );

        final withoutChallenge = PassportPresentationModel(
          keyId: 'k1', userId: 'u1', certificateId: 'c1', issuerKeyId: 'ik1',
          issuedAt: 100, expiresAt: 130, nonce: 'n1',
        );

        expect(withChallenge.isChallengebound, isTrue);
        expect(withoutChallenge.isChallengebound, isFalse);
      });

      test('16. canonical JSON includes challenge key in sorted position', () {
        final model = PassportPresentationModel(
          keyId: 'k1', userId: 'u1', certificateId: 'c1', issuerKeyId: 'ik1',
          issuedAt: 100, expiresAt: 130, nonce: 'n1',
          challenge: {'expiresAt': 160, 'issuedAt': 100, 'nonce': 'cn1', 'verifierId': 'v1'},
        );

        final canonical = model.toCanonicalJson();
        // 'challenge' should appear between 'certificateId' and 'expiresAt'
        final certIdx = canonical.indexOf('"certificateId"');
        final challengeIdx = canonical.indexOf('"challenge"');
        final expiresIdx = canonical.indexOf('"expiresAt"');

        expect(challengeIdx, greaterThan(certIdx));
        expect(challengeIdx, lessThan(expiresIdx));
      });

      test('17. canonical JSON WITHOUT challenge matches 1D format exactly', () {
        final model = PassportPresentationModel(
          version: 1, type: 'PASSPORT_PRESENTATION',
          keyId: 'k-123', userId: 'u-456', certificateId: 'c-789',
          issuerKeyId: 'inst-1', issuedAt: 1700000000, expiresAt: 1700000030,
          nonce: 'abc-nonce-123',
        );

        const expected =
            '{"certificateId":"c-789","expiresAt":1700000030,"issuedAt":1700000000,"issuerKeyId":"inst-1","keyId":"k-123","nonce":"abc-nonce-123","type":"PASSPORT_PRESENTATION","userId":"u-456","version":1}';

        expect(model.toCanonicalJson(), equals(expected));
      });

      test('18. withChallenge() clears signature and adds challenge', () {
        final original = PassportPresentationModel(
          keyId: 'k1', userId: 'u1', certificateId: 'c1', issuerKeyId: 'ik1',
          issuedAt: 100, expiresAt: 130, nonce: 'n1', signature: 'old-sig',
        );

        final bound = original.withChallenge({
          'nonce': 'cn1', 'verifierId': 'v1', 'issuedAt': 100, 'expiresAt': 160,
        });

        expect(bound.challenge, isNotNull);
        expect(bound.signature, isEmpty); // Must be recalculated
        expect(bound.keyId, equals(original.keyId));
      });

      test('19. withSignature() preserves challenge', () {
        final model = PassportPresentationModel(
          keyId: 'k1', userId: 'u1', certificateId: 'c1', issuerKeyId: 'ik1',
          issuedAt: 100, expiresAt: 130, nonce: 'n1',
          challenge: {'nonce': 'cn1', 'verifierId': 'v1', 'issuedAt': 100, 'expiresAt': 160},
        );

        final signed = model.withSignature('new-sig');
        expect(signed.challenge, isNotNull);
        expect(signed.challenge!['nonce'], equals('cn1'));
        expect(signed.signature, equals('new-sig'));
      });

      test('20. fromPayloadMap() parses challenge when present', () {
        final map = {
          'version': 1, 'type': 'PASSPORT_PRESENTATION',
          'keyId': 'k1', 'userId': 'u1', 'certificateId': 'c1',
          'issuerKeyId': 'ik1', 'issuedAt': 100, 'expiresAt': 130, 'nonce': 'n1',
          'challenge': {'nonce': 'cn1', 'verifierId': 'v1', 'issuedAt': 100, 'expiresAt': 160},
        };

        final model = PassportPresentationModel.fromPayloadMap(map);
        expect(model.isChallengebound, isTrue);
        expect(model.challenge!['nonce'], equals('cn1'));
      });

      test('21. fromPayloadMap() leaves challenge null when absent', () {
        final map = {
          'version': 1, 'type': 'PASSPORT_PRESENTATION',
          'keyId': 'k1', 'userId': 'u1', 'certificateId': 'c1',
          'issuerKeyId': 'ik1', 'issuedAt': 100, 'expiresAt': 130, 'nonce': 'n1',
        };

        final model = PassportPresentationModel.fromPayloadMap(map);
        expect(model.isChallengebound, isFalse);
        expect(model.challenge, isNull);
      });

      test('22. QR roundtrip preserves challenge binding', () {
        final original = PassportPresentationModel(
          keyId: 'k1', userId: 'u1', certificateId: 'c1', issuerKeyId: 'ik1',
          issuedAt: 100, expiresAt: 130, nonce: 'n1', signature: 'sig',
          challenge: {'nonce': 'cn1', 'verifierId': 'v1', 'issuedAt': 100, 'expiresAt': 160},
        );

        final qr = original.toQrPayload();
        final parsed = PassportPresentationModel.fromQrPayload(qr);

        expect(parsed.isChallengebound, isTrue);
        expect(parsed.challenge!['nonce'], equals('cn1'));
        expect(parsed.challenge!['verifierId'], equals('v1'));
        expect(parsed.signature, equals('sig'));
      });
    });

    // ═══════════════════════════════════════════════════════════════════
    // SECTION 3: Challenge-Bound Presentation Signing Tests
    // ═══════════════════════════════════════════════════════════════════
    group('Challenge-Bound Presentation Signing', () {
      late FakePassportKeyStorage fakeStorage;
      late PassportCryptoService cryptoService;

      setUp(() {
        fakeStorage = FakePassportKeyStorage();
        cryptoService = PassportCryptoService(storage: fakeStorage);
      });

      test('23. challenge-bound canonical JSON is different from non-challenge canonical', () async {
        await cryptoService.getOrCreatePublicKey();

        final base = PassportPresentationModel(
          keyId: 'k1', userId: 'u1', certificateId: 'c1', issuerKeyId: 'ik1',
          issuedAt: 100, expiresAt: 130, nonce: 'n1',
        );

        final withChallenge = PassportPresentationModel(
          keyId: 'k1', userId: 'u1', certificateId: 'c1', issuerKeyId: 'ik1',
          issuedAt: 100, expiresAt: 130, nonce: 'n1',
          challenge: {'nonce': 'cn1', 'verifierId': 'v1', 'issuedAt': 100, 'expiresAt': 160},
        );

        expect(base.toCanonicalJson(), isNot(equals(withChallenge.toCanonicalJson())));
      });

      test('24. signature over challenge-bound payload verifies correctly', () async {
        final pubKey = await cryptoService.getOrCreatePublicKey();

        final model = PassportPresentationModel(
          keyId: 'k1', userId: 'u1', certificateId: 'c1', issuerKeyId: 'ik1',
          issuedAt: 100, expiresAt: 130, nonce: 'n1',
          challenge: {'nonce': 'cn1', 'verifierId': 'v1', 'issuedAt': 100, 'expiresAt': 160},
        );

        final canonical = model.toCanonicalJson();
        final signature = await cryptoService.signPresentation(canonical);

        final verified = await cryptoService.verifySignature(
          publicKey: pubKey,
          challenge: canonical,
          signature: signature,
        );

        expect(verified, isTrue);
      });

      test('25. signature over non-challenge payload does NOT verify against challenge-bound canonical', () async {
        final pubKey = await cryptoService.getOrCreatePublicKey();

        final withoutChallenge = PassportPresentationModel(
          keyId: 'k1', userId: 'u1', certificateId: 'c1', issuerKeyId: 'ik1',
          issuedAt: 100, expiresAt: 130, nonce: 'n1',
        );

        final withChallenge = PassportPresentationModel(
          keyId: 'k1', userId: 'u1', certificateId: 'c1', issuerKeyId: 'ik1',
          issuedAt: 100, expiresAt: 130, nonce: 'n1',
          challenge: {'nonce': 'cn1', 'verifierId': 'v1', 'issuedAt': 100, 'expiresAt': 160},
        );

        // Sign without challenge
        final sigWithout = await cryptoService.signPresentation(withoutChallenge.toCanonicalJson());

        // Try to verify against challenge-bound canonical
        final verified = await cryptoService.verifySignature(
          publicKey: pubKey,
          challenge: withChallenge.toCanonicalJson(),
          signature: sigWithout,
        );

        expect(verified, isFalse); // MUST be false: prevents replay
      });

      test('26. different challenge nonces produce different signatures', () async {
        await cryptoService.getOrCreatePublicKey();

        final model1 = PassportPresentationModel(
          keyId: 'k1', userId: 'u1', certificateId: 'c1', issuerKeyId: 'ik1',
          issuedAt: 100, expiresAt: 130, nonce: 'n1',
          challenge: {'nonce': 'challenge-A', 'verifierId': 'v1', 'issuedAt': 100, 'expiresAt': 160},
        );

        final model2 = PassportPresentationModel(
          keyId: 'k1', userId: 'u1', certificateId: 'c1', issuerKeyId: 'ik1',
          issuedAt: 100, expiresAt: 130, nonce: 'n1',
          challenge: {'nonce': 'challenge-B', 'verifierId': 'v1', 'issuedAt': 100, 'expiresAt': 160},
        );

        final sig1 = await cryptoService.signPresentation(model1.toCanonicalJson());
        final sig2 = await cryptoService.signPresentation(model2.toCanonicalJson());

        expect(sig1, isNot(equals(sig2)));
      });
    });

    // ═══════════════════════════════════════════════════════════════════
    // SECTION 4: PassportPresentationService Challenge-Bound Creation Tests
    // ═══════════════════════════════════════════════════════════════════
    group('PassportPresentationService Challenge-Bound', () {
      late FakePassportKeyStorage fakeStorage;
      late PassportCryptoService cryptoService;
      late FakePassportIdentityService fakeIdentityService;
      late PassportPresentationService presentationService;

      setUp(() async {
        fakeStorage = FakePassportKeyStorage();
        cryptoService = PassportCryptoService(storage: fakeStorage);
        final pubKey = await cryptoService.getOrCreatePublicKey();

        fakeIdentityService = FakePassportIdentityService(
          PassportEnrollmentStatus(
            enrolled: true,
            key: PassportIdentityKeyModel(
              id: 'key-1',
              userId: 'user-1',
              publicKey: pubKey,
              status: 'ACTIVE',
            ),
            certificate: PassportCertificateModel(
              id: 'cert-1',
              keyId: 'key-1',
              issuerKeyId: 'inst-key-1',
              userId: 'user-1',
              publicKey: pubKey,
              validFrom: DateTime.now().subtract(const Duration(days: 365)),
              validTo: DateTime.now().add(const Duration(days: 365)),
              signature: 'dummy-sig',
              status: 'ACTIVE',
              payload: {},
            ),
          ),
        );

        presentationService = PassportPresentationService(
          cryptoService: cryptoService,
          identityService: fakeIdentityService,
        );
      });

      test('27. createChallengeBoundPresentation() succeeds with valid challenge', () async {
        final challenge = PassportChallengeModel.generate(
          verifierId: 'verifier-001',
        );

        final presentation = await presentationService.createChallengeBoundPresentation(
          challenge: challenge,
        );

        expect(presentation.isChallengebound, isTrue);
        expect(presentation.challenge!['nonce'], equals(challenge.nonce));
        expect(presentation.challenge!['verifierId'], equals('verifier-001'));
        expect(presentation.signature, isNotEmpty);
      });

      test('28. createChallengeBoundPresentation() throws on expired challenge', () async {
        const expiredChallenge = PassportChallengeModel(
          nonce: 'expired-nonce',
          verifierId: 'v1',
          issuedAt: 1700000000,
          expiresAt: 1700000001, // Long expired
        );

        expect(
          () => presentationService.createChallengeBoundPresentation(
            challenge: expiredChallenge,
          ),
          throwsA(isA<PassportChallengeExpiredException>()),
        );
      });

      test('29. createChallengeBoundPresentation() signature covers challenge data', () async {
        final challenge = PassportChallengeModel.generate(verifierId: 'v1');
        final presentation = await presentationService.createChallengeBoundPresentation(
          challenge: challenge,
        );

        final pubKey = await cryptoService.getPublicKeyBase64();
        final isValid = await cryptoService.verifySignature(
          publicKey: pubKey!,
          challenge: presentation.toCanonicalJson(),
          signature: presentation.signature,
        );

        expect(isValid, isTrue);
      });

      test('30. non-challenge createPresentation() still works (backward compat)', () async {
        final presentation = await presentationService.createPresentation();

        expect(presentation.isChallengebound, isFalse);
        expect(presentation.challenge, isNull);
        expect(presentation.signature, isNotEmpty);
      });

      test('31. createChallengeBoundPresentation() throws when not enrolled', () async {
        fakeIdentityService.status = PassportEnrollmentStatus(enrolled: false);

        final challenge = PassportChallengeModel.generate(verifierId: 'v1');

        expect(
          () => presentationService.createChallengeBoundPresentation(challenge: challenge),
          throwsA(isA<PassportNotEnrolledException>()),
        );
      });
    });

    // ═══════════════════════════════════════════════════════════════════
    // SECTION 5: PassportChallengeService (Verifier-Side) Tests
    // ═══════════════════════════════════════════════════════════════════
    group('PassportChallengeService', () {
      late PassportChallengeService challengeService;

      setUp(() {
        challengeService = PassportChallengeService();
      });

      test('32. generateChallenge() creates and stores challenge', () {
        final challenge = challengeService.generateChallenge(
          verifierId: 'v1',
        );

        expect(challenge.nonce, isNotEmpty);
        expect(challengeService.currentChallenge, equals(challenge));
        expect(challengeService.activeChallengeCount, equals(1));
      });

      test('33. validateChallenge() returns valid challenge for known nonce', () {
        final challenge = challengeService.generateChallenge(
          verifierId: 'v1',
          currentTimestampSeconds: 1700000000,
        );

        final result = challengeService.validateChallenge(
          challenge.nonce,
          currentTimestampSeconds: 1700000030,
        );

        expect(result, isNotNull);
        expect(result!.nonce, equals(challenge.nonce));
      });

      test('34. validateChallenge() consumes nonce by default', () {
        final challenge = challengeService.generateChallenge(
          verifierId: 'v1',
          currentTimestampSeconds: 1700000000,
        );

        challengeService.validateChallenge(
          challenge.nonce,
          currentTimestampSeconds: 1700000030,
        );

        // Second call should return null (consumed)
        final result2 = challengeService.validateChallenge(
          challenge.nonce,
          currentTimestampSeconds: 1700000030,
        );

        expect(result2, isNull);
      });

      test('35. validateChallenge() with consume=false does not remove challenge', () {
        final challenge = challengeService.generateChallenge(
          verifierId: 'v1',
          currentTimestampSeconds: 1700000000,
        );

        final r1 = challengeService.validateChallenge(
          challenge.nonce,
          currentTimestampSeconds: 1700000030,
          consume: false,
        );

        final r2 = challengeService.validateChallenge(
          challenge.nonce,
          currentTimestampSeconds: 1700000030,
          consume: false,
        );

        expect(r1, isNotNull);
        expect(r2, isNotNull);
      });

      test('36. validateChallenge() returns null for unknown nonce', () {
        challengeService.generateChallenge(
          verifierId: 'v1',
          currentTimestampSeconds: 1700000000,
        );

        final result = challengeService.validateChallenge(
          'unknown-nonce',
          currentTimestampSeconds: 1700000030,
        );

        expect(result, isNull);
      });

      test('37. validateChallenge() returns null for expired challenge', () {
        final challenge = challengeService.generateChallenge(
          verifierId: 'v1',
          validity: const Duration(seconds: 30),
          currentTimestampSeconds: 1700000000,
        );

        final result = challengeService.validateChallenge(
          challenge.nonce,
          currentTimestampSeconds: 1700000100, // Well past expiry
        );

        expect(result, isNull);
      });

      test('38. hasChallengeNonce() correctly checks existence', () {
        final challenge = challengeService.generateChallenge(
          verifierId: 'v1',
        );

        expect(challengeService.hasChallengeNonce(challenge.nonce), isTrue);
        expect(challengeService.hasChallengeNonce('fake-nonce'), isFalse);
      });

      test('39. expired challenges are pruned on access', () {
        // Generate 3 challenges with short validity
        final nowSec = DateTime.now().toUtc().millisecondsSinceEpoch ~/ 1000;
        for (int i = 0; i < 3; i++) {
          challengeService.generateChallenge(
            verifierId: 'v1',
            validity: const Duration(seconds: 2),
            currentTimestampSeconds: nowSec - 100 + i, // All in the past => expired
          );
        }

        // activeChallengeCount prunes expired, so should be 0
        // Generate a new live challenge
        challengeService.generateChallenge(
          verifierId: 'v1',
        );

        // The old 3 should be pruned, leaving only the new one
        expect(challengeService.activeChallengeCount, equals(1));
      });

      test('40. dispose() clears all state', () async {
        challengeService.generateChallenge(
          verifierId: 'v1',
          currentTimestampSeconds: 1700000000,
        );

        await challengeService.dispose();

        expect(challengeService.currentChallenge, isNull);
        expect(challengeService.activeChallengeCount, equals(0));
        expect(challengeService.isAdvertising, isFalse);
      });
    });

    // ═══════════════════════════════════════════════════════════════════
    // SECTION 6: PassportVerificationResult Challenge Fields Tests
    // ═══════════════════════════════════════════════════════════════════
    group('PassportVerificationResult Challenge Fields', () {
      test('41. isChallengeBound returns true when challengeNonce is present', () {
        const result = PassportVerificationResult(
          valid: true,
          reason: 'OFFLINE_VALID',
          verificationSource: 'OFFLINE',
          challengeNonce: 'cn1',
          challengeVerifierId: 'v1',
        );

        expect(result.isChallengeBound, isTrue);
      });

      test('42. isChallengeBound returns false when challengeNonce is null', () {
        const result = PassportVerificationResult(
          valid: true,
          reason: 'VALID',
          verificationSource: 'ONLINE',
        );

        expect(result.isChallengeBound, isFalse);
      });

      test('43. challenge-specific failure getters work', () {
        const expired = PassportVerificationResult(
          valid: false, reason: 'OFFLINE_CHALLENGE_EXPIRED',
        );
        const missing = PassportVerificationResult(
          valid: false, reason: 'OFFLINE_CHALLENGE_MISSING',
        );
        const mismatch = PassportVerificationResult(
          valid: false, reason: 'OFFLINE_CHALLENGE_MISMATCH',
        );
        const invalid = PassportVerificationResult(
          valid: false, reason: 'OFFLINE_CHALLENGE_INVALID',
        );

        expect(expired.isChallengeExpired, isTrue);
        expect(missing.isChallengeMissing, isTrue);
        expect(mismatch.isChallengeMismatch, isTrue);
        expect(invalid.isChallengeInvalid, isTrue);
      });

      test('44. displayTitle returns appropriate challenge failure titles', () {
        const expired = PassportVerificationResult(
          valid: false, reason: 'OFFLINE_CHALLENGE_EXPIRED',
        );
        const missing = PassportVerificationResult(
          valid: false, reason: 'OFFLINE_CHALLENGE_MISSING',
        );

        expect(expired.displayTitle, equals('Challenge Expired'));
        expect(missing.displayTitle, equals('Challenge Required'));
      });

      test('45. displayMessage returns user-friendly challenge failure messages', () {
        const mismatch = PassportVerificationResult(
          valid: false, reason: 'OFFLINE_CHALLENGE_MISMATCH',
        );

        expect(mismatch.displayMessage, contains('nonce'));
      });
    });

    // ═══════════════════════════════════════════════════════════════════
    // SECTION 7: End-to-End Challenge-Bound Verification Tests
    // ═══════════════════════════════════════════════════════════════════
    group('End-to-End Challenge-Bound Verification', () {
      late FakePassportKeyStorage fakeStorage;
      late PassportCryptoService cryptoService;
      late FakePassportIdentityService fakeIdentityService;
      late PassportPresentationService presentationService;
      late PassportChallengeService challengeService;

      setUp(() async {
        fakeStorage = FakePassportKeyStorage();
        cryptoService = PassportCryptoService(storage: fakeStorage);
        final pubKey = await cryptoService.getOrCreatePublicKey();

        fakeIdentityService = FakePassportIdentityService(
          PassportEnrollmentStatus(
            enrolled: true,
            key: PassportIdentityKeyModel(
              id: 'key-1',
              userId: 'user-1',
              publicKey: pubKey,
              status: 'ACTIVE',
            ),
            certificate: PassportCertificateModel(
              id: 'cert-1',
              keyId: 'key-1',
              issuerKeyId: 'inst-key-1',
              userId: 'user-1',
              publicKey: pubKey,
              validFrom: DateTime.now().subtract(const Duration(days: 365)),
              validTo: DateTime.now().add(const Duration(days: 365)),
              signature: 'dummy-sig',
              status: 'ACTIVE',
              payload: {},
            ),
          ),
        );

        presentationService = PassportPresentationService(
          cryptoService: cryptoService,
          identityService: fakeIdentityService,
        );

        challengeService = PassportChallengeService();
      });

      test('46. full flow: verifier generates → student signs → verifier validates', () async {
        // 1. Verifier generates challenge
        final challenge = challengeService.generateChallenge(verifierId: 'gate-guard-1');

        // 2. Student creates challenge-bound presentation
        final presentation = await presentationService.createChallengeBoundPresentation(
          challenge: challenge,
        );

        // 3. Verifier validates challenge nonce
        final validatedChallenge = challengeService.validateChallenge(
          presentation.challenge!['nonce'] as String,
          consume: false,
        );

        expect(validatedChallenge, isNotNull);
        expect(validatedChallenge!.nonce, equals(challenge.nonce));

        // 4. Verify signature covers challenge
        final pubKey = await cryptoService.getPublicKeyBase64();
        final isValid = await cryptoService.verifySignature(
          publicKey: pubKey!,
          challenge: presentation.toCanonicalJson(),
          signature: presentation.signature,
        );

        expect(isValid, isTrue);
      });

      test('47. replayed presentation with wrong challenge nonce fails signature', () async {
        // Create presentation with challenge A
        final challengeA = challengeService.generateChallenge(verifierId: 'v1');
        final presentation = await presentationService.createChallengeBoundPresentation(
          challenge: challengeA,
        );

        // Tamper: replace challenge nonce with B
        final tamperedPayload = Map<String, dynamic>.from(presentation.toPayloadMap());
        tamperedPayload['challenge'] = {
          'nonce': 'tampered-nonce',
          'verifierId': 'v1',
          'issuedAt': challengeA.issuedAt,
          'expiresAt': challengeA.expiresAt,
        };

        // Reconstruct canonical with tampered challenge
        final tamperedModel = PassportPresentationModel.fromPayloadMap(
          tamperedPayload,
          signature: presentation.signature, // Original signature
        );

        final pubKey = await cryptoService.getPublicKeyBase64();
        final isValid = await cryptoService.verifySignature(
          publicKey: pubKey!,
          challenge: tamperedModel.toCanonicalJson(),
          signature: tamperedModel.signature,
        );

        expect(isValid, isFalse); // MUST fail: replay attack prevented
      });

      test('48. challenge-bound QR survives JSON serialization roundtrip', () async {
        final challenge = PassportChallengeModel.generate(verifierId: 'v1');
        final presentation = await presentationService.createChallengeBoundPresentation(
          challenge: challenge,
        );

        // Serialize to QR
        final qrString = presentation.toQrPayload();

        // Deserialize
        final parsed = PassportPresentationModel.fromQrPayload(qrString);

        expect(parsed.isChallengebound, isTrue);
        expect(parsed.challenge!['nonce'], equals(challenge.nonce));
        expect(parsed.signature, equals(presentation.signature));

        // Verify signature
        final pubKey = await cryptoService.getPublicKeyBase64();
        final isValid = await cryptoService.verifySignature(
          publicKey: pubKey!,
          challenge: parsed.toCanonicalJson(),
          signature: parsed.signature,
        );

        expect(isValid, isTrue);
      });

      test('49. non-challenge presentation cannot be used for challenge-bound verification', () {
        // Verifier expects a challenge but gets a plain presentation
        final plainPresentation = PassportPresentationModel(
          keyId: 'k1', userId: 'u1', certificateId: 'c1', issuerKeyId: 'ik1',
          issuedAt: 100, expiresAt: 130, nonce: 'n1', signature: 'sig',
        );

        expect(plainPresentation.isChallengebound, isFalse);
        // Verifier should reject this if challenge mode is required
      });

      test('50. challenge consumed after single use prevents replay', () {
        final challenge = challengeService.generateChallenge(verifierId: 'v1');

        // First validation: success
        final first = challengeService.validateChallenge(challenge.nonce);
        expect(first, isNotNull);

        // Second validation: consumed
        final second = challengeService.validateChallenge(challenge.nonce);
        expect(second, isNull);
      });
    });

    // ═══════════════════════════════════════════════════════════════════
    // SECTION 7: Offline Verifier Challenge Enforcement Tests
    // ═══════════════════════════════════════════════════════════════════
    group('PassportOfflineVerifierService Challenge Enforcement', () {
      late TestOfflineVerifierService verifier;

      setUp(() {
        verifier = TestOfflineVerifierService();
      });

      test('51. verifyOfflineWithChallenge() succeeds when QR has matching challenge nonce and verifierId', () async {
        final challenge = PassportChallengeModel.generate(verifierId: 'gate-verifier-north');
        final presentation = PassportPresentationModel(
          keyId: 'k1', userId: 'u1', certificateId: 'c1', issuerKeyId: 'ik1',
          issuedAt: 100, expiresAt: 130, nonce: 'n1',
          challenge: challenge.toPayloadMap(),
          signature: 'sig',
        );

        final result = await verifier.verifyOfflineWithChallenge(
          qrPayload: presentation.toQrPayload(),
          expectedChallengeNonce: challenge.nonce,
          expectedVerifierId: 'gate-verifier-north',
        );

        expect(result.isValid, isTrue);
        expect(result.isChallengeBound, isTrue);
        expect(result.challengeNonce, equals(challenge.nonce));
        expect(result.challengeVerifierId, equals('gate-verifier-north'));
      });

      test('52. verifyOfflineWithChallenge() fails with OFFLINE_CHALLENGE_MISSING when QR lacks challenge', () async {
        final presentation = PassportPresentationModel(
          keyId: 'k1', userId: 'u1', certificateId: 'c1', issuerKeyId: 'ik1',
          issuedAt: 100, expiresAt: 130, nonce: 'n1',
          signature: 'sig',
        );

        final result = await verifier.verifyOfflineWithChallenge(
          qrPayload: presentation.toQrPayload(),
          expectedChallengeNonce: 'any-nonce',
        );

        expect(result.isValid, isFalse);
        expect(result.isChallengeMissing, isTrue);
        expect(result.reason, equals('OFFLINE_CHALLENGE_MISSING'));
      });

      test('53. verifyOfflineWithChallenge() fails with OFFLINE_CHALLENGE_MISMATCH when nonce differs', () async {
        final challenge = PassportChallengeModel.generate(verifierId: 'gate-verifier-north');
        final presentation = PassportPresentationModel(
          keyId: 'k1', userId: 'u1', certificateId: 'c1', issuerKeyId: 'ik1',
          issuedAt: 100, expiresAt: 130, nonce: 'n1',
          challenge: challenge.toPayloadMap(),
          signature: 'sig',
        );

        final result = await verifier.verifyOfflineWithChallenge(
          qrPayload: presentation.toQrPayload(),
          expectedChallengeNonce: 'different-nonce',
        );

        expect(result.isValid, isFalse);
        expect(result.isChallengeMismatch, isTrue);
        expect(result.reason, equals('OFFLINE_CHALLENGE_MISMATCH'));
      });

      test('54. verifyOfflineWithChallenge() fails with OFFLINE_CHALLENGE_MISMATCH when verifierId differs', () async {
        final challenge = PassportChallengeModel.generate(verifierId: 'gate-verifier-north');
        final presentation = PassportPresentationModel(
          keyId: 'k1', userId: 'u1', certificateId: 'c1', issuerKeyId: 'ik1',
          issuedAt: 100, expiresAt: 130, nonce: 'n1',
          challenge: challenge.toPayloadMap(),
          signature: 'sig',
        );

        final result = await verifier.verifyOfflineWithChallenge(
          qrPayload: presentation.toQrPayload(),
          expectedChallengeNonce: challenge.nonce,
          expectedVerifierId: 'gate-verifier-south',
        );

        expect(result.isValid, isFalse);
        expect(result.isChallengeMismatch, isTrue);
        expect(result.reason, equals('OFFLINE_CHALLENGE_MISMATCH'));
      });

      test('55. verifyOfflineWithChallenge() returns base offline failure directly', () async {
        verifier.mockBaseResult = const PassportVerificationResult(
          valid: false,
          reason: 'OFFLINE_EXPIRED',
          verificationSource: 'OFFLINE',
        );

        final result = await verifier.verifyOfflineWithChallenge(
          qrPayload: '{"p":{"version":1},"s":""}',
          expectedChallengeNonce: 'any-nonce',
        );

        expect(result.isValid, isFalse);
        expect(result.reason, equals('OFFLINE_EXPIRED'));
      });
    });

    // ═══════════════════════════════════════════════════════════════════
    // SECTION 8: Backward Compatibility (1A–1F Regression Tests)
    // ═══════════════════════════════════════════════════════════════════
    group('Backward Compatibility', () {
      test('56. PassportPresentationModel without challenge is fully 1D-compatible', () {
        final model = PassportPresentationModel(
          version: 1, type: 'PASSPORT_PRESENTATION',
          keyId: 'k1', userId: 'u1', certificateId: 'c1', issuerKeyId: 'ik1',
          issuedAt: 1700000000, expiresAt: 1700000030, nonce: 'n1',
        );

        final payload = model.toPayloadMap();
        expect(payload.containsKey('challenge'), isFalse);
        expect(payload.keys.length, equals(9)); // Original 9 fields, no challenge
      });

      test('57. 1D canonical JSON format is unchanged for non-challenge presentations', () {
        final model = PassportPresentationModel(
          version: 1, type: 'PASSPORT_PRESENTATION',
          keyId: 'k1', userId: 'u1', certificateId: 'c1', issuerKeyId: 'ik1',
          issuedAt: 100, expiresAt: 130, nonce: 'n1',
        );

        final canonical = model.toCanonicalJson();
        expect(canonical, isNot(contains('challenge')));
        expect(canonical.contains('"version":1'), isTrue);
      });

      test('58. existing QR envelope format is preserved', () {
        final model = PassportPresentationModel(
          keyId: 'k1', userId: 'u1', certificateId: 'c1', issuerKeyId: 'ik1',
          issuedAt: 100, expiresAt: 130, nonce: 'n1', signature: 'sig1',
        );

        final qr = model.toQrPayload();
        final decoded = jsonDecode(qr);
        expect(decoded['p'], isA<Map<String, dynamic>>());
        expect(decoded['s'], equals('sig1'));
        expect((decoded['p'] as Map).containsKey('challenge'), isFalse);
      });

      test('59. PassportVerificationResult existing getters unchanged', () {
        const result = PassportVerificationResult(
          valid: true, reason: 'VALID', verificationSource: 'ONLINE',
          userId: 'u1', keyId: 'k1',
        );

        expect(result.isValid, isTrue);
        expect(result.isOffline, isFalse);
        expect(result.isChallengeBound, isFalse);
        expect(result.isNetworkError, isFalse);
      });

      test('60. PassportVerificationResult offline valid result unchanged', () {
        const result = PassportVerificationResult(
          valid: true, reason: 'OFFLINE_VALID', verificationSource: 'OFFLINE',
          userId: 'u1', keyId: 'k1', trustSnapshotTime: 1700000000,
        );

        expect(result.isOfflineValid, isTrue);
        expect(result.isChallengeBound, isFalse);
        expect(result.displayTitle, equals('PASSPORT VALID'));
      });
    });
  });
}
