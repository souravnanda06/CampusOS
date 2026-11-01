import 'package:flutter/material.dart';
import 'package:attendance_app/core/haptics/app_haptics.dart';

import 'package:google_fonts/google_fonts.dart';
import '../../core/services/expansion_api_service.dart';
import '../../core/theme/app_colors.dart';

class VisitorPassVerifySheet extends StatefulWidget {
  final String guardId;
  final String? initialPassCode;

  const VisitorPassVerifySheet({
    Key? key,
    required this.guardId,
    this.initialPassCode,
  }) : super(key: key);

  static void show(BuildContext context,
      {required String guardId, String? initialPassCode}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => VisitorPassVerifySheet(
        guardId: guardId,
        initialPassCode: initialPassCode,
      ),
    );
  }

  @override
  State<VisitorPassVerifySheet> createState() => _VisitorPassVerifySheetState();
}

class _VisitorPassVerifySheetState extends State<VisitorPassVerifySheet> {
  final ExpansionApiService _api = ExpansionApiService.instance;
  late final TextEditingController _codeController;

  bool _isVerifying = false;
  bool _isProcessing = false;
  Map<String, dynamic>? _verificationResult;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _codeController =
        TextEditingController(text: widget.initialPassCode ?? '');
    if (widget.initialPassCode != null &&
        widget.initialPassCode!.isNotEmpty) {
      _verifyCode();
    }
  }

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _verifyCode() async {
    final code = _codeController.text.trim();
    if (code.isEmpty) return;

    setState(() {
      _isVerifying = true;
      _errorMessage = null;
      _verificationResult = null;
    });

    try {
      AppHaptics.lightImpact();
      final res = await _api.verifyVisitorPass(
        passCode: code,
        guardId: widget.guardId,
      );

      if (mounted) {
        setState(() {
          _verificationResult = res;
          _isVerifying = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString().replaceAll('Exception: ', '');
          _isVerifying = false;
        });
      }
    }
  }

  Future<void> _handleCheckIn(String code) async {
    setState(() => _isProcessing = true);
    AppHaptics.mediumImpact();

    try {
      await _api.checkInVisitor(
        passCode: code,
        guardId: widget.guardId,
        remarks: 'Verified at Main Gate',
      );
      if (mounted) {
        setState(() => _isProcessing = false);
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              "Visitor Checked IN. Entry logged in gate ledger.",
              style: GoogleFonts.plusJakartaSans(
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isProcessing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Check-In Error: $e"),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    }
  }

  Future<void> _handleCheckOut(String code) async {
    setState(() => _isProcessing = true);
    AppHaptics.mediumImpact();

    try {
      await _api.checkOutVisitor(
        passCode: code,
        guardId: widget.guardId,
        remarks: 'Checked out at Main Gate',
      );
      if (mounted) {
        setState(() => _isProcessing = false);
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              "Visitor Checked OUT. Pass marked completed.",
              style: GoogleFonts.plusJakartaSans(
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            backgroundColor: const Color(0xFF64748B),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isProcessing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Check-Out Error: $e"),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      decoration: const BoxDecoration(
        color: AppColors.surface,
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
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                const Icon(Icons.shield_rounded,
                    color: Color(0xFFD97706), size: 24),
                const SizedBox(width: 10),
                Text(
                  "Gate Visitor Verification",
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              "Scan or enter visitor token for anti-replay verified check-in & check-out.",
              style: GoogleFonts.plusJakartaSans(
                fontSize: 13,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _codeController,
                    textCapitalization: TextCapitalization.characters,
                    decoration: InputDecoration(
                      hintText: "Enter Token e.g. VP-2026-...",
                      hintStyle: GoogleFonts.jetBrainsMono(
                          fontSize: 13, color: AppColors.textTertiary),
                      filled: true,
                      fillColor: AppColors.bg,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(color: AppColors.border),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                ElevatedButton(
                  onPressed: _isVerifying ? null : _verifyCode,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFD97706),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 18, vertical: 14),
                  ),
                  child: _isVerifying
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                      : const Text("Verify"),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (_errorMessage != null)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.danger.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  _errorMessage!,
                  style: GoogleFonts.plusJakartaSans(
                    color: AppColors.danger,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            if (_verificationResult != null) ...[
              _buildResultCard(_verificationResult!),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildResultCard(Map<String, dynamic> res) {
    final bool valid = res['valid'] == true;
    final String status = res['status'] ?? 'INVALID';
    final pass = res['pass'] as Map<String, dynamic>?;

    final isApproved = status == 'APPROVED';
    final isCheckedIn = status == 'CHECKED_IN';
    final passCode = pass?['passCode'] ?? _codeController.text.trim();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: valid
            ? (isCheckedIn
                ? const Color(0xFFF0FDF4)
                : const Color(0xFFFFFBEB))
            : const Color(0xFFFEF2F2),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: valid
              ? (isCheckedIn ? AppColors.success : const Color(0xFFD97706))
              : AppColors.danger,
          width: 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                valid ? "VERIFIED PASS" : "INVALID / EXPIRED",
                style: GoogleFonts.plusJakartaSans(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: valid
                      ? (isCheckedIn
                          ? AppColors.success
                          : const Color(0xFFD97706))
                      : AppColors.danger,
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                decoration: BoxDecoration(
                  color: valid ? Colors.white : AppColors.danger,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  status,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: valid ? AppColors.textPrimary : Colors.white,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (pass != null) ...[
            Text(
              "${pass['visitorName']} (${pass['relation']})",
              style: GoogleFonts.plusJakartaSans(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              "Phone: ${pass['visitorPhone']}  •  Date: ${pass['visitDate']}",
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12,
                color: AppColors.textSecondary,
              ),
            ),
            Text(
              "Host Student ID: ${pass['studentId']}",
              style: GoogleFonts.jetBrainsMono(
                fontSize: 11,
                color: AppColors.textSecondary,
              ),
            ),
            Text(
              "Purpose: ${pass['purpose']}",
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 16),
            if (isApproved)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _isProcessing
                      ? null
                      : () => _handleCheckIn(passCode),
                  icon: const Icon(Icons.login_rounded, size: 18),
                  label: const Text("Log Check-In (Allow Entry)"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.success,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            if (isCheckedIn)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _isProcessing
                      ? null
                      : () => _handleCheckOut(passCode),
                  icon: const Icon(Icons.logout_rounded, size: 18),
                  label: const Text("Log Check-Out (Complete Exit)"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF475569),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }
}
