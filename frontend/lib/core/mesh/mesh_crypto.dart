import 'dart:convert';
import 'dart:typed_data';
import 'package:cryptography/cryptography.dart';

import '../../student/models/passport_trust_bundle_model.dart';
import '../../student/services/passport_crypto_service.dart';
import '../../student/services/passport_trust_bundle_service.dart';
import 'mesh_packet.dart';

/// Exception thrown when cryptographic operations fail in CampusOS Mesh.
class MeshCryptoException implements Exception {
  final String message;
  MeshCryptoException(this.message);

  @override
  String toString() => 'MeshCryptoException: $message';
}

/// Verification status categories for inbound CampusOS Mesh packets.
enum MeshVerificationStatus {
  /// Packet signature verified against an active institutional certificate.
  trusted,

  /// Cryptographic signature is invalid or does not match signable bytes.
  invalidSignature,

  /// Sender identity / keyId is not registered in the institutional trust bundle.
  unknownSender,

  /// Trust bundle or sender certificate has expired.
  expiredTrust,

  /// Sender identity or key is marked as REVOKED in the institutional trust bundle.
  revokedSender,

  /// Sender public key, certificate, or signature format is malformed.
  malformedIdentity,

  /// Packet timestamp is outside the allowable clock-skew window.
  staleTimestamp,

  /// Sender role is not authorized to originate the specific packet type (e.g. emergency).
  unauthorizedRole,
}

/// Structured result describing the outcome of a mesh packet verification.
class MeshPacketVerificationResult {
  final MeshVerificationStatus status;
  final String? senderUserId;
  final String? senderKeyId;
  final String? senderRole;
  final String? senderName;
  final String message;

  const MeshPacketVerificationResult({
    required this.status,
    this.senderUserId,
    this.senderKeyId,
    this.senderRole,
    this.senderName,
    required this.message,
  });

  /// Whether the packet is cryptographically authenticated and certified.
  bool get isTrusted => status == MeshVerificationStatus.trusted;

  /// Convenience alias for [isTrusted].
  bool get isValid => isTrusted;

  factory MeshPacketVerificationResult.trusted({
    required String senderUserId,
    required String senderKeyId,
    required String senderRole,
    String? senderName,
    String message = 'Packet signature verified against certified institutional trust bundle.',
  }) {
    return MeshPacketVerificationResult(
      status: MeshVerificationStatus.trusted,
      senderUserId: senderUserId,
      senderKeyId: senderKeyId,
      senderRole: senderRole,
      senderName: senderName,
      message: message,
    );
  }

  factory MeshPacketVerificationResult.invalidSignature([
    String message = 'Packet signature is cryptographically invalid.',
  ]) {
    return MeshPacketVerificationResult(
      status: MeshVerificationStatus.invalidSignature,
      message: message,
    );
  }

  factory MeshPacketVerificationResult.unknownSender([
    String message = 'Sender is not registered in institutional trust bundle.',
  ]) {
    return MeshPacketVerificationResult(
      status: MeshVerificationStatus.unknownSender,
      message: message,
    );
  }

  factory MeshPacketVerificationResult.expiredTrust([
    String message = 'Institutional trust bundle or sender certificate has expired.',
  ]) {
    return MeshPacketVerificationResult(
      status: MeshVerificationStatus.expiredTrust,
      message: message,
    );
  }

  factory MeshPacketVerificationResult.revokedSender([
    String message = 'Sender identity or key is recorded as revoked.',
  ]) {
    return MeshPacketVerificationResult(
      status: MeshVerificationStatus.revokedSender,
      message: message,
    );
  }

  factory MeshPacketVerificationResult.malformedIdentity([
    String message = 'Malformed identity, public key, or signature parameters.',
  ]) {
    return MeshPacketVerificationResult(
      status: MeshVerificationStatus.malformedIdentity,
      message: message,
    );
  }

  factory MeshPacketVerificationResult.staleTimestamp([
    String message = 'Packet timestamp is outside the permitted clock-skew window.',
  ]) {
    return MeshPacketVerificationResult(
      status: MeshVerificationStatus.staleTimestamp,
      message: message,
    );
  }

  factory MeshPacketVerificationResult.unauthorizedRole([
    String message = 'Sender role is not authorized to originate this packet type.',
  ]) {
    return MeshPacketVerificationResult(
      status: MeshVerificationStatus.unauthorizedRole,
      message: message,
    );
  }

  @override
  String toString() => 'MeshPacketVerificationResult(status: $status, sender: $senderUserId, message: $message)';
}

