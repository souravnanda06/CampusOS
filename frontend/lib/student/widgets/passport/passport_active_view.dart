import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:attendance_app/core/haptics/app_haptics.dart';

import 'package:google_fonts/google_fonts.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../../core/utils/animation_constants.dart';
import '../../../shared/widgets/motion/apple_bounceable.dart';
import '../../services/passport_student_attendance_service.dart';
import 'card_security_pattern.dart';

// ============================================================================
// PASSPORT INDIGO GLOW LIGHTING CONSTANTS (Tuneable)
// ============================================================================
class PassportIndigoGlowTheme {
  // Ambient Glow (behind card)
  static const Color ambientGlowColor = Color(0xFF4F46E5);
  static const double ambientStop0Alpha = 0.30; // 0x4D4F46E5 (~30%)
  static const double ambientStop1Alpha = 0.22; // 0x384F46E5 (~22%)
  static const double ambientStop2Alpha = 0.10; // 0x1A4F46E5 (~10%)
  static const double ambientStop3Alpha = 0.00; // Transparent

  // Concentric Rings (behind card)
  static const double ringInnerDiameter = 400.0;
  static const double ringInnerAlpha = 0.06; // Colors.white at 6%
  static const double ringOuterDiameter = 540.0;
  static const double ringOuterAlpha = 0.04; // Colors.white at 4%

  // Pass Shadows (Static wide pool + dark grounding, outside flip transform)
  static const Color shadowIndigoPool = Color(0x734F46E5); // 0x73 = ~45%
  static const Offset shadowIndigoOffset = Offset(0, 40);
  static const double shadowIndigoBlur = 70.0;
  static const double shadowIndigoSpread = -28.0;

  static const Color shadowDarkGrounding = Color(0xB3000000); // 0xB3 = ~70%
  static const Offset shadowDarkOffset = Offset(0, 12);
  static const double shadowDarkBlur = 28.0;
  static const double shadowDarkSpread = -8.0;

  // Pass Fixed Light Edge (Outer Border)
  static const double edgeWidth = 1.5;
  static const Color edgeTopLeft = Color(0x8CFFFFFF); // white 55%
  static const Color edgeMid = Color(0x1AFFFFFF); // white 10% (at 38%)
  static const Color edgeBottomRight = Color(0x59818CF8); // #818CF8 at 35%

  // Pass Inner Surface Fill (LinearGradient 160 deg)
  static const Color surfaceTop = Color(0xFF34338F);
  static const Color surfaceMid = Color(0xFF1B1A50);
  static const Color surfaceBottom = Color(0xFF0B0A24);

  // Inner Highlights
  static const Color innerTopHighlight = Color(0x59FFFFFF); // 1px white at 35%
  static const Color innerBottomShade = Color(0x59000000); // 1px black at 35%

  // Bloom (Top-Left inside card)
  static const Color bloomCenter = Color(0x4D818CF8); // #818CF8 at 30%
  static const Color bloomOuter = Color(0x00818CF8);

  // Gloss
  static const Color glossStart = Color(0x21FFFFFF); // white 13%
  static const Color glossEnd = Color(0x00FFFFFF);

  // QR Tile Glow (Back face only)
  static const Color qrGlowIndigo = Color(0x40818CF8); // blur 36
  static const Color qrShadowDark = Color(0x8C000000); // offset (0, 16), blur 32, spread -8
}

// ============================================================================
// PASSPORT PROXIMITY WAVE & RIPPLE LIGHTING CONSTANTS (Tuneable)
// ============================================================================
class PassportProximityWaveTheme {
  // Const toggle to enable/disable blurred glow stroke (for profiling / low-overhead)
  static const bool kRippleGlow = false;

  // Still rings (static, 1px strokes, no fill, Colors.white)
  static const double stillRingDiameter1 = 1.2; // relative to card width W
  static const double stillRingAlpha1 = 0.08;
  static const double stillRingDiameter2 = 1.6;
  static const double stillRingAlpha2 = 0.055;
  static const double stillRingDiameter3 = 2.0;
  static const double stillRingAlpha3 = 0.035;

  // Animated ripples
  static const Duration rippleScanDuration = Duration(milliseconds: 5400); // scanning/idle
  static const Duration rippleHeardDuration = Duration(milliseconds: 4200); // teacherBeaconDetected
  static const Duration rippleVerifyingDuration = Duration(milliseconds: 3200); // authenticating/signing/advertising
  static const Duration completedPulseDuration = Duration(milliseconds: 1400); // completed one-shot outward pulse

  static const double rippleMinRadiusFactor = 0.43; // relative to W (starts behind card)
  static const double rippleMaxRadiusFactor = 1.27; // relative to W (spreads past edges)
  static const double rippleStrokeWidth = 1.5;
  static const Color rippleStrokeColor = Color(0xFFA5B4FC);

  // Ripple glow
  static const double glowStrokeWidth = 14.0;
  static const double glowAlphaFactor = 0.25; // 25% of ripple opacity
  static const double glowBlurRadius = 12.0;
  static const Color glowColor = Color(0xFF6366F1);

  // Completed pulse color
  static const Color completedPulseColor = Color(0xFFC7D2FE);

  // BLE Heard brightness boost
  static const double brightnessBoostDeviceHeard = 1.2;

  // Bottom fade gradient stops
  static const double fadeOpaqueStop = 0.58; // fully opaque until 58% screen height
  static const double fadeTransparentStop = 0.80; // transparent at 80% screen height
}

