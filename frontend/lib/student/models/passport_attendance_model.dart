import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'passport_proximity_observation.dart';
import 'passport_trust_bundle_model.dart';
import '../services/passport_crypto_service.dart';

/// CampusOS Passport Attendance Protocol Constants (Phase 1I).
class PassportAttendanceModel {
  static const int currentVersion = 1;

  /// Dedicated 16-bit alias service UUID for Passport Attendance.
  /// Used for both Teacher Beacon and Student Response BLE advertisements.
  static const String passportAttendanceServiceUuid =
      '0000FE20-0000-1000-8000-00805F9B34FB';

  /// Verification mode constants
  static const String modeBle = 'BLE_BATCH';
  static const String modeWifiLan = 'WIFI_LAN';
  static const String modeWifiHotspot = 'WIFI_HOTSPOT';
  static const String modeQrOptical = 'QR_OPTICAL';
  static const String modePinManual = 'PIN_MANUAL';

  /// Default port for teacher offline local HTTP attendance receiver
  static const int defaultLocalHttpPort = 53318;

  /// Default port for teacher Wi-Fi UDP beacon multicast
  static const int defaultUdpMulticastPort = 53317;

  /// Legacy attendance BLE service UUID (session ID).
  /// Preserved for backward compatibility.
  static const String legacyAttendancePrefix = 'attentify';

  /// BLE frame magic byte.
  static const int bleFrameMagic = 0xCA;

  /// BLE frame types.
  static const int frameTypeBeacon = 0x01;
  static const int frameTypeResponse = 0x02;
  static const int frameTypeCompactResponse = 0x03;

  /// Maximum payload bytes per BLE frame (header is 8 bytes, so 8 + 16 = 24 bytes,
  /// which fits safely within the 27-byte legacy BLE advertisement limit).
  static const int maxFramePayloadSize = 16;

  /// Generates a cryptographically secure random session nonce (default 16 bytes = 32 hex chars).
  static String generateSecureSessionNonce([int byteCount = 16]) {
    final random = Random.secure();
    final nonceBytes = List<int>.generate(byteCount, (_) => random.nextInt(256));
    return nonceBytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }
}

/// Verification status for an attendance evaluation.
enum PassportAttendanceStatus {
  verifiedPresent,
  proximityInconclusive,
  ownerMismatch,
  biometricRequired,
  cryptoInvalid,
  sessionExpired,
  unknownStudent,
  replayedResponse,
  fakeBeacon,
}

/// Explicit cryptographic verification status for teacher attendance beacons.
enum TeacherBeaconVerificationStatus {
  trustedAndVerified,
  trustBundleUnavailable,
  unknownKey,
  invalidSignature,
  expiredSession,
  invalidPayload,
}

/// Detailed outcome of verifying a teacher attendance beacon.
class TeacherBeaconVerificationResult {
  final bool isValid;
  final TeacherBeaconVerificationStatus status;
  final String reason;
  final PassportTrustIdentity? teacherIdentity;

  const TeacherBeaconVerificationResult({
    required this.isValid,
    required this.status,
    required this.reason,
    this.teacherIdentity,
  });

  String get code {
    switch (status) {
      case TeacherBeaconVerificationStatus.trustedAndVerified:
        return 'TRUSTED_AND_VERIFIED';
      case TeacherBeaconVerificationStatus.trustBundleUnavailable:
        return 'TRUST_BUNDLE_UNAVAILABLE';
      case TeacherBeaconVerificationStatus.unknownKey:
        return 'UNKNOWN_KEY';
      case TeacherBeaconVerificationStatus.invalidSignature:
        return 'INVALID_SIGNATURE';
      case TeacherBeaconVerificationStatus.expiredSession:
        return 'EXPIRED_SESSION';
      case TeacherBeaconVerificationStatus.invalidPayload:
        return 'INVALID_PAYLOAD';
    }
  }
}

/// 15-second Rolling PIN Generator & Validator for Zero-BLE Attendance.
class PassportRollingPinModel {
  static const int defaultWindowSeconds = 15;

  /// Generates a deterministic 4-digit PIN for the given session and window.
  static String generatePin({
    required String sessionId,
    required String sessionNonce,
    int? timestampSeconds,
    int windowSeconds = defaultWindowSeconds,
  }) {
    final nowSec = timestampSeconds ??
        (DateTime.now().toUtc().millisecondsSinceEpoch ~/ 1000);
    final window = nowSec ~/ windowSeconds;
    return _computePin(sessionId, sessionNonce, window);
  }

  /// Verifies an entered 4-digit PIN against current and adjacent windows (anti-drift skew).
  static bool verifyPin({
    required String enteredPin,
    required String sessionId,
    required String sessionNonce,
    int? timestampSeconds,
    int windowSeconds = defaultWindowSeconds,
    int allowedWindowSkew = 1,
  }) {
    final cleanPin = enteredPin.trim();
    if (cleanPin.length != 4) return false;
    final nowSec = timestampSeconds ??
        (DateTime.now().toUtc().millisecondsSinceEpoch ~/ 1000);
    final currentWindow = nowSec ~/ windowSeconds;

    for (int offset = -allowedWindowSkew; offset <= allowedWindowSkew; offset++) {
      final pin = _computePin(sessionId, sessionNonce, currentWindow + offset);
      if (pin == cleanPin) return true;
    }
    return false;
  }

  /// Seconds remaining before the current PIN expires and rotates.
  static int getRemainingSeconds({
    int? timestampSeconds,
    int windowSeconds = defaultWindowSeconds,
  }) {
    final nowSec = timestampSeconds ??
        (DateTime.now().toUtc().millisecondsSinceEpoch ~/ 1000);
    final remainder = nowSec % windowSeconds;
    return windowSeconds - remainder;
  }

  /// Fraction of window elapsed (0.0 -> 1.0) for circular UI timer.
  static double getProgress({
    int? timestampSeconds,
    int windowSeconds = defaultWindowSeconds,
  }) {
    final remaining = getRemainingSeconds(
      timestampSeconds: timestampSeconds,
      windowSeconds: windowSeconds,
    );
    return remaining / windowSeconds;
  }

  static String _computePin(String sessionId, String sessionNonce, int window) {
    final input = '$sessionId:$sessionNonce:$window';
    final bytes = utf8.encode(input);
    int hash = 0x811C9DC5;
    for (final b in bytes) {
      hash = ((hash ^ b) * 0x01000193) & 0xFFFFFFFF;
    }
    final pinNum = hash.abs() % 10000;
    return pinNum.toString().padLeft(4, '0');
  }
}

