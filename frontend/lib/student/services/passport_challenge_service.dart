import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_ble_peripheral/flutter_ble_peripheral.dart';
import 'package:permission_handler/permission_handler.dart';
import '../models/passport_challenge_model.dart';
import '../models/passport_proximity_observation.dart';
import 'passport_proximity_service.dart';

/// CampusOS Passport BLE Challenge Service (Phase 1G & 1H).
///
/// Manages the verifier-side lifecycle:
/// 1. Generate an ephemeral BLE challenge with a cryptographic nonce.
/// 2. Advertise the challenge via BLE peripheral using service data.
/// 3. Track challenge expiration and auto-rotate.
/// 4. Validate incoming challenge nonces against the local ephemeral store.
/// 5. Coordinate Phase 1H BLE proximity observation for the active challenge.
///
/// CRITICAL:
/// - Challenge state is 100% in-memory. No database migrations.
/// - Uses [flutter_ble_peripheral] for advertising (same package as attendance BLE).
/// - Uses a DEDICATED service UUID distinct from attendance session UUIDs.
/// - Does NOT interfere with existing attendance BLE advertising.
class PassportChallengeService {
  final FlutterBlePeripheral _blePeripheral;

  /// Phase 1H: Proximity service tracking RSSI observations for the active challenge.
  final PassportProximityService proximityService;

  /// In-memory ephemeral challenge store.
  /// Maps challenge nonce -> PassportChallengeModel.
  /// Old challenges are pruned on access.
  final Map<String, PassportChallengeModel> _activeChallenges = {};

  /// Maximum number of concurrent challenges to retain (prevents unbounded growth).
  static const int maxChallenges = 50;

  /// Maximum age for a challenge before it is pruned even if not expired (safety ceiling).
  static const Duration maxChallengeAge = Duration(minutes: 5);

  /// The currently broadcasting challenge (null if not advertising).
  PassportChallengeModel? _currentChallenge;

  /// Whether BLE advertising is active.
  bool _isAdvertising = false;

  /// Timer for auto-rotating the challenge.
  Timer? _rotationTimer;

  /// Callback invoked when a new challenge is generated during auto-rotation.
  void Function(PassportChallengeModel)? onChallengeRotated;

  PassportChallengeService({
    FlutterBlePeripheral? blePeripheral,
    PassportProximityService? proximityService,
  })  : _blePeripheral = blePeripheral ?? FlutterBlePeripheral(),
        proximityService = proximityService ?? PassportProximityService();

  /// The current active challenge being advertised, if any.
  PassportChallengeModel? get currentChallenge => _currentChallenge;

  /// Whether the service is actively advertising a challenge.
  bool get isAdvertising => _isAdvertising;

  /// Number of active (non-expired) challenges in the ephemeral store.
  int get activeChallengeCount {
    _pruneExpired();
    return _activeChallenges.length;
  }

  /// Generates a new ephemeral challenge and stores it in-memory.
  ///
  /// Does NOT start BLE advertising automatically.
  PassportChallengeModel generateChallenge({
    required String verifierId,
    Duration validity = PassportChallengeModel.defaultValidity,
    int? currentTimestampSeconds,
  }) {
    _pruneExpired(currentTimestampSeconds: currentTimestampSeconds);

    final challenge = PassportChallengeModel.generate(
      verifierId: verifierId,
      validity: validity,
      currentTimestampSeconds: currentTimestampSeconds,
    );

    _activeChallenges[challenge.nonce] = challenge;
    _currentChallenge = challenge;

    // Phase 1H: Initialize proximity observation window for the new challenge
    proximityService.startObservation(challengeId: challenge.nonce);

    debugPrint('🔵 [PASSPORT_CHALLENGE] Generated challenge: ${challenge.nonce} '
        '(expires in ${challenge.remainingSeconds()}s)');

    return challenge;
  }

  /// Starts BLE advertising with the current challenge.
  ///
  /// Uses the dedicated Passport Challenge service UUID and encodes the
  /// challenge in the service data field (compact 20-byte binary format).
  Future<bool> startAdvertising({
    required String verifierId,
    Duration validity = PassportChallengeModel.defaultValidity,
    bool autoRotate = true,
  }) async {
    // Request BLE permissions
    final permissionStatuses = await [
      Permission.bluetooth,
      Permission.bluetoothAdvertise,
      Permission.bluetoothConnect,
      Permission.location,
    ].request();

    final denied = permissionStatuses.entries
        .where((e) => !e.value.isGranted)
        .map((e) => e.key.toString())
        .toList();

    if (denied.isNotEmpty) {
      debugPrint('❌ [PASSPORT_CHALLENGE] BLE permissions denied: $denied');
      return false;
    }

    // Stop existing advertising if any
    await stopAdvertising();

    // Generate a fresh challenge
    final challenge = generateChallenge(
      verifierId: verifierId,
      validity: validity,
    );

    // Encode challenge as BLE service data
    final serviceData = challenge.toBleServiceData();

    final advertiseData = AdvertiseData(
      serviceUuid: PassportChallengeModel.passportChallengeServiceUuid,
      localName: 'CampusOS Verify',
      includeDeviceName: false,
      manufacturerData: serviceData,
    );

    final settings = AdvertiseSettings(
      advertiseMode: AdvertiseMode.advertiseModeBalanced,
      connectable: false,
      timeout: 0,
      txPowerLevel: AdvertiseTxPower.advertiseTxPowerMedium,
    );

    try {
      await _blePeripheral.start(
        advertiseData: advertiseData,
        advertiseSettings: settings,
      );
      _isAdvertising = true;

      debugPrint('📡 [PASSPORT_CHALLENGE] BLE advertising started with challenge: ${challenge.nonce}');

      // Phase 1H: Start proximity receiver scanning for student chirps
      proximityService.startBleScanning(challengeNonce: challenge.nonce);

      // Auto-rotate challenge before expiration
      if (autoRotate) {
        _startRotationTimer(verifierId, validity);
      }

      return true;
    } catch (e) {
      debugPrint('❌ [PASSPORT_CHALLENGE] BLE advertising failed: $e');
      _isAdvertising = false;
      return false;
    }
  }

