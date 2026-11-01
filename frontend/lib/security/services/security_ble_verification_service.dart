import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

/// Explicit Gate Verification States as required by institutional gate specification.
enum GateBleState {
  idle,
  starting,
  active,
  processing,
  verified,
  duplicate,
  invalid,
  unavailable,
  failed,
  qrFallback,
  offline,
  syncPending,
}

extension GateBleStateExtension on GateBleState {
  String get displayName {
    switch (this) {
      case GateBleState.idle:
        return 'IDLE';
      case GateBleState.starting:
        return 'STARTING';
      case GateBleState.active:
        return 'ACTIVE';
      case GateBleState.processing:
        return 'PROCESSING';
      case GateBleState.verified:
        return 'VERIFIED';
      case GateBleState.duplicate:
        return 'DUPLICATE';
      case GateBleState.invalid:
        return 'INVALID';
      case GateBleState.unavailable:
        return 'UNAVAILABLE';
      case GateBleState.failed:
        return 'FAILED';
      case GateBleState.qrFallback:
        return 'QR_FALLBACK';
      case GateBleState.offline:
        return 'OFFLINE';
      case GateBleState.syncPending:
        return 'SYNC_PENDING';
    }
  }

  String get description {
    switch (this) {
      case GateBleState.idle:
        return 'Ready to scan';
      case GateBleState.starting:
        return 'Initializing BLE hardware...';
      case GateBleState.active:
        return 'Listening for nearby gate passes...';
      case GateBleState.processing:
        return 'Resolving cryptographic credential...';
      case GateBleState.verified:
        return 'Gate pass verified';
      case GateBleState.duplicate:
        return 'Pass already processed';
      case GateBleState.invalid:
        return 'Invalid or revoked pass';
      case GateBleState.unavailable:
        return 'Bluetooth unavailable or disabled';
      case GateBleState.failed:
        return 'BLE verification failed';
      case GateBleState.qrFallback:
        return 'Please scan student Gate Pass QR';
      case GateBleState.offline:
        return 'Operating in offline local mode';
      case GateBleState.syncPending:
        return 'Local event pending synchronization';
    }
  }
}

/// Service managing BLE proximity radar for gate transit verification.
class SecurityBleVerificationService {
  GateBleState _state = GateBleState.idle;
  String _statusMessage = 'Ready';

  final _stateController = StreamController<GateBleState>.broadcast();
  final _messageController = StreamController<String>.broadcast();

  Stream<GateBleState> get stateStream => _stateController.stream;
  Stream<String> get messageStream => _messageController.stream;

  GateBleState get currentState => _state;
  String get currentMessage => _statusMessage;

  StreamSubscription<List<ScanResult>>? _scanSubscription;
  Timer? _timeoutTimer;

  void _setState(GateBleState newState, String message) {
    _state = newState;
    _statusMessage = message;
    if (!_stateController.isClosed) {
      _stateController.add(newState);
    }
    if (!_messageController.isClosed) {
      _messageController.add(message);
    }
  }

  /// Starts BLE scanning for nearby gate devices with automatic timeout to QR fallback.
  Future<void> startScanning({Duration timeout = const Duration(seconds: 10)}) async {
    _setState(GateBleState.starting, 'Initializing BLE radar...');

    try {
      final isSupported = await FlutterBluePlus.isSupported.timeout(
        const Duration(seconds: 2),
        onTimeout: () => false,
      );
      if (!isSupported) {
        _setState(GateBleState.unavailable, 'Bluetooth Low Energy not supported on this device');
        _triggerFallback('BLE unsupported');
        return;
      }

      final adapterState = await FlutterBluePlus.adapterState
          .first
          .timeout(const Duration(seconds: 2), onTimeout: () => BluetoothAdapterState.unavailable);
      if (adapterState != BluetoothAdapterState.on) {
        _setState(GateBleState.unavailable, 'Bluetooth is turned off. Please enable Bluetooth.');
        _triggerFallback('Bluetooth off');
        return;
      }

      _setState(GateBleState.active, 'Scanning for nearby student devices...');

      // Stop any existing scan first
      await FlutterBluePlus.stopScan().catchError((_) {});

      // Start scan with timeout without location requirement
      await FlutterBluePlus.startScan(
        timeout: timeout,
        androidUsesFineLocation: false,
      );

      _scanSubscription = FlutterBluePlus.scanResults.listen((results) {
        _handleScanResults(results);
      }, onError: (err) {
        debugPrint("⚠️ [SECURITY_BLE] Scan error: $err");
        _setState(GateBleState.failed, 'BLE scan interrupted');
        _triggerFallback('Scan error');
      });

      _timeoutTimer?.cancel();
      _timeoutTimer = Timer(timeout, () {
        if (_state == GateBleState.active) {
          debugPrint("⏱️ [SECURITY_BLE] Scan timed out. Triggering QR fallback.");
          _triggerFallback('Scan timed out. No nearby device detected.');
        }
      });
    } catch (e) {
      debugPrint("⚠️ [SECURITY_BLE] startScanning error: $e");
      _setState(GateBleState.failed, 'Bluetooth scan error: $e');
      _triggerFallback('Scan exception');
    }
  }

  void _handleScanResults(List<ScanResult> results) {
    if (_state != GateBleState.active) return;

    for (final r in results) {
      // Check for CampusOS service data or high RSSI proximity
      if (r.rssi > -65) {
        // High proximity device detected
        _setState(GateBleState.processing, 'Device in proximity. Resolving pass...');
        return;
      }
    }
  }

  void _triggerFallback(String reason) {
    _stopInternal();
    if (_state != GateBleState.qrFallback) {
      _setState(GateBleState.qrFallback, 'Use Gate Pass QR ($reason)');
    }
  }

  /// Manually switch to Gate Pass QR fallback.
  void triggerQrFallback() {
    _stopInternal();
    if (_state != GateBleState.qrFallback) {
      _setState(GateBleState.qrFallback, 'Switched to Gate Pass QR scanner');
    }
  }

  void _stopInternal() {
    _timeoutTimer?.cancel();
    _scanSubscription?.cancel();
    _scanSubscription = null;
    try {
      FlutterBluePlus.stopScan().catchError((_) {});
    } catch (_) {}
  }

  /// Stop active scanning and return to IDLE.
  Future<void> stopScanning() async {
    _stopInternal();
    _setState(GateBleState.idle, 'Radar stopped');
  }

  /// Reset to idle state.
  void reset() {
    _stopInternal();
    _setState(GateBleState.idle, 'Ready');
  }

  void dispose() {
    _stopInternal();
    _stateController.close();
    _messageController.close();
  }
}
