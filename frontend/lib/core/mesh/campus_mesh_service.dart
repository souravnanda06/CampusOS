import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_ble_peripheral/flutter_ble_peripheral.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';

import 'campus_ble_gatt_adapter.dart';
import 'local_mesh_socket_transport.dart';
import 'mesh_crypto.dart';
import 'mesh_deduplication_store.dart';
import 'mesh_packet.dart';
import 'mesh_packet_codec.dart';
import 'mesh_peer.dart';
import 'mesh_peer_registry.dart';
import 'mesh_relay_engine.dart';

/// CampusOS Mesh Service Lifecycle status.
enum MeshStateStatus {
  disabled,
  initializing,
  active,
  degraded,
  unavailable,
  error,
}

/// Specific reason explaining the current [MeshStateStatus].
enum MeshStateReason {
  bluetoothUnavailable,
  bluetoothPermissionDenied,
  scanningUnavailable,
  advertisingUnavailable,
  activeMesh,
  idle,
  internalError,
}

/// Composite state describing the operational condition of the mesh engine.
class MeshServiceState {
  final MeshStateStatus status;
  final MeshStateReason reason;
  final String? details;

  const MeshServiceState({
    required this.status,
    required this.reason,
    this.details,
  });

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! MeshServiceState) return false;
    return status == other.status && reason == other.reason && details == other.details;
  }

  @override
  int get hashCode => Object.hash(status, reason, details);

  @override
  String toString() => 'MeshServiceState(status: $status, reason: $reason, details: $details)';
}

/// Error report emitted on the mesh service error stream.
class MeshServiceError {
  final String message;
  final Object? cause;
  final StackTrace? stackTrace;

  const MeshServiceError({
    required this.message,
    this.cause,
    this.stackTrace,
  });

  @override
  String toString() => 'MeshServiceError(message: $message, cause: $cause)';
}

/// Abstract contract for Bluetooth Low Energy advertising and scanning.
///
/// Enables robust testing via mocks/fakes without physical radio hardware.
abstract class MeshBleAdapter {
  /// Checks whether Bluetooth is enabled and supported on the host device.
  Future<bool> isBluetoothAvailable();

  /// Requests runtime Bluetooth and location permissions.
  Future<bool> requestPermissions();

  /// Starts listening for CampusOS Mesh BLE advertisements.
  Future<bool> startScanning({
    required void Function(Uint8List rawBytes, int rssi) onPacketDiscovered,
  });

  /// Stops BLE scanning.
  Future<void> stopScanning();

  /// Broadcasts raw packet bytes via BLE advertising.
  Future<bool> advertisePacket(Uint8List rawBytes);

  /// Stops BLE advertising.
  Future<void> stopAdvertising();

  /// Releases underlying hardware handles and subscriptions.
  Future<void> dispose();
}

/// Production implementation of [MeshBleAdapter] utilizing [flutter_blue_plus]
/// and [flutter_ble_peripheral].
///
/// Isolation:
/// - Dedicated 128-bit Service UUID: `0000CA05-0000-1000-8000-00805F9B34FB`
/// - Dedicated Manufacturer ID: `0xCA05`
/// - Does not collide with or alter Passport Attendance or Passport Challenge BLE flows.
class PlatformMeshBleAdapter implements MeshBleAdapter {
  /// Dedicated CampusOS Mesh BLE 128-bit service UUID.
  static const String meshServiceUuid = '0000CA05-0000-1000-8000-00805F9B34FB';

  /// Dedicated 16-bit manufacturer identifier for CampusOS Mesh advertisements.
  static const int meshManufacturerId = 0xCA05;

  final FlutterBlePeripheral _peripheral;
  StreamSubscription? _scanSubscription;
  bool _isScanning = false;
  bool _isAdvertising = false;

  PlatformMeshBleAdapter({
    FlutterBlePeripheral? peripheral,
  }) : _peripheral = peripheral ?? FlutterBlePeripheral();

  /// Whether BLE scanning is currently running.
  bool get isScanning => _isScanning;

  /// Whether BLE advertising is currently active.
  bool get isAdvertising => _isAdvertising;

