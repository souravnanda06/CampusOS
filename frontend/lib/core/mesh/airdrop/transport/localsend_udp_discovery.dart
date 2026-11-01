import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

import 'local_wifi_capability.dart';

/// A peer discovered via LocalSend-compatible UDP broadcast on the local Wi-Fi / Hotspot network.
class LocalSendPeer {
  final String deviceId;
  final String alias;
  final String deviceModel;
  final String ipAddress;
  final int port;
  final String role;
  final DateTime lastSeen;

  const LocalSendPeer({
    required this.deviceId,
    required this.alias,
    required this.deviceModel,
    required this.ipAddress,
    required this.port,
    required this.role,
    required this.lastSeen,
  });

  String get displayName => alias.isNotEmpty ? alias : deviceId;

  Map<String, dynamic> toJson() => {
        'alias': alias,
        'version': '2.0',
        'deviceModel': deviceModel,
        'deviceType': 'mobile',
        'fingerprint': deviceId,
        'port': port,
        'protocol': 'http',
        'download': true,
        'announce': true,
        'campusOsRole': role,
      };

  factory LocalSendPeer.fromJson(Map<String, dynamic> json, String ip) {
    return LocalSendPeer(
      deviceId: json['fingerprint'] as String? ?? 'node_${ip.replaceAll('.', '_')}',
      alias: json['alias'] as String? ?? 'CampusOS Peer ($ip)',
      deviceModel: json['deviceModel'] as String? ?? 'Android Device',
      ipAddress: ip,
      port: (json['port'] as num?)?.toInt() ?? 53317,
      role: json['campusOsRole'] as String? ?? 'student',
      lastSeen: DateTime.now(),
    );
  }
}

/// Service providing zero-configuration peer discovery over local Wi-Fi / Hotspot.
///
/// Implements LocalSend Protocol v2 UDP Multicast & Broadcast:
/// - Listens for incoming announcements on UDP port 53317 / 53318.
/// - Periodically broadcasts device announcement packets across IPv4 subnets.
/// - Discovers nearby peers on the same Wi-Fi router or mobile hotspot in under 500ms.
class LocalSendUdpDiscoveryService {
  static const int defaultPort = 53317;
  static const int fallbackPort = 53318;
  static const String multicastAddress = '224.0.0.167';

  final String localDeviceId;
  final String localAlias;
  final String localRole;
  final int serverPort;
  final LocalWifiCapabilityDetector _capabilityDetector;

  RawDatagramSocket? _socket;
  Timer? _broadcastTimer;
  Timer? _peerPruneTimer;

  final Map<String, LocalSendPeer> _discoveredPeers = {};
  final StreamController<List<LocalSendPeer>> _peersController =
      StreamController<List<LocalSendPeer>>.broadcast();

  bool _isRunning = false;

  LocalSendUdpDiscoveryService({
    required this.localDeviceId,
    required this.localAlias,
    required this.localRole,
    this.serverPort = defaultPort,
    LocalWifiCapabilityDetector? capabilityDetector,
  }) : _capabilityDetector = capabilityDetector ?? LocalWifiCapabilityDetector();

  /// Stream of active peers discovered on the local Wi-Fi network.
  Stream<List<LocalSendPeer>> get peersStream => _peersController.stream;

  /// Current active peers on the local Wi-Fi network.
  List<LocalSendPeer> get activePeers => _discoveredPeers.values.toList();

  bool get isRunning => _isRunning;

