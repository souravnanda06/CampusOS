import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../auth/providers/user_provider.dart';
import '../../models/complaint_model.dart';
import '../../models/complaint_history_model.dart';
import '../../services/complaint_service.dart';

class ComplaintDetailSheet extends StatefulWidget {
  final ComplaintModel complaint;
  final VoidCallback? onStatusChanged;

  const ComplaintDetailSheet({
    Key? key,
    required this.complaint,
    this.onStatusChanged,
  }) : super(key: key);

  @override
  State<ComplaintDetailSheet> createState() => _ComplaintDetailSheetState();
}

class _ComplaintDetailSheetState extends State<ComplaintDetailSheet> {
  final ComplaintService _complaintService = ComplaintService();
  late ComplaintModel _complaint;
  List<ComplaintHistoryModel> _history = [];
  bool _isLoadingHistory = true;
  String? _historyError;
  bool _isPerformingAction = false;

  // Feature 2: Proof-of-Fix Feedback & Rating
  int? _selectedRating;
  final TextEditingController _feedbackController = TextEditingController();
  bool _isSubmittingFeedback = false;

  @override
  void initState() {
    super.initState();
    _complaint = widget.complaint;
    _selectedRating = widget.complaint.studentRating;
    if (widget.complaint.studentFeedback != null) {
      _feedbackController.text = widget.complaint.studentFeedback!;
    }
    _loadHistoryAndDetails();
  }

  @override
  void dispose() {
    _feedbackController.dispose();
    super.dispose();
  }

  Future<void> _loadHistoryAndDetails() async {
    final studentId = Provider.of<UserProvider>(context, listen: false).user?.id;
    setState(() {
      _isLoadingHistory = true;
      _historyError = null;
    });

    try {
      final results = await Future.wait([
        _complaintService.getComplaint(_complaint.id, requesterId: studentId),
        _complaintService.getComplaintHistory(_complaint.id, requesterId: studentId),
      ]);

      if (mounted) {
        final c = results[0] as ComplaintModel;
        setState(() {
          _complaint = c;
          _history = results[1] as List<ComplaintHistoryModel>;
          _isLoadingHistory = false;
          _selectedRating = c.studentRating ?? _selectedRating;
          if (c.studentFeedback != null && _feedbackController.text.isEmpty) {
            _feedbackController.text = c.studentFeedback!;
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _historyError = e.toString().replaceAll('Exception: ', '');
          _isLoadingHistory = false;
        });
      }
    }
  }

  Future<void> _submitFeedback() async {
    final studentId = Provider.of<UserProvider>(context, listen: false).user?.id;
    if (studentId == null || _selectedRating == null) return;

    setState(() => _isSubmittingFeedback = true);
    try {
      final updated = await _complaintService.submitFeedback(
        complaintId: _complaint.id,
        studentId: studentId,
        rating: _selectedRating!,
        feedback: _feedbackController.text.trim(),
      );
      if (mounted) {
        setState(() {
          _complaint = updated;
          _isSubmittingFeedback = false;
        });
        widget.onStatusChanged?.call();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Resolution feedback & rating submitted successfully!"),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSubmittingFeedback = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString()), backgroundColor: AppColors.danger),
        );
      }
    }
  }

