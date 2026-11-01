import 'package:flutter/foundation.dart';
import 'passport_proximity_config.dart';

/// CampusOS Passport Proximity Tiers (Phase 1H).
///
/// Descriptive classifications derived from multiple RSSI samples.
/// We intentionally avoid pretending to calculate exact distance in meters,
/// because radio path loss in real environments is inherently non-linear and noisy.
enum PassportProximityTier {
  /// Insufficient or missing RSSI samples (< minimumSamples).
  unknown,

  /// Median signal strength suggests close physical proximity (typically ~1–2 meters).
  near,

  /// Median signal strength suggests distance or physical obstruction.
  far,

  /// High signal variance (spread > maximumSpread), indicating fluctuating environment or motion.
  unstable;

  String get displayName {
    switch (this) {
      case PassportProximityTier.near:
        return 'Near';
      case PassportProximityTier.far:
        return 'Far';
      case PassportProximityTier.unstable:
        return 'Unstable';
      case PassportProximityTier.unknown:
        return 'Unknown';
    }
  }

  String get code {
    switch (this) {
      case PassportProximityTier.near:
        return 'NEAR';
      case PassportProximityTier.far:
        return 'FAR';
      case PassportProximityTier.unstable:
        return 'UNSTABLE';
      case PassportProximityTier.unknown:
        return 'UNKNOWN';
    }
  }

  static PassportProximityTier fromCode(String? code) {
    switch (code?.toUpperCase()) {
      case 'NEAR':
        return PassportProximityTier.near;
      case 'FAR':
        return PassportProximityTier.far;
      case 'UNSTABLE':
        return PassportProximityTier.unstable;
      default:
        return PassportProximityTier.unknown;
    }
  }
}

/// Confidence level in the proximity classification.
enum PassportProximityConfidence {
  none,
  low,
  medium,
  high;

  String get displayName {
    switch (this) {
      case PassportProximityConfidence.high:
        return 'High';
      case PassportProximityConfidence.medium:
        return 'Medium';
      case PassportProximityConfidence.low:
        return 'Low';
      case PassportProximityConfidence.none:
        return 'None';
    }
  }

  String get code {
    switch (this) {
      case PassportProximityConfidence.high:
        return 'HIGH';
      case PassportProximityConfidence.medium:
        return 'MEDIUM';
      case PassportProximityConfidence.low:
        return 'LOW';
      case PassportProximityConfidence.none:
        return 'NONE';
    }
  }

  static PassportProximityConfidence fromCode(String? code) {
    switch (code?.toUpperCase()) {
      case 'HIGH':
        return PassportProximityConfidence.high;
      case 'MEDIUM':
        return PassportProximityConfidence.medium;
      case 'LOW':
        return PassportProximityConfidence.low;
      default:
        return PassportProximityConfidence.none;
    }
  }
}

/// CampusOS Passport Proximity Observation (Phase 1H).
///
/// Encapsulates multiple RSSI samples collected during an active challenge window,
/// statistical aggregation (median, min, max, spread), and tier classification.
///
/// SECURITY & PRIVACY:
/// - RSSI is an additional physical-world observation, NOT cryptographic proof.
/// - Bound to a specific ephemeral challengeNonce (cannot be transplanted).
/// - Ephemeral verifier-session data: NEVER persisted to database tables.
/// - Cryptographic identity verification remains strictly authoritative.
@immutable
class PassportProximityObservation {
  /// The 1G challenge nonce to which this proximity observation is bound.
  final String challengeId;

  /// Timestamp when RSSI sample collection began.
  final DateTime startedAt;

  /// Timestamp when RSSI sample collection concluded.
  final DateTime completedAt;

  /// Total number of valid RSSI samples collected in the window.
  final int sampleCount;

  /// Median RSSI value in dBm (robust against single-packet outliers).
  final int? medianRssi;

  /// Minimum (weakest) RSSI sample recorded in dBm.
  final int? minRssi;

  /// Maximum (strongest) RSSI sample recorded in dBm.
  final int? maxRssi;

  /// Spread in dBm: (maxRssi - minRssi).
  final int? spread;

