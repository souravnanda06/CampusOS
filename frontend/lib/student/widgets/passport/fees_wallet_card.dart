import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/models/expansion_models.dart';
import '../../../core/theme/app_colors.dart';
import 'wallet_card.dart';

/// Fees & Dues Card (Card 5 in Campus Wallet).
/// Institutional billing card showing balance due, payment status, and due date.
class FeesWalletCard extends StatelessWidget {
  final FeeSummaryModel? feeSummary;
  final VoidCallback? onTap;

  const FeesWalletCard({
    Key? key,
    this.feeSummary,
    this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final balanceDue = feeSummary?.totalDue ?? 0.0;
    final isCleared = balanceDue <= 0.0;
    final dueDate = feeSummary?.nextDueDate ?? 'None';
    final category = feeSummary?.primaryCategory ?? 'Institutional Dues';

    return Semantics(
      label: 'Fees and Dues Card. ${isCleared ? "All cleared" : "Balance Due ₹${balanceDue.toStringAsFixed(0)}"}. Due Date: $dueDate. Tap to view breakdown and payment history.',
      child: WalletCardContainer(
        onTap: onTap,
        isInteractive: onTap != null,
        gradient: const LinearGradient(
          colors: [
            Color(0xFF1E293B), // Slate 800
            Color(0xFF0F172A), // Slate 900
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        isDarkSurface: true,
        border: Border.all(
          color: isCleared
              ? AppColors.success.withValues(alpha: 0.3)
              : const Color(0xFFF59E0B).withValues(alpha: 0.3),
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
                        isCleared ? Icons.check_circle_outline_rounded : Icons.account_balance_wallet_rounded,
                        color: isCleared ? AppColors.success : const Color(0xFFFBBF24),
                        size: 15,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'CAMPUSOS • ACADEMIC DUES',
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
                    color: (isCleared ? AppColors.success : const Color(0xFFF59E0B))
                        .withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: (isCleared ? AppColors.success : const Color(0xFFF59E0B))
                          .withValues(alpha: 0.4),
                      width: 0.8,
                    ),
                  ),
                  child: Text(
                    isCleared ? 'CLEARED' : 'DUE',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                      color: isCleared ? AppColors.success : const Color(0xFFFBBF24),
                      letterSpacing: 0.6,
                    ),
                  ),
                ),
              ],
            ),

            // Middle: Amount & Category
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      '₹',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF94A3B8),
                      ),
                    ),
                    const SizedBox(width: 2),
                    Text(
                      balanceDue.toStringAsFixed(0),
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        letterSpacing: -0.6,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      isCleared ? 'No Outstanding' : 'Outstanding',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: const Color(0xFF94A3B8),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  category,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: Colors.white.withValues(alpha: 0.7),
                  ),
                ),
              ],
            ),

            // Bottom Row: Due Date & View Action
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'NEXT DUE DATE',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 8.5,
                        fontWeight: FontWeight.w700,
                        color: Colors.white.withValues(alpha: 0.5),
                        letterSpacing: 0.5,
                      ),
                    ),
                    Text(
                      dueDate,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11,
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
                      Text(
                        'View Dues & Receipts',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF93C5FD),
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Icon(Icons.arrow_forward_ios_rounded, size: 9, color: Color(0xFF93C5FD)),
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
