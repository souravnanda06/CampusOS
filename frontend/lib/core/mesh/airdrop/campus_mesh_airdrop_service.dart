import 'dart:async';
import 'dart:io';
import 'dart:math';

import '../../../student/models/passport_trust_bundle_model.dart';
import '../../../student/services/passport_trust_bundle_service.dart';
import '../campus_mesh_service.dart';
import '../mesh_crypto.dart';
import '../mesh_packet.dart';
import 'mesh_airdrop_models.dart';
import 'mesh_airdrop_repository.dart';
import 'mesh_airdrop_storage.dart';
import 'transport/ble_mesh_file_transport.dart';
import 'transport/local_wifi_capability.dart';
import 'transport/local_wifi_file_transport.dart';
import 'transport/localsend_udp_discovery.dart';

/// Authorized institutional roles permitted to use Academic AirDrop.
const Set<String> kAuthorizedAcademicRoles = {
  'student',
  'teacher',
  'faculty',
  'professor',
  'admin',
  'dean',
  'staff',
};

/// High-level domain service orchestrating CampusOS Mesh Academic AirDrop (Phase M5A + M5B).
///
/// Features:
/// - Pure offline BLE Mesh file transfer for small academic documents (<= 2 MB).
/// - Hybrid Local Wi-Fi high-speed HTTP streaming for larger academic payloads (<= 100 MB).
/// - Reuses existing CampusOS Passport Ed25519 identity and trust-bundle PKI.
/// - Memory-bounded streaming: source files are read chunk-by-chunk; chunks are written
///   directly to disk at exact byte offsets via [RandomAccessFile].
/// - Out-of-order chunk handling and duplicate-safe idempotency.
/// - End-to-end SHA-256 integrity verification before finalizing file download.
/// - Bounded retries (max 3), expiration handling, and full transfer cancellation.
class CampusMeshAirDropService {
  final CampusMeshService _meshService;
  final MeshAirDropRepository _repository;
  final MeshAirDropStorage _storage;
  final MeshCryptoService? _cryptoService;
  final PassportTrustBundleService? _trustBundleService;
  final PassportTrustBundle? _mockTrustBundle;
  final Duration _offerTtl;
  final Duration _chunkPacing;
  final LocalWifiCapabilityDetector _wifiCapabilityDetector;
  final LocalWifiFileTransport _wifiTransport;
  final BleMeshFileTransport _bleTransport;

  StreamSubscription<MeshPacket>? _meshSubscription;

  final Map<String, File> _outgoingFiles = {};
  final Map<String, File> _incomingTempFiles = {};
  final Map<String, ReceivedChunkTracker> _chunkTrackers = {};

  bool _isDisposed = false;

  final StreamController<MeshFileTransferSession> _incomingOffersController =
      StreamController<MeshFileTransferSession>.broadcast();

  CampusMeshAirDropService({
    required CampusMeshService meshService,
    required MeshAirDropRepository repository,
    MeshAirDropStorage? storage,
    MeshCryptoService? cryptoService,
    PassportTrustBundleService? trustBundleService,
    PassportTrustBundle? mockTrustBundle,
    Duration offerTtl = const Duration(minutes: 5),
    Duration chunkPacing = const Duration(milliseconds: 15),
    LocalWifiCapabilityDetector? wifiCapabilityDetector,
    LocalWifiFileTransport? wifiTransport,
    BleMeshFileTransport? bleTransport,
  })  : _meshService = meshService,
        _repository = repository,
        _storage = storage ?? MeshAirDropStorage(),
        _cryptoService = cryptoService ?? meshService.cryptoService,
        _trustBundleService = trustBundleService,
        _mockTrustBundle = mockTrustBundle,
        _offerTtl = offerTtl,
        _chunkPacing = chunkPacing,
        _wifiCapabilityDetector = wifiCapabilityDetector ?? LocalWifiCapabilityDetector(),
        _wifiTransport = wifiTransport ?? LocalWifiFileTransport(storage: storage),
        _bleTransport = bleTransport ?? BleMeshFileTransport();

  /// Local Wi-Fi capability detector instance.
  LocalWifiCapabilityDetector get wifiCapabilityDetector => _wifiCapabilityDetector;

  /// High-speed local Wi-Fi transport instance.
  LocalWifiFileTransport get wifiTransport => _wifiTransport;

  /// Underlying BLE Mesh transport instance.
  BleMeshFileTransport get bleTransport => _bleTransport;

  /// Stream of pending incoming offers requiring user acceptance or rejection.
  Stream<MeshFileTransferSession> get incomingOffers =>
      _incomingOffersController.stream;

  /// Underlying repository instance.
  MeshAirDropRepository get repository => _repository;

  /// Cryptographic service if configured.
  MeshCryptoService? get cryptoService => _cryptoService;

