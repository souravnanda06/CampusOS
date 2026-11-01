import 'package:flutter/material.dart';
import 'dart:math' as math;
import '../../core/theme/app_theme.dart';
import '../../core/performance/performance.dart';

class AnimatedBackground extends StatefulWidget {
  final Widget child;
  final bool isDark;
  final bool hasWaves;

  const AnimatedBackground({
    Key? key,
    required this.child,
    this.isDark = false,
    this.hasWaves = false,
  }) : super(key: key);

  @override
  State<AnimatedBackground> createState() => _AnimatedBackgroundState();
}

class _AnimatedBackgroundState extends State<AnimatedBackground>
    with TickerProviderStateMixin {
  late AnimationController _orbController;
  late AnimationController _waveController;

  @override
  void initState() {
    super.initState();
    final perf = PerformanceEngine.instance;
    final mode = perf.profile.renderingProfile.backgroundAnimationMode;
    final isStatic = mode == BackgroundAnimationMode.staticGradient ||
        perf.profile.animationProfile.reducedMotion;

    _orbController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 12),
    );

    _waveController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    );

    if (!isStatic) {
      _orbController.repeat(reverse: true);
      if (widget.hasWaves && mode == BackgroundAnimationMode.activeOrbsAndWaves) {
        _waveController.repeat();
      }
    }
  }

  @override
  void dispose() {
    _orbController.dispose();
    _waveController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Background Color
        Container(
          decoration: BoxDecoration(
            gradient: widget.isDark
                ? const LinearGradient(
                    colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  )
                : const LinearGradient(
                    colors: [Color(0xFFF8F9FA), Color(0xFFFFFFFF)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
          ),
        ),

        // Animated Orbs with Parallax
        AnimatedBuilder(
          animation: _orbController,
          builder: (context, child) {
            return Stack(
              children: [
                Positioned(
                  top: -120 + (_orbController.value * 60),
                  left: -60 + (_orbController.value * 40),
                  child: _buildOrb(
                    widget.isDark
                        ? AppTheme.primaryBlue.withValues(alpha: 0.15)
                        : AppTheme.primaryBlue.withValues(alpha: 0.2),
                    320,
                  ),
                ),
                Positioned(
                  bottom: -80 - (_orbController.value * 70),
                  right: -120 - (_orbController.value * 50),
                  child: _buildOrb(
                    widget.isDark
                        ? AppTheme.secondaryTeal.withValues(alpha: 0.12)
                        : AppTheme.secondaryTeal.withValues(alpha: 0.18),
                    420,
                  ),
                ),
                Positioned(
                  top: 180 + (_orbController.value * 30),
                  right: -160 + (_orbController.value * 25),
                  child: _buildOrb(
                    widget.isDark
                        ? const Color(0xFF9D4EDD).withValues(alpha: 0.1)
                        : const Color(0xFF9D4EDD).withValues(alpha: 0.15),
                    240,
                  ),
                ),
              ],
            );
          },
        ),

        // Wave Pattern (optional)
        if (widget.hasWaves &&
            PerformanceEngine.instance.profile.renderingProfile.backgroundAnimationMode ==
                BackgroundAnimationMode.activeOrbsAndWaves)
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: AnimatedBuilder(
              animation: _waveController,
              builder: (context, child) {
                return CustomPaint(
                  size: Size(MediaQuery.of(context).size.width, 200),
                  painter: WavePainter(
                    animation: _waveController.value,
                    isDark: widget.isDark,
                  ),
                );
              },
            ),
          ),

        // Content
        widget.child,
      ],
    );
  }

  Widget _buildOrb(Color color, double size) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [
            color,
            color.withValues(alpha: 0),
          ],
          stops: const [0.0, 1.0],
        ),
      ),
    );
  }
}

class WavePainter extends CustomPainter {
  final double animation;
  final bool isDark;

  WavePainter({required this.animation, required this.isDark});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = isDark
          ? AppTheme.primaryBlue.withValues(alpha: 0.05)
          : AppTheme.primaryBlue.withValues(alpha: 0.08)
      ..style = PaintingStyle.fill;

    final path = Path();
    const waveHeight = 30.0;
    final waveLength = size.width / 2;

    path.moveTo(0, size.height);
    path.lineTo(0, size.height / 2);

    for (double i = 0; i <= size.width; i++) {
      path.lineTo(
        i,
        size.height / 2 +
            math.sin((i / waveLength + animation * 2) * 2 * math.pi) *
                waveHeight,
      );
    }

    path.lineTo(size.width, size.height);
    path.close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(WavePainter oldDelegate) => true;
}
