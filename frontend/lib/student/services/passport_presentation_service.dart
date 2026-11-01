import 'dart:math';
import 'package:flutter/foundation.dart';
import '../models/passport_challenge_model.dart';
import '../models/passport_identity_model.dart';
import '../models/passport_presentation_model.dart';
import 'passport_crypto_service.dart';
import 'passport_identity_service.dart';

/// Exceptions thrown during presentation creation.
class PassportPresentationException implements Exception {
  final String message;
  PassportPresentationException(this.message);

  @override
  String toString() => 'PassportPresentationException: $message';
}

class PassportNotEnrolledException extends PassportPresentationException {
  PassportNotEnrolledException() : super('Passport identity is not enrolled on the backend.');
}

class PassportIdentityInactiveException extends PassportPresentationException {
  PassportIdentityInactiveException(String status)
      : super('Passport identity is not active (current status: $status).');
}

class PassportKeyMissingException extends PassportPresentationException {
  PassportKeyMissingException()
      : super('Local device identity key missing from secure storage.');
}

class PassportKeyMismatchException extends PassportPresentationException {
  PassportKeyMismatchException()
      : super('Local identity key does not match backend certified key.');
}

class PassportChallengeExpiredException extends PassportPresentationException {
  PassportChallengeExpiredException()
      : super('BLE challenge has expired. Request a new challenge from the verifier.');
}

/// CampusOS Passport Presentation Service (Phase 1D + 1G).
///
/// Responsible for:
/// 1. Querying active backend identity status.
/// 2. Ensuring device-bound Ed25519 key matches certified identity.
/// 3. Generating short-lived (~30s) signed presentations with secure nonces.
/// 4. Managing local rotation without requiring network requests on every rotation.
/// 5. (Phase 1G) Generating challenge-bound presentations tied to a verifier's BLE challenge.
class PassportPresentationService {
  static const Duration presentationLifetime = Duration(seconds: 30);

  final PassportCryptoService _cryptoService;
  final PassportIdentityService _identityService;

  PassportPresentationService({
    PassportCryptoService? cryptoService,
    PassportIdentityService? identityService,
  })  : _cryptoService = cryptoService ?? PassportCryptoService(),
        _identityService = identityService ?? PassportIdentityService();

  /// Duration for which each generated presentation remains valid.
  Duration get lifetime => presentationLifetime;

  /// Generates a cryptographically signed, short-lived presentation.
  ///
  /// Can take an optional [cachedStatus] to avoid querying the backend on every ~30s rotation.
  Future<PassportPresentationModel> createPresentation({
    PassportEnrollmentStatus? cachedStatus,
  }) async {
    // 1. Resolve identity status
    final status = cachedStatus ?? await _identityService.getIdentity();

    if (!status.enrolled || status.key == null || status.certificate == null) {
      throw PassportNotEnrolledException();
    }

    final key = status.key!;
    final cert = status.certificate!;

    if (!key.isActive) {
      throw PassportIdentityInactiveException(key.status);
    }

    if (!cert.isActive || cert.isExpired) {
      throw PassportIdentityInactiveException(cert.isExpired ? 'EXPIRED' : cert.status);
    }

    // 2. Ensure local key exists in secure keystore
    final hasKey = await _cryptoService.hasIdentityKey();
    if (!hasKey) {
      throw PassportKeyMissingException();
    }

    // 3. Verify local key matches certified key
    final localPubKey = await _cryptoService.getPublicKeyBase64();
    if (localPubKey == null || localPubKey.trim() != key.publicKey.trim()) {
      throw PassportKeyMismatchException();
    }

    // 4. Generate timestamps (in seconds)
    final nowSec = DateTime.now().toUtc().millisecondsSinceEpoch ~/ 1000;
    final expiresAt = nowSec + presentationLifetime.inSeconds;

    // 5. Generate secure random nonce (16 bytes = 32 hex chars)
    final nonce = _generateSecureNonce();

    // 6. Build unsigned presentation model
    final unsignedModel = PassportPresentationModel(
      version: PassportPresentationModel.currentVersion,
      type: PassportPresentationModel.presentationType,
      keyId: key.id,
      userId: key.userId,
      certificateId: cert.id,
      issuerKeyId: cert.issuerKeyId,
      issuedAt: nowSec,
      expiresAt: expiresAt,
      nonce: nonce,
    );

    // 7. Canonicalize and sign with local Ed25519 private key
    final canonicalJson = unsignedModel.toCanonicalJson();
    final signature = await _cryptoService.signPresentation(canonicalJson);

    debugPrint('🔒 [PASSPORT_PRESENTATION] Presentation generated and signed. Expires in ${presentationLifetime.inSeconds}s.');

    return unsignedModel.withSignature(signature);
  }

