import 'dart:math';
import 'package:flutter/material.dart';

class BrandedLoader extends StatefulWidget {
  final double size;
  final Color color;

  const BrandedLoader({
    Key? key,
    this.size = 36.0,
    this.color = const Color(0xD9FFFFFF), // White 85%
  }) : super(key: key);

  @override
  State<BrandedLoader> createState() => _BrandedLoaderState();
}

class _BrandedLoaderState extends State<BrandedLoader>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration:
          const Duration(milliseconds: 2400), // 1.2s per loop * 2 for reverse
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Transform.rotate(
          angle: _controller.value * 2 * pi,
          child: CustomPaint(
            size: Size(widget.size, widget.size),
            painter: _LoaderPainter(color: widget.color),
          ),
        );
      },
    );
  }
}

class _LoaderPainter extends CustomPainter {
  final Color color;

  _LoaderPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - 2.5) / 2;

    // Draw an arc that isn't a full circle
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      0,
      1.5 * pi, // 270 degrees
      false,
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
