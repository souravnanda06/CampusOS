import 'package:flutter/foundation.dart';
import '../device_capabilities.dart';

/// Monitors device thermal state safely with hysteresis and fallback simulation.
class ThermalMonitor extends ChangeNotifier {
  ThermalState _currentState = ThermalState.normal;
  DateTime _lastStateChange = DateTime.now();
  static const Duration _cooldownDuration = Duration(seconds: 15);

  ThermalState get currentState => _currentState;

  /// Returns true if the device is experiencing thermal throttling.
  bool get isThermalThrottled =>
      _currentState == ThermalState.hot || _currentState == ThermalState.critical;

  /// Updates the thermal state with hysteresis protection to prevent rapid oscillation.
  bool updateThermalState(ThermalState newState) {
    if (newState == _currentState) return false;

    // Upward escalation (hotter) applies immediately to protect hardware
    final isEscalating = newState.index > _currentState.index;
    final now = DateTime.now();

    if (isEscalating) {
      _currentState = newState;
      _lastStateChange = now;
      notifyListeners();
      return true;
    }

    // Downward de-escalation (cooling down) requires cooldown hysteresis
    if (now.difference(_lastStateChange) >= _cooldownDuration) {
      _currentState = newState;
      _lastStateChange = now;
      notifyListeners();
      return true;
    }

    return false;
  }

  /// Explicit simulation hook for deterministic unit & integration tests.
  @visibleForTesting
  void simulateThermalState(ThermalState state) {
    _currentState = state;
    _lastStateChange = DateTime.now();
    notifyListeners();
  }
}