  @override
  Future<bool> isBluetoothAvailable() async {
    try {
      final isSupported = await FlutterBluePlus.isSupported;
      if (!isSupported) {
        debugPrint('⚠️ [MESH_BLE] Bluetooth not supported on device');
        return false;
      }
      final adapterState = await FlutterBluePlus.adapterState
          .first
          .timeout(const Duration(milliseconds: 1500), onTimeout: () => BluetoothAdapterState.unknown);
      if (adapterState == BluetoothAdapterState.on) return true;
      if (adapterState == BluetoothAdapterState.unknown) {
        return true; // Graceful non-blocking fallback
      }
      return false;
    } catch (e) {
      debugPrint('⚠️ [MESH_BLE] Error querying adapter state: $e');
      return true; // Non-blocking fallback
    }
  }

  @override
  Future<bool> requestPermissions() async {
    try {
      if (!kIsWeb && Platform.isAndroid) {
        int sdkInt = 31;
        try {
          sdkInt = (await DeviceInfoPlugin().androidInfo).version.sdkInt;
        } catch (_) {}

        if (sdkInt >= 31) {
          final statuses = await [
            Permission.bluetoothScan,
            Permission.bluetoothAdvertise,
            Permission.bluetoothConnect,
          ].request();

          final scanOk = (statuses[Permission.bluetoothScan]?.isGranted ?? false) ||
              (statuses[Permission.bluetoothScan]?.isLimited ?? false);
          final advOk = (statuses[Permission.bluetoothAdvertise]?.isGranted ?? false) ||
              (statuses[Permission.bluetoothAdvertise]?.isLimited ?? false);
          final connOk = (statuses[Permission.bluetoothConnect]?.isGranted ?? false) ||
              (statuses[Permission.bluetoothConnect]?.isLimited ?? false);
          return scanOk && advOk && connOk;
        } else {
          final locStatus = await Permission.locationWhenInUse.request();
          return locStatus.isGranted || locStatus.isLimited;
        }
      } else if (!kIsWeb && Platform.isIOS) {
        final btStatus = await Permission.bluetooth.request();
        return btStatus.isGranted || btStatus.isLimited;
      }
      return true;
    } catch (e) {
      debugPrint('⚠️ [MESH_BLE] Permission request error: $e');
      return false;
    }
  }

  @override
  Future<bool> startScanning({
    required void Function(Uint8List rawBytes, int rssi) onPacketDiscovered,
  }) async {
    if (_isScanning) return true;

    try {
      await stopScanning();

      _scanSubscription = FlutterBluePlus.onScanResults.listen((results) {
        for (final r in results) {
          // Look for dedicated mesh service data or manufacturer data
          final serviceData = r.advertisementData.serviceData;
          for (final entry in serviceData.entries) {
            if (entry.key.toString().toUpperCase().contains('CA05')) {
              onPacketDiscovered(Uint8List.fromList(entry.value), r.rssi);
              return;
            }
          }

          final manufacturerData = r.advertisementData.manufacturerData;
          if (manufacturerData.containsKey(meshManufacturerId)) {
            final data = manufacturerData[meshManufacturerId]!;
            onPacketDiscovered(Uint8List.fromList(data), r.rssi);
            return;
          }
        }
      });

      // Avoid hardware filter 'withServices' which discards manufacturer-data advertisements
      // on many Android chipsets. Dart listener above filters by CA05 safely.
      await FlutterBluePlus.startScan(
        continuousUpdates: true,
      );

      _isScanning = true;
      return true;
    } catch (e) {
      debugPrint('⚠️ [MESH_BLE] Failed to start scanning: $e');
      _isScanning = false;
      return false;
    }
  }

  @override
  Future<void> stopScanning() async {
    try {
      await _scanSubscription?.cancel();
      _scanSubscription = null;
      final isScanning = await FlutterBluePlus.isScanning.first
          .timeout(const Duration(milliseconds: 500), onTimeout: () => false);
      if (isScanning) {
        await FlutterBluePlus.stopScan();
      }
    } catch (_) {}
    _isScanning = false;
  }

