import 'dart:math';
import 'package:attendance_app/core/haptics/app_haptics.dart';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../auth/models/user_model.dart';
import '../../core/theme/app_colors.dart';
import '../models/admin_dashboard_models.dart';
import '../services/admin_dashboard_service.dart';
import '../widgets/recurring_issue_detail_sheet.dart';

/// CampusOS Admin Analytics Screen.
///
/// Restrained, Apple Health-grade operational intelligence:
/// 1. Lifecycle & Resolution Overview (Total, Pending, Resolved, Avg Resolution Time)
/// 2. Ageing Brackets (<24h, 1–3 days, 3–7 days, 7+ days)
/// 3. Deterministic Recurring Patterns (Location, occurrences, window, severity)
/// 4. Staff Workload Roster (Assigned vs In-Progress distribution)
/// 5. Category Breakdown (Proportional distribution bars)
class AdminAnalyticsScreen extends StatefulWidget {
  final UserModel? user;

  const AdminAnalyticsScreen({Key? key, this.user}) : super(key: key);

  @override
  State<AdminAnalyticsScreen> createState() => _AdminAnalyticsScreenState();
}

class _AdminAnalyticsScreenState extends State<AdminAnalyticsScreen> {
  final AdminDashboardService _service = AdminDashboardService();

  bool _isLoading = true;
  String? _errorMessage;

  AdminDashboardSummaryModel? _summary;
  List<AdminAgeingComplaintModel> _ageingComplaints = [];
  List<StaffWorkloadModel> _workload = [];
  List<CategoryDistributionModel> _categories = [];
  List<RecurringIssueModel> _recurringIssues = [];

  @override
  void initState() {
    super.initState();
    _fetchAnalytics();
  }