  /// Heuristic proximity classification.
  final PassportProximityTier proximityTier;

  /// Confidence level in the proximity classification.
  final PassportProximityConfidence confidence;

  /// Ephemeral list of valid samples for inspection/testing.
  final List<int> rawSamples;

  const PassportProximityObservation({
    required this.challengeId,
    required this.startedAt,
    required this.completedAt,
    required this.sampleCount,
    this.medianRssi,
    this.minRssi,
    this.maxRssi,
    this.spread,
    required this.proximityTier,
    required this.confidence,
    this.rawSamples = const [],
  });

  /// Factory constructor to compute observation statistics and classify tier from raw samples.
  factory PassportProximityObservation.compute({
    required String challengeId,
    required List<int> samples,
    required DateTime startedAt,
    required DateTime completedAt,
    PassportProximityConfig config = PassportProximityConfig.defaultConfig,
  }) {
    // 1. Filter out physically unbelievable samples
    final validSamples = samples.where((s) => config.isValidSample(s)).toList();

    if (validSamples.isEmpty) {
      return PassportProximityObservation(
        challengeId: challengeId,
        startedAt: startedAt,
        completedAt: completedAt,
        sampleCount: 0,
        medianRssi: null,
        minRssi: null,
        maxRssi: null,
        spread: null,
        proximityTier: PassportProximityTier.unknown,
        confidence: PassportProximityConfidence.none,
        rawSamples: const [],
      );
    }

    // 2. Sort samples for statistical computation
    final sorted = List<int>.from(validSamples)..sort();
    final count = sorted.length;
    final min = sorted.first;
    final max = sorted.last;
    final spreadValue = max - min;

    // 3. Compute median RSSI
    final int median;
    if (count % 2 == 1) {
      median = sorted[count ~/ 2];
    } else {
      median = ((sorted[(count ~/ 2) - 1] + sorted[count ~/ 2]) / 2).round();
    }

    // 4. Insufficient samples check
    if (count < config.minimumSamples) {
      return PassportProximityObservation(
        challengeId: challengeId,
        startedAt: startedAt,
        completedAt: completedAt,
        sampleCount: count,
        medianRssi: median,
        minRssi: min,
        maxRssi: max,
        spread: spreadValue,
        proximityTier: PassportProximityTier.unknown,
        confidence: PassportProximityConfidence.low,
        rawSamples: List.unmodifiable(validSamples),
      );
    }

    // 5. High variance check -> UNSTABLE
    if (spreadValue > config.maximumSpread) {
      return PassportProximityObservation(
        challengeId: challengeId,
        startedAt: startedAt,
        completedAt: completedAt,
        sampleCount: count,
        medianRssi: median,
        minRssi: min,
        maxRssi: max,
        spread: spreadValue,
        proximityTier: PassportProximityTier.unstable,
        confidence: PassportProximityConfidence.low,
        rawSamples: List.unmodifiable(validSamples),
      );
    }

    // 6. Proximity Tier Classification
    final PassportProximityTier tier;
    if (median >= config.nearThreshold) {
      tier = PassportProximityTier.near;
    } else {
      tier = PassportProximityTier.far;
    }

    // 7. Confidence Calculation
    final PassportProximityConfidence conf;
    if (count >= config.preferredSamples) {
      conf = PassportProximityConfidence.high;
    } else {
      conf = PassportProximityConfidence.medium;
    }

    return PassportProximityObservation(
      challengeId: challengeId,
      startedAt: startedAt,
      completedAt: completedAt,
      sampleCount: count,
      medianRssi: median,
      minRssi: min,
      maxRssi: max,
      spread: spreadValue,
      proximityTier: tier,
      confidence: conf,
      rawSamples: List.unmodifiable(validSamples),
    );
  }

  /// Factory creating an empty/unknown observation for an active challenge.
  factory PassportProximityObservation.unknown({
    required String challengeId,
    DateTime? timestamp,
  }) {
    final now = timestamp ?? DateTime.now();
    return PassportProximityObservation(
      challengeId: challengeId,
      startedAt: now,
      completedAt: now,
      sampleCount: 0,
      medianRssi: null,
      minRssi: null,
      maxRssi: null,
      spread: null,
      proximityTier: PassportProximityTier.unknown,
      confidence: PassportProximityConfidence.none,
      rawSamples: const [],
    );
  }