  /// Underlying mesh network service.
  CampusMeshService get meshService => _meshService;

  LocalSendUdpDiscoveryService? _udpDiscovery;

  /// High-speed LocalSend-compatible UDP peer discovery over local Wi-Fi.
  LocalSendUdpDiscoveryService? get udpDiscovery => _udpDiscovery;

  /// Storage engine.
  MeshAirDropStorage get storage => _storage;

  /// Initializes local SQLite repository, registers packet listeners, and cleans stale files.
  Future<void> initialize() async {
    await _repository.initialize();
    await _storage.cleanupStaleTemporaryFiles();

    await _meshSubscription?.cancel();
    _meshSubscription = _meshService.receivedPackets.listen(_handleIncomingMeshPacket);

    try {
      _udpDiscovery = LocalSendUdpDiscoveryService(
        localDeviceId: _meshService.localDeviceId,
        localAlias: _meshService.localDeviceId,
        localRole: _meshService.localRole,
        capabilityDetector: _wifiCapabilityDetector,
      );
      unawaited(_udpDiscovery!.start());
    } catch (_) {}
  }

  /// Initiates an outgoing file offer over BLE Mesh (with optional high-speed Local Wi-Fi payload).
  ///
  /// Constraints:
  /// - File must exist and be > 0 bytes.
  /// - File size must not exceed transport limit (2 MB for BLE, 100 MB for Local Wi-Fi).
  /// - Filename must be <= 120 chars.
  /// - MIME type must be <= 80 chars.
  Future<MeshFileTransferSession> sendFileOffer({
    required File file,
    String? targetDeviceId,
    String? mimeType,
    int chunkSize = MeshFileOffer.defaultChunkSize,
    MeshTransportType? preferredTransport,
  }) async {
    if (!await file.exists()) {
      throw FileSystemException('Source file does not exist', file.path);
    }

    final fileSize = await file.length();
    if (fileSize <= 0) {
      throw ArgumentError('Cannot transfer empty (0-byte) file');
    }

    final selectedTransport = preferredTransport ??
        (fileSize > MeshFileOffer.maxBleFileSizeBytes
            ? MeshTransportType.localWifi
            : MeshTransportType.bleMesh);

    final maxAllowed = selectedTransport == MeshTransportType.localWifi
        ? MeshFileOffer.maxWifiFileSizeBytes
        : MeshFileOffer.maxBleFileSizeBytes;

    if (fileSize > maxAllowed) {
      if (selectedTransport == MeshTransportType.bleMesh) {
        throw ArgumentError(
          'High-speed local transfer unavailable. This file exceeds the offline BLE transfer limit ($fileSize bytes > ${MeshFileOffer.maxBleFileSizeBytes} bytes).',
        );
      } else {
        throw ArgumentError(
          'File size ($fileSize bytes) exceeds maximum supported limit of ${MeshFileOffer.maxWifiFileSizeBytes} bytes.',
        );
      }
    }

    final rawFilename = file.uri.pathSegments.isNotEmpty
        ? file.uri.pathSegments.last
        : 'file_${DateTime.now().millisecondsSinceEpoch}';
    final safeFilename = MeshAirDropStorage.sanitizeFilename(rawFilename);
    if (safeFilename.length > MeshFileOffer.maxFilenameLength) {
      throw ArgumentError(
        'Filename exceeds maximum length of ${MeshFileOffer.maxFilenameLength} characters.',
      );
    }

    final effectiveMime = (mimeType != null && mimeType.trim().isNotEmpty)
        ? mimeType.trim()
        : _inferMimeType(safeFilename);
    if (effectiveMime.length > MeshFileOffer.maxMimeTypeLength) {
      throw ArgumentError(
        'MIME type exceeds maximum length of ${MeshFileOffer.maxMimeTypeLength} characters.',
      );
    }

    // 1. Calculate streaming SHA-256 (memory-bounded)
    final sha256 = await _storage.computeFileSha256(file);

    // 2. Generate unique 16-byte file ID (32 hex characters)
    final fileId = _generateFileId();
    final transferId = 'transfer_out_$fileId';
    final totalChunks = MeshFileOffer.calculateTotalChunks(fileSize, chunkSize);

    final now = DateTime.now();
    final expiresAt = now.add(_offerTtl);

    // 3. Resolve sender user ID from trust bundle if available
    String? senderUserId;
    final bundle = await _resolveTrustBundle();
    if (bundle != null) {
      final identity = bundle.findIdentity(_meshService.localDeviceId) ??
          bundle.identities.cast<PassportTrustIdentity?>().firstWhere(
                (i) => i?.userId == _meshService.localDeviceId,
                orElse: () => null,
              );
      if (identity != null) {
        senderUserId = identity.userId;
      }
    }

    // 4. Construct file offer wire model
    final offer = MeshFileOffer(
      fileId: fileId,
      senderDeviceId: _meshService.localDeviceId,
      senderUserId: senderUserId,
      senderRole: _meshService.localRole,
      filename: safeFilename,
      mimeType: effectiveMime,
      fileSize: fileSize,
      sha256: sha256,
      chunkSize: chunkSize,
      totalChunks: totalChunks,
      createdAt: now,
      expiresAt: expiresAt,
      targetDeviceId: targetDeviceId,
      preferredTransport: selectedTransport,
    );

    // 5. Construct domain session
    final session = MeshFileTransferSession(
      transferId: transferId,
      fileId: fileId,
      peerDeviceId: targetDeviceId ?? 'broadcast',
      peerDisplayName: targetDeviceId != null ? 'Peer ($targetDeviceId)' : 'All Nearby Peers',
      peerRole: 'unknown',
      isPeerVerified: true,
      direction: MeshTransferDirection.outgoing,
      state: MeshFileTransferState.waitingForAccept,
      filename: safeFilename,
      mimeType: effectiveMime,
      fileSize: fileSize,
      transferredBytes: 0,
      totalChunks: totalChunks,
      transferredChunks: 0,
      sha256: sha256,
      localFilePath: file.path,
      createdAt: now,
      updatedAt: now,
      expiresAt: expiresAt,
      transportType: selectedTransport,
    );

    _outgoingFiles[fileId] = file;
    await _repository.saveTransfer(session);

    // 6. Broadcast signed fileOffer packet
    final offerBytes = offer.toBytes();
    final packet = MeshPacket(
      packetId: MeshPacket.generatePacketId(),
      packetType: MeshPacketType.fileOffer,
      ttl: MeshPacket.defaultTtl,
      hopCount: 0,
      senderDeviceId: _meshService.localDeviceId,
      senderRole: _meshService.localRole,
      timestamp: now,
      payload: offerBytes,
    );

    await _meshService.broadcastPacket(packet);
    return session;
  }

