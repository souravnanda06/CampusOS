part of '../screens/broadcasting_screen.dart';

/// Ambient static rings and 3 spreading proximity ripples centered on the hero orb.
///
/// Painted inside a single [CustomPainter] wrapped in [RepaintBoundary] and [IgnorePointer].
/// Vertical fade (40% -> 56% of screen height) is applied directly via stroke gradient shaders,
/// avoiding expensive full-screen ShaderMask saveLayers and per-frame MaskFilter blurs.
class _ProximityRipples extends StatelessWidget {
  final Animation<double> animation;
  final ValueListenable<Offset?> orbCenterListenable;
  final bool isLive;

  const _ProximityRipples({
    required this.animation,
    required this.orbCenterListenable,
    required this.isLive,
  });

  @override
  Widget build(BuildContext context) {
    final bool reducedMotion = AnimationConstants.isReducedMotion(context);
    final bool tickerEnabled = TickerMode.of(context);
    final bool animate = isLive && !reducedMotion && tickerEnabled;

    return IgnorePointer(
      child: RepaintBoundary(
        child: CustomPaint(
          size: Size.infinite,
          painter: _ProximityRipplesPainter(
            animation: animation,
            orbCenterListenable: orbCenterListenable,
            animate: animate,
          ),
        ),
      ),
    );
  }
}

class _ProximityRipplesPainter extends CustomPainter {
  final Animation<double> animation;
  final ValueListenable<Offset?> orbCenterListenable;
  final bool animate;

  _ProximityRipplesPainter({
    required this.animation,
    required this.orbCenterListenable,
    required this.animate,
  }) : super(
          repaint: animate
              ? Listenable.merge([animation, orbCenterListenable])
              : orbCenterListenable,
        );

  Shader _buildVerticalFadeShader(Size size, Color color) {
    final double fadeEndY = math.max(1.0, size.height * 0.56);
    const double opaqueStop = 0.40 / 0.56; // 0.7143
    return LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        color,
        color,
        color.withValues(alpha: 0.0),
      ],
      stops: const [0.0, opaqueStop, 1.0],
      tileMode: TileMode.clamp,
    ).createShader(Rect.fromLTWH(0.0, 0.0, size.width, fadeEndY));
  }

  @override
  void paint(Canvas canvas, Size size) {
    final Offset center = orbCenterListenable.value ??
        Offset(size.width * 0.5, size.height * 0.26);

    // Two static ambient rings (290px and 370px diameter) with vertical fade
    final Paint staticRing1 = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0
      ..shader = _buildVerticalFadeShader(
        size,
        Colors.white.withValues(alpha: 0.07),
      );
    canvas.drawCircle(center, _LiveTheme.staticRing1Diameter / 2.0, staticRing1);

    final Paint staticRing2 = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0
      ..shader = _buildVerticalFadeShader(
        size,
        Colors.white.withValues(alpha: 0.045),
      );
    canvas.drawCircle(center, _LiveTheme.staticRing2Diameter / 2.0, staticRing2);

    if (!animate) return;

    final double t = animation.value;
    for (int i = 0; i < 3; i++) {
      final double p = (t + i / 3.0) % 1.0;
      final double eased = Curves.easeOutCubic.transform(p);
      final double diameter = ui.lerpDouble(
        _LiveTheme.rippleMinDiameter,
        _LiveTheme.rippleMaxDiameter,
        eased,
      )!;
      final double radius = diameter / 2.0;

      final double fadeIn = p < 0.16 ? (p / 0.16) : 1.0;
      final double fadeOut = math.pow(1.0 - p, 1.6).toDouble();
      final double opacity = (fadeIn * fadeOut * 0.7).clamp(0.0, 1.0);
      if (opacity <= 0.004) continue;

      final double normalizedAlpha = (opacity / 0.7).clamp(0.0, 1.0);

      // Soft wide halo stroke (replaces expensive MaskFilter.blur at 60fps)
      final Paint outerGlowPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 14.0
        ..shader = _buildVerticalFadeShader(
          size,
          _LiveTheme.indigoRipple.withValues(alpha: 0.10 * normalizedAlpha),
        );
      canvas.drawCircle(center, radius, outerGlowPaint);

      final Paint midGlowPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5.5
        ..shader = _buildVerticalFadeShader(
          size,
          _LiveTheme.indigoRipple.withValues(alpha: 0.16 * normalizedAlpha),
        );
      canvas.drawCircle(center, radius, midGlowPaint);

      // Crisp inner ripple stroke
      final Paint strokePaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..shader = _buildVerticalFadeShader(
          size,
          _LiveTheme.accent.withValues(alpha: opacity),
        );
      canvas.drawCircle(center, radius, strokePaint);
    }
  }

  @override
  bool shouldRepaint(_ProximityRipplesPainter oldDelegate) {
    return oldDelegate.animate != animate ||
        oldDelegate.animation != animation ||
        oldDelegate.orbCenterListenable != orbCenterListenable;
  }
}

