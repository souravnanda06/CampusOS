import 'package:flutter/widgets.dart';

/// Centralized Apple-level animation constants for consistent timing, curves,
/// and accessible reduced-motion handling across CampusOS.
class AnimationConstants {
  AnimationConstants._();

  // Duration presets (refined for tactile perceived performance)
  static const Duration micro = Duration(milliseconds: 120);
  static const Duration fast = Duration(milliseconds: 180);
  static const Duration standard = Duration(milliseconds: 240);
  static const Duration medium = Duration(milliseconds: 280);
  static const Duration slow = Duration(milliseconds: 360);
  static const Duration verySlow = Duration(milliseconds: 500);

  // Curve definitions
  static const Curve appleFluid = Curves.easeOutCubic;
  static const Curve appleSnappy = Curves.easeOutQuint;
  static const Curve easeInOutCubic = Curves.easeInOutCubic;
  static const Curve elasticOut = Curves.elasticOut;
  static const Curve bounceOut = Curves.bounceOut;
  static const Curve spring = Curves.easeOutBack;

  // Delay multipliers for staggered animations (ms)
  static const int staggerDelay = 30;
  static const int listItemDelay = 60;

  // Scale factors
  static const double pressScale = 0.96;
  static const double hoverScale = 1.03;

  /// Returns true if the user or device has requested reduced motion.
  static bool isReducedMotion(BuildContext context) {
    return MediaQuery.maybeOf(context)?.disableAnimations ?? false;
  }

  /// Adjusts animation duration based on system accessibility preferences.
  /// If reduced motion is enabled, returns [Duration.zero] for immediate rendering.
  static Duration responsiveDuration(BuildContext context, Duration standardDuration) {
    if (isReducedMotion(context)) {
      return Duration.zero;
    }
    return standardDuration;
  }
}