  /// Accepts an incoming file offer, creates a temporary file on disk,
  /// and sends a signed [FILE_OFFER_ACCEPT] or [WIFI_NEGOTIATE] acknowledgement.
  Future<void> acceptOffer(String fileId) async {
    final session = await _repository.getTransferByFileId(fileId);
    if (session == null) {
      throw StateError('Transfer session not found for fileId $fileId');
    }
    if (session.state != MeshFileTransferState.offered) {
      throw StateError('Cannot accept transfer in state ${session.state.name}');
    }

    if (DateTime.now().isAfter(session.expiresAt)) {
      await _repository.updateTransferState(
        session.transferId,
        MeshFileTransferState.expired,
        errorMessage: 'File offer expired before acceptance',
      );
      throw StateError('File offer has expired');
    }

    if (session.transportType == MeshTransportType.localWifi) {
      // 1. Detect local Wi-Fi capability
      final cap = await _wifiCapabilityDetector.detectCapability();
      if (!cap.isSupported) {
        // Fallback to BLE if within limit
        if (session.fileSize <= MeshFileOffer.maxBleFileSizeBytes) {
          await _repository.updateTransferState(
            session.transferId,
            MeshFileTransferState.fallback,
          );
          final tempFile = await _storage.createTemporaryIncomingFile(fileId);
          _incomingTempFiles[fileId] = tempFile;
          _chunkTrackers[fileId] = ReceivedChunkTracker(totalChunks: session.totalChunks);

          await _repository.updateTransferState(
            session.transferId,
            MeshFileTransferState.receiving,
          );

          final fallbackAck = MeshFileAck(
            fileId: fileId,
            ackType: MeshFileAckType.wifiFallback,
          );
          await _broadcastAck(fallbackAck);
          return;
        } else {
          await _repository.updateTransferState(
            session.transferId,
            MeshFileTransferState.failed,
            errorMessage:
                'High-speed local transfer unavailable. This file exceeds the offline BLE transfer limit.',
          );
          final rejectAck = MeshFileAck(
            fileId: fileId,
            ackType: MeshFileAckType.fileOfferReject,
          );
          await _broadcastAck(rejectAck);
          return;
        }
      }

      // 2. Wi-Fi supported: send wifiNegotiate ACK
      await _repository.updateTransferState(
        session.transferId,
        MeshFileTransferState.negotiating,
      );

      final ack = MeshFileAck(
        fileId: fileId,
        ackType: MeshFileAckType.wifiNegotiate,
      );
      await _broadcastAck(ack);
      return;
    }

    // BLE Mesh transport: prepare disk storage and accept
    final tempFile = await _storage.createTemporaryIncomingFile(fileId);
    _incomingTempFiles[fileId] = tempFile;
    _chunkTrackers[fileId] = ReceivedChunkTracker(totalChunks: session.totalChunks);

    // Update state to accepted / receiving
    await _repository.updateTransferState(
      session.transferId,
      MeshFileTransferState.receiving,
    );

    // Send FILE_OFFER_ACCEPT acknowledgement packet
    final ack = MeshFileAck(
      fileId: fileId,
      ackType: MeshFileAckType.fileOfferAccept,
    );
    await _broadcastAck(ack);
  }

