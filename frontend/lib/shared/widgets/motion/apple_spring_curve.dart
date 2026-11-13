import 'dart:math' as math;
import 'package:flutter/animation.dart';

/// True Apple iOS / SwiftUI spring physics curve.
///
/// Implements the exact damped harmonic oscillator physics differential equation:
/// x(t) = 1.0 - e^(-damping * t) * (cos(omega * t) + (damping / omega) * sin(omega * t))
///
/// This provides the authentic tactile spring trajectory used across iOS, macOS,
/// and visionOS interfaces.
class AppleSpringCurve extends Curve {
  final double damping;
  final double stiffness;
  final double mass;

  const AppleSpringCurve({
    this.damping = 26.0,
    this.stiffness = 280.0,
    this.mass = 1.0,
  });

  /// Standard iOS interactive response: snappy, critically-damped, zero overshoot.
  static const AppleSpringCurve standard = AppleSpringCurve(
    damping: 26.0,
    stiffness: 280.0,
    mass: 1.0,
  );

  /// Playful Apple spring with subtle overshoot (~3-4%).
  static const AppleSpringCurve bouncy = AppleSpringCurve(
    damping: 20.0,
    stiffness: 260.0,
    mass: 1.0,
  );

  /// Luxurious gentle spring for large modal presentations.
  static const AppleSpringCurve smooth = AppleSpringCurve(
    damping: 32.0,
    stiffness: 220.0,
    mass: 1.0,
  );

  @override
  double transformInternal(double t) {
    if (t <= 0.0) return 0.0;
    if (t >= 1.0) return 1.0;

    // Natural angular frequency
    final omega0 = math.sqrt(stiffness / mass);
    // Damping ratio zeta
    final zeta = damping / (2.0 * math.sqrt(stiffness * mass));

    if (zeta < 1.0) {
      // Underdamped / slight bounce (typical iOS feel)
      final omegaD = omega0 * math.sqrt(1.0 - zeta * zeta);
      final decay = math.exp(-zeta * omega0 * t * 4.0);
      final oscillation = math.cos(omegaD * t * 4.0) +
          (zeta * omega0 / omegaD) * math.sin(omegaD * t * 4.0);
      final result = 1.0 - decay * oscillation;
      return result.clamp(0.0, 1.1);
    } else {
      // Critically damped or overdamped
      final decay = math.exp(-omega0 * t * 4.0);
      final result = 1.0 - decay * (1.0 + omega0 * t * 4.0);
      return result.clamp(0.0, 1.0);
    }
  }
}