  @override
  Future<bool> advertisePacket(Uint8List rawBytes) async {
    try {
      final Uint8List dataToAdvertise = rawBytes;

      final advertiseData = AdvertiseData(
        serviceUuid: meshServiceUuid,
        manufacturerId: meshManufacturerId,
        manufacturerData: dataToAdvertise,
        includeDeviceName: false,
      );

      await _peripheral.stop();
      try {
        await _peripheral.start(
          advertiseData: advertiseData,
          advertiseSetParameters: AdvertiseSetParameters(legacyMode: false),
        );
      } catch (_) {
        // Fallback for Android chipsets lacking BLE 5.0 Extended Advertising (legacy mode)
        await _peripheral.start(
          advertiseData: advertiseData,
        );
      }
      _isAdvertising = true;
      return true;
    } catch (e) {
      debugPrint('⚠️ [MESH_BLE] Advertising error: $e');
      _isAdvertising = false;
      return false;
    }
  }

  @override
  Future<void> stopAdvertising() async {
    try {
      await _peripheral.stop();
    } catch (_) {}
    _isAdvertising = false;
  }

  Future<void> pauseAdvertising() async {
    await stopAdvertising();
  }

  Future<void> resumeAdvertising() async {
    // PlatformMeshBleAdapter advertises on-demand per packet
  }

  @override
  Future<void> dispose() async {
    await stopScanning();
    await stopAdvertising();
  }
}

/// Core CampusOS Mesh Service coordinating packet reception, decoding, peer discovery,
/// deduplication, and relay forwarding.
class CampusMeshService {
  final String localDeviceId;
  final String? localDisplayName;
  String _localRole;
  String get localRole => _localRole;
  void setLocalRole(String role) {
    _localRole = role.trim().toLowerCase();
  }

  final MeshBleAdapter _adapter;
  final MeshPacketCodec _codec;
  final MeshDeduplicationStore _deduplicationStore;
  final MeshPeerRegistry _peerRegistry;
  final MeshRelayEngine _relayEngine;

  MeshServiceState _currentState = const MeshServiceState(
    status: MeshStateStatus.disabled,
    reason: MeshStateReason.idle,
    details: 'Service is stopped.',
  );

  bool _isRunning = false;
  Timer? _peerCleanupTimer;
  Timer? _heartbeatTimer;

  final StreamController<MeshPacket> _receivedPacketsController =
      StreamController<MeshPacket>.broadcast();

  final StreamController<MeshPacket> _relayedPacketsController =
      StreamController<MeshPacket>.broadcast();

  final StreamController<List<MeshPeer>> _peerUpdatesController =
      StreamController<List<MeshPeer>>.broadcast();

  final StreamController<MeshServiceState> _meshStateController =
      StreamController<MeshServiceState>.broadcast();

  final StreamController<MeshServiceError> _errorsController =
      StreamController<MeshServiceError>.broadcast();

  final MeshCryptoService? _cryptoService;
  final LocalMeshSocketTransport? _socketTransport;
  LocalMeshSocketTransport? _localSocketTransport;
  final bool allowUncertifiedChatPeers;

  factory CampusMeshService({
    required String localDeviceId,
    String? localDisplayName,
    required String localRole,
    MeshBleAdapter? adapter,
    MeshPacketCodec? codec,
    MeshDeduplicationStore? deduplicationStore,
    MeshPeerRegistry? peerRegistry,
    MeshRelayEngine? relayEngine,
    MeshCryptoService? cryptoService,
    LocalMeshSocketTransport? socketTransport,
    bool allowUncertifiedChatPeers = false,
  }) {
    final sharedDedup = deduplicationStore ?? MeshDeduplicationStore();
    return CampusMeshService._internal(
      localDeviceId: localDeviceId,
      localDisplayName: localDisplayName,
      localRole: localRole,
      adapter: adapter,
      codec: codec,
      deduplicationStore: sharedDedup,
      peerRegistry: peerRegistry,
      relayEngine: relayEngine ??
          MeshRelayEngine(
            localDeviceId: localDeviceId,
            deduplicationStore: sharedDedup,
          ),
      cryptoService: cryptoService,
      socketTransport: socketTransport,
      allowUncertifiedChatPeers: allowUncertifiedChatPeers,
    );
  }

