import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:attendance_app/student/services/passport_crypto_service.dart';

/// In-memory implementation of [PassportKeyStorage] for deterministic headless unit tests.
class InMemoryPassportKeyStorage implements PassportKeyStorage {
  final Map<String, String> _data = {};

  @override
  Future<String?> read(String key) async => _data[key];

  @override
  Future<void> write(String key, String value) async => _data[key] = value;

  @override
  Future<void> delete(String key) async => _data.remove(key);

  @override
  Future<bool> containsKey(String key) async => _data.containsKey(key);

  void clear() => _data.clear();
}

void main() {
  group('CampusOS Passport Phase 1B: Cryptographic Foundation & Key Storage', () {
    late InMemoryPassportKeyStorage storage;
    late PassportCryptoService cryptoService;

    setUp(() {
      storage = InMemoryPassportKeyStorage();
      cryptoService = PassportCryptoService(storage: storage);
    });

    test('TEST 1: Generate keypair successfully', () async {
      expect(await cryptoService.hasIdentityKey(), isFalse);

      final publicKey = await cryptoService.getOrCreatePublicKey();

      expect(publicKey, isNotEmpty);
      expect(await cryptoService.hasIdentityKey(), isTrue);
    });

    test('TEST 2: Generated public key has the expected Ed25519 representation/length', () async {
      final publicKeyBase64 = await cryptoService.getOrCreatePublicKey();
      final pubKeyBytes = base64Decode(publicKeyBase64);

      // Ed25519 raw public key is exactly 32 bytes (256 bits)
      expect(pubKeyBytes.length, equals(32));
      // Base64 encoding of 32 bytes is 44 characters (with single '=' padding)
      expect(publicKeyBase64.length, equals(44));
      expect(publicKeyBase64.endsWith('='), isTrue);
    });

    test('TEST 3: Repeated getOrCreatePublicKey returns the same key', () async {
      final key1 = await cryptoService.getOrCreatePublicKey();
      final key2 = await cryptoService.getOrCreatePublicKey();
      final key3 = await cryptoService.getOrCreatePublicKey();

      expect(key1, equals(key2));
      expect(key2, equals(key3));
    });

    test('TEST 4: Private key survives service reinitialization', () async {
      final initialPubKey = await cryptoService.getOrCreatePublicKey();

      // Create a new instance pointing to the exact same underlying storage
      final reloadedService = PassportCryptoService(storage: storage);
      await reloadedService.initialize();

      expect(await reloadedService.hasIdentityKey(), isTrue);
      final reloadedPubKey = await reloadedService.getOrCreatePublicKey();

      expect(reloadedPubKey, equals(initialPubKey));
    });

    test('TEST 5: Sign challenge successfully', () async {
      await cryptoService.getOrCreatePublicKey();

      const challenge = 'CAMPUS_OS_CHALLENGE_NONCE_789456123';
      final signature = await cryptoService.signChallenge(challenge);

      expect(signature, isNotEmpty);
      final sigBytes = base64Decode(signature);
      // Ed25519 signature is exactly 64 bytes (512 bits)
      expect(sigBytes.length, equals(64));
      // Base64 encoding of 64 bytes is 88 characters (with single '=' padding)
      expect(signature.length, equals(88));
    });

    test('TEST 6: Valid signature verifies', () async {
      final pubKey = await cryptoService.getOrCreatePublicKey();
      const challenge = 'CAMPUS_OS_CHALLENGE_SESSION_ATTENDANCE';

      final signature = await cryptoService.signChallenge(challenge);

      final isValid = await cryptoService.verifySignature(
        publicKey: pubKey,
        challenge: challenge,
        signature: signature,
      );

      expect(isValid, isTrue);
    });

    test('TEST 7: Modified challenge fails verification', () async {
      final pubKey = await cryptoService.getOrCreatePublicKey();
      const originalChallenge = 'ORIGINAL_ATTENDANCE_NONCE';
      const tamperedChallenge = 'TAMPERED_ATTENDANCE_NONCE';

      final signature = await cryptoService.signChallenge(originalChallenge);

      final isValid = await cryptoService.verifySignature(
        publicKey: pubKey,
        challenge: tamperedChallenge,
        signature: signature,
      );

      expect(isValid, isFalse);
    });

    test('TEST 8: Modified signature fails verification', () async {
      final pubKey = await cryptoService.getOrCreatePublicKey();
      const challenge = 'GATE_PASS_CHALLENGE_9999';

      final signature = await cryptoService.signChallenge(challenge);

      // Flip byte inside the signature
      final sigBytes = base64Decode(signature);
      sigBytes[0] ^= 0xFF; // Invert first byte
      final tamperedSig = base64Encode(sigBytes);

      final isValid = await cryptoService.verifySignature(
        publicKey: pubKey,
        challenge: challenge,
        signature: tamperedSig,
      );

      expect(isValid, isFalse);
    });

    test('TEST 9: Different public key fails verification', () async {
      // First keypair
      await cryptoService.getOrCreatePublicKey();
      const challenge = 'VERIFY_WRONG_PUBLIC_KEY_NONCE';
      final signature = await cryptoService.signChallenge(challenge);

      // Generate a completely different secondary keypair
      final secondStorage = InMemoryPassportKeyStorage();
      final secondService = PassportCryptoService(storage: secondStorage);
      final secondPubKey = await secondService.getOrCreatePublicKey();

      final isValid = await cryptoService.verifySignature(
        publicKey: secondPubKey,
        challenge: challenge,
        signature: signature,
      );

      expect(isValid, isFalse);
    });

    test('TEST 10: clearIdentityKey removes local identity', () async {
      await cryptoService.getOrCreatePublicKey();
      expect(await cryptoService.hasIdentityKey(), isTrue);

      await cryptoService.clearIdentityKey();

      expect(await cryptoService.hasIdentityKey(), isFalse);
      expect(await storage.containsKey(PassportCryptoService.privateKeyStorageKey), isFalse);
      expect(await storage.containsKey(PassportCryptoService.publicKeyStorageKey), isFalse);
    });

    test('TEST 11: After clearing, a new keypair is generated', () async {
      final firstPubKey = await cryptoService.getOrCreatePublicKey();
      await cryptoService.clearIdentityKey();

      final secondPubKey = await cryptoService.getOrCreatePublicKey();

      expect(secondPubKey, isNot(equals(firstPubKey)));
      expect(await cryptoService.hasIdentityKey(), isTrue);
    });

    test('TEST 12: Private key never appears in service return values intended for backend transmission', () async {
      final pubKey = await cryptoService.getOrCreatePublicKey();
      const challenge = 'SECURITY_AUDIT_CHALLENGE';
      final signature = await cryptoService.signChallenge(challenge);

      final storedPrivKey = await storage.read(PassportCryptoService.privateKeyStorageKey);
      expect(storedPrivKey, isNotNull);

      // The public key must NOT match or contain the private key
      expect(pubKey, isNot(equals(storedPrivKey)));
      expect(pubKey.contains(storedPrivKey!), isFalse);

      // The signature must NOT match or contain the private key
      expect(signature, isNot(equals(storedPrivKey)));
      expect(signature.contains(storedPrivKey), isFalse);

      // Raw private key bytes must never equal raw public key bytes
      final privBytes = base64Decode(storedPrivKey);
      final pubBytes = base64Decode(pubKey);
      expect(privBytes, isNot(equals(pubBytes)));
    });

    test('TEST 13: Signing without initialized key throws PassportCryptoException', () async {
      expect(
        () => cryptoService.signChallenge('ANY_CHALLENGE'),
        throwsA(isA<PassportCryptoException>()),
      );
    });

    test('TEST 14: Malformed verification arguments return false without crashing', () async {
      expect(
        await cryptoService.verifySignature(
          publicKey: 'not-base-64!@#',
          challenge: 'test',
          signature: 'invalid-sig',
        ),
        isFalse,
      );

      expect(
        await cryptoService.verifySignature(
          publicKey: base64Encode(List.filled(16, 0)), // Too short (16 bytes vs 32)
          challenge: 'test',
          signature: base64Encode(List.filled(64, 0)),
        ),
        isFalse,
      );
    });
  });
}
