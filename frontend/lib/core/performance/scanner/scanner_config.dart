import 'package:flutter/material.dart';

/// Configuration for camera QR/barcode scanner controllers, balancing
/// optical recognition accuracy with thermal and battery performance.
@immutable
class ScannerConfig {
  /// Target resolution passed to the camera hardware subsystem.
  final Size targetResolution;

  /// Cooldown between consecutive QR code frames in continuous scanning.
  final int detectionTimeoutMs;

  /// Whether to return decoded pixel image frames to the Dart heap (kept false for zero-copy).
  final bool returnImage;

  /// Duration of idle scanner state before auto-stopping to protect battery/thermals.
  final Duration autoPauseTimeout;

  const ScannerConfig({
    this.targetResolution = const Size(1280, 720),
    this.detectionTimeoutMs = 600,
    this.returnImage = false,
    this.autoPauseTimeout = const Duration(minutes: 3),
  });

  /// High-end configuration.
  factory ScannerConfig.highEnd() {
    return const ScannerConfig(
      targetResolution: Size(1920, 1080),
      detectionTimeoutMs: 400,
      returnImage: false,
      autoPauseTimeout: Duration(minutes: 5),
    );
  }

  /// Standard balanced configuration (720p is optimal for QR matrix codes).
  factory ScannerConfig.balanced() {
    return const ScannerConfig(
      targetResolution: Size(1280, 720),
      detectionTimeoutMs: 600,
      returnImage: false,
      autoPauseTimeout: Duration(minutes: 3),
    );
  }

  /// Thermal-throttled / Constrained configuration (reducing camera ISP heat).
  factory ScannerConfig.constrained() {
    return const ScannerConfig(
      targetResolution: Size(1280, 720),
      detectionTimeoutMs: 900,
      returnImage: false,
      autoPauseTimeout: Duration(minutes: 2),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'targetResolutionWidth': targetResolution.width,
      'targetResolutionHeight': targetResolution.height,
      'detectionTimeoutMs': detectionTimeoutMs,
      'returnImage': returnImage,
      'autoPauseTimeoutSec': autoPauseTimeout.inSeconds,
    };
  }

  factory ScannerConfig.fromMap(Map<String, dynamic> map) {
    return ScannerConfig(
      targetResolution: Size(
        (map['targetResolutionWidth'] as num?)?.toDouble() ?? 1280.0,
        (map['targetResolutionHeight'] as num?)?.toDouble() ?? 720.0,
      ),
      detectionTimeoutMs:
          (map['detectionTimeoutMs'] as num?)?.toInt() ?? 600,
      returnImage: map['returnImage'] as bool? ?? false,
      autoPauseTimeout: Duration(
        seconds: (map['autoPauseTimeoutSec'] as num?)?.toInt() ?? 180,
      ),
    );
  }
}
