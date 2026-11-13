import 'dart:ui';
import 'package:flutter/material.dart';
import '../../theme/mesh_theme.dart';

/// Reusable Apple-grade Frosted Glass Container with high-performance RepaintBoundary.
///
/// Features:
/// - BackdropFilter with ImageFilter.blur sigma ~24
/// - Clipped with ClipRRect to prevent blur bleeding outside geometry
/// - Translucent white surface (78-88% opacity)
/// - 1px hairline border
/// - Layered soft BoxShadows
class GlassContainer extends StatelessWidget {
  final Widget child;
  final double blurSigma;
  final BorderRadius borderRadius;
  final Color backgroundColor;
  final Color? borderColor;
  final double borderWidth;
  final List<BoxShadow>? shadows;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final double? width;
  final double? height;

  const GlassContainer({
    super.key,
    required this.child,
    this.blurSigma = 24.0,
    this.borderRadius = AppRadii.cardRadius,
    this.backgroundColor = AppColors.frostedGlassWhite,
    this.borderColor = AppColors.hairlineBorder,
    this.borderWidth = 1.0,
    this.shadows = AppShadows.softCard,
    this.padding,
    this.margin,
    this.width,
    this.height,
  });

  @override
  Widget build(BuildContext context) {
    Widget content = child;
    if (padding != null) {
      content = Padding(padding: padding!, child: content);
    }

    Widget glassBody = RepaintBoundary(
      child: ClipRRect(
        borderRadius: borderRadius,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
          child: Container(
            width: width,
            height: height,
            decoration: BoxDecoration(
              color: backgroundColor,
              borderRadius: borderRadius,
              border: Border.all(
                color: borderColor ?? AppColors.hairlineBorder,
                width: borderWidth,
              ),
            ),
            child: content,
          ),
        ),
      ),
    );

    if (shadows != null && shadows!.isNotEmpty) {
      glassBody = DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: borderRadius,
          boxShadow: shadows,
        ),
        child: glassBody,
      );
    }

    if (margin != null) {
      glassBody = Padding(padding: margin!, child: glassBody);
    }

    return glassBody;
  }
}
