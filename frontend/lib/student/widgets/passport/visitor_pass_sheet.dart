import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../../core/models/expansion_models.dart';
import '../../../core/theme/app_colors.dart';

class VisitorPassSheet extends StatelessWidget {
  final VisitorRequestModel pass;

  const VisitorPassSheet({
    Key? key,
    required this.pass,
  }) : super(key: key);

  static void show(BuildContext context, VisitorRequestModel pass) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => VisitorPassSheet(pass: pass),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isCheckedIn = pass.status == 'CHECKED_IN';

    return Container(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.divider,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF59E0B).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(
                    Icons.badge_rounded,
                    color: Color(0xFFD97706),
                    size: 28,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Temporary Visitor Pass',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Security Gate Clearance Token',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: (isCheckedIn ? AppColors.success : const Color(0xFFF59E0B))
                        .withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: (isCheckedIn ? AppColors.success : const Color(0xFFF59E0B))
                          .withValues(alpha: 0.3),
                      width: 0.8,
                    ),
                  ),
                  child: Text(
                    isCheckedIn ? 'INSIDE CAMPUS' : pass.status,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: isCheckedIn ? AppColors.success : const Color(0xFFD97706),
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 24),

            // Visitor Info Box
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Column(
                children: [
                  _buildRow('Visitor Name', pass.visitorName),
                  const Divider(height: 20),
                  _buildRow('Phone Number', pass.visitorPhone),
                  const Divider(height: 20),
                  _buildRow('Relation to Student', pass.relation),
                  const Divider(height: 20),
                  _buildRow('Visit Purpose', pass.purpose),
                  const Divider(height: 20),
                  _buildRow('Valid Date', pass.visitDate),
                  const Divider(height: 20),
                  _buildRow('Time Window', '${pass.expectedEntryTime} - ${pass.expectedExitTime}'),
                  const Divider(height: 20),
                  _buildRow('Pass Code', pass.passCode ?? 'PENDING', isMonospace: true),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Verification QR
            Center(
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.04),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: QrImageView(
                      data: pass.passCode ?? 'CAMPUSOS:VP:INVALID',
                      version: QrVersions.auto,
                      size: 140,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Present this QR to Main Gate Security for Verification',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRow(String label, String value, {bool isMonospace = false}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(width: 16),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: isMonospace
                ? GoogleFonts.jetBrainsMono(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  )
                : GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
          ),
        ),
      ],
    );
  }
}
