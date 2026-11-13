import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../../services/notification_service.dart';
import 'emergency_alert.dart';

/// Abstract contract for triggering physical device alerts (audible siren, notification,
/// vibration, haptics) and silencing active sirens.
///
/// Enables hardware-independent testing and graceful degradation on low-end
/// or permission-restricted devices without crashing.
abstract class EmergencyNotifier {
  /// Reactive notifier holding the alert currently sounding an audible siren (null when silent).
  ValueListenable<EmergencyAlert?> get activeSirenAlert;

  /// Triggers sensory alert effects & siren (if enabled) for a newly received [EmergencyAlert].
  Future<void> notifyEmergency(EmergencyAlert alert);

  /// Silences any currently sounding emergency siren and haptic loop.
  Future<void> stopSiren({String? alertId});

  /// Plays a brief local siren & haptic test for the requested [pattern].
  Future<void> triggerSirenTest({
    EmergencySirenPattern pattern = EmergencySirenPattern.wail,
    Duration duration = const Duration(seconds: 6),
  });
}

/// Production implementation of [EmergencyNotifier] using native Android
/// alarm-stream siren synthesis (`campusos/emergency_siren`), local notifications,
/// and tactile haptics.
class PlatformEmergencyNotifier implements EmergencyNotifier {
  static const MethodChannel _sirenChannel =
      MethodChannel('campusos/emergency_siren');

  final ValueNotifier<EmergencyAlert?> _activeSirenAlert =
      ValueNotifier<EmergencyAlert?>(null);
  Timer? _autoClearTimer;

  @override
  ValueListenable<EmergencyAlert?> get activeSirenAlert => _activeSirenAlert;

  @override
  Future<void> notifyEmergency(EmergencyAlert alert) async {
    try {
      final isCritical = alert.severity == EmergencySeverity.critical;
      final shouldPlaySiren = alert.hasSiren || isCritical;
      final effectivePattern = alert.sirenPattern != EmergencySirenPattern.none
          ? alert.sirenPattern
          : EmergencySirenPattern.defaultFor(
              severity: alert.severity,
              category: alert.category,
            );

      // 1. Android system notification (runs 100% offline via local notification channel)
      try {
        await NotificationService.showOfflineEmergencyNotification(
          title: shouldPlaySiren
              ? '🚨 SIREN · ${alert.severity.label}: ${alert.title}'
              : '🚨 ${alert.severity.label}: ${alert.title}',
          message: alert.message,
          isCritical: isCritical,
          sirenEnabled: shouldPlaySiren,
          alertId: alert.alertId,
        );
      } catch (_) {}

      // 2. Audible native alarm-stream siren + continuous haptic pattern
      if (shouldPlaySiren && effectivePattern != EmergencySirenPattern.none) {
        final durationSec = isCritical ? 45 : 20;
        _setActiveSiren(alert, durationSeconds: durationSec);

        bool nativeSirenStarted = false;
        try {
          if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
            final ok = await _sirenChannel.invokeMethod<bool>('startSiren', {
              'pattern': effectivePattern.name,
              'durationSeconds': durationSec,
              'maxVolume': true,
            });
            nativeSirenStarted = ok == true;
          }
        } catch (e) {
          debugPrint('ℹ️ [EMERGENCY_NOTIFIER] Native siren channel unavailable: $e');
        }

        if (!nativeSirenStarted) {
          await _playFallbackAlertHaptics(isCritical: isCritical);
        }
      } else if (alert.severity == EmergencySeverity.warning) {
        await _playFallbackAlertHaptics(isCritical: false);
      }
    } catch (e) {
      debugPrint('ℹ️ [EMERGENCY_NOTIFIER] Platform sensory alert effect unavailable: $e');
    }
  }

  @override
  Future<void> stopSiren({String? alertId}) async {
    final current = _activeSirenAlert.value;
    if (alertId != null && current != null && current.alertId != alertId) {
      return;
    }

    _autoClearTimer?.cancel();
    _autoClearTimer = null;
    _activeSirenAlert.value = null;

    try {
      await NotificationService.cancelEmergencyNotification(
        alertId ?? current?.alertId,
      );
    } catch (_) {}

    try {
      if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
        await _sirenChannel.invokeMethod<bool>('stopSiren');
      }
    } catch (e) {
      debugPrint('ℹ️ [EMERGENCY_NOTIFIER] Stop siren channel unavailable: $e');
    }
  }

  @override
  Future<void> triggerSirenTest({
    EmergencySirenPattern pattern = EmergencySirenPattern.wail,
    Duration duration = const Duration(seconds: 6),
  }) async {
    final effectivePattern = pattern == EmergencySirenPattern.none
        ? EmergencySirenPattern.wail
        : pattern;
    final testAlert = EmergencyAlert(
      alertId: 'siren_test_${DateTime.now().millisecondsSinceEpoch}',
      issuerDeviceId: 'local_device',
      issuerRole: 'test',
      scope: EmergencyScope.campus,
      severity: EmergencySeverity.critical,
      category: EmergencyCategory.other,
      title: 'Siren Test (${effectivePattern.label})',
      message: 'Hardware audible siren and vibration diagnostic check.',
      createdAt: DateTime.now(),
      expiresAt: DateTime.now().add(const Duration(minutes: 2)),
      firstSeenAt: DateTime.now(),
      lastSeenAt: DateTime.now(),
      sirenEnabled: true,
      sirenPattern: effectivePattern,
    );

    final durationSec = duration.inSeconds.clamp(2, 60);
    _setActiveSiren(testAlert, durationSeconds: durationSec);

    bool nativeStarted = false;
    try {
      if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
        final ok = await _sirenChannel.invokeMethod<bool>('startSiren', {
          'pattern': effectivePattern.name,
          'durationSeconds': durationSec,
          'maxVolume': true,
        });
        nativeStarted = ok == true;
      }
    } catch (_) {}

    if (!nativeStarted) {
      await _playFallbackAlertHaptics(isCritical: true);
    }
  }

  void _setActiveSiren(EmergencyAlert alert, {required int durationSeconds}) {
    _autoClearTimer?.cancel();
    _activeSirenAlert.value = alert;
    _autoClearTimer = Timer(Duration(seconds: durationSeconds), () {
      if (_activeSirenAlert.value?.alertId == alert.alertId) {
        _activeSirenAlert.value = null;
      }
    });
  }

  Future<void> _playFallbackAlertHaptics({required bool isCritical}) async {
    try {
      if (isCritical) {
        await HapticFeedback.heavyImpact();
        await Future.delayed(const Duration(milliseconds: 120));
        await HapticFeedback.heavyImpact();
        await SystemSound.play(SystemSoundType.alert);
      } else {
        await HapticFeedback.mediumImpact();
        await SystemSound.play(SystemSoundType.alert);
      }
    } catch (_) {}
  }
}

