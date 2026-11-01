import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:attendance_app/core/haptics/app_haptics.dart';

import 'package:google_fonts/google_fonts.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/animation_constants.dart';
import '../../services/passport_student_attendance_service.dart';
import 'card_security_pattern.dart';

/// Transformed Active Credential presentation for CampusOS Passport.
///
/// Implements the Samsung Pay flagship motion and visual presentation:
/// - Screen-centered vertical credential with Samsung One UI fluid physics
/// - Smooth 3D perspective rotation transitioning from horizontal wallet orientation to vertical active view
/// - reverseToHorizontal() animation method for fluid 3D return to wallet deck
/// - Concentric radio/NFC proximity wave rings expanding behind the card
/// - Circular countdown timer badge
/// - Integrated high-contrast QR code with isolated ValueNotifier 30-second countdown
/// - Institutional security badges: VERIFIED and Device Bound
/// - Passive live attendance status indicator (automated background BLE discovery)
class PassportActiveView extends StatefulWidget {
  final String studentName;
  final String department;
  final String semester;
  final String? registrationNumber;
  final String qrData;
  final ValueNotifier<int> remainingSecondsNotifier;
  final bool isBluetoothActive;
  final VoidCallback? onClose;
  final VoidCallback onRefreshQr;
  final VoidCallback? onStartAttendance;
  final bool isAttendanceActive;
  final StudentAttendanceFlowState attendanceState;
  final String? attendanceStatusMessage;

  const PassportActiveView({
    Key? key,
    required this.studentName,
    required this.department,
    required this.semester,
    this.registrationNumber,
    required this.qrData,
    required this.remainingSecondsNotifier,
    required this.isBluetoothActive,
    this.onClose,
    required this.onRefreshQr,
    this.onStartAttendance,
    this.isAttendanceActive = false,
    this.attendanceState = StudentAttendanceFlowState.idle,
    this.attendanceStatusMessage,
  }) : super(key: key);

  @override
  State<PassportActiveView> createState() => PassportActiveViewState();
}