  /// Rejects an incoming file offer and sends a signed [FILE_OFFER_REJECT] acknowledgement.
  Future<void> rejectOffer(String fileId) async {
    final session = await _repository.getTransferByFileId(fileId);
    if (session == null) return;

    await _repository.updateTransferState(
      session.transferId,
      MeshFileTransferState.rejected,
      errorMessage: 'Declined by recipient',
    );

    final ack = MeshFileAck(
      fileId: fileId,
      ackType: MeshFileAckType.fileOfferReject,
    );
    await _broadcastAck(ack);
  }

  /// Cancels an in-progress file transfer (either incoming or outgoing).
  Future<void> cancelTransfer(String transferId) async {
    final session = await _repository.getTransfer(transferId);
    if (session == null || session.state.isTerminal) return;

    await _repository.updateTransferState(
      transferId,
      MeshFileTransferState.cancelled,
      errorMessage: 'Transfer cancelled by user',
    );

    await _wifiTransport.cancel(transferId);

    // Delete temporary assembly file if incoming
    if (session.direction == MeshTransferDirection.incoming) {
      final temp = _incomingTempFiles.remove(session.fileId);
      if (temp != null && await temp.exists()) {
        await temp.delete();
      }
    }
    _outgoingFiles.remove(session.fileId);
    _chunkTrackers.remove(session.fileId);

    final ack = MeshFileAck(
      fileId: session.fileId,
      ackType: MeshFileAckType.transferCancelled,
    );
    await _broadcastAck(ack);
  }

  Future<void> _broadcastAck(MeshFileAck ack) async {
    final packet = MeshPacket(
      packetId: MeshPacket.generatePacketId(),
      packetType: MeshPacketType.acknowledgement,
      ttl: MeshPacket.defaultTtl,
      hopCount: 0,
      senderDeviceId: _meshService.localDeviceId,
      senderRole: _meshService.localRole,
      timestamp: DateTime.now(),
      payload: ack.toBytes(),
    );
    await _meshService.broadcastPacket(packet);
  }

  /// Inbound packet dispatcher.
  Future<void> _handleIncomingMeshPacket(MeshPacket packet) async {
    try {
      switch (packet.packetType) {
        case MeshPacketType.fileOffer:
          await _handleInboundOffer(packet);
          break;
        case MeshPacketType.fileChunk:
          await _handleInboundChunk(packet);
          break;
        case MeshPacketType.acknowledgement:
          await _handleInboundAck(packet);
          break;
        default:
          break;
      }
    } catch (_) {
      // Malformed or corrupt packets are discarded safely without crashing the node
    }
  }

  /// Handles incoming [MeshPacketType.fileOffer] packets.
  Future<void> _handleInboundOffer(MeshPacket packet) async {
    // 1. Verify cryptographic validity and trust bundle
    final bundle = await _resolveTrustBundle();
    bool isVerified = false;
    String resolvedDisplayName = packet.senderDeviceId;

    if (bundle != null) {
      // Check if key or user is revoked
      if (bundle.isKeyRevoked(packet.senderDeviceId)) {
        return; // Discard revoked sender packets
      }

      final identity = bundle.findIdentity(packet.senderDeviceId) ??
          bundle.identities.cast<PassportTrustIdentity?>().firstWhere(
                (i) => i?.userId == packet.senderDeviceId,
                orElse: () => null,
              );

      if (identity != null) {
        isVerified = true;
        resolvedDisplayName = identity.userName ?? identity.userId;
      }
    } else {
      // In dev or isolated tests without trust bundle, accept authenticated packet
      isVerified = true;
    }

    // 2. Check academic role authorization
    final role = packet.senderRole.toLowerCase().trim();
    if (!kAuthorizedAcademicRoles.contains(role)) {
      return; // Discard unauthorized non-academic senders
    }

    // 3. Deserialize offer payload
    final offer = MeshFileOffer.fromBytes(
      bytes: packet.payload,
      senderDeviceId: packet.senderDeviceId,
      senderRole: packet.senderRole,
      createdAt: packet.timestamp,
    );

    // 4. Target peer verification
    if (offer.targetDeviceId != null &&
        offer.targetDeviceId!.isNotEmpty &&
        offer.targetDeviceId != _meshService.localDeviceId) {
      return; // Offer is unicast to a different peer
    }

    // 5. Expiration check
    if (DateTime.now().isAfter(offer.expiresAt)) {
      return;
    }

    // 6. Deduplication check
    final existing = await _repository.getTransferByFileId(offer.fileId);
    if (existing != null) {
      return;
    }

    // 7. Register incoming transfer session in offered state
    final transferId = 'transfer_in_${offer.fileId}';
    final session = MeshFileTransferSession(
      transferId: transferId,
      fileId: offer.fileId,
      peerDeviceId: packet.senderDeviceId,
      peerDisplayName: resolvedDisplayName,
      peerRole: packet.senderRole,
      isPeerVerified: isVerified,
      direction: MeshTransferDirection.incoming,
      state: MeshFileTransferState.offered,
      filename: offer.filename,
      mimeType: offer.mimeType,
      fileSize: offer.fileSize,
      transferredBytes: 0,
      totalChunks: offer.totalChunks,
      transferredChunks: 0,
      sha256: offer.sha256,
      createdAt: packet.timestamp,
      updatedAt: DateTime.now(),
      expiresAt: offer.expiresAt,
      hopCount: packet.hopCount,
      transportType: offer.preferredTransport,
    );

    await _repository.saveTransfer(session);
    _incomingOffersController.add(session);
  }

