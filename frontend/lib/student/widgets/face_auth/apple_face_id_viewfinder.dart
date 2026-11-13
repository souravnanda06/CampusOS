import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:attendance_app/core/haptics/app_haptics.dart';

/// An authentic Apple Face ID-style circular/oval biometric scanning viewfinder.
///
/// Features:
/// - 44 radial tick segments surrounding the face aperture.
/// - Progressive clockwise segment illumination as biometric extraction advances.
/// - Tactile haptic tick feedback as segments lock into position.
/// - TrueDepth 3D infrared dot grid matrix simulation.
/// - Fluid morphing transition into Apple verified green shield/checkmark upon completion.
class AppleFaceIdViewfinder extends StatefulWidget {
  final double progress; // 0.0 to 1.0
  final bool isCompleted;
  final Widget? cameraPreview;
  final double width;
  final double height;

  const AppleFaceIdViewfinder({
    Key? key,
    required this.progress,
    this.isCompleted = false,
    this.cameraPreview,
    this.width = 250,
    this.height = 330,
  }) : super(key: key);

  @override
  State<AppleFaceIdViewfinder> createState() => _AppleFaceIdViewfinderState();
}

class _AppleFaceIdViewfinderState extends State<AppleFaceIdViewfinder>
    with SingleTickerProviderStateMixin {
  late AnimationController _scannerMeshController;
  int _lastHapticTickIndex = -1;

  static const int totalTicks = 44;

  @override
  void initState() {
    super.initState();
    _scannerMeshController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat(reverse: true);
  }

  @override
  void didUpdateWidget(covariant AppleFaceIdViewfinder oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.progress > oldWidget.progress && !widget.isCompleted) {
      final currentTick = (widget.progress * totalTicks).floor();
      if (currentTick != _lastHapticTickIndex && currentTick % 3 == 0) {
        _lastHapticTickIndex = currentTick;
        AppHaptics.selectionClick();
      }
    }
  }

  @override
  void dispose() {
    _scannerMeshController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isReduced = MediaQuery.maybeDisableAnimationsOf(context) ?? false;

    return Center(
      child: SizedBox(
        width: widget.width + 36,
        height: widget.height + 36,
        child: Stack(
          alignment: Alignment.center,
          children: [
            // 1. Camera Viewfinder Oval Aperture
            Container(
              width: widget.width,
              height: widget.height,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(widget.width / 2),
                color: const Color(0xFF070B14),
                boxShadow: [
                  BoxShadow(
                    color: widget.isCompleted
                        ? const Color(0xFF10B981).withValues(alpha: 0.35)
                        : const Color(0xFF6366F1).withValues(alpha: 0.20),
                    blurRadius: 36,
                    spreadRadius: 4,
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(widget.width / 2),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    if (widget.cameraPreview != null)
                      widget.cameraPreview!
                    else
                      Icon(
                        widget.isCompleted
                            ? Icons.verified_rounded
                            : Icons.face_rounded,
                        size: 110,
                        color: widget.isCompleted
                            ? const Color(0xFF34D399)
                            : Colors.white.withValues(alpha: 0.35),
                      ),

                    // 2. TrueDepth Infrared Dot Matrix Mesh Simulation
                    if (!widget.isCompleted && !isReduced)
                      AnimatedBuilder(
                        animation: _scannerMeshController,
                        builder: (context, _) {
                          return CustomPaint(
                            size: Size(widget.width, widget.height),
                            painter: _TrueDepthMeshPainter(
                              animationValue: _scannerMeshController.value,
                              activeColor: const Color(0xFF818CF8),
                            ),
                          );
                        },
                      ),

                    // 3. Verified Success Green Flash
                    if (widget.isCompleted)
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 320),
                        color: const Color(0xFF10B981).withValues(alpha: 0.28),
                        child: const Center(
                          child: Icon(
                            Icons.check_rounded,
                            size: 100,
                            color: Colors.white,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),

            // 4. Apple Face ID Radial Scanning Ticks Outer Ring
            CustomPaint(
              size: Size(widget.width + 36, widget.height + 36),
              painter: _AppleFaceIdTicksPainter(
                progress: widget.isCompleted ? 1.0 : widget.progress,
                isCompleted: widget.isCompleted,
                ovalWidth: widget.width,
                ovalHeight: widget.height,
                totalTicks: totalTicks,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AppleFaceIdTicksPainter extends CustomPainter {
  final double progress;
  final bool isCompleted;
  final double ovalWidth;
  final double ovalHeight;
  final int totalTicks;

  _AppleFaceIdTicksPainter({
    required this.progress,
    required this.isCompleted,
    required this.ovalWidth,
    required this.ovalHeight,
    required this.totalTicks,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final rx = (ovalWidth / 2) + 12;
    final ry = (ovalHeight / 2) + 12;

    final unreadPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.16)
      ..strokeWidth = 2.4
      ..strokeCap = StrokeCap.round;

    final activePaint = Paint()
      ..color = isCompleted
          ? const Color(0xFF34D399)
          : const Color(0xFF818CF8)
      ..strokeWidth = 3.0
      ..strokeCap = StrokeCap.round;

    final completedPaint = Paint()
      ..color = const Color(0xFF10B981)
      ..strokeWidth = 3.2
      ..strokeCap = StrokeCap.round;

    final activeTicksCount = (progress.clamp(0.0, 1.0) * totalTicks).round();

    for (int i = 0; i < totalTicks; i++) {
      // Angle starting from top (-pi/2) going clockwise
      final angle = (-math.pi / 2) + (i * 2 * math.pi / totalTicks);

      // Points on inner and outer ellipse ring
      final cosA = math.cos(angle);
      final sinA = math.sin(angle);

      final pInner = Offset(
        center.dx + rx * cosA,
        center.dy + ry * sinA,
      );

      const double tickLength = 7.0;
      final pOuter = Offset(
        center.dx + (rx + tickLength) * cosA,
        center.dy + (ry + tickLength) * sinA,
      );

      final bool isActive = i <= activeTicksCount;

      final paintToUse = isCompleted
          ? completedPaint
          : (isActive ? activePaint : unreadPaint);

      canvas.drawLine(pInner, pOuter, paintToUse);
    }
  }

  @override
  bool shouldRepaint(covariant _AppleFaceIdTicksPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.isCompleted != isCompleted ||
        oldDelegate.ovalWidth != ovalWidth ||
        oldDelegate.ovalHeight != ovalHeight;
  }
}

class _TrueDepthMeshPainter extends CustomPainter {
  final double animationValue;
  final Color activeColor;

  _TrueDepthMeshPainter({
    required this.animationValue,
    required this.activeColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final dotPaint = Paint()..style = PaintingStyle.fill;

    // Grid of biometric tracking mesh points
    const rows = 5;
    const cols = 5;
    final stepX = (size.width * 0.55) / (cols - 1);
    final stepY = (size.height * 0.55) / (rows - 1);
    final startX = center.dx - (size.width * 0.55) / 2;
    final startY = center.dy - (size.height * 0.55) / 2;

    for (int r = 0; r < rows; r++) {
      for (int c = 0; c < cols; c++) {
        final posX = startX + (c * stepX);
        final posY = startY + (r * stepY);

        // Calculate wave pulsation
        final dist = (r + c) * 0.2;
        final phase = (animationValue * math.pi * 2 + dist) % (math.pi * 2);
        final alpha = (0.15 + (0.35 * (math.sin(phase) + 1) / 2)).clamp(0.0, 1.0);

        dotPaint.color = activeColor.withValues(alpha: alpha);
        canvas.drawCircle(Offset(posX, posY), 1.8, dotPaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _TrueDepthMeshPainter oldDelegate) {
    return oldDelegate.animationValue != animationValue;
  }
}