/// CampusOS Passport Teacher Attendance Beacon Model (Phase 1I).
///
/// Broadcast by the teacher over BLE or displayed as an active session QR code.
/// Cryptographically authenticates the session, teacher identity, and ephemeral nonce.
class PassportTeacherBeaconModel {
  final int protocolVersion;
  final String type;
  final String sessionId;
  final String teacherId;
  final String teacherKeyId;
  final String? course;
  final String? branch;
  final String? year;
  final String? subject;
  final String sessionNonce; // Minimum 16 random bytes (32 hex characters)
  final int issuedAt;
  final int expiresAt;
  final String signature; // Base64 Ed25519 signature
  final String? routerBssid;
  final String? localIp;
  final int? localPort;
  final String? hotspotSsid;
  final String? hotspotPassword;
  final double? teacherLatitude;
  final double? teacherLongitude;
  final double? teacherLocationAccuracy;

  const PassportTeacherBeaconModel({
    this.protocolVersion = PassportAttendanceModel.currentVersion,
    this.type = 'ATTENDANCE_BEACON',
    required this.sessionId,
    required this.teacherId,
    required this.teacherKeyId,
    this.course,
    this.branch,
    this.year,
    this.subject,
    required this.sessionNonce,
    required this.issuedAt,
    required this.expiresAt,
    this.signature = '',
    this.routerBssid,
    this.localIp,
    this.localPort,
    this.hotspotSsid,
    this.hotspotPassword,
    this.teacherLatitude,
    this.teacherLongitude,
    this.teacherLocationAccuracy,
  });

  /// Generates a new teacher attendance beacon with a cryptographically secure 16-byte random nonce.
  factory PassportTeacherBeaconModel.create({
    required String sessionId,
    required String teacherId,
    required String teacherKeyId,
    String? course,
    String? branch,
    String? year,
    String? subject,
    Duration validity = const Duration(minutes: 10),
    int? currentTimestampSeconds,
    String? customSessionNonce,
    String? routerBssid,
    String? localIp,
    int? localPort,
    String? hotspotSsid,
    String? hotspotPassword,
    double? teacherLatitude,
    double? teacherLongitude,
    double? teacherLocationAccuracy,
  }) {
    final nowSec = currentTimestampSeconds ??
        (DateTime.now().toUtc().millisecondsSinceEpoch ~/ 1000);
    final String sessionNonce;
    if (customSessionNonce != null && customSessionNonce.isNotEmpty) {
      sessionNonce = customSessionNonce;
    } else {
      final random = Random.secure();
      final nonceBytes = List<int>.generate(16, (_) => random.nextInt(256));
      sessionNonce =
          nonceBytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    }

    return PassportTeacherBeaconModel(
      protocolVersion: PassportAttendanceModel.currentVersion,
      type: 'ATTENDANCE_BEACON',
      sessionId: sessionId,
      teacherId: teacherId,
      teacherKeyId: teacherKeyId,
      course: course,
      branch: branch,
      year: year,
      subject: subject,
      sessionNonce: sessionNonce,
      issuedAt: nowSec,
      expiresAt: nowSec + validity.inSeconds,
      routerBssid: routerBssid,
      localIp: localIp,
      localPort: localPort,
      hotspotSsid: hotspotSsid,
      hotspotPassword: hotspotPassword,
      teacherLatitude: teacherLatitude,
      teacherLongitude: teacherLongitude,
      teacherLocationAccuracy: teacherLocationAccuracy,
    );
  }

  /// Checks if this beacon has expired.
  bool isExpired([int? currentTimestampSeconds]) {
    final now = currentTimestampSeconds ??
        (DateTime.now().toUtc().millisecondsSinceEpoch ~/ 1000);
    return now >= expiresAt;
  }

  /// Returns canonical JSON representation for signature generation and verification.
  String toCanonicalJson() {
    final map = <String, dynamic>{
      if (branch != null) 'branch': branch,
      if (course != null) 'course': course,
      'expiresAt': expiresAt,
      if (hotspotPassword != null) 'hotspotPassword': hotspotPassword,
      if (hotspotSsid != null) 'hotspotSsid': hotspotSsid,
      'issuedAt': issuedAt,
      if (localIp != null) 'localIp': localIp,
      if (localPort != null) 'localPort': localPort,
      'protocolVersion': protocolVersion,
      if (routerBssid != null) 'routerBssid': routerBssid,
      'sessionId': sessionId,
      'sessionNonce': sessionNonce,
      if (subject != null) 'subject': subject,
      'teacherId': teacherId,
      'teacherKeyId': teacherKeyId,
      if (teacherLatitude != null) 'teacherLatitude': teacherLatitude,
      if (teacherLocationAccuracy != null) 'teacherLocationAccuracy': teacherLocationAccuracy,
      if (teacherLongitude != null) 'teacherLongitude': teacherLongitude,
      'type': type,
      if (year != null) 'year': year,
    };
    return canonicalizeJson(map);
  }

  /// Creates a copy with a signature.
  PassportTeacherBeaconModel withSignature(String signature) {
    return PassportTeacherBeaconModel(
      protocolVersion: protocolVersion,
      type: type,
      sessionId: sessionId,
      teacherId: teacherId,
      teacherKeyId: teacherKeyId,
      course: course,
      branch: branch,
      year: year,
      subject: subject,
      sessionNonce: sessionNonce,
      issuedAt: issuedAt,
      expiresAt: expiresAt,
      signature: signature,
      routerBssid: routerBssid,
      localIp: localIp,
      localPort: localPort,
      hotspotSsid: hotspotSsid,
      hotspotPassword: hotspotPassword,
      teacherLatitude: teacherLatitude,
      teacherLongitude: teacherLongitude,
      teacherLocationAccuracy: teacherLocationAccuracy,
    );
  }