/// Institutional authorization policies governing packet origination per role.
class MeshRolePolicy {
  /// Evaluates whether a given campus [role] has privilege to originate [packetType].
  static bool isAuthorizedToOriginate({
    required String role,
    required MeshPacketType packetType,
  }) {
    final normalized = role.toLowerCase().trim();

    switch (packetType) {
      case MeshPacketType.chat:
      case MeshPacketType.fileOffer:
      case MeshPacketType.fileChunk:
      case MeshPacketType.acknowledgement:
        // Any authenticated campus member may originate standard P2P packets
        return true;

      case MeshPacketType.emergency:
        // Emergency broadcasts are restricted to institutional staff.
        // Students CANNOT originate emergency alerts under any circumstances.
        // Admin, Dean, Director, Warden, and authorized Faculty are permitted at transport level;
        // fine-grained scope authorization is enforced by the emergency service.
        if (normalized == 'admin' ||
            normalized == 'dean' ||
            normalized == 'director' ||
            normalized == 'warden' ||
            normalized == 'teacher' ||
            normalized == 'faculty') {
          return true;
        }
        return false;
    }
  }
}

/// Verification and signing interface for CampusOS Mesh packets.
///
/// Follows CampusOS security boundaries:
/// - Reuses Ed25519 cryptographic primitives and Passport trust bundles.
/// - Private keys NEVER leave local secure memory / keystore.
/// - Packets never transmit private key data.
abstract class MeshCryptoService {
  /// Signs raw signable bytes using the local node's identity key.
  Future<Uint8List> sign(Uint8List signableBytes);

  /// Signs an outbound [MeshPacket] using the local device identity key.
  ///
  /// Returns a copy of [packet] with the [MeshPacket.signature] field populated.
  Future<MeshPacket> signPacket(MeshPacket packet);

  /// Verifies the signature of raw bytes against a provided public key.
  Future<bool> verify({
    required Uint8List signableBytes,
    required Uint8List signature,
    required String senderDeviceId,
    Uint8List? senderPublicKey,
  });

  /// Verifies an inbound [MeshPacket] against the institutional trust bundle.
  Future<MeshPacketVerificationResult> verifyPacket(MeshPacket packet, {DateTime? now});

  /// Checks whether a given role is institutionally authorized to originate a packet type.
  bool isRoleAuthorized({required String role, required MeshPacketType packetType});
}

/// Production implementation of [MeshCryptoService] utilizing existing CampusOS Passport
/// Ed25519 identity key storage and institutional trust bundles.
class CampusMeshCryptoService implements MeshCryptoService {
  final Ed25519 _algorithm;
  final PassportCryptoService? _passportCryptoService;
  final PassportTrustBundleService? _trustBundleService;
  final SimpleKeyPair? _localKeyPair;
  final PassportTrustBundle? _mockTrustBundle;
  final Duration maxClockSkew;

  CampusMeshCryptoService({
    Ed25519? algorithm,
    PassportCryptoService? passportCryptoService,
    PassportTrustBundleService? trustBundleService,
    SimpleKeyPair? localKeyPair,
    PassportTrustBundle? mockTrustBundle,
    this.maxClockSkew = const Duration(minutes: 5),
  })  : _algorithm = algorithm ?? Ed25519(),
        _passportCryptoService = passportCryptoService,
        _trustBundleService = trustBundleService,
        _localKeyPair = localKeyPair,
        _mockTrustBundle = mockTrustBundle;

  @override
  Future<Uint8List> sign(Uint8List signableBytes) async {
    // 1. Try PassportCryptoService if injected
    final pcs = _passportCryptoService;
    if (pcs != null) {
      try {
        final b64Sig = await pcs.signCanonicalBytes(signableBytes);
        return Uint8List.fromList(base64Decode(b64Sig));
      } catch (e) {
        throw MeshCryptoException('Passport crypto failed to sign bytes: $e');
      }
    }

    // 2. Fall back to local keypair (test double or standalone)
    final keyPair = _localKeyPair;
    if (keyPair == null) {
      throw MeshCryptoException('Cannot sign: No local identity key pair configured.');
    }

    try {
      final sig = await _algorithm.sign(
        signableBytes,
        keyPair: keyPair,
      );
      return Uint8List.fromList(sig.bytes);
    } catch (e) {
      throw MeshCryptoException('Failed to sign mesh packet: $e');
    }
  }

  @override
  Future<MeshPacket> signPacket(MeshPacket packet) async {
    final signableBytes = packet.getSignableBytes();
    final signature = await sign(signableBytes);
    return packet.copyWith(signature: signature);
  }

  @override
  Future<bool> verify({
    required Uint8List signableBytes,
    required Uint8List signature,
    required String senderDeviceId,
    Uint8List? senderPublicKey,
  }) async {
    if (signature.isEmpty || senderPublicKey == null || senderPublicKey.length != 32) {
      return false;
    }

    try {
      final pubKey = SimplePublicKey(
        senderPublicKey,
        type: KeyPairType.ed25519,
      );

      final sigObject = Signature(
        signature,
        publicKey: pubKey,
      );

      return await _algorithm.verify(
        signableBytes,
        signature: sigObject,
      );
    } catch (_) {
      return false;
    }
  }

