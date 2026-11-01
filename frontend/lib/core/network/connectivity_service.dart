import 'dart:async';
import 'dart:io';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/widgets.dart';
import 'package:http/http.dart' as http;

import '../config/app_config.dart';
import 'connectivity_state.dart';

/// CampusOS Core Connectivity & Backend Reachability Service.
///
/// Responsibilities:
/// 1. Monitors physical network interfaces (Wi-Fi, Cellular, Ethernet) via `connectivity_plus`.
/// 2. Performs lightweight, non-blocking HTTP reachability probes against the `/health` endpoint.
/// 3. Distinguishes interface availability from true backend reachability.
/// 4. Manages lifecycle events (app startup, background/resume, interface loss, restoration).
/// 5. Strictly avoids aggressive polling: probes only on state transitions, app resume, or explicit request.
/// 6. Fully observable via `ChangeNotifier` and reactive `Stream`.
class ConnectivityService extends ChangeNotifier with WidgetsBindingObserver {
  static ConnectivityService? _instance;

  final Connectivity _connectivity;
  final http.Client _httpClient;
  final String _baseUrl;
  final Duration _probeTimeout;

  final Duration _minProbeInterval;

  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  final StreamController<NetworkStatus> _statusController =
      StreamController<NetworkStatus>.broadcast();

  NetworkStatus _currentStatus = NetworkStatus.unknown();
  DateTime? _lastProbeTime;
  bool _isProbing = false;

  ConnectivityService({
    Connectivity? connectivity,
    http.Client? httpClient,
    String? baseUrl,
    Duration? probeTimeout,
    Duration? minProbeInterval,
  })  : _connectivity = connectivity ?? Connectivity(),
        _httpClient = httpClient ?? http.Client(),
        _baseUrl = baseUrl ?? AppConfig.baseUrl,
        _probeTimeout = probeTimeout ?? const Duration(seconds: 3),
        _minProbeInterval = minProbeInterval ?? const Duration(seconds: 2);

  /// Global shared instance.
  static ConnectivityService get instance {
    if (_instance == null) {
      _instance = ConnectivityService();
      _instance!.init();
    }
    return _instance!;
  }

  /// Explicit initializer with optional custom/mock dependencies.
  static ConnectivityService initialize({
    Connectivity? connectivity,
    http.Client? httpClient,
    String? baseUrl,
    Duration? probeTimeout,
    Duration? minProbeInterval,
  }) {
    _instance?.dispose();
    _instance = ConnectivityService(
      connectivity: connectivity,
      httpClient: httpClient,
      baseUrl: baseUrl,
      probeTimeout: probeTimeout,
      minProbeInterval: minProbeInterval,
    );
    _instance!.init();
    return _instance!;
  }

  /// Testing factory for isolated unit tests with mock interfaces.
  factory ConnectivityService.forTesting({
    required Connectivity connectivity,
    required http.Client httpClient,
    String? baseUrl,
    Duration? probeTimeout,
    Duration? minProbeInterval,
  }) {
    return ConnectivityService(
      connectivity: connectivity,
      httpClient: httpClient,
      baseUrl: baseUrl ?? AppConfig.baseUrl,
      probeTimeout: probeTimeout ?? const Duration(milliseconds: 500),
      minProbeInterval: minProbeInterval ?? Duration.zero,
    );
  }

  /// Current network status snapshot.
  NetworkStatus get status => _currentStatus;

  /// Current connectivity state enum.
  ConnectivityState get state => _currentStatus.state;

  /// True only when the backend is actively verified as reachable.
  bool get isOnline => _currentStatus.isOnline;

  /// True if a local network interface (Wi-Fi, Cellular, Ethernet) is present and active.
  bool get hasNetworkInterface => _currentStatus.hasNetworkInterface;

  /// True if the device has an active network connection (online or local sync mode).
  bool get isDeviceOnline =>
      _currentStatus.hasNetworkInterface || _currentStatus.isOnline;

  /// True when offline or backend unreachable.
  bool get isOffline => _currentStatus.isOffline;

  /// Stream of status transitions for reactive listeners.
  Stream<NetworkStatus> get onStatusChanged => _statusController.stream;

