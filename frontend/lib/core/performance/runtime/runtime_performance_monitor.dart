import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';

/// Lightweight runtime frame performance telemetry that monitors rasterization
/// pressure using [SchedulerBinding.addTimingsCallback] with hysteresis.
class RuntimePerformanceMonitor extends ChangeNotifier {
  final double targetFrameBudgetMs;
  final int windowSize;

  final List<double> _recentFrameDurations = [];
  bool _hasSustainedPressure = false;
  DateTime _lastPressureChange = DateTime.now();
  static const Duration _pressureCooldown = Duration(seconds: 20);
  bool _isMonitoring = false;

  RuntimePerformanceMonitor({
    this.targetFrameBudgetMs = 16.67,
    this.windowSize = 60,
  });

  bool get hasSustainedPressure => _hasSustainedPressure;
  bool get isMonitoring => _isMonitoring;
  int get recordedSampleCount => _recentFrameDurations.length;

  /// Average frame duration across the current sampling window.
  double get averageFrameDurationMs {
    if (_recentFrameDurations.isEmpty) return 0.0;
    return _recentFrameDurations.reduce((a, b) => a + b) /
        _recentFrameDurations.length;
  }

  /// Starts listening to Flutter frame timings.
  void start() {
    if (_isMonitoring) return;
    try {
      SchedulerBinding.instance.addTimingsCallback(_onFrameTimings);
      _isMonitoring = true;
    } catch (e) {
      debugPrint('⚠️ [RuntimePerformanceMonitor] Could not attach frame timings callback: $e');
    }
  }

  /// Stops listening to Flutter frame timings.
  void stop() {
    if (!_isMonitoring) return;
    try {
      SchedulerBinding.instance.removeTimingsCallback(_onFrameTimings);
      _isMonitoring = false;
    } catch (e) {
      debugPrint('⚠️ [RuntimePerformanceMonitor] Could not remove frame timings callback: $e');
    }
  }

  void _onFrameTimings(List<FrameTiming> timings) {
    for (final timing in timings) {
      // Total frame time: build + raster in milliseconds
      final totalDurationMs =
          (timing.buildDuration.inMicroseconds + timing.rasterDuration.inMicroseconds) / 1000.0;
      _recentFrameDurations.add(totalDurationMs);
      if (_recentFrameDurations.length > windowSize) {
        _recentFrameDurations.removeAt(0);
      }
    }

    _evaluatePressure();
  }

  void _evaluatePressure() {
    if (_recentFrameDurations.length < 30) return;

    final overBudgetCount = _recentFrameDurations
        .where((d) => d > (targetFrameBudgetMs * 1.25))
        .length;
    final overBudgetRatio = overBudgetCount / _recentFrameDurations.length;

    final now = DateTime.now();
    // Sustained pressure triggers if > 40% of frames in the window severely exceeded budget
    if (overBudgetRatio >= 0.40 && !_hasSustainedPressure) {
      _hasSustainedPressure = true;
      _lastPressureChange = now;
      notifyListeners();
    } else if (overBudgetRatio < 0.15 && _hasSustainedPressure) {
      // Recovery with cooldown hysteresis
      if (now.difference(_lastPressureChange) >= _pressureCooldown) {
        _hasSustainedPressure = false;
        _lastPressureChange = now;
        notifyListeners();
      }
    }
  }

  /// Explicit simulation hook for tests.
  @visibleForTesting
  void simulateSustainedPressure(bool pressure) {
    _hasSustainedPressure = pressure;
    _lastPressureChange = DateTime.now();
    notifyListeners();
  }

  @override
  void dispose() {
    stop();
    super.dispose();
  }
}
