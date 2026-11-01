import 'package:flutter/foundation.dart';
import '../device_capabilities.dart';

/// Network policy governing polling frequencies, request timeouts, batch sizing,
/// and prefetching without ever sacrificing offline queue reliability or idempotency.
@immutable
class NetworkOptimizationPolicy {
  final NetworkQuality networkQuality;
  final Duration requestTimeout;
  final Duration pollingInterval;
  final int maxBatchSyncSize;
  final bool enablePrefetching;
  final Duration retryBackoffBase;

  const NetworkOptimizationPolicy({
    this.networkQuality = NetworkQuality.standard,
    this.requestTimeout = const Duration(seconds: 15),
    this.pollingInterval = const Duration(seconds: 30),
    this.maxBatchSyncSize = 25,
    this.enablePrefetching = true,
    this.retryBackoffBase = const Duration(seconds: 2),
  });

  factory NetworkOptimizationPolicy.forQuality(NetworkQuality quality) {
    switch (quality) {
      case NetworkQuality.highSpeed:
        return const NetworkOptimizationPolicy(
          networkQuality: NetworkQuality.highSpeed,
          requestTimeout: Duration(seconds: 8),
          pollingInterval: Duration(seconds: 15),
          maxBatchSyncSize: 50,
          enablePrefetching: true,
          retryBackoffBase: Duration(seconds: 1),
        );
      case NetworkQuality.standard:
        return const NetworkOptimizationPolicy(
          networkQuality: NetworkQuality.standard,
          requestTimeout: Duration(seconds: 15),
          pollingInterval: Duration(seconds: 30),
          maxBatchSyncSize: 25,
          enablePrefetching: true,
          retryBackoffBase: Duration(seconds: 2),
        );
      case NetworkQuality.unstable:
        return const NetworkOptimizationPolicy(
          networkQuality: NetworkQuality.unstable,
          requestTimeout: Duration(seconds: 25),
          pollingInterval: Duration(seconds: 60),
          maxBatchSyncSize: 10,
          enablePrefetching: false,
          retryBackoffBase: Duration(seconds: 5),
        );
      case NetworkQuality.offline:
        return const NetworkOptimizationPolicy(
          networkQuality: NetworkQuality.offline,
          requestTimeout: Duration(seconds: 3),
          pollingInterval: Duration(days: 365), // Effectively disabled
          maxBatchSyncSize: 0,
          enablePrefetching: false,
          retryBackoffBase: Duration(seconds: 10),
        );
    }
  }

  Map<String, dynamic> toMap() {
    return {
      'networkQuality': networkQuality.name,
      'requestTimeoutMs': requestTimeout.inMilliseconds,
      'pollingIntervalMs': pollingInterval.inMilliseconds,
      'maxBatchSyncSize': maxBatchSyncSize,
      'enablePrefetching': enablePrefetching,
      'retryBackoffBaseMs': retryBackoffBase.inMilliseconds,
    };
  }

  factory NetworkOptimizationPolicy.fromMap(Map<String, dynamic> map) {
    return NetworkOptimizationPolicy(
      networkQuality: NetworkQuality.values.firstWhere(
        (e) => e.name == map['networkQuality'],
        orElse: () => NetworkQuality.standard,
      ),
      requestTimeout: Duration(
        milliseconds: (map['requestTimeoutMs'] as num?)?.toInt() ?? 15000,
      ),
      pollingInterval: Duration(
        milliseconds: (map['pollingIntervalMs'] as num?)?.toInt() ?? 30000,
      ),
      maxBatchSyncSize: (map['maxBatchSyncSize'] as num?)?.toInt() ?? 25,
      enablePrefetching: map['enablePrefetching'] as bool? ?? true,
      retryBackoffBase: Duration(
        milliseconds: (map['retryBackoffBaseMs'] as num?)?.toInt() ?? 2000,
      ),
    );
  }
}
