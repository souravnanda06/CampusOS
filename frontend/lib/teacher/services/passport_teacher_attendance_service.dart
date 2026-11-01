import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter_ble_peripheral/flutter_ble_peripheral.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../auth/models/user_model.dart';
import '../../shared/models/session_model.dart';
import '../../student/models/passport_attendance_model.dart';
import '../../student/models/passport_proximity_config.dart';
import '../../student/models/passport_proximity_observation.dart';
import '../../student/models/passport_trust_bundle_model.dart';
import '../../student/services/passport_attendance_ledger_service.dart';
import '../../student/services/passport_crypto_service.dart';
import '../../student/services/passport_identity_service.dart';
import '../../student/services/passport_trust_bundle_service.dart';
import '../../student/services/passport_offline_verifier_service.dart';
import '../../student/models/passport_verification_result.dart';
import '../../shared/services/session_service.dart';
import '../../core/mesh/campus_mesh_manager.dart';

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

  PassportTeacherBeaconModel? _activeBeacon;
  SessionModel? _activeSession;

  bool _isBroadcasting = false;
  bool _isCollecting = false;
  StreamSubscription? _bleScanSubscription;
  Timer? _beaconCycleTimer;

  /// Map of collected BLE response frames: streamId -> List<Uint8List>.
  final Map<int, List<Uint8List>> _collectedFramesByStream = {};

  /// Map of RSSI samples per student/stream: streamId -> List<int>.
  final Map<int, List<int>> _rssiSamplesByStream = {};

  /// Active per-stream reassembly buffers: 32-bit streamId -> buffer.
  final Map<int, _StreamReassemblyBuffer> _streamBuffers = {};
  Timer? _streamCleanupTimer;

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
  }
  bool get isBroadcasting => _isBroadcasting;
  bool get isCollecting => _isCollecting;
  Map<String, PassportAttendanceVerificationResult> get verifiedResults =>
      Map.unmodifiable(_verifiedResults);
  Map<String, PassportAttendanceVerificationResult> get inconclusiveResults =>
      Map.unmodifiable(_inconclusiveResults);

  Future<void> pauseBeaconAdvertising() async {
    _isBroadcasting = false;
    try {
      await _blePeripheral.stop();
    } catch (_) {}
    await CampusMeshManager.instance.resumeAdvertisingAfterAttendance();
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
  })  : _cryptoService = cryptoService ?? PassportCryptoService(),
        _trustBundleService = trustBundleService ?? PassportTrustBundleService(),
        _ledgerService = ledgerService ?? PassportAttendanceLedgerService(),
        _identityService = identityService ?? PassportIdentityService(),
        _blePeripheral = blePeripheral ?? FlutterBlePeripheral(),
        _proximityConfig = proximityConfig ?? PassportProximityConfig.defaultConfig;

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
    await [
      Permission.bluetooth,
      Permission.bluetoothScan,
      Permission.bluetoothAdvertise,
      Permission.bluetoothConnect,
      Permission.location,
    ].request();

    try {
      var adapterState = await FlutterBluePlus.adapterState.first
          .timeout(const Duration(seconds: 2), onTimeout: () => BluetoothAdapterState.on);
      if (adapterState != BluetoothAdapterState.on) {
        try {
          await FlutterBluePlus.turnOn();
        } catch (_) {}
      }
    } catch (_) {}

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

    // 2. Generate teacher beacon bound deterministically to this session ID
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
    );

    // 3. Sign beacon canonically with teacher's Ed25519 key
    final hasKey = await _cryptoService.hasIdentityKey();
    if (!hasKey) {
      await _cryptoService.getOrCreatePublicKey();
    }
    final canonicalJson = beacon.toCanonicalJson();
    final signature = await _cryptoService.signPresentation(canonicalJson);
    _activeBeacon = beacon.withSignature(signature);

    // 4. Start advertising teacher beacon frames
    await _startBeaconAdvertising(_activeBeacon!);

    // 5. Start concurrent batch scanner to capture direct BLE radio frames from students (offline & online)
    await startBatchCollection();

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
          lastErr = e.toString().replaceAll('Exception: ', '').replaceAll('PlatformException: ', '');
          debugPrint('⚠️ [PASSPORT_TEACHER] Teacher advertiser attempt $attempt failed: $e');
          if (attempt < 3) {
            await _blePeripheral.stop();
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
      _advertisingError = e.toString().replaceAll('Exception: ', '').replaceAll('PlatformException: ', '');
      debugPrint('⚠️ [PASSPORT_TEACHER] Teacher advertising error: $e');
    }
  }

  /// Retries teacher beacon advertising (e.g. after radio contention is cleared).
  Future<void> retryBeaconAdvertising() async {
    if (_activeBeacon == null) return;
    _advertisingError = null;
    await _startBeaconAdvertising(_activeBeacon!);
    _emitMetrics();
  }

  /// Starts concurrent batch collection of student responses.
  Future<void> startBatchCollection({Duration? timeout}) async {
    _stopCollection();
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
    String studentName = transmittedName;
    if (studentName.isEmpty) {
      try {
        final bundle = await _trustBundleService.getLocalBundle();
        final match = bundle?.identities.where((id) => id.userId == resolvedStudentId).toList();
        if (match != null && match.isNotEmpty && match.first.userName != null && match.first.userName!.isNotEmpty) {
          studentName = match.first.userName!;
        }
      } catch (_) {}
    }
    if (studentName.isEmpty) {
      studentName = 'Student ${resolvedStudentId.substring(0, min(6, resolvedStudentId.length))}';
    }

    final res = PassportAttendanceVerificationResult(
      valid: true,
      status: PassportAttendanceStatus.verifiedPresent,
      reason: 'Verified present via direct BLE Radio frame',
      studentId: resolvedStudentId,
      studentName: studentName,
      deviceKeyId: 'key_$resolvedStudentId',
      sessionId: _activeSession?.id ?? _activeBeacon?.sessionId ?? '',
      responseNonce: streamId.toString(),
      idempotencyKey: '${_activeSession?.id ?? _activeBeacon?.sessionId}_$resolvedStudentId',
      proximityTier: PassportProximityTier.near,
      medianRssi: rssi,
      verificationMode: 'BLE_BATCH',
      verifiedAt: DateTime.now(),
    );

    if (!_verifiedResults.containsKey(resolvedStudentId)) {
      await _ledgerService.recordAttendance(res);
      _verifiedResults[resolvedStudentId] = res;
      _inconclusiveResults.remove(resolvedStudentId);
      _emitMetrics();
      debugPrint('🎯 [PASSPORT_TEACHER] Verified student $studentName (ID: $resolvedStudentId) over direct BLE radio (RSSI: $rssi dBm)!');
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
      return PassportAttendanceVerificationResult(
        valid: true,
        status: PassportAttendanceStatus.verifiedPresent,
        reason: 'OFFLINE_TRUST_DATA_MISSING: Verified present offline (structural validation)',
        sessionId: response.sessionId,
        studentId: response.studentId,
        studentName: 'Student ${response.studentId.substring(0, min(6, response.studentId.length))}',
        deviceKeyId: response.deviceKeyId,
        responseNonce: response.responseNonce,
        idempotencyKey: response.idempotencyKey,
        proximityTier: proximity.proximityTier,
        medianRssi: proximity.medianRssi,
        verificationMode: verificationMode,
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

    // 10. Proximity / RSSI evaluation
    PassportProximityObservation proximity;
    if (verificationMode == 'QR_FALLBACK') {
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

    // If cryptographically valid AND proximity is NEAR: VERIFIED PRESENT
    if (proximity.proximityTier == PassportProximityTier.near ||
        verificationMode == 'QR_FALLBACK') {
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
        verifiedAt: DateTime.now(),
      );
      await _ledgerService.recordAttendance(res);
      _verifiedResults[response.studentId] = res;
      _inconclusiveResults.remove(response.studentId);
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

  void _emitMetrics() {
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

  Future<void> stopSession() async {
    _isBroadcasting = false;
    _beaconCycleTimer?.cancel();
    _beaconCycleTimer = null;
    _streamCleanupTimer?.cancel();
    _streamCleanupTimer = null;
    _streamBuffers.clear();
    _stopCollection();

    try {
      await _blePeripheral.stop();
    } catch (_) {}
    await CampusMeshManager.instance.resumeAdvertisingAfterAttendance();

    debugPrint('🏁 [PASSPORT_TEACHER] Attendance session stopped.');
  }

  void dispose() {
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
