import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_colors.dart';
import '../../models/gate_pass_model.dart';
import 'wallet_card.dart';

/// Institutional Transit Gate Pass card (Card 3 in Campus Wallet).
///
/// Features:
/// - Sleek dark card surface for transit credentials
/// - Active pass destination and validity window
/// - HMAC-SHA256 security guarantee
/// - Biometric-protected unlock prompt
class GatePassCard extends StatelessWidget {
  final GatePassModel? activePass;
  final bool isLoading;
  final bool isUnlocked;
  final VoidCallback onUnlockTap;
  final VoidCallback onRequestPassTap;
  final VoidCallback onViewQrTap;

  const GatePassCard({
    Key? key,
    required this.activePass,
    required this.isLoading,
    required this.isUnlocked,
    required this.onUnlockTap,
    required this.onRequestPassTap,
    required this.onViewQrTap,
  }) : super(key: key);

  Color _getStatusColor(String status) {
    switch (status.toUpperCase()) {
      case 'APPROVED':
      case 'ISSUED':
        return AppColors.success;
      case 'EXITED':
        return AppColors.warning;
      case 'RETURNED':
        return AppColors.primary;
      case 'REJECTED':
      case 'EXPIRED':
        return AppColors.danger;
      default:
        return const Color(0xFFA855F7);
    }
  }

  @override
  Widget build(BuildContext context) {
    // 1. Loading State
    if (isLoading) {
      return const WalletCardContainer(
        surfaceColor: Color(0xFF181C2E),
        isInteractive: false,
        child: Center(
          child: SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
            ),
          ),
        ),
      );
    }

    final pass = activePass;

    // 2. Empty State (No active gate pass)
    if (pass == null) {
      return Semantics(
        label: 'Gate Pass. No active gate pass. Tap to request gate pass.',
        button: true,
        child: WalletCardContainer(
          onTap: onRequestPassTap,
          padding: EdgeInsets.zero,
          gradient: const LinearGradient(
            colors: [Color(0xFF1E2235), Color(0xFF151828)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          border: Border.all(
            color: const Color(0xFFA855F7).withValues(alpha: 0.28),
            width: 1.0,
          ),
          child: Stack(
            children: [
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      center: const Alignment(-0.8, -0.6),
                      radius: 1.25,
                      colors: [
                        const Color(0xFFA855F7).withValues(alpha: 0.14),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topRight,
                      end: Alignment.bottomLeft,
                      colors: [
                        Colors.white.withValues(alpha: 0.04),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
              // Top Row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          'CAMPUS TRANSIT',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.8,
                            color: Colors.white70,
                          ),
                        ),
                      ),
                    ],
                  ),
                  Text(
                    'No Active Pass',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Colors.white54,
                    ),
                  ),
                ],
              ),

              // Middle Prompt
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Campus Transit Gate Pass',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    'Apply for hostel exit or city transit approval to generate an authorized Gate Pass.',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 11.5,
                      color: Colors.white60,
                      height: 1.3,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),

              // Bottom CTA
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFFA855F7).withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color: const Color(0xFFA855F7).withValues(alpha: 0.45),
                        width: 1.0,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.add_rounded, size: 14, color: Colors.white),
                        const SizedBox(width: 4),
                        Text(
                          'Request Gate Pass',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    ),
  ),
);
    }

    // 3. Active Gate Pass Available
    final statusColor = _getStatusColor(pass.status);
    final exitTimeStr = DateFormat('hh:mm a').format(pass.expectedExitTime);
    final returnTimeStr =
        DateFormat('hh:mm a, MMM dd').format(pass.expectedReturnTime);

    return Semantics(
      label:
          'Gate Pass. Status: ${pass.status}. Destination: ${pass.destination}. ${isUnlocked ? "Double tap to view pass QR." : "Double tap to unlock."}',
      button: true,
      child: WalletCardContainer(
        onTap: isUnlocked ? onViewQrTap : onUnlockTap,
        padding: EdgeInsets.zero,
        gradient: const LinearGradient(
          colors: [Color(0xFF1E2235), Color(0xFF141726)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(
          color: statusColor.withValues(alpha: 0.42),
          width: 1.0,
        ),
        child: Stack(
          children: [
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: const Alignment(-0.8, -0.6),
                    radius: 1.25,
                    colors: [
                      statusColor.withValues(alpha: 0.16),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topRight,
                    end: Alignment.bottomLeft,
                    colors: [
                      Colors.white.withValues(alpha: 0.05),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
            // Top Row: Header & Status Capsule
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    'GATE PASS',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.8,
                      color: Colors.white70,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color: statusColor.withValues(alpha: 0.35),
                      width: 0.8,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: statusColor,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 5),
                      Text(
                        pass.status,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: statusColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            // Middle Section: Destination & Tabular Validity Timing
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  pass.destination.toUpperCase(),
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 3),
                Text(
                  'Valid: $exitTimeStr → $returnTimeStr',
                  style: GoogleFonts.spaceGrotesk(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.white70,
                    letterSpacing: 0.2,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 3),
                Row(
                  children: [
                    const Icon(
                      Icons.verified_user_rounded,
                      size: 11,
                      color: Color(0xFF00D084),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'HMAC-SHA256 Validated',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF00D084),
                      ),
                    ),
                  ],
                ),
              ],
            ),

            // Bottom Row: Interactive Action Indicator
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isUnlocked ? Icons.qr_code_2_rounded : Icons.lock_outline_rounded,
                      size: 13,
                      color: isUnlocked ? const Color(0xFF00D084) : const Color(0xFFFFB020),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      isUnlocked ? 'Pass Ready' : 'Gate Pass Locked',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: isUnlocked ? const Color(0xFF00D084) : const Color(0xFFFFB020),
                      ),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
                  decoration: BoxDecoration(
                    color: isUnlocked
                        ? const Color(0xFF00D084).withValues(alpha: 0.16)
                        : const Color(0xFFA855F7).withValues(alpha: 0.22),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color: isUnlocked
                          ? const Color(0xFF00D084).withValues(alpha: 0.4)
                          : const Color(0xFFA855F7).withValues(alpha: 0.45),
                      width: 0.8,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isUnlocked
                            ? Icons.visibility_rounded
                            : Icons.fingerprint_rounded,
                        size: 12,
                        color: Colors.white,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        isUnlocked ? 'View Pass QR' : 'Unlock pass',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ],
  ),
),
);
  }
}
