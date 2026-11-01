import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_ble_peripheral/flutter_ble_peripheral.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import '../models/passport_challenge_model.dart';

/// CampusOS Passport BLE Challenge Scanner Service (Phase 1G).
///
/// Student-side service that listens for BLE advertisements from a verifier
/// containing a Passport challenge. Once a challenge is detected, the student's
/// next Passport presentation can be cryptographically bound to it.
///
/// CRITICAL:
/// - Uses [flutter_blue_plus] for BLE scanning (same package as attendance scanning).
/// - Listens for the dedicated Passport Challenge service UUID.
/// - Does NOT interfere with existing attendance BLE scanning.
/// - Scans are short-lived and automatically stop after detection or timeout.
class PassportChallengeScannerService {
  /// Detected challenge, if any.
  PassportChallengeModel? _detectedChallenge;

  /// Whether a scan is currently active.
  bool _isScanning = false;

  /// Stream subscription for BLE scan results.
  StreamSubscription? _scanSubscription;

  /// Callback invoked when a challenge is detected.
  void Function(PassportChallengeModel)? onChallengeDetected;

  /// The most recently detected BLE challenge, or null.
  PassportChallengeModel? get detectedChallenge => _detectedChallenge;

  /// Whether a scan is currently active.
  bool get isScanning => _isScanning;

  /// Whether a valid (non-expired) challenge has been detected.
  bool get hasChallengeReady =>
      _detectedChallenge != null && !_detectedChallenge!.isExpired();

  /// Starts scanning for a verifier's Passport challenge BLE advertisement.
  ///
  /// Returns the detected [PassportChallengeModel] or null if timeout.
  Future<PassportChallengeModel?> scanForChallenge({
    Duration timeout = const Duration(seconds: 10),
  }) async {
    // Request BLE permissions
    await [
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.location,
    ].request();

    if (_isScanning) {
      debugPrint('⚠️ [PASSPORT_CHALLENGE_SCAN] Already scanning. Ignoring duplicate request.');
      return _detectedChallenge;
    }

    _isScanning = true;
    _detectedChallenge = null;

    debugPrint('🔍 [PASSPORT_CHALLENGE_SCAN] Starting BLE scan for Passport challenge...');

    final completer = Completer<PassportChallengeModel?>();

    try {
      // Start BLE scan
      await FlutterBluePlus.startScan(timeout: timeout);

      _scanSubscription = FlutterBluePlus.scanResults.listen((results) {
        if (completer.isCompleted) return;

        for (final result in results) {
          final challenge = _extractChallengeFromScanResult(result);
          if (challenge != null && !challenge.isExpired()) {
            debugPrint('✅ [PASSPORT_CHALLENGE_SCAN] Challenge detected: ${challenge.nonce}');

            _detectedChallenge = challenge;
            onChallengeDetected?.call(challenge);

            FlutterBluePlus.stopScan();
            _scanSubscription?.cancel();
            _scanSubscription = null;
            _isScanning = false;

            if (!completer.isCompleted) {
              completer.complete(challenge);
            }
            return;
          }
        }
      });

      // Timeout fallback
      Future.delayed(timeout, () {
        if (!completer.isCompleted) {
          debugPrint('⏰ [PASSPORT_CHALLENGE_SCAN] Scan timed out. No challenge found.');
          _stopScan();
          completer.complete(null);
        }
      });

      return await completer.future;
    } catch (e) {
      debugPrint('❌ [PASSPORT_CHALLENGE_SCAN] Scan failed: $e');
      _stopScan();
      return null;
    }
  }

  /// Stops any active BLE scanning.
  void _stopScan() {
    _scanSubscription?.cancel();
    _scanSubscription = null;
    _isScanning = false;
    try {
      FlutterBluePlus.stopScan();
    } catch (_) {}
  }

  FlutterBlePeripheral? _blePeripheral;

