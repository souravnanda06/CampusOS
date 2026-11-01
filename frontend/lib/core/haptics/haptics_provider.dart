import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Global haptic feedback preference for CampusOS.
///
/// When disabled, all HapticFeedback calls should check [isEnabled] first.
/// Singleton pattern, consistent with ThemeProvider and LanguageProvider.
class HapticsProvider extends ChangeNotifier {
  static const String _prefKey = 'campusos_haptics_enabled';
  static final HapticsProvider instance = HapticsProvider._internal();

  factory HapticsProvider() => instance;

  bool _isEnabled = true;

  bool get isEnabled => _isEnabled;

  HapticsProvider._internal() {
    _loadPreference();
  }

  Future<void> _loadPreference() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getBool(_prefKey);
      if (saved != null) {
        _isEnabled = saved;
        notifyListeners();
      }
    } catch (_) {}
  }

  Future<void> setEnabled(bool enabled) async {
    if (_isEnabled == enabled) return;

    _isEnabled = enabled;
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_prefKey, enabled);
    } catch (_) {}
  }

  /// Convenience: performs light impact only if haptics enabled.
  void lightImpact() {
    if (_isEnabled) HapticFeedback.lightImpact();
  }

  /// Convenience: performs medium impact only if haptics enabled.
  void mediumImpact() {
    if (_isEnabled) HapticFeedback.mediumImpact();
  }

  /// Convenience: performs heavy impact only if haptics enabled.
  void heavyImpact() {
    if (_isEnabled) HapticFeedback.heavyImpact();
  }

  /// Convenience: performs selection click only if haptics enabled.
  void selectionClick() {
    if (_isEnabled) HapticFeedback.selectionClick();
  }

  /// Convenience: performs vibrate only if haptics enabled.
  void vibrate() {
    if (_isEnabled) HapticFeedback.vibrate();
  }
}
