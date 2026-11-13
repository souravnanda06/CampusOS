import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'dart:ui' show FontFeature, ImageFilter;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_ble_peripheral/flutter_ble_peripheral.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../auth/models/user_model.dart';
import '../../auth/providers/user_provider.dart';
import '../../core/haptics/app_haptics.dart';
import '../../core/network/connectivity_service.dart';
import '../../core/network/connectivity_state.dart';
import '../../core/sync/sync_manager.dart';
import '../../core/sync/sync_state.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/animation_constants.dart';
import '../../router/app_routes.dart';
import '../../shared/models/attendance_model.dart';
import '../../shared/models/session_model.dart';
import '../../shared/services/attendance_service.dart';
import '../../shared/services/session_service.dart';
import '../../shared/widgets/campus_scanner_overlay.dart';
import '../../student/models/passport_attendance_model.dart';
import '../services/passport_teacher_attendance_service.dart';

part '../widgets/live_session_glass.dart';
part '../widgets/live_session_orb.dart';
part '../widgets/live_session_tiles.dart';
part '../widgets/live_session_controls.dart';

/// Local dark "live mode" design tokens for [BroadcastingScreen].
///
/// Kept scoped to this screen without altering the app-wide theme.
class _LiveTheme {
  const _LiveTheme._();

  // Performance toggle for BackdropFilter on glass surfaces over moving/colored areas.
  // Disabled by default to keep 60fps smooth on mid-range Android GPUs while ripples animate.
  static const bool enableGlassBlur = false;

  // Background & ambient glow
  static const Color bgTop = Color(0xFF0B0B1E);
  static const Color bgBottom = Color(0xFF06060F);
  static const Color indigoGlow = Color(0xFF6366F1);
  static const Color indigoDeep = Color(0xFF4F46E5);
  static const Color indigoRipple = Color(0xFF6366F1);

  // Text
  static const Color textPrimary = Color(0xFFFFFFFF);
  static const Color textMuted50 = Color(0x80FFFFFF);
  static const Color textMuted60 = Color(0x99FFFFFF);
  static const Color textMuted62 = Color(0x9EFFFFFF);
  static const Color textMuted66 = Color(0xA8FFFFFF);
  static const Color textMuted82 = Color(0xD1FFFFFF);
  static const Color textMuted90 = Color(0xE6FFFFFF);

  // Accents & semantic states
  static const Color accent = Color(0xFFA5B4FC);
  static const Color accentLight = Color(0xFFC7D2FE);
  static const Color amber = Color(0xFFFFB340);
  static const Color amberText = Color(0xFFFFD08A);
  static const Color amberBody = Color(0xC7FFE2BE); // rgba(255,226,190,0.78)
  static const Color amberFill = Color(0x1AFFB340); // rgba(255,179,64,0.10)
  static const Color amberBorder = Color(0x42FFB340); // rgba(255,179,64,0.26)
  static const Color amberTileFill = Color(0x33FFB340); // rgba(255,179,64,0.20)

  static const Color liveRed = Color(0xFFFF453A);
  static const Color liveRedFill = Color(0x29FF453A); // rgba(255,69,58,0.16)
  static const Color liveRedBorder = Color(0x4DFF453A); // rgba(255,69,58,0.30)
  static const Color liveRedText = Color(0xFFFFB0AA);
  static const Color endRedTop = Color(0xFFFF5B50);
  static const Color endRedBottom = Color(0xFFE5342A);

  static const Color onlineGreen = Color(0xFF30D158);

  // Glass surface tokens
  static const Color glassFillTop = Color(0x1AFFFFFF); // white 10%
  static const Color glassFillBottom = Color(0x0DFFFFFF); // white 5%
  static const Color glassBorder = Color(0x1AFFFFFF); // white 10%
  static const Color glassTopHighlight = Color(0x29FFFFFF); // white 16%

  // Layout sizes & radii
  static const double backButtonSize = 44.0;
  static const double livePillHeight = 32.0;
  static const double orbStageSize = 224.0;
  static const double orbSphereSize = 184.0;
  static const double orbOuterRingStroke = 5.0;
  static const double staticRing1Diameter = 290.0;
  static const double staticRing2Diameter = 370.0;
  static const double rippleMinDiameter = 190.0;
  static const double rippleMaxDiameter = 560.0;
  static const double statusPillHeight = 30.0;
  static const double bleNoticeRadius = 20.0;
  static const double methodTileRadius = 22.0;
  static const double methodTileHeight = 104.0;
  static const double ringTimerSize = 20.0;
  static const double ringTimerStroke = 2.8;
  static const double attendeesRowHeight = 60.0;
  static const double attendeesRowRadius = 22.0;
  static const double controlButtonSize = 64.0;
  static const double bottomScrimHeight = 230.0;

  // Durations & curves
  static const Duration entranceTotalDuration = Duration(milliseconds: 1000);
  static const Curve entranceCurve = Cubic(0.2, 0.8, 0.2, 1.0);
  static const Duration pressDuration = Duration(milliseconds: 200);
  static const double pressScale = 0.95;
  static const Duration rippleDuration = Duration(milliseconds: 5400);
  static const Duration pulseDuration = Duration(milliseconds: 1800);
}

/// CampusOS Teacher Live Attendance Command Center.
///
/// Features:
/// - Real-time 1I batch BLE attendance monitoring.
/// - Live elapsed session timer (e.g. ● 00:14:32).
/// - Honest RSSI proximity reporting (NEAR / FAR / INCONCLUSIVE / UNKNOWN, -42 dBm).
/// - Real-time connectivity state (ONLINE / OFFLINE · Verifying locally).
/// - Exception Queue with direct 1I QR Fallback recovery challenge.
/// - Hero ambient orb & proximity ripple visualizer + glass attendee sheet.
/// - Intentional confirmation on End Session -> direct transition to [PostSessionReportScreen].
class BroadcastingScreen extends StatefulWidget {
  final UserModel user;
  final SessionModel session;
  @visibleForTesting
  final PassportTeacherAttendanceService? teacherServiceOverride;
  @visibleForTesting
  final SessionService? sessionServiceOverride;
  @visibleForTesting
  final bool autoStartServices;

  const BroadcastingScreen({
    Key? key,
    required this.user,
    required this.session,
    @visibleForTesting this.teacherServiceOverride,
    @visibleForTesting this.sessionServiceOverride,
    @visibleForTesting this.autoStartServices = true,
  }) : super(key: key);

  @override
  State<BroadcastingScreen> createState() => _BroadcastingScreenState();
}

