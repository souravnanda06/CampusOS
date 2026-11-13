import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import '../../../core/haptics/app_haptics.dart';

/// An Apple iOS / visionOS style physics-driven tactile spring-bounce wrapper.
///
/// Uses true [SpringSimulation] with critically-damped mass/stiffness physics
/// to deliver fluid, zero-lag compression on tap-down, velocity-preserving
/// rebound on release, and full support for Apple's Reduce Motion accessibility.
class AppleBounceable extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final double scaleFactor;
  final bool enableHaptic;
  final HitTestBehavior behavior;

  const AppleBounceable({
    Key? key,
    required this.child,
    this.onTap,
    this.onLongPress,
    this.scaleFactor = 0.96,
    this.enableHaptic = true,
    this.behavior = HitTestBehavior.opaque,
  }) : super(key: key);

  @override
  State<AppleBounceable> createState() => _AppleBounceableState();
}

class _AppleBounceableState extends State<AppleBounceable>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late Animation<double> _scaleAnimation;

  // Apple UIKit / SwiftUI standard interactive spring parameters:
  // Critically-damped, snappy response without artificial wobble
  static const _pressSpring = SpringDescription(
    mass: 1.0,
    stiffness: 550.0,
    damping: 30.0,
  );

  static const _releaseSpring = SpringDescription(
    mass: 1.0,
    stiffness: 420.0,
    damping: 24.0,
  );

  @override
  void initState() {
    super.initState();
    _controller = AnimationController.unbounded(vsync: this, value: 0.0);
    _scaleAnimation = _controller.drive(
      Tween<double>(begin: 1.0, end: widget.scaleFactor),
    );
  }

  @override
  void didUpdateWidget(covariant AppleBounceable oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.scaleFactor != widget.scaleFactor) {
      _scaleAnimation = _controller.drive(
        Tween<double>(begin: 1.0, end: widget.scaleFactor),
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  bool _isReducedMotion(BuildContext context) {
    return MediaQuery.maybeDisableAnimationsOf(context) ?? false;
  }

  void _onTapDown(TapDownDetails details) {
    if (widget.onTap == null && widget.onLongPress == null) return;
    if (widget.enableHaptic) {
      AppHaptics.selectionClick();
    }
    if (_isReducedMotion(context)) {
      _controller.value = 0.0;
      return;
    }
    final sim = SpringSimulation(
      _pressSpring,
      _controller.value,
      1.0,
      _controller.velocity,
    );
    _controller.animateWith(sim);
  }

  void _onTapUp(TapUpDetails details) {
    if (widget.onTap == null) return;
    if (_isReducedMotion(context)) {
      _controller.value = 0.0;
    } else {
      final sim = SpringSimulation(
        _releaseSpring,
        _controller.value,
        0.0,
        _controller.velocity,
      );
      _controller.animateWith(sim);
    }
    widget.onTap?.call();
  }

  void _onTapCancel() {
    if (_isReducedMotion(context)) {
      _controller.value = 0.0;
    } else {
      final sim = SpringSimulation(
        _releaseSpring,
        _controller.value,
        0.0,
        _controller.velocity,
      );
      _controller.animateWith(sim);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isInteractive = widget.onTap != null || widget.onLongPress != null;
    final isReduced = _isReducedMotion(context);
    return GestureDetector(
      behavior: widget.behavior,
      onTapDown: isInteractive ? _onTapDown : null,
      onTapUp: isInteractive ? _onTapUp : null,
      onTapCancel: isInteractive ? _onTapCancel : null,
      onLongPress: widget.onLongPress != null
          ? () {
              if (widget.enableHaptic) AppHaptics.mediumImpact();
              widget.onLongPress?.call();
            }
          : null,
      child: AnimatedBuilder(
        animation: _scaleAnimation,
        builder: (context, child) => Transform.scale(
          scale: isReduced ? 1.0 : _scaleAnimation.value,
          alignment: Alignment.center,
          child: child,
        ),
        child: widget.child,
      ),
    );
  }
}

/// Extension enabling fluid spring bounce behavior on any widget.
extension AppleBounceableExtension on Widget {
  Widget bounceable({
    VoidCallback? onTap,
    VoidCallback? onLongPress,
    double scaleFactor = 0.96,
    bool enableHaptic = true,
    HitTestBehavior behavior = HitTestBehavior.opaque,
  }) {
    return AppleBounceable(
      onTap: onTap,
      onLongPress: onLongPress,
      scaleFactor: scaleFactor,
      enableHaptic: enableHaptic,
      behavior: behavior,
      child: this,
    );
  }
}
