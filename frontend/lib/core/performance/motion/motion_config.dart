import 'package:flutter/material.dart';

/// Refresh-rate and accessibility-aware motion timing configuration.
@immutable
class MotionConfig {
  final double displayRefreshRate;
  final bool reducedMotion;
  final bool enableSpringPhysics;

  const MotionConfig({
    this.displayRefreshRate = 60.0,
    this.reducedMotion = false,
    this.enableSpringPhysics = true,
  });

  /// Approximate frame budget in milliseconds based on refresh rate.
  double get frameBudgetMs =>
      displayRefreshRate > 0 ? (1000.0 / displayRefreshRate) : 16.67;

  /// Fast interaction duration (e.g. button presses, chip selection).
  Duration get fast {
    if (reducedMotion) return Duration.zero;
    if (displayRefreshRate >= 110) return const Duration(milliseconds: 140);
    if (displayRefreshRate >= 85) return const Duration(milliseconds: 160);
    return const Duration(milliseconds: 180);
  }

  /// Standard interaction duration (e.g. card expansion, dock switching).
  Duration get standard {
    if (reducedMotion) return Duration.zero;
    if (displayRefreshRate >= 110) return const Duration(milliseconds: 220);
    if (displayRefreshRate >= 85) return const Duration(milliseconds: 250);
    return const Duration(milliseconds: 280);
  }

  /// Deliberate transition duration (e.g. modal sheets, page slides).
  Duration get deliberate {
    if (reducedMotion) return Duration.zero;
    if (displayRefreshRate >= 110) return const Duration(milliseconds: 320);
    if (displayRefreshRate >= 85) return const Duration(milliseconds: 350);
    return const Duration(milliseconds: 400);
  }

  Curve get standardCurve =>
      reducedMotion ? Curves.linear : Curves.easeOutCubic;

  Curve get springCurve => (reducedMotion || !enableSpringPhysics)
      ? Curves.easeOutCubic
      : Curves.easeOutBack;

  Curve get enterCurve =>
      reducedMotion ? Curves.linear : Curves.easeOutQuart;

  Curve get exitCurve =>
      reducedMotion ? Curves.linear : Curves.easeInCubic;

  MotionConfig copyWith({
    double? displayRefreshRate,
    bool? reducedMotion,
    bool? enableSpringPhysics,
  }) {
    return MotionConfig(
      displayRefreshRate: displayRefreshRate ?? this.displayRefreshRate,
      reducedMotion: reducedMotion ?? this.reducedMotion,
      enableSpringPhysics: enableSpringPhysics ?? this.enableSpringPhysics,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'displayRefreshRate': displayRefreshRate,
      'reducedMotion': reducedMotion,
      'enableSpringPhysics': enableSpringPhysics,
    };
  }

  factory MotionConfig.fromMap(Map<String, dynamic> map) {
    return MotionConfig(
      displayRefreshRate:
          (map['displayRefreshRate'] as num?)?.toDouble() ?? 60.0,
      reducedMotion: map['reducedMotion'] as bool? ?? false,
      enableSpringPhysics: map['enableSpringPhysics'] as bool? ?? true,
    );
  }
}
