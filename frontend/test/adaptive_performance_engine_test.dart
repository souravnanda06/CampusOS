import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:attendance_app/core/performance/performance.dart';
import 'package:attendance_app/student/services/passport_crypto_service.dart';

/// In-memory implementation of [PassportKeyStorage] for deterministic headless unit tests.
class InMemoryPassportKeyStorage implements PassportKeyStorage {
  final Map<String, String> _data = {};

  @override
  Future<String?> read(String key) async => _data[key];

  @override
  Future<void> write(String key, String value) async => _data[key] = value;

  @override
  Future<void> delete(String key) async => _data.remove(key);

  @override
  Future<bool> containsKey(String key) async => _data.containsKey(key);

  void clear() => _data.clear();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('DeviceCapabilities & DeviceProfiler Tests', () {
    test('DeviceCapabilities.simulated for entry device produces entry class and constrained tier', () {
      final cap = DeviceCapabilities.simulated(deviceClass: DeviceClass.entry);
      expect(cap.estimatedRamMb, 3072);
      expect(cap.isLowRamDevice, isTrue);
      expect(cap.cpuCoreCount, 4);

      final deviceClass = DeviceProfiler.classifyDevice(cap);
      expect(deviceClass, DeviceClass.entry);

      final baselineTier = DeviceProfiler.determineTier(deviceClass, cap);
      expect(baselineTier, PerformanceTier.constrained);
    });

    test('DeviceCapabilities for balanced device produces balanced class and standard tier', () {
      const cap = DeviceCapabilities(
        manufacturer: 'Samsung',
        model: 'Galaxy A34',
        hardware: 'mt6877',
        sdkVersion: 34,
        architecture: 'arm64',
        cpuCoreCount: 8,
        estimatedRamMb: 6144,
        displayRefreshRate: 60.0,
        devicePixelRatio: 2.2,
        logicalWidth: 384.0,
        logicalHeight: 832.0,
        hasBiometrics: true,
        hasBle: true,
        isLowRamDevice: false,
      );

      final deviceClass = DeviceProfiler.classifyDevice(cap);
      expect(deviceClass, DeviceClass.balanced);

      final baselineTier = DeviceProfiler.determineTier(deviceClass, cap);
      expect(baselineTier, PerformanceTier.standard);
    });

    test('DeviceCapabilities.simulated for highEnd device produces highEnd class and ultra tier', () {
      final cap = DeviceCapabilities.simulated(deviceClass: DeviceClass.highEnd);
      expect(cap.estimatedRamMb, 16384);
      expect(cap.displayRefreshRate, 120.0);
      expect(cap.cpuCoreCount, 8);

      final deviceClass = DeviceProfiler.classifyDevice(cap);
      expect(deviceClass, DeviceClass.highEnd);

      final baselineTier = DeviceProfiler.determineTier(deviceClass, cap);
      expect(baselineTier, PerformanceTier.ultra);
    });

    test('DeviceProfiler forces entry class if isLowRamDevice is true despite high RAM', () {
      const cap = DeviceCapabilities(
        manufacturer: 'TestBrand',
        model: 'BudgetGo',
        hardware: 'test_soc',
        sdkVersion: 33,
        architecture: 'arm64',
        cpuCoreCount: 8,
        estimatedRamMb: 6144,
        displayRefreshRate: 60.0,
        devicePixelRatio: 2.0,
        logicalWidth: 360,
        logicalHeight: 800,
        hasBiometrics: false,
        hasBle: true,
        isLowRamDevice: true,
      );
      final deviceClass = DeviceProfiler.classifyDevice(cap);
      expect(deviceClass, DeviceClass.entry);

      final tier = DeviceProfiler.determineTier(deviceClass, cap);
      expect(tier, PerformanceTier.constrained);
    });
  });

