import 'haptics_provider.dart';

/// Application-wide tactile response dispatcher.
/// All tactile feedback calls across CampusOS route through this class.
/// When user disables Haptic Feedback in Settings, all calls safely no-op.
class AppHaptics {
  AppHaptics._();

  static void lightImpact() {
    HapticsProvider.instance.lightImpact();
  }

  static void mediumImpact() {
    HapticsProvider.instance.mediumImpact();
  }

  static void heavyImpact() {
    HapticsProvider.instance.heavyImpact();
  }

  static void selectionClick() {
    HapticsProvider.instance.selectionClick();
  }

  static void vibrate() {
    HapticsProvider.instance.vibrate();
  }
}
