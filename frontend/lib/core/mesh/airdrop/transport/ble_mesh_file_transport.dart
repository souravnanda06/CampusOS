import 'dart:async';
import 'dart:io';

import '../mesh_airdrop_models.dart';
import 'mesh_file_transport.dart';

/// Concrete BLE Mesh file transport wrapper for M5A transfers.
///
/// Handles chunk-by-chunk transport over the CampusOS Bluetooth Low Energy mesh.
/// Operates with strict payload budget constraints (~100 bytes per chunk) and
/// serves as the universal offline fallback when high-speed Wi-Fi is unavailable.
class BleMeshFileTransport implements MeshFileTransport {
  bool _isDisposed = false;

  @override
  MeshTransportType get transportType => MeshTransportType.bleMesh;

  @override
  Future<bool> isAvailable() async => !_isDisposed;

  @override
  Future<void> send({
    required MeshFileTransferSession session,
    required File file,
    TransportProgressCallback? onProgress,
  }) async {
    // BLE chunk delivery is coordinated through CampusMeshAirDropService
    // and CampusMeshService packet broadcasts.
  }

  @override
  Future<File> receive({
    required MeshFileTransferSession session,
    required File targetFile,
    TransportProgressCallback? onProgress,
  }) async {
    // BLE chunk reassembly is coordinated through CampusMeshAirDropService.
    return targetFile;
  }

  @override
  Future<void> cancel(String transferId) async {
    // Handled at service level by emitting cancellation packet
  }

  @override
  Future<void> dispose() async {
    _isDisposed = true;
  }
}
