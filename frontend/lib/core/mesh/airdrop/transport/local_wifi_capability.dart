import 'dart:io';

/// Current capability status of the device's local Wi-Fi / direct interface.
enum LocalWifiCapabilityStatus {
  supported,
  unavailable,
  permissionDenied,
  busy,
  failed,
}

/// Result of local Wi-Fi capability detection.
class LocalWifiCapabilityResult {
  final LocalWifiCapabilityStatus status;
  final String? ipAddress;
  final String? interfaceName;
  final String? failureReason;

  const LocalWifiCapabilityResult({
    required this.status,
    this.ipAddress,
    this.interfaceName,
    this.failureReason,
  });

  bool get isSupported => status == LocalWifiCapabilityStatus.supported;

  @override
  String toString() =>
      'LocalWifiCapabilityResult(status: $status, ip: $ipAddress, interface: $interfaceName, reason: $failureReason)';
}

/// Detects local network interface capabilities for high-speed P2P file transfers.
///
/// Discovers whether a direct Wi-Fi interface, mobile hotspot, or local LAN interface
/// is active and has an assignable IPv4 address for direct peer-to-peer streaming.
class LocalWifiCapabilityDetector {
  /// Optional mock override for automated testing.
  final Future<LocalWifiCapabilityResult> Function()? _mockDetector;

  LocalWifiCapabilityDetector({
    Future<LocalWifiCapabilityResult> Function()? mockDetector,
  }) : _mockDetector = mockDetector;

  /// Detects whether high-speed local Wi-Fi / LAN transport is currently available.
  Future<LocalWifiCapabilityResult> detectCapability() async {
    final mock = _mockDetector;
    if (mock != null) {
      return mock();
    }

    try {
      final interfaces = await NetworkInterface.list(
        includeLoopback: false,
        type: InternetAddressType.IPv4,
      );

      if (interfaces.isEmpty) {
        return const LocalWifiCapabilityResult(
          status: LocalWifiCapabilityStatus.unavailable,
          failureReason: 'No non-loopback network interface available.',
        );
      }

      // Prioritize Wi-Fi / wlan interfaces, otherwise accept any valid LAN interface
      NetworkInterface? preferredInterface;
      InternetAddress? preferredAddress;

      for (final iface in interfaces) {
        final name = iface.name.toLowerCase();
        final isWifiOrWlan = name.contains('wlan') ||
            name.contains('wi-fi') ||
            name.contains('wifi') ||
            name.contains('p2p') ||
            name.contains('ap') ||
            name.contains('softap') ||
            name.contains('swlan') ||
            name.contains('rndis') ||
            name.contains('tether') ||
            name.contains('bridge');

        for (final addr in iface.addresses) {
          if (addr.type == InternetAddressType.IPv4 &&
              !addr.isLoopback &&
              !addr.address.startsWith('169.254.') &&
              !addr.address.startsWith('0.')) {
            final isHotspotSubnet = addr.address.startsWith('192.168.43.') ||
                addr.address.startsWith('192.168.49.');
            if (isWifiOrWlan || isHotspotSubnet) {
              return LocalWifiCapabilityResult(
                status: LocalWifiCapabilityStatus.supported,
                ipAddress: addr.address,
                interfaceName: iface.name,
              );
            } else if (preferredAddress == null) {
              preferredInterface = iface;
              preferredAddress = addr;
            }
          }
        }
      }

      if (preferredAddress != null && preferredInterface != null) {
        return LocalWifiCapabilityResult(
          status: LocalWifiCapabilityStatus.supported,
          ipAddress: preferredAddress.address,
          interfaceName: preferredInterface.name,
        );
      }

      return const LocalWifiCapabilityResult(
        status: LocalWifiCapabilityStatus.unavailable,
        failureReason: 'No routable IPv4 address found on active interfaces.',
      );
    } on SocketException catch (e) {
      return LocalWifiCapabilityResult(
        status: LocalWifiCapabilityStatus.failed,
        failureReason: 'Socket error inspecting network interfaces: ${e.message}',
      );
    } catch (e) {
      return LocalWifiCapabilityResult(
        status: LocalWifiCapabilityStatus.failed,
        failureReason: 'Unexpected error detecting Wi-Fi capability: $e',
      );
    }
  }
}