  PassportTeacherBeaconModel copyWith({
    int? protocolVersion,
    String? type,
    String? sessionId,
    String? teacherId,
    String? teacherKeyId,
    String? course,
    String? branch,
    String? year,
    String? subject,
    String? sessionNonce,
    int? issuedAt,
    int? expiresAt,
    String? signature,
    String? routerBssid,
    String? localIp,
    int? localPort,
    String? hotspotSsid,
    String? hotspotPassword,
    double? teacherLatitude,
    double? teacherLongitude,
    double? teacherLocationAccuracy,
  }) {
    return PassportTeacherBeaconModel(
      protocolVersion: protocolVersion ?? this.protocolVersion,
      type: type ?? this.type,
      sessionId: sessionId ?? this.sessionId,
      teacherId: teacherId ?? this.teacherId,
      teacherKeyId: teacherKeyId ?? this.teacherKeyId,
      course: course ?? this.course,
      branch: branch ?? this.branch,
      year: year ?? this.year,
      subject: subject ?? this.subject,
      sessionNonce: sessionNonce ?? this.sessionNonce,
      issuedAt: issuedAt ?? this.issuedAt,
      expiresAt: expiresAt ?? this.expiresAt,
      signature: signature ?? this.signature,
      routerBssid: routerBssid ?? this.routerBssid,
      localIp: localIp ?? this.localIp,
      localPort: localPort ?? this.localPort,
      hotspotSsid: hotspotSsid ?? this.hotspotSsid,
      hotspotPassword: hotspotPassword ?? this.hotspotPassword,
      teacherLatitude: teacherLatitude ?? this.teacherLatitude,
      teacherLongitude: teacherLongitude ?? this.teacherLongitude,
      teacherLocationAccuracy:
          teacherLocationAccuracy ?? this.teacherLocationAccuracy,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'protocolVersion': protocolVersion,
      'type': type,
      'sessionId': sessionId,
      'teacherId': teacherId,
      'teacherKeyId': teacherKeyId,
      if (course != null) 'course': course,
      if (branch != null) 'branch': branch,
      if (year != null) 'year': year,
      if (subject != null) 'subject': subject,
      'sessionNonce': sessionNonce,
      'issuedAt': issuedAt,
      'expiresAt': expiresAt,
      'signature': signature,
      if (routerBssid != null) 'routerBssid': routerBssid,
      if (localIp != null) 'localIp': localIp,
      if (localPort != null) 'localPort': localPort,
      if (hotspotSsid != null) 'hotspotSsid': hotspotSsid,
      if (hotspotPassword != null) 'hotspotPassword': hotspotPassword,
      if (teacherLatitude != null) 'teacherLatitude': teacherLatitude,
      if (teacherLongitude != null) 'teacherLongitude': teacherLongitude,
      if (teacherLocationAccuracy != null) 'teacherLocationAccuracy': teacherLocationAccuracy,
    };
  }

  factory PassportTeacherBeaconModel.fromMap(Map<String, dynamic> map) {
    return PassportTeacherBeaconModel(
      protocolVersion: map['protocolVersion'] is int
          ? map['protocolVersion'] as int
          : (map['v'] is int
              ? map['v'] as int
              : int.tryParse(map['protocolVersion']?.toString() ?? map['v']?.toString() ?? '1') ?? 1),
      type: (map['type']?.toString() == 'ATTENDANCE_BEACON' || map['t']?.toString() == 'BEACON')
          ? 'ATTENDANCE_BEACON'
          : (map['type']?.toString() ?? map['t']?.toString() ?? 'ATTENDANCE_BEACON'),
      sessionId: map['sessionId']?.toString() ?? map['sid']?.toString() ?? '',
      teacherId: map['teacherId']?.toString() ?? map['tid']?.toString() ?? '',
      teacherKeyId: map['teacherKeyId']?.toString() ?? map['tkid']?.toString() ?? '',
      course: map['course']?.toString() ?? map['crs']?.toString(),
      branch: map['branch']?.toString() ?? map['br']?.toString(),
      year: map['year']?.toString() ?? map['yr']?.toString(),
      subject: map['subject']?.toString() ?? map['sub']?.toString(),
      sessionNonce: map['sessionNonce']?.toString() ?? map['sn']?.toString() ?? '',
      issuedAt: (map['issuedAt'] is int)
          ? map['issuedAt'] as int
          : (map['iat'] is int
              ? map['iat'] as int
              : int.tryParse(map['issuedAt']?.toString() ?? map['iat']?.toString() ?? '0') ?? 0),
      expiresAt: (map['expiresAt'] is int)
          ? map['expiresAt'] as int
          : (map['exp'] is int
              ? map['exp'] as int
              : int.tryParse(map['expiresAt']?.toString() ?? map['exp']?.toString() ?? '0') ?? 0),
      signature: map['signature']?.toString() ?? map['s']?.toString() ?? '',
      routerBssid: map['routerBssid']?.toString() ?? map['rb']?.toString(),
      localIp: map['localIp']?.toString() ?? map['lip']?.toString(),
      localPort: map['localPort'] is int
          ? map['localPort'] as int
          : int.tryParse(map['localPort']?.toString() ?? map['lp']?.toString() ?? ''),
      hotspotSsid: map['hotspotSsid']?.toString() ?? map['hs']?.toString(),
      hotspotPassword: map['hotspotPassword']?.toString() ?? map['hp']?.toString(),
      teacherLatitude: (map['teacherLatitude'] as num?)?.toDouble() ??
          (map['tlat'] as num?)?.toDouble() ??
          double.tryParse(map['teacherLatitude']?.toString() ?? map['tlat']?.toString() ?? ''),
      teacherLongitude: (map['teacherLongitude'] as num?)?.toDouble() ??
          (map['tlng'] as num?)?.toDouble() ??
          double.tryParse(map['teacherLongitude']?.toString() ?? map['tlng']?.toString() ?? ''),
      teacherLocationAccuracy: (map['teacherLocationAccuracy'] as num?)?.toDouble() ??
          (map['tacc'] as num?)?.toDouble() ??
          double.tryParse(map['teacherLocationAccuracy']?.toString() ?? map['tacc']?.toString() ?? ''),
    );
  }

  /// Compact map representation for efficient BLE advertising.
  Map<String, dynamic> toCompactMap() => {
    'v': protocolVersion,
    't': 'BEACON',
    'sid': sessionId,
    'tid': teacherId,
    'tkid': teacherKeyId,
    if (course != null) 'crs': course,
    if (branch != null) 'br': branch,
    if (year != null) 'yr': year,
    if (subject != null) 'sub': subject,
    'sn': sessionNonce,
    'iat': issuedAt,
    'exp': expiresAt,
    's': signature,
    if (routerBssid != null) 'rb': routerBssid,
    if (localIp != null) 'lip': localIp,
    if (localPort != null) 'lp': localPort,
    if (hotspotSsid != null) 'hs': hotspotSsid,
    if (hotspotPassword != null) 'hp': hotspotPassword,
    if (teacherLatitude != null) 'tlat': teacherLatitude,
    if (teacherLongitude != null) 'tlng': teacherLongitude,
    if (teacherLocationAccuracy != null) 'tacc': teacherLocationAccuracy,
  };

