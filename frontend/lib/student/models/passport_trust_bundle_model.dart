import 'dart:convert';
import 'dart:math';

/// Deterministically canonicalizes a JSON data structure according to
/// CampusOS Passport canonicalization rules:
/// - Alphabetically sorted dictionary keys at all nesting levels.
/// - Compact delimiters (',' and ':') with no whitespace.
/// - UTF-8 compatible standard string encoding.
String canonicalizeJson(dynamic value) {
  if (value is Map) {
    final keys = value.keys.map((k) => k.toString()).toList()..sort();
    final buffer = StringBuffer('{');
    for (int i = 0; i < keys.length; i++) {
      final k = keys[i];
      if (i > 0) buffer.write(',');
      buffer.write(jsonEncode(k));
      buffer.write(':');
      buffer.write(canonicalizeJson(value[k]));
    }
    buffer.write('}');
    return buffer.toString();
  } else if (value is List) {
    final buffer = StringBuffer('[');
    for (int i = 0; i < value.length; i++) {
      if (i > 0) buffer.write(',');
      buffer.write(canonicalizeJson(value[i]));
    }
    buffer.write(']');
    return buffer.toString();
  } else {
    return jsonEncode(value);
  }
}

/// Represents the trusted institutional root parameters within a trust bundle.
class PassportInstitutionTrust {
  final String keyId;
  final String publicKey;
  final String issuer;

  const PassportInstitutionTrust({
    required this.keyId,
    required this.publicKey,
    this.issuer = 'CampusOS',
  });

  factory PassportInstitutionTrust.fromJson(Map<String, dynamic> json) {
    return PassportInstitutionTrust(
      keyId: json['keyId']?.toString() ?? '',
      publicKey: json['publicKey']?.toString() ?? '',
      issuer: json['issuer']?.toString() ?? 'CampusOS',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'keyId': keyId,
      'publicKey': publicKey,
      if (issuer != 'CampusOS' && issuer.isNotEmpty) 'issuer': issuer,
    };
  }
}

/// Represents a certified student identity entry inside a trust bundle.
class PassportTrustIdentity {
  final String keyId;
  final String userId;
  final String publicKey;
  final String certificateId;
  final String issuerKeyId;
  final int validFrom;
  final int validTo;
  final String status;
  final String? userName;

  const PassportTrustIdentity({
    required this.keyId,
    required this.userId,
    required this.publicKey,
    required this.certificateId,
    required this.issuerKeyId,
    required this.validFrom,
    required this.validTo,
    this.status = 'ACTIVE',
    this.userName,
  });

  static int _parseTimestamp(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) {
      final parsedInt = int.tryParse(value);
      if (parsedInt != null) return parsedInt;
      try {
        final dt = DateTime.parse(value);
        return dt.toUtc().millisecondsSinceEpoch ~/ 1000;
      } catch (_) {
        return 0;
      }
    }
    return 0;
  }

  factory PassportTrustIdentity.fromJson(Map<String, dynamic> json) {
    return PassportTrustIdentity(
      keyId: json['keyId']?.toString() ?? '',
      userId: json['userId']?.toString() ?? '',
      publicKey: json['publicKey']?.toString() ?? '',
      certificateId: json['certificateId']?.toString() ?? '',
      issuerKeyId: json['issuerKeyId']?.toString() ?? '',
      validFrom: _parseTimestamp(json['validFrom']),
      validTo: _parseTimestamp(json['validTo']),
      status: json['status']?.toString().toUpperCase() ?? 'ACTIVE',
      userName: json['userName']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'certificateId': certificateId,
      'issuerKeyId': issuerKeyId,
      'keyId': keyId,
      'publicKey': publicKey,
      'status': status,
      'userId': userId,
      'validFrom': validFrom,
      'validTo': validTo,
      if (userName != null && userName!.isNotEmpty) 'userName': userName,
    };
  }

  bool isValidAt(int timestampSeconds) {
    return timestampSeconds >= validFrom && timestampSeconds <= validTo;
  }
}

