import 'package:flutter/material.dart';
import 'package:attendance_app/core/haptics/app_haptics.dart';

import 'package:google_fonts/google_fonts.dart';

import '../../auth/models/user_model.dart';
import '../../core/theme/app_colors.dart';
import '../../router/app_routes.dart';
import '../../shared/models/session_model.dart';
import '../../shared/services/session_service.dart';
import '../../student/services/notice_service.dart';
import '../../student/services/mess_service.dart';
import '../../student/models/notice_model.dart';
import '../../student/models/mess_model.dart';
import '../models/admin_dashboard_models.dart';
import '../services/admin_dashboard_service.dart';
import 'admin_complaints_screen.dart';
import '../widgets/admin_document_review_sheet.dart';
import '../../core/services/expansion_api_service.dart';

/// CampusOS Admin Operations Hub.
///
/// Features clean, restrained Apple-grade operation cards:
/// - Complaints (pending, ageing, open queue)
/// - Notices (active announcements, global broadcast composer)
/// - Mess (daily menus, student feedback analytics)
/// - Attendance (live classroom sessions oversight)
/// - Security & Gate (gate pass activity & status)
/// - Passport Verification (cryptographic terminal launchpad)
class AdminOperationsScreen extends StatefulWidget {
  final UserModel? user;

  const AdminOperationsScreen({Key? key, this.user}) : super(key: key);

  @override
  State<AdminOperationsScreen> createState() => _AdminOperationsScreenState();
}

class _AdminOperationsScreenState extends State<AdminOperationsScreen> {
  final AdminDashboardService _dashboardService = AdminDashboardService();
  final NoticeService _noticeService = NoticeService();
  final MessService _messService = MessService();
  final SessionService _sessionService = SessionService();

  bool _isLoading = true;

  AdminDashboardSummaryModel? _summary;
  int _activeNoticeCount = 0;
  int _activeSessionCount = 0;
  List<SessionModel> _activeSessions = [];
  String? _todayMealSummary;

  @override
  void initState() {
    super.initState();
    _loadOperationsData();
  }