  CampusMeshService._internal({
    required this.localDeviceId,
    this.localDisplayName,
    required String localRole,
    MeshBleAdapter? adapter,
    MeshPacketCodec? codec,
    required MeshDeduplicationStore deduplicationStore,
    MeshPeerRegistry? peerRegistry,
    required MeshRelayEngine relayEngine,
    MeshCryptoService? cryptoService,
    LocalMeshSocketTransport? socketTransport,
    this.allowUncertifiedChatPeers = false,
  })  : _localRole = localRole.trim().toLowerCase(),
        _adapter = adapter ?? (!kIsWeb && Platform.isAndroid ? CampusBleGattAdapter() : PlatformMeshBleAdapter()),
        _codec = codec ?? const MeshPacketCodec(),
        _deduplicationStore = deduplicationStore,
        _peerRegistry = peerRegistry ?? MeshPeerRegistry(),
        _relayEngine = relayEngine,
        _cryptoService = cryptoService,
        _socketTransport = socketTransport;

  /// Current state of the mesh service.
  MeshServiceState get currentState => _currentState;

  /// Whether the service is currently running.
  bool get isRunning => _isRunning;

  /// Hardware BLE adapter abstraction.
  MeshBleAdapter get adapter => _adapter;

  /// Cryptographic service instance, if configured.
  MeshCryptoService? get cryptoService => _cryptoService;

  /// Deduplication store instance.
  MeshDeduplicationStore get deduplicationStore => _deduplicationStore;

  /// Peer registry instance.
  MeshPeerRegistry get peerRegistry => _peerRegistry;

  /// Relay engine instance.
  MeshRelayEngine get relayEngine => _relayEngine;

  /// Stream of successfully received and validated inbound mesh packets.
  Stream<MeshPacket> get receivedPackets => _receivedPacketsController.stream;

  /// Stream of packets accepted and forwarded by the local relay engine.
  Stream<MeshPacket> get relayedPackets => _relayedPacketsController.stream;

  /// Stream of active peer list updates.
  Stream<List<MeshPeer>> get peerUpdates => _peerUpdatesController.stream;

  /// Stream of mesh service lifecycle states.
  Stream<MeshServiceState> get meshState => _meshStateController.stream;

  /// Stream of non-fatal operational errors.
  Stream<MeshServiceError> get errors => _errorsController.stream;

