import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/animation_constants.dart';

/// Lightweight, 120Hz-friendly animated radio wave indicator for Bluetooth status.
///
/// Uses pure [Transform.scale] and [Opacity] with a single shared [AnimationController].
/// Strictly avoids Gaussian blur or expensive shaders to maintain the 8.33ms frame budget.
/// Automatically falls back to static indicators when reduced-motion is requested.
class BluetoothWave extends StatefulWidget {
  final bool isActive;
  final double size;
  final Color activeColor;

  const BluetoothWave({
    Key? key,
    required this.isActive,
    this.size = 32.0,
    this.activeColor = const Color(0xFF6366F1),
  }) : super(key: key);

  @override
  State<BluetoothWave> createState() => _BluetoothWaveState();
}

class _BluetoothWaveState extends State<BluetoothWave>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    );
    if (widget.isActive) {
      _controller.repeat();
    }
  }

  @override
  void didUpdateWidget(covariant BluetoothWave oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive != oldWidget.isActive) {
      if (widget.isActive) {
        _controller.repeat();
      } else {
        _controller.stop();
        _controller.reset();
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isReducedMotion = AnimationConstants.isReducedMotion(context);

    if (!widget.isActive || isReducedMotion) {
      return SizedBox(
        width: widget.size,
        height: widget.size,
        child: Center(
          child: Icon(
            widget.isActive
                ? Icons.bluetooth_audio_rounded
                : Icons.bluetooth_disabled_rounded,
            size: widget.size * 0.7,
            color: widget.isActive ? widget.activeColor : AppColors.textSecondary,
          ),
        ),
      );
    }

    return RepaintBoundary(
      child: SizedBox(
        width: widget.size,
        height: widget.size,
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Wave 1 (Outer pulse)
            AnimatedBuilder(
              animation: _controller,
              builder: (context, child) {
                final progress = (_controller.value + 0.5) % 1.0;
                final scale = 0.6 + (progress * 0.6);
                final opacity = (1.0 - progress).clamp(0.0, 0.7);

                return Transform.scale(
                  scale: scale,
                  child: Opacity(
                    opacity: opacity,
                    child: Container(
                      width: widget.size,
                      height: widget.size,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: widget.activeColor,
                          width: 1.5,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),

            // Wave 2 (Inner pulse)
            AnimatedBuilder(
              animation: _controller,
              builder: (context, child) {
                final progress = _controller.value;
                final scale = 0.5 + (progress * 0.5);
                final opacity = (1.0 - progress).clamp(0.0, 0.8);

                return Transform.scale(
                  scale: scale,
                  child: Opacity(
                    opacity: opacity,
                    child: Container(
                      width: widget.size * 0.85,
                      height: widget.size * 0.85,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: widget.activeColor,
                          width: 1.5,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),

            // Center Bluetooth Glyph
            Icon(
              Icons.bluetooth_audio_rounded,
              size: widget.size * 0.65,
              color: widget.activeColor,
            ),
          ],
        ),
      ),
    );
  }
}
