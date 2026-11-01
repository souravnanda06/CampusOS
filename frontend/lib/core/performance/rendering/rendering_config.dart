import 'package:flutter/foundation.dart';

/// Strategy for rendering glassmorphism and background blurs.
enum BlurStrategy {
  /// Full Gaussian kernel sampling (BackdropFilter with sigma 16.0).
  gaussian,

  /// Reduced blur radius (BackdropFilter with sigma 10.0) saving ~40% fragment cost.
  localized,

  /// Translucent frosted surface with borders and subtle elevation, eliminating
  /// all runtime GPU Gaussian framebuffer passes.
  tintedApproximation,
}

/// Shadow rendering complexity.
enum ShadowComplexity {
  /// Multi-layered ambient + key shadows.
  full,

  /// Single soft elevation shadow.
  simplified,

  /// Border-only or flat elevation for constrained GPUs.
  minimal,
}

/// Dynamic decorative background animation mode (e.g. login, onboarding).
enum BackgroundAnimationMode {
  /// Dynamic floating orbs with parallax and sine wave CustomPainter.
  activeOrbsAndWaves,

  /// Floating orbs with waves paused.
  gentleOrbs,

  /// Static radial gradient, zero ticker cost, zero per-frame repaints.
  staticGradient,
}

/// Level of detail for geometric mesh rendering in Identity Mesh / Wallet.
enum IdentityMeshDetail {
  /// High density polygon lattice.
  full,

  /// Optimized polygon lattice with identical visual gradient silhouette.
  optimized,
}

/// Rendering configuration derived from device capability and runtime telemetry.
@immutable
class RenderingConfig {
  final BlurStrategy blurStrategy;
  final double blurSigma;
  final ShadowComplexity shadowComplexity;
  final BackgroundAnimationMode backgroundAnimationMode;
  final IdentityMeshDetail identityMeshDetail;
  final bool enableShimmerDecorations;

  const RenderingConfig({
    this.blurStrategy = BlurStrategy.gaussian,
    this.blurSigma = 16.0,
    this.shadowComplexity = ShadowComplexity.full,
    this.backgroundAnimationMode = BackgroundAnimationMode.activeOrbsAndWaves,
    this.identityMeshDetail = IdentityMeshDetail.full,
    this.enableShimmerDecorations = true,
  });

  /// Factory for high-end / flagship profile.
  factory RenderingConfig.highEnd() {
    return const RenderingConfig(
      blurStrategy: BlurStrategy.gaussian,
      blurSigma: 16.0,
      shadowComplexity: ShadowComplexity.full,
      backgroundAnimationMode: BackgroundAnimationMode.activeOrbsAndWaves,
      identityMeshDetail: IdentityMeshDetail.full,
      enableShimmerDecorations: true,
    );
  }

  /// Factory for balanced profile (e.g. Samsung Galaxy A55).
  factory RenderingConfig.balanced() {
    return const RenderingConfig(
      blurStrategy: BlurStrategy.gaussian,
      blurSigma: 16.0,
      shadowComplexity: ShadowComplexity.simplified,
      backgroundAnimationMode: BackgroundAnimationMode.gentleOrbs,
      identityMeshDetail: IdentityMeshDetail.optimized,
      enableShimmerDecorations: true,
    );
  }

  /// Factory for constrained / low-end / high thermal pressure profile.
  factory RenderingConfig.constrained() {
    return const RenderingConfig(
      blurStrategy: BlurStrategy.tintedApproximation,
      blurSigma: 0.0,
      shadowComplexity: ShadowComplexity.minimal,
      backgroundAnimationMode: BackgroundAnimationMode.staticGradient,
      identityMeshDetail: IdentityMeshDetail.optimized,
      enableShimmerDecorations: false,
    );
  }

  RenderingConfig copyWith({
    BlurStrategy? blurStrategy,
    double? blurSigma,
    ShadowComplexity? shadowComplexity,
    BackgroundAnimationMode? backgroundAnimationMode,
    IdentityMeshDetail? identityMeshDetail,
    bool? enableShimmerDecorations,
  }) {
    return RenderingConfig(
      blurStrategy: blurStrategy ?? this.blurStrategy,
      blurSigma: blurSigma ?? this.blurSigma,
      shadowComplexity: shadowComplexity ?? this.shadowComplexity,
      backgroundAnimationMode:
          backgroundAnimationMode ?? this.backgroundAnimationMode,
      identityMeshDetail: identityMeshDetail ?? this.identityMeshDetail,
      enableShimmerDecorations:
          enableShimmerDecorations ?? this.enableShimmerDecorations,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'blurStrategy': blurStrategy.name,
      'blurSigma': blurSigma,
      'shadowComplexity': shadowComplexity.name,
      'backgroundAnimationMode': backgroundAnimationMode.name,
      'identityMeshDetail': identityMeshDetail.name,
      'enableShimmerDecorations': enableShimmerDecorations,
    };
  }

  factory RenderingConfig.fromMap(Map<String, dynamic> map) {
    return RenderingConfig(
      blurStrategy: BlurStrategy.values.firstWhere(
        (e) => e.name == map['blurStrategy'],
        orElse: () => BlurStrategy.gaussian,
      ),
      blurSigma: (map['blurSigma'] as num?)?.toDouble() ?? 16.0,
      shadowComplexity: ShadowComplexity.values.firstWhere(
        (e) => e.name == map['shadowComplexity'],
        orElse: () => ShadowComplexity.full,
      ),
      backgroundAnimationMode: BackgroundAnimationMode.values.firstWhere(
        (e) => e.name == map['backgroundAnimationMode'],
        orElse: () => BackgroundAnimationMode.activeOrbsAndWaves,
      ),
      identityMeshDetail: IdentityMeshDetail.values.firstWhere(
        (e) => e.name == map['identityMeshDetail'],
        orElse: () => IdentityMeshDetail.full,
      ),
      enableShimmerDecorations: map['enableShimmerDecorations'] as bool? ?? true,
    );
  }
}
