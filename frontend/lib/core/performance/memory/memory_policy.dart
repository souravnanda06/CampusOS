import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

/// Memory management and caching policy derived from device capability and memory pressure.
@immutable
class MemoryPolicy {
  final int maxImageCacheSizeBytes;
  final int maxImageCacheCount;
  final double listCacheExtent;
  final bool enableAggressiveImageEviction;

  const MemoryPolicy({
    this.maxImageCacheSizeBytes = 50 * 1024 * 1024, // 50 MB
    this.maxImageCacheCount = 100,
    this.listCacheExtent = 350.0,
    this.enableAggressiveImageEviction = false,
  });

  /// Ultra / High-End policy for 12GB+ RAM devices.
  factory MemoryPolicy.highEnd() {
    return const MemoryPolicy(
      maxImageCacheSizeBytes: 120 * 1024 * 1024, // 120 MB
      maxImageCacheCount: 250,
      listCacheExtent: 600.0,
      enableAggressiveImageEviction: false,
    );
  }

  /// Standard Balanced policy for 6-8GB RAM devices.
  factory MemoryPolicy.balanced() {
    return const MemoryPolicy(
      maxImageCacheSizeBytes: 60 * 1024 * 1024, // 60 MB
      maxImageCacheCount: 120,
      listCacheExtent: 350.0,
      enableAggressiveImageEviction: false,
    );
  }

  /// Constrained policy for entry-tier / low-memory / thermal pressure.
  factory MemoryPolicy.constrained() {
    return const MemoryPolicy(
      maxImageCacheSizeBytes: 24 * 1024 * 1024, // 24 MB
      maxImageCacheCount: 40,
      listCacheExtent: 150.0,
      enableAggressiveImageEviction: true,
    );
  }

  /// Applies the memory configuration to Flutter's global [PaintingBinding.instance.imageCache].
  void applyToPaintingBinding() {
    try {
      final cache = PaintingBinding.instance.imageCache;
      cache.maximumSizeBytes = maxImageCacheSizeBytes;
      cache.maximumSize = maxImageCacheCount;
      if (enableAggressiveImageEviction) {
        cache.clearLiveImages();
      }
    } catch (e) {
      debugPrint('⚠️ [MemoryPolicy] Could not apply cache limits to PaintingBinding: $e');
    }
  }

  Map<String, dynamic> toMap() {
    return {
      'maxImageCacheSizeBytes': maxImageCacheSizeBytes,
      'maxImageCacheCount': maxImageCacheCount,
      'listCacheExtent': listCacheExtent,
      'enableAggressiveImageEviction': enableAggressiveImageEviction,
    };
  }

  factory MemoryPolicy.fromMap(Map<String, dynamic> map) {
    return MemoryPolicy(
      maxImageCacheSizeBytes:
          (map['maxImageCacheSizeBytes'] as num?)?.toInt() ?? 50 * 1024 * 1024,
      maxImageCacheCount: (map['maxImageCacheCount'] as num?)?.toInt() ?? 100,
      listCacheExtent:
          (map['listCacheExtent'] as num?)?.toDouble() ?? 350.0,
      enableAggressiveImageEviction:
          map['enableAggressiveImageEviction'] as bool? ?? false,
    );
  }
}