  /// Starts listening for UDP broadcasts and broadcasting presence.
  Future<bool> start() async {
    if (_isRunning) return true;

    try {
      final cap = await _capabilityDetector.detectCapability();
      if (!cap.isSupported) {
        debugPrint('ℹ️ [LOCALSEND_UDP] Local Wi-Fi interface not available for UDP discovery');
        return false;
      }

      // 1. Bind UDP socket with port reuse (reusePort is only supported on POSIX/Linux/macOS/Android, not Windows)
      final canReusePort = !Platform.isWindows;
      try {
        _socket = await RawDatagramSocket.bind(
          InternetAddress.anyIPv4,
          defaultPort,
          reuseAddress: true,
          reusePort: canReusePort,
        );
      } catch (_) {
        // Fallback to secondary port if 53317 is bound by another service
        _socket = await RawDatagramSocket.bind(
          InternetAddress.anyIPv4,
          fallbackPort,
          reuseAddress: true,
          reusePort: canReusePort,
        );
      }

      _socket!.broadcastEnabled = true;
      _socket!.multicastHops = 1;

      // Join multicast group if supported
      try {
        _socket!.joinMulticast(InternetAddress(multicastAddress));
      } catch (_) {}

      // 2. Listen for inbound datagrams
      _socket!.listen(_handleIncomingDatagram);

      _isRunning = true;

      // 3. Send initial announcement immediately
      await broadcastAnnouncement();

      // 4. Start periodic heartbeats every 4 seconds
      _broadcastTimer = Timer.periodic(const Duration(seconds: 4), (_) {
        broadcastAnnouncement();
      });

      // 5. Start peer prune timer (removes peers not seen for > 12 seconds)
      _peerPruneTimer = Timer.periodic(const Duration(seconds: 6), (_) {
        _pruneStalePeers();
      });

      debugPrint('⚡ [LOCALSEND_UDP] Discovery active on port ${_socket!.port}');
      return true;
    } catch (e) {
      debugPrint('⚠️ [LOCALSEND_UDP] Failed to start UDP discovery: $e');
      _isRunning = false;
      return false;
    }
  }

  /// Sends a UDP announcement packet across broadcast and multicast addresses.
  Future<void> broadcastAnnouncement() async {
    if (_socket == null || !_isRunning) return;

    try {
      final cap = await _capabilityDetector.detectCapability();
      final myIp = cap.ipAddress ?? '';

      final announcement = {
        'alias': localAlias,
        'version': '2.0',
        'deviceModel': 'CampusOS Node',
        'deviceType': 'mobile',
        'fingerprint': localDeviceId,
        'port': serverPort,
        'protocol': 'http',
        'download': true,
        'announce': true,
        'campusOsRole': localRole,
        'ip': myIp,
      };

      final bytes = utf8.encode(jsonEncode(announcement));

      // 1. Broadcast to 255.255.255.255
      _socket!.send(bytes, InternetAddress('255.255.255.255'), defaultPort);
      _socket!.send(bytes, InternetAddress('255.255.255.255'), fallbackPort);

      // 2. Broadcast to Multicast address
      try {
        _socket!.send(bytes, InternetAddress(multicastAddress), defaultPort);
      } catch (_) {}

      // 3. Subnet-directed broadcast (e.g. 192.168.1.255)
      if (myIp.isNotEmpty && myIp.contains('.')) {
        final parts = myIp.split('.');
        if (parts.length == 4) {
          final subnetBroadcast = '${parts[0]}.${parts[1]}.${parts[2]}.255';
          _socket!.send(bytes, InternetAddress(subnetBroadcast), defaultPort);
        }
      }
    } catch (e) {
      debugPrint('ℹ️ [LOCALSEND_UDP] Broadcast error: $e');
    }
  }

  void _handleIncomingDatagram(RawSocketEvent event) {
    if (event != RawSocketEvent.read || _socket == null) return;

    final datagram = _socket!.receive();
    if (datagram == null) return;

    try {
      final rawString = utf8.decode(datagram.data);
      final json = jsonDecode(rawString) as Map<String, dynamic>;

      final senderFingerprint = json['fingerprint'] as String? ?? '';
      // Ignore own packets
      if (senderFingerprint == localDeviceId) return;

      final senderIp = datagram.address.address;
      final peer = LocalSendPeer.fromJson(json, senderIp);

      _discoveredPeers[peer.deviceId] = peer;
      if (!_peersController.isClosed) {
        _peersController.add(activePeers);
      }
    } catch (_) {
      // Ignore non-json or foreign UDP packets
    }
  }

  void _pruneStalePeers() {
    final now = DateTime.now();
    bool changed = false;

    _discoveredPeers.removeWhere((_, peer) {
      if (now.difference(peer.lastSeen).inSeconds > 12) {
        changed = true;
        return true;
      }
      return false;
    });

    if (changed && !_peersController.isClosed) {
      _peersController.add(activePeers);
    }
  }

  /// Stops discovery and frees the UDP socket.
  Future<void> stop() async {
    _isRunning = false;
    _broadcastTimer?.cancel();
    _broadcastTimer = null;
    _peerPruneTimer?.cancel();
    _peerPruneTimer = null;

    try {
      _socket?.close();
    } catch (_) {}
    _socket = null;
    _discoveredPeers.clear();
    if (!_peersController.isClosed) {
      _peersController.add([]);
    }
  }

  void dispose() {
    stop();
    _peersController.close();
  }
}
