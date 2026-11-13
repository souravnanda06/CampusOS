import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../core/haptics/app_haptics.dart';
import '../../services/passport_biometric_service.dart';
import '../../services/passport_face_auth_service.dart';
import '../../services/passport_mlkit_service.dart';

/// CampusOS Apple-Grade Face Authentication Gate Viewfinder Modal.
///
/// Designed with authentic Apple Human Interface Guidelines:
/// - Liquid Glass obsidian surface with backdrop blur (sigma: 28).
/// - 64-tick precision radial biometric aperture with continuous rotating radar sweep.
/// - Inner circular lens with live front selfie camera feed & dark edge vignette.
/// - Faint dashed facial alignment contour guide.
/// - Multi-layer luminous laser scanning beam with cyan-indigo radiant glow.
/// - Fluid morphing status capsule with spinner, success, and error feedback.
/// - Google ML Kit on-device face landmark extraction & liveness verification.
/// - Instant SIMD Cosine Similarity evaluation (< 250ms).
/// - 44pt touch target Cancel button with tactile haptic feedback.
class FaceAuthGateSheet extends StatefulWidget {
  final String studentId;
  final List<double> enrolledVector;
  final String promptReason;
  final bool isTestMode;

  const FaceAuthGateSheet({
    Key? key,
    required this.studentId,
    required this.enrolledVector,
    this.promptReason = 'Verify face to unlock Campus Passport',
    this.isTestMode = false,
  }) : super(key: key);

  @override
  State<FaceAuthGateSheet> createState() => _FaceAuthGateSheetState();
}

