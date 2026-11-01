/// Performance audit configuration, device thresholds, and status categories
/// for CampusOS Phase 3B automated validation.
library;

enum PerformanceStatus {
  pass,
  warning,
  critical,
  notMeasured,
  manualValidationRequired;

  String get label {
    switch (this) {
      case PerformanceStatus.pass:
        return 'PASS';
      case PerformanceStatus.warning:
        return 'WARNING';
      case PerformanceStatus.critical:
        return 'CRITICAL';
      case PerformanceStatus.notMeasured:
        return 'NOT MEASURED';
      case PerformanceStatus.manualValidationRequired:
        return 'MANUAL VALIDATION REQUIRED';
    }
  }
}

enum ValidationMode {
  automatedSoftware,
  manualHardwareValidation,
}

class PerformanceConfig {
  PerformanceConfig._();

  // Target Physical Device Specification
  static const String deviceName = 'Samsung Galaxy A55';
  static const String deviceModel = 'SM-A556E';
  static const String deviceProduct = 'a55xnsins';
  static const int androidApi = 36;
  static const String androidVersion = 'Android 16';
  static const double nativeRefreshRateHz = 120.0;
  static const int displayWidthPx = 1080;
  static const int displayHeightPx = 2340;
  static const double devicePixelRatio = 2.8125;

  // Frame Budgets
  static const double frameBudget120HzMs = 1000.0 / 120.0; // 8.33 ms
  static const double frameBudget60HzMs = 1000.0 / 60.0; // 16.67 ms

  // Thresholds for 120Hz Displays
  static const double warningFrameThresholdMs = 16.67; // Dropped below 60fps equivalent
  static const double criticalFrameThresholdMs = 33.33; // Noticeable freeze / multi-frame drop
  static const double warningJankRatePercent = 5.0; // >5% janky frames triggers warning
  static const double criticalJankRatePercent = 15.0; // >15% janky frames triggers critical

  // Startup Targets
  static const double coldStartupTargetMs = 1200.0;
  static const double coldStartupWarningMs = 2000.0;
  static const double firstMeaningfulFrameTargetMs = 800.0;
  static const double firstMeaningfulFrameWarningMs = 1500.0;

  // Interaction / Navigation Latency Targets
  static const double navigationTransitionTargetMs = 280.0;
  static const double modalPresentationTargetMs = 250.0;
  static const double scrollActionSampleDurationMs = 1500.0;

  // Memory Leak Tolerance across repeated navigation cycles (e.g. 5 iterations)
  static const int repeatedNavigationCycles = 5;
  static const int memoryGrowthWarningKb = 8192; // 8 MB growth triggers warning
  static const int memoryGrowthCriticalKb = 20480; // 20 MB growth triggers critical
}
