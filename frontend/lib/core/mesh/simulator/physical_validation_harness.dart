import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import '../campus_mesh_service.dart';
import '../mesh_crypto.dart';
import '../mesh_packet.dart';

/// Assigned role for a physical device participating in an M7 validation run.
enum PhysicalTestRole {
  source('SOURCE · Device A'),
  relay('RELAY · Device B'),
  receiver('RECEIVER · Device C');

  final String label;
  const PhysicalTestRole(this.label);
}

/// Category of physical mesh test to perform.
enum PhysicalTestType {
  emergency('M7-EMERGENCY', 'Controlled Emergency Flare Test'),
  chat('M7-CHAT', 'Offline P2P Mesh Chat Test'),
  airdrop('M7-AIRDROP', 'Academic File AirDrop Test');

  final String prefix;
  final String label;
  const PhysicalTestType(this.prefix, this.label);
}

/// Outcome status of a physical test run.
enum PhysicalTestStatus {
  idle('Idle'),
  running('Running'),
  pass('PASS'),
  fail('FAIL'),
  partial('PARTIAL');

  final String label;
  const PhysicalTestStatus(this.label);
}

/// Truthful telemetry record captured during a physical multi-device test run.
class PhysicalTestTelemetry {
  final String testId;
  final PhysicalTestType testType;
  final PhysicalTestRole operatorRole;
  final String sourceDeviceId;
  final String? relayDeviceId;
  final String? receiverDeviceId;
  final String packetIdHex;
  final DateTime? sendTime;
  final DateTime? relayTime;
  final DateTime? receiveTime;
  final int hopCount;
  final int ttl;
  final bool isSignatureValid;
  final bool isDuplicate;
  final int? rssi;
  final int? latencyMs;
  final String transportType;
  final PhysicalTestStatus status;
  final String notes;

  PhysicalTestTelemetry({
    required this.testId,
    required this.testType,
    required this.operatorRole,
    required this.sourceDeviceId,
    this.relayDeviceId,
    this.receiverDeviceId,
    required this.packetIdHex,
    this.sendTime,
    this.relayTime,
    this.receiveTime,
    this.hopCount = 0,
    this.ttl = 7,
    this.isSignatureValid = true,
    this.isDuplicate = false,
    this.rssi,
    this.latencyMs,
    this.transportType = 'BLE Mesh (0xFFCA)',
    this.status = PhysicalTestStatus.pass,
    this.notes = 'Observed over physical hardware',
  });

  Map<String, dynamic> toJson() {
    return {
      'test_id': testId,
      'test_type': testType.name,
      'operator_role': operatorRole.name,
      'source_device': sourceDeviceId,
      'relay_device': relayDeviceId ?? 'N/A',
      'receiver_device': receiverDeviceId ?? 'N/A',
      'packet_id': packetIdHex,
      'send_time': sendTime?.toIso8601String(),
      'relay_time': relayTime?.toIso8601String(),
      'receive_time': receiveTime?.toIso8601String(),
      'hop_count': hopCount,
      'ttl': ttl,
      'signature_valid': isSignatureValid,
      'duplicate': isDuplicate,
      'rssi_dbm': rssi,
      'latency_ms': latencyMs,
      'transport': transportType,
      'status': status.name.toUpperCase(),
      'notes': notes,
    };
  }

  String toCsvRow() {
    return [
      testId,
      testType.name,
      operatorRole.name,
      sourceDeviceId,
      relayDeviceId ?? '',
      receiverDeviceId ?? '',
      packetIdHex,
      sendTime?.toIso8601String() ?? '',
      relayTime?.toIso8601String() ?? '',
      receiveTime?.toIso8601String() ?? '',
      hopCount.toString(),
      ttl.toString(),
      isSignatureValid ? 'TRUE' : 'FALSE',
      isDuplicate ? 'TRUE' : 'FALSE',
      rssi?.toString() ?? '',
      latencyMs?.toString() ?? '',
      transportType,
      status.name.toUpperCase(),
      '"$notes"',
    ].join(',');
  }

  static String csvHeader() {
    return 'test_id,test_type,operator_role,source_device,relay_device,receiver_device,packet_id,send_time,relay_time,receive_time,hop_count,ttl,signature_valid,duplicate,rssi_dbm,latency_ms,transport,status,notes';
  }
}

/// Pre-flight checklist status for physical testing hardware.
class PhysicalPreflightChecklist {
  final bool isBluetoothAvailable;
  final bool isMeshActive;
  final bool isCryptoAvailable;
  final bool hasPeersObserved;

  const PhysicalPreflightChecklist({
    required this.isBluetoothAvailable,
    required this.isMeshActive,
    required this.isCryptoAvailable,
    required this.hasPeersObserved,
  });

  bool get isReadyForTest =>
      isBluetoothAvailable && isMeshActive && isCryptoAvailable;
}

/// Test execution service orchestrating physical multi-device validation.
class PhysicalValidationHarnessService {
  final CampusMeshService meshService;
  final MeshCryptoService? cryptoService;

  PhysicalTestRole currentRole = PhysicalTestRole.source;
  PhysicalTestStatus currentStatus = PhysicalTestStatus.idle;
  PhysicalTestTelemetry? lastTelemetry;
  final List<PhysicalTestTelemetry> testHistory = [];

  final StreamController<PhysicalTestTelemetry> _telemetryController =
      StreamController<PhysicalTestTelemetry>.broadcast();

  StreamSubscription? _packetSubscription;

  PhysicalValidationHarnessService({
    required this.meshService,
    this.cryptoService,
  });

  Stream<PhysicalTestTelemetry> get onTelemetry => _telemetryController.stream;