  Future<void> _fetchAnalytics() async {
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
      final workloadFuture = _service
          .getWorkload(requesterId: reqId)
          .catchError((_) => <StaffWorkloadModel>[]);
      final categoriesFuture = _service
          .getCategoriesDistribution(requesterId: reqId)
          .catchError((_) => <CategoryDistributionModel>[]);
      final recurringFuture = _service
          .getRecurringIssues(requesterId: reqId)
          .catchError((_) => <RecurringIssueModel>[]);

      final results = await Future.wait([
        summaryFuture,
        ageingFuture,
        workloadFuture,
        categoriesFuture,
        recurringFuture,
      ]);

      if (mounted) {
        setState(() {
          _summary = results[0] as AdminDashboardSummaryModel;
          _ageingComplaints = results[1] as List<AdminAgeingComplaintModel>;
          _workload = results[2] as List<StaffWorkloadModel>;
          _categories = results[3] as List<CategoryDistributionModel>;
          _recurringIssues = results[4] as List<RecurringIssueModel>;
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

  void _openRecurringDetail(String recurrenceId) {
    AppHaptics.selectionClick();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => RecurringIssueDetailSheet(
        recurrenceId: recurrenceId,
        currentUser: widget.user,
        onRefresh: () => _fetchAnalytics(),
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
          onRefresh: _fetchAnalytics,
          color: AppColors.primary,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(
              parent: BouncingScrollPhysics(),
            ),
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 120),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Header
                Text(
                  'Analytics',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                    letterSpacing: -0.5,
                  ),
                ),
                Text(
                  'Institutional resolution rates, ageing & recurring patterns',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 20),

                if (_isLoading)
                  _buildLoadingSkeleton()
                else if (_errorMessage != null)
                  _buildErrorState()
                else ...[
                  // 1. Resolution & Lifecycle Summary
                  _buildResolutionSection(),
                  const SizedBox(height: 24),

                  // 2. Ageing Brackets
                  _buildAgeingSection(),
                  const SizedBox(height: 24),

                  // 3. Recurring Issues Engine
                  _buildRecurringSection(),
                  const SizedBox(height: 24),

                  // 4. Staff Workload
                  _buildWorkloadSection(),
                  const SizedBox(height: 24),

                  // 5. Category Distribution
                  _buildCategoriesSection(),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  // --- 1. Resolution & Lifecycle Overview ---
  Widget _buildResolutionSection() {
    final avgHours = _summary?.averageResolutionHours ?? 0.0;
    final total = _summary?.totalComplaints ?? 0;
    final resolved = _summary?.resolvedComplaints ?? 0;
    final closed = _summary?.closedComplaints ?? 0;
    final totalResolved = resolved + closed;
    final resolutionRate =
        total > 0 ? ((totalResolved / total) * 100).round() : 0;

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
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  'RESOLUTION PERFORMANCE',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textSecondary,
                    letterSpacing: 0.8,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.success.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '$resolutionRate% resolved',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppColors.success,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Big Metric: Average Resolution Hours
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                avgHours > 0 ? avgHours.toStringAsFixed(1) : '—',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 32,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                  letterSpacing: -1,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                'hours',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'average resolution time',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textSecondary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Mini 4-stat grid
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.bg,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Expanded(
                  child: _buildStatPill('Total', '${_summary?.totalComplaints ?? 0}'),
                ),
                _buildStatDivider(),
                Expanded(
                  child: _buildStatPill('Pending', '${_summary?.pendingComplaints ?? 0}'),
                ),
                _buildStatDivider(),
                Expanded(
                  child: _buildStatPill('In Progress', '${_summary?.inProgressComplaints ?? 0}'),
                ),
                _buildStatDivider(),
                Expanded(
                  child: _buildStatPill('Resolved', '$totalResolved'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatPill(String label, String value) {
    return Column(
      children: [
        Text(
          value,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 15,
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        Text(
          label,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: AppColors.textSecondary,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildStatDivider() {
    return Container(
      width: 1,
      height: 24,
      color: AppColors.border,
    );
  }

  // --- 2. Ageing Brackets ---
  Widget _buildAgeingSection() {
    int under24h = 0;
    int day1to3 = 0;
    int day3to7 = 0;
    int over7d = 0;

    for (final c in _ageingComplaints) {
      if (c.ageHours < 24) {
        under24h++;
      } else if (c.ageHours <= 72) {
        day1to3++;
      } else if (c.ageHours <= 168) {
        day3to7++;
      } else {
        over7d++;
      }
    }

    final totalAgeing = _ageingComplaints.length;

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
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  'COMPLAINT AGEING ANALYSIS',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textSecondary,
                    letterSpacing: 0.8,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '$totalAgeing active past 48h SLA',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: totalAgeing > 0
                      ? AppColors.danger
                      : AppColors.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Ageing distribution brackets
          Row(
            children: [
              Expanded(
                child: _buildAgeingBracketCard(
                  label: '< 24h',
                  count: under24h,
                  color: const Color(0xFF3B82F6),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildAgeingBracketCard(
                  label: '1–3 days',
                  count: day1to3,
                  color: const Color(0xFFF59E0B),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildAgeingBracketCard(
                  label: '3–7 days',
                  count: day3to7,
                  color: const Color(0xFFEA580C),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildAgeingBracketCard(
                  label: '7+ days',
                  count: over7d,
                  color: AppColors.danger,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAgeingBracketCard({
    required String label,
    required int count,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: BoxDecoration(
        color: AppColors.bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: count > 0 ? color.withValues(alpha: 0.3) : Colors.transparent,
          width: 1,
        ),
      ),
      child: Column(
        children: [
          Text(
            count.toString(),
            style: GoogleFonts.plusJakartaSans(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: count > 0 ? color : AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  // --- 3. Recurring Issues Engine ---
  Widget _buildRecurringSection() {
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
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  'RECURRING ISSUES (DETERMINISTIC)',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textSecondary,
                    letterSpacing: 0.8,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${_recurringIssues.length} patterns',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          if (_recurringIssues.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Center(
                child: Text(
                  'No recurring incident patterns detected within the 14-day window.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _recurringIssues.length,
              separatorBuilder: (_, __) =>
                  const Divider(height: 16, color: AppColors.border),
              itemBuilder: (context, idx) {
                final rec = _recurringIssues[idx];
                final isHigh = rec.escalationLevel == 'HIGH';

                return Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                rec.category,
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: (isHigh
                                          ? AppColors.danger
                                          : const Color(0xFFF59E0B))
                                      .withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  rec.escalationLevel,
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 9,
                                    fontWeight: FontWeight.w800,
                                    color: isHigh
                                        ? AppColors.danger
                                        : const Color(0xFFF59E0B),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            "${rec.location} · ${rec.complaintCount} reports in ${rec.windowDays}d",
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    ElevatedButton(
                      onPressed: () => _openRecurringDetail(rec.recurrenceId),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.bg,
                        foregroundColor: AppColors.textPrimary,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                          side: const BorderSide(color: AppColors.border),
                        ),
                      ),
                      child: Text(
                        'View Pattern',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
        ],
      ),
    );
  }

  // --- 4. Staff Workload ---
  Widget _buildWorkloadSection() {
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
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  'STAFF WORKLOAD',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textSecondary,
                    letterSpacing: 0.8,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${_workload.length} assignees',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          if (_workload.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Center(
                child: Text(
                  'No staff workload records currently assigned.',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _workload.take(5).length,
              separatorBuilder: (_, __) =>
                  const Divider(height: 14, color: AppColors.border),
              itemBuilder: (context, idx) {
                final w = _workload[idx];
                final isOverloaded = w.totalActive >= 10;

                return Row(
                  children: [
                    CircleAvatar(
                      radius: 14,
                      backgroundColor: AppColors.bg,
                      child: Text(
                        w.staffName.isNotEmpty
                            ? w.staffName[0].toUpperCase()
                            : 'S',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            w.staffName,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          Text(
                            "${w.assignedCount} assigned · ${w.inProgressCount} in progress",
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 11,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: (isOverloaded
                                ? AppColors.danger
                                : const Color(0xFF3B82F6))
                            .withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        '${w.totalActive} active',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: isOverloaded
                              ? AppColors.danger
                              : const Color(0xFF3B82F6),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
        ],
      ),
    );
  }

  // --- 5. Category Distribution ---
  Widget _buildCategoriesSection() {
    final maxCount = _categories.fold<int>(
        1, (prev, element) => max(prev, element.count));

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
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'CATEGORY DISTRIBUTION',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: AppColors.textSecondary,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 14),

          if (_categories.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Center(
                child: Text(
                  'No complaint categories recorded yet.',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            )
          else
            ..._categories.map((cat) {
              final ratio = cat.count / maxCount;
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          cat.category,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        Text(
                          '${cat.count}',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: ratio.clamp(0.05, 1.0),
                        minHeight: 6,
                        backgroundColor: AppColors.bg,
                        valueColor: const AlwaysStoppedAnimation<Color>(
                            AppColors.primary),
                      ),
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }

  // --- Skeletons & Errors ---
  Widget _buildLoadingSkeleton() {
    return Column(
      children: [
        Container(
          height: 140,
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
            "Couldn't load analytics data.",
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
            onPressed: _fetchAnalytics,
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
}
