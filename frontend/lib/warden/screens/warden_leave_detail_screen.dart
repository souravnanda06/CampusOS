import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../auth/models/user_model.dart';
import '../../core/theme/app_colors.dart';
import '../models/warden_models.dart';
import '../services/warden_service.dart';

class WardenLeaveDetailScreen extends StatefulWidget {
  final WardenLeaveRequestModel initialRequest;
  final UserModel? user;

  const WardenLeaveDetailScreen({
    Key? key,
    required this.initialRequest,
    this.user,
  }) : super(key: key);

  @override
  State<WardenLeaveDetailScreen> createState() => _WardenLeaveDetailScreenState();
}

class _WardenLeaveDetailScreenState extends State<WardenLeaveDetailScreen> {
  late WardenLeaveRequestModel _request;
  final WardenService _wardenService = WardenService();
  bool _isProcessingAction = false;

  @override
  void initState() {
    super.initState();
    _request = widget.initialRequest;
    _refreshDetail();
  }

  Future<void> _refreshDetail() async {
    final updated = await _wardenService.fetchLeaveDetail(
      _request.id,
      widget.user?.id,
    );
    if (mounted && updated != null) {
      setState(() {
        _request = updated;
      });
    }
  }

  Future<void> _showActionDialog(String action) async {
    final TextEditingController remarksController = TextEditingController();
    final isApprove = action == 'APPROVE';
    final isReject = action == 'REJECT';

    try {
      final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(
              isApprove
                  ? Icons.check_circle_rounded
                  : isReject
                      ? Icons.cancel_rounded
                      : Icons.help_outline_rounded,
              color: isApprove
                  ? AppColors.success
                  : isReject
                      ? AppColors.error
                      : AppColors.primary,
            ),
            const SizedBox(width: 10),
            Text(
              isApprove
                  ? 'Approve Leave'
                  : isReject
                      ? 'Reject Leave'
                      : 'Request Clarification',
              style: GoogleFonts.plusJakartaSans(
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              isApprove
                  ? "Approving this leave will immediately authorize Gate Pass issuance for ${_request.studentName}."
                  : isReject
                      ? "Please specify the reason for rejecting this leave request."
                      : "Send an institutional inquiry to ${_request.studentName}.",
              style: GoogleFonts.plusJakartaSans(
                fontSize: 13,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: remarksController,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: isApprove
                    ? 'Optional approval remarks...'
                    : 'Enter remarks / justification...',
                hintStyle: GoogleFonts.plusJakartaSans(fontSize: 13),
                filled: true,
                fillColor: AppColors.bg,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.border),
                ),
                contentPadding: const EdgeInsets.all(12),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'Cancel',
              style: GoogleFonts.plusJakartaSans(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: isApprove
                  ? AppColors.success
                  : isReject
                      ? AppColors.error
                      : AppColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: Text(
              isApprove
                  ? 'Confirm Approval'
                  : isReject
                      ? 'Confirm Rejection'
                      : 'Send Inquiry',
              style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      _handleAction(action, remarksController.text.trim());
    }
  } finally {
    remarksController.dispose();
  }
}

  Future<void> _handleAction(String action, String remarks) async {
    setState(() => _isProcessingAction = true);

    final res = await _wardenService.processAction(
      _request.id,
      action: action,
      remarks: remarks,
      wardenId: widget.user?.id,
    );

    if (!mounted) return;
    setState(() => _isProcessingAction = false);

    if (res['success'] == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            action == 'APPROVE'
                ? "Leave approved. Associated Gate Pass eligible for verification."
                : action == 'REJECT'
                    ? "Leave request rejected."
                    : "Inquiry sent to student.",
            style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold),
          ),
          backgroundColor: action == 'APPROVE' ? AppColors.success : AppColors.primary,
          behavior: SnackBarBehavior.floating,
        ),
      );
      _refreshDetail();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            res['message'] ?? 'Action failed',
            style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold),
          ),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Color _getStatusColor() {
    switch (_request.status) {
      case 'APPROVED':
        return AppColors.success;
      case 'REJECTED':
        return AppColors.error;
      case 'PENDING':
      default:
        return AppColors.warning;
    }
  }

  Widget _buildSectionCard({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: AppColors.primary),
              const SizedBox(width: 8),
              Text(
                title,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ...children,
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, {IconData? icon}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 16, color: AppColors.textSecondary),
            const SizedBox(width: 8),
          ],
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final statusColor = _getStatusColor();

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        title: Text(
          'Leave Request Review',
          style: GoogleFonts.plusJakartaSans(
            fontWeight: FontWeight.bold,
            fontSize: 17,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _refreshDetail,
          ),
        ],
      ),
      body: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  // Status Header Banner
                  Container(
                    width: double.infinity,
                    margin: const EdgeInsets.only(bottom: 16),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: statusColor.withValues(alpha: 0.25),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Icon(
                              _request.status == 'APPROVED'
                                  ? Icons.check_circle_rounded
                                  : _request.status == 'REJECTED'
                                      ? Icons.cancel_rounded
                                      : Icons.pending_rounded,
                              color: statusColor,
                              size: 22,
                            ),
                            const SizedBox(width: 10),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  "Status: ${_request.status}",
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                    color: statusColor,
                                  ),
                                ),
                                Text(
                                  "Submitted: ${_request.createdAt.split('T').first}",
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 11,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            _request.leaveType,
                            style: GoogleFonts.jetBrainsMono(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: AppColors.primary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Student Academic Profile Card
                  _buildSectionCard(
                    title: 'Student Academic Profile',
                    icon: Icons.school_outlined,
                    children: [
                      _buildDetailRow('Full Name', _request.studentName, icon: Icons.person_outline),
                      _buildDetailRow('Registration', _request.registrationNumber, icon: Icons.badge_outlined),
                      _buildDetailRow('Course', _request.course, icon: Icons.menu_book_outlined),
                      _buildDetailRow('Branch', _request.branch, icon: Icons.account_tree_outlined),
                      _buildDetailRow('Year of Study', 'Year ${_request.year}', icon: Icons.timeline_outlined),
                      if (_request.studentPhone != null && _request.studentPhone!.isNotEmpty)
                        _buildDetailRow('Contact', _request.studentPhone!, icon: Icons.phone_outlined),
                      _buildDetailRow(
                        'Prior Leaves',
                        "${_request.previousRequestsCount} prior requests on record",
                        icon: Icons.history_rounded,
                      ),
                    ],
                  ),

                  // Leave Details Card
                  _buildSectionCard(
                    title: 'Leave & Travel Details',
                    icon: Icons.flight_takeoff_rounded,
                    children: [
                      _buildDetailRow('Destination', _request.destination, icon: Icons.place_outlined),
                      _buildDetailRow('Departure Date', _request.startDate, icon: Icons.event_outlined),
                      _buildDetailRow('Return Date', _request.endDate, icon: Icons.event_available_outlined),
                      const SizedBox(height: 6),
                      Text(
                        'Reason for Leave:',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.bg,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          _request.reason,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 13,
                            color: AppColors.textPrimary,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),

                  // Gate Pass Integration Card
                  _buildSectionCard(
                    title: 'Gate Pass Lifecycle Status',
                    icon: Icons.security_rounded,
                    children: [
                      if (_request.gatePass != null) ...[
                        _buildDetailRow(
                          'Gate Pass Status',
                          _request.gatePass!['status'] ?? 'ISSUED',
                          icon: Icons.qr_code_2_rounded,
                        ),
                        _buildDetailRow(
                          'Designated Gate',
                          _request.gatePass!['gateName'] ?? 'Main Gate',
                          icon: Icons.door_sliding_outlined,
                        ),
                        _buildDetailRow(
                          'Verification Mode',
                          _request.gatePass!['verificationMode'] ?? 'QR_FALLBACK',
                          icon: Icons.verified_user_outlined,
                        ),
                      ] else if (_request.isApproved) ...[
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.success.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.check_circle_outline, color: AppColors.success, size: 20),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  "Gate pass is active for verification by Security Officer at campus exit.",
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 12,
                                    color: AppColors.success,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ] else ...[
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.warning.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.info_outline, color: AppColors.warning, size: 20),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  "Upon Warden approval, the student is automatically eligible to present their cryptographically verified Gate Pass at the security checkpoint.",
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 12,
                                    color: AppColors.warning,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),

                  // Remarks Section (if any)
                  if (_request.reviewRemarks != null && _request.reviewRemarks!.isNotEmpty)
                    _buildSectionCard(
                      title: 'Warden Review Remarks',
                      icon: Icons.rate_review_outlined,
                      children: [
                        Text(
                          _request.reviewRemarks!,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 13,
                            color: AppColors.textPrimary,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ],
                    ),

                  const SizedBox(height: 80),
                ],
              ),
            ),
      bottomSheet: _request.isPending
          ? Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.06),
                    blurRadius: 10,
                    offset: const Offset(0, -4),
                  ),
                ],
              ),
              child: SafeArea(
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _isProcessingAction ? null : () => _showActionDialog('REJECT'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.error,
                          side: const BorderSide(color: AppColors.error),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: Text(
                          'Reject Request',
                          style: GoogleFonts.plusJakartaSans(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _isProcessingAction ? null : () => _showActionDialog('APPROVE'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.success,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: _isProcessingAction
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : Text(
                                'Approve Leave',
                                style: GoogleFonts.plusJakartaSans(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            )
          : null,
    );
  }
}
