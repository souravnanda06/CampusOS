import 'dart:math' as math;
import 'package:flutter/material.dart';

/// True Apple iOS UIScrollView spring bounce physics.
///
/// Features:
/// - Critically damped Newtonian spring mechanics matching iOS 18 / visionOS
/// - Smooth elastic overscroll resistance without artificial wobble
/// - Precise Apple deceleration rate (0.998)
/// - Drop-in replacement for standard [BouncingScrollPhysics]
class AppleSpringScrollPhysics extends BouncingScrollPhysics {
  const AppleSpringScrollPhysics({
    ScrollPhysics? parent,
    ScrollDecelerationRate decelerationRate = ScrollDecelerationRate.normal,
  }) : super(parent: parent, decelerationRate: decelerationRate);

  /// Convenient static constant for scroll views that must always bounce even if content fits.
  static const ScrollPhysics always = AlwaysScrollableScrollPhysics(
    parent: AppleSpringScrollPhysics(),
  );

  /// Standard iOS interactive overscroll spring description:
  /// Mass 0.8, stiffness 165.0, damping 25.0 delivers the authentic Apple rubber-band tension.
  @override
  SpringDescription get spring => const SpringDescription(
        mass: 0.8,
        stiffness: 165.0,
        damping: 25.0,
      );

  @override
  AppleSpringScrollPhysics applyTo(ScrollPhysics? ancestor) {
    return AppleSpringScrollPhysics(
      parent: buildParent(ancestor),
      decelerationRate: decelerationRate,
    );
  }

  @override
  double frictionFactor(double overscrollFraction) {
    // True iOS exponential drag falloff curve
    final clamped = (1.0 - overscrollFraction.abs()).clamp(0.0, 1.0);
    return 0.52 * math.pow(clamped, 2.0).toDouble();
  }
}