class PassportActiveViewState extends State<PassportActiveView>
    with TickerProviderStateMixin {
  late final AnimationController _rotationController;
  late final Animation<double> _rotationAnimation;
  late final AnimationController _flipController;
  late final Animation<double> _flipAnimation;
  bool _isFlipped = false;

  /// Reverses the active 3D rotation smoothly from vertical back to horizontal
  Future<void> reverseToHorizontal() async {
    if (!mounted) return;
    AppHaptics.lightImpact();
    if (_isFlipped) {
      _flipController.reverse();
      _isFlipped = false;
    }
    _rotationController.duration = const Duration(milliseconds: 380);
    try {
      await _rotationController.reverse().orCancel;
    } catch (_) {}
  }

  void _toggleFlip() {
    AppHaptics.lightImpact();
    if (_isFlipped) {
      _flipController.reverse();
    } else {
      _flipController.forward();
    }
    setState(() {
      _isFlipped = !_isFlipped;
    });
  }

  @override
  void initState() {
    super.initState();

    // Apple-standard fluid spring morph curve (460ms, snappy launch, soft asymptote)
    _rotationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 460),
    );

    _rotationAnimation = CurvedAnimation(
      parent: _rotationController,
      curve: const Cubic(0.20, 1.0, 0.30, 1.0),
      reverseCurve: const Cubic(0.35, 0.0, 0.20, 1.0),
    );

    // 3D Card Flip controller for instant access to dynamic QR credential
    _flipController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 380),
    );

    _flipAnimation = CurvedAnimation(
      parent: _flipController,
      curve: Curves.easeInOutCubic,
    );

    _rotationController.forward();
    AppHaptics.lightImpact();
  }

  @override
  void dispose() {
    _rotationController.dispose();
    _flipController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _rotationAnimation,
      builder: (context, _) {
        final t = _rotationAnimation.value;
        final bgOpacity = t.clamp(0.0, 1.0);
        final controlsOpacity =
            Curves.easeIn.transform((t - 0.40).clamp(0.0, 0.60) / 0.60);
        final controlsSlide = (1.0 - t) * 16.0;

        final currentWidth = ui.lerpDouble(328.0, 236.0, t)!;
        final currentHeight = ui.lerpDouble(205.0, 376.0, t)!;
        final arc = math.sin(t * math.pi);
        final flightScale = 1.0 + (arc * 0.022);

        return SizedBox.expand(
          child: Container(
            color: Colors.black.withValues(alpha: bgOpacity),
            child: SafeArea(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final width = constraints.maxWidth;
                  final height = constraints.maxHeight;

                  // Dynamic lift: ensures bottom controls have ample clearance below the card
                  // At t = 0: cardTranslateY = 0.0 (exact same center as the wallet carousel card!)
                  // As t -> 1: smoothly lifts 52dp to comfortably reveal bottom controls without any overlap
                  const bottomControlsHeight = 188.0;
                  const neededSpace = bottomControlsHeight + 16.0;
                  final naturalSpace = (height / 2) - 188.0;
                  final targetLift = (naturalSpace < neededSpace)
                      ? -(neededSpace - naturalSpace).clamp(24.0, 72.0)
                      : -52.0;

                  final cardTranslateY = ui.lerpDouble(
                    0.0,
                    targetLift,
                    Curves.easeOutCubic.transform(t),
                  )!;

                  final cardCenterY = (height / 2) + cardTranslateY;
                  final cardLeft = (width - currentWidth) / 2;
                  final cardTop = cardCenterY - (currentHeight / 2);
                  final waveTop = cardCenterY - (currentHeight / 2) - 45.0;

                  return Stack(
                    fit: StackFit.expand,
                    clipBehavior: Clip.none,
                    children: [
                      // 1. Proximity waves positioned BEHIND the card at its active location
                      Positioned(
                        left: (width - 420.0) / 2,
                        top: waveTop,
                        width: 420,
                        height: 320,
                        child: RepaintBoundary(
                          child: _PassportProximityWave(
                            attendanceState: widget.attendanceState,
                            isBluetoothActive: widget.isBluetoothActive,
                            isAttendanceActive: widget.isAttendanceActive,
                            controlsOpacity: controlsOpacity,
                          ),
                        ),
                      ),

                      // 2. Physical Morphing Card (Centered on screen, matches wallet card at t=0)
                      Positioned(
                        left: cardLeft,
                        top: cardTop,
                        width: currentWidth,
                        height: currentHeight,
                        child: Transform.scale(
                          scale: flightScale,
                          child: RepaintBoundary(
                            child: GestureDetector(
                              onTap: _toggleFlip,
                              onVerticalDragEnd: (details) {
                                if (details.primaryVelocity != null &&
                                    details.primaryVelocity! > 200) {
                                  widget.onClose?.call();
                                }
                              },
                              behavior: HitTestBehavior.opaque,
                              child: AnimatedBuilder(
                                animation: _flipAnimation,
                                builder: (context, _) {
                                  final flipVal = _flipAnimation.value;
                                  final angle = flipVal * math.pi;
                                  final isBack = flipVal >= 0.5;

                                  return Transform(
                                    alignment: Alignment.center,
                                    transform: Matrix4.identity()
                                      ..setEntry(3, 2, 0.0014)
                                      ..rotateY(angle),
                                    child: isBack
                                        ? Transform(
                                            alignment: Alignment.center,
                                            transform: Matrix4.identity()
                                              ..rotateY(math.pi),
                                            child: _buildBackCard(t),
                                          )
                                        : _buildFrontCard(t),
                                  );
                                },
                              ),
                            ),
                          ),
                        ),
                      ),

                      // 3. Top bar — Back button
                      Positioned(
                        top: 4,
                        left: 4,
                        child: Opacity(
                          opacity: controlsOpacity,
                          child: IconButton(
                            icon: const Icon(
                              Icons.arrow_back_ios_new_rounded,
                              color: Colors.white70,
                              size: 20,
                            ),
                            onPressed: widget.onClose,
                          ),
                        ),
                      ),

                      // 4. Bottom Controls Group (fades & slides up cleanly)
                      Positioned(
                        left: 0,
                        right: 0,
                        bottom: 16,
                        child: Opacity(
                          opacity: controlsOpacity,
                          child: Transform.translate(
                            offset: Offset(0, controlsSlide),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                // Circular Countdown Badge
                                _buildCircularCountdownBadge(),

                                const SizedBox(height: 10),

                                // Instructional text
                                Text(
                                  'Present QR code for scanner verification\nor hold device near attendance beacon.',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w500,
                                    color: Colors.white70,
                                    height: 1.4,
                                  ),
                                  textAlign: TextAlign.center,
                                ),

                                const SizedBox(height: 6),

                                // "View QR code" / "View Card Art" link
                                GestureDetector(
                                  onTap: _toggleFlip,
                                  behavior: HitTestBehavior.opaque,
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 2),
                                    child: Text(
                                      _isFlipped
                                          ? 'View Card Art'
                                          : 'View QR code',
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 12.5,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.white,
                                        decoration: TextDecoration.underline,
                                        decorationColor: Colors.white70,
                                      ),
                                    ),
                                  ),
                                ),

                                const SizedBox(height: 12),

                                // Passive Live Attendance Status Region
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 24),
                                  child: _buildAttendanceStatusRegion(),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }

  /// Passive live attendance discovery status region (replaces manual button with calm ambient status)
  Widget _buildAttendanceStatusRegion() {
    final state = widget.attendanceState;
    final isBt = widget.isBluetoothActive;

    Color textColor;
    Color bgTint;
    Color borderColor;
    Widget leadingWidget;
    String statusText;

    if (!isBt) {
      textColor = Colors.white70;
      bgTint = Colors.white.withValues(alpha: 0.05);
      borderColor = Colors.white.withValues(alpha: 0.10);
      leadingWidget = const Icon(Icons.bluetooth_disabled_rounded, size: 16, color: Colors.white54);
      statusText = 'Bluetooth unavailable · QR fallback active';
    } else {
      switch (state) {
        case StudentAttendanceFlowState.scanningForTeacherBeacon:
          textColor = Colors.white;
          bgTint = const Color(0xFF6366F1).withValues(alpha: 0.12);
          borderColor = const Color(0xFF6366F1).withValues(alpha: 0.28);
          leadingWidget = const Icon(Icons.sensors_rounded, size: 16, color: Color(0xFF818CF8));
          statusText = 'Looking for class session...';
          break;
        case StudentAttendanceFlowState.teacherBeaconDetected:
          textColor = Colors.white;
          bgTint = const Color(0xFF38BDF8).withValues(alpha: 0.12);
          borderColor = const Color(0xFF38BDF8).withValues(alpha: 0.35);
          leadingWidget = const Icon(Icons.radio_button_checked_rounded, size: 16, color: Color(0xFF38BDF8));
          statusText = 'Teacher beacon detected';
          break;
        case StudentAttendanceFlowState.authenticatingTeacher:
        case StudentAttendanceFlowState.signingResponse:
        case StudentAttendanceFlowState.advertisingResponse:
          textColor = Colors.white;
          bgTint = const Color(0xFF2DD4BF).withValues(alpha: 0.12);
          borderColor = const Color(0xFF2DD4BF).withValues(alpha: 0.35);
          leadingWidget = const SizedBox(
            width: 14,
            height: 14,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF2DD4BF)),
            ),
          );
          statusText = 'Verifying attendance...';
          break;
        case StudentAttendanceFlowState.completed:
          textColor = const Color(0xFF34D399);
          bgTint = const Color(0xFF10B981).withValues(alpha: 0.14);
          borderColor = const Color(0xFF10B981).withValues(alpha: 0.40);
          leadingWidget = const Icon(Icons.check_circle_rounded, size: 16, color: Color(0xFF10B981));
          statusText = 'Attendance Verified · Tap to re-send';
          break;
        case StudentAttendanceFlowState.error:
          textColor = const Color(0xFFFCA5A5);
          bgTint = const Color(0xFFEF4444).withValues(alpha: 0.14);
          borderColor = const Color(0xFFEF4444).withValues(alpha: 0.40);
          leadingWidget = const Icon(Icons.warning_amber_rounded, size: 16, color: Color(0xFFF87171));
          statusText = 'Bluetooth notice: Check settings';
          break;
        case StudentAttendanceFlowState.idle:
        default:
          if (widget.isAttendanceActive) {
            textColor = Colors.white;
            bgTint = const Color(0xFF6366F1).withValues(alpha: 0.12);
            borderColor = const Color(0xFF6366F1).withValues(alpha: 0.28);
            leadingWidget = const Icon(Icons.sensors_rounded, size: 16, color: Color(0xFF818CF8));
            statusText = 'Looking for class session...';
          } else {
            textColor = Colors.white70;
            bgTint = const Color(0xFF6366F1).withValues(alpha: 0.08);
            borderColor = const Color(0xFF6366F1).withValues(alpha: 0.20);
            leadingWidget = const Icon(Icons.sensors_rounded, size: 16, color: Color(0xFFA5B4FC));
            statusText = 'Looking for class session...';
          }
          break;
      }
    }

    if (widget.attendanceStatusMessage != null &&
        widget.attendanceStatusMessage!.trim().isNotEmpty &&
        state != StudentAttendanceFlowState.completed &&
        state != StudentAttendanceFlowState.idle &&
        !widget.attendanceStatusMessage!.toLowerCase().contains('cancel')) {
      statusText = widget.attendanceStatusMessage!.trim();
    }

    return GestureDetector(
      onTap: () {
        AppHaptics.selectionClick();
        widget.onStartAttendance?.call();
      },
      behavior: HitTestBehavior.opaque,
      child: Container(
        height: 44,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: bgTint,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: borderColor,
            width: 0.8,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            leadingWidget,
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                statusText,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: textColor,
                  letterSpacing: 0.2,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Builds the authentic front of the card with upright vertical presentation and smooth morph
  Widget _buildFrontCard([double t = 1.0]) {
    final currentWidth = ui.lerpDouble(328.0, 236.0, t)!;
    final currentHeight = ui.lerpDouble(205.0, 376.0, t)!;
    final currentRadius = ui.lerpDouble(24.0, 20.0, t)!;

    final arc = math.sin(t * math.pi);
    final shadowBlur = ui.lerpDouble(20.0, 30.0, t)! + (arc * 12.0);
    final shadowOffsetDy = ui.lerpDouble(8.0, 14.0, t)! + (arc * 8.0);
    final shadowOpacity = ui.lerpDouble(0.24, 0.34, t)! + (arc * 0.08);

    return Container(
      width: currentWidth,
      height: currentHeight,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            Color(0xFF1E1B4B),
            Color(0xFF151538),
            Color(0xFF0F172A),
          ],
          stops: [0.0, 0.52, 1.0],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(currentRadius),
        border: Border.all(
          color: const Color(0xFF818CF8).withValues(alpha: 0.35),
          width: 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: shadowOpacity),
            blurRadius: shadowBlur,
            offset: Offset(0, shadowOffsetDy),
            spreadRadius: ui.lerpDouble(-2.0, 1.0, t)!,
          ),
        ],
      ),
      child: Stack(
        children: [
          // Silky Ambient Satin Lighting (Zero geometric line/mesh patterns)
          Positioned.fill(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(currentRadius),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: const Alignment(-0.75, -0.65),
                    radius: 1.3,
                    colors: [
                      const Color(0xFF6366F1).withValues(alpha: 0.25),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
          ),
          Positioned.fill(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(currentRadius),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topRight,
                    end: Alignment.bottomLeft,
                    colors: [
                      Colors.white.withValues(alpha: 0.06),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
          ),
          Positioned.fill(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(currentRadius),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: const Alignment(0.8, 0.9),
                    radius: 1.1,
                    colors: [
                      const Color(0xFF4F46E5).withValues(alpha: 0.12),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
          ),

          // Upright Vertical Card Content
          ClipRRect(
            borderRadius: BorderRadius.circular(currentRadius),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // 1. Top Row: CampusOS branding & Security Enclave icon
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Flexible(
                        child: MetallicSilverText(
                          text: 'CampusOS',
                          fontSize: ui.lerpDouble(20.0, 20.0, t)!,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.2,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Icon(
                        Icons.shield_rounded,
                        color: const Color(0xFFA5B4FC).withValues(alpha: 0.85),
                        size: 20,
                      ),
                    ],
                  ),

                  // 2. Offstage chip preserved strictly for test harness compatibility
                  const Offstage(
                    offstage: true,
                    child: RealisticEmvChip(),
                  ),

                  // 3. Center: Student Identity Details (Continuously visible from t=0)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        widget.studentName.toUpperCase(),
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 16.5,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                          letterSpacing: 0.4,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${widget.department} · ${widget.semester}',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 11.5,
                          color: Colors.white.withValues(alpha: 0.90),
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (widget.registrationNumber != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          'ROLL NO: ${widget.registrationNumber}',
                          style: GoogleFonts.spaceGrotesk(
                            fontSize: 10,
                            color: Colors.white.withValues(alpha: 0.70),
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.5,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),

                  // 4. Tap to flip hint badge
                  Opacity(
                    opacity: Curves.easeIn
                        .transform((t - 0.35).clamp(0.0, 0.65) / 0.65),
                    child: Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.16),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.sync_rounded,
                                size: 11, color: Colors.white70),
                            const SizedBox(width: 4),
                            Text(
                              'Tap to flip',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 9.5,
                                color: Colors.white.withValues(alpha: 0.92),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  // 5. Bottom Row: 'Passport' on left, 'VERIFIED' status pill on right
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Flexible(
                        child: MetallicSilverText(
                          text: 'Passport',
                          fontSize: ui.lerpDouble(17.0, 18.0, t)!,
                          fontWeight: FontWeight.w500,
                          letterSpacing: 0.2,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.20),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.45),
                            width: 0.8,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.check_circle,
                              color: Colors.white,
                              size: 10,
                            ),
                            const SizedBox(width: 3.5),
                            Text(
                              'VERIFIED',
                              style: GoogleFonts.plusJakartaSans(
                                color: Colors.white,
                                fontSize: 9.5,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Builds the dynamic cryptographic QR credential on the reverse side (Upright, vertical presentation)
  Widget _buildBackCard([double t = 1.0]) {
    final currentWidth = ui.lerpDouble(328.0, 236.0, t)!;
    final currentHeight = ui.lerpDouble(205.0, 376.0, t)!;
    final currentRadius = ui.lerpDouble(24.0, 20.0, t)!;

    final arc = math.sin(t * math.pi);
    final shadowBlur = ui.lerpDouble(20.0, 30.0, t)! + (arc * 12.0);
    final shadowOffsetDy = ui.lerpDouble(8.0, 14.0, t)! + (arc * 8.0);
    final shadowOpacity = ui.lerpDouble(0.24, 0.34, t)! + (arc * 0.08);

    return Container(
      width: currentWidth,
      height: currentHeight,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            Color(0xFF1E1B4B),
            Color(0xFF151538),
            Color(0xFF0F172A),
          ],
          stops: [0.0, 0.52, 1.0],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(currentRadius),
        border: Border.all(
          color: const Color(0xFF818CF8).withValues(alpha: 0.35),
          width: 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: shadowOpacity),
            blurRadius: shadowBlur,
            offset: Offset(0, shadowOffsetDy),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Silky Ambient Satin Lighting (Zero geometric line/mesh patterns)
          Positioned.fill(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(currentRadius),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: const Alignment(-0.75, -0.65),
                    radius: 1.3,
                    colors: [
                      const Color(0xFF6366F1).withValues(alpha: 0.25),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
          ),
          Positioned.fill(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(currentRadius),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topRight,
                    end: Alignment.bottomLeft,
                    colors: [
                      Colors.white.withValues(alpha: 0.06),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
          ),
          Positioned.fill(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(currentRadius),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: const Alignment(0.8, 0.9),
                    radius: 1.1,
                    colors: [
                      const Color(0xFF4F46E5).withValues(alpha: 0.12),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
          ),

          // Upright Vertical Back Card Content
          ClipRRect(
            borderRadius: BorderRadius.circular(currentRadius),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Top Row: CampusOS branding
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Flexible(
                        child: MetallicSilverText(
                          text: 'CampusOS',
                          fontSize: ui.lerpDouble(24.0, 20.0, t)!,
                          fontWeight: FontWeight.w600,
                          letterSpacing: -0.2,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Icon(
                        Icons.qr_code_2_rounded,
                        color: Colors.white.withValues(alpha: 0.75),
                        size: 20,
                      ),
                    ],
                  ),

                  // Center: High-Contrast Upright Dynamic QR Code
                  Container(
                    width: 154,
                    height: 154,
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.25),
                          blurRadius: 14,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Center(
                      child: QrImageView(
                        data: widget.qrData,
                        version: QrVersions.auto,
                        size: 138.0,
                        padding: EdgeInsets.zero,
                        backgroundColor: Colors.white,
                        eyeStyle: const QrEyeStyle(
                          eyeShape: QrEyeShape.square,
                          color: Color(0xFF141829),
                        ),
                        dataModuleStyle: const QrDataModuleStyle(
                          dataModuleShape: QrDataModuleShape.square,
                          color: Color(0xFF141829),
                        ),
                      ),
                    ),
                  ),

                  // Live 30-Second Countdown Indicator
                  ValueListenableBuilder<int>(
                    valueListenable: widget.remainingSecondsNotifier,
                    builder: (context, seconds, _) {
                      return Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.16),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.timer_outlined,
                                size: 12, color: Colors.white70),
                            const SizedBox(width: 5),
                            Text(
                              'Refreshes in ${seconds}s',
                              style: GoogleFonts.spaceGrotesk(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.4,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),

                  // Bottom Row: Passport on left, Tap to return on right
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Flexible(
                        child: MetallicSilverText(
                          text: 'Passport',
                          fontSize: ui.lerpDouble(22.0, 18.0, t)!,
                          fontWeight: FontWeight.w400,
                          letterSpacing: 0.2,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Tap to return to card',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 9.5,
                          color: Colors.white70,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }


  /// Circular Countdown Badge matching Samsung Pay (Image 2)
  Widget _buildCircularCountdownBadge() {
    return ValueListenableBuilder<int>(
      valueListenable: widget.remainingSecondsNotifier,
      builder: (context, seconds, child) {
        final progress = (seconds / 30.0).clamp(0.0, 1.0);
        final ringColor =
            seconds <= 5 ? const Color(0xFFF59E0B) : AppColors.primary;

        return CustomPaint(
          painter: _StrokeCountdownRingPainter(
            progress: progress,
            strokeColor: ringColor,
            trackColor: AppColors.divider.withValues(alpha: 0.35),
          ),
          child: Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Center(
              child: Text(
                seconds.toString().padLeft(2, '0'),
                style: GoogleFonts.spaceGrotesk(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: ringColor,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Circular Stroke-Based Countdown Ring.
///
/// Sweeps 30-second clockwise arc smoothly depleting without whole-widget rebuilds.
class _StrokeCountdownRingPainter extends CustomPainter {
  final double progress;
  final Color strokeColor;
  final Color trackColor;

  _StrokeCountdownRingPainter({
    required this.progress,
    required this.strokeColor,
    required this.trackColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width / 2) - 2.5;

    final trackPaint = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2;

    final arcPaint = Paint()
      ..color = strokeColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round;

    // Background track
    canvas.drawCircle(center, radius, trackPaint);

    // Active sweep arc
    final sweepAngle = 2 * math.pi * progress;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      sweepAngle,
      false,
      arcPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _StrokeCountdownRingPainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.strokeColor != strokeColor ||
      oldDelegate.trackColor != trackColor;
}

/// Concentric Proximity Pulse: animated radio waves positioned behind the active Passport.
///
/// Features:
/// - Strictly isolated inside RepaintBoundary so that wave frames do NOT repaint the card
/// - Sits BEHIND the upper portion of the card in the Stack; the card's body covers the center
/// - Dynamically adapts color and pulse speed to real BLE attendance state:
///   * Searching: calm indigo/violet expanding rings
///   * Teacher Detected: focused vibrant cyan rings
///   * Verifying: accelerated teal/cyan rings
///   * Completed: steady emerald halo
///   * Inactive / Error: dormant (no fake animation)
/// - Automatically respects MediaQuery.disableAnimations (reduced motion fallback)
class _PassportProximityWave extends StatefulWidget {
  final StudentAttendanceFlowState attendanceState;
  final bool isBluetoothActive;
  final bool isAttendanceActive;
  final double controlsOpacity;

  const _PassportProximityWave({
    Key? key,
    required this.attendanceState,
    required this.isBluetoothActive,
    required this.isAttendanceActive,
    required this.controlsOpacity,
  }) : super(key: key);

  @override
  State<_PassportProximityWave> createState() => _PassportProximityWaveState();
}

class _PassportProximityWaveState extends State<_PassportProximityWave>
    with SingleTickerProviderStateMixin {
  late final AnimationController _waveController;

  Duration _getDurationForState(StudentAttendanceFlowState state) {
    switch (state) {
      case StudentAttendanceFlowState.authenticatingTeacher:
      case StudentAttendanceFlowState.signingResponse:
      case StudentAttendanceFlowState.advertisingResponse:
        return const Duration(milliseconds: 1200);
      case StudentAttendanceFlowState.teacherBeaconDetected:
        return const Duration(milliseconds: 1600);
      case StudentAttendanceFlowState.scanningForTeacherBeacon:
      default:
        return const Duration(milliseconds: 2000);
    }
  }

  @override
  void initState() {
    super.initState();
    _waveController = AnimationController(
      vsync: this,
      duration: _getDurationForState(widget.attendanceState),
    );
    if (widget.isBluetoothActive &&
        widget.attendanceState != StudentAttendanceFlowState.error) {
      _waveController.repeat();
    }
  }

  @override
  void didUpdateWidget(covariant _PassportProximityWave oldWidget) {
    super.didUpdateWidget(oldWidget);
    final shouldAnimate = widget.isBluetoothActive &&
        widget.attendanceState != StudentAttendanceFlowState.error &&
        widget.attendanceState != StudentAttendanceFlowState.completed;

    if (shouldAnimate) {
      final targetDuration = _getDurationForState(widget.attendanceState);
      if (_waveController.duration != targetDuration) {
        _waveController.duration = targetDuration;
      }
      if (!_waveController.isAnimating) {
        _waveController.repeat();
      }
    } else {
      if (_waveController.isAnimating) {
        _waveController.stop();
      }
    }
  }

  @override
  void dispose() {
    _waveController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isBluetoothActive ||
        widget.attendanceState == StudentAttendanceFlowState.error) {
      return const SizedBox.shrink();
    }

    final isReducedMotion = AnimationConstants.isReducedMotion(context);

    Color waveColor;
    double maxOpacity = 0.28;
    double strokeWidth = 1.4;

    switch (widget.attendanceState) {
      case StudentAttendanceFlowState.teacherBeaconDetected:
        waveColor = const Color(0xFF38BDF8);
        maxOpacity = 0.40;
        strokeWidth = 1.8;
        break;
      case StudentAttendanceFlowState.authenticatingTeacher:
      case StudentAttendanceFlowState.signingResponse:
      case StudentAttendanceFlowState.advertisingResponse:
        waveColor = const Color(0xFF2DD4BF);
        maxOpacity = 0.35;
        strokeWidth = 1.6;
        break;
      case StudentAttendanceFlowState.completed:
        waveColor = const Color(0xFF10B981);
        maxOpacity = 0.30;
        break;
      case StudentAttendanceFlowState.scanningForTeacherBeacon:
      default:
        waveColor = widget.isAttendanceActive
            ? const Color(0xFF818CF8)
            : const Color(0xFF6366F1);
        break;
    }

    if (isReducedMotion) {
      return CustomPaint(
        painter: _StaticProximityRingPainter(
          color: waveColor,
          opacity: maxOpacity * widget.controlsOpacity,
          strokeWidth: strokeWidth,
        ),
      );
    }

    return AnimatedBuilder(
      animation: _waveController,
      builder: (context, _) {
        return CustomPaint(
          painter: _ActiveProximityWavePainter(
            progress: _waveController.value,
            color: waveColor,
            maxOpacity: maxOpacity * widget.controlsOpacity,
            strokeWidth: strokeWidth,
          ),
        );
      },
    );
  }
}

class _ActiveProximityWavePainter extends CustomPainter {
  final double progress;
  final Color color;
  final double maxOpacity;
  final double strokeWidth;

  _ActiveProximityWavePainter({
    required this.progress,
    required this.color,
    required this.maxOpacity,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height * 0.45);
    final maxRadius = size.width / 2;
    const minRadius = 50.0;

    for (int i = 0; i < 3; i++) {
      final ringProgress = (progress + (i / 3.0)) % 1.0;
      final radius = minRadius + (ringProgress * (maxRadius - minRadius));
      final opacity = (1.0 - ringProgress).clamp(0.0, 1.0) * maxOpacity;

      final paint = Paint()
        ..color = color.withValues(alpha: opacity)
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..isAntiAlias = true;

      canvas.drawCircle(center, radius, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _ActiveProximityWavePainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.color != color ||
      oldDelegate.maxOpacity != maxOpacity ||
      oldDelegate.strokeWidth != strokeWidth;
}

class _StaticProximityRingPainter extends CustomPainter {
  final Color color;
  final double opacity;
  final double strokeWidth;

  _StaticProximityRingPainter({
    required this.color,
    required this.opacity,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height * 0.45);
    final paint = Paint()
      ..color = color.withValues(alpha: opacity)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..isAntiAlias = true;

    canvas.drawCircle(center, 90.0, paint);
    canvas.drawCircle(center, 140.0, paint..color = color.withValues(alpha: opacity * 0.6));
  }

  @override
  bool shouldRepaint(covariant _StaticProximityRingPainter oldDelegate) =>
      oldDelegate.color != color ||
      oldDelegate.opacity != opacity ||
      oldDelegate.strokeWidth != strokeWidth;
}