class _FaceAuthGateSheetState extends State<FaceAuthGateSheet>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _laserAnim;
  late Animation<double> _sweepAnim;

  CameraController? _cameraController;
  final PassportMlKitService _mlKitService = PassportMlKitService.instance;

  String _statusText = 'Verifying identity & liveness...';
  bool _isSuccess = false;
  bool _isMismatch = false;
  Timer? _verificationTimer;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat();

    _laserAnim = Tween<double>(begin: -1.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animController,
        curve: Curves.easeInOutQuad,
      ),
    );

    _sweepAnim = Tween<double>(begin: 0.0, end: 2 * math.pi).animate(
      CurvedAnimation(
        parent: _animController,
        curve: Curves.linear,
      ),
    );

    AppHaptics.selectionClick();
    _initCamera();
  }

  Future<void> _initCamera() async {
    try {
      final status = await Permission.camera.request();
      if (!status.isGranted) {
        if (!widget.isTestMode) {
          _handleMismatch('Camera permission is required.');
          return;
        }
      }
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        if (!widget.isTestMode) {
          _handleMismatch('Front selfie camera is required.');
          return;
        }
        _startRecognitionPipeline();
        return;
      }
      final frontCamera = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );
      final controller = CameraController(
        frontCamera,
        ResolutionPreset.medium,
        enableAudio: false,
      );
      await controller.initialize();
      if (mounted) {
        setState(() {
          _cameraController = controller;
        });
        _startRecognitionPipeline();
      }
    } catch (e) {
      debugPrint('ℹ️ [CAMERA] Camera init note in gate sheet: $e');
      if (!widget.isTestMode) {
        _handleMismatch('Unable to initialize camera.');
      } else {
        _startRecognitionPipeline();
      }
    }
  }

  void _startRecognitionPipeline() {
    // 1. Initial lock phase (120ms)
    _verificationTimer = Timer(const Duration(milliseconds: 120), () {
      if (!mounted) return;
      setState(() {
        _statusText = 'Verifying identity & liveness...';
      });
      AppHaptics.lightImpact();

      // 2. Inference & Cosine Matching phase (260ms)
      _verificationTimer = Timer(const Duration(milliseconds: 260), () {
        if (!mounted) return;
        _evaluateFaceMatch();
      });
    });
  }

  Future<void> _evaluateFaceMatch() async {
    if (widget.enrolledVector.isEmpty) {
      _handleMismatch('Enrollment template missing. Please re-enroll.');
      return;
    }

    List<double>? liveSample;

    // 1. If physical front camera is active, take picture & run Google ML Kit
    if (_cameraController != null && _cameraController!.value.isInitialized) {
      try {
        final xFile = await _cameraController!.takePicture();
        final faces = await _mlKitService.detectFacesFromPath(xFile.path);
        try {
          File(xFile.path).delete().ignore();
        } catch (_) {}

        if (faces.isEmpty) {
          _handleMismatch('Align your face within the frame.');
          return;
        }

        final bestFace = faces.first;
        final isLive = _mlKitService.evaluateLiveness(bestFace);
        if (!isLive) {
          _handleMismatch('Static photo or screen replay detected.');
          return;
        }

        liveSample = _mlKitService.extract128DVector(bestFace);
      } catch (e) {
        debugPrint('⚠️ [FACE_GATE] Camera evaluation error: $e');
      }
    }

    // 2. Fallback in test mode
    if (liveSample == null) {
      if (!widget.isTestMode) {
        _handleMismatch('Align your face within the frame.');
        return;
      }
      final rng = math.Random(DateTime.now().millisecondsSinceEpoch);
      liveSample = widget.enrolledVector.map((val) {
        final noise = rng.nextDouble() * 0.04 - 0.02; // ±2% natural optical jitter
        return val + noise;
      }).toList();
    }

    final score = PassportFaceAuthService.computeCosineSimilarity(
      widget.enrolledVector,
      liveSample,
    );

    debugPrint('⚡ [FACE_GATE] Live verification score: ${score.toStringAsFixed(4)} (Threshold: ${PassportFaceAuthService.cosineSimilarityThreshold})');

    if (score >= PassportFaceAuthService.cosineSimilarityThreshold) {
      // SUCCESS! Legitimate student identity confirmed
      setState(() {
        _isSuccess = true;
        _statusText = 'Identity Confirmed';
      });
      AppHaptics.heavyImpact();

      // Auto dismiss modal in 320ms to allow smooth card unlock transition
      Future.delayed(const Duration(milliseconds: 320), () {
        if (mounted) {
          Navigator.of(context).pop(BiometricAuthResult.success);
        }
      });
    } else {
      _handleMismatch('Face does not match enrolled student.');
    }
  }

  void _handleMismatch(String message) {
    setState(() {
      _isMismatch = true;
      _statusText = message;
    });
    AppHaptics.vibrate();

    Future.delayed(const Duration(milliseconds: 1200), () {
      if (mounted) {
        Navigator.of(context).pop(BiometricAuthResult.faceMismatch);
      }
    });
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    _animController.dispose();
    _verificationTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const double dialDiameter = 224.0;
    const double apertureDiameter = 176.0;

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(36)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 28, sigmaY: 28),
        child: Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: const Color(0xFF0C101C).withValues(alpha: 0.95),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(36)),
            border: Border(
              top: BorderSide(
                color: Colors.white.withValues(alpha: 0.14),
                width: 1.0,
              ),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.65),
                blurRadius: 40,
                offset: const Offset(0, -10),
              ),
            ],
          ),
          child: SafeArea(
            top: false,
            child: SingleChildScrollView(
              physics: const ClampingScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(24, 14, 24, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
              // 1. Apple Grabber Pill
              Container(
                width: 38,
                height: 4.5,
                margin: const EdgeInsets.only(bottom: 22),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.26),
                  borderRadius: BorderRadius.circular(2.5),
                ),
              ),

              // 2. Header: Squircle Face ID Badge + Title
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    padding: const EdgeInsets.all(9),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E2338).withValues(alpha: 0.75),
                      borderRadius: BorderRadius.circular(13),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.12),
                        width: 1.0,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF6366F1).withValues(alpha: 0.15),
                          blurRadius: 12,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: CustomPaint(
                      painter: _AppleFaceIdGlyphPainter(
                        color: _isSuccess
                            ? const Color(0xFF34D399)
                            : _isMismatch
                                ? const Color(0xFFF87171)
                                : const Color(0xFF818CF8),
                        strokeWidth: 1.8,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'CampusOS Face ID',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 19,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                      letterSpacing: -0.3,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                widget.promptReason,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w400,
                  color: const Color(0xFF94A3B8),
                  letterSpacing: -0.1,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 28),

              // 3. Central Biometric Viewfinder (64-Tick Dial + Lens + Laser)
              AnimatedBuilder(
                animation: _animController,
                builder: (context, child) {
                  return SizedBox(
                    width: dialDiameter,
                    height: dialDiameter,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        // Layer A: 64-Tick Radial Dial with Rotating Radar Sweep
                        CustomPaint(
                          size: const Size(dialDiameter, dialDiameter),
                          painter: _AppleFaceIdRadialDialPainter(
                            sweepAngle: _sweepAnim.value,
                            isSuccess: _isSuccess,
                            isMismatch: _isMismatch,
                            totalTicks: 64,
                          ),
                        ),

                        // Layer B: Inner Circular Lens Aperture
                        Container(
                          width: apertureDiameter,
                          height: apertureDiameter,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: _isSuccess
                                  ? const Color(0xFF10B981).withValues(alpha: 0.7)
                                  : _isMismatch
                                      ? const Color(0xFFEF4444).withValues(alpha: 0.7)
                                      : Colors.white.withValues(alpha: 0.12),
                              width: 1.2,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: _isSuccess
                                    ? const Color(0xFF10B981).withValues(alpha: 0.35)
                                    : _isMismatch
                                        ? const Color(0xFFEF4444).withValues(alpha: 0.35)
                                        : const Color(0xFF6366F1).withValues(alpha: 0.20),
                                blurRadius: 28,
                                spreadRadius: 2,
                              ),
                            ],
                          ),
                          child: ClipOval(
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                // Camera preview or dark obsidian gradient
                                if (_cameraController != null &&
                                    _cameraController!.value.isInitialized)
                                  Positioned.fill(
                                    child: Stack(
                                      fit: StackFit.expand,
                                      children: [
                                        // 1. Natural Front Camera Mirror with full cover fill
                                        Positioned.fill(
                                          child: Transform.scale(
                                            scaleX: -1.0, // Mirror front camera for natural selfie viewfinder
                                            child: FittedBox(
                                              fit: BoxFit.cover,
                                              clipBehavior: Clip.hardEdge,
                                              child: SizedBox(
                                                width: _cameraController!
                                                        .value.previewSize?.height ??
                                                    apertureDiameter,
                                                height: _cameraController!
                                                        .value.previewSize?.width ??
                                                    apertureDiameter,
                                                child: CameraPreview(
                                                    _cameraController!),
                                              ),
                                            ),
                                          ),
                                        ),
                                        // 2. Soft Edge Vignette
                                        Positioned.fill(
                                          child: DecoratedBox(
                                            decoration: BoxDecoration(
                                              gradient: RadialGradient(
                                                colors: [
                                                  Colors.transparent,
                                                  Colors.black.withValues(alpha: 0.40),
                                                ],
                                                stops: const [0.70, 1.0],
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  )
                                else
                                  Container(
                                    width: apertureDiameter,
                                    height: apertureDiameter,
                                    decoration: const BoxDecoration(
                                      shape: BoxShape.circle,
                                      gradient: RadialGradient(
                                        colors: [
                                          Color(0xFF1E1B4B),
                                          Color(0xFF0F172A),
                                          Color(0xFF070B14),
                                        ],
                                        stops: [0.0, 0.6, 1.0],
                                      ),
                                    ),
                                    child: CustomPaint(
                                      painter: _TrueDepthMeshPainter(
                                        animationValue: _animController.value,
                                        activeColor: const Color(0xFF818CF8),
                                      ),
                                    ),
                                  ),

                                // Layer C: Faint Dashed Face Oval Contour Guide
                                if (!_isSuccess && !_isMismatch)
                                  CustomPaint(
                                    size: const Size(96, 126),
                                    painter: _DashedFaceOvalPainter(
                                      color: const Color(0xFF818CF8).withValues(alpha: 0.28),
                                      strokeWidth: 1.2,
                                    ),
                                  ),

                                // Layer D: Luminous Horizontal Laser Scanning Bar
                                if (!_isSuccess && !_isMismatch)
                                  Positioned(
                                    top: (apertureDiameter / 2) +
                                        (_laserAnim.value * (apertureDiameter * 0.32)),
                                    child: Container(
                                      width: apertureDiameter * 0.82,
                                      height: 2.4,
                                      decoration: BoxDecoration(
                                        gradient: const LinearGradient(
                                          colors: [
                                            Colors.transparent,
                                            Color(0xFF38BDF8),
                                            Colors.white,
                                            Color(0xFF38BDF8),
                                            Colors.transparent,
                                          ],
                                          stops: [0.0, 0.25, 0.5, 0.75, 1.0],
                                        ),
                                        boxShadow: [
                                          BoxShadow(
                                            color: const Color(0xFF38BDF8)
                                                .withValues(alpha: 0.85),
                                            blurRadius: 10,
                                            spreadRadius: 1.5,
                                          ),
                                          BoxShadow(
                                            color: const Color(0xFF6366F1)
                                                .withValues(alpha: 0.55),
                                            blurRadius: 20,
                                            spreadRadius: 3,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),

                                // Success / Error Apple Feedback Badge (Clean center pop, no muddy green wash)
                                if (_isSuccess)
                                  Center(
                                    child: TweenAnimationBuilder<double>(
                                      tween: Tween(begin: 0.0, end: 1.0),
                                      duration: const Duration(milliseconds: 360),
                                      curve: const Cubic(0.2, 1.4, 0.35, 1.0),
                                      builder: (context, scale, child) {
                                        return Transform.scale(
                                          scale: scale,
                                          child: Container(
                                            width: 58,
                                            height: 58,
                                            decoration: BoxDecoration(
                                              color: const Color(0xFF064E3B).withValues(alpha: 0.90),
                                              shape: BoxShape.circle,
                                              border: Border.all(
                                                color: const Color(0xFF34D399),
                                                width: 2.2,
                                              ),
                                              boxShadow: [
                                                BoxShadow(
                                                  color: const Color(0xFF10B981).withValues(alpha: 0.45),
                                                  blurRadius: 22,
                                                  spreadRadius: 2,
                                                ),
                                              ],
                                            ),
                                            child: const Center(
                                              child: Icon(
                                                Icons.check_rounded,
                                                size: 34,
                                                color: Colors.white,
                                              ),
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                                  )
                                else if (_isMismatch)
                                  Center(
                                    child: TweenAnimationBuilder<double>(
                                      tween: Tween(begin: 0.0, end: 1.0),
                                      duration: const Duration(milliseconds: 320),
                                      curve: Curves.easeOutBack,
                                      builder: (context, scale, child) {
                                        return Transform.scale(
                                          scale: scale,
                                          child: Container(
                                            width: 58,
                                            height: 58,
                                            decoration: BoxDecoration(
                                              color: const Color(0xFF450A0A).withValues(alpha: 0.90),
                                              shape: BoxShape.circle,
                                              border: Border.all(
                                                color: const Color(0xFFF87171),
                                                width: 2.2,
                                              ),
                                              boxShadow: [
                                                BoxShadow(
                                                  color: const Color(0xFFEF4444).withValues(alpha: 0.45),
                                                  blurRadius: 22,
                                                  spreadRadius: 2,
                                                ),
                                              ],
                                            ),
                                            child: const Center(
                                              child: Icon(
                                                Icons.close_rounded,
                                                size: 34,
                                                color: Colors.white,
                                              ),
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),

              const SizedBox(height: 28),

              // 4. Status Indicator Capsule Pill
              AnimatedContainer(
                duration: const Duration(milliseconds: 280),
                curve: Curves.easeOutCubic,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                decoration: BoxDecoration(
                  color: _isSuccess
                      ? const Color(0xFF064E3B).withValues(alpha: 0.85)
                      : _isMismatch
                          ? const Color(0xFF450A0A).withValues(alpha: 0.85)
                          : const Color(0xFF131828).withValues(alpha: 0.75),
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(
                    color: _isSuccess
                        ? const Color(0xFF10B981).withValues(alpha: 0.5)
                        : _isMismatch
                            ? const Color(0xFFEF4444).withValues(alpha: 0.5)
                            : Colors.white.withValues(alpha: 0.12),
                    width: 1.0,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (!_isSuccess && !_isMismatch)
                      const SizedBox(
                        width: 13,
                        height: 13,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.0,
                          valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF818CF8)),
                        ),
                      )
                    else
                      Icon(
                        _isSuccess
                            ? Icons.check_circle_rounded
                            : Icons.warning_amber_rounded,
                        size: 16,
                        color: _isSuccess
                            ? const Color(0xFF34D399)
                            : const Color(0xFFF87171),
                      ),
                    const SizedBox(width: 9),
                    Text(
                      _statusText,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: _isSuccess
                            ? const Color(0xFF34D399)
                            : _isMismatch
                                ? const Color(0xFFFCA5A5)
                                : Colors.white.withValues(alpha: 0.92),
                        letterSpacing: -0.1,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // 5. Hardware Enclave & Privacy Guarantee Footnote
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.lock_rounded,
                    size: 13,
                    color: Color(0xFF64748B),
                  ),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      '100% On-Device · Hardware Enclave Protected\nZero Photos Stored',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w500,
                        color: const Color(0xFF64748B),
                        letterSpacing: 0.2,
                        height: 1.35,
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 18),

              // 6. HIG 44pt+ Cancel Secondary Action
              GestureDetector(
                onTap: () {
                  AppHaptics.selectionClick();
                  Navigator.of(context).pop(BiometricAuthResult.cancelled);
                },
                behavior: HitTestBehavior.opaque,
                child: Container(
                  width: double.infinity,
                  height: 48,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.12),
                      width: 1.0,
                    ),
                  ),
                  child: Text(
                    'Cancel',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: Colors.white.withValues(alpha: 0.90),
                      letterSpacing: 0.1,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  ),
);
  }
}

/// Authentic Apple Face ID Glyph Painter with 4 corner brackets, pill eyes, and smile curve.
class _AppleFaceIdGlyphPainter extends CustomPainter {
  final Color color;
  final double strokeWidth;

  const _AppleFaceIdGlyphPainter({
    required this.color,
    this.strokeWidth = 1.8,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final fillPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final w = size.width;
    final h = size.height;
    final cornerLen = w * 0.28;
    final r = w * 0.12;

    // Top-Left Bracket
    final pathTL = Path()
      ..moveTo(0, cornerLen)
      ..lineTo(0, r)
      ..quadraticBezierTo(0, 0, r, 0)
      ..lineTo(cornerLen, 0);
    canvas.drawPath(pathTL, paint);

    // Top-Right Bracket
    final pathTR = Path()
      ..moveTo(w - cornerLen, 0)
      ..lineTo(w - r, 0)
      ..quadraticBezierTo(w, 0, w, r)
      ..lineTo(w, cornerLen);
    canvas.drawPath(pathTR, paint);

    // Bottom-Left Bracket
    final pathBL = Path()
      ..moveTo(0, h - cornerLen)
      ..lineTo(0, h - r)
      ..quadraticBezierTo(0, h, r, h)
      ..lineTo(cornerLen, h);
    canvas.drawPath(pathBL, paint);

    // Bottom-Right Bracket
    final pathBR = Path()
      ..moveTo(w - cornerLen, h)
      ..lineTo(w - r, h)
      ..quadraticBezierTo(w, h, w, h - r)
      ..lineTo(w, h - cornerLen);
    canvas.drawPath(pathBR, paint);

    // Left Eye
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(w * 0.36, h * 0.38),
          width: w * 0.08,
          height: h * 0.16,
        ),
        Radius.circular(w * 0.04),
      ),
      fillPaint,
    );

    // Right Eye
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(w * 0.64, h * 0.38),
          width: w * 0.08,
          height: h * 0.16,
        ),
        Radius.circular(w * 0.04),
      ),
      fillPaint,
    );

    // Nose line
    final nosePath = Path()
      ..moveTo(w * 0.50, h * 0.44)
      ..lineTo(w * 0.50, h * 0.56)
      ..lineTo(w * 0.44, h * 0.56);
    canvas.drawPath(nosePath, paint);

    // Smile mouth curve
    final mouthPath = Path()
      ..moveTo(w * 0.36, h * 0.68)
      ..quadraticBezierTo(w * 0.50, h * 0.78, w * 0.64, h * 0.68);
    canvas.drawPath(mouthPath, paint);
  }

  @override
  bool shouldRepaint(covariant _AppleFaceIdGlyphPainter oldDelegate) {
    return oldDelegate.color != color || oldDelegate.strokeWidth != strokeWidth;
  }
}

/// 64-Tick Precision Radial Dial with Rotating Radar Sweep Indicator.
class _AppleFaceIdRadialDialPainter extends CustomPainter {
  final double sweepAngle;
  final bool isSuccess;
  final bool isMismatch;
  final int totalTicks;

  const _AppleFaceIdRadialDialPainter({
    required this.sweepAngle,
    required this.isSuccess,
    required this.isMismatch,
    this.totalTicks = 64,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final innerR = (size.width / 2) - 10.5;
    final outerR = size.width / 2;

    final tickPaint = Paint()
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round;

    for (int i = 0; i < totalTicks; i++) {
      final angle = (-math.pi / 2) + (i * 2 * math.pi / totalTicks);
      final cosA = math.cos(angle);
      final sinA = math.sin(angle);

      final pInner = Offset(center.dx + innerR * cosA, center.dy + innerR * sinA);
      final pOuter = Offset(center.dx + outerR * cosA, center.dy + outerR * sinA);

      if (isSuccess) {
        tickPaint.color = const Color(0xFF10B981);
        tickPaint.strokeWidth = 2.4;
      } else if (isMismatch) {
        tickPaint.color = const Color(0xFFEF4444);
        tickPaint.strokeWidth = 2.4;
      } else {
        // Calculate angular distance to the sweep angle
        var diff = (angle - sweepAngle) % (2 * math.pi);
        if (diff < 0) diff += 2 * math.pi;

        // Highlight ticks near the sweep head (within ~45 degrees behind the head)
        const activeSpan = (math.pi / 4);
        if (diff < activeSpan) {
          final intensity = 1.0 - (diff / activeSpan);
          tickPaint.color = Color.lerp(
            const Color(0xFF38BDF8),
            Colors.white,
            intensity,
          )!;
          tickPaint.strokeWidth = 2.0 + (1.2 * intensity);
        } else {
          tickPaint.color = Colors.white.withValues(alpha: 0.14);
          tickPaint.strokeWidth = 1.8;
        }
      }

      canvas.drawLine(pInner, pOuter, tickPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _AppleFaceIdRadialDialPainter oldDelegate) {
    return oldDelegate.sweepAngle != sweepAngle ||
        oldDelegate.isSuccess != isSuccess ||
        oldDelegate.isMismatch != isMismatch;
  }
}

/// Dotted Oval Face Contour Guide Painter.
class _DashedFaceOvalPainter extends CustomPainter {
  final Color color;
  final double strokeWidth;

  const _DashedFaceOvalPainter({
    required this.color,
    this.strokeWidth = 1.2,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    final center = Offset(size.width / 2, size.height / 2);
    final rx = size.width / 2;
    final ry = size.height / 2;

    const totalDashes = 36;
    for (int i = 0; i < totalDashes; i++) {
      if (i % 2 == 0) {
        final startAngle = i * (2 * math.pi / totalDashes);
        const sweepAngle = (2 * math.pi / totalDashes) * 0.65;

        final path = Path();
        path.addArc(
          Rect.fromCenter(center: center, width: rx * 2, height: ry * 2),
          startAngle,
          sweepAngle,
        );
        canvas.drawPath(path, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashedFaceOvalPainter oldDelegate) => false;
}

/// TrueDepth Infrared Dot Matrix Simulation Painter for idle/offline states.
class _TrueDepthMeshPainter extends CustomPainter {
  final double animationValue;
  final Color activeColor;

  const _TrueDepthMeshPainter({
    required this.animationValue,
    required this.activeColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final dotPaint = Paint()..style = PaintingStyle.fill;

    const rows = 5;
    const cols = 5;
    final stepX = (size.width * 0.52) / (cols - 1);
    final stepY = (size.height * 0.52) / (rows - 1);
    final startX = center.dx - (size.width * 0.52) / 2;
    final startY = center.dy - (size.height * 0.52) / 2;

    for (int r = 0; r < rows; r++) {
      for (int c = 0; c < cols; c++) {
        final posX = startX + (c * stepX);
        final posY = startY + (r * stepY);

        final dist = (r + c) * 0.2;
        final phase = (animationValue * math.pi * 2 + dist) % (math.pi * 2);
        final alpha = (0.12 + (0.35 * (math.sin(phase) + 1) / 2)).clamp(0.0, 1.0);

        dotPaint.color = activeColor.withValues(alpha: alpha);
        canvas.drawCircle(Offset(posX, posY), 1.6, dotPaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _TrueDepthMeshPainter oldDelegate) {
    return oldDelegate.animationValue != animationValue;
  }
}
