import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Concentric guilloche/polar-grid security pattern drawn on the card.
class CardSecurityPatternPainter extends CustomPainter {
  final Color lineColor;
  final double opacity;
  final Offset focalPoint;

  const CardSecurityPatternPainter({
    this.lineColor = Colors.white,
    this.opacity = 0.12,
    this.focalPoint = const Offset(0.65, 0.5),
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = lineColor.withValues(alpha: opacity)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8
      ..isAntiAlias = true;

    final center = Offset(size.width * focalPoint.dx, size.height * focalPoint.dy);
    final maxDim = math.max(size.width, size.height);

    // Concentric circles
    const ringSpacing = 22.0;
    final maxRadius = maxDim * 1.3;
    for (double r = 18; r < maxRadius; r += ringSpacing) {
      canvas.drawCircle(center, r, paint);
    }

    // Radial lines emanating from center
    const numRays = 24;
    for (int i = 0; i < numRays; i++) {
      final angle = (i * 2 * math.pi) / numRays;
      final end = Offset(
        center.dx + maxRadius * math.cos(angle),
        center.dy + maxRadius * math.sin(angle),
      );
      canvas.drawLine(center, end, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CardSecurityPatternPainter oldDelegate) => false;
}

/// Realistic Metallic Gold EMV Chip.
class RealisticEmvChip extends StatelessWidget {
  final double width;
  final double height;
  final bool isGold;

  const RealisticEmvChip({
    Key? key,
    this.width = 44,
    this.height = 34,
    this.isGold = true,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(7),
        border: Border.all(
          color: isGold
              ? const Color(0xFFD49E35).withValues(alpha: 0.6)
              : const Color(0xFFCBD5E1).withValues(alpha: 0.5),
          width: 0.8,
        ),
        gradient: LinearGradient(
          colors: isGold
              ? const [
                  Color(0xFFFFDF79),
                  Color(0xFFD49E35),
                  Color(0xFFB57E1E),
                  Color(0xFFE5C07B),
                ]
              : const [
                  Color(0xFFFFFFFF),
                  Color(0xFFE2E8F0),
                  Color(0xFFCBD5E1),
                  Color(0xFF94A3B8),
                  Color(0xFFCBD5E1),
                ],
          stops: isGold ? null : const [0.0, 0.25, 0.55, 0.85, 1.0],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.35),
            blurRadius: 4,
            offset: const Offset(0, 1.5),
          ),
        ],
      ),
      child: CustomPaint(
        painter: _EmvChipPainter(isGold: isGold),
      ),
    );
  }
}

class _EmvChipPainter extends CustomPainter {
  final bool isGold;

  const _EmvChipPainter({this.isGold = true});

  @override
  void paint(Canvas canvas, Size size) {
    final linePaint = Paint()
      ..color = isGold
          ? const Color(0xFF6B4E10).withValues(alpha: 0.65)
          : const Color(0xFF475569).withValues(alpha: 0.75)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    final w = size.width;
    final h = size.height;

    // Center rounded contact area
    final centerRect = RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset(w / 2, h / 2), width: w * 0.44, height: h * 0.52),
      const Radius.circular(3),
    );
    canvas.drawRRect(centerRect, linePaint);

    // Contact division lines
    canvas.drawLine(Offset(0, h * 0.35), Offset(w * 0.28, h * 0.35), linePaint);
    canvas.drawLine(Offset(0, h * 0.65), Offset(w * 0.28, h * 0.65), linePaint);
    canvas.drawLine(Offset(w * 0.72, h * 0.35), Offset(w, h * 0.35), linePaint);
    canvas.drawLine(Offset(w * 0.72, h * 0.65), Offset(w, h * 0.65), linePaint);

    canvas.drawLine(Offset(w * 0.5, 0), Offset(w * 0.5, h * 0.24), linePaint);
    canvas.drawLine(Offset(w * 0.5, h * 0.76), Offset(w * 0.5, h), linePaint);
  }

  @override
  bool shouldRepaint(covariant _EmvChipPainter oldDelegate) =>
      oldDelegate.isGold != isGold;
}

/// Etched PCB Circuit Traces & Geometric Constellation Mesh background.
///
/// Faithfully reproduces the luxury crimson satin card aesthetics:
/// - Left & Center: Ultra-dense PCB circuit traces radiating around the EMV chip
/// - Central Data Highway: Multi-lane parallel vertical circuit bus with IC pads
/// - Right: High-density geometric low-poly wireframe constellation network (55+ nodes, 110+ edges)
/// - Bottom-Right: Brilliant 4-point diamond specular star flare & chromatic glints
class CardCircuitMeshPainter extends CustomPainter {
  final Color traceColor;
  final Color meshColor;
  final bool showSparkle;