/// 224px hero stage with progress ring, glowing top cap, and 184px glass sphere.
class _LiveOrb extends StatelessWidget {
  final int verifiedCount;
  final int totalExpected;

  const _LiveOrb({
    super.key,
    required this.verifiedCount,
    required this.totalExpected,
  });

  @override
  Widget build(BuildContext context) {
    final double progress = totalExpected > 0
        ? (verifiedCount / totalExpected).clamp(0.0, 1.0)
        : 0.0;

    return Semantics(
      label: '$verifiedCount of $totalExpected students detected',
      container: true,
      excludeSemantics: true,
      child: RepaintBoundary(
        child: SizedBox(
          width: _LiveTheme.orbStageSize,
          height: _LiveTheme.orbStageSize,
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: [
              // Zero-blur radial ambient indigo shadow beneath the sphere
              Positioned(
                top: 24.0,
                child: IgnorePointer(
                  child: Container(
                    width: 224.0,
                    height: 224.0,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          _LiveTheme.indigoDeep.withValues(alpha: 0.52),
                          _LiveTheme.indigoDeep.withValues(alpha: 0.22),
                          _LiveTheme.indigoDeep.withValues(alpha: 0.0),
                        ],
                        stops: const [0.0, 0.55, 1.0],
                      ),
                    ),
                  ),
                ),
              ),
              // Outer track ring, proportional progress arc, and glowing top start cap
              CustomPaint(
                size: const Size(
                  _LiveTheme.orbStageSize,
                  _LiveTheme.orbStageSize,
                ),
                painter: _OrbRingPainter(progress: progress),
              ),
              // 184px Glass Sphere
              SizedBox(
                width: _LiveTheme.orbSphereSize,
                height: _LiveTheme.orbSphereSize,
                child: ClipOval(
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // Radial glass sphere gradient + inner rim lighting
                      Positioned.fill(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: const RadialGradient(
                              center: Alignment(-0.4, -0.72), // 30%, 14%
                              radius: 0.90,
                              colors: [
                                Color(0x61A5B4FC), // rgba(165,180,252,0.38)
                                Color(0x334F46E5), // rgba(79,70,229,0.20)
                                Color(0xB30E0E24), // rgba(14,14,36,0.70)
                              ],
                              stops: [0.0, 0.42, 1.0],
                            ),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.14),
                              width: 1.0,
                            ),
                          ),
                        ),
                      ),
                      // Top white 40% inner highlight & bottom black 35% inner shade
                      Positioned.fill(
                        child: CustomPaint(
                          painter: _OrbInnerRimPainter(),
                        ),
                      ),
                      // Soft specular crescent at top-left, rotated -24 deg
                      Positioned(
                        top: 14.0,
                        left: 20.0,
                        child: Transform.rotate(
                          angle: -24.0 * math.pi / 180.0,
                          child: CustomPaint(
                            size: const Size(74.0, 34.0),
                            painter: _SpecularCrescentPainter(),
                          ),
                        ),
                      ),
                      // Center count readout
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 18.0),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.baseline,
                                textBaseline: TextBaseline.alphabetic,
                                children: [
                                  Text(
                                    '$verifiedCount',
                                    style: GoogleFonts.inter(
                                      fontSize: 84.0,
                                      fontWeight: FontWeight.w700,
                                      height: 0.96,
                                      letterSpacing: 84.0 * -0.055,
                                      color: _LiveTheme.textPrimary,
                                      fontFeatures: const [
                                        FontFeature.tabularFigures(),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 4.0),
                                  Text(
                                    '/ $totalExpected',
                                    style: GoogleFonts.inter(
                                      fontSize: 24.0,
                                      fontWeight: FontWeight.w600,
                                      color: _LiveTheme.textMuted50,
                                      fontFeatures: const [
                                        FontFeature.tabularFigures(),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 6.0),
                            Text(
                              'students detected',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.inter(
                                fontSize: 13.0,
                                fontWeight: FontWeight.w400,
                                color: _LiveTheme.textMuted66,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OrbRingPainter extends CustomPainter {
  final double progress;

  const _OrbRingPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final Offset center = Offset(size.width / 2.0, size.height / 2.0);
    final double radius = (size.width / 2.0) - 10.0;

    // Outer thin ring (stroke 5, white 9%)
    final Paint trackPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = _LiveTheme.orbOuterRingStroke
      ..color = Colors.white.withValues(alpha: 0.09);
    canvas.drawCircle(center, radius, trackPaint);

    // Proportional indigo progress arc starting from 12 o'clock
    if (progress > 0.0) {
      final Rect arcRect = Rect.fromCircle(center: center, radius: radius);
      final double sweepAngle = 2.0 * math.pi * progress;
      final Paint arcPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = _LiveTheme.orbOuterRingStroke
        ..strokeCap = StrokeCap.round
        ..shader = const SweepGradient(
          startAngle: -math.pi / 2.0,
          endAngle: 1.5 * math.pi,
          colors: [
            _LiveTheme.accentLight,
            _LiveTheme.accent,
            _LiveTheme.indigoRipple,
          ],
          stops: [0.0, 0.5, 1.0],
        ).createShader(arcRect);
      canvas.drawArc(
        arcRect,
        -math.pi / 2.0,
        sweepAngle,
        false,
        arcPaint,
      );
    }

    // Glowing start cap at the top (radial gradient halo + #C7D2FE cap + white highlight dot)
    final Offset topCap = Offset(center.dx, center.dy - radius);
    final Rect glowRect = Rect.fromCircle(center: topCap, radius: 14.0);
    final Paint capGlowPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          _LiveTheme.accentLight.withValues(alpha: 0.70),
          _LiveTheme.accentLight.withValues(alpha: 0.22),
          _LiveTheme.accentLight.withValues(alpha: 0.0),
        ],
        stops: const [0.0, 0.45, 1.0],
      ).createShader(glowRect);
    canvas.drawCircle(topCap, 14.0, capGlowPaint);

    final Paint capCorePaint = Paint()..color = _LiveTheme.accentLight;
    canvas.drawCircle(topCap, 5.5, capCorePaint);

    final Paint capHighlightDot = Paint()..color = Colors.white;
    canvas.drawCircle(topCap + const Offset(-1.2, -1.2), 2.1, capHighlightDot);
  }

  @override
  bool shouldRepaint(_OrbRingPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}

class _OrbInnerRimPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final Rect rect = Offset.zero & size;
    final Rect insetRect = rect.deflate(0.8);

    // Top inner highlight (white 40%)
    final Paint topHighlight = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Colors.white.withValues(alpha: 0.40),
          Colors.transparent,
        ],
        stops: const [0.0, 0.38],
      ).createShader(insetRect);
    canvas.drawArc(insetRect, -math.pi * 0.9, math.pi * 0.8, false, topHighlight);

    // Bottom inner shade (black 35%)
    final Paint bottomShade = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.5
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Colors.transparent,
          Colors.black.withValues(alpha: 0.35),
        ],
        stops: const [0.58, 1.0],
      ).createShader(insetRect);
    canvas.drawArc(insetRect, math.pi * 0.1, math.pi * 0.8, false, bottomShade);
  }

  @override
  bool shouldRepaint(_OrbInnerRimPainter oldDelegate) => false;
}

class _SpecularCrescentPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final Rect ovalRect = Offset.zero & size;
    final Paint crescentPaint = Paint()
      ..shader = RadialGradient(
        center: const Alignment(0.0, -0.35),
        radius: 0.9,
        colors: [
          Colors.white.withValues(alpha: 0.30),
          Colors.white.withValues(alpha: 0.12),
          Colors.white.withValues(alpha: 0.0),
        ],
        stops: const [0.0, 0.55, 1.0],
      ).createShader(ovalRect);

    canvas.drawOval(ovalRect, crescentPaint);
  }

  @override
  bool shouldRepaint(_SpecularCrescentPainter oldDelegate) => false;
}
