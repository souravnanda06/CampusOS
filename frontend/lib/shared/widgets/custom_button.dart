import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';


class CustomButton extends StatelessWidget {
  final String text;
  final VoidCallback onPressed;
  final bool isLoading;
  final Color? backgroundColor;
  final Color? textColor;
  final IconData? icon;
  final bool isPrimary;
  final bool hasPulse; // For BLE broadcast button

  const CustomButton({
    Key? key,
    required this.text,
    required this.onPressed,
    this.isLoading = false,
    this.backgroundColor,
    this.textColor,
    this.icon,
    this.isPrimary = true,
    this.hasPulse = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final btnColor = backgroundColor ??
        (isPrimary ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.secondary);

    Widget button = ElevatedButton(
      onPressed: isLoading ? null : onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: btnColor,
        foregroundColor: textColor ?? Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 18),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        elevation: 0,
        shadowColor: btnColor.withValues(alpha: 0.3),
      ),
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 200),
        child: isLoading
            ? const SizedBox(
                height: 24,
                width: 24,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2.5,
                ),
              )
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (icon != null) ...{
                    Icon(icon, size: 20),
                    const SizedBox(width: 10),
                  },
                  Text(
                    text,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
      ),
    );

    // Add pulse animation for BLE buttons
    if (hasPulse && !isLoading) {
      button = button
          .animate(onPlay: (controller) => controller.repeat())
          .scale(
            duration: 1500.ms,
            begin: const Offset(1.0, 1.0),
            end: const Offset(1.05, 1.05),
            curve: Curves.easeInOut,
          )
          .then()
          .scale(
            duration: 1500.ms,
            begin: const Offset(1.05, 1.05),
            end: const Offset(1.0, 1.0),
            curve: Curves.easeInOut,
          );
    }

    // Spring animation on tap
    return button
        .animate(target: isLoading ? 0 : 1)
        .fadeIn(duration: 300.ms)
        .slideY(begin: 0.1, end: 0, curve: Curves.easeOutCubic);
  }
}