  Future<void> _closeComplaint() async {
    final studentId = Provider.of<UserProvider>(context, listen: false).user?.id;
    if (studentId == null) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          "Close Complaint?",
          style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, color: AppColors.textPrimary),
        ),
        content: Text(
          "Are you satisfied with the resolution and ready to close this complaint?",
          style: GoogleFonts.plusJakartaSans(color: AppColors.textSecondary, fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text("Cancel", style: GoogleFonts.plusJakartaSans(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.success,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: Text("Confirm & Close", style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isPerformingAction = true);

    try {
      final updated = await _complaintService.takeAction(
        complaintId: _complaint.id,
        actorId: studentId,
        action: 'CLOSE',
        remarks: 'Student verified and closed issue',
      );

      if (!mounted) return;
      setState(() {
        _complaint = updated;
        _isPerformingAction = false;
      });
      widget.onStatusChanged?.call();
      _loadHistoryAndDetails();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Complaint closed successfully"), backgroundColor: AppColors.success),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isPerformingAction = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString()), backgroundColor: AppColors.danger),
      );
    }
  }

  Future<void> _reopenComplaint() async {
    final studentId = Provider.of<UserProvider>(context, listen: false).user?.id;
    if (studentId == null) return;

    final remarksController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    String? remarks;
    try {
      remarks = await showDialog<String>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: AppColors.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(
            "Reopen Complaint",
            style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, color: AppColors.textPrimary),
          ),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Please describe what remains unresolved so our staff can address it:",
                  style: GoogleFonts.plusJakartaSans(color: AppColors.textSecondary, fontSize: 13),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: remarksController,
                  maxLines: 3,
                  style: GoogleFonts.plusJakartaSans(color: AppColors.textPrimary),
                  decoration: InputDecoration(
                    hintText: "Reason for reopening...",
                    filled: true,
                    fillColor: AppColors.bg,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  validator: (val) => (val == null || val.trim().isEmpty) ? 'Please enter reopen remarks' : null,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text("Cancel", style: GoogleFonts.plusJakartaSans(color: AppColors.textSecondary)),
            ),
            ElevatedButton(
              onPressed: () {
                if (formKey.currentState!.validate()) {
                  Navigator.pop(ctx, remarksController.text.trim());
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.danger,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: Text("Reopen", style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      );
    } finally {
      remarksController.dispose();
    }

    if (remarks == null || remarks.isEmpty) return;

    setState(() => _isPerformingAction = true);

    try {
      final updated = await _complaintService.takeAction(
        complaintId: _complaint.id,
        actorId: studentId,
        action: 'REOPEN',
        remarks: remarks,
      );

      if (!mounted) return;
      setState(() {
        _complaint = updated;
        _isPerformingAction = false;
      });
      widget.onStatusChanged?.call();
      _loadHistoryAndDetails();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Complaint reopened for staff review"), backgroundColor: AppColors.warning),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isPerformingAction = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString()), backgroundColor: AppColors.danger),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    Color statusColor;
    Color statusBg;
    if (_complaint.isResolved) {
      statusColor = AppColors.success;
      statusBg = AppColors.success.withValues(alpha: 0.1);
    } else if (_complaint.isClosed) {
      statusColor = AppColors.textSecondary;
      statusBg = AppColors.border.withValues(alpha: 0.5);
    } else if (_complaint.isInProgress) {
      statusColor = AppColors.primary;
      statusBg = AppColors.primary.withValues(alpha: 0.1);
    } else if (_complaint.isAssigned) {
      statusColor = Colors.teal;
      statusBg = Colors.teal.withValues(alpha: 0.1);
    } else if (_complaint.isReopened) {
      statusColor = Colors.deepOrange;
      statusBg = Colors.deepOrange.withValues(alpha: 0.1);
    } else if (_complaint.isRejected) {
      statusColor = AppColors.danger;
      statusBg = AppColors.danger.withValues(alpha: 0.1);
    } else {
      statusColor = AppColors.warning;
      statusBg = AppColors.warning.withValues(alpha: 0.12);
    }

    final dateFormat = DateFormat('MMM dd, yyyy • hh:mm a');

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: const EdgeInsets.all(24),
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.88,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 48,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: AppColors.primaryLight.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      _complaint.category,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: statusBg,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      _complaint.status,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: statusColor,
                      ),
                    ),
                  ),
                ],
              ),
              IconButton(
                icon: const Icon(Icons.close_rounded, color: AppColors.textSecondary),
                onPressed: () => Navigator.pop(context),
                style: IconButton.styleFrom(
                  backgroundColor: AppColors.bg,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Title & Location
          Text(
            _complaint.title,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 19,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              const Icon(Icons.location_on_outlined, size: 14, color: AppColors.textSecondary),
              const SizedBox(width: 4),
              Text(
                _complaint.location,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(width: 12),
              const Icon(Icons.flag_outlined, size: 14, color: AppColors.textSecondary),
              const SizedBox(width: 4),
              Text(
                "Priority: ${_complaint.priority}",
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(height: 1, color: AppColors.border),
          const SizedBox(height: 16),

          // Scrollable body: Description, Resolution, History
          Expanded(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Description
                  Text(
                    "Description",
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _complaint.description,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 14,
                      color: AppColors.textPrimary.withValues(alpha: 0.9),
                      height: 1.45,
                    ),
                  ),

                  // --- FEATURE 2: PROOF-OF-FIX CLOSURE PIN CARD (ACTIVE TICKETS) ---
                  if (_complaint.closureOtp != null && !_complaint.isResolved && !_complaint.isClosed) ...[
                    const SizedBox(height: 16),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            const Color(0xFF1E3A8A).withValues(alpha: 0.08),
                            const Color(0xFF3B82F6).withValues(alpha: 0.04),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFF2563EB).withValues(alpha: 0.35), width: 1.5),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.shield_outlined, color: Color(0xFF2563EB), size: 18),
                              const SizedBox(width: 8),
                              Text(
                                "PROOF-OF-FIX CLOSURE PIN",
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.8,
                                  color: const Color(0xFF1E40AF),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: const Color(0xFF2563EB).withValues(alpha: 0.3)),
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color(0xFF2563EB).withValues(alpha: 0.08),
                                      blurRadius: 6,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: Text(
                                  _complaint.closureOtp!,
                                  style: GoogleFonts.spaceMono(
                                    fontSize: 22,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 6,
                                    color: const Color(0xFF1E3A8A),
                                  ),
                                ),
                              ),
                              ElevatedButton.icon(
                                onPressed: () {
                                  Clipboard.setData(ClipboardData(text: _complaint.closureOtp!));
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text("Closure PIN copied to clipboard"),
                                      duration: Duration(seconds: 2),
                                    ),
                                  );
                                },
                                icon: const Icon(Icons.copy_rounded, size: 16),
                                label: const Text("Copy PIN"),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF2563EB),
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                  elevation: 0,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Text(
                            "⚠️ Share this 4-digit PIN with maintenance staff ONLY AFTER they physically fix the issue in your presence. Staff CANNOT close this ticket without your PIN.",
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 11.5,
                              color: const Color(0xFF1E3A8A),
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  // --- FEATURE 2: SLA ESCALATION SLINGSHOT BANNER ---
                  if (_complaint.isTier3DeanSlingshot) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEF2F2),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFEF4444)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.bolt_rounded, color: Color(0xFFDC2626), size: 22),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  "SLA BREACH: DEAN SLINGSHOT ACTIVE",
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: const Color(0xFF991B1B),
                                  ),
                                ),
                                Text(
                                  "Ticket exceeded 48h SLA. ₹${_complaint.vendorPenaltyAmount.toStringAsFixed(0)} vendor deduction penalty debited against contractor.",
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 11,
                                    color: const Color(0xFFB91C1C),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ] else if (_complaint.isTier2WardenAlert) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFFBEB),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFF59E0B)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.warning_amber_rounded, color: Color(0xFFD97706), size: 20),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              "Tier 2 Escalation: Hostel Warden alerted for priority resolution (>24h SLA breach).",
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 11.5,
                                color: const Color(0xFF92400E),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  // Assigned staff info
                  if (_complaint.assignedToName != null) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.bg,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.engineering_rounded, color: AppColors.primary, size: 20),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  "Assigned Staff",
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 11,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                                Text(
                                  _complaint.assignedToName!,
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  // Resolution remarks & Proof-of-Fix Handshake info
                  if (_complaint.resolutionRemarks != null && _complaint.resolutionRemarks!.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppColors.success.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppColors.success.withValues(alpha: 0.25)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.check_circle_outline_rounded, color: AppColors.success, size: 18),
                              const SizedBox(width: 8),
                              Text(
                                "Resolution Remarks",
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.success,
                                ),
                              ),
                              const Spacer(),
                              if (_complaint.otpVerifiedAt != null)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: AppColors.success.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    "OTP Verified Handshake",
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.success,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _complaint.resolutionRemarks!,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 13.5,
                              color: AppColors.textPrimary,
                              height: 1.4,
                            ),
                          ),
                          if (_complaint.resolvedAt != null) ...[
                            const SizedBox(height: 6),
                            Text(
                              "Resolved: ${dateFormat.format(_complaint.resolvedAt!)}",
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 11,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],

                  // --- FEATURE 2: 5-STAR RATING & FEEDBACK SECTION (RESOLVED / CLOSED) ---
                  if (_complaint.isResolved || _complaint.isClosed) ...[
                    const SizedBox(height: 16),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppColors.border),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.03),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.star_rounded, color: Colors.amber, size: 20),
                              const SizedBox(width: 6),
                              Text(
                                "Rate Resolution Quality",
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: List.generate(5, (index) {
                              final starNum = index + 1;
                              final isSelected = (_selectedRating ?? 0) >= starNum;
                              return IconButton(
                                icon: Icon(
                                  isSelected ? Icons.star_rounded : Icons.star_outline_rounded,
                                  color: isSelected ? Colors.amber : Colors.grey.shade400,
                                  size: 32,
                                ),
                                onPressed: _isSubmittingFeedback
                                    ? null
                                    : () {
                                        setState(() => _selectedRating = starNum);
                                      },
                              );
                            }),
                          ),
                          TextField(
                            controller: _feedbackController,
                            decoration: InputDecoration(
                              hintText: "Was the issue permanently fixed? Add notes...",
                              hintStyle: GoogleFonts.plusJakartaSans(fontSize: 12.5),
                              filled: true,
                              fillColor: AppColors.bg,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: BorderSide.none,
                              ),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            ),
                            maxLines: 2,
                          ),
                          const SizedBox(height: 10),
                          Align(
                            alignment: Alignment.centerRight,
                            child: ElevatedButton(
                              onPressed: (_selectedRating == null || _isSubmittingFeedback)
                                  ? null
                                  : _submitFeedback,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primary,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                elevation: 0,
                              ),
                              child: _isSubmittingFeedback
                                  ? const SizedBox(
                                      width: 14,
                                      height: 14,
                                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                    )
                                  : Text(
                                      _complaint.studentRating != null ? "Update Feedback" : "Submit Rating",
                                      style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.bold),
                                    ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  // Actions if RESOLVED
                  if (_complaint.isResolved) ...[
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _isPerformingAction ? null : _reopenComplaint,
                            icon: const Icon(Icons.replay_rounded, size: 16),
                            label: const Text("Reopen"),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.danger,
                              side: const BorderSide(color: AppColors.danger),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _isPerformingAction ? null : _closeComplaint,
                            icon: const Icon(Icons.check_rounded, size: 16),
                            label: const Text("Close Issue"),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.success,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              elevation: 0,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],

                  const SizedBox(height: 24),

                  // Timeline / Status History
                  Text(
                    "Status History & Timeline",
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 14),

                  if (_isLoadingHistory)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.all(24.0),
                        child: CircularProgressIndicator(color: AppColors.primary),
                      ),
                    )
                  else if (_historyError != null)
                    Text(
                      _historyError!,
                      style: GoogleFonts.plusJakartaSans(color: AppColors.danger, fontSize: 13),
                    )
                  else if (_history.isEmpty)
                    Text(
                      "No history entries found",
                      style: GoogleFonts.plusJakartaSans(color: AppColors.textSecondary, fontSize: 13),
                    )
                  else
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _history.length,
                      itemBuilder: (context, idx) {
                        final h = _history[idx];
                        final isLast = idx == _history.length - 1;

                        Color dotColor = AppColors.primary;
                        if (h.newStatus == 'RESOLVED' || h.newStatus == 'CLOSED') {
                          dotColor = AppColors.success;
                        } else if (h.newStatus == 'REOPENED' || h.newStatus == 'REJECTED') {
                          dotColor = AppColors.danger;
                        }

                        return IntrinsicHeight(
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Timeline indicators
                              Column(
                                children: [
                                  Container(
                                    width: 12,
                                    height: 12,
                                    decoration: BoxDecoration(
                                      color: dotColor,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  if (!isLast)
                                    Expanded(
                                      child: Container(
                                        width: 2,
                                        color: AppColors.border,
                                      ),
                                    ),
                                ],
                              ),
                              const SizedBox(width: 14),
                              // Content
                              Expanded(
                                child: Padding(
                                  padding: const EdgeInsets.only(bottom: 20),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            h.oldStatus != null
                                                ? "${h.oldStatus} → ${h.newStatus}"
                                                : h.newStatus,
                                            style: GoogleFonts.plusJakartaSans(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 13,
                                              color: dotColor,
                                            ),
                                          ),
                                          Text(
                                            dateFormat.format(h.timestamp),
                                            style: GoogleFonts.plusJakartaSans(
                                              fontSize: 11,
                                              color: AppColors.textSecondary,
                                            ),
                                          ),
                                        ],
                                      ),
                                      if (h.remarks != null && h.remarks!.isNotEmpty) ...[
                                        const SizedBox(height: 3),
                                        Text(
                                          h.remarks!,
                                          style: GoogleFonts.plusJakartaSans(
                                            fontSize: 12.5,
                                            color: AppColors.textPrimary.withValues(alpha: 0.8),
                                          ),
                                        ),
                                      ],
                                      if (h.actorName != null) ...[
                                        const SizedBox(height: 2),
                                        Text(
                                          "By ${h.actorName} (${h.actorRole ?? 'Staff'})",
                                          style: GoogleFonts.plusJakartaSans(
                                            fontSize: 11,
                                            color: AppColors.textSecondary,
                                            fontStyle: FontStyle.italic,
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