  /// Generates a challenge-bound presentation (Phase 1G).
  ///
  /// The presentation payload includes the BLE challenge fields, and the
  /// Ed25519 signature covers the combined payload (presentation + challenge).
  /// This cryptographically prevents replay of a QR code at a different verifier.
  ///
  /// Throws [PassportChallengeExpiredException] if the challenge has expired.
  Future<PassportPresentationModel> createChallengeBoundPresentation({
    required PassportChallengeModel challenge,
    PassportEnrollmentStatus? cachedStatus,
  }) async {
    // Validate challenge is still valid
    if (challenge.isExpired()) {
      throw PassportChallengeExpiredException();
    }

    // 1. Resolve identity status
    final status = cachedStatus ?? await _identityService.getIdentity();

    if (!status.enrolled || status.key == null || status.certificate == null) {
      throw PassportNotEnrolledException();
    }

    final key = status.key!;
    final cert = status.certificate!;

    if (!key.isActive) {
      throw PassportIdentityInactiveException(key.status);
    }

    if (!cert.isActive || cert.isExpired) {
      throw PassportIdentityInactiveException(cert.isExpired ? 'EXPIRED' : cert.status);
    }

    // 2. Ensure local key exists
    final hasKey = await _cryptoService.hasIdentityKey();
    if (!hasKey) {
      throw PassportKeyMissingException();
    }

    // 3. Verify local key matches
    final localPubKey = await _cryptoService.getPublicKeyBase64();
    if (localPubKey == null || localPubKey.trim() != key.publicKey.trim()) {
      throw PassportKeyMismatchException();
    }

    // 4. Generate timestamps
    final nowSec = DateTime.now().toUtc().millisecondsSinceEpoch ~/ 1000;
    final expiresAt = nowSec + presentationLifetime.inSeconds;

    // 5. Generate secure nonce
    final nonce = _generateSecureNonce();

    // 6. Build presentation with challenge binding
    final unsignedModel = PassportPresentationModel(
      version: PassportPresentationModel.currentVersion,
      type: PassportPresentationModel.presentationType,
      keyId: key.id,
      userId: key.userId,
      certificateId: cert.id,
      issuerKeyId: cert.issuerKeyId,
      issuedAt: nowSec,
      expiresAt: expiresAt,
      nonce: nonce,
      challenge: challenge.toPayloadMap(),
    );

    // 7. Canonicalize (challenge included in sorted keys) and sign
    final canonicalJson = unsignedModel.toCanonicalJson();
    final signature = await _cryptoService.signPresentation(canonicalJson);

    debugPrint('🔒 [PASSPORT_PRESENTATION] Challenge-bound presentation generated. '
        'Challenge nonce: ${challenge.nonce}. Expires in ${presentationLifetime.inSeconds}s.');

    return unsignedModel.withSignature(signature);
  }

  /// Checks whether a presentation has expired.
  bool isExpired(PassportPresentationModel presentation) {
    return presentation.isExpired();
  }

  /// Generates a 32-character hexadecimal secure nonce.
  String _generateSecureNonce() {
    final random = Random.secure();
    final values = List<int>.generate(16, (i) => random.nextInt(256));
    return values.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }
}