class _BroadcastingScreenState extends State<BroadcastingScreen>
    with TickerProviderStateMixin {
  final FlutterBlePeripheral _blePeripheral = FlutterBlePeripheral();
  final AttendanceService _attendanceService = AttendanceService();
  late final PassportTeacherAttendanceService _passportTeacherService;
  late final SessionService _sessionService;

  bool _isPaused = false;
  bool _isOnline = true;
  bool _isSessionStopped = false;
  StreamSubscription<NetworkStatus>? _connectivitySubscription;
  SyncStatus _syncStatus = SyncManager.instance.status;
  StreamSubscription<SyncStatus>? _syncSubscription;

  List<AttendanceModel> _presentStudents = [];
  TeacherAttendanceMetrics _metrics = const TeacherAttendanceMetrics();
  StreamSubscription<TeacherAttendanceMetrics>? _metricsSubscription;

  Timer? _pollingTimer;
  Timer? _elapsedTimer;
  final ValueNotifier<Duration> _elapsedDurationNotifier =
      ValueNotifier<Duration>(Duration.zero);

  late final AnimationController _rippleController;
  late final AnimationController _pulseController;
  late final AnimationController _entranceController;

  final GlobalKey _stackKey = GlobalKey();
  final GlobalKey _orbStageKey = GlobalKey();
  final ValueNotifier<Offset?> _orbCenterNotifier = ValueNotifier<Offset?>(null);
  String? _lastOrbLayoutKey;

  @override
  void initState() {
    super.initState();

    _sessionService = widget.sessionServiceOverride ?? SessionService();
    _passportTeacherService = widget.teacherServiceOverride ??
        PassportTeacherAttendanceService(
          blePeripheral: _blePeripheral,
        );

    _isOnline = ConnectivityService.instance.isDeviceOnline;
    _connectivitySubscription =
        ConnectivityService.instance.onStatusChanged.listen((status) {
      if (mounted) {
        setState(() {
          _isOnline = status.hasNetworkInterface || status.isOnline;
        });
        if (status.isOnline && widget.autoStartServices) {
          _fetchLiveAttendance();
        }
      }
    });

    _syncStatus = SyncManager.instance.status;
    _syncSubscription = SyncManager.instance.onStatusChanged.listen((status) {
      if (mounted) {
        setState(() {
          _syncStatus = status;
        });
      }
    });

    _rippleController = AnimationController(
      vsync: this,
      duration: _LiveTheme.rippleDuration,
    );
    _pulseController = AnimationController(
      vsync: this,
      duration: _LiveTheme.pulseDuration,
    );
    _entranceController = AnimationController(
      vsync: this,
      duration: _LiveTheme.entranceTotalDuration,
    );

    _startElapsedTimer();

    _metricsSubscription = _passportTeacherService.metricsStream.listen((m) {
      if (mounted) {
        setState(() {
          _metrics = m;
        });
      }
    });

    if (widget.autoStartServices) {
      _initPassportBatchAttendance();
      _fetchLiveAttendance();
      _pollingTimer = Timer.periodic(const Duration(seconds: 3), (timer) {
        if (_isOnline) {
          _passportTeacherService.syncAttendance().catchError((_) => null);
          _fetchLiveAttendance();
        }
      });
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final bool reducedMotion = AnimationConstants.isReducedMotion(context);
    if (reducedMotion) {
      _entranceController.value = 1.0;
      _rippleController.stop();
      _pulseController.stop();
    } else {
      if (_entranceController.status == AnimationStatus.dismissed) {
        _entranceController.forward();
      }
      _syncLoopControllers();
    }
    _scheduleOrbCenterMeasure();
  }

  void _syncLoopControllers() {
    final bool reducedMotion = AnimationConstants.isReducedMotion(context);
    if (reducedMotion || _isPaused) {
      _rippleController.stop();
      _pulseController.stop();
    } else {
      if (!_rippleController.isAnimating) {
        _rippleController.repeat();
      }
      if (!_pulseController.isAnimating) {
        _pulseController.repeat();
      }
    }
  }

  void _scheduleOrbCenterMeasure() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _measureOrbCenterNow();
    });
  }

  void _measureOrbCenterNow() {
    if (!mounted) return;
    final stackBox =
        _stackKey.currentContext?.findRenderObject() as RenderBox?;
    final orbBox =
        _orbStageKey.currentContext?.findRenderObject() as RenderBox?;
    if (stackBox == null ||
        orbBox == null ||
        !stackBox.hasSize ||
        !orbBox.hasSize) {
      return;
    }
    final Offset orbGlobalCenter =
        orbBox.localToGlobal(orbBox.size.center(Offset.zero));
    final Offset orbLocalCenter = stackBox.globalToLocal(orbGlobalCenter);
    final current = _orbCenterNotifier.value;
    if (current == null ||
        (current.dx - orbLocalCenter.dx).abs() > 0.5 ||
        (current.dy - orbLocalCenter.dy).abs() > 0.5) {
      _orbCenterNotifier.value = orbLocalCenter;
    }
  }

  void _startElapsedTimer() {
    final startTime = widget.session.startTime;
    var duration = DateTime.now().difference(startTime);
    if (duration.isNegative) duration = Duration.zero;
    _elapsedDurationNotifier.value = duration;

    _elapsedTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted && !_isPaused) {
        _elapsedDurationNotifier.value += const Duration(seconds: 1);
      }
    });
  }

  String _formatElapsed(Duration d) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final hours = twoDigits(d.inHours);
    final minutes = twoDigits(d.inMinutes.remainder(60));
    final seconds = twoDigits(d.inSeconds.remainder(60));
    return d.inHours > 0 ? '$hours:$minutes:$seconds' : '$minutes:$seconds';
  }

  Future<void> _initPassportBatchAttendance() async {
    try {
      await _passportTeacherService.startBatchAttendance(
        teacher: widget.user,
        session: widget.session,
      );
      if (mounted) setState(() {});
    } catch (e) {
      debugPrint('Passport batch attendance startup error: $e');
    }
  }

  @override
  void dispose() {
    _rippleController.dispose();
    _pulseController.dispose();
    _entranceController.dispose();
    _orbCenterNotifier.dispose();
    _pollingTimer?.cancel();
    _elapsedTimer?.cancel();
    _metricsSubscription?.cancel();
    _connectivitySubscription?.cancel();
    _syncSubscription?.cancel();
    if (widget.teacherServiceOverride == null) {
      _passportTeacherService.dispose();
    }
    _elapsedDurationNotifier.dispose();
    if (!_isSessionStopped && widget.autoStartServices) {
      _sessionService.stopSession(widget.session.id).catchError((_) => false);
    }
    super.dispose();
  }

  Future<void> _fetchLiveAttendance() async {
    try {
      final list =
          await _attendanceService.getSessionAttendance(widget.session.id);
      if (mounted) {
        setState(() {
          _presentStudents = list;
          _isOnline = true;
        });
      }
    } catch (e) {
      // Backend request failed or session is local.
      // Do NOT overwrite _isOnline! Device network state is governed by ConnectivityService.
    }
  }

  Future<void> _togglePause() async {
    AppHaptics.lightImpact();
    if (_isPaused) {
      await _passportTeacherService.resumeBeaconAdvertising();
      if (!mounted) return;
      setState(() => _isPaused = false);
      _syncLoopControllers();
    } else {
      await _passportTeacherService.pauseBeaconAdvertising();
      if (!mounted) return;
      setState(() => _isPaused = true);
      _syncLoopControllers();
    }
  }

  int _getVerifiedTotal() {
    final verifiedIds = <String>{};
    final verifiedNames = <String>{};
    int count = 0;

    for (final v in _metrics.verifiedStudents) {
      final sId = (v.studentId ?? '').trim();
      final sName = (v.studentName ?? '').toLowerCase().trim();
      if ((sId.isNotEmpty && verifiedIds.contains(sId)) ||
          (sName.isNotEmpty &&
              sName != 'student' &&
              verifiedNames.contains(sName))) {
        continue;
      }
      if (sId.isNotEmpty) verifiedIds.add(sId);
      if (sName.isNotEmpty && sName != 'student') verifiedNames.add(sName);
      count++;
    }

    for (final p in _presentStudents) {
      final pId = p.userId.trim();
      final pName = p.studentName.toLowerCase().trim();
      if ((pId.isNotEmpty && verifiedIds.contains(pId)) ||
          (pName.isNotEmpty && verifiedNames.contains(pName))) {
        continue;
      }
      if (pId.isNotEmpty) verifiedIds.add(pId);
      if (pName.isNotEmpty) verifiedNames.add(pName);
      count++;
    }

    return count;
  }

  int _getTotalExpected() {
    if (_metrics.totalRoster > 0) return _metrics.totalRoster;
    return math.max(_getVerifiedTotal() + _metrics.inconclusiveCount, 45);
  }

  String _getRangeLabel() {
    final level = widget.session.txPowerLevel ?? 1;
    if (level == 0) return 'Low · Small Room';
    if (level == 2) return 'High · Lecture Hall';
    return 'Medium · Classroom';
  }

  List<_AttendeeDisplayData> _buildAttendeeDisplayItems() {
    final Set<String> renderedIds = {};
    final Set<String> renderedNames = {};
    final List<_AttendeeDisplayData> items = [];

    for (final v in _metrics.verifiedStudents) {
      final id = (v.studentId ?? '').trim();
      final name = (v.studentName ?? 'Student').trim();
      final normName = name.toLowerCase();

      if (id.isNotEmpty && renderedIds.contains(id)) continue;
      if (normName.isNotEmpty &&
          normName != 'student' &&
          renderedNames.contains(normName)) {
        continue;
      }

      if (id.isNotEmpty) renderedIds.add(id);
      if (normName.isNotEmpty && normName != 'student') {
        renderedNames.add(normName);
      }

      final rssiStr = v.medianRssi != null ? '${v.medianRssi} dBm' : null;
      final vMode = v.verificationMode;
      String modeLabel = 'BLE · ${v.proximityTier.code}';
      Color modeColor = _LiveTheme.accent;
      IconData modeIcon = Icons.bluetooth_rounded;

      if (vMode == PassportAttendanceModel.modeWifiLan) {
        modeLabel = 'Wi-Fi LAN';
        modeColor = _LiveTheme.onlineGreen;
        modeIcon = Icons.wifi_rounded;
      } else if (vMode == PassportAttendanceModel.modeWifiHotspot) {
        modeLabel = 'Hotspot';
        modeColor = const Color(0xFFA855F7);
        modeIcon = Icons.wifi_tethering_rounded;
      } else if (vMode == PassportAttendanceModel.modeQrOptical ||
          vMode == 'QR_FALLBACK') {
        modeLabel = 'Optical QR';
        modeColor = _LiveTheme.amber;
        modeIcon = Icons.qr_code_2_rounded;
      } else if (vMode == PassportAttendanceModel.modePinManual) {
        modeLabel = 'Room PIN';
        modeColor = const Color(0xFFEC4899);
        modeIcon = Icons.pin_rounded;
      }

      final gpsBadge =
          (v.gpsStatus == 'VERIFIED' && v.gpsDistanceMeters != null)
              ? '📍 ${v.gpsDistanceMeters!.round()}m'
              : null;

      items.add(
        _AttendeeDisplayData(
          name: name,
          id: v.studentId ?? 'Verified',
          mode: modeLabel,
          rssi: rssiStr,
          gpsBadge: gpsBadge,
          timestamp: DateFormat('HH:mm:ss').format(v.verifiedAt),
          badgeColor: modeColor,
          badgeIcon: modeIcon,
        ),
      );
    }

    for (final p in _presentStudents) {
      final pId = p.userId.trim();
      final pName = p.studentName.trim();
      final normName = pName.toLowerCase();

      if (pId.isNotEmpty && renderedIds.contains(pId)) continue;
      if (normName.isNotEmpty && renderedNames.contains(normName)) continue;

      if (pId.isNotEmpty) renderedIds.add(pId);
      if (normName.isNotEmpty) renderedNames.add(normName);

      items.add(
        _AttendeeDisplayData(
          name: p.studentName,
          id: p.userId,
          mode: 'BLE · NEAR',
          rssi: '-45 dBm',
          timestamp: DateFormat('HH:mm:ss').format(p.checkInTime),
          badgeColor: _LiveTheme.accent,
          badgeIcon: Icons.bluetooth_rounded,
        ),
      );
    }

    return items;
  }

  Future<void> _stopSession() async {
    AppHaptics.selectionClick();
    final verified = _getVerifiedTotal();
    final unresolved = _metrics.inconclusiveCount;

    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF14142E),
        shape: ContinuousRectangleBorder(
          borderRadius: BorderRadius.circular(24.0),
          side: BorderSide(color: Colors.white.withValues(alpha: 0.14)),
        ),
        title: Text(
          'End Attendance Session?',
          style: GoogleFonts.inter(
            fontWeight: FontWeight.w700,
            fontSize: 18,
            color: _LiveTheme.textPrimary,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Session attendance will be finalized and ledgered:',
              style: GoogleFonts.inter(
                fontSize: 13,
                color: _LiveTheme.textMuted66,
              ),
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  Column(
                    children: [
                      Text(
                        '$verified',
                        style: GoogleFonts.inter(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: _LiveTheme.onlineGreen,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                      Text(
                        'Verified',
                        style: GoogleFonts.inter(
                          fontSize: 11.5,
                          color: _LiveTheme.textMuted60,
                        ),
                      ),
                    ],
                  ),
                  Container(
                    width: 1,
                    height: 28,
                    color: Colors.white.withValues(alpha: 0.12),
                  ),
                  Column(
                    children: [
                      Text(
                        '$unresolved',
                        style: GoogleFonts.inter(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: unresolved > 0
                              ? _LiveTheme.amberText
                              : _LiveTheme.textMuted60,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                      Text(
                        'Unresolved',
                        style: GoogleFonts.inter(
                          fontSize: 11.5,
                          color: _LiveTheme.textMuted60,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              'Continue Session',
              style: GoogleFonts.inter(
                fontWeight: FontWeight.w600,
                color: _LiveTheme.textMuted66,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: _LiveTheme.liveRed,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(
              'End Session',
              style: GoogleFonts.inter(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    _isSessionStopped = true;

    try {
      final success = await _sessionService.stopSession(widget.session.id);
      if (!success) {
        debugPrint(
            'Offline or server unreachable when stopping session. Concluding session locally.');
      }
    } catch (e) {
      debugPrint('Offline network error on stopSession: $e');
    }

    try {
      await _passportTeacherService.stopSession();
    } catch (e) {
      debugPrint('Error stopping passport teacher service: $e');
    }

    try {
      await _blePeripheral.stop();
    } catch (e) {
      debugPrint('Error stopping BLE peripheral: $e');
    }

    try {
      if (mounted) {
        await context.read<UserProvider>().clearSessionId();
      }
    } catch (e) {
      debugPrint('Error clearing session ID: $e');
    }

    try {
      if (mounted) {
        Navigator.pushReplacementNamed(
          context,
          AppRoutes.teacherPostSessionReport,
          arguments: {
            'session': widget.session,
            'metrics': _metrics,
            'verifiedRecords':
                _passportTeacherService.verifiedResults.values.toList(),
            'legacyAttendees': _presentStudents,
          },
        );
      }
    } catch (e) {
      debugPrint('Error completing session transition: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to end session: $e',
                style: GoogleFonts.inter()),
            backgroundColor: _LiveTheme.liveRed,
          ),
        );
      }
    }
  }

  Future<void> _retryBleBroadcast() async {
    AppHaptics.lightImpact();
    if (!_passportTeacherService.isAdvertisingSupported) {
      _showExceptionResolutionSheet();
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Freeing BLE radio and retrying beacon broadcast...',
          style: GoogleFonts.inter(),
        ),
        duration: const Duration(seconds: 2),
      ),
    );
    await _passportTeacherService.retryBeaconAdvertising();
    if (mounted) setState(() {});
  }

  Future<void> _toggleHotspotBurst() async {
    AppHaptics.mediumImpact();
    if (_passportTeacherService.isHotspotActive) {
      _passportTeacherService.stopHotspotBurst();
      if (mounted) setState(() {});
      return;
    }
    await _passportTeacherService.startHotspotBurst();
    if (!mounted) return;
    setState(() {});
    if (_passportTeacherService.isHotspotActive &&
        _passportTeacherService.hotspotSsid != null) {
      _showHotspotGatewaySheet();
    }
  }

  void _showHotspotGatewaySheet() {
    AppHaptics.selectionClick();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _HotspotGatewaySheet(
        teacherService: _passportTeacherService,
        session: widget.session,
        onEditCredentials: () {
          Navigator.pop(ctx);
          _showConfigureHotspotSheet();
        },
        onEnlargeQr: () {
          AppHaptics.selectionClick();
          final ssid = _passportTeacherService.hotspotSsid ?? '';
          final pass = _passportTeacherService.hotspotPassword ?? '';
          final rem = _passportTeacherService.hotspotRemainingSeconds;
          final payload = _passportTeacherService.buildWifiHotspotQrPayload(
            sessionId: widget.session.id,
            fallbackTeacherId: widget.session.instructorName,
          );
          _showEnlargedHotspotDialog(
            ssid,
            pass,
            rem,
            qrDataOverride: payload,
          );
        },
        onStopHotspot: () {
          _passportTeacherService.stopHotspotBurst();
          if (mounted) setState(() {});
        },
      ),
    );
  }

  void _showAttendeesSheet() {
    final bool hasNetwork =
        _isOnline || ConnectivityService.instance.hasNetworkInterface;
    final String radioLabel = !hasNetwork
        ? 'Verifying Locally (Offline)'
        : (_isPaused ? 'BLE Radio Paused' : 'BLE Radio Active');
    final Color radioColor = !hasNetwork
        ? _LiveTheme.amber
        : (_isPaused ? _LiveTheme.amber : _LiveTheme.accent);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return _LiveAttendeesSheet(
          attendees: _buildAttendeeDisplayItems(),
          inconclusiveStudents: _metrics.inconclusiveStudents,
          radioStatusLabel: radioLabel,
          radioDotColor: radioColor,
          onResolveExceptions: () {
            Navigator.pop(ctx);
            _showExceptionResolutionSheet();
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final verified = _getVerifiedTotal();
    final totalExpected = _getTotalExpected();
    final bleError = _passportTeacherService.advertisingError;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _stopSession();
      },
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.light,
        child: Scaffold(
          backgroundColor: _LiveTheme.bgBottom,
          body: Stack(
            key: _stackKey,
            children: [
              // 1. Background vertical gradient + radial indigo orb glow (cached GPU layer)
              const Positioned.fill(
                child: RepaintBoundary(
                  child: _LiveBackgroundLayer(),
                ),
              ),
              // 2. Ambient static rings + 3 spreading ripples behind orb
              Positioned.fill(
                child: _ProximityRipples(
                  animation: _rippleController,
                  orbCenterListenable: _orbCenterNotifier,
                  isLive: !_isPaused,
                ),
              ),
              // 3. Soft dark scrim behind bottom controls & attendee row
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                height: _LiveTheme.bottomScrimHeight,
                child: IgnorePointer(
                  child: RepaintBoundary(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.transparent,
                            Colors.black.withValues(alpha: 0.90),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              // 4. Foreground SafeArea layout (single-pass SliverFillRemaining; no IntrinsicHeight double layout)
              SafeArea(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final double textScale =
                        MediaQuery.textScalerOf(context).scale(14.0) / 14.0;
                    final double scrollThreshold =
                        bleError != null ? 780.0 : 700.0;
                    final bool forceScroll =
                        constraints.maxHeight <= scrollThreshold ||
                            textScale > 1.15;
                    final String layoutKey =
                        '${constraints.maxWidth.toStringAsFixed(0)}x${constraints.maxHeight.toStringAsFixed(0)}_${bleError != null}_$forceScroll';
                    if (_lastOrbLayoutKey != layoutKey) {
                      _lastOrbLayoutKey = layoutKey;
                      _scheduleOrbCenterMeasure();
                    }

                    final Widget columnContent = Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20.0),
                      child: Column(
                        mainAxisSize:
                            forceScroll ? MainAxisSize.min : MainAxisSize.max,
                        children: [
                          _SectionEntrance(
                            controller: _entranceController,
                            index: 0,
                            child: _buildTopBar(),
                          ),
                          if (forceScroll)
                            const SizedBox(height: 10.0)
                          else
                            const Spacer(flex: 2),
                          _SectionEntrance(
                            controller: _entranceController,
                            index: 1,
                            child: _LiveOrb(
                              key: _orbStageKey,
                              verifiedCount: verified,
                              totalExpected: totalExpected,
                            ),
                          ),
                          const SizedBox(height: 8.0),
                          _SectionEntrance(
                            controller: _entranceController,
                            index: 2,
                            child: _buildStatusSection(),
                          ),
                          if (bleError != null) ...[
                            const SizedBox(height: 14.0),
                            _SectionEntrance(
                              controller: _entranceController,
                              index: 3,
                              child: _BleNoticeStrip(
                                errorText: bleError,
                                onRetry: _retryBleBroadcast,
                              ),
                            ),
                          ],
                          if (forceScroll)
                            const SizedBox(height: 16.0)
                          else
                            const Spacer(flex: 3),
                          _SectionEntrance(
                            controller: _entranceController,
                            index: 4,
                            child: ValueListenableBuilder<Duration>(
                              valueListenable: _elapsedDurationNotifier,
                              builder: (context, _, __) =>
                                  _buildCheckInMethodsSection(),
                            ),
                          ),
                          const SizedBox(height: 8.0),
                          _SectionEntrance(
                            controller: _entranceController,
                            index: 5,
                            child: _buildAttendeesRowSection(verified),
                          ),
                          const SizedBox(height: 10.0),
                          _SectionEntrance(
                            controller: _entranceController,
                            index: 6,
                            child: _SessionControls(
                              isPaused: _isPaused,
                              onScanQr: _openStudentQrScanner,
                              onShowQrCode: _showExceptionResolutionSheet,
                              onTogglePause: _togglePause,
                              onEndSession: _stopSession,
                            ),
                          ),
                          const SizedBox(height: 4.0),
                        ],
                      ),
                    );

                    if (forceScroll) {
                      return NotificationListener<ScrollNotification>(
                        onNotification: (_) {
                          _measureOrbCenterNow();
                          return false;
                        },
                        child: SingleChildScrollView(
                          physics: const BouncingScrollPhysics(),
                          child: ConstrainedBox(
                            constraints: BoxConstraints(
                              minHeight: constraints.maxHeight,
                            ),
                            child: columnContent,
                          ),
                        ),
                      );
                    }

                    return SizedBox(
                      height: constraints.maxHeight,
                      child: columnContent,
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    final String room = widget.session.location.isNotEmpty
        ? widget.session.location.toUpperCase()
        : 'ROOM 204';

    return Padding(
      padding: const EdgeInsets.only(top: 6.0, bottom: 2.0),
      child: Row(
        children: [
          // Left: 44px circular glass back button
          _TactilePress(
            onTap: _stopSession,
            onHaptic: AppHaptics.selectionClick,
            semanticsLabel: 'Back and end session',
            child: const _LiveGlassSurface(
              isCircle: true,
              useBlur: true,
              width: _LiveTheme.backButtonSize,
              height: _LiveTheme.backButtonSize,
              child: Center(
                child: Icon(
                  Icons.chevron_left_rounded,
                  size: 24.0,
                  color: _LiveTheme.textPrimary,
                ),
              ),
            ),
          ),
          const SizedBox(width: 10.0),
          // Center: course name + room subtitle
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  widget.session.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    fontSize: 17.0,
                    fontWeight: FontWeight.w600,
                    letterSpacing: -0.2,
                    color: _LiveTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 2.0),
                Text(
                  room,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 10.5 * 0.09,
                    color: _LiveTheme.textMuted60,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10.0),
          // Right: LIVE pill with pulsing red dot + tabular elapsed timer
          ValueListenableBuilder<Duration>(
            valueListenable: _elapsedDurationNotifier,
            builder: (context, elapsed, _) {
              final String formatted = _formatElapsed(elapsed);
              return Semantics(
                label: 'Live session elapsed $formatted',
                child: Container(
                  height: _LiveTheme.livePillHeight,
                  padding: const EdgeInsets.symmetric(horizontal: 12.0),
                  decoration: BoxDecoration(
                    color: _LiveTheme.liveRedFill,
                    borderRadius: BorderRadius.circular(16.0),
                    border: Border.all(
                      color: _LiveTheme.liveRedBorder,
                      width: 1.0,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _PulsingDot(
                        color: _LiveTheme.liveRed,
                        size: 8.0,
                        animation: _pulseController,
                        isPulsing: !_isPaused,
                        showPingRing: true,
                      ),
                      const SizedBox(width: 7.0),
                      Text(
                        formatted,
                        style: GoogleFonts.inter(
                          fontSize: 13.0,
                          fontWeight: FontWeight.w600,
                          color: _LiveTheme.liveRedText,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildStatusSection() {
    final bool hasNetwork =
        _isOnline || ConnectivityService.instance.hasNetworkInterface;

    String syncLabel;
    Color syncDotColor;
    if (_syncStatus.isSyncing) {
      syncLabel = 'Syncing · Uploading';
      syncDotColor = _LiveTheme.accent;
    } else if (!hasNetwork) {
      syncLabel = 'Offline · Saved locally';
      syncDotColor = _LiveTheme.amber;
    } else if (_syncStatus.hasError) {
      syncLabel = 'Online · Sync pending';
      syncDotColor = _LiveTheme.amber;
    } else if (_syncStatus.isWaiting) {
      syncLabel = 'Online · Pending sync';
      syncDotColor = _LiveTheme.accent;
    } else {
      syncLabel = 'Online · Synced';
      syncDotColor = _LiveTheme.onlineGreen;
    }

    final String scanLabel =
        _isPaused ? 'Paused' : 'Scanning for passports';
    final Color scanDotColor =
        _isPaused ? _LiveTheme.amber : _LiveTheme.accent;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 8.0,
          runSpacing: 8.0,
          children: [
            _LiveGlassSurface(
              radius: 15.0,
              useBlur: true,
              height: _LiveTheme.statusPillHeight,
              padding: const EdgeInsets.symmetric(horizontal: 12.0),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _PulsingDot(
                    color: scanDotColor,
                    size: 7.0,
                    animation: _pulseController,
                    isPulsing: !_isPaused,
                  ),
                  const SizedBox(width: 7.0),
                  Flexible(
                    child: Text(
                      scanLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w500,
                        color: _LiveTheme.textMuted90,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            _LiveGlassSurface(
              radius: 15.0,
              useBlur: true,
              height: _LiveTheme.statusPillHeight,
              padding: const EdgeInsets.symmetric(horizontal: 12.0),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 7.0,
                    height: 7.0,
                    decoration: BoxDecoration(
                      color: syncDotColor,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 7.0),
                  Flexible(
                    child: Text(
                      syncLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w500,
                        color: _LiveTheme.textMuted90,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 4.0),
        Wrap(
          alignment: WrapAlignment.center,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 14.0,
          runSpacing: 2.0,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 2.0),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.shield_outlined,
                    size: 14.0,
                    color: _LiveTheme.textMuted62,
                  ),
                  const SizedBox(width: 5.0),
                  Flexible(
                    child: Text(
                      _getRangeLabel(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                        fontSize: 13.0,
                        fontWeight: FontWeight.w400,
                        color: _LiveTheme.textMuted62,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            _TactilePress(
              onTap: _showExceptionResolutionSheet,
              onHaptic: AppHaptics.lightImpact,
              semanticsLabel: 'Open QR Challenge',
              minHeight: 44.0,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4.0),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.qr_code_rounded,
                      size: 14.0,
                      color: _LiveTheme.textMuted62,
                    ),
                    const SizedBox(width: 5.0),
                    Flexible(
                      child: Text(
                        'QR Challenge',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(
                          fontSize: 13.0,
                          fontWeight: FontWeight.w400,
                          color: _LiveTheme.textMuted62,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Builder(
              builder: (_) {
                final beacon = _passportTeacherService.activeBeacon;
                final teacherLoc = _passportTeacherService.teacherLocation;
                final hasGps = beacon?.teacherLatitude != null ||
                    teacherLoc != null;
                final acc = (beacon?.teacherLocationAccuracy ??
                        teacherLoc?.accuracyMeters)
                    ?.round();
                final gpsText = hasGps
                    ? (acc != null ? 'GPS ±${acc}m' : 'GPS Locked')
                    : 'GPS Standby';
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10.0),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        hasGps
                            ? Icons.location_on_rounded
                            : Icons.location_searching_rounded,
                        size: 14.0,
                        color: hasGps
                            ? _LiveTheme.onlineGreen
                            : _LiveTheme.textMuted62,
                      ),
                      const SizedBox(width: 4.0),
                      Flexible(
                        child: Text(
                          gpsText,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.inter(
                            fontSize: 13.0,
                            fontWeight: FontWeight.w400,
                            color: hasGps
                                ? _LiveTheme.onlineGreen
                                : _LiveTheme.textMuted62,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildCheckInMethodsSection() {
    final beacon = _passportTeacherService.activeBeacon;
    final pin = _passportTeacherService.currentRollingPin;
    final pinRem = _passportTeacherService.rollingPinRemainingSeconds;
    final pinProg = _passportTeacherService.rollingPinProgress;
    final isHotspot = _passportTeacherService.isHotspotActive;
    final hotspotRem = _passportTeacherService.hotspotRemainingSeconds;
    final qrRem = 10 - (DateTime.now().millisecondsSinceEpoch ~/ 1000 % 10);
    final qrProg = qrRem / 10.0;

    final bool lanActive =
        beacon?.localIp != null || _passportTeacherService.isLanWifiDetected;
    final String networkStatusLabel = isHotspot
        ? 'Hotspot burst'
        : (lanActive ? 'LAN active' : 'LAN inactive');
    final Color networkStatusColor = (isHotspot || lanActive)
        ? _LiveTheme.accent
        : _LiveTheme.textMuted60;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2.0),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'ZERO-BLE & SUB-NET SYNC',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 10.5 * 0.08,
                    color: _LiveTheme.textMuted60,
                  ),
                ),
              ),
              const SizedBox(width: 8.0),
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: isHotspot ? _showHotspotGatewaySheet : null,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isHotspot
                          ? Icons.wifi_tethering_rounded
                          : Icons.wifi_rounded,
                      size: 14.0,
                      color: networkStatusColor,
                    ),
                    const SizedBox(width: 5.0),
                    Text(
                      networkStatusLabel,
                      style: GoogleFonts.inter(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: networkStatusColor,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8.0),
        Row(
          children: [
            Expanded(
              child: _MethodTile(
                label: 'ROOM PIN',
                trailing: _RingTimer(progress: pinProg),
                value: pin,
                caption: 'Rotates in ${pinRem}s',
                captionColor: _LiveTheme.textMuted62,
                semanticsLabel: 'Room PIN $pin, rotates in $pinRem seconds. Tap to enlarge.',
                onTap: () => _showEnlargedPinDialog(pin, pinRem),
              ),
            ),
            const SizedBox(width: 8.0),
            Expanded(
              child: _MethodTile(
                label: 'OPTICAL QR',
                trailing: _RingTimer(progress: qrProg),
                value: '10s',
                unit: 'Loop',
                caption: 'Tap for screen',
                captionColor: _LiveTheme.accent,
                semanticsLabel: 'Optical QR 10 second loop. Tap to open QR screen.',
                onTap: _showExceptionResolutionSheet,
              ),
            ),
            const SizedBox(width: 8.0),
            Expanded(
              child: _MethodTile(
                label: 'HOTSPOT',
                trailing: Icon(
                  Icons.bolt_rounded,
                  size: 15.0,
                  color: isHotspot ? _LiveTheme.accentLight : _LiveTheme.accent,
                ),
                value: isHotspot ? '${hotspotRem}s' : '60s',
                unit: 'Burst',
                caption: isHotspot ? 'Tap to Stop' : 'Tap to Start',
                valueColor:
                    isHotspot ? _LiveTheme.accentLight : _LiveTheme.textPrimary,
                captionColor:
                    isHotspot ? _LiveTheme.amberText : _LiveTheme.accent,
                isHighlighted: isHotspot,
                semanticsLabel: isHotspot
                    ? 'Hotspot burst active, $hotspotRem seconds remaining. Tap to stop.'
                    : 'Hotspot 60 second burst. Tap to start.',
                onHaptic: AppHaptics.mediumImpact,
                onTap: _toggleHotspotBurst,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildAttendeesRowSection(int verified) {
    final bool hasNetwork =
        _isOnline || ConnectivityService.instance.hasNetworkInterface;
    final String radioLabel = !hasNetwork
        ? 'Verifying Locally (Offline)'
        : (_isPaused ? 'BLE Radio Paused' : 'BLE Radio Active');
    final Color radioColor = !hasNetwork
        ? _LiveTheme.amber
        : (_isPaused ? _LiveTheme.amber : _LiveTheme.accent);

    return _AttendeesRow(
      verifiedCount: verified,
      inconclusiveCount: _metrics.inconclusiveCount,
      radioStatusLabel: radioLabel,
      radioDotColor: radioColor,
      isPulsing: !_isPaused && hasNetwork,
      pulseAnimation: _pulseController,
      onOpenSheet: _showAttendeesSheet,
    );
  }

  void _showConfigureHotspotSheet() {
    AppHaptics.selectionClick();
    final ssidController = TextEditingController(
      text: _passportTeacherService.savedHotspotSsid ??
          _passportTeacherService.hotspotSsid ??
          '',
    );
    final passController = TextEditingController(
      text: _passportTeacherService.savedHotspotPassword ??
          _passportTeacherService.hotspotPassword ??
          '',
    );

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom,
          ),
          child: Container(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFF14142E), Color(0xFF0A0A1A)],
              ),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(24)),
              border: Border(
                top: BorderSide(
                  color: Colors.white.withValues(alpha: 0.16),
                ),
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.24),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: _LiveTheme.indigoRipple.withValues(alpha: 0.22),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.wifi_tethering_rounded,
                          size: 20, color: _LiveTheme.accentLight),
                    ),
                    const SizedBox(width: 10),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Configure Phone Hotspot',
                          style: GoogleFonts.inter(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: _LiveTheme.textPrimary,
                          ),
                        ),
                        Text(
                          "Match your phone's real Hotspot settings",
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: _LiveTheme.textMuted62,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                Text(
                  'HOTSPOT NETWORK NAME (SSID)',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: _LiveTheme.textMuted60,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: ssidController,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: _LiveTheme.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                  decoration: InputDecoration(
                    hintText: 'e.g. OnePlus 11, Galaxy S22',
                    hintStyle: GoogleFonts.inter(
                      color: Colors.white.withValues(alpha: 0.35),
                    ),
                    filled: true,
                    fillColor: Colors.white.withValues(alpha: 0.06),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 12),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                          color: Colors.white.withValues(alpha: 0.14)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                          color: Colors.white.withValues(alpha: 0.14)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(
                          color: _LiveTheme.accent, width: 1.5),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  'HOTSPOT PASSWORD',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: _LiveTheme.textMuted60,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: passController,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: _LiveTheme.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                  decoration: InputDecoration(
                    hintText: 'At least 8 characters (WPA2)',
                    hintStyle: GoogleFonts.inter(
                      color: Colors.white.withValues(alpha: 0.35),
                    ),
                    filled: true,
                    fillColor: Colors.white.withValues(alpha: 0.06),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 12),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                          color: Colors.white.withValues(alpha: 0.14)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                          color: Colors.white.withValues(alpha: 0.14)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(
                          color: _LiveTheme.accent, width: 1.5),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(ctx),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                          side: BorderSide(
                              color: Colors.white.withValues(alpha: 0.18)),
                        ),
                        child: Text(
                          'Cancel',
                          style: GoogleFonts.inter(
                            fontWeight: FontWeight.w600,
                            color: _LiveTheme.textMuted66,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () async {
                          final newSsid = ssidController.text.trim();
                          final newPass = passController.text.trim();
                          if (newSsid.isEmpty) return;
                          await _passportTeacherService.saveHotspotCredentials(
                              newSsid, newPass);
                          if (ctx.mounted) Navigator.pop(ctx);
                          if (mounted) setState(() {});
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _LiveTheme.indigoDeep,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                          elevation: 0,
                        ),
                        child: Text(
                          'Save & Update QR',
                          style: GoogleFonts.inter(
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showEnlargedPinDialog(String pin, int remaining) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF14142E),
        shape: ContinuousRectangleBorder(
          borderRadius: BorderRadius.circular(24.0),
          side: BorderSide(color: Colors.white.withValues(alpha: 0.16)),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'CLASSROOM ROLLING PIN',
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: _LiveTheme.textMuted60,
                letterSpacing: 1.0,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              pin,
              style: GoogleFonts.inter(
                fontSize: 48,
                fontWeight: FontWeight.w800,
                letterSpacing: 6,
                color: _LiveTheme.textPrimary,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Announce or project this 4-digit code in class.\nStudents without BLE enter it in Passport.\nRotates automatically every 15 seconds.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 12,
                color: _LiveTheme.textMuted62,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showEnlargedHotspotDialog(
    String ssid,
    String password,
    int remaining, {
    String? qrDataOverride,
  }) {
    final qrData = qrDataOverride ?? 'WIFI:S:$ssid;T:WPA;P:$password;;';
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF14142E),
        shape: ContinuousRectangleBorder(
          borderRadius: BorderRadius.circular(24.0),
          side: BorderSide(color: Colors.white.withValues(alpha: 0.16)),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.wifi_tethering_rounded,
                    size: 16, color: _LiveTheme.accentLight),
                const SizedBox(width: 8),
                Text(
                  'TEACHER WI-FI HOTSPOT',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: _LiveTheme.accentLight,
                    letterSpacing: 1.0,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
              ),
              child: QrImageView(
                data: qrData,
                version: QrVersions.auto,
                size: 200.0,
                padding: EdgeInsets.zero,
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: _LiveTheme.indigoRipple.withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: _LiveTheme.accent.withValues(alpha: 0.30),
                ),
              ),
              child: Column(
                children: [
                  Text(
                    'Network: $ssid',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: _LiveTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    'Password: $password',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: _LiveTheme.accentLight,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Students scan this QR code with the CampusOS scanner.\nThey connect, submit, and drop automatically.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 11.5,
                color: _LiveTheme.textMuted62,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showExceptionResolutionSheet() {
    AppHaptics.lightImpact();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return _DynamicTeacherQrModal(
          teacherService: _passportTeacherService,
          onScanStudentResponse: () {
            Navigator.pop(ctx);
            _openStudentQrScanner();
          },
          onClose: () => Navigator.pop(ctx),
        );
      },
    );
  }

  void _openStudentQrScanner() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.black,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) {
        bool isProcessing = false;
        final controller = MobileScannerController();
        double currentZoom = 0.0;
        double baseZoom = 0.0;
        bool isTorchOn = false;

        return StatefulBuilder(
          builder: (context, setModalState) {
            return ClipRRect(
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(28)),
              child: SizedBox(
                height: MediaQuery.of(context).size.height * 0.88,
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final screenWidth = constraints.maxWidth;
                    final screenHeight = constraints.maxHeight;
                    final cutOutSize = math.min(screenWidth * 0.72, 275.0);
                    final cutOutTop = (screenHeight * 0.38) - (cutOutSize / 2);
                    final cutOutLeft = (screenWidth - cutOutSize) / 2;
                    final cutOutRect = Rect.fromLTWH(
                        cutOutLeft, cutOutTop, cutOutSize, cutOutSize);

                    return Stack(
                      children: [
                        // Camera with pinch to zoom
                        GestureDetector(
                          onScaleStart: (_) => baseZoom = currentZoom,
                          onScaleUpdate: (details) {
                            final newZoom =
                                (baseZoom * details.scale).clamp(0.0, 1.0);
                            if (newZoom != currentZoom) {
                              setModalState(() {
                                currentZoom = newZoom;
                              });
                              controller.setZoomScale(newZoom);
                            }
                          },
                          child: MobileScanner(
                            controller: controller,
                            onDetect: (capture) async {
                              if (isProcessing) return;
                              final barcodes = capture.barcodes;
                              if (barcodes.isEmpty ||
                                  barcodes.first.rawValue == null) {
                                return;
                              }
                              isProcessing = true;

                              final rawValue = barcodes.first.rawValue!;
                              await controller.stop();
                              controller.dispose();
                              if (ctx.mounted) Navigator.pop(ctx);

                              final result = await _passportTeacherService
                                  .verifyQrResponse(rawValue);

                              if (result.valid && result.studentId != null) {
                                try {
                                  await _attendanceService.markAttendance(
                                    sessionId: widget.session.id,
                                    studentId: result.studentId!,
                                    studentName:
                                        result.studentName ?? 'Student',
                                  );
                                  _fetchLiveAttendance();
                                } catch (e) {
                                  debugPrint(
                                      'Backend mark attendance sync notice: $e');
                                }
                              }

                              if (context.mounted) {
                                AppHaptics.mediumImpact();
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      result.valid
                                          ? "✓ Verified Present: ${result.studentName ?? 'Student'}"
                                          : 'Verification failed: ${result.reason}',
                                      style: GoogleFonts.inter(
                                          color: Colors.white),
                                    ),
                                    backgroundColor: result.valid
                                        ? AppColors.success
                                        : AppColors.danger,
                                    behavior: SnackBarBehavior.floating,
                                    shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(12)),
                                  ),
                                );
                              }
                            },
                          ),
                        ),

                        // Dim overlay with rounded cutout
                        Positioned.fill(
                          child: CustomPaint(
                            painter: ScannerHoleOverlayPainter(
                              cutOutRect: cutOutRect,
                              borderRadius: 20.0,
                            ),
                          ),
                        ),

                        // 4 corner brackets
                        Positioned.fill(
                          child: CustomPaint(
                            painter: ScannerCornersPainter(
                              cutOutRect: cutOutRect,
                              cornerLength: 32.0,
                              cornerStroke: 3.8,
                              borderRadius: 20.0,
                            ),
                          ),
                        ),

                        // Top header bar with title and close button
                        Positioned(
                          top: 16,
                          left: 20,
                          right: 16,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color:
                                          Colors.white.withValues(alpha: 0.12),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(
                                        Icons.qr_code_scanner_rounded,
                                        color: Colors.white,
                                        size: 20),
                                  ),
                                  const SizedBox(width: 12),
                                  Text(
                                    'Scan Student QR',
                                    style: GoogleFonts.inter(
                                      fontSize: 17,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                ],
                              ),
                              IconButton(
                                icon: Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.15),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.close_rounded,
                                      color: Colors.white, size: 20),
                                ),
                                onPressed: () {
                                  controller.stop();
                                  controller.dispose();
                                  Navigator.pop(ctx);
                                },
                              ),
                            ],
                          ),
                        ),

                        // Subtitle guide text below viewfinder
                        Positioned(
                          top: cutOutTop + cutOutSize + 24,
                          left: 24,
                          right: 24,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                "Align student's Passport QR within frame",
                                textAlign: TextAlign.center,
                                style: GoogleFonts.inter(
                                  color: Colors.white.withValues(alpha: 0.95),
                                  fontSize: 14.0,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 0.2,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'Pinch to zoom for better focus',
                                textAlign: TextAlign.center,
                                style: GoogleFonts.inter(
                                  color: Colors.white.withValues(alpha: 0.55),
                                  fontSize: 12.0,
                                  fontWeight: FontWeight.w400,
                                ),
                              ),
                            ],
                          ),
                        ),

                        // Floating Torch Button
                        Positioned(
                          bottom: 28,
                          left: 0,
                          right: 0,
                          child: Center(
                            child: CampusTorchButton(
                              isTorchOn: isTorchOn,
                              onTap: () {
                                controller.toggleTorch();
                                setModalState(() => isTorchOn = !isTorchOn);
                              },
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            );
          },
        );
      },
    );
  }
}

/// Deep indigo dark gradient background with 5-stop radial glow centered behind the orb.
class _LiveBackgroundLayer extends StatelessWidget {
  const _LiveBackgroundLayer();

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                _LiveTheme.bgTop,
                _LiveTheme.bgBottom,
              ],
            ),
          ),
        ),
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: const Alignment(0.0, -0.48), // 50% across, 26% down
              radius: 0.72,
              colors: [
                _LiveTheme.indigoGlow.withValues(alpha: 0.36),
                _LiveTheme.indigoGlow.withValues(alpha: 0.22),
                _LiveTheme.indigoGlow.withValues(alpha: 0.08),
                _LiveTheme.indigoGlow.withValues(alpha: 0.02),
                _LiveTheme.indigoGlow.withValues(alpha: 0.00),
              ],
              stops: const [0.0, 0.28, 0.56, 0.80, 1.0],
            ),
          ),
        ),
      ],
    );
  }
}

/// Apple-grade Dynamic Rotating Optical QR Sheet with live countdown sweep.
class _DynamicTeacherQrModal extends StatefulWidget {
  final PassportTeacherAttendanceService teacherService;
  final VoidCallback onScanStudentResponse;
  final VoidCallback onClose;

  const _DynamicTeacherQrModal({
    required this.teacherService,
    required this.onScanStudentResponse,
    required this.onClose,
  });

  @override
  State<_DynamicTeacherQrModal> createState() => _DynamicTeacherQrModalState();
}

class _DynamicTeacherQrModalState extends State<_DynamicTeacherQrModal> {
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now().toUtc().millisecondsSinceEpoch ~/ 1000;
    final remainingWindowSeconds = 10 - (now % 10);
    final qrProg = (10 - remainingWindowSeconds) / 10.0;
    final beacon = widget.teacherService.activeBeacon;
    final qrData = beacon?.toQrString(dynamicWindowSeconds: 10) ?? '';
    final currentPin = widget.teacherService.currentRollingPin;

    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF14142E), Color(0xFF0A0A1A)],
        ),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        border: Border(
          top: BorderSide(
            color: Colors.white.withValues(alpha: 0.16),
          ),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 38,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.24),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Dynamic Optical QR',
                      style: GoogleFonts.inter(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: _LiveTheme.textPrimary,
                      ),
                    ),
                    Text(
                      '10s Rotating Line-of-Sight · Anti-Relay Protected',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: _LiveTheme.textMuted62,
                      ),
                    ),
                  ],
                ),
              ),
              _TactilePress(
                onTap: widget.onClose,
                semanticsLabel: 'Close optical QR sheet',
                child: const _LiveGlassSurface(
                  isCircle: true,
                  width: 36,
                  height: 36,
                  child: Center(
                    child: Icon(
                      Icons.close_rounded,
                      size: 18,
                      color: _LiveTheme.textPrimary,
                    ),
                  ),
                ),
              ),
            ],
          ),
          Divider(color: Colors.white.withValues(alpha: 0.08), height: 22),
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  Text(
                    'Students with Bluetooth turned off scan this rotating QR code to prove physical line-of-sight attendance:',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      color: _LiveTheme.textMuted66,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (qrData.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: _LiveTheme.indigoDeep.withValues(alpha: 0.35),
                            blurRadius: 24,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: QrImageView(
                        data: qrData,
                        version: QrVersions.auto,
                        size: 200.0,
                      ),
                    )
                  else
                    const Padding(
                      padding: EdgeInsets.all(32),
                      child:
                          CircularProgressIndicator(color: _LiveTheme.accent),
                    ),
                  const SizedBox(height: 14),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _RingTimer(progress: qrProg),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          'Rotates in ${remainingWindowSeconds}s  ·  Room PIN: $currentPin',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.inter(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                            color: _LiveTheme.textMuted66,
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton.icon(
                    onPressed: widget.onScanStudentResponse,
                    icon: const Icon(Icons.qr_code_scanner_rounded,
                        size: 18, color: Colors.white),
                    label: Text(
                      'Scan Student Response QR',
                      style: GoogleFonts.inter(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                        color: Colors.white,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _LiveTheme.indigoDeep,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      padding: const EdgeInsets.symmetric(
                          vertical: 14, horizontal: 20),
                      elevation: 0,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
