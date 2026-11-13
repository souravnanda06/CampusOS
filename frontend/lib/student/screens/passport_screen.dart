import 'campus_scanner_screen.dart';
import '../../shared/models/session_model.dart';
import '../../shared/services/session_service.dart';
import 'dart:async';
import 'package:attendance_app/core/haptics/app_haptics.dart';

import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../auth/models/user_model.dart';
import '../../auth/providers/user_provider.dart';
import '../../auth/services/auth_service.dart';
import '../../core/theme/app_colors.dart';
import '../../router/app_routes.dart';
import '../../shared/providers/attendance_provider.dart';
import '../models/gate_pass_model.dart';
import '../models/passport_identity_model.dart';
import '../models/passport_presentation_model.dart';
import '../models/passport_wallet_state.dart';
import '../services/gate_pass_service.dart';
import '../services/passport_biometric_service.dart';
import '../services/passport_face_auth_service.dart';
import '../services/passport_challenge_scanner_service.dart';
import '../services/passport_crypto_service.dart';
import '../services/passport_identity_service.dart';
import '../services/passport_presentation_service.dart';
import '../services/passport_student_attendance_service.dart';
import '../services/passport_trust_bundle_service.dart';
import '../widgets/passport/campus_wallet.dart';
import '../widgets/passport/passport_active_view.dart';
import '../widgets/requests/gate_pass_form.dart';

/// Backward-compatible alias for the Passport state enum.
typedef PassportUiState = PassportWalletState;

/// Flagship Campus Wallet screen for students.
///
/// Integrates:
/// - Horizontally swipeable credential cards (Campus Passport, Student ID, Gate Pass)
/// - Contextual biometric / PIN authentication affordances
/// - Ed25519 hardware-backed device identity management (first-time activation & reactivation)
/// - 30-second dynamic rotating presentation with isolated countdown
/// - Seamless batch BLE attendance verification without redundant biometric prompts
/// - Mess dining credential validation through the primary Passport
/// - HMAC-SHA256 Gate Pass credential viewing
/// - Floating QR scanner for campus verification
class PassportScreen extends StatefulWidget {
  final UserModel? user;

  /// Flag indicating whether the student is currently on the Passport tab (tab index 1).
  final bool isActiveTab;
  final ValueNotifier<bool> isFullScreenActive;
  final PassportStudentAttendanceService? studentAttendanceService;
  final PassportBiometricAuthProvider? biometricService;
  final PassportCryptoService? cryptoService;
  final PassportIdentityService? identityService;

  PassportScreen({
    Key? key,
    required this.user,
    this.isActiveTab = true,
    ValueNotifier<bool>? isFullScreenActive,
    this.studentAttendanceService,
    this.biometricService,
    this.cryptoService,
    this.identityService,
  })  : isFullScreenActive = isFullScreenActive ?? ValueNotifier<bool>(false),
        super(key: key);

  @override
  State<PassportScreen> createState() => _PassportScreenState();
}