  /// Compact QR code representation for optical line-of-sight attendance presentation.
  /// If dynamicWindowSeconds > 0, binds the optical token to a rotating window to prevent photographed QR relay.
  /// If dynamicWindowSeconds <= 0 (default), preserves the canonical signed issuedAt and expiresAt timestamps.
  String toQrString({int dynamicWindowSeconds = 0}) {
    final now = DateTime.now().toUtc().millisecondsSinceEpoch ~/ 1000;
    final bool useDynamic = dynamicWindowSeconds > 0;
    final windowIndex = useDynamic ? (now ~/ dynamicWindowSeconds) : null;
    final dynamicExp = useDynamic ? ((windowIndex! + 1) * dynamicWindowSeconds + 5) : null;
    return jsonEncode({
      'p': {
        'v': protocolVersion,
        't': 'BEACON',
        'sid': sessionId,
        'tid': teacherId,
        'tkid': teacherKeyId,
        'sn': sessionNonce,
        'iat': useDynamic ? now : issuedAt,
        'exp': useDynamic ? dynamicExp! : expiresAt,
        if (windowIndex != null) 'w': windowIndex,
        if (subject != null) 'sub': subject,
        if (routerBssid != null) 'rb': routerBssid,
        if (localIp != null) 'lip': localIp,
        if (localPort != null) 'lp': localPort,
        if (hotspotSsid != null) 'hs': hotspotSsid,
        if (hotspotPassword != null) 'hp': hotspotPassword,
        if (teacherLatitude != null) 'tlat': teacherLatitude,
        if (teacherLongitude != null) 'tlng': teacherLongitude,
        if (teacherLocationAccuracy != null) 'tacc': teacherLocationAccuracy,
      },
      's': signature,
    });
  }

  /// Deserializes a beacon from QR string.
  factory PassportTeacherBeaconModel.fromQrString(String qrString) {
    final decoded = jsonDecode(qrString.trim()) as Map<String, dynamic>;
    if (!decoded.containsKey('p') || decoded['p'] is! Map<String, dynamic>) {
      throw const FormatException('Missing or invalid beacon payload structure');
    }
    final p = decoded['p'] as Map<String, dynamic>;
    if (!p.containsKey('sid') || !p.containsKey('tid') || !p.containsKey('sn')) {
      throw const FormatException('Missing required fields (sid, tid, sn) in beacon payload');
    }
    final s = decoded['s']?.toString() ?? '';

    return PassportTeacherBeaconModel(
      protocolVersion: p['v'] is int ? p['v'] as int : 1,
      type: 'ATTENDANCE_BEACON',
      sessionId: p['sid']?.toString() ?? '',
      teacherId: p['tid']?.toString() ?? '',
      teacherKeyId: p['tkid']?.toString() ?? '',
      subject: p['sub']?.toString(),
      sessionNonce: p['sn']?.toString() ?? '',
      issuedAt: (p['iat'] is int)
          ? p['iat'] as int
          : int.tryParse(p['iat']?.toString() ?? '0') ?? 0,
      expiresAt: (p['exp'] is int)
          ? p['exp'] as int
          : int.tryParse(p['exp']?.toString() ?? '0') ?? 0,
      signature: s,
      routerBssid: p['rb']?.toString(),
      localIp: p['lip']?.toString(),
      localPort: p['lp'] is int ? p['lp'] as int : int.tryParse(p['lp']?.toString() ?? ''),
      hotspotSsid: p['hs']?.toString(),
      hotspotPassword: p['hp']?.toString(),
      teacherLatitude: (p['tlat'] as num?)?.toDouble() ??
          double.tryParse(p['tlat']?.toString() ?? ''),
      teacherLongitude: (p['tlng'] as num?)?.toDouble() ??
          double.tryParse(p['tlng']?.toString() ?? ''),
      teacherLocationAccuracy: (p['tacc'] as num?)?.toDouble() ??
          double.tryParse(p['tacc']?.toString() ?? ''),
    );
  }

  /// Splits the serialized beacon into sequenced 24-byte BLE advertisement frames
  /// using a deterministic 32-bit streamId.
  List<Uint8List> toBleFrames([int? customStreamId]) {
    final jsonStr = jsonEncode(toCompactMap());
    final rawBytes = utf8.encode(jsonStr);
    final streamId = customStreamId ??
        PassportBleFrame.computeStreamId('$sessionId:$sessionNonce');
    return PassportBleFrame.fragment(
      frameType: PassportAttendanceModel.frameTypeBeacon,
      streamId: streamId,
      data: Uint8List.fromList(rawBytes),
    );
  }

  /// Reassembles a beacon from collected BLE advertisement frames.
  static PassportTeacherBeaconModel? fromBleFrames(List<Uint8List> frames, [int? expectedStreamId]) {
    final assembled = PassportBleFrame.reassemble(frames, expectedStreamId: expectedStreamId);
    if (assembled == null) return null;
    try {
      final jsonStr = utf8.decode(assembled);
      final map = jsonDecode(jsonStr) as Map<String, dynamic>;
      return PassportTeacherBeaconModel.fromMap(map);
    } catch (_) {
      return null;
    }
  }
}

/// CampusOS Passport Student Attendance Response Model (Phase 1I).
///
/// Created ONLY after successful biometric-only authentication.
/// Signed using the student's device-bound Ed25519 private key.
/// Bound to the teacher's session nonce to prevent replay attacks.
class PassportAttendanceResponseModel {
  final int version;
  final String type;
  final String sessionId;
  final String studentId;
  final String deviceKeyId;
  final String challengeNonce;
  final int issuedAt;
  final int expiresAt;
  final bool biometricGate;
  final String responseNonce; // Ephemeral 8-byte random nonce (16 hex chars)
  final String signature;
  final String verificationMode; // 'BLE_BATCH', 'WIFI_LAN', 'WIFI_HOTSPOT', 'QR_OPTICAL', 'PIN_MANUAL'
  final String? routerBssid;
  final double? latitude;
  final double? longitude;
  final double? gpsAccuracy;
  final bool isMockedGps;

  const PassportAttendanceResponseModel({
    this.version = PassportAttendanceModel.currentVersion,
    this.type = 'ATTENDANCE_RESPONSE',
    required this.sessionId,
    required this.studentId,
    required this.deviceKeyId,
    required this.challengeNonce,
    required this.issuedAt,
    required this.expiresAt,
    this.biometricGate = true,
    required this.responseNonce,
    this.signature = '',
    this.verificationMode = PassportAttendanceModel.modeBle,
    this.routerBssid,
    this.latitude,
    this.longitude,
    this.gpsAccuracy,
    this.isMockedGps = false,
  });