  @override
  bool isRoleAuthorized({required String role, required MeshPacketType packetType}) {
    return MeshRolePolicy.isAuthorizedToOriginate(role: role, packetType: packetType);
  }

  @override
  Future<MeshPacketVerificationResult> verifyPacket(MeshPacket packet, {DateTime? now}) async {
    final currentTime = now ?? DateTime.now();

    // 1. Replay / Freshness: clock-skew window check
    final skew = currentTime.difference(packet.timestamp);
    if (skew.abs() > maxClockSkew) {
      return MeshPacketVerificationResult.staleTimestamp(
        'Packet timestamp (${packet.timestamp.toIso8601String()}) is outside skew window of ${maxClockSkew.inMinutes}m (skew: ${skew.inSeconds}s)',
      );
    }

    // 2. Institutional Role Authorization
    if (!isRoleAuthorized(role: packet.senderRole, packetType: packet.packetType)) {
      return MeshPacketVerificationResult.unauthorizedRole(
        'Role "${packet.senderRole}" is not authorized to originate packet type "${packet.packetType.name}".',
      );
    }

    // 3. Structural signature validation
    if (packet.signature.isEmpty || packet.signature.length != 64) {
      return MeshPacketVerificationResult.invalidSignature(
        'Packet signature must be exactly 64 bytes (got ${packet.signature.length}).',
      );
    }

    // 4. Resolve institutional trust bundle
    PassportTrustBundle? bundle = _mockTrustBundle;
    final tbs = _trustBundleService;
    if (bundle == null && tbs != null) {
      bundle = await tbs.getLocalBundle();
    }

    if (bundle == null) {
      return MeshPacketVerificationResult.expiredTrust(
        'No institutional trust bundle found. Connect to CampusOS to synchronize certified trust anchors.',
      );
    }

    final currentUnixSeconds = currentTime.toUtc().millisecondsSinceEpoch ~/ 1000;
    if (bundle.isExpired(currentUnixSeconds)) {
      return MeshPacketVerificationResult.expiredTrust(
        'Institutional trust bundle expired at ${bundle.expiresAt} (current: $currentUnixSeconds).',
      );
    }

    // 5. Lookup sender identity in trust bundle (exact userId or keyId match only)
    PassportTrustIdentity? identity = bundle.findIdentity(packet.senderDeviceId);
    if (identity == null) {
      for (final idEntry in bundle.identities) {
        if (idEntry.userId == packet.senderDeviceId || idEntry.keyId == packet.senderDeviceId) {
          identity = idEntry;
          break;
        }
      }
    }

    if (identity == null) {
      return MeshPacketVerificationResult.unknownSender(
        'Sender "${packet.senderDeviceId}" is not registered in institutional trust bundle.',
      );
    }

    // 6. Check revocation status
    if (bundle.isKeyRevoked(identity.keyId) || identity.status != 'ACTIVE') {
      return MeshPacketVerificationResult.revokedSender(
        'Identity key "${identity.keyId}" is marked as ${identity.status} in trust bundle.',
      );
    }

    // 7. Check identity certificate validity window
    if (!identity.isValidAt(currentUnixSeconds)) {
      return MeshPacketVerificationResult.expiredTrust(
        'Identity certificate for "${identity.userId}" is expired or not yet valid (valid: ${identity.validFrom} - ${identity.validTo}).',
      );
    }

    // 8. Cryptographic verification with certified public key
    Uint8List pubKeyBytes;
    try {
      final decoded = base64Decode(identity.publicKey.trim());
      if (decoded.length != 32) {
        return MeshPacketVerificationResult.malformedIdentity(
          'Certified public key for "${identity.userId}" is invalid length (${decoded.length} != 32).',
        );
      }
      pubKeyBytes = Uint8List.fromList(decoded);
    } catch (_) {
      return MeshPacketVerificationResult.malformedIdentity(
        'Failed to decode Base64 public key from certified identity.',
      );
    }

    final isSigValid = await verify(
      signableBytes: packet.getSignableBytes(),
      signature: packet.signature,
      senderDeviceId: packet.senderDeviceId,
      senderPublicKey: pubKeyBytes,
    );

    if (!isSigValid) {
      return MeshPacketVerificationResult.invalidSignature(
        'Ed25519 signature verification failed against certified public key for "${identity.userId}".',
      );
    }

    return MeshPacketVerificationResult.trusted(
      senderUserId: identity.userId,
      senderKeyId: identity.keyId,
      senderRole: packet.senderRole,
      senderName: identity.userName,
    );
  }
}