  /// Handles incoming [MeshPacketType.fileChunk] packets.
  Future<void> _handleInboundChunk(MeshPacket packet) async {
    final chunk = MeshFileChunk.fromBytes(packet.payload);
    final session = await _repository.getTransferByFileId(chunk.fileId);
    if (session == null) return;

    // Only process chunks if recipient has accepted or is actively receiving
    if (session.state != MeshFileTransferState.accepted &&
        session.state != MeshFileTransferState.receiving) {
      return;
    }

    // Expiration check
    if (DateTime.now().isAfter(session.expiresAt)) {
      await _repository.updateTransferState(
        session.transferId,
        MeshFileTransferState.expired,
        errorMessage: 'Transfer timed out during chunk arrival',
      );
      return;
    }

    // Retrieve or initialize chunk tracker and temp file
    var tracker = _chunkTrackers[chunk.fileId];
    if (tracker == null) {
      tracker = ReceivedChunkTracker(totalChunks: chunk.totalChunks);
      _chunkTrackers[chunk.fileId] = tracker;
    }

    var tempFile = _incomingTempFiles[chunk.fileId];
    if (tempFile == null) {
      tempFile = await _storage.createTemporaryIncomingFile(chunk.fileId);
      _incomingTempFiles[chunk.fileId] = tempFile;
    }

    // 1. Mark in tracker (idempotent duplicate suppression)
    final isNew = tracker.markReceived(chunk.sequence);
    if (!isNew) {
      return; // Duplicate chunk safely ignored
    }

    // 2. Write chunk directly to disk at exact byte offset (zero RAM buffering)
    const chunkSize = MeshFileOffer.defaultChunkSize;
    await _storage.writeChunkToDisk(
      tempFile: tempFile,
      chunk: chunk,
      chunkSize: chunkSize,
    );

    // 3. Record sequence in SQLite chunk bitmap index
    await _repository.recordReceivedChunk(chunk.fileId, chunk.sequence);

    // 4. Update byte and chunk progress
    final transferredChunks = tracker.receivedCount;
    final transferredBytes = min(transferredChunks * chunkSize, session.fileSize);
    await _repository.updateProgress(
      session.transferId,
      transferredBytes: transferredBytes,
      transferredChunks: transferredChunks,
    );

    // 5. Check for complete reassembly
    if (tracker.isComplete) {
      await _finalizeInboundTransfer(session, tempFile);
    }
  }