  /// Start monitoring connectivity and lifecycle.
  void init() {
    try {
      WidgetsBinding.instance.addObserver(this);
    } catch (_) {
      // In pure unit test environments without a Flutter widget binding
    }

    _connectivitySubscription =
        _connectivity.onConnectivityChanged.listen(_handleInterfaceChange);

    // Initial check on startup
    checkReachability();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Re-verify reachability when app returns to foreground
      checkReachability(force: true);
    }
  }

  /// Handles network interface transitions from connectivity_plus.
  void _handleInterfaceChange(List<ConnectivityResult> results) {
    final hasInterface = results.isNotEmpty &&
        results.any((r) => r != ConnectivityResult.none);

    if (!hasInterface) {
      _updateStatus(NetworkStatus.offline(interfaces: results));
    } else {
      // Interface appeared (e.g. Wi-Fi reconnected). Probe backend reachability.
      checkReachability(forcedInterfaces: results, force: true);
    }
  }

  /// Probes actual backend reachability via `/health` endpoint.
  Future<NetworkStatus> checkReachability({
    List<ConnectivityResult>? forcedInterfaces,
    bool force = false,
  }) async {
    // Avoid concurrent overlapping probes
    if (_isProbing) return _currentStatus;

    // Throttle checks unless forced
    final now = DateTime.now();
    if (!force &&
        _lastProbeTime != null &&
        now.difference(_lastProbeTime!) < _minProbeInterval) {
      return _currentStatus;
    }

    _isProbing = true;
    _lastProbeTime = now;

    try {
      // 1. Inspect physical interface availability
      final interfaces = forcedInterfaces ?? await _connectivity.checkConnectivity();
      final hasInterface = interfaces.isNotEmpty &&
          interfaces.any((r) => r != ConnectivityResult.none);

      if (!hasInterface) {
        final newStatus = NetworkStatus.offline(interfaces: interfaces);
        _updateStatus(newStatus);
        return newStatus;
      }

      // Mark as network available while probe is in flight
      if (_currentStatus.state == ConnectivityState.offline ||
          _currentStatus.state == ConnectivityState.unknown) {
        _updateStatus(NetworkStatus.networkAvailable(interfaces: interfaces));
      }

      // 2. Perform lightweight reachability probe against backend
      final cleanBase = _baseUrl.endsWith('/')
          ? _baseUrl.substring(0, _baseUrl.length - 1)
          : _baseUrl;
      final uri = Uri.parse('$cleanBase/health');

      final stopwatch = Stopwatch()..start();
      http.Response? response;

      try {
        response = await _httpClient.get(uri).timeout(_probeTimeout);
      } catch (e) {
        // If /health network probe failed, attempt unauthenticated public-key fallback
        try {
          final fallbackUri =
              Uri.parse('$cleanBase/passport/institution/public-key');
          final fallbackResponse =
              await _httpClient.get(fallbackUri).timeout(_probeTimeout);
          if (fallbackResponse.statusCode >= 200 &&
              fallbackResponse.statusCode < 400) {
            response = fallbackResponse;
          }
        } catch (_) {
          rethrow;
        }
      }

      // If /health returns 404 or other non-2xx status (e.g. WSGI route unmapped),
      // fallback to probing /passport/institution/public-key which is unauthenticated and always active.
      if (response != null &&
          (response.statusCode < 200 || response.statusCode >= 400)) {
        try {
          final fallbackUri =
              Uri.parse('$cleanBase/passport/institution/public-key');
          final fallbackResponse =
              await _httpClient.get(fallbackUri).timeout(_probeTimeout);
          if (fallbackResponse.statusCode >= 200 &&
              fallbackResponse.statusCode < 400) {
            response = fallbackResponse;
          }
        } catch (_) {
          // Keep original response for error reporting
        }
      }
      stopwatch.stop();

      if (response != null &&
          response.statusCode >= 200 &&
          response.statusCode < 400) {
        final newStatus = NetworkStatus.backendReachable(
          interfaces: interfaces,
          latency: stopwatch.elapsed,
        );
        _updateStatus(newStatus);
        return newStatus;
      } else {
        final newStatus = NetworkStatus.backendUnreachable(
          interfaces: interfaces,
          reason: response != null
              ? 'Backend returned HTTP ${response.statusCode}'
              : 'Backend unreachable across health probes',
        );
        _updateStatus(newStatus);
        return newStatus;
      }
    } on TimeoutException {
      final interfaces = forcedInterfaces ?? [];
      final newStatus = NetworkStatus.backendUnreachable(
        interfaces: interfaces,
        reason: 'Backend probe timed out after ${_probeTimeout.inSeconds}s',
      );
      _updateStatus(newStatus);
      return newStatus;
    } on SocketException catch (e) {
      final interfaces = forcedInterfaces ?? [];
      final newStatus = NetworkStatus.backendUnreachable(
        interfaces: interfaces,
        reason: 'SocketException: ${e.message}',
      );
      _updateStatus(newStatus);
      return newStatus;
    } catch (e) {
      final interfaces = forcedInterfaces ?? [];
      final newStatus = NetworkStatus.backendUnreachable(
        interfaces: interfaces,
        reason: 'Network error: $e',
      );
      _updateStatus(newStatus);
      return newStatus;
    } finally {
      _isProbing = false;
    }
  }

  void _updateStatus(NetworkStatus newStatus) {
    if (_currentStatus.state != newStatus.state ||
        _currentStatus.activeInterfaces != newStatus.activeInterfaces) {
      _currentStatus = newStatus;
      _statusController.add(newStatus);
      notifyListeners();
    } else {
      _currentStatus = newStatus;
    }
  }

  @override
  void dispose() {
    try {
      WidgetsBinding.instance.removeObserver(this);
    } catch (_) {}
    _connectivitySubscription?.cancel();
    _statusController.close();
    super.dispose();
  }

  @visibleForTesting
  static void reset() {
    _instance?.dispose();
    _instance = null;
  }
}
