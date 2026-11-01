import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';


class CustomCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final Color? color;
  final VoidCallback? onTap;
  final bool hasGradient;
  final Gradient? gradient;
  final double borderRadius;
  final bool hasShadow;

  const CustomCard({
    Key? key,
    required this.child,
    this.padding,
    this.color,
    this.onTap,
    this.hasGradient = false,
    this.gradient,
    this.borderRadius = 24,
    this.hasShadow = true,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    Widget card = Container(
      padding: padding ?? const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: hasGradient
            ? null
            : (color ?? Theme.of(context).cardTheme.color ?? Theme.of(context).colorScheme.surface),
        gradient: hasGradient
            ? (gradient ??
                (isDark
                    ? const LinearGradient(
                        colors: [Color(0xFF1E293B), Color(0xFF0F172A)],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      )
                    : LinearGradient(
                        colors: [Theme.of(context).colorScheme.surface, Theme.of(context).colorScheme.surface],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      )))
            : null,
        borderRadius: BorderRadius.circular(borderRadius),
        boxShadow: hasShadow ? [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 20,
            offset: const Offset(0, 10),
          )
        ] : null,
      ),
      child: child,
    );

    if (onTap != null) {
      card = Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(borderRadius),
          child: card,
        ),
      );
    }

    // Fade-up entry animation
    return card
        .animate()
        .fadeIn(duration: 400.ms, curve: Curves.easeOut)
        .slideY(
            begin: 0.1, end: 0, duration: 400.ms, curve: Curves.easeOutCubic);
  }
}
