import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/models/expansion_models.dart';
import '../../../core/theme/app_colors.dart';
import 'wallet_card.dart';

/// Visitor Pass Temporary Card (Card 6 in Campus Wallet).
/// Appears when an approved visitor request exists for the student.
class VisitorPassCard extends StatelessWidget {
  final VisitorRequestModel? pass;
  final VoidCallback? onTap;

  const VisitorPassCard({
    Key? key,
    this.pass,
    this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final visitorName = pass?.visitorName ?? 'Visitor Guest';
    final relation = pass?.relation ?? 'Guest';
    final passCode = pass?.passCode ?? 'VP-PENDING';
    final visitDate = pass?.visitDate ?? 'Today';
    final status = pass?.status ?? 'APPROVED';
    final isCheckedIn = status == 'CHECKED_IN';

    return Semantics(
      label: 'Visitor Pass Card. $visitorName ($relation). Pass Code $passCode. Status: $status. Tap to view pass details and QR.',
      child: WalletCardContainer(
        onTap: onTap,
        isInteractive: onTap != null,
        gradient: const LinearGradient(
          colors: [
            Color(0xFF292524), // Stone 800
            Color(0xFF1C1917), // Stone 900
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        isDarkSurface: true,
        border: Border.all(
          color: isCheckedIn
              ? AppColors.success.withValues(alpha: 0.4)
              : const Color(0xFFF59E0B).withValues(alpha: 0.35),
          width: 1.0,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Top Row: Brand & Status Chip
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(5),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        isCheckedIn ? Icons.login_rounded : Icons.confirmation_number_rounded,
                        color: isCheckedIn ? AppColors.success : const Color(0xFFFBBF24),
                        size: 15,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'CAMPUSOS • VISITOR PASS',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: Colors.white.withValues(alpha: 0.75),
                        letterSpacing: 1.0,
                      ),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: (isCheckedIn ? AppColors.success : const Color(0xFFF59E0B))
                        .withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: (isCheckedIn ? AppColors.success : const Color(0xFFF59E0B))
                          .withValues(alpha: 0.4),
                      width: 0.8,
                    ),
                  ),
                  child: Text(
                    isCheckedIn ? 'INSIDE CAMPUS' : 'APPROVED',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                      color: isCheckedIn ? AppColors.success : const Color(0xFFFBBF24),
                      letterSpacing: 0.6,
                    ),
                  ),
                ),
              ],
            ),

            // Middle: Visitor Name & Pass Code
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  visitorName,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    letterSpacing: -0.4,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Text(
                      relation,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: const Color(0xFFCBD5E1),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text('•', style: TextStyle(color: Colors.white.withValues(alpha: 0.4))),
                    const SizedBox(width: 8),
                    Text(
                      passCode,
                      style: GoogleFonts.jetBrainsMono(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFFFBBF24),
                        letterSpacing: 0.8,
                      ),
                    ),
                  ],
                ),
              ],
            ),

            // Bottom Row: Validity & Present Action
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'VALID ON',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 8.5,
                        fontWeight: FontWeight.w700,
                        color: Colors.white.withValues(alpha: 0.5),
                        letterSpacing: 0.5,
                      ),
                    ),
                    Text(
                      '$visitDate (${pass?.expectedEntryTime ?? "4 PM"} - ${pass?.expectedExitTime ?? "8 PM"})',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w600,
                        color: Colors.white.withValues(alpha: 0.9),
                      ),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.qr_code_2_rounded, size: 12, color: Color(0xFFFBBF24)),
                      const SizedBox(width: 4),
                      Text(
                        'Show Gate Pass',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFFFBBF24),
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
    );
  }
}
