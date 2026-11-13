part of '../screens/broadcasting_screen.dart';

/// Shared Apple-style continuous-corner glass surface with optional BackdropFilter.
///
/// Uses translucent gradient fill + 1px inner border + 1px top highlight.
/// BackdropFilter and ClipPath are only allocated when [useBlur] is true AND
/// [_LiveTheme.enableGlassBlur] is enabled; otherwise ShapeDecoration renders
/// directly with zero offscreen saveLayer allocations.
class _LiveGlassSurface extends StatelessWidget {
  final Widget child;
  final double radius;
  final bool isCircle;
  final bool useBlur;
  final EdgeInsetsGeometry? padding;
  final double? width;
  final double? height;
  final Color? fillTop;
  final Color? fillBottom;
  final Color? borderColor;
  final Color? topHighlightColor;

  const _LiveGlassSurface({
    required this.child,
    this.radius = 22.0,
    this.isCircle = false,
    this.useBlur = false,
    this.padding,
    this.width,
    this.height,
    this.fillTop,
    this.fillBottom,
    this.borderColor,
    this.topHighlightColor,
  });

  @override
  Widget build(BuildContext context) {
    final ShapeBorder shape = isCircle
        ? const CircleBorder()
        : ContinuousRectangleBorder(
            borderRadius: BorderRadius.circular(radius),
          );

    final effectiveBorder = borderColor ?? _LiveTheme.glassBorder;
    final effectiveTop = fillTop ?? _LiveTheme.glassFillTop;
    final effectiveBottom = fillBottom ?? _LiveTheme.glassFillBottom;
    final effectiveHighlight = topHighlightColor ?? _LiveTheme.glassTopHighlight;

    final Widget surface = CustomPaint(
      foregroundPainter: _GlassEdgePainter(
        isCircle: isCircle,
        radius: radius,
        borderColor: effectiveBorder,
        topHighlightColor: effectiveHighlight,
      ),
      child: Container(
        width: width,
        height: height,
        padding: padding,
        decoration: ShapeDecoration(
          shape: shape,
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [effectiveTop, effectiveBottom],
          ),
        ),
        child: child,
      ),
    );

    if (useBlur && _LiveTheme.enableGlassBlur) {
      return ClipPath(
        clipper: ShapeBorderClipper(shape: shape),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 16.0, sigmaY: 16.0),
          child: surface,
        ),
      );
    }

    return surface;
  }
}

class _GlassEdgePainter extends CustomPainter {
  final bool isCircle;
  final double radius;
  final Color borderColor;
  final Color topHighlightColor;

  const _GlassEdgePainter({
    required this.isCircle,
    required this.radius,
    required this.borderColor,
    required this.topHighlightColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final borderPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0
      ..color = borderColor;

    if (isCircle) {
      final center = rect.center;
      final r = (math.min(size.width, size.height) / 2.0) - 0.5;
      if (r <= 0) return;
      canvas.drawCircle(center, r, borderPaint);

      final topHighlightPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [topHighlightColor, Colors.transparent],
          stops: const [0.0, 0.45],
        ).createShader(rect);
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: r),
        -math.pi * 0.85,
        math.pi * 0.7,
        false,
        topHighlightPaint,
      );
      return;
    }

    final shape = ContinuousRectangleBorder(
      borderRadius: BorderRadius.circular(radius),
    );
    final innerRect = rect.deflate(0.5);
    final path = shape.getOuterPath(innerRect);
    canvas.drawPath(path, borderPaint);

    final highlightPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [topHighlightColor, Colors.transparent],
        stops: const [0.0, 0.25],
      ).createShader(innerRect);
    canvas.drawPath(path, highlightPaint);
  }

  @override
  bool shouldRepaint(_GlassEdgePainter oldDelegate) {
    return oldDelegate.isCircle != isCircle ||
        oldDelegate.radius != radius ||
        oldDelegate.borderColor != borderColor ||
        oldDelegate.topHighlightColor != topHighlightColor;
  }
}

/// Interactive press wrapper with 0.95 scale (200ms), haptics, Semantics,
/// and guaranteed minimum 44x44 tap target.
class _TactilePress extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final void Function(DragEndDetails)? onVerticalDragEnd;
  final String? semanticsLabel;
  final VoidCallback? onHaptic;
  final double minWidth;
  final double minHeight;

  const _TactilePress({
    required this.child,
    this.onTap,
    this.onVerticalDragEnd,
    this.semanticsLabel,
    this.onHaptic,
    this.minWidth = 44.0,
    this.minHeight = 44.0,
  });

  @override
  State<_TactilePress> createState() => _TactilePressState();
}

class _TactilePressState extends State<_TactilePress> {
  bool _isPressed = false;

  void _setPressed(bool value) {
    if (_isPressed == value) return;
    setState(() => _isPressed = value);
  }

