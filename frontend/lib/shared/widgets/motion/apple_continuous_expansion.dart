import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../../../../core/haptics/app_haptics.dart';
import '../../../../core/performance/performance_engine.dart';
import 'apple_spring_curve.dart';
import 'apple_bounceable.dart';

/// Builder signature for the expanded full-screen content.
/// [dismiss] can be invoked to programmatically trigger the reverse collapse.
typedef AppleExpandedContentBuilder = Widget Function(
  BuildContext context,
  VoidCallback dismiss,
);

/// Apple HIG Continuous Expansion Transition widget.
///
/// Wraps any card or tile in the interface. When activated, the card
/// smoothly and continuously expands from its exact on-screen geometry
/// ([Rect]) into full-screen, interpolating position, size, corner radius,
/// elevation, and contents using authentic iOS Spring Physics.
///
/// Engineered for 60/120 FPS hardware-accelerated fluid performance:
/// - Fast-path [PhysicalModel] elevation (zero per-frame Gaussian blur filter convolution)
/// - Fixed-dimension constraints (zero layout thrashing or mid-flight rebuilds)
/// - Immediate pre-warmed element tree (zero insertion frame-drops)
/// - Luxurious, cinematic Apple HIG pacing (480ms forward, 380ms reverse)
/// - Rubber-band pull-down dismissal with haptic detent
class AppleContinuousExpansionCard extends StatefulWidget {
  /// The compact card preview rendered inline on the parent screen.
  final Widget child;

  /// Builder for the full-screen expanded presentation.
  final AppleExpandedContentBuilder expandedBuilder;

  /// The resting corner radius of the compact card.
  final double cardRadius;

  /// Optional background color of the expanding surface container.
  final Color? cardColor;

  /// If false, tapping does not trigger expansion (useful if triggering externally).
  final bool enabled;

  /// Optional callback invoked when the expansion starts.
  final VoidCallback? onExpand;

  /// Optional callback invoked when the card has completely collapsed back.
  final VoidCallback? onCollapse;

  const AppleContinuousExpansionCard({
    Key? key,
    required this.child,
    required this.expandedBuilder,
    this.cardRadius = 24.0,
    this.cardColor,
    this.enabled = true,
    this.onExpand,
    this.onCollapse,
  }) : super(key: key);

  @override
  State<AppleContinuousExpansionCard> createState() =>
      AppleContinuousExpansionCardState();
}

class AppleContinuousExpansionCardState
    extends State<AppleContinuousExpansionCard> {
  final GlobalKey _cardKey = GlobalKey();
  bool _isExpanded = false;

  /// Programmatically open the continuous expansion transition.
  void open() {
    if (!widget.enabled || !mounted || _isExpanded) return;

    final renderBox =
        _cardKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null || !renderBox.hasSize) return;

    final translation = renderBox.localToGlobal(Offset.zero);
    final sourceRect = translation & renderBox.size;

    widget.onExpand?.call();
    AppHaptics.lightImpact();

    setState(() {
      _isExpanded = true;
    });

    final reducedMotion =
        PerformanceEngine.instance.profile.animationProfile.reducedMotion;

    Navigator.of(context).push(
      PageRouteBuilder(
        opaque: false,
        barrierDismissible: true,
        barrierColor: Colors.transparent,
        // Luxurious fluid Apple HIG pacing: unhurried 480ms expand, 380ms collapse
        transitionDuration: reducedMotion
            ? const Duration(milliseconds: 200)
            : const Duration(milliseconds: 480),
        reverseTransitionDuration: reducedMotion
            ? const Duration(milliseconds: 180)
            : const Duration(milliseconds: 380),
        pageBuilder: (ctx, animation, secondaryAnimation) {
          return _AppleContinuousExpandedOverlay(
            sourceRect: sourceRect,
            cardRadius: widget.cardRadius,
            cardColor: widget.cardColor ?? Theme.of(context).cardColor,
            preview: widget.child,
            expandedBuilder: widget.expandedBuilder,
            animation: animation,
            reducedMotion: reducedMotion,
          );
        },
      ),
    ).then((_) {
      if (mounted) {
        setState(() {
          _isExpanded = false;
        });
      }
      widget.onCollapse?.call();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      key: _cardKey,
      child: AppleContinuousExpansionScope(
        state: this,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.enabled ? open : null,
          child: Visibility(
            visible: !_isExpanded,
            maintainSize: true,
            maintainAnimation: true,
            maintainState: true,
            child: widget.child,
          ),
        ),
      ),
    );
  }
}

