import 'package:flutter/material.dart';

class SuccessCheckAnimation extends StatefulWidget {
  const SuccessCheckAnimation({super.key});

  @override
  State<SuccessCheckAnimation> createState() => _SuccessCheckAnimationState();
}

class _SuccessCheckAnimationState extends State<SuccessCheckAnimation>
    with TickerProviderStateMixin {
  late AnimationController _scale;
  late AnimationController _ripple;

  @override
  void initState() {
    super.initState();

    _scale = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );

    _ripple = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    _scale.forward();
    _ripple.forward();
  }

  @override
  void dispose() {
    _scale.dispose();
    _ripple.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        // Ripple effect
        AnimatedBuilder(
          animation: _ripple,
          builder: (_, child) {
            final v = _ripple.value;
            return Container(
              width: 140 * v,
              height: 140 * v,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color:
                    const Color(0xFF3AD875).withValues(alpha: (1 - v) * 0.15),
              ),
            );
          },
        ),

        // Central success icon
        ScaleTransition(
          scale: Tween<double>(begin: 0.2, end: 1.0)
              .chain(CurveTween(curve: Curves.easeOutBack))
              .animate(_scale),
          child: Container(
            width: 110,
            height: 110,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                colors: [
                  Color(0xFF3AD875),
                  Color(0xFF52E68E),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: [
                BoxShadow(
                  blurRadius: 20,
                  color: const Color(0xFF3AD875).withValues(alpha: 0.4),
                  offset: const Offset(0, 8),
                )
              ],
            ),
            child:
                const Icon(Icons.check_rounded, size: 56, color: Colors.white),
          ),
        ),
      ],
    );
  }
}
