import 'dart:async';
import 'dart:io';

import '../mesh_airdrop_models.dart';

/// Progress snapshot emitted during active payload transport.
class TransportProgressUpdate {
  final int transferredBytes;
  final int totalBytes;
  final double speedKbps;

  const TransportProgressUpdate({
    required this.transferredBytes,
    required this.totalBytes,
    required this.speedKbps,
  });

  double get progress {
    if (totalBytes <= 0) return 0.0;
    return (transferredBytes / totalBytes).clamp(0.0, 1.0);
  }

  String get formattedSpeed {
    if (speedKbps >= 1024.0) {
      return '${(speedKbps / 1024.0).toStringAsFixed(1)} MB/s';
    }
    return '${speedKbps.toStringAsFixed(1)} KB/s';
  }
}

/// Callback invoked on incremental progress updates during transfer.
typedef TransportProgressCallback = void Function(TransportProgressUpdate update);

/// Abstract contract for delivering file payload bytes between CampusOS mesh peers.
///
/// Designed to decouple the authoritative cryptographic BLE negotiation from
/// the concrete physical payload transport (e.g. [BleMeshFileTransport] vs [LocalWifiFileTransport]).
abstract class MeshFileTransport {
  /// The transport type implemented by this transport engine.
  MeshTransportType get transportType;

  /// Checks if this transport mechanism is currently available and supported on the device.
  Future<bool> isAvailable();

  /// Sends file payload bytes to the peer using this transport.
  ///
  /// Streamed directly from disk without loading complete file into memory.
  Future<void> send({
    required MeshFileTransferSession session,
    required File file,
    TransportProgressCallback? onProgress,
  });

  /// Receives file payload bytes from the peer using this transport.
  ///
  /// Streamed directly to disk at [targetFile] without loading complete file into memory.
  Future<File> receive({
    required MeshFileTransferSession session,
    required File targetFile,
    TransportProgressCallback? onProgress,
  });

  /// Cancels an in-progress transfer session on this transport.
  Future<void> cancel(String transferId);

  /// Disposes of any resources, sockets, or open servers held by this transport.
  Future<void> dispose();
}
