import 'package:flutter/material.dart';
import 'package:attendance_app/core/haptics/app_haptics.dart';

import 'package:google_fonts/google_fonts.dart';

import '../../auth/models/user_model.dart';
import '../../core/theme/app_colors.dart';
import '../models/admin_dashboard_models.dart';
import '../services/admin_dashboard_service.dart';
import '../widgets/admin_complaint_detail_sheet.dart';

/// CampusOS Admin Complaints Queue & Lifecycle Management Screen.
///
/// Features:
/// - Real-time filtering by status, priority, category, and ageing SLA (>48h).
/// - Fast text search across title, description, and location.
/// - Restrained Apple-grade card hierarchy with priority and ageing indicators.
/// - Full lifecycle actions via [AdminComplaintDetailSheet] (Assign, Start, Resolve, Reopen, Reject).
class AdminComplaintsScreen extends StatefulWidget {
  final UserModel? user;
  final String? initialStatusFilter;
  final bool initialAgeingFilter;

  const AdminComplaintsScreen({
    Key? key,
    this.user,
    this.initialStatusFilter,
    this.initialAgeingFilter = false,
  }) : super(key: key);

  @override
  State<AdminComplaintsScreen> createState() => _AdminComplaintsScreenState();
}

class _AdminComplaintsScreenState extends State<AdminComplaintsScreen> {
  final AdminDashboardService _service = AdminDashboardService();
  final TextEditingController _searchController = TextEditingController();

  List<AdminComplaintItemModel> _complaints = [];
  bool _isLoading = true;
  String? _errorMessage;

  late String _selectedStatus;
  String _selectedPriority = 'ALL';
  late bool _filterAgeingOnly;

  final List<String> _statusFilters = [
    'ALL',
    'PENDING',
    'ASSIGNED',
    'IN_PROGRESS',
    'RESOLVED',
    'CLOSED',
    'REOPENED',
    'REJECTED',
  ];

  final List<String> _priorityFilters = [
    'ALL',
    'URGENT',
    'HIGH',
    'MEDIUM',
    'LOW',
  ];

