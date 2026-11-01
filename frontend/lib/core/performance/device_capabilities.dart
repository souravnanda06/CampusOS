import 'package:flutter/foundation.dart';

/// Represents broad hardware classifications derived from device capabilities.
enum DeviceClass {
  entry,
  balanced,
  performance,
  highEnd,
}

/// Represents the overall performance tier for baseline policies.
enum PerformanceTier {
  constrained,
  standard,
  highPerformance,
  ultra,
}

/// Thermal state of the device.
enum ThermalState {
  normal,
  warm,
  hot,
  critical,
}

/// Network connectivity and quality state.
enum NetworkQuality {
  offline,
  unstable,
  standard,
  highSpeed,
}

/// User override preference for the performance engine.
enum UserOverrideMode {
  automatic,
  performancePriority,
  visualQualityPriority,
}

/// Immutable representation of the physical device's detected capabilities.
@immutable
class DeviceCapabilities {
  final String manufacturer;
  final String model;
  final String hardware;
  final int sdkVersion;
  final String architecture;
  final int cpuCoreCount;
  final int estimatedRamMb;
  final double displayRefreshRate;
  final double devicePixelRatio;
  final double logicalWidth;
  final double logicalHeight;
  final bool hasBiometrics;
  final bool hasBle;
  final bool isLowRamDevice;

  const DeviceCapabilities({
    this.manufacturer = 'Unknown',
    this.model = 'Generic Device',
    this.hardware = 'unknown',
    this.sdkVersion = 30,
    this.architecture = 'arm64',
    this.cpuCoreCount = 4,
    this.estimatedRamMb = 4096,
    this.displayRefreshRate = 60.0,
    this.devicePixelRatio = 2.0,
    this.logicalWidth = 390.0,
    this.logicalHeight = 844.0,
    this.hasBiometrics = true,
    this.hasBle = true,
    this.isLowRamDevice = false,
  });

  /// Factory for a simulated matrix entry (used in deterministic testing).
  factory DeviceCapabilities.simulated({
    required DeviceClass deviceClass,
    double? refreshRate,
    int? ramMb,
  }) {
    switch (deviceClass) {
      case DeviceClass.entry:
        return DeviceCapabilities(
          manufacturer: 'Simulated Entry',
          model: 'Budget Phone A1',
          hardware: 'entry_soc',
          sdkVersion: 31,
          architecture: 'arm64',
          cpuCoreCount: 4,
          estimatedRamMb: ramMb ?? 3072,
          displayRefreshRate: refreshRate ?? 60.0,
          devicePixelRatio: 2.0,
          logicalWidth: 360.0,
          logicalHeight: 800.0,
          hasBiometrics: false,
          hasBle: true,
          isLowRamDevice: true,
        );
      case DeviceClass.balanced:
        return DeviceCapabilities(
          manufacturer: 'Samsung',
          model: 'Galaxy A55 (SM-A556E)',
          hardware: 's5e8845',
          sdkVersion: 36,
          architecture: 'arm64',
          cpuCoreCount: 8,
          estimatedRamMb: ramMb ?? 8192,
          displayRefreshRate: refreshRate ?? 120.0,
          devicePixelRatio: 2.8125,
          logicalWidth: 384.0,
          logicalHeight: 832.0,
          hasBiometrics: true,
          hasBle: true,
          isLowRamDevice: false,
        );
      case DeviceClass.performance:
        return DeviceCapabilities(
          manufacturer: 'Google',
          model: 'Pixel 9 Pro',
          hardware: 'tensor_g4',
          sdkVersion: 36,
          architecture: 'arm64',
          cpuCoreCount: 8,
          estimatedRamMb: ramMb ?? 12288,
          displayRefreshRate: refreshRate ?? 120.0,
          devicePixelRatio: 3.0,
          logicalWidth: 412.0,
          logicalHeight: 915.0,
          hasBiometrics: true,
          hasBle: true,
          isLowRamDevice: false,
        );
      case DeviceClass.highEnd:
        return DeviceCapabilities(
          manufacturer: 'Samsung',
          model: 'Galaxy S25 Ultra',
          hardware: 'snapdragon_8_elite',
          sdkVersion: 36,
          architecture: 'arm64',
          cpuCoreCount: 8,
          estimatedRamMb: ramMb ?? 16384,
          displayRefreshRate: refreshRate ?? 120.0,
          devicePixelRatio: 3.5,
          logicalWidth: 412.0,
          logicalHeight: 915.0,
          hasBiometrics: true,
          hasBle: true,
          isLowRamDevice: false,
        );
    }
  }

  Map<String, dynamic> toMap() {
    return {
      'manufacturer': manufacturer,
      'model': model,
      'hardware': hardware,
      'sdkVersion': sdkVersion,
      'architecture': architecture,
      'cpuCoreCount': cpuCoreCount,
      'estimatedRamMb': estimatedRamMb,
      'displayRefreshRate': displayRefreshRate,
      'devicePixelRatio': devicePixelRatio,
      'logicalWidth': logicalWidth,
      'logicalHeight': logicalHeight,
      'hasBiometrics': hasBiometrics,
      'hasBle': hasBle,
      'isLowRamDevice': isLowRamDevice,
    };
  }

  factory DeviceCapabilities.fromMap(Map<String, dynamic> map) {
    return DeviceCapabilities(
      manufacturer: map['manufacturer'] as String? ?? 'Unknown',
      model: map['model'] as String? ?? 'Generic Device',
      hardware: map['hardware'] as String? ?? 'unknown',
      sdkVersion: (map['sdkVersion'] as num?)?.toInt() ?? 30,
      architecture: map['architecture'] as String? ?? 'arm64',
      cpuCoreCount: (map['cpuCoreCount'] as num?)?.toInt() ?? 4,
      estimatedRamMb: (map['estimatedRamMb'] as num?)?.toInt() ?? 4096,
      displayRefreshRate: (map['displayRefreshRate'] as num?)?.toDouble() ?? 60.0,
      devicePixelRatio: (map['devicePixelRatio'] as num?)?.toDouble() ?? 2.0,
      logicalWidth: (map['logicalWidth'] as num?)?.toDouble() ?? 390.0,
      logicalHeight: (map['logicalHeight'] as num?)?.toDouble() ?? 844.0,
      hasBiometrics: map['hasBiometrics'] as bool? ?? true,
      hasBle: map['hasBle'] as bool? ?? true,
      isLowRamDevice: map['isLowRamDevice'] as bool? ?? false,
    );
  }

  @override
  String toString() =>
      'DeviceCapabilities($manufacturer $model, ${estimatedRamMb}MB RAM, ${displayRefreshRate.toStringAsFixed(0)}Hz)';
}