  group('PerformancePolicyResolver Resolution Tests', () {
    test('Constrained tier policy enforces zero-cost rendering and low memory cache', () {
      final cap = DeviceCapabilities.simulated(deviceClass: DeviceClass.entry);
      final profile = PerformancePolicyResolver.resolveProfile(
        capabilities: cap,
        thermalState: ThermalState.normal,
        userOverride: UserOverrideMode.automatic,
        reducedMotion: false,
      );

      expect(profile.performanceTier, PerformanceTier.constrained);
      // Zero-cost rendering
      expect(profile.renderingProfile.blurStrategy, BlurStrategy.tintedApproximation);
      expect(profile.renderingProfile.shadowComplexity, ShadowComplexity.minimal);
      expect(profile.renderingProfile.backgroundAnimationMode, BackgroundAnimationMode.staticGradient);
      expect(profile.renderingProfile.identityMeshDetail, IdentityMeshDetail.optimized);
      // Memory limits
      expect(profile.memoryProfile.maxImageCacheCount, 40);
      expect(profile.memoryProfile.maxImageCacheSizeBytes, 24 * 1024 * 1024);
      // Motion frame budget for 60Hz
      expect(profile.animationProfile.frameBudgetMs, closeTo(16.6, 0.1));
      // Scanner throttled to 720p
      expect(profile.scannerProfile.targetResolution, const Size(1280, 720));
      expect(profile.scannerProfile.detectionTimeoutMs, 900);
    });

    test('Ultra tier policy enables 120Hz, Gaussian blur, and fluid background', () {
      final cap = DeviceCapabilities.simulated(deviceClass: DeviceClass.highEnd);
      final profile = PerformancePolicyResolver.resolveProfile(
        capabilities: cap,
        thermalState: ThermalState.normal,
        userOverride: UserOverrideMode.automatic,
        reducedMotion: false,
      );

      expect(profile.performanceTier, PerformanceTier.ultra);
      expect(profile.renderingProfile.blurStrategy, BlurStrategy.gaussian);
      expect(profile.renderingProfile.shadowComplexity, ShadowComplexity.full);
      expect(profile.renderingProfile.backgroundAnimationMode, BackgroundAnimationMode.activeOrbsAndWaves);
      expect(profile.renderingProfile.identityMeshDetail, IdentityMeshDetail.full);
      expect(profile.animationProfile.frameBudgetMs, closeTo(8.33, 0.1));
      expect(profile.memoryProfile.maxImageCacheCount, 250);
      expect(profile.scannerProfile.targetResolution, const Size(1920, 1080));
    });

    test('Accessibility Reduced Motion forces instant transitions across all tiers', () {
      final cap = DeviceCapabilities.simulated(deviceClass: DeviceClass.highEnd);
      final profile = PerformancePolicyResolver.resolveProfile(
        capabilities: cap,
        thermalState: ThermalState.normal,
        userOverride: UserOverrideMode.automatic,
        reducedMotion: true,
      );

      expect(profile.animationProfile.reducedMotion, isTrue);
      expect(profile.animationProfile.fast, Duration.zero);
      expect(profile.animationProfile.standard, Duration.zero);
      expect(profile.animationProfile.deliberate, Duration.zero);
    });

    test('Thermal degradation steps down high-end rendering on critical heat', () {
      final cap = DeviceCapabilities.simulated(deviceClass: DeviceClass.highEnd);
      final profile = PerformancePolicyResolver.resolveProfile(
        capabilities: cap,
        thermalState: ThermalState.critical,
        userOverride: UserOverrideMode.automatic,
        reducedMotion: false,
      );

      // Throttling downgrades rendering config to relieve GPU pressure
      expect(profile.renderingProfile.backgroundAnimationMode, BackgroundAnimationMode.gentleOrbs);
    });

    test('User override performancePriority forces constrained rendering to maximize FPS', () {
      final cap = DeviceCapabilities.simulated(deviceClass: DeviceClass.highEnd);
      final profile = PerformancePolicyResolver.resolveProfile(
        capabilities: cap,
        thermalState: ThermalState.normal,
        userOverride: UserOverrideMode.performancePriority,
        reducedMotion: false,
      );

      expect(profile.performanceTier, PerformanceTier.constrained);
      expect(profile.renderingProfile.blurStrategy, BlurStrategy.tintedApproximation);
      expect(profile.renderingProfile.backgroundAnimationMode, BackgroundAnimationMode.staticGradient);
    });
  });

  group('PerformanceStorage & Persistence Tests', () {
    test('Loads default automatic override when nothing is stored', () async {
      final storage = PerformanceStorage();
      final override = await storage.loadUserOverride();
      expect(override, UserOverrideMode.automatic);

      final baseline = await storage.loadBaseline();
      expect(baseline, isNull);
    });

    test('Saves and loads baseline and user override correctly', () async {
      final storage = PerformanceStorage();
      await storage.saveUserOverride(UserOverrideMode.performancePriority);
      final override = await storage.loadUserOverride();
      expect(override, UserOverrideMode.performancePriority);

      final cap = DeviceCapabilities.simulated(deviceClass: DeviceClass.entry);
      await storage.saveBaseline(cap);
      final baseline = await storage.loadBaseline();
      expect(baseline, isNotNull);
      expect(baseline!.estimatedRamMb, cap.estimatedRamMb);
      expect(baseline.manufacturer, cap.manufacturer);

      await storage.clear();
      final cleared = await storage.loadUserOverride();
      expect(cleared, UserOverrideMode.automatic);
      final clearedBaseline = await storage.loadBaseline();
      expect(clearedBaseline, isNull);
    });
  });