  @override
  Widget build(BuildContext context) {
    final reducedMotion = AnimationConstants.isReducedMotion(context);
    final duration = reducedMotion ? Duration.zero : _LiveTheme.pressDuration;

    return Semantics(
      button: widget.onTap != null,
      label: widget.semanticsLabel,
      excludeSemantics: widget.semanticsLabel != null,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: widget.onTap != null ? (_) => _setPressed(true) : null,
        onTapUp: widget.onTap != null ? (_) => _setPressed(false) : null,
        onTapCancel: widget.onTap != null ? () => _setPressed(false) : null,
        onVerticalDragEnd: widget.onVerticalDragEnd,
        onTap: widget.onTap != null
            ? () {
                (widget.onHaptic ?? AppHaptics.selectionClick)();
                widget.onTap!();
              }
            : null,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            minWidth: widget.minWidth,
            minHeight: widget.minHeight,
          ),
          child: Center(
            widthFactor: 1.0,
            heightFactor: 1.0,
            child: AnimatedScale(
              scale: _isPressed && !reducedMotion ? _LiveTheme.pressScale : 1.0,
              duration: duration,
              curve: Curves.easeOutCubic,
              child: widget.child,
            ),
          ),
        ),
      ),
    );
  }
}

/// Zero-rebuild pulsing status indicator dot painted directly via CustomPainter.
class _PulsingDot extends StatelessWidget {
  final Color color;
  final double size;
  final Animation<double> animation;
  final bool isPulsing;
  final bool showPingRing;

  const _PulsingDot({
    required this.color,
    required this.animation,
    this.size = 8.0,
    this.isPulsing = true,
    this.showPingRing = false,
  });

  @override
  Widget build(BuildContext context) {
    final reducedMotion = AnimationConstants.isReducedMotion(context);
    final bool animate = isPulsing && !reducedMotion;

    return RepaintBoundary(
      child: SizedBox(
        width: size,
        height: size,
        child: CustomPaint(
          painter: _PulsingDotPainter(
            animation: animation,
            color: color,
            animate: animate,
            showPingRing: showPingRing,
          ),
        ),
      ),
    );
  }
}

class _PulsingDotPainter extends CustomPainter {
  final Animation<double> animation;
  final Color color;
  final bool animate;
  final bool showPingRing;

  _PulsingDotPainter({
    required this.animation,
    required this.color,
    required this.animate,
    required this.showPingRing,
  }) : super(repaint: animate ? animation : null);

  @override
  void paint(Canvas canvas, Size size) {
    final Offset center = Offset(size.width / 2.0, size.height / 2.0);
    final double baseRadius = math.min(size.width, size.height) / 2.0;

    if (!animate) {
      canvas.drawCircle(center, baseRadius, Paint()..color = color);
      return;
    }

    final double t = animation.value;
    if (showPingRing) {
      final double pingRadius = baseRadius * (1.0 + t * 1.45);
      final double pingOpacity = (1.0 - t).clamp(0.0, 1.0) * 0.55;
      if (pingOpacity > 0.01) {
        canvas.drawCircle(
          center,
          pingRadius,
          Paint()..color = color.withValues(alpha: pingOpacity),
        );
      }
      canvas.drawCircle(center, baseRadius, Paint()..color = color);
      return;
    }

    final double coreOpacity =
        0.55 + 0.45 * (0.5 + 0.5 * math.sin(t * 2.0 * math.pi));
    canvas.drawCircle(
      center,
      baseRadius,
      Paint()..color = color.withValues(alpha: coreOpacity),
    );
  }

  @override
  bool shouldRepaint(_PulsingDotPainter oldDelegate) {
    return oldDelegate.color != color ||
        oldDelegate.animate != animate ||
        oldDelegate.showPingRing != showPingRing ||
        oldDelegate.animation != animation;
  }
}

/// Entrance fade + 12px rise wrapper with 700ms Cubic(0.2, 0.8, 0.2, 1) and stagger.
/// Short-circuits directly to [child] once finished so no Opacity/Transform layers linger.
class _SectionEntrance extends StatelessWidget {
  final Animation<double> controller;
  final int index;
  final Widget child;

  const _SectionEntrance({
    required this.controller,
    required this.index,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    if (AnimationConstants.isReducedMotion(context) ||
        controller.status == AnimationStatus.completed) {
      return child;
    }

    final double start = ((index * 50) / 1000.0).clamp(0.0, 0.3);
    final double end = ((index * 50 + 700) / 1000.0).clamp(start + 0.1, 1.0);

    return AnimatedBuilder(
      animation: controller,
      builder: (context, builtChild) {
        final double raw =
            ((controller.value - start) / (end - start)).clamp(0.0, 1.0);
        if (raw >= 1.0) return builtChild!;
        final double curved = _LiveTheme.entranceCurve.transform(raw);
        return Opacity(
          opacity: curved,
          child: Transform.translate(
            offset: Offset(0, 12.0 * (1.0 - curved)),
            child: builtChild,
          ),
        );
      },
      child: child,
    );
  }
}