  Future<void> _loadOperationsData() async {
    setState(() => _isLoading = true);

    try {
      final reqId = widget.user?.id;

      // 1. Dashboard summary
      final summaryFuture = _dashboardService.getDashboardSummary(requesterId: reqId)
          .catchError((_) => AdminDashboardSummaryModel(
                totalComplaints: 0,
                pendingComplaints: 0,
                assignedComplaints: 0,
                inProgressComplaints: 0,
                resolvedComplaints: 0,
                closedComplaints: 0,
                reopenedComplaints: 0,
                rejectedComplaints: 0,
                ageingComplaints: 0,
                averageResolutionHours: 0,
              ));

      // 2. Active notices
      final noticesFuture = _noticeService.getNotices(requesterId: reqId)
          .catchError((_) => <NoticeModel>[]);

      // 3. Active sessions
      final sessionsFuture = _sessionService.getActiveSessions()
          .catchError((_) => <SessionModel>[]);

      // 4. Mess menu
      final messFuture = _messService.getTodayMenu(requesterId: reqId)
          .catchError((_) => null);

      final results = await Future.wait([
        summaryFuture,
        noticesFuture,
        sessionsFuture,
        messFuture,
      ]);

      if (mounted) {
        final noticeList = results[1] as List<NoticeModel>;
        final sessionsList = results[2] as List<SessionModel>;
        final dailyMenu = results[3] as MessMenu?;

        String mealText = "Today's menu active";
        if (dailyMenu != null && dailyMenu.meals.isNotEmpty) {
          mealText = "${dailyMenu.meals.length} meals configured";
        }

        setState(() {
          _summary = results[0] as AdminDashboardSummaryModel;
          _activeNoticeCount = noticeList.length;
          _activeSessions = sessionsList;
          _activeSessionCount = sessionsList.length;
          _todayMealSummary = mealText;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showActiveSessionsModal() {
    AppHaptics.selectionClick();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Active Class Sessions',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded,
                          color: AppColors.textSecondary, size: 20),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (_activeSessions.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 24),
                    child: Center(
                      child: Text(
                        'No classroom attendance sessions currently broadcasting.',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 13,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                  )
                else
                  Flexible(
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: _activeSessions.length,
                      separatorBuilder: (_, __) =>
                          const Divider(height: 1, color: AppColors.border),
                      itemBuilder: (c, i) {
                        final s = _activeSessions[i];
                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(
                            s.name,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          subtitle: Text(
                            "${s.course ?? 'Academic'} · ${s.instructorName}",
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          trailing: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: AppColors.success.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              'BROADCASTING',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: AppColors.success,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final pendingComplaints = _summary?.pendingComplaints ?? 0;
    final inProgressComplaints = _summary?.inProgressComplaints ?? 0;
    final ageingComplaints = _summary?.ageingComplaints ?? 0;

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          onRefresh: _loadOperationsData,
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
                  'Operations',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                    letterSpacing: -0.5,
                  ),
                ),
                Text(
                  'Campus services management & active oversight',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 20),

                if (_isLoading)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 60),
                    child: Center(
                      child: CircularProgressIndicator(
                        color: AppColors.primary,
                        strokeWidth: 2.5,
                      ),
                    ),
                  )
                else ...[
                  // 1. Complaints Operations Card
                  _buildOperationCard(
                  icon: Icons.assignment_outlined,
                  iconColor: const Color(0xFFF59E0B),
                  title: 'Complaints',
                  statusBadge: '$pendingComplaints pending',
                  statusBadgeColor: pendingComplaints > 0
                      ? const Color(0xFFF59E0B)
                      : AppColors.success,
                  details: [
                    '$inProgressComplaints in progress',
                    '$ageingComplaints ageing >48h',
                  ],
                  primaryActionText: 'Open Queue',
                  onPrimaryAction: () {
                    AppHaptics.selectionClick();
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => AdminComplaintsScreen(user: widget.user),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 12),

                // 2. Notices Management Card
                _buildOperationCard(
                  icon: Icons.campaign_outlined,
                  iconColor: AppColors.primary,
                  title: 'Notices',
                  statusBadge: '$_activeNoticeCount active',
                  statusBadgeColor: AppColors.primary,
                  details: [
                    'Global institution targeting',
                    'FCM push notification support',
                  ],
                  primaryActionText: 'Manage Notices',
                  onPrimaryAction: () {
                    AppHaptics.selectionClick();
                    Navigator.pushNamed(
                      context,
                      AppRoutes.noticeManagement,
                      arguments: widget.user,
                    );
                  },
                ),
                const SizedBox(height: 12),

                // 3. Mess Management Card
                _buildOperationCard(
                  icon: Icons.restaurant_outlined,
                  iconColor: const Color(0xFF10B981),
                  title: 'Mess Operations',
                  statusBadge: _todayMealSummary ?? "Active",
                  statusBadgeColor: const Color(0xFF10B981),
                  details: [
                    'Weekly menu publication',
                    'Student meal feedback analytics',
                  ],
                  primaryActionText: 'Manage Menus',
                  onPrimaryAction: () {
                    AppHaptics.selectionClick();
                    Navigator.pushNamed(
                      context,
                      AppRoutes.messManagement,
                      arguments: widget.user,
                    );
                  },
                ),
                const SizedBox(height: 12),

                // 4. Attendance Oversight Card
                _buildOperationCard(
                  icon: Icons.how_to_reg_outlined,
                  iconColor: const Color(0xFF007AFF),
                  title: 'Attendance Oversight',
                  statusBadge: '$_activeSessionCount broadcasting',
                  statusBadgeColor: _activeSessionCount > 0
                      ? AppColors.success
                      : AppColors.textSecondary,
                  details: [
                    '1I Batch BLE & QR live sessions',
                    'Teacher roster broadcast status',
                  ],
                  primaryActionText: 'View Active Sessions',
                  onPrimaryAction: _showActiveSessionsModal,
                ),
                const SizedBox(height: 12),

                // 5. Gate & Security Card
                _buildOperationCard(
                  icon: Icons.security_rounded,
                  iconColor: const Color(0xFF64748B),
                  title: 'Gate & Security Oversight',
                  statusBadge: 'Terminal Ready',
                  statusBadgeColor: AppColors.success,
                  details: [
                    'Gate pass ledger monitoring',
                    'Digital student verification',
                  ],
                  primaryActionText: 'Security Status',
                  onPrimaryAction: () {
                    AppHaptics.lightImpact();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          'Gate pass and security guard role integration is operational.',
                          style: GoogleFonts.plusJakartaSans(fontSize: 13),
                        ),
                        duration: const Duration(seconds: 2),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 12),

                // 6. Passport Verification Terminal Card
                _buildOperationCard(
                  icon: Icons.qr_code_scanner_rounded,
                  iconColor: const Color(0xFF8B5CF6),
                  title: 'Passport Verification',
                  statusBadge: '1I Engine Online',
                  statusBadgeColor: const Color(0xFF8B5CF6),
                  details: [
                    'Offline & online cryptographic verification',
                    'Ed25519 signature validation',
                  ],
                  primaryActionText: 'Open Verifier',
                  onPrimaryAction: () {
                    AppHaptics.selectionClick();
                    Navigator.pushNamed(
                      context,
                      AppRoutes.passportVerify,
                      arguments: widget.user,
                    );
                  },
                ),
                const SizedBox(height: 12),

                // 7. Documents & Attestations
                _buildOperationCard(
                  icon: Icons.verified_user_rounded,
                  iconColor: const Color(0xFF4338CA),
                  title: 'Attested Documents',
                  statusBadge: 'Registrar Ready',
                  statusBadgeColor: const Color(0xFF4338CA),
                  details: [
                    'Digital sealing of Bonafide & NOCs',
                    'Attestation export to student wallets',
                  ],
                  primaryActionText: 'Review Requests',
                  onPrimaryAction: () {
                    AppHaptics.selectionClick();
                    AdminDocumentReviewSheet.show(
                      context,
                      adminId: widget.user?.id ?? '',
                    );
                  },
                ),
                const SizedBox(height: 12),

                // 8. Institutional Fees & Dues
                _buildOperationCard(
                  icon: Icons.account_balance_rounded,
                  iconColor: const Color(0xFF0D9488),
                  title: 'Institutional Fees & Dues',
                  statusBadge: 'Billing Active',
                  statusBadgeColor: const Color(0xFF0D9488),
                  details: [
                    'Tuition & hostel dues overview',
                    'Digital receipt generation & ledger',
                  ],
                  primaryActionText: 'Fees Overview',
                  onPrimaryAction: () async {
                    AppHaptics.lightImpact();
                    try {
                      final overview = await ExpansionApiService.instance.getAdminFeesOverview();
                      if (context.mounted) {
                        showDialog(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            backgroundColor: AppColors.surface,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            title: Text(
                              'Fees & Dues KPI',
                              style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold),
                            ),
                            content: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text("Total Dues: ₹${overview['totalDues'] ?? 0}"),
                                const SizedBox(height: 4),
                                Text("Total Collected: ₹${overview['totalPaid'] ?? 0}"),
                                const SizedBox(height: 4),
                                Text("Outstanding: ₹${overview['outstandingBalance'] ?? 0}"),
                                const SizedBox(height: 4),
                                Text("Overdue Accounts: ${overview['overdueCount'] ?? 0}"),
                              ],
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(ctx),
                                child: const Text("Close"),
                              ),
                            ],
                          ),
                        );
                      }
                    } catch (_) {}
                  },
                ),
                const SizedBox(height: 12),

                // 9. Academic Updates & Schedule
                _buildOperationCard(
                  icon: Icons.edit_calendar_rounded,
                  iconColor: const Color(0xFFD97706),
                  title: 'Academic Updates',
                  statusBadge: 'Live Feeds',
                  statusBadgeColor: const Color(0xFFD97706),
                  details: [
                    'Teacher class cancellations & swaps',
                    'Real-time student notice distribution',
                  ],
                  primaryActionText: 'Schedule Status',
                  onPrimaryAction: () async {
                    AppHaptics.lightImpact();
                    try {
                      final summary = await ExpansionApiService.instance.getTodayUpdatesSummary();
                      if (context.mounted) {
                        showDialog(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            backgroundColor: AppColors.surface,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            title: Text(
                              "Today's Academic Status",
                              style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold),
                            ),
                            content: Text(
                              "Total updates today: ${summary['todayTotal']}\nCancellations: ${summary['cancellationsCount']}\nRescheduled classes: ${summary['rescheduledCount']}",
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(ctx),
                                child: const Text("Close"),
                              ),
                            ],
                          ),
                        );
                      }
                    } catch (_) {}
                  },
                ),
                const SizedBox(height: 12),

