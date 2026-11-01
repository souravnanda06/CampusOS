import 'package:flutter/material.dart';
import 'package:attendance_app/core/haptics/app_haptics.dart';

import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../auth/models/user_model.dart';
import '../../core/theme/app_colors.dart';
import '../../router/app_routes.dart';
import '../models/admin_dashboard_models.dart';
import '../services/admin_dashboard_service.dart';
import '../widgets/admin_complaint_detail_sheet.dart';
import '../widgets/recurring_issue_detail_sheet.dart';
import '../screens/admin_complaints_screen.dart';

/// CampusOS Admin Home — Command Center.
///
/// Philosophy: "SEE WHAT NEEDS ATTENTION. ACT WITHOUT DIGGING."
///
/// Sections:
/// 1. Top Calm Header (Greeting, Live Date, Campus Status)
/// 2. Command Center Status Cards (Needs Attention, Ageing, Recurring, High Priority)
/// 3. Needs Attention / Critical Issues (Actionable cards with direct sheet action)
/// 4. Quick Actions (Restrained Apple-style utility grid)
/// 5. Recent Activity (Truthful real operational timeline)
class AdminHomeContent extends StatefulWidget {
  final UserModel? user;
  final ValueChanged<int> onNavigateToTab;

  const AdminHomeContent({
    Key? key,
    required this.user,
    required this.onNavigateToTab,
  }) : super(key: key);

  @override
  State<AdminHomeContent> createState() => _AdminHomeContentState();
}

class _AdminHomeContentState extends State<AdminHomeContent> {
  final AdminDashboardService _service = AdminDashboardService();

  bool _isLoading = true;
  String? _errorMessage;

  AdminDashboardSummaryModel? _summary;
  List<AdminAgeingComplaintModel> _ageingComplaints = [];
  List<RecurringIssueModel> _recurringIssues = [];
  List<AdminComplaintItemModel> _recentComplaints = [];

  @override
  void initState() {
    super.initState();
    _fetchHomeData();
  }

  Future<void> _fetchHomeData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final reqId = widget.user?.id;
      final summaryFuture = _service.getDashboardSummary(requesterId: reqId).catchError(
            (_) => AdminDashboardSummaryModel(
              totalComplaints: 0,
              pendingComplaints: 0,
              assignedComplaints: 0,
              inProgressComplaints: 0,
              resolvedComplaints: 0,
              closedComplaints: 0,
              reopenedComplaints: 0,
              rejectedComplaints: 0,
              ageingComplaints: 0,
              averageResolutionHours: 0.0,
            ),
          );
      final ageingFuture = _service
          .getAgeingComplaints(requesterId: reqId)
          .catchError((_) => <AdminAgeingComplaintModel>[]);
      final recurringFuture = _service
          .getRecurringIssues(requesterId: reqId)
          .catchError((_) => <RecurringIssueModel>[]);
      final recentComplaintsFuture = _service
          .getComplaints(order: 'newest', requesterId: reqId)
          .catchError((_) => <AdminComplaintItemModel>[]);

      final results = await Future.wait([
        summaryFuture,
        ageingFuture,
        recurringFuture,
        recentComplaintsFuture,
      ]);

      if (mounted) {
        setState(() {
          _summary = results[0] as AdminDashboardSummaryModel;
          _ageingComplaints = results[1] as List<AdminAgeingComplaintModel>;
          _recurringIssues = results[2] as List<RecurringIssueModel>;
          _recentComplaints = results[3] as List<AdminComplaintItemModel>;
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

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return "Good morning";
    if (hour < 17) return "Good afternoon";
    return "Good evening";
  }

  void _openComplaintDetail(String complaintId) {
    AppHaptics.selectionClick();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => AdminComplaintDetailSheet(
        complaintId: complaintId,
        currentUser: widget.user,
        onActionCompleted: () => _fetchHomeData(),
      ),
    );
  }

  void _openRecurringDetail(String recurrenceId) {
    AppHaptics.selectionClick();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => RecurringIssueDetailSheet(
        recurrenceId: recurrenceId,
        currentUser: widget.user,
        onRefresh: () => _fetchHomeData(),
      ),
    );
  }

