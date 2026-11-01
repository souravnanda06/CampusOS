import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'device_capabilities.dart';
import 'device_profiler.dart';
import 'performance_profile.dart';
import 'performance_policy.dart';
import 'persistence/performance_storage.dart';
import 'thermal/thermal_monitor.dart';
import 'runtime/runtime_performance_monitor.dart';

/// Centralized Adaptive Performance Engine for CampusOS.
///
/// Acts as the single source of truth for device capability detection,
/// runtime telemetry, thermal adaptation, and subsystem policies.
class PerformanceEngine extends ChangeNotifier {
  static final PerformanceEngine _singleton = PerformanceEngine._internal();
  factory PerformanceEngine() => _singleton;
  static PerformanceEngine get instance => _singleton;

  final DeviceProfiler _profiler;
  final PerformanceStorage _storage;
  final ThermalMonitor _thermalMonitor;
  late final RuntimePerformanceMonitor _runtimeMonitor;

  DeviceCapabilities _capabilities = const DeviceCapabilities();
  late PerformanceProfile _currentProfile;
  UserOverrideMode _userOverrideMode = UserOverrideMode.automatic;
  bool _reducedMotion = false;
  bool _isInitialized = false;
  bool _isCalibrating = false;

  PerformanceEngine._internal({
    DeviceProfiler? profiler,
    PerformanceStorage? storage,
    ThermalMonitor? thermalMonitor,
  })  : _profiler = profiler ?? DeviceProfiler(),
        _storage = storage ?? PerformanceStorage(),
        _thermalMonitor = thermalMonitor ?? ThermalMonitor() {
    _currentProfile = PerformancePolicyResolver.resolveProfile(
      capabilities: _capabilities,
    );
  }

  /// Visible for testing constructor to allow dependency injection.
  @visibleForTesting
  PerformanceEngine.withDependencies({
    required DeviceProfiler profiler,
    required PerformanceStorage storage,
    required ThermalMonitor thermalMonitor,
    RuntimePerformanceMonitor? runtimeMonitor,
  })  : _profiler = profiler,
        _storage = storage,
        _thermalMonitor = thermalMonitor {
    _runtimeMonitor = runtimeMonitor ??
        RuntimePerformanceMonitor(
          targetFrameBudgetMs: _capabilities.displayRefreshRate > 0
              ? (1000.0 / _capabilities.displayRefreshRate)
              : 16.67,
        );
    _currentProfile = PerformancePolicyResolver.resolveProfile(
      capabilities: _capabilities,
    );
  }

  // Getters
  DeviceCapabilities get capabilities => _capabilities;
  PerformanceProfile get profile => _currentProfile;
  UserOverrideMode get userOverrideMode => _userOverrideMode;
  ThermalState get thermalState => _thermalMonitor.currentState;
  bool get isInitialized => _isInitialized;
  bool get isCalibrating => _isCalibrating;
  ThermalMonitor get thermalMonitor => _thermalMonitor;
  RuntimePerformanceMonitor get runtimeMonitor => _runtimeMonitor;

