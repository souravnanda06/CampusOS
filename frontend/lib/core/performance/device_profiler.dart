import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:device_info_plus/device_info_plus.dart';

import 'device_capabilities.dart';

/// Centralized profiler that queries platform and display capabilities safely.
class DeviceProfiler {
  final DeviceInfoPlugin _deviceInfoPlugin;

  DeviceProfiler({DeviceInfoPlugin? deviceInfoPlugin})
      : _deviceInfoPlugin = deviceInfoPlugin ?? DeviceInfoPlugin();

  /// Collects physical or platform-reported device capabilities.
  Future<DeviceCapabilities> profileDevice({DeviceCapabilities? override}) async {
    if (override != null) {
      return override;
    }

    try {
      String manufacturer = 'Unknown';
      String model = 'Generic Device';
      String hardware = 'unknown';
      int sdkVersion = 30;
      String architecture = 'arm64';
      int cpuCoreCount = 4;
      int estimatedRamMb = 4096;
      bool isLowRamDevice = false;

      if (!kIsWeb) {
        if (Platform.isAndroid) {
          final androidInfo = await _deviceInfoPlugin.androidInfo;
          manufacturer = androidInfo.manufacturer;
          model = '${androidInfo.brand} ${androidInfo.model}'.trim();
          hardware = androidInfo.hardware;
          sdkVersion = androidInfo.version.sdkInt;
          architecture = androidInfo.supportedAbis.isNotEmpty
              ? androidInfo.supportedAbis.first
              : 'arm64';
          isLowRamDevice = androidInfo.isLowRamDevice;

          // Estimate RAM based on model/hardware heuristics if direct memory is platform-protected
          estimatedRamMb = _estimateAndroidRam(androidInfo);
          cpuCoreCount = androidInfo.supportedAbis.length > 2 ? 8 : 4;
        } else if (Platform.isIOS) {
          final iosInfo = await _deviceInfoPlugin.iosInfo;
          manufacturer = 'Apple';
          model = iosInfo.utsname.machine;
          hardware = iosInfo.model;
          sdkVersion = 17;
          architecture = 'arm64';
          estimatedRamMb = 6144;
          cpuCoreCount = 6;
        }
      }

      // Display & Viewport interrogation
      double refreshRate = 60.0;
      double devicePixelRatio = 2.0;
      double logicalWidth = 390.0;
      double logicalHeight = 844.0;

      // 1. Interrogate Android native display manager for true hardware panel modes
      if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
        try {
          const channel = MethodChannel('campusos/performance');
          final nativeCaps = await channel.invokeMapMethod<String, dynamic>('getDisplayCapabilities');
          if (nativeCaps != null) {
            final maxRate = (nativeCaps['maxRefreshRate'] as num?)?.toDouble() ?? 60.0;
            if (maxRate > refreshRate) {
              refreshRate = maxRate;
            }
          }
        } catch (e) {
          debugPrint('⚠️ [DeviceProfiler] Native refresh rate query fallback: $e');
        }
      }

      final views = WidgetsBinding.instance.platformDispatcher.views;
      if (views.isNotEmpty) {
        final view = views.first;
        devicePixelRatio = view.devicePixelRatio > 0 ? view.devicePixelRatio : 2.0;
        final physicalWidth = view.physicalSize.width;
        final physicalHeight = view.physicalSize.height;

        if (devicePixelRatio > 0 && physicalWidth > 0 && physicalHeight > 0) {
          logicalWidth = physicalWidth / devicePixelRatio;
          logicalHeight = physicalHeight / devicePixelRatio;
        }

        // Modern Flutter (>=3.13) exposes display refresh rates through Display
        final displays = WidgetsBinding.instance.platformDispatcher.displays;
        for (final display in displays) {
          if (display.refreshRate > 0) {
            final rate = display.refreshRate;
            if (rate > refreshRate) {
              refreshRate = rate;
            }
          }
        }
      }

      // Normalize fractional refresh rates (e.g. 119.88/120.1 -> 120.0, 89.9 -> 90.0, 143.9 -> 144.0)
      if ((refreshRate - 120.0).abs() <= 2.5) {
        refreshRate = 120.0;
      } else if ((refreshRate - 90.0).abs() <= 2.5) {
        refreshRate = 90.0;
      } else if ((refreshRate - 144.0).abs() <= 2.5) {
        refreshRate = 144.0;
      } else if ((refreshRate - 60.0).abs() <= 2.5) {
        refreshRate = 60.0;
      }

      return DeviceCapabilities(
        manufacturer: manufacturer,
        model: model,
        hardware: hardware,
        sdkVersion: sdkVersion,
        architecture: architecture,
        cpuCoreCount: cpuCoreCount,
        estimatedRamMb: estimatedRamMb,
        displayRefreshRate: refreshRate,
        devicePixelRatio: devicePixelRatio,
        logicalWidth: logicalWidth,
        logicalHeight: logicalHeight,
        hasBiometrics: true,
        hasBle: true,
        isLowRamDevice: isLowRamDevice,
      );
    } catch (e) {
      debugPrint('⚠️ [DeviceProfiler] Error querying platform capabilities: $e. Using safe baseline.');
      return const DeviceCapabilities();
    }
  }

  /// Classifies a device capability profile into a deterministic [DeviceClass].
  static DeviceClass classifyDevice(DeviceCapabilities caps) {
    if (caps.isLowRamDevice || caps.estimatedRamMb <= 3500) {
      return DeviceClass.entry;
    }

    if (caps.estimatedRamMb >= 12000 && caps.displayRefreshRate >= 90) {
      return DeviceClass.highEnd;
    }

    if (caps.estimatedRamMb >= 8000 && caps.displayRefreshRate >= 90) {
      return DeviceClass.performance;
    }

    // Default balanced tier (e.g. 4GB - 8GB, 60-120Hz mid-range like Galaxy A55)
    return DeviceClass.balanced;
  }

  /// Maps [DeviceClass] and capability signals to a baseline [PerformanceTier].
  static PerformanceTier determineTier(DeviceClass deviceClass, DeviceCapabilities caps) {
    switch (deviceClass) {
      case DeviceClass.entry:
        return PerformanceTier.constrained;
      case DeviceClass.balanced:
        return PerformanceTier.standard;
      case DeviceClass.performance:
        return PerformanceTier.highPerformance;
      case DeviceClass.highEnd:
        return PerformanceTier.ultra;
    }
  }

  static int _estimateAndroidRam(AndroidDeviceInfo info) {
    if (info.isLowRamDevice) return 2048;
    final modelLower = info.model.toLowerCase();
    final hardwareLower = info.hardware.toLowerCase();

    // High-end flagship identifiers
    if (modelLower.contains('ultra') ||
        modelLower.contains('pro max') ||
        hardwareLower.contains('snapdragon 8') ||
        hardwareLower.contains('tensor g4') ||
        hardwareLower.contains('dimensity 9300')) {
      return 12288;
    }

    // Modern mid-range / balanced (e.g. Samsung Galaxy A55, Nothing Phone, Pixel 7a/8a)
    if (info.version.sdkInt >= 34) {
      return 8192;
    }

    // Default safe standard for modern Android
    return 6144;
  }
}