  /// Starts the mesh service: validates hardware & permissions, initializes scanning & advertising.
  ///
  /// Even if Bluetooth is unavailable or denied, initializes the local Wi-Fi/Hotspot UDP
  /// fallback transport on physical hardware so P2P chat continues over LAN/hotspot.
  Future<bool> start() async {
    if (_isRunning) return true;

    _updateState(const MeshServiceState(
      status: MeshStateStatus.initializing,
      reason: MeshStateReason.idle,
      details: 'Checking Bluetooth availability and permissions...',
    ));

    // Always start offline local socket transport on physical hardware (Wi-Fi/Hotspot fallback)
    final isPhysicalHardware = _adapter is PlatformMeshBleAdapter || _adapter is CampusBleGattAdapter;
    if (_socketTransport == null && isPhysicalHardware) {
      _localSocketTransport ??= LocalMeshSocketTransport(
        onPacketReceived: (data, rssi) => handleIncomingRawData(data, rssi: rssi),
      );
    }
    await (_socketTransport ?? _localSocketTransport)?.start();

    // 1. Bluetooth availability check
    final isBtAvailable = await _adapter.isBluetoothAvailable();
    if (!isBtAvailable) {
      _updateState(const MeshServiceState(
        status: MeshStateStatus.unavailable,
        reason: MeshStateReason.bluetoothUnavailable,
        details: 'Bluetooth adapter is disabled or unavailable. Using Wi-Fi/Hotspot & Cloud fallback.',
      ));
      return false;
    }

    // 2. Permission check
    final permissionsGranted = await _adapter.requestPermissions();
    if (!permissionsGranted) {
      _updateState(const MeshServiceState(
        status: MeshStateStatus.unavailable,
        reason: MeshStateReason.bluetoothPermissionDenied,
        details: 'Bluetooth permissions were denied. Using Wi-Fi/Hotspot & Cloud fallback.',
      ));
      return false;
    }

    // 3. Start scanning
    final scanOk = await _adapter.startScanning(
      onPacketDiscovered: (rawBytes, rssi) {
        handleIncomingRawData(rawBytes, rssi: rssi);
      },
    );

    if (!scanOk) {
      _updateState(const MeshServiceState(
        status: MeshStateStatus.degraded,
        reason: MeshStateReason.scanningUnavailable,
        details: 'Failed to start BLE scanner. Mesh can only transmit.',
      ));
      return false;
    }

    // 5. Mesh operational
    _isRunning = true;
    _updateState(const MeshServiceState(
      status: MeshStateStatus.active,
      reason: MeshStateReason.activeMesh,
      details: 'CampusOS BLE Mesh active (scanning enabled).',
    ));

    // Periodic peer inactive cleanup
    _peerCleanupTimer?.cancel();
    _peerCleanupTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      _peerRegistry.cleanupInactivePeers();
      _peerUpdatesController.add(_peerRegistry.activePeers);
    });

    // BitChat + LocalSend periodic presence beacon (on physical hardware adapters)
    if (isPhysicalHardware) {
      _heartbeatTimer?.cancel();
      _heartbeatTimer = Timer.periodic(const Duration(seconds: 6), (_) {
        _broadcastPresenceHeartbeat();
      });
      _broadcastPresenceHeartbeat();
    }

    return true;
  }

  /// Stops all scanning, advertising, and background maintenance.
  Future<void> stop() async {
    _peerCleanupTimer?.cancel();
    _peerCleanupTimer = null;
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;

    await _adapter.stopScanning();
    await _adapter.stopAdvertising();
    await (_socketTransport ?? _localSocketTransport)?.stop();

    _isRunning = false;
    _updateState(const MeshServiceState(
      status: MeshStateStatus.disabled,
      reason: MeshStateReason.idle,
      details: 'CampusOS Mesh service stopped.',
    ));
  }

  /// Pauses background mesh advertising so high-priority operations (BLE attendance) can use advertiser hardware slots.
  Future<void> pauseAdvertising() async {
    try {
      if (_adapter is CampusBleGattAdapter) {
        await (_adapter as CampusBleGattAdapter).pauseAdvertising();
      } else if (_adapter is PlatformMeshBleAdapter) {
        await (_adapter as PlatformMeshBleAdapter).pauseAdvertising();
      }
    } catch (_) {}
  }

  /// Resumes background mesh advertising after high-priority operations finish.
  Future<void> resumeAdvertising() async {
    try {
      if (_adapter is CampusBleGattAdapter) {
        await (_adapter as CampusBleGattAdapter).resumeAdvertising();
      } else if (_adapter is PlatformMeshBleAdapter) {
        await (_adapter as PlatformMeshBleAdapter).resumeAdvertising();
      }
    } catch (_) {}
  }

  /// Broadcasts a lightweight BitChat / LocalSend heartbeat to announce presence to peers.
  Future<void> _broadcastPresenceHeartbeat() async {
    if (!_isRunning) return;
    try {
      final now = DateTime.now();
      final packetId = MeshPacket.generatePacketId();
      final pingName = (localDisplayName != null && localDisplayName!.isNotEmpty)
          ? localDisplayName!
          : localDeviceId;
      final payloadBytes = Uint8List.fromList(utf8.encode(jsonEncode({
        'cid': 'system:heartbeat',
        'txt': 'ping',
        'name': pingName,
      })));

      final pingPacket = MeshPacket(
        packetId: packetId,
        packetType: MeshPacketType.chat,
        ttl: 1,
        hopCount: 0,
        senderDeviceId: localDeviceId,
        senderRole: localRole,
        timestamp: now,
        payload: payloadBytes,
      );

      final encoded = _codec.encode(pingPacket);
      await (_socketTransport ?? _localSocketTransport)?.broadcast(encoded);
      await _adapter.advertisePacket(encoded);
    } catch (_) {}
  }

  /// Broadcasts an outbound [MeshPacket] created by the local device.
  ///
  /// If a [MeshCryptoService] is configured and the packet is not yet signed,
  /// it is automatically signed using the local identity key before transmission.
  /// Returns `true` if transmission succeeded, `false` otherwise.
  Future<bool> broadcastPacket(MeshPacket packet) async {
    try {
      MeshPacket packetToBroadcast = packet;
      if (_cryptoService != null && packet.signature.isEmpty) {
        packetToBroadcast = await _cryptoService!.signPacket(packet);
      }

      final encoded = _codec.encode(packetToBroadcast);
      // Register locally created packet to prevent self-loop echo
      _deduplicationStore.add(packetToBroadcast.packetId);

      // 1. Broadcast via offline local socket transport (if available/connected to Wi-Fi/Hotspot)
      final transport = _socketTransport ?? _localSocketTransport;
      final socketOk = await transport?.broadcast(encoded) ?? false;

      // 2. Broadcast via BLE adapter (skip when BLE is explicitly unavailable/denied)
      final bleUnavailable = _currentState.status == MeshStateStatus.unavailable &&
          (_currentState.reason == MeshStateReason.bluetoothPermissionDenied ||
              _currentState.reason == MeshStateReason.bluetoothUnavailable);
      final bleOk = bleUnavailable ? false : await _adapter.advertisePacket(encoded);

      final ok = socketOk || bleOk;
      if (!ok && !bleUnavailable) {
        _notifyError('Failed to advertise mesh packet over BLE or offline socket');
      }
      return ok;
    } on MeshCodecException catch (e, st) {
      _notifyError('Mesh codec error encoding packet: ${e.message}', cause: e, stackTrace: st);
      return false;
    } catch (e, st) {
      _notifyError('Unexpected error broadcasting packet: $e', cause: e, stackTrace: st);
      return false;
    }
  }

  /// Ingests and processes raw inbound advertisement bytes.
  Future<void> handleIncomingRawData(Uint8List rawBytes, {int? rssi}) async {
    MeshPacket packet;
    try {
      packet = _codec.decode(rawBytes);
    } on MeshCodecException catch (e) {
      // Malformed or non-mesh packet: ignore silently or log without crashing
      debugPrint('ℹ️ [MESH_SERVICE] Ignored non-mesh/malformed advertisement: ${e.message}');
      return;
    } catch (e, st) {
      _notifyError('Error decoding incoming advertisement bytes: $e', cause: e, stackTrace: st);
      return;
    }

    // Inspect payload for sender display name (heartbeat, digest, chat, etc.)
    String? peerDisplayName;
    if (packet.payload.isNotEmpty) {
      try {
        final decodedMap = jsonDecode(utf8.decode(packet.payload));
        if (decodedMap is Map<String, dynamic>) {
          final candidateName = decodedMap['name']?.toString() ??
              decodedMap['senderDisplayName']?.toString();
          if (candidateName != null &&
              candidateName.trim().isNotEmpty &&
              candidateName.trim() != packet.senderDeviceId) {
            peerDisplayName = candidateName.trim();
          }
        }
      } catch (_) {}
    }

    // Update peer registry (never register self as a nearby peer)
    if (packet.senderDeviceId != localDeviceId) {
      _peerRegistry.registerOrUpdatePeer(
        deviceId: packet.senderDeviceId,
        displayName: peerDisplayName,
        role: packet.senderRole,
        packetId: packet.packetId,
        rssi: rssi,
        hopCount: packet.hopCount,
      );
      _peerUpdatesController.add(_peerRegistry.activePeers);
    }

    // Cryptographic & institutional trust verification if crypto service is configured
    if (_cryptoService != null) {
      final verifyResult = await _cryptoService!.verifyPacket(packet);

      final isChatOrAck = packet.packetType == MeshPacketType.chat ||
          packet.packetType == MeshPacketType.acknowledgement;
      final isAirDropPacket = packet.packetType == MeshPacketType.fileOffer ||
          packet.packetType == MeshPacketType.fileChunk ||
          packet.packetType == MeshPacketType.acknowledgement;
      final isUnsignedAllowed = allowUncertifiedChatPeers &&
          (isChatOrAck || isAirDropPacket) &&
          packet.signature.isEmpty &&
          verifyResult.status == MeshVerificationStatus.invalidSignature;

      // 1. Strict security across all packet types:
      // Drop if signature is invalid/tampered, timestamp is stale, role is unauthorized, or sender is revoked
      if ((verifyResult.status == MeshVerificationStatus.invalidSignature && !isUnsignedAllowed) ||
          verifyResult.status == MeshVerificationStatus.staleTimestamp ||
          verifyResult.status == MeshVerificationStatus.unauthorizedRole ||
          verifyResult.status == MeshVerificationStatus.revokedSender) {
        debugPrint('⚠️ [MESH_SERVICE] Dropped untrusted packet from ${packet.senderDeviceId}: ${verifyResult.status.name}');
        _notifyError('Inbound packet from ${packet.senderDeviceId} dropped: ${verifyResult.status.name}');
        return;
      }

      // 2. For emergency disaster flares (or uncertified P2P chat and AirDrop when enabled), allow unknown senders
      // to pass through as UNVERIFIED ('P2P') rather than silently dropping peer messages.
      if (verifyResult.status == MeshVerificationStatus.unknownSender) {
        if (packet.packetType == MeshPacketType.emergency || (allowUncertifiedChatPeers && (isChatOrAck || isAirDropPacket))) {
          debugPrint('ℹ️ [MESH_SERVICE] Allowing uncertified P2P ${packet.packetType.name} from ${packet.senderDeviceId} (${verifyResult.status.name})');
        } else {
          debugPrint('⚠️ [MESH_SERVICE] Dropped packet from unregistered node ${packet.senderDeviceId}');
          _notifyError('Inbound packet from ${packet.senderDeviceId} dropped: unknown sender');
          return;
        }
      }
    }

    // Deduplication check
    if (_deduplicationStore.contains(packet.packetId)) {
      debugPrint('ℹ️ [MESH_SERVICE] Dropped duplicate packet ${packet.packetIdHex}');
      return;
    }

    // Notify received packet stream
    _receivedPacketsController.add(packet);

    // Evaluate for relay forwarding
    if (packet.senderDeviceId != localDeviceId) {
      final relayResult = _relayEngine.evaluateAndPrepareRelay(packet);
      if (relayResult.isAccepted && relayResult.relayedPacket != null) {
        final forwardPacket = relayResult.relayedPacket!;
        final encoded = _codec.encode(forwardPacket);
        (_socketTransport ?? _localSocketTransport)?.broadcast(encoded);
        _adapter.advertisePacket(encoded).then((sent) {
          _relayedPacketsController.add(forwardPacket);
        }).catchError((e) {
          _notifyError('Failed to forward relayed packet: $e');
        });
      }
    }

    // Ensure packet ID is registered as seen
    _deduplicationStore.add(packet.packetId);
  }

  void _updateState(MeshServiceState newState) {
    if (_currentState != newState) {
      _currentState = newState;
      _meshStateController.add(newState);
    }
  }

  void _notifyError(String message, {Object? cause, StackTrace? stackTrace}) {
    if (!_errorsController.isClosed) {
      _errorsController.add(MeshServiceError(
        message: message,
        cause: cause,
        stackTrace: stackTrace,
      ));
    }
  }

  /// Checks whether Bluetooth permissions have been permanently denied on this device.
  Future<bool> isBluetoothPermissionPermanentlyDenied() async {
    try {
      if (kIsWeb) return false;
      if (Platform.isAndroid) {
        int sdkInt = 31;
        try {
          sdkInt = (await DeviceInfoPlugin().androidInfo).version.sdkInt;
        } catch (_) {}
        if (sdkInt >= 31) {
          return await Permission.bluetoothScan.isPermanentlyDenied ||
              await Permission.bluetoothAdvertise.isPermanentlyDenied ||
              await Permission.bluetoothConnect.isPermanentlyDenied;
        }
        return await Permission.locationWhenInUse.isPermanentlyDenied;
      } else if (Platform.isIOS) {
        return await Permission.bluetooth.isPermanentlyDenied;
      }
    } catch (_) {}
    return false;
  }

  /// Opens the OS app settings page so the user can re-enable permanently denied permissions.
  Future<bool> openPermissionSettings() async {
    try {
      return await openAppSettings();
    } catch (_) {
      return false;
    }
  }

  /// Disposes all internal resources, timers, and streams.
  Future<void> dispose() async {
    await stop();
    await _adapter.dispose();
    await _peerRegistry.dispose();
    await _relayEngine.dispose();
    await _receivedPacketsController.close();
    await _relayedPacketsController.close();
    await _peerUpdatesController.close();
    await _meshStateController.close();
    await _errorsController.close();
  }
}
