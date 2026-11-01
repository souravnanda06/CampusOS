import 'device_capabilities.dart';
import 'device_profiler.dart';
import 'performance_profile.dart';
import 'rendering/rendering_config.dart';
import 'motion/motion_config.dart';
import 'memory/memory_policy.dart';
import 'network/network_policy.dart';
import 'scanner/scanner_config.dart';

/// Policy resolver that deterministically computes a [PerformanceProfile] from
/// device capabilities, runtime conditions, and user preferences.
class PerformancePolicyResolver {
  PerformancePolicyResolver._();

  /// Resolves the comprehensive [PerformanceProfile].
  static PerformanceProfile resolveProfile({
    required DeviceCapabilities capabilities,
    ThermalState thermalState = ThermalState.normal,
    NetworkQuality networkQuality = NetworkQuality.standard,
    UserOverrideMode userOverride = UserOverrideMode.automatic,
    bool reducedMotion = false,
    bool sustainedFramePressure = false,
    DateTime? lastOptimized,
  }) {
    final deviceClass = DeviceProfiler.classifyDevice(capabilities);
    var tier = DeviceProfiler.determineTier(deviceClass, capabilities);

    // 1. User Override Adjustments
    if (userOverride == UserOverrideMode.performancePriority) {
      if (tier != PerformanceTier.constrained) {
        tier = PerformanceTier.constrained;
      }
    } else if (userOverride == UserOverrideMode.visualQualityPriority) {
      if (tier == PerformanceTier.constrained && thermalState != ThermalState.hot && thermalState != ThermalState.critical) {
        tier = PerformanceTier.standard;
      }
    }

    // 2. Dynamic Thermal & Frame Pressure Demotions (Graceful throttling)
    final isUnderPressure = thermalState == ThermalState.hot ||
        thermalState == ThermalState.critical ||
        sustainedFramePressure;

    // 3. Resolve Rendering Config
    RenderingConfig rendering;
    switch (tier) {
      case PerformanceTier.constrained:
        rendering = RenderingConfig.constrained();
        break;
      case PerformanceTier.standard:
        rendering = isUnderPressure
            ? RenderingConfig.constrained()
            : RenderingConfig.balanced();
        break;
      case PerformanceTier.highPerformance:
        rendering = isUnderPressure
            ? RenderingConfig.balanced()
            : RenderingConfig.highEnd();
        break;
      case PerformanceTier.ultra:
        rendering = isUnderPressure
            ? RenderingConfig.balanced()
            : RenderingConfig.highEnd();
        break;
    }

    // 4. Resolve Motion Config (Accessibility ALWAYS overrides cosmetic performance)
    final motion = MotionConfig(
      displayRefreshRate: capabilities.displayRefreshRate,
      reducedMotion: reducedMotion,
      enableSpringPhysics: !isUnderPressure && !reducedMotion,
    );

    // 5. Resolve Memory Policy
    MemoryPolicy memory;
    switch (tier) {
      case PerformanceTier.constrained:
        memory = MemoryPolicy.constrained();
        break;
      case PerformanceTier.standard:
        memory = isUnderPressure
            ? MemoryPolicy.constrained()
            : MemoryPolicy.balanced();
        break;
      case PerformanceTier.highPerformance:
      case PerformanceTier.ultra:
        memory = isUnderPressure
            ? MemoryPolicy.balanced()
            : MemoryPolicy.highEnd();
        break;
    }

    // 6. Resolve Scanner Config
    ScannerConfig scanner;
    if (isUnderPressure || tier == PerformanceTier.constrained) {
      scanner = ScannerConfig.constrained();
    } else if (tier == PerformanceTier.ultra) {
      scanner = ScannerConfig.highEnd();
    } else {
      scanner = ScannerConfig.balanced();
    }

    // 7. Resolve Network Policy
    final network = NetworkOptimizationPolicy.forQuality(networkQuality);

    // 8. Resolve Background Work Policy
    BackgroundWorkPolicy background;
    if (isUnderPressure || tier == PerformanceTier.constrained) {
      background = BackgroundWorkPolicy.constrained();
    } else if (tier == PerformanceTier.ultra) {
      background = BackgroundWorkPolicy.highEnd();
    } else {
      background = BackgroundWorkPolicy.balanced();
    }

    return PerformanceProfile(
      deviceClass: deviceClass,
      performanceTier: tier,
      refreshRate: capabilities.displayRefreshRate,
      renderingProfile: rendering,
      animationProfile: motion,
      memoryProfile: memory,
      networkProfile: network,
      scannerProfile: scanner,
      thermalProfile: thermalState,
      backgroundWorkProfile: background,
      userOverrideMode: userOverride,
      lastOptimized: lastOptimized ?? DateTime.now(),
    );
  }
}