  const CardCircuitMeshPainter({
    this.traceColor = const Color(0xFF240307),
    this.meshColor = const Color(0xFF1E0205),
    this.showSparkle = true,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // 1. Etched Circuit Board Traces (Left, Upper, Lower & Center Highway)
    _paintCircuitTraces(canvas, w, h);

    // 2. High-Density Geometric Constellation Low-Poly Mesh (Right Side)
    _paintConstellationMesh(canvas, w, h);

    // 3. Specular Diamond Flare & Prismatic Glints
    if (showSparkle) {
      _paintSpecularFlare(canvas, w, h);
    }
  }

  void _paintCircuitTraces(Canvas canvas, double w, double h) {
    final tracePaint = Paint()
      ..color = traceColor.withValues(alpha: 0.45)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0
      ..strokeCap = StrokeCap.round
      ..isAntiAlias = true;

    final fineTracePaint = Paint()
      ..color = traceColor.withValues(alpha: 0.35)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8
      ..strokeCap = StrokeCap.round
      ..isAntiAlias = true;

    final padFillPaint = Paint()
      ..color = traceColor.withValues(alpha: 0.50)
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;

    final padHollowPaint = Paint()
      ..color = traceColor.withValues(alpha: 0.45)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0
      ..isAntiAlias = true;

    // Micro-highlight underneath for genuine etched depth in satin metal
    final highlightPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.07)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8
      ..strokeCap = StrokeCap.round
      ..isAntiAlias = true;

    void drawTrace(Path path, {bool endVia = true, bool hollowVia = false, bool fine = false}) {
      canvas.drawPath(path.shift(const Offset(0.5, 0.5)), highlightPaint);
      canvas.drawPath(path, fine ? fineTracePaint : tracePaint);

      if (endVia) {
        final metric = path.computeMetrics().last;
        final endPos = metric.getTangentForOffset(metric.length)?.position;
        if (endPos != null) {
          if (hollowVia) {
            canvas.drawCircle(endPos, 2.5, padHollowPaint);
            canvas.drawCircle(endPos, 1.0, padFillPaint);
          } else {
            canvas.drawCircle(endPos, 1.8, padFillPaint);
          }
        }
      }
    }

    // --- TOP CLUSTER (Above Chip & Upper Left / Center) ---
    final t1 = Path()
      ..moveTo(w * 0.09, h * 0.36)
      ..lineTo(w * 0.05, h * 0.36)
      ..lineTo(w * 0.03, h * 0.33)
      ..lineTo(w * 0.03, h * 0.18)
      ..lineTo(w * 0.07, h * 0.12)
      ..lineTo(w * 0.14, h * 0.12);
    drawTrace(t1, endVia: true);

    final t2 = Path()
      ..moveTo(w * 0.11, h * 0.36)
      ..lineTo(w * 0.07, h * 0.36)
      ..lineTo(w * 0.05, h * 0.31)
      ..lineTo(w * 0.05, h * 0.21)
      ..lineTo(w * 0.09, h * 0.16)
      ..lineTo(w * 0.18, h * 0.16);
    drawTrace(t2, endVia: true);

    final t3 = Path()
      ..moveTo(w * 0.13, h * 0.36)
      ..lineTo(w * 0.09, h * 0.36)
      ..lineTo(w * 0.07, h * 0.28)
      ..lineTo(w * 0.07, h * 0.23)
      ..lineTo(w * 0.11, h * 0.19)
      ..lineTo(w * 0.21, h * 0.19);
    drawTrace(t3, endVia: true, hollowVia: true);

    final t4 = Path()
      ..moveTo(w * 0.15, h * 0.36)
      ..lineTo(w * 0.15, h * 0.26)
      ..lineTo(w * 0.18, h * 0.22)
      ..lineTo(w * 0.25, h * 0.22)
      ..lineTo(w * 0.29, h * 0.16)
      ..lineTo(w * 0.29, h * 0.08);
    drawTrace(t4, endVia: true);

    final t5 = Path()
      ..moveTo(w * 0.17, h * 0.36)
      ..lineTo(w * 0.17, h * 0.28)
      ..lineTo(w * 0.20, h * 0.24)
      ..lineTo(w * 0.28, h * 0.24)
      ..lineTo(w * 0.32, h * 0.18)
      ..lineTo(w * 0.32, h * 0.06);
    drawTrace(t5, endVia: true);

    final t6 = Path()
      ..moveTo(w * 0.19, h * 0.36)
      ..lineTo(w * 0.19, h * 0.30)
      ..lineTo(w * 0.22, h * 0.26)
      ..lineTo(w * 0.31, h * 0.26)
      ..lineTo(w * 0.35, h * 0.20)
      ..lineTo(w * 0.35, h * 0.08);
    drawTrace(t6, endVia: true, hollowVia: true);

    final t7 = Path()
      ..moveTo(w * 0.21, h * 0.36)
      ..lineTo(w * 0.21, h * 0.32)
      ..lineTo(w * 0.24, h * 0.28)
      ..lineTo(w * 0.33, h * 0.28)
      ..lineTo(w * 0.37, h * 0.23)
      ..lineTo(w * 0.37, h * 0.10);
    drawTrace(t7, endVia: true);

    final t8 = Path()
      ..moveTo(w * 0.23, h * 0.36)
      ..lineTo(w * 0.23, h * 0.33)
      ..lineTo(w * 0.26, h * 0.30)
      ..lineTo(w * 0.35, h * 0.30)
      ..lineTo(w * 0.39, h * 0.25)
      ..lineTo(w * 0.39, h * 0.13);
    drawTrace(t8, endVia: true);

    // --- HORIZONTAL CHIP BREAKOUT BUS (Right edge of Chip) ---
    final m1 = Path()
      ..moveTo(w * 0.24, h * 0.38)
      ..lineTo(w * 0.29, h * 0.38)
      ..lineTo(w * 0.33, h * 0.34)
      ..lineTo(w * 0.40, h * 0.34)
      ..lineTo(w * 0.44, h * 0.30)
      ..lineTo(w * 0.48, h * 0.30);
    drawTrace(m1, endVia: true, hollowVia: true);

    final m2 = Path()
      ..moveTo(w * 0.24, h * 0.42)
      ..lineTo(w * 0.30, h * 0.42)
      ..lineTo(w * 0.34, h * 0.38)
      ..lineTo(w * 0.42, h * 0.38)
      ..lineTo(w * 0.46, h * 0.34)
      ..lineTo(w * 0.50, h * 0.34);
    drawTrace(m2, endVia: true);

    final m3 = Path()
      ..moveTo(w * 0.24, h * 0.47)
      ..lineTo(w * 0.31, h * 0.47)
      ..lineTo(w * 0.35, h * 0.43)
      ..lineTo(w * 0.43, h * 0.43)
      ..lineTo(w * 0.47, h * 0.39)
      ..lineTo(w * 0.52, h * 0.39);
    drawTrace(m3, endVia: true);

    final m4 = Path()
      ..moveTo(w * 0.24, h * 0.52)
      ..lineTo(w * 0.31, h * 0.52)
      ..lineTo(w * 0.35, h * 0.48)
      ..lineTo(w * 0.44, h * 0.48)
      ..lineTo(w * 0.48, h * 0.44)
      ..lineTo(w * 0.53, h * 0.44);
    drawTrace(m4, endVia: true, hollowVia: true);

    final m5 = Path()
      ..moveTo(w * 0.24, h * 0.56)
      ..lineTo(w * 0.29, h * 0.56)
      ..lineTo(w * 0.33, h * 0.60)
      ..lineTo(w * 0.41, h * 0.60)
      ..lineTo(w * 0.45, h * 0.65)
      ..lineTo(w * 0.51, h * 0.65);
    drawTrace(m5, endVia: true);

    // --- BOTTOM CLUSTER (Below Chip & Lower Left / Center) ---
    final b1 = Path()
      ..moveTo(w * 0.09, h * 0.58)
      ..lineTo(w * 0.05, h * 0.58)
      ..lineTo(w * 0.03, h * 0.62)
      ..lineTo(w * 0.03, h * 0.75)
      ..lineTo(w * 0.07, h * 0.81)
      ..lineTo(w * 0.14, h * 0.81);
    drawTrace(b1, endVia: true);

    final b2 = Path()
      ..moveTo(w * 0.11, h * 0.58)
      ..lineTo(w * 0.07, h * 0.58)
      ..lineTo(w * 0.05, h * 0.64)
      ..lineTo(w * 0.05, h * 0.73)
      ..lineTo(w * 0.09, h * 0.78)
      ..lineTo(w * 0.17, h * 0.78);
    drawTrace(b2, endVia: true);

    final b3 = Path()
      ..moveTo(w * 0.13, h * 0.58)
      ..lineTo(w * 0.13, h * 0.66)
      ..lineTo(w * 0.16, h * 0.70)
      ..lineTo(w * 0.23, h * 0.70)
      ..lineTo(w * 0.27, h * 0.76)
      ..lineTo(w * 0.27, h * 0.86);
    drawTrace(b3, endVia: true);

    final b4 = Path()
      ..moveTo(w * 0.15, h * 0.58)
      ..lineTo(w * 0.15, h * 0.68)
      ..lineTo(w * 0.18, h * 0.73)
      ..lineTo(w * 0.26, h * 0.73)
      ..lineTo(w * 0.30, h * 0.79)
      ..lineTo(w * 0.30, h * 0.90);
    drawTrace(b4, endVia: true, hollowVia: true);

    final b5 = Path()
      ..moveTo(w * 0.17, h * 0.58)
      ..lineTo(w * 0.17, h * 0.70)
      ..lineTo(w * 0.20, h * 0.75)
      ..lineTo(w * 0.29, h * 0.75)
      ..lineTo(w * 0.33, h * 0.82)
      ..lineTo(w * 0.33, h * 0.93);
    drawTrace(b5, endVia: true);

    final b6 = Path()
      ..moveTo(w * 0.19, h * 0.58)
      ..lineTo(w * 0.19, h * 0.72)
      ..lineTo(w * 0.22, h * 0.77)
      ..lineTo(w * 0.31, h * 0.77)
      ..lineTo(w * 0.35, h * 0.84)
      ..lineTo(w * 0.35, h * 0.94);
    drawTrace(b6, endVia: true);

    final b7 = Path()
      ..moveTo(w * 0.21, h * 0.58)
      ..lineTo(w * 0.21, h * 0.74)
      ..lineTo(w * 0.25, h * 0.80)
      ..lineTo(w * 0.34, h * 0.80)
      ..lineTo(w * 0.38, h * 0.86)
      ..lineTo(w * 0.38, h * 0.96);
    drawTrace(b7, endVia: true, hollowVia: true);

    final b8 = Path()
      ..moveTo(w * 0.23, h * 0.58)
      ..lineTo(w * 0.23, h * 0.76)
      ..lineTo(w * 0.27, h * 0.82)
      ..lineTo(w * 0.37, h * 0.82)
      ..lineTo(w * 0.41, h * 0.88)
      ..lineTo(w * 0.41, h * 0.96);
    drawTrace(b8, endVia: true);

    // --- CENTRAL DATA HIGHWAY (Dense Vertical Parallel Bus between x: 0.38 and 0.53) ---
    final h1 = Path()
      ..moveTo(w * 0.41, h * 0.05)
      ..lineTo(w * 0.41, h * 0.22)
      ..lineTo(w * 0.44, h * 0.27)
      ..lineTo(w * 0.44, h * 0.48)
      ..lineTo(w * 0.47, h * 0.53)
      ..lineTo(w * 0.47, h * 0.78)
      ..lineTo(w * 0.49, h * 0.82)
      ..lineTo(w * 0.49, h * 0.95);
    drawTrace(h1, endVia: true, hollowVia: true);

    final h2 = Path()
      ..moveTo(w * 0.43, h * 0.05)
      ..lineTo(w * 0.43, h * 0.24)
      ..lineTo(w * 0.46, h * 0.29)
      ..lineTo(w * 0.46, h * 0.52)
      ..lineTo(w * 0.49, h * 0.57)
      ..lineTo(w * 0.49, h * 0.85);
    drawTrace(h2, endVia: true);

    final h3 = Path()
      ..moveTo(w * 0.45, h * 0.07)
      ..lineTo(w * 0.45, h * 0.26)
      ..lineTo(w * 0.48, h * 0.31)
      ..lineTo(w * 0.48, h * 0.56)
      ..lineTo(w * 0.51, h * 0.61)
      ..lineTo(w * 0.51, h * 0.88);
    drawTrace(h3, endVia: true);

    final h4 = Path()
      ..moveTo(w * 0.47, h * 0.08)
      ..lineTo(w * 0.47, h * 0.28)
      ..lineTo(w * 0.50, h * 0.33)
      ..lineTo(w * 0.50, h * 0.58)
      ..lineTo(w * 0.53, h * 0.63)
      ..lineTo(w * 0.53, h * 0.90);
    drawTrace(h4, endVia: true, hollowVia: true);

    final h5 = Path()
      ..moveTo(w * 0.39, h * 0.12)
      ..lineTo(w * 0.39, h * 0.35)
      ..lineTo(w * 0.42, h * 0.40)
      ..lineTo(w * 0.42, h * 0.66)
      ..lineTo(w * 0.45, h * 0.71)
      ..lineTo(w * 0.45, h * 0.92);
    drawTrace(h5, endVia: true);

    // Fine secondary circuit tracks
    final f1 = Path()
      ..moveTo(w * 0.31, h * 0.14)
      ..lineTo(w * 0.35, h * 0.14)
      ..lineTo(w * 0.38, h * 0.18)
      ..lineTo(w * 0.44, h * 0.18);
    drawTrace(f1, endVia: true, fine: true);

    final f2 = Path()
      ..moveTo(w * 0.28, h * 0.88)
      ..lineTo(w * 0.32, h * 0.88)
      ..lineTo(w * 0.36, h * 0.84)
      ..lineTo(w * 0.44, h * 0.84);
    drawTrace(f2, endVia: true, fine: true);

    final f3 = Path()
      ..moveTo(w * 0.06, h * 0.44)
      ..lineTo(w * 0.02, h * 0.44)
      ..lineTo(w * 0.02, h * 0.54)
      ..lineTo(w * 0.06, h * 0.54);
    drawTrace(f3, endVia: false, fine: true);

    // Real IC SMD landing pads array
    final smdPaint = Paint()
      ..color = traceColor.withValues(alpha: 0.55)
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;

    for (int i = 0; i < 6; i++) {
      final padY = h * 0.35 + (i * 7.0);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(w * 0.375, padY, 4.0, 2.2),
          const Radius.circular(0.8),
        ),
        smdPaint,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(w * 0.386, padY, 4.0, 2.2),
          const Radius.circular(0.8),
        ),
        smdPaint,
      );
    }

    // Isolated circuit vias & test pads
    final testPads = [
      Offset(w * 0.06, h * 0.12),
      Offset(w * 0.15, h * 0.08),
      Offset(w * 0.22, h * 0.12),
      Offset(w * 0.27, h * 0.06),
      Offset(w * 0.09, h * 0.85),
      Offset(w * 0.16, h * 0.88),
      Offset(w * 0.25, h * 0.90),
      Offset(w * 0.36, h * 0.68),
      Offset(w * 0.48, h * 0.22),
      Offset(w * 0.52, h * 0.74),
      Offset(w * 0.39, h * 0.77),
    ];
    for (final pad in testPads) {
      canvas.drawCircle(pad, 1.8, padFillPaint);
      canvas.drawCircle(pad, 3.0, padHollowPaint);
    }
  }

  void _paintConstellationMesh(Canvas canvas, double w, double h) {
    final primaryMeshPaint = Paint()
      ..color = meshColor.withValues(alpha: 0.36)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.90
      ..isAntiAlias = true;

    final secondaryMeshPaint = Paint()
      ..color = meshColor.withValues(alpha: 0.22)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.70
      ..isAntiAlias = true;

    final subtleSheenPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.08)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.75
      ..isAntiAlias = true;

    final nodePaint = Paint()
      ..color = meshColor.withValues(alpha: 0.55)
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;

    // High-Density Low-Poly Mesh Network: 56 vertices across right hemisphere
    final nodes = <Offset>[
      // Row 1 (y: 0.10 - 0.16)
      Offset(w * 0.46, h * 0.16), // 0
      Offset(w * 0.54, h * 0.12), // 1
      Offset(w * 0.63, h * 0.15), // 2
      Offset(w * 0.72, h * 0.11), // 3
      Offset(w * 0.82, h * 0.14), // 4
      Offset(w * 0.91, h * 0.12), // 5
      Offset(w * 0.97, h * 0.16), // 6

      // Row 2 (y: 0.22 - 0.28)
      Offset(w * 0.42, h * 0.26), // 7
      Offset(w * 0.50, h * 0.24), // 8
      Offset(w * 0.59, h * 0.27), // 9
      Offset(w * 0.68, h * 0.23), // 10
      Offset(w * 0.77, h * 0.26), // 11
      Offset(w * 0.86, h * 0.22), // 12
      Offset(w * 0.95, h * 0.25), // 13

      // Row 3 (y: 0.34 - 0.40)
      Offset(w * 0.44, h * 0.38), // 14
      Offset(w * 0.52, h * 0.35), // 15
      Offset(w * 0.61, h * 0.38), // 16
      Offset(w * 0.70, h * 0.34), // 17
      Offset(w * 0.79, h * 0.37), // 18
      Offset(w * 0.88, h * 0.33), // 19
      Offset(w * 0.97, h * 0.37), // 20

      // Row 4 (y: 0.46 - 0.52)
      Offset(w * 0.40, h * 0.49), // 21
      Offset(w * 0.48, h * 0.46), // 22
      Offset(w * 0.57, h * 0.50), // 23
      Offset(w * 0.66, h * 0.45), // 24
      Offset(w * 0.75, h * 0.49), // 25
      Offset(w * 0.84, h * 0.46), // 26
      Offset(w * 0.93, h * 0.50), // 27

      // Row 5 (y: 0.58 - 0.64)
      Offset(w * 0.43, h * 0.61), // 28
      Offset(w * 0.51, h * 0.58), // 29
      Offset(w * 0.60, h * 0.62), // 30
      Offset(w * 0.69, h * 0.57), // 31
      Offset(w * 0.78, h * 0.61), // 32
      Offset(w * 0.87, h * 0.58), // 33
      Offset(w * 0.96, h * 0.62), // 34

      // Row 6 (y: 0.70 - 0.76)
      Offset(w * 0.46, h * 0.73), // 35
      Offset(w * 0.55, h * 0.69), // 36
      Offset(w * 0.64, h * 0.73), // 37
      Offset(w * 0.73, h * 0.68), // 38
      Offset(w * 0.82, h * 0.72), // 39
      Offset(w * 0.90, h * 0.69), // 40
      Offset(w * 0.98, h * 0.74), // 41

      // Row 7 (y: 0.82 - 0.88)
      Offset(w * 0.49, h * 0.85), // 42
      Offset(w * 0.58, h * 0.82), // 43
      Offset(w * 0.67, h * 0.85), // 44
      Offset(w * 0.76, h * 0.81), // 45
      Offset(w * 0.85, h * 0.85), // 46
      Offset(w * 0.93, h * 0.82), // 47
      Offset(w * 0.98, h * 0.87), // 48

      // Row 8 (y: 0.92 - 0.96)
      Offset(w * 0.54, h * 0.95), // 49
      Offset(w * 0.63, h * 0.93), // 50
      Offset(w * 0.72, h * 0.95), // 51
      Offset(w * 0.81, h * 0.92), // 52
      Offset(w * 0.89, h * 0.95), // 53
      Offset(w * 0.97, h * 0.93), // 54
    ];

    // Delaunay triangular connectivity edges (120+ edges)
    final edges = <List<int>>[
      // Row 1 internal
      [0, 1], [1, 2], [2, 3], [3, 4], [4, 5], [5, 6],
      // Row 1 to Row 2
      [0, 7], [0, 8], [1, 8], [1, 9], [2, 9], [2, 10], [3, 10], [3, 11], [4, 11], [4, 12], [5, 12], [5, 13], [6, 13],
      // Row 2 internal
      [7, 8], [8, 9], [9, 10], [10, 11], [11, 12], [12, 13],
      // Row 2 to Row 3
      [7, 14], [8, 14], [8, 15], [9, 15], [9, 16], [10, 16], [10, 17], [11, 17], [11, 18], [12, 18], [12, 19], [13, 19], [13, 20],
      // Row 3 internal
      [14, 15], [15, 16], [16, 17], [17, 18], [18, 19], [19, 20],
      // Row 3 to Row 4
      [14, 21], [14, 22], [15, 22], [15, 23], [16, 23], [16, 24], [17, 24], [17, 25], [18, 25], [18, 26], [19, 26], [19, 27], [20, 27],
      // Row 4 internal
      [21, 22], [22, 23], [23, 24], [24, 25], [25, 26], [26, 27],
      // Row 4 to Row 5
      [21, 28], [22, 28], [22, 29], [23, 29], [23, 30], [24, 30], [24, 31], [25, 31], [25, 32], [26, 32], [26, 33], [27, 33], [27, 34],
      // Row 5 internal
      [28, 29], [29, 30], [30, 31], [31, 32], [32, 33], [33, 34],
      // Row 5 to Row 6
      [28, 35], [29, 35], [29, 36], [30, 36], [30, 37], [31, 37], [31, 38], [32, 38], [32, 39], [33, 39], [33, 40], [34, 40], [34, 41],
      // Row 6 internal
      [35, 36], [36, 37], [37, 38], [38, 39], [39, 40], [40, 41],
      // Row 6 to Row 7
      [35, 42], [36, 42], [36, 43], [37, 43], [37, 44], [38, 44], [38, 45], [39, 45], [39, 46], [40, 46], [40, 47], [41, 47], [41, 48],
      // Row 7 internal
      [42, 43], [43, 44], [44, 45], [45, 46], [46, 47], [47, 48],
      // Row 7 to Row 8
      [42, 49], [43, 49], [43, 50], [44, 50], [44, 51], [45, 51], [45, 52], [46, 52], [46, 53], [47, 53], [47, 54], [48, 54],
      // Row 8 internal
      [49, 50], [50, 51], [51, 52], [52, 53], [53, 54],
    ];

    // Draw all mesh lines with depth variation
    for (int i = 0; i < edges.length; i++) {
      final e = edges[i];
      if (e[0] < nodes.length && e[1] < nodes.length) {
        final n1 = nodes[e[0]];
        final n2 = nodes[e[1]];
        final isMajor = i % 2 == 0;
        canvas.drawLine(n1, n2, isMajor ? primaryMeshPaint : secondaryMeshPaint);

        // Subtle specular highlight on diagonal lines to emulate light catch
        if (i % 4 == 0) {
          canvas.drawLine(n1, n2, subtleSheenPaint);
        }
      }
    }

    // Draw mesh vertices
    for (int i = 0; i < nodes.length; i++) {
      final node = nodes[i];
      final radius = (i % 3 == 0) ? 1.6 : 1.1;
      canvas.drawCircle(node, radius, nodePaint);
    }
  }

  void _paintSpecularFlare(Canvas canvas, double w, double h) {
    // 1. Brilliant diamond 4-point sparkle at bottom-right corner
    final sparkleCenter = Offset(w * 0.90, h * 0.88);

    // Radial bloom halo
    final glowPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          Colors.white.withValues(alpha: 0.95),
          const Color(0xFFF1F5F9).withValues(alpha: 0.50),
          const Color(0xFF67E8F9).withValues(alpha: 0.22),
          Colors.transparent,
        ],
        stops: const [0.0, 0.22, 0.55, 1.0],
      ).createShader(Rect.fromCircle(center: sparkleCenter, radius: 26));
    canvas.drawCircle(sparkleCenter, 26, glowPaint);

    // Primary horizontal & vertical diamond rays
    final rayPaint = Paint()
      ..color = Colors.white
      ..strokeCap = StrokeCap.round
      ..isAntiAlias = true;

    final rayPath = Path();
    const rayLength = 34.0;
    const rayWidth = 1.9;

    // Horizontal diamond ray
    rayPath.moveTo(sparkleCenter.dx - rayLength, sparkleCenter.dy);
    rayPath.quadraticBezierTo(
      sparkleCenter.dx, sparkleCenter.dy - rayWidth,
      sparkleCenter.dx + rayLength, sparkleCenter.dy,
    );
    rayPath.quadraticBezierTo(
      sparkleCenter.dx, sparkleCenter.dy + rayWidth,
      sparkleCenter.dx - rayLength, sparkleCenter.dy,
    );

    // Vertical diamond ray
    rayPath.moveTo(sparkleCenter.dx, sparkleCenter.dy - rayLength);
    rayPath.quadraticBezierTo(
      sparkleCenter.dx - rayWidth, sparkleCenter.dy,
      sparkleCenter.dx, sparkleCenter.dy + rayLength,
    );
    rayPath.quadraticBezierTo(
      sparkleCenter.dx + rayWidth, sparkleCenter.dy,
      sparkleCenter.dx, sparkleCenter.dy - rayLength,
    );

    canvas.drawPath(rayPath, rayPaint);

    // Diagonal diffraction spikes
    final diagRayPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.70)
      ..strokeWidth = 1.0
      ..isAntiAlias = true;
    const diagLen = 15.0;
    canvas.drawLine(
      Offset(sparkleCenter.dx - diagLen, sparkleCenter.dy - diagLen),
      Offset(sparkleCenter.dx + diagLen, sparkleCenter.dy + diagLen),
      diagRayPaint,
    );
    canvas.drawLine(
      Offset(sparkleCenter.dx - diagLen, sparkleCenter.dy + diagLen),
      Offset(sparkleCenter.dx + diagLen, sparkleCenter.dy - diagLen),
      diagRayPaint,
    );

    // Central white core
    canvas.drawCircle(sparkleCenter, 2.4, Paint()..color = Colors.white);

    // 2. Realistic chromatic anamorphic surface glints along diagonal
    final glints = [
      (Offset(w * 0.22, h * 0.28), 14.0, const Color(0xFFFF8A80)),
      (Offset(w * 0.60, h * 0.56), 18.0, const Color(0xFFFFD180)),
      (Offset(w * 0.74, h * 0.74), 16.0, const Color(0xFF80D8FF)),
      (Offset(w * 0.84, h * 0.42), 12.0, const Color(0xFFFFAB91)),
    ];

    for (final glint in glints) {
      canvas.drawCircle(
        glint.$1,
        glint.$2,
        Paint()
          ..shader = RadialGradient(
            colors: [
              glint.$3.withValues(alpha: 0.16),
              Colors.transparent,
            ],
          ).createShader(Rect.fromCircle(center: glint.$1, radius: glint.$2)),
      );
    }
  }

  @override
  bool shouldRepaint(covariant CardCircuitMeshPainter oldDelegate) => false;
}


