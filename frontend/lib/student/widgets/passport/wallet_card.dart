import 'package:flutter/material.dart';
import 'package:attendance_app/core/haptics/app_haptics.dart';

/// Base credential card surface container for CampusOS Wallet.
///
/// Features:
/// - Crisp, clean, flat card surface matching modern minimalist fintech aesthetics
/// - 24dp rounded corners matching the flagship CampusOS design
/// - Layered soft shadows & subtle hairline border
/// - Responsive tactile tap feedback
class WalletCardContainer extends StatelessWidget {
  final Widget child;
  final Gradient? gradient;
  final Color? surfaceColor;
  final Border? border;
  final VoidCallback? onTap;
  final double elevation;
  final bool isInteractive;
  final bool isDarkSurface;
  final EdgeInsetsGeometry? padding;
  final bool enableTilt;

  const WalletCardContainer({
    Key? key,
    required this.child,
    this.gradient,
    this.surfaceColor,
    this.border,
    this.onTap,
    this.elevation = 8.0,
    this.isInteractive = true,
    this.isDarkSurface = true,
    this.padding,
    this.enableTilt = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final effectiveBorder = border ??
        Border.all(
          color: isDarkSurface
              ? Colors.white.withValues(alpha: 0.12)
              : Colors.black.withValues(alpha: 0.08),
          width: 1.0,
        );

    final card = Container(
      width: double.infinity,
      constraints: const BoxConstraints(
        minHeight: 195,
        maxHeight: 210,
      ),
      decoration: BoxDecoration(
        color: surfaceColor ??
            (gradient == null ? const Color(0xFF141829) : null),
        gradient: gradient,
        borderRadius: BorderRadius.circular(24),
        border: effectiveBorder,
        boxShadow: [
          BoxShadow(
            color: isDarkSurface
                ? Colors.black.withValues(alpha: 0.32)
                : const Color(0xFF0F172A).withValues(alpha: 0.07),
            blurRadius: 24,
            offset: const Offset(0, 10),
            spreadRadius: -2,
          ),
          BoxShadow(
            color: isDarkSurface
                ? Colors.black.withValues(alpha: 0.16)
                : const Color(0xFF0F172A).withValues(alpha: 0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Padding(
          padding: padding ?? const EdgeInsets.all(18),
          child: child,
        ),
      ),
    );

    if (!isInteractive || onTap == null) {
      return card;
    }

    return GestureDetector(
      onTap: () {
        AppHaptics.selectionClick();
        onTap!();
      },
      behavior: HitTestBehavior.opaque,
      child: card,
    );
  }
}