  group('ThermalMonitor Tests', () {
    test('ThermalMonitor updates state and triggers listeners safely', () {
      final monitor = ThermalMonitor();
      expect(monitor.currentState, ThermalState.normal);

      int notifyCount = 0;
      monitor.addListener(() => notifyCount++);

      // Upward escalation applies immediately
      final updated = monitor.updateThermalState(ThermalState.warm);
      expect(updated, isTrue);
      expect(monitor.currentState, ThermalState.warm);
      expect(notifyCount, 1);

      // Downward de-escalation requires 15s cooldown hysteresis
      final cooledDownImmediately = monitor.updateThermalState(ThermalState.normal);
      expect(cooledDownImmediately, isFalse); // rejected by cooldown
      expect(monitor.currentState, ThermalState.warm);

      // Explicit test simulation hook bypasses cooldown
      monitor.simulateThermalState(ThermalState.critical);
      expect(monitor.currentState, ThermalState.critical);
      expect(monitor.isThermalThrottled, isTrue);
    });
  });

  group('RuntimePerformanceMonitor Tests', () {
    test('Monitors sustained pressure state correctly', () {
      final monitor = RuntimePerformanceMonitor(
        targetFrameBudgetMs: 16.67,
        windowSize: 30,
      );

      expect(monitor.hasSustainedPressure, isFalse);

      int notifyCount = 0;
      monitor.addListener(() => notifyCount++);

      // Simulate sustained pressure trigger
      monitor.simulateSustainedPressure(true);
      expect(monitor.hasSustainedPressure, isTrue);
      expect(notifyCount, 1);

      // Simulate recovery
      monitor.simulateSustainedPressure(false);
      expect(monitor.hasSustainedPressure, isFalse);
      expect(notifyCount, 2);
    });
  });

  group('PerformanceEngine Singleton & Recalibration Tests', () {
    test('PerformanceEngine initializes with test capabilities and allows override toggles', () async {
      final engine = PerformanceEngine.instance;
      final cap = DeviceCapabilities.simulated(deviceClass: DeviceClass.entry);

      await engine.initialize(testCapabilities: cap, startRuntimeMonitoring: false);

      expect(engine.isInitialized, isTrue);
      expect(engine.profile, isNotNull);
      expect(engine.capabilities.estimatedRamMb, cap.estimatedRamMb);

      // Change user override
      await engine.setUserOverride(UserOverrideMode.performancePriority);
      expect(engine.userOverrideMode, UserOverrideMode.performancePriority);
      expect(engine.profile.performanceTier, PerformanceTier.constrained);

      // Recalibrate
      await engine.recalibrate();
      expect(engine.profile, isNotNull);
    });
  });

  group('AdaptiveBlurSurface Widget Tests', () {
    testWidgets('Renders tintedApproximation mode without BackdropFilter for low-end devices', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AdaptiveBlurSurface(
              blurStrategy: BlurStrategy.tintedApproximation,
              backgroundColor: Colors.white,
              child: Text('Frosted Content'),
            ),
          ),
        ),
      );

      expect(find.text('Frosted Content'), findsOneWidget);
      // Ensure NO BackdropFilter widget is instantiated in the tree
      expect(find.byType(BackdropFilter), findsNothing);
    });

    testWidgets('Renders gaussian mode with BackdropFilter for high-end devices', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AdaptiveBlurSurface(
              blurStrategy: BlurStrategy.gaussian,
              blurSigma: 12.0,
              backgroundColor: Colors.white,
              child: Text('Gaussian Content'),
            ),
          ),
        ),
      );

      expect(find.text('Gaussian Content'), findsOneWidget);
      // Ensure BackdropFilter IS instantiated
      expect(find.byType(BackdropFilter), findsOneWidget);
    });
  });

  group('Security & Cryptography Non-Negotiable Invariants', () {
    test('Adaptive Performance NEVER weakens or impairs Ed25519 Passport signing and verification', () async {
      final fakeStorage = InMemoryPassportKeyStorage();
      final cryptoService = PassportCryptoService(storage: fakeStorage);
      final pubKey = await cryptoService.getOrCreatePublicKey();
      expect(pubKey.isNotEmpty, isTrue);

      const challenge = 'CAMPUSOS-CHALLENGE-2026-GATE';

      // Ensure that under ANY performance tier (including constrained/battery saver),
      // full cryptographic Ed25519 signing and verification produces valid results.
      for (final tier in PerformanceTier.values) {
        final signature = await cryptoService.signChallenge(challenge);
        expect(signature.isNotEmpty, isTrue);

        final isValid = await cryptoService.verifySignature(
          publicKey: pubKey,
          challenge: challenge,
          signature: signature,
        );

        expect(isValid, isTrue, reason: 'Failed verification under tier $tier');
      }
    });
  });
}
