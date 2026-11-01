import 'package:flutter/material.dart';
import 'package:attendance_app/core/haptics/app_haptics.dart';

import 'package:google_fonts/google_fonts.dart';
import '../../auth/models/user_model.dart';
import '../../core/models/expansion_models.dart';
import '../../core/services/expansion_api_service.dart';
import '../../core/theme/app_colors.dart';
import '../models/warden_models.dart';
import '../services/warden_service.dart';
import '../widgets/warden_request_card.dart';
import '../widgets/warden_summary_card.dart';
import 'warden_leave_detail_screen.dart';
import '../widgets/warden_hostel_triage_sheet.dart';
import '../../core/localization/app_localizations.dart';
import '../../router/app_routes.dart';

class WardenHomeScreen extends StatefulWidget {
  final UserModel user;
  final VoidCallback onNavigateToRequests;
  final VoidCallback onNavigateToActivity;

  const WardenHomeScreen({
    Key? key,
    required this.user,
    required this.onNavigateToRequests,
    required this.onNavigateToActivity,
  }) : super(key: key);

  @override
  State<WardenHomeScreen> createState() => _WardenHomeScreenState();
}

class _WardenHomeScreenState extends State<WardenHomeScreen> {
  final WardenService _wardenService = WardenService();
  final ExpansionApiService _expansionApi = ExpansionApiService.instance;
  WardenSummaryModel _summary = WardenSummaryModel.empty();
  List<VisitorRequestModel> _pendingVisitors = [];
  bool _isLoading = true;
  int _selectedPendingTab = 0; // 0: Leaves, 1: Visitor Passes

  @override
  void initState() {
    super.initState();
    _loadSummary();
  }

