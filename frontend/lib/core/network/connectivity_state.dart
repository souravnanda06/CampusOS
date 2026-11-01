import 'package:connectivity_plus/connectivity_plus.dart';

/// Explicit application-level connectivity states.
///
/// Distinguishes physical network interface state from actual CampusOS backend reachability.
enum ConnectivityState {
  /// Initial unverified state before any connectivity checks have run.
  unknown,

  /// No network interface is active (e.g. Airplane mode, Wi-Fi and mobile data off).
  offline,

  /// A network interface is active, but backend reachability is unverified or currently being probed.
  networkAvailable,

  /// A network interface is active, but the CampusOS backend is unreachable
  /// (e.g. captive portal, hostel router without internet, backend server stopped, timeout).
  backendUnreachable,

  /// The CampusOS backend is reached and verified (responded with 200 OK to /health).
  backendReachable,
}

extension ConnectivityStateX on ConnectivityState {
  /// True only when the backend has been actively verified as reachable.
  bool get isOnline => this == ConnectivityState.backendReachable;

  /// True when the device is completely offline or the backend cannot be reached.
  bool get isOffline =>
      this == ConnectivityState.offline ||
      this == ConnectivityState.backendUnreachable;

  /// True if a local network interface is present.
  bool get hasNetworkInterface =>
      this != ConnectivityState.offline && this != ConnectivityState.unknown;

  /// User-friendly label for UI badges.
  String get displayLabel {
    switch (this) {
      case ConnectivityState.backendReachable:
        return 'ONLINE';
      case ConnectivityState.networkAvailable:
        return 'CHECKING...';
      case ConnectivityState.backendUnreachable:
        return 'OFFLINE · Backend Unreachable';
      case ConnectivityState.offline:
        return 'OFFLINE';
      case ConnectivityState.unknown:
        return 'INITIALIZING';
    }
  }
}

/// Snapshot of the device's current network state and backend reachability.
class NetworkStatus {
  final ConnectivityState state;
  final List<ConnectivityResult> activeInterfaces;
  final DateTime lastChecked;
  final Duration? latency;
  final String? failureReason;

  const NetworkStatus({
    required this.state,
    this.activeInterfaces = const [],
    required this.lastChecked,
    this.latency,
    this.failureReason,
  });

  factory NetworkStatus.unknown() => NetworkStatus(
        state: ConnectivityState.unknown,
        lastChecked: DateTime.now(),
      );

  factory NetworkStatus.offline({List<ConnectivityResult> interfaces = const []}) =>
      NetworkStatus(
        state: ConnectivityState.offline,
        activeInterfaces: interfaces,
        lastChecked: DateTime.now(),
      );

  factory NetworkStatus.networkAvailable({
    required List<ConnectivityResult> interfaces,
  }) =>
      NetworkStatus(
        state: ConnectivityState.networkAvailable,
        activeInterfaces: interfaces,
        lastChecked: DateTime.now(),
      );

  factory NetworkStatus.backendReachable({
    required List<ConnectivityResult> interfaces,
    Duration? latency,
  }) =>
      NetworkStatus(
        state: ConnectivityState.backendReachable,
        activeInterfaces: interfaces,
        lastChecked: DateTime.now(),
        latency: latency,
      );

  factory NetworkStatus.backendUnreachable({
    required List<ConnectivityResult> interfaces,
    required String reason,
  }) =>
      NetworkStatus(
        state: ConnectivityState.backendUnreachable,
        activeInterfaces: interfaces,
        lastChecked: DateTime.now(),
        failureReason: reason,
      );

  bool get isOnline => state.isOnline;
  bool get isOffline => state.isOffline;
  bool get hasNetworkInterface => state.hasNetworkInterface;

  @override
  String toString() =>
      'NetworkStatus(state: $state, interfaces: $activeInterfaces, latency: ${latency?.inMilliseconds}ms, reason: $failureReason)';
}