  @override
  void initState() {
    super.initState();
    _selectedStatus = widget.initialStatusFilter ?? 'ALL';
    _filterAgeingOnly = widget.initialAgeingFilter;
    _fetchComplaints();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchComplaints() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final list = await _service.getComplaints(
        status: _selectedStatus == 'ALL' ? null : _selectedStatus,
        priority: _selectedPriority == 'ALL' ? null : _selectedPriority,
        ageing: _filterAgeingOnly ? true : null,
        search: _searchController.text.trim().isNotEmpty
            ? _searchController.text.trim()
            : null,
        requesterId: widget.user?.id,
      ).catchError((_) => <AdminComplaintItemModel>[]);

      if (mounted) {
        setState(() {
          _complaints = list;
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

  void _openDetail(String complaintId) {
    AppHaptics.selectionClick();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => AdminComplaintDetailSheet(
        complaintId: complaintId,
        currentUser: widget.user,
        onActionCompleted: () {
          _fetchComplaints();
        },
      ),
    );
  }

  Color _statusColor(String status) {
    switch (status.toUpperCase()) {
      case 'PENDING':
        return const Color(0xFFF59E0B);
      case 'ASSIGNED':
        return AppColors.info;
      case 'IN_PROGRESS':
        return const Color(0xFF8B5CF6);
      case 'RESOLVED':
      case 'CLOSED':
        return AppColors.success;
      case 'REOPENED':
      case 'REJECTED':
        return AppColors.danger;
      default:
        return AppColors.textSecondary;
    }
  }

  Color _priorityColor(String priority) {
    switch (priority.toUpperCase()) {
      case 'URGENT':
        return AppColors.danger;
      case 'HIGH':
        return const Color(0xFFEA580C);
      case 'MEDIUM':
        return const Color(0xFFD97706);
      case 'LOW':
        return const Color(0xFF64748B);
      default:
        return AppColors.textSecondary;
    }
  }

  String _formatAge(double ageHours) {
    if (ageHours < 1) return 'Just now';
    if (ageHours < 24) return '${ageHours.round()}h ago';
    final days = (ageHours / 24).floor();
    return '$days d ago';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0.5,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              size: 20, color: AppColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Complaint Queue',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            Text(
              '${_complaints.length} records loaded',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded,
                color: AppColors.primary, size: 22),
            onPressed: () {
              AppHaptics.lightImpact();
              _fetchComplaints();
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          // Filter Bar
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: Column(
              children: [
                // Search Field
                RepaintBoundary(
                  child: Container(
                    height: 40,
                    decoration: BoxDecoration(
                      color: AppColors.bg,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: TextField(
                      controller: _searchController,
                      onSubmitted: (_) => _fetchComplaints(),
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 14,
                        color: AppColors.textPrimary,
                      ),
                      decoration: InputDecoration(
                        hintText: 'Search complaints by title, room, ID...',
                        hintStyle: GoogleFonts.plusJakartaSans(
                          fontSize: 13,
                          color: AppColors.textSecondary,
                        ),
                        prefixIcon: const Icon(Icons.search_rounded,
                            size: 18, color: AppColors.textSecondary),
                        suffixIcon: _searchController.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear_rounded,
                                    size: 16, color: AppColors.textSecondary),
                                onPressed: () {
                                  _searchController.clear();
                                  _fetchComplaints();
                                },
                              )
                            : null,
                        border: InputBorder.none,
                        contentPadding:
                            const EdgeInsets.symmetric(horizontal: 12),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 10),

                // Status & Ageing Filter Chips
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  child: Row(
                    children: [
                      // Ageing toggle chip
                      GestureDetector(
                        onTap: () {
                          AppHaptics.selectionClick();
                          setState(() {
                            _filterAgeingOnly = !_filterAgeingOnly;
                          });
                          _fetchComplaints();
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: _filterAgeingOnly
                                ? AppColors.danger.withValues(alpha: 0.12)
                                : AppColors.bg,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: _filterAgeingOnly
                                  ? AppColors.danger
                                  : Colors.transparent,
                              width: 1,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.warning_amber_rounded,
                                size: 14,
                                color: _filterAgeingOnly
                                    ? AppColors.danger
                                    : AppColors.textSecondary,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'Ageing >48h',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 12,
                                  fontWeight: _filterAgeingOnly
                                      ? FontWeight.w700
                                      : FontWeight.w500,
                                  color: _filterAgeingOnly
                                      ? AppColors.danger
                                      : AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),

                      // Status Chips
                      ..._statusFilters.map((st) {
                        final isSelected = _selectedStatus == st;
                        return Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: ChoiceChip(
                            label: Text(
                              st == 'ALL' ? 'All Status' : st.replaceAll('_', ' '),
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 12,
                                fontWeight: isSelected
                                    ? FontWeight.w700
                                    : FontWeight.w500,
                                color: isSelected
                                    ? Colors.white
                                    : AppColors.textSecondary,
                              ),
                            ),
                            selected: isSelected,
                            selectedColor: AppColors.primary,
                            backgroundColor: AppColors.bg,
                            elevation: 0,
                            pressElevation: 0,
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                              side: BorderSide(
                                color: isSelected
                                    ? AppColors.primary
                                    : Colors.transparent,
                              ),
                            ),
                            onSelected: (val) {
                              if (val) {
                                AppHaptics.selectionClick();
                                setState(() => _selectedStatus = st);
                                _fetchComplaints();
                              }
                            },
                          ),
                        );
                      }),
                      const SizedBox(width: 8),

                      // Priority Chips
                      ..._priorityFilters.map((pr) {
                        final isSelected = _selectedPriority == pr;
                        final pCol = _priorityColor(pr);
                        return Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: ChoiceChip(
                            label: Text(
                              pr == 'ALL' ? 'All Priority' : pr,
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 12,
                                fontWeight: isSelected
                                    ? FontWeight.w700
                                    : FontWeight.w500,
                                color: isSelected
                                    ? Colors.white
                                    : AppColors.textSecondary,
                              ),
                            ),
                            selected: isSelected,
                            selectedColor: isSelected && pr != 'ALL' ? pCol : AppColors.primary,
                            backgroundColor: AppColors.bg,
                            elevation: 0,
                            pressElevation: 0,
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                              side: BorderSide(
                                color: isSelected
                                    ? (pr != 'ALL' ? pCol : AppColors.primary)
                                    : Colors.transparent,
                              ),
                            ),
                            onSelected: (val) {
                              if (val) {
                                AppHaptics.selectionClick();
                                setState(() => _selectedPriority = pr);
                                _fetchComplaints();
                              }
                            },
                          ),
                        );
                      }),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const Divider(height: 1, color: AppColors.border),

          // Content List
          Expanded(
            child: _buildBody(),
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(
          color: AppColors.primary,
          strokeWidth: 2.5,
        ),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline_rounded,
                  size: 44, color: AppColors.danger),
              const SizedBox(height: 12),
              Text(
                "Couldn't load complaints queue.",
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _fetchComplaints,
                icon: const Icon(Icons.refresh_rounded, size: 16),
                label: const Text('Try Again'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_complaints.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: const BoxDecoration(
                  color: AppColors.primaryLight,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.task_alt_rounded,
                    size: 36, color: AppColors.primary),
              ),
              const SizedBox(height: 16),
              Text(
                'No Complaints Found',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'There are no complaints matching your selected filters.',
                textAlign: TextAlign.center,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _fetchComplaints,
      color: AppColors.primary,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
        itemCount: _complaints.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (context, index) {
          final comp = _complaints[index];
          return _buildComplaintCard(comp);
        },
      ),
    );
  }

  Widget _buildComplaintCard(AdminComplaintItemModel item) {
    final statusCol = _statusColor(item.status);
    final priorityCol = _priorityColor(item.priority);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: item.isAgeing
              ? AppColors.danger.withValues(alpha: 0.4)
              : AppColors.border,
          width: item.isAgeing ? 1.2 : 0.8,
        ),
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
          borderRadius: BorderRadius.circular(14),
          onTap: () => _openDetail(item.id),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top row: Category, Priority, Ageing flag
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppColors.bg,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        item.category,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 7, vertical: 3),
                      decoration: BoxDecoration(
                        color: priorityCol.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        item.priority,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: priorityCol,
                        ),
                      ),
                    ),
                    if (item.isAgeing) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.danger.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.timer_outlined,
                                size: 10, color: AppColors.danger),
                            const SizedBox(width: 3),
                            Text(
                              'Ageing',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: AppColors.danger,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    const Spacer(),
                    Text(
                      _formatAge(item.ageHours),
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                // Title
                Text(
                  item.title,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),

                // Location & Student
                Row(
                  children: [
                    const Icon(Icons.location_on_outlined,
                        size: 13, color: AppColors.textSecondary),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        "${item.location} · ${item.studentName}",
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                const Divider(height: 1, color: AppColors.border),
                const SizedBox(height: 8),

                // Bottom row: Status badge + Assigned to + Action arrow
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: statusCol.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(
                              color: statusCol,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            item.status.replaceAll('_', ' '),
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: statusCol,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Row(
                      children: [
                        if (item.assignedToName != null &&
                            item.assignedToName!.isNotEmpty) ...[
                          const Icon(Icons.person_outline_rounded,
                              size: 14, color: AppColors.textSecondary),
                          const SizedBox(width: 4),
                          Text(
                            item.assignedToName!,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          const SizedBox(width: 8),
                        ],
                        const Icon(Icons.arrow_forward_ios_rounded,
                            size: 12, color: AppColors.textSecondary),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