/// Contactless payment wave icon `)))`.
class ContactlessWaveIcon extends StatelessWidget {
  final double size;
  final Color color;

  const ContactlessWaveIcon({
    Key? key,
    this.size = 20,
    this.color = Colors.white,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(size, size),
      painter: _ContactlessWavePainter(color: color),
    );
  }
}

class _ContactlessWavePainter extends CustomPainter {
  final Color color;

  const _ContactlessWavePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round
      ..isAntiAlias = true;

    final w = size.width;
    final h = size.height;

    for (int i = 1; i <= 3; i++) {
      final r = (w * 0.26) * i;
      final rect = Rect.fromCircle(center: Offset(w * 0.12, h * 0.5), radius: r);
      canvas.drawArc(rect, -math.pi / 3.2, (2 * math.pi) / 3.2, false, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _ContactlessWavePainter oldDelegate) => false;
}

/// Circular CampusOS Emblem with infinity symbol.
class CampusOsEmblem extends StatelessWidget {
  final double size;

  const CampusOsEmblem({Key? key, this.size = 32.0}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: const Color(0xFF003882),
        shape: BoxShape.circle,
        border: Border.all(
          color: Colors.white,
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Center(
        child: Text(
          '∞',
          style: TextStyle(
            color: Colors.white,
            fontSize: size * 0.55,
            fontWeight: FontWeight.bold,
            height: 1.0,
          ),
        ),
      ),
    );
  }
}

/// Backward compatibility alias
class CampusNodeGlyph extends StatelessWidget {
  final double size;
  final Color baseColor;
  final Color accentColor;

