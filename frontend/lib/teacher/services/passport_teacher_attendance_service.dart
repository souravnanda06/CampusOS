import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_ble_peripheral/flutter_ble_peripheral.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:device_info_plus/device_info_plus.dart';
import '../../auth/models/user_model.dart';
import '../../shared/models/session_model.dart';
import '../../student/models/passport_attendance_model.dart';
import '../../student/models/passport_proximity_config.dart';
import '../../student/models/passport_proximity_observation.dart';
import '../../student/models/passport_trust_bundle_model.dart';
import '../../student/services/passport_attendance_ledger_service.dart';
import '../../student/services/passport_crypto_service.dart';
import '../../student/services/passport_identity_service.dart';
import '../../student/services/passport_location_service.dart';
import '../../student/services/passport_trust_bundle_service.dart';
import '../../student/services/passport_offline_verifier_service.dart';
import '../../student/models/passport_verification_result.dart';
import '../../shared/services/session_service.dart';
import '../../core/mesh/campus_mesh_manager.dart';
import '../../core/network/api_client.dart';

/// Summary metrics for teacher batch attendance session.
class TeacherAttendanceMetrics {
  final int verifiedCount;
  final int inconclusiveCount;
  final int missingCount;
  final int totalRoster;
  final List<PassportAttendanceVerificationResult> verifiedStudents;
  final List<PassportAttendanceVerificationResult> inconclusiveStudents;

  const TeacherAttendanceMetrics({
    this.verifiedCount = 0,
    this.inconclusiveCount = 0,
    this.missingCount = 0,
    this.totalRoster = 0,
    this.verifiedStudents = const [],
    this.inconclusiveStudents = const [],
  });
}

/// CampusOS Passport Teacher Batch Attendance Service (Phase 1I).
///
/// Implements:
/// 1. Cryptographic session beacon generation & advertising.
/// 2. Concurrently collecting batch BLE responses.
/// 3. 100% offline local verification order in Airplane Mode.
/// 4. RSSI proximity analysis (NEAR -> Present, FAR/Unstable -> Inconclusive).
/// 5. QR Fallback exception recovery.
/// 6. Idempotent queueing and backend synchronization.
class PassportTeacherAttendanceService {
  final PassportCryptoService _cryptoService;
  final PassportTrustBundleService _trustBundleService;
  final PassportAttendanceLedgerService _ledgerService;
  final PassportIdentityService _identityService;
  final FlutterBlePeripheral _blePeripheral;
  final PassportProximityConfig _proximityConfig;
  final PassportLocationService _locationService;

  PassportTeacherBeaconModel? _activeBeacon;
  SessionModel? _activeSession;
  PassportLocationSnapshot? _teacherLocation;
  PassportLocationSnapshot? get teacherLocation => _teacherLocation;

  bool _isBroadcasting = false;
  bool _isCollecting = false;
  StreamSubscription? _bleScanSubscription;
  Timer? _beaconCycleTimer;
  Timer? _gpsRetryTimer;

  /// Map of collected BLE response frames: streamId -> List<Uint8List>.
  final Map<int, List<Uint8List>> _collectedFramesByStream = {};

  /// Map of RSSI samples per student/stream: streamId -> List<int>.
  final Map<int, List<int>> _rssiSamplesByStream = {};

  /// Active per-stream reassembly buffers: 32-bit streamId -> buffer.
  final Map<int, _StreamReassemblyBuffer> _streamBuffers = {};
  Timer? _streamCleanupTimer;
  bool _hasUserDeclinedBluetooth = false;

  /// Checks whether Bluetooth permissions are granted across Android/iOS.
  Future<bool> checkBlePermissions() async {
    try {
      if (Platform.isAndroid) {
        int sdkInt = 31;
        try {
          sdkInt = (await DeviceInfoPlugin().androidInfo).version.sdkInt;
        } catch (_) {}

        if (sdkInt >= 31) {
          final scan = await Permission.bluetoothScan.status;
          final adv = await Permission.bluetoothAdvertise.status;
          final conn = await Permission.bluetoothConnect.status;
          return (scan.isGranted || scan.isLimited) &&
                 (adv.isGranted || adv.isLimited) &&
                 (conn.isGranted || conn.isLimited);
        } else {
          final bt = await Permission.bluetooth.status;
          final loc = await Permission.locationWhenInUse.status;
          return (bt.isGranted || bt.isLimited) &&
                 (loc.isGranted || loc.isLimited);
        }
      } else if (Platform.isIOS) {
        final bt = await Permission.bluetooth.status;
        return bt.isGranted || bt.isLimited;
      }
    } catch (e) {
      debugPrint('⚠️ [PASSPORT_TEACHER] checkBlePermissions error: $e');
    }
    return false;
  }

  /// Requests Bluetooth permissions and returns true if granted.
  Future<bool> requestBlePermissions() async {
    try {
      if (Platform.isAndroid) {
        int sdkInt = 31;
        try {
          sdkInt = (await DeviceInfoPlugin().androidInfo).version.sdkInt;
        } catch (_) {}

        if (sdkInt >= 31) {
          final statuses = await [
            Permission.bluetoothScan,
            Permission.bluetoothAdvertise,
            Permission.bluetoothConnect,
          ].request();

          final scanOk = (statuses[Permission.bluetoothScan]?.isGranted ?? false) ||
              (statuses[Permission.bluetoothScan]?.isLimited ?? false);
          final advOk = (statuses[Permission.bluetoothAdvertise]?.isGranted ?? false) ||
              (statuses[Permission.bluetoothAdvertise]?.isLimited ?? false);
          final connOk = (statuses[Permission.bluetoothConnect]?.isGranted ?? false) ||
              (statuses[Permission.bluetoothConnect]?.isLimited ?? false);
          return scanOk && advOk && connOk;
        } else {
          final statuses = await [
            Permission.bluetooth,
            Permission.locationWhenInUse,
          ].request();
          final btOk = (statuses[Permission.bluetooth]?.isGranted ?? false) ||
              (statuses[Permission.bluetooth]?.isLimited ?? false);
          final locOk = (statuses[Permission.locationWhenInUse]?.isGranted ?? false) ||
              (statuses[Permission.locationWhenInUse]?.isLimited ?? false);
          return btOk && locOk;
        }
      } else if (Platform.isIOS) {
        final status = await Permission.bluetooth.request();
        return status.isGranted || status.isLimited;
      }
    } catch (e) {
      debugPrint('⚠️ [PASSPORT_TEACHER] requestBlePermissions error: $e');
    }
    return false;
  }

  String _formatBleError(dynamic e) {
    final str = e.toString();
    if (str.contains('NullPointerException')) {
      return 'Bluetooth is turned off or BLE permissions were denied.';
    }
    if (str.contains('PERMISSION_DENIED') || str.contains('SecurityException')) {
      return 'Nearby Devices Bluetooth permission is required.';
    }
    if (str.contains('ADVERTISE_FAILED_ALREADY_STARTED')) {
      return 'BLE broadcast is already active.';
    }
    if (str.contains('ADVERTISE_FAILED_FEATURE_UNSUPPORTED')) {
      return 'BLE peripheral advertising is not supported on this device.';
    }
    if (str.contains('ADVERTISE_FAILED_TOO_LARGE')) {
      return 'BLE advertising data is too large for this device.';
    }
    return str
        .replaceAll('PlatformException(', '')
        .replaceAll('Exception: ', '')
        .replaceAll(')', '')
        .trim();
  }

  /// Local session results: studentId -> result.
  final Map<String, PassportAttendanceVerificationResult> _verifiedResults = {};
  final Map<String, PassportAttendanceVerificationResult> _inconclusiveResults = {};

  /// Known student IDs in this class roster.
  final Set<String> _classRosterStudentIds = {};

  final StreamController<TeacherAttendanceMetrics> _metricsController =
      StreamController<TeacherAttendanceMetrics>.broadcast();
  Stream<TeacherAttendanceMetrics> get metricsStream => _metricsController.stream;

  String? _advertisingError;
  String? get advertisingError => _advertisingError;
  bool _isAdvertisingSupported = true;
  bool get isAdvertisingSupported => _isAdvertisingSupported;

  PassportTeacherBeaconModel? get activeBeacon => _activeBeacon;
  void setActiveBeacon(PassportTeacherBeaconModel beacon) {
    _activeBeacon = beacon;
    if (beacon.routerBssid != null && beacon.routerBssid!.isNotEmpty) {
      _classroomRouterBssid = beacon.routerBssid;
    }
  }
  bool get isBroadcasting => _isBroadcasting;
  bool get isCollecting => _isCollecting;
  Map<String, PassportAttendanceVerificationResult> get verifiedResults =>
      Map.unmodifiable(_verifiedResults);
  Map<String, PassportAttendanceVerificationResult> get inconclusiveResults =>
      Map.unmodifiable(_inconclusiveResults);

  // --- Zero-BLE & Wi-Fi LAN / Hotspot Infrastructure ---
  HttpServer? _localHttpServer;
  RawDatagramSocket? _udpBroadcastSocket;
  Timer? _udpBroadcastTimer;
  bool _isSyncingAttendance = false;
  Timer? _debounceSyncTimer;

  void _syncVerifiedAttendanceToBackend() {
    if (_activeSession == null) return;
    _debounceSyncTimer?.cancel();
    _debounceSyncTimer = Timer(const Duration(milliseconds: 500), () async {
      if (_isSyncingAttendance) return;
      _isSyncingAttendance = true;
      try {
        await syncAttendance();
      } catch (e) {
        debugPrint('ℹ️ [PASSPORT_TEACHER] Opportunistic backend sync deferred to ledger queue: $e');
      } finally {
        _isSyncingAttendance = false;
      }
    });
  }

  Future<void> _syncBeaconToBackend(
    String sessionId,
    PassportTeacherBeaconModel beacon,
  ) async {
    try {
      final body = {
        'sessionId': sessionId,
        'sessionNonce': beacon.sessionNonce,
        'latitude': beacon.teacherLatitude,
        'longitude': beacon.teacherLongitude,
        'radiusMeters': 20.0,
        'beaconPayload': beacon.toCanonicalJson(),
      };
      await ApiClient.instance.post(
        '/sessions/$sessionId/beacon',
        body: body,
      );
      debugPrint('📍 [PASSPORT_TEACHER] Synced session beacon & GPS anchor to backend ($sessionId, lat=${beacon.teacherLatitude}, lng=${beacon.teacherLongitude})');
    } catch (e) {
      debugPrint('⚠️ [PASSPORT_TEACHER] Failed syncing beacon to backend: $e');
    }
  }

  String? _classroomRouterBssid;
  String? get classroomRouterBssid => _classroomRouterBssid;
  void setClassroomRouterBssid(String? bssid) {
    _classroomRouterBssid = bssid;
    if (_activeBeacon != null) {
      _activeBeacon = _activeBeacon!.copyWith(routerBssid: bssid);
    }
  }

  // --- 15-Second Rolling PIN ---
  String get currentRollingPin {
    if (_activeBeacon == null) return '----';
    return PassportRollingPinModel.generatePin(
      sessionId: _activeBeacon!.sessionId,
      sessionNonce: _activeBeacon!.sessionNonce,
    );
  }

  int get rollingPinRemainingSeconds => PassportRollingPinModel.getRemainingSeconds();
  double get rollingPinProgress => PassportRollingPinModel.getProgress();

  // --- 60-Second Ephemeral Hotspot Burst & Multi-Option Real Wi-Fi ---
  static const MethodChannel _hotspotChannel = MethodChannel('campusos/hotspot');

  bool _isHotspotActive = false;
  bool get isHotspotActive => _isHotspotActive;
  int _hotspotRemainingSeconds = 0;
  int get hotspotRemainingSeconds => _hotspotRemainingSeconds;
  String? _hotspotSsid;
  String? get hotspotSsid => _hotspotSsid;
  String? _hotspotPassword;
  String? get hotspotPassword => _hotspotPassword;
  Timer? _hotspotBurstTimer;
  Timer? _hotspotPollTimer;

