import 'dart:convert';
import 'package:cryptography/cryptography.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Exceptions originating from Passport cryptographic operations.
class PassportCryptoException implements Exception {
  final String message;
  PassportCryptoException(this.message);

  @override
  String toString() => 'PassportCryptoException: $message';
}

/// Exceptions originating from secure key storage operations.
class PassportKeyStorageException implements Exception {
  final String message;
  PassportKeyStorageException(this.message);

  @override
  String toString() => 'PassportKeyStorageException: $message';
}

/// Abstract contract for secure key storage.
///
/// In production, uses [SecurePassportKeyStorage] backed by [FlutterSecureStorage]
/// with Android Keystore / EncryptedSharedPreferences.
/// In unit tests, an in-memory fake can be injected.
abstract class PassportKeyStorage {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
  Future<void> delete(String key);
  Future<bool> containsKey(String key);
}

/// Production implementation of [PassportKeyStorage] using [FlutterSecureStorage]
/// with hardware-backed Android Keystore / EncryptedSharedPreferences enabled.
class SecurePassportKeyStorage implements PassportKeyStorage {
  final FlutterSecureStorage _storage;

  SecurePassportKeyStorage({FlutterSecureStorage? storage})
      : _storage = storage ??
            const FlutterSecureStorage(
              aOptions: AndroidOptions(
                resetOnError: true,
              ),
              iOptions: IOSOptions(
                accessibility: KeychainAccessibility.first_unlock,
              ),
            );

  @override
  Future<String?> read(String key) async {
    try {
      return await _storage
          .read(key: key)
          .timeout(const Duration(milliseconds: 300), onTimeout: () => null);
    } catch (e) {
      debugPrint('⚠️ [SECURE_STORAGE] Read exception for $key: $e');
      throw PassportKeyStorageException('Failed to read from secure storage');
    }
  }

  @override
  Future<void> write(String key, String value) async {
    try {
      await _storage.write(key: key, value: value);
    } catch (e) {
      debugPrint('⚠️ [SECURE_STORAGE] Write exception for $key: $e');
      throw PassportKeyStorageException('Failed to write to secure storage');
    }
  }

  @override
  Future<void> delete(String key) async {
    try {
      await _storage.delete(key: key);
    } catch (e) {
      debugPrint('⚠️ [SECURE_STORAGE] Delete exception for $key: $e');
      throw PassportKeyStorageException('Failed to delete from secure storage');
    }
  }

  @override
  Future<bool> containsKey(String key) async {
    try {
      return await _storage.containsKey(key: key);
    } catch (e) {
      debugPrint('⚠️ [SECURE_STORAGE] ContainsKey exception for $key: $e');
      throw PassportKeyStorageException('Failed to query secure storage');
    }
  }
}

/// CampusOS Passport Cryptographic Service (Phase 1B).
///
/// Responsible for:
/// 1. Generating and securely storing a device-bound Ed25519 identity keypair.
/// 2. Ensuring the private key NEVER leaves the local secure keystore.
/// 3. Providing deterministic Base64-encoded signing and verification operations.
///
/// Encoding Standards:
/// - Public Key: Deterministic standard Base64 encoding of the raw 32-byte Ed25519 public key.
/// - Signature: Deterministic standard Base64 encoding of the raw 64-byte Ed25519 signature.
/// - Challenge: Arbitrary UTF-8 string encoded to bytes prior to signing.
class PassportCryptoService {
  static const String privateKeyStorageKey = 'campus_os.passport.private_key';
  static const String publicKeyStorageKey = 'campus_os.passport.public_key';

  final PassportKeyStorage _storage;
  final Ed25519 _algorithm;

  SimpleKeyPair? _cachedKeyPair;
  SimplePublicKey? _cachedPublicKey;

  PassportCryptoService({
    PassportKeyStorage? storage,
    Ed25519? algorithm,
  })  : _storage = storage ?? SecurePassportKeyStorage(),
        _algorithm = algorithm ?? Ed25519();

  /// Returns the underlying storage implementation
  PassportKeyStorage get storage => _storage;

  /// Initializes the service by attempting to restore an existing identity key from storage.
  Future<void> initialize() async {
    try {
      final storedPrivateKey = await _storage.read(privateKeyStorageKey);
      if (storedPrivateKey != null && storedPrivateKey.isNotEmpty) {
        final privateKeyBytes = base64Decode(storedPrivateKey);
        if (privateKeyBytes.length == 32) {
          final keyPair = await _algorithm.newKeyPairFromSeed(privateKeyBytes);
          final pubKey = await keyPair.extractPublicKey();
          _cachedKeyPair = keyPair;
          _cachedPublicKey = pubKey;
          debugPrint('🔒 [PASSPORT_CRYPTO] Existing identity key loaded successfully.');
          return;
        }
      }
      _cachedKeyPair = null;
      _cachedPublicKey = null;
    } catch (e) {
      _cachedKeyPair = null;
      _cachedPublicKey = null;
      if (e is PassportKeyStorageException) rethrow;
      throw PassportCryptoException('Failed to initialize Passport identity key: $e');
    }
  }

  /// Checks whether a local device identity key exists in storage or memory.
  Future<bool> hasIdentityKey() async {
    if (_cachedKeyPair != null) return true;
    try {
      await initialize();
      return _cachedKeyPair != null;
    } catch (_) {
      return false;
    }
  }

  /// Returns the existing Ed25519 public key in Base64 format if one exists, or null.
  Future<String?> getPublicKeyBase64() async {
    if (_cachedPublicKey != null) {
      return base64Encode(_cachedPublicKey!.bytes);
    }
    await initialize();
    if (_cachedPublicKey != null) {
      return base64Encode(_cachedPublicKey!.bytes);
    }
    return null;
  }