  void _openComplaintsQueue({String? status, bool ageing = false}) {
    AppHaptics.selectionClick();
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => AdminComplaintsScreen(
          user: widget.user,
          initialStatusFilter: status,
          initialAgeingFilter: ageing,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          onRefresh: _fetchHomeData,
          color: AppColors.primary,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(
              parent: BouncingScrollPhysics(),
            ),
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 120),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(),
                const SizedBox(height: 20),

                if (_isLoading)
                  _buildLoadingSkeleton()
                else if (_errorMessage != null)
                  _buildErrorState()
                else ...[
                  // CampusOS Mesh (M1-M7) Dean Command & Emergency Dispatcher
                  _buildCampusMeshDeanSection(),
                  const SizedBox(height: 24),
                  _buildCommandCenterMetrics(),
                  const SizedBox(height: 24),
                  _buildAttentionSection(),
                  const SizedBox(height: 24),
                  _buildQuickActions(),
                  const SizedBox(height: 24),
                  _buildRecentActivity(),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  // --- 1. Top Calm Header ---
  Widget _buildHeader() {
    final now = DateTime.now();
    final dateStr = DateFormat('d MMMM').format(now);
    final adminName = widget.user?.name.isNotEmpty == true
        ? (widget.user!.name.startsWith('Dr.') || widget.user!.name.startsWith('Prof.')
            ? widget.user!.name.split(' ').take(2).join(' ')
            : widget.user!.name.split(' ').first)
        : 'Admin';

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${_getGreeting()}, $adminName',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                  letterSpacing: -0.5,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              Text(
                'Campus Overview · $dateStr',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textSecondary,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        // Mesh Hub Antenna shortcut
        InkWell(
          onTap: () {
            AppHaptics.lightImpact();
            Navigator.pushNamed(context, AppRoutes.meshHub);
          },
          borderRadius: BorderRadius.circular(20),
          child: Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0xFF6366F1).withValues(alpha: 0.3)),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF6366F1).withValues(alpha: 0.1),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: const Icon(
              Icons.settings_input_antenna_rounded,
              color: Color(0xFF6366F1),
              size: 18,
            ),
          ),
        ),
        const SizedBox(width: 8),
        // Live Campus status pill
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.border, width: 0.8),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 7,
                height: 7,
                decoration: const BoxDecoration(
                  color: AppColors.success,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                'CAMPUS ONLINE',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                  letterSpacing: 0.4,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // --- 2. Command Center Metrics (4 Cards) ---
  Widget _buildCommandCenterMetrics() {
    final needsAttention = (_summary?.pendingComplaints ?? 0) +
        (_summary?.reopenedComplaints ?? 0);
    final ageing = _summary?.ageingComplaints ?? 0;
    final recurringCount =
        _recurringIssues.where((r) => r.isActive).length;
    final highPriority = _recentComplaints
        .where((c) =>
            (c.priority == 'URGENT' || c.priority == 'HIGH') &&
            c.status != 'RESOLVED' &&
            c.status != 'CLOSED')
        .length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'CAMPUS OPERATIONS',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            color: AppColors.textSecondary,
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _buildMetricCard(
                title: 'Needs Attention',
                value: needsAttention.toString(),
                accentColor: needsAttention > 0
                    ? const Color(0xFFF59E0B)
                    : AppColors.success,
                icon: Icons.assignment_late_outlined,
                onTap: () => _openComplaintsQueue(status: 'PENDING'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildMetricCard(
                title: 'Ageing >48h',
                value: ageing.toString(),
                accentColor: ageing > 0 ? AppColors.danger : AppColors.success,
                icon: Icons.hourglass_bottom_rounded,
                onTap: () => _openComplaintsQueue(ageing: true),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _buildMetricCard(
                title: 'Recurring Issues',
                value: recurringCount.toString(),
                accentColor: recurringCount > 0
                    ? const Color(0xFF8B5CF6)
                    : AppColors.textSecondary,
                icon: Icons.repeat_rounded,
                onTap: () => widget.onNavigateToTab(2), // Jump to Analytics tab
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildMetricCard(
                title: 'High Priority',
                value: highPriority.toString(),
                accentColor: highPriority > 0
                    ? AppColors.danger
                    : AppColors.success,
                icon: Icons.priority_high_rounded,
                onTap: () => _openComplaintsQueue(),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildMetricCard({
    required String title,
    required String value,
    required Color accentColor,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border, width: 0.8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      value,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                        color: accentColor,
                        letterSpacing: -0.5,
                      ),
                    ),
                    Icon(icon, size: 18, color: accentColor.withValues(alpha: 0.7)),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  title,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // --- 3. Needs Attention Section ---
  Widget _buildAttentionSection() {
    // Collect critical actionable items
    final List<Widget> attentionItems = [];

    // Add ageing complaints (up to 2)
    for (final ageing in _ageingComplaints.take(2)) {
      final days = (ageing.ageHours / 24).floor();
      attentionItems.add(
        _buildAttentionCard(
          badgeText: 'Ageing ${days > 0 ? '${days}d' : '${ageing.ageHours.round()}h'}',
          badgeColor: AppColors.danger,
          title: ageing.title,
          subtitle: '${ageing.category} · Assigned to ${ageing.assignedToName ?? "Unassigned"}',
          actionLabel: 'View',
          onAction: () => _openComplaintDetail(ageing.id),
        ),
      );
    }

    // Add active recurring patterns (up to 2)
    final activeRecurring = _recurringIssues.where((r) => r.isActive).take(2);
    for (final rec in activeRecurring) {
      attentionItems.add(
        _buildAttentionCard(
          badgeText: 'Recurring (${rec.complaintCount} reports)',
          badgeColor: const Color(0xFF8B5CF6),
          title: '${rec.category} in ${rec.location}',
          subtitle: '${rec.complaintCount} incidents in ${rec.windowDays}d window · ${rec.escalationLevel} severity',
          actionLabel: 'Pattern',
          onAction: () => _openRecurringDetail(rec.recurrenceId),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'NEEDS ATTENTION',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: AppColors.textSecondary,
                letterSpacing: 0.8,
              ),
            ),
            if (attentionItems.isNotEmpty)
              GestureDetector(
                onTap: () => _openComplaintsQueue(ageing: true),
                child: Text(
                  'View All',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 10),

        if (attentionItems.isEmpty)
          _buildPositiveEmptyState()
        else
          Column(
            children: attentionItems
                .map((item) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: item,
                    ))
                .toList(),
          ),
      ],
    );
  }

  Widget _buildAttentionCard({
    required String badgeText,
    required Color badgeColor,
    required String title,
    required String subtitle,
    required String actionLabel,
    required VoidCallback onAction,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border, width: 0.8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: badgeColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    badgeText,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: badgeColor,
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  title,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          ElevatedButton(
            onPressed: onAction,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.bg,
              foregroundColor: AppColors.textPrimary,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
                side: const BorderSide(color: AppColors.border),
              ),
            ),
            child: Text(
              actionLabel,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPositiveEmptyState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border, width: 0.8),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.success.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.check_rounded,
                color: AppColors.success, size: 24),
          ),
          const SizedBox(height: 12),
          Text(
            'Everything looks good',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'No unresolved high-priority issues right now.',
            textAlign: TextAlign.center,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 12,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  // --- 4. Quick Actions ---
  Widget _buildQuickActions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'QUICK ACTIONS',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            color: AppColors.textSecondary,
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border, width: 0.8),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.02),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              Expanded(
                child: _buildQuickActionButton(
                  icon: Icons.assignment_outlined,
                  label: 'Complaints',
                  onTap: () => _openComplaintsQueue(),
                ),
              ),
              Expanded(
                child: _buildQuickActionButton(
                  icon: Icons.campaign_outlined,
                  label: 'Notices',
                  onTap: () {
                    AppHaptics.selectionClick();
                    Navigator.pushNamed(
                      context,
                      AppRoutes.noticeManagement,
                      arguments: widget.user,
                    );
                  },
                ),
              ),
              Expanded(
                child: _buildQuickActionButton(
                  icon: Icons.restaurant_outlined,
                  label: 'Mess',
                  onTap: () {
                    AppHaptics.selectionClick();
                    Navigator.pushNamed(
                      context,
                      AppRoutes.messManagement,
                      arguments: widget.user,
                    );
                  },
                ),
              ),
              Expanded(
                child: _buildQuickActionButton(
                  icon: Icons.how_to_reg_outlined,
                  label: 'Attendance',
                  onTap: () {
                    AppHaptics.selectionClick();
                    widget.onNavigateToTab(1); // Operations tab
                  },
                ),
              ),
              Expanded(
                child: _buildQuickActionButton(
                  icon: Icons.verified_user_outlined,
                  label: 'Passport',
                  onTap: () {
                    AppHaptics.selectionClick();
                    Navigator.pushNamed(
                      context,
                      AppRoutes.passportVerify,
                      arguments: widget.user,
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildQuickActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return Semantics(
      button: true,
      label: label,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.bg,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.border, width: 0.5),
                ),
                child: Icon(icon, size: 20, color: AppColors.primary),
              ),
              const SizedBox(height: 6),
              Text(
                label,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // --- 5. Recent Real Activity ---
  Widget _buildRecentActivity() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'RECENT ACTIVITY',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: AppColors.textSecondary,
                letterSpacing: 0.8,
              ),
            ),
            GestureDetector(
              onTap: () => _openComplaintsQueue(),
              child: Text(
                'View All',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primary,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),

        if (_recentComplaints.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border, width: 0.8),
            ),
            child: Center(
              child: Text(
                'No recent activity recorded.',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
          )
        else
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border, width: 0.8),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.02),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: const EdgeInsets.all(8),
              itemCount: _recentComplaints.take(4).length,
              separatorBuilder: (_, __) =>
                  const Divider(height: 1, indent: 46, color: AppColors.border),
              itemBuilder: (context, idx) {
                final c = _recentComplaints[idx];
                final statusCol = c.status == 'RESOLVED' || c.status == 'CLOSED'
                    ? AppColors.success
                    : (c.status == 'IN_PROGRESS'
                        ? const Color(0xFF8B5CF6)
                        : const Color(0xFFF59E0B));

                return ListTile(
                  dense: true,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                  leading: Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: statusCol.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      c.status == 'RESOLVED' || c.status == 'CLOSED'
                          ? Icons.check_circle_outline_rounded
                          : Icons.build_circle_outlined,
                      size: 18,
                      color: statusCol,
                    ),
                  ),
                  title: Text(
                    c.title,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text(
                    "${c.category} · ${c.location}",
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 11,
                      color: AppColors.textSecondary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: Text(
                    c.status.replaceAll('_', ' '),
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: statusCol,
                    ),
                  ),
                  onTap: () => _openComplaintDetail(c.id),
                );
              },
            ),
          ),
      ],
    );
  }

  // --- Skeletons & Errors ---
  Widget _buildLoadingSkeleton() {
    return Column(
      children: [
        Container(
          height: 120,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border),
          ),
          child: const Center(
            child: CircularProgressIndicator(
              color: AppColors.primary,
              strokeWidth: 2.5,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildErrorState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.danger.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          const Icon(Icons.error_outline_rounded,
              size: 32, color: AppColors.danger),
          const SizedBox(height: 8),
          Text(
            "Couldn't load command center.",
            style: GoogleFonts.plusJakartaSans(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _errorMessage ?? "An unexpected error occurred.",
            textAlign: TextAlign.center,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 12,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 12),
          ElevatedButton(
            onPressed: _fetchHomeData,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Try Again'),
          ),
        ],
      ),
    );
  }

  Widget _buildCampusMeshDeanSection() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFF6366F1).withValues(alpha: 0.25),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF6366F1).withValues(alpha: 0.08),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFDC2626).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.broadcast_on_personal_rounded,
                      color: Color(0xFFDC2626),
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            "CampusOS Mesh",
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF0F172A),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                            decoration: BoxDecoration(
                              color: const Color(0xFFDC2626).withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              "DEAN AUTHORITY",
                              style: GoogleFonts.jetBrainsMono(
                                fontSize: 9,
                                fontWeight: FontWeight.w800,
                                color: const Color(0xFFDC2626),
                              ),
                            ),
                          ),
                        ],
                      ),
                      Text(
                        "Cryptographic Emergency Flare & Stage Simulator",
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 11,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              InkWell(
                onTap: () {
                  AppHaptics.lightImpact();
                  Navigator.pushNamed(context, AppRoutes.meshHub);
                },
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: const Color(0xFF6366F1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        "Mesh Hub",
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(width: 2),
                      const Icon(Icons.chevron_right_rounded, color: Colors.white, size: 14),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildMeshAdminActionItem(
                  title: "Dean Flare",
                  subtitle: "Dispatcher (M6)",
                  icon: Icons.emergency_share_rounded,
                  color: const Color(0xFFDC2626),
                  route: AppRoutes.meshDispatcher,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildMeshAdminActionItem(
                  title: "Stage Demo",
                  subtitle: "Simulator (M7)",
                  icon: Icons.schema_rounded,
                  color: const Color(0xFF8B5CF6),
                  route: AppRoutes.meshSimulator,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildMeshAdminActionItem(
                  title: "Validation",
                  subtitle: "Harness (M7)",
                  icon: Icons.network_check_rounded,
                  color: const Color(0xFF10B981),
                  route: AppRoutes.meshPhysicalTest,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildMeshAdminActionItem(
                  title: "Mesh Chat",
                  subtitle: "P2P (M3)",
                  icon: Icons.chat_bubble_outline_rounded,
                  color: const Color(0xFF0EA5E9),
                  route: AppRoutes.meshChat,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMeshAdminActionItem({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required String route,
  }) {
    return InkWell(
      onTap: () {
        AppHaptics.lightImpact();
        Navigator.pushNamed(context, route);
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(height: 6),
            Text(
              title,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF0F172A),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              subtitle,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 9,
                color: Colors.grey[600],
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