/// CampusOS Passport Versioned Trust Bundle (Phase 1F).
///
/// Encapsulates the complete set of cryptographic anchors, active identity keys,
/// and certified public keys required for 100% offline QR verification.
///
/// Signed by the institutional Ed25519 root private key.
class PassportTrustBundle {
  final int version;
  final String issuerKeyId;
  final int generatedAt;
  final int expiresAt;
  final PassportInstitutionTrust institution;
  final List<PassportTrustIdentity> identities;
  final List<String> revokedKeyIds;
  final String signature;
  final Map<String, dynamic> rawPayload;

  const PassportTrustBundle({
    required this.version,
    required this.issuerKeyId,
    required this.generatedAt,
    required this.expiresAt,
    required this.institution,
    required this.identities,
    required this.revokedKeyIds,
    required this.signature,
    required this.rawPayload,
  });

  factory PassportTrustBundle.fromJson(Map<String, dynamic> json) {
    final payload = json['payload'] is Map<String, dynamic>
        ? json['payload'] as Map<String, dynamic>
        : json;

    final sig = json['signature']?.toString() ?? '';

    final instMap = payload['institution'] is Map<String, dynamic>
        ? payload['institution'] as Map<String, dynamic>
        : <String, dynamic>{};

    final rawIdentities = payload['identities'] is List ? payload['identities'] as List : [];
    final identityList = rawIdentities
        .whereType<Map<String, dynamic>>()
        .map((m) => PassportTrustIdentity.fromJson(m))
        .toList();

    final rawRevoked = payload['revokedKeyIds'] is List ? payload['revokedKeyIds'] as List : [];
    final revokedList = rawRevoked.map((e) => e.toString()).toList();

    return PassportTrustBundle(
      version: payload['version'] is int ? payload['version'] as int : int.tryParse(payload['version']?.toString() ?? '1') ?? 1,
      issuerKeyId: payload['issuerKeyId']?.toString() ?? '',
      generatedAt: payload['generatedAt'] is int ? payload['generatedAt'] as int : int.tryParse(payload['generatedAt']?.toString() ?? '0') ?? 0,
      expiresAt: payload['expiresAt'] is int ? payload['expiresAt'] as int : int.tryParse(payload['expiresAt']?.toString() ?? '0') ?? 0,
      institution: PassportInstitutionTrust.fromJson(instMap),
      identities: identityList,
      revokedKeyIds: revokedList,
      signature: sig,
      rawPayload: payload,
    );
  }

  Map<String, dynamic> toPayloadMap() {
    return {
      'expiresAt': expiresAt,
      'generatedAt': generatedAt,
      'identities': identities.map((i) => i.toJson()).toList(),
      'institution': institution.toJson(),
      'issuerKeyId': issuerKeyId,
      'revokedKeyIds': revokedKeyIds,
      'version': version,
    };
  }

  Map<String, dynamic> toJson() {
    return {
      'payload': rawPayload.isNotEmpty ? rawPayload : toPayloadMap(),
      'signature': signature,
    };
  }

  /// Canonicalizes the bundle payload deterministically for signature verification.
  String toCanonicalJson() {
    return canonicalizeJson(rawPayload.isNotEmpty ? rawPayload : toPayloadMap());
  }

  /// Checks if this bundle has expired relative to current unix timestamp in seconds.
  bool isExpired([int? currentTimestampSeconds]) {
    final now = currentTimestampSeconds ?? (DateTime.now().toUtc().millisecondsSinceEpoch ~/ 1000);
    return now >= expiresAt;
  }

  /// Returns remaining validity in seconds (clamped to 0).
  int remainingValiditySeconds([int? currentTimestampSeconds]) {
    final now = currentTimestampSeconds ?? (DateTime.now().toUtc().millisecondsSinceEpoch ~/ 1000);
    return max(0, expiresAt - now);
  }

  /// Finds an identity by keyId.
  PassportTrustIdentity? findIdentity(String keyId) {
    for (final identity in identities) {
      if (identity.keyId == keyId) {
        return identity;
      }
    }
    return null;
  }

  /// Checks whether a key is recorded as revoked in this bundle.
  bool isKeyRevoked(String keyId) {
    if (revokedKeyIds.contains(keyId)) return true;
    final identity = findIdentity(keyId);
    if (identity != null && identity.status == 'REVOKED') return true;
    return false;
  }
}