class _PassportScreenState extends State<PassportScreen>
    with WidgetsBindingObserver {
  final GatePassService _gatePassService = GatePassService();
  late final PassportCryptoService _cryptoService;
  late final PassportIdentityService _identityService;
  late final PassportPresentationService _presentationService;
  final PassportChallengeScannerService _challengeScannerService =
      PassportChallengeScannerService();
  late final PassportStudentAttendanceService _studentAttendanceService;
  late final PassportBiometricAuthProvider _biometricService;
  bool _isScanningLoopActive = false;
  String? _verifiedSessionId;
  final Set<String> _verifiedSessionIds = <String>{};
  StudentAttendanceFlowState _attendanceFlowState = StudentAttendanceFlowState.idle;
  String _attendanceStatusMessage = '';

  // State Machine
  PassportWalletState _walletState = PassportWalletState.uninitialized;
  String? _errorMessage;
  bool _isActivatingPassport = false;
  bool _isExpandedActiveView = false;
  bool _isGatePassUnlocked = false;
  bool _isLoadingGatePass = true;
  bool _isBluetoothActive = true;
  bool _isAttendanceActive = false;
  bool _isChirpActive = false;
  final GlobalKey<PassportActiveViewState> _activePassportViewKey =
      GlobalKey<PassportActiveViewState>();
  bool _isReversingToWallet = false;

  /// Smoothly reverses the 3D card animation from vertical to horizontal before exiting to the wallet deck
  Future<void> _handleBackToWallet() async {
    _stopInactivityTimer();
    await _stopAttendanceFlow(clearVerified: true);
    if (_isReversingToWallet) return;
    _isReversingToWallet = true;

    try {
      if (_activePassportViewKey.currentState != null) {
        await _activePassportViewKey.currentState!.reverseToHorizontal();
      }
    } catch (_) {}

    if (mounted) {
      setState(() {
        _isExpandedActiveView = false;
        _walletState = PassportWalletState.locked;
        _currentPresentation = null;
      });
      widget.isFullScreenActive.value = false;
      _isReversingToWallet = false;
    }
  }

  // Credential Data
  GatePassModel? _activeGatePass;
  PassportEnrollmentStatus? _enrollmentStatus;
  PassportPresentationModel? _currentPresentation;

  // Isolated countdown notifier (zero whole-screen rebuilds)
  final ValueNotifier<int> _qrRemainingSecondsNotifier = ValueNotifier<int>(30);

  // Subscriptions & Timers
  Timer? _rotationTimer;
  Timer? _inactivityLockTimer;
  static const Duration _inactivityTimeout = Duration(seconds: 90);
  StreamSubscription? _bluetoothSub;
  StreamSubscription? _attendanceStateSub;
  StreamSubscription? _attendanceMsgSub;
  DateTime? _lastPausedAt;

  /// Resets the 90-second inactivity lock timer whenever the user interacts with the screen
  void _resetInactivityTimer() {
    if (_walletState == PassportWalletState.active) {
      _inactivityLockTimer?.cancel();
      _inactivityLockTimer = Timer(_inactivityTimeout, _handleInactivityLock);
    }
  }

  /// Cancels the inactivity lock timer
  void _stopInactivityTimer() {
    _inactivityLockTimer?.cancel();
    _inactivityLockTimer = null;
  }

  /// Automatically locks the Passport back to locked state after 90 seconds of inactivity
  void _handleInactivityLock() {
    if (!mounted) return;
    if (_walletState == PassportWalletState.active) {
      debugPrint("🔒 [PASSPORT_SCREEN] Inactivity timeout (90s): Automatically locking Passport.");
      _stopRotationTimer();
      _stopInactivityTimer();
      _stopAttendanceFlow(clearVerified: true);
      if (_isChirpActive) {
        _challengeScannerService.stopProximityChirp();
        _isChirpActive = false;
      }
      setState(() {
        _walletState = PassportWalletState.locked;
        _isExpandedActiveView = false;
        _currentPresentation = null;
      });
      widget.isFullScreenActive.value = false;
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _cryptoService = widget.cryptoService ?? PassportCryptoService();
    _identityService = widget.identityService ?? PassportIdentityService();
    _studentAttendanceService =
        widget.studentAttendanceService ?? PassportStudentAttendanceService();
    _biometricService =
        widget.biometricService ?? PassportFaceAuthService();
    _presentationService = PassportPresentationService(
      cryptoService: _cryptoService,
      identityService: _identityService,
    );

    _initBluetoothListener();
    _initAttendanceListeners();
    _loadAll();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _stopAttendanceFlow(notify: false);
    _rotationTimer?.cancel();
    _inactivityLockTimer?.cancel();
    _bluetoothSub?.cancel();
    _attendanceStateSub?.cancel();
    _attendanceMsgSub?.cancel();
    _challengeScannerService.stopProximityChirp();
    _challengeScannerService.dispose();
    _studentAttendanceService.dispose();
    _qrRemainingSecondsNotifier.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      if (_lastPausedAt != null) {
        final elapsed = DateTime.now().difference(_lastPausedAt!);
        _lastPausedAt = null;
        if (elapsed > _inactivityTimeout) {
          debugPrint("🔒 [PASSPORT_SCREEN] Backgrounded for > 90s: Automatically locking Passport.");
          _stopInactivityTimer();
          _stopAttendanceFlow(notify: false, clearVerified: true);
          if (mounted) {
            setState(() {
              _walletState = PassportWalletState.locked;
              _isExpandedActiveView = false;
              _currentPresentation = null;
            });
            widget.isFullScreenActive.value = false;
          }
          return;
        }
      }
      if (_walletState == PassportWalletState.active) {
        if (_currentPresentation == null || _currentPresentation!.isExpired()) {
          _rotatePresentation();
        }
        _resetInactivityTimer();
        _startAttendanceFlowIfNeeded();
      }
    } else if (state == AppLifecycleState.paused) {
      _lastPausedAt = DateTime.now();
      // NOTE: Do not immediately lock _walletState or reset _isExpandedActiveView here.
      // On Android, system permission dialogs and Bluetooth enable dialogs (FlutterBluePlus.turnOn)
      // cause the host Activity to pause. Instantly locking here kicks students out of the active
      // passport before they can accept or deny the prompt.
      // If the student actually leaves the app for longer than _inactivityTimeout, it locks upon resume.
    }
    // NOTE: On AppLifecycleState.inactive, do nothing. Inactive represents transient system overlays
    // (notification drawer, permission dialogs, biometric sheets) and must never lock the passport.
  }

  @override
  void didUpdateWidget(covariant PassportScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.isActiveTab && oldWidget.isActiveTab) {
      // User switched away from Passport tab: stop all BLE loops immediately and relock
      _stopInactivityTimer();
      _stopAttendanceFlow(notify: false, clearVerified: true);
      _walletState = PassportWalletState.locked;
      _isExpandedActiveView = false;
      _currentPresentation = null;
    } else if (widget.isActiveTab && !oldWidget.isActiveTab) {
      // User switched to Passport tab: keep in locked state until face verification
    }
  }

  void _initBluetoothListener() {
    try {
      FlutterBluePlus.isSupported.then((supported) {
        if (supported && mounted) {
          FlutterBluePlus.adapterState.first
              .timeout(const Duration(seconds: 1), onTimeout: () => BluetoothAdapterState.on)
              .then((state) {
            if (mounted) {
              setState(() {
                _isBluetoothActive = state == BluetoothAdapterState.on;
              });
            }
          });
          _bluetoothSub = FlutterBluePlus.adapterState.listen((state) {
            if (mounted) {
              final isOn = state == BluetoothAdapterState.on;
              setState(() {
                _isBluetoothActive = isOn;
              });
              if (isOn) {
                _studentAttendanceService.resetBluetoothDeclinedSession();
                if (_isExpandedActiveView && _walletState == PassportWalletState.active) {
                  _startAttendanceFlowIfNeeded();
                }
              }
            }
          }, onError: (e) {
            debugPrint("⚠️ [PASSPORT] Bluetooth stream error: $e");
          });
        }
      }).catchError((e) {
        debugPrint("⚠️ [PASSPORT] Bluetooth not supported in this environment: $e");
      });
    } on UnsupportedError catch (ue) {
      debugPrint("⚠️ [PASSPORT] Bluetooth unsupported on platform: $ue");
    } catch (e) {
      debugPrint("⚠️ [PASSPORT] Bluetooth adapter listener error: $e");
    }
  }

  void _initAttendanceListeners() {
    _attendanceStateSub = _studentAttendanceService.stateStream.listen((state) {
      if (mounted) {
        setState(() {
          _attendanceFlowState = state;
          _isAttendanceActive = state == StudentAttendanceFlowState.scanningForTeacherBeacon ||
              state == StudentAttendanceFlowState.authenticatingTeacher ||
              state == StudentAttendanceFlowState.signingResponse ||
              state == StudentAttendanceFlowState.advertisingResponse;
        });
      }
    });

    _attendanceMsgSub = _studentAttendanceService.statusMessageStream.listen((msg) {
      if (mounted) {
        setState(() {
          _attendanceStatusMessage = msg;
        });
        if (msg.isNotEmpty) {
          debugPrint("📱 [ATTENDANCE_MSG] $msg");
        }
      }
    });
  }

  Future<void> _loadAll() async {
    await Future.wait([
      _loadPassportIdentity(),
      _loadActiveGatePass(),
      _loadTrustBundle(),
    ]);
  }

  Future<void> _loadTrustBundle() async {
    try {
      final trustBundleService = PassportTrustBundleService(
        storage: _cryptoService.storage,
        cryptoService: _cryptoService,
      );
      final hasBundle = await trustBundleService.hasValidLocalBundle();
      if (!hasBundle) {
        await trustBundleService.downloadAndSaveBundle();
        debugPrint('✅ [PASSPORT_SCREEN] Institutional trust bundle downloaded and cached locally.');
      }
    } catch (e) {
      debugPrint("ℹ️ [PASSPORT_SCREEN] Trust bundle fetch note: $e");
    }
  }

  Future<void> _loadActiveGatePass() async {
    final studentId = widget.user?.id ??
        (mounted ? Provider.of<UserProvider>(context, listen: false).user?.id : null);
    if (studentId == null || studentId.isEmpty) {
      if (mounted) {
        setState(() {
          _isLoadingGatePass = false;
        });
      }
      return;
    }

    setState(() {
      _isLoadingGatePass = true;
    });

    try {
      final active = await _gatePassService.getActiveGatePass(studentId);
      if (mounted) {
        setState(() {
          _activeGatePass = active;
          _isLoadingGatePass = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingGatePass = false;
        });
      }
    }
  }

  Future<void> _loadPassportIdentity() async {
    setState(() {
      _errorMessage = null;
    });

    try {
      String? studentId = widget.user?.id;
      if (studentId == null || studentId.isEmpty) {
        if (mounted) {
          studentId = Provider.of<UserProvider>(context, listen: false).user?.id;
        }
      }
      if (studentId == null || studentId.isEmpty) {
        final storedUser = await AuthService().getUserDataFromStorage();
        studentId = storedUser?.id;
      }

      // Check hardware-backed keystore for local identity key first
      final hasLocalKey = await _cryptoService.hasIdentityKey();
      final localPubKey = await _cryptoService.getPublicKeyBase64();

      final status = await _identityService.getIdentity(userId: studentId);
      if (!mounted) return;

      if (hasLocalKey) {
        // NORMAL RESTART: Hardware key is present on device.
        // Check if server reports revocation or expiration
        if (status.enrolled && status.key != null) {
          final serverKey = status.key!;
          if (!serverKey.isActive ||
              status.certificate?.status == 'REVOKED' ||
              (status.certificate?.isExpired ?? false)) {
            _stopRotationTimer();
            setState(() {
              _enrollmentStatus = status;
              _currentPresentation = null;
              _walletState = PassportWalletState.error;
              _errorMessage = (status.certificate?.isExpired ?? false)
                  ? "Passport certificate has expired."
                  : "Passport certificate has been revoked.";
            });
            return;
          }

          // Check if server public key matches our local public key
          if (localPubKey != null &&
              localPubKey.trim() != serverKey.publicKey.trim()) {
            _stopRotationTimer();
            setState(() {
              _enrollmentStatus = status;
              _currentPresentation = null;
              _walletState = PassportWalletState.keyMissing;
              _errorMessage = "Identity bound to another device. Reactivation required.";
            });
            return;
          }
          // Key exists and is valid -> lands securely in State 2: Activated but locked
          _enrollmentStatus = status;
          if (_walletState != PassportWalletState.active) {
            setState(() {
              _walletState = PassportWalletState.locked;
            });
          }
        } else {
          // Local key exists, but no active enrollment found on server or locally
          _stopRotationTimer();
          _currentPresentation = null;
          setState(() {
            _enrollmentStatus = status;
            _walletState = PassportWalletState.uninitialized;
          });
        }
      } else {
        // No local key found in hardware keystore
        _stopRotationTimer();
        _currentPresentation = null;
        if (status.enrolled && status.key != null) {
          // Account was certified, but local device has no key -> State 4: Genuine identity loss
          setState(() {
            _enrollmentStatus = status;
            _walletState = PassportWalletState.keyMissing;
            _errorMessage = "Passport identity key is not found on this device.";
          });
        } else {
          // User never activated Passport -> State 1: Never activated
          setState(() {
            _enrollmentStatus = status;
            _walletState = PassportWalletState.uninitialized;
          });
        }
      }
    } catch (e) {
    if (mounted) {
      final hasLocalKey = await _cryptoService.hasIdentityKey();
      final cached = await _identityService.getCachedIdentity();
      if (hasLocalKey && cached != null && cached.enrolled && cached.key != null) {
        final localPubKey = await _cryptoService.getPublicKeyBase64();
        if (localPubKey != null && localPubKey.trim() == cached.key!.publicKey.trim()) {
          if (cached.certificate?.isExpired ?? false) {
            setState(() {
              _enrollmentStatus = cached;
              _walletState = PassportWalletState.error;
              _errorMessage = "Passport certificate has expired.";
            });
            return;
          }
          _enrollmentStatus = cached;
          if (_walletState != PassportWalletState.active) {
            setState(() {
              _walletState = PassportWalletState.locked;
            });
          }
          return;
        }
      }

      if (!hasLocalKey) {
        _stopRotationTimer();
        setState(() {
          _walletState = PassportWalletState.uninitialized;
        });
      } else {
        _stopRotationTimer();
        setState(() {
          _walletState = PassportWalletState.error;
          _errorMessage = e.toString().replaceAll('Exception: ', '');
        });
      }
    }
  }
}

  /// CampusOS Face ID authentication engine (Aadhaar-style face verification).
  /// Strictly requires live face verification to prevent proxy attendance (no fingerprint/PIN bypass).
  Future<BiometricAuthResult> _authenticateUser({
    required String reason,
    required String studentId,
    bool biometricOnly = false,
  }) async {
    // If an explicit mock provider was injected for testing, respect it
    if (widget.biometricService != null) {
      return await _biometricService.authenticate(
        reason: reason,
        biometricOnly: biometricOnly,
      );
    }

    // CampusOS Face ID Authentication Engine
    final sId = PassportFaceAuthService.resolveActiveStudentId(studentId);
    final faceService = PassportFaceAuthService();
    final isEnrolled = await faceService.isFaceEnrolled(sId);
    if (!isEnrolled) {
      if (!mounted) return BiometricAuthResult.cancelled;
      final enrolled = await Navigator.of(context).pushNamed(
        AppRoutes.faceEnrollment,
        arguments: sId,
      );
      if (enrolled != true) {
        return BiometricAuthResult.cancelled;
      }
    }

    if (!mounted) return BiometricAuthResult.cancelled;
    return await faceService.verifyFaceIdentity(
      studentId: sId,
      context: context,
      reason: reason,
    );
  }

  Future<void> _unlockPassport() async {
    if (_walletState == PassportWalletState.uninitialized ||
        _walletState == PassportWalletState.keyMissing) {
      final hasKey = await _cryptoService.hasIdentityKey();
      if (hasKey) {
        setState(() {
          _walletState = PassportWalletState.locked;
        });
      } else {
        await _activatePassport();
        return;
      }
    }

    setState(() {
      _walletState = PassportWalletState.authenticating;
    });

    try {
      final studentId = PassportFaceAuthService.resolveActiveStudentId(
        widget.user?.id ??
            (mounted ? Provider.of<UserProvider>(context, listen: false).user?.id : null),
      );

      final bioResult = await _authenticateUser(
        reason: 'Verify face to unlock Campus Passport',
        studentId: studentId,
        biometricOnly: false,
      );

      if (!bioResult.isSuccess) {
        if (mounted) {
          setState(() {
            _walletState = PassportWalletState.locked;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(bioResult.message),
              backgroundColor: AppColors.warning,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
        return;
      }

      // Biometric success! Instantly activate and reveal active credential presentation
      if (mounted) {
        setState(() {
          _walletState = PassportWalletState.active;
          _isExpandedActiveView = true;
          _verifiedSessionId = null;
          _verifiedSessionIds.clear();
          _attendanceFlowState = StudentAttendanceFlowState.idle;
          _attendanceStatusMessage = '';
        });
        widget.isFullScreenActive.value = true;
        _startRotationTimer();
        _resetInactivityTimer();
        AppHaptics.mediumImpact();
        _startAttendanceFlowIfNeeded();
      }

      // Generate/rotate dynamic presentation in background without blocking transition
      await _rotatePresentation();
    } catch (e) {
      if (mounted) {
        setState(() {
          _walletState = PassportWalletState.error;
          _errorMessage = e.toString();
        });
      }
    }
  }

  Future<void> _activatePassport() async {
    final studentId = PassportFaceAuthService.resolveActiveStudentId(
      widget.user?.id ??
          (mounted ? Provider.of<UserProvider>(context, listen: false).user?.id : null),
    );
    setState(() {
      _isActivatingPassport = true;
    });

    try {
      // 1. Authenticate user intent with biometric / Face ID
      final bioResult = await _authenticateUser(
        reason: 'Authenticate to generate secure device identity for Campus Passport',
        studentId: studentId,
        biometricOnly: false,
      );

      if (!bioResult.isSuccess) {
        if (mounted) {
          setState(() {
            _isActivatingPassport = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Activation cancelled: ${bioResult.message}'),
              backgroundColor: AppColors.warning,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
        return;
      }

      // 2. Clear any stale key and generate fresh Ed25519 keypair on this device
      await _cryptoService.clearIdentityKey();
      final pubKeyB64 = await _cryptoService.getOrCreatePublicKey();

      // 3. If user already had an active key on backend, revoke it first to avoid 409 Conflict
      var activeKeyId = _enrollmentStatus?.key?.id;
      if (activeKeyId == null) {
        try {
          final currentStatus = await _identityService.getIdentity(userId: studentId);
          if (currentStatus.enrolled && currentStatus.key != null) {
            activeKeyId = currentStatus.key!.id;
          }
        } catch (_) {}
      }
      if (activeKeyId != null) {
        try {
          await _identityService.revokeKey(
            activeKeyId,
            requesterId: studentId,
          );
        } catch (_) {}
      }

      // 4. Register fresh public key with backend key registry
      await _identityService.registerKey(
        publicKey: pubKeyB64,
        userId: studentId,
      );

      // 5. Instantly transition to active credential presentation on first unlock
      if (mounted) {
        setState(() {
          _walletState = PassportWalletState.active;
          _isExpandedActiveView = true;
          _verifiedSessionId = null;
          _verifiedSessionIds.clear();
          _attendanceFlowState = StudentAttendanceFlowState.idle;
          _attendanceStatusMessage = '';
        });
        widget.isFullScreenActive.value = true;
        _startRotationTimer();
        _resetInactivityTimer();
        AppHaptics.mediumImpact();
        _startAttendanceFlowIfNeeded();

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle_outline_rounded, color: Colors.white),
                SizedBox(width: 8),
                Expanded(child: Text("Campus Passport activated successfully!")),
              ],
            ),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }

      // 6. Reload identity and rotate presentation in background without blocking transition
      _loadPassportIdentity().then((_) {
        _rotatePresentation();
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Activation failed: ${e.toString().replaceAll('Exception: ', '')}"),
            backgroundColor: AppColors.danger,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isActivatingPassport = false;
        });
      }
    }
  }

  void _startRotationTimer() {
    _rotationTimer?.cancel();
    _rotationTimer = Timer.periodic(const Duration(seconds: 1), (timer) async {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_walletState != PassportWalletState.active) {
        timer.cancel();
        return;
      }

      final rem = _currentPresentation != null
          ? _currentPresentation!.remainingSeconds()
          : 0;

      if (rem <= 0) {
        await _rotatePresentation();
      } else {
        _qrRemainingSecondsNotifier.value = rem;
      }
    });
  }

  void _stopRotationTimer() {
    _rotationTimer?.cancel();
    _rotationTimer = null;
  }

  Future<void> _rotatePresentation() async {
    if (_enrollmentStatus == null || !_enrollmentStatus!.enrolled) {
      final cached = await _identityService.getCachedIdentity();
      if (cached != null && cached.enrolled) {
        _enrollmentStatus = cached;
      } else {
        try {
          final studentId = widget.user?.id;
          final status = await _identityService.getIdentity(userId: studentId);
          if (status.enrolled) {
            _enrollmentStatus = status;
          } else {
            return;
          }
        } catch (_) {
          return;
        }
      }
    }
    try {
      final presentation = await _presentationService.createPresentation(
        cachedStatus: _enrollmentStatus,
      );
      if (mounted) {
        setState(() {
          _currentPresentation = presentation;
          _qrRemainingSecondsNotifier.value = presentation.remainingSeconds();
          _walletState = PassportWalletState.active;
        });
        _startProximityChirpIfNeeded(presentation);
      }
    } catch (e) {
      debugPrint("❌ [PASSPORT_SCREEN] _rotatePresentation error: $e");
    }
  }

  void _startProximityChirpIfNeeded(PassportPresentationModel presentation) {
    if (!presentation.isChallengebound) {
      if (_isChirpActive) {
        _challengeScannerService.stopProximityChirp();
        setState(() {
          _isChirpActive = false;
        });
      }
      return;
    }

    final nonce = presentation.challenge?['nonce']?.toString();
    if (nonce == null || nonce.isEmpty) return;

    _challengeScannerService
        .broadcastProximityChirp(
      challengeNonce: nonce,
      duration: const Duration(seconds: 4),
    )
        .then((success) {
      if (mounted) {
        setState(() {
          _isChirpActive = success;
        });
        if (success) {
          Future.delayed(const Duration(seconds: 4), () {
            if (mounted) {
              setState(() {
                _isChirpActive = false;
              });
            }
          });
        }
      }
    });
  }

  Future<void> _unlockGatePass() async {
    final studentId = PassportFaceAuthService.resolveActiveStudentId(
      widget.user?.id ??
          (mounted ? Provider.of<UserProvider>(context, listen: false).user?.id : null),
    );
    final bioResult = await _authenticateUser(
      reason: 'Verify biometric identity to access Gate Pass credential',
      studentId: studentId,
      biometricOnly: false,
    );

    if (bioResult.isSuccess) {
      if (mounted) {
        setState(() {
          _isGatePassUnlocked = true;
        });
        _showGatePassQrSheet();
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(bioResult.message),
            backgroundColor: AppColors.warning,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  void _showGatePassQrSheet() {
    final pass = _activeGatePass;
    if (pass == null || pass.credential == null) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(24),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.divider,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 18),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.shield_rounded, size: 20, color: Color(0xFFA855F7)),
                  const SizedBox(width: 8),
                  Text(
                    'Campus Gate Pass',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                'Present this QR to Security Guard at campus exit/entry',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 12.5,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.border),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.08),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: QrImageView(
                  data: pass.credential!,
                  version: QrVersions.auto,
                  size: 200,
                  backgroundColor: Colors.white,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Destination: ${pass.destination}',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Valid: ${DateFormat('hh:mm a').format(pass.expectedExitTime)} → ${DateFormat('hh:mm a, MMM dd').format(pass.expectedReturnTime)}',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        );
      },
    );
  }

  void _showNewGatePassForm() async {
    final res = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => GatePassForm(
        onRequestSubmitted: _loadActiveGatePass,
      ),
    );
    if (res == true) {
      _loadActiveGatePass();
    }
  }

  void _startAttendanceFlowIfNeeded() {
    if (!widget.isActiveTab) {
      debugPrint("🚫 [PASSPORT] Will not start attendance BLE: Passport tab is not active.");
      return;
    }
    if (!_isExpandedActiveView || _walletState != PassportWalletState.active) {
      debugPrint("🚫 [PASSPORT] Will not start attendance BLE: Active Passport card is not open.");
      return;
    }
    if (_isScanningLoopActive) {
      debugPrint("ℹ️ [PASSPORT] Ambient attendance BLE loop already active.");
      return;
    }
    _startAmbientAttendanceLoop();
  }

  Future<void> _stopAttendanceFlow({bool notify = true, bool clearVerified = false}) async {
    _isScanningLoopActive = false;
    await _studentAttendanceService.cancel();
    _isAttendanceActive = false;
    if (clearVerified || _attendanceFlowState != StudentAttendanceFlowState.completed) {
      _attendanceFlowState = StudentAttendanceFlowState.idle;
      _attendanceStatusMessage = '';
      if (clearVerified) {
        _verifiedSessionId = null;
        _verifiedSessionIds.clear();
      }
    }
    if (notify && mounted) {
      setState(() {});
    }
  }

  Future<void> _handleManualAttendanceTrigger() async {
    AppHaptics.selectionClick();
    await _stopAttendanceFlow(notify: false, clearVerified: true);
    if (mounted) {
      setState(() {
        _attendanceFlowState = StudentAttendanceFlowState.scanningForTeacherBeacon;
        _attendanceStatusMessage = 'Looking for class session...';
        _isAttendanceActive = true;
      });
    }
    _startAmbientAttendanceLoop();
  }

  Future<void> _startAmbientAttendanceLoop() async {
    if (_isScanningLoopActive) return;
    _isScanningLoopActive = true;

    final user = widget.user ??
        (mounted ? Provider.of<UserProvider>(context, listen: false).user : null);
    if (user == null) {
      _isScanningLoopActive = false;
      return;
    }

    try {
      if (mounted) {
        setState(() {
          _isAttendanceActive = true;
        });
      }

      final hasAlreadyVerified = _verifiedSessionId != null &&
          _attendanceFlowState == StudentAttendanceFlowState.completed;

      // Run attendance scan window (15 seconds, prevents Android OS scan rate limiting)
      final response = await _studentAttendanceService.startAttendance(
        currentUser: user,
        alreadyAuthenticated: true,
        scanTimeout: const Duration(seconds: 15),
        activeSessions: const [],
        ignoredSessionIds: _verifiedSessionIds,
        preserveCompletedState: hasAlreadyVerified,
      );

      if (response != null && mounted) {
        // Attendance verified and recorded!
        _verifiedSessionId = response.sessionId;
        _verifiedSessionIds.add(response.sessionId);
        _isAttendanceActive = false;
        AppHaptics.heavyImpact();

        if (mounted) {
          try {
            context.read<AttendanceProvider>().recordAttendanceLocally(
              sessionId: response.sessionId,
              studentId: user.id,
            );
          } catch (_) {}
          setState(() {
            _attendanceFlowState = StudentAttendanceFlowState.completed;
            _attendanceStatusMessage = 'Attendance Verified · Tap to re-send';
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Row(
                children: [
                  Icon(Icons.check_circle_outline_rounded, color: Colors.white),
                  SizedBox(width: 8),
                  Expanded(child: Text("Attendance broadcasted to teacher!")),
                ],
              ),
              backgroundColor: AppColors.success,
              behavior: SnackBarBehavior.floating,
              duration: Duration(seconds: 2),
            ),
          );
        }
      } else if (mounted) {
        setState(() {
          _isAttendanceActive = false;
          if (_attendanceFlowState != StudentAttendanceFlowState.completed) {
            _attendanceFlowState = StudentAttendanceFlowState.scanningForTeacherBeacon;
            _attendanceStatusMessage = 'Looking for class session...';
          }
        });
      }
    } catch (e) {
      debugPrint("⚠️ [PASSPORT] Ambient attendance loop notice: $e");
    } finally {
      _isScanningLoopActive = false;
      if (mounted) {
        setState(() {
          _isAttendanceActive = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = widget.user ??
        (mounted ? Provider.of<UserProvider>(context, listen: true).user : null);
    final studentName = user?.name ?? 'Student';
    final department = user?.branch ?? 'CSE';
    final semester = user?.year ?? '5th Semester';
    final rollNumber = user?.registrationNumber;

    final isShowingActiveView = _isExpandedActiveView &&
        _walletState == PassportWalletState.active;

    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (_) => _resetInactivityTimer(),
      onPointerMove: (_) => _resetInactivityTimer(),
      child: Stack(
        fit: StackFit.expand,
        children: [
          _buildWalletDeckScreen(
            key: const ValueKey('wallet_deck_view'),
            studentName: studentName,
            department: department,
            semester: semester,
            rollNumber: rollNumber,
            user: user,
          ),
          if (isShowingActiveView)
            _buildActivePassportScreen(
              key: const ValueKey('active_passport_view'),
              studentName: studentName,
              department: department,
              semester: semester,
              rollNumber: rollNumber,
            ),
        ],
      ),
    );
  }

  Widget _buildActivePassportScreen({
    required Key key,
    required String studentName,
    required String department,
    required String semester,
    required String? rollNumber,
  }) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          _handleBackToWallet();
        }
      },
      child: Scaffold(
        key: key,
        backgroundColor: Colors.transparent,
        body: SizedBox.expand(
          child: PassportActiveView(
            key: _activePassportViewKey,
            studentName: studentName,
            department: department,
            semester: semester,
            registrationNumber: rollNumber,
            qrData: _currentPresentation?.toQrPayload() ??
                'CAMPUS_PASSPORT:v1:${rollNumber ?? studentName}:${DateTime.now().millisecondsSinceEpoch ~/ 1000}',
            remainingSecondsNotifier: _qrRemainingSecondsNotifier,
            isBluetoothActive: _isBluetoothActive,
            onClose: _handleBackToWallet,
            onRefreshQr: _rotatePresentation,
            onStartAttendance: _handleManualAttendanceTrigger,
            onScanWifiHotspot: _openClassroomQrScanner,
            onScanClassroomQr: _openClassroomQrScanner,
            onEnterRoomPin: _openRoomPinSheet,
            onMarkGpsLocation: _handleGpsAttendanceTrigger,
            isAttendanceActive: _isAttendanceActive,
            attendanceState: _attendanceFlowState,
            attendanceStatusMessage: _attendanceStatusMessage,
          ),
      ),
    ),
  );
}

  Widget _buildWalletDeckScreen({
    required Key key,
    required String studentName,
    required String department,
    required String semester,
    required String? rollNumber,
    required UserModel? user,
  }) {
    return Container(
      key: key,
      color: AppColors.bg,
      child: SafeArea(
        child: Column(
          children: [
            if (_errorMessage != null &&
                _walletState == PassportWalletState.error) ...[
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 6),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.danger.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: AppColors.danger.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.error_outline_rounded,
                            size: 18, color: AppColors.danger),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _errorMessage!,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 12,
                              color: AppColors.danger,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],

              // Horizontal Swipeable Wallet Deck (Campus Passport, Student ID, Gate Pass)
              Expanded(
                child: CampusWalletView(
                  studentName: studentName,
                  studentId: user?.id,
                  department: department,
                  semester: semester,
                  registrationNumber: rollNumber,
                  course: user?.course,
                  passportState: _walletState,
                  isBluetoothActive: _isBluetoothActive,
                  activeGatePass: _activeGatePass,
                  isLoadingGatePass: _isLoadingGatePass,
                  isGatePassUnlocked: _isGatePassUnlocked,
                  isActivatingPassport: _isActivatingPassport,
                  onUnlockPassport: _unlockPassport,
                  onExpandPassport: () {
                    setState(() {
                      _isExpandedActiveView = true;
                      _verifiedSessionId = null;
                      _verifiedSessionIds.clear();
                      _attendanceFlowState = StudentAttendanceFlowState.idle;
                      _attendanceStatusMessage = '';
                    });
                    widget.isFullScreenActive.value = true;
                    _resetInactivityTimer();
                    _startAttendanceFlowIfNeeded();
                  },
                  onActivatePassport: _activatePassport,
                  onUnlockGatePass: _unlockGatePass,
                  onViewGatePassQr: _showGatePassQrSheet,
                  onRequestGatePass: _showNewGatePassForm,
                  onOpenScanner: () {
                    Navigator.pushNamed(
                      context,
                      AppRoutes.studentScanner,
                      arguments: widget.user,
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      );
  }




  // --- Apple-Grade Zero-BLE Room PIN Bottom Sheet ---
  void _openRoomPinSheet() {
    AppHaptics.selectionClick();
    final user = widget.user ??
        (mounted ? Provider.of<UserProvider>(context, listen: false).user : null);
    if (user == null) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return _RoomPinEntrySheet(
          onPinSubmitted: (pin) async {
            return await _handleRoomPinSubmit(pin, user);
          },
        );
      },
    );
  }

  Future<bool> _handleRoomPinSubmit(String pin, UserModel user) async {
    try {
      // 1. Resolve active session
      SessionModel? targetSession;
      final beacon = _studentAttendanceService.lastDiscoveredTeacherBeacon;
      if (beacon != null && beacon.sessionId.isNotEmpty) {
        targetSession = SessionModel(
          id: beacon.sessionId,
          name: beacon.subject ?? 'Class Session',
          course: beacon.course ?? user.course,
          branch: beacon.branch ?? user.branch,
          year: beacon.year ?? user.year,
          instructorName: beacon.teacherId,
          startTime: DateTime.now(),
          endTime: DateTime.now().add(const Duration(hours: 1)),
          location: 'Classroom',
          isActive: true,
        );
      } else {
        final activeList = await SessionService().getActiveSessions(
          course: user.course,
          branch: user.branch,
          year: user.year,
        );
        if (activeList.isNotEmpty) {
          targetSession = activeList.first;
        } else {
          final allActive = await SessionService().getActiveSessions();
          if (allActive.isNotEmpty) {
            targetSession = allActive.first;
          }
        }
      }

      targetSession ??= SessionModel(
          id: 'manual_session_${DateTime.now().millisecondsSinceEpoch ~/ 1000}',
          name: 'Class Attendance',
          instructorName: 'Instructor',
          startTime: DateTime.now(),
          endTime: DateTime.now().add(const Duration(hours: 1)),
          location: 'Classroom',
          isActive: true,
        );

      final result = await _studentAttendanceService.submitRollingPin(
        pin: pin,
        session: targetSession,
        currentUser: user,
      );

      if (result != null && result.valid && mounted) {
        _verifiedSessionId = targetSession.id;
        _verifiedSessionIds.add(targetSession.id);
        _isAttendanceActive = false;
        AppHaptics.heavyImpact();

        try {
          context.read<AttendanceProvider>().recordAttendanceLocally(
            sessionId: targetSession.id,
            studentId: user.id,
          );
        } catch (_) {}

        setState(() {
          _attendanceFlowState = StudentAttendanceFlowState.completed;
          _attendanceStatusMessage = 'Attendance verified with Room PIN · ${targetSession!.name}';
        });
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('⚠️ [PASSPORT] PIN submit error: $e');
      return false;
    }
  }

  // --- Direct GPS Location Verification (20m Radius) ---
  Future<void> _handleGpsAttendanceTrigger() async {
    AppHaptics.selectionClick();
    final user = widget.user ??
        (mounted ? Provider.of<UserProvider>(context, listen: false).user : null);
    if (user == null) return;

    setState(() {
      _isAttendanceActive = true;
      _attendanceFlowState = StudentAttendanceFlowState.scanningForTeacherBeacon;
      _attendanceStatusMessage = 'Verifying GPS coordinates (20m radius)...';
    });

    final success = await _studentAttendanceService.markAttendanceByGpsLocation(
      currentUser: user,
    );

    if (!mounted) return;
    setState(() {
      _isAttendanceActive = false;
      if (success) {
        _attendanceFlowState = StudentAttendanceFlowState.completed;
      }
    });

    if (success) {
      AppHaptics.heavyImpact();
      context.read<AttendanceProvider>().refreshAttendance();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              Icon(Icons.check_circle_outline_rounded, color: Colors.white),
              SizedBox(width: 8),
              Expanded(child: Text("Attendance verified via GPS Location (20m)!")),
            ],
          ),
          backgroundColor: Color(0xFF0D9488),
          behavior: SnackBarBehavior.floating,
          duration: Duration(seconds: 3),
        ),
      );
    } else {
      AppHaptics.heavyImpact();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_attendanceStatusMessage.isNotEmpty
              ? _attendanceStatusMessage
              : 'GPS verification failed. Make sure you are within 20m of teacher.'),
          backgroundColor: Colors.red.shade700,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }

  // --- Student Campus QR Scanner for Classroom Session ---
  void _openClassroomQrScanner() {
    AppHaptics.selectionClick();
    final user = widget.user ??
        (mounted ? Provider.of<UserProvider>(context, listen: false).user : null);
    if (user == null) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (ctx) => CampusScannerScreen(
          user: user,
          title: 'Scan Teacher Wi-Fi',
          subtitle: "Align the Wi-Fi or classroom QR on your teacher's screen within the box.",
          onQrDetected: (qrCode) async {
            await _handleScannedQrSubmit(qrCode, user);
          },
        ),
      ),
    );
  }

  Future<void> _handleScannedQrSubmit(String qrCode, UserModel user) async {
    try {
      final result = await _studentAttendanceService.submitScannedTeacherQr(
        qrData: qrCode,
        currentUser: user,
      );

      if (result != null && result.valid && mounted) {
        _verifiedSessionId = result.sessionId;
        if (result.sessionId != null) {
          _verifiedSessionIds.add(result.sessionId!);
        }
        _isAttendanceActive = false;
        AppHaptics.heavyImpact();

        try {
          if (result.sessionId != null) {
            context.read<AttendanceProvider>().recordAttendanceLocally(
              sessionId: result.sessionId!,
              studentId: user.id,
            );
          }
        } catch (_) {}

        final isWifi = qrCode.startsWith('WIFI:') || qrCode.contains('WIFI:S:');
        setState(() {
          _attendanceFlowState = StudentAttendanceFlowState.completed;
          _attendanceStatusMessage = isWifi
              ? 'Attendance verified via Teacher Wi-Fi'
              : 'Attendance verified via Screen QR';
        });
      } else if (mounted) {
        AppHaptics.vibrate();
        final msg = result?.reason ?? 'Could not verify classroom QR. Try again.';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFFEF4444),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            content: Row(
              children: [
                const Icon(Icons.error_outline_rounded, color: Colors.white, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    msg,
                    style: GoogleFonts.plusJakartaSans(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13),
                  ),
                ),
              ],
            ),
          ),
        );
      }
    } catch (e) {
      debugPrint('⚠️ [PASSPORT] Scanned QR error: $e');
    }
  }

}