/// In-memory test double for verifying emergency alert and siren notification behavior.
class MockEmergencyNotifier implements EmergencyNotifier {
  final List<EmergencyAlert> notifiedAlerts = [];
  final List<String?> stoppedAlertIds = [];
  final List<EmergencySirenPattern> testedPatterns = [];
  int notificationCount = 0;
  int stopCount = 0;
  int sirenTestCount = 0;

  final ValueNotifier<EmergencyAlert?> _activeSirenAlert =
      ValueNotifier<EmergencyAlert?>(null);

  @override
  ValueListenable<EmergencyAlert?> get activeSirenAlert => _activeSirenAlert;

  @override
  Future<void> notifyEmergency(EmergencyAlert alert) async {
    notificationCount++;
    notifiedAlerts.add(alert);
    if (alert.hasSiren || alert.isCritical) {
      _activeSirenAlert.value = alert;
    }
  }

  @override
  Future<void> stopSiren({String? alertId}) async {
    stopCount++;
    stoppedAlertIds.add(alertId);
    if (alertId == null || _activeSirenAlert.value?.alertId == alertId) {
      _activeSirenAlert.value = null;
    }
  }

  @override
  Future<void> triggerSirenTest({
    EmergencySirenPattern pattern = EmergencySirenPattern.wail,
    Duration duration = const Duration(seconds: 6),
  }) async {
    sirenTestCount++;
    testedPatterns.add(pattern);
  }

  void reset() {
    notifiedAlerts.clear();
    stoppedAlertIds.clear();
    testedPatterns.clear();
    notificationCount = 0;
    stopCount = 0;
    sirenTestCount = 0;
    _activeSirenAlert.value = null;
  }
}