  bool _isNativeHotspot = false;
  bool get isNativeHotspot => _isNativeHotspot;

  bool _isHardwareHotspotDetected = false;
  bool get isHardwareHotspotDetected => _isHardwareHotspotDetected;

  String? _detectedGatewayIp;
  String? get detectedGatewayIp => _detectedGatewayIp;

  bool _isLanWifiDetected = false;
  bool get isLanWifiDetected => _isLanWifiDetected;

  String? _lanWifiIp;
  String? get lanWifiIp => _lanWifiIp;

  String? _savedHotspotSsid;
  String? get savedHotspotSsid => _savedHotspotSsid;
  String? _savedHotspotPassword;
  String? get savedHotspotPassword => _savedHotspotPassword;
  String? _lastHotspotError;
  String? get lastHotspotError => _lastHotspotError;

  /// Opens Android Tethering / Hotspot settings page directly.
  Future<bool> openHotspotSettings() async {
    try {
      if (Platform.isAndroid) {
        final res = await _hotspotChannel.invokeMethod<bool>('openHotspotSettings');
        return res ?? false;
      }
    } catch (e) {
      debugPrint('⚠️ [PASSPORT_TEACHER] openHotspotSettings error: $e');
    }
    return false;
  }

  /// Loads saved teacher hotspot profile credentials (Option A).
  Future<void> loadSavedHotspotCredentials() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _savedHotspotSsid = prefs.getString('teacher_saved_hotspot_ssid');
      _savedHotspotPassword = prefs.getString('teacher_saved_hotspot_password');

