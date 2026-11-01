import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../../services/notification_service.dart';
import 'emergency_alert.dart';

/// Abstract contract for triggering physical device alerts (sound, vibration, haptics).
///
/// Enables hardware-independent testing and graceful degradation on low-end
/// or permission-restricted devices without crashing.
abstract class EmergencyNotifier {
  /// Triggers sensory alert effects for a newly received [EmergencyAlert].
  Future<void> notifyEmergency(EmergencyAlert alert);
}

/// Production implementation of [EmergencyNotifier] using platform services.
///
/// Handles missing plugins and permission restrictions gracefully.
class PlatformEmergencyNotifier implements EmergencyNotifier {
  @override
  Future<void> notifyEmergency(EmergencyAlert alert) async {
    try {
      final isCritical = alert.severity == EmergencySeverity.critical;

      // 1. Android system notification (runs 100% offline via local notification channel)
      try {
        await NotificationService.showOfflineEmergencyNotification(
          title: '🚨 ${alert.severity.label}: ${alert.title}',
          message: alert.message,
          isCritical: isCritical,
        );
      } catch (_) {}

      // 2. High-intensity haptic vibration sequence & audible alarm
      if (isCritical) {
        await HapticFeedback.heavyImpact();
        await Future.delayed(const Duration(milliseconds: 120));
        await HapticFeedback.heavyImpact();
        await SystemSound.play(SystemSoundType.alert);
      } else if (alert.severity == EmergencySeverity.warning) {
        await HapticFeedback.mediumImpact();
        await SystemSound.play(SystemSoundType.alert);
      }
    } catch (e) {
      debugPrint('ℹ️ [EMERGENCY_NOTIFIER] Platform sensory alert effect unavailable: $e');
    }
  }
}

/// In-memory test double for verifying emergency alert notification behavior.
class MockEmergencyNotifier implements EmergencyNotifier {
  final List<EmergencyAlert> notifiedAlerts = [];
  int notificationCount = 0;

  @override
  Future<void> notifyEmergency(EmergencyAlert alert) async {
    notificationCount++;
    notifiedAlerts.add(alert);
  }

  void reset() {
    notifiedAlerts.clear();
    notificationCount = 0;
  }
}