  /// Emits a brief BLE proximity chirp carrying the challenge nonce (Phase 1H).
  ///
  /// This allows the verifier's receiver to observe RSSI samples while the
  /// student presents their challenge-bound QR code.
  /// Automatically stops after [duration] (default: 4 seconds).
  Future<bool> broadcastProximityChirp({
    required String challengeNonce,
    Duration duration = const Duration(seconds: 4),
  }) async {
    try {
      _blePeripheral ??= FlutterBlePeripheral();
      if (await _blePeripheral!.isAdvertising) {
        await _blePeripheral!.stop();
      }

      // Convert 16-hex nonce to 8 bytes binary
      final nonceBytes = <int>[];
      for (int i = 0; i < challengeNonce.length && i + 2 <= challengeNonce.length; i += 2) {
        nonceBytes.add(int.parse(challengeNonce.substring(i, i + 2), radix: 16));
      }

      final advertiseData = AdvertiseData(
        serviceUuid: PassportChallengeModel.passportProximityServiceUuid,
        localName: 'CampusOS Ping',
        includeDeviceName: false,
        manufacturerData: Uint8List.fromList(nonceBytes),
      );

      final settings = AdvertiseSettings(
        advertiseMode: AdvertiseMode.advertiseModeLowLatency,
        connectable: false,
        timeout: duration.inMilliseconds,
        txPowerLevel: AdvertiseTxPower.advertiseTxPowerMedium,
      );

      await _blePeripheral!.start(
        advertiseData: advertiseData,
        advertiseSettings: settings,
      );

      debugPrint('📡 [PASSPORT_PROXIMITY_CHIRP] Proximity chirp started for nonce: $challengeNonce');

      // Auto-stop after duration
      Future.delayed(duration, () async {
        await stopProximityChirp();
      });

      return true;
    } catch (e) {
      debugPrint('⚠️ [PASSPORT_PROXIMITY_CHIRP] Proximity chirp unavailable: $e');
      return false;
    }
  }

  /// Stops any active proximity chirp.
  Future<void> stopProximityChirp() async {
    try {
      if (_blePeripheral != null && await _blePeripheral!.isAdvertising) {
        await _blePeripheral!.stop();
        debugPrint('🔴 [PASSPORT_PROXIMITY_CHIRP] Proximity chirp stopped.');
      }
    } catch (_) {}
  }

  /// Clears the detected challenge.
  void clearDetectedChallenge() {
    _detectedChallenge = null;
  }

  /// Disposes the scanner and stops any active scan or chirp.
  void dispose() {
    _stopScan();
    stopProximityChirp();
    _detectedChallenge = null;
    onChallengeDetected = null;
  }

  /// Extracts a Passport challenge from a BLE scan result.
  ///
  /// Checks for the dedicated Passport Challenge service UUID in the
  /// advertisement data and decodes the challenge from manufacturer data
  /// or service data.
  PassportChallengeModel? _extractChallengeFromScanResult(ScanResult result) {
    final ad = result.advertisementData;

    // Check if the advertisement contains the Passport Challenge service UUID
    final hasPassportService = ad.serviceUuids.any(
      (uuid) =>
          uuid.toString().toUpperCase() ==
          PassportChallengeModel.passportChallengeServiceUuid.toUpperCase(),
    );

    if (!hasPassportService) return null;

    // Extract challenge from manufacturer data (where we encode it)
    final manufacturerData = ad.manufacturerData;
    if (manufacturerData.isNotEmpty) {
      // manufacturer data is Map<int, List<int>>, combine all entries
      for (final entry in manufacturerData.entries) {
        final data = Uint8List.fromList(entry.value);
        if (data.length >= 16) {
          try {
            return PassportChallengeModel.fromBleServiceData(data);
          } catch (e) {
            debugPrint('⚠️ [PASSPORT_CHALLENGE_SCAN] Failed to decode manufacturer data: $e');
          }
        }
      }
    }

    // Fallback: try service data
    final serviceData = ad.serviceData;
    if (serviceData.isNotEmpty) {
      for (final entry in serviceData.entries) {
        final data = Uint8List.fromList(entry.value);
        if (data.length >= 16) {
          try {
            return PassportChallengeModel.fromBleServiceData(data);
          } catch (e) {
            debugPrint('⚠️ [PASSPORT_CHALLENGE_SCAN] Failed to decode service data: $e');
          }
        }
      }
    }

    return null;
  }
}
