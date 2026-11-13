import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/haptics/app_haptics.dart';
import '../../../auth/providers/user_provider.dart';
import '../models/leave_request_model.dart';
import '../models/gate_pass_model.dart';
import '../models/complaint_model.dart';
import '../models/notice_model.dart';
import '../services/leave_service.dart';
import '../services/gate_pass_service.dart';
import '../services/complaint_service.dart';
import '../services/notice_service.dart';
import '../widgets/requests/leave_request_form.dart';
import '../widgets/requests/gate_pass_form.dart';
import '../widgets/requests/complaint_form.dart';
import '../widgets/requests/complaint_detail_sheet.dart';

import '../widgets/requests/notice_card.dart';
import '../widgets/requests/document_requests_section.dart';
import '../widgets/requests/hostel_requests_section.dart';
import '../widgets/requests/visitor_requests_section.dart';
import '../../../core/localization/app_localizations.dart';
import '../../shared/widgets/motion/apple_bounceable.dart';
import '../../shared/widgets/motion/apple_spring_scroll_physics.dart';
import '../../shared/widgets/motion/apple_spring_curve.dart';

class RequestsScreen extends StatefulWidget {
  final int initialTabIndex;
  final int initialSubTabIndex;

  const RequestsScreen({
    Key? key,
    this.initialTabIndex = 0,
    this.initialSubTabIndex = 0,
  }) : super(key: key);

  @override
  State<RequestsScreen> createState() => RequestsScreenState();
}

class RequestsScreenState extends State<RequestsScreen> {
  int _selectedIndex = 0;
  int _subTabIndex = 0; // 0: Leaves, 1: Gate Passes
  late final PageController _pageController;

  final LeaveService _leaveService = LeaveService();
  final GatePassService _gatePassService = GatePassService();
  final ComplaintService _complaintService = ComplaintService();
  final NoticeService _noticeService = NoticeService();

  List<LeaveRequestModel> _leaveRequests = [];
  bool _isLoadingLeaves = false;
  String? _leaveError;

  List<GatePassModel> _gatePasses = [];
  bool _isLoadingGatePasses = false;
  String? _gatePassError;

  List<ComplaintModel> _complaints = [];
  bool _isLoadingComplaints = false;
  String? _complaintError;

  List<NoticeModel> _notices = [];
  bool _isLoadingNotices = false;
  String? _noticeError;

  int get _unreadNoticesCount => _notices.where((n) => !n.isRead).length;

