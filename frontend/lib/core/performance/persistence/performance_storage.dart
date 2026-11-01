import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../device_capabilities.dart';

/// Persists non-volatile device baseline profiles, calibration timestamps, and user overrides.
class PerformanceStorage {
  static const String _keyCapabilities = 'campusos_perf_capabilities_v1';
  static const String _keyUserOverride = 'campusos_perf_user_override_v1';
  static const String _keyLastCalibratedMs = 'campusos_perf_last_calibrated_ms_v1';
  static const String _keySchemaVersion = 'campusos_perf_schema_version';
  static const int currentSchemaVersion = 2;

  final SharedPreferences? _prefsInstance;

  PerformanceStorage({SharedPreferences? prefs}) : _prefsInstance = prefs;

  Future<SharedPreferences> _getPrefs() async {
    if (_prefsInstance != null) return _prefsInstance!;
    return await SharedPreferences.getInstance();
  }

  /// Saves calibrated baseline capabilities and calibration timestamp.
  Future<void> saveBaseline(DeviceCapabilities capabilities) async {
    try {
      final prefs = await _getPrefs();
      final jsonStr = jsonEncode(capabilities.toMap());
      await prefs.setString(_keyCapabilities, jsonStr);
      await prefs.setInt(_keyLastCalibratedMs, DateTime.now().millisecondsSinceEpoch);
      await prefs.setInt(_keySchemaVersion, currentSchemaVersion);
    } catch (e) {
      debugPrint('⚠️ [PerformanceStorage] Failed to save baseline: $e');
    }
  }

  /// Loads stored baseline capabilities if available and schema version matches.
  Future<DeviceCapabilities?> loadBaseline() async {
    try {
      final prefs = await _getPrefs();
      final version = prefs.getInt(_keySchemaVersion) ?? 0;
      if (version != currentSchemaVersion) {
        return null;
      }
      final jsonStr = prefs.getString(_keyCapabilities);
      if (jsonStr == null || jsonStr.isEmpty) return null;
      final map = jsonDecode(jsonStr) as Map<String, dynamic>;
      return DeviceCapabilities.fromMap(map);
    } catch (e) {
      debugPrint('⚠️ [PerformanceStorage] Corrupted baseline storage. Resetting: $e');
      return null;
    }
  }

  /// Gets the timestamp of the last manual or automatic device calibration.
  Future<DateTime?> getLastCalibratedTime() async {
    try {
      final prefs = await _getPrefs();
      final ms = prefs.getInt(_keyLastCalibratedMs);
      if (ms == null) return null;
      return DateTime.fromMillisecondsSinceEpoch(ms);
    } catch (_) {
      return null;
    }
  }

  /// Saves the user's explicit performance override.
  Future<void> saveUserOverride(UserOverrideMode mode) async {
    try {
      final prefs = await _getPrefs();
      await prefs.setString(_keyUserOverride, mode.name);
    } catch (e) {
      debugPrint('⚠️ [PerformanceStorage] Failed to save override: $e');
    }
  }

  /// Loads the user's explicit performance override.
  Future<UserOverrideMode> loadUserOverride() async {
    try {
      final prefs = await _getPrefs();
      final modeStr = prefs.getString(_keyUserOverride);
      if (modeStr == null) return UserOverrideMode.automatic;
      return UserOverrideMode.values.firstWhere(
        (e) => e.name == modeStr,
        orElse: () => UserOverrideMode.automatic,
      );
    } catch (_) {
      return UserOverrideMode.automatic;
    }
  }

  /// Clears stored performance configuration.
  Future<void> clear() async {
    try {
      final prefs = await _getPrefs();
      await prefs.remove(_keyCapabilities);
      await prefs.remove(_keyUserOverride);
      await prefs.remove(_keyLastCalibratedMs);
      await prefs.remove(_keySchemaVersion);
    } catch (_) {}
  }
}
