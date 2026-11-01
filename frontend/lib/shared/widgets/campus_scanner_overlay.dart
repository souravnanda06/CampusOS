import 'dart:math';
import 'package:attendance_app/core/haptics/app_haptics.dart';

import 'package:flutter/material.dart';
/// Reusable dark backdrop painter with a rounded rectangular cutout for the camera viewfinder.
class ScannerHoleOverlayPainter extends CustomPainter {
  final Rect scanWindow;
  final double borderRadius;
  final Color overlayColor;

  ScannerHoleOverlayPainter({
    Rect? scanWindow,
    Rect? cutOutRect,
    this.borderRadius = 20.0,
    this.overlayColor = const Color(0x94000000), // ~58% opacity black
  }) : scanWindow = scanWindow ?? cutOutRect ?? Rect.zero;

  @override
  void paint(Canvas canvas, Size size) {
    final fullRect = Offset.zero & size;
    final cutoutRRect = RRect.fromRectAndRadius(
      scanWindow,
      Radius.circular(borderRadius),
    );

    final path = Path()
      ..addRect(fullRect)
      ..addRRect(cutoutRRect)
      ..fillType = PathFillType.evenOdd;

    final paint = Paint()
      ..color = overlayColor
      ..style = PaintingStyle.fill;

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant ScannerHoleOverlayPainter oldDelegate) {
    return oldDelegate.scanWindow != scanWindow ||
        oldDelegate.borderRadius != borderRadius ||
        oldDelegate.overlayColor != overlayColor;
  }
}

/// Paints the 4 rounded white corner brackets framing the viewfinder window.
class ScannerCornersPainter extends CustomPainter {
  final Rect scanWindow;
  final double cornerLength;
  final double strokeWidth;
  final double cornerRadius;
  final Color cornerColor;

  ScannerCornersPainter({
    Rect? scanWindow,
    Rect? cutOutRect,
    this.cornerLength = 32.0,
    double? strokeWidth,
    double? cornerStroke,
    double? cornerRadius,
    double? borderRadius,
    this.cornerColor = Colors.white,
  })  : scanWindow = scanWindow ?? cutOutRect ?? Rect.zero,
        strokeWidth = strokeWidth ?? cornerStroke ?? 3.8,
        cornerRadius = cornerRadius ?? borderRadius ?? 20.0;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = cornerColor
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final r = cornerRadius;
    final l = cornerLength;

    final left = scanWindow.left;
    final top = scanWindow.top;
    final right = scanWindow.right;
    final bottom = scanWindow.bottom;

    // 1. Top-Left Corner
    final tlPath = Path()
      ..moveTo(left, top + l)
      ..lineTo(left, top + r)
      ..arcTo(Rect.fromLTWH(left, top, 2 * r, 2 * r), pi, pi / 2, false)
      ..lineTo(left + l, top);
    canvas.drawPath(tlPath, paint);

    // 2. Top-Right Corner
    final trPath = Path()
      ..moveTo(right - l, top)
      ..lineTo(right - r, top)
      ..arcTo(Rect.fromLTWH(right - 2 * r, top, 2 * r, 2 * r), 1.5 * pi, pi / 2, false)
      ..lineTo(right, top + l);
    canvas.drawPath(trPath, paint);

    // 3. Bottom-Right Corner
    final brPath = Path()
      ..moveTo(right, bottom - l)
      ..lineTo(right, bottom - r)
      ..arcTo(Rect.fromLTWH(right - 2 * r, bottom - 2 * r, 2 * r, 2 * r), 0, pi / 2, false)
      ..lineTo(right - l, bottom);
    canvas.drawPath(brPath, paint);

    // 4. Bottom-Left Corner
    final blPath = Path()
      ..moveTo(left + l, bottom)
      ..lineTo(left + r, bottom)
      ..arcTo(Rect.fromLTWH(left, bottom - 2 * r, 2 * r, 2 * r), 0.5 * pi, pi / 2, false)
      ..lineTo(left, bottom - l);
    canvas.drawPath(blPath, paint);
  }

  @override
  bool shouldRepaint(covariant ScannerCornersPainter oldDelegate) {
    return oldDelegate.scanWindow != scanWindow ||
        oldDelegate.cornerLength != cornerLength ||
        oldDelegate.strokeWidth != strokeWidth ||
        oldDelegate.cornerRadius != cornerRadius ||
        oldDelegate.cornerColor != cornerColor;
  }
}

/// Reusable circular glowing Torch Button styled identically to the Student scanner.
class CampusTorchButton extends StatelessWidget {
  final bool torchEnabled;
  final VoidCallback onToggle;
  final double size;

  CampusTorchButton({
    Key? key,
    bool? torchEnabled,
    bool? isTorchOn,
    VoidCallback? onToggle,
    VoidCallback? onTap,
    this.size = 64.0,
  })  : torchEnabled = torchEnabled ?? isTorchOn ?? false,
        onToggle = onToggle ?? onTap ?? (() {}),
        super(key: key);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        AppHaptics.selectionClick();
        onToggle();
      },
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: torchEnabled
              ? Colors.amber.withValues(alpha: 0.35)
              : Colors.white.withValues(alpha: 0.16),
          border: Border.all(
            color: torchEnabled
                ? Colors.amberAccent
                : Colors.white.withValues(alpha: 0.28),
            width: 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.25),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Center(
          child: Icon(
            torchEnabled ? Icons.flash_on_rounded : Icons.flash_off_rounded,
            color: torchEnabled ? Colors.amberAccent : Colors.white,
            size: size * 0.44,
          ),
        ),
      ),
    );
  }
}