  /// Factory creating an unsigned response structure ready for canonical signing.
  factory PassportAttendanceResponseModel.create({
    required String sessionId,
    required String studentId,
    required String deviceKeyId,
    required String challengeNonce,
    Duration validity = const Duration(seconds: 20),
    int? currentTimestampSeconds,
    String verificationMode = PassportAttendanceModel.modeBle,
    String? routerBssid,
    String? customResponseNonce,
    double? latitude,
    double? longitude,
    double? gpsAccuracy,
    bool isMockedGps = false,
  }) {
    final nowSec = currentTimestampSeconds ??
        (DateTime.now().toUtc().millisecondsSinceEpoch ~/ 1000);
    final random = Random.secure();
    final nonceBytes = List<int>.generate(8, (_) => random.nextInt(256));
    final nonceHex = customResponseNonce ??
        nonceBytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();

    return PassportAttendanceResponseModel(
      version: PassportAttendanceModel.currentVersion,
      type: 'ATTENDANCE_RESPONSE',
      sessionId: sessionId,
      studentId: studentId,
      deviceKeyId: deviceKeyId,
      challengeNonce: challengeNonce,
      issuedAt: nowSec,
      expiresAt: nowSec + validity.inSeconds,
      biometricGate: true,
      responseNonce: nonceHex,
      verificationMode: verificationMode,
      routerBssid: routerBssid,
      latitude: latitude,
      longitude: longitude,
      gpsAccuracy: gpsAccuracy,
      isMockedGps: isMockedGps,
    );
  }

  /// Whether this attendance response has expired.
  bool isExpired([int? currentTimestampSeconds]) {
    final now = currentTimestampSeconds ??
        (DateTime.now().toUtc().millisecondsSinceEpoch ~/ 1000);
    return now >= expiresAt;
  }

  /// Produces deterministic, canonical JSON representation of payload for signing.
  String toCanonicalJson() {
    final map = <String, dynamic>{
      'biometricGate': biometricGate,
      'challengeNonce': challengeNonce,
      'deviceKeyId': deviceKeyId,
      'expiresAt': expiresAt,
      if (gpsAccuracy != null) 'gpsAccuracy': gpsAccuracy,
      if (isMockedGps) 'isMockedGps': isMockedGps,
      'issuedAt': issuedAt,
      if (latitude != null) 'latitude': latitude,
      if (longitude != null) 'longitude': longitude,
      'responseNonce': responseNonce,
      if (routerBssid != null) 'routerBssid': routerBssid,
      'sessionId': sessionId,
      'studentId': studentId,
      'type': type,
      'verificationMode': verificationMode,
      'version': version,
    };
    return canonicalizeJson(map);
  }

  /// Derives an idempotency key from session ID, device key ID, and response nonce.
  String get derivedIdempotencyKey {
    return 'att_${sessionId}_${deviceKeyId}_$responseNonce';
  }

  String get idempotencyKey => derivedIdempotencyKey;

  /// Returns a copy with signature attached.
  PassportAttendanceResponseModel withSignature(String signature) {
    return PassportAttendanceResponseModel(
      version: version,
      type: type,
      sessionId: sessionId,
      studentId: studentId,
      deviceKeyId: deviceKeyId,
      challengeNonce: challengeNonce,
      issuedAt: issuedAt,
      expiresAt: expiresAt,
      biometricGate: biometricGate,
      responseNonce: responseNonce,
      signature: signature,
      verificationMode: verificationMode,
      routerBssid: routerBssid,
      latitude: latitude,
      longitude: longitude,
      gpsAccuracy: gpsAccuracy,
      isMockedGps: isMockedGps,
    );
  }

  PassportAttendanceResponseModel copyWith({
    int? version,
    String? type,
    String? sessionId,
    String? studentId,
    String? deviceKeyId,
    String? challengeNonce,
    int? issuedAt,
    int? expiresAt,
    bool? biometricGate,
    String? responseNonce,
    String? signature,
    String? verificationMode,
    String? routerBssid,
    double? latitude,
    double? longitude,
    double? gpsAccuracy,
    bool? isMockedGps,
  }) {
    return PassportAttendanceResponseModel(
      version: version ?? this.version,
      type: type ?? this.type,
      sessionId: sessionId ?? this.sessionId,
      studentId: studentId ?? this.studentId,
      deviceKeyId: deviceKeyId ?? this.deviceKeyId,
      challengeNonce: challengeNonce ?? this.challengeNonce,
      issuedAt: issuedAt ?? this.issuedAt,
      expiresAt: expiresAt ?? this.expiresAt,
      biometricGate: biometricGate ?? this.biometricGate,
      responseNonce: responseNonce ?? this.responseNonce,
      signature: signature ?? this.signature,
      verificationMode: verificationMode ?? this.verificationMode,
      routerBssid: routerBssid ?? this.routerBssid,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      gpsAccuracy: gpsAccuracy ?? this.gpsAccuracy,
      isMockedGps: isMockedGps ?? this.isMockedGps,
    );
  }

  /// Cryptographically signs this response using the device private key.
  Future<PassportAttendanceResponseModel> sign(PassportCryptoService crypto) async {
    final canonical = toCanonicalJson();
    final sig = await crypto.signPresentation(canonical);
    return withSignature(sig);
  }

  Map<String, dynamic> toMap() {
    return {
      'version': version,
      'type': type,
      'sessionId': sessionId,
      'studentId': studentId,
      'deviceKeyId': deviceKeyId,
      'challengeNonce': challengeNonce,
      'issuedAt': issuedAt,
      'expiresAt': expiresAt,
      'biometricGate': biometricGate,
      'responseNonce': responseNonce,
      'signature': signature,
      'verificationMode': verificationMode,
      if (routerBssid != null) 'routerBssid': routerBssid,
      if (latitude != null) 'latitude': latitude,
      if (longitude != null) 'longitude': longitude,
      if (gpsAccuracy != null) 'gpsAccuracy': gpsAccuracy,
      if (isMockedGps) 'isMockedGps': isMockedGps,
    };
  }

