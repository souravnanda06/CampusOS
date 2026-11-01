import 'package:flutter/material.dart';

enum CampusOSLogoVariant {
  primary,
  accent,
  monochrome,
  reversed,
  mark,
}

class CampusOSLogo extends StatelessWidget {
  final CampusOSLogoVariant variant;
  final double? width;
  final double? height;
  final BoxFit fit;
  final AlignmentGeometry alignment;
  final String? semanticLabel;

  const CampusOSLogo({
    Key? key,
    this.variant = CampusOSLogoVariant.primary,
    this.width,
    this.height,
    this.fit = BoxFit.contain,
    this.alignment = Alignment.center,
    this.semanticLabel,
  }) : super(key: key);

  String get _assetPath {
    switch (variant) {
      case CampusOSLogoVariant.primary:
        return 'assets/branding/campusos-wordmark-primary.png';
      case CampusOSLogoVariant.accent:
        return 'assets/branding/campusos-wordmark-accent.png';
      case CampusOSLogoVariant.monochrome:
        return 'assets/branding/campusos-wordmark-monochrome.png';
      case CampusOSLogoVariant.reversed:
        return 'assets/branding/campusos-wordmark-reversed.png';
      case CampusOSLogoVariant.mark:
        return 'assets/branding/campusos-mark.png';
    }
  }

  String get _defaultSemanticLabel {
    switch (variant) {
      case CampusOSLogoVariant.mark:
        return 'CampusOS App Mark';
      default:
        return 'CampusOS Logo';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      _assetPath,
      width: width,
      height: height,
      fit: fit,
      alignment: alignment,
      semanticLabel: semanticLabel ?? _defaultSemanticLabel,
      filterQuality: FilterQuality.medium,
    );
  }
}
