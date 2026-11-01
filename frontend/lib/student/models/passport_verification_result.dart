import 'passport_proximity_observation.dart';

/// CampusOS Passport Verification Result Model (Phase 1E, 1F, 1G & 1H).
///
/// Encapsulates the cryptographic verification outcome returned by:
/// 1. Online backend endpoint POST /passport/verify
/// 2. Offline verifier service using local certified trust bundle
/// 3. Local pre-validation failures (e.g. malformed QR, network error, missing trust data).
/// 4. Phase 1H BLE proximity strengthening observation.
///
/// CRITICAL:
/// - Never exposes internal backend secrets or stack traces.
/// - Clearly distinguishes cryptographic invalidity from network transport failure.
/// - Clearly indicates when verification was performed OFFLINE against cached snapshot.
/// - Explicitly acknowledges the offline revocation limitation.
/// - Cryptographic identity verification remains strictly authoritative;
///   RSSI proximity is an additional physical-world signal and CANNOT validate
///   an invalid cryptographic presentation.

/// Possible high-level verification outcomes for Passport presentation (Phase 1H).
enum PassportVerificationStatus {
  /// Presentation signature, certificate, and trust are cryptographically valid.
  verified,

  /// Valid presentation bound to a fresh challenge with nearby BLE proximity signal.
  verifiedWithProximity,

  /// Valid presentation bound to a fresh challenge, but BLE proximity signal is inconclusive or absent.
  verifiedWithoutProximity,

  /// Cryptographic signature, certificate, challenge, or trust verification failed.
  rejected;

  String get code {
    switch (this) {
      case PassportVerificationStatus.verified:
        return 'VERIFIED';
      case PassportVerificationStatus.verifiedWithProximity:
        return 'VERIFIED_WITH_PROXIMITY_SIGNAL';
      case PassportVerificationStatus.verifiedWithoutProximity:
        return 'VERIFIED_WITHOUT_PROXIMITY_SIGNAL';
      case PassportVerificationStatus.rejected:
        return 'REJECTED';
    }
  }
}

class PassportVerifiedUser {
  final String name;
  final String? branch;
  final String? year;
  final String? course;
  final String? registrationNumber;

  const PassportVerifiedUser({
    required this.name,
    this.branch,
    this.year,
    this.course,
    this.registrationNumber,
  });

  factory PassportVerifiedUser.fromMap(Map<String, dynamic> map) {
    return PassportVerifiedUser(
      name: map['name']?.toString() ?? 'Student',
      branch: map['branch']?.toString(),
      year: map['year']?.toString(),
      course: map['course']?.toString(),
      registrationNumber: map['registrationNumber']?.toString(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      if (branch != null) 'branch': branch,
      if (year != null) 'year': year,
      if (course != null) 'course': course,
      if (registrationNumber != null) 'registrationNumber': registrationNumber,
    };
  }
}

class PassportVerificationResult {
  final bool valid;
  final String reason;
  final String verificationSource; // 'ONLINE' or 'OFFLINE'
  final String? userId;
  final String? keyId;
  final String? certificateId;
  final int? expiresAt;
  final int? trustSnapshotTime; // Unix timestamp of trust bundle used for offline verification
  final PassportVerifiedUser? user;
  final String? rawMessage;

  /// Phase 1G: Challenge nonce from BLE challenge-bound verification.
  final String? challengeNonce;

  /// Phase 1G: Verifier ID from BLE challenge-bound verification.
  final String? challengeVerifierId;

  /// Phase 1H: Ephemeral proximity observation associated with the challenge.
  final PassportProximityObservation? proximityObservation;

  /// Phase 1H: Proximity tier code ('NEAR', 'FAR', 'UNSTABLE', 'UNKNOWN').
  final String? proximityTier;

  /// Phase 1H: Median RSSI in dBm from proximity observation.
  final int? medianRssi;

  /// Phase 1H: Proximity confidence code ('HIGH', 'MEDIUM', 'LOW', 'NONE').
  final String? proximityConfidence;

