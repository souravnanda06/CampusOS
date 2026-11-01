import 'package:flutter/foundation.dart';

/// CampusOS Passport BLE Proximity Configuration (Phase 1H).
///
/// Centralized heuristic configuration for BLE RSSI proximity measurements.
///
/// CRITICAL REALITY OF RSSI:
/// Received Signal Strength Indication (RSSI) is a noisy radio measurement,
/// NOT cryptographic proof of physical distance. Actual RSSI varies significantly by:
/// - Smartphone model, casing, and Bluetooth antenna design
/// - Device orientation and polarization mismatch
/// - Human body obstruction (attenuates 2.4 GHz signal by 10–20 dBm)
/// - Ambient RF environment (WiFi, microwaves, reflections, multipath fading)
/// - Surrounding walls, glass, furniture, and physical obstacles
///
/// Therefore, thresholds defined here are probabilistic heuristics designed
/// to classify proximity into general tiers (NEAR, FAR, UNSTABLE, UNKNOWN)
/// rather than calculating precise metric distance.
@immutable
class PassportProximityConfig {
  /// Minimum number of valid RSSI samples required before computing a proximity tier.
  /// If fewer samples are collected, the tier evaluates to UNKNOWN.
  final int minimumSamples;

  /// Preferred number of samples for high-confidence classification.
  final int preferredSamples;

  /// Duration of the active RSSI sampling window during challenge presentation.
  final Duration samplingWindow;

  /// Median RSSI threshold (dBm) for NEAR classification.
  /// Typically around -70 dBm for hand-held proximity (~1–2 meters in open air).
  final int nearThreshold;

  /// Median RSSI threshold (dBm) below which proximity is classified as FAR.
  /// Typically around -85 dBm (~5–10+ meters or through obstructions).
  final int farThreshold;

  /// Maximum permissible difference between max and min RSSI (dBm) in a sample window.
  /// If (maxRssi - minRssi) > maximumSpread, the signal is considered UNSTABLE.
  final int maximumSpread;

  /// Minimum believable RSSI (dBm). Samples below this are discarded as radio noise.
  final int minValidRssi;

  /// Maximum believable RSSI (dBm). Samples above this are discarded as transmitter glitches.
  /// Positive or near-zero RSSI is typically impossible in normal mobile BLE operation.
  final int maxValidRssi;

  const PassportProximityConfig({
    this.minimumSamples = 3,
    this.preferredSamples = 5,
    this.samplingWindow = const Duration(seconds: 4),
    this.nearThreshold = -70,
    this.farThreshold = -85,
    this.maximumSpread = 20,
    this.minValidRssi = -120,
    this.maxValidRssi = -10,
  });

  /// Default production configuration calibrated for typical campus gate checkpoints.
  static const PassportProximityConfig defaultConfig = PassportProximityConfig();

  /// Validates whether an individual raw RSSI sample falls within physically believable bounds.
  bool isValidSample(int rssi) {
    return rssi >= minValidRssi && rssi <= maxValidRssi;
  }

  /// Copies this config with optional overrides.
  PassportProximityConfig copyWith({
    int? minimumSamples,
    int? preferredSamples,
    Duration? samplingWindow,
    int? nearThreshold,
    int? farThreshold,
    int? maximumSpread,
    int? minValidRssi,
    int? maxValidRssi,
  }) {
    return PassportProximityConfig(
      minimumSamples: minimumSamples ?? this.minimumSamples,
      preferredSamples: preferredSamples ?? this.preferredSamples,
      samplingWindow: samplingWindow ?? this.samplingWindow,
      nearThreshold: nearThreshold ?? this.nearThreshold,
      farThreshold: farThreshold ?? this.farThreshold,
      maximumSpread: maximumSpread ?? this.maximumSpread,
      minValidRssi: minValidRssi ?? this.minValidRssi,
      maxValidRssi: maxValidRssi ?? this.maxValidRssi,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PassportProximityConfig &&
          runtimeType == other.runtimeType &&
          minimumSamples == other.minimumSamples &&
          preferredSamples == other.preferredSamples &&
          samplingWindow == other.samplingWindow &&
          nearThreshold == other.nearThreshold &&
          farThreshold == other.farThreshold &&
          maximumSpread == other.maximumSpread &&
          minValidRssi == other.minValidRssi &&
          maxValidRssi == other.maxValidRssi;

  @override
  int get hashCode => Object.hash(
        minimumSamples,
        preferredSamples,
        samplingWindow,
        nearThreshold,
        farThreshold,
        maximumSpread,
        minValidRssi,
        maxValidRssi,
      );
}
