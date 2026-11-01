import 'package:flutter/material.dart';
import 'package:attendance_app/core/haptics/app_haptics.dart';

import '../../../core/theme/app_colors.dart';

/// Floating scanner action button positioned in the Campus Wallet area.
///
/// Features:
/// - 56dp standard CampusOS FAB touch target
/// - Crisp white circular button with refined dark-indigo glyph
/// - High-contrast QR scanner glyph
/// - Accessible touch target (>= 48x48)
/// - Tactile haptic feedback on tap
/// - Accessible tooltip for screen readers and automated test compliance
class PassportScannerButton extends StatelessWidget {
  final VoidCallback onPressed;
  final double size;

  const PassportScannerButton({
    Key? key,
    required this.onPressed,
    this.size = 56,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Campus Scanner',
      child: Semantics(
        label: 'Scan Campus QR Code',
        button: true,
        child: GestureDetector(
          onTap: () {
            AppHaptics.selectionClick();
            onPressed();
          },
          behavior: HitTestBehavior.opaque,
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              border: Border.all(
                color: AppColors.border,
                width: 1.0,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.10),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: const Center(
              child: Icon(
                Icons.qr_code_scanner_rounded,
                color: Color(0xFF1E1B4B),
                size: 26,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