  const PassportVerificationResult({
    required this.valid,
    required this.reason,
    this.verificationSource = 'ONLINE',
    this.userId,
    this.keyId,
    this.certificateId,
    this.expiresAt,
    this.trustSnapshotTime,
    this.user,
    this.rawMessage,
    this.challengeNonce,
    this.challengeVerifierId,
    this.proximityObservation,
    this.proximityTier,
    this.medianRssi,
    this.proximityConfidence,
  });

  bool get isOffline => verificationSource == 'OFFLINE';
  bool get isValid => valid && (reason == 'VALID' || reason == 'OFFLINE_VALID');
  bool get isOfflineValid => isOffline && isValid;
  bool get isNetworkError => reason == 'NETWORK_ERROR';
  bool get isExpired =>
      reason == 'PRESENTATION_EXPIRED' ||
      reason == 'EXPIRED_CERTIFICATE' ||
      reason == 'OFFLINE_EXPIRED' ||
      reason == 'OFFLINE_CERTIFICATE_EXPIRED';
  bool get isRevoked =>
      reason == 'REVOKED_KEY' ||
      reason == 'REVOKED_CERTIFICATE' ||
      reason == 'OFFLINE_REVOKED_KEY';
  bool get isInvalidSignature =>
      reason == 'INVALID_SIGNATURE' || reason == 'OFFLINE_INVALID_SIGNATURE';
  bool get isInvalidFormat =>
      reason == 'INVALID_FORMAT' || reason == 'OFFLINE_INVALID_FORMAT';
  bool get isUnknownKey =>
      reason == 'UNKNOWN_KEY' || reason == 'OFFLINE_UNKNOWN_KEY';
  bool get isMismatch =>
      reason == 'CERTIFICATE_MISMATCH' || reason == 'OFFLINE_CERTIFICATE_MISMATCH';
  bool get isTrustDataExpired => reason == 'OFFLINE_TRUST_DATA_EXPIRED';
  bool get isTrustDataMissing => reason == 'OFFLINE_TRUST_DATA_MISSING';

  /// Phase 1G: Whether this result contains challenge-bound verification.
  bool get isChallengeBound => challengeNonce != null && challengeNonce!.isNotEmpty;

  /// Phase 1H: Alias for isChallengeBound.
  bool get challengeBound => isChallengeBound;

  /// Phase 1H: Overall composite verification status.
  /// CRITICAL: RSSI alone NEVER turns an invalid cryptographic identity into valid!
  PassportVerificationStatus get verificationStatus {
    if (!isValid) return PassportVerificationStatus.rejected;
    if (isChallengeBound) {
      if (isProximityNear) {
        return PassportVerificationStatus.verifiedWithProximity;
      }
      return PassportVerificationStatus.verifiedWithoutProximity;
    }
    return PassportVerificationStatus.verified;
  }

  /// Phase 1H: Whether a proximity signal was observed with at least 1 sample.
  bool get hasProximitySignal =>
      proximityObservation != null && proximityObservation!.sampleCount > 0;

  /// Phase 1H: Whether proximity observation is classified as NEAR.
  bool get isProximityNear =>
      (proximityTier?.toUpperCase() == 'NEAR') ||
      (proximityObservation?.isNear ?? false);

  /// Phase 1H: Whether proximity observation is classified as FAR.
  bool get isProximityFar =>
      (proximityTier?.toUpperCase() == 'FAR') ||
      (proximityObservation?.isFar ?? false);

  /// Phase 1H: Whether proximity observation is classified as UNSTABLE.
  bool get isProximityUnstable =>
      (proximityTier?.toUpperCase() == 'UNSTABLE') ||
      (proximityObservation?.isUnstable ?? false);

  /// Phase 1H: Whether proximity observation is UNKNOWN or absent.
  bool get isProximityUnknown =>
      (!isProximityNear && !isProximityFar && !isProximityUnstable);