  const CampusNodeGlyph({
    Key? key,
    this.size = 28.0,
    this.baseColor = Colors.white,
    this.accentColor = const Color(0xFF6C63FF),
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return CampusOsEmblem(size: size);
  }
}

/// Lightweight, performance-safe geometric Identity Mesh CustomPainter for CampusOS credentials.
///
/// Features:
/// - Sparse, technical, institutional geometric node-and-edge network
/// - Precomputed normalized coordinates to avoid runtime trigonometric allocations
/// - 120Hz-safe: shouldRepaint returns false (zero frame redraw cost)
/// - Single-pass canvas drawing without saveLayer, blur, or shader overhead
class CampusIdentityMeshPainter extends CustomPainter {
  final Color meshColor;
  final Color nodeColor;
  final double opacity;

  const CampusIdentityMeshPainter({
    this.meshColor = const Color(0xFF6366F1),
    this.nodeColor = const Color(0xFFA5B4FC),
    this.opacity = 0.16,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    final linePaint = Paint()
      ..color = meshColor.withValues(alpha: opacity)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8
      ..isAntiAlias = true;

    final nodePaint = Paint()
      ..color = nodeColor.withValues(alpha: opacity * 1.5)
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;

    // Sparse, geometric technical nodes distributed across the right quadrant
    final nodes = [
      Offset(w * 0.48, h * 0.15),
      Offset(w * 0.62, h * 0.12),
      Offset(w * 0.78, h * 0.18),
      Offset(w * 0.92, h * 0.14),
      Offset(w * 0.42, h * 0.42),
      Offset(w * 0.58, h * 0.38),
      Offset(w * 0.72, h * 0.45),
      Offset(w * 0.88, h * 0.36),
      Offset(w * 0.96, h * 0.48),
      Offset(w * 0.46, h * 0.70),
      Offset(w * 0.64, h * 0.66),
      Offset(w * 0.80, h * 0.74),
      Offset(w * 0.92, h * 0.68),
      Offset(w * 0.56, h * 0.88),
      Offset(w * 0.74, h * 0.90),
      Offset(w * 0.86, h * 0.86),
    ];

    // Sparse geometric triangular topology
    const edges = [
      [0, 1], [1, 2], [2, 3],
      [0, 4], [0, 5], [1, 5], [1, 6], [2, 6], [2, 7], [3, 7], [3, 8],
      [4, 5], [5, 6], [6, 7], [7, 8],
      [4, 9], [5, 9], [5, 10], [6, 10], [6, 11], [7, 11], [7, 12], [8, 12],
      [9, 10], [10, 11], [11, 12],
      [9, 13], [10, 13], [10, 14], [11, 14], [11, 15], [12, 15],
      [13, 14], [14, 15],
    ];

    for (final e in edges) {
      canvas.drawLine(nodes[e[0]], nodes[e[1]], linePaint);
    }

    for (final node in nodes) {
      canvas.drawCircle(node, 1.4, nodePaint);
    }
  }

  @override
  bool shouldRepaint(covariant CampusIdentityMeshPainter oldDelegate) => false;
}

/// Brushed Metallic Silver Typography matching luxury card embossing.
/// Optimized without saveLayer ShaderMask to guarantee 120Hz 8.33ms frame budget.
class MetallicSilverText extends StatelessWidget {
  final String text;
  final double fontSize;
  final FontWeight fontWeight;
  final double letterSpacing;
  final TextAlign? textAlign;
  final TextOverflow? overflow;
  final int? maxLines;

  const MetallicSilverText({
    Key? key,
    required this.text,
    this.fontSize = 22,
    this.fontWeight = FontWeight.w500,
    this.letterSpacing = 0.2,
    this.textAlign,
    this.overflow = TextOverflow.ellipsis,
    this.maxLines = 1,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      textAlign: textAlign,
      maxLines: maxLines,
      overflow: overflow,
      style: GoogleFonts.plusJakartaSans(
        fontSize: fontSize,
        fontWeight: fontWeight,
        color: const Color(0xFFF8FAFC),
        letterSpacing: letterSpacing,
        height: 1.1,
      ),
    );
  }
}
