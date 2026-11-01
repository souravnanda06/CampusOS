import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import '../models/passport_challenge_model.dart';
import '../models/passport_proximity_config.dart';
import '../models/passport_proximity_observation.dart';

/// CampusOS Passport BLE Proximity Service (Phase 1H).
///
/// Collects and analyzes multiple RSSI observations during an active challenge window
/// to produce a heuristic proximity classification (NEAR, FAR, UNSTABLE, UNKNOWN).
///
/// ARCHITECTURAL PRINCIPLES:
/// 1. RSSI is an additional physical-world observation, NOT cryptographic proof.
/// 2. Cryptographic identity verification remains authoritative.
/// 3. Ephemeral verifier-session state only: ZERO database writes or tracking tables.
/// 4. Discards physically unbelievable radio artifacts (< -120 or > -10 dBm).
/// 5. Automatically cleans up scanner and timers on challenge completion or dispose.
class PassportProximityService {
  final PassportProximityConfig config;

  /// Active challenge nonce to which current samples belong.
  String? _activeChallengeId;

  /// Raw RSSI samples collected in the current sampling window.
  final List<int> _samples = [];

  /// Timestamp when observation collection started.
  DateTime? _startedAt;

  /// Timestamp when observation was finalized.
  DateTime? _completedAt;

  /// Whether active RSSI collection is underway.
  bool _isCollecting = false;

  /// Stream controller for broadcasting live observation updates to UI.
  final StreamController<PassportProximityObservation> _observationController =
      StreamController<PassportProximityObservation>.broadcast();

  /// Stream subscription for BLE scan results.
  StreamSubscription? _bleScanSubscription;

  PassportProximityService({
    this.config = PassportProximityConfig.defaultConfig,
  });

  /// The active challenge ID being observed, or null.
  String? get activeChallengeId => _activeChallengeId;

  /// Whether the service is currently collecting RSSI samples.
  bool get isCollecting => _isCollecting;

  /// Current number of valid samples collected.
  int get sampleCount => _samples.length;

  /// Stream of proximity observations emitting on each new sample or state change.
  Stream<PassportProximityObservation> get observationStream =>
      _observationController.stream;

  /// Starts collecting RSSI samples for a newly issued or active challenge.
  ///
  /// Clears any previous samples from earlier challenges.
  void startObservation({
    required String challengeId,
    DateTime? startTime,
  }) {
    _activeChallengeId = challengeId;
    _samples.clear();
    _startedAt = startTime ?? DateTime.now();
    _completedAt = null;
    _isCollecting = true;

    debugPrint('📡 [PASSPORT_PROXIMITY] Started proximity observation for challenge: $challengeId');

    final initial = currentObservation;
    _observationController.add(initial);
  }

  /// Appends a raw RSSI sample for the active challenge.
  ///
  /// Validates that the sample falls within believable physical bounds (-120 to -10 dBm).
  /// Rejects samples if collection is not active or if [challengeId] does not match.
  bool addSample(
    int rssi, {
    String? challengeId,
    DateTime? timestamp,
  }) {
    if (!_isCollecting || _activeChallengeId == null) {
      debugPrint('⚠️ [PASSPORT_PROXIMITY] Sample ignored: observation not active.');
      return false;
    }

    if (challengeId != null && challengeId != _activeChallengeId) {
      debugPrint('⚠️ [PASSPORT_PROXIMITY] Sample ignored: challenge mismatch ($challengeId != $_activeChallengeId).');
      return false;
    }

    // Filter out invalid RF samples
    if (!config.isValidSample(rssi)) {
      debugPrint('⚠️ [PASSPORT_PROXIMITY] Sample discarded (out of valid bounds): $rssi dBm');
      return false;
    }

    _samples.add(rssi);

    final observation = currentObservation;
    _observationController.add(observation);

    debugPrint('📶 [PASSPORT_PROXIMITY] RSSI sample added: $rssi dBm '
        '(total: ${_samples.length}, median: ${observation.medianRssi} dBm, tier: ${observation.proximityTier.code})');

    return true;
  }