  /// Retrieves the existing Ed25519 public key in Base64 format,
  /// or generates a new keypair and securely saves it if none exists.
  ///
  /// Repeated calls on an established identity are idempotent and return the exact same public key.
  Future<String> getOrCreatePublicKey() async {
    if (_cachedPublicKey != null) {
      return base64Encode(_cachedPublicKey!.bytes);
    }

    // Try loading from storage first
    await initialize();
    if (_cachedPublicKey != null) {
      return base64Encode(_cachedPublicKey!.bytes);
    }

    // Generate new Ed25519 keypair
    try {
      final newKeyPair = await _algorithm.newKeyPair();
      final privateKeyBytes = await newKeyPair.extractPrivateKeyBytes();
      final publicKey = await newKeyPair.extractPublicKey();

      if (privateKeyBytes.length != 32 || publicKey.bytes.length != 32) {
        throw PassportCryptoException('Invalid key length generated by Ed25519 algorithm');
      }

      final privBase64 = base64Encode(privateKeyBytes);
      final pubBase64 = base64Encode(publicKey.bytes);

      // Securely store private key (and public key cache)
      await _storage.write(privateKeyStorageKey, privBase64);
      await _storage.write(publicKeyStorageKey, pubBase64);

      _cachedKeyPair = newKeyPair;
      _cachedPublicKey = publicKey;

      debugPrint('🔒 [PASSPORT_CRYPTO] New device identity keypair generated and stored securely.');
      return pubBase64;
    } catch (e) {
      if (e is PassportKeyStorageException || e is PassportCryptoException) rethrow;
      throw PassportCryptoException('Failed to generate Ed25519 identity keypair: $e');
    }
  }

  /// Signs an arbitrary UTF-8 challenge string using the local private key.
  ///
  /// Returns standard Base64-encoded 64-byte Ed25519 signature.
  Future<String> signChallenge(String challenge) async {
    if (_cachedKeyPair == null) {
      await initialize();
      if (_cachedKeyPair == null) {
        try {
          await getOrCreatePublicKey();
        } catch (_) {}
      }
      if (_cachedKeyPair == null) {
        throw PassportCryptoException(
            'Cannot sign challenge: No identity key found. Call getOrCreatePublicKey() first.');
      }
    }

    try {
      final challengeBytes = utf8.encode(challenge);
      final signature = await _algorithm.sign(
        challengeBytes,
        keyPair: _cachedKeyPair!,
      );

      debugPrint('🔒 [PASSPORT_CRYPTO] Challenge signed successfully.');
      return base64Encode(signature.bytes);
    } catch (e) {
      debugPrint('❌ [PASSPORT_CRYPTO] Challenge signing failed.');
      throw PassportCryptoException('Signing failed: ${e.toString()}');
    }
  }

  /// Signs raw canonical bytes using the local Ed25519 private key.
  ///
  /// Returns standard Base64-encoded 64-byte Ed25519 signature.
  Future<String> signCanonicalBytes(List<int> bytes) async {
    if (_cachedKeyPair == null) {
      await initialize();
      if (_cachedKeyPair == null) {
        try {
          await getOrCreatePublicKey();
        } catch (_) {}
      }
      if (_cachedKeyPair == null) {
        throw PassportCryptoException(
            'Cannot sign presentation: No identity key found. Call getOrCreatePublicKey() first.');
      }
    }

    try {
      final signature = await _algorithm.sign(
        bytes,
        keyPair: _cachedKeyPair!,
      );
      return base64Encode(signature.bytes);
    } catch (e) {
      throw PassportCryptoException('Presentation signing failed: ${e.toString()}');
    }
  }

  /// Signs a canonical presentation JSON string using the local Ed25519 private key.
  Future<String> signPresentation(String canonicalJson) async {
    return signCanonicalBytes(utf8.encode(canonicalJson));
  }

  /// Verifies an Ed25519 signature against a public key and challenge string.
  ///
  /// Returns `true` if valid, `false` otherwise. Does not throw for mismatched signatures or malformed inputs.
  Future<bool> verifySignature({
    required String publicKey,
    required String challenge,
    required String signature,
  }) async {
    try {
      final pubBytes = base64Decode(publicKey.trim());
      if (pubBytes.length != 32) {
        return false;
      }

      final sigBytes = base64Decode(signature.trim());
      if (sigBytes.length != 64) {
        return false;
      }

      final challengeBytes = utf8.encode(challenge);
      final simplePubKey = SimplePublicKey(pubBytes, type: KeyPairType.ed25519);
      final sigObject = Signature(sigBytes, publicKey: simplePubKey);

      final isValid = await _algorithm.verify(
        challengeBytes,
        signature: sigObject,
      );

      return isValid;
    } catch (e) {
      // Malformed Base64 or corrupted data results in graceful verification failure
      return false;
    }
  }

  /// Permanently removes the local identity keypair from secure storage.
  ///
  /// WARNING: This is a destructive operation. After clearing, subsequent
  /// calls to [getOrCreatePublicKey] will generate a completely NEW identity keypair.
  Future<void> clearIdentityKey() async {
    try {
      await _storage.delete(privateKeyStorageKey);
      await _storage.delete(publicKeyStorageKey);
      _cachedKeyPair = null;
      _cachedPublicKey = null;
      debugPrint('🔒 [PASSPORT_CRYPTO] Local identity keypair cleared.');
    } catch (e) {
      throw PassportKeyStorageException('Failed to clear identity key from secure storage');
    }
  }
}