/// InheritedWidget that provides access to the nearest [AppleContinuousExpansionCardState].
/// Descendants (such as [AppleContextMenu] or custom tap targets) can call:
/// `AppleContinuousExpansionScope.of(context).open();` or `maybeOf(context)`.
class AppleContinuousExpansionScope extends InheritedWidget {
  final AppleContinuousExpansionCardState state;

  const AppleContinuousExpansionScope({
    Key? key,
    required this.state,
    required Widget child,
  }) : super(key: key, child: child);

  static AppleContinuousExpansionCardState? maybeOf(BuildContext context) {
    return context
        .dependOnInheritedWidgetOfExactType<AppleContinuousExpansionScope>()
        ?.state;
  }

  static AppleContinuousExpansionCardState of(BuildContext context) {
    final scope = maybeOf(context);
    assert(scope != null, 'No AppleContinuousExpansionScope found in context');
    return scope!;
  }

  @override
  bool updateShouldNotify(covariant AppleContinuousExpansionScope oldWidget) =>
      state != oldWidget.state;
}

/// The overlay route that hosts the physical spring expansion and
/// the interactive pull-down drag gesture.
class _AppleContinuousExpandedOverlay extends StatefulWidget {
  final Rect sourceRect;
  final double cardRadius;
  final Color cardColor;
  final Widget preview;
  final AppleExpandedContentBuilder expandedBuilder;
  final Animation<double> animation;
  final bool reducedMotion;

  const _AppleContinuousExpandedOverlay({
    Key? key,
    required this.sourceRect,
    required this.cardRadius,
    required this.cardColor,
    required this.preview,
    required this.expandedBuilder,
    required this.animation,
    required this.reducedMotion,
  }) : super(key: key);

  @override
  State<_AppleContinuousExpandedOverlay> createState() =>
      _AppleContinuousExpandedOverlayState();
}

