import 'package:flutter_test/flutter_test.dart';
import 'package:attendance_app/student/models/passport_proximity_config.dart';
import 'package:attendance_app/student/models/passport_proximity_observation.dart';

/// CampusOS Passport Phase 1H: Proximity Observation Unit Tests.
///
/// Tests the statistical aggregation (median, spread, min, max),
/// proximity tier classification (NEAR, FAR, UNSTABLE, UNKNOWN),
/// confidence levels, and edge cases of the RSSI observation model.
void main() {
  const config = PassportProximityConfig.defaultConfig;
  final fixedStart = DateTime(2026, 1, 1, 12, 0, 0);
  final fixedEnd = DateTime(2026, 1, 1, 12, 0, 5);

  group('PassportProximityObservation.compute', () {
    test('returns UNKNOWN tier with zero samples', () {
      final obs = PassportProximityObservation.compute(
        challengeId: 'test-001',
        samples: const [],
        startedAt: fixedStart,
        completedAt: fixedEnd,
        config: config,
      );

      expect(obs.challengeId, 'test-001');
      expect(obs.sampleCount, 0);
      expect(obs.medianRssi, isNull);
      expect(obs.minRssi, isNull);
      expect(obs.maxRssi, isNull);
      expect(obs.spread, isNull);
      expect(obs.proximityTier, PassportProximityTier.unknown);
      expect(obs.confidence, PassportProximityConfidence.none);
    });

    test('returns UNKNOWN tier with all invalid samples (out of bounds)', () {
      final obs = PassportProximityObservation.compute(
        challengeId: 'test-002',
        samples: const [-130, -140, -5, 0, 10], // all out of [-120, -10] range
        startedAt: fixedStart,
        completedAt: fixedEnd,
        config: config,
      );

      expect(obs.sampleCount, 0);
      expect(obs.proximityTier, PassportProximityTier.unknown);
      expect(obs.confidence, PassportProximityConfidence.none);
    });

    test('returns UNKNOWN tier with fewer than minimumSamples valid samples', () {
      // Default minimumSamples is 3, provide only 2
      final obs = PassportProximityObservation.compute(
        challengeId: 'test-003',
        samples: const [-45, -50],
        startedAt: fixedStart,
        completedAt: fixedEnd,
        config: config,
      );

      expect(obs.sampleCount, 2);
      expect(obs.medianRssi, isNotNull);
      expect(obs.proximityTier, PassportProximityTier.unknown);
      expect(obs.confidence, PassportProximityConfidence.low);
    });

    test('classifies NEAR tier with strong close-range samples', () {
      // nearThreshold defaults to -70 dBm; all samples stronger (closer to 0)
      final obs = PassportProximityObservation.compute(
        challengeId: 'test-near',
        samples: const [-55, -60, -58, -62, -56],
        startedAt: fixedStart,
        completedAt: fixedEnd,
        config: config,
      );

      expect(obs.sampleCount, 5);
      expect(obs.proximityTier, PassportProximityTier.near);
      expect(obs.medianRssi, -58); // sorted: [-62,-60,-58,-56,-55], median=-58
      expect(obs.minRssi, -62);
      expect(obs.maxRssi, -55);
      expect(obs.spread, 7); // 62-55 = 7
      expect(obs.confidence, PassportProximityConfidence.high);
      expect(obs.isNear, isTrue);
      expect(obs.isFar, isFalse);
    });

    test('classifies FAR tier with weak distant samples', () {
      // Median below nearThreshold (-55 dBm)
      final obs = PassportProximityObservation.compute(
        challengeId: 'test-far',
        samples: const [-75, -80, -78, -82, -76],
        startedAt: fixedStart,
        completedAt: fixedEnd,
        config: config,
      );

      expect(obs.sampleCount, 5);
      expect(obs.proximityTier, PassportProximityTier.far);
      expect(obs.medianRssi, -78); // sorted: [-82,-80,-78,-76,-75], median=-78
      expect(obs.isFar, isTrue);
      expect(obs.isNear, isFalse);
    });

    test('classifies UNSTABLE tier with high spread', () {
      // Default maximumSpread is 20 dBm; create spread > 20
      final obs = PassportProximityObservation.compute(
        challengeId: 'test-unstable',
        samples: const [-40, -70, -50, -60, -45],
        startedAt: fixedStart,
        completedAt: fixedEnd,
        config: config,
      );

      expect(obs.sampleCount, 5);
      // sorted: [-70, -60, -50, -45, -40]; spread = 70 - 40 = 30
      expect(obs.spread, 30);
      expect(obs.proximityTier, PassportProximityTier.unstable);
      expect(obs.isUnstable, isTrue);
      expect(obs.confidence, PassportProximityConfidence.low);
    });

    test('computes correct median for even number of samples', () {
      final obs = PassportProximityObservation.compute(
        challengeId: 'test-even',
        samples: const [-40, -50, -44, -46],
        startedAt: fixedStart,
        completedAt: fixedEnd,
        config: config,
      );

      // sorted: [-50, -46, -44, -40]; median = (-46 + -44) / 2 = -45
      expect(obs.medianRssi, -45);
      expect(obs.sampleCount, 4);
    });

    test('computes correct median for odd number of samples', () {
      final obs = PassportProximityObservation.compute(
        challengeId: 'test-odd',
        samples: const [-40, -50, -44, -46, -48],
        startedAt: fixedStart,
        completedAt: fixedEnd,
        config: config,
      );

      // sorted: [-50, -48, -46, -44, -40]; median = -46
      expect(obs.medianRssi, -46);
      expect(obs.sampleCount, 5);
    });

    test('computes correct median for single valid sample (below minimumSamples)', () {
      final obs = PassportProximityObservation.compute(
        challengeId: 'test-single',
        samples: const [-42],
        startedAt: fixedStart,
        completedAt: fixedEnd,
        config: config,
      );

      expect(obs.sampleCount, 1);
      expect(obs.medianRssi, -42);
      expect(obs.minRssi, -42);
      expect(obs.maxRssi, -42);
      expect(obs.spread, 0);
      // Below minimumSamples → UNKNOWN
      expect(obs.proximityTier, PassportProximityTier.unknown);
      expect(obs.confidence, PassportProximityConfidence.low);
    });

    test('filters out invalid samples and uses only valid ones', () {
      // Mix of valid and invalid; only valid samples counted
      final obs = PassportProximityObservation.compute(
        challengeId: 'test-filter',
        samples: const [-130, -40, -5, -45, 0, -42, -200],
        startedAt: fixedStart,
        completedAt: fixedEnd,
        config: config,
      );

      // Valid: [-40, -45, -42]; sorted: [-45, -42, -40]; median = -42
      expect(obs.sampleCount, 3);
      expect(obs.medianRssi, -42);
      expect(obs.minRssi, -45);
      expect(obs.maxRssi, -40);
      expect(obs.spread, 5);
    });

    test('assigns MEDIUM confidence when sampleCount >= minimumSamples but < preferredSamples', () {
      // Default: minimumSamples=3, preferredSamples=5
      final obs = PassportProximityObservation.compute(
        challengeId: 'test-medium-conf',
        samples: const [-40, -42, -44], // exactly minimumSamples
        startedAt: fixedStart,
        completedAt: fixedEnd,
        config: config,
      );

      expect(obs.sampleCount, 3);
      expect(obs.confidence, PassportProximityConfidence.medium);
    });

    test('assigns HIGH confidence when sampleCount >= preferredSamples', () {
      final obs = PassportProximityObservation.compute(
        challengeId: 'test-high-conf',
        samples: const [-40, -42, -44, -38, -41], // = preferredSamples (5)
        startedAt: fixedStart,
        completedAt: fixedEnd,
        config: config,
      );

      expect(obs.sampleCount, 5);
      expect(obs.confidence, PassportProximityConfidence.high);
    });

    test('preserves challengeId binding across observations', () {
      const targetChallenge = 'challenge-abc123';
      final obs = PassportProximityObservation.compute(
        challengeId: targetChallenge,
        samples: const [-40, -42, -44, -38, -41],
        startedAt: fixedStart,
        completedAt: fixedEnd,
        config: config,
      );

      expect(obs.challengeId, targetChallenge);
    });

    test('respects custom config thresholds', () {
      const customConfig = PassportProximityConfig(
        nearThreshold: -50,      // stricter NEAR threshold
        maximumSpread: 10,       // tighter spread requirement
        minimumSamples: 2,
        preferredSamples: 4,
        samplingWindow: Duration(seconds: 3),
        minValidRssi: -100,
        maxValidRssi: -20,
      );

      // Median -43 is above -50 threshold, so NEAR under custom config
      final obs = PassportProximityObservation.compute(
        challengeId: 'test-custom',
        samples: const [-40, -45, -43],
        startedAt: fixedStart,
        completedAt: fixedEnd,
        config: customConfig,
      );

      expect(obs.proximityTier, PassportProximityTier.near);
    });

    test('custom config with tight spread classifies as UNSTABLE', () {
      const tightConfig = PassportProximityConfig(
        nearThreshold: -55,
        maximumSpread: 5,  // very tight
        minimumSamples: 3,
        preferredSamples: 5,
        samplingWindow: Duration(seconds: 4),
        minValidRssi: -120,
        maxValidRssi: -10,
      );

      final obs = PassportProximityObservation.compute(
        challengeId: 'test-tight',
        samples: const [-40, -48, -44], // spread = 8 > 5
        startedAt: fixedStart,
        completedAt: fixedEnd,
        config: tightConfig,
      );

      expect(obs.spread, 8);
      expect(obs.proximityTier, PassportProximityTier.unstable);
    });
  });

  group('PassportProximityObservation serialization', () {
    test('toMap produces correct JSON-compatible map', () {
      final obs = PassportProximityObservation.compute(
        challengeId: 'ser-test',
        samples: const [-55, -60, -58, -62, -56],
        startedAt: fixedStart,
        completedAt: fixedEnd,
        config: config,
      );

      final map = obs.toMap();
      expect(map['challengeId'], 'ser-test');
      expect(map['sampleCount'], 5);
      expect(map['medianRssi'], -58);
      expect(map['proximityTier'], 'NEAR');
      expect(map['confidence'], 'HIGH');
      expect(map['rawSamples'], isA<List>());
    });

    test('fromMap round-trips correctly', () {
      final original = PassportProximityObservation.compute(
        challengeId: 'roundtrip',
        samples: const [-45, -50, -48, -52, -47],
        startedAt: fixedStart,
        completedAt: fixedEnd,
        config: config,
      );

      final map = original.toMap();
      final restored = PassportProximityObservation.fromMap(map);

      expect(restored.challengeId, original.challengeId);
      expect(restored.sampleCount, original.sampleCount);
      expect(restored.medianRssi, original.medianRssi);
      expect(restored.minRssi, original.minRssi);
      expect(restored.maxRssi, original.maxRssi);
      expect(restored.spread, original.spread);
      expect(restored.proximityTier, original.proximityTier);
      expect(restored.confidence, original.confidence);
    });
  });

  group('PassportProximityObservation.unknown', () {
    test('creates empty observation with all null stats', () {
      final obs = PassportProximityObservation.unknown(
        challengeId: 'unknown-test',
        timestamp: fixedStart,
      );

      expect(obs.challengeId, 'unknown-test');
      expect(obs.sampleCount, 0);
      expect(obs.medianRssi, isNull);
      expect(obs.proximityTier, PassportProximityTier.unknown);
      expect(obs.confidence, PassportProximityConfidence.none);
      expect(obs.isUnknown, isTrue);
    });
  });

  group('PassportProximityObservation equality', () {
    test('equal observations are ==', () {
      final a = PassportProximityObservation.compute(
        challengeId: 'eq-test',
        samples: const [-40, -42, -44, -38, -41],
        startedAt: fixedStart,
        completedAt: fixedEnd,
        config: config,
      );
      final b = PassportProximityObservation.compute(
        challengeId: 'eq-test',
        samples: const [-40, -42, -44, -38, -41],
        startedAt: fixedStart,
        completedAt: fixedEnd,
        config: config,
      );

      expect(a, equals(b));
      expect(a.hashCode, b.hashCode);
    });

    test('different challengeIds are not equal', () {
      final a = PassportProximityObservation.compute(
        challengeId: 'id-a',
        samples: const [-40, -42, -44],
        startedAt: fixedStart,
        completedAt: fixedEnd,
        config: config,
      );
      final b = PassportProximityObservation.compute(
        challengeId: 'id-b',
        samples: const [-40, -42, -44],
        startedAt: fixedStart,
        completedAt: fixedEnd,
        config: config,
      );

      expect(a, isNot(equals(b)));
    });
  });

  group('PassportProximityTier', () {
    test('fromCode handles all values', () {
      expect(PassportProximityTier.fromCode('NEAR'), PassportProximityTier.near);
      expect(PassportProximityTier.fromCode('FAR'), PassportProximityTier.far);
      expect(PassportProximityTier.fromCode('UNSTABLE'), PassportProximityTier.unstable);
      expect(PassportProximityTier.fromCode('UNKNOWN'), PassportProximityTier.unknown);
      expect(PassportProximityTier.fromCode(null), PassportProximityTier.unknown);
      expect(PassportProximityTier.fromCode('invalid'), PassportProximityTier.unknown);
    });

    test('code and displayName are consistent', () {
      expect(PassportProximityTier.near.code, 'NEAR');
      expect(PassportProximityTier.near.displayName, 'Near');
      expect(PassportProximityTier.far.code, 'FAR');
      expect(PassportProximityTier.far.displayName, 'Far');
    });
  });

  group('PassportProximityConfidence', () {
    test('fromCode handles all values', () {
      expect(PassportProximityConfidence.fromCode('HIGH'), PassportProximityConfidence.high);
      expect(PassportProximityConfidence.fromCode('MEDIUM'), PassportProximityConfidence.medium);
      expect(PassportProximityConfidence.fromCode('LOW'), PassportProximityConfidence.low);
      expect(PassportProximityConfidence.fromCode('NONE'), PassportProximityConfidence.none);
      expect(PassportProximityConfidence.fromCode(null), PassportProximityConfidence.none);
      expect(PassportProximityConfidence.fromCode('invalid'), PassportProximityConfidence.none);
    });
  });

  group('PassportProximityObservation userFriendlyDescription', () {
    test('NEAR tier produces anti-relay compliant message', () {
      final obs = PassportProximityObservation.compute(
        challengeId: 'desc-near',
        samples: const [-55, -60, -58, -62, -56],
        startedAt: fixedStart,
        completedAt: fixedEnd,
        config: config,
      );

      final msg = obs.userFriendlyDescription;
      expect(msg, contains('Nearby signal observed'));
      // Anti-relay: must NOT say any of these
      expect(msg, isNot(contains('Guaranteed nearby')));
      expect(msg, isNot(contains('Relay-proof')));
      expect(msg, isNot(contains('Impossible to spoof')));
      expect(msg, isNot(contains('Physical presence verified')));
    });

    test('FAR tier produces anti-relay compliant message', () {
      final obs = PassportProximityObservation.compute(
        challengeId: 'desc-far',
        samples: const [-75, -80, -78, -82, -76],
        startedAt: fixedStart,
        completedAt: fixedEnd,
        config: config,
      );

      expect(obs.userFriendlyDescription, contains('Distant'));
      expect(obs.userFriendlyDescription, isNot(contains('Guaranteed')));
    });

    test('UNSTABLE tier produces inconclusive message', () {
      final obs = PassportProximityObservation.compute(
        challengeId: 'desc-unstable',
        samples: const [-40, -70, -50, -60, -45],
        startedAt: fixedStart,
        completedAt: fixedEnd,
        config: config,
      );

      expect(obs.userFriendlyDescription, contains('inconclusive'));
    });

    test('UNKNOWN tier produces inconclusive message', () {
      final obs = PassportProximityObservation.unknown(challengeId: 'desc-unknown');
      expect(obs.userFriendlyDescription, contains('inconclusive'));
    });
  });
}