      if (_savedHotspotSsid == null || _savedHotspotSsid!.isEmpty) {
        String defaultName = 'Teacher_Hotspot';
        try {
          final deviceInfo = DeviceInfoPlugin();
          if (Platform.isAndroid) {
            final androidInfo = await deviceInfo.androidInfo;
            defaultName = 'Hotspot_${androidInfo.model.replaceAll(' ', '_')}';
          } else if (Platform.isIOS) {
            final iosInfo = await deviceInfo.iosInfo;
            defaultName = 'Hotspot_${iosInfo.name.replaceAll(' ', '_')}';
          }
        } catch (_) {}
        _savedHotspotSsid = defaultName;
        _savedHotspotPassword = 'pass${Random.secure().nextInt(899999) + 100000}';
        await prefs.setString('teacher_saved_hotspot_ssid', _savedHotspotSsid!);
        await prefs.setString('teacher_saved_hotspot_password', _savedHotspotPassword!);
      }
    } catch (e) {
      _savedHotspotSsid ??= 'Teacher_Hotspot';
      _savedHotspotPassword ??= 'pass123456';
    }
    _hotspotSsid = _savedHotspotSsid;
    _hotspotPassword = _savedHotspotPassword;
  }

  /// Saves custom teacher hotspot profile credentials (Option A).
  Future<void> saveHotspotCredentials(String ssid, String password) async {
    _savedHotspotSsid = ssid.trim();
    _savedHotspotPassword = password.trim();
    _hotspotSsid = _savedHotspotSsid;
    _hotspotPassword = _savedHotspotPassword;

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('teacher_saved_hotspot_ssid', _savedHotspotSsid!);
      await prefs.setString('teacher_saved_hotspot_password', _savedHotspotPassword!);
    } catch (_) {}

    if (_activeBeacon != null) {
      _activeBeacon = _activeBeacon!.copyWith(
        hotspotSsid: _hotspotSsid,
        hotspotPassword: _hotspotPassword,
      );
    }
    _emitMetrics();
  }

  /// Starts native Android LocalOnlyHotspot (Option C).
  Future<bool> startNativeLocalOnlyHotspot() async {
    if (!Platform.isAndroid) return false;
    try {
      _lastHotspotError = null;
      // Request location and nearby wifi permissions if on Android
      try {
        await [
          Permission.location,
          Permission.nearbyWifiDevices,
        ].request();
      } catch (_) {}

      final res = await _hotspotChannel.invokeMapMethod<String, dynamic>('startLocalOnlyHotspot');
      if (res != null && res['success'] == true) {
        final ssid = res['ssid']?.toString() ?? '';
        final pass = res['password']?.toString() ?? '';
        if (ssid.isNotEmpty) {
          _hotspotSsid = ssid;
          _hotspotPassword = pass;
          _isNativeHotspot = true;
          _isHardwareHotspotDetected = true;
          _detectedGatewayIp = '192.168.43.1';
          if (_activeBeacon != null) {
            _activeBeacon = _activeBeacon!.copyWith(
              hotspotSsid: _hotspotSsid,
              hotspotPassword: _hotspotPassword,
            );
          }
          _emitMetrics();
          debugPrint('⚡ [PASSPORT_TEACHER] Native LocalOnlyHotspot active: SSID $ssid');
          return true;
        }
      }
    } catch (e) {
      final msg = e is PlatformException ? (e.message ?? e.toString()) : e.toString();
      _lastHotspotError = msg;
      debugPrint('ℹ️ [PASSPORT_TEACHER] LocalOnlyHotspot error: $msg');
    }
    return false;
  }

  /// Stops native Android LocalOnlyHotspot.
  Future<void> stopNativeLocalOnlyHotspot() async {
    if (!Platform.isAndroid) return;
    try {
      await _hotspotChannel.invokeMethod('stopLocalOnlyHotspot');
      _isNativeHotspot = false;
    } catch (_) {}
  }

  /// Checks whether hardware hotspot interface (ap0, 192.168.43.1, 172.20.10.1) or LAN Wi-Fi is active.
  Future<void> checkHardwareHotspotActive() async {
    try {
      final interfaces = await NetworkInterface.list(type: InternetAddressType.IPv4);
      bool hotspotFound = _isNativeHotspot;
      String? gateway;
      bool lanFound = false;
      String? lanIp;

      for (final iface in interfaces) {
        final name = iface.name.toLowerCase();
        final isTetherIface = name.startsWith('ap') ||
            name.startsWith('swlan') ||
            name.startsWith('softap') ||
            name.contains('tether') ||
            name.startsWith('rndis');

        for (final addr in iface.addresses) {
          if (addr.isLoopback) continue;
          if (addr.address == '192.168.43.1' || addr.address == '172.20.10.1' || (isTetherIface && !addr.isLoopback)) {
            hotspotFound = true;
            gateway = addr.address;
          } else if (name.contains('wlan') || name.contains('wi-fi') || name.contains('en')) {
            lanFound = true;
            lanIp = addr.address;
          }
        }
      }

      _isHardwareHotspotDetected = hotspotFound;
      _detectedGatewayIp = gateway ?? (hotspotFound ? '192.168.43.1' : null);
      _isLanWifiDetected = lanFound;
      _lanWifiIp = lanIp;
    } catch (_) {}
  }

  /// Starts a 60-second ephemeral hotspot burst with automatic countdown and termination.
  Future<void> startHotspotBurst({bool tryNativeFirst = true}) async {
    if (_activeBeacon == null) return;
    _isHotspotActive = true;
    _hotspotRemainingSeconds = 60;

    await loadSavedHotspotCredentials();

    bool nativeStarted = false;
    if (tryNativeFirst) {
      nativeStarted = await startNativeLocalOnlyHotspot();
    }

    if (!nativeStarted) {
      _isNativeHotspot = false;
      await checkHardwareHotspotActive();
      _hotspotSsid = _savedHotspotSsid;
      _hotspotPassword = _savedHotspotPassword;
    }

    _activeBeacon = _activeBeacon!.copyWith(
      hotspotSsid: _hotspotSsid,
      hotspotPassword: _hotspotPassword,
    );

    if (_localHttpServer == null) {
      await _startLocalHttpServer();
    }

    _hotspotBurstTimer?.cancel();
    _hotspotBurstTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_hotspotRemainingSeconds > 0) {
        _hotspotRemainingSeconds--;
        _emitMetrics();
      } else {
        stopHotspotBurst();
      }
    });

    // Start background poll to detect when teacher toggles Hotspot switch ON in Quick Settings
    _hotspotPollTimer?.cancel();
    _hotspotPollTimer = Timer.periodic(const Duration(milliseconds: 1500), (_) async {
      if (!_isHotspotActive) return;
      final prevDetected = _isHardwareHotspotDetected;
      await checkHardwareHotspotActive();
      if (_isHardwareHotspotDetected != prevDetected) {
        _emitMetrics();
      }
    });

    _emitMetrics();
    debugPrint('🔥 [PASSPORT_TEACHER] Ephemeral Hotspot Burst active (Native: $_isNativeHotspot, Hardware: $_isHardwareHotspotDetected, SSID: $_hotspotSsid)');
  }

  /// Manually stops ephemeral hotspot burst.
  void stopHotspotBurst() {
    _isHotspotActive = false;
    _hotspotRemainingSeconds = 0;
    _hotspotBurstTimer?.cancel();
    _hotspotBurstTimer = null;
    _hotspotPollTimer?.cancel();
    _hotspotPollTimer = null;

    if (_isNativeHotspot) {
      stopNativeLocalOnlyHotspot();
    }

    if (!_isBroadcasting) {
      _localHttpServer?.close(force: true);
      _localHttpServer = null;
    }
    debugPrint('🛑 [PASSPORT_TEACHER] Ephemeral Hotspot Burst terminated.');
    _emitMetrics();
  }

  /// Verifies a student submitting the 15-second Classroom Rolling PIN manually.
  Future<PassportAttendanceVerificationResult> verifyStudentPin({
    required String studentId,
    required String studentName,
    required String pin,
    double? studentLatitude,
    double? studentLongitude,
    double? studentAccuracy,
    bool isMockedGps = false,
  }) async {
    if (_activeBeacon == null) {
      return PassportAttendanceVerificationResult(
        valid: false,
        status: PassportAttendanceStatus.sessionExpired,
        reason: 'No active attendance session.',
        verifiedAt: DateTime.now(),
      );
    }

    final isValid = PassportRollingPinModel.verifyPin(
      enteredPin: pin,
      sessionId: _activeBeacon!.sessionId,
      sessionNonce: _activeBeacon!.sessionNonce,
    );

    if (!isValid) {
      return PassportAttendanceVerificationResult(
        valid: false,
        status: PassportAttendanceStatus.cryptoInvalid,
        reason: 'Invalid or expired room PIN.',
        studentId: studentId,
        studentName: studentName,
        sessionId: _activeBeacon!.sessionId,
        verificationMode: PassportAttendanceModel.modePinManual,
        verifiedAt: DateTime.now(),
      );
    }

    final gpsEval = PassportLocationService.evaluate(
      teacherLatitude: _activeBeacon!.teacherLatitude ?? _teacherLocation?.latitude,
      teacherLongitude: _activeBeacon!.teacherLongitude ?? _teacherLocation?.longitude,
      teacherAccuracyMeters:
          _activeBeacon!.teacherLocationAccuracy ?? _teacherLocation?.accuracyMeters,
      studentLatitude: studentLatitude,
      studentLongitude: studentLongitude,
      studentAccuracyMeters: studentAccuracy,
      studentIsMocked: isMockedGps,
    );

    if (gpsEval.status == PassportGeofenceStatus.mockDetected) {
      return PassportAttendanceVerificationResult(
        valid: false,
        status: PassportAttendanceStatus.fakeBeacon,
        reason: gpsEval.summary,
        studentId: studentId,
        studentName: studentName,
        sessionId: _activeBeacon!.sessionId,
        verificationMode: PassportAttendanceModel.modePinManual,
        gpsDistanceMeters: gpsEval.distanceMeters,
        gpsStatus: gpsEval.statusCode,
        verifiedAt: DateTime.now(),
      );
    }

    if (gpsEval.status == PassportGeofenceStatus.outsideReview) {
      final inconclusive = PassportAttendanceVerificationResult(
        valid: false,
        status: PassportAttendanceStatus.proximityInconclusive,
        reason: gpsEval.summary,
        studentId: studentId,
        studentName: studentName,
        deviceKeyId: 'pin_$studentId',
        sessionId: _activeBeacon!.sessionId,
        responseNonce: pin,
        idempotencyKey: 'pin_${_activeBeacon!.sessionId}_$studentId',
        proximityTier: PassportProximityTier.far,
        verificationMode: PassportAttendanceModel.modePinManual,
        gpsDistanceMeters: gpsEval.distanceMeters,
        gpsStatus: gpsEval.statusCode,
        verifiedAt: DateTime.now(),
      );
      _inconclusiveResults[studentId] = inconclusive;
      _emitMetrics();
      return inconclusive;
    }

    if (_ledgerService.isStudentRecorded(_activeBeacon!.sessionId, studentId)) {
      return PassportAttendanceVerificationResult(
        valid: false,
        status: PassportAttendanceStatus.replayedResponse,
        reason: 'Attendance already recorded for this student.',
        studentId: studentId,
        studentName: studentName,
        sessionId: _activeBeacon!.sessionId,
        verificationMode: PassportAttendanceModel.modePinManual,
        verifiedAt: DateTime.now(),
      );
    }

    final res = PassportAttendanceVerificationResult(
      valid: true,
      status: PassportAttendanceStatus.verifiedPresent,
      reason: 'Verified present via Classroom Rolling PIN',
      studentId: studentId,
      studentName: studentName,
      deviceKeyId: 'pin_$studentId',
      sessionId: _activeBeacon!.sessionId,
      responseNonce: pin,
      idempotencyKey: 'pin_${_activeBeacon!.sessionId}_$studentId',
      proximityTier: PassportProximityTier.near,
      verificationMode: PassportAttendanceModel.modePinManual,
      gpsDistanceMeters: gpsEval.distanceMeters,
      gpsStatus: gpsEval.statusCode,
      verifiedAt: DateTime.now(),
    );

    await _ledgerService.recordAttendance(res);
    _verifiedResults[studentId] = res;
    _inconclusiveResults.remove(studentId);
    _emitMetrics();
    return res;
  }

  Future<void> pauseBeaconAdvertising() async {
    _isBroadcasting = false;
    try {
      await _blePeripheral.stop();
    } catch (_) {}
    try {
      await CampusMeshManager.instance.resumeAdvertisingAfterAttendance();
    } catch (_) {}
  }

  Future<void> resumeBeaconAdvertising() async {
    if (_activeBeacon != null) {
      await _startBeaconAdvertising(_activeBeacon!);
    }
  }

  PassportTeacherAttendanceService({
    PassportCryptoService? cryptoService,
    PassportTrustBundleService? trustBundleService,
    PassportAttendanceLedgerService? ledgerService,
    PassportIdentityService? identityService,
    FlutterBlePeripheral? blePeripheral,
    PassportProximityConfig? proximityConfig,
    PassportLocationService? locationService,
  })  : _cryptoService = cryptoService ?? PassportCryptoService(),
        _trustBundleService = trustBundleService ?? PassportTrustBundleService(),
        _ledgerService = ledgerService ?? PassportAttendanceLedgerService(),
        _identityService = identityService ?? PassportIdentityService(),
        _blePeripheral = blePeripheral ?? FlutterBlePeripheral(),
        _proximityConfig = proximityConfig ?? PassportProximityConfig.defaultConfig,
        _locationService = locationService ?? const PassportLocationService();

  /// Starts the batch attendance session:
  /// 1. Creates teacher beacon with cryptographically random session nonce.
  /// 2. Signs beacon using teacher's Passport key.
  /// 3. Advertises beacon over BLE.
  /// 4. Starts scanning for student response frames.
  Future<PassportTeacherBeaconModel> startBatchAttendance({
    required UserModel teacher,
    required SessionModel session,
    int? currentTimestampSeconds,
  }) async {
    _activeSession = session;
    _verifiedResults.clear();
    _inconclusiveResults.clear();
    _collectedFramesByStream.clear();
    _rssiSamplesByStream.clear();
    _streamBuffers.clear();
    _startStreamCleanupTimer();

    // Load roster from trust bundle if available
    await _loadClassRoster(session);

    // Restore previously queued verified results for this session from offline ledger
    await restoreQueuedResults(session.id);

    // Request BLE permissions
    final bool permissionsGranted = await requestBlePermissions();

    bool isBleOn = false;
    if (permissionsGranted) {
      try {
        final isSupported = await FlutterBluePlus.isSupported;
        if (isSupported) {
          var adapterState = await FlutterBluePlus.adapterState.first
              .timeout(const Duration(seconds: 1), onTimeout: () => BluetoothAdapterState.unknown);
          if (adapterState == BluetoothAdapterState.on) {
            isBleOn = true;
          } else if (!_hasUserDeclinedBluetooth) {
            try {
              await FlutterBluePlus.turnOn();
              adapterState = await FlutterBluePlus.adapterState.first
                  .timeout(const Duration(seconds: 2), onTimeout: () => BluetoothAdapterState.off);
              if (adapterState == BluetoothAdapterState.on) {
                isBleOn = true;
              } else {
                _hasUserDeclinedBluetooth = true;
              }
            } catch (_) {
              _hasUserDeclinedBluetooth = true;
            }
          }
        }
      } catch (e) {
        debugPrint('⚠️ [PASSPORT_TEACHER] Adapter check notice: $e');
      }
    } else {
      debugPrint('⚠️ [PASSPORT_TEACHER] BLE permissions denied. Running in Zero-BLE mode.');
    }

    // 1. Resolve teacher keyId — used as an identifier in the beacon.
    //    Teachers are NOT enrolled in Passport (student-only), so this keyId
    //    will NOT be in the trust bundle. Students accept teacher beacons
    //    via structural validation. The keyId is purely for traceability.
    String teacherKeyId = 'teacher_key_${teacher.uid}';
    try {
      // Try trust bundle first (future-proof: if institution later enrolls teachers)
      final bundle = await _trustBundleService.getLocalBundle();
      if (bundle != null) {
        final match = bundle.identities
            .where((id) => id.userId == teacher.uid && id.status == 'ACTIVE')
            .toList();
        if (match.isNotEmpty) {
          teacherKeyId = match.first.keyId;
          debugPrint('🔑 [PASSPORT_TEACHER] Resolved keyId from trust bundle: $teacherKeyId');
        }
      }
    } catch (_) {}

    // Fallback: use cached enrollment keyId if Passport was activated for this teacher
    if (teacherKeyId == 'teacher_key_${teacher.uid}') {
      try {
        final cached = await _identityService.getCachedIdentity();
        if (cached != null && cached.enrolled && cached.key != null && cached.key!.id.isNotEmpty) {
          teacherKeyId = cached.key!.id;
          debugPrint('🔑 [PASSPORT_TEACHER] Resolved keyId from cached enrollment: $teacherKeyId');
        }
      } catch (_) {}
    }

    // 2. Discover local IP address & capture teacher reference GPS concurrently
    final localIpFuture = _getLocalIpAddress();
    final gpsFuture = _locationService.captureSnapshot(
      timeout: const Duration(seconds: 2),
    );
    final localIp = await localIpFuture;
    _teacherLocation = await gpsFuture;
    if (_teacherLocation != null) {
      debugPrint(
        '📍 [PASSPORT_TEACHER] Teacher reference GPS anchored: '
        '(${_teacherLocation!.latitude}, ${_teacherLocation!.longitude}) '
        '±${_teacherLocation!.accuracyMeters}m',
      );
    }

    // 3. Generate teacher beacon bound deterministically to this session ID
    final beacon = PassportTeacherBeaconModel.create(
      sessionId: session.id,
      teacherId: teacher.uid,
      teacherKeyId: teacherKeyId,
      course: session.course,
      branch: session.branch,
      year: session.year,
      subject: session.name,
      validity: const Duration(minutes: 15),
      currentTimestampSeconds: currentTimestampSeconds,
      customSessionNonce: 'nonce_${session.id}',
      routerBssid: _classroomRouterBssid,
      localIp: localIp,
      localPort: PassportAttendanceModel.defaultLocalHttpPort,
      hotspotSsid: _isHotspotActive ? _hotspotSsid : null,
      hotspotPassword: _isHotspotActive ? _hotspotPassword : null,
      teacherLatitude: _teacherLocation?.latitude,
      teacherLongitude: _teacherLocation?.longitude,
      teacherLocationAccuracy: _teacherLocation?.accuracyMeters,
    );

    // 4. Sign beacon canonically with teacher's Ed25519 key
    final hasKey = await _cryptoService.hasIdentityKey();
    if (!hasKey) {
      await _cryptoService.getOrCreatePublicKey();
    }
    final canonicalJson = beacon.toCanonicalJson();
    final signature = await _cryptoService.signPresentation(canonicalJson);
    _activeBeacon = beacon.withSignature(signature);

    // Sync session beacon & teacher reference GPS anchor to cloud backend
    unawaited(_syncBeaconToBackend(session.id, _activeBeacon!));

    // Lazy background GPS retry once if initial indoor lock wasn't ready
    _gpsRetryTimer?.cancel();
    if (_teacherLocation == null) {
      _gpsRetryTimer = Timer(const Duration(seconds: 4), () async {
        if (_activeBeacon == null || _metricsController.isClosed) return;
        final snap = await _locationService.captureSnapshot(
          timeout: const Duration(seconds: 3),
        );
        if (snap != null && _activeBeacon != null && !_metricsController.isClosed) {
          _teacherLocation = snap;
          final updated = _activeBeacon!.copyWith(
            teacherLatitude: snap.latitude,
            teacherLongitude: snap.longitude,
            teacherLocationAccuracy: snap.accuracyMeters,
          );
          final sig = await _cryptoService.signPresentation(updated.toCanonicalJson());
          _activeBeacon = updated.withSignature(sig);
          unawaited(_syncBeaconToBackend(session.id, _activeBeacon!));
          _emitMetrics();
        }
      });
    }

    // 5. Start advertising teacher beacon frames over BLE (if permitted and Bluetooth is ready)
    if (permissionsGranted && isBleOn) {
      await _startBeaconAdvertising(_activeBeacon!);
      // 6. Start concurrent batch scanner to capture direct BLE radio frames from students (offline & online)
      await startBatchCollection();
    } else {
      _isBroadcasting = false;
      if (!permissionsGranted) {
        _advertisingError = "Bluetooth permissions denied. Enable Nearby Devices in Settings.";
      } else {
        _advertisingError = "Bluetooth is turned off. Please turn on Bluetooth to broadcast beacon.";
      }
      debugPrint('ℹ️ [PASSPORT_TEACHER] BLE radio skipped ($_advertisingError). Zero-BLE & Wi-Fi LAN active.');
    }

    // 7. Start local offline HTTP server on port 53318 for Zero-BLE / Wi-Fi LAN / Hotspot attendance
    await _startLocalHttpServer();

    // 8. Start Wi-Fi UDP multicast broadcaster on port 53317 for automatic campus subnet discovery
    await _startUdpBroadcasting();

    _emitMetrics();
    return _activeBeacon!;
  }

  /// Restores locally queued attendance results from offline ledger to populate UI on restart/resume.
  Future<void> restoreQueuedResults(String sessionId) async {
    try {
      final queued = await _ledgerService.getQueuedRecords(sessionId);
      for (final q in queued) {
        final sId = q['studentId']?.toString();
        if (sId != null && sId.isNotEmpty && !_verifiedResults.containsKey(sId)) {
          final res = PassportAttendanceVerificationResult(
            valid: true,
            status: PassportAttendanceStatus.verifiedPresent,
            reason: 'Restored from local offline ledger',
            studentId: sId,
            studentName: (q['studentName']?.toString().trim().isNotEmpty ?? false)
                ? q['studentName']!.toString().trim()
                : 'Student ${sId.substring(0, min(6, sId.length))}',
            deviceKeyId: q['deviceKeyId']?.toString() ?? '',
            sessionId: sessionId,
            responseNonce: q['responseNonce']?.toString() ?? '',
            idempotencyKey: q['idempotencyKey']?.toString(),
            proximityTier: PassportProximityTier.values.firstWhere(
              (p) => p.code == q['proximityTier']?.toString(),
              orElse: () => PassportProximityTier.near,
            ),
            verificationMode: q['verificationMode']?.toString() ?? 'BLE_BATCH',
            verifiedAt: DateTime.tryParse(q['checkInTime']?.toString() ?? '') ?? DateTime.now(),
            gpsDistanceMeters: (q['gpsDistanceMeters'] as num?)?.toDouble() ??
                double.tryParse(q['gpsDistanceMeters']?.toString() ?? ''),
            gpsStatus: q['gpsStatus']?.toString(),
          );
          _verifiedResults[sId] = res;
        }
      }
    } catch (e) {
      debugPrint('⚠️ [PASSPORT_TEACHER] Error restoring queued records: $e');
    }
  }

  /// Populates the class roster from cached trust bundle identities.
  Future<void> _loadClassRoster(SessionModel session) async {
    _classRosterStudentIds.clear();
    try {
      var bundle = await _trustBundleService.getLocalBundle();
      if (bundle == null) {
        try {
          bundle = await _trustBundleService.downloadAndSaveBundle();
        } catch (_) {}
      }
      if (bundle != null) {
        for (final id in bundle.identities) {
          if (id.status == 'ACTIVE') {
            _classRosterStudentIds.add(id.userId);
          }
        }
      }
    } catch (_) {}
  }

  /// Advertises the teacher beacon over BLE.
  Future<void> _startBeaconAdvertising(PassportTeacherBeaconModel beacon) async {
    try {
      final permsOk = await checkBlePermissions();
      if (!permsOk) {
        _isBroadcasting = false;
        _advertisingError = "Bluetooth permissions denied. Enable Nearby Devices in Settings.";
        return;
      }

      try {
        var adapterState = await FlutterBluePlus.adapterState.first
            .timeout(const Duration(milliseconds: 500), onTimeout: () => BluetoothAdapterState.unknown);
        if (adapterState != BluetoothAdapterState.on && adapterState != BluetoothAdapterState.unknown) {
          _isBroadcasting = false;
          _advertisingError = "Bluetooth is turned off. Please turn on Bluetooth.";
          return;
        }
      } catch (_) {}

      final isSupp = await _blePeripheral.isSupported;
      if (!isSupp) {
        _isAdvertisingSupported = false;
        _advertisingError = "Device does not support BLE Peripheral advertising.";
        _isBroadcasting = false;
        debugPrint('⚠️ [PASSPORT_TEACHER] $_advertisingError');
        return;
      }
      _isAdvertisingSupported = true;

      // 1. Cooperative yield: pause background mesh advertising so hardware advertiser slot is free
      await CampusMeshManager.instance.pauseAdvertisingForAttendance();

      // 2. Ensure any previous broadcast is stopped and give Android Bluetooth stack a breather
      try {
        await _blePeripheral.stop();
      } catch (_) {}
      await Future.delayed(const Duration(milliseconds: 250));

      final formattedUuid = SessionService.formatSessionBleUuid(beacon.sessionId);
      final adData = AdvertiseData(
        serviceUuid: formattedUuid,
        localName: "",
        includeDeviceName: false,
      );

      final settings = AdvertiseSettings(
        advertiseMode: AdvertiseMode.advertiseModeLowLatency,
        connectable: true,
        timeout: 0,
        txPowerLevel: AdvertiseTxPower.advertiseTxPowerHigh,
        advertiseSet: false,
      );

      bool started = false;
      String? lastErr;
      for (int attempt = 1; attempt <= 3; attempt++) {
        try {
          await _blePeripheral.start(
            advertiseData: adData,
            advertiseSettings: settings,
          );
          started = true;
          break;
        } catch (e) {
          lastErr = _formatBleError(e);
          debugPrint('⚠️ [PASSPORT_TEACHER] Teacher advertiser attempt $attempt failed: $e');
          if (attempt < 3) {
            try {
              await _blePeripheral.stop();
            } catch (_) {}
            await CampusMeshManager.instance.pauseAdvertisingForAttendance();
            await Future.delayed(Duration(milliseconds: 300 * attempt));
          }
        }
      }

      if (started) {
        _isBroadcasting = true;
        _advertisingError = null;
        debugPrint('📡 [PASSPORT_TEACHER] Teacher beacon advertising started for session: ${beacon.sessionId} (UUID: $formattedUuid)');
      } else {
        _isBroadcasting = false;
        _advertisingError = lastErr;
        debugPrint('⚠️ [PASSPORT_TEACHER] Teacher advertising error after 3 attempts: $lastErr');
      }
    } catch (e) {
      _isBroadcasting = false;
      _advertisingError = _formatBleError(e);
      debugPrint('⚠️ [PASSPORT_TEACHER] Teacher advertising error: $e');
    }
  }

  /// Retries teacher beacon advertising (e.g. after radio contention is cleared).
  Future<void> retryBeaconAdvertising() async {
    if (_activeBeacon == null) return;
    _advertisingError = null;

    bool permsOk = await checkBlePermissions();
    if (!permsOk) {
      permsOk = await requestBlePermissions();
      if (!permsOk) {
        _isBroadcasting = false;
        _advertisingError = "Bluetooth permissions denied. Enable Nearby Devices in Settings.";
        _emitMetrics();
        return;
      }
    }

    try {
      var adapterState = await FlutterBluePlus.adapterState.first
          .timeout(const Duration(seconds: 1), onTimeout: () => BluetoothAdapterState.unknown);
      if (adapterState != BluetoothAdapterState.on) {
        try {
          await FlutterBluePlus.turnOn();
          adapterState = await FlutterBluePlus.adapterState.first
              .timeout(const Duration(seconds: 2), onTimeout: () => BluetoothAdapterState.off);
        } catch (_) {}
      }
      if (adapterState != BluetoothAdapterState.on) {
        _isBroadcasting = false;
        _advertisingError = "Bluetooth is turned off. Please turn on Bluetooth.";
        _emitMetrics();
        return;
      }
    } catch (_) {}

    await _startBeaconAdvertising(_activeBeacon!);
    if (_isBroadcasting && !_isCollecting) {
      await startBatchCollection();
    }
    _emitMetrics();
  }

  /// Starts concurrent batch collection of student responses.
  Future<void> startBatchCollection({Duration? timeout}) async {
    _stopCollection();

    final permsOk = await checkBlePermissions();
    if (!permsOk) {
      debugPrint('⚠️ [PASSPORT_TEACHER] Skipping BLE scan: permissions not granted.');
      return;
    }

    _isCollecting = true;
    _startStreamCleanupTimer();

    try {
      final scanDuration = timeout ?? const Duration(minutes: 15);
      await FlutterBluePlus.startScan(
        timeout: scanDuration,
        androidScanMode: AndroidScanMode.lowLatency,
        androidUsesFineLocation: true,
        continuousUpdates: true,
      );

      _bleScanSubscription = FlutterBluePlus.scanResults.listen((results) {
        if (!_isCollecting) return;

        for (final r in results) {
          final ad = r.advertisementData;

          for (final entry in ad.manufacturerData.entries) {
            final bytes = Uint8List.fromList(entry.value);
            handleIncomingBleFrame(bytes, r.rssi);
          }
        }
      });

      debugPrint('🔍 [PASSPORT_TEACHER] Batch BLE response collection active (lowLatency continuous)...');
    } catch (e) {
      _isCollecting = false;
      debugPrint('⚠️ [PASSPORT_TEACHER] Scan error: $e');
    }
  }

  /// Ingests and processes an incoming BLE advertisement manufacturer data frame.
  ///
  /// Features:
  /// - Extracts 32-bit streamId (2^32 entropy, collision-resistant).
  /// - Deduplicates fragments by frameIndex.
  /// - Buffers per streamId, isolating concurrent student streams.
  /// - Triggers offline verification immediately once all sequenced frames arrive.
  /// - Discards duplicate frames arriving after completed verification.
  Future<void> handleIncomingBleFrame(Uint8List bytes, int rssi) async {
    if (bytes.length < 4 ||
        bytes[0] != PassportAttendanceModel.bleFrameMagic) {
      return;
    }

    final frameType = bytes[1];
    if (frameType != PassportAttendanceModel.frameTypeResponse &&
        frameType != PassportAttendanceModel.frameTypeCompactResponse) {
      return;
    }

    // 1. Sequenced multi-frame response check (PassportBleFrame with 8-byte header):
    // [0] Magic (0xCA)
    // [1] FrameType (0x02 = response)
    // [2..5] 32-bit Stream ID
    // [6] Frame Index
    // [7] Total Frames (> 0, and frameIndex < totalFrames)
    final isSequenced = frameType == PassportAttendanceModel.frameTypeResponse &&
        bytes.length >= PassportBleFrame.headerSize &&
        bytes[7] > 0 &&
        bytes[6] < bytes[7] &&
        (bytes[7] > 1 || (bytes[7] == 1 && bytes.length > 8 && bytes[8] == 0x7B));

    if (isSequenced) {
      final streamId = PassportBleFrame.extractStreamId(bytes);
      final totalFrames = PassportBleFrame.extractTotalFrames(bytes);
      final frameIndex = PassportBleFrame.extractFrameIndex(bytes);

      if (streamId == 0 || totalFrames == 0 || frameIndex >= totalFrames) {
        return;
      }

      // Maintain legacy frame & RSSI maps for backward compatibility
      _rssiSamplesByStream.putIfAbsent(streamId, () => []);
      _rssiSamplesByStream[streamId]!.add(rssi);

      _collectedFramesByStream.putIfAbsent(streamId, () => []);
      _collectedFramesByStream[streamId]!.add(bytes);

      // Look up or initialize stream reassembly buffer
      final buffer = _streamBuffers.putIfAbsent(
        streamId,
        () => _StreamReassemblyBuffer(
          streamId: streamId,
          frameType: PassportAttendanceModel.frameTypeResponse,
          totalFrames: totalFrames,
          lastSeen: DateTime.now(),
        ),
      );

      final isNewlyCompleted = buffer.addFrame(bytes, rssi);

      if (isNewlyCompleted) {
        final response = buffer.reassemble();
        if (response != null) {
          await _handleStudentResponse(
            response: response,
            rssiSamples: buffer.rssiSamples.isNotEmpty ? buffer.rssiSamples : [rssi],
          );
        }
      }
      return;
    }

    // 2. Compact single-frame student BLE attendance response:
    final streamId = ((bytes[2] & 0xFF) << 8) | (bytes[3] & 0xFF);

    // Extract up to 12-byte student name from bytes 4..min(16, bytes.length)
    String transmittedName = '';
    if (bytes.length > 4) {
      final nameEnd = min(16, bytes.length);
      final rawNameBytes = bytes.sublist(4, nameEnd);
      transmittedName = utf8.decode(rawNameBytes, allowMalformed: true).replaceAll('\x00', '').trim();
    }

    // Extract up to 8-byte student ID from bytes 16..min(24, bytes.length)
    String transmittedId = '';
    if (bytes.length > 16) {
      final idEnd = min(24, bytes.length);
      final rawIdBytes = bytes.sublist(16, idEnd);
      transmittedId = utf8.decode(rawIdBytes, allowMalformed: true).replaceAll('\x00', '').trim();
    }

    final resolvedStudentId = transmittedId.isNotEmpty ? transmittedId : streamId.toString();
    String finalStudentId = resolvedStudentId;
    String finalStudentName = transmittedName;

    // Resolve full student ID & name against trust bundle and class roster
    try {
      final bundle = await _trustBundleService.getLocalBundle();
      if (bundle != null && bundle.identities.isNotEmpty) {
        final match = bundle.identities.firstWhere(
          (id) =>
              id.userId == resolvedStudentId ||
              id.keyId == resolvedStudentId ||
              (resolvedStudentId.length >= 4 && (id.userId.startsWith(resolvedStudentId) || id.keyId.startsWith(resolvedStudentId))) ||
              (transmittedName.isNotEmpty && id.userName != null && id.userName!.trim().toLowerCase() == transmittedName.toLowerCase()),
          orElse: () => const PassportTrustIdentity(
            keyId: '',
            userId: '',
            publicKey: '',
            certificateId: '',
            issuerKeyId: '',
            validFrom: 0,
            validTo: 0,
            status: '',
          ),
        );
        if (match.userId.isNotEmpty) {
          finalStudentId = match.userId;
          if (match.userName != null && match.userName!.trim().isNotEmpty) {
            finalStudentName = match.userName!.trim();
          }
        }
      }

      if (finalStudentId == resolvedStudentId && _classRosterStudentIds.isNotEmpty) {
        final rosterMatch = _classRosterStudentIds.firstWhere(
          (rId) => rId == resolvedStudentId || (resolvedStudentId.length >= 4 && rId.startsWith(resolvedStudentId)),
          orElse: () => '',
        );
        if (rosterMatch.isNotEmpty) {
          finalStudentId = rosterMatch;
        }
      }
    } catch (_) {}

    if (finalStudentName.isEmpty) {
      finalStudentName = transmittedName.isNotEmpty
          ? transmittedName
          : 'Student ${finalStudentId.substring(0, min(6, finalStudentId.length))}';
    }

    final res = PassportAttendanceVerificationResult(
      valid: true,
      status: PassportAttendanceStatus.verifiedPresent,
      reason: 'Verified present via direct BLE Radio frame',
      studentId: finalStudentId,
      studentName: finalStudentName,
      deviceKeyId: 'key_$finalStudentId',
      sessionId: _activeSession?.id ?? _activeBeacon?.sessionId ?? '',
      responseNonce: streamId.toString(),
      idempotencyKey: '${_activeSession?.id ?? _activeBeacon?.sessionId}_$finalStudentId',
      proximityTier: PassportProximityTier.near,
      medianRssi: rssi,
      verificationMode: 'BLE_BATCH',
      verifiedAt: DateTime.now(),
    );

    if (!_verifiedResults.containsKey(finalStudentId) && !_verifiedResults.containsKey(resolvedStudentId)) {
      await _ledgerService.recordAttendance(res);
      _verifiedResults[finalStudentId] = res;
      if (finalStudentId != resolvedStudentId) {
        _verifiedResults[resolvedStudentId] = res;
      }
      _inconclusiveResults.remove(finalStudentId);
      _inconclusiveResults.remove(resolvedStudentId);
      _emitMetrics();
      debugPrint('🎯 [PASSPORT_TEACHER] Verified student $finalStudentName (ID: $finalStudentId) over direct BLE radio (RSSI: $rssi dBm)!');

      // Opportunistically sync to central backend so live attendance updates immediately
      _syncVerifiedAttendanceToBackend();
    }
  }

  /// Performs the 15-step Local Offline Verification Order against cached trust data.
  Future<PassportAttendanceVerificationResult> verifyResponseOffline({
    required PassportAttendanceResponseModel response,
    required List<int> rssiSamples,
    String verificationMode = 'BLE_BATCH',
    int? currentTimestampSeconds,
  }) async {
    final now = currentTimestampSeconds ??
        (DateTime.now().toUtc().millisecondsSinceEpoch ~/ 1000);

    // 1. Validate protocol version
    if (response.version != PassportAttendanceModel.currentVersion) {
      return PassportAttendanceVerificationResult(
        valid: false,
        status: PassportAttendanceStatus.cryptoInvalid,
        reason: 'Unsupported response protocol version',
        sessionId: response.sessionId,
        studentId: response.studentId,
        verifiedAt: DateTime.now(),
      );
    }

    // 2. Validate packet structure
    if (response.sessionId.isEmpty ||
        response.studentId.isEmpty ||
        response.deviceKeyId.isEmpty ||
        response.challengeNonce.isEmpty ||
        response.signature.isEmpty) {
      return PassportAttendanceVerificationResult(
        valid: false,
        status: PassportAttendanceStatus.cryptoInvalid,
        reason: 'Malformed attendance response packet: Missing fields',
        sessionId: response.sessionId,
        studentId: response.studentId,
        verifiedAt: DateTime.now(),
      );
    }

    // 3. Validate response expiration
    if (response.isExpired(now)) {
      return PassportAttendanceVerificationResult(
        valid: false,
        status: PassportAttendanceStatus.sessionExpired,
        reason: 'Attendance response expired',
        sessionId: response.sessionId,
        studentId: response.studentId,
        verifiedAt: DateTime.now(),
      );
    }

    // 4. Validate sessionId match
    final activeId = _activeBeacon?.sessionId ?? '';
    final isSessionMatch = response.sessionId == activeId ||
        SessionService.formatSessionBleUuid(response.sessionId) ==
            SessionService.formatSessionBleUuid(activeId);
    if (_activeBeacon != null && !isSessionMatch) {
      return PassportAttendanceVerificationResult(
        valid: false,
        status: PassportAttendanceStatus.cryptoInvalid,
        reason: 'Session ID mismatch',
        sessionId: response.sessionId,
        studentId: response.studentId,
        verifiedAt: DateTime.now(),
      );
    }

    // 5. Validate session nonce binding
    if (_activeBeacon != null &&
        response.challengeNonce.toLowerCase() != _activeBeacon!.sessionNonce.toLowerCase()) {
      return PassportAttendanceVerificationResult(
        valid: false,
        status: PassportAttendanceStatus.cryptoInvalid,
        reason: 'Challenge nonce binding mismatch',
        sessionId: response.sessionId,
        studentId: response.studentId,
        verifiedAt: DateTime.now(),
      );
    }

    // 6. Verify biometric gate state
    if (!response.biometricGate) {
      return PassportAttendanceVerificationResult(
        valid: false,
        status: PassportAttendanceStatus.biometricRequired,
        reason: 'BIOMETRIC_REQUIRED: Response indicated biometric gate was not completed',
        sessionId: response.sessionId,
        studentId: response.studentId,
        verifiedAt: DateTime.now(),
      );
    }

    // 6b. Classroom Router BSSID Lock (Anti-hostel Wi-Fi spoofing)
    final expectedBssid = _classroomRouterBssid ?? _activeBeacon?.routerBssid;
    if (verificationMode == PassportAttendanceModel.modeWifiLan &&
        expectedBssid != null &&
        expectedBssid.isNotEmpty &&
        response.routerBssid != null &&
        response.routerBssid!.isNotEmpty) {
      if (expectedBssid.toLowerCase() != response.routerBssid!.toLowerCase()) {
        return PassportAttendanceVerificationResult(
          valid: false,
          status: PassportAttendanceStatus.proximityInconclusive,
          reason: 'BSSID_MISMATCH: Connected to different Wi-Fi access point (${response.routerBssid}). Classroom lock failed.',
          sessionId: response.sessionId,
          studentId: response.studentId,
          routerBssid: response.routerBssid,
          verifiedAt: DateTime.now(),
        );
      }
    }

    // 6c. Room PIN Verification Lock
    if (verificationMode == PassportAttendanceModel.modePinManual) {
      final pin = response.responseNonce;
      final expectedNonce = _activeBeacon?.sessionNonce ?? 'nonce_';
      final activeSessionId = _activeBeacon?.sessionId ?? response.sessionId;
      final isPinValid = PassportRollingPinModel.verifyPin(
        enteredPin: pin,
        sessionId: activeSessionId,
        sessionNonce: expectedNonce,
        timestampSeconds: now,
      );
      if (!isPinValid) {
        return PassportAttendanceVerificationResult(
          valid: false,
          status: PassportAttendanceStatus.cryptoInvalid,
          reason: 'PIN_INVALID: Room PIN is incorrect or expired. Check classroom display.',
          sessionId: response.sessionId,
          studentId: response.studentId,
          verifiedAt: DateTime.now(),
        );
      }
    }

    // 6d. Hybrid GPS Geofence & Anti-Mock Location Check
    final gpsEval = PassportLocationService.evaluate(
      teacherLatitude:
          _activeBeacon?.teacherLatitude ?? _teacherLocation?.latitude,
      teacherLongitude:
          _activeBeacon?.teacherLongitude ?? _teacherLocation?.longitude,
      teacherAccuracyMeters: _activeBeacon?.teacherLocationAccuracy ??
          _teacherLocation?.accuracyMeters,
      studentLatitude: response.latitude,
      studentLongitude: response.longitude,
      studentAccuracyMeters: response.gpsAccuracy,
      studentIsMocked: response.isMockedGps,
    );

    if (gpsEval.status == PassportGeofenceStatus.mockDetected) {
      return PassportAttendanceVerificationResult(
        valid: false,
        status: PassportAttendanceStatus.fakeBeacon,
        reason: gpsEval.summary,
        sessionId: response.sessionId,
        studentId: response.studentId,
        verificationMode: verificationMode,
        gpsDistanceMeters: gpsEval.distanceMeters,
        gpsStatus: gpsEval.statusCode,
        verifiedAt: DateTime.now(),
      );
    }

    // 7. Check cached trust bundle for student registered key & certificate
    var bundle = await _trustBundleService.getLocalBundle();
    if (bundle == null) {
      try {
        bundle = await _trustBundleService.downloadAndSaveBundle();
      } catch (_) {}
    }

    if (bundle != null && bundle.isKeyRevoked(response.deviceKeyId)) {
      return PassportAttendanceVerificationResult(
        valid: false,
        status: PassportAttendanceStatus.unknownStudent,
        reason: 'REVOKED_KEY: Student device identity key is recorded as revoked in trust bundle',
        sessionId: response.sessionId,
        studentId: response.studentId,
        verifiedAt: DateTime.now(),
      );
    }

    if (bundle == null) {
      debugPrint('ℹ️ [PASSPORT_TEACHER] Trust bundle missing offline — accepting structurally valid response with biometric gate.');
      final proximity = PassportProximityObservation.compute(
        challengeId: response.challengeNonce,
        samples: rssiSamples,
        startedAt: DateTime.now().subtract(const Duration(seconds: 3)),
        completedAt: DateTime.now(),
        config: _proximityConfig,
      );
      final fallbackName =
          'Student ${response.studentId.substring(0, min(6, response.studentId.length))}';
      if (gpsEval.status == PassportGeofenceStatus.outsideReview &&
          verificationMode != 'QR_FALLBACK') {
        return PassportAttendanceVerificationResult(
          valid: false,
          status: PassportAttendanceStatus.proximityInconclusive,
          reason: gpsEval.summary,
          sessionId: response.sessionId,
          studentId: response.studentId,
          studentName: fallbackName,
          deviceKeyId: response.deviceKeyId,
          responseNonce: response.responseNonce,
          idempotencyKey: response.idempotencyKey,
          proximityTier: proximity.proximityTier,
          medianRssi: proximity.medianRssi,
          verificationMode: verificationMode,
          gpsDistanceMeters: gpsEval.distanceMeters,
          gpsStatus: gpsEval.statusCode,
          verifiedAt: DateTime.now(),
        );
      }
      return PassportAttendanceVerificationResult(
        valid: true,
        status: PassportAttendanceStatus.verifiedPresent,
        reason: 'OFFLINE_TRUST_DATA_MISSING: Verified present offline (structural validation)',
        sessionId: response.sessionId,
        studentId: response.studentId,
        studentName: fallbackName,
        deviceKeyId: response.deviceKeyId,
        responseNonce: response.responseNonce,
        idempotencyKey: response.idempotencyKey,
        proximityTier: proximity.proximityTier,
        medianRssi: proximity.medianRssi,
        verificationMode: verificationMode,
        gpsDistanceMeters: gpsEval.distanceMeters,
        gpsStatus: gpsEval.statusCode,
        verifiedAt: DateTime.now(),
      );
    }

    var studentIdentity = bundle.identities.firstWhere(
      (id) =>
          id.keyId == response.deviceKeyId &&
          id.userId == response.studentId &&
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

    // If student identity key was not found in bundle, try refreshing the trust bundle once
    if (studentIdentity.keyId.isEmpty) {
      try {
        final freshBundle = await _trustBundleService.downloadAndSaveBundle();
        bundle = freshBundle;
        studentIdentity = freshBundle.identities.firstWhere(
            (id) =>
                id.keyId == response.deviceKeyId &&
                id.userId == response.studentId &&
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
      } catch (_) {}
    }

    // If student identity key was not found in bundle, reject unknown student
    if (studentIdentity.keyId.isEmpty) {
      return PassportAttendanceVerificationResult(
        valid: false,
        status: PassportAttendanceStatus.unknownStudent,
        reason:
            'UNKNOWN_KEY: Student device identity key not found or revoked in trust bundle',
        sessionId: response.sessionId,
        studentId: response.studentId,
        verifiedAt: DateTime.now(),
      );
    }

    // Check certificate validity timestamps
    if (!studentIdentity.isValidAt(now)) {
      return PassportAttendanceVerificationResult(
        valid: false,
        status: PassportAttendanceStatus.cryptoInvalid,
        reason: 'EXPIRED_KEY: Student certificate expired or not yet valid',
        sessionId: response.sessionId,
        studentId: response.studentId,
        verifiedAt: DateTime.now(),
      );
    }

    // 8. Verify student Ed25519 signature
    final canonicalJson = response.toCanonicalJson();
    final isSigValid = await _cryptoService.verifySignature(
      publicKey: studentIdentity.publicKey,
      challenge: canonicalJson,
      signature: response.signature,
    );

    if (!isSigValid) {
      return PassportAttendanceVerificationResult(
        valid: false,
        status: PassportAttendanceStatus.cryptoInvalid,
        reason: 'Invalid cryptographic Ed25519 signature',
        sessionId: response.sessionId,
        studentId: response.studentId,
        verifiedAt: DateTime.now(),
      );
    }

    // 9. Replay / idempotency check
    final idempotencyKey = response.derivedIdempotencyKey;
    if (_ledgerService.isStudentRecorded(response.sessionId, response.studentId) ||
        _ledgerService.isIdempotencyKeyRecorded(response.sessionId, idempotencyKey)) {
      return PassportAttendanceVerificationResult(
        valid: false,
        status: PassportAttendanceStatus.replayedResponse,
        reason: 'Duplicate or replayed attendance response rejected',
        sessionId: response.sessionId,
        studentId: response.studentId,
        idempotencyKey: idempotencyKey,
        verifiedAt: DateTime.now(),
      );
    }

    // 9b. Classroom Router BSSID Lock evaluated at Step 6b

    // 10. Proximity / Multi-rail evaluation
    PassportProximityObservation proximity;
    if (verificationMode == 'QR_FALLBACK' || verificationMode == PassportAttendanceModel.modeQrOptical) {
      proximity = PassportProximityObservation.compute(
        challengeId: response.challengeNonce,
        samples: const [-50], // Direct visual proximity confirmed by camera scan
        startedAt: DateTime.now(),
        completedAt: DateTime.now(),
        config: _proximityConfig,
      );
    } else {
      proximity = PassportProximityObservation.compute(
        challengeId: response.challengeNonce,
        samples: rssiSamples,
        startedAt: DateTime.now().subtract(const Duration(seconds: 3)),
        completedAt: DateTime.now(),
        config: _proximityConfig,
      );
    }

    final studentName = studentIdentity.userName ?? 'Student ${response.studentId.substring(0, min(6, response.studentId.length))}';

    if (gpsEval.status == PassportGeofenceStatus.outsideReview &&
        verificationMode != 'QR_FALLBACK') {
      return PassportAttendanceVerificationResult(
        valid: false,
        status: PassportAttendanceStatus.proximityInconclusive,
        reason: gpsEval.summary,
        studentId: response.studentId,
        studentName: studentName,
        deviceKeyId: response.deviceKeyId,
        sessionId: response.sessionId,
        responseNonce: response.responseNonce,
        idempotencyKey: idempotencyKey,
        proximityTier: proximity.proximityTier,
        medianRssi: proximity.medianRssi,
        verificationMode: verificationMode,
        gpsDistanceMeters: gpsEval.distanceMeters,
        gpsStatus: gpsEval.statusCode,
        verifiedAt: DateTime.now(),
      );
    }

    final isProximityGuaranteed = proximity.proximityTier == PassportProximityTier.near ||
        verificationMode == 'QR_FALLBACK' ||
        verificationMode == PassportAttendanceModel.modeQrOptical ||
        verificationMode == PassportAttendanceModel.modeWifiLan ||
        verificationMode == PassportAttendanceModel.modeWifiHotspot ||
        verificationMode == PassportAttendanceModel.modePinManual;

    // If cryptographically valid AND proximity is guaranteed: VERIFIED PRESENT
    if (isProximityGuaranteed) {
      final res = PassportAttendanceVerificationResult(
        valid: true,
        status: PassportAttendanceStatus.verifiedPresent,
        reason: 'Verified present via $verificationMode',
        studentId: response.studentId,
        studentName: studentName,
        deviceKeyId: response.deviceKeyId,
        sessionId: response.sessionId,
        responseNonce: response.responseNonce,
        idempotencyKey: idempotencyKey,
        proximityTier: proximity.proximityTier,
        medianRssi: proximity.medianRssi,
        verificationMode: verificationMode,
        routerBssid: response.routerBssid,
        gpsDistanceMeters: gpsEval.distanceMeters,
        gpsStatus: gpsEval.statusCode,
        verifiedAt: DateTime.now(),
      );
      await _ledgerService.recordAttendance(res);
      _verifiedResults[response.studentId] = res;
      _inconclusiveResults.remove(response.studentId);
      _syncVerifiedAttendanceToBackend();
      return res;
    }

    // Cryptographically valid, but proximity is weak/unstable: PROXIMITY_INCONCLUSIVE
    return PassportAttendanceVerificationResult(
      valid: false,
      status: PassportAttendanceStatus.proximityInconclusive,
      reason: 'Cryptographic proof valid, but proximity inconclusive (${proximity.proximityTier.code}). QR fallback required.',
      studentId: response.studentId,
      studentName: studentName,
      deviceKeyId: response.deviceKeyId,
      sessionId: response.sessionId,
      responseNonce: response.responseNonce,
      idempotencyKey: idempotencyKey,
      proximityTier: proximity.proximityTier,
      medianRssi: proximity.medianRssi,
      verificationMode: verificationMode,
      gpsDistanceMeters: gpsEval.distanceMeters,
      gpsStatus: gpsEval.statusCode,
      verifiedAt: DateTime.now(),
    );
  }

  /// Evaluates RSSI proximity tier for a list of RSSI integer samples.
  PassportProximityTier evaluateRssiProximity(List<int> samples) {
    final now = DateTime.now();
    final obs = PassportProximityObservation.compute(
      challengeId: 'rssi-eval',
      samples: samples,
      startedAt: now,
      completedAt: now,
      config: _proximityConfig,
    );
    return obs.proximityTier;
  }

  /// Convenience wrapper for offline verification.
  Future<PassportAttendanceVerificationResult> verifyAttendanceResponse(
    PassportAttendanceResponseModel response, {
    String? expectedSessionNonce,
    List<int> rssiSamples = const [-65],
    String verificationMode = 'BLE_BATCH',
    int? currentTimestampSeconds,
  }) async {
    return verifyResponseOffline(
      response: response,
      rssiSamples: rssiSamples,
      verificationMode: verificationMode,
      currentTimestampSeconds: currentTimestampSeconds,
    );
  }

  /// Processes a newly assembled student response concurrently.
  Future<void> _handleStudentResponse({
    required PassportAttendanceResponseModel response,
    required List<int> rssiSamples,
  }) async {
    // If already verified present, ignore duplicates
    if (_verifiedResults.containsKey(response.studentId)) return;

    final result = await verifyResponseOffline(
      response: response,
      rssiSamples: rssiSamples,
      verificationMode: 'BLE_BATCH',
    );

    if (result.status == PassportAttendanceStatus.verifiedPresent) {
      _verifiedResults[result.studentId!] = result;
      _inconclusiveResults.remove(result.studentId);
      await _ledgerService.recordAttendance(result);
      debugPrint('✅ [PASSPORT_TEACHER] Verified Present: ${result.studentName} (${result.studentId})');
      _syncVerifiedAttendanceToBackend();
    } else if (result.status == PassportAttendanceStatus.proximityInconclusive) {
      _inconclusiveResults[result.studentId!] = result;
      debugPrint('⚠️ [PASSPORT_TEACHER] Proximity Inconclusive: ${result.studentName} (${result.studentId}) -> QR Fallback');
    }

    _emitMetrics();
  }

  /// QR Fallback Exception Path:
  /// Verifies a student's response QR code or dynamic Passport presentation scanned by the teacher.
  Future<PassportAttendanceVerificationResult> verifyQrResponse(String qrString) async {
    try {
      // 1. Try decoding as PassportAttendanceResponseModel first
      PassportAttendanceResponseModel? response;
      try {
        final decoded = jsonDecode(qrString.trim());
        if (decoded is Map<String, dynamic>) {
          final p = decoded['p'];
          if (p is Map<String, dynamic> &&
              (p['t'] == 'ATT_RESP' || p['t'] == 'ATTENDANCE_RESPONSE')) {
            response = PassportAttendanceResponseModel.fromQrString(qrString);
          }
        }
      } catch (_) {}

      if (response != null) {
        final result = await verifyResponseOffline(
          response: response,
          rssiSamples: const [-50],
          verificationMode: 'QR_FALLBACK',
        );

        if (result.status == PassportAttendanceStatus.verifiedPresent) {
          _verifiedResults[result.studentId!] = result;
          _inconclusiveResults.remove(result.studentId);
          await _ledgerService.recordAttendance(result);
          debugPrint('✅ [PASSPORT_TEACHER] QR Exception Resolved: ${result.studentName}');
        }

        _emitMetrics();
        return result;
      }

      // 2. Alternatively, verify student dynamic Passport presentation QR
      // (The standard 30s rotating QR code on the back of the student's Passport card!)
      final verifier = PassportOfflineVerifierService(
        bundleService: _trustBundleService,
      );
      final verResult = await verifier.verifyOffline(qrPayload: qrString);

      if (verResult.valid) {
        final studentId = verResult.userId ?? 'student';
        String studentName = verResult.user?.name ?? 'Student';

        if (studentName == 'Student' || studentName.isEmpty) {
          try {
            final bundle = await _trustBundleService.getLocalBundle();
            final idObj = bundle?.identities.where((i) => i.userId == studentId).firstOrNull;
            if (idObj != null && idObj.userName != null && idObj.userName!.isNotEmpty) {
              studentName = idObj.userName!;
            }
          } catch (_) {}
        }

        final result = PassportAttendanceVerificationResult(
          valid: true,
          status: PassportAttendanceStatus.verifiedPresent,
          reason: 'Verified Present via Student Passport Presentation',
          sessionId: _activeSession?.id ?? '',
          studentId: studentId,
          studentName: studentName,
          proximityTier: PassportProximityTier.near,
          medianRssi: -50,
          verifiedAt: DateTime.now(),
          verificationMode: 'QR_FALLBACK',
        );

        _verifiedResults[studentId] = result;
        _inconclusiveResults.remove(studentId);
        await _ledgerService.recordAttendance(result);
        debugPrint('✅ [PASSPORT_TEACHER] Verified Student Presentation QR: $studentName ($studentId)');

        _emitMetrics();
        return result;
      } else if (verResult.reason == 'OFFLINE_TRUST_DATA_MISSING') {
        // 3. Graceful offline fallback: trust bundle not yet downloaded.
        //    Validate the Passport Presentation structure and timestamp only.
        //    Accept if the QR was issued within 120 seconds (2× the normal window).
        debugPrint('⚠️ [PASSPORT_TEACHER] Trust bundle missing — attempting structural QR fallback.');
        try {
          final envDecoded = jsonDecode(qrString.trim());
          if (envDecoded is Map<String, dynamic>) {
            final payloadMap = envDecoded['p'] is Map<String, dynamic>
                ? envDecoded['p'] as Map<String, dynamic>
                : (envDecoded['payload'] is Map<String, dynamic>
                    ? envDecoded['payload'] as Map<String, dynamic>
                    : null);
            final signatureStr =
                envDecoded['s']?.toString() ?? envDecoded['signature']?.toString();

            if (payloadMap != null && signatureStr != null && signatureStr.isNotEmpty) {
              final type =
                  payloadMap['t']?.toString() ?? payloadMap['type']?.toString() ?? '';
              if (type == 'PASSPORT_PRESENTATION' || type == 'PP') {
                final issuedAt =
                    payloadMap['iat'] as int? ?? payloadMap['issuedAt'] as int? ?? 0;
                final expiresAt =
                    payloadMap['exp'] as int? ?? payloadMap['expiresAt'] as int? ?? 0;
                final userId =
                    payloadMap['uid']?.toString() ?? payloadMap['userId']?.toString() ?? '';
                final userName = payloadMap['user'] is Map
                    ? (payloadMap['user'] as Map)['name']?.toString() ?? ''
                    : '';
                final keyId =
                    payloadMap['kid']?.toString() ?? payloadMap['keyId']?.toString() ?? '';

                final nowTs =
                    DateTime.now().toUtc().millisecondsSinceEpoch ~/ 1000;
                final isRecent = issuedAt > 0 && (nowTs - issuedAt) <= 120;
                final notExpired = expiresAt == 0 || expiresAt > nowTs;
                final hasId = userId.isNotEmpty;
                final hasKey = keyId.isNotEmpty;

                if (isRecent && notExpired && hasId && hasKey) {
                  final displayName = userName.isNotEmpty
                      ? userName
                      : 'Student ${userId.substring(0, min(6, userId.length))}';
                  final result = PassportAttendanceVerificationResult(
                    valid: true,
                    status: PassportAttendanceStatus.verifiedPresent,
                    reason: 'Verified Present (Trust Bundle Pending — Structural QR)',
                    sessionId: _activeSession?.id ?? '',
                    studentId: userId,
                    studentName: displayName,
                    proximityTier: PassportProximityTier.near,
                    medianRssi: -50,
                    verifiedAt: DateTime.now(),
                    verificationMode: 'QR_TRUST_EXEMPT',
                  );

                  _verifiedResults[userId] = result;
                  _inconclusiveResults.remove(userId);
                  await _ledgerService.recordAttendance(result);
                  debugPrint(
                      '✅ [PASSPORT_TEACHER] QR_TRUST_EXEMPT accepted: $displayName ($userId)');

                  // Trigger bundle download in background so next scans are fully verified
                  () async {
                    try { await _trustBundleService.downloadAndSaveBundle(); } catch (_) {}
                  }();

                  _emitMetrics();
                  return result;
                }
              }
            }
          }
        } catch (e) {
          debugPrint('⚠️ [PASSPORT_TEACHER] Structural fallback parse error: $e');
        }
        // Structural check also failed — surface informative message
        return PassportAttendanceVerificationResult(
          valid: false,
          status: PassportAttendanceStatus.cryptoInvalid,
          reason:
              'Trust bundle not available and QR structure/timestamp invalid. Please connect to CampusOS first.',
          verifiedAt: DateTime.now(),
        );
      } else if (verResult.reason == 'OFFLINE_UNKNOWN_KEY' ||
                 verResult.reason == 'OFFLINE_TRUST_DATA_EXPIRED' ||
                 verResult.reason == 'OFFLINE_CERTIFICATE_MISMATCH') {
        // 3b. Student key not found in local bundle — bundle is stale.
        //     This is the most common case: teacher downloaded bundle before
        //     student activated their Passport. Force a fresh download and retry.
        debugPrint('⚠️ [PASSPORT_TEACHER] ${verResult.reason} — refreshing trust bundle and retrying...');

        PassportVerificationResult? retryResult;
        try {
          await _trustBundleService.downloadAndSaveBundle();
          retryResult = await verifier.verifyOffline(qrPayload: qrString);
        } catch (e) {
          debugPrint('⚠️ [PASSPORT_TEACHER] Bundle refresh failed: $e');
        }

        // If retry succeeded after fresh bundle, accept normally
        if (retryResult != null && retryResult.valid) {
          final studentId = retryResult.userId ?? 'student';
          String studentName = retryResult.user?.name ?? 'Student';
          try {
            final bundle = await _trustBundleService.getLocalBundle();
            final idObj = bundle?.identities.where((i) => i.userId == studentId).firstOrNull;
            if (idObj?.userName != null && idObj!.userName!.isNotEmpty) {
              studentName = idObj.userName!;
            }
          } catch (_) {}

          final result = PassportAttendanceVerificationResult(
            valid: true,
            status: PassportAttendanceStatus.verifiedPresent,
            reason: 'Verified Present via Student Passport (fresh bundle)',
            sessionId: _activeSession?.id ?? '',
            studentId: studentId,
            studentName: studentName,
            proximityTier: PassportProximityTier.near,
            medianRssi: -50,
            verifiedAt: DateTime.now(),
            verificationMode: 'QR_FALLBACK',
          );
          _verifiedResults[studentId] = result;
          _inconclusiveResults.remove(studentId);
          await _ledgerService.recordAttendance(result);
          debugPrint('✅ [PASSPORT_TEACHER] Verified after bundle refresh: $studentName ($studentId)');
          _emitMetrics();
          return result;
        }

        // Retry also failed — apply structural-only fallback (timestamp + structure check)
        debugPrint('⚠️ [PASSPORT_TEACHER] Retry failed — applying structural QR fallback.');
        try {
          final envDecoded = jsonDecode(qrString.trim());
          if (envDecoded is Map<String, dynamic>) {
            final payloadMap = envDecoded['p'] is Map<String, dynamic>
                ? envDecoded['p'] as Map<String, dynamic>
                : (envDecoded['payload'] is Map<String, dynamic>
                    ? envDecoded['payload'] as Map<String, dynamic>
                    : null);
            final signatureStr =
                envDecoded['s']?.toString() ?? envDecoded['signature']?.toString();

            if (payloadMap != null && signatureStr != null && signatureStr.isNotEmpty) {
              final type = payloadMap['t']?.toString() ?? payloadMap['type']?.toString() ?? '';
              if (type == 'PASSPORT_PRESENTATION' || type == 'PP') {
                final issuedAt = payloadMap['iat'] as int? ?? payloadMap['issuedAt'] as int? ?? 0;
                final expiresAt = payloadMap['exp'] as int? ?? payloadMap['expiresAt'] as int? ?? 0;
                final userId = payloadMap['uid']?.toString() ?? payloadMap['userId']?.toString() ?? '';
                final userName = payloadMap['user'] is Map
                    ? (payloadMap['user'] as Map)['name']?.toString() ?? '' : '';
                final keyId = payloadMap['kid']?.toString() ?? payloadMap['keyId']?.toString() ?? '';
                final nowTs = DateTime.now().toUtc().millisecondsSinceEpoch ~/ 1000;
                final isRecent = issuedAt > 0 && (nowTs - issuedAt) <= 120;
                final notExpired = expiresAt == 0 || expiresAt > nowTs;

                if (isRecent && notExpired && userId.isNotEmpty && keyId.isNotEmpty) {
                  final displayName = userName.isNotEmpty
                      ? userName
                      : 'Student ${userId.substring(0, min(6, userId.length))}';
                  final result = PassportAttendanceVerificationResult(
                    valid: true,
                    status: PassportAttendanceStatus.verifiedPresent,
                    reason: 'Verified Present (Passport pending sync — Structural QR)',
                    sessionId: _activeSession?.id ?? '',
                    studentId: userId,
                    studentName: displayName,
                    proximityTier: PassportProximityTier.near,
                    medianRssi: -50,
                    verifiedAt: DateTime.now(),
                    verificationMode: 'QR_TRUST_EXEMPT',
                  );
                  _verifiedResults[userId] = result;
                  _inconclusiveResults.remove(userId);
                  await _ledgerService.recordAttendance(result);
                  debugPrint('✅ [PASSPORT_TEACHER] QR_TRUST_EXEMPT (stale bundle): $displayName');
                  _emitMetrics();
                  return result;
                }
              }
            }
          }
        } catch (e) {
          debugPrint('⚠️ [PASSPORT_TEACHER] Structural fallback parse error: $e');
        }

        return PassportAttendanceVerificationResult(
          valid: false,
          status: PassportAttendanceStatus.cryptoInvalid,
          reason: 'Student Passport not yet synced. Ask student to re-open their Passport screen and try again.',
          verifiedAt: DateTime.now(),
        );
      } else {
        // Hard failures: invalid format, expired QR, revoked key, bad signature
        return PassportAttendanceVerificationResult(
          valid: false,
          status: PassportAttendanceStatus.cryptoInvalid,
          reason: verResult.rawMessage ?? 'Invalid QR: ${verResult.reason}',
          verifiedAt: DateTime.now(),
        );
      }
    } catch (e) {
      debugPrint('❌ [PASSPORT_TEACHER] QR Exception verification failed: $e');
      return PassportAttendanceVerificationResult(
        valid: false,
        status: PassportAttendanceStatus.cryptoInvalid,
        reason: 'Malformed student QR response: $e',
        verifiedAt: DateTime.now(),
      );
    }
  }

  /// Generates the compact session QR challenge payload for students to scan during QR fallback.
  Future<String> generateSessionQrPayload() async {
    if (_activeBeacon == null) {
      throw StateError('No active attendance session');
    }
    return _activeBeacon!.toQrString();
  }

  /// Builds the hybrid Wi-Fi MECARD + `X-CAMPUSOS` QR payload including reference GPS coordinates when available.
  String buildWifiHotspotQrPayload({
    required String sessionId,
    String? fallbackTeacherId,
    String? gatewayIpOverride,
  }) {
    final ssid = _hotspotSsid ?? '';
    final pass = _hotspotPassword ?? '';
    final gatewayIp = gatewayIpOverride ?? _detectedGatewayIp ?? '192.168.43.1';
    final nonce = _activeBeacon?.sessionNonce ?? '';
    final teacherId = _activeBeacon?.teacherId ?? fallbackTeacherId ?? 'teacher';
    const localPort = PassportAttendanceModel.defaultLocalHttpPort;
    final lat = _activeBeacon?.teacherLatitude ?? _teacherLocation?.latitude;
    final lng = _activeBeacon?.teacherLongitude ?? _teacherLocation?.longitude;
    final acc = _activeBeacon?.teacherLocationAccuracy ??
        _teacherLocation?.accuracyMeters;
    final gpsSuffix = (lat != null && lng != null)
        ? ',$lat,$lng,${acc ?? 15.0}'
        : '';
    return 'WIFI:S:$ssid;T:WPA;P:$pass;X-CAMPUSOS:$sessionId,$nonce,$teacherId,$gatewayIp,$localPort$gpsSuffix;;';
  }

  void _emitMetrics() {
    if (_metricsController.isClosed) return;
    final verified = _verifiedResults.length;
    final inconclusive = _inconclusiveResults.length;
    final total = max(_classRosterStudentIds.length, verified + inconclusive);
    final missing = max(0, total - (verified + inconclusive));

    final metrics = TeacherAttendanceMetrics(
      verifiedCount: verified,
      inconclusiveCount: inconclusive,
      missingCount: missing,
      totalRoster: total,
      verifiedStudents: _verifiedResults.values.toList(),
      inconclusiveStudents: _inconclusiveResults.values.toList(),
    );

    _metricsController.add(metrics);
  }

  /// Syncs queued offline attendance results to the backend when connectivity returns.
  Future<Map<String, dynamic>?> syncAttendance() async {
    if (_activeSession == null) return null;
    return await _ledgerService.syncQueue(_activeSession!.id);
  }

  void _startStreamCleanupTimer() {
    _streamCleanupTimer?.cancel();
    _streamCleanupTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      pruneStaleStreams();
    });
  }

  /// Prunes abandoned or incomplete streams older than timeout (default 30s)
  /// to prevent memory leaks and stale partial fragments.
  void pruneStaleStreams({Duration timeout = const Duration(seconds: 30)}) {
    final now = DateTime.now();
    _streamBuffers.removeWhere((id, buf) =>
        !buf.isCompleted && now.difference(buf.lastSeen) > timeout);
  }

  void _stopCollection() {
    _bleScanSubscription?.cancel();
    _bleScanSubscription = null;
    _streamCleanupTimer?.cancel();
    _streamCleanupTimer = null;
    _isCollecting = false;
    try {
      FlutterBluePlus.stopScan();
    } catch (_) {}
  }

  /// Starts the local HTTP attendance receiver on port 53318.
  Future<void> _startLocalHttpServer() async {
    try {
      await _localHttpServer?.close(force: true);
      _localHttpServer = await HttpServer.bind(
        InternetAddress.anyIPv4,
        PassportAttendanceModel.defaultLocalHttpPort,
        shared: true,
      );
      debugPrint('🌐 [PASSPORT_TEACHER] Local attendance HTTP server listening on port ${_localHttpServer!.port}');
      _localHttpServer!.listen((HttpRequest request) async {
        request.response.headers.add('Access-Control-Allow-Origin', '*');
        request.response.headers.add('Access-Control-Allow-Methods', 'POST, GET, OPTIONS');
        request.response.headers.add('Access-Control-Allow-Headers', 'Content-Type');

        if (request.method == 'OPTIONS') {
          request.response.statusCode = HttpStatus.ok;
          await request.response.close();
          return;
        }

        if (request.method == 'POST' &&
            (request.uri.path == '/attendance/submit' ||
             request.uri.path == '/api/attendance/submit')) {
          try {
            final content = await utf8.decoder.bind(request).join();
            final map = jsonDecode(content) as Map<String, dynamic>;
            final response = PassportAttendanceResponseModel.fromMap(map);
            final verificationMode = response.verificationMode.isNotEmpty
                ? response.verificationMode
                : PassportAttendanceModel.modeWifiLan;

            final result = await verifyResponseOffline(
              response: response,
              rssiSamples: const [-45], // Wi-Fi LAN / Hotspot direct TCP socket
              verificationMode: verificationMode,
            );

            if (result.valid && result.status == PassportAttendanceStatus.verifiedPresent) {
              if (result.studentId != null &&
                  !_verifiedResults.containsKey(result.studentId)) {
                await _ledgerService.recordAttendance(result);
                _verifiedResults[result.studentId!] = result;
                _inconclusiveResults.remove(result.studentId);
              }
              request.response.statusCode = HttpStatus.ok;
              request.response.headers.contentType = ContentType.json;
              request.response.write(jsonEncode({
                'status': 'verified',
                'studentId': result.studentId,
                'studentName': result.studentName,
                'verificationMode': result.verificationMode,
                'idempotencyKey': result.idempotencyKey,
                if (result.gpsStatus != null) 'gpsStatus': result.gpsStatus,
                if (result.gpsDistanceMeters != null)
                  'gpsDistanceMeters': result.gpsDistanceMeters,
              }));
              _emitMetrics();
            } else if (result.status ==
                PassportAttendanceStatus.proximityInconclusive) {
              if (result.studentId != null) {
                _inconclusiveResults[result.studentId!] = result;
                _emitMetrics();
              }
              request.response.statusCode = HttpStatus.badRequest;
              request.response.headers.contentType = ContentType.json;
              request.response.write(jsonEncode({
                'status': 'inconclusive',
                'reason': result.reason,
                'studentId': result.studentId,
                if (result.gpsStatus != null) 'gpsStatus': result.gpsStatus,
                if (result.gpsDistanceMeters != null)
                  'gpsDistanceMeters': result.gpsDistanceMeters,
              }));
            } else {
              request.response.statusCode = HttpStatus.badRequest;
              request.response.headers.contentType = ContentType.json;
              request.response.write(jsonEncode({
                'status': 'rejected',
                'reason': result.reason,
                'studentId': result.studentId,
              }));
            }
          } catch (e) {
            request.response.statusCode = HttpStatus.badRequest;
            request.response.headers.contentType = ContentType.json;
            request.response.write(jsonEncode({'error': e.toString()}));
          }
          await request.response.close();
        } else if (request.method == 'GET' && request.uri.path == '/attendance/beacon') {
          request.response.statusCode = HttpStatus.ok;
          request.response.headers.contentType = ContentType.json;
          request.response.write(jsonEncode(_activeBeacon?.toMap() ?? {}));
          await request.response.close();
        } else {
          request.response.statusCode = HttpStatus.notFound;
          await request.response.close();
        }
      });
    } catch (e) {
      debugPrint('⚠️ [PASSPORT_TEACHER] Failed to start local HTTP server: $e');
    }
  }

  /// Starts UDP multicast / broadcast on port 53317 for automatic subnet discovery.
  Future<void> _startUdpBroadcasting() async {
    try {
      _udpBroadcastSocket?.close();
      _udpBroadcastSocket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
      _udpBroadcastSocket!.broadcastEnabled = true;

      _udpBroadcastTimer?.cancel();
      _udpBroadcastTimer = Timer.periodic(const Duration(seconds: 2), (_) async {
        if (!_isBroadcasting || _activeBeacon == null) return;
        try {
          final localIp = await _getLocalIpAddress();
          final beaconPayload = jsonEncode({
            'type': 'TEACHER_BEACON',
            'sessionId': _activeBeacon!.sessionId,
            'teacherId': _activeBeacon!.teacherId,
            'nonce': _activeBeacon!.sessionNonce,
            'ip': localIp,
            'port': PassportAttendanceModel.defaultLocalHttpPort,
            'pin': currentRollingPin,
            if (_activeBeacon!.routerBssid != null) 'bssid': _activeBeacon!.routerBssid,
            if (_isHotspotActive) 'hotspotSsid': _hotspotSsid,
            if (_isHotspotActive) 'hotspotPassword': _hotspotPassword,
            if (_activeBeacon!.teacherLatitude != null)
              'tlat': _activeBeacon!.teacherLatitude,
            if (_activeBeacon!.teacherLongitude != null)
              'tlng': _activeBeacon!.teacherLongitude,
            if (_activeBeacon!.teacherLocationAccuracy != null)
              'tacc': _activeBeacon!.teacherLocationAccuracy,
          });
          final bytes = utf8.encode(beaconPayload);
          _udpBroadcastSocket?.send(
            bytes,
            InternetAddress('255.255.255.255'),
            PassportAttendanceModel.defaultUdpMulticastPort,
          );
        } catch (_) {}
      });
      debugPrint('📡 [PASSPORT_TEACHER] UDP Multicast Broadcaster active on port ${PassportAttendanceModel.defaultUdpMulticastPort}');
    } catch (e) {
      debugPrint('⚠️ [PASSPORT_TEACHER] UDP Broadcaster error: $e');
    }
  }

  /// Discovers the local device IPv4 address.
  Future<String> _getLocalIpAddress() async {
    try {
      final interfaces = await NetworkInterface.list(type: InternetAddressType.IPv4);
      // Priority 1: Physical Wi-Fi or Hotspot interface (wlan, ap, en, wi-fi, eth)
      for (final interface in interfaces) {
        final name = interface.name.toLowerCase();
        if (name.contains('wlan') || name.contains('ap') || name.contains('en') || name.contains('wi-fi') || name.contains('eth')) {
          for (final addr in interface.addresses) {
            if (!addr.isLoopback && !addr.address.startsWith('127.')) {
              return addr.address;
            }
          }
        }
      }
      // Priority 2: Standard LAN private subnets (192.168.x, 10.x, 172.x)
      for (final interface in interfaces) {
        for (final addr in interface.addresses) {
          if (!addr.isLoopback && (addr.address.startsWith('192.168.') || addr.address.startsWith('10.') || addr.address.startsWith('172.'))) {
            return addr.address;
          }
        }
      }
      // Priority 3: Any non-loopback IPv4 address
      for (final interface in interfaces) {
        for (final addr in interface.addresses) {
          if (!addr.isLoopback && addr.address.isNotEmpty) {
            return addr.address;
          }
        }
      }
    } catch (_) {}
    return '127.0.0.1';
  }

  Future<void> stopSession() async {
    _isBroadcasting = false;
    _gpsRetryTimer?.cancel();
    _gpsRetryTimer = null;
    _debounceSyncTimer?.cancel();
    _debounceSyncTimer = null;
    _beaconCycleTimer?.cancel();
    _beaconCycleTimer = null;
    _streamCleanupTimer?.cancel();
    _streamCleanupTimer = null;
    _streamBuffers.clear();
    _stopCollection();

    // Clean up local Wi-Fi & Hotspot network services
    _udpBroadcastTimer?.cancel();
    _udpBroadcastTimer = null;
    try {
      _udpBroadcastSocket?.close();
      _udpBroadcastSocket = null;
    } catch (_) {}

    try {
      await _localHttpServer?.close(force: true);
      _localHttpServer = null;
    } catch (_) {}

    stopHotspotBurst();

    try {
      await _blePeripheral.stop();
    } catch (_) {}
    try {
      await CampusMeshManager.instance.resumeAdvertisingAfterAttendance();
    } catch (_) {}

    try {
      await syncAttendance();
    } catch (_) {}

    debugPrint('🏁 [PASSPORT_TEACHER] Attendance session stopped.');
  }

  void dispose() {
    _debounceSyncTimer?.cancel();
    _debounceSyncTimer = null;
    stopSession();
    _metricsController.close();
  }
}

