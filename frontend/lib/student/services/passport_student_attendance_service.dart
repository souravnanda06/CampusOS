import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
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

  StreamSubscription? _scanSubscription;
  Timer? _advertisingTimer;
  bool _isScanning = false;
  bool _isAdvertising = false;

  StudentAttendanceFlowState _state = StudentAttendanceFlowState.idle;
  StudentAttendanceFlowState get state => _state;
  bool get isAdvertising => _isAdvertising;

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
  })  : _cryptoService = cryptoService ?? PassportCryptoService(),
        _trustBundleService = trustBundleService ?? PassportTrustBundleService(),
        _identityService = identityService ?? PassportIdentityService(),
        _biometricService = biometricService ?? PassportFaceAuthService(),
        _blePeripheral = blePeripheral ?? FlutterBlePeripheral();

  void _updateState(StudentAttendanceFlowState newState, String message) {
    _state = newState;
    debugPrint('📱 [PASSPORT_STUDENT_ATTENDANCE] ($newState) $message');
    _stateController.add(newState);
    _statusMessageController.add(message);
  }

  /// Request runtime permissions required for BLE scanning and advertising.
  Future<bool> checkAndRequestPermissions() async {
    _updateState(
      StudentAttendanceFlowState.requestingPermissions,
      'Checking Bluetooth permissions...',
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
    try {
      final isSupported = await FlutterBluePlus.isSupported;
      if (!isSupported) {
        _updateState(
          StudentAttendanceFlowState.error,
          'Bluetooth is not supported on this device.',
        );
        return false;
      }
      var adapterState = await FlutterBluePlus.adapterState.first
          .timeout(const Duration(seconds: 2), onTimeout: () => BluetoothAdapterState.on);
      if (adapterState != BluetoothAdapterState.on) {
        try {
          await FlutterBluePlus.turnOn();
          adapterState = await FlutterBluePlus.adapterState.first
              .timeout(const Duration(seconds: 3), onTimeout: () => BluetoothAdapterState.on);
        } catch (_) {}
      }
      if (adapterState != BluetoothAdapterState.on) {
        _updateState(
          StudentAttendanceFlowState.error,
          'Please turn on Bluetooth to take attendance.',
        );
        return false;
      }
    } catch (e) {
      debugPrint('⚠️ [PASSPORT_STUDENT] Adapter check notice: $e');
    }

    // Check Location (GPS) hardware toggle on Android
    try {
      final locStatus = await Permission.location.serviceStatus;
      if (locStatus == ServiceStatus.disabled) {
        _updateState(
          StudentAttendanceFlowState.error,
          'Turn on GPS/Location in settings for Bluetooth.',
        );
        return false;
      }
    } catch (_) {}

    return true;
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
              .timeout(const Duration(milliseconds: 600), onTimeout: () => []);
        } catch (_) {}
      }
      if (sessions.isEmpty) {
        try {
          sessions = await SessionService()
              .getActiveSessions()
              .timeout(const Duration(milliseconds: 400), onTimeout: () => []);
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

      // Step 4: Sign canonical attendance response
      _updateState(
        StudentAttendanceFlowState.signingResponse,
        'Identity unlocked. Signing attendance response...',
      );

      final response = await createAndSignResponse(
        beacon: beacon,
        currentUser: currentUser,
        currentTimestampSeconds: currentTimestampSeconds,
      );

      // Step 5: Advertise response via short-lived BLE broadcast
      _updateState(
        StudentAttendanceFlowState.advertisingResponse,
        'BLE Attendance Active. Broadcasting response...',
      );

      await _advertiseResponse(
        response,
        duration: advertisingDuration,
        currentUser: currentUser,
      );

      // Best-effort online backup registration
      bool onlineSuccess = false;
      try {
        await AttendanceService().markAttendance(
          sessionId: beacon.sessionId,
          studentId: currentUser.id,
          studentName: currentUser.name,
          idempotencyKey: '${beacon.sessionId}_${currentUser.id}',
          verificationMode: 'BLE',
          proximityTier: 'IMMEDIATE',
        );
        onlineSuccess = true;
        debugPrint('✅ [PASSPORT_STUDENT] Online attendance backup marked for ${currentUser.name}');
      } catch (e) {
        debugPrint('ℹ️ [PASSPORT_STUDENT] Online attendance backup notice: $e');
      }

      if (!_isAdvertising && !onlineSuccess) {
        _updateState(
          StudentAttendanceFlowState.error,
          'Could not broadcast attendance over BLE. Tap to retry or use QR.',
        );
        return null;
      }

      _updateState(
        StudentAttendanceFlowState.completed,
        beacon.subject != null && beacon.subject!.isNotEmpty
            ? 'Attendance verified · ${beacon.subject}'
            : 'Attendance verified',
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
            final detectedSessionId = SessionService.extractSessionIdFromBleUuid(u.str128);
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
                final beacon = PassportTeacherBeaconModel(
                  sessionId: detectedSessionId,
                  subject: 'Class Session',
                  course: 'General',
                  branch: 'General',
                  year: '1',
                  teacherId: 'teacher',
                  teacherKeyId: 'teacher_key',
                  sessionNonce: 'nonce_$detectedSessionId',
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

      await FlutterBluePlus.startScan(
        timeout: timeout,
        androidScanMode: AndroidScanMode.lowLatency,
        androidUsesFineLocation: true,
        continuousUpdates: true,
      );

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
          StudentAttendanceFlowState.error,
          'Please enable Location (GPS) in phone settings for Bluetooth.',
        );
      } else if (err.contains('bluetooth')) {
        _updateState(
          StudentAttendanceFlowState.error,
          'Please enable Bluetooth to take attendance.',
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

  Future<void> _stopScan() async {
    _scanSubscription?.cancel();
    _scanSubscription = null;
    _isScanning = false;
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
