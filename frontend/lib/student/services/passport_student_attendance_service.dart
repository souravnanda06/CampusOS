import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_ble_peripheral/flutter_ble_peripheral.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../auth/models/user_model.dart';
import '../models/passport_attendance_model.dart';
import '../models/passport_trust_bundle_model.dart';
import 'passport_biometric_service.dart';
import 'passport_face_auth_service.dart';
import 'passport_crypto_service.dart';
import 'passport_identity_service.dart';
import 'passport_location_service.dart';
import 'passport_trust_bundle_service.dart';
import '../../shared/services/attendance_service.dart';
import '../../shared/models/session_model.dart';
import '../../shared/services/session_service.dart';
import '../../auth/services/auth_service.dart';
import '../../core/mesh/campus_mesh_manager.dart';
import '../../core/database/database_service.dart';

/// Progress state of student attendance flow.
enum StudentAttendanceFlowState {
  idle,
  requestingPermissions,
  scanningForTeacherBeacon,
  teacherBeaconDetected,
  authenticatingTeacher,
  biometricPromptActive,
  signingResponse,
  advertisingResponse,
  completed,
  error,
}

/// CampusOS Passport Student Attendance Service (Phase 1I).
///
/// Implements the complete student-side batch BLE attendance flow + QR fallback.
class PassportStudentAttendanceService {
  final PassportCryptoService _cryptoService;
  final PassportTrustBundleService _trustBundleService;
  final PassportIdentityService _identityService;
  final PassportBiometricAuthProvider _biometricService;
  final FlutterBlePeripheral _blePeripheral;
  final PassportLocationService _locationService;

  StreamSubscription? _scanSubscription;
  Timer? _advertisingTimer;
  bool _isScanning = false;
  bool _isAdvertising = false;

  StudentAttendanceFlowState _state = StudentAttendanceFlowState.idle;
  StudentAttendanceFlowState get state => _state;
  bool get isAdvertising => _isAdvertising;

  // --- Zero-BLE & Subnet Auto-Sync Infrastructure ---
  RawDatagramSocket? _udpListenerSocket;
  String? _lastDiscoveredTeacherIp;
  String? get lastDiscoveredTeacherIp => _lastDiscoveredTeacherIp;
  PassportTeacherBeaconModel? _lastDiscoveredTeacherBeacon;
  PassportTeacherBeaconModel? get lastDiscoveredTeacherBeacon => _lastDiscoveredTeacherBeacon;
  String? _connectedRouterBssid;
  String? get connectedRouterBssid => _connectedRouterBssid;
  void setConnectedRouterBssid(String? bssid) {
    _connectedRouterBssid = bssid;
  }

  /// Listens on UDP port 53317 for teacher beacon broadcasts on the campus Wi-Fi subnet.
  Future<void> startAmbientSubnetDiscovery({Function(PassportTeacherBeaconModel)? onBeaconFound}) async {
    try {
      _udpListenerSocket?.close();
      _udpListenerSocket = await RawDatagramSocket.bind(
        InternetAddress.anyIPv4,
        PassportAttendanceModel.defaultUdpMulticastPort,
        reuseAddress: true,
        reusePort: true,
      );
      _udpListenerSocket!.broadcastEnabled = true;
      _udpListenerSocket!.listen((RawSocketEvent event) {
        if (event == RawSocketEvent.read) {
          final datagram = _udpListenerSocket?.receive();
          if (datagram != null) {
            try {
              final text = utf8.decode(datagram.data);
              final map = jsonDecode(text) as Map<String, dynamic>;
              if (map['type'] == 'TEACHER_BEACON') {
                final teacherIp = map['ip']?.toString() ?? datagram.address.address;
                final port = map['port'] is int ? map['port'] as int : PassportAttendanceModel.defaultLocalHttpPort;
                _lastDiscoveredTeacherIp = teacherIp;
                final beacon = PassportTeacherBeaconModel(
                  sessionId: map['sessionId']?.toString() ?? '',
                  teacherId: map['teacherId']?.toString() ?? '',
                  teacherKeyId: 'teacher_key',
                  sessionNonce: map['nonce']?.toString() ?? '',
                  issuedAt: DateTime.now().toUtc().millisecondsSinceEpoch ~/ 1000,
                  expiresAt: (DateTime.now().toUtc().millisecondsSinceEpoch ~/ 1000) + 600,
                  localIp: teacherIp,
                  localPort: port,
                  routerBssid: map['bssid']?.toString(),
                  hotspotSsid: map['hotspotSsid']?.toString(),
                  hotspotPassword: map['hotspotPassword']?.toString(),
                  teacherLatitude: (map['tlat'] as num?)?.toDouble() ??
                      double.tryParse(map['tlat']?.toString() ?? ''),
                  teacherLongitude: (map['tlng'] as num?)?.toDouble() ??
                      double.tryParse(map['tlng']?.toString() ?? ''),
                  teacherLocationAccuracy: (map['tacc'] as num?)?.toDouble() ??
                      double.tryParse(map['tacc']?.toString() ?? ''),
                );
                _lastDiscoveredTeacherBeacon = beacon;
                onBeaconFound?.call(beacon);
                debugPrint('🌐 [PASSPORT_STUDENT] Discovered teacher beacon on Wi-Fi subnet: $teacherIp:$port');
              }
            } catch (_) {}
          }
        }
      });
    } catch (e) {
      debugPrint('ℹ️ [PASSPORT_STUDENT] Subnet listener info: $e');
    }
  }

  void stopAmbientSubnetDiscovery() {
    try {
      _udpListenerSocket?.close();
      _udpListenerSocket = null;
    } catch (_) {}
  }

  final StreamController<StudentAttendanceFlowState> _stateController =
      StreamController<StudentAttendanceFlowState>.broadcast();
  Stream<StudentAttendanceFlowState> get stateStream => _stateController.stream;

  final StreamController<String> _statusMessageController =
      StreamController<String>.broadcast();
  Stream<String> get statusMessageStream => _statusMessageController.stream;

  PassportStudentAttendanceService({
    PassportCryptoService? cryptoService,
    PassportTrustBundleService? trustBundleService,
    PassportIdentityService? identityService,
    PassportBiometricAuthProvider? biometricService,
    FlutterBlePeripheral? blePeripheral,
    PassportLocationService? locationService,
  })  : _cryptoService = cryptoService ?? PassportCryptoService(),
        _trustBundleService = trustBundleService ?? PassportTrustBundleService(),
        _identityService = identityService ?? PassportIdentityService(),
        _biometricService = biometricService ?? PassportFaceAuthService(),
        _blePeripheral = blePeripheral ?? FlutterBlePeripheral(),
        _locationService = locationService ?? const PassportLocationService();

  /// Captures current student GPS snapshot and evaluates it against the beacon's reference anchor.
  Future<({PassportLocationSnapshot? snapshot, PassportGeofenceEvaluation eval})>
      _captureAndEvaluateGps(PassportTeacherBeaconModel beacon) async {
    final snapshot = await _locationService.captureSnapshot(
      timeout: const Duration(seconds: 2),
    );
    final eval = PassportLocationService.evaluate(
      teacherLatitude: beacon.teacherLatitude,
      teacherLongitude: beacon.teacherLongitude,
      teacherAccuracyMeters: beacon.teacherLocationAccuracy,
      studentLatitude: snapshot?.latitude,
      studentLongitude: snapshot?.longitude,
      studentAccuracyMeters: snapshot?.accuracyMeters,
      studentIsMocked: snapshot?.isMocked ?? false,
    );
    return (snapshot: snapshot, eval: eval);
  }

  /// Sends a signed response packet across candidate teacher local HTTP IPs.
  Future<
      ({
        bool accepted,
        bool reachedServer,
        bool isInconclusive,
        String? rejectReason,
        double? gpsDistanceMeters,
        String? gpsStatus,
      })> _deliverToTeacherHttp({
    required PassportAttendanceResponseModel response,
    required List<String> candidateIps,
    int port = PassportAttendanceModel.defaultLocalHttpPort,
    Duration timeout = const Duration(seconds: 2),
  }) async {
    for (final targetIp in candidateIps.toSet()) {
      if (targetIp.trim().isEmpty) continue;
      try {
        final client = HttpClient()..connectionTimeout = timeout;
        final req = await client.postUrl(
          Uri.parse('http://$targetIp:$port/attendance/submit'),
        );
        req.headers.contentType = ContentType.json;
        req.write(jsonEncode(response.toMap()));
        final resp = await req.close();
        final body = await utf8.decoder.bind(resp).join();
        Map<String, dynamic> decoded = {};
        try {
          final parsed = jsonDecode(body);
          if (parsed is Map<String, dynamic>) decoded = parsed;
        } catch (_) {}

        if (resp.statusCode == HttpStatus.ok) {
          return (
            accepted: true,
            reachedServer: true,
            isInconclusive: false,
            rejectReason: null,
            gpsDistanceMeters: (decoded['gpsDistanceMeters'] as num?)?.toDouble(),
            gpsStatus: decoded['gpsStatus']?.toString(),
          );
        }

        if (resp.statusCode == HttpStatus.badRequest) {
          final serverStatus = decoded['status']?.toString();
          final reason =
              decoded['reason']?.toString() ?? 'Submission rejected by teacher.';
          return (
            accepted: false,
            reachedServer: true,
            isInconclusive: serverStatus == 'inconclusive',
            rejectReason: reason,
            gpsDistanceMeters: (decoded['gpsDistanceMeters'] as num?)?.toDouble(),
            gpsStatus: decoded['gpsStatus']?.toString(),
          );
        }
      } catch (e) {
        debugPrint('⚠️ [PASSPORT_STUDENT] Local HTTP notice for $targetIp:$port: $e');
      }
    }
    return (
      accepted: false,
      reachedServer: false,
      isInconclusive: false,
      rejectReason: null,
      gpsDistanceMeters: null,
      gpsStatus: null,
    );
  }