  /// Phase 1H: Anti-relay compliant user-facing proximity summary description.
  String get proximitySummary {
    if (proximityObservation != null) {
      return proximityObservation!.userFriendlyDescription;
    }
    if (isProximityNear) {
      final rStr = medianRssi != null ? ' ($medianRssi dBm)' : '';
      return 'Nearby signal observed$rStr';
    }
    if (isProximityFar) {
      final rStr = medianRssi != null ? ' ($medianRssi dBm)' : '';
      return 'Distant or attenuated signal observed$rStr';
    }
    if (isProximityUnstable) {
      return 'Challenge verified, proximity signal inconclusive (unstable RF)';
    }
    return 'Challenge verified, proximity signal inconclusive (no BLE samples)';
  }

  /// Phase 1G: Challenge-specific failure reasons.
  bool get isChallengeExpired =>
      reason == 'OFFLINE_CHALLENGE_EXPIRED' || reason == 'CHALLENGE_EXPIRED';
  bool get isChallengeMissing => reason == 'OFFLINE_CHALLENGE_MISSING';
  bool get isChallengeMismatch => reason == 'OFFLINE_CHALLENGE_MISMATCH';
  bool get isChallengeInvalid =>
      reason == 'OFFLINE_CHALLENGE_INVALID' || reason == 'INVALID_CHALLENGE';

  /// Remaining seconds relative to now (clamped to 0).
  int get remainingSeconds {
    if (expiresAt == null) return 0;
    final now = DateTime.now().toUtc().millisecondsSinceEpoch ~/ 1000;
    final diff = expiresAt! - now;
    return diff > 0 ? diff : 0;
  }

  /// Formatted age string for trust bundle snapshot (e.g. "18 mins ago").
  String get snapshotAgeDescription {
    if (trustSnapshotTime == null || trustSnapshotTime == 0) return '';
    final now = DateTime.now().toUtc().millisecondsSinceEpoch ~/ 1000;
    final elapsedSeconds = now - trustSnapshotTime!;
    if (elapsedSeconds < 60) return 'just now';
    final minutes = elapsedSeconds ~/ 60;
    if (minutes < 60) return '$minutes ${minutes == 1 ? "min" : "mins"} ago';
    final hours = minutes ~/ 60;
    if (hours < 24) return '$hours ${hours == 1 ? "hour" : "hours"} ago';
    final days = hours ~/ 24;
    return '$days ${days == 1 ? "day" : "days"} ago';
  }

  /// Creates a copy of this result with optional fields replaced.
  PassportVerificationResult copyWith({
    bool? valid,
    String? reason,
    String? verificationSource,
    String? userId,
    String? keyId,
    String? certificateId,
    int? expiresAt,
    int? trustSnapshotTime,
    PassportVerifiedUser? user,
    String? rawMessage,
    String? challengeNonce,
    String? challengeVerifierId,
    PassportProximityObservation? proximityObservation,
    String? proximityTier,
    int? medianRssi,
    String? proximityConfidence,
  }) {
    return PassportVerificationResult(
      valid: valid ?? this.valid,
      reason: reason ?? this.reason,
      verificationSource: verificationSource ?? this.verificationSource,
      userId: userId ?? this.userId,
      keyId: keyId ?? this.keyId,
      certificateId: certificateId ?? this.certificateId,
      expiresAt: expiresAt ?? this.expiresAt,
      trustSnapshotTime: trustSnapshotTime ?? this.trustSnapshotTime,
      user: user ?? this.user,
      rawMessage: rawMessage ?? this.rawMessage,
      challengeNonce: challengeNonce ?? this.challengeNonce,
      challengeVerifierId: challengeVerifierId ?? this.challengeVerifierId,
      proximityObservation: proximityObservation ?? this.proximityObservation,
      proximityTier: proximityTier ?? this.proximityTier,
      medianRssi: medianRssi ?? this.medianRssi,
      proximityConfidence: proximityConfidence ?? this.proximityConfidence,
    );
  }

