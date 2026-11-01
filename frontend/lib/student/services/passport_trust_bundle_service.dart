import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../../core/network/api_client.dart';
import '../models/passport_trust_bundle_model.dart';
import 'passport_crypto_service.dart';

/// Operational status of the local trust bundle.
enum TrustBundleStatus {
  fresh,
  expiringSoon,
  expired,
  missing,
}

/// Exception originating from trust bundle operations.
class PassportTrustBundleException implements Exception {
  final String message;
  PassportTrustBundleException(this.message);

  @override
  String toString() => 'PassportTrustBundleException: $message';
}

/// CampusOS Passport Trust Bundle Service (Phase 1F).
///
/// Responsibilities:
/// 1. Synchronizing signed trust bundles from backend `/passport/trust-bundle`.
/// 2. Cryptographically authenticating the bundle signature using the institution public key.
/// 3. Securely caching the validated bundle in local persistent storage.
/// 4. Providing fast in-memory access and keyId lookups for offline QR verification.
/// 5. Monitoring bundle freshness and expiration.
class PassportTrustBundleService {
  static const String trustBundleStorageKey = 'campus_os.passport.trust_bundle';
  static const String defaultInstitutionKeyId = 'campusos-root-2026-v1';

  final ApiClient _apiClient;
  final PassportKeyStorage _storage;
  final PassportCryptoService _cryptoService;

  PassportTrustBundle? _cachedBundle;

  PassportTrustBundleService({
    ApiClient? apiClient,
    PassportKeyStorage? storage,
    PassportCryptoService? cryptoService,
  })  : _apiClient = apiClient ?? ApiClient.instance,
        _storage = storage ?? SecurePassportKeyStorage(),
        _cryptoService = cryptoService ?? PassportCryptoService(storage: storage);

  /// Retrieves the current locally cached trust bundle.
  /// Uses in-memory cache if available, otherwise loads from persistent storage.
  Future<PassportTrustBundle?> getLocalBundle() async {
    if (_cachedBundle != null) {
      return _cachedBundle;
    }

    try {
      final raw = await _storage.read(trustBundleStorageKey);
      if (raw == null || raw.isEmpty) {
        return null;
      }

      final jsonMap = jsonDecode(raw) as Map<String, dynamic>;
      final bundle = PassportTrustBundle.fromJson(jsonMap);

      // Verify cryptographic signature integrity on cold load
      final isValid = await verifyBundleIntegrity(bundle);
      if (!isValid) {
        debugPrint('⚠️ [TRUST_BUNDLE] Local bundle failed integrity verification. Clearing corrupt cache.');
        await clearLocalBundle();
        return null;
      }

      _cachedBundle = bundle;
      return bundle;
    } catch (e) {
      debugPrint('⚠️ [TRUST_BUNDLE] Error reading local bundle: $e');
      return null;
    }
  }

  /// Checks if a valid, unexpired trust bundle exists locally.
  Future<bool> hasValidLocalBundle([int? currentTimestampSeconds]) async {
    final bundle = await getLocalBundle();
    if (bundle == null) return false;
    return !bundle.isExpired(currentTimestampSeconds);
  }

  /// Downloads a fresh signed trust bundle from `/passport/trust-bundle`, verifies
  /// its institutional signature, and persists it locally.
  Future<PassportTrustBundle> downloadAndSaveBundle({int? ttlSeconds}) async {
    final queryParams = ttlSeconds != null ? '?ttlSeconds=$ttlSeconds' : '';
    final response = await _apiClient.get('/passport/trust-bundle$queryParams');

    if (response.statusCode != 200) {
      Map<String, dynamic>? errBody;
      try {
        errBody = jsonDecode(response.body) as Map<String, dynamic>?;
      } catch (_) {}
      final msg = errBody?['message'] ?? 'Failed to download trust bundle (HTTP ${response.statusCode})';
      throw PassportTrustBundleException(msg);
    }

    final Map<String, dynamic> jsonMap = jsonDecode(response.body) as Map<String, dynamic>;
    final bundle = PassportTrustBundle.fromJson(jsonMap);

    // 1. Validate version
    if (bundle.version != 1) {
      throw PassportTrustBundleException('Unsupported trust bundle version: ${bundle.version}');
    }

    // 2. Validate timestamps
    final now = DateTime.now().toUtc().millisecondsSinceEpoch ~/ 1000;
    if (bundle.expiresAt <= bundle.generatedAt) {
      throw PassportTrustBundleException('Malformed bundle validity window (expiresAt <= generatedAt)');
    }
    if (bundle.isExpired(now)) {
      throw PassportTrustBundleException('Downloaded trust bundle is already expired');
    }

    // 3. Validate institution block
    if (bundle.institution.publicKey.isEmpty || bundle.institution.keyId.isEmpty) {
      throw PassportTrustBundleException('Missing institutional public key or key ID in bundle');
    }
    if (bundle.issuerKeyId != bundle.institution.keyId) {
      throw PassportTrustBundleException('Bundle issuerKeyId does not match institutional trust key');
    }

    // 4. Verify institutional cryptographic signature
    final isSigValid = await verifyBundleIntegrity(bundle);
    if (!isSigValid) {
      throw PassportTrustBundleException('Institutional signature verification failed over downloaded trust bundle');
    }

    // 5. Persist to local secure storage
    await _storage.write(trustBundleStorageKey, jsonEncode(bundle.toJson()));
    _cachedBundle = bundle;

    debugPrint('🔒 [TRUST_BUNDLE] Fresh trust bundle persisted. Identities: ${bundle.identities.length}, Expires in: ${bundle.remainingValiditySeconds(now)}s');
    return bundle;
  }

  /// Cryptographically verifies the bundle signature using the institution public key.
  Future<bool> verifyBundleIntegrity(PassportTrustBundle bundle) async {
    try {
      final canonicalJson = bundle.toCanonicalJson();
      final pubKey = bundle.institution.publicKey;
      final signature = bundle.signature;

      if (pubKey.isEmpty || signature.isEmpty) return false;

      return await _cryptoService.verifySignature(
        publicKey: pubKey,
        challenge: canonicalJson,
        signature: signature,
      );
    } catch (e) {
      debugPrint('❌ [TRUST_BUNDLE] Signature verification exception: $e');
      return false;
    }
  }

  /// Returns the operational health status of the bundle.
  TrustBundleStatus getBundleStatus(PassportTrustBundle? bundle, [int? currentTimestampSeconds]) {
    if (bundle == null) return TrustBundleStatus.missing;
    final now = currentTimestampSeconds ?? (DateTime.now().toUtc().millisecondsSinceEpoch ~/ 1000);
    if (bundle.isExpired(now)) return TrustBundleStatus.expired;
    // Expiring soon if less than 1 hour (3600 seconds) remaining
    if (bundle.remainingValiditySeconds(now) < 3600) return TrustBundleStatus.expiringSoon;
    return TrustBundleStatus.fresh;
  }

  /// Clears the local trust bundle from memory and persistent storage.
  Future<void> clearLocalBundle() async {
    _cachedBundle = null;
    try {
      await _storage.delete(trustBundleStorageKey);
    } catch (_) {}
  }
}