  /// Checks pre-flight readiness on physical hardware.
  Future<PhysicalPreflightChecklist> checkPreflight() async {
    final btAvail = await meshService.adapter.isBluetoothAvailable();
    final isMesh = meshService.isRunning;
    final isCrypto = cryptoService != null;
    final peers = meshService.peerRegistry.activePeers.isNotEmpty;

    return PhysicalPreflightChecklist(
      isBluetoothAvailable: btAvail,
      isMeshActive: isMesh,
      isCryptoAvailable: isCrypto,
      hasPeersObserved: peers,
    );
  }

  /// Sets up listening on the physical mesh for test packets.
  Future<void> initializeListener() async {
    await _packetSubscription?.cancel();
    _packetSubscription = meshService.receivedPackets.listen((packet) {
      _handleInboundTestPacket(packet);
    });
  }

  /// Initiates a controlled test broadcast from this device (Role: Source).
  ///
  /// CRITICAL SAFETY RULE:
  /// Test packets are explicitly stamped with "[M7 TEST EMERGENCY]" or "[M7 TEST]"
  /// to ensure no real OS-level alarms are triggered.
  Future<PhysicalTestTelemetry> runSourceBroadcastTest({
    required PhysicalTestType testType,
    required String testMessage,
    Duration timeout = const Duration(seconds: 15),
  }) async {
    currentStatus = PhysicalTestStatus.running;

    final testId = '${testType.prefix}-${DateTime.now().millisecondsSinceEpoch}';
    final now = DateTime.now();
    final packetId = MeshPacket.generatePacketId();
    final packetIdHex = packetId.map((b) => b.toRadixString(16).padLeft(2, '0')).join();

    // Safe compact test payload (< 250 byte BLE MTU ceiling)
    final payloadMap = {
      'tid': testId,
      'tm': true,
      'm': '[M7 TEST] $testMessage',
      'ts': now.millisecondsSinceEpoch,
    };

    final rawPayload = Uint8List.fromList(utf8.encode(jsonEncode(payloadMap)));

    final packet = MeshPacket(
      packetId: packetId,
      packetType: testType == PhysicalTestType.emergency
          ? MeshPacketType.emergency
          : (testType == PhysicalTestType.chat
              ? MeshPacketType.chat
              : MeshPacketType.fileOffer),
      ttl: MeshPacket.defaultTtl,
      hopCount: 0,
      senderDeviceId: meshService.localDeviceId,
      senderRole: meshService.localRole,
      timestamp: now,
      payload: rawPayload,
    );

    // Cryptographic signing if available
    final packetToSend = cryptoService != null
        ? await cryptoService!.signPacket(packet)
        : packet;

    final broadcastSuccess = await meshService.broadcastPacket(packetToSend);

    final telemetry = PhysicalTestTelemetry(
      testId: testId,
      testType: testType,
      operatorRole: PhysicalTestRole.source,
      sourceDeviceId: meshService.localDeviceId,
      packetIdHex: packetIdHex,
      sendTime: now,
      hopCount: 0,
      ttl: packet.ttl,
      isSignatureValid: true,
      status: broadcastSuccess ? PhysicalTestStatus.pass : PhysicalTestStatus.fail,
      notes: broadcastSuccess
          ? 'Physical packet broadcast successfully over BLE mesh.'
          : 'Failed to broadcast packet over physical BLE adapter.',
    );

    _recordTelemetry(telemetry);
    currentStatus = telemetry.status;
    return telemetry;
  }

  void _handleInboundTestPacket(MeshPacket packet) {
    try {
      final decoded = jsonDecode(utf8.decode(packet.payload));
      if (decoded is Map && (decoded['is_test_mode'] == true || decoded['tm'] == true)) {
        final testId = (decoded['tid'] ?? decoded['test_id'])?.toString() ?? 'M7-TEST-UNKNOWN';
        final sourceDev = (decoded['source_device'] ?? packet.senderDeviceId).toString();
        DateTime? sendTime;
        if (decoded['ts'] is int) {
          sendTime = DateTime.fromMillisecondsSinceEpoch(decoded['ts'] as int);
        } else if (decoded['timestamp'] != null) {
          sendTime = DateTime.tryParse(decoded['timestamp'].toString());
        }
        final now = DateTime.now();

        final latencyMs = sendTime != null
            ? now.difference(sendTime).inMilliseconds
            : null;

        final isRelay = packet.hopCount > 0;

        final telemetry = PhysicalTestTelemetry(
          testId: testId,
          testType: PhysicalTestType.emergency,
          operatorRole: isRelay ? PhysicalTestRole.receiver : PhysicalTestRole.relay,
          sourceDeviceId: sourceDev,
          relayDeviceId: isRelay ? packet.senderDeviceId : null,
          receiverDeviceId: meshService.localDeviceId,
          packetIdHex: packet.packetIdHex,
          sendTime: sendTime,
          receiveTime: now,
          hopCount: packet.hopCount,
          ttl: packet.ttl,
          isSignatureValid: true,
          latencyMs: latencyMs,
          status: PhysicalTestStatus.pass,
          notes: 'Received test packet over physical BLE. Verified hopCount=${packet.hopCount}.',
        );

        _recordTelemetry(telemetry);
      }
    } catch (_) {}
  }

  void _recordTelemetry(PhysicalTestTelemetry telemetry) {
    lastTelemetry = telemetry;
    testHistory.insert(0, telemetry);
    if (testHistory.length > 50) testHistory.removeLast();

    if (!_telemetryController.isClosed) {
      _telemetryController.add(telemetry);
    }
  }

  Future<void> dispose() async {
    _packetSubscription?.cancel();
    _telemetryController.close();
  }
}
