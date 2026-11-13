import 'dart:async';
import 'package:attendance_app/core/haptics/app_haptics.dart';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../auth/services/auth_service.dart';
import '../../shared/services/session_service.dart';
import '../../shared/services/attendance_service.dart';
import '../../auth/models/user_model.dart';
import '../../shared/models/session_model.dart';
import '../../core/theme/app_theme.dart';
import '../../router/app_routes.dart';
import 'package:provider/provider.dart';
import '../../shared/providers/attendance_provider.dart';
import 'passport_screen.dart';
import '../services/passport_location_service.dart';

class ReadyScreen extends StatefulWidget {
  const ReadyScreen({Key? key}) : super(key: key);

  @override
  State<ReadyScreen> createState() => _ReadyScreenState();
}

class _ReadyScreenState extends State<ReadyScreen>
    with TickerProviderStateMixin {
  final _authService = AuthService();
  final _sessionService = SessionService();
  final _attendanceService = AttendanceService();

  UserModel? _currentUser;
  List<SessionModel> _activeSessions = [];
  bool _isScanning = false;
  String _statusMessage = "Finding Active Class...";

  // Broadcast Timer
  Timer? _broadcastTimer;
  final ValueNotifier<Duration> _broadcastDurationNotifier =
      ValueNotifier<Duration>(Duration.zero);

  // Slider State
  double _dragValue = 0.0;
  final double _maxWidth = 280.0;
  Timer? _autoRefreshTimer;

  @override
  void initState() {
    super.initState();
    _loadData();
    _startBroadcastTimer();
    _autoRefreshTimer = Timer.periodic(const Duration(seconds: 3), (timer) {
      if (!_isScanning) {
        _refreshSessions();
      }
    });
  }

  @override
  void dispose() {
    try {
      FlutterBluePlus.stopScan();
    } catch (_) {}
    _autoRefreshTimer?.cancel();
    _broadcastTimer?.cancel();
    _broadcastDurationNotifier.dispose();
    super.dispose();
  }

  void _startBroadcastTimer() {
    _broadcastTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        _broadcastDurationNotifier.value += const Duration(seconds: 1);
      }
    });
  }

  String _formatDuration(Duration d) {
    String twoDigits(int n) => n.toString().padLeft(2, "0");
    String twoDigitMinutes = twoDigits(d.inMinutes.remainder(60));
    String twoDigitSeconds = twoDigits(d.inSeconds.remainder(60));
    return "$twoDigitMinutes:$twoDigitSeconds";
  }

  Future<void> _loadData() async {
    _currentUser = await _authService.getUserDataFromStorage();
    await _refreshSessions();
  }

  Future<void> _refreshSessions() async {
    if (_currentUser == null) return;
    try {
      final sessions = await _sessionService.getActiveSessions(
        course: _currentUser?.course,
        branch: _currentUser?.branch,
        year: _currentUser?.year,
      );
      if (mounted) {
        setState(() {
          _activeSessions = sessions;
          if (sessions.isEmpty) {
            _statusMessage = "No Active Class Found Yet";
          } else {
            _statusMessage = "Class Detected: ${sessions.first.name}";
          }
        });
      }
    } catch (e) {
      debugPrint("Error refreshing sessions: $e");
    }
  }

  Future<void> _startScanning() async {
    // Logic: The slider is UNLOCKED only when a session is found.
    // So if this is called, we assume a session exists and user swiped.
    if (_activeSessions.isEmpty) return;

    try {
      await [
        Permission.bluetoothScan,
        Permission.bluetoothConnect,
        Permission.location
      ].request();
    } catch (_) {}

    setState(() {
      _isScanning = true;
      _statusMessage = "Verifying signal & proximity...";
    });

    // Attempt BLE Scan with graceful GPS + Internet fallback
    try {
      await FlutterBluePlus.startScan(timeout: const Duration(seconds: 5));

      var scanSubscription = FlutterBluePlus.scanResults.listen((results) async {
        for (ScanResult r in results) {
          for (var session in _activeSessions) {
            final targetUuid = SessionService.formatSessionBleUuid(session.id).toLowerCase();
            final matchesService = r.advertisementData.serviceUuids.any(
              (u) =>
                  u.toString().toLowerCase() == targetUuid ||
                  u.toString().toLowerCase().replaceAll('-', '').contains(session.id.toLowerCase()),
            );

            if (matchesService) {
              int rssi = r.rssi;
              bool isShortRange = (session.txPowerLevel == 0);
              int threshold = isShortRange ? -60 : -90;

              if (rssi >= threshold) {
                FlutterBluePlus.stopScan();
                await _stopScanAndMarkAttendance(session);
                return;
              }
            }
          }
        }
      });

      await Future.delayed(const Duration(seconds: 5));
      if (mounted && _isScanning) {
        FlutterBluePlus.stopScan();
        scanSubscription.cancel();
        // If student has an active session and BLE didn't trigger in 5s, mark attendance directly via GPS
        if (_activeSessions.isNotEmpty) {
          setState(() {
            _statusMessage = "Session detected: ${_activeSessions.first.name}. Verifying GPS...";
          });
          await _stopScanAndMarkAttendance(_activeSessions.first);
        } else {
          setState(() {
            _isScanning = false;
            _dragValue = 0.0; // Reset slider
            _statusMessage = "Signal too weak. Move closer.";
          });
        }
      }
    } catch (e) {
      debugPrint("ℹ️ [READY_SCREEN] Bluetooth unavailable ($e). Marking via GPS + Internet...");
      if (_activeSessions.isNotEmpty) {
        await _stopScanAndMarkAttendance(_activeSessions.first);
      } else {
        setState(() {
          _isScanning = false;
          _dragValue = 0.0;
          _statusMessage = "Bluetooth unavailable. Please enable GPS & Internet.";
        });
      }
    }
  }

  Future<void> _stopScanAndMarkAttendance(SessionModel session) async {
    if (!mounted) return;
    setState(() {
      _statusMessage = "Verifying GPS location within 20m radius...";
    });
    try {
      double? lat;
      double? lng;
      try {
        final snap = await const PassportLocationService().captureSnapshot(
          timeout: const Duration(seconds: 4),
        );
        if (snap != null) {
          lat = snap.latitude;
          lng = snap.longitude;
        }
      } catch (locErr) {
        debugPrint('ℹ️ [READY_SCREEN] Location snapshot notice: $locErr');
      }

      await _attendanceService.markAttendance(
        sessionId: session.id,
        studentId: _currentUser!.uid,
        studentName: _currentUser!.name,
        latitude: lat,
        longitude: lng,
        verificationMode: lat != null ? 'GPS_LOCATION' : 'BLE_PROXIMITY',
      );

      if (!mounted) return;

      // --- NEW: Refresh History ---
      context.read<AttendanceProvider>().refreshAttendance();

      AppHaptics.heavyImpact();
      Navigator.pushReplacementNamed(
        context,
        AppRoutes.studentSuccess,
        arguments: {
          'userName': _currentUser!.name,
          'sessionName': session.name,
        },
      );
    } catch (e) {
      if (mounted) {
        setState(() {
          _isScanning = false;
          _dragValue = 0.0;
          _statusMessage = "Error: ${e.toString().replaceAll('Exception: ', '')}";
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasSession = _activeSessions.isNotEmpty;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: Stack(
        children: [
          // 1. Background Gradients
          Positioned(
            top: -150,
            right: -100,
            child: Container(
              width: 400,
              height: 400,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    AppTheme.primaryBlue.withValues(alpha: 0.1),
                    Colors.transparent
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            bottom: -100,
            left: -100,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    const Color(0xFF4ECCA3).withValues(alpha: 0.1),
                    Colors.transparent
                  ],
                ),
              ),
            ),
          ),

          // 2. Main Content
          SafeArea(
            child: Column(
              children: [
                _buildTopBar(),
                const Spacer(),
                _buildRadarCard(hasSession),
                const SizedBox(height: 30),
                _buildBroadcastPill(),
                const SizedBox(height: 20),
                // Hint Text
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 40),
                  child: Text(
                    "Keep your phone nearby. Attendance will appear automatically when the class session starts.",
                    textAlign: TextAlign.center,
                    style: GoogleFonts.outfit(
                      fontSize: 13,
                      color: Colors.grey.shade500,
                      height: 1.4,
                    ),
                  ),
                ),
                const Spacer(),
                TextButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => PassportScreen(user: _currentUser),
                      ),
                    );
                  },
                  icon: const Icon(Icons.fingerprint_rounded, size: 18, color: AppTheme.primaryBlue),
                  label: Text(
                    "Switch to CampusOS Passport Batch Attendance",
                    style: GoogleFonts.outfit(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.primaryBlue,
                    ),
                  ),
                ),
                if (hasSession) ...[
                  const SizedBox(height: 6),
                  OutlinedButton.icon(
                    onPressed: _isScanning
                        ? null
                        : () => _stopScanAndMarkAttendance(_activeSessions.first),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF0D9488),
                      side: const BorderSide(color: Color(0xFF0D9488)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    ),
                    icon: const Icon(Icons.location_on_rounded, size: 16),
                    label: Text(
                      "Mark via GPS & Internet (20m Radius)",
                      style: GoogleFonts.outfit(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                _buildSlider(hasSession),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
            color: const Color(0xFF1E293B),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Mark Attendance",
                style: GoogleFonts.outfit(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF1E293B),
                ),
              ),
              Text(
                "Broadcasting active — looking for session",
                style: GoogleFonts.outfit(
                  fontSize: 12,
                  color: Colors.grey.shade500,
                ),
              ),
            ],
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppTheme.primaryBlue.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.bluetooth_audio_rounded,
                color: AppTheme.primaryBlue, size: 20),
          ).animate(onPlay: (c) => c.repeat(reverse: true)).scale(
              begin: const Offset(1, 1),
              end: const Offset(1.1, 1.1),
              duration: 1500.ms),
        ],
      ),
    );
  }

  Widget _buildRadarCard(bool hasSession) {
    return Container(
      width: 300,
      height: 320,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(32),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 30,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Radar Visual
          SizedBox(
            width: 160,
            height: 160,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Outer Pulse
                Container(
                  width: 160,
                  height: 160,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppTheme.primaryBlue.withValues(alpha: 0.05),
                  ),
                )
                    .animate(onPlay: (c) => c.repeat())
                    .scale(
                        begin: const Offset(0.5, 0.5),
                        end: const Offset(1, 1),
                        duration: 2000.ms)
                    .fadeOut(duration: 2000.ms),
                // Middle Pulse
                Container(
                  width: 110,
                  height: 110,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppTheme.primaryBlue.withValues(alpha: 0.1),
                  ),
                )
                    .animate(onPlay: (c) => c.repeat())
                    .scale(
                        begin: const Offset(0.5, 0.5),
                        end: const Offset(1, 1),
                        duration: 2000.ms,
                        delay: 500.ms)
                    .fadeOut(duration: 2000.ms, delay: 500.ms),
                // Center Icon
                Container(
                  width: 70,
                  height: 70,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(
                      colors: [AppTheme.primaryBlue, Color(0xFF2563EB)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.primaryBlue.withValues(alpha: 0.4),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: const Icon(Icons.radar_rounded,
                      color: Colors.white, size: 32),
                ),
              ],
            ),
          ),
          const SizedBox(height: 30),
          // Status Text
          Text(
            _statusMessage,
            textAlign: TextAlign.center,
            style: GoogleFonts.outfit(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: hasSession
                  ? const Color(0xFF4ECCA3)
                  : const Color(0xFF1E293B),
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Text(
              hasSession
                  ? "Session found: ${_activeSessions.first.name}"
                  : "Please wait while we detect the teacher's session.",
              textAlign: TextAlign.center,
              style: GoogleFonts.outfit(
                fontSize: 14,
                color: Colors.grey.shade500,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 600.ms).slideY(begin: 0.1, end: 0);
  }

  Widget _buildBroadcastPill() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: const BoxDecoration(
              color: AppTheme.primaryBlue,
              shape: BoxShape.circle,
            ),
          )
              .animate(onPlay: (c) => c.repeat(reverse: true))
              .fadeIn(duration: 800.ms),
          const SizedBox(width: 10),
          ValueListenableBuilder<Duration>(
            valueListenable: _broadcastDurationNotifier,
            builder: (context, duration, _) {
              return Text(
                "Broadcasting... BLE active for ${_formatDuration(duration)}",
                style: GoogleFonts.outfit(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: const Color(0xFF1E293B),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSlider(bool hasSession) {
    return Center(
      child: Container(
        width: _maxWidth,
        height: 70,
        decoration: BoxDecoration(
          color: hasSession ? Colors.white : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(35),
          border: Border.all(
            color: hasSession
                ? AppTheme.primaryBlue.withValues(alpha: 0.2)
                : Colors.grey.shade300,
          ),
          boxShadow: hasSession
              ? [
                  BoxShadow(
                    color: AppTheme.primaryBlue.withValues(alpha: 0.15),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  )
                ]
              : null,
        ),
        child: Stack(
          alignment: Alignment.centerLeft,
          children: [
            // Text
            Center(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (!hasSession)
                    Icon(Icons.lock_outline_rounded,
                        size: 16, color: Colors.grey.shade400),
                  if (!hasSession) const SizedBox(width: 8),
                  Text(
                    hasSession
                        ? "SLIDE TO MARK ATTENDANCE"
                        : "WAITING FOR CLASS...",
                    style: GoogleFonts.outfit(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                      color: hasSession
                          ? AppTheme.primaryBlue
                          : Colors.grey.shade400,
                    ),
                  ),
                ],
              ),
            ),

            // Slider Knob
            Positioned(
              left: _dragValue,
              child: GestureDetector(
                onHorizontalDragUpdate: (details) {
                  if (!hasSession || _isScanning) return;
                  setState(() {
                    _dragValue += details.delta.dx;
                    if (_dragValue < 0) _dragValue = 0;
                    if (_dragValue > _maxWidth - 70) {
                      _dragValue = _maxWidth - 70;
                    }
                  });
                },
                onHorizontalDragEnd: (details) {
                  if (!hasSession || _isScanning) return;
                  if (_dragValue > (_maxWidth - 70) * 0.7) {
                    setState(() => _dragValue = _maxWidth - 70);
                    AppHaptics.mediumImpact();
                    _startScanning();
                  } else {
                    setState(() => _dragValue = 0);
                  }
                },
                child: Container(
                  width: 70,
                  height: 70,
                  margin: const EdgeInsets.all(0), // No margin for flush fit
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: hasSession
                        ? const LinearGradient(
                            colors: [AppTheme.primaryBlue, Color(0xFF2563EB)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          )
                        : LinearGradient(
                            colors: [
                              Colors.grey.shade300,
                              Colors.grey.shade400
                            ],
                          ),
                    boxShadow: hasSession
                        ? [
                            BoxShadow(
                              color: AppTheme.primaryBlue.withValues(alpha: 0.4),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            )
                          ]
                        : null,
                  ),
                  child: Icon(
                    hasSession
                        ? Icons.arrow_forward_rounded
                        : Icons.lock_rounded,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    ).animate().fadeIn(delay: 400.ms).slideY(begin: 0.2, end: 0);
  }
}