  factory PassportAttendanceResponseModel.fromMap(Map<String, dynamic> map) {
    return PassportAttendanceResponseModel(
      version: map['version'] is int
          ? map['version'] as int
          : (map['v'] is int
              ? map['v'] as int
              : int.tryParse(map['protocolVersion']?.toString() ?? map['v']?.toString() ?? '1') ?? 1),
      type: (map['type']?.toString() == 'ATTENDANCE_RESPONSE' || map['t']?.toString() == 'ATT_RESP')
          ? 'ATTENDANCE_RESPONSE'
          : (map['type']?.toString() ?? map['t']?.toString() ?? 'ATTENDANCE_RESPONSE'),
      sessionId: map['sessionId']?.toString() ?? map['sid']?.toString() ?? '',
      studentId: map['studentId']?.toString() ?? map['uid']?.toString() ?? '',
      deviceKeyId: map['deviceKeyId']?.toString() ?? map['kid']?.toString() ?? '',
      challengeNonce: map['challengeNonce']?.toString() ?? map['cn']?.toString() ?? '',
      issuedAt: (map['issuedAt'] is int)
          ? map['issuedAt'] as int
          : (map['iat'] is int
              ? map['iat'] as int
              : int.tryParse(map['issuedAt']?.toString() ?? map['iat']?.toString() ?? '0') ?? 0),
      expiresAt: (map['expiresAt'] is int)
          ? map['expiresAt'] as int
          : (map['exp'] is int
              ? map['exp'] as int
              : int.tryParse(map['expiresAt']?.toString() ?? map['exp']?.toString() ?? '0') ?? 0),
      biometricGate: map['biometricGate'] == true ||
          map['bio'] == true ||
          map['biometricGate']?.toString().toLowerCase() == 'true' ||
          map['bio']?.toString().toLowerCase() == 'true',
      responseNonce: map['responseNonce']?.toString() ?? map['rn']?.toString() ?? '',
      signature: map['signature']?.toString() ?? map['s']?.toString() ?? '',
      verificationMode: map['verificationMode']?.toString() ?? map['vm']?.toString() ?? PassportAttendanceModel.modeBle,
      routerBssid: map['routerBssid']?.toString() ?? map['rb']?.toString(),
      latitude: (map['latitude'] as num?)?.toDouble() ??
          (map['lat'] as num?)?.toDouble() ??
          double.tryParse(map['latitude']?.toString() ?? map['lat']?.toString() ?? ''),
      longitude: (map['longitude'] as num?)?.toDouble() ??
          (map['lng'] as num?)?.toDouble() ??
          double.tryParse(map['longitude']?.toString() ?? map['lng']?.toString() ?? ''),
      gpsAccuracy: (map['gpsAccuracy'] as num?)?.toDouble() ??
          (map['acc'] as num?)?.toDouble() ??
          double.tryParse(map['gpsAccuracy']?.toString() ?? map['acc']?.toString() ?? ''),
      isMockedGps: map['isMockedGps'] == true ||
          map['mgps'] == true ||
          map['isMockedGps']?.toString().toLowerCase() == 'true' ||
          map['mgps']?.toString().toLowerCase() == 'true',
    );
  }

  /// Compact map representation for efficient BLE advertising.
  Map<String, dynamic> toCompactMap() => {
    'v': version,
    't': 'ATT_RESP',
    'sid': sessionId,
    'uid': studentId,
    'kid': deviceKeyId,
    'cn': challengeNonce,
    'iat': issuedAt,
    'exp': expiresAt,
    'bio': biometricGate,
    'rn': responseNonce,
    's': signature,
    'vm': verificationMode,
    if (routerBssid != null) 'rb': routerBssid,
    if (latitude != null) 'lat': latitude,
    if (longitude != null) 'lng': longitude,
    if (gpsAccuracy != null) 'acc': gpsAccuracy,
    if (isMockedGps) 'mgps': isMockedGps,
  };

  /// Compact QR representation for QR fallback exception path.
  String toQrString() {
    return jsonEncode({
      'p': {
        'v': version,
        't': 'ATT_RESP',
        'sid': sessionId,
        'uid': studentId,
        'kid': deviceKeyId,
        'cn': challengeNonce,
        'rn': responseNonce,
        'iat': issuedAt,
        'exp': expiresAt,
        'bio': biometricGate,
        'vm': verificationMode,
        if (routerBssid != null) 'rb': routerBssid,
        if (latitude != null) 'lat': latitude,
        if (longitude != null) 'lng': longitude,
        if (gpsAccuracy != null) 'acc': gpsAccuracy,
        if (isMockedGps) 'mgps': isMockedGps,
      },
      's': signature,
    });
  }

  /// Deserializes response from QR string.
  factory PassportAttendanceResponseModel.fromQrString(String qrString) {
    final decoded = jsonDecode(qrString.trim()) as Map<String, dynamic>;
    final p = decoded['p'] as Map<String, dynamic>;
    final s = decoded['s']?.toString() ?? '';

    return PassportAttendanceResponseModel(
      version: p['v'] is int ? p['v'] as int : 1,
      type: 'ATTENDANCE_RESPONSE',
      sessionId: p['sid']?.toString() ?? '',
      studentId: p['uid']?.toString() ?? '',
      deviceKeyId: p['kid']?.toString() ?? '',
      challengeNonce: p['cn']?.toString() ?? '',
      responseNonce: p['rn']?.toString() ?? '',
      issuedAt: (p['iat'] is int)
          ? p['iat'] as int
          : int.tryParse(p['iat']?.toString() ?? '0') ?? 0,
      expiresAt: (p['exp'] is int)
          ? p['exp'] as int
          : int.tryParse(p['exp']?.toString() ?? '0') ?? 0,
      biometricGate: p['bio'] == true || p['bio']?.toString() == 'true',
      signature: s,
      verificationMode: p['vm']?.toString() ?? PassportAttendanceModel.modeQrOptical,
      routerBssid: p['rb']?.toString(),
      latitude: (p['lat'] as num?)?.toDouble() ??
          double.tryParse(p['lat']?.toString() ?? ''),
      longitude: (p['lng'] as num?)?.toDouble() ??
          double.tryParse(p['lng']?.toString() ?? ''),
      gpsAccuracy: (p['acc'] as num?)?.toDouble() ??
          double.tryParse(p['acc']?.toString() ?? ''),
      isMockedGps: p['mgps'] == true || p['mgps']?.toString() == 'true',
    );
  }

  /// Splits response into sequenced 24-byte BLE advertisement frames using
  /// a deterministic 32-bit streamId derived from sessionId, studentId, and responseNonce.
  List<Uint8List> toBleFrames([int? customStreamId]) {
    final jsonStr = jsonEncode(toCompactMap());
    final rawBytes = utf8.encode(jsonStr);
    final streamId = customStreamId ??
        PassportBleFrame.computeStreamId('$sessionId:$studentId:$responseNonce');
    return PassportBleFrame.fragment(
      frameType: PassportAttendanceModel.frameTypeResponse,
      streamId: streamId,
      data: Uint8List.fromList(rawBytes),
    );
  }