  /// Computes the current real-time [PassportProximityObservation] based on samples collected so far.
  PassportProximityObservation get currentObservation {
    final challengeId = _activeChallengeId ?? '';
    final start = _startedAt ?? DateTime.now();
    final completed = _completedAt ?? DateTime.now();

    if (_samples.isEmpty || challengeId.isEmpty) {
      return PassportProximityObservation.unknown(
        challengeId: challengeId,
        timestamp: start,
      );
    }

    return PassportProximityObservation.compute(
      challengeId: challengeId,
      samples: _samples,
      startedAt: start,
      completedAt: completed,
      config: config,
    );
  }

  /// Finalizes the observation window, freezes the completedAt timestamp,
  /// stops any active BLE scan, and returns the authoritative [PassportProximityObservation].
  PassportProximityObservation finalizeObservation({DateTime? completionTime}) {
    _completedAt = completionTime ?? DateTime.now();
    _isCollecting = false;
    _stopBleScan();

    final finalObservation = currentObservation;
    _observationController.add(finalObservation);

    debugPrint('🏁 [PASSPORT_PROXIMITY] Finalized observation for challenge: $_activeChallengeId '
        '(samples: ${finalObservation.sampleCount}, tier: ${finalObservation.proximityTier.code}, '
        'median: ${finalObservation.medianRssi} dBm, spread: ${finalObservation.spread} dBm)');

    return finalObservation;
  }

  /// Starts scanning for student BLE proximity response chirps matching the active challenge.
  ///
  /// Listens for advertisements with the dedicated `passportProximityServiceUuid`
  /// or matching the active challenge nonce in manufacturer data.
  Future<void> startBleScanning({
    required String challengeNonce,
    Duration? timeout,
  }) async {
    startObservation(challengeId: challengeNonce);

    try {
      await [
        Permission.bluetoothScan,
        Permission.bluetoothConnect,
        Permission.location,
      ].request();

      _stopBleScan();

      final scanDuration = timeout ?? config.samplingWindow;

      await FlutterBluePlus.startScan(timeout: scanDuration);

      _bleScanSubscription = FlutterBluePlus.scanResults.listen((results) {
        if (!_isCollecting) return;

        for (final result in results) {
          final isMatch = _isMatchingProximityAdvertisement(result, challengeNonce);
          if (isMatch) {
            addSample(result.rssi, challengeId: challengeNonce);
          }
        }
      });

      // Auto-finalize when sampling window completes
      Future.delayed(scanDuration, () {
        if (_isCollecting && _activeChallengeId == challengeNonce) {
          debugPrint('⏰ [PASSPORT_PROXIMITY] Sampling window completed.');
          _stopBleScan();
        }
      });
    } catch (e) {
      debugPrint('⚠️ [PASSPORT_PROXIMITY] BLE scan failed: $e');
    }
  }

  /// Inspects a BLE scan result to check if it matches the active challenge.
  bool _isMatchingProximityAdvertisement(ScanResult result, String challengeNonce) {
    final ad = result.advertisementData;

    // Check service UUID for proximity response
    final hasProximityUuid = ad.serviceUuids.any(
      (uuid) =>
          uuid.toString().toUpperCase() ==
          PassportChallengeModel.passportProximityServiceUuid.toUpperCase(),
    );

    if (hasProximityUuid) return true;

    // Check manufacturer data for challenge nonce match
    for (final entry in ad.manufacturerData.entries) {
      final bytes = entry.value;
      if (bytes.length >= 8) {
        final nonceHex = bytes
            .take(8)
            .map((b) => b.toRadixString(16).padLeft(2, '0'))
            .join();
        if (nonceHex.toLowerCase() == challengeNonce.toLowerCase()) {
          return true;
        }
      }
    }

    return false;
  }

  /// Stops any active BLE scanning.
  void _stopBleScan() {
    _bleScanSubscription?.cancel();
    _bleScanSubscription = null;
    try {
      FlutterBluePlus.stopScan();
    } catch (_) {}
  }

  /// Clears current state and stops collection.
  void clear() {
    _stopBleScan();
    _isCollecting = false;
    _activeChallengeId = null;
    _samples.clear();
    _startedAt = null;
    _completedAt = null;
  }

  /// Disposes of all resources, streams, and BLE subscriptions.
  void dispose() {
    clear();
    _observationController.close();
  }
}