  @override
  void initState() {
    super.initState();
    _selectedIndex = widget.initialTabIndex;
    _subTabIndex = widget.initialSubTabIndex;
    _pageController = PageController(initialPage: _selectedIndex);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadAll();
    });
  }

  @override
  void didUpdateWidget(covariant RequestsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialTabIndex != oldWidget.initialTabIndex ||
        widget.initialSubTabIndex != oldWidget.initialSubTabIndex) {
      setTab(widget.initialTabIndex, subTab: widget.initialSubTabIndex);
    }
  }

  void setTab(int index, {int subTab = 0}) {
    if (mounted) {
      setState(() {
        _selectedIndex = index;
        _subTabIndex = subTab;
      });
      if (_pageController.hasClients) {
        _pageController.animateToPage(
          index,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      }
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _loadAll() async {
    await Future.wait([
      _loadLeaveRequests(),
      _loadGatePasses(),
      _loadComplaints(),
      _loadNotices(),
    ]);
  }

  Future<void> _loadNotices() async {
    final studentId = Provider.of<UserProvider>(context, listen: false).user?.id;
    if (studentId == null || studentId.isEmpty) return;

    setState(() {
      _isLoadingNotices = true;
      _noticeError = null;
    });

    try {
      final list = await _noticeService.getNotices(requesterId: studentId);
      if (mounted) {
        setState(() {
          _notices = list;
          _isLoadingNotices = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _noticeError = e.toString().replaceAll('Exception: ', '');
          _isLoadingNotices = false;
        });
      }
    }
  }

  Future<void> _loadComplaints() async {
    final studentId = Provider.of<UserProvider>(context, listen: false).user?.id;
    if (studentId == null || studentId.isEmpty) return;

    setState(() {
      _isLoadingComplaints = true;
      _complaintError = null;
    });

    try {
      final list = await _complaintService.getStudentComplaints(studentId, requesterId: studentId);
      if (mounted) {
        setState(() {
          _complaints = list;
          _isLoadingComplaints = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _complaintError = e.toString().replaceAll('Exception: ', '');
          _isLoadingComplaints = false;
        });
      }
    }
  }

  Future<void> _loadLeaveRequests() async {
    final studentId = Provider.of<UserProvider>(context, listen: false).user?.id;
    if (studentId == null || studentId.isEmpty) return;

    setState(() {
      _isLoadingLeaves = true;
      _leaveError = null;
    });

    try {
      final list = await _leaveService.getStudentLeaveRequests(studentId);
      if (mounted) {
        setState(() {
          _leaveRequests = list;
          _isLoadingLeaves = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _leaveError = e.toString().replaceAll('Exception: ', '');
          _isLoadingLeaves = false;
        });
      }
    }
  }

  Future<void> _loadGatePasses() async {
    final studentId = Provider.of<UserProvider>(context, listen: false).user?.id;
    if (studentId == null || studentId.isEmpty) return;

    setState(() {
      _isLoadingGatePasses = true;
      _gatePassError = null;
    });

    try {
      final list = await _gatePassService.getStudentGatePasses(studentId);
      if (mounted) {
        setState(() {
          _gatePasses = list;
          _isLoadingGatePasses = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _gatePassError = e.toString().replaceAll('Exception: ', '');
          _isLoadingGatePasses = false;
        });
      }
    }
  }

  Future<void> _cancelLeave(LeaveRequestModel req) async {
    final studentId = Provider.of<UserProvider>(context, listen: false).user?.id;
    if (studentId == null) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          "Cancel Leave Request?",
          style: GoogleFonts.plusJakartaSans(
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
        content: Text(
          "Are you sure you want to cancel your leave request for ${req.leaveType} (${DateFormat('MMM dd').format(req.startDate)} - ${DateFormat('MMM dd').format(req.endDate)})?",
          style: GoogleFonts.plusJakartaSans(
            color: AppColors.textSecondary,
            fontSize: 14,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              "Keep Request",
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
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 0,
            ),
            child: Text(
              "Cancel Leave",
              style: GoogleFonts.plusJakartaSans(
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await _leaveService.cancelLeaveRequest(
        requestId: req.id,
        studentId: studentId,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            "Leave request cancelled",
            style: GoogleFonts.plusJakartaSans(color: Colors.white),
          ),
          backgroundColor: AppColors.textPrimary,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
      _loadAll();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            e.toString().replaceAll('Exception: ', ''),
            style: GoogleFonts.plusJakartaSans(color: Colors.white),
          ),
          backgroundColor: AppColors.danger,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    }
  }

  void _showLeaveForm() async {
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => LeaveRequestForm(
        onRequestSubmitted: _loadAll,
      ),
    );
    if (result == true) {
      _loadAll();
    }
  }

  void _showGatePassForm({String? initialLeaveId}) async {
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => GatePassForm(
        initialLeaveRequestId: initialLeaveId,
        onRequestSubmitted: _loadAll,
      ),
    );
    if (result == true) {
      _loadAll();
    }
  }

  void _showComplaintForm() async {
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => ComplaintForm(
        onRequestSubmitted: _loadAll,
      ),
    );
    if (result == true) {
      _loadAll();
    }
  }

  void _showComplaintDetails(ComplaintModel complaint) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => ComplaintDetailSheet(
        complaint: complaint,
        onStatusChanged: _loadAll,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgOf(context),
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Requests".tr(context),
              style: GoogleFonts.plusJakartaSans(
                color: AppColors.textPrimaryOf(context),
                fontWeight: FontWeight.w800,
                fontSize: 22,
                letterSpacing: -0.5,
              ),
            ),
            Text(
              "Transit, Documents & Campus Services",
              style: GoogleFonts.plusJakartaSans(
                color: AppColors.textSecondaryOf(context),
                fontWeight: FontWeight.w500,
                fontSize: 11.5,
              ),
            ),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: AppleBounceable(
              scaleFactor: 0.90,
              onTap: () {
                AppHaptics.lightImpact();
                _loadAll();
              },
              child: Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: AppColors.surfaceAltOf(context),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppColors.borderOf(context).withValues(alpha: 0.6),
                    width: 0.5,
                  ),
                ),
                child: const Icon(
                  Icons.refresh_rounded,
                  size: 20,
                  color: AppColors.primary,
                ),
              ),
            ),
          ),
        ],
        backgroundColor: AppColors.surfaceOf(context),
        elevation: 0,
        centerTitle: false,
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: AppColors.surfaceOf(context),
              border: Border(
                bottom: BorderSide(
                  color: AppColors.borderOf(context).withValues(alpha: 0.7),
                  width: 0.5,
                ),
              ),
            ),
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 16),
            child: _buildSegmentedControl(),
          ),
          Expanded(
            child: PageView(
              controller: _pageController,
              onPageChanged: (index) {
                setState(() => _selectedIndex = index);
              },
              physics: const AppleSpringScrollPhysics(),
              children: [
                _buildTransitSection(),
                const DocumentRequestsSection(),
                const HostelRequestsSection(),
                const VisitorRequestsSection(),
                _buildComplaintsSection(),
                _buildNoticesSection(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSegmentedControl() {
    final tabs = [
      {'title': 'Leave & Pass'.tr(context), 'icon': Icons.directions_walk_rounded, 'badge': 0},
      {'title': 'Documents'.tr(context), 'icon': Icons.description_rounded, 'badge': 0},
      {'title': 'Hostel & Room'.tr(context), 'icon': Icons.hotel_rounded, 'badge': 0},
      {'title': 'Visitor Pass'.tr(context), 'icon': Icons.badge_rounded, 'badge': 0},
      {'title': 'Complaints'.tr(context), 'icon': Icons.report_problem_rounded, 'badge': 0},
      {'title': 'Notices'.tr(context), 'icon': Icons.campaign_rounded, 'badge': _unreadNoticesCount},
    ];

    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const AppleSpringScrollPhysics(),
        itemCount: tabs.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final item = tabs[index];
          final isSelected = _selectedIndex == index;
          final badge = item['badge'] as int;

          return AppleBounceable(
            scaleFactor: 0.94,
            onTap: () {
              AppHaptics.selectionClick();
              setState(() => _selectedIndex = index);
              _pageController.animateToPage(
                index,
                duration: const Duration(milliseconds: 380),
                curve: AppleSpringCurve.standard,
              );
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 240),
              curve: AppleSpringCurve.standard,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
              decoration: BoxDecoration(
                color: isSelected ? AppColors.primary : AppColors.surfaceAltOf(context),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isSelected
                      ? AppColors.primary
                      : AppColors.borderOf(context).withValues(alpha: 0.6),
                  width: 0.5,
                ),
                boxShadow: isSelected
                    ? [
                        BoxShadow(
                          color: AppColors.primary.withValues(alpha: 0.25),
                          blurRadius: 10,
                          offset: const Offset(0, 3),
                        )
                      ]
                    : null,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    item['icon'] as IconData,
                    size: 15,
                    color: isSelected ? Colors.white : AppColors.textSecondaryOf(context),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    item['title'] as String,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12.5,
                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                      color: isSelected ? Colors.white : AppColors.textPrimaryOf(context),
                      letterSpacing: -0.2,
                    ),
                  ),
                  if (badge > 0) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                      decoration: BoxDecoration(
                        color: isSelected ? Colors.white : AppColors.primary,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        badge.toString(),
                        style: GoogleFonts.plusJakartaSans(
                          color: isSelected ? AppColors.primary : Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildTransitSection() {
    return Column(
      children: [
        // Sub-filter segmented pill
        Container(
          margin: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: AppColors.surfaceAltOf(context),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: AppColors.borderOf(context).withValues(alpha: 0.6),
              width: 0.5,
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: _buildSubFilterTab(0, "Leave Requests".tr(context), _leaveRequests.length),
              ),
              Expanded(
                child: _buildSubFilterTab(1, "Gate Passes".tr(context), _gatePasses.length),
              ),
            ],
          ),
        ),
        Expanded(
          child: _subTabIndex == 0 ? _buildLeaveList() : _buildGatePassList(),
        ),
      ],
    );
  }

  Widget _buildSubFilterTab(int index, String label, int count) {
    final isSelected = _subTabIndex == index;
    return AppleBounceable(
      scaleFactor: 0.96,
      onTap: () {
        AppHaptics.selectionClick();
        setState(() => _subTabIndex = index);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: AppleSpringCurve.standard,
        padding: const EdgeInsets.symmetric(vertical: 9),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.surfaceOf(context) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: isSelected
              ? Border.all(
                  color: AppColors.borderOf(context).withValues(alpha: 0.4),
                  width: 0.5,
                )
              : null,
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              label,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                color: isSelected ? AppColors.textPrimaryOf(context) : AppColors.textSecondaryOf(context),
                letterSpacing: -0.2,
              ),
            ),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                color: isSelected
                    ? AppColors.primary.withValues(alpha: 0.12)
                    : AppColors.borderOf(context).withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                "$count",
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: isSelected ? AppColors.primary : AppColors.textSecondaryOf(context),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLeaveList() {
    if (_isLoadingLeaves && _leaveRequests.isEmpty) {
      return const Center(child: CircularProgressIndicator(color: AppColors.primary));
    }

    if (_leaveError != null && _leaveRequests.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline_rounded, size: 48, color: AppColors.danger),
              const SizedBox(height: 16),
              Text(
                "Unable to load leave requests",
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _leaveError!,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: _loadAll,
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text("Retry"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_leaveRequests.isEmpty) {
      return _buildEmptyState(
        icon: Icons.event_available_rounded,
        headline: "No Leave Requests",
        explanation:
            "Submit a leave request when you need time away from campus. Approved leaves can be used to request Gate Passes.",
        primaryActionLabel: "New Leave Request",
        onPrimaryAction: _showLeaveForm,
      );
    }

    return RefreshIndicator(
      onRefresh: _loadAll,
      color: AppColors.primary,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
        physics: AppleSpringScrollPhysics.always,
        itemCount: _leaveRequests.length + 1,
        separatorBuilder: (_, __) => const SizedBox(height: 14),
        itemBuilder: (context, index) {
          if (index == 0) {
            return Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "Applications (${_leaveRequests.length})",
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textSecondary,
                    letterSpacing: 0.5,
                  ),
                ),
                TextButton.icon(
                  onPressed: _showLeaveForm,
                  icon: const Icon(Icons.add_rounded, size: 18),
                  label: const Text("New Leave"),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    textStyle: GoogleFonts.plusJakartaSans(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            );
          }
          final req = _leaveRequests[index - 1];
          return _buildLeaveCard(req);
        },
      ),
    );
  }

  Widget _buildLeaveCard(LeaveRequestModel req) {
    Color statusColor;
    Color statusBg;
    IconData statusIcon;
    String statusText = req.status;

    if (req.isApproved) {
      statusColor = AppColors.emerald;
      statusBg = AppColors.emerald.withValues(alpha: 0.12);
      statusIcon = Icons.check_circle_rounded;
      statusText = "Approved";
    } else if (req.isRejected) {
      statusColor = AppColors.danger;
      statusBg = AppColors.danger.withValues(alpha: 0.12);
      statusIcon = Icons.cancel_rounded;
      statusText = "Rejected";
    } else if (req.isCancelled) {
      statusColor = AppColors.textSecondaryOf(context);
      statusBg = AppColors.borderOf(context).withValues(alpha: 0.4);
      statusIcon = Icons.block_rounded;
      statusText = "Cancelled";
    } else {
      statusColor = AppColors.warning;
      statusBg = AppColors.warning.withValues(alpha: 0.14);
      statusIcon = Icons.schedule_rounded;
      statusText = "Pending Review";
    }

    final dateFormat = DateFormat('MMM dd, yyyy');
    final startStr = dateFormat.format(req.startDate);
    final endStr = dateFormat.format(req.endDate);
    final durationDays = req.endDate.difference(req.startDate).inDays + 1;
    final durationLabel = "$durationDays ${durationDays == 1 ? 'day' : 'days'}";

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceOf(context),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppColors.borderOf(context).withValues(alpha: 0.7),
          width: 0.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 12,
            offset: const Offset(0, 4),
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
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.event_note_rounded, size: 14, color: AppColors.primary),
                    const SizedBox(width: 5),
                    Text(
                      req.leaveType,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: statusBg,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(statusIcon, size: 13, color: statusColor),
                    const SizedBox(width: 5),
                    Text(
                      statusText,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: statusColor,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.surfaceAltOf(context),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: AppColors.borderOf(context).withValues(alpha: 0.5),
                width: 0.5,
              ),
            ),
            child: Row(
              children: [
                const Icon(Icons.calendar_today_rounded, size: 13, color: AppColors.primary),
                const SizedBox(width: 8),
                Text(
                  "$startStr — $endStr",
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimaryOf(context),
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    durationLabel,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Text(
            req.reason,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 13.5,
              color: AppColors.textPrimaryOf(context).withValues(alpha: 0.88),
              height: 1.45,
            ),
          ),
          if (req.reviewRemarks != null && req.reviewRemarks!.isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: statusBg.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: statusColor.withValues(alpha: 0.25),
                  width: 0.5,
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.rate_review_outlined, size: 14, color: statusColor),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      "Review: ${req.reviewRemarks}",
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: statusColor,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 12),
          Divider(
            height: 1,
            color: AppColors.borderOf(context).withValues(alpha: 0.6),
            thickness: 0.5,
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "Submitted ${dateFormat.format(req.createdAt)}",
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 11,
                  color: AppColors.textSecondaryOf(context),
                ),
              ),
              if (req.isPending)
                AppleBounceable(
                  scaleFactor: 0.94,
                  onTap: () {
                    AppHaptics.selectionClick();
                    _cancelLeave(req);
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    child: Text(
                      "Cancel Request",
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppColors.danger,
                      ),
                    ),
                  ),
                )
              else if (req.isApproved)
                AppleBounceable(
                  scaleFactor: 0.95,
                  onTap: () {
                    AppHaptics.lightImpact();
                    _showGatePassForm(initialLeaveId: req.id);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary.withValues(alpha: 0.25),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.vpn_key_outlined, size: 13, color: Colors.white),
                        const SizedBox(width: 5),
                        Text(
                          "Request Gate Pass",
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildGatePassList() {
    if (_isLoadingGatePasses && _gatePasses.isEmpty) {
      return const Center(child: CircularProgressIndicator(color: AppColors.primary));
    }

    if (_gatePassError != null && _gatePasses.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline_rounded, size: 48, color: AppColors.danger),
              const SizedBox(height: 16),
              Text(
                "Unable to load gate passes",
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimaryOf(context),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _gatePassError!,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 13,
                  color: AppColors.textSecondaryOf(context),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: _loadAll,
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text("Retry"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_gatePasses.isEmpty) {
      return _buildEmptyState(
        icon: Icons.vpn_key_outlined,
        headline: "No Gate Passes",
        explanation:
            "Gate passes grant authorized exit through campus gates. You need an approved leave request to create a gate pass.",
        primaryActionLabel: "New Gate Pass",
        onPrimaryAction: () => _showGatePassForm(),
        secondaryActionLabel: "Apply for Leave",
        onSecondaryAction: _showLeaveForm,
      );
    }

    return RefreshIndicator(
      onRefresh: _loadAll,
      color: AppColors.primary,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
        physics: AppleSpringScrollPhysics.always,
        itemCount: _gatePasses.length + 1,
        separatorBuilder: (_, __) => const SizedBox(height: 14),
        itemBuilder: (context, index) {
          if (index == 0) {
            return Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "Gate Passes (${_gatePasses.length})",
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textSecondaryOf(context),
                    letterSpacing: 0.5,
                  ),
                ),
                TextButton.icon(
                  onPressed: () {
                    AppHaptics.lightImpact();
                    _showGatePassForm();
                  },
                  icon: const Icon(Icons.add_rounded, size: 18),
                  label: const Text("New Pass"),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    textStyle: GoogleFonts.plusJakartaSans(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            );
          }
          final pass = _gatePasses[index - 1];
          return _buildGatePassCard(pass);
        },
      ),
    );
  }

  Widget _buildGatePassCard(GatePassModel pass) {
    Color statusColor;
    Color statusBg;
    IconData statusIcon;
    String statusText = pass.status;

    if (pass.isIssued) {
      statusColor = AppColors.emerald;
      statusBg = AppColors.emerald.withValues(alpha: 0.12);
      statusIcon = Icons.check_circle_rounded;
      statusText = "ISSUED • Ready";
    } else if (pass.isExited) {
      statusColor = AppColors.warning;
      statusBg = AppColors.warning.withValues(alpha: 0.14);
      statusIcon = Icons.departure_board_rounded;
      statusText = "EXITED • Off Campus";
    } else if (pass.isReturned) {
      statusColor = Colors.indigo;
      statusBg = Colors.indigo.withValues(alpha: 0.12);
      statusIcon = Icons.keyboard_return_rounded;
      statusText = "RETURNED";
    } else if (pass.isApproved) {
      statusColor = AppColors.primary;
      statusBg = AppColors.primary.withValues(alpha: 0.12);
      statusIcon = Icons.verified_outlined;
      statusText = "APPROVED";
    } else if (pass.isExpired) {
      statusColor = AppColors.textSecondaryOf(context);
      statusBg = AppColors.borderOf(context).withValues(alpha: 0.5);
      statusIcon = Icons.timelapse_rounded;
      statusText = "EXPIRED";
    } else if (pass.isRejected) {
      statusColor = AppColors.danger;
      statusBg = AppColors.danger.withValues(alpha: 0.12);
      statusIcon = Icons.cancel_rounded;
      statusText = "REJECTED";
    } else {
      statusColor = AppColors.warning;
      statusBg = AppColors.warning.withValues(alpha: 0.12);
      statusIcon = Icons.schedule_rounded;
      statusText = "PENDING";
    }

    final timeFormat = DateFormat('MMM dd, hh:mm a');

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceOf(context),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: pass.isActive
              ? statusColor.withValues(alpha: 0.5)
              : AppColors.borderOf(context).withValues(alpha: 0.7),
          width: pass.isActive ? 1.0 : 0.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 12,
            offset: const Offset(0, 4),
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
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.location_on_outlined, size: 16, color: AppColors.primary),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    pass.destination,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimaryOf(context),
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: statusBg,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(statusIcon, size: 13, color: statusColor),
                    const SizedBox(width: 4),
                    Text(
                      statusText,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: statusColor,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.surfaceAltOf(context),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: AppColors.borderOf(context).withValues(alpha: 0.5),
                width: 0.5,
              ),
            ),
            child: Row(
              children: [
                const Icon(Icons.access_time_rounded, size: 13, color: AppColors.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    "${timeFormat.format(pass.expectedExitTime)} → ${timeFormat.format(pass.expectedReturnTime)}",
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimaryOf(context),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Text(
            pass.reason,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 13.5,
              color: AppColors.textPrimaryOf(context).withValues(alpha: 0.88),
              height: 1.45,
            ),
          ),
          const SizedBox(height: 12),
          Divider(
            height: 1,
            color: AppColors.borderOf(context).withValues(alpha: 0.6),
            thickness: 0.5,
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.surfaceAltOf(context),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  "Pass #${pass.id.substring(0, 8)}",
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondaryOf(context),
                  ),
                ),
              ),
              if (pass.isActive)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.emerald.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: AppColors.emerald.withValues(alpha: 0.3),
                      width: 0.5,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.shield_rounded, size: 12, color: AppColors.emerald),
                      const SizedBox(width: 4),
                      Text(
                        "Active in Passport",
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: AppColors.emerald,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildComplaintsSection() {
    if (_isLoadingComplaints && _complaints.isEmpty) {
      return const Center(child: CircularProgressIndicator(color: AppColors.primary));
    }

    if (_complaintError != null && _complaints.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline_rounded, size: 48, color: AppColors.danger),
              const SizedBox(height: 16),
              Text(
                "Unable to load complaints",
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _complaintError!,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: _loadAll,
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text("Retry"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_complaints.isEmpty) {
      return _buildEmptyState(
        icon: Icons.check_circle_outline_rounded,
        headline: "Nothing reported yet",
        explanation: "Report a campus issue and track its resolution here.",
        primaryActionLabel: "Report an Issue",
        onPrimaryAction: _showComplaintForm,
      );
    }

    return RefreshIndicator(
      onRefresh: _loadAll,
      color: AppColors.primary,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
        physics: AppleSpringScrollPhysics.always,
        itemCount: _complaints.length + 1,
        separatorBuilder: (_, __) => const SizedBox(height: 14),
        itemBuilder: (context, index) {
          if (index == 0) {
            final pendingCount = _complaints.where((c) => c.isSyncPending).length;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (pendingCount > 0)
                  Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF59E0B).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.4)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.cloud_queue_rounded, size: 16, color: Color(0xFFD97706)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            "$pendingCount issue${pendingCount > 1 ? 's' : ''} saved locally (pending sync)",
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFFD97706),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      "Issues Reported (${_complaints.length})",
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textSecondary,
                        letterSpacing: 0.5,
                      ),
                    ),
                    TextButton.icon(
                      onPressed: _showComplaintForm,
                      icon: const Icon(Icons.add_rounded, size: 18),
                      label: const Text("New Issue"),
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.primary,
                        textStyle: GoogleFonts.plusJakartaSans(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            );
          }
          final c = _complaints[index - 1];
          return _buildComplaintCard(c);
        },
      ),
    );
  }

  Widget _buildComplaintCard(ComplaintModel c) {
    Color statusColor;
    Color statusBg;
    if (c.isResolved) {
      statusColor = AppColors.emerald;
      statusBg = AppColors.emerald.withValues(alpha: 0.12);
    } else if (c.isClosed) {
      statusColor = AppColors.textSecondaryOf(context);
      statusBg = AppColors.borderOf(context).withValues(alpha: 0.5);
    } else if (c.isInProgress) {
      statusColor = AppColors.primary;
      statusBg = AppColors.primary.withValues(alpha: 0.12);
    } else if (c.isAssigned) {
      statusColor = Colors.teal;
      statusBg = Colors.teal.withValues(alpha: 0.12);
    } else if (c.isReopened) {
      statusColor = Colors.deepOrange;
      statusBg = Colors.deepOrange.withValues(alpha: 0.12);
    } else if (c.isRejected) {
      statusColor = AppColors.danger;
      statusBg = AppColors.danger.withValues(alpha: 0.12);
    } else {
      statusColor = AppColors.warning;
      statusBg = AppColors.warning.withValues(alpha: 0.14);
    }

    Color priorityColor;
    if (c.priority == 'URGENT') {
      priorityColor = AppColors.danger;
    } else if (c.priority == 'HIGH') {
      priorityColor = Colors.deepOrange;
    } else if (c.priority == 'MEDIUM') {
      priorityColor = AppColors.primary;
    } else {
      priorityColor = AppColors.textSecondaryOf(context);
    }

    final dateFormat = DateFormat('MMM dd, yyyy');

    return AppleBounceable(
      scaleFactor: 0.98,
      onTap: () {
        AppHaptics.lightImpact();
        _showComplaintDetails(c);
      },
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surfaceOf(context),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: AppColors.borderOf(context).withValues(alpha: 0.7),
            width: 0.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 12,
              offset: const Offset(0, 4),
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
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        c.category,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: priorityColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        c.priority,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: priorityColor,
                        ),
                      ),
                    ),
                  ],
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (c.isSyncPending) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        margin: const EdgeInsets.only(right: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF59E0B).withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: const Color(0xFFF59E0B).withValues(alpha: 0.4),
                            width: 0.5,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.cloud_upload_outlined, size: 11, color: Color(0xFFD97706)),
                            const SizedBox(width: 4),
                            Text(
                              "Saved locally",
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: const Color(0xFFD97706),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ] else if (c.isSyncFailed) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        margin: const EdgeInsets.only(right: 6),
                        decoration: BoxDecoration(
                          color: AppColors.danger.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: AppColors.danger.withValues(alpha: 0.4),
                            width: 0.5,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.cloud_off_rounded, size: 11, color: AppColors.danger),
                            const SizedBox(width: 4),
                            Text(
                              "Sync failed",
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
                    if (c.closureOtp != null && !c.isResolved && !c.isClosed) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        margin: const EdgeInsets.only(right: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFF2563EB).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: const Color(0xFF2563EB).withValues(alpha: 0.3),
                            width: 0.5,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.shield_rounded, size: 12, color: Color(0xFF2563EB)),
                            const SizedBox(width: 4),
                            Text(
                              "PIN: ${c.closureOtp}",
                              style: GoogleFonts.jetBrainsMono(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 1.2,
                                color: const Color(0xFF1E40AF),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                      decoration: BoxDecoration(
                        color: statusBg,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        c.status,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          color: statusColor,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              c.title,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimaryOf(context),
              ),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(Icons.location_on_outlined, size: 13, color: AppColors.primary),
                const SizedBox(width: 4),
                Text(
                  c.location,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textSecondaryOf(context),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              c.description,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 13,
                color: AppColors.textPrimaryOf(context).withValues(alpha: 0.82),
                height: 1.45,
              ),
            ),
            if (c.resolutionRemarks != null && c.resolutionRemarks!.isNotEmpty) ...[
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.emerald.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: AppColors.emerald.withValues(alpha: 0.2),
                    width: 0.5,
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle_outline_rounded, size: 14, color: AppColors.emerald),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        "Resolution: ${c.resolutionRemarks}",
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12,
                          color: AppColors.emerald,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 12),
            Divider(
              height: 1,
              color: AppColors.borderOf(context).withValues(alpha: 0.6),
              thickness: 0.5,
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "Reported ${dateFormat.format(c.createdAt)}",
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 11,
                    color: AppColors.textSecondaryOf(context),
                  ),
                ),
                Row(
                  children: [
                    Text(
                      "Details & Timeline",
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(width: 2),
                    const Icon(Icons.chevron_right_rounded, size: 16, color: AppColors.primary),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }


  Widget _buildNoticesSection() {
    if (_isLoadingNotices && _notices.isEmpty) {
      return _buildNoticeSkeleton();
    }

    if (_noticeError != null && _notices.isEmpty) {
      return _buildEmptyState(
        icon: Icons.cloud_off_rounded,
        headline: "Could not load notices",
        explanation: _noticeError!,
        primaryActionLabel: "Try Again",
        onPrimaryAction: _loadNotices,
      );
    }

    if (_notices.isEmpty) {
      return _buildEmptyState(
        icon: Icons.notifications_none_rounded,
        headline: "No new notices",
        explanation: "Official announcements from campus administration will appear here.",
        primaryActionLabel: "Refresh Feed",
        onPrimaryAction: _loadNotices,
      );
    }

    return RefreshIndicator(
      onRefresh: _loadNotices,
      color: AppColors.primary,
      backgroundColor: AppColors.surface,
      child: ListView.builder(
        physics: AppleSpringScrollPhysics.always,
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
        itemCount: _notices.length + 1,
        itemBuilder: (context, index) {
          if (index == 0) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    "Announcements (${_notices.length})",
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textSecondary,
                      letterSpacing: 0.5,
                    ),
                  ),
                  if (_unreadNoticesCount > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        "$_unreadNoticesCount unread",
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                ],
              ),
            );
          }
          final notice = _notices[index - 1];
          return NoticeCard(
            notice: notice,
            onTap: () {
              if (!notice.isRead) {
                final studentId =
                    Provider.of<UserProvider>(context, listen: false).user?.id;
                if (studentId != null) {
                  _noticeService.markNoticeRead(notice.id,
                      requesterId: studentId);
                }
                if (mounted) {
                  setState(() {
                    final idx = _notices.indexWhere((n) => n.id == notice.id);
                    if (idx != -1) {
                      _notices[idx] = _notices[idx]
                          .copyWith(isRead: true, readAt: DateTime.now());
                    }
                  });
                }
              }
            },
          );
        },
      ),
    );
  }

  Widget _buildNoticeSkeleton() {
    return ListView.builder(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
      itemCount: 4,
      itemBuilder: (context, index) {
        return Container(
          margin: const EdgeInsets.only(bottom: 14),
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.border.withValues(alpha: 0.6)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 70,
                    height: 22,
                    decoration: BoxDecoration(
                      color: AppColors.bg,
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                  const Spacer(),
                  Container(
                    width: 50,
                    height: 16,
                    decoration: BoxDecoration(
                      color: AppColors.bg,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                height: 18,
                decoration: BoxDecoration(
                  color: AppColors.bg,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(height: 8),
              Container(
                width: 200,
                height: 14,
                decoration: BoxDecoration(
                  color: AppColors.bg,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildEmptyState({
    required IconData icon,
    required String headline,
    required String explanation,
    String? primaryActionLabel,
    VoidCallback? onPrimaryAction,
    String? secondaryActionLabel,
    VoidCallback? onSecondaryAction,
  }) {
    return SingleChildScrollView(
      physics: AppleSpringScrollPhysics.always,
      padding: const EdgeInsets.symmetric(horizontal: 28.0, vertical: 40.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(height: 24),
          Container(
            width: 88,
            height: 88,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              shape: BoxShape.circle,
              border: Border.all(
                color: AppColors.primary.withValues(alpha: 0.2),
                width: 1,
              ),
            ),
            child: Center(
              child: Icon(
                icon,
                size: 42,
                color: AppColors.primary,
              ),
            ),
          ).animate().scale(duration: 400.ms, curve: AppleSpringCurve.bouncy),
          const SizedBox(height: 24),
          Text(
            headline,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimaryOf(context),
              letterSpacing: -0.4,
            ),
            textAlign: TextAlign.center,
          ).animate().fadeIn(delay: 100.ms).slideY(begin: 0.1),
          const SizedBox(height: 10),
          Text(
            explanation,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 14,
              color: AppColors.textSecondaryOf(context),
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ).animate().fadeIn(delay: 180.ms).slideY(begin: 0.1),
          const SizedBox(height: 36),
          if (primaryActionLabel != null && onPrimaryAction != null)
            AppleBounceable(
              scaleFactor: 0.96,
              onTap: () {
                AppHaptics.lightImpact();
                onPrimaryAction();
              },
              child: Container(
                width: double.infinity,
                height: 52,
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.25),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Center(
                  child: Text(
                    primaryActionLabel,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                      letterSpacing: -0.2,
                    ),
                  ),
                ),
              ),
            ).animate().fadeIn(delay: 260.ms).slideY(begin: 0.1),
          if (secondaryActionLabel != null && onSecondaryAction != null) ...[
            const SizedBox(height: 12),
            AppleBounceable(
              scaleFactor: 0.96,
              onTap: () {
                AppHaptics.selectionClick();
                onSecondaryAction();
              },
              child: Container(
                width: double.infinity,
                height: 50,
                decoration: BoxDecoration(
                  color: AppColors.surfaceAltOf(context),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: AppColors.borderOf(context).withValues(alpha: 0.7),
                    width: 0.5,
                  ),
                ),
                child: Center(
                  child: Text(
                    secondaryActionLabel,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary,
                      letterSpacing: -0.2,
                    ),
                  ),
                ),
              ),
            ).animate().fadeIn(delay: 320.ms).slideY(begin: 0.1),
          ],
        ],
      ),
    );
  }
}