  /// Finalizes and cryptographically verifies an incoming file transfer.
  Future<void> _finalizeInboundTransfer(
    MeshFileTransferSession session,
    File tempFile,
  ) async {
    final current = await _repository.getTransfer(session.transferId);
    if (current == null ||
        current.state == MeshFileTransferState.verifying ||
        current.state.isTerminal) {
      return;
    }

    _incomingTempFiles.remove(session.fileId);
    _chunkTrackers.remove(session.fileId);

    await _repository.updateTransferState(
      session.transferId,
      MeshFileTransferState.verifying,
    );

    try {
      // 1. Verify SHA-256 against signed offer and move to completed directory
      final finalFile = await _storage.finalizeAndVerifyFile(
        tempFile: tempFile,
        fileId: session.fileId,
        originalFilename: session.filename,
        expectedSha256: session.sha256,
      );

      // 2. Mark completed in SQLite
      await _repository.updateTransferState(
        session.transferId,
        MeshFileTransferState.completed,
        localFilePath: finalFile.path,
      );

      // 3. Send TRANSFER_COMPLETE acknowledgement to sender
      final ack = MeshFileAck(
        fileId: session.fileId,
        ackType: MeshFileAckType.transferComplete,
      );

      final packet = MeshPacket(
        packetId: MeshPacket.generatePacketId(),
        packetType: MeshPacketType.acknowledgement,
        ttl: MeshPacket.defaultTtl,
        hopCount: 0,
        senderDeviceId: _meshService.localDeviceId,
        senderRole: _meshService.localRole,
        timestamp: DateTime.now(),
        payload: ack.toBytes(),
      );

      await _meshService.broadcastPacket(packet);
    } on MeshAirDropIntegrityException catch (e) {
      _incomingTempFiles.remove(session.fileId);
      _chunkTrackers.remove(session.fileId);

      await _repository.updateTransferState(
        session.transferId,
        MeshFileTransferState.integrityFailure,
        errorMessage: e.toString(),
      );

      // Send TRANSFER_FAILED acknowledgement
      final ack = MeshFileAck(
        fileId: session.fileId,
        ackType: MeshFileAckType.transferFailed,
        reasonCode: 0x01, // integrity failure
      );

      final packet = MeshPacket(
        packetId: MeshPacket.generatePacketId(),
        packetType: MeshPacketType.acknowledgement,
        ttl: MeshPacket.defaultTtl,
        hopCount: 0,
        senderDeviceId: _meshService.localDeviceId,
        senderRole: _meshService.localRole,
        timestamp: DateTime.now(),
        payload: ack.toBytes(),
      );

      await _meshService.broadcastPacket(packet);
    } catch (e) {
      _incomingTempFiles.remove(session.fileId);
      _chunkTrackers.remove(session.fileId);

      await _repository.updateTransferState(
        session.transferId,
        MeshFileTransferState.failed,
        errorMessage: 'Assembly failed: $e',
      );
    }
  }

  /// Handles incoming [MeshPacketType.acknowledgement] packets for transfer signaling.
  Future<void> _handleInboundAck(MeshPacket packet) async {
    final ack = MeshFileAck.fromBytes(packet.payload);
    final session = await _repository.getTransferByFileId(ack.fileId);
    if (session == null) return;

    switch (ack.ackType) {
      case MeshFileAckType.fileOfferAccept:
        if (session.state == MeshFileTransferState.waitingForAccept ||
            session.state == MeshFileTransferState.offering) {
          if (session.transportType == MeshTransportType.localWifi) {
            await _startWifiServerAndSignalReady(session);
          } else {
            await _repository.updateTransferState(
              session.transferId,
              MeshFileTransferState.sending,
            );
            // Launch asynchronous streaming chunk loop
            unawaited(_streamChunksToPeer(session));
          }
        }
        break;

      case MeshFileAckType.wifiNegotiate:
        if (session.state == MeshFileTransferState.waitingForAccept ||
            session.state == MeshFileTransferState.offering ||
            session.state == MeshFileTransferState.negotiating) {
          await _startWifiServerAndSignalReady(session);
        }
        break;

      case MeshFileAckType.wifiReady:
        if (session.state == MeshFileTransferState.negotiating ||
            session.state == MeshFileTransferState.offered ||
            session.state == MeshFileTransferState.waitingForAccept) {
          await _repository.updateTransferState(
            session.transferId,
            MeshFileTransferState.connecting,
          );
          unawaited(_receiveWifiFileStream(session, ack));
        }
        break;

      case MeshFileAckType.wifiFallback:
        if (session.fileSize <= MeshFileOffer.maxBleFileSizeBytes) {
          await _repository.updateTransferState(
            session.transferId,
            MeshFileTransferState.fallback,
          );
          if (session.direction == MeshTransferDirection.outgoing) {
            await _repository.updateTransferState(
              session.transferId,
              MeshFileTransferState.sending,
            );
            unawaited(_streamChunksToPeer(session));
          } else {
            final tempFile = await _storage.createTemporaryIncomingFile(session.fileId);
            _incomingTempFiles[session.fileId] = tempFile;
            _chunkTrackers[session.fileId] =
                ReceivedChunkTracker(totalChunks: session.totalChunks);
            await _repository.updateTransferState(
              session.transferId,
              MeshFileTransferState.receiving,
            );
          }
        } else {
          await _repository.updateTransferState(
            session.transferId,
            MeshFileTransferState.failed,
            errorMessage:
                'High-speed local transfer unavailable. This file exceeds the offline BLE transfer limit.',
          );
          _outgoingFiles.remove(ack.fileId);
        }
        break;

      case MeshFileAckType.fileOfferReject:
        await _repository.updateTransferState(
          session.transferId,
          MeshFileTransferState.rejected,
          errorMessage: 'Offer rejected by peer',
        );
        _outgoingFiles.remove(ack.fileId);
        break;

      case MeshFileAckType.transferComplete:
        await _repository.updateTransferState(
          session.transferId,
          MeshFileTransferState.completed,
        );
        _outgoingFiles.remove(ack.fileId);
        break;

      case MeshFileAckType.transferFailed:
        await _repository.updateTransferState(
          session.transferId,
          MeshFileTransferState.integrityFailure,
          errorMessage: 'Recipient reported transfer or integrity failure',
        );
        _outgoingFiles.remove(ack.fileId);
        break;

      case MeshFileAckType.transferCancelled:
        await _repository.updateTransferState(
          session.transferId,
          MeshFileTransferState.cancelled,
          errorMessage: 'Transfer cancelled by peer',
        );
        _outgoingFiles.remove(ack.fileId);
        break;

      case MeshFileAckType.chunkAck:
        // Optional window ACK
        break;
    }
  }