  /// Stops BLE challenge advertising and cancels rotation timer.
  Future<void> stopAdvertising() async {
    _rotationTimer?.cancel();
    _rotationTimer = null;

    proximityService.clear();

    try {
      if (_isAdvertising) {
        await _blePeripheral.stop();
      }
    } catch (e) {
      debugPrint('⚠️ [PASSPORT_CHALLENGE] Error stopping BLE advertisement: $e');
    }

    _isAdvertising = false;
    debugPrint('🔴 [PASSPORT_CHALLENGE] BLE advertising stopped.');
  }

  /// Validates a challenge nonce against the ephemeral in-memory store.
  ///
  /// Returns the matching [PassportChallengeModel] if found, valid, and not expired.
  /// Returns `null` if the nonce is unknown, expired, or the store is empty.
  ///
  /// A successfully validated challenge is consumed (removed from the store)
  /// to prevent reuse, unless [consume] is false.
  PassportChallengeModel? validateChallenge(
    String nonce, {
    int? currentTimestampSeconds,
    bool consume = true,
  }) {
    _pruneExpired(currentTimestampSeconds: currentTimestampSeconds);

    final challenge = _activeChallenges[nonce];
    if (challenge == null) {
      debugPrint('❌ [PASSPORT_CHALLENGE] Unknown challenge nonce: $nonce');
      return null;
    }

    if (challenge.isExpired(currentTimestampSeconds)) {
      _activeChallenges.remove(nonce);
      debugPrint('❌ [PASSPORT_CHALLENGE] Challenge expired: $nonce');
      return null;
    }

    if (consume) {
      _activeChallenges.remove(nonce);
      debugPrint('✅ [PASSPORT_CHALLENGE] Challenge consumed: $nonce');
    }

    return challenge;
  }

  /// Checks whether a challenge nonce exists in the ephemeral store
  /// without consuming or modifying it.
  bool hasChallengeNonce(String nonce) {
    _pruneExpired();
    final challenge = _activeChallenges[nonce];
    return challenge != null && !challenge.isExpired();
  }

  /// Finalizes and returns the proximity observation for the active challenge (Phase 1H).
  PassportProximityObservation finalizeProximityObservation() =>
      proximityService.finalizeObservation();

  /// Clears all challenges and stops advertising and proximity observation.
  Future<void> dispose() async {
    await stopAdvertising();
    proximityService.dispose();
    _activeChallenges.clear();
    _currentChallenge = null;
  }

  /// Prunes expired challenges from the in-memory store.
  void _pruneExpired({int? currentTimestampSeconds}) {
    final nowSec = currentTimestampSeconds ??
        (DateTime.now().toUtc().millisecondsSinceEpoch ~/ 1000);

    _activeChallenges.removeWhere((nonce, challenge) {
      return challenge.isExpired(nowSec) ||
          (nowSec - challenge.issuedAt > maxChallengeAge.inSeconds);
    });

    // Enforce max capacity by removing oldest challenges
    while (_activeChallenges.length > maxChallenges) {
      final oldestNonce = _activeChallenges.entries
          .reduce((a, b) => a.value.issuedAt < b.value.issuedAt ? a : b)
          .key;
      _activeChallenges.remove(oldestNonce);
    }
  }

  /// Starts a timer to rotate the challenge before it expires.
  void _startRotationTimer(String verifierId, Duration validity) {
    _rotationTimer?.cancel();

    // Rotate at 75% of validity window (e.g., at 45s for a 60s challenge)
    final rotateAfter = Duration(
      milliseconds: (validity.inMilliseconds * 0.75).toInt(),
    );

    _rotationTimer = Timer(rotateAfter, () async {
      if (!_isAdvertising) return;

      debugPrint('🔄 [PASSPORT_CHALLENGE] Auto-rotating challenge...');

      // Stop current advertisement
      try {
        await _blePeripheral.stop();
      } catch (_) {}

      // Generate and re-advertise with new challenge
      final newChallenge = generateChallenge(
        verifierId: verifierId,
        validity: validity,
      );

      final serviceData = newChallenge.toBleServiceData();

      final advertiseData = AdvertiseData(
        serviceUuid: PassportChallengeModel.passportChallengeServiceUuid,
        localName: 'CampusOS Verify',
        includeDeviceName: false,
        manufacturerData: serviceData,
      );

      final settings = AdvertiseSettings(
        advertiseMode: AdvertiseMode.advertiseModeBalanced,
        connectable: false,
        timeout: 0,
        txPowerLevel: AdvertiseTxPower.advertiseTxPowerMedium,
      );

      try {
        await _blePeripheral.start(
          advertiseData: advertiseData,
          advertiseSettings: settings,
        );
        debugPrint('📡 [PASSPORT_CHALLENGE] Rotated to new challenge: ${newChallenge.nonce}');

        onChallengeRotated?.call(newChallenge);

        // Schedule next rotation
        _startRotationTimer(verifierId, validity);
      } catch (e) {
        debugPrint('❌ [PASSPORT_CHALLENGE] Rotation failed: $e');
        _isAdvertising = false;
      }
    });
  }
}
