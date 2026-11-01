import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../auth/models/user_model.dart';
import '../models/admin_dashboard_models.dart';
import '../services/admin_dashboard_service.dart';

class AdminComplaintDetailSheet extends StatefulWidget {
  final String complaintId;
  final UserModel? currentUser;
  final VoidCallback onActionCompleted;

  const AdminComplaintDetailSheet({
    Key? key,
    required this.complaintId,
    required this.currentUser,
    required this.onActionCompleted,
  }) : super(key: key);

  @override
  State<AdminComplaintDetailSheet> createState() => _AdminComplaintDetailSheetState();
}

class _AdminComplaintDetailSheetState extends State<AdminComplaintDetailSheet> {
  final AdminDashboardService _service = AdminDashboardService();
  bool _isLoading = true;
  String? _errorMessage;
  AdminComplaintDetailModel? _detail;
  bool _isProcessingAction = false;

  @override
  void initState() {
    super.initState();
    _loadDetail();
  }

  Future<void> _loadDetail() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final detail = await _service.getComplaintDetail(
        widget.complaintId,
        requesterId: widget.currentUser?.id,
      );
      if (mounted) {
        setState(() {
          _detail = detail;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString().replaceAll('Exception:', '');
          _isLoading = false;
        });
      }
    }
  }

  Color _getStatusColor(String status) {
    switch (status.toUpperCase()) {
      case 'PENDING':
        return const Color(0xFFF59E0B);
      case 'ASSIGNED':
        return const Color(0xFF3B82F6);
      case 'IN_PROGRESS':
        return const Color(0xFF8B5CF6);
      case 'RESOLVED':
        return const Color(0xFF10B981);
      case 'CLOSED':
        return const Color(0xFF64748B);
      case 'REOPENED':
        return const Color(0xFFEF4444);
      case 'REJECTED':
        return const Color(0xFFDC2626);
      default:
        return const Color(0xFF6B7280);
    }
  }

  Color _getPriorityColor(String priority) {
    switch (priority.toUpperCase()) {
      case 'URGENT':
        return const Color(0xFFDC2626);
      case 'HIGH':
        return const Color(0xFFF97316);
      case 'MEDIUM':
        return const Color(0xFF3B82F6);
      case 'LOW':
        return const Color(0xFF6B7280);
      default:
        return const Color(0xFF6B7280);
    }
  }

  Future<void> _handleAssign() async {
    List<StaffUserModel> staffList = [];
    try {
      staffList = await _service.getStaffList(requesterId: widget.currentUser?.id);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load staff list: $e')),
        );
      }
      return;
    }

    if (!mounted) return;

    String? selectedStaffId = staffList.isNotEmpty ? staffList.first.id : null;
    final remarksController = TextEditingController();

    try {
      final result = await showDialog<bool>(
        context: context,
        builder: (ctx) => StatefulBuilder(
          builder: (ctx, setDialogState) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Text(
              'Assign Staff Member',
              style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Select operational staff / faculty to handle this complaint:',
                  style: GoogleFonts.outfit(fontSize: 13, color: Colors.grey.shade700),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: selectedStaffId,
                  decoration: InputDecoration(
                    labelText: 'Staff Member',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  ),
                  items: staffList.map((s) {
                    return DropdownMenuItem<String>(
                      value: s.id,
                      child: Text('${s.name} (${s.role})'),
                    );
                  }).toList(),
                  onChanged: (val) {
                    setDialogState(() => selectedStaffId = val);
                  },
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: remarksController,
                  decoration: InputDecoration(
                    labelText: 'Instructions / Remarks (Optional)',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  maxLines: 2,
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: Text('Cancel', style: GoogleFonts.outfit()),
              ),
              ElevatedButton(
                onPressed: selectedStaffId == null
                    ? null
                    : () => Navigator.pop(ctx, true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1E3A8A),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: Text('Confirm Assignment', style: GoogleFonts.outfit(fontWeight: FontWeight.w600)),
              ),
            ],
          ),
        ),
      );

      if (result == true && selectedStaffId != null) {
        _executeAction(
          actionName: 'Assign',
          call: () => _service.assignComplaint(
            complaintId: widget.complaintId,
            actorId: widget.currentUser?.id ?? '',
            assignedTo: selectedStaffId!,
            remarks: remarksController.text.trim().isNotEmpty
                ? remarksController.text.trim()
                : null,
          ),
        );
      }
    } finally {
      remarksController.dispose();
    }
  }

  Future<void> _handleStart() async {
    _executeAction(
      actionName: 'Start',
      call: () => _service.takeComplaintAction(
        complaintId: widget.complaintId,
        actorId: widget.currentUser?.id ?? '',
        action: 'START',
        remarks: 'Staff commenced resolution work',
      ),
    );
  }

  Future<void> _handleResolve() async {
    final remarksController = TextEditingController();
    final otpController = TextEditingController();
    try {
      final result = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              const Icon(Icons.verified_user_rounded, color: Color(0xFF10B981), size: 22),
              const SizedBox(width: 8),
              Text('Resolve Complaint', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Enter the 4-digit PIN provided by the student upon physical inspection and completion:',
                style: GoogleFonts.outfit(fontSize: 13, color: Colors.grey.shade700),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: otpController,
                keyboardType: TextInputType.number,
                maxLength: 4,
                decoration: InputDecoration(
                  labelText: 'Student Closure OTP *',
                  hintText: '4-digit PIN from student',
                  prefixIcon: const Icon(Icons.pin_rounded, color: Color(0xFF10B981)),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  counterText: "",
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: remarksController,
                decoration: InputDecoration(
                  labelText: 'Resolution Remarks *',
                  hintText: 'e.g. Electrician repaired switch board and tested cut-off',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
                maxLines: 2,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text('Cancel', style: GoogleFonts.outfit()),
            ),
            ElevatedButton(
              onPressed: () {
                if (otpController.text.trim().length != 4) {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    const SnackBar(content: Text('A 4-digit Student Closure OTP is required')),
                  );
                  return;
                }
                if (remarksController.text.trim().isEmpty) {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    const SnackBar(content: Text('Resolution remarks are required')),
                  );
                  return;
                }
                Navigator.pop(ctx, true);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF10B981),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: Text('Verify & Resolve', style: GoogleFonts.outfit(fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      );

      if (result == true) {
        _executeAction(
          actionName: 'Resolve',
          call: () => _service.verifyResolveComplaint(
            complaintId: widget.complaintId,
            actorId: widget.currentUser?.id ?? '',
            otp: otpController.text.trim(),
            remarks: remarksController.text.trim(),
          ),
        );
      }
    } finally {
      remarksController.dispose();
      otpController.dispose();
    }
  }

  Future<void> _handleClose() async {
    _executeAction(
      actionName: 'Close',
      call: () => _service.takeComplaintAction(
        complaintId: widget.complaintId,
        actorId: widget.currentUser?.id ?? '',
        action: 'CLOSE',
        remarks: 'Closed by administrator',
      ),
    );
  }

  Future<void> _handleReopen() async {
    final remarksController = TextEditingController();
    try {
      final result = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text('Reopen Complaint', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Specify reason for reopening this complaint:',
                style: GoogleFonts.outfit(fontSize: 13, color: Colors.grey.shade700),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: remarksController,
                decoration: InputDecoration(
                  labelText: 'Reopen Remarks *',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
                maxLines: 3,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text('Cancel', style: GoogleFonts.outfit()),
            ),
            ElevatedButton(
              onPressed: () {
                if (remarksController.text.trim().isEmpty) {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    const SnackBar(content: Text('Remarks are required to reopen')),
                  );
                  return;
                }
                Navigator.pop(ctx, true);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFEF4444),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: Text('Reopen Complaint', style: GoogleFonts.outfit(fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      );

      if (result == true) {
        _executeAction(
          actionName: 'Reopen',
          call: () => _service.takeComplaintAction(
            complaintId: widget.complaintId,
            actorId: widget.currentUser?.id ?? '',
            action: 'REOPEN',
            remarks: remarksController.text.trim(),
          ),
        );
      }
    } finally {
      remarksController.dispose();
    }
  }

  Future<void> _handleReject() async {
    final remarksController = TextEditingController();
    try {
      final result = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text('Reject Complaint', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Specify reason for rejecting this complaint:',
                style: GoogleFonts.outfit(fontSize: 13, color: Colors.grey.shade700),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: remarksController,
                decoration: InputDecoration(
                  labelText: 'Rejection Reason',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
                maxLines: 2,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text('Cancel', style: GoogleFonts.outfit()),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFDC2626),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: Text('Reject', style: GoogleFonts.outfit(fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      );

      if (result == true) {
        _executeAction(
          actionName: 'Reject',
          call: () => _service.takeComplaintAction(
            complaintId: widget.complaintId,
            actorId: widget.currentUser?.id ?? '',
            action: 'REJECT',
            remarks: remarksController.text.trim().isNotEmpty
                ? remarksController.text.trim()
                : 'Rejected by admin',
          ),
        );
      }
    } finally {
      remarksController.dispose();
    }
  }

  Future<void> _executeAction({
    required String actionName,
    required Future<void> Function() call,
  }) async {
    setState(() => _isProcessingAction = true);
    try {
      await call();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Complaint $actionName successful!'),
            backgroundColor: const Color(0xFF10B981),
          ),
        );
        widget.onActionCompleted();
        _loadDetail();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Action failed: ${e.toString().replaceAll("Exception:", "")}'),
            backgroundColor: const Color(0xFFDC2626),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isProcessingAction = false);
      }
    }
  }

  Widget _buildContextAwareActions(String status) {
    if (_isProcessingAction) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: CircularProgressIndicator(),
        ),
      );
    }

    final upperStatus = status.toUpperCase();
    final List<Widget> buttons = [];

    if (upperStatus == 'PENDING') {
      buttons.add(
        Expanded(
          child: ElevatedButton.icon(
            onPressed: _handleAssign,
            icon: const Icon(Icons.person_add_alt_1_rounded, size: 18),
            label: Text('Assign Staff', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1E3A8A),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ),
      );
      buttons.add(const SizedBox(width: 10));
      buttons.add(
        Expanded(
          child: OutlinedButton.icon(
            onPressed: _handleReject,
            icon: const Icon(Icons.close_rounded, size: 18),
            label: Text('Reject', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFFDC2626),
              side: const BorderSide(color: Color(0xFFDC2626)),
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ),
      );
    } else if (upperStatus == 'ASSIGNED') {
      buttons.add(
        Expanded(
          child: ElevatedButton.icon(
            onPressed: _handleStart,
            icon: const Icon(Icons.play_arrow_rounded, size: 18),
            label: Text('Start Work', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF8B5CF6),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ),
      );
    } else if (upperStatus == 'IN_PROGRESS') {
      buttons.add(
        Expanded(
          child: ElevatedButton.icon(
            onPressed: _handleResolve,
            icon: const Icon(Icons.check_circle_outline_rounded, size: 18),
            label: Text('Mark Resolved', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF10B981),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ),
      );
    } else if (upperStatus == 'RESOLVED') {
      buttons.add(
        Expanded(
          child: ElevatedButton.icon(
            onPressed: _handleClose,
            icon: const Icon(Icons.lock_outline_rounded, size: 18),
            label: Text('Close Ticket', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF64748B),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ),
      );
      buttons.add(const SizedBox(width: 10));
      buttons.add(
        Expanded(
          child: OutlinedButton.icon(
            onPressed: _handleReopen,
            icon: const Icon(Icons.refresh_rounded, size: 18),
            label: Text('Reopen', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFFEF4444),
              side: const BorderSide(color: Color(0xFFEF4444)),
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ),
      );
    } else if (upperStatus == 'REOPENED') {
      buttons.add(
        Expanded(
          child: ElevatedButton.icon(
            onPressed: _handleStart,
            icon: const Icon(Icons.play_arrow_rounded, size: 18),
            label: Text('Resume Work', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF8B5CF6),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ),
      );
      buttons.add(const SizedBox(width: 10));
      buttons.add(
        Expanded(
          child: OutlinedButton.icon(
            onPressed: _handleAssign,
            icon: const Icon(Icons.swap_horiz_rounded, size: 18),
            label: Text('Reassign', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFF1E3A8A),
              side: const BorderSide(color: Color(0xFF1E3A8A)),
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ),
      );
    }

    if (buttons.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.lock_rounded, size: 16, color: Colors.grey),
            const SizedBox(width: 8),
            Text(
              'No further actions available for this ticket state ($upperStatus)',
              style: GoogleFonts.outfit(fontSize: 13, color: Colors.grey.shade600),
            ),
          ],
        ),
      );
    }

    return Row(children: buttons);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        top: 16,
        left: 20,
        right: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: _isLoading
          ? const SizedBox(
              height: 350,
              child: Center(child: CircularProgressIndicator()),
            )
          : _errorMessage != null
              ? SizedBox(
                  height: 250,
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error_outline_rounded, color: Colors.red, size: 40),
                        const SizedBox(height: 12),
                        Text(_errorMessage!, style: GoogleFonts.outfit(color: Colors.red)),
                        const SizedBox(height: 16),
                        ElevatedButton(onPressed: _loadDetail, child: const Text('Retry')),
                      ],
                    ),
                  ),
                )
              : _buildContent(),
    );
  }

  Widget _buildContent() {
    final complaint = _detail!.complaint;
    final student = _detail!.student;
    final staff = _detail!.assignedStaff;
    final statusColor = _getStatusColor(complaint.status);
    final priorityColor = _getPriorityColor(complaint.priority);

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Header: Category & ID
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  complaint.category.toUpperCase(),
                  style: GoogleFonts.outfit(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey.shade800,
                  ),
                ),
              ),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: priorityColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      complaint.priority,
                      style: GoogleFonts.outfit(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: priorityColor,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      complaint.status,
                      style: GoogleFonts.outfit(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: statusColor,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Title
          Text(
            complaint.title,
            style: GoogleFonts.outfit(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: const Color(0xFF1E293B),
            ),
          ),
          const SizedBox(height: 8),

          // Description
          Text(
            complaint.description,
            style: GoogleFonts.outfit(
              fontSize: 14,
              color: Colors.grey.shade700,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 16),

          // Meta Info Card
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Column(
              children: [
                _buildInfoRow(
                  Icons.location_on_outlined,
                  'Location',
                  complaint.location,
                ),
                const Divider(height: 16),
                _buildInfoRow(
                  Icons.person_outline_rounded,
                  'Student',
                  student != null
                      ? '${student['name']} (${student['registrationNumber'] ?? student['branch'] ?? ''})'
                      : complaint.studentName,
                ),
                const Divider(height: 16),
                _buildInfoRow(
                  Icons.assignment_ind_outlined,
                  'Assigned Staff',
                  staff != null
                      ? '${staff.name} (${staff.role})'
                      : (complaint.assignedToName ?? 'Unassigned'),
                ),
                const Divider(height: 16),
                _buildInfoRow(
                  Icons.access_time_rounded,
                  'Age',
                  '${complaint.ageHours.toStringAsFixed(1)} hrs (${DateFormat('MMM d, h:mm a').format(complaint.createdAt)})',
                  trailingBadge: complaint.isAgeing
                      ? Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.red.shade100,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            'AGEING',
                            style: GoogleFonts.outfit(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: Colors.red.shade800,
                            ),
                          ),
                        )
                      : null,
                ),
                if (complaint.resolutionRemarks != null && complaint.resolutionRemarks!.isNotEmpty) ...[
                  const Divider(height: 16),
                  _buildInfoRow(
                    Icons.check_circle_outline,
                    'Resolution Notes',
                    complaint.resolutionRemarks!,
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Context-aware actions
          Text(
            'Operational Actions',
            style: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.bold, color: const Color(0xFF1E293B)),
          ),
          const SizedBox(height: 10),
          _buildContextAwareActions(complaint.status),
          const SizedBox(height: 24),

          // Status History Timeline
          Text(
            'Lifecycle Timeline',
            style: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.bold, color: const Color(0xFF1E293B)),
          ),
          const SizedBox(height: 12),
          if (_detail!.statusHistory.isEmpty)
            Text('No history records recorded yet.', style: GoogleFonts.outfit(fontSize: 13, color: Colors.grey))
          else
            ...List.generate(_detail!.statusHistory.length, (index) {
              final h = _detail!.statusHistory[index];
              final isLast = index == _detail!.statusHistory.length - 1;
              final dateStr = DateFormat('MMM d, h:mm a').format(h.timestamp);
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Column(
                    children: [
                      Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          color: _getStatusColor(h.newStatus),
                          shape: BoxShape.circle,
                        ),
                      ),
                      if (!isLast)
                        Container(
                          width: 2,
                          height: 36,
                          color: Colors.grey.shade300,
                        ),
                    ],
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                h.newStatus,
                                style: GoogleFonts.outfit(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                  color: _getStatusColor(h.newStatus),
                                ),
                              ),
                              Text(
                                dateStr,
                                style: GoogleFonts.outfit(fontSize: 11, color: Colors.grey.shade500),
                              ),
                            ],
                          ),
                          if (h.remarks != null && h.remarks!.isNotEmpty)
                            Text(
                              h.remarks!,
                              style: GoogleFonts.outfit(fontSize: 12, color: Colors.grey.shade700),
                            ),
                          if (h.actorName != null)
                            Text(
                              'By: ${h.actorName} (${h.actorRole ?? 'Staff'})',
                              style: GoogleFonts.outfit(fontSize: 11, color: Colors.grey.shade500),
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
              );
            }),
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value, {Widget? trailingBadge}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: Colors.grey.shade600),
        const SizedBox(width: 10),
        Text(
          '$label: ',
          style: GoogleFonts.outfit(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Colors.grey.shade700,
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: GoogleFonts.outfit(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: const Color(0xFF1E293B),
            ),
          ),
        ),
        if (trailingBadge != null) trailingBadge,
      ],
    );
  }
}
