import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'campus_mesh_service.dart';

/// Native BitChat-compatible BLE GATT Client/Server adapter for CampusOS Mesh on Android.
///
/// Unlike legacy advertising which is limited to 31 bytes total and prone to
/// `ADVERTISE_FAILED_DATA_TOO_LARGE`, this adapter implements true 2-way BitChat
/// GATT Client/Server connections:
/// 1. Hosts a GATT Server with BitChat Service & Characteristic UUIDs.
/// 2. Advertises Service UUID so nearby peers can discover this device.
/// 3. Scans for peers advertising Service UUID and establishes GATT Client connections.
/// 4. Negotiates 517-byte MTU for high-throughput packet transfers.
/// 5. Transmits full packets via characteristic writes and server notifications.
class CampusBleGattAdapter implements MeshBleAdapter {
  static const MethodChannel _methodChannel = MethodChannel('campusos/ble_gatt_mesh');
  static const EventChannel _eventChannel = EventChannel('campusos/ble_gatt_mesh/packets');

  final PlatformMeshBleAdapter _fallbackAdapter = PlatformMeshBleAdapter();

  StreamSubscription? _packetSubscription;
  bool _isRunning = false;

  bool get isRunning => _isRunning;

  @override
  Future<bool> isBluetoothAvailable() async {
    try {
      if (Platform.isAndroid) {
        final isSupported = await FlutterBluePlus.isSupported;
        if (!isSupported) return false;
        final state = await FlutterBluePlus.adapterState.first
            .timeout(const Duration(milliseconds: 1500), onTimeout: () => BluetoothAdapterState.unknown);
        return state == BluetoothAdapterState.on || state == BluetoothAdapterState.unknown;
      }
    } catch (_) {}
    return _fallbackAdapter.isBluetoothAvailable();
  }

  @override
  Future<bool> requestPermissions() async {
    try {
      if (Platform.isAndroid) {
        final scanStatus = await Permission.bluetoothScan.request();
        final advertiseStatus = await Permission.bluetoothAdvertise.request();
        final connectStatus = await Permission.bluetoothConnect.request();
        final locationStatus = await Permission.location.request();

        final bleGranted = (scanStatus.isGranted || scanStatus.isLimited) &&
            (advertiseStatus.isGranted || advertiseStatus.isLimited) &&
            (connectStatus.isGranted || connectStatus.isLimited);

        final locationGranted = locationStatus.isGranted || locationStatus.isLimited;

        // On Android 12+ (API 31+), Bluetooth permissions are sufficient for BLE GATT.
        // On older Android versions, location permission is required.
        return bleGranted || locationGranted;
      }
    } catch (_) {}
    return _fallbackAdapter.requestPermissions();
  }

  @override
  Future<bool> startScanning({
    required void Function(Uint8List rawBytes, int rssi) onPacketDiscovered,
  }) async {
    if (_isRunning) return true;

    if (Platform.isAndroid) {
      try {
        await _packetSubscription?.cancel();
        _packetSubscription = _eventChannel.receiveBroadcastStream().listen(
          (dynamic event) {
            try {
              if (event is Uint8List) {
                onPacketDiscovered(event, -40);
              } else if (event is List) {
                onPacketDiscovered(Uint8List.fromList(event.cast<int>()), -40);
              }
            } catch (e) {
              debugPrint('⚠️ [GATT_ADAPTER] Error decoding inbound GATT packet: $e');
            }
          },
          onError: (e) {
            debugPrint('⚠️ [GATT_ADAPTER] Packet event stream error: $e');
          },
        );

        final bool? success = await _methodChannel.invokeMethod<bool>('startMesh');
        if (success == true) {
          _isRunning = true;
          debugPrint('🟢 [GATT_ADAPTER] BitChat Native GATT Client/Server mesh started');
          return true;
        }
      } catch (e) {
        debugPrint('ℹ️ [GATT_ADAPTER] Native GATT start failed, falling back to legacy: $e');
      }
    }

    // Fallback if not Android or if native GATT throws
    final fallbackOk = await _fallbackAdapter.startScanning(onPacketDiscovered: onPacketDiscovered);
    _isRunning = fallbackOk;
    return fallbackOk;
  }

  @override
  Future<void> stopScanning() async {
    await stopAdvertising();
  }

  @override
  Future<bool> advertisePacket(Uint8List rawBytes) async {
    if (Platform.isAndroid && _isRunning) {
      try {
        final int? sentCount = await _methodChannel.invokeMethod<int>('sendPacket', rawBytes);
        return (sentCount ?? 0) >= 0;
      } catch (e) {
        debugPrint('⚠️ [GATT_ADAPTER] Send packet failed via GATT: $e');
        return false;
      }
    }

    return _fallbackAdapter.advertisePacket(rawBytes);
  }

  @override
  Future<void> stopAdvertising() async {
    _isRunning = false;
    try {
      await _packetSubscription?.cancel();
      _packetSubscription = null;
      if (Platform.isAndroid) {
        await _methodChannel.invokeMethod('stopMesh');
      }
    } catch (_) {}
    await _fallbackAdapter.stopScanning();
    await _fallbackAdapter.stopAdvertising();
  }

  Future<void> pauseAdvertising() async {
    if (Platform.isAndroid && _isRunning) {
      try {
        await _methodChannel.invokeMethod('pauseAdvertising');
      } catch (e) {
        debugPrint('⚠️ [GATT_ADAPTER] pauseAdvertising error: $e');
      }
    }
    await _fallbackAdapter.pauseAdvertising();
  }

  Future<void> resumeAdvertising() async {
    if (Platform.isAndroid && _isRunning) {
      try {
        await _methodChannel.invokeMethod('resumeAdvertising');
      } catch (e) {
        debugPrint('⚠️ [GATT_ADAPTER] resumeAdvertising error: $e');
      }
    }
    await _fallbackAdapter.resumeAdvertising();
  }

  @override
  Future<void> dispose() async {
    await stopAdvertising();
    await _fallbackAdapter.dispose();
  }
}