  Future<void> _loadSummary() async {
    setState(() => _isLoading = true);
    try {
      final summaryFuture = _wardenService.fetchSummary(widget.user.id);
      final visitorsFuture = _expansionApi.getWardenPendingVisitors(widget.user.id);
      final results = await Future.wait([summaryFuture, visitorsFuture]);
      if (mounted) {
        final summary = results[0] as WardenSummaryModel;
        final visitors = results[1] as List<VisitorRequestModel>;
        setState(() {
          _summary = summary;
          _pendingVisitors = visitors;
          if (_summary.pendingRequests == 0 && _pendingVisitors.isNotEmpty) {
            _selectedPendingTab = 1;
          }
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleVisitorAction(VisitorRequestModel visitor, String action) async {
    try {
      await _expansionApi.actionVisitorRequest(
        requestId: visitor.id,
        wardenId: widget.user.id,
        action: action,
        remarks: action == 'APPROVE' ? 'Approved by Warden' : 'Rejected by Warden',
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            action == 'APPROVE'
                ? "Visitor pass approved for ${visitor.visitorName}. Gate QR pass issued."
                : "Visitor pass rejected for ${visitor.visitorName}.",
            style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold),
          ),
          backgroundColor: action == 'APPROVE' ? AppColors.success : AppColors.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
      _loadSummary();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Error: $e"),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _handleQuickAction(WardenLeaveRequestModel req, String action) async {
    final res = await _wardenService.processAction(
      req.id,
      action: action,
      remarks: action == 'APPROVE' ? 'Quick approved by Warden' : 'Rejected by Warden',
      wardenId: widget.user.id,
    );

    if (!mounted) return;

    if (res['success'] == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            action == 'APPROVE'
                ? "Leave approved for ${req.studentName}"
                : "Leave rejected for ${req.studentName}",
            style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold),
          ),
          backgroundColor: action == 'APPROVE' ? AppColors.success : AppColors.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
      _loadSummary();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(res['message'] ?? 'Action failed'),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: Colors.white,
        elevation: 0,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.admin_panel_settings_rounded,
                color: AppColors.primary,
                size: 20,
              ),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.user.name,
                  style: GoogleFonts.plusJakartaSans(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: AppColors.textPrimary,
                  ),
                ),
                Text(
                  "Campus Warden Command Center".tr(context),
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          // Mesh Hub Antenna shortcut
          IconButton(
            icon: const Icon(Icons.settings_input_antenna_rounded, color: Color(0xFF6366F1)),
            tooltip: 'Campus Mesh Hub',
            onPressed: () {
              AppHaptics.lightImpact();
              Navigator.pushNamed(context, AppRoutes.meshHub);
            },
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: AppColors.textSecondary),
            onPressed: _loadSummary,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadSummary,
        color: AppColors.primary,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Welcome Banner
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppColors.primary,
                      AppColors.primary.withValues(alpha: 0.85),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(22),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.22),
                      blurRadius: 14,
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
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.18),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.verified_rounded, size: 14, color: Colors.white),
                              const SizedBox(width: 5),
                              Text(
                                "INSTITUTIONAL WARDEN".tr(context),
                                style: GoogleFonts.jetBrainsMono(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Text(
                          DateTime.now().toLocal().toString().split(' ').first,
                          style: GoogleFonts.plusJakartaSans(
                            color: Colors.white.withValues(alpha: 0.8),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Text(
                      "Student Leave & Pass Control".tr(context),
                      style: GoogleFonts.plusJakartaSans(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "Review requests, grant gate clearances, and track transit securely.".tr(context),
                      style: GoogleFonts.plusJakartaSans(
                        color: Colors.white.withValues(alpha: 0.85),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),

              // CampusOS Mesh (M1-M7) Hostel Command Section
              _buildCampusMeshWardenSection(context),
              const SizedBox(height: 18),

              // Operational Metric Cards Grid (2x2)
              Text(
                "Operational Overview".tr(context),
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 12),

              Row(
                children: [
                  Expanded(
                    child: WardenSummaryCard(
                      title: "Pending Leaves".tr(context),
                      value: "${_summary.pendingRequests}",
                      subtitle: "Requires review".tr(context),
                      icon: Icons.hourglass_top_rounded,
                      color: AppColors.warning,
                      onTap: () {
                        setState(() => _selectedPendingTab = 0);
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: WardenSummaryCard(
                      title: "Visitor Passes".tr(context),
                      value: "${_pendingVisitors.length}",
                      subtitle: (_pendingVisitors.isEmpty ? "All reviewed" : "Awaiting approval").tr(context),
                      icon: Icons.badge_rounded,
                      color: const Color(0xFFD97706),
                      onTap: () {
                        setState(() => _selectedPendingTab = 1);
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: WardenSummaryCard(
                      title: "Approved Today".tr(context),
                      value: "${_summary.approvedToday}",
                      subtitle: "Clearance granted".tr(context),
                      icon: Icons.check_circle_rounded,
                      color: AppColors.success,
                      onTap: widget.onNavigateToRequests,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: WardenSummaryCard(
                      title: "Active Gate Passes".tr(context),
                      value: "${_summary.activeGatePasses}",
                      subtitle: "In transit / campus".tr(context),
                      icon: Icons.shield_rounded,
                      color: const Color(0xFF007AFF),
                      onTap: widget.onNavigateToRequests,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              if (_pendingVisitors.isNotEmpty) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFFBEB),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.6)),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFD97706).withValues(alpha: 0.08),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(9),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF59E0B).withValues(alpha: 0.2),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.badge_rounded, color: Color(0xFFD97706), size: 20),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "${_pendingVisitors.length} Visitor Pass${_pendingVisitors.length > 1 ? 'es' : ''} Awaiting Approval",
                              style: GoogleFonts.plusJakartaSans(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                                color: const Color(0xFF92400E),
                              ),
                            ),
                            Text(
                              "Review guest clearances to generate gate entry QR codes.",
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 11,
                                color: const Color(0xFFB45309),
                              ),
                            ),
                          ],
                        ),
                      ),
                      ElevatedButton(
                        onPressed: () {
                          setState(() {
                            _selectedPendingTab = 1;
                          });
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFD97706),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          elevation: 0,
                        ),
                        child: const Text("Review", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // Hostel & Visitors Operations Trigger
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFD97706).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.hotel_rounded,
                          color: Color(0xFFD97706), size: 24),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Hostel & Room Triage".tr(context),
                            style: GoogleFonts.plusJakartaSans(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _pendingVisitors.isEmpty
                                ? "Triage room changes, asset damage & full visitor logs"
                                : "${_pendingVisitors.length} visitor passes pending • Room & asset triage",
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    ElevatedButton(
                      onPressed: () {
                        WardenHostelTriageSheet.show(context,
                            wardenId: widget.user.id);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFD97706),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 8),
                        elevation: 0,
                      ),
                      child: Text("Triage".tr(context)),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Section Header: Pending Reviews
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    "Pending Approvals".tr(context),
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  if (_selectedPendingTab == 0)
                    TextButton(
                      onPressed: widget.onNavigateToRequests,
                      child: Text(
                        "View All Leaves".tr(context),
                        style: GoogleFonts.plusJakartaSans(
                          color: AppColors.primary,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    )
                  else
                    TextButton(
                      onPressed: () => WardenHostelTriageSheet.show(context, wardenId: widget.user.id),
                      child: Text(
                        "Triage Sheet".tr(context),
                        style: GoogleFonts.plusJakartaSans(
                          color: const Color(0xFFD97706),
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 10),

              // Segmented Filter Tabs: Student Leaves vs Visitor Passes
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: _buildPendingFilterTab(
                        index: 0,
                        title: "Student Leaves".tr(context),
                        count: _summary.pendingRequests,
                        icon: Icons.logout_rounded,
                        activeColor: AppColors.primary,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: _buildPendingFilterTab(
                        index: 1,
                        title: "Visitor Passes".tr(context),
                        count: _pendingVisitors.length,
                        icon: Icons.badge_rounded,
                        activeColor: const Color(0xFFD97706),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              if (_isLoading)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: CircularProgressIndicator(),
                  ),
                )
              else if (_selectedPendingTab == 0)
                ..._buildLeavesContent()
              else
                ..._buildVisitorsContent(),

              const SizedBox(height: 90),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPendingFilterTab({
    required int index,
    required String title,
    required int count,
    required IconData icon,
    required Color activeColor,
  }) {
    final isSelected = _selectedPendingTab == index;
    return GestureDetector(
      onTap: () {
        AppHaptics.selectionClick();
        setState(() => _selectedPendingTab = index);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 8),
        decoration: BoxDecoration(
          color: isSelected ? activeColor : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 15,
              color: isSelected ? Colors.white : AppColors.textSecondary,
            ),
            const SizedBox(width: 6),
            Text(
              title,
              style: GoogleFonts.plusJakartaSans(
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                fontSize: 12,
                color: isSelected ? Colors.white : AppColors.textPrimary,
              ),
            ),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              decoration: BoxDecoration(
                color: isSelected
                    ? Colors.white.withValues(alpha: 0.25)
                    : (count > 0 ? activeColor.withValues(alpha: 0.12) : Colors.black.withValues(alpha: 0.05)),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                "$count",
                style: GoogleFonts.jetBrainsMono(
                  fontWeight: FontWeight.bold,
                  fontSize: 11,
                  color: isSelected
                      ? Colors.white
                      : (count > 0 ? activeColor : AppColors.textSecondary),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildLeavesContent() {
    if (_summary.pendingPreview.isEmpty) {
      return [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.success.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.done_all_rounded,
                  size: 32,
                  color: AppColors.success,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                "Inbox Zero!",
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                "No student leave requests pending review at this time.",
                textAlign: TextAlign.center,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ];
    }

    return _summary.pendingPreview.map(
      (req) => WardenRequestCard(
        request: req,
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => WardenLeaveDetailScreen(
                initialRequest: req,
                user: widget.user,
              ),
            ),
          ).then((_) => _loadSummary());
        },
        onAction: (action) => _handleQuickAction(req, action),
      ),
    ).toList();
  }

  List<Widget> _buildVisitorsContent() {
    if (_pendingVisitors.isEmpty) {
      return [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.success.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.verified_user_rounded,
                  size: 32,
                  color: AppColors.success,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                "No Pending Visitor Passes",
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                "All campus guest gate passes have been processed. When hostel students request visitor passes, they will appear here for review.",
                textAlign: TextAlign.center,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ];
    }

    return _pendingVisitors.map((v) => _buildVisitorCard(v)).toList();
  }

  Widget _buildVisitorCard(VisitorRequestModel visitor) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFD97706).withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.badge_rounded,
                        color: Color(0xFFD97706),
                        size: 18,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            visitor.visitorName,
                            style: GoogleFonts.plusJakartaSans(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                              color: AppColors.textPrimary,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            visitor.visitorPhone,
                            style: GoogleFonts.jetBrainsMono(
                              fontSize: 11,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFD97706).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFD97706).withValues(alpha: 0.3)),
                ),
                child: Text(
                  visitor.relation.toUpperCase(),
                  style: GoogleFonts.jetBrainsMono(
                    color: const Color(0xFFD97706),
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(height: 1, color: AppColors.border),
          const SizedBox(height: 12),

          if (visitor.studentName != null && visitor.studentName!.isNotEmpty) ...[
            Row(
              children: [
                const Icon(Icons.school_rounded, size: 14, color: AppColors.textSecondary),
                const SizedBox(width: 6),
                Text(
                  "Student: ",
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Expanded(
                  child: Text(
                    "${visitor.studentName} ${visitor.registrationNumber != null ? '(${visitor.registrationNumber})' : ''}",
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12,
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.bold,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
          ],

          Row(
            children: [
              const Icon(Icons.calendar_today_rounded, size: 14, color: AppColors.textSecondary),
              const SizedBox(width: 6),
              Text(
                "Date: ${visitor.visitDate}",
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 12,
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 12),
              const Icon(Icons.schedule_rounded, size: 14, color: AppColors.textSecondary),
              const SizedBox(width: 6),
              Text(
                "${visitor.expectedEntryTime} - ${visitor.expectedExitTime}",
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 12,
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),

          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.info_outline_rounded, size: 14, color: AppColors.textSecondary),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  "Purpose: ${visitor.purpose}",
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              OutlinedButton.icon(
                onPressed: () => _handleVisitorAction(visitor, 'REJECT'),
                icon: const Icon(Icons.close_rounded, size: 16),
                label: const Text("Reject"),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.error,
                  side: const BorderSide(color: AppColors.error),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                ),
              ),
              const SizedBox(width: 10),
              ElevatedButton.icon(
                onPressed: () => _handleVisitorAction(visitor, 'APPROVE'),
                icon: const Icon(Icons.check_circle_rounded, size: 16),
                label: const Text("Approve & Issue Pass"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.success,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  elevation: 0,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCampusMeshWardenSection(BuildContext context) {
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
                      color: const Color(0xFF6366F1).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.night_shelter_rounded,
                      color: Color(0xFF6366F1),
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
                            "Hostel Mesh",
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
                              color: const Color(0xFF10B981).withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              "M1–M7",
                              style: GoogleFonts.jetBrainsMono(
                                fontSize: 9.5,
                                fontWeight: FontWeight.w700,
                                color: const Color(0xFF10B981),
                              ),
                            ),
                          ),
                        ],
                      ),
                      Text(
                        "Zero-Cellular Hostel Disaster Flare & Peer Mesh",
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
                        "Open Hub",
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
                child: _buildMeshWardenActionItem(
                  context,
                  title: "Hostel Flare",
                  subtitle: "SOS Alert",
                  icon: Icons.warning_amber_rounded,
                  color: const Color(0xFFEF4444),
                  route: AppRoutes.meshEmergency,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildMeshWardenActionItem(
                  context,
                  title: "Mesh Chat",
                  subtitle: "Hostel P2P",
                  icon: Icons.chat_bubble_outline_rounded,
                  color: const Color(0xFF0EA5E9),
                  route: AppRoutes.meshChat,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildMeshWardenActionItem(
                  context,
                  title: "Resident Radar",
                  subtitle: "Find Nearby",
                  icon: Icons.radar_rounded,
                  color: const Color(0xFF10B981),
                  route: AppRoutes.meshRadar,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildMeshWardenActionItem(
                  context,
                  title: "AirDrop",
                  subtitle: "Notices P2P",
                  icon: Icons.file_upload_outlined,
                  color: const Color(0xFF6366F1),
                  route: AppRoutes.meshAirDrop,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMeshWardenActionItem(
    BuildContext context, {
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