/// Internal buffer for deterministic, collision-resistant student response reassembly.
class _StreamReassemblyBuffer {
  final int streamId;
  final int frameType;
  int totalFrames;
  final Map<int, Uint8List> framesByIndex = {};
  final List<int> rssiSamples = [];
  DateTime lastSeen;
  bool isCompleted = false;

  _StreamReassemblyBuffer({
    required this.streamId,
    required this.frameType,
    required this.totalFrames,
    required this.lastSeen,
  });

  /// Adds a frame, deduplicates by index, and returns true if reassembly is
  /// completed for the first time.
  bool addFrame(Uint8List frame, int rssi) {
    lastSeen = DateTime.now();
    rssiSamples.add(rssi);

    if (isCompleted) return false;

    final index = PassportBleFrame.extractFrameIndex(frame);
    final total = PassportBleFrame.extractTotalFrames(frame);

    if (totalFrames == 0 && total > 0) {
      totalFrames = total;
    }

    if (index < totalFrames && !framesByIndex.containsKey(index)) {
      framesByIndex[index] = frame;
    }

    if (totalFrames > 0 && framesByIndex.length == totalFrames) {
      isCompleted = true;
      return true;
    }
    return false;
  }

  /// Reassembles the collected frames into a response model.
  PassportAttendanceResponseModel? reassemble() {
    final framesList = framesByIndex.values.toList();
    return PassportAttendanceResponseModel.fromBleFrames(framesList, streamId);
  }
}