  factory PassportVerificationResult.fromMap(
    Map<String, dynamic> map, {
    String verificationSource = 'ONLINE',
    int? trustSnapshotTime,
  }) {
    final valid = map['valid'] == true;
    final reason = map['reason']?.toString() ?? (valid ? 'VALID' : 'INVALID_FORMAT');
    PassportVerifiedUser? verifiedUser;
    if (map['user'] is Map<String, dynamic>) {
      verifiedUser = PassportVerifiedUser.fromMap(map['user'] as Map<String, dynamic>);
    }

    PassportProximityObservation? obs;
    if (map['proximityObservation'] is Map<String, dynamic>) {
      obs = PassportProximityObservation.fromMap(
          map['proximityObservation'] as Map<String, dynamic>);
    }

    return PassportVerificationResult(
      valid: valid,
      reason: reason,
      verificationSource: verificationSource,
      userId: map['userId']?.toString(),
      keyId: map['keyId']?.toString(),
      certificateId: map['certificateId']?.toString(),
      expiresAt: (map['expiresAt'] is int)
          ? map['expiresAt'] as int
          : int.tryParse(map['expiresAt']?.toString() ?? ''),
      trustSnapshotTime: trustSnapshotTime ??
          ((map['trustSnapshotTime'] is int)
              ? map['trustSnapshotTime'] as int
              : int.tryParse(map['trustSnapshotTime']?.toString() ?? '')),
      user: verifiedUser,
      rawMessage: map['message']?.toString(),
      challengeNonce: map['challengeNonce']?.toString(),
      challengeVerifierId: map['challengeVerifierId']?.toString(),
      proximityObservation: obs,
      proximityTier: map['proximityTier']?.toString() ?? obs?.proximityTier.code,
      medianRssi: (map['medianRssi'] is int)
          ? map['medianRssi'] as int
          : (int.tryParse(map['medianRssi']?.toString() ?? '') ?? obs?.medianRssi),
      proximityConfidence: map['proximityConfidence']?.toString() ?? obs?.confidence.code,
    );
  }

  factory PassportVerificationResult.networkError([String? message]) {
    return PassportVerificationResult(
      valid: false,
      reason: 'NETWORK_ERROR',
      verificationSource: 'ONLINE',
      rawMessage: message ?? 'Connect to the CampusOS server and try again.',
    );
  }

  factory PassportVerificationResult.invalidFormat([String? message]) {
    return PassportVerificationResult(
      valid: false,
      reason: 'INVALID_FORMAT',
      verificationSource: 'ONLINE',
      rawMessage: message ?? 'Invalid Passport QR.',
    );
  }

  factory PassportVerificationResult.offlineInvalidFormat([String? message]) {
    return PassportVerificationResult(
      valid: false,
      reason: 'OFFLINE_INVALID_FORMAT',
      verificationSource: 'OFFLINE',
      rawMessage: message ?? 'Invalid Passport QR format.',
    );
  }

  factory PassportVerificationResult.offlineTrustDataExpired([String? message]) {
    return PassportVerificationResult(
      valid: false,
      reason: 'OFFLINE_TRUST_DATA_EXPIRED',
      verificationSource: 'OFFLINE',
      rawMessage: message ?? 'Offline verification data has expired. Connect to CampusOS to refresh.',
    );
  }

  factory PassportVerificationResult.offlineTrustDataMissing([String? message]) {
    return PassportVerificationResult(
      valid: false,
      reason: 'OFFLINE_TRUST_DATA_MISSING',
      verificationSource: 'OFFLINE',
      rawMessage: message ?? 'No local trust bundle found. Connect to CampusOS to download verification data.',
    );
  }