class _AppleContinuousExpandedOverlayState
    extends State<_AppleContinuousExpandedOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _dragController;
  Widget? _cachedExpandedWidget;
  Widget? _cachedPreviewWidget;
  Widget? _cachedCloseButton;

  late final Animation<double> _expansionAnimation;
  late final Animation<double> _previewFadeAnimation;
  late final Animation<double> _previewOpacityTween;
  late final Animation<double> _expandedFadeAnimation;
  late final Animation<double> _closeButtonFadeAnimation;
  late final Animation<double> _scrimFadeAnimation;

  double _dragOffsetY = 0.0;
  bool _isDragging = false;
  bool _hasTriggeredHapticDetent = false;

  // Authentic Apple iOS expansion curve: fluid acceleration with soft deceleration
  static const Curve _kExpansionCurve = Curves.easeOutCubic;
  static const Curve _kCollapseCurve = Curves.easeInCubic;

  @override
  void initState() {
    super.initState();
    _dragController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
    );

    // Natural fluid easing for physical expansion
    _expansionAnimation = CurvedAnimation(
      parent: widget.animation,
      curve: _kExpansionCurve,
      reverseCurve: _kCollapseCurve,
    );

    // Elegant, smooth cross-fade: preview fades out gracefully in initial expansion
    _previewFadeAnimation = CurvedAnimation(
      parent: widget.animation,
      curve: const Interval(0.0, 0.24, curve: Curves.easeOut),
      reverseCurve: const Interval(0.0, 0.24, curve: Curves.easeIn),
    );
    _previewOpacityTween =
        Tween<double>(begin: 1.0, end: 0.0).animate(_previewFadeAnimation);

    // Smooth, natural fade-in for expanded content: settles cleanly into full opacity
    _expandedFadeAnimation = CurvedAnimation(
      parent: widget.animation,
      curve: const Interval(0.06, 0.28, curve: Curves.easeIn),
      reverseCurve: const Interval(0.06, 0.28, curve: Curves.easeOut),
    );

    // Floating close button reveal towards completion
    _closeButtonFadeAnimation = CurvedAnimation(
      parent: widget.animation,
      curve: const Interval(0.60, 1.0, curve: Curves.easeOut),
      reverseCurve: const Interval(0.60, 1.0, curve: Curves.easeIn),
    );

    // Ambient scrim backdrop
    _scrimFadeAnimation = CurvedAnimation(
      parent: widget.animation,
      curve: const Interval(0.0, 0.40, curve: Curves.easeOut),
      reverseCurve: const Interval(0.0, 0.40, curve: Curves.easeIn),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Pre-warm and isolate all subtrees into GPU texture caches from Frame 0
    _cachedExpandedWidget ??= RepaintBoundary(
      child: widget.expandedBuilder(context, _handleDismiss),
    );
    _cachedPreviewWidget ??= RepaintBoundary(
      child: IgnorePointer(child: widget.preview),
    );
    _cachedCloseButton ??= AppleBounceable(
      scaleFactor: 0.88,
      onTap: _handleDismiss,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.black.withValues(alpha: 0.54),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.24),
            width: 1.0,
          ),
          boxShadow: const [
            BoxShadow(
              color: Colors.black26,
              blurRadius: 6.0,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: const Center(
          child: Icon(
            Icons.close_rounded,
            size: 18,
            color: Colors.white,
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _dragController.dispose();
    super.dispose();
  }

  void _handleDismiss() {
    AppHaptics.lightImpact();
    Navigator.of(context).maybePop();
  }

  void _onVerticalDragStart(DragStartDetails details) {
    _isDragging = true;
    _hasTriggeredHapticDetent = false;
    _dragController.stop();
  }

  void _onVerticalDragUpdate(DragUpdateDetails details) {
    if (!_isDragging) return;
    final delta = details.delta.dy;
    if (_dragOffsetY + delta >= 0) {
      // iOS asymptotic rubber-band damping resistance
      final progress = (_dragOffsetY / 400.0).clamp(0.0, 1.0);
      final damping = 1.0 - (progress * 0.55);
      final newOffset = _dragOffsetY + (delta * damping);

      // Tactile haptic detent upon crossing dismissal threshold
      if (newOffset > 90 && !_hasTriggeredHapticDetent) {
        _hasTriggeredHapticDetent = true;
        AppHaptics.selectionClick();
      } else if (newOffset <= 90 && _hasTriggeredHapticDetent) {
        _hasTriggeredHapticDetent = false;
      }

      setState(() {
        _dragOffsetY = newOffset;
      });
    }
  }

  void _onVerticalDragEnd(DragEndDetails details) {
    _isDragging = false;
    final velocity = details.primaryVelocity ?? 0.0;
    // Dismiss threshold: dragged > 90 dp or flicked downward > 600 px/s
    if (_dragOffsetY > 90 || velocity > 600) {
      _handleDismiss();
    } else {
      // Fluid spring snap back to full-screen
      AppHaptics.selectionClick();
      final currentOffset = _dragOffsetY;
      final anim = Tween<double>(begin: currentOffset, end: 0.0).animate(
        CurvedAnimation(
          parent: _dragController,
          curve: AppleSpringCurve.bouncy,
        ),
      );
      anim.addListener(() {
        if (mounted) {
          setState(() {
            _dragOffsetY = anim.value;
          });
        }
      });
      _dragController.forward(from: 0.0);
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final targetRect =
        Rect.fromLTWH(0, 0, screenSize.width, screenSize.height);

    if (widget.reducedMotion) {
      return _buildReducedMotionView(context);
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        // 1. Ambient Backdrop Scrim (Hardware composited, zero widget rebuilds)
        FadeTransition(
          opacity: _scrimFadeAnimation,
          child: GestureDetector(
            onTap: _handleDismiss,
            behavior: HitTestBehavior.opaque,
            child: const ColoredBox(
              color: Colors.black54,
            ),
          ),
        ),

        // 2. Hardware-accelerated Expanding Card Container
        AnimatedBuilder(
          animation: widget.animation,
          builder: (context, _) {
            final double t = _expansionAnimation.value;

            // Interpolate geometry
            final Rect currentRect =
                Rect.lerp(widget.sourceRect, targetRect, t)!;
            final double radius = ui.lerpDouble(
              widget.cardRadius,
              0.0,
              t,
            )!;

            // Interactive pull-down rubber-band scale & radius
            final double dragProgress =
                (_dragOffsetY / 400.0).clamp(0.0, 1.0);
            final double interactiveScale = 1.0 - (dragProgress * 0.08);
            final double interactiveRadius =
                radius + (dragProgress * widget.cardRadius);

            // Fast-path hardware shadow elevation: 0 at full-screen, subtle in-flight
            final double currentElevation = ui.lerpDouble(
              _isDragging ? 12.0 : 4.0,
              0.0,
              t,
            )!;

            return Positioned.fromRect(
              rect: Rect.fromLTWH(
                currentRect.left,
                currentRect.top + _dragOffsetY,
                currentRect.width,
                currentRect.height,
              ),
              child: Transform.scale(
                scale: interactiveScale,
                alignment: Alignment.center,
                child: GestureDetector(
                  onVerticalDragStart: _onVerticalDragStart,
                  onVerticalDragUpdate: _onVerticalDragUpdate,
                  onVerticalDragEnd: _onVerticalDragEnd,
                  child: PhysicalModel(
                    color: widget.cardColor,
                    borderRadius: BorderRadius.circular(interactiveRadius),
                    elevation: currentElevation,
                    clipBehavior: Clip.antiAlias,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        // Full-Screen Expanded View (Always laid out at fixed target size)
                        Positioned(
                          top: 0,
                          left: 0,
                          width: targetRect.width,
                          height: targetRect.height,
                          child: FadeTransition(
                            opacity: _expandedFadeAnimation,
                            child: _cachedExpandedWidget!,
                          ),
                        ),

                        // Compact Preview (Always laid out at fixed source size, zero re-layout)
                        if (_previewFadeAnimation.value < 1.0)
                          Positioned(
                            top: 0,
                            left: 0,
                            width: widget.sourceRect.width,
                            height: widget.sourceRect.height,
                            child: FadeTransition(
                              opacity: _previewOpacityTween,
                              child: _cachedPreviewWidget!,
                            ),
                          ),

                        // Floating Apple Close Button (Permanent tree node, zero insertion jank)
                        Positioned(
                          top: MediaQuery.of(context).padding.top + 12,
                          right: 18,
                          child: FadeTransition(
                            opacity: _closeButtonFadeAnimation,
                            child: IgnorePointer(
                              ignoring: _closeButtonFadeAnimation.value < 0.8,
                              child: _cachedCloseButton!,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildReducedMotionView(BuildContext context) {
    return FadeTransition(
      opacity: widget.animation,
      child: Material(
        color: widget.cardColor,
        child: Stack(
          fit: StackFit.expand,
          children: [
            widget.expandedBuilder(context, _handleDismiss),
            Positioned(
              top: MediaQuery.of(context).padding.top + 12,
              right: 18,
              child: AppleBounceable(
                scaleFactor: 0.88,
                onTap: _handleDismiss,
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.black.withValues(alpha: 0.52),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.22),
                      width: 1.0,
                    ),
                  ),
                  child: const Center(
                    child: Icon(
                      Icons.close_rounded,
                      size: 18,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