                // 10. Hostel & Assets
                _buildOperationCard(
                  icon: Icons.hotel_rounded,
                  iconColor: const Color(0xFF2563EB),
                  title: 'Hostel & Assets Oversight',
                  statusBadge: 'Inventory Active',
                  statusBadgeColor: const Color(0xFF2563EB),
                  details: [
                    'Room allocation & resident registry',
                    'Room change requests & asset triage',
                  ],
                  primaryActionText: 'Hostel Overview',
                  onPrimaryAction: () async {
                    AppHaptics.lightImpact();
                    try {
                      final overview = await ExpansionApiService.instance.getHostelOverview();
                      if (context.mounted) {
                        showDialog(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            backgroundColor: AppColors.surface,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            title: Text(
                              "Hostel Operations KPI",
                              style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold),
                            ),
                            content: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text("Occupied Beds: ${overview['occupiedBeds'] ?? 0}"),
                                const SizedBox(height: 4),
                                Text("Pending Room Requests: ${overview['pendingRequests'] ?? 0}"),
                                const SizedBox(height: 4),
                                Text("Pending Asset Issues: ${overview['pendingAssetIssues'] ?? 0}"),
                              ],
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(ctx),
                                child: const Text("Close"),
                              ),
                            ],
                          ),
                        );
                      }
                    } catch (_) {}
                  },
                ),
              ],
            ],
          ),
          ),
        ),
      ),
    );
  }

  Widget _buildOperationCard({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String statusBadge,
    required Color statusBadgeColor,
    required List<String> details,
    required String primaryActionText,
    required VoidCallback onPrimaryAction,
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
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Icon + Title + Status Badge
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 20, color: iconColor),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: statusBadgeColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  statusBadge,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: statusBadgeColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Details bullet points
          ...details.map((d) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  children: [
                    Container(
                      width: 4,
                      height: 4,
                      decoration: const BoxDecoration(
                        color: AppColors.textSecondary,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        d,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
              )),
          const SizedBox(height: 14),

          // Action Button
          SizedBox(
            width: double.infinity,
            height: 38,
            child: ElevatedButton(
              onPressed: onPrimaryAction,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.bg,
                foregroundColor: AppColors.textPrimary,
                elevation: 0,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                  side: const BorderSide(color: AppColors.border),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: Text(
                      primaryActionText,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 6),
                  const Icon(Icons.arrow_forward_ios_rounded,
                      size: 12, color: AppColors.textSecondary),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