  bool get isNear => proximityTier == PassportProximityTier.near;
  bool get isFar => proximityTier == PassportProximityTier.far;
  bool get isUnstable => proximityTier == PassportProximityTier.unstable;
  bool get isUnknown => proximityTier == PassportProximityTier.unknown;

  /// User-friendly, realistic summary message adhering strictly to anti-relay guidelines.
  /// Never claims "guaranteed nearby", "relay-proof", or "impossible to spoof".
  String get userFriendlyDescription {
    switch (proximityTier) {
      case PassportProximityTier.near:
        final rssiStr = medianRssi != null ? ' ($medianRssi dBm)' : '';
        return 'Nearby signal observed$rssiStr';
      case PassportProximityTier.far:
        final rssiStr = medianRssi != null ? ' ($medianRssi dBm)' : '';
        return 'Distant or attenuated signal observed$rssiStr';
      case PassportProximityTier.unstable:
        return 'Challenge verified, proximity signal inconclusive (unstable RF)';
      case PassportProximityTier.unknown:
        return 'Challenge verified, proximity signal inconclusive (no BLE samples)';
    }
  }

  Map<String, dynamic> toMap() {
    return {
      'challengeId': challengeId,
      'startedAt': startedAt.toIso8601String(),
      'completedAt': completedAt.toIso8601String(),
      'sampleCount': sampleCount,
      if (medianRssi != null) 'medianRssi': medianRssi,
      if (minRssi != null) 'minRssi': minRssi,
      if (maxRssi != null) 'maxRssi': maxRssi,
      if (spread != null) 'spread': spread,
      'proximityTier': proximityTier.code,
      'confidence': confidence.code,
      'rawSamples': rawSamples,
    };
  }

  factory PassportProximityObservation.fromMap(Map<String, dynamic> map) {
    return PassportProximityObservation(
      challengeId: map['challengeId']?.toString() ?? '',
      startedAt: map['startedAt'] != null
          ? DateTime.tryParse(map['startedAt'].toString()) ?? DateTime.now()
          : DateTime.now(),
      completedAt: map['completedAt'] != null
          ? DateTime.tryParse(map['completedAt'].toString()) ?? DateTime.now()
          : DateTime.now(),
      sampleCount: (map['sampleCount'] as int?) ??
          int.tryParse(map['sampleCount']?.toString() ?? '0') ??
          0,
      medianRssi: (map['medianRssi'] as int?) ??
          int.tryParse(map['medianRssi']?.toString() ?? ''),
      minRssi: (map['minRssi'] as int?) ??
          int.tryParse(map['minRssi']?.toString() ?? ''),
      maxRssi: (map['maxRssi'] as int?) ??
          int.tryParse(map['maxRssi']?.toString() ?? ''),
      spread: (map['spread'] as int?) ??
          int.tryParse(map['spread']?.toString() ?? ''),
      proximityTier: PassportProximityTier.fromCode(map['proximityTier']?.toString()),
      confidence: PassportProximityConfidence.fromCode(map['confidence']?.toString()),
      rawSamples: (map['rawSamples'] as List<dynamic>?)
              ?.map((e) => int.tryParse(e.toString()) ?? 0)
              .toList() ??
          const [],
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PassportProximityObservation &&
          runtimeType == other.runtimeType &&
          challengeId == other.challengeId &&
          sampleCount == other.sampleCount &&
          medianRssi == other.medianRssi &&
          minRssi == other.minRssi &&
          maxRssi == other.maxRssi &&
          spread == other.spread &&
          proximityTier == other.proximityTier &&
          confidence == other.confidence;

  @override
  int get hashCode => Object.hash(
        challengeId,
        sampleCount,
        medianRssi,
        minRssi,
        maxRssi,
        spread,
        proximityTier,
        confidence,
      );
}
