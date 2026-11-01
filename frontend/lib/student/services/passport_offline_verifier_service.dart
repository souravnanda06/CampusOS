import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../models/passport_presentation_model.dart';
import '../models/passport_proximity_observation.dart';
import '../models/passport_verification_result.dart';
import 'passport_crypto_service.dart';
import 'passport_trust_bundle_service.dart';

/// CampusOS Passport Offline Cryptographic Verifier Service (Phase 1F).
///
/// Executes 100% offline verification of rotating 30-second student Passport presentations
/// against a locally certified institutional trust bundle.
///
/// CRITICAL:
/// - Never invokes ApiClient or network endpoints.
/// - Validates 18 cryptographic, structural, and timestamp invariants locally.
/// - Explicitly acknowledges the offline limitation (cannot see revocations after snapshot).
class PassportOfflineVerifierService {
  final PassportTrustBundleService _bundleService;
  final PassportCryptoService _cryptoService;

  PassportOfflineVerifierService({
    PassportTrustBundleService? bundleService,
    PassportCryptoService? cryptoService,
  })  : _bundleService = bundleService ?? PassportTrustBundleService(),
        _cryptoService = cryptoService ?? PassportCryptoService();

  /// Performs complete local cryptographic verification of a scanned QR payload.
  Future<PassportVerificationResult> verifyOffline({
    required String qrPayload,
    int? currentTimestampSeconds,
    int maxClockSkewSeconds = 30,
  }) async {
    final nowTs = currentTimestampSeconds ?? (DateTime.now().toUtc().millisecondsSinceEpoch ~/ 1000);

    // Rule 1, 2, 3: Local QR envelope pre-validation
    if (qrPayload.trim().isEmpty) {
      return PassportVerificationResult.offlineInvalidFormat('Empty QR payload');
    }

    dynamic decoded;
    try {
      decoded = jsonDecode(qrPayload.trim());
    } catch (_) {
      return PassportVerificationResult.offlineInvalidFormat('Invalid JSON');
    }

    if (decoded is! Map<String, dynamic>) {
      return PassportVerificationResult.offlineInvalidFormat('Envelope must be a JSON object');
    }

    final payloadMap = decoded['p'] is Map<String, dynamic>
        ? decoded['p'] as Map<String, dynamic>
        : (decoded['payload'] is Map<String, dynamic> ? decoded['payload'] as Map<String, dynamic> : null);

    final signatureStr = decoded['s']?.toString() ?? decoded['signature']?.toString();

    if (payloadMap == null || signatureStr == null || signatureStr.isEmpty) {
      return PassportVerificationResult.offlineInvalidFormat('Missing payload or signature in envelope');
    }

    // Rule 4, 5, 6: Presentation model instantiation and structural checks
    PassportPresentationModel presentation;
    try {
      presentation = PassportPresentationModel.fromPayloadMap(payloadMap, signature: signatureStr);
    } catch (e) {
      return PassportVerificationResult.offlineInvalidFormat('Malformed presentation fields: $e');
    }

    if (presentation.version != 1) {
      return const PassportVerificationResult(
        valid: false,
        reason: 'OFFLINE_INVALID_FORMAT',
        verificationSource: 'OFFLINE',
        rawMessage: 'Unsupported presentation version',
      );
    }

    if (presentation.type != 'PASSPORT_PRESENTATION') {
      return const PassportVerificationResult(
        valid: false,
        reason: 'OFFLINE_INVALID_FORMAT',
        verificationSource: 'OFFLINE',
        rawMessage: 'Invalid presentation type',
      );
    }

    if (presentation.keyId.isEmpty ||
        presentation.userId.isEmpty ||
        presentation.certificateId.isEmpty ||
        presentation.issuerKeyId.isEmpty ||
        presentation.nonce.isEmpty) {
      return const PassportVerificationResult(
        valid: false,
        reason: 'OFFLINE_INVALID_FORMAT',
        verificationSource: 'OFFLINE',
        rawMessage: 'Required presentation fields missing',
      );
    }

    // Step 3: Load local trust bundle
    final bundle = await _bundleService.getLocalBundle();
    if (bundle == null) {
      return const PassportVerificationResult(
        valid: false,
        reason: 'OFFLINE_TRUST_DATA_MISSING',
        verificationSource: 'OFFLINE',
        rawMessage: 'No local trust bundle found. Connect to CampusOS to download trust data.',
      );
    }

    // Step 4: Validate trust bundle freshness
    if (bundle.isExpired(nowTs)) {
      return PassportVerificationResult(
        valid: false,
        reason: 'OFFLINE_TRUST_DATA_EXPIRED',
        verificationSource: 'OFFLINE',
        trustSnapshotTime: bundle.generatedAt,
        rawMessage: 'Offline verification data has expired. Refresh trust bundle.',
      );
    }

    // Step 5: Check if key is recorded as revoked in local bundle
    if (bundle.isKeyRevoked(presentation.keyId)) {
      return PassportVerificationResult(
        valid: false,
        reason: 'OFFLINE_REVOKED_KEY',
        verificationSource: 'OFFLINE',
        userId: presentation.userId,
        keyId: presentation.keyId,
        trustSnapshotTime: bundle.generatedAt,
        rawMessage: 'Identity key is recorded as revoked in local trust bundle.',
      );
    }

    // Rule 7: Key exists in local trust bundle
    final identity = bundle.findIdentity(presentation.keyId);
    if (identity == null) {
      return PassportVerificationResult(
        valid: false,
        reason: 'OFFLINE_UNKNOWN_KEY',
        verificationSource: 'OFFLINE',
        keyId: presentation.keyId,
        trustSnapshotTime: bundle.generatedAt,
        rawMessage: 'Identity key is not registered in local trust bundle.',
      );
    }

    // Rule 8, 9, 10, 11: Correlation checks against cached certified identity
    if (identity.userId != presentation.userId ||
        identity.certificateId != presentation.certificateId ||
        identity.issuerKeyId != presentation.issuerKeyId) {
      return PassportVerificationResult(
        valid: false,
        reason: 'OFFLINE_CERTIFICATE_MISMATCH',
        verificationSource: 'OFFLINE',
        userId: presentation.userId,
        keyId: presentation.keyId,
        certificateId: presentation.certificateId,
        trustSnapshotTime: bundle.generatedAt,
        rawMessage: 'Presentation credentials do not match certified identity.',
      );
    }

    // Rule 12: Certificate status is ACTIVE
    if (identity.status != 'ACTIVE') {
      return PassportVerificationResult(
        valid: false,
        reason: 'OFFLINE_REVOKED_KEY',
        verificationSource: 'OFFLINE',
        userId: presentation.userId,
        keyId: presentation.keyId,
        trustSnapshotTime: bundle.generatedAt,
        rawMessage: 'Certificate status is not ACTIVE (${identity.status}).',
      );
    }

    // Rule 13: Certificate validity window
    if (identity.validFrom > 0 && nowTs < identity.validFrom) {
      return PassportVerificationResult(
        valid: false,
        reason: 'OFFLINE_NOT_YET_VALID',
        verificationSource: 'OFFLINE',
        trustSnapshotTime: bundle.generatedAt,
        rawMessage: 'Institutional certificate is not yet valid.',
      );
    }

    if (identity.validTo > 0 && nowTs > identity.validTo) {
      return PassportVerificationResult(
        valid: false,
        reason: 'OFFLINE_CERTIFICATE_EXPIRED',
        verificationSource: 'OFFLINE',
        trustSnapshotTime: bundle.generatedAt,
        rawMessage: 'Institutional certificate has expired.',
      );
    }

    // Rule 14, 15, 16: Presentation timestamps & expiration check with clock skew
    if (presentation.issuedAt > presentation.expiresAt) {
      return const PassportVerificationResult(
        valid: false,
        reason: 'OFFLINE_INVALID_FORMAT',
        verificationSource: 'OFFLINE',
        rawMessage: 'issuedAt is greater than expiresAt',
      );
    }

    // Future skew tolerance
    if (presentation.issuedAt > nowTs + maxClockSkewSeconds) {
      return PassportVerificationResult(
        valid: false,
        reason: 'OFFLINE_NOT_YET_VALID',
        verificationSource: 'OFFLINE',
        trustSnapshotTime: bundle.generatedAt,
        rawMessage: 'Presentation issued in the future outside allowed clock skew.',
      );
    }

    // Expiration tolerance
    if (presentation.expiresAt < nowTs - maxClockSkewSeconds) {
      return PassportVerificationResult(
        valid: false,
        reason: 'OFFLINE_EXPIRED',
        verificationSource: 'OFFLINE',
        expiresAt: presentation.expiresAt,
        trustSnapshotTime: bundle.generatedAt,
        rawMessage: 'Presentation has expired.',
      );
    }

    // Rule 17, 18: Deterministic canonicalization and Ed25519 signature verification
    final canonicalJson = presentation.toCanonicalJson();
    bool isSigValid = false;
    try {
      isSigValid = await _cryptoService.verifySignature(
        publicKey: identity.publicKey,
        challenge: canonicalJson,
        signature: presentation.signature,
      );
    } catch (e) {
      debugPrint('❌ [OFFLINE_VERIFIER] Signature verification exception: $e');
      isSigValid = false;
    }

    if (!isSigValid) {
      return PassportVerificationResult(
        valid: false,
        reason: 'OFFLINE_INVALID_SIGNATURE',
        verificationSource: 'OFFLINE',
        userId: presentation.userId,
        keyId: presentation.keyId,
        trustSnapshotTime: bundle.generatedAt,
        rawMessage: 'Presentation signature is cryptographically invalid.',
      );
    }

    // Phase 1G: Validate challenge binding if present
    if (presentation.challenge != null && presentation.challenge!.isNotEmpty) {
      final challengeValidation = _validateChallengeBinding(
        presentation.challenge!,
        nowTs,
        maxClockSkewSeconds,
      );
      if (challengeValidation != null) {
        return PassportVerificationResult(
          valid: false,
          reason: challengeValidation['reason'] as String,
          verificationSource: 'OFFLINE',
          userId: presentation.userId,
          keyId: presentation.keyId,
          trustSnapshotTime: bundle.generatedAt,
          rawMessage: challengeValidation['message'] as String,
        );
      }
    }

    // All offline checks passed!
    return PassportVerificationResult(
      valid: true,
      reason: 'OFFLINE_VALID',
      verificationSource: 'OFFLINE',
      userId: presentation.userId,
      keyId: presentation.keyId,
      certificateId: presentation.certificateId,
      expiresAt: presentation.expiresAt,
      trustSnapshotTime: bundle.generatedAt,
      challengeNonce: presentation.challenge?['nonce']?.toString(),
      challengeVerifierId: presentation.challenge?['verifierId']?.toString(),
      user: identity.userName != null
          ? PassportVerifiedUser(name: identity.userName!)
          : null,
    );
  }

