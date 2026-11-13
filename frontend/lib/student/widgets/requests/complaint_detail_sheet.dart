import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../auth/providers/user_provider.dart';
import '../../../core/haptics/app_haptics.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/motion/apple_bounceable.dart';
import '../../../shared/widgets/motion/apple_spring_scroll_physics.dart';
import '../../models/complaint_history_model.dart';
import '../../models/complaint_model.dart';
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
    final studentId =
        Provider.of<UserProvider>(context, listen: false).user?.id;
    if (mounted) {
      setState(() {
        _isLoadingHistory = true;
        _historyError = null;
      });
    }

    final targetId = _complaint.serverId ?? _complaint.id;
    try {
      final results = await Future.wait([
        _complaintService.getComplaint(targetId, requesterId: studentId),
        _complaintService.getComplaintHistory(targetId,
            requesterId: studentId),
      ]);

      if (mounted) {
        final c = results[0] as ComplaintModel;
        final h = results[1] as List<ComplaintHistoryModel>;
        setState(() {
          _complaint = (c.closureOtp != null && c.closureOtp!.isNotEmpty)
              ? c
              : (_complaint.closureOtp != null ? c.copyWith(closureOtp: _complaint.closureOtp) : c);
          _history = h;
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
          if (_history.isEmpty) {
            _history = [
              ComplaintHistoryModel(
                id: 'fallback_${_complaint.id}',
                complaintId: _complaint.id,
                changedBy: studentId ?? _complaint.studentId,
                actorName: 'You (Student)',
                actorRole: 'student',
                oldStatus: null,
                newStatus: _complaint.status,
                remarks: 'Complaint submitted',
                timestamp: _complaint.createdAt,
              ),
            ];
          }
          _historyError = null;
          _isLoadingHistory = false;
        });
      }
    }
  }

  Future<void> _submitFeedback() async {
    final studentId =
        Provider.of<UserProvider>(context, listen: false).user?.id;
    if (studentId == null || _selectedRating == null) return;

    AppHaptics.mediumImpact();
    setState(() => _isSubmittingFeedback = true);
    try {
      final updated = await _complaintService.submitFeedback(
        complaintId: _complaint.serverId ?? _complaint.id,
        studentId: studentId,
        rating: _selectedRating!,
        feedback: _feedbackController.text.trim(),
      );
      if (mounted) {
        AppHaptics.mediumImpact();
        setState(() {
          _complaint = updated;
          _isSubmittingFeedback = false;
        });
        widget.onStatusChanged?.call();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content:
                Text("Resolution feedback & rating submitted successfully!"),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        AppHaptics.vibrate();
        setState(() => _isSubmittingFeedback = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(e.toString()), backgroundColor: AppColors.danger),
        );
      }
    }
  }

  Future<void> _closeComplaint() async {
    final studentId =
        Provider.of<UserProvider>(context, listen: false).user?.id;
    if (studentId == null) return;

    AppHaptics.selectionClick();
    final surfaceColor = AppColors.surfaceOf(context);
    final borderColor = AppColors.borderOf(context);
    final textColor = AppColors.textPrimaryOf(context);
    final textSec = AppColors.textSecondaryOf(context);

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: surfaceColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        title: Text(
          "Close Complaint?",
          style: GoogleFonts.plusJakartaSans(
            fontWeight: FontWeight.bold,
            color: textColor,
            letterSpacing: -0.3,
          ),
        ),
        content: Text(
          "Are you satisfied with the resolution and ready to close this complaint?",
          style: GoogleFonts.plusJakartaSans(
            color: textSec,
            fontSize: 14,
            height: 1.4,
          ),
        ),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        actions: [
          AppleBounceable(
            onTap: () {
              AppHaptics.selectionClick();
              Navigator.pop(ctx, false);
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: borderColor, width: 0.6),
              ),
              child: Text(
                "Cancel",
                style: GoogleFonts.plusJakartaSans(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                  color: textSec,
                ),
              ),
            ),
          ),
          AppleBounceable(
            onTap: () {
              AppHaptics.mediumImpact();
              Navigator.pop(ctx, true);
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.success,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                "Confirm & Close",
                style: GoogleFonts.plusJakartaSans(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isPerformingAction = true);

    try {
      final updated = await _complaintService.takeAction(
        complaintId: _complaint.serverId ?? _complaint.id,
        actorId: studentId,
        action: 'CLOSE',
        remarks: 'Student verified and closed issue',
      );

      if (!mounted) return;
      AppHaptics.mediumImpact();
      setState(() {
        _complaint = updated;
        _isPerformingAction = false;
      });
      widget.onStatusChanged?.call();
      _loadHistoryAndDetails();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Complaint closed successfully"),
          backgroundColor: AppColors.success,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      AppHaptics.vibrate();
      setState(() => _isPerformingAction = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(e.toString()), backgroundColor: AppColors.danger),
      );
    }
  }

  Future<void> _reopenComplaint() async {
    final studentId =
        Provider.of<UserProvider>(context, listen: false).user?.id;
    if (studentId == null) return;

    AppHaptics.selectionClick();
    final remarksController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    final surfaceColor = AppColors.surfaceOf(context);
    final bgColor = AppColors.bgOf(context);
    final borderColor = AppColors.borderOf(context);
    final textColor = AppColors.textPrimaryOf(context);
    final textSec = AppColors.textSecondaryOf(context);

    String? remarks;
    try {
      remarks = await showDialog<String>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: surfaceColor,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
          title: Text(
            "Reopen Complaint",
            style: GoogleFonts.plusJakartaSans(
              fontWeight: FontWeight.bold,
              color: textColor,
              letterSpacing: -0.3,
            ),
          ),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Please describe what remains unresolved so our staff can address it:",
                  style: GoogleFonts.plusJakartaSans(
                    color: textSec,
                    fontSize: 13,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: remarksController,
                  maxLines: 3,
                  style: GoogleFonts.plusJakartaSans(
                      fontSize: 14, color: textColor),
                  decoration: InputDecoration(
                    hintText: "Reason for reopening...",
                    hintStyle: GoogleFonts.plusJakartaSans(
                        fontSize: 13, color: textSec.withValues(alpha: 0.6)),
                    filled: true,
                    fillColor: bgColor,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(color: borderColor, width: 0.6),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(color: borderColor, width: 0.6),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide:
                          const BorderSide(color: AppColors.danger, width: 1.5),
                    ),
                    contentPadding: const EdgeInsets.all(12),
                  ),
                  validator: (val) => (val == null || val.trim().isEmpty)
                      ? 'Please enter reopen remarks'
                      : null,
                ),
              ],
            ),
          ),
          actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          actions: [
            AppleBounceable(
              onTap: () {
                AppHaptics.selectionClick();
                Navigator.pop(ctx);
              },
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: borderColor, width: 0.6),
                ),
                child: Text(
                  "Cancel",
                  style: GoogleFonts.plusJakartaSans(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                    color: textSec,
                  ),
                ),
              ),
            ),
            AppleBounceable(
              onTap: () {
                if (formKey.currentState!.validate()) {
                  AppHaptics.mediumImpact();
                  Navigator.pop(ctx, remarksController.text.trim());
                } else {
                  AppHaptics.vibrate();
                }
              },
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                decoration: BoxDecoration(
                  color: AppColors.danger,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  "Reopen",
                  style: GoogleFonts.plusJakartaSans(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: Colors.white,
                  ),
                ),
              ),
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
        complaintId: _complaint.serverId ?? _complaint.id,
        actorId: studentId,
        action: 'REOPEN',
        remarks: remarks,
      );

      if (!mounted) return;
      AppHaptics.mediumImpact();
      setState(() {
        _complaint = updated;
        _isPerformingAction = false;
      });
      widget.onStatusChanged?.call();
      _loadHistoryAndDetails();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Complaint reopened for staff review"),
          backgroundColor: AppColors.warning,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      AppHaptics.vibrate();
      setState(() => _isPerformingAction = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(e.toString()), backgroundColor: AppColors.danger),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    Color statusColor;
    Color statusBg;
    IconData statusIcon;

    if (_complaint.isResolved) {
      statusColor = AppColors.success;
      statusBg = AppColors.success.withValues(alpha: 0.1);
      statusIcon = Icons.check_circle_outline_rounded;
    } else if (_complaint.isClosed) {
      statusColor = const Color(0xFF64748B);
      statusBg = const Color(0xFF64748B).withValues(alpha: 0.1);
      statusIcon = Icons.lock_outline_rounded;
    } else if (_complaint.isInProgress) {
      statusColor = AppColors.primary;
      statusBg = AppColors.primary.withValues(alpha: 0.1);
      statusIcon = Icons.autorenew_rounded;
    } else if (_complaint.isAssigned) {
      statusColor = const Color(0xFF0D9488);
      statusBg = const Color(0xFF0D9488).withValues(alpha: 0.1);
      statusIcon = Icons.assignment_ind_outlined;
    } else if (_complaint.isReopened) {
      statusColor = const Color(0xFFEA580C);
      statusBg = const Color(0xFFEA580C).withValues(alpha: 0.1);
      statusIcon = Icons.replay_rounded;
    } else if (_complaint.isRejected) {
      statusColor = AppColors.danger;
      statusBg = AppColors.danger.withValues(alpha: 0.1);
      statusIcon = Icons.cancel_outlined;
    } else {
      statusColor = const Color(0xFFD97706);
      statusBg = const Color(0xFFD97706).withValues(alpha: 0.12);
      statusIcon = Icons.schedule_rounded;
    }

    final dateFormat = DateFormat('MMM dd, yyyy • hh:mm a');
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surfaceColor = AppColors.surfaceOf(context);
    final bgColor = AppColors.bgOf(context);
    final borderColor = AppColors.borderOf(context);
    final textColor = AppColors.textPrimaryOf(context);
    final textSec = AppColors.textSecondaryOf(context);

    Color priorityColor;
    switch (_complaint.priority.toUpperCase()) {
      case 'URGENT':
        priorityColor = AppColors.danger;
        break;
      case 'HIGH':
        priorityColor = const Color(0xFFD97706);
        break;
      case 'MEDIUM':
        priorityColor = AppColors.primary;
        break;
      default:
        priorityColor = const Color(0xFF64748B);
    }

    return Container(
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.4 : 0.12),
            blurRadius: 24,
            offset: const Offset(0, -6),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.88,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // iOS Drag handle
          Center(
            child: Container(
              width: 36,
              height: 5,
              decoration: BoxDecoration(
                color: borderColor,
                borderRadius: BorderRadius.circular(2.5),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Top Header Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: AppColors.primaryLight.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(10),
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
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: statusBg,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(statusIcon, size: 12, color: statusColor),
                        const SizedBox(width: 4),
                        Text(
                          _complaint.status,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: statusColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              AppleBounceable(
                onTap: () => Navigator.pop(context),
                child: Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: bgColor,
                    shape: BoxShape.circle,
                    border: Border.all(color: borderColor, width: 0.6),
                  ),
                  child: Icon(Icons.close_rounded, size: 18, color: textSec),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Title & Location & Priority
          Text(
            _complaint.title,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 19,
              fontWeight: FontWeight.bold,
              color: textColor,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(Icons.location_on_outlined, size: 15, color: textSec),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  _complaint.location,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 13,
                    color: textSec,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 12),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: priorityColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _complaint.priority.toUpperCase() == 'URGENT'
                          ? Icons.local_fire_department_rounded
                          : Icons.flag_outlined,
                      size: 13,
                      color: priorityColor,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      _complaint.priority,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: priorityColor,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Divider(height: 1, color: borderColor, thickness: 0.6),
          const SizedBox(height: 16),

          // Scrollable Body: Description, Proof-of-Fix OTP, SLA, Staff, Rating, History
          Expanded(
            child: SingleChildScrollView(
              physics: AppleSpringScrollPhysics.always,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Description
                  _buildSectionLabel("DESCRIPTION", textSec),
                  const SizedBox(height: 6),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: bgColor,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: borderColor, width: 0.6),
                    ),
                    child: Text(
                      _complaint.description,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 14,
                        color: textColor.withValues(alpha: 0.9),
                        height: 1.5,
                      ),
                    ),
                  ),

                  // FEATURE 2: PROOF-OF-FIX CLOSURE PIN CARD (ACTIVE TICKETS)
                  if (_complaint.closureOtp != null &&
                      !_complaint.isResolved &&
                      !_complaint.isClosed) ...[
                    const SizedBox(height: 16),
                    Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            const Color(0xFF1E3A8A).withValues(alpha: 0.08),
                            const Color(0xFF3B82F6).withValues(alpha: 0.04),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: const Color(0xFF2563EB)
                              .withValues(alpha: 0.35),
                          width: 1.2,
                        ),
                      ),
                      padding: const EdgeInsets.all(18),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 28,
                                height: 28,
                                decoration: BoxDecoration(
                                  color: const Color(0xFF2563EB)
                                      .withValues(alpha: 0.15),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.shield_outlined,
                                    color: Color(0xFF2563EB), size: 16),
                              ),
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
                          const SizedBox(height: 14),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 18, vertical: 10),
                                decoration: BoxDecoration(
                                  color: surfaceColor,
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                    color: const Color(0xFF2563EB)
                                        .withValues(alpha: 0.3),
                                    width: 1,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color(0xFF2563EB)
                                          .withValues(alpha: 0.08),
                                      blurRadius: 8,
                                      offset: const Offset(0, 3),
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
                              AppleBounceable(
                                onTap: () {
                                  AppHaptics.selectionClick();
                                  Clipboard.setData(ClipboardData(
                                      text: _complaint.closureOtp!));
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                          "Closure PIN copied to clipboard"),
                                      duration: Duration(seconds: 2),
                                    ),
                                  );
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 16, vertical: 11),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF2563EB),
                                    borderRadius: BorderRadius.circular(12),
                                    boxShadow: [
                                      BoxShadow(
                                        color: const Color(0xFF2563EB)
                                            .withValues(alpha: 0.3),
                                        blurRadius: 8,
                                        offset: const Offset(0, 3),
                                      ),
                                    ],
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.copy_rounded,
                                          size: 15, color: Colors.white),
                                      const SizedBox(width: 6),
                                      Text(
                                        "Copy PIN",
                                        style: GoogleFonts.plusJakartaSans(
                                          fontSize: 13,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Text(
                            "⚠️ Share this 4-digit PIN with maintenance staff ONLY AFTER they physically fix the issue in your presence. Staff CANNOT close this ticket without your PIN.",
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 11.5,
                              color: const Color(0xFF1E3A8A),
                              height: 1.45,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  // FEATURE 2: SLA ESCALATION SLINGSHOT BANNER
                  if (_complaint.isTier3DeanSlingshot) ...[
                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEF2F2),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                            color: const Color(0xFFEF4444), width: 1),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: const Color(0xFFEF4444)
                                  .withValues(alpha: 0.15),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.bolt_rounded,
                                color: Color(0xFFDC2626), size: 20),
                          ),
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
                                const SizedBox(height: 2),
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
                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFFBEB),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                            color: const Color(0xFFF59E0B), width: 1),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.warning_amber_rounded,
                              color: Color(0xFFD97706), size: 20),
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
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: bgColor,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: borderColor, width: 0.6),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: AppColors.primaryLight
                                  .withValues(alpha: 0.5),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.engineering_rounded,
                                color: AppColors.primary, size: 20),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  "Assigned Staff",
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 11,
                                    color: textSec,
                                  ),
                                ),
                                Text(
                                  _complaint.assignedToName!,
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.bold,
                                    color: textColor,
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
                  if (_complaint.resolutionRemarks != null &&
                      _complaint.resolutionRemarks!.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.success.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                            color: AppColors.success.withValues(alpha: 0.25),
                            width: 0.8),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.check_circle_outline_rounded,
                                  color: AppColors.success, size: 18),
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
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: AppColors.success
                                        .withValues(alpha: 0.15),
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
                              color: textColor,
                              height: 1.45,
                            ),
                          ),
                          if (_complaint.resolvedAt != null) ...[
                            const SizedBox(height: 6),
                            Text(
                              "Resolved: ${dateFormat.format(_complaint.resolvedAt!)}",
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 11,
                                color: textSec,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],

                  // FEATURE 2: 5-STAR RATING & FEEDBACK SECTION (RESOLVED / CLOSED)
                  if (_complaint.isResolved || _complaint.isClosed) ...[
                    const SizedBox(height: 18),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: surfaceColor,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: borderColor, width: 0.6),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.03),
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
                              const Icon(Icons.star_rounded,
                                  color: Colors.amber, size: 20),
                              const SizedBox(width: 8),
                              Text(
                                "Rate Resolution Quality",
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: textColor,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: List.generate(5, (index) {
                              final starNum = index + 1;
                              final isSelected =
                                  (_selectedRating ?? 0) >= starNum;
                              return AppleBounceable(
                                onTap: _isSubmittingFeedback
                                    ? null
                                    : () {
                                        AppHaptics.selectionClick();
                                        setState(
                                            () => _selectedRating = starNum);
                                      },
                                child: Padding(
                                  padding:
                                      const EdgeInsets.symmetric(horizontal: 6),
                                  child: Icon(
                                    isSelected
                                        ? Icons.star_rounded
                                        : Icons.star_outline_rounded,
                                    color: isSelected
                                        ? Colors.amber
                                        : textSec.withValues(alpha: 0.4),
                                    size: 34,
                                  ),
                                ),
                              );
                            }),
                          ),
                          const SizedBox(height: 14),
                          TextField(
                            controller: _feedbackController,
                            style: GoogleFonts.plusJakartaSans(
                                fontSize: 13.5, color: textColor),
                            decoration: InputDecoration(
                              hintText:
                                  "Was the issue permanently fixed? Add notes...",
                              hintStyle: GoogleFonts.plusJakartaSans(
                                  fontSize: 12.5,
                                  color: textSec.withValues(alpha: 0.6)),
                              filled: true,
                              fillColor: bgColor,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide:
                                    BorderSide(color: borderColor, width: 0.6),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide:
                                    BorderSide(color: borderColor, width: 0.6),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide: const BorderSide(
                                    color: AppColors.primary, width: 1.5),
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 12),
                            ),
                            maxLines: 2,
                          ),
                          const SizedBox(height: 12),
                          Align(
                            alignment: Alignment.centerRight,
                            child: AppleBounceable(
                              onTap: (_selectedRating == null ||
                                      _isSubmittingFeedback)
                                  ? null
                                  : _submitFeedback,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 18, vertical: 10),
                                decoration: BoxDecoration(
                                  color: _selectedRating != null
                                      ? AppColors.primary
                                      : textSec.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: _isSubmittingFeedback
                                    ? const SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: Colors.white),
                                      )
                                    : Text(
                                        _complaint.studentRating != null
                                            ? "Update Feedback"
                                            : "Submit Rating",
                                        style: GoogleFonts.plusJakartaSans(
                                          fontSize: 12.5,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                        ),
                                      ),
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
                          child: AppleBounceable(
                            onTap:
                                _isPerformingAction ? null : _reopenComplaint,
                            child: Container(
                              height: 48,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                    color: AppColors.danger, width: 1),
                              ),
                              alignment: Alignment.center,
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(Icons.replay_rounded,
                                      size: 16, color: AppColors.danger),
                                  const SizedBox(width: 6),
                                  Text(
                                    "Reopen Issue",
                                    style: GoogleFonts.plusJakartaSans(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13.5,
                                      color: AppColors.danger,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: AppleBounceable(
                            onTap:
                                _isPerformingAction ? null : _closeComplaint,
                            child: Container(
                              height: 48,
                              decoration: BoxDecoration(
                                color: AppColors.success,
                                borderRadius: BorderRadius.circular(14),
                                boxShadow: [
                                  BoxShadow(
                                    color: AppColors.success
                                        .withValues(alpha: 0.3),
                                    blurRadius: 8,
                                    offset: const Offset(0, 3),
                                  ),
                                ],
                              ),
                              alignment: Alignment.center,
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(Icons.check_rounded,
                                      size: 17, color: Colors.white),
                                  const SizedBox(width: 6),
                                  Text(
                                    "Close Issue",
                                    style: GoogleFonts.plusJakartaSans(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13.5,
                                      color: Colors.white,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],

                  const SizedBox(height: 24),

                  // Timeline / Status History Header
                  Row(
                    children: [
                      _buildSectionLabel(
                          "STATUS HISTORY & TIMELINE", textSec),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: borderColor,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          "${_history.length}",
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: textSec,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  if (_isLoadingHistory)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.all(24.0),
                        child:
                            CircularProgressIndicator(color: AppColors.primary),
                      ),
                    )
                  else if (_historyError != null)
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.danger.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Text(
                        _historyError!,
                        style: GoogleFonts.plusJakartaSans(
                          color: AppColors.danger,
                          fontSize: 13,
                        ),
                      ),
                    )
                  else if (_history.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: bgColor,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: borderColor, width: 0.6),
                      ),
                      child: Center(
                        child: Text(
                          "No status transitions logged yet",
                          style: GoogleFonts.plusJakartaSans(
                            color: textSec,
                            fontSize: 13,
                          ),
                        ),
                      ),
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
                        if (h.newStatus == 'RESOLVED' ||
                            h.newStatus == 'CLOSED') {
                          dotColor = AppColors.success;
                        } else if (h.newStatus == 'REOPENED' ||
                            h.newStatus == 'REJECTED') {
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
                                    width: 14,
                                    height: 14,
                                    decoration: BoxDecoration(
                                      color: dotColor,
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: surfaceColor,
                                        width: 2.5,
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: dotColor
                                              .withValues(alpha: 0.4),
                                          blurRadius: 4,
                                          offset: const Offset(0, 1),
                                        ),
                                      ],
                                    ),
                                  ),
                                  if (!isLast)
                                    Expanded(
                                      child: Container(
                                        width: 1.5,
                                        color: borderColor,
                                      ),
                                    ),
                                ],
                              ),
                              const SizedBox(width: 14),
                              // Content Cardlet
                              Expanded(
                                child: Padding(
                                  padding: const EdgeInsets.only(bottom: 20),
                                  child: Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: bgColor,
                                      borderRadius: BorderRadius.circular(14),
                                      border: Border.all(
                                          color: borderColor, width: 0.5),
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.spaceBetween,
                                          children: [
                                            Text(
                                              h.oldStatus != null
                                                  ? "${h.oldStatus} → ${h.newStatus}"
                                                  : h.newStatus,
                                              style:
                                                  GoogleFonts.plusJakartaSans(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 13,
                                                color: dotColor,
                                              ),
                                            ),
                                            Text(
                                              dateFormat.format(h.timestamp),
                                              style:
                                                  GoogleFonts.plusJakartaSans(
                                                fontSize: 11,
                                                color: textSec,
                                              ),
                                            ),
                                          ],
                                        ),
                                        if (h.remarks != null &&
                                            h.remarks!.isNotEmpty) ...[
                                          const SizedBox(height: 4),
                                          Text(
                                            h.remarks!,
                                            style:
                                                GoogleFonts.plusJakartaSans(
                                              fontSize: 12.5,
                                              color: textColor
                                                  .withValues(alpha: 0.85),
                                              height: 1.35,
                                            ),
                                          ),
                                        ],
                                        if (h.actorName != null) ...[
                                          const SizedBox(height: 4),
                                          Text(
                                            "By ${h.actorName} (${h.actorRole ?? 'Staff'})",
                                            style:
                                                GoogleFonts.plusJakartaSans(
                                              fontSize: 11,
                                              color: textSec,
                                              fontStyle: FontStyle.italic,
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
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

  Widget _buildSectionLabel(String text, Color color) {
    return Text(
      text,
      style: GoogleFonts.plusJakartaSans(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.8,
        color: color,
      ),
    );
  }
}
