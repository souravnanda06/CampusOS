import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

/// CampusOS Passport BLE Challenge Model (Phase 1G).
///
/// Represents a verifier-issued ephemeral challenge that is broadcast over BLE.
/// A student's Passport presentation becomes cryptographically bound to this
/// challenge, preventing QR replay attacks.
///
/// BLE Service Data Format (compact binary, 20 bytes):
/// - Bytes 0–7:   Challenge nonce (8 random bytes, hex-encoded in payload)
/// - Bytes 8–11:  Issued-at timestamp (uint32 big-endian, seconds since epoch)
/// - Bytes 12–15: Expires-at timestamp (uint32 big-endian, seconds since epoch)
/// - Bytes 16–19: Verifier ID hash (first 4 bytes of SHA-256 of verifier ID)
///
/// The full challenge payload included in a signed presentation uses JSON fields.
class PassportChallengeModel {
  /// Dedicated Passport challenge BLE service UUID.
  /// Distinct from the attendance session UUID scheme to avoid collisions.
  static const String passportChallengeServiceUuid =
      '0000FE10-0000-1000-8000-00805F9B34FB';

  /// Dedicated Passport proximity response BLE service UUID (Phase 1H).
  /// Used by presenting student devices to chirp short proximity signals.
  static const String passportProximityServiceUuid =
      '0000FE11-0000-1000-8000-00805F9B34FB';

  /// Default challenge validity window.
  static const Duration defaultValidity = Duration(seconds: 60);

  /// Challenge nonce: 16 hex characters (8 random bytes).
  final String nonce;

  /// Verifier identifier (userId of the staff/warden/teacher scanning).
  final String verifierId;

  /// Unix timestamp (seconds) when the challenge was created.
  final int issuedAt;

  /// Unix timestamp (seconds) when the challenge expires.
  final int expiresAt;

  const PassportChallengeModel({
    required this.nonce,
    required this.verifierId,
    required this.issuedAt,
    required this.expiresAt,
  });

  /// Generates a new challenge with a cryptographically random nonce.
  factory PassportChallengeModel.generate({
    required String verifierId,
    Duration validity = defaultValidity,
    int? currentTimestampSeconds,
  }) {
    final nowSec = currentTimestampSeconds ??
        (DateTime.now().toUtc().millisecondsSinceEpoch ~/ 1000);
    final random = Random.secure();
    final nonceBytes = List<int>.generate(8, (_) => random.nextInt(256));
    final nonce = nonceBytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();

    return PassportChallengeModel(
      nonce: nonce,
      verifierId: verifierId,
      issuedAt: nowSec,
      expiresAt: nowSec + validity.inSeconds,
    );
  }

  /// Whether this challenge has expired.
  bool isExpired([int? currentTimestampSeconds]) {
    final now = currentTimestampSeconds ??
        (DateTime.now().toUtc().millisecondsSinceEpoch ~/ 1000);
    return now >= expiresAt;
  }

  /// Remaining validity in seconds (clamped to 0).
  int remainingSeconds([int? currentTimestampSeconds]) {
    final now = currentTimestampSeconds ??
        (DateTime.now().toUtc().millisecondsSinceEpoch ~/ 1000);
    return max(0, expiresAt - now);
  }

  /// Returns the challenge payload map for inclusion in a signed presentation.
  /// Keys are sorted alphabetically for canonical serialization consistency.
  Map<String, dynamic> toPayloadMap() {
    return {
      'expiresAt': expiresAt,
      'issuedAt': issuedAt,
      'nonce': nonce,
      'verifierId': verifierId,
    };
  }

  /// Encodes the challenge into compact BLE service data bytes (20 bytes).
  ///
  /// Format:
  /// - [0..7]   8-byte nonce (raw bytes from hex)
  /// - [8..11]  issuedAt as uint32 big-endian
  /// - [12..15] expiresAt as uint32 big-endian
  /// - [16..19] first 4 bytes of verifierId UTF-8 (zero-padded)
  Uint8List toBleServiceData() {
    final data = Uint8List(20);

    // Nonce: 16 hex chars => 8 raw bytes
    for (int i = 0; i < 8; i++) {
      final hexByte = nonce.substring(i * 2, i * 2 + 2);
      data[i] = int.parse(hexByte, radix: 16);
    }

    // issuedAt as uint32 big-endian
    final byteData = ByteData.sublistView(data);
    byteData.setUint32(8, issuedAt, Endian.big);
    byteData.setUint32(12, expiresAt, Endian.big);

    // Verifier ID hash: first 4 bytes of UTF-8 encoding (truncated/padded)
    final verifierBytes = utf8.encode(verifierId);
    for (int i = 0; i < 4; i++) {
      data[16 + i] = i < verifierBytes.length ? verifierBytes[i] : 0;
    }

    return data;
  }

  /// Decodes challenge from compact BLE service data bytes.
  factory PassportChallengeModel.fromBleServiceData(
    Uint8List data, {
    String fallbackVerifierId = '',
  }) {
    if (data.length < 16) {
      throw FormatException(
        'BLE challenge service data too short: expected ≥16 bytes, got ${data.length}',
      );
    }

    // Nonce: 8 raw bytes => 16 hex chars
    final nonceHex = data
        .sublist(0, 8)
        .map((b) => b.toRadixString(16).padLeft(2, '0'))
        .join();

    final byteData = ByteData.sublistView(data);
    final issuedAt = byteData.getUint32(8, Endian.big);
    final expiresAt = byteData.getUint32(12, Endian.big);

    // Verifier ID hint (first 4 bytes, may be truncated)
    String verifierHint = fallbackVerifierId;
    if (data.length >= 20) {
      final verifierBytes = data.sublist(16, 20);
      final trimmed = verifierBytes.where((b) => b != 0).toList();
      if (trimmed.isNotEmpty) {
        verifierHint = utf8.decode(trimmed, allowMalformed: true);
      }
    }

    return PassportChallengeModel(
      nonce: nonceHex,
      verifierId: verifierHint,
      issuedAt: issuedAt,
      expiresAt: expiresAt,
    );
  }

  /// Creates a challenge from a JSON map (used in test / offline scenarios).
  factory PassportChallengeModel.fromMap(Map<String, dynamic> map) {
    return PassportChallengeModel(
      nonce: map['nonce']?.toString() ?? '',
      verifierId: map['verifierId']?.toString() ?? '',
      issuedAt: (map['issuedAt'] is int)
          ? map['issuedAt'] as int
          : int.tryParse(map['issuedAt']?.toString() ?? '0') ?? 0,
      expiresAt: (map['expiresAt'] is int)
          ? map['expiresAt'] as int
          : int.tryParse(map['expiresAt']?.toString() ?? '0') ?? 0,
    );
  }

  @override
  String toString() =>
      'PassportChallengeModel(nonce: $nonce, verifierId: $verifierId, '
      'issuedAt: $issuedAt, expiresAt: $expiresAt)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PassportChallengeModel &&
          runtimeType == other.runtimeType &&
          nonce == other.nonce &&
          verifierId == other.verifierId &&
          issuedAt == other.issuedAt &&
          expiresAt == other.expiresAt;

  @override
  int get hashCode => Object.hash(nonce, verifierId, issuedAt, expiresAt);
}
