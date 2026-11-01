import 'package:flutter/material.dart';
import 'package:attendance_app/core/haptics/app_haptics.dart';

import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_colors.dart';
import '../../../auth/models/user_model.dart';
import '../../../student/models/notice_model.dart';
import '../../../student/services/notice_service.dart';
import '../../../router/app_routes.dart';

class NoticeManagementDetailScreen extends StatefulWidget {
  final UserModel user;
  final NoticeModel notice;

  const NoticeManagementDetailScreen({
    Key? key,
    required this.user,
    required this.notice,
  }) : super(key: key);

  @override
  State<NoticeManagementDetailScreen> createState() =>
      _NoticeManagementDetailScreenState();
}

class _NoticeManagementDetailScreenState
    extends State<NoticeManagementDetailScreen> {
  final NoticeService _noticeService = NoticeService();
  late NoticeModel _notice;
  bool _isLoading = false;
  Map<String, dynamic>? _deliveryMetrics;

  @override
  void initState() {
    super.initState();
    _notice = widget.notice;
    _refreshNotice();
  }

  Future<void> _refreshNotice() async {
    setState(() => _isLoading = true);
    try {
      final updated = await _noticeService.getNotice(_notice.id,
          requesterId: widget.user.id);
      Map<String, dynamic>? metricsData;
      try {
        metricsData = await _noticeService.getDeliveryMetrics(_notice.id,
            requesterId: widget.user.id);
      } catch (e) {
        debugPrint("Notice delivery metrics error: $e");
      }
      if (mounted) {
        setState(() {
          _notice = updated;
          if (metricsData != null && metricsData['metrics'] != null) {
            _deliveryMetrics = metricsData['metrics'] as Map<String, dynamic>;
          }
        });
      }
    } catch (e) {
      debugPrint("Error refreshing notice: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _archiveNotice() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Archive Notice?',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
          ),
        ),
        content: Text(
          'This will remove the notice from active student feeds. Historical delivery metrics and audit logs will be permanently preserved.',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 13,
            color: AppColors.textSecondary,
            height: 1.4,
          ),
        ),
        actionsPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              'Cancel',
              style: GoogleFonts.plusJakartaSans(
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.danger,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: Text(
              'Archive',
              style: GoogleFonts.plusJakartaSans(
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isLoading = true);
    try {
      final updated = await _noticeService.archiveNotice(_notice.id,
          requesterId: widget.user.id);
      if (mounted) {
        setState(() {
          _notice = updated;
        });
        AppHaptics.mediumImpact();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Notice archived successfully.'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString()),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _publishNotice() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Publish Notice Now?',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
          ),
        ),
        content: Text(
          'This will broadcast the notice to all targeted students and deliver push notifications immediately.',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 13,
            color: AppColors.textSecondary,
            height: 1.4,
          ),
        ),
        actionsPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              'Cancel',
              style: GoogleFonts.plusJakartaSans(
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: Text(
              'Publish',
              style: GoogleFonts.plusJakartaSans(
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isLoading = true);
    try {
      final updated = await _noticeService.updateNotice(
        _notice.id,
        {'status': 'PUBLISHED'},
        requesterId: widget.user.id,
      );
      if (mounted) {
        setState(() {
          _notice = updated;
        });
        AppHaptics.mediumImpact();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Notice published successfully!'),
            backgroundColor: AppColors.success,
          ),
        );
        _refreshNotice();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString()),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final statusColor = _getStatusColor(_notice.status);

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        title: Text(
          'Notice Details',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
        actions: [
          if (!_notice.isArchived)
            IconButton(
              icon: const Icon(Icons.edit_outlined,
                  color: AppColors.primary, size: 20),
              tooltip: 'Edit Notice',
              onPressed: () async {
                AppHaptics.lightImpact();
                final result = await Navigator.pushNamed(
                  context,
                  AppRoutes.noticeComposer,
                  arguments: {'user': widget.user, 'notice': _notice},
                );
                if (result == true) {
                  _refreshNotice();
                }
              },
            ),
        ],
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(0.5),
          child: Divider(height: 0.5, color: AppColors.border),
        ),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primary))
          : RefreshIndicator(
              color: AppColors.primary,
              onRefresh: _refreshNotice,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(
                    parent: BouncingScrollPhysics()),
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildHeaderCard(statusColor),
                    const SizedBox(height: 16),
                    _buildContentCard(),
                    const SizedBox(height: 16),
                    _buildMetricsCard(),
                    const SizedBox(height: 24),
                    if (!_notice.isArchived) _buildActionDock(),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildHeaderCard(Color statusColor) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Row 1: Status Pill + Published timestamp
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _notice.isPublished
                          ? Icons.check_circle_rounded
                          : _notice.isDraft
                              ? Icons.edit_note_rounded
                              : Icons.archive_outlined,
                      size: 13,
                      color: statusColor,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      _notice.status,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: statusColor,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                DateFormat('MMM dd, yyyy · hh:mm a').format(_notice.createdAt),
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Title
          Text(
            _notice.title,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
              letterSpacing: -0.4,
            ),
          ),
          const SizedBox(height: 14),

          // Metadata Chips: Category, Priority, Audience
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildPill(Icons.category_rounded, _notice.category,
                  AppColors.primary),
              if (_notice.isUrgent || _notice.isHigh)
                _buildPill(
                    Icons.priority_high_rounded,
                    _notice.priority,
                    _notice.isUrgent ? AppColors.danger : AppColors.warning),
              _buildPill(
                  Icons.groups_rounded, _formatAudience(_notice), Colors.indigo),
            ],
          ),

          // Expiration banner if set
          if (_notice.expiresAt != null) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: _notice.isExpired
                    ? AppColors.danger.withValues(alpha: 0.08)
                    : AppColors.bg,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: _notice.isExpired
                      ? AppColors.danger.withValues(alpha: 0.3)
                      : AppColors.border,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.schedule_rounded,
                    size: 14,
                    color: _notice.isExpired
                        ? AppColors.danger
                        : AppColors.textSecondary,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _notice.isExpired
                        ? 'Expired on ${DateFormat('MMM dd, yyyy · hh:mm a').format(_notice.expiresAt!)}'
                        : 'Expires on ${DateFormat('MMM dd, yyyy · hh:mm a').format(_notice.expiresAt!)}',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: _notice.isExpired
                          ? AppColors.danger
                          : AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildContentCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "MESSAGE",
            style: GoogleFonts.plusJakartaSans(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: AppColors.textSecondary,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 10),
          SelectableText(
            _notice.body,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 14,
              color: AppColors.textPrimary,
              height: 1.6,
            ),
          ),
          if (_notice.hasAction) ...[
            const SizedBox(height: 16),
            const Divider(color: AppColors.border, height: 1),
            const SizedBox(height: 14),
            Row(
              children: [
                const Icon(Icons.link_rounded,
                    size: 16, color: AppColors.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    "Action: ${_notice.actionType} (${_notice.actionPayload ?? ''})",
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMetricsCard() {
    final int recipients = _deliveryMetrics?['recipients'] as int? ??
        (_notice.totalDeliveries > 0
            ? _notice.totalDeliveries
            : _notice.recipientCount);
    final int pushAttempts =
        _deliveryMetrics?['pushAttempts'] as int? ?? 0;
    final int delivered = _deliveryMetrics?['delivered'] as int? ?? 0;
    final int failed = _deliveryMetrics?['failed'] as int? ?? 0;
    final int readCount =
        _deliveryMetrics?['read'] as int? ?? _notice.readDeliveries;
    final int unreadCount =
        _deliveryMetrics?['unread'] as int? ?? (recipients - readCount).clamp(0, recipients);

    final double readRate = recipients > 0 ? (readCount / recipients) : 0.0;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "DELIVERY & ENGAGEMENT",
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textSecondary,
                  letterSpacing: 0.8,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.refresh_rounded, size: 18),
                tooltip: 'Refresh Metrics',
                color: AppColors.primary,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                onPressed: _isLoading ? null : _refreshNotice,
              ),
            ],
          ),
          const SizedBox(height: 16),

          if (_notice.isDraft) ...[
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.bg,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline_rounded,
                      size: 20, color: AppColors.textSecondary),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      "This notice is saved as a draft. Publish to deliver push notifications and generate student read tracking.",
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ] else ...[
            // Apple Health-style metric grid
            Row(
              children: [
                Expanded(
                  child: _buildMetricTile(
                    label: "Recipients",
                    value: recipients,
                    icon: Icons.groups_rounded,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _buildMetricTile(
                    label: "Delivered",
                    value: delivered > 0 ? delivered : recipients,
                    icon: Icons.done_all_rounded,
                    color: const Color(0xFF0D9488), // Teal
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _buildMetricTile(
                    label: "Read",
                    value: readCount,
                    icon: Icons.mark_email_read_rounded,
                    color: AppColors.success,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _buildMetricTile(
                    label: "Unread",
                    value: unreadCount,
                    icon: Icons.mark_email_unread_rounded,
                    color: AppColors.warning,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Read Rate Progress Bar
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      "Read Rate",
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    Text(
                      "${(readRate * 100).toStringAsFixed(0)}%",
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: AppColors.success,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: readRate.clamp(0.0, 1.0),
                    minHeight: 6,
                    backgroundColor: AppColors.bg,
                    valueColor:
                        const AlwaysStoppedAnimation<Color>(AppColors.success),
                  ),
                ),
              ],
            ),

            if (pushAttempts > 0 || failed > 0) ...[
              const SizedBox(height: 14),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    "FCM Push Dispatched: $pushAttempts",
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 11,
                      color: AppColors.textTertiary,
                    ),
                  ),
                  if (failed > 0)
                    Text(
                      "Push Failures: $failed",
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11,
                        color: AppColors.danger,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                ],
              ),
            ],
          ],
        ],
      ),
    );
  }

  Widget _buildMetricTile({
    required String label,
    required int value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.bg,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                label,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                ),
              ),
              Icon(icon, size: 16, color: color),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value.toString(),
            style: GoogleFonts.plusJakartaSans(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: color,
              letterSpacing: -0.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionDock() {
    return Row(
      children: [
        if (_notice.isDraft) ...[
          Expanded(
            child: ElevatedButton.icon(
              onPressed: _publishNotice,
              icon: const Icon(Icons.send_rounded, size: 16),
              label: Text(
                'Publish Now',
                style: GoogleFonts.plusJakartaSans(
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
        ],
        Expanded(
          child: OutlinedButton.icon(
            onPressed: _archiveNotice,
            icon: const Icon(Icons.archive_outlined,
                size: 16, color: AppColors.danger),
            label: Text(
              'Archive Notice',
              style: GoogleFonts.plusJakartaSans(
                fontWeight: FontWeight.w700,
                fontSize: 14,
                color: AppColors.danger,
              ),
            ),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
              side: const BorderSide(color: AppColors.danger, width: 1.2),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPill(IconData icon, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  String _formatAudience(NoticeModel notice) {
    if (notice.targetType == 'ALL') {
      return "All Students";
    } else if (notice.targetType == 'BRANCH') {
      return "${notice.targetValue ?? 'Department'} Dept";
    } else if (notice.targetType == 'YEAR') {
      return "${notice.targetValue ?? ''} Year Cohort";
    } else if (notice.targetType == 'STUDENT') {
      return "Student: ${notice.targetValue ?? 'Targeted'}";
    }
    return notice.targetType;
  }

  Color _getStatusColor(String status) {
    switch (status.toUpperCase()) {
      case 'PUBLISHED':
        return AppColors.success;
      case 'DRAFT':
        return AppColors.warning;
      case 'ARCHIVED':
        return AppColors.textSecondary;
      case 'EXPIRED':
        return AppColors.danger;
      default:
        return AppColors.primary;
    }
  }
}
