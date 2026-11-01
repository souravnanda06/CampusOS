import 'package:flutter/material.dart';

class MorphText extends StatefulWidget {
  const MorphText({super.key});

  @override
  State<MorphText> createState() => _MorphTextState();
}

class _MorphTextState extends State<MorphText>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> m1, m2, m3, m4;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );

    // Each letter animates slightly after the previous one
    m1 = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.0, 0.45, curve: Curves.easeOutCubic),
    );

    m2 = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.15, 0.60, curve: Curves.easeOutCubic),
    );

    m3 = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.30, 0.75, curve: Curves.easeOutCubic),
    );

    m4 = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.45, 0.90, curve: Curves.easeOutCubic),
    );

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        MorphLetter(letter: "E", progress: m1),
        const SizedBox(width: 4),
        MorphLetter(letter: "z", progress: m2),
        const SizedBox(width: 2),
        MorphLetter(letter: "z", progress: m3),
        const SizedBox(width: 2),
        MorphLetter(letter: "o", progress: m4),
      ],
    );
  }
}

class MorphLetter extends StatelessWidget {
  final String letter;
  final Animation<double> progress;

  const MorphLetter({
    super.key,
    required this.letter,
    required this.progress,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: progress,
      builder: (_, __) {
        return Stack(
          alignment: Alignment.center,
          children: [
            // glow pulse when letter fully settles
            Opacity(
              opacity: progress.value.clamp(0.0, 1.0) * 0.4,
              child: Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: Colors.blueAccent.withValues(alpha: 0.2 * progress.value),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color:
                          Colors.blueAccent.withValues(alpha: 0.5 * progress.value),
                      blurRadius: 30 * progress.value,
                      spreadRadius: 5 * progress.value,
                    ),
                  ],
                ),
              ),
            ),
            // morph letter
            ClipRect(
              child: TweenAnimationBuilder<double>(
                duration: const Duration(milliseconds: 300),
                tween: Tween(begin: 0.0, end: progress.value),
                builder: (_, v, child) {
                  return Transform.scale(
                    scale: 0.9 + (v * 0.1),
                    child: ShaderMask(
                      shaderCallback: (bounds) {
                        return const LinearGradient(
                          colors: [
                            Color(0xFF5894FF),
                            Color(0xFF00D6C9),
                          ],
                        ).createShader(bounds);
                      },
                      child: CustomPaint(
                        painter: _LetterMorphPainter(
                          letter: letter,
                          progress: v,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}

class _LetterMorphPainter extends CustomPainter {
  final String letter;
  final double progress;

  _LetterMorphPainter({required this.letter, required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white
      ..strokeWidth = 8
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final p = Path();

    // start as a single vertical line → morph to letter
    final startX = size.width * 0.5;
    final startY = size.height * 0.2;
    final endY = size.height * 0.8;

    // Draw morph path
    if (progress < 0.4) {
      // phase 1: straight line
      p.moveTo(startX, startY);
      p.lineTo(startX, startY + (endY - startY) * (progress / 0.4));
    } else {
      // phase 2: final letter
      TextPainter tp = TextPainter(
        text: TextSpan(
          text: letter,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 64,
            fontWeight: FontWeight.w600,
          ),
        ),
        textDirection: TextDirection.ltr,
      );
      tp.layout();
      // Center the text painter
      tp.paint(canvas, Offset(-tp.width / 2, -tp.height / 2));
      return;
    }

    canvas.drawPath(p, paint);
  }

  @override
  bool shouldRepaint(_) => true;
}
