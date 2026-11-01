import 'dart:convert';

/// CampusOS Passport Identity and Institutional Certificate Models (Phase 1C).
///
/// Encapsulates the backend-registered device public key and institutional certification.
/// CRITICAL: The model NEVER stores or handles private keys.

class PassportCertificateModel {
  final String id;
  final String keyId;
  final String certificateVersion;
  final String issuer;
  final String issuerKeyId;
  final String userId;
  final String publicKey;
  final String algorithm;
  final DateTime validFrom;
  final DateTime validTo;
  final String signature;
  final String status;
  final Map<String, dynamic> payload;

  PassportCertificateModel({
    required this.id,
    required this.keyId,
    this.certificateVersion = '1.0',
    this.issuer = 'CampusOS',
    required this.issuerKeyId,
    required this.userId,
    required this.publicKey,
    this.algorithm = 'Ed25519',
    required this.validFrom,
    required this.validTo,
    required this.signature,
    this.status = 'ACTIVE',
    required this.payload,
  });

  bool get isActive => status.toUpperCase() == 'ACTIVE';
  bool get isExpired => DateTime.now().isAfter(validTo);
  bool get isValidNow => isActive && !isExpired && DateTime.now().isAfter(validFrom);

  factory PassportCertificateModel.fromMap(Map<String, dynamic> map) {
    final payloadMap = map['payload'] is Map<String, dynamic>
        ? map['payload'] as Map<String, dynamic>
        : <String, dynamic>{};

    return PassportCertificateModel(
      id: map['id']?.toString() ?? '',
      keyId: map['keyId']?.toString() ?? payloadMap['keyId']?.toString() ?? '',
      certificateVersion: map['certificateVersion']?.toString() ?? payloadMap['certificateVersion']?.toString() ?? '1.0',
      issuer: map['issuer']?.toString() ?? payloadMap['issuer']?.toString() ?? 'CampusOS',
      issuerKeyId: map['issuerKeyId']?.toString() ?? '',
      userId: map['userId']?.toString() ?? payloadMap['userId']?.toString() ?? '',
      publicKey: map['publicKey']?.toString() ?? payloadMap['publicKey']?.toString() ?? '',
      algorithm: map['algorithm']?.toString() ?? payloadMap['algorithm']?.toString() ?? 'Ed25519',
      validFrom: DateTime.tryParse(map['validFrom']?.toString() ?? payloadMap['validFrom']?.toString() ?? '') ?? DateTime.now(),
      validTo: DateTime.tryParse(map['validTo']?.toString() ?? payloadMap['validTo']?.toString() ?? '') ?? DateTime.now().add(const Duration(days: 365)),
      signature: map['signature']?.toString() ?? '',
      status: map['status']?.toString() ?? 'ACTIVE',
      payload: payloadMap,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'keyId': keyId,
      'certificateVersion': certificateVersion,
      'issuer': issuer,
      'issuerKeyId': issuerKeyId,
      'userId': userId,
      'publicKey': publicKey,
      'algorithm': algorithm,
      'validFrom': validFrom.toIso8601String(),
      'validTo': validTo.toIso8601String(),
      'signature': signature,
      'status': status,
      'payload': payload,
    };
  }
}

class PassportIdentityKeyModel {
  final String id;
  final String userId;
  final String publicKey;
  final String keyType;
  final String status;
  final DateTime? createdAt;
  final DateTime? activatedAt;
  final DateTime? revokedAt;
  final DateTime? lastSeenAt;
  final PassportCertificateModel? certificate;

  PassportIdentityKeyModel({
    required this.id,
    required this.userId,
    required this.publicKey,
    this.keyType = 'ED25519',
    this.status = 'ACTIVE',
    this.createdAt,
    this.activatedAt,
    this.revokedAt,
    this.lastSeenAt,
    this.certificate,
  });

  bool get isActive => status.toUpperCase() == 'ACTIVE';

  factory PassportIdentityKeyModel.fromMap(Map<String, dynamic> map) {
    PassportCertificateModel? cert;
    if (map['certificate'] is Map<String, dynamic>) {
      cert = PassportCertificateModel.fromMap(map['certificate'] as Map<String, dynamic>);
    }

    return PassportIdentityKeyModel(
      id: map['id']?.toString() ?? map['keyId']?.toString() ?? '',
      userId: map['userId']?.toString() ?? '',
      publicKey: map['publicKey']?.toString() ?? '',
      keyType: map['keyType']?.toString() ?? 'ED25519',
      status: map['status']?.toString() ?? 'ACTIVE',
      createdAt: map['createdAt'] != null ? DateTime.tryParse(map['createdAt'].toString()) : null,
      activatedAt: map['activatedAt'] != null ? DateTime.tryParse(map['activatedAt'].toString()) : null,
      revokedAt: map['revokedAt'] != null ? DateTime.tryParse(map['revokedAt'].toString()) : null,
      lastSeenAt: map['lastSeenAt'] != null ? DateTime.tryParse(map['lastSeenAt'].toString()) : null,
      certificate: cert,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'userId': userId,
      'publicKey': publicKey,
      'keyType': keyType,
      'status': status,
      'createdAt': createdAt?.toIso8601String(),
      'activatedAt': activatedAt?.toIso8601String(),
      'revokedAt': revokedAt?.toIso8601String(),
      'lastSeenAt': lastSeenAt?.toIso8601String(),
      if (certificate != null) 'certificate': certificate!.toMap(),
    };
  }
}

class PassportEnrollmentStatus {
  final bool enrolled;
  final PassportIdentityKeyModel? key;
  final PassportCertificateModel? certificate;

  PassportEnrollmentStatus({
    required this.enrolled,
    this.key,
    this.certificate,
  });

  factory PassportEnrollmentStatus.fromMap(Map<String, dynamic> map) {
    final isEnrolled = map['enrolled'] == true;
    PassportIdentityKeyModel? keyModel;
    PassportCertificateModel? certModel;

    if (map['key'] is Map<String, dynamic>) {
      keyModel = PassportIdentityKeyModel.fromMap(map['key'] as Map<String, dynamic>);
    }
    if (map['certificate'] is Map<String, dynamic>) {
      certModel = PassportCertificateModel.fromMap(map['certificate'] as Map<String, dynamic>);
    }

    return PassportEnrollmentStatus(
      enrolled: isEnrolled,
      key: keyModel,
      certificate: certModel,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'enrolled': enrolled,
      if (key != null) 'key': key!.toMap(),
      if (certificate != null) 'certificate': certificate!.toMap(),
    };
  }

  String toJson() => jsonEncode(toMap());

  factory PassportEnrollmentStatus.fromJson(String source) =>
      PassportEnrollmentStatus.fromMap(jsonDecode(source) as Map<String, dynamic>);
}