/// Apple-Grade 4-Digit Rolling PIN Bottom Sheet
class _RoomPinEntrySheet extends StatefulWidget {
  final Future<bool> Function(String pin) onPinSubmitted;

  const _RoomPinEntrySheet({Key? key, required this.onPinSubmitted}) : super(key: key);

  @override
  State<_RoomPinEntrySheet> createState() => _RoomPinEntrySheetState();
}

class _RoomPinEntrySheetState extends State<_RoomPinEntrySheet> {
  String _enteredPin = '';
  bool _isSubmitting = false;
  String? _errorMessage;

  void _handleKeyPress(String val) {
    if (_isSubmitting) return;
    AppHaptics.selectionClick();
    if (_enteredPin.length < 4) {
      setState(() {
        _enteredPin += val;
        _errorMessage = null;
      });
      if (_enteredPin.length == 4) {
        _submitPin();
      }
    }
  }

  void _handleBackspace() {
    if (_isSubmitting) return;
    AppHaptics.selectionClick();
    if (_enteredPin.isNotEmpty) {
      setState(() {
        _enteredPin = _enteredPin.substring(0, _enteredPin.length - 1);
        _errorMessage = null;
      });
    }
  }

  Future<void> _submitPin() async {
    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    final success = await widget.onPinSubmitted(_enteredPin);

    if (mounted) {
      if (success) {
        Navigator.pop(context);
      } else {
        setState(() {
          _isSubmitting = false;
          _enteredPin = '';
          _errorMessage = 'Invalid or expired PIN. Check screen.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(
        24,
        12,
        24,
        MediaQuery.of(context).viewInsets.bottom + 28,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // iOS Grabber pill
          Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.border,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Classroom Room PIN",
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  Text(
                    "15-second rotating zero-BLE verification",
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close_rounded, size: 20, color: AppColors.textSecondary),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // 4 Digit Boxes
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(4, (index) {
              final isFilled = index < _enteredPin.length;
              final isCurrent = index == _enteredPin.length;
              final digit = isFilled ? _enteredPin[index] : '';

              return Container(
                width: 52,
                height: 60,
                margin: const EdgeInsets.symmetric(horizontal: 6),
                decoration: BoxDecoration(
                  color: AppColors.bg,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: isCurrent
                        ? const Color(0xFF818CF8)
                        : (isFilled ? AppColors.textPrimary : AppColors.border),
                    width: isCurrent ? 2.0 : 1.2,
                  ),
                ),
                child: Center(
                  child: Text(
                    digit,
                    style: GoogleFonts.jetBrainsMono(
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 12),
          if (_errorMessage != null)
            Text(
              _errorMessage!,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.danger,
              ),
            ),
          if (_isSubmitting) ...[
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                const SizedBox(width: 8),
                Text(
                  "Authenticating Face ID & submitting...",
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 20),

          // Apple-style Tactile 10-Key Keypad
          _buildNumericKeypad(),
        ],
      ),
    );
  }

  Widget _buildNumericKeypad() {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildKeypadButton('1'),
            _buildKeypadButton('2'),
            _buildKeypadButton('3'),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildKeypadButton('4'),
            _buildKeypadButton('5'),
            _buildKeypadButton('6'),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildKeypadButton('7'),
            _buildKeypadButton('8'),
            _buildKeypadButton('9'),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            const SizedBox(width: 64, height: 50),
            _buildKeypadButton('0'),
            GestureDetector(
              onTap: _handleBackspace,
              behavior: HitTestBehavior.opaque,
              child: Container(
                width: 64,
                height: 50,
                alignment: Alignment.center,
                child: const Icon(Icons.backspace_outlined, size: 22, color: AppColors.textPrimary),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildKeypadButton(String digit) {
    return GestureDetector(
      onTap: () => _handleKeyPress(digit),
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: 64,
        height: 50,
        decoration: BoxDecoration(
          color: AppColors.bg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
        ),
        alignment: Alignment.center,
        child: Text(
          digit,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 22,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
      ),
    );
  }
}
