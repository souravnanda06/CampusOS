import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:attendance_app/student/models/passport_identity_model.dart';
import 'package:attendance_app/student/models/passport_presentation_model.dart';
import 'package:attendance_app/student/services/passport_crypto_service.dart';
import 'package:attendance_app/student/services/passport_presentation_service.dart';
import 'package:attendance_app/student/services/passport_identity_service.dart';

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

void main() {
  group('CampusOS Passport 1D — Dynamic Presentation & Rotating QR Tests', () {
    late FakePassportKeyStorage fakeStorage;
    late PassportCryptoService cryptoService;

    setUp(() {
      fakeStorage = FakePassportKeyStorage();
      cryptoService = PassportCryptoService(storage: fakeStorage);
    });

    test('1. Deterministic canonical JSON serialization has sorted keys and compact delimiters', () {
      final model = PassportPresentationModel(
        version: 1,
        type: 'PASSPORT_PRESENTATION',
        keyId: 'k-123',
        userId: 'u-456',
        certificateId: 'c-789',
        issuerKeyId: 'inst-1',
        issuedAt: 1700000000,
        expiresAt: 1700000030,
        nonce: 'abc-nonce-123',
      );

      final canonical = model.toCanonicalJson();
      const expected =
          '{"certificateId":"c-789","expiresAt":1700000030,"issuedAt":1700000000,"issuerKeyId":"inst-1","keyId":"k-123","nonce":"abc-nonce-123","type":"PASSPORT_PRESENTATION","userId":"u-456","version":1}';

      expect(canonical, equals(expected));
      expect(canonical.contains(' '), isFalse);
    });

    test('2. Signature generated and verified successfully with local Ed25519 key', () async {
      final pubKey = await cryptoService.getOrCreatePublicKey();
      final model = PassportPresentationModel(
        keyId: 'key-1',
        userId: 'user-1',
        certificateId: 'cert-1',
        issuerKeyId: 'inst-key-1',
        issuedAt: 1700000000,
        expiresAt: 1700000030,
        nonce: 'nonce-1',
      );

      final canonicalJson = model.toCanonicalJson();
      final signature = await cryptoService.signPresentation(canonicalJson);

      expect(signature, isNotEmpty);
      expect(base64Decode(signature).length, equals(64));

      final isValid = await cryptoService.verifySignature(
        publicKey: pubKey,
        challenge: canonicalJson,
        signature: signature,
      );
      expect(isValid, isTrue);
    });

    test('3. Changing any signed field invalidates the signature', () async {
      final pubKey = await cryptoService.getOrCreatePublicKey();
      final model = PassportPresentationModel(
        keyId: 'key-1',
        userId: 'user-1',
        certificateId: 'cert-1',
        issuerKeyId: 'inst-key-1',
        issuedAt: 1700000000,
        expiresAt: 1700000030,
        nonce: 'nonce-1',
      );

      final signature = await cryptoService.signPresentation(model.toCanonicalJson());

      // Alter user ID
      final tampered = PassportPresentationModel(
        keyId: 'key-1',
        userId: 'user-2', // Tampered!
        certificateId: 'cert-1',
        issuerKeyId: 'inst-key-1',
        issuedAt: 1700000000,
        expiresAt: 1700000030,
        nonce: 'nonce-1',
      );

      final isValid = await cryptoService.verifySignature(
        publicKey: pubKey,
        challenge: tampered.toCanonicalJson(),
        signature: signature,
      );
      expect(isValid, isFalse);
    });

    test('4. Changing nonce invalidates the signature', () async {
      final pubKey = await cryptoService.getOrCreatePublicKey();
      final model = PassportPresentationModel(
        keyId: 'key-1',
        userId: 'user-1',
        certificateId: 'cert-1',
        issuerKeyId: 'inst-key-1',
        issuedAt: 1700000000,
        expiresAt: 1700000030,
        nonce: 'nonce-1',
      );

      final signature = await cryptoService.signPresentation(model.toCanonicalJson());

      final tampered = PassportPresentationModel(
        keyId: 'key-1',
        userId: 'user-1',
        certificateId: 'cert-1',
        issuerKeyId: 'inst-key-1',
        issuedAt: 1700000000,
        expiresAt: 1700000030,
        nonce: 'nonce-different', // Tampered!
      );

      final isValid = await cryptoService.verifySignature(
        publicKey: pubKey,
        challenge: tampered.toCanonicalJson(),
        signature: signature,
      );
      expect(isValid, isFalse);
    });

    test('5. Changing expiry invalidates the signature', () async {
      final pubKey = await cryptoService.getOrCreatePublicKey();
      final model = PassportPresentationModel(
        keyId: 'key-1',
        userId: 'user-1',
        certificateId: 'cert-1',
        issuerKeyId: 'inst-key-1',
        issuedAt: 1700000000,
        expiresAt: 1700000030,
        nonce: 'nonce-1',
      );

      final signature = await cryptoService.signPresentation(model.toCanonicalJson());

      final tampered = PassportPresentationModel(
        keyId: 'key-1',
        userId: 'user-1',
        certificateId: 'cert-1',
        issuerKeyId: 'inst-key-1',
        issuedAt: 1700000000,
        expiresAt: 1700000999, // Tampered!
        nonce: 'nonce-1',
      );

      final isValid = await cryptoService.verifySignature(
        publicKey: pubKey,
        challenge: tampered.toCanonicalJson(),
        signature: signature,
      );
      expect(isValid, isFalse);
    });

    test('6. Expired presentation detected correctly', () {
      const nowSec = 1700000050;
      final model = PassportPresentationModel(
        keyId: 'k1',
        userId: 'u1',
        certificateId: 'c1',
        issuerKeyId: 'i1',
        issuedAt: 1700000000,
        expiresAt: 1700000030, // Expired 20s ago
        nonce: 'n1',
      );

      expect(model.isExpired(nowSec), isTrue);
      expect(model.remainingSeconds(nowSec), equals(0));
      expect(model.validityProgress(nowSec), equals(0.0));
    });

    test('7. Valid presentation detected correctly', () {
      const nowSec = 1700000015;
      final model = PassportPresentationModel(
        keyId: 'k1',
        userId: 'u1',
        certificateId: 'c1',
        issuerKeyId: 'i1',
        issuedAt: 1700000000,
        expiresAt: 1700000030, // 15s remaining
        nonce: 'n1',
      );

      expect(model.isExpired(nowSec), isFalse);
      expect(model.remainingSeconds(nowSec), equals(15));
      expect(model.validityProgress(nowSec), equals(0.5));
    });

    test('8. QR payload envelope contains no private key and no permanent public key', () {
      final model = PassportPresentationModel(
        keyId: 'k-uuid-1',
        userId: 'u-uuid-1',
        certificateId: 'c-uuid-1',
        issuerKeyId: 'inst-1',
        issuedAt: 1700000000,
        expiresAt: 1700000030,
        nonce: 'nonce-abc',
        signature: 'fake-sig',
      );

      final qrString = model.toQrPayload();
      expect(qrString.toLowerCase().contains('private'), isFalse);
      expect(qrString.contains('publicKey'), isFalse);
      expect(qrString.contains('version'), isTrue);
      expect(qrString.contains('PASSPORT_PRESENTATION'), isTrue);

      final parsed = PassportPresentationModel.fromQrPayload(qrString);
      expect(parsed.keyId, equals('k-uuid-1'));
      expect(parsed.signature, equals('fake-sig'));
      expect(parsed.nonce, equals('nonce-abc'));
    });

    test('9. PassportPresentationService generates presentation with active identity', () async {
      final pubKey = await cryptoService.getOrCreatePublicKey();

      final activeStatus = PassportEnrollmentStatus(
        enrolled: true,
        key: PassportIdentityKeyModel(
          id: 'key-uuid-1',
          userId: 'user-uuid-1',
          publicKey: pubKey,
          status: 'ACTIVE',
        ),
        certificate: PassportCertificateModel(
          id: 'cert-uuid-1',
          keyId: 'key-uuid-1',
          issuerKeyId: 'inst-key-1',
          userId: 'user-uuid-1',
          publicKey: pubKey,
          validFrom: DateTime.now().subtract(const Duration(days: 1)),
          validTo: DateTime.now().add(const Duration(days: 30)),
          signature: 'cert-sig',
          status: 'ACTIVE',
          payload: {},
        ),
      );

      final fakeIdentityService = FakePassportIdentityService(activeStatus);
      final presentationService = PassportPresentationService(
        cryptoService: cryptoService,
        identityService: fakeIdentityService,
      );

      final pres = await presentationService.createPresentation();

      expect(pres.keyId, equals('key-uuid-1'));
      expect(pres.userId, equals('user-uuid-1'));
      expect(pres.certificateId, equals('cert-uuid-1'));
      expect(pres.signature, isNotEmpty);
      expect(pres.nonce, isNotEmpty);
      expect(pres.isExpired(), isFalse);

      // Verify the signature is valid using public key
      final isValid = await cryptoService.verifySignature(
        publicKey: pubKey,
        challenge: pres.toCanonicalJson(),
        signature: pres.signature,
      );
      expect(isValid, isTrue);
    });

    test('10. New rotation produces different nonce and signature while identity key stays identical', () async {
      final pubKey = await cryptoService.getOrCreatePublicKey();

      final activeStatus = PassportEnrollmentStatus(
        enrolled: true,
        key: PassportIdentityKeyModel(
          id: 'key-uuid-1',
          userId: 'user-uuid-1',
          publicKey: pubKey,
          status: 'ACTIVE',
        ),
        certificate: PassportCertificateModel(
          id: 'cert-uuid-1',
          keyId: 'key-uuid-1',
          issuerKeyId: 'inst-key-1',
          userId: 'user-uuid-1',
          publicKey: pubKey,
          validFrom: DateTime.now().subtract(const Duration(days: 1)),
          validTo: DateTime.now().add(const Duration(days: 30)),
          signature: 'cert-sig',
          status: 'ACTIVE',
          payload: {},
        ),
      );

      final fakeIdentityService = FakePassportIdentityService(activeStatus);
      final presentationService = PassportPresentationService(
        cryptoService: cryptoService,
        identityService: fakeIdentityService,
      );

      final pres1 = await presentationService.createPresentation();
      final pres2 = await presentationService.createPresentation();

      // Nonces and signatures must differ across rotations
      expect(pres1.nonce, isNot(equals(pres2.nonce)));
      expect(pres1.signature, isNot(equals(pres2.signature)));

      // Underlying keyId and public key stay identical
      expect(pres1.keyId, equals(pres2.keyId));
      final currentPubKey = await cryptoService.getPublicKeyBase64();
      expect(currentPubKey, equals(pubKey));
    });

    test('11. Unenrolled identity throws PassportNotEnrolledException', () async {
      await cryptoService.getOrCreatePublicKey();

      final unenrolledStatus = PassportEnrollmentStatus(enrolled: false);
      final fakeIdentityService = FakePassportIdentityService(unenrolledStatus);
      final presentationService = PassportPresentationService(
        cryptoService: cryptoService,
        identityService: fakeIdentityService,
      );

      expect(
        () => presentationService.createPresentation(),
        throwsA(isA<PassportNotEnrolledException>()),
      );
    });

    test('12. Revoked key throws PassportIdentityInactiveException', () async {
      final pubKey = await cryptoService.getOrCreatePublicKey();

      final revokedStatus = PassportEnrollmentStatus(
        enrolled: true,
        key: PassportIdentityKeyModel(
          id: 'key-uuid-1',
          userId: 'user-uuid-1',
          publicKey: pubKey,
          status: 'REVOKED', // REVOKED!
        ),
        certificate: PassportCertificateModel(
          id: 'cert-uuid-1',
          keyId: 'key-uuid-1',
          issuerKeyId: 'inst-key-1',
          userId: 'user-uuid-1',
          publicKey: pubKey,
          validFrom: DateTime.now().subtract(const Duration(days: 1)),
          validTo: DateTime.now().add(const Duration(days: 30)),
          signature: 'cert-sig',
          status: 'REVOKED',
          payload: {},
        ),
      );

      final fakeIdentityService = FakePassportIdentityService(revokedStatus);
      final presentationService = PassportPresentationService(
        cryptoService: cryptoService,
        identityService: fakeIdentityService,
      );

      expect(
        () => presentationService.createPresentation(),
        throwsA(isA<PassportIdentityInactiveException>()),
      );
    });

    test('13. Missing local key throws PassportKeyMissingException', () async {
      // Storage has no key saved
      final emptyCrypto = PassportCryptoService(storage: FakePassportKeyStorage());

      final activeStatus = PassportEnrollmentStatus(
        enrolled: true,
        key: PassportIdentityKeyModel(
          id: 'key-uuid-1',
          userId: 'user-uuid-1',
          publicKey: 'some-pub-key',
          status: 'ACTIVE',
        ),
        certificate: PassportCertificateModel(
          id: 'cert-uuid-1',
          keyId: 'key-uuid-1',
          issuerKeyId: 'inst-key-1',
          userId: 'user-uuid-1',
          publicKey: 'some-pub-key',
          validFrom: DateTime.now().subtract(const Duration(days: 1)),
          validTo: DateTime.now().add(const Duration(days: 30)),
          signature: 'cert-sig',
          status: 'ACTIVE',
          payload: {},
        ),
      );

      final fakeIdentityService = FakePassportIdentityService(activeStatus);
      final presentationService = PassportPresentationService(
        cryptoService: emptyCrypto,
        identityService: fakeIdentityService,
      );

      expect(
        () => presentationService.createPresentation(),
        throwsA(isA<PassportKeyMissingException>()),
      );
    });

    test('14. Mismatched local key throws PassportKeyMismatchException', () async {
      // Local key has key A
      await cryptoService.getOrCreatePublicKey();

      // Backend says key B is enrolled
      final activeStatus = PassportEnrollmentStatus(
        enrolled: true,
        key: PassportIdentityKeyModel(
          id: 'key-uuid-1',
          userId: 'user-uuid-1',
          publicKey: 'different-registered-public-key-32b=',
          status: 'ACTIVE',
        ),
        certificate: PassportCertificateModel(
          id: 'cert-uuid-1',
          keyId: 'key-uuid-1',
          issuerKeyId: 'inst-key-1',
          userId: 'user-uuid-1',
          publicKey: 'different-registered-public-key-32b=',
          validFrom: DateTime.now().subtract(const Duration(days: 1)),
          validTo: DateTime.now().add(const Duration(days: 30)),
          signature: 'cert-sig',
          status: 'ACTIVE',
          payload: {},
        ),
      );

      final fakeIdentityService = FakePassportIdentityService(activeStatus);
      final presentationService = PassportPresentationService(
        cryptoService: cryptoService,
        identityService: fakeIdentityService,
      );

      expect(
        () => presentationService.createPresentation(),
        throwsA(isA<PassportKeyMismatchException>()),
      );
    });
  });
}