  /// Performs offline verification with mandatory challenge-binding enforcement (Phase 1G).
  ///
  /// Unlike [verifyOffline], this method REQUIRES the presentation to contain a valid
  /// challenge binding. Use this when the verifier has issued a BLE challenge and
  /// expects the student's presentation to be cryptographically bound to it.
  Future<PassportVerificationResult> verifyOfflineWithChallenge({
    required String qrPayload,
    required String expectedChallengeNonce,
    String? expectedVerifierId,
    int? currentTimestampSeconds,
    int maxClockSkewSeconds = 30,
    PassportProximityObservation? proximityObservation,
  }) async {
    // First, perform standard offline verification
    final result = await verifyOffline(
      qrPayload: qrPayload,
      currentTimestampSeconds: currentTimestampSeconds,
      maxClockSkewSeconds: maxClockSkewSeconds,
    );

    // If base verification failed, return as-is (carrying proximity observation if available)
    if (!result.valid) {
      return result.copyWith(
        proximityObservation: proximityObservation,
        proximityTier: proximityObservation?.proximityTier.code,
        medianRssi: proximityObservation?.medianRssi,
        proximityConfidence: proximityObservation?.confidence.code,
      );
    }

    // Enforce challenge binding

    // Parse the presentation to inspect challenge field
    final decoded = jsonDecode(qrPayload.trim()) as Map<String, dynamic>;
    final payloadMap = decoded['p'] as Map<String, dynamic>? ??
        decoded['payload'] as Map<String, dynamic>?;
    final presentation = PassportPresentationModel.fromPayloadMap(
      payloadMap!,
      signature: decoded['s']?.toString() ?? decoded['signature']?.toString() ?? '',
    );

    if (!presentation.isChallengebound) {
      return PassportVerificationResult(
        valid: false,
        reason: 'OFFLINE_CHALLENGE_MISSING',
        verificationSource: 'OFFLINE',
        userId: result.userId,
        keyId: result.keyId,
        trustSnapshotTime: result.trustSnapshotTime,
        proximityObservation: proximityObservation,
        proximityTier: proximityObservation?.proximityTier.code,
        medianRssi: proximityObservation?.medianRssi,
        proximityConfidence: proximityObservation?.confidence.code,
        rawMessage: 'Presentation is not challenge-bound. '
            'Verifier requires BLE challenge binding for anti-replay verification.',
      );
    }

    // Verify challenge nonce matches
    final presentedNonce = presentation.challenge!['nonce']?.toString() ?? '';
    if (presentedNonce != expectedChallengeNonce) {
      return PassportVerificationResult(
        valid: false,
        reason: 'OFFLINE_CHALLENGE_MISMATCH',
        verificationSource: 'OFFLINE',
        userId: result.userId,
        keyId: result.keyId,
        trustSnapshotTime: result.trustSnapshotTime,
        proximityObservation: proximityObservation,
        proximityTier: proximityObservation?.proximityTier.code,
        medianRssi: proximityObservation?.medianRssi,
        proximityConfidence: proximityObservation?.confidence.code,
        rawMessage: 'Challenge nonce does not match the verifier\'s issued challenge.',
      );
    }

    // Optionally verify verifier ID
    if (expectedVerifierId != null) {
      final presentedVerifierId = presentation.challenge!['verifierId']?.toString() ?? '';
      if (presentedVerifierId != expectedVerifierId) {
        return PassportVerificationResult(
          valid: false,
          reason: 'OFFLINE_CHALLENGE_MISMATCH',
          verificationSource: 'OFFLINE',
          userId: result.userId,
          keyId: result.keyId,
          trustSnapshotTime: result.trustSnapshotTime,
          proximityObservation: proximityObservation,
          proximityTier: proximityObservation?.proximityTier.code,
          medianRssi: proximityObservation?.medianRssi,
          proximityConfidence: proximityObservation?.confidence.code,
          rawMessage: 'Challenge verifier ID does not match.',
        );
      }
    }

    // Return result with challenge and proximity metadata
    return PassportVerificationResult(
      valid: true,
      reason: 'OFFLINE_VALID',
      verificationSource: 'OFFLINE',
      userId: result.userId,
      keyId: result.keyId,
      certificateId: result.certificateId,
      expiresAt: result.expiresAt,
      trustSnapshotTime: result.trustSnapshotTime,
      challengeNonce: presentedNonce,
      challengeVerifierId: presentation.challenge!['verifierId']?.toString(),
      proximityObservation: proximityObservation,
      proximityTier: proximityObservation?.proximityTier.code,
      medianRssi: proximityObservation?.medianRssi,
      proximityConfidence: proximityObservation?.confidence.code,
      user: result.user,
    );
  }