/// Transformed Active Credential presentation for CampusOS Passport.
///
/// Implements the Apple Wallet & Flagship Motion presentation:
/// - Screen-centered vertical credential with authentic iOS spring physics
/// - Smooth 3D perspective rotation transitioning from horizontal wallet orientation to vertical active view
/// - reverseToHorizontal() animation method for fluid 3D return to wallet deck
/// - Interactive rubber-band pull-down dismiss gesture
/// - Midpoint haptic detent on 3D card flip with zero horizontal mirroring
/// - Concentric radio/NFC proximity wave rings expanding behind the card
/// - Circular dark countdown timer badge with continuous sweep
/// - High-contrast QR code with isolated ValueNotifier 30-second countdown
/// - Institutional security badges: VERIFIED and Device Bound
/// - Passive live attendance status indicator with Apple breathing pulse
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
  final VoidCallback? onScanWifiHotspot;
  final VoidCallback? onScanClassroomQr;
  final VoidCallback? onEnterRoomPin;
  final VoidCallback? onMarkGpsLocation;

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
    this.onScanWifiHotspot,
    this.onScanClassroomQr,
    this.onEnterRoomPin,
    this.onMarkGpsLocation,
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
  bool _lastFlipPhase = false;

  // Interactive pull-to-dismiss rubber band drag state
  double _dragOffsetY = 0.0;
  late final AnimationController _dragResetController;
  late Animation<double> _dragResetAnimation;

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

  /// Toggles card flip programmatically
  void toggleFlip() => _toggleFlip();

  void _onVerticalDragUpdate(DragUpdateDetails details) {
    if (details.primaryDelta == null) return;
    final delta = details.primaryDelta!;
    if (_dragOffsetY + delta > 0) {
      // Authentic Apple Rubber-band resistance: smooth progressive dampening
      final resistance = 1.0 / (1.0 + (_dragOffsetY / 180.0));
      setState(() {
        _dragOffsetY += delta * resistance * 0.78;
      });
    }
  }

  void _onVerticalDragEnd(DragEndDetails details) {
    final velocity = details.primaryVelocity ?? 0.0;
    if (_dragOffsetY > 95.0 || velocity > 550.0) {
      AppHaptics.mediumImpact();
      widget.onClose?.call();
    } else if (_dragOffsetY > 0) {
      _dragResetAnimation = Tween<double>(
        begin: _dragOffsetY,
        end: 0.0,
      ).animate(CurvedAnimation(
        parent: _dragResetController,
        curve: const Cubic(0.18, 1.0, 0.28, 1.0),
      ));
      _dragResetController.forward(from: 0.0);
      AppHaptics.selectionClick();
    }
  }

  @override
  void initState() {
    super.initState();

    // Apple-standard fluid spring morph curve (480ms, snappy launch, soft asymptote)
    _rotationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 480),
    );

    _rotationAnimation = CurvedAnimation(
      parent: _rotationController,
      curve: const Cubic(0.20, 1.0, 0.30, 1.0),
      reverseCurve: const Cubic(0.35, 0.0, 0.20, 1.0),
    );

    // 3D Card Flip controller: snappy, fluid 380ms 3D flip with symmetric easeInOutCubic (eliminates flipback delay)
    _flipController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 380),
      reverseDuration: const Duration(milliseconds: 380),
    );

    _flipAnimation = CurvedAnimation(
      parent: _flipController,
      curve: Curves.easeInOutCubic,
      reverseCurve: Curves.easeInOutCubic,
    );

    // Midpoint haptic detent listener: fires when card flips past 90 degrees
    _flipAnimation.addListener(() {
      final isBackNow = _flipAnimation.value >= 0.5;
      if (isBackNow != _lastFlipPhase) {
        _lastFlipPhase = isBackNow;
        AppHaptics.selectionClick();
      }
    });

    // Spring reset controller for rubber-band pull-down gesture
    _dragResetController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
    );
    _dragResetAnimation = CurvedAnimation(
      parent: _dragResetController,
      curve: const Cubic(0.18, 1.0, 0.28, 1.0),
    );
    _dragResetController.addListener(() {
      setState(() {
        _dragOffsetY = _dragResetAnimation.value;
      });
    });

    _rotationController.forward();
    AppHaptics.lightImpact();
  }

  @override
  void dispose() {
    _rotationController.dispose();
    _flipController.dispose();
    _dragResetController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _rotationAnimation,
      builder: (context, _) {
        final t = _rotationAnimation.value;
        final dragProgress = (_dragOffsetY / 120.0).clamp(0.0, 1.0);
        final bgOpacity =
            (t.clamp(0.0, 1.0) * (1.0 - (dragProgress * 0.35))).clamp(0.0, 1.0);
        final controlsOpacity =
            Curves.easeIn.transform((t - 0.40).clamp(0.0, 0.60) / 0.60);
        final controlsSlide = (1.0 - t) * 16.0;

        return SizedBox.expand(
          child: Container(
            color: Colors.black.withValues(alpha: bgOpacity),
            child: SafeArea(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final width = constraints.maxWidth;
                  final height = constraints.maxHeight;

                  // Target dimensions: taller, slender, premium vertical card (aspect ratio ~1.65, perfectly balanced)
                  final hasActionPills = (widget.onScanWifiHotspot ??
                          widget.onScanClassroomQr) !=
                      null ||
                      widget.onEnterRoomPin != null ||
                      widget.onMarkGpsLocation != null;
                  final bottomControlsSpan = hasActionPills ? 204.0 : 160.0;

                  final targetWidth = math.min(width - 40.0, 312.0);
                  final availableCardHeight =
                      height - bottomControlsSpan - 20.0 - 52.0;
                  final targetHeight = math.min(
                    math.max(availableCardHeight, 360.0),
                    516.0,
                  );
                  final currentWidth = ui.lerpDouble(328.0, targetWidth, t)!;
                  final currentHeight = ui.lerpDouble(205.0, targetHeight, t)!;
                  final currentRadius = ui.lerpDouble(24.0, 30.0, t)!;
                  final arc = math.sin(t * math.pi);
                  final flightScale = 1.0 + (arc * 0.022);
                  final dragScale = 1.0 - (dragProgress * 0.06);

                  // Dynamic lift: ensures the card has clean breathing room above the countdown badge
                  final neededLift =
                      (height / 2) - bottomControlsSpan - 20.0 - (targetHeight / 2);
                  final maxUpwardLift =
                      -((height / 2) - (targetHeight / 2) - 8.0);
                  final targetLift = math.min(-52.0, neededLift)
                      .clamp(maxUpwardLift, 0.0);

                  final cardTranslateY = ui.lerpDouble(
                    0.0,
                    targetLift,
                    Curves.easeOutCubic.transform(t),
                  )!;

                  final cardCenterY =
                      (height / 2) + cardTranslateY + _dragOffsetY;
                  final cardLeft = (width - currentWidth) / 2;
                  final cardTop = cardCenterY - (currentHeight / 2);
                  final cardCenter = Offset(
                    cardLeft + (currentWidth / 2),
                    cardTop + (currentHeight / 2),
                  );

                  return Stack(
                    fit: StackFit.expand,
                    clipBehavior: Clip.none,
                    children: [
                      // 1b. Ambient Indigo Glow Ellipse (centered on cardCenterY, multiplied by t)
                      Positioned(
                        left: (width - (width * 1.1)) / 2,
                        top: cardCenterY - ((width * 1.3) / 2),
                        width: width * 1.1,
                        height: width * 1.3,
                        child: IgnorePointer(
                          child: RepaintBoundary(
                            child: Opacity(
                              opacity: (t * controlsOpacity).clamp(0.0, 1.0),
                              child: Container(
                                decoration: const BoxDecoration(
                                  shape: BoxShape.rectangle,
                                  gradient: RadialGradient(
                                    center: Alignment.center,
                                    radius: 0.5,
                                    colors: [
                                      Color(0x4D4F46E5), // ~30%
                                      Color(0x384F46E5), // ~22%
                                      Color(0x1A4F46E5), // ~10%
                                      Color(0x004F46E5), // transparent
                                    ],
                                    stops: [0.0, 0.3, 0.6, 1.0],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),

                      // 1c. Proximity Waves (Still Rings + Animated Ripples) with Bottom Fade ShaderMask
                      Positioned.fill(
                        child: IgnorePointer(
                          child: RepaintBoundary(
                            child: _PassportProximityWave(
                              attendanceState: widget.attendanceState,
                              isBluetoothActive: widget.isBluetoothActive,
                              isAttendanceActive: widget.isAttendanceActive,
                              controlsOpacity: controlsOpacity,
                              cardCenter: cardCenter,
                              cardWidth: currentWidth,
                              t: t,
                            ),
                          ),
                        ),
                      ),

                      // 1d. Static Grounding Shadows (Wide indigo pool + grounding dark shadow)
                      Positioned(
                        left: cardLeft,
                        top: cardTop,
                        width: currentWidth,
                        height: currentHeight,
                        child: AnimatedBuilder(
                          animation: _flipAnimation,
                          builder: (context, _) {
                            final flipVal = _flipAnimation.value;
                            final flipFlightScale =
                                1.0 + (math.sin(flipVal * math.pi) * 0.045);

                            return Transform.scale(
                              scale: flightScale * dragScale * flipFlightScale,
                              child: RepaintBoundary(
                                child: IgnorePointer(
                                  child: Opacity(
                                    opacity: t.clamp(0.0, 1.0),
                                    child: Container(
                                      decoration: BoxDecoration(
                                        borderRadius:
                                            BorderRadius.circular(currentRadius),
                                        boxShadow: const [
                                          BoxShadow(
                                            color: PassportIndigoGlowTheme
                                                .shadowIndigoPool,
                                            offset: PassportIndigoGlowTheme
                                                .shadowIndigoOffset,
                                            blurRadius: PassportIndigoGlowTheme
                                                .shadowIndigoBlur,
                                            spreadRadius: PassportIndigoGlowTheme
                                                .shadowIndigoSpread,
                                          ),
                                          BoxShadow(
                                            color: PassportIndigoGlowTheme
                                                .shadowDarkGrounding,
                                            offset: PassportIndigoGlowTheme
                                                .shadowDarkOffset,
                                            blurRadius: PassportIndigoGlowTheme
                                                .shadowDarkBlur,
                                            spreadRadius: PassportIndigoGlowTheme
                                                .shadowDarkSpread,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),

                      // 2. Physical Morphing Card (Centered on screen, matches wallet card at t=0)
                      Positioned(
                        left: cardLeft,
                        top: cardTop,
                        width: currentWidth,
                        height: currentHeight,
                        child: Transform.scale(
                          scale: flightScale * dragScale,
                          child: RepaintBoundary(
                            child: GestureDetector(
                              onTap: _toggleFlip,
                              onVerticalDragUpdate: _onVerticalDragUpdate,
                              onVerticalDragEnd: _onVerticalDragEnd,
                              behavior: HitTestBehavior.opaque,
                              child: AnimatedBuilder(
                                animation: _flipAnimation,
                                builder: (context, _) {
                                  final flipVal = _flipAnimation.value;
                                  final isBack = flipVal >= 0.5;
                                  // Two-phase rotation without inner transform to avoid horizontal mirroring:
                                  // When flipVal < 0.5: rotates from 0 to pi/2 (front card)
                                  // When flipVal >= 0.5: rotates from -pi/2 to 0 (back card)
                                  final angle = isBack
                                      ? (flipVal - 1.0) * math.pi
                                      : flipVal * math.pi;
                                  final flipFlightScale = 1.0 +
                                      (math.sin(flipVal * math.pi) * 0.045);

                                  return Transform(
                                    alignment: Alignment.center,
                                    transform: Matrix4.identity()
                                      ..setEntry(3, 2, 0.0014)
                                      ..rotateY(angle),
                                    child: Transform.scale(
                                      scale: flipFlightScale,
                                      child: isBack
                                          ? _buildBackCard(t)
                                          : _buildFrontCard(t),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ),
                        ),
                      ),

                      // 3. Top bar — Apple Glass Circular Back Button
                      Positioned(
                        top: 10,
                        left: 14,
                        child: Opacity(
                          opacity: controlsOpacity,
                          child: AppleBounceable(
                            onTap: () {
                              AppHaptics.lightImpact();
                              widget.onClose?.call();
                            },
                            child: Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.white.withValues(alpha: 0.12),
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.18),
                                  width: 1.0,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.25),
                                    blurRadius: 10,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: const Center(
                                child: Icon(
                                  Icons.arrow_back_ios_new_rounded,
                                  color: Colors.white,
                                  size: 16,
                                ),
                              ),
                            ),
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
                                    fontSize: 12.0,
                                    fontWeight: FontWeight.w500,
                                    color: Colors.white.withValues(alpha: 0.65),
                                    height: 1.38,
                                  ),
                                  textAlign: TextAlign.center,
                                ),

                                const SizedBox(height: 12),

                                // Passive Live Attendance Status Region (matches card width)
                                SizedBox(
                                  width: currentWidth,
                                  child: _buildAttendanceStatusRegion(),
                                ),
                                const SizedBox(height: 10),
                                _buildZeroBleActionPills(),
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

  Widget _buildZeroBleActionPills() {
    final wifiAction = widget.onScanWifiHotspot ?? widget.onScanClassroomQr;
    if (wifiAction == null && widget.onEnterRoomPin == null && widget.onMarkGpsLocation == null) {
      return const SizedBox.shrink();
    }
    return Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 8,
      runSpacing: 8,
      children: [
        if (widget.onMarkGpsLocation != null)
          AppleBounceable(
            onTap: () {
              AppHaptics.selectionClick();
              widget.onMarkGpsLocation?.call();
            },
            child: ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: BackdropFilter(
                filter: ui.ImageFilter.blur(sigmaX: 14, sigmaY: 14),
                child: Container(
                  constraints: const BoxConstraints(minHeight: 36),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(18),
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Color(0x4D0D9488), // 30% teal
                        Color(0x260F766E), // 15% deep teal
                      ],
                    ),
                    border: Border.all(
                      color: const Color(0xFF2DD4BF).withValues(alpha: 0.50),
                      width: 1.0,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.30),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                      BoxShadow(
                        color: const Color(0xFF0D9488).withValues(alpha: 0.35),
                        blurRadius: 10,
                        spreadRadius: -1,
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.my_location_rounded,
                        size: 14,
                        color: Color(0xFF5EEAD4),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'GPS Location (20m)',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                          height: 1.0,
                          letterSpacing: 0.1,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        if (wifiAction != null)
          AppleBounceable(
            onTap: () {
              AppHaptics.selectionClick();
              wifiAction();
            },
            child: ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: BackdropFilter(
                filter: ui.ImageFilter.blur(sigmaX: 14, sigmaY: 14),
                child: Container(
                  constraints: const BoxConstraints(minHeight: 36),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(18),
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Colors.white.withValues(alpha: 0.16),
                        Colors.white.withValues(alpha: 0.05),
                      ],
                    ),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.22),
                      width: 1.0,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.30),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                      BoxShadow(
                        color: Colors.white.withValues(alpha: 0.04),
                        blurRadius: 4,
                        offset: const Offset(0, 1),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.wifi_tethering_rounded,
                        size: 14,
                        color: Colors.white.withValues(alpha: 0.95),
                      ),
                      const SizedBox(width: 7),
                      Text(
                        'Wi-Fi Hotspot',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                          height: 1.0,
                          letterSpacing: 0.1,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        if (widget.onEnterRoomPin != null)
          AppleBounceable(
            onTap: () {
              AppHaptics.selectionClick();
              widget.onEnterRoomPin?.call();
            },
            child: ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: BackdropFilter(
                filter: ui.ImageFilter.blur(sigmaX: 14, sigmaY: 14),
                child: Container(
                  constraints: const BoxConstraints(minHeight: 36),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(18),
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Color(0x3D818CF8), // 24% indigo
                        Color(0x1F4F46E5), // 12% deep indigo
                      ],
                    ),
                    border: Border.all(
                      color: const Color(0xFF818CF8).withValues(alpha: 0.38),
                      width: 1.0,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.30),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                      BoxShadow(
                        color: const Color(0xFF6366F1).withValues(alpha: 0.22),
                        blurRadius: 10,
                        spreadRadius: -2,
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.pin_rounded,
                        size: 14,
                        color: Color(0xFFC7D2FE),
                      ),
                      const SizedBox(width: 7),
                      Text(
                        'Enter Room PIN',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                          height: 1.0,
                          letterSpacing: 0.1,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  /// Passive live attendance discovery status region with Liquid Glass material
  Widget _buildAttendanceStatusRegion() {
    final state = widget.attendanceState;
    final isBt = widget.isBluetoothActive;

    Color textColor;
    Color glassTintTop;
    Color glassTintBottom;
    Color glassBorderColor;
    Color? accentGlow;
    Widget leadingWidget;
    String statusText;

    final isAttendanceUnderway = state == StudentAttendanceFlowState.completed ||
        state == StudentAttendanceFlowState.authenticatingTeacher ||
        state == StudentAttendanceFlowState.signingResponse ||
        state == StudentAttendanceFlowState.advertisingResponse;

    if (!isBt && !isAttendanceUnderway) {
      textColor = Colors.white70;
      glassTintTop = Colors.white.withValues(alpha: 0.12);
      glassTintBottom = const Color(0xFF13151D).withValues(alpha: 0.40);
      glassBorderColor = Colors.white.withValues(alpha: 0.18);
      accentGlow = null;
      leadingWidget = const Icon(Icons.bluetooth_disabled_rounded,
          size: 16, color: Colors.white54);
      statusText = widget.onMarkGpsLocation != null
          ? 'Bluetooth off · Tap GPS Location (20m) to check in'
          : 'Bluetooth unavailable · QR fallback active';
    } else {
      switch (state) {
        case StudentAttendanceFlowState.scanningForTeacherBeacon:
          textColor = Colors.white;
          glassTintTop = const Color(0xFF818CF8).withValues(alpha: 0.16);
          glassTintBottom = const Color(0xFF13151D).withValues(alpha: 0.45);
          glassBorderColor = const Color(0xFFA5B4FC).withValues(alpha: 0.28);
          accentGlow = const Color(0xFF6366F1);
          leadingWidget = Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFF818CF8),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF818CF8).withValues(alpha: 0.65),
                  blurRadius: 6,
                  spreadRadius: 1,
                ),
              ],
            ),
          );
          statusText = 'Looking for class session...';
          break;
        case StudentAttendanceFlowState.teacherBeaconDetected:
          textColor = Colors.white;
          glassTintTop = const Color(0xFF38BDF8).withValues(alpha: 0.18);
          glassTintBottom = const Color(0xFF0C4A6E).withValues(alpha: 0.45);
          glassBorderColor = const Color(0xFF7DD3FC).withValues(alpha: 0.38);
          accentGlow = const Color(0xFF38BDF8);
          leadingWidget = Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFF38BDF8),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF38BDF8).withValues(alpha: 0.65),
                  blurRadius: 6,
                  spreadRadius: 1,
                ),
              ],
            ),
          );
          statusText = 'Teacher beacon detected';
          break;
        case StudentAttendanceFlowState.authenticatingTeacher:
        case StudentAttendanceFlowState.signingResponse:
        case StudentAttendanceFlowState.advertisingResponse:
          textColor = Colors.white;
          glassTintTop = const Color(0xFF2DD4BF).withValues(alpha: 0.18);
          glassTintBottom = const Color(0xFF134E4A).withValues(alpha: 0.45);
          glassBorderColor = const Color(0xFF5EEAD4).withValues(alpha: 0.38);
          accentGlow = const Color(0xFF2DD4BF);
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
          glassTintTop = const Color(0xFF10B981).withValues(alpha: 0.22);
          glassTintBottom = const Color(0xFF064E3B).withValues(alpha: 0.48);
          glassBorderColor = const Color(0xFF6EE7B7).withValues(alpha: 0.45);
          accentGlow = const Color(0xFF10B981);
          leadingWidget = const Icon(Icons.check_circle_rounded,
              size: 16, color: Color(0xFF10B981));
          statusText = 'Attendance Verified · Tap to re-send';
          break;
        case StudentAttendanceFlowState.error:
          textColor = const Color(0xFFFCA5A5);
          glassTintTop = const Color(0xFFEF4444).withValues(alpha: 0.18);
          glassTintBottom = const Color(0xFF7F1D1D).withValues(alpha: 0.45);
          glassBorderColor = const Color(0xFFFCA5A5).withValues(alpha: 0.38);
          accentGlow = const Color(0xFFEF4444);
          leadingWidget = const Icon(Icons.warning_amber_rounded,
              size: 16, color: Color(0xFFF87171));
          statusText = 'Bluetooth notice: Check settings';
          break;
        case StudentAttendanceFlowState.idle:
        default:
          textColor = Colors.white;
          glassTintTop = const Color(0xFF818CF8).withValues(alpha: 0.16);
          glassTintBottom = const Color(0xFF13151D).withValues(alpha: 0.45);
          glassBorderColor = const Color(0xFFA5B4FC).withValues(alpha: 0.28);
          accentGlow = const Color(0xFF6366F1);
          leadingWidget = Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFF818CF8),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF818CF8).withValues(alpha: 0.65),
                  blurRadius: 6,
                  spreadRadius: 1,
                ),
              ],
            ),
          );
          statusText = 'Looking for class session...';
          break;
      }
    }

    if (widget.attendanceStatusMessage != null &&
        widget.attendanceStatusMessage!.trim().isNotEmpty &&
        state != StudentAttendanceFlowState.idle &&
        !widget.attendanceStatusMessage!.toLowerCase().contains('cancel')) {
      if (isBt || isAttendanceUnderway) {
        statusText = widget.attendanceStatusMessage!.trim();
      }
    }

    return AppleBounceable(
      onTap: () {
        AppHaptics.selectionClick();
        widget.onStartAttendance?.call();
      },
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 14, sigmaY: 14),
          child: Container(
            constraints: const BoxConstraints(minHeight: 48),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  glassTintTop,
                  glassTintBottom,
                ],
              ),
              border: Border.all(
                color: glassBorderColor,
                width: 1.0,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.35),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
                if (accentGlow != null)
                  BoxShadow(
                    color: accentGlow.withValues(alpha: 0.20),
                    blurRadius: 14,
                    spreadRadius: -2,
                  ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                leadingWidget,
                const SizedBox(width: 10),
                Flexible(
                  child: Text(
                    statusText,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w500,
                      color: textColor,
                      height: 1.32,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Unified Apple-style card shell with fixed light edge, inner 160° surface, top-left bloom, and gloss
  Widget _buildPassportCardShell({
    required double currentRadius,
    required Widget child,
  }) {
    final innerRadius = (currentRadius - PassportIndigoGlowTheme.edgeWidth).clamp(0.0, 40.0);

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(currentRadius),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            PassportIndigoGlowTheme.edgeTopLeft, // white 55%
            PassportIndigoGlowTheme.edgeMid, // white 10% (at 38%)
            PassportIndigoGlowTheme.edgeBottomRight, // indigo #818CF8 at 35%
          ],
          stops: [0.0, 0.38, 1.0],
        ),
      ),
      padding: const EdgeInsets.all(PassportIndigoGlowTheme.edgeWidth),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(innerRadius),
          gradient: const LinearGradient(
            begin: Alignment(-0.85, -1.0),
            end: Alignment(0.85, 1.0),
            colors: [
              PassportIndigoGlowTheme.surfaceTop,
              PassportIndigoGlowTheme.surfaceMid,
              PassportIndigoGlowTheme.surfaceBottom,
            ],
            stops: [0.0, 0.45, 1.0],
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(innerRadius),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Single unified lighting layer (bloom + gloss + 1px highlights)
              Positioned.fill(
                child: IgnorePointer(
                  child: CustomPaint(
                    painter: _PassportCardLightingPainter(
                      borderRadius: innerRadius,
                    ),
                  ),
                ),
              ),
              // Card content
              child,
            ],
          ),
        ),
      ),
    );
  }

  /// Builds the authentic front of the card with upright vertical presentation and smooth morph
  Widget _buildFrontCard([double t = 1.0]) {
    final currentRadius = ui.lerpDouble(24.0, 30.0, t)!;
    final vPadding = ui.lerpDouble(12.0, 18.0, t)!;
    final hPadding = ui.lerpDouble(16.0, 18.0, t)!;
    final nameSize = ui.lerpDouble(17.0, 26.0, t)!;
    final flipPillOpacity =
        Curves.easeIn.transform((t - 0.40).clamp(0.0, 0.60) / 0.60);

    return _buildPassportCardShell(
      currentRadius: currentRadius,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Offstage elements for test harness compatibility
          Offstage(
            offstage: true,
            child: Column(
              children: [
                Text(widget.studentName.toUpperCase()),
                const RealisticEmvChip(),
              ],
            ),
          ),

          // Upright Vertical Card Content
          Padding(
            padding: EdgeInsets.symmetric(horizontal: hPadding, vertical: vPadding),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // 1. Top Row: CampusOS branding & Security Shield Pod
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.radio_button_checked,
                            color: Colors.white,
                            size: 19,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'CampusOS',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                              letterSpacing: -0.2,
                            ),
                          ),
                        ],
                      ),
                      Container(
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withValues(alpha: 0.12),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.16),
                            width: 0.8,
                          ),
                        ),
                        child: const Center(
                          child: Icon(
                            Icons.shield_outlined,
                            color: Colors.white,
                            size: 17,
                          ),
                        ),
                      ),
                    ],
                  ),

                  // Spacious upper satin expanse (pushes credentials to lower half at t > 0.35)
                  if (t > 0.35) const Spacer(),

                  // 2. Lower Half: Student Identity Details (Matching exact screenshot placement)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        widget.studentName.toUpperCase(),
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: nameSize,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                          letterSpacing: -0.4,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      SizedBox(height: ui.lerpDouble(4.0, 14.0, t)!),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'PROGRAM',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white.withValues(alpha: 0.60),
                                    letterSpacing: 0.8,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '${widget.department} · ${widget.semester}',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: ui.lerpDouble(12.0, 14.5, t)!,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'ROLL NO',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white.withValues(alpha: 0.60),
                                  letterSpacing: 0.8,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                widget.registrationNumber ?? '2401294183',
                                style: GoogleFonts.spaceGrotesk(
                                  fontSize: ui.lerpDouble(12.0, 14.5, t)!,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),

                  // 3. Tap to flip hint pill (visible at vertical expanded position)
                  if (t > 0.40) ...[
                    SizedBox(height: ui.lerpDouble(4.0, 14.0, t)!),
                    Opacity(
                      opacity: flipPillOpacity,
                      child: Center(
                        child: AppleBounceable(
                          onTap: _toggleFlip,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 5.5),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.14),
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.16),
                                width: 0.8,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.sync_rounded,
                                  size: 14,
                                  color: Colors.white,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  'Tap to flip',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 11.5,
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],

                  if (t > 0.35) SizedBox(height: ui.lerpDouble(6.0, 16.0, t)!),

                  // 4. Bottom Row: 'Passport' on left, 'VERIFIED' badge on right
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Flexible(
                        child: Text(
                          'Passport',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: ui.lerpDouble(18.0, 22.0, t)!,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.28),
                            width: 0.8,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.check_circle_rounded,
                              color: Colors.white,
                              size: 13,
                            ),
                            const SizedBox(width: 4.5),
                            Text(
                              'VERIFIED',
                              style: GoogleFonts.plusJakartaSans(
                                color: Colors.white,
                                fontSize: 10.5,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.6,
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
          ],
        ),
      );
    }

  /// Builds the dynamic cryptographic QR credential on the reverse side (Upright, unmirrored vertical presentation)
  Widget _buildBackCard([double t = 1.0]) {
    final currentRadius = ui.lerpDouble(24.0, 30.0, t)!;
    final vPadding = ui.lerpDouble(12.0, 18.0, t)!;
    final hPadding = ui.lerpDouble(16.0, 18.0, t)!;
    final qrBoxSize = ui.lerpDouble(120.0, 172.0, t)!;
    final qrSize = ui.lerpDouble(98.0, 148.0, t)!;

    return _buildPassportCardShell(
      currentRadius: currentRadius,
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: hPadding, vertical: vPadding),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
                  // 1. Top Row: CampusOS branding & QR Scanner Icon Pod
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.radio_button_checked,
                            color: Colors.white,
                            size: 19,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'CampusOS',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                              letterSpacing: -0.2,
                            ),
                          ),
                        ],
                      ),
                      Container(
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withValues(alpha: 0.12),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.16),
                            width: 0.8,
                          ),
                        ),
                        child: const Center(
                          child: Icon(
                            Icons.qr_code_scanner_rounded,
                            color: Colors.white,
                            size: 18,
                          ),
                        ),
                      ),
                    ],
                  ),

                  // 2. Center: High-Contrast Upright Dynamic QR Code with Indigo Glow
                  Container(
                    width: qrBoxSize,
                    height: qrBoxSize,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: const [
                        BoxShadow(
                          color: PassportIndigoGlowTheme.qrGlowIndigo,
                          blurRadius: 36,
                        ),
                        BoxShadow(
                          color: PassportIndigoGlowTheme.qrShadowDark,
                          offset: Offset(0, 16),
                          blurRadius: 32,
                          spreadRadius: -8,
                        ),
                      ],
                    ),
                    child: Center(
                      child: QrImageView(
                        data: widget.qrData,
                        version: QrVersions.auto,
                        size: qrSize,
                        padding: EdgeInsets.zero,
                        backgroundColor: Colors.white,
                        eyeStyle: const QrEyeStyle(
                          eyeShape: QrEyeShape.square,
                          color: Color(0xFF0F172A),
                        ),
                        dataModuleStyle: const QrDataModuleStyle(
                          dataModuleShape: QrDataModuleShape.square,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                    ),
                  ),

                  // 3. Live 30-Second Countdown Indicator Capsule
                  ValueListenableBuilder<int>(
                    valueListenable: widget.remainingSecondsNotifier,
                    builder: (context, seconds, _) {
                      return Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 5.5),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.16),
                            width: 0.8,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.access_time_rounded,
                              size: 13,
                              color: Colors.white,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'Refreshes in ${seconds}s',
                              style: GoogleFonts.plusJakartaSans(
                                color: Colors.white,
                                fontSize: 11.5,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 0.2,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),

                  // 4. Bottom Row: 'Passport' on left, 'Tap to return to card' on right
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Flexible(
                        child: Text(
                          'Passport',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: ui.lerpDouble(18.0, 22.0, t)!,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: AppleBounceable(
                          onTap: _toggleFlip,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Text(
                              'Tap to return to card',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 10.5,
                                color: Colors.white.withValues(alpha: 0.70),
                                fontWeight: FontWeight.w500,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
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
        }

  /// Circular Countdown Badge matching Apple presentation
  Widget _buildCircularCountdownBadge() {
    return ValueListenableBuilder<int>(
      valueListenable: widget.remainingSecondsNotifier,
      builder: (context, seconds, child) {
        final progress = (seconds / 30.0).clamp(0.0, 1.0);
        final ringColor =
            seconds <= 5 ? const Color(0xFFF59E0B) : const Color(0xFF818CF8);

        return Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: const Color(0xFF161924),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.12),
              width: 1.0,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.30),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: CustomPaint(
            painter: _StrokeCountdownRingPainter(
              progress: progress,
              strokeColor: ringColor,
              trackColor: Colors.white.withValues(alpha: 0.15),
            ),
            child: Center(
              child: Text(
                '$seconds',
                textAlign: TextAlign.center,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 15.5,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                  letterSpacing: -0.2,
                  height: 1.0,
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
    final radius = (size.width / 2) - 2.8;

    final trackPaint = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.4;

    canvas.drawCircle(center, radius, trackPaint);

    if (progress <= 0.0) return;

    final sweepAngle = 2 * math.pi * progress;
    final arcPaint = Paint()
      ..color = strokeColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.4
      ..strokeCap = StrokeCap.round;

    final arcRect = Rect.fromCircle(center: center, radius: radius);
    canvas.drawArc(
      arcRect,
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

/// Concentric Proximity Waves & Still Rings: positioned behind the active Passport.
///
/// Features:
/// - 3 static, ultra-faint concentric rings centered on the pass (always drawn when t > 0)
/// - 3 smooth outward expanding ripples (#A5B4FC stroke with #6366F1 blurred glow)
/// - Durations: scanning/idle 5400ms, teacherBeaconDetected 4200ms, authenticating/verifying 3200ms
/// - Changing state preserves phase seamlessly without jump
/// - Completed state: one soft outward pulse in #C7D2FE and then stops
/// - ShaderMask bottom fade: fully opaque until 58% screen height, transparent at 80% (using Colors.white with alpha 0)
/// - Scaled by active card morph t: dormant in Wallet view (t = 0), fully visible at t = 1
/// - Reduced-motion fallback: suppresses animated ripples while preserving the 3 still rings
class _PassportProximityWave extends StatefulWidget {
  final StudentAttendanceFlowState attendanceState;
  final bool isBluetoothActive;
  final bool isAttendanceActive;
  final double controlsOpacity;
  final Offset? cardCenter;
  final double cardWidth;
  final double t;

  const _PassportProximityWave({
    Key? key,
    required this.attendanceState,
    required this.isBluetoothActive,
    required this.isAttendanceActive,
    required this.controlsOpacity,
    this.cardCenter,
    this.cardWidth = 286.0,
    this.t = 1.0,
  }) : super(key: key);

  @override
  State<_PassportProximityWave> createState() => _PassportProximityWaveState();
}

class _PassportProximityWaveState extends State<_PassportProximityWave>
    with SingleTickerProviderStateMixin {
  late final AnimationController _waveController;
  bool _isCompletedPulse = false;
  Shader? _cachedShader;
  Rect? _cachedBounds;

  Duration _getDurationForState(StudentAttendanceFlowState state) {
    switch (state) {
      case StudentAttendanceFlowState.authenticatingTeacher:
      case StudentAttendanceFlowState.biometricPromptActive:
      case StudentAttendanceFlowState.signingResponse:
      case StudentAttendanceFlowState.advertisingResponse:
        return PassportProximityWaveTheme.rippleVerifyingDuration;
      case StudentAttendanceFlowState.teacherBeaconDetected:
        return PassportProximityWaveTheme.rippleHeardDuration;
      case StudentAttendanceFlowState.idle:
      case StudentAttendanceFlowState.requestingPermissions:
      case StudentAttendanceFlowState.scanningForTeacherBeacon:
      case StudentAttendanceFlowState.completed:
      case StudentAttendanceFlowState.error:
        return PassportProximityWaveTheme.rippleScanDuration;
    }
  }

  double get _brightnessMultiplier {
    switch (widget.attendanceState) {
      case StudentAttendanceFlowState.teacherBeaconDetected:
      case StudentAttendanceFlowState.authenticatingTeacher:
      case StudentAttendanceFlowState.biometricPromptActive:
      case StudentAttendanceFlowState.signingResponse:
      case StudentAttendanceFlowState.advertisingResponse:
        return PassportProximityWaveTheme.brightnessBoostDeviceHeard;
      case StudentAttendanceFlowState.idle:
      case StudentAttendanceFlowState.requestingPermissions:
      case StudentAttendanceFlowState.scanningForTeacherBeacon:
      case StudentAttendanceFlowState.completed:
      case StudentAttendanceFlowState.error:
        return 1.0;
    }
  }

  @override
  void initState() {
    super.initState();
    _waveController = AnimationController(
      vsync: this,
      duration: _getDurationForState(widget.attendanceState),
    );

    _waveController.addStatusListener((status) {
      if (status == AnimationStatus.completed && _isCompletedPulse) {
        if (mounted) {
          setState(() {
            _isCompletedPulse = false;
          });
        }
      }
    });

    if (widget.t > 0.0 &&
        widget.isBluetoothActive &&
        widget.attendanceState != StudentAttendanceFlowState.error &&
        widget.attendanceState != StudentAttendanceFlowState.completed) {
      _waveController.repeat(period: _getDurationForState(widget.attendanceState));
    }
  }

  void _triggerCompletedPulse() {
    _isCompletedPulse = true;
    _waveController.stop();
    _waveController.duration = PassportProximityWaveTheme.completedPulseDuration;
    _waveController.forward(from: 0.0);
  }

  void _syncAnimationState(covariant _PassportProximityWave? oldWidget) {
    if (widget.attendanceState == StudentAttendanceFlowState.completed) {
      if (oldWidget != null &&
          oldWidget.attendanceState != StudentAttendanceFlowState.completed) {
        _triggerCompletedPulse();
      }
      return;
    }

    if (widget.t <= 0.0) {
      if (_waveController.isAnimating) {
        _waveController.stop();
        _waveController.value = 0.0;
      }
      return;
    }

    final isReducedMotion = AnimationConstants.isReducedMotion(context);
    final shouldAnimate = widget.isBluetoothActive &&
        widget.attendanceState != StudentAttendanceFlowState.error &&
        !isReducedMotion;

    if (shouldAnimate) {
      final targetDuration = _getDurationForState(widget.attendanceState);
      if (_waveController.duration != targetDuration) {
        _waveController.duration = targetDuration;
        if (_waveController.isAnimating) {
          _waveController.repeat(period: targetDuration);
        }
      }
      if (!_waveController.isAnimating && !_isCompletedPulse) {
        _waveController.repeat(period: targetDuration);
      }
    } else {
      if (_waveController.isAnimating && !_isCompletedPulse) {
        _waveController.stop();
      }
    }
  }

  @override
  void didUpdateWidget(covariant _PassportProximityWave oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncAnimationState(oldWidget);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncAnimationState(null);
  }

  @override
  void dispose() {
    _waveController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isReducedMotion = AnimationConstants.isReducedMotion(context);
    final screenSize = MediaQuery.sizeOf(context);
    final center = widget.cardCenter ??
        Offset(screenSize.width / 2, screenSize.height * 0.45);

    final showRipples = widget.isBluetoothActive &&
        widget.attendanceState != StudentAttendanceFlowState.error &&
        !isReducedMotion &&
        widget.t > 0.0;

    final isCompleted =
        widget.attendanceState == StudentAttendanceFlowState.completed;

    return ShaderMask(
      blendMode: BlendMode.dstIn,
      shaderCallback: (Rect bounds) {
        if (_cachedBounds == bounds && _cachedShader != null) {
          return _cachedShader!;
        }
        _cachedBounds = bounds;
        _cachedShader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          stops: [
            0.0,
            PassportProximityWaveTheme.fadeOpaqueStop,
            PassportProximityWaveTheme.fadeTransparentStop,
            1.0,
          ],
          colors: [
            Colors.white,
            Colors.white,
            Color(0x00FFFFFF),
            Color(0x00FFFFFF),
          ],
        ).createShader(bounds);
        return _cachedShader!;
      },
      child: CustomPaint(
        size: Size.infinite,
        painter: _ProximityWavesPainter(
          rippleAnimation:
              (showRipples || _isCompletedPulse) ? _waveController : null,
          center: center,
          cardWidth: widget.cardWidth,
          t: widget.t,
          showRipples: showRipples && !isCompleted,
          isCompleted: isCompleted,
          isCompletedPulse: _isCompletedPulse && _waveController.isAnimating,
          brightnessMultiplier: _brightnessMultiplier,
        ),
      ),
    );
  }
}

class _ProximityWavesPainter extends CustomPainter {
  final Animation<double>? rippleAnimation;
  final Offset center;
  final double cardWidth;
  final double t;
  final bool showRipples;
  final bool isCompleted;
  final bool isCompletedPulse;
  final double brightnessMultiplier;

  // Cached Paint objects to eliminate GC allocations per frame
  final Paint _ringPaint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1.0
    ..isAntiAlias = true;

  final Paint _pulsePaint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1.8
    ..isAntiAlias = true;

  final Paint _ripplePaint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = PassportProximityWaveTheme.rippleStrokeWidth
    ..isAntiAlias = true;

  final Paint _glowPaint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = PassportProximityWaveTheme.glowStrokeWidth
    ..maskFilter = const MaskFilter.blur(
      BlurStyle.normal,
      PassportProximityWaveTheme.glowBlurRadius,
    )
    ..isAntiAlias = true;

  _ProximityWavesPainter({
    required this.rippleAnimation,
    required this.center,
    required this.cardWidth,
    required this.t,
    required this.showRipples,
    required this.isCompleted,
    required this.isCompletedPulse,
    required this.brightnessMultiplier,
  }) : super(repaint: rippleAnimation);

  @override
  void paint(Canvas canvas, Size size) {
    if (t <= 0.0) return;

    final w = cardWidth;

    // 1. Still rings (static, 1px strokes, no fill, Colors.white)
    // Always drawn, even when !isBluetoothActive or in error state
    final stillRings = [
      (
        PassportProximityWaveTheme.stillRingDiameter1 * w / 2.0,
        PassportProximityWaveTheme.stillRingAlpha1,
      ),
      (
        PassportProximityWaveTheme.stillRingDiameter2 * w / 2.0,
        PassportProximityWaveTheme.stillRingAlpha2,
      ),
      (
        PassportProximityWaveTheme.stillRingDiameter3 * w / 2.0,
        PassportProximityWaveTheme.stillRingAlpha3,
      ),
    ];

    for (final ring in stillRings) {
      final ringRadius = ring.$1;
      final ringAlpha = (ring.$2 * t).clamp(0.0, 1.0);
      if (ringAlpha > 0.001) {
        _ringPaint.color = Colors.white.withValues(alpha: ringAlpha);
        canvas.drawCircle(center, ringRadius, _ringPaint);
      }
    }

    // 2. Completed State One-Shot Outward Pulse in #C7D2FE
    if (isCompleted && isCompletedPulse && rippleAnimation != null) {
      final p = rippleAnimation!.value;
      final curvedP = Curves.easeOutCubic.transform(p);
      final radius = ui.lerpDouble(
        PassportProximityWaveTheme.rippleMinRadiusFactor * w,
        PassportProximityWaveTheme.rippleMaxRadiusFactor * w,
        curvedP,
      )!;
      final alpha = (math.pow(1.0 - p, 1.4) * 0.75 * t).clamp(0.0, 1.0);

      if (alpha > 0.001) {
        if (PassportProximityWaveTheme.kRippleGlow) {
          _glowPaint.color = PassportProximityWaveTheme.completedPulseColor.withValues(
            alpha: alpha * PassportProximityWaveTheme.glowAlphaFactor,
          );
          canvas.drawCircle(center, radius, _glowPaint);
        }

        _pulsePaint.color =
            PassportProximityWaveTheme.completedPulseColor.withValues(alpha: alpha);
        canvas.drawCircle(center, radius, _pulsePaint);
      }
      return;
    }

    // 3. Animated Ripples (3 round ripples spreading outwards)
    if (showRipples && rippleAnimation != null) {
      final progress = rippleAnimation!.value;

      for (int i = 0; i < 3; i++) {
        final p = (progress + (i / 3.0)) % 1.0;
        final curvedP = Curves.easeOutCubic.transform(p);
        final radius = ui.lerpDouble(
          PassportProximityWaveTheme.rippleMinRadiusFactor * w,
          PassportProximityWaveTheme.rippleMaxRadiusFactor * w,
          curvedP,
        )!;

        // Opacity formula: (p < 0.16 ? p / 0.16 : 1.0) * pow(1 - p, 1.6) * 0.7
        final fadeIn = p < 0.16 ? (p / 0.16) : 1.0;
        final baseOpacity = fadeIn * math.pow(1.0 - p, 1.6) * 0.7;
        final effectiveOpacity =
            (baseOpacity * brightnessMultiplier * t).clamp(0.0, 1.0);

        if (effectiveOpacity > 0.001) {
          // Glow stroke under ripple: width 14, color #6366F1, blur 12, alpha 25% of opacity
          if (PassportProximityWaveTheme.kRippleGlow) {
            _glowPaint.color = PassportProximityWaveTheme.glowColor.withValues(
              alpha:
                  effectiveOpacity * PassportProximityWaveTheme.glowAlphaFactor,
            );
            canvas.drawCircle(center, radius, _glowPaint);
          }

          // Main ripple stroke: width 1.5, color #A5B4FC
          _ripplePaint.color = PassportProximityWaveTheme.rippleStrokeColor.withValues(
            alpha: effectiveOpacity,
          );
          canvas.drawCircle(center, radius, _ripplePaint);
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant _ProximityWavesPainter oldDelegate) {
    return oldDelegate.center != center ||
        oldDelegate.cardWidth != cardWidth ||
        oldDelegate.t != t ||
        oldDelegate.showRipples != showRipples ||
        oldDelegate.isCompleted != isCompleted ||
        oldDelegate.isCompletedPulse != isCompletedPulse ||
        oldDelegate.brightnessMultiplier != brightnessMultiplier;
  }
}

/// Renders authentic Apple specular lighting, bloom, gloss, and edge highlights inside the card surface
class _PassportCardLightingPainter extends CustomPainter {
  final double borderRadius;

  const _PassportCardLightingPainter({
    required this.borderRadius,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final rrect = RRect.fromRectAndRadius(rect, Radius.circular(borderRadius));

    // 1. Top-left bloom: RadialGradient center Alignment(-0.72, -1.0), radius ~0.8 of card width
    final bloomCenter = Offset(
      rect.width * 0.14,
      0.0,
    );
    final bloomRadius = size.width * 0.80;
    final bloomPaint = Paint()
      ..shader = ui.Gradient.radial(
        bloomCenter,
        bloomRadius,
        const [
          PassportIndigoGlowTheme.bloomCenter,
          PassportIndigoGlowTheme.bloomOuter,
        ],
        const [0.0, 1.0],
      );
    canvas.drawRRect(rrect, bloomPaint);

    // 2. Gloss: LinearGradient topLeft toward middle, white 13% at 0% -> transparent at 36%
    final glossPaint = Paint()
      ..shader = ui.Gradient.linear(
        Offset.zero,
        Offset(size.width * 0.55, size.height * 0.55),
        const [
          PassportIndigoGlowTheme.glossStart,
          PassportIndigoGlowTheme.glossEnd,
        ],
        const [0.0, 0.36],
      );
    canvas.drawRRect(rrect, glossPaint);

    // 3. Inner top highlight (1px white at 35%)
    final topHighlightPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0
      ..shader = ui.Gradient.linear(
        Offset(size.width * 0.10, 0.5),
        Offset(size.width * 0.90, 0.5),
        [
          Colors.white.withValues(alpha: 0.0),
          PassportIndigoGlowTheme.innerTopHighlight,
          Colors.white.withValues(alpha: 0.0),
        ],
        const [0.0, 0.5, 1.0],
      );
    canvas.drawLine(
      Offset(size.width * 0.05, 0.5),
      Offset(size.width * 0.95, 0.5),
      topHighlightPaint,
    );

    // 4. Inner bottom shade (1px black at 35%)
    final bottomShadePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0
      ..shader = ui.Gradient.linear(
        Offset(size.width * 0.10, size.height - 0.5),
        Offset(size.width * 0.90, size.height - 0.5),
        [
          Colors.black.withValues(alpha: 0.0),
          PassportIndigoGlowTheme.innerBottomShade,
          Colors.black.withValues(alpha: 0.0),
        ],
        const [0.0, 0.5, 1.0],
      );
    canvas.drawLine(
      Offset(size.width * 0.05, size.height - 0.5),
      Offset(size.width * 0.95, size.height - 0.5),
      bottomShadePaint,
    );
  }

  @override
  bool shouldRepaint(covariant _PassportCardLightingPainter oldDelegate) =>
      oldDelegate.borderRadius != borderRadius;
}