  /// Reassembles a response from BLE advertisement frames.
  static PassportAttendanceResponseModel? fromBleFrames(List<Uint8List> frames, [int? expectedStreamId]) {
    final assembled = PassportBleFrame.reassemble(frames, expectedStreamId: expectedStreamId);
    if (assembled == null) return null;
    try {
      final jsonStr = utf8.decode(assembled);
      final map = jsonDecode(jsonStr) as Map<String, dynamic>;
      return PassportAttendanceResponseModel.fromMap(map);
    } catch (_) {
      return null;
    }
  }
}

/// BLE advertisement frame fragmentation and reassembly utility.
///
/// Encodes arbitrarily sized payloads across multiple legacy-compatible
/// 24-byte advertisement chunks with collision-resistant 32-bit stream IDs.
///
/// Header (8 bytes):
/// - [0] 0xCA (Magic byte)
/// - [1] Frame Type (0x01: Beacon, 0x02: Response)
/// - [2..5] Stream ID (32-bit unsigned big-endian integer, 2^32 entropy)
/// - [6] frameIndex (0..totalFrames-1)
/// - [7] totalFrames (1..255)
/// Data (up to 16 bytes):
/// - [8..23] Chunk payload
class PassportBleFrame {
  static const int headerSize = 8;
  static const int maxFrames = 255;

  static bool isPassportFrame(Uint8List frame) =>
      frame.length >= headerSize && frame[0] == PassportAttendanceModel.bleFrameMagic;

  /// Computes a deterministic 32-bit FNV-1a stream identifier from input string.
  /// Provides 4.29 billion possible stream IDs, reducing collision probability
  /// among 60 simultaneous students to < 0.00005%.
  static int computeStreamId(String input) {
    int hash = 0x811C9DC5;
    final bytes = utf8.encode(input);
    for (final b in bytes) {
      hash = ((hash ^ b) * 0x01000193) & 0xFFFFFFFF;
    }
    return hash;
  }

  /// Extracts the frame type from a BLE frame.
  static int extractFrameType(Uint8List frame) {
    if (frame.length < 2) return 0;
    return frame[1];
  }

  /// Extracts the 32-bit big-endian streamId from a BLE frame.
  static int extractStreamId(Uint8List frame) {
    if (frame.length < 6) return 0;
    return ((frame[2] & 0xFF) << 24) |
           ((frame[3] & 0xFF) << 16) |
           ((frame[4] & 0xFF) << 8) |
           (frame[5] & 0xFF);
  }

  /// Extracts the 8-bit frame index.
  static int extractFrameIndex(Uint8List frame) {
    if (frame.length < 7) return 0;
    return frame[6] & 0xFF;
  }

  /// Extracts the 8-bit total frame count.
  static int extractTotalFrames(Uint8List frame) {
    if (frame.length < 8) return 0;
    return frame[7] & 0xFF;
  }

  /// Extracts the payload chunk from a BLE frame.
  static Uint8List extractPayload(Uint8List frame) {
    if (frame.length <= headerSize) return Uint8List(0);
    return frame.sublist(headerSize);
  }

  /// Fragments payload data into sequenced BLE frames of at most 24 bytes each.
  static List<Uint8List> fragment({
    required int frameType,
    required int streamId,
    required Uint8List data,
    int chunkSize = PassportAttendanceModel.maxFramePayloadSize,
  }) {
    if (data.isEmpty) return [];
    final totalFrames = (data.length / chunkSize).ceil();
    if (totalFrames > maxFrames) {
      throw ArgumentError('Payload too large to fit in $maxFrames BLE frames ($totalFrames frames)');
    }

    final frames = <Uint8List>[];
    for (int i = 0; i < totalFrames; i++) {
      final start = i * chunkSize;
      final end = min(start + chunkSize, data.length);
      final slice = data.sublist(start, end);

      final frame = Uint8List(headerSize + slice.length);
      frame[0] = PassportAttendanceModel.bleFrameMagic;
      frame[1] = frameType;
      frame[2] = (streamId >> 24) & 0xFF;
      frame[3] = (streamId >> 16) & 0xFF;
      frame[4] = (streamId >> 8) & 0xFF;
      frame[5] = streamId & 0xFF;
      frame[6] = i & 0xFF;
      frame[7] = totalFrames & 0xFF;
      frame.setRange(headerSize, headerSize + slice.length, slice);
      frames.add(frame);
    }
    return frames;
  }

  /// Reassembles sequenced BLE frames belonging to a single stream.
  ///
  /// Rejects frames with mismatched magic, wrong length, mismatched streamId,
  /// duplicate indices, or missing frames.
  static Uint8List? reassemble(List<Uint8List> frames, {int? expectedStreamId}) {
    if (frames.isEmpty) return null;

    // Filter valid frames
    final validFrames = <Uint8List>[];
    int? streamId;
    int? totalFrames;
    int? frameType;

    for (final f in frames) {
      if (f.length < headerSize || f[0] != PassportAttendanceModel.bleFrameMagic) {
        continue;
      }
      final fStreamId = extractStreamId(f);
      final fTotal = extractTotalFrames(f);
      final fType = extractFrameType(f);

      if (fTotal == 0) continue;

      if (expectedStreamId != null && fStreamId != expectedStreamId) {
        // Discard frames that do not match expected stream
        continue;
      }

      if (streamId == null) {
        streamId = fStreamId;
        totalFrames = fTotal;
        frameType = fType;
      } else if (fStreamId != streamId || fTotal != totalFrames || fType != frameType) {
        // Discard frames from different stream/packet to prevent interleaving corruption
        continue;
      }

      validFrames.add(f);
    }

    if (validFrames.isEmpty || totalFrames == null || totalFrames == 0) {
      return null;
    }

    // Deduplicate by frameIndex
    final Map<int, Uint8List> chunksByIndex = {};
    for (final f in validFrames) {
      final idx = extractFrameIndex(f);
      if (idx < totalFrames && !chunksByIndex.containsKey(idx)) {
        chunksByIndex[idx] = extractPayload(f);
      }
    }

    // Must have all frames from 0 to totalFrames - 1
    if (chunksByIndex.length != totalFrames) {
      return null; // Missing fragments
    }

    // Calculate total size and assemble
    int totalBytes = 0;
    for (int i = 0; i < totalFrames; i++) {
      final chunk = chunksByIndex[i];
      if (chunk == null) return null; // Gap detected
      totalBytes += chunk.length;
    }

    final result = Uint8List(totalBytes);
    int offset = 0;
    for (int i = 0; i < totalFrames; i++) {
      final chunk = chunksByIndex[i]!;
      result.setRange(offset, offset + chunk.length, chunk);
      offset += chunk.length;
    }
    return result;
  }
}