  /// Validates the structure and expiration of a challenge binding within a presentation.
  ///
  /// Returns null if valid, or a map with 'reason' and 'message' if invalid.
  Map<String, String>? _validateChallengeBinding(
    Map<String, dynamic> challenge,
    int nowTs,
    int maxClockSkewSeconds,
  ) {
    // Required challenge fields
    final nonce = challenge['nonce']?.toString();
    final verifierId = challenge['verifierId']?.toString();
    final challengeIssuedAt = challenge['issuedAt'];
    final challengeExpiresAt = challenge['expiresAt'];

    if (nonce == null || nonce.isEmpty) {
      return {
        'reason': 'OFFLINE_CHALLENGE_INVALID',
        'message': 'Challenge binding missing required nonce.',
      };
    }

    if (verifierId == null || verifierId.isEmpty) {
      return {
        'reason': 'OFFLINE_CHALLENGE_INVALID',
        'message': 'Challenge binding missing required verifierId.',
      };
    }

    if (challengeIssuedAt == null || challengeExpiresAt == null) {
      return {
        'reason': 'OFFLINE_CHALLENGE_INVALID',
        'message': 'Challenge binding missing timestamp fields.',
      };
    }

    final issuedAt = challengeIssuedAt is int
        ? challengeIssuedAt
        : int.tryParse(challengeIssuedAt.toString()) ?? 0;
    final expiresAt = challengeExpiresAt is int
        ? challengeExpiresAt
        : int.tryParse(challengeExpiresAt.toString()) ?? 0;

    if (issuedAt > expiresAt) {
      return {
        'reason': 'OFFLINE_CHALLENGE_INVALID',
        'message': 'Challenge issuedAt is greater than expiresAt.',
      };
    }

    // Challenge expiration with clock skew tolerance
    if (expiresAt < nowTs - maxClockSkewSeconds) {
      return {
        'reason': 'OFFLINE_CHALLENGE_EXPIRED',
        'message': 'BLE challenge has expired.',
      };
    }

    return null; // Valid
  }
}