  /// Initializes the performance engine on app startup.
  Future<void> initialize({
    DeviceCapabilities? testCapabilities,
    bool startRuntimeMonitoring = true,
  }) async {
    if (_isInitialized && testCapabilities == null) return;

    try {
      // 1. Load user override
      _userOverrideMode = await _storage.loadUserOverride();

      // 2. Load stored baseline or profile device
      if (testCapabilities != null) {
        _capabilities = testCapabilities;
      } else {
        final stored = await _storage.loadBaseline();
        final live = await _profiler.profileDevice();
        // If stored baseline exists and has high refresh rate >= live, keep stored,
        // otherwise upgrade to live hardware capabilities to ensure 120Hz/90Hz is active!
        if (stored != null && stored.displayRefreshRate >= live.displayRefreshRate) {
          _capabilities = stored;
        } else {
          _capabilities = live;
          await _storage.saveBaseline(_capabilities);
        }
      }

      // 3. Initialize Runtime Monitor with display frame budget
      _runtimeMonitor = RuntimePerformanceMonitor(
        targetFrameBudgetMs: _capabilities.displayRefreshRate > 0
            ? (1000.0 / _capabilities.displayRefreshRate)
            : 16.67,
      );

      if (startRuntimeMonitoring && !kIsWeb) {
        _runtimeMonitor.start();
      }

      // 4. Attach telemetry listeners
      _thermalMonitor.addListener(_onRuntimeConditionsChanged);
      _runtimeMonitor.addListener(_onRuntimeConditionsChanged);

      // 5. Check platform accessibility reduced motion or persisted user preference
      final prefs = await SharedPreferences.getInstance();
      final userPref = prefs.getBool('campusos_reduced_motion');
      _reducedMotion = userPref ??
          WidgetsBinding.instance.platformDispatcher.accessibilityFeatures.disableAnimations;

      // 6. Compute initial profile and apply memory policy
      final lastOptimized = await _storage.getLastCalibratedTime();
      _recomputeProfile(lastOptimized: lastOptimized);
      _currentProfile.memoryProfile.applyToPaintingBinding();

      _isInitialized = true;
      notifyListeners();
    } catch (e) {
      debugPrint('⚠️ [PerformanceEngine] Initialization fallback: $e');
      _currentProfile = PerformancePolicyResolver.resolveProfile(
        capabilities: _capabilities,
      );
      _isInitialized = true;
      notifyListeners();
    }
  }

  /// Manually recalibrates and optimizes CampusOS for the current device.
  /// Triggered by the "⚡ Optimize CampusOS" user action.
  Future<PerformanceProfile> recalibrate() async {
    _isCalibrating = true;
    notifyListeners();

    try {
      // 1. Force native Android high refresh rate if supported
      if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
        try {
          const channel = MethodChannel('campusos/performance');
          await channel.invokeMethod('forceHighRefreshRate');
        } catch (_) {}
      }

      // 2. Re-query physical device capabilities
      _capabilities = await _profiler.profileDevice();
      await _storage.saveBaseline(_capabilities);

      // 3. Apply updated policy
      final now = DateTime.now();
      _recomputeProfile(lastOptimized: now);
      _currentProfile.memoryProfile.applyToPaintingBinding();

      _isCalibrating = false;
      notifyListeners();
      return _currentProfile;
    } catch (e) {
      debugPrint('⚠️ [PerformanceEngine] Recalibration error: $e');
      _isCalibrating = false;
      notifyListeners();
      return _currentProfile;
    }
  }

  /// Updates the user's explicit optimization override.
  Future<void> setUserOverride(UserOverrideMode mode) async {
    if (_userOverrideMode == mode) return;
    _userOverrideMode = mode;
    await _storage.saveUserOverride(mode);
    _recomputeProfile();
    _currentProfile.memoryProfile.applyToPaintingBinding();
    notifyListeners();
  }

  /// Updates the accessibility reduced-motion state.
  void setReducedMotion(bool reduced) async {
    if (_reducedMotion == reduced) return;
    _reducedMotion = reduced;
    _recomputeProfile();
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('campusos_reduced_motion', reduced);
    } catch (_) {}
  }

  void _onRuntimeConditionsChanged() {
    _recomputeProfile();
    notifyListeners();
  }

  void _recomputeProfile({DateTime? lastOptimized}) {
    _currentProfile = PerformancePolicyResolver.resolveProfile(
      capabilities: _capabilities,
      thermalState: _thermalMonitor.currentState,
      networkQuality: NetworkQuality.standard,
      userOverride: _userOverrideMode,
      reducedMotion: _reducedMotion,
      sustainedFramePressure:
          _isInitialized ? _runtimeMonitor.hasSustainedPressure : false,
      lastOptimized: lastOptimized ?? _currentProfile.lastOptimized,
    );
  }

  @override
  void dispose() {
    _thermalMonitor.removeListener(_onRuntimeConditionsChanged);
    _runtimeMonitor.removeListener(_onRuntimeConditionsChanged);
    _runtimeMonitor.stop();
    super.dispose();
  }
}
