import 'package:flutter/foundation.dart';

import 'device_capabilities.dart';
import 'rendering/rendering_config.dart';
import 'motion/motion_config.dart';
import 'memory/memory_policy.dart';
import 'network/network_policy.dart';
import 'scanner/scanner_config.dart';

/// Background task and lifecycle execution policy.
@immutable
class BackgroundWorkPolicy {
  final bool pauseInactiveTickers;
  final Duration inactivityTimeout;
  final Duration bleScanThrottleInterval;

  const BackgroundWorkPolicy({
    this.pauseInactiveTickers = true,
    this.inactivityTimeout = const Duration(minutes: 3),
    this.bleScanThrottleInterval = const Duration(milliseconds: 800),
  });

  factory BackgroundWorkPolicy.highEnd() {
    return const BackgroundWorkPolicy(
      pauseInactiveTickers: false,
      inactivityTimeout: Duration(minutes: 8),
      bleScanThrottleInterval: Duration(milliseconds: 400),
    );
  }

  factory BackgroundWorkPolicy.balanced() {
    return const BackgroundWorkPolicy(
      pauseInactiveTickers: true,
      inactivityTimeout: Duration(minutes: 4),
      bleScanThrottleInterval: Duration(milliseconds: 800),
    );
  }

  factory BackgroundWorkPolicy.constrained() {
    return const BackgroundWorkPolicy(
      pauseInactiveTickers: true,
      inactivityTimeout: Duration(minutes: 1),
      bleScanThrottleInterval: Duration(milliseconds: 1400),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'pauseInactiveTickers': pauseInactiveTickers,
      'inactivityTimeoutSec': inactivityTimeout.inSeconds,
      'bleScanThrottleIntervalMs': bleScanThrottleInterval.inMilliseconds,
    };
  }

  factory BackgroundWorkPolicy.fromMap(Map<String, dynamic> map) {
    return BackgroundWorkPolicy(
      pauseInactiveTickers: map['pauseInactiveTickers'] as bool? ?? true,
      inactivityTimeout: Duration(
        seconds: (map['inactivityTimeoutSec'] as num?)?.toInt() ?? 180,
      ),
      bleScanThrottleInterval: Duration(
        milliseconds:
            (map['bleScanThrottleIntervalMs'] as num?)?.toInt() ?? 800,
      ),
    );
  }
}

/// Comprehensive, immutable multi-dimensional performance profile.
///
/// Decouples rendering, motion, memory, network, scanner, and background policies
/// into independent dimensions rather than a single monolithic low/medium/high flag.
@immutable
class PerformanceProfile {
  final DeviceClass deviceClass;
  final PerformanceTier performanceTier;
  final double refreshRate;
  final RenderingConfig renderingProfile;
  final MotionConfig animationProfile;
  final MemoryPolicy memoryProfile;
  final NetworkOptimizationPolicy networkProfile;
  final ScannerConfig scannerProfile;
  final ThermalState thermalProfile;
  final BackgroundWorkPolicy backgroundWorkProfile;
  final UserOverrideMode userOverrideMode;
  final DateTime lastOptimized;

  const PerformanceProfile({
    required this.deviceClass,
    required this.performanceTier,
    required this.refreshRate,
    required this.renderingProfile,
    required this.animationProfile,
    required this.memoryProfile,
    required this.networkProfile,
    required this.scannerProfile,
    required this.thermalProfile,
    required this.backgroundWorkProfile,
    required this.userOverrideMode,
    required this.lastOptimized,
  });

  /// Human-friendly display label (e.g. "Balanced+", "Ultra Performance").
  String get displayTierLabel {
    if (userOverrideMode == UserOverrideMode.performancePriority) {
      return 'Max Performance';
    }
    if (userOverrideMode == UserOverrideMode.visualQualityPriority) {
      return 'High Fidelity';
    }

    switch (performanceTier) {
      case PerformanceTier.constrained:
        return 'Battery & Performance Saver';
      case PerformanceTier.standard:
        return 'Balanced';
      case PerformanceTier.highPerformance:
        return 'Performance';
      case PerformanceTier.ultra:
        return 'Ultra High-End';
    }
  }

  PerformanceProfile copyWith({
    DeviceClass? deviceClass,
    PerformanceTier? performanceTier,
    double? refreshRate,
    RenderingConfig? renderingProfile,
    MotionConfig? animationProfile,
    MemoryPolicy? memoryProfile,
    NetworkOptimizationPolicy? networkProfile,
    ScannerConfig? scannerProfile,
    ThermalState? thermalProfile,
    BackgroundWorkPolicy? backgroundWorkProfile,
    UserOverrideMode? userOverrideMode,
    DateTime? lastOptimized,
  }) {
    return PerformanceProfile(
      deviceClass: deviceClass ?? this.deviceClass,
      performanceTier: performanceTier ?? this.performanceTier,
      refreshRate: refreshRate ?? this.refreshRate,
      renderingProfile: renderingProfile ?? this.renderingProfile,
      animationProfile: animationProfile ?? this.animationProfile,
      memoryProfile: memoryProfile ?? this.memoryProfile,
      networkProfile: networkProfile ?? this.networkProfile,
      scannerProfile: scannerProfile ?? this.scannerProfile,
      thermalProfile: thermalProfile ?? this.thermalProfile,
      backgroundWorkProfile:
          backgroundWorkProfile ?? this.backgroundWorkProfile,
      userOverrideMode: userOverrideMode ?? this.userOverrideMode,
      lastOptimized: lastOptimized ?? this.lastOptimized,
    );
  }
}
