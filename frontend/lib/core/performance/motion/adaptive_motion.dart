import 'package:flutter/material.dart';

import 'motion_config.dart';

/// Motion utility providing adaptive page transitions and interactive micro-animations.
class AdaptiveMotion {
  AdaptiveMotion._();

  /// Creates a fade + subtle slide page route transition tuned to [MotionConfig].
  static PageRouteBuilder<T> createAdaptiveRoute<T>({
    required Widget page,
    required RouteSettings settings,
    MotionConfig motionConfig = const MotionConfig(),
  }) {
    if (motionConfig.reducedMotion) {
      return PageRouteBuilder<T>(
        settings: settings,
        pageBuilder: (context, _, __) => page,
        transitionDuration: Duration.zero,
        reverseTransitionDuration: Duration.zero,
      );
    }

    return PageRouteBuilder<T>(
      settings: settings,
      transitionDuration: motionConfig.standard,
      reverseTransitionDuration: motionConfig.fast,
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        final fadeAnimation = CurvedAnimation(
          parent: animation,
          curve: motionConfig.standardCurve,
        );

        return FadeTransition(
          opacity: fadeAnimation,
          child: child,
        );
      },
    );
  }

  /// Wraps a widget in an adaptive scale bounce animation on press.
  static Widget buildScaleButton({
    required Widget child,
    required VoidCallback onTap,
    bool isPressed = false,
    MotionConfig motionConfig = const MotionConfig(),
  }) {
    if (motionConfig.reducedMotion) {
      return GestureDetector(
        onTap: onTap,
        child: child,
      );
    }

    return AnimatedScale(
      scale: isPressed ? 0.96 : 1.0,
      duration: motionConfig.fast,
      curve: motionConfig.springCurve,
      child: child,
    );
  }
}