/// Verification result representing the outcome of verifying an attendance response.
class PassportAttendanceVerificationResult {
  final bool valid;
  final PassportAttendanceStatus status;
  final String reason;
  final String? studentId;
  final String? studentName;
  final String? deviceKeyId;
  final String? sessionId;
  final String? responseNonce;
  final String? idempotencyKey;
  final PassportProximityTier proximityTier;
  final int? medianRssi;
  final String verificationMode; // 'BLE_BATCH', 'WIFI_LAN', 'WIFI_HOTSPOT', 'QR_OPTICAL', 'PIN_MANUAL'
  final DateTime verifiedAt;
  final String? routerBssid;
  final double? gpsDistanceMeters;
  final String? gpsStatus; // 'VERIFIED', 'MOCK_DETECTED', 'OUTSIDE_GEOFENCE', 'UNAVAILABLE', 'INDOOR_DRIFT'

  const PassportAttendanceVerificationResult({
    required this.valid,
    required this.status,
    required this.reason,
    this.studentId,
    this.studentName,
    this.deviceKeyId,
    this.sessionId,
    this.responseNonce,
    this.idempotencyKey,
    this.proximityTier = PassportProximityTier.unknown,
    this.medianRssi,
    this.verificationMode = PassportAttendanceModel.modeBle,
    required this.verifiedAt,
    this.routerBssid,
    this.gpsDistanceMeters,
    this.gpsStatus,
  });

  Map<String, dynamic> toMap() {
    return {
      'valid': valid,
      'status': status.name,
      'reason': reason,
      'studentId': studentId,
      'studentName': studentName,
      'deviceKeyId': deviceKeyId,
      'sessionId': sessionId,
      'responseNonce': responseNonce,
      'idempotencyKey': idempotencyKey,
      'proximityTier': proximityTier.code,
      'medianRssi': medianRssi,
      'verificationMode': verificationMode,
      'verifiedAt': verifiedAt.toIso8601String(),
      if (routerBssid != null) 'routerBssid': routerBssid,
      if (gpsDistanceMeters != null) 'gpsDistanceMeters': gpsDistanceMeters,
      if (gpsStatus != null) 'gpsStatus': gpsStatus,
    };
  }

  factory PassportAttendanceVerificationResult.fromMap(Map<String, dynamic> map) {
    return PassportAttendanceVerificationResult(
      valid: map['valid'] == true,
      status: PassportAttendanceStatus.values.firstWhere(
        (e) => e.name == map['status'],
        orElse: () => PassportAttendanceStatus.cryptoInvalid,
      ),
      reason: map['reason']?.toString() ?? '',
      studentId: map['studentId']?.toString(),
      studentName: map['studentName']?.toString(),
      deviceKeyId: map['deviceKeyId']?.toString(),
      sessionId: map['sessionId']?.toString(),
      responseNonce: map['responseNonce']?.toString(),
      idempotencyKey: map['idempotencyKey']?.toString(),
      proximityTier: PassportProximityTier.values.firstWhere(
        (e) => e.code == map['proximityTier'],
        orElse: () => PassportProximityTier.unknown,
      ),
      medianRssi: map['medianRssi'] is int ? map['medianRssi'] as int : null,
      verificationMode: map['verificationMode']?.toString() ?? PassportAttendanceModel.modeBle,
      verifiedAt: DateTime.tryParse(map['verifiedAt']?.toString() ?? '') ??
          DateTime.now(),
      routerBssid: map['routerBssid']?.toString(),
      gpsDistanceMeters: (map['gpsDistanceMeters'] as num?)?.toDouble() ??
          double.tryParse(map['gpsDistanceMeters']?.toString() ?? ''),
      gpsStatus: map['gpsStatus']?.toString(),
    );
  }
}

/// Offline attendance ledger entry stored in local persistent queue.
class PassportOfflineAttendanceRecord {
  final String sessionId;
  final String studentId;
  final String? studentName;
  final String deviceKeyId;
  final String responseNonce;
  final String verificationResult;
  final int timestamp;
  final String verificationMode;
  final String proximityTier;
  final String idempotencyKey;
  final String? routerBssid;
  final double? gpsDistanceMeters;
  final String? gpsStatus;

  const PassportOfflineAttendanceRecord({
    required this.sessionId,
    required this.studentId,
    this.studentName,
    required this.deviceKeyId,
    required this.responseNonce,
    required this.verificationResult,
    required this.timestamp,
    required this.verificationMode,
    required this.proximityTier,
    required this.idempotencyKey,
    this.routerBssid,
    this.gpsDistanceMeters,
    this.gpsStatus,
  });

  Map<String, dynamic> toMap() => {
    'sessionId': sessionId,
    'studentId': studentId,
    if (studentName != null) 'studentName': studentName,
    'deviceKeyId': deviceKeyId,
    'responseNonce': responseNonce,
    'verificationResult': verificationResult,
    'timestamp': timestamp,
    'verificationMode': verificationMode,
    'proximityTier': proximityTier,
    'idempotencyKey': idempotencyKey,
    if (routerBssid != null) 'routerBssid': routerBssid,
    if (gpsDistanceMeters != null) 'gpsDistanceMeters': gpsDistanceMeters,
    if (gpsStatus != null) 'gpsStatus': gpsStatus,
  };

  factory PassportOfflineAttendanceRecord.fromMap(Map<String, dynamic> map) =>
    PassportOfflineAttendanceRecord(
      sessionId: map['sessionId']?.toString() ?? '',
      studentId: map['studentId']?.toString() ?? '',
      studentName: map['studentName']?.toString(),
      deviceKeyId: map['deviceKeyId']?.toString() ?? '',
      responseNonce: map['responseNonce']?.toString() ?? '',
      verificationResult: map['verificationResult']?.toString() ?? '',
      timestamp: (map['timestamp'] is int)
          ? map['timestamp'] as int
          : int.tryParse(map['timestamp']?.toString() ?? '0') ?? 0,
      verificationMode: map['verificationMode']?.toString() ?? PassportAttendanceModel.modeBle,
      proximityTier: map['proximityTier']?.toString() ?? 'NEAR',
      idempotencyKey: map['idempotencyKey']?.toString() ?? '',
      routerBssid: map['routerBssid']?.toString(),
      gpsDistanceMeters: (map['gpsDistanceMeters'] as num?)?.toDouble() ??
          double.tryParse(map['gpsDistanceMeters']?.toString() ?? ''),
      gpsStatus: map['gpsStatus']?.toString(),
    );
}