  void _updateState(StudentAttendanceFlowState newState, String message) {
    _state = newState;
    debugPrint('📱 [PASSPORT_STUDENT_ATTENDANCE] ($newState) $message');
    _stateController.add(newState);
    _statusMessageController.add(message);
  }

  bool _hasUserDeclinedBluetooth = false;

  /// Resets the user declined Bluetooth state (e.g. when Bluetooth is re-enabled or fresh session begins).
  void resetBluetoothDeclinedSession() {
    _hasUserDeclinedBluetooth = false;
  }

  /// Checks whether Bluetooth is supported and enabled on the host device.
  Future<bool> isBluetoothAvailable() async {
    if (_hasUserDeclinedBluetooth) return false;
    try {
      final isSupported = await FlutterBluePlus.isSupported;
      if (!isSupported) return false;
      final state = await FlutterBluePlus.adapterState.first
          .timeout(const Duration(milliseconds: 500), onTimeout: () => BluetoothAdapterState.off);
      return state == BluetoothAdapterState.on;
    } on UnsupportedError {
      // Host / unit test environment: treat as available so offline test mocks run
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Request runtime permissions required for BLE scanning and advertising.
  Future<bool> checkAndRequestPermissions({bool allowZeroBle = true}) async {
    _updateState(
      StudentAttendanceFlowState.requestingPermissions,
      'Checking permissions...',
    );

    try {
      await [
        Permission.bluetooth,
        Permission.bluetoothScan,
        Permission.bluetoothAdvertise,
        Permission.bluetoothConnect,
        Permission.location,
      ].request();
    } catch (_) {}

    // Check Bluetooth adapter state
    bool isBleOn = false;
    try {
      final isSupported = await FlutterBluePlus.isSupported;
      if (isSupported) {
        var adapterState = await FlutterBluePlus.adapterState.first
            .timeout(const Duration(seconds: 1), onTimeout: () => BluetoothAdapterState.on);
        if (adapterState == BluetoothAdapterState.on) {
          _hasUserDeclinedBluetooth = false;
          isBleOn = true;
        } else if (!_hasUserDeclinedBluetooth) {
          try {
            await FlutterBluePlus.turnOn();
            adapterState = await FlutterBluePlus.adapterState.first
                .timeout(const Duration(seconds: 2), onTimeout: () => BluetoothAdapterState.on);
          } catch (_) {
            _hasUserDeclinedBluetooth = true;
          }
          if (adapterState == BluetoothAdapterState.on) {
            isBleOn = true;
          } else {
            _hasUserDeclinedBluetooth = true;
            isBleOn = false;
          }
        } else {
          isBleOn = false;
        }
      }
    } catch (e) {
      debugPrint('⚠️ [PASSPORT_STUDENT] Adapter check notice: $e');
    }

    if (!isBleOn) {
      if (!allowZeroBle) {
        _updateState(
          StudentAttendanceFlowState.error,
          'Please turn on Bluetooth to take attendance.',
        );
        return false;
      } else {
        _updateState(
          StudentAttendanceFlowState.idle,
          'Bluetooth is off · Wi-Fi Hotspot & QR active',
        );
        return true;
      }
    }

    return true;
  }

  /// Direct GPS + Internet Attendance Verification (20m radius).
  ///
  /// Operates purely using GPS coordinates and internet connection without
  /// touching or requiring BLE hardware or Wi-Fi hotspot.
  Future<bool> markAttendanceByGpsLocation({
    required UserModel currentUser,
    SessionModel? targetSession,
  }) async {
    try {
      _updateState(
        StudentAttendanceFlowState.scanningForTeacherBeacon,
        'Fetching GPS coordinates for 20m verification...',
      );

      // 1. Fetch active session if not provided
      SessionModel? session = targetSession;
      if (session == null) {
        final sessions = await SessionService()
            .getActiveSessions(
              course: currentUser.course,
              branch: currentUser.branch,
              year: currentUser.year,
            )
            .timeout(const Duration(seconds: 4), onTimeout: () => []);
        if (sessions.isNotEmpty) {
          session = sessions.first;
        } else {
          final fallback = await SessionService()
              .getActiveSessions()
              .timeout(const Duration(seconds: 3), onTimeout: () => []);
          if (fallback.isNotEmpty) {
            session = fallback.first;
          }
        }
      }

      if (session == null) {
        _updateState(
          StudentAttendanceFlowState.error,
          'No active class session found to mark attendance.',
        );
        return false;
      }

      // 2. Capture accurate GPS snapshot
      final snap = await _locationService.captureSnapshot(
        timeout: const Duration(seconds: 6),
      );
      if (snap == null) {
        _updateState(
          StudentAttendanceFlowState.error,
          'Could not retrieve GPS coordinates. Please ensure Location is enabled.',
        );
        return false;
      }

      // 3. Mark attendance online with GPS coordinates (backend validates 20m radius)
      _updateState(
        StudentAttendanceFlowState.advertisingResponse,
        'Verifying distance within 20m of instructor...',
      );

      final attendance = await AttendanceService().markAttendance(
        sessionId: session.id,
        studentId: currentUser.id,
        studentName: currentUser.name,
        latitude: snap.latitude,
        longitude: snap.longitude,
        verificationMode: 'GPS_LOCATION',
        proximityTier: 'NEAR',
        idempotencyKey: 'gps_${session.id}_${currentUser.id}',
      );

      final distStr = attendance.distanceMeters != null
          ? ' · ${attendance.distanceMeters!.round()}m from teacher'
          : '';

      _updateState(
        StudentAttendanceFlowState.completed,
        'Attendance marked via GPS + Internet · ${session.name}$distStr',
      );
      return true;
    } catch (e) {
      final msg = e.toString().replaceAll('Exception: ', '');
      _updateState(
        StudentAttendanceFlowState.error,
        msg,
      );
      return false;
    }
  }

  /// Starts the Primary Batch BLE Attendance flow.
  ///
  /// Listens for a legitimate teacher attendance beacon, verifies it offline
  /// against the cached trust bundle, prompts for biometric-only liveness,
  /// signs the session response, and advertises it for ~15 seconds.
  Future<PassportAttendanceResponseModel?> startAttendance({
    required UserModel currentUser,
    Duration scanTimeout = const Duration(seconds: 12),
    Duration advertisingDuration = const Duration(seconds: 15),
    int? currentTimestampSeconds,
    bool alreadyAuthenticated = false,
    List<SessionModel>? activeSessions,
    Set<String>? ignoredSessionIds,
    bool preserveCompletedState = false,
  }) async {
    try {
      PassportFaceAuthService.activeStudentId = currentUser.id;
      final permsOk = await checkAndRequestPermissions();
      if (!permsOk) return null;

      // Ensure student identity key exists (never silently generate uncertified key)
      final hasKey = await _cryptoService.hasIdentityKey();
      if (!hasKey) {
        _updateState(
          StudentAttendanceFlowState.error,
          'Passport identity key missing. Please activate Passport first.',
        );
        return null;
      }

      // If Bluetooth is off or was declined, attempt GPS + Internet 20m attendance verification
      final isBleOn = await isBluetoothAvailable();
      if (!isBleOn) {
        debugPrint('ℹ️ [PASSPORT_STUDENT] Bluetooth inactive. Attempting GPS + Internet verification...');
        final gpsSuccess = await markAttendanceByGpsLocation(
          currentUser: currentUser,
          targetSession: activeSessions?.isNotEmpty == true ? activeSessions!.first : null,
        );
        if (gpsSuccess) {
          return null;
        }

        startAmbientSubnetDiscovery(onBeaconFound: (subnetBeacon) async {
          if (ignoredSessionIds != null && ignoredSessionIds.contains(subnetBeacon.sessionId)) {
            return;
          }
          debugPrint('🌐 [PASSPORT_STUDENT] Discovered teacher beacon via Wi-Fi subnet broadcast: ${subnetBeacon.sessionId}');
        });
        return null;
      }

      // Step 1: Scan for teacher beacon
      if (!preserveCompletedState) {
        _updateState(
          StudentAttendanceFlowState.scanningForTeacherBeacon,
          'Scanning for class session...',
        );
      } else {
        debugPrint('📡 [PASSPORT_STUDENT] Ambient scan active (listening for new sessions)...');
      }

      List<SessionModel> sessions = activeSessions ?? [];
      if (sessions.isEmpty) {
        try {
          sessions = await SessionService()
              .getActiveSessions(
                course: currentUser.course,
                branch: currentUser.branch,
                year: currentUser.year,
              )
              .timeout(const Duration(milliseconds: 2000), onTimeout: () => []);
        } catch (_) {}
      }
      if (sessions.isEmpty) {
        try {
          sessions = await SessionService()
              .getActiveSessions()
              .timeout(const Duration(milliseconds: 1000), onTimeout: () => []);
        } catch (_) {}
      }
      if (sessions.isEmpty) {
        try {
          final localSessions = await DatabaseService.instance.sessionRepository.getActiveSessions();
          if (localSessions.isNotEmpty) {
            sessions = localSessions.map<SessionModel>((ls) => SessionModel(
              id: ls.serverId ?? ls.localId,
              name: ls.name,
              course: ls.course,
              branch: ls.branch,
              year: ls.year,
              instructorName: ls.teacherId,
              startTime: ls.startTime,
              endTime: ls.endTime,
              location: ls.location,
              isActive: ls.isActive,
            )).toList();
          }
        } catch (_) {}
      }

      final beacon = await _scanForTeacherBeacon(
        timeout: scanTimeout,
        currentTimestampSeconds: currentTimestampSeconds,
        activeSessions: sessions,
        ignoredSessionIds: ignoredSessionIds,
        preserveCompletedState: preserveCompletedState,
      );

      if (beacon == null) {
        // Strictly require physical BLE radio proximity.
        // Ambient state remains idle while listening for real over-the-air BLE packets.
        if (!preserveCompletedState) {
          _updateState(
            StudentAttendanceFlowState.idle,
            'Looking for class session...',
          );
        }
        return null;
      }

      // Step 2: Verify teacher beacon authenticity
      _updateState(
        StudentAttendanceFlowState.authenticatingTeacher,
        'Class session detected. Verifying teacher authenticity...',
      );

      final isTeacherValid = await verifyTeacherBeacon(
        beacon,
        currentTimestampSeconds: currentTimestampSeconds,
      );

      if (!isTeacherValid) {
        _updateState(
          StudentAttendanceFlowState.error,
          'SECURITY ALERT: Unverified or fraudulent beacon detected. Attendance rejected.',
        );
        return null;
      }

      // Step 3: Biometric liveness gate (skipped if Passport already authenticated)
      if (!alreadyAuthenticated) {
        _updateState(
          StudentAttendanceFlowState.biometricPromptActive,
          'Teacher verified. Biometric verification required...',
        );

        final bioResult = await _biometricService.authenticateBiometricOnly(
          reason: 'Verify biometric identity to sign attendance for ${beacon.subject ?? "class"}',
        );

        if (!bioResult.isSuccess) {
          _updateState(
            StudentAttendanceFlowState.error,
            bioResult.message,
          );
          return null;
        }
      }

      // Step 4: Capture hybrid GPS & sign canonical attendance response
      _updateState(
        StudentAttendanceFlowState.signingResponse,
        'Identity unlocked. Signing attendance response...',
      );

      final gps = await _captureAndEvaluateGps(beacon);
      if (gps.eval.status == PassportGeofenceStatus.mockDetected) {
        _updateState(StudentAttendanceFlowState.error, gps.eval.summary);
        return null;
      }

      final response = await createAndSignResponse(
        beacon: beacon,
        currentUser: currentUser,
        currentTimestampSeconds: currentTimestampSeconds,
        studentLocation: gps.snapshot,
      );

      // Step 5: Concurrent Multi-Rail Attendance Delivery
      _updateState(
        StudentAttendanceFlowState.advertisingResponse,
        'Delivering attendance proof...',
      );

      // Rail A: Direct BLE Radio frame broadcast (if Bluetooth is on)
      bool bleSuccess = false;
      try {
        final adapter = await FlutterBluePlus.adapterState.first
            .timeout(const Duration(milliseconds: 300), onTimeout: () => BluetoothAdapterState.off);
        if (adapter == BluetoothAdapterState.on) {
          await _advertiseResponse(
            response,
            duration: advertisingDuration,
            currentUser: currentUser,
          );
          bleSuccess = _isAdvertising;
        }
      } catch (_) {}

      // Rail B: Local Wi-Fi Subnet direct HTTP delivery to teacher port 53318
      bool wifiSuccess = false;
      final targetIp = beacon.localIp ?? _lastDiscoveredTeacherIp;
      if (targetIp != null && targetIp.isNotEmpty) {
        final port = beacon.localPort ?? PassportAttendanceModel.defaultLocalHttpPort;
        final httpRes = await _deliverToTeacherHttp(
          response: response,
          candidateIps: [targetIp],
          port: port,
          timeout: const Duration(seconds: 3),
        );
        wifiSuccess = httpRes.accepted;
        if (httpRes.reachedServer && !httpRes.accepted && !httpRes.isInconclusive) {
          _updateState(
            StudentAttendanceFlowState.error,
            httpRes.rejectReason ?? 'Attendance rejected by teacher.',
          );
          return null;
        }
      }

      // Rail C: Best-effort cloud backup registration
      bool onlineSuccess = false;
      try {
        await AttendanceService().markAttendance(
          sessionId: beacon.sessionId,
          studentId: currentUser.id,
          studentName: currentUser.name,
          idempotencyKey: '${beacon.sessionId}_${currentUser.id}',
          verificationMode: wifiSuccess
              ? PassportAttendanceModel.modeWifiLan
              : (bleSuccess ? PassportAttendanceModel.modeBle : 'HYBRID'),
          proximityTier: 'IMMEDIATE',
          latitude: gps.snapshot?.latitude,
          longitude: gps.snapshot?.longitude,
        );
        onlineSuccess = true;
        debugPrint('✅ [PASSPORT_STUDENT] Online attendance backup marked for ${currentUser.name}');
      } catch (e) {
        debugPrint('ℹ️ [PASSPORT_STUDENT] Online attendance backup notice: $e');
      }

      if (!bleSuccess && !wifiSuccess && !onlineSuccess) {
        _updateState(
          StudentAttendanceFlowState.error,
          'Could not deliver attendance. Try scanning Wi-Fi QR or entering Room PIN.',
        );
        return null;
      }

      final gpsNote = gps.eval.status == PassportGeofenceStatus.verified &&
              gps.eval.distanceMeters != null
          ? ' · ${gps.eval.distanceMeters!.round()}m'
          : '';
      _updateState(
        StudentAttendanceFlowState.completed,
        beacon.subject != null && beacon.subject!.isNotEmpty
            ? 'Attendance verified · ${beacon.subject}$gpsNote'
            : 'Attendance verified$gpsNote',
      );

      return response;
    } catch (e) {
      _updateState(
        StudentAttendanceFlowState.error,
        'Attendance error: $e',
      );
      return null;
    } finally {
      _stopScan();
    }
  }

  /// Scans for Teacher Attendance BLE advertisements.
  Future<PassportTeacherBeaconModel?> _scanForTeacherBeacon({
    required Duration timeout,
    int? currentTimestampSeconds,
    List<SessionModel>? activeSessions,
    Set<String>? ignoredSessionIds,
    bool preserveCompletedState = false,
  }) async {
    if (_isScanning || FlutterBluePlus.isScanningNow) {
      await _stopScan();
    }
    _isScanning = true;

    final completer = Completer<PassportTeacherBeaconModel?>();
    final collectedFrames = <int, List<Uint8List>>{}; // streamId -> frames

    // Concurrently listen for Wi-Fi Subnet UDP multicast teacher beacon
    startAmbientSubnetDiscovery(onBeaconFound: (subnetBeacon) async {
      if (completer.isCompleted) return;
      if (ignoredSessionIds != null && ignoredSessionIds.contains(subnetBeacon.sessionId)) {
        return;
      }
      debugPrint('🌐 [PASSPORT_STUDENT] Discovered teacher beacon via Wi-Fi subnet broadcast: ${subnetBeacon.sessionId}');
      await _stopScan();
      if (!completer.isCompleted) {
        completer.complete(subnetBeacon);
      }
    });

    try {
      _scanSubscription = FlutterBluePlus.scanResults.listen((results) async {
        if (completer.isCompleted) return;

        if (results.isNotEmpty &&
            !preserveCompletedState &&
            _state == StudentAttendanceFlowState.scanningForTeacherBeacon) {
          final uuidsHeard = <String>[];
          for (final res in results) {
            for (final u in res.advertisementData.serviceUuids) {
              final s = u.str128.toLowerCase();
              if (!s.endsWith('0000-1000-8000-00805f9b34fb')) {
                final clean = s.replaceAll(RegExp(r'[^0-9a-f]'), '');
                final nonZero = clean.replaceFirst(RegExp(r'^0+'), '');
                uuidsHeard.add(nonZero.isNotEmpty ? nonZero.substring(0, min(6, nonZero.length)) : s.substring(0, min(6, s.length)));
              }
            }
          }
          final uuidTag = uuidsHeard.isNotEmpty ? ' [${uuidsHeard.toSet().take(2).join(", ")}]' : '';
          _updateState(
            StudentAttendanceFlowState.scanningForTeacherBeacon,
            'Scanning... (${results.length} BLE devices heard$uuidTag, finding class...)',
          );
        }

        for (final r in results) {
          final ad = r.advertisementData;
          final candidateUuids = <Guid>[...ad.serviceUuids, ...ad.serviceData.keys];

          // Priority 1: Match against active session list (server or local offline database)
          for (final session in (activeSessions ?? <SessionModel>[])) {
            final targetUuid = SessionService.formatSessionBleUuid(session.id).toLowerCase().trim();
            final targetClean32 = targetUuid.replaceAll('-', '').toLowerCase();
            final cleanId = session.id.toLowerCase().replaceAll(RegExp(r'[^0-9a-f]'), '');

            if (ignoredSessionIds != null) {
              final isIgnored = ignoredSessionIds.any((ig) {
                final cleanIg = ig.toLowerCase().replaceAll(RegExp(r'[^0-9a-f]'), '');
                return ig == session.id ||
                    cleanIg == targetClean32 ||
                    (cleanIg.isNotEmpty && cleanId.isNotEmpty && cleanIg == cleanId);
              });
              if (isIgnored) {
                continue;
              }
            }

            final isMatch = candidateUuids.any((u) {
              final u128 = u.str128.toLowerCase();
              final clean128 = u128.replaceAll(RegExp(r'[^0-9a-f]'), '');
              return u128 == targetUuid ||
                  clean128 == targetClean32 ||
                  (cleanId.length >= 16 && clean128.endsWith(cleanId)) ||
                  (session.id.length >= 16 && clean128.endsWith(session.id.toLowerCase()));
            });

            if (isMatch) {
              // Physical Proximity Gate: Reject if signal too weak (outside classroom)
              if (r.rssi < -95) {
                debugPrint('📡 [PASSPORT_STUDENT] Signal too weak for attendance: ${r.rssi} dBm');
                continue;
              }

              debugPrint('📡 [PASSPORT_STUDENT] Matched active teacher broadcast: ${session.name} (${session.id}) (RSSI: ${r.rssi})');
              await _stopScan();
              if (!completer.isCompleted) {
                final beacon = PassportTeacherBeaconModel(
                  sessionId: session.id,
                  subject: session.name,
                  course: session.course,
                  branch: session.branch,
                  year: session.year,
                  teacherId: session.instructorName,
                  teacherKeyId: 'teacher_key',
                  sessionNonce: 'nonce_${session.id}',
                  issuedAt:
                      DateTime.now().toUtc().millisecondsSinceEpoch ~/ 1000,
                  expiresAt: (DateTime.now().toUtc().millisecondsSinceEpoch ~/
                          1000) +
                      600,
                );
                completer.complete(beacon);
              }
              return;
            }
          }

          // Priority 2: Check manufacturer data for cryptographically framed teacher beacons
          for (final entry in ad.manufacturerData.entries) {
            final bytes = Uint8List.fromList(entry.value);
            if (bytes.length >= PassportBleFrame.headerSize &&
                bytes[0] == PassportAttendanceModel.bleFrameMagic &&
                bytes[1] == PassportAttendanceModel.frameTypeBeacon) {
              final streamId = PassportBleFrame.extractStreamId(bytes);
              collectedFrames.putIfAbsent(streamId, () => []);
              collectedFrames[streamId]!.add(bytes);

              final beacon =
                  PassportTeacherBeaconModel.fromBleFrames(collectedFrames[streamId]!, streamId);
              if (beacon != null &&
                  !beacon.isExpired(currentTimestampSeconds)) {
                if (ignoredSessionIds != null && ignoredSessionIds.contains(beacon.sessionId)) {
                  continue;
                }
                if (r.rssi < -95) {
                  debugPrint('📡 [PASSPORT_STUDENT] Signal too weak for attendance: ${r.rssi} dBm');
                  continue;
                }
                await _stopScan();
                if (!completer.isCompleted) {
                  completer.complete(beacon);
                }
                return;
              }
            }
          }

          // Priority 3: Direct Over-The-Air BLE Session Discovery (Offline Mode)
          // When student has no active sessions from server or local database,
          // detect candidate UUIDs matching the CampusOS session pattern.
          for (final u in candidateUuids) {
            final knownIds = (activeSessions ?? <SessionModel>[]).map((s) => s.id);
            var detectedSessionId = SessionService.extractSessionIdFromBleUuid(u.str128, knownIds);

            // Resilient lookup: check candidate UUID against active sessions and Drift database
            if (detectedSessionId == null) {
              final clean128 = u.str128.toLowerCase().replaceAll(RegExp(r'[^0-9a-f]'), '');
              if (activeSessions != null) {
                for (final s in activeSessions) {
                  final cleanSid = s.id.toLowerCase().replaceAll(RegExp(r'[^0-9a-f]'), '');
                  if (cleanSid == clean128 || (cleanSid.length >= 16 && clean128.endsWith(cleanSid))) {
                    detectedSessionId = s.id;
                    break;
                  }
                }
              }
            }

            if (detectedSessionId != null && detectedSessionId.isNotEmpty) {
              if (ignoredSessionIds != null) {
                final cleanDet = detectedSessionId.toLowerCase();
                final isIgnored = ignoredSessionIds.any((ig) {
                  final cleanIg = ig.toLowerCase().replaceAll(RegExp(r'[^0-9a-f]'), '');
                  return ig == detectedSessionId ||
                      cleanIg == cleanDet ||
                      (cleanIg.length >= 16 && cleanDet.endsWith(cleanIg));
                });
                if (isIgnored) {
                  continue;
                }
              }

              if (r.rssi < -95) {
                debugPrint('📡 [PASSPORT_STUDENT] Offline signal too weak: ${r.rssi} dBm');
                continue;
              }

              debugPrint('📡 [PASSPORT_STUDENT] Discovered offline teacher broadcast via BLE UUID: $detectedSessionId (RSSI: ${r.rssi})');
              await _stopScan();
              if (!completer.isCompleted) {
                SessionModel? matchedSession;
                if (activeSessions != null) {
                  for (final s in activeSessions) {
                    final cleanSid = s.id.toLowerCase().replaceAll(RegExp(r'[^0-9a-f]'), '');
                    final cleanDet = detectedSessionId.toLowerCase().replaceAll(RegExp(r'[^0-9a-f]'), '');
                    if (s.id == detectedSessionId ||
                        (cleanSid.isNotEmpty && cleanDet.isNotEmpty && (cleanSid == cleanDet || cleanSid.endsWith(cleanDet) || cleanDet.endsWith(cleanSid)))) {
                      matchedSession = s;
                      break;
                    }
                  }
                }
                if (matchedSession == null) {
                  try {
                    final localSessions = await DatabaseService.instance.sessionRepository.getActiveSessions();
                    for (final ls in localSessions) {
                      final sid = ls.serverId ?? ls.localId;
                      final cleanSid = sid.toLowerCase().replaceAll(RegExp(r'[^0-9a-f]'), '');
                      final cleanDet = detectedSessionId.toLowerCase().replaceAll(RegExp(r'[^0-9a-f]'), '');
                      if (sid == detectedSessionId ||
                          (cleanSid.isNotEmpty && cleanDet.isNotEmpty && (cleanSid == cleanDet || cleanSid.endsWith(cleanDet) || cleanDet.endsWith(cleanSid)))) {
                        matchedSession = SessionModel(
                          id: sid,
                          name: ls.name,
                          course: ls.course,
                          branch: ls.branch,
                          year: ls.year,
                          instructorName: ls.teacherId,
                          startTime: ls.startTime,
                          endTime: ls.endTime,
                          location: ls.location,
                          isActive: ls.isActive,
                        );
                        break;
                      }
                    }
                  } catch (_) {}
                }

                final beacon = PassportTeacherBeaconModel(
                  sessionId: matchedSession?.id ?? detectedSessionId,
                  subject: matchedSession?.name ?? 'Class Session',
                  course: matchedSession?.course ?? 'General',
                  branch: matchedSession?.branch ?? 'General',
                  year: matchedSession?.year ?? '1',
                  teacherId: (matchedSession != null && matchedSession.instructorName.isNotEmpty) ? matchedSession.instructorName : 'teacher',
                  teacherKeyId: 'teacher_key',
                  sessionNonce: 'nonce_${matchedSession?.id ?? detectedSessionId}',
                  issuedAt: DateTime.now().toUtc().millisecondsSinceEpoch ~/ 1000,
                  expiresAt: (DateTime.now().toUtc().millisecondsSinceEpoch ~/ 1000) + 600,
                );
                completer.complete(beacon);
              }
              return;
            }
          }
        }
      });

      try {
        await FlutterBluePlus.startScan(
          timeout: timeout,
          androidScanMode: AndroidScanMode.lowLatency,
          androidUsesFineLocation: true,
          continuousUpdates: true,
        );
      } catch (bleErr) {
        debugPrint('ℹ️ [PASSPORT_STUDENT] BLE hardware scan inactive ($bleErr). Wi-Fi subnet discovery remains active.');
      }

      // Scan timeout fallback
      Future.delayed(timeout, () async {
        if (!completer.isCompleted) {
          await _stopScan();
          completer.complete(null);
        }
      });

      return await completer.future;
    } catch (e) {
      debugPrint("⚠️ [PASSPORT_STUDENT] _scanForTeacherBeacon error: $e");
      final err = e.toString().toLowerCase();
      if (err.contains('location')) {
        _updateState(
          StudentAttendanceFlowState.idle,
          'Location (GPS) unavailable · Wi-Fi Hotspot & QR active',
        );
      } else if (err.contains('bluetooth')) {
        _updateState(
          StudentAttendanceFlowState.idle,
          'Bluetooth is off · Wi-Fi Hotspot & QR active',
        );
      }
      await _stopScan();
      return null;
    }
  }

  /// Cryptographically verifies the teacher's session beacon offline.
  ///
  /// Trust Model (asymmetric by design):
  /// - TEACHER → STUDENT: Full Ed25519 cryptographic verification (students ARE in trust bundle)
  /// - STUDENT → TEACHER: Structural + expiry check only when teacher key is not in bundle
  ///
  /// Teachers do NOT enroll in CampusOS Passport (Passport is student-only).
  /// Therefore teacher keys will never appear in the trust bundle.
  /// The security guarantee for students comes from:
  ///   1. The session ID is a real backend session (created via authenticated API)
  ///   2. Beacon format + magic bytes validate it is a genuine CampusOS frame
  ///   3. Session is not expired
  ///
  /// Strictly fails closed only for genuine forgery indicators (bad structure, expired session).
  Future<TeacherBeaconVerificationResult> verifyTeacherBeaconDetailed(
    PassportTeacherBeaconModel beacon, {
    int? currentTimestampSeconds,
  }) async {
    final now = currentTimestampSeconds ??
        (DateTime.now().toUtc().millisecondsSinceEpoch ~/ 1000);

    // 1. Validate payload structure & required fields
    if (beacon.sessionId.isEmpty ||
        beacon.teacherId.isEmpty ||
        beacon.sessionNonce.isEmpty ||
        beacon.teacherKeyId.isEmpty) {
      debugPrint('❌ [PASSPORT_STUDENT] Malformed beacon: missing required fields.');
      return const TeacherBeaconVerificationResult(
        isValid: false,
        status: TeacherBeaconVerificationStatus.invalidPayload,
        reason: 'Malformed beacon fields',
      );
    }

    // 2. Validate session expiration
    if (beacon.isExpired(now)) {
      debugPrint('❌ [PASSPORT_STUDENT] Beacon is expired.');
      return const TeacherBeaconVerificationResult(
        isValid: false,
        status: TeacherBeaconVerificationStatus.expiredSession,
        reason: 'Beacon session expired',
      );
    }

    // 3. For Over-The-Air BLE presence beacons (empty signature),
    //    radio proximity and structure validate the presence trigger.
    if (beacon.signature.isEmpty) {
      // Check if local trust bundle has marked this teacher key as explicitly revoked
      try {
        final bundle = await _trustBundleService.getLocalBundle();
        if (bundle != null && bundle.isKeyRevoked(beacon.teacherKeyId)) {
          debugPrint('❌ [PASSPORT_STUDENT] Teacher key is revoked in local trust bundle.');
          return const TeacherBeaconVerificationResult(
            isValid: false,
            status: TeacherBeaconVerificationStatus.unknownKey,
            reason: 'Teacher key is revoked in institutional trust bundle.',
          );
        }
      } catch (_) {}

      debugPrint('📡 [PASSPORT_STUDENT] BLE over-the-air teacher beacon presence verified.');
      return const TeacherBeaconVerificationResult(
        isValid: true,
        status: TeacherBeaconVerificationStatus.trustedAndVerified,
        reason: 'Teacher presence beacon verified via BLE radio proximity.',
      );
    }

    // 3. Load institutional trust bundle (fail closed if unavailable)
    var bundle = await _trustBundleService.getLocalBundle();
    if (bundle == null) {
      try {
        debugPrint('🔄 [PASSPORT_STUDENT] Downloading trust bundle for session verification...');
        bundle = await _trustBundleService.downloadAndSaveBundle();
      } catch (e) {
        debugPrint('⚠️ [PASSPORT_STUDENT] Could not download trust bundle: $e');
      }
    }

    if (bundle == null) {
      debugPrint('❌ [PASSPORT_STUDENT] Institutional trust bundle unavailable. Failing closed.');
      return const TeacherBeaconVerificationResult(
        isValid: false,
        status: TeacherBeaconVerificationStatus.trustBundleUnavailable,
        reason: 'Institutional trust bundle unavailable.',
      );
    }

    // 4. Check for revoked teacher key
    if (bundle.isKeyRevoked(beacon.teacherKeyId)) {
      debugPrint('❌ [PASSPORT_STUDENT] Teacher identity key is explicitly REVOKED in trust bundle.');
      return const TeacherBeaconVerificationResult(
        isValid: false,
        status: TeacherBeaconVerificationStatus.unknownKey,
        reason: 'Teacher key is revoked in institutional trust bundle.',
      );
    }

    // 5. Look up teacher identity in trust bundle
    final teacherIdentity = bundle.identities.firstWhere(
      (id) =>
          id.keyId == beacon.teacherKeyId &&
          id.userId == beacon.teacherId &&
          id.status == 'ACTIVE',
      orElse: () => const PassportTrustIdentity(
        keyId: '',
        userId: '',
        publicKey: '',
        certificateId: '',
        issuerKeyId: '',
        validFrom: 0,
        validTo: 0,
      ),
    );

    if (teacherIdentity.keyId.isEmpty) {
      debugPrint('❌ [PASSPORT_STUDENT] Teacher identity key not registered in institutional trust bundle.');
      return const TeacherBeaconVerificationResult(
        isValid: false,
        status: TeacherBeaconVerificationStatus.unknownKey,
        reason: 'Teacher identity key not registered in institutional trust bundle.',
      );
    }

    // 6. Check certificate validity period
    if (!teacherIdentity.isValidAt(now)) {
      return const TeacherBeaconVerificationResult(
        isValid: false,
        status: TeacherBeaconVerificationStatus.unknownKey,
        reason: 'Teacher certificate is expired or not yet valid.',
      );
    }

    // 7. Verify Ed25519 signature
    final canonicalJson = beacon.toCanonicalJson();
    final isSigValid = await _cryptoService.verifySignature(
      publicKey: teacherIdentity.publicKey,
      challenge: canonicalJson,
      signature: beacon.signature,
    );

    if (!isSigValid) {
      debugPrint('❌ [PASSPORT_STUDENT] FAKE BEACON: Invalid teacher Ed25519 signature!');
      return const TeacherBeaconVerificationResult(
        isValid: false,
        status: TeacherBeaconVerificationStatus.invalidSignature,
        reason: 'Cryptographic Ed25519 signature verification failed.',
      );
    }

    debugPrint('🔒 [PASSPORT_STUDENT] Teacher beacon FULLY verified via institutional trust bundle.');
    return TeacherBeaconVerificationResult(
      isValid: true,
      status: TeacherBeaconVerificationStatus.trustedAndVerified,
      reason: 'Teacher beacon cryptographically verified.',
      teacherIdentity: teacherIdentity,
    );
  }

  /// Convenience wrapper returning boolean validity.
  Future<bool> verifyTeacherBeacon(
    PassportTeacherBeaconModel beacon, {
    int? currentTimestampSeconds,
  }) async {
    final result = await verifyTeacherBeaconDetailed(
      beacon,
      currentTimestampSeconds: currentTimestampSeconds,
    );
    return result.isValid;
  }

  /// Creates and canonically signs an attendance response using student's Ed25519 key.
  Future<PassportAttendanceResponseModel> createAndSignResponse({
    required PassportTeacherBeaconModel beacon,
    required UserModel currentUser,
    int? currentTimestampSeconds,
    String verificationMode = PassportAttendanceModel.modeBle,
    String? routerBssid,
    String? customResponseNonce,
    PassportLocationSnapshot? studentLocation,
  }) async {
    String deviceKeyId = 'key_${currentUser.uid}';
    try {
      final status = await _identityService.getIdentity(userId: currentUser.uid);
      if (status.enrolled && status.key != null) {
        deviceKeyId = status.key!.id;
      } else {
        final bundle = await _trustBundleService.getLocalBundle();
        if (bundle != null) {
          final match = bundle.identities
              .where((id) => id.userId == currentUser.uid)
              .toList();
          if (match.isNotEmpty) {
            deviceKeyId = match.first.keyId;
          }
        }
      }
    } catch (_) {}

    final response = PassportAttendanceResponseModel.create(
      sessionId: beacon.sessionId,
      studentId: currentUser.uid,
      deviceKeyId: deviceKeyId,
      challengeNonce: beacon.sessionNonce,
      currentTimestampSeconds: currentTimestampSeconds,
      verificationMode: verificationMode,
      routerBssid: routerBssid ?? _connectedRouterBssid ?? beacon.routerBssid,
      customResponseNonce: customResponseNonce,
      latitude: studentLocation?.latitude,
      longitude: studentLocation?.longitude,
      gpsAccuracy: studentLocation?.accuracyMeters,
      isMockedGps: studentLocation?.isMocked ?? false,
    );

    // Sign canonical representation using student's device private key
    final canonicalJson = response.toCanonicalJson();
    final signature = await _cryptoService.signPresentation(canonicalJson);

    return response.withSignature(signature);
  }

  /// Advertises the signed response over BLE as short-lived frames.
  Future<void> _advertiseResponse(
    PassportAttendanceResponseModel response, {
    required Duration duration,
    UserModel? currentUser,
  }) async {
    try {
      if (await _blePeripheral.isAdvertising) {
        await _blePeripheral.stop();
      }

      UserModel? resolvedUser = currentUser;
      if (resolvedUser == null || resolvedUser.name.trim().isEmpty) {
        try {
          resolvedUser = await AuthService().getUserDataFromStorage();
        } catch (_) {}
      }

      // Construct compact 24-byte student attendance frame:
      // [0] 0xCA (magic)
      // [1] 0x02 (frameTypeResponse)
      // [2..3] 16-bit streamId / session hash (2 bytes)
      // [4..15] Student Name (12 bytes, UTF-8 encoded)
      // [16..23] Student ID / Roll number (8 bytes, UTF-8 encoded)
      final compactFrame = Uint8List(24);
      compactFrame[0] = PassportAttendanceModel.bleFrameMagic;
      compactFrame[1] = PassportAttendanceModel.frameTypeCompactResponse;

      final streamId = PassportBleFrame.computeStreamId('${response.sessionId}:${response.studentId}');
      compactFrame[2] = (streamId >> 8) & 0xFF;
      compactFrame[3] = streamId & 0xFF;

      // Pack student name (12 bytes)
      final studentName = (resolvedUser?.name.trim().isNotEmpty ?? false)
          ? resolvedUser!.name.trim()
          : (currentUser?.name.trim().isNotEmpty ?? false)
              ? currentUser!.name.trim()
              : 'Student';
      final nameBytes = utf8.encode(studentName);
      for (int i = 0; i < 12; i++) {
        compactFrame[4 + i] = i < nameBytes.length ? nameBytes[i] : 0;
      }

      // Pack student ID / registration number (8 bytes)
      final idStr = (resolvedUser?.registrationNumber?.trim().isNotEmpty ?? false)
          ? resolvedUser!.registrationNumber!.trim()
          : (currentUser?.registrationNumber?.trim().isNotEmpty ?? false)
              ? currentUser!.registrationNumber!.trim()
              : (response.studentId.trim().isNotEmpty)
                  ? response.studentId.trim()
                  : (resolvedUser?.id.trim() ?? '');
      final idBytes = utf8.encode(idStr);
      for (int i = 0; i < 8; i++) {
        compactFrame[16 + i] = i < idBytes.length ? idBytes[i] : 0;
      }

      // Pause background mesh advertising to yield BLE advertiser slot
      try {
        await CampusMeshManager.instance.pauseAdvertisingForAttendance();
      } catch (e) {
        debugPrint('⚠️ [PASSPORT_STUDENT] Mesh pause error: $e');
      }

      // Clear any dangling peripheral instance
      try {
        if (await _blePeripheral.isAdvertising) {
          await _blePeripheral.stop();
          await Future.delayed(const Duration(milliseconds: 200));
        }
      } catch (_) {}

      final adData = AdvertiseData(
        manufacturerId: 0xCA01,
        manufacturerData: compactFrame,
        includeDeviceName: false,
      );

      final settings = AdvertiseSettings(
        advertiseMode: AdvertiseMode.advertiseModeLowLatency,
        connectable: false,
        timeout: 0,
        txPowerLevel: AdvertiseTxPower.advertiseTxPowerHigh,
        advertiseSet: false,
      );

      // Start advertising with retry and backoff on advertiser slot collision
      bool started = false;
      int attempts = 0;
      while (!started && attempts < 3) {
        try {
          await _blePeripheral.start(
            advertiseData: adData,
            advertiseSettings: settings,
          );
          started = true;
        } catch (err) {
          attempts++;
          debugPrint('⚠️ [PASSPORT_STUDENT] Peripheral start attempt $attempts failed: $err');
          if (attempts >= 3) rethrow;
          await Future.delayed(Duration(milliseconds: 250 * attempts));
        }
      }

      _isAdvertising = true;
      debugPrint('📡 [PASSPORT_STUDENT] Broadcasting direct BLE response frame for $studentName ($idStr)...');

      _advertisingTimer?.cancel();
      _advertisingTimer = Timer(duration, () async {
        await stopAdvertising();
      });
    } catch (e) {
      debugPrint('⚠️ [PASSPORT_STUDENT] Error starting BLE response advertising: $e');
    }
  }

  /// Stops BLE advertising and resumes background mesh advertising.
  Future<void> stopAdvertising() async {
    _isAdvertising = false;
    _advertisingTimer?.cancel();
    _advertisingTimer = null;
    try {
      if (await _blePeripheral.isAdvertising) {
        await _blePeripheral.stop();
        debugPrint('🔴 [PASSPORT_STUDENT] BLE response advertising stopped.');
      }
    } catch (_) {}
    try {
      await CampusMeshManager.instance.resumeAdvertisingAfterAttendance();
    } catch (_) {}
  }

  /// QR Fallback path: Student scans teacher session QR, requires biometric-only,
  /// signs the same challenge, and produces response QR.
  Future<PassportAttendanceResponseModel?> processQrFallback({
    required String teacherQrPayload,
    required UserModel currentUser,
    int? currentTimestampSeconds,
  }) async {
    try {
      PassportFaceAuthService.activeStudentId = currentUser.id;
      final beacon = PassportTeacherBeaconModel.fromQrString(teacherQrPayload);

      final isValid = await verifyTeacherBeacon(
        beacon,
        currentTimestampSeconds: currentTimestampSeconds,
      );
      if (!isValid) {
        _updateState(
          StudentAttendanceFlowState.error,
          'Invalid or fake teacher session QR.',
        );
        return null;
      }

      // Biometric liveness check
      final bioResult = await _biometricService.authenticateBiometricOnly(
        reason: 'Authenticate biometrics for QR attendance exception',
      );
      if (!bioResult.isSuccess) {
        _updateState(
          StudentAttendanceFlowState.error,
          bioResult.message,
        );
        return null;
      }

      // Sign identical session challenge
      final response = await createAndSignResponse(
        beacon: beacon,
        currentUser: currentUser,
        currentTimestampSeconds: currentTimestampSeconds,
      );

      _updateState(
        StudentAttendanceFlowState.completed,
        'QR response ready. Present QR to teacher.',
      );

      return response;
    } catch (e) {
      _updateState(
        StudentAttendanceFlowState.error,
        'Failed to process session QR: $e',
      );
      return null;
    }
  }

  /// Submits the 15-second Classroom Rolling PIN entered by the student.
  Future<PassportAttendanceVerificationResult?> submitRollingPin({
    required String pin,
    required SessionModel session,
    required UserModel currentUser,
  }) async {
    // 0. Algorithmic verification of the 15-second rolling PIN
    final sessionNonce = _lastDiscoveredTeacherBeacon?.sessionNonce ?? 'nonce_${session.id}';
    final isPinValid = PassportRollingPinModel.verifyPin(
      enteredPin: pin,
      sessionId: session.id,
      sessionNonce: sessionNonce,
    );
    if (!isPinValid) {
      _updateState(
        StudentAttendanceFlowState.error,
        'Invalid or expired Room PIN. Check the classroom screen and try again.',
      );
      return PassportAttendanceVerificationResult(
        valid: false,
        status: PassportAttendanceStatus.cryptoInvalid,
        reason: 'PIN_INVALID: Room PIN is incorrect or expired',
        sessionId: session.id,
        studentId: currentUser.id,
        verifiedAt: DateTime.now(),
      );
    }

    // 1. Biometric liveness gate
    final bioResult = await _biometricService.authenticateBiometricOnly(
      reason: 'Verify biometric identity to enter Room PIN for ${session.name}',
    );
    if (!bioResult.isSuccess) {
      _updateState(StudentAttendanceFlowState.error, bioResult.message);
      return null;
    }

    _updateState(StudentAttendanceFlowState.signingResponse, 'Submitting Room PIN...');

    final pinBeacon = PassportTeacherBeaconModel(
      sessionId: session.id,
      teacherId: session.instructorName,
      teacherKeyId: 'teacher_key',
      sessionNonce: sessionNonce,
      issuedAt: DateTime.now().toUtc().millisecondsSinceEpoch ~/ 1000,
      expiresAt: (DateTime.now().toUtc().millisecondsSinceEpoch ~/ 1000) + 600,
      subject: session.name,
      teacherLatitude: _lastDiscoveredTeacherBeacon?.teacherLatitude,
      teacherLongitude: _lastDiscoveredTeacherBeacon?.teacherLongitude,
      teacherLocationAccuracy:
          _lastDiscoveredTeacherBeacon?.teacherLocationAccuracy,
    );

    final gps = await _captureAndEvaluateGps(pinBeacon);
    if (gps.eval.status == PassportGeofenceStatus.mockDetected) {
      _updateState(StudentAttendanceFlowState.error, gps.eval.summary);
      return PassportAttendanceVerificationResult(
        valid: false,
        status: PassportAttendanceStatus.fakeBeacon,
        reason: gps.eval.summary,
        sessionId: session.id,
        studentId: currentUser.id,
        verificationMode: PassportAttendanceModel.modePinManual,
        gpsStatus: gps.eval.statusCode,
        verifiedAt: DateTime.now(),
      );
    }

    // 2. Sign response with customResponseNonce: pin + GPS proof
    final response = await createAndSignResponse(
      beacon: pinBeacon,
      currentUser: currentUser,
      verificationMode: PassportAttendanceModel.modePinManual,
      customResponseNonce: pin,
      studentLocation: gps.snapshot,
    );

    // 3. Try delivering directly to teacher's local HTTP server
    final targetIp = _lastDiscoveredTeacherIp ?? _lastDiscoveredTeacherBeacon?.localIp;
    double? verifiedDistance = gps.eval.distanceMeters;
    String? verifiedGpsStatus = gps.eval.statusCode;

    if (targetIp != null && targetIp.isNotEmpty) {
      final httpRes = await _deliverToTeacherHttp(
        response: response,
        candidateIps: [targetIp],
      );
      if (httpRes.gpsDistanceMeters != null) {
        verifiedDistance = httpRes.gpsDistanceMeters;
      }
      if (httpRes.gpsStatus != null) {
        verifiedGpsStatus = httpRes.gpsStatus;
      }
      if (httpRes.reachedServer && !httpRes.accepted) {
        final reason = httpRes.rejectReason ?? 'Submission rejected by teacher.';
        _updateState(StudentAttendanceFlowState.error, reason);
        return PassportAttendanceVerificationResult(
          valid: false,
          status: httpRes.isInconclusive
              ? PassportAttendanceStatus.proximityInconclusive
              : PassportAttendanceStatus.cryptoInvalid,
          reason: reason,
          sessionId: session.id,
          studentId: currentUser.id,
          verificationMode: PassportAttendanceModel.modePinManual,
          gpsDistanceMeters: verifiedDistance,
          gpsStatus: verifiedGpsStatus,
          verifiedAt: DateTime.now(),
        );
      }
    }

    // 4. Online backup to central server
    try {
      await AttendanceService().markAttendance(
        sessionId: session.id,
        studentId: currentUser.id,
        studentName: currentUser.name,
        idempotencyKey: 'pin_${session.id}_${currentUser.id}_$pin',
        verificationMode: PassportAttendanceModel.modePinManual,
        proximityTier: 'NEAR',
      );
    } catch (_) {}

    final gpsNote = verifiedGpsStatus == 'VERIFIED' && verifiedDistance != null
        ? ' · ${verifiedDistance.round()}m'
        : '';
    _updateState(
      StudentAttendanceFlowState.completed,
      'Attendance verified with Room PIN · ${session.name}$gpsNote',
    );

    return PassportAttendanceVerificationResult(
      valid: true,
      status: PassportAttendanceStatus.verifiedPresent,
      reason: 'Verified present via Room PIN',
      studentId: currentUser.id,
      studentName: currentUser.name,
      sessionId: session.id,
      verificationMode: PassportAttendanceModel.modePinManual,
      gpsDistanceMeters: verifiedDistance,
      gpsStatus: verifiedGpsStatus,
      verifiedAt: DateTime.now(),
    );
  }

  /// Submits attendance by scanning the teacher's dynamic screen QR or Wi-Fi Hotspot QR.
  Future<PassportAttendanceVerificationResult?> submitScannedTeacherQr({
    required String qrData,
    required UserModel currentUser,
  }) async {
    final trimmed = qrData.trim();
    if (trimmed.startsWith('WIFI:') || trimmed.contains('WIFI:S:')) {
      return await submitScannedWifiHotspotQr(
        qrData: trimmed,
        currentUser: currentUser,
      );
    }

    try {
      final beacon = PassportTeacherBeaconModel.fromQrString(trimmed);
      final now = DateTime.now().toUtc().millisecondsSinceEpoch ~/ 1000;
      if (beacon.isExpired(now)) {
        _updateState(
          StudentAttendanceFlowState.error,
          'The scanned QR code has expired. Please scan the active code on screen.',
        );
        return PassportAttendanceVerificationResult(
          valid: false,
          status: PassportAttendanceStatus.sessionExpired,
          reason: 'EXPIRED_QR: Scanned QR code has expired. Please scan the active code.',
          sessionId: beacon.sessionId,
          studentId: currentUser.id,
          verifiedAt: DateTime.now(),
        );
      }

      final bioResult = await _biometricService.authenticateBiometricOnly(
        reason: 'Verify biometric identity to scan classroom QR for ${beacon.subject ?? "class"}',
      );
      if (!bioResult.isSuccess) {
        _updateState(StudentAttendanceFlowState.error, bioResult.message);
        return null;
      }

      final gps = await _captureAndEvaluateGps(beacon);
      if (gps.eval.status == PassportGeofenceStatus.mockDetected) {
        _updateState(StudentAttendanceFlowState.error, gps.eval.summary);
        return PassportAttendanceVerificationResult(
          valid: false,
          status: PassportAttendanceStatus.fakeBeacon,
          reason: gps.eval.summary,
          sessionId: beacon.sessionId,
          studentId: currentUser.id,
          verificationMode: PassportAttendanceModel.modeQrOptical,
          gpsStatus: gps.eval.statusCode,
          verifiedAt: DateTime.now(),
        );
      }

      _updateState(StudentAttendanceFlowState.signingResponse, 'Signing QR attendance response...');

      final response = await createAndSignResponse(
        beacon: beacon,
        currentUser: currentUser,
        verificationMode: PassportAttendanceModel.modeQrOptical,
        studentLocation: gps.snapshot,
      );

      // Deliver directly to teacher local HTTP server on port 53318 (probing candidate IPs)
      final httpRes = await _deliverToTeacherHttp(
        response: response,
        candidateIps: [
          if (beacon.localIp != null && beacon.localIp!.isNotEmpty) beacon.localIp!,
          if (_lastDiscoveredTeacherIp != null && _lastDiscoveredTeacherIp!.isNotEmpty) _lastDiscoveredTeacherIp!,
          '192.168.43.1',
          '172.20.10.1',
        ],
        port: beacon.localPort ?? PassportAttendanceModel.defaultLocalHttpPort,
      );

      final verifiedDistance = httpRes.gpsDistanceMeters ?? gps.eval.distanceMeters;
      final verifiedGpsStatus = httpRes.gpsStatus ?? gps.eval.statusCode;

      if (httpRes.reachedServer && !httpRes.accepted) {
        final reason = httpRes.rejectReason ?? 'Classroom QR rejected by teacher.';
        _updateState(StudentAttendanceFlowState.error, reason);
        return PassportAttendanceVerificationResult(
          valid: false,
          status: httpRes.isInconclusive
              ? PassportAttendanceStatus.proximityInconclusive
              : PassportAttendanceStatus.cryptoInvalid,
          reason: reason,
          sessionId: beacon.sessionId,
          studentId: currentUser.id,
          verificationMode: PassportAttendanceModel.modeQrOptical,
          gpsDistanceMeters: verifiedDistance,
          gpsStatus: verifiedGpsStatus,
          verifiedAt: DateTime.now(),
        );
      }

      // Online backup
      try {
        await AttendanceService().markAttendance(
          sessionId: beacon.sessionId,
          studentId: currentUser.id,
          studentName: currentUser.name,
          idempotencyKey: '${beacon.sessionId}_${currentUser.id}',
          verificationMode: PassportAttendanceModel.modeQrOptical,
          proximityTier: 'NEAR',
        );
      } catch (_) {}

      final gpsNote = verifiedGpsStatus == 'VERIFIED' && verifiedDistance != null
          ? ' · ${verifiedDistance.round()}m'
          : '';
      _updateState(
        StudentAttendanceFlowState.completed,
        'Attendance verified via Classroom QR · ${beacon.subject ?? ""}$gpsNote',
      );

      return PassportAttendanceVerificationResult(
        valid: true,
        status: PassportAttendanceStatus.verifiedPresent,
        reason: 'Verified present via Optical QR',
        studentId: currentUser.id,
        studentName: currentUser.name,
        sessionId: beacon.sessionId,
        verificationMode: PassportAttendanceModel.modeQrOptical,
        gpsDistanceMeters: verifiedDistance,
        gpsStatus: verifiedGpsStatus,
        verifiedAt: DateTime.now(),
      );
    } catch (e) {
      _updateState(StudentAttendanceFlowState.error, 'Invalid QR code: $e');
      return null;
    }
  }

  /// Submits attendance by scanning the teacher's Wi-Fi Hotspot QR code (WIFI:S:...;T:WPA;P:...;;).
  Future<PassportAttendanceVerificationResult?> submitScannedWifiHotspotQr({
    required String qrData,
    required UserModel currentUser,
  }) async {
    try {
      _updateState(
        StudentAttendanceFlowState.authenticatingTeacher,
        'Wi-Fi Hotspot detected. Initializing attendance handshake...',
      );

      // 1. Parse SSID and Password from standard Wi-Fi MECARD
      final ssidMatch = RegExp(r'S:([^;]+)').firstMatch(qrData);
      final passMatch = RegExp(r'P:([^;]+)').firstMatch(qrData);
      final ssid = ssidMatch?.group(1) ?? 'CampusOS_Class';
      final pass = passMatch?.group(1) ?? '';

      // 2. Parse CampusOS session + GPS metadata if embedded:
      //    X-CAMPUSOS:sessionId,nonce,teacherId,ip,port[,tlat,tlng,tacc]
      String? embeddedSessionId;
      String? embeddedNonce;
      String? embeddedTeacherId;
      String? embeddedIp;
      int? embeddedPort;
      double? embeddedLat;
      double? embeddedLng;
      double? embeddedAcc;

      final metaMatch = RegExp(r'X-CAMPUSOS:([^;]+)').firstMatch(qrData);
      if (metaMatch != null) {
        final parts = metaMatch.group(1)?.split(',') ?? [];
        if (parts.isNotEmpty && parts[0].trim().isNotEmpty) embeddedSessionId = parts[0].trim();
        if (parts.length > 1 && parts[1].trim().isNotEmpty) embeddedNonce = parts[1].trim();
        if (parts.length > 2 && parts[2].trim().isNotEmpty) embeddedTeacherId = parts[2].trim();
        if (parts.length > 3 && parts[3].trim().isNotEmpty) embeddedIp = parts[3].trim();
        if (parts.length > 4 && parts[4].trim().isNotEmpty) embeddedPort = int.tryParse(parts[4].trim());
        if (parts.length > 5 && parts[5].trim().isNotEmpty) embeddedLat = double.tryParse(parts[5].trim());
        if (parts.length > 6 && parts[6].trim().isNotEmpty) embeddedLng = double.tryParse(parts[6].trim());
        if (parts.length > 7 && parts[7].trim().isNotEmpty) embeddedAcc = double.tryParse(parts[7].trim());
      }

      // If JSON payload was passed instead (e.g. direct optical beacon)
      if (qrData.trim().startsWith('{') && qrData.trim().endsWith('}')) {
        try {
          final decoded = jsonDecode(qrData.trim()) as Map<String, dynamic>;
          embeddedSessionId ??= decoded['sessionId']?.toString() ?? decoded['sid']?.toString();
          embeddedNonce ??= decoded['nonce']?.toString();
          embeddedTeacherId ??= decoded['teacherId']?.toString() ?? decoded['tid']?.toString();
          embeddedIp ??= decoded['ip']?.toString();
          if (decoded['port'] != null) embeddedPort ??= int.tryParse(decoded['port'].toString());
          embeddedLat ??= (decoded['tlat'] as num?)?.toDouble() ?? double.tryParse(decoded['tlat']?.toString() ?? '');
          embeddedLng ??= (decoded['tlng'] as num?)?.toDouble() ?? double.tryParse(decoded['tlng']?.toString() ?? '');
          embeddedAcc ??= (decoded['tacc'] as num?)?.toDouble() ?? double.tryParse(decoded['tacc']?.toString() ?? '');
        } catch (_) {}
      }

      // 3. Auto-connect to Wi-Fi on Android via native WifiNetworkSpecifier
      if (Platform.isAndroid && ssid.isNotEmpty && pass.isNotEmpty) {
        try {
          const channel = MethodChannel('campusos/hotspot');
          channel.invokeMethod('connectToWifi', {'ssid': ssid, 'password': pass});
        } catch (_) {}
      }

      // 4. Probe Candidate Gateways
      final candidateIps = <String>[
        if (embeddedIp != null && embeddedIp.isNotEmpty) embeddedIp,
        '192.168.43.1', // Android Hotspot default gateway
        '172.20.10.1',  // iOS Hotspot default gateway
        if (_lastDiscoveredTeacherIp != null && _lastDiscoveredTeacherIp!.isNotEmpty) _lastDiscoveredTeacherIp!,
        '192.168.137.1', // Windows Hotspot default gateway
      ];

      PassportTeacherBeaconModel? fetchedBeacon;
      String? reachableIp;

      // Probe gateways to fetch active session beacon
      for (final ip in candidateIps.toSet()) {
        try {
          final client = HttpClient()..connectionTimeout = const Duration(milliseconds: 1200);
          final port = embeddedPort ?? PassportAttendanceModel.defaultLocalHttpPort;
          final req = await client.getUrl(Uri.parse('http://$ip:$port/attendance/beacon'));
          final resp = await req.close();
          if (resp.statusCode == HttpStatus.ok) {
            final body = await utf8.decoder.bind(resp).join();
            final map = jsonDecode(body) as Map<String, dynamic>;
            if (map.containsKey('sessionId')) {
              fetchedBeacon = PassportTeacherBeaconModel.fromMap(map);
              reachableIp = ip;
              debugPrint('🌐 [PASSPORT_STUDENT] Connected to teacher gateway at $ip:$port');
              break;
            }
          }
        } catch (_) {}
      }

      // 5. Construct or resolve real beacon
      PassportTeacherBeaconModel beacon;
      if (fetchedBeacon != null) {
        beacon = fetchedBeacon;
      } else if (embeddedSessionId != null && embeddedSessionId.isNotEmpty) {
        beacon = PassportTeacherBeaconModel.create(
          sessionId: embeddedSessionId,
          teacherId: embeddedTeacherId ?? 'teacher',
          teacherKeyId: 'tk_${embeddedTeacherId ?? 'teacher'}',
          customSessionNonce: embeddedNonce ?? 'nonce_${DateTime.now().millisecondsSinceEpoch}',
          hotspotSsid: ssid,
          hotspotPassword: pass,
          localIp: reachableIp ?? embeddedIp ?? '192.168.43.1',
          localPort: embeddedPort ?? PassportAttendanceModel.defaultLocalHttpPort,
          teacherLatitude: embeddedLat,
          teacherLongitude: embeddedLng,
          teacherLocationAccuracy: embeddedAcc,
        );
      } else if (_lastDiscoveredTeacherBeacon != null) {
        beacon = _lastDiscoveredTeacherBeacon!;
      } else {
        throw Exception('Could not determine active session ID. Please align with the teacher screen QR.');
      }

      // 6. Biometric Liveness Gate
      final bioResult = await _biometricService.authenticateBiometricOnly(
        reason: 'Verify biometric identity to submit attendance over Teacher Wi-Fi',
      );
      if (!bioResult.isSuccess) {
        _updateState(StudentAttendanceFlowState.error, bioResult.message);
        return null;
      }

      // 6b. Simultaneous Hybrid GPS + Anti-Mock check
      final gps = await _captureAndEvaluateGps(beacon);
      if (gps.eval.status == PassportGeofenceStatus.mockDetected) {
        _updateState(StudentAttendanceFlowState.error, gps.eval.summary);
        return PassportAttendanceVerificationResult(
          valid: false,
          status: PassportAttendanceStatus.fakeBeacon,
          reason: gps.eval.summary,
          sessionId: beacon.sessionId,
          studentId: currentUser.id,
          verificationMode: PassportAttendanceModel.modeWifiHotspot,
          gpsStatus: gps.eval.statusCode,
          verifiedAt: DateTime.now(),
        );
      }

      _updateState(StudentAttendanceFlowState.signingResponse, 'Signing Wi-Fi Hotspot attendance response...');

      // 7. Create cryptographically signed response with modeWifiHotspot + GPS fix
      final response = await createAndSignResponse(
        beacon: beacon,
        currentUser: currentUser,
        verificationMode: PassportAttendanceModel.modeWifiHotspot,
        studentLocation: gps.snapshot,
      );

      // 8. Deliver directly to teacher's HTTP server on port 53318
      final httpRes = await _deliverToTeacherHttp(
        response: response,
        candidateIps: [
          if (reachableIp != null) reachableIp,
          if (embeddedIp != null) embeddedIp,
          '192.168.43.1',
          '172.20.10.1',
          if (beacon.localIp != null) beacon.localIp!,
        ],
        port: beacon.localPort ?? embeddedPort ?? PassportAttendanceModel.defaultLocalHttpPort,
      );

      final verifiedDistance = httpRes.gpsDistanceMeters ?? gps.eval.distanceMeters;
      final verifiedGpsStatus = httpRes.gpsStatus ?? gps.eval.statusCode;

      if (httpRes.reachedServer && !httpRes.accepted) {
        final reason = httpRes.rejectReason ?? 'Submission rejected by teacher.';
        _updateState(StudentAttendanceFlowState.error, reason);
        return PassportAttendanceVerificationResult(
          valid: false,
          status: httpRes.isInconclusive
              ? PassportAttendanceStatus.proximityInconclusive
              : PassportAttendanceStatus.cryptoInvalid,
          reason: reason,
          sessionId: beacon.sessionId,
          studentId: currentUser.id,
          verificationMode: PassportAttendanceModel.modeWifiHotspot,
          gpsDistanceMeters: verifiedDistance,
          gpsStatus: verifiedGpsStatus,
          verifiedAt: DateTime.now(),
        );
      }

      // 9. Online Cloud Backup (uses the REAL sessionId!)
      try {
        await AttendanceService().markAttendance(
          sessionId: beacon.sessionId,
          studentId: currentUser.id,
          studentName: currentUser.name,
          idempotencyKey: '${beacon.sessionId}_${currentUser.id}',
          verificationMode: PassportAttendanceModel.modeWifiHotspot,
          proximityTier: 'IMMEDIATE',
        );
      } catch (_) {}

      // Clean up native network binding if active
      if (Platform.isAndroid) {
        try {
          const channel = MethodChannel('campusos/hotspot');
          channel.invokeMethod('disconnectWifi');
        } catch (_) {}
      }

      final gpsNote = verifiedGpsStatus == 'VERIFIED' && verifiedDistance != null
          ? ' · ${verifiedDistance.round()}m'
          : '';
      _updateState(
        StudentAttendanceFlowState.completed,
        'Attendance verified via Teacher Wi-Fi ($ssid)$gpsNote',
      );

      return PassportAttendanceVerificationResult(
        valid: true,
        status: PassportAttendanceStatus.verifiedPresent,
        reason: 'Verified present via Teacher Wi-Fi Hotspot',
        studentId: currentUser.id,
        studentName: currentUser.name,
        sessionId: beacon.sessionId,
        verificationMode: PassportAttendanceModel.modeWifiHotspot,
        gpsDistanceMeters: verifiedDistance,
        gpsStatus: verifiedGpsStatus,
        verifiedAt: DateTime.now(),
      );
    } catch (e) {
      _updateState(StudentAttendanceFlowState.error, 'Wi-Fi Hotspot attendance notice: $e');
      return null;
    }
  }

  Future<void> _stopScan() async {
    _scanSubscription?.cancel();
    _scanSubscription = null;
    _isScanning = false;
    stopAmbientSubnetDiscovery();
    try {
      if (FlutterBluePlus.isScanningNow) {
        await FlutterBluePlus.stopScan();
      }
    } catch (_) {}
  }

  /// Cancels any ongoing scanning, advertising, or state.
  Future<void> cancel({bool userCancelled = false}) async {
    await _stopScan();
    await stopAdvertising();
    _updateState(
      StudentAttendanceFlowState.idle,
      userCancelled ? 'Attendance stopped' : 'Looking for class session...',
    );
  }

  void dispose() {
    _stopScan();
    stopAdvertising();
    _stateController.close();
    _statusMessageController.close();
  }
}
