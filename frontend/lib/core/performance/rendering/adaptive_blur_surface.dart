import 'dart:ui';
import 'package:flutter/material.dart';

import 'rendering_config.dart';

/// An adaptive glassmorphic surface widget that automatically selects between
/// hardware Gaussian kernel blur and a high-performance frosted translucent
/// approximation based on [BlurStrategy].
///
/// Guarantees bit-level identical geometry, border radii, and internal alignment
/// across all device tiers without changing visual hierarchy.
class AdaptiveBlurSurface extends StatelessWidget {
  final Widget child;
  final BlurStrategy blurStrategy;
  final double blurSigma;
  final Color backgroundColor;
  final BorderRadius? borderRadius;
  final Border? border;
  final List<BoxShadow>? boxShadow;
  final EdgeInsetsGeometry? padding;
  final double? width;
  final double? height;

  const AdaptiveBlurSurface({
    Key? key,
    required this.child,
    this.blurStrategy = BlurStrategy.gaussian,
    this.blurSigma = 16.0,
    required this.backgroundColor,
    this.borderRadius,
    this.border,
    this.boxShadow,
    this.padding,
    this.width,
    this.height,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final effectiveSigma = blurStrategy == BlurStrategy.localized
        ? (blurSigma * 0.625).clamp(4.0, 10.0)
        : blurSigma;

    final containerDecoration = BoxDecoration(
      color: blurStrategy == BlurStrategy.tintedApproximation
          // Slight opacity increase for tinted approximation to maintain frosted legibility
          ? backgroundColor.withValues(alpha: (backgroundColor.a * 1.15).clamp(0.0, 0.96))
          : backgroundColor,
      borderRadius: borderRadius,
      border: border,
      boxShadow: boxShadow,
    );

    // If tinted approximation is active, bypass runtime GPU Gaussian sampling
    if (blurStrategy == BlurStrategy.tintedApproximation || effectiveSigma <= 0.5) {
      return RepaintBoundary(
        child: Container(
          width: width,
          height: height,
          padding: padding,
          decoration: containerDecoration,
          child: child,
        ),
      );
    }

    // Standard high-performance Gaussian blur surface with RepaintBoundary isolation
    Widget content = Container(
      width: width,
      height: height,
      padding: padding,
      decoration: containerDecoration,
      child: child,
    );

    if (borderRadius != null) {
      return RepaintBoundary(
        child: ClipRRect(
          borderRadius: borderRadius!,
          child: BackdropFilter(
            filter: ImageFilter.blur(
              sigmaX: effectiveSigma,
              sigmaY: effectiveSigma,
            ),
            child: content,
          ),
        ),
      );
    }

    return RepaintBoundary(
      child: ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(
            sigmaX: effectiveSigma,
            sigmaY: effectiveSigma,
          ),
          child: content,
        ),
      ),
    );
  }
}
