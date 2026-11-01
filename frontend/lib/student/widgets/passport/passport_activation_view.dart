import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_colors.dart';
import '../../models/passport_wallet_state.dart';
import 'wallet_card.dart';

/// Dedicated initialization and reactivation card for Campus Passport.
///
/// Explicitly handles:
/// - Case A: First-Time Device Activation ([PassportWalletState.uninitialized])
/// - Case B: Key Missing on Device ([PassportWalletState.keyMissing])
///
/// Invariants:
/// - Ed25519 private key is generated and stored locally in hardware keystore.
/// - Only the public key is registered with the backend.
/// - Preserves auditability without silent replacement.
class PassportActivationCard extends StatelessWidget {
  final PassportWalletState state;
  final bool isProcessing;
  final VoidCallback onActivateTap;

  const PassportActivationCard({
    Key? key,
    required this.state,
    required this.isProcessing,
    required this.onActivateTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isReactivation = state == PassportWalletState.keyMissing;

    final title = isReactivation ? 'Passport Identity Unavailable' : 'Campus Passport';
    final subtitle = isReactivation ? null : 'Not Activated';
    final description = isReactivation
        ? 'Your certified Passport identity is no longer available on this device.'
        : 'Secure your campus identity on this device.';

    return WalletCardContainer(
      gradient: const LinearGradient(
        colors: [
          Color(0xFF1E1B4B),
          Color(0xFF0F172A),
        ],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      border: Border.all(
        color: isReactivation
            ? AppColors.warning.withValues(alpha: 0.35)
            : const Color(0xFF6366F1).withValues(alpha: 0.35),
        width: 1.2,
      ),
      elevation: 5.0,
      onTap: onActivateTap,
      isInteractive: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Top Row: CAMPUSOS Badge & State Tag
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                decoration: BoxDecoration(
                  color: const Color(0xFF6366F1).withValues(alpha: 0.22),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: const Color(0xFF6366F1).withValues(alpha: 0.4),
                    width: 0.8,
                  ),
                ),
                child: Text(
                  'CAMPUSOS',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.2,
                    color: const Color(0xFFA5B4FC),
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                decoration: BoxDecoration(
                  color: isReactivation
                      ? AppColors.warning.withValues(alpha: 0.15)
                      : const Color(0xFF6366F1).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isReactivation
                        ? AppColors.warning.withValues(alpha: 0.35)
                        : const Color(0xFF6366F1).withValues(alpha: 0.35),
                    width: 0.8,
                  ),
                ),
                child: Text(
                  isReactivation ? 'ACTION REQUIRED' : 'SETUP REQUIRED',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5,
                    color: isReactivation ? AppColors.warning : const Color(0xFFA5B4FC),
                  ),
                ),
              ),
            ],
          ),

          // Middle Section: Status Title and Explanation
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 19,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                  letterSpacing: -0.3,
                ),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFFA5B4FC),
                  ),
                ),
              ],
              const SizedBox(height: 6),
              Text(
                description,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 12,
                  color: const Color(0xFF94A3B8),
                  height: 1.4,
                ),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),

          // Bottom Section: Hardware Trust Tag & Indicator
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.security_rounded,
                    size: 14,
                    color: isReactivation
                        ? AppColors.warning
                        : const Color(0xFFA5B4FC).withValues(alpha: 0.7),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    isReactivation
                        ? 'Re-binding required'
                        : 'Hardware keystore bound',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: isReactivation
                          ? AppColors.warning
                          : Colors.white.withValues(alpha: 0.6),
                    ),
                  ),
                ],
              ),
              Icon(
                isReactivation ? Icons.lock_reset_rounded : Icons.fingerprint_rounded,
                size: 18,
                color: Colors.white.withValues(alpha: 0.4),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