  /// Starts the sender HTTP streaming server and sends WIFI_READY over BLE.
  Future<void> _startWifiServerAndSignalReady(MeshFileTransferSession session) async {
    final file = _outgoingFiles[session.fileId];
    if (file == null || !await file.exists()) {
      await _repository.updateTransferState(
        session.transferId,
        MeshFileTransferState.failed,
        errorMessage: 'Source file missing during Wi-Fi setup',
      );
      return;
    }

    try {
      final cap = await _wifiCapabilityDetector.detectCapability();
      final localIp = cap.ipAddress ?? '127.0.0.1';

      final wifiSession = await _wifiTransport.startSenderServer(
        session: session,
        file: file,
        localIpAddress: localIp,
      );

      await _repository.updateTransferState(
        session.transferId,
        MeshFileTransferState.connecting,
      );

      final readyAck = MeshFileAck(
        fileId: session.fileId,
        ackType: MeshFileAckType.wifiReady,
        wifiHost: wifiSession.host,
        wifiPort: wifiSession.port,
        wifiToken: wifiSession.authToken,
      );
      await _broadcastAck(readyAck);
    } catch (e) {
      if (session.fileSize <= MeshFileOffer.maxBleFileSizeBytes) {
        await _repository.updateTransferState(
          session.transferId,
          MeshFileTransferState.fallback,
        );
        await _repository.updateTransferState(
          session.transferId,
          MeshFileTransferState.sending,
        );
        final fallbackAck = MeshFileAck(
          fileId: session.fileId,
          ackType: MeshFileAckType.wifiFallback,
        );
        await _broadcastAck(fallbackAck);
        unawaited(_streamChunksToPeer(session));
      } else {
        await _repository.updateTransferState(
          session.transferId,
          MeshFileTransferState.failed,
          errorMessage:
              'High-speed local transfer unavailable. This file exceeds the offline BLE transfer limit.',
        );
      }
    }
  }

  /// Connects to peer HTTP server over local Wi-Fi and streams file payload directly to disk.
  Future<void> _receiveWifiFileStream(
    MeshFileTransferSession session,
    MeshFileAck ack,
  ) async {
    final targetTempFile = await _storage.createTemporaryIncomingFile(session.fileId);
    _incomingTempFiles[session.fileId] = targetTempFile;

    final sessionWithWifi = session.copyWith(
      wifiHost: ack.wifiHost,
      wifiPort: ack.wifiPort,
      wifiToken: ack.wifiToken,
      state: MeshFileTransferState.transferring,
    );

    await _repository.updateTransferState(
      session.transferId,
      MeshFileTransferState.transferring,
    );

    try {
      final completedFile = await _wifiTransport.receive(
        session: sessionWithWifi,
        targetFile: targetTempFile,
        onProgress: (update) {
          _repository.updateProgress(
            session.transferId,
            transferredBytes: update.transferredBytes,
            transferredChunks: 1,
          );
        },
      );

      await _repository.updateTransferState(
        session.transferId,
        MeshFileTransferState.verifying,
      );

      final finalFile = await _storage.finalizeAndVerifyFile(
        tempFile: completedFile,
        fileId: session.fileId,
        originalFilename: session.filename,
        expectedSha256: session.sha256,
      );

      await _repository.updateTransferState(
        session.transferId,
        MeshFileTransferState.completed,
        localFilePath: finalFile.path,
      );

      final completeAck = MeshFileAck(
        fileId: session.fileId,
        ackType: MeshFileAckType.transferComplete,
      );
      await _broadcastAck(completeAck);
    } on MeshAirDropIntegrityException catch (e) {
      await _repository.updateTransferState(
        session.transferId,
        MeshFileTransferState.integrityFailure,
        errorMessage: e.toString(),
      );
      final failedAck = MeshFileAck(
        fileId: session.fileId,
        ackType: MeshFileAckType.transferFailed,
        reasonCode: 0x01,
      );
      await _broadcastAck(failedAck);
    } catch (e) {
      if (session.fileSize <= MeshFileOffer.maxBleFileSizeBytes) {
        await _repository.updateTransferState(
          session.transferId,
          MeshFileTransferState.fallback,
        );
        _chunkTrackers[session.fileId] =
            ReceivedChunkTracker(totalChunks: session.totalChunks);
        await _repository.updateTransferState(
          session.transferId,
          MeshFileTransferState.receiving,
        );
        final fallbackAck = MeshFileAck(
          fileId: session.fileId,
          ackType: MeshFileAckType.wifiFallback,
        );
        await _broadcastAck(fallbackAck);
      } else {
        await _repository.updateTransferState(
          session.transferId,
          MeshFileTransferState.failed,
          errorMessage:
              'High-speed local transfer unavailable. This file exceeds the offline BLE transfer limit.',
        );
        final failedAck = MeshFileAck(
          fileId: session.fileId,
          ackType: MeshFileAckType.transferFailed,
        );
        await _broadcastAck(failedAck);
      }
    }
  }

