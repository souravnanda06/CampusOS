import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../auth/models/user_model.dart';
import '../../../core/theme/app_colors.dart';
import '../motion/apple_bounceable.dart';
import 'copilot_sheet.dart';

/// Floating AI Copilot pill positioned cleanly above the 4-item AppDock.
class CopilotFloatingPill extends StatelessWidget {
  final UserModel? user;
  final String role;
  final String? screenContext;

  const CopilotFloatingPill({
    super.key,
    required this.user,
    required this.role,
    this.screenContext,
  });

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    final bottomOffset = (bottomInset > 0 ? bottomInset + 8.0 : 16.0) + 74.0;

    return Positioned(
      right: 18,
      bottom: bottomOffset,
      child: AppleBounceable(
        scaleFactor: 0.92,
        onTap: () => CopilotSheet.show(
          context,
          user: user,
          role: role,
          screenContext: screenContext,
        ),
        child: Container(
          key: Key('copilot_fab_${role.toLowerCase()}'),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            gradient: AppColors.primaryGradient,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.35),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.auto_awesome_rounded,
                color: Colors.white,
                size: 17,
              ),
              const SizedBox(width: 6),
              Text(
                'Campus AI',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                  letterSpacing: -0.1,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
