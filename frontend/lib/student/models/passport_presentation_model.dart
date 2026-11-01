import 'dart:convert';
import 'dart:math';

/// CampusOS Passport Dynamic Presentation Model (Phase 1D).
///
/// Represents a short-lived (~30s) presentation payload signed by the student's
/// local Ed25519 private key.
///
/// CRITICAL SECURITY INVARIANTS:
/// - NEVER includes the private key.
/// - NEVER includes the permanent public key in the payload.
/// - Relies on `keyId` to identify the registered identity key.
/// - The verifier validates the signature using the institutionally certified key.
class PassportPresentationModel {
  static const int currentVersion = 1;
  static const String presentationType = 'PASSPORT_PRESENTATION';

  final int version;
  final String type;
  final String keyId;
  final String userId;
  final String certificateId;
  final String issuerKeyId;
  final int issuedAt;
  final int expiresAt;
  final String nonce;
  final String signature;

  /// Optional BLE challenge binding (Phase 1G).
  /// When present, the presentation is cryptographically bound to a verifier's
  /// BLE challenge, preventing replay attacks across verifier sessions.
  final Map<String, dynamic>? challenge;

  /// Whether this presentation is challenge-bound.
  bool get isChallengebound => challenge != null && challenge!.isNotEmpty;

  PassportPresentationModel({
    this.version = currentVersion,
    this.type = presentationType,
    required this.keyId,
    required this.userId,
    required this.certificateId,
    required this.issuerKeyId,
    required this.issuedAt,
    required this.expiresAt,
    required this.nonce,
    this.signature = '',
    this.challenge,
  });

  /// Returns the presentation payload dictionary without signature.
  /// Includes the optional challenge binding when present.
  Map<String, dynamic> toPayloadMap() {
    final map = <String, dynamic>{
      'version': version,
      'type': type,
      'keyId': keyId,
      'userId': userId,
      'certificateId': certificateId,
      'issuerKeyId': issuerKeyId,
      'issuedAt': issuedAt,
      'expiresAt': expiresAt,
      'nonce': nonce,
    };
    if (challenge != null && challenge!.isNotEmpty) {
      map['challenge'] = challenge;
    }
    return map;
  }

  /// Produces deterministic, canonical JSON representation of the payload.
  /// Keys are sorted alphabetically with compact delimiters (',' and ':').
  ///
  /// Alphabetical key order:
  /// 1. certificateId
  /// 2. expiresAt
  /// 3. issuedAt
  /// 4. issuerKeyId
  /// 5. keyId
  /// 6. nonce
  /// 7. type
  /// 8. userId
  /// 9. version
  String toCanonicalJson() {
    final payload = toPayloadMap();
    final sortedKeys = payload.keys.toList()..sort();
    final buffer = StringBuffer('{');
    for (int i = 0; i < sortedKeys.length; i++) {
      final key = sortedKeys[i];
      final value = payload[key];
      if (i > 0) buffer.write(',');
      buffer.write(jsonEncode(key));
      buffer.write(':');
      buffer.write(jsonEncode(value));
    }
    buffer.write('}');
    return buffer.toString();
  }

  /// Compact QR envelope format:
  /// {"p": <payload>, "s": "<signature>"}
  String toQrPayload() {
    final envelope = {
      'p': toPayloadMap(),
      's': signature,
    };
    return jsonEncode(envelope);
  }

  /// Parses a compact QR envelope string into a [PassportPresentationModel].
  factory PassportPresentationModel.fromQrPayload(String qrString) {
    final decoded = jsonDecode(qrString);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Invalid QR envelope format: expected JSON object');
    }

    final payload = decoded['p'] is Map<String, dynamic>
        ? decoded['p'] as Map<String, dynamic>
        : (decoded['payload'] is Map<String, dynamic> ? decoded['payload'] as Map<String, dynamic> : decoded);

    final signature = decoded['s']?.toString() ?? decoded['signature']?.toString() ?? '';

    return PassportPresentationModel.fromPayloadMap(payload, signature: signature);
  }

  /// Creates a model from a payload map and optional signature.
  factory PassportPresentationModel.fromPayloadMap(Map<String, dynamic> map, {String signature = ''}) {
    // Parse optional challenge binding (Phase 1G)
    Map<String, dynamic>? challengeMap;
    if (map['challenge'] is Map<String, dynamic>) {
      challengeMap = map['challenge'] as Map<String, dynamic>;
    }

    return PassportPresentationModel(
      version: (map['version'] is int) ? map['version'] as int : int.tryParse(map['version']?.toString() ?? '1') ?? 1,
      type: map['type']?.toString() ?? presentationType,
      keyId: map['keyId']?.toString() ?? '',
      userId: map['userId']?.toString() ?? '',
      certificateId: map['certificateId']?.toString() ?? '',
      issuerKeyId: map['issuerKeyId']?.toString() ?? '',
      issuedAt: (map['issuedAt'] is int) ? map['issuedAt'] as int : int.tryParse(map['issuedAt']?.toString() ?? '0') ?? 0,
      expiresAt: (map['expiresAt'] is int) ? map['expiresAt'] as int : int.tryParse(map['expiresAt']?.toString() ?? '0') ?? 0,
      nonce: map['nonce']?.toString() ?? '',
      signature: signature.isNotEmpty ? signature : (map['signature']?.toString() ?? ''),
      challenge: challengeMap,
    );
  }

  /// Creates a copy of this presentation with a new signature.
  PassportPresentationModel withSignature(String newSignature) {
    return PassportPresentationModel(
      version: version,
      type: type,
      keyId: keyId,
      userId: userId,
      certificateId: certificateId,
      issuerKeyId: issuerKeyId,
      issuedAt: issuedAt,
      expiresAt: expiresAt,
      nonce: nonce,
      signature: newSignature,
      challenge: challenge,
    );
  }

  /// Creates a copy of this presentation with a BLE challenge binding.
  PassportPresentationModel withChallenge(Map<String, dynamic> challengeMap) {
    return PassportPresentationModel(
      version: version,
      type: type,
      keyId: keyId,
      userId: userId,
      certificateId: certificateId,
      issuerKeyId: issuerKeyId,
      issuedAt: issuedAt,
      expiresAt: expiresAt,
      nonce: nonce,
      signature: '', // Signature must be recalculated with challenge included
      challenge: challengeMap,
    );
  }

  /// Checks if this presentation has expired relative to current unix timestamp in seconds.
  bool isExpired([int? currentTimestampSeconds]) {
    final now = currentTimestampSeconds ?? (DateTime.now().toUtc().millisecondsSinceEpoch ~/ 1000);
    return now >= expiresAt;
  }

  /// Returns remaining validity in seconds (clamped to 0).
  int remainingSeconds([int? currentTimestampSeconds]) {
    final now = currentTimestampSeconds ?? (DateTime.now().toUtc().millisecondsSinceEpoch ~/ 1000);
    return max(0, expiresAt - now);
  }

  /// Returns validity progress between 0.0 (expired) and 1.0 (fresh).
  double validityProgress([int? currentTimestampSeconds]) {
    final total = expiresAt - issuedAt;
    if (total <= 0) return 0.0;
    final remaining = remainingSeconds(currentTimestampSeconds);
    return (remaining / total).clamp(0.0, 1.0);
  }
}
