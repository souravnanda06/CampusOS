import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class ShimmeringText extends StatefulWidget {
  final String text;
  final TextStyle style;

  const ShimmeringText({
    super.key,
    required this.text,
    required this.style,
  });

  @override
  State<ShimmeringText> createState() => _ShimmeringTextState();
}

class _ShimmeringTextState extends State<ShimmeringText>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3500),
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
        return ShaderMask(
          shaderCallback: (bounds) {
            return LinearGradient(
              colors: const [
                Colors.white30,
                Colors.white,
                Colors.white30,
              ],
              stops: const [0.0, 0.5, 1.0],
              begin: Alignment(-1.0 + (_controller.value * 3), 0.0),
              end: Alignment(1.0 + (_controller.value * 3), 0.0),
              tileMode: TileMode.clamp,
            ).createShader(bounds);
          },
          child: Text(
            widget.text,
            style: widget.style.copyWith(
              color: Colors.white, // Required for ShaderMask
              fontFamily: GoogleFonts.outfit().fontFamily,
            ),
          ),
        );
      },
    );
  }
}
