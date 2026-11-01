import 'dart:convert';
import 'package:cryptography/cryptography.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:attendance_app/student/models/passport_trust_bundle_model.dart';
import 'package:attendance_app/student/services/passport_crypto_service.dart';
import 'package:attendance_app/student/services/passport_trust_bundle_service.dart';

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

  group('CampusOS Passport 1F: Trust Bundle Model & Service Tests', () {
    late PassportCryptoService cryptoService;
    late FakePassportKeyStorage keyStorage;
    late SimpleKeyPair institutionKeyPair;
    late String institutionPubB64;

    setUp(() async {
      keyStorage = FakePassportKeyStorage();
      cryptoService = PassportCryptoService(storage: keyStorage);
      await cryptoService.initialize();

      // Generate in-memory institution root keypair for tests
      final ed25519 = Ed25519();
      institutionKeyPair = await ed25519.newKeyPair();
      final pubKey = await institutionKeyPair.extractPublicKey();
      institutionPubB64 = base64Encode(pubKey.bytes);
    });

    test('1. Canonical JSON deterministic serialization matches rules', () {
      final sample = {
        'version': 1,
        'issuerKeyId': 'inst-1',
        'identities': [
          {'keyId': 'k2', 'userId': 'u2'},
          {'keyId': 'k1', 'userId': 'u1'},
        ],
        'institution': {
          'publicKey': 'pub-key-1',
          'keyId': 'inst-1',
        },
      };

      final c1 = canonicalizeJson(sample);
      final c2 = canonicalizeJson(sample);

      expect(c1, equals(c2));
      // Top level keys are alphabetically ordered
      expect(c1.indexOf('"identities"'), lessThan(c1.indexOf('"institution"')));
      expect(c1.indexOf('"institution"'), lessThan(c1.indexOf('"issuerKeyId"')));
      expect(c1.indexOf('"issuerKeyId"'), lessThan(c1.indexOf('"version"')));
      // Nested map keys are alphabetically ordered
      expect(c1.indexOf('"keyId"'), lessThan(c1.indexOf('"publicKey"')));
    });

    test('2. Trust bundle parsing, serialization, and identity lookup', () async {
      final now = DateTime.now().toUtc().millisecondsSinceEpoch ~/ 1000;
      final bundle = PassportTrustBundle(
        version: 1,
        issuerKeyId: 'campusos-root-2026-v1',
        generatedAt: now - 100,
        expiresAt: now + 3600,
        institution: PassportInstitutionTrust(
          keyId: 'campusos-root-2026-v1',
          publicKey: institutionPubB64,
        ),
        identities: [
          PassportTrustIdentity(
            keyId: 'key-student-42',
            userId: 'student-42',
            publicKey: 'dummy_pub_b64',
            certificateId: 'cert-student-42',
            issuerKeyId: 'campusos-root-2026-v1',
            validFrom: now - 1000,
            validTo: now + 100000,
            status: 'ACTIVE',
            userName: 'Sourav Nanda',
          ),
        ],
        revokedKeyIds: ['revoked-key-99'],
        signature: 'dummy_signature',
        rawPayload: {},
      );

      final jsonMap = bundle.toJson();
      final parsed = PassportTrustBundle.fromJson(jsonMap);

      expect(parsed.version, equals(1));
      expect(parsed.issuerKeyId, equals('campusos-root-2026-v1'));
      expect(parsed.isExpired(), isFalse);
      expect(parsed.remainingValiditySeconds(), greaterThan(3500));

      final id = parsed.findIdentity('key-student-42');
      expect(id, isNotNull);
      expect(id!.userName, equals('Sourav Nanda'));
      expect(id.isValidAt(now), isTrue);

      expect(parsed.isKeyRevoked('revoked-key-99'), isTrue);
      expect(parsed.isKeyRevoked('key-student-42'), isFalse);
    });

    test('3. Cryptographic signature creation and verification on bundle', () async {
      final now = DateTime.now().toUtc().millisecondsSinceEpoch ~/ 1000;
      final payloadMap = {
        'version': 1,
        'issuerKeyId': 'campusos-root-2026-v1',
        'generatedAt': now,
        'expiresAt': now + 86400,
        'institution': {
          'keyId': 'campusos-root-2026-v1',
          'publicKey': institutionPubB64,
        },
        'identities': [
          {
            'certificateId': 'cert-1',
            'issuerKeyId': 'campusos-root-2026-v1',
            'keyId': 'key-1',
            'publicKey': institutionPubB64,
            'status': 'ACTIVE',
            'userId': 'user-1',
            'validFrom': now - 1000,
            'validTo': now + 86400,
          }
        ],
        'revokedKeyIds': <String>[],
      };

      final canonicalJson = canonicalizeJson(payloadMap);
      final ed25519 = Ed25519();
      final sig = await ed25519.sign(utf8.encode(canonicalJson), keyPair: institutionKeyPair);
      final sigB64 = base64Encode(sig.bytes);

      final bundle = PassportTrustBundle.fromJson({
        'payload': payloadMap,
        'signature': sigB64,
      });

      final service = PassportTrustBundleService(
        storage: keyStorage,
        cryptoService: cryptoService,
      );

      final isValid = await service.verifyBundleIntegrity(bundle);
      expect(isValid, isTrue);

      // Tampered bundle check
      final tamperedMap = jsonDecode(jsonEncode(payloadMap)) as Map<String, dynamic>;
      tamperedMap['version'] = 2; // altered version
      final tamperedBundle = PassportTrustBundle.fromJson({
        'payload': tamperedMap,
        'signature': sigB64,
      });

      final isTamperedValid = await service.verifyBundleIntegrity(tamperedBundle);
      expect(isTamperedValid, isFalse);
    });

    test('4. Bundle expiration checks', () {
      const now = 1774480000;
      const activeBundle = PassportTrustBundle(
        version: 1,
        issuerKeyId: 'inst-1',
        generatedAt: now - 3600,
        expiresAt: now + 3600,
        institution: PassportInstitutionTrust(keyId: 'inst-1', publicKey: 'pk'),
        identities: [],
        revokedKeyIds: [],
        signature: 'sig',
        rawPayload: {},
      );

      expect(activeBundle.isExpired(now), isFalse);
      expect(activeBundle.remainingValiditySeconds(now), equals(3600));

      const expiredBundle = PassportTrustBundle(
        version: 1,
        issuerKeyId: 'inst-1',
        generatedAt: now - 7200,
        expiresAt: now - 10,
        institution: PassportInstitutionTrust(keyId: 'inst-1', publicKey: 'pk'),
        identities: [],
        revokedKeyIds: [],
        signature: 'sig',
        rawPayload: {},
      );

      expect(expiredBundle.isExpired(now), isTrue);
      expect(expiredBundle.remainingValiditySeconds(now), equals(0));
    });

    test('5. Service status mapping (fresh, expiringSoon, expired, missing)', () {
      final service = PassportTrustBundleService(storage: keyStorage);
      expect(service.getBundleStatus(null), equals(TrustBundleStatus.missing));

      const now = 1774480000;
      const freshBundle = PassportTrustBundle(
        version: 1,
        issuerKeyId: 'inst-1',
        generatedAt: now - 100,
        expiresAt: now + 10000,
        institution: PassportInstitutionTrust(keyId: 'inst-1', publicKey: 'pk'),
        identities: [],
        revokedKeyIds: [],
        signature: 'sig',
        rawPayload: {},
      );
      expect(service.getBundleStatus(freshBundle, now), equals(TrustBundleStatus.fresh));

      const expiringSoonBundle = PassportTrustBundle(
        version: 1,
        issuerKeyId: 'inst-1',
        generatedAt: now - 100,
        expiresAt: now + 1800, // 30 minutes left (< 3600)
        institution: PassportInstitutionTrust(keyId: 'inst-1', publicKey: 'pk'),
        identities: [],
        revokedKeyIds: [],
        signature: 'sig',
        rawPayload: {},
      );
      expect(service.getBundleStatus(expiringSoonBundle, now), equals(TrustBundleStatus.expiringSoon));

      const expiredBundle = PassportTrustBundle(
        version: 1,
        issuerKeyId: 'inst-1',
        generatedAt: now - 100,
        expiresAt: now - 1,
        institution: PassportInstitutionTrust(keyId: 'inst-1', publicKey: 'pk'),
        identities: [],
        revokedKeyIds: [],
        signature: 'sig',
        rawPayload: {},
      );
      expect(service.getBundleStatus(expiredBundle, now), equals(TrustBundleStatus.expired));
    });
  });
}