  /// Streams chunks from local source file incrementally to peer.
  ///
  /// Guarantees:
  /// - File is NEVER loaded completely into RAM.
  /// - Chunks stream sequentially with configurable radio pacing.
  /// - Progress is updated in SQLite after each chunk broadcast.
  Future<void> _streamChunksToPeer(MeshFileTransferSession session) async {
    final file = _outgoingFiles[session.fileId];
    if (file == null || !await file.exists()) {
      await _repository.updateTransferState(
        session.transferId,
        MeshFileTransferState.failed,
        errorMessage: 'Source file missing during chunk transmission',
      );
      return;
    }

    const chunkSize = MeshFileOffer.defaultChunkSize;
    int transferredBytes = 0;
    int transferredChunks = 0;

    await for (final chunk in _storage.readChunks(
      file: file,
      fileId: session.fileId,
      chunkSize: chunkSize,
      totalChunks: session.totalChunks,
    )) {
      if (_isDisposed) return;

      // Check if session was cancelled or terminated in the meantime
      try {
        final current = await _repository.getTransfer(session.transferId);
        if (current == null || current.state != MeshFileTransferState.sending) {
          return;
        }
      } catch (_) {
        if (_isDisposed) return;
        rethrow;
      }

      if (_isDisposed) return;

      // Construct fileChunk mesh packet
      final packet = MeshPacket(
        packetId: MeshPacket.generatePacketId(),
        packetType: MeshPacketType.fileChunk,
        ttl: MeshPacket.defaultTtl,
        hopCount: 0,
        senderDeviceId: _meshService.localDeviceId,
        senderRole: _meshService.localRole,
        timestamp: DateTime.now(),
        payload: chunk.toBytes(),
      );

      await _meshService.broadcastPacket(packet);

      transferredChunks++;
      transferredBytes = min(transferredChunks * chunkSize, session.fileSize);

      if (!_isDisposed) {
        try {
          await _repository.updateProgress(
            session.transferId,
            transferredBytes: transferredBytes,
            transferredChunks: transferredChunks,
          );
        } catch (_) {
          if (_isDisposed) return;
        }
      }

      if (_chunkPacing.inMilliseconds > 0 && !_isDisposed) {
        await Future.delayed(_chunkPacing);
      }
    }
  }

  Future<PassportTrustBundle?> _resolveTrustBundle() async {
    if (_mockTrustBundle != null) return _mockTrustBundle;
    final tbs = _trustBundleService;
    if (tbs != null) {
      return await tbs.getLocalBundle();
    }
    return null;
  }

  String _generateFileId() {
    final rand = Random.secure();
    final bytes = List<int>.generate(16, (_) => rand.nextInt(256));
    return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }

  String _inferMimeType(String filename) {
    final ext = filename.split('.').last.toLowerCase();
    switch (ext) {
      case 'pdf':
        return 'application/pdf';
      case 'txt':
        return 'text/plain';
      case 'png':
        return 'image/png';
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'zip':
        return 'application/zip';
      case 'docx':
      case 'doc':
        return 'application/msword';
      case 'pptx':
      case 'ppt':
        return 'application/vnd.ms-powerpoint';
      case 'xlsx':
      case 'xls':
        return 'application/vnd.ms-excel';
      default:
        return 'application/octet-stream';
    }
  }

  /// Closes subscriptions and controllers.
  Future<void> dispose() async {
    _isDisposed = true;
    await _meshSubscription?.cancel();
    await _incomingOffersController.close();
    await _wifiTransport.dispose();
    await _bleTransport.dispose();
    await _udpDiscovery?.stop();
  }
}
