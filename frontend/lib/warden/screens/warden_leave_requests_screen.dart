import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../auth/models/user_model.dart';
import '../../core/theme/app_colors.dart';
import '../models/warden_models.dart';
import '../services/warden_service.dart';
import '../widgets/warden_request_card.dart';
import 'warden_leave_detail_screen.dart';
import '../widgets/warden_hostel_triage_sheet.dart';
import '../../core/localization/app_localizations.dart';

class WardenLeaveRequestsScreen extends StatefulWidget {
  final UserModel user;

  const WardenLeaveRequestsScreen({Key? key, required this.user}) : super(key: key);

  @override
  State<WardenLeaveRequestsScreen> createState() => _WardenLeaveRequestsScreenState();
}

class _WardenLeaveRequestsScreenState extends State<WardenLeaveRequestsScreen>
    with SingleTickerProviderStateMixin {
  final WardenService _wardenService = WardenService();
  late TabController _tabController;

  final TextEditingController _searchController = TextEditingController();
  List<WardenLeaveRequestModel> _allRequests = [];
  bool _isLoading = true;
  String _selectedStatus = 'ALL';

  final List<String> _tabs = ['ALL', 'PENDING', 'APPROVED', 'REJECTED'];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs.length, vsync: this);
    _tabController.addListener(() {
      if (_tabController.indexIsChanging) return;
      setState(() {
        _selectedStatus = _tabs[_tabController.index];
      });
      _loadRequests();
    });
    _loadRequests();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadRequests() async {
    setState(() => _isLoading = true);
    final list = await _wardenService.fetchLeaveRequests(
      status: _selectedStatus == 'ALL' ? null : _selectedStatus,
      search: _searchController.text.trim(),
      wardenId: widget.user.id,
    );
    if (mounted) {
      setState(() {
        _allRequests = list;
        _isLoading = false;
      });
    }
  }

  Future<void> _handleQuickAction(WardenLeaveRequestModel req, String action) async {
    final res = await _wardenService.processAction(
      req.id,
      action: action,
      remarks: action == 'APPROVE' ? 'Approved by Warden' : 'Rejected by Warden',
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
      _loadRequests();
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
        title: Text(
          'Leave Requests Management'.tr(context),
          style: GoogleFonts.plusJakartaSans(
            fontWeight: FontWeight.bold,
            fontSize: 17,
            color: AppColors.textPrimary,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.badge_rounded, color: Color(0xFFD97706)),
            tooltip: 'Visitor Passes & Hostel Triage',
            onPressed: () {
              WardenHostelTriageSheet.show(context, wardenId: widget.user.id);
            },
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: AppColors.textSecondary),
            onPressed: _loadRequests,
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(104),
          child: Column(
            children: [
              // Search Input Field
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: TextField(
                  controller: _searchController,
                  onSubmitted: (_) => _loadRequests(),
                  decoration: InputDecoration(
                    hintText: 'Search by student, reg no, or destination...'.tr(context),
                    hintStyle: GoogleFonts.plusJakartaSans(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                    ),
                    prefixIcon: const Icon(Icons.search_rounded, size: 20, color: AppColors.textSecondary),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear_rounded, size: 18),
                            onPressed: () {
                              _searchController.clear();
                              _loadRequests();
                            },
                          )
                        : null,
                    filled: true,
                    fillColor: AppColors.bg,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: AppColors.border),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: AppColors.border),
                    ),
                  ),
                ),
              ),
              // Filter Tabs
              TabBar(
                controller: _tabController,
                isScrollable: false,
                indicatorColor: AppColors.primary,
                indicatorWeight: 3,
                labelColor: AppColors.primary,
                unselectedLabelColor: AppColors.textSecondary,
                labelStyle: GoogleFonts.plusJakartaSans(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
                unselectedLabelStyle: GoogleFonts.plusJakartaSans(
                  fontWeight: FontWeight.w500,
                  fontSize: 13,
                ),
                tabs: [
                  Tab(text: 'All'.tr(context)),
                  Tab(text: 'Pending'.tr(context)),
                  Tab(text: 'Approved'.tr(context)),
                  Tab(text: 'Rejected'.tr(context)),
                ],
              ),
            ],
          ),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _loadRequests,
        color: AppColors.primary,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _allRequests.isEmpty
                ? ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(32),
                    children: [
                      const SizedBox(height: 60),
                      Center(
                        child: Container(
                          padding: const EdgeInsets.all(20),
                          decoration: const BoxDecoration(
                            color: AppColors.surface,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.inbox_rounded,
                            size: 48,
                            color: AppColors.textSecondary.withValues(alpha: 0.5),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Center(
                        child: Text(
                          _selectedStatus == 'ALL'
                              ? 'No Leave Requests Found'
                              : 'No $_selectedStatus Requests',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Center(
                        child: Text(
                          'Try clearing search filters or check back later.',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 13,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                    ],
                  )
                : ListView.builder(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(16),
                    itemCount: _allRequests.length + 1,
                    itemBuilder: (context, index) {
                      if (index == _allRequests.length) {
                        return const SizedBox(height: 80);
                      }
                      final req = _allRequests[index];
                      return WardenRequestCard(
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
                          ).then((_) => _loadRequests());
                        },
                        onAction: (action) => _handleQuickAction(req, action),
                      );
                    },
                  ),
      ),
    );
  }
}
