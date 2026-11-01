import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../auth/models/user_model.dart';
import '../models/admin_dashboard_models.dart';
import '../services/admin_dashboard_service.dart';
import 'admin_complaint_detail_sheet.dart';

class RecurringIssueDetailSheet extends StatefulWidget {
  final String recurrenceId;
  final UserModel? currentUser;
  final VoidCallback onRefresh;

  const RecurringIssueDetailSheet({
    Key? key,
    required this.recurrenceId,
    required this.currentUser,
    required this.onRefresh,
  }) : super(key: key);

  @override
  State<RecurringIssueDetailSheet> createState() => _RecurringIssueDetailSheetState();
}

class _RecurringIssueDetailSheetState extends State<RecurringIssueDetailSheet> {
  final AdminDashboardService _service = AdminDashboardService();
  bool _isLoading = true;
  String? _errorMessage;
  RecurringIssueDetailModel? _detail;

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
      final detail = await _service.getRecurringIssueDetail(
        widget.recurrenceId,
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

  Color _getEscalationColor(String level) {
    switch (level.toUpperCase()) {
      case 'HIGH':
        return const Color(0xFFDC2626);
      case 'ELEVATED':
        return const Color(0xFFF97316);
      case 'NORMAL':
      default:
        return const Color(0xFF3B82F6);
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

  void _openComplaintDetail(String complaintId) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => AdminComplaintDetailSheet(
        complaintId: complaintId,
        currentUser: widget.currentUser,
        onActionCompleted: () {
          _loadDetail();
          widget.onRefresh();
        },
      ),
    );
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
    final rec = _detail!.recurrence;
    final complaints = _detail!.complaints;
    final escalationColor = _getEscalationColor(rec.escalationLevel);

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

          // Header badges: Category, Location, Escalation, Status
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      rec.category,
                      style: GoogleFonts.outfit(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey.shade800,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: escalationColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.warning_amber_rounded, size: 14, color: escalationColor),
                        const SizedBox(width: 4),
                        Text(
                          '${rec.escalationLevel} ESCALATION',
                          style: GoogleFonts.outfit(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: escalationColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: rec.isActive ? const Color(0xFFFEF2F2) : Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  rec.recurrenceStatus,
                  style: GoogleFonts.outfit(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: rec.isActive ? const Color(0xFFDC2626) : Colors.grey.shade700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Title
          Text(
            rec.location,
            style: GoogleFonts.outfit(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: const Color(0xFF1E293B),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Systemic pattern detected: ${rec.complaintCount} related complaints in ${rec.windowDays}-day window',
            style: GoogleFonts.outfit(fontSize: 13, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 16),

          // Summary Metrics Cards Grid
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _buildMetricItem(
                        'Total Complaints',
                        '${rec.complaintCount}',
                        Icons.layers_outlined,
                      ),
                    ),
                    Expanded(
                      child: _buildMetricItem(
                        'Active Tickets',
                        '${rec.activeComplaintCount}',
                        Icons.pending_actions_rounded,
                        color: rec.activeComplaintCount > 0 ? const Color(0xFFDC2626) : null,
                      ),
                    ),
                  ],
                ),
                const Divider(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: _buildMetricItem(
                        'Resolved Tickets',
                        '${rec.resolvedComplaintCount}',
                        Icons.check_circle_outline_rounded,
                        color: const Color(0xFF10B981),
                      ),
                    ),
                    Expanded(
                      child: _buildMetricItem(
                        'Avg Resolution',
                        rec.averageResolutionHours > 0
                            ? '${rec.averageResolutionHours.toStringAsFixed(1)}h'
                            : 'N/A',
                        Icons.timer_outlined,
                      ),
                    ),
                  ],
                ),
                const Divider(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: _buildMetricItem(
                        'First Reported',
                        DateFormat('MMM d, h:mm a').format(rec.firstComplaintAt),
                        Icons.calendar_today_outlined,
                      ),
                    ),
                    Expanded(
                      child: _buildMetricItem(
                        'Latest Reported',
                        DateFormat('MMM d, h:mm a').format(rec.latestComplaintAt),
                        Icons.update_rounded,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Related Complaints Section
          Text(
            'Related Complaints in Cluster (${complaints.length})',
            style: GoogleFonts.outfit(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: const Color(0xFF1E293B),
            ),
          ),
          const SizedBox(height: 10),
          ...complaints.map((c) {
            final stColor = _getStatusColor(c.status);
            return InkWell(
              onTap: () => _openComplaintDetail(c.id),
              borderRadius: BorderRadius.circular(12),
              child: Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade200),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.02),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          DateFormat('MMM d, yyyy • h:mm a').format(c.createdAt),
                          style: GoogleFonts.outfit(fontSize: 11, color: Colors.grey.shade500),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: stColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            c.status,
                            style: GoogleFonts.outfit(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: stColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      c.title,
                      style: GoogleFonts.outfit(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF1E293B),
                      ),
                    ),
                    if (c.description.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        c.description,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.outfit(fontSize: 12, color: Colors.grey.shade600),
                      ),
                    ],
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Student: ${c.studentName}',
                          style: GoogleFonts.outfit(fontSize: 11, color: Colors.grey.shade700),
                        ),
                        Row(
                          children: [
                            Text(
                              'Staff: ${c.assignedToName ?? "Unassigned"}',
                              style: GoogleFonts.outfit(
                                fontSize: 11,
                                color: c.assignedToName != null ? const Color(0xFF1E3A8A) : Colors.grey.shade500,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(width: 4),
                            const Icon(Icons.chevron_right_rounded, size: 16, color: Colors.grey),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildMetricItem(String label, String value, IconData icon, {Color? color}) {
    return Row(
      children: [
        Icon(icon, size: 18, color: color ?? Colors.grey.shade600),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: GoogleFonts.outfit(fontSize: 11, color: Colors.grey.shade500, fontWeight: FontWeight.w500),
            ),
            Text(
              value,
              style: GoogleFonts.outfit(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: color ?? const Color(0xFF1E293B),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