  /// User-friendly display title
  String get displayTitle {
    if (isValid) return "PASSPORT VALID";
    if (isNetworkError) return "Verification Unavailable";
    if (isTrustDataExpired) return "Trust Data Expired";
    if (isTrustDataMissing) return "Trust Data Missing";
    if (reason == 'PRESENTATION_EXPIRED' || reason == 'OFFLINE_EXPIRED') {
      return "Passport Presentation Expired";
    }
    if (reason == 'EXPIRED_CERTIFICATE' || reason == 'OFFLINE_CERTIFICATE_EXPIRED') {
      return "Identity Certificate Expired";
    }
    if (reason == 'REVOKED_KEY' || reason == 'OFFLINE_REVOKED_KEY') {
      return "Passport Identity Revoked";
    }
    if (reason == 'REVOKED_CERTIFICATE') return "Certificate Revoked";
    if (isInvalidSignature) return "Passport Could Not Be Verified";
    if (isMismatch) return "Passport Identity Mismatch";
    if (isUnknownKey) return "Unknown Passport Identity";
    if (reason == 'NOT_YET_VALID' || reason == 'OFFLINE_NOT_YET_VALID') {
      return "Passport Not Yet Valid";
    }
    if (isInvalidFormat) return "Invalid Passport QR";
    if (isChallengeExpired) return "Challenge Expired";
    if (isChallengeMissing) return "Challenge Required";
    if (isChallengeMismatch) return "Challenge Mismatch";
    if (isChallengeInvalid) return "Invalid Challenge";
    return "Unable to Verify Passport";
  }

  /// User-friendly display message / description
  String get displayMessage {
    if (isOfflineValid) {
      final ageStr = snapshotAgeDescription.isNotEmpty ? ' updated $snapshotAgeDescription' : '';
      return "Verified against CampusOS trust data$ageStr.";
    }
    if (isValid) return "Certified CampusOS Identity Presentation";
    if (isNetworkError) return "Connect to the CampusOS server and try again.";
    if (isTrustDataExpired) {
      return "Offline verification data has expired. Connect to CampusOS to refresh.";
    }
    if (isTrustDataMissing) {
      return "No local trust bundle found. Connect to CampusOS to download verification data.";
    }
    if (reason == 'PRESENTATION_EXPIRED' || reason == 'OFFLINE_EXPIRED') {
      return "Ask the student to refresh their Passport QR.";
    }
    if (reason == 'OFFLINE_CERTIFICATE_EXPIRED') {
      return "The cached institutional certificate is no longer valid.";
    }
    if (reason == 'EXPIRED_CERTIFICATE') {
      return "The student's institutional identity certificate is expired.";
    }
    if (reason == 'OFFLINE_REVOKED_KEY') {
      return "This identity key is recorded as revoked in the local trust bundle.";
    }
    if (reason == 'REVOKED_KEY' || reason == 'REVOKED_CERTIFICATE') {
      return "This identity is no longer active.";
    }
    if (reason == 'INVALID_SIGNATURE') return "Signature is invalid.";
    if (reason == 'OFFLINE_INVALID_SIGNATURE') {
      return "The Passport signature does not match the trusted identity key.";
    }
    if (reason == 'OFFLINE_UNKNOWN_KEY') {
      return "This identity is not present in the local CampusOS trust bundle.";
    }
    if (isMismatch) return "The presentation does not match its certified identity.";
    if (isUnknownKey) return "Identity key is not recognized.";
    if (reason == 'NOT_YET_VALID' || reason == 'OFFLINE_NOT_YET_VALID') {
      return "Device clock appears to be set in the future.";
    }
    if (isInvalidFormat) return "The scanned QR code is not a valid CampusOS presentation.";
    if (isChallengeExpired) return "The BLE challenge has expired. Request a new challenge.";
    if (isChallengeMissing) return "This verifier requires BLE challenge binding. Present your QR while near the verifier.";
    if (isChallengeMismatch) return "The challenge nonce does not match. Present a fresh QR near the verifier.";
    if (isChallengeInvalid) return "The challenge binding is malformed or incomplete.";
    return "The presentation credential could not be verified by the campus authority.";
  }
}
