import 'dart:math';
import '../mesh_airdrop_models.dart';

/// Cryptographically bound temporary local transfer session.
///
/// Binds logical transfer metadata strictly to an ephemeral, single-use,
/// cryptographically random authorization token.
class LocalWifiTransferSession {
  /// Logical 16-byte hex file ID.
  final String fileId;

  /// Unique transfer session UUID.
  final String transferId;

  /// Device ID of the file sender.
  final String senderDeviceId;

  /// Device ID of the intended receiver.
  final String receiverDeviceId;

  /// Expected SHA-256 hash of the complete file payload.
  final String sha256;

  /// Total size of the file payload in bytes.
  final int fileSize;

  /// One-time, cryptographically random authorization token (32 hex characters).
  final String authToken;

  /// Bound local IPv4 address or hostname.
  final String host;

  /// Ephemeral listening TCP port.
  final int port;

  /// Creation timestamp.
  final DateTime createdAt;

  /// Session expiration timestamp (default: 5 minutes from creation).
  final DateTime expiresAt;

  /// Transport type (always [MeshTransportType.localWifi]).
  final MeshTransportType transportType;

  /// Whether the session has already been redeemed / accessed (replay protection).
  bool _hasBeenRedeemed = false;

  LocalWifiTransferSession({
    required this.fileId,
    required this.transferId,
    required this.senderDeviceId,
    required this.receiverDeviceId,
    required this.sha256,
    required this.fileSize,
    required this.authToken,
    required this.host,
    required this.port,
    required this.createdAt,
    required this.expiresAt,
    this.transportType = MeshTransportType.localWifi,
  });

  /// Factory that generates a fresh session with a secure 32-character random token.
  factory LocalWifiTransferSession.create({
    required String fileId,
    required String transferId,
    required String senderDeviceId,
    required String receiverDeviceId,
    required String sha256,
    required int fileSize,
    required String host,
    required int port,
    Duration duration = const Duration(minutes: 5),
  }) {
    final now = DateTime.now();
    final token = generateSecureToken();
    return LocalWifiTransferSession(
      fileId: fileId,
      transferId: transferId,
      senderDeviceId: senderDeviceId,
      receiverDeviceId: receiverDeviceId,
      sha256: sha256,
      fileSize: fileSize,
      authToken: token,
      host: host,
      port: port,
      createdAt: now,
      expiresAt: now.add(duration),
    );
  }

  /// Generates a cryptographically secure 128-bit (32 hex char) random token.
  static String generateSecureToken() {
    final random = Random.secure();
    final values = List<int>.generate(16, (i) => random.nextInt(256));
    return values.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }

  /// Whether the session has expired.
  bool get isExpired => DateTime.now().isAfter(expiresAt);

  /// Whether the session has already been redeemed.
  bool get hasBeenRedeemed => _hasBeenRedeemed;

  /// Validates a candidate token against this session.
  ///
  /// Rejects if:
  /// - Session is expired.
  /// - Candidate token does not match [authToken].
  /// - Session was already redeemed (replay attack prevention).
  bool validateToken(String candidateToken, {bool allowMultiChunk = true}) {
    if (isExpired) return false;
    if (candidateToken.trim() != authToken) return false;
    if (_hasBeenRedeemed && !allowMultiChunk) return false;
    return true;
  }

  /// Marks the token as redeemed for download.
  void markRedeemed() {
    _hasBeenRedeemed = true;
  }
}
