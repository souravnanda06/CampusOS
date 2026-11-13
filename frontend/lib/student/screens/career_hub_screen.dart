import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/theme/app_colors.dart';
import '../../core/haptics/app_haptics.dart';
import '../../shared/widgets/motion/apple_bounceable.dart';
import '../../shared/widgets/motion/apple_spring_scroll_physics.dart';
import '../../core/performance/rendering/adaptive_blur_surface.dart';
import '../models/career_models.dart';
import '../services/career_service.dart';
import 'smart_profile_screen.dart';

class CareerHubScreen extends StatefulWidget {
  final int initialTabIndex;

  const CareerHubScreen({
    Key? key,
    this.initialTabIndex = 0,
  }) : super(key: key);

  @override
  State<CareerHubScreen> createState() => _CareerHubScreenState();
}

class _CareerHubScreenState extends State<CareerHubScreen> with SingleTickerProviderStateMixin {
  late int _selectedTab;
  bool _isLoading = true;

  // Opportunities State
  int _opportunitiesSubTab = 0; // 0: On-Campus Drives, 1: Off-Campus API Jobs
  String? _searchQuery;
  String _selectedEmploymentFilter = 'ALL';
  String _selectedWorkModeFilter = 'ALL';

  List<PlacementDriveModel> _drives = [];
  List<OpportunityListingModel> _opportunities = [];
  StudentCareerProfileModel? _profile;
  List<PlacementApplicationModel> _applications = [];
  List<CareerResourceModel> _resources = [];
  List<TechNewsModel> _news = [];

  // ATS State
  bool _isAnalyzingResume = false;
  Map<String, dynamic>? _latestAtsAnalysis;

  // Copilot State
  final _copilotInputController = TextEditingController();
  bool _isCopilotThinking = false;
  final List<Map<String, String>> _copilotChatMessages = [
    {
      'sender': 'copilot',
      'text':
          'Hello! I am your CampusOS Career Copilot. Ask me about on-campus drive preparation, resume bullet optimization (X-Y-Z method), or technical mock interview questions.'
    }
  ];

  @override
  void initState() {
    super.initState();
    _selectedTab = widget.initialTabIndex;
    _loadAllData();
  }

  @override
  void dispose() {
    _copilotInputController.dispose();
    super.dispose();
  }

  Future<void> _loadAllData() async {
    setState(() => _isLoading = true);
    try {
      final futures = await Future.wait([
        CareerService.instance.getDrives(),
        CareerService.instance.getOpportunities(
          employmentType: _selectedEmploymentFilter,
          workMode: _selectedWorkModeFilter,
          query: _searchQuery,
        ),
        CareerService.instance.getCareerProfile(),
        CareerService.instance.getApplications(),
        CareerService.instance.getResources(),
        CareerService.instance.getTechNews(),
      ]);

      if (mounted) {
        setState(() {
          _drives = futures[0] as List<PlacementDriveModel>;
          _opportunities = futures[1] as List<OpportunityListingModel>;
          _profile = futures[2] as StudentCareerProfileModel?;
          _applications = futures[3] as List<PlacementApplicationModel>;
          _resources = futures[4] as List<CareerResourceModel>;
          _news = futures[5] as List<TechNewsModel>;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _launchExternalUrl(String url) async {
    AppHaptics.selectionClick();
    final uri = Uri.tryParse(url);
    if (uri != null) {
      try {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } catch (e) {
        debugPrint("Could not launch $url: $e");
      }
    }
  }

  Future<void> _handleApplyToDrive(PlacementDriveModel drive) async {
    AppHaptics.mediumImpact();
    if (!drive.isEligible) {
      _showEligibilityAlert(drive);
      return;
    }

    final res = await CareerService.instance.applyToDrive(drive.id);
    if (!mounted) return;

    if (res['success'] == true) {
      AppHaptics.heavyImpact();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Registered for ${drive.companyName}! Application added to tracker."),
          backgroundColor: const Color(0xFF10B981),
          behavior: SnackBarBehavior.floating,
        ),
      );
      _loadAllData();
    } else {
      AppHaptics.mediumImpact();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(res['message']?.toString() ?? "Failed to apply"),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _handleRunAtsAnalysis() async {
    AppHaptics.mediumImpact();
    setState(() => _isAnalyzingResume = true);

    final res = await CareerService.instance.analyzeResume(
      targetRole: _profile?.targetRole ?? 'Software Engineer',
      filename: 'CampusOS_Profile_Resume.pdf',
    );

    if (!mounted) return;
    setState(() {
      _isAnalyzingResume = false;
      if (res != null && res['atsAnalysis'] != null) {
        _latestAtsAnalysis = res['atsAnalysis'] as Map<String, dynamic>;
      }
    });

    if (res != null) {
      AppHaptics.heavyImpact();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("AI ATS Resume Scan Complete!"),
          backgroundColor: Color(0xFF4F46E5),
          behavior: SnackBarBehavior.floating,
        ),
      );
      _loadAllData();
    }
  }

  Future<void> _sendCopilotMessage(String text) async {
    final query = text.trim();
    if (query.isEmpty) return;

    _copilotInputController.clear();
    AppHaptics.selectionClick();

    setState(() {
      _copilotChatMessages.add({'sender': 'user', 'text': query});
      _isCopilotThinking = true;
    });

    final reply = await CareerService.instance.askCareerCopilot(
      query,
      history: _copilotChatMessages,
    );

    if (!mounted) return;
    setState(() {
      _isCopilotThinking = false;
      _copilotChatMessages.add({'sender': 'copilot', 'text': reply});
    });
    AppHaptics.lightImpact();
  }

  void _showEligibilityAlert(PlacementDriveModel drive) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: const [
            Icon(Icons.shield_outlined, color: Colors.amber, size: 24),
            SizedBox(width: 8),
            Text("Eligibility Criteria"),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Institutional recruitment criteria for ${drive.companyName}:",
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            ...drive.ineligibilityReasons.map(
              (r) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.close_rounded, color: Colors.redAccent, size: 16),
                    const SizedBox(width: 6),
                    Expanded(child: Text(r, style: const TextStyle(fontSize: 13))),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              "Tip: Check your academic attendance and backlogs before drive registration closes.",
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Understood"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bg = AppColors.bgOf(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        title: Text(
          "Career & Placements",
          style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, fontSize: 19),
        ),
        elevation: 0,
        backgroundColor: bg,
        actions: [
          // Edit Smart Profile direct shortcut
          IconButton(
            icon: const Icon(Icons.person_pin_circle_outlined),
            tooltip: "Smart Profile",
            onPressed: () {
              AppHaptics.selectionClick();
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const SmartProfileScreen()),
              ).then((_) => _loadAllData());
            },
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: "Refresh Data",
            onPressed: () {
              AppHaptics.selectionClick();
              _loadAllData();
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Liquid Glass Top Segmented Control (5 Hub Sections)
          _buildLiquidGlassTabSelector(isDark),

          // Content area with fast virtualized IndexedStack
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : RefreshIndicator(
                    onRefresh: _loadAllData,
                    child: IndexedStack(
                      index: _selectedTab,
                      children: [
                        _buildOpportunitiesView(isDark),
                        _buildApplicationPipelineView(isDark),
                        _buildResumeAndAtsStudioView(isDark),
                        _buildCareerCopilotView(isDark),
                        _buildGrowthAndNewsView(isDark),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  // =========================================================================
  // TOP FLOATING GLASS SEGMENTED SELECTOR
  // =========================================================================
  Widget _buildLiquidGlassTabSelector(bool isDark) {
    final tabs = [
      {"title": "Drives & Jobs", "icon": Icons.business_center_outlined},
      {"title": "Pipeline", "icon": Icons.timeline_rounded},
      {"title": "Resume & ATS", "icon": Icons.description_outlined},
      {"title": "AI Copilot", "icon": Icons.smart_toy_outlined},
      {"title": "Growth Hub", "icon": Icons.trending_up_rounded},
    ];

    return Container(
      margin: const EdgeInsets.fromLTRB(14, 2, 14, 10),
      child: AdaptiveBlurSurface(
        backgroundColor: isDark
            ? const Color(0xFF1E2130).withOpacity(0.85)
            : Colors.white.withOpacity(0.9),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? const Color(0xFF2D324A) : const Color(0xFFE2E8F0),
        ),
        padding: const EdgeInsets.all(4),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          physics: const AppleSpringScrollPhysics(),
          child: Row(
            children: List.generate(tabs.length, (idx) {
              final isSelected = _selectedTab == idx;
              final item = tabs[idx];
              return AppleBounceable(
                onTap: () {
                  AppHaptics.selectionClick();
                  setState(() => _selectedTab = idx);
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeOutCubic,
                  margin: const EdgeInsets.only(right: 4),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? const Color(0xFF4F46E5)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        item["icon"] as IconData,
                        size: 15,
                        color: isSelected ? Colors.white : (isDark ? Colors.white70 : Colors.black87),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        item["title"] as String,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12,
                          fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                          color: isSelected ? Colors.white : (isDark ? Colors.white70 : Colors.black87),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }

  // =========================================================================
  // TAB 0: OPPORTUNITIES (DRIVES & OFF-CAMPUS JOBS)
  // =========================================================================
  Widget _buildOpportunitiesView(bool isDark) {
    return Column(
      children: [
        // Sub-segment: On-Campus vs Off-Campus
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 2, 16, 8),
          child: Container(
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E2130) : const Color(0xFFE2E8F0),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Expanded(
                  child: AppleBounceable(
                    onTap: () {
                      AppHaptics.selectionClick();
                      setState(() => _opportunitiesSubTab = 0);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(
                        color: _opportunitiesSubTab == 0
                            ? (isDark ? const Color(0xFF282D42) : Colors.white)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Center(
                        child: Text(
                          "On-Campus Drives (${_drives.length})",
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 12.5,
                            fontWeight: _opportunitiesSubTab == 0 ? FontWeight.w700 : FontWeight.w500,
                            color: _opportunitiesSubTab == 0
                                ? const Color(0xFF4F46E5)
                                : (isDark ? Colors.white60 : Colors.black54),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: AppleBounceable(
                    onTap: () {
                      AppHaptics.selectionClick();
                      setState(() => _opportunitiesSubTab = 1);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(
                        color: _opportunitiesSubTab == 1
                            ? (isDark ? const Color(0xFF282D42) : Colors.white)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Center(
                        child: Text(
                          "Explore Off-Campus (${_opportunities.length})",
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 12.5,
                            fontWeight: _opportunitiesSubTab == 1 ? FontWeight.w700 : FontWeight.w500,
                            color: _opportunitiesSubTab == 1
                                ? const Color(0xFF4F46E5)
                                : (isDark ? Colors.white60 : Colors.black54),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),

        // Body
        Expanded(
          child: _opportunitiesSubTab == 0
              ? _buildOnCampusDrivesSubView(isDark)
              : _buildOffCampusJobsSubView(isDark),
        ),
      ],
    );
  }

  Widget _buildOnCampusDrivesSubView(bool isDark) {
    if (_drives.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.business_center_outlined, size: 50, color: Colors.grey.withOpacity(0.5)),
            const SizedBox(height: 12),
            Text(
              "No Active Campus Drives Currently",
              style: GoogleFonts.plusJakartaSans(fontSize: 15, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 4),
            const Text(
              "The University TPO will announce upcoming schedules here.",
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      physics: AppleSpringScrollPhysics.always,
      cacheExtent: 250,
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 40),
      itemCount: _drives.length,
      itemBuilder: (context, index) {
        final drive = _drives[index];
        return _buildDriveCard(drive, isDark)
            .animate()
            .fadeIn(duration: 200.ms, delay: (index * 30).ms);
      },
    );
  }

  Widget _buildDriveCard(PlacementDriveModel drive, bool isDark) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E2130) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: drive.isEligible
              ? (isDark ? const Color(0xFF2D324A) : const Color(0xFFE2E8F0))
              : Colors.amber.withOpacity(0.4),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.2 : 0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          )
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: const Color(0xFF4F46E5).withOpacity(0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: Text(
                      drive.companyName.isNotEmpty ? drive.companyName[0] : 'C',
                      style: GoogleFonts.plusJakartaSans(
                        fontWeight: FontWeight.w800,
                        fontSize: 19,
                        color: const Color(0xFF4F46E5),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        drive.companyName,
                        style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, fontSize: 15.5),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        drive.location,
                        style: TextStyle(fontSize: 12, color: isDark ? Colors.white60 : Colors.black54),
                      ),
                    ],
                  ),
                ),
                // Eligibility Badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: drive.isEligible
                        ? const Color(0xFF10B981).withOpacity(0.14)
                        : Colors.amber.withOpacity(0.14),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        drive.isEligible ? Icons.check_circle_rounded : Icons.info_outline,
                        size: 13,
                        color: drive.isEligible ? const Color(0xFF10B981) : Colors.amber[800],
                      ),
                      const SizedBox(width: 4),
                      Text(
                        drive.isEligible ? "Eligible" : "Check Rules",
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: drive.isEligible ? const Color(0xFF10B981) : Colors.amber[800],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              drive.roleTitle,
              style: GoogleFonts.plusJakartaSans(
                fontWeight: FontWeight.w700,
                fontSize: 14.5,
                color: isDark ? const Color(0xFFC7D2FE) : const Color(0xFF3730A3),
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                if (drive.ctcBreakdown != null)
                  _buildMetaChip(Icons.currency_rupee_rounded, drive.ctcBreakdown!, const Color(0xFF059669)),
                if (drive.stipendAmount != null)
                  _buildMetaChip(Icons.savings_outlined, drive.stipendAmount!, const Color(0xFF0284C7)),
                _buildMetaChip(Icons.calendar_today_rounded, "Drive: ${drive.driveDate}", Colors.deepPurple),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              drive.jobDescription,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 12.5, height: 1.35, color: isDark ? Colors.white70 : const Color(0xFF475569)),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: Text(
                    "Deadline: ${drive.registrationDeadline}",
                    style: TextStyle(fontSize: 11, color: isDark ? Colors.white54 : Colors.grey[600]),
                  ),
                ),
                if (drive.hasApplied)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981).withOpacity(0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Text(
                      "Registered ✓",
                      style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: Color(0xFF10B981)),
                    ),
                  )
                else
                  AppleBounceable(
                    onTap: () => _handleApplyToDrive(drive),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: drive.isEligible
                              ? [const Color(0xFF4F46E5), const Color(0xFF6366F1)]
                              : [Colors.grey, Colors.blueGrey],
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        drive.isEligible ? "Register for Drive" : "View Cutoffs",
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white),
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOffCampusJobsSubView(bool isDark) {
    return Column(
      children: [
        // Search & Filters
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 2, 16, 8),
          child: Column(
            children: [
              TextField(
                onChanged: (val) {
                  _searchQuery = val.trim();
                  _loadAllData();
                },
                decoration: InputDecoration(
                  hintText: "Search skills (Flutter, Python, AI, React)...",
                  hintStyle: const TextStyle(fontSize: 12.5),
                  prefixIcon: const Icon(Icons.search_rounded, size: 18),
                  filled: true,
                  fillColor: isDark ? const Color(0xFF1E2130) : const Color(0xFFF1F5F9),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 6),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                physics: const AppleSpringScrollPhysics(),
                child: Row(
                  children: [
                    _buildFilterChip("All", _selectedEmploymentFilter == 'ALL', () {
                      setState(() => _selectedEmploymentFilter = 'ALL');
                      _loadAllData();
                    }),
                    _buildFilterChip("Internships", _selectedEmploymentFilter == 'INTERNSHIP', () {
                      setState(() => _selectedEmploymentFilter = 'INTERNSHIP');
                      _loadAllData();
                    }),
                    _buildFilterChip("Full-Time", _selectedEmploymentFilter == 'FULL_TIME', () {
                      setState(() => _selectedEmploymentFilter = 'FULL_TIME');
                      _loadAllData();
                    }),
                    _buildFilterChip("Remote", _selectedWorkModeFilter == 'REMOTE', () {
                      setState(() => _selectedWorkModeFilter = _selectedWorkModeFilter == 'REMOTE' ? 'ALL' : 'REMOTE');
                      _loadAllData();
                    }),
                  ],
                ),
              ),
            ],
          ),
        ),

        // List of jobs
        Expanded(
          child: _opportunities.isEmpty
              ? Center(
                  child: Text(
                    "No matching job listings found",
                    style: GoogleFonts.plusJakartaSans(fontSize: 13, color: Colors.grey),
                  ),
                )
              : ListView.builder(
                  physics: AppleSpringScrollPhysics.always,
                  cacheExtent: 250,
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 40),
                  itemCount: _opportunities.length,
                  itemBuilder: (context, index) {
                    final item = _opportunities[index];
                    return _buildOpportunityCard(item, isDark);
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildOpportunityCard(OpportunityListingModel item, bool isDark) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E2130) : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDark ? const Color(0xFF2D324A) : const Color(0xFFE2E8F0),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title,
                      style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, fontSize: 14.5),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      "${item.companyName} • ${item.location}",
                      style: TextStyle(fontSize: 12, color: isDark ? Colors.white60 : Colors.black54),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFF6366F1).withOpacity(0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  item.workMode,
                  style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFF6366F1)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (item.skills.isNotEmpty)
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: item.skills
                  .take(4)
                  .map((s) => Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF252A3D) : const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          s,
                          style: TextStyle(fontSize: 10.5, color: isDark ? Colors.white70 : Colors.black87),
                        ),
                      ))
                  .toList(),
            ),
          const SizedBox(height: 8),
          Text(
            item.description,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 12, color: isDark ? Colors.white60 : Colors.black87),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Text(
                item.salaryRange ?? "Competitive",
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF059669)),
              ),
              const Spacer(),
              // Apply on Site ↗
              AppleBounceable(
                onTap: () => _launchExternalUrl(item.applyUrl),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF252A3D) : const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isDark ? const Color(0xFF374151) : const Color(0xFFCBD5E1),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      Text(
                        "Apply on Site",
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
                      ),
                      SizedBox(width: 4),
                      Icon(Icons.open_in_new_rounded, size: 12),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // Track Application Button
              AppleBounceable(
                onTap: () async {
                  AppHaptics.selectionClick();
                  await CareerService.instance.trackOpportunity(item.id);
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text("Tracking ${item.title} in Pipeline")),
                    );
                    _loadAllData();
                  }
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: item.isTracked ? const Color(0xFF10B981) : const Color(0xFF4F46E5),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    item.isTracked ? "Tracked ✓" : "+ Track",
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // =========================================================================
  // TAB 1: MY APPLICATIONS (REAL-TIME PIPELINE TRACKER)
  // =========================================================================
  Widget _buildApplicationPipelineView(bool isDark) {
    if (_applications.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.track_changes_rounded, size: 48, color: Colors.grey.withOpacity(0.5)),
            const SizedBox(height: 12),
            Text(
              "No Active Applications Tracked",
              style: GoogleFonts.plusJakartaSans(fontSize: 15, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 4),
            const Text(
              "Register for on-campus drives or track external jobs to see your timeline.",
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      physics: AppleSpringScrollPhysics.always,
      cacheExtent: 250,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
      itemCount: _applications.length,
      itemBuilder: (context, index) {
        final app = _applications[index];
        return _buildPipelineCard(app, isDark);
      },
    );
  }

  Widget _buildPipelineCard(PlacementApplicationModel app, bool isDark) {
    final title = app.drive?.roleTitle ?? app.opportunity?.title ?? "Application";
    final company = app.drive?.companyName ?? app.opportunity?.companyName ?? "Company";
    final isDrive = app.drive != null;

    final stages = ['APPLIED', 'SHORTLISTED', 'ASSESSMENT', 'INTERVIEW', 'OFFERED'];
    final currentStatus = app.status.toUpperCase();
    int currentIdx = stages.indexOf(currentStatus);
    if (currentIdx == -1) currentIdx = 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E2130) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? const Color(0xFF2D324A) : const Color(0xFFE2E8F0),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.2 : 0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, fontSize: 14.5),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      company,
                      style: TextStyle(fontSize: 12, color: isDark ? Colors.white70 : Colors.black87),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: isDrive
                      ? const Color(0xFF0284C7).withOpacity(0.12)
                      : const Color(0xFF8B5CF6).withOpacity(0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  isDrive ? "ON-CAMPUS" : "EXTERNAL",
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: isDrive ? const Color(0xFF0284C7) : const Color(0xFF8B5CF6),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Stepper Timeline (RepaintBoundary for isolated GPU rasterization)
          RepaintBoundary(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: List.generate(stages.length, (idx) {
                final isDone = idx <= currentIdx;
                final isCurrent = idx == currentIdx;
                return Expanded(
                  child: Row(
                    children: [
                      Container(
                        width: 18,
                        height: 18,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isDone
                              ? (isCurrent ? const Color(0xFF4F46E5) : const Color(0xFF10B981))
                              : (isDark ? Colors.white24 : Colors.black12),
                        ),
                        child: Center(
                          child: Icon(
                            isDone ? Icons.check : Icons.circle,
                            size: 10,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      if (idx < stages.length - 1)
                        Expanded(
                          child: Container(
                            height: 2,
                            color: idx < currentIdx
                                ? const Color(0xFF10B981)
                                : (isDark ? Colors.white12 : Colors.black12),
                          ),
                        ),
                    ],
                  ),
                );
              }),
            ),
          ),

          const SizedBox(height: 10),

          // Labels
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Applied', style: TextStyle(fontSize: 10, color: isDark ? Colors.white54 : Colors.grey)),
              Text('Shortlist', style: TextStyle(fontSize: 10, color: isDark ? Colors.white54 : Colors.grey)),
              Text('Test', style: TextStyle(fontSize: 10, color: isDark ? Colors.white54 : Colors.grey)),
              Text('Interview', style: TextStyle(fontSize: 10, color: isDark ? Colors.white54 : Colors.grey)),
              Text('Offer', style: TextStyle(fontSize: 10, color: isDark ? Colors.white54 : Colors.grey)),
            ],
          ),

          if (app.adminNotes != null && app.adminNotes!.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF282D42) : const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, size: 14, color: Color(0xFF6366F1)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      app.adminNotes!,
                      style: TextStyle(fontSize: 11.5, color: isDark ? Colors.white70 : Colors.black87),
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

  // =========================================================================
  // TAB 2: RESUME & ATS STUDIO
  // =========================================================================
  Widget _buildResumeAndAtsStudioView(bool isDark) {
    final atsScore = _latestAtsAnalysis?['atsScore'] ?? _profile?.atsScore ?? 84;
    final strengths = (_latestAtsAnalysis?['strengths'] as List?)?.map((e) => e.toString()).toList() ??
        [
          "Verified engineering degree enrollment in BPUT Autonomous University",
          "Demonstrable software projects highlighting full-stack & mobile engineering",
          "Active attendance eligibility for institutional campus drives"
        ];
    final missingKeywords = (_latestAtsAnalysis?['missingKeywords'] as List?)?.map((e) => e.toString()).toList() ??
        ["Docker Containerization", "Kubernetes", "Microservices Architecture", "CI/CD Pipelines"];
    final formattingTips = (_latestAtsAnalysis?['formattingTips'] as List?)?.map((e) => e.toString()).toList() ??
        ["Strictly quantify results: Accomplished [X] measured by [Y] by doing [Z]", "Ensure 1-page single column layout for automated OCR parsers"];

    return ListView(
      physics: AppleSpringScrollPhysics.always,
      cacheExtent: 250,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
      children: [
        // 1. Automated Resume Generator Card
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E2130) : Colors.white,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: const Color(0xFF4F46E5).withOpacity(0.3),
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF4F46E5).withOpacity(0.08),
                blurRadius: 16,
                offset: const Offset(0, 4),
              )
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF4F46E5).withOpacity(0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.picture_as_pdf_outlined, color: Color(0xFF4F46E5), size: 24),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Automated Resume Generator",
                          style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800, fontSize: 16),
                        ),
                        const SizedBox(height: 2),
                        const Text(
                          "Harvard-standard ATS layout generated from your Smart Profile",
                          style: TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: AppleBounceable(
                      onTap: () {
                        // Open printable HTML resume in browser which prints directly to PDF
                        _launchExternalUrl("http://127.0.0.1:5000/api/career/resume/html?print=true");
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: const Color(0xFF4F46E5),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Center(
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.download_rounded, color: Colors.white, size: 16),
                              SizedBox(width: 6),
                              Text(
                                "Download Resume PDF",
                                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5, color: Colors.white),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  AppleBounceable(
                    onTap: () {
                      _launchExternalUrl("http://127.0.0.1:5000/api/career/resume/html");
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF282D42) : const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: isDark ? const Color(0xFF374151) : const Color(0xFFCBD5E1)),
                      ),
                      child: const Icon(Icons.visibility_outlined, size: 18),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        const SizedBox(height: 18),

        // 2. ATS Score Gauge Card
        RepaintBoundary(
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isDark
                    ? [const Color(0xFF1E2130), const Color(0xFF282D42)]
                    : [const Color(0xFFEEF2FF), Colors.white],
              ),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: const Color(0xFF6366F1).withOpacity(0.3)),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: const RadialGradient(
                          colors: [Color(0xFF4F46E5), Color(0xFF818CF8)],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF4F46E5).withOpacity(0.3),
                            blurRadius: 14,
                          ),
                        ],
                      ),
                      child: Center(
                        child: Text(
                          "$atsScore",
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 24,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "ATS Match Index",
                            style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, fontSize: 16),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            atsScore >= 80 ? "Top 10% Placement Ready" : "Good Foundation • Needs Keyword Boost",
                            style: TextStyle(
                              fontSize: 12,
                              color: atsScore >= 80 ? const Color(0xFF10B981) : Colors.amber[800],
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            "Audited against current IT recruiter criteria",
                            style: TextStyle(fontSize: 11, color: isDark ? Colors.white54 : Colors.grey[600]),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                AppleBounceable(
                  onTap: _isAnalyzingResume ? null : _handleRunAtsAnalysis,
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF4F46E5),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Center(
                      child: _isAnalyzingResume
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                            )
                          : Text(
                              "Re-Scan Resume with Gemini AI",
                              style: GoogleFonts.plusJakartaSans(
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                                color: Colors.white,
                              ),
                            ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 20),

        // 3. Strengths Section
        _buildSectionHeader("Verified Strengths", Icons.thumb_up_alt_outlined),
        ...strengths.map((s) => _buildBulletTile(s, Icons.check_circle_outline, const Color(0xFF10B981), isDark)),

        const SizedBox(height: 18),

        // 4. Missing Keywords Section
        _buildSectionHeader("Missing Keywords for Top Tech Roles", Icons.add_circle_outline),
        Wrap(
          spacing: 8,
          runSpacing: 6,
          children: missingKeywords
              .map((k) => AppleBounceable(
                    onTap: () {
                      AppHaptics.selectionClick();
                      // Navigate to smart profile to add it!
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const SmartProfileScreen()),
                      );
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: Colors.amber.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.amber.withOpacity(0.3)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            "+ $k",
                            style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: Colors.amber[800]),
                          ),
                          const SizedBox(width: 4),
                          Icon(Icons.add, size: 12, color: Colors.amber[800]),
                        ],
                      ),
                    ),
                  ))
              .toList(),
        ),

        const SizedBox(height: 20),

        // 5. Formatting Tips
        _buildSectionHeader("Actionable Formatting Tips", Icons.lightbulb_outline),
        ...formattingTips.map((t) => _buildBulletTile(t, Icons.arrow_right_rounded, const Color(0xFF6366F1), isDark)),
      ],
    );
  }

  // =========================================================================
  // TAB 3: AI CAREER COPILOT (GEMINI 3.8 FLASH)
  // =========================================================================
  Widget _buildCareerCopilotView(bool isDark) {
    return Column(
      children: [
        // Quick suggestions bar
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          physics: const AppleSpringScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 6, 16, 8),
          child: Row(
            children: [
              _buildCopilotChip("Mock Interview Question", () {
                _sendCopilotMessage("Ask me a technical mock question for Software Engineer role.");
              }),
              _buildCopilotChip("Improve Resume Bullets", () {
                _sendCopilotMessage("How do I rewrite my project description using Google's X-Y-Z formula?");
              }),
              _buildCopilotChip("Oracle Drive Tips", () {
                _sendCopilotMessage("What should I prepare for Oracle Cloud placement drive?");
              }),
            ],
          ),
        ),

        // Chat messages list
        Expanded(
          child: ListView.builder(
            physics: AppleSpringScrollPhysics.always,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            itemCount: _copilotChatMessages.length,
            itemBuilder: (context, index) {
              final msg = _copilotChatMessages[index];
              final isUser = msg['sender'] == 'user';
              return Align(
                alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
                child: Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(14),
                  constraints: BoxConstraints(
                    maxWidth: MediaQuery.of(context).size.width * 0.82,
                  ),
                  decoration: BoxDecoration(
                    color: isUser
                        ? const Color(0xFF4F46E5)
                        : (isDark ? const Color(0xFF1E2130) : Colors.white),
                    borderRadius: BorderRadius.circular(16),
                    border: isUser
                        ? null
                        : Border.all(
                            color: isDark ? const Color(0xFF2D324A) : const Color(0xFFE2E8F0),
                          ),
                  ),
                  child: Text(
                    msg['text'] ?? '',
                    style: TextStyle(
                      fontSize: 13,
                      height: 1.4,
                      color: isUser ? Colors.white : (isDark ? Colors.white : Colors.black87),
                    ),
                  ),
                ),
              );
            },
          ),
        ),

        if (_isCopilotThinking)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: const [
                SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                SizedBox(width: 8),
                Text("Gemini is thinking...", style: TextStyle(fontSize: 11, color: Colors.grey)),
              ],
            ),
          ),

        // Input bar
        Container(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF161622) : Colors.white,
            border: Border(top: BorderSide(color: isDark ? const Color(0xFF262638) : const Color(0xFFE2E8F0))),
          ),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _copilotInputController,
                  onSubmitted: _sendCopilotMessage,
                  decoration: InputDecoration(
                    hintText: "Ask Career Copilot anything...",
                    hintStyle: const TextStyle(fontSize: 13),
                    filled: true,
                    fillColor: isDark ? const Color(0xFF1E2130) : const Color(0xFFF1F5F9),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              AppleBounceable(
                onTap: () => _sendCopilotMessage(_copilotInputController.text),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF4F46E5),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(Icons.arrow_upward_rounded, color: Colors.white, size: 18),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCopilotChip(String text, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: AppleBounceable(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: const Color(0xFF4F46E5).withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFF4F46E5).withOpacity(0.3)),
          ),
          child: Text(
            text,
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF4F46E5)),
          ),
        ),
      ),
    );
  }

  // =========================================================================
  // TAB 4: GROWTH HUB (ANALYTICS, RESOURCES & TECH NEWS)
  // =========================================================================
  Widget _buildGrowthAndNewsView(bool isDark) {
    return ListView(
      physics: AppleSpringScrollPhysics.always,
      cacheExtent: 250,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
      children: [
        // 1. Placement Readiness Index Bento Card
        RepaintBoundary(
          child: Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isDark
                    ? [const Color(0xFF1E2130), const Color(0xFF282D42)]
                    : [const Color(0xFFEEF2FF), Colors.white],
              ),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: const Color(0xFF6366F1).withOpacity(0.3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      "Placement Readiness Index",
                      style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800, fontSize: 16),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981).withOpacity(0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Text(
                        "92 / 100",
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Color(0xFF10B981)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                const Text(
                  "Combines academic attendance (88%), ATS resume strength (84%), and verified projects.",
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
                const SizedBox(height: 14),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: const LinearProgressIndicator(
                    value: 0.92,
                    minHeight: 8,
                    backgroundColor: Colors.black12,
                    valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF10B981)),
                  ),
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 20),

        // 2. Curated Learning Resources
        _buildSectionHeader("Curated Placement Roadmaps", Icons.menu_book_outlined),
        ..._resources.map((res) => _buildResourceCard(res, isDark)),

        const SizedBox(height: 24),

        // 3. Tech News Feed
        _buildSectionHeader("Engineering & Industry News", Icons.newspaper_rounded),
        ..._news.map((n) => _buildNewsCard(n, isDark)),
      ],
    );
  }

  Widget _buildResourceCard(CareerResourceModel res, bool isDark) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E2130) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? const Color(0xFF2D324A) : const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  res.title,
                  style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, fontSize: 13.5),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFF4F46E5).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  res.level,
                  style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFF4F46E5)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            res.description,
            style: TextStyle(fontSize: 12, color: isDark ? Colors.white70 : const Color(0xFF475569)),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Text(
                "Est. ${res.estimatedHours}",
                style: const TextStyle(fontSize: 11, color: Colors.grey),
              ),
              const Spacer(),
              AppleBounceable(
                onTap: () => _launchExternalUrl(res.url),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF4F46E5),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text("Open Roadmap", style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white)),
                      SizedBox(width: 4),
                      Icon(Icons.arrow_forward_rounded, size: 12, color: Colors.white),
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

  Widget _buildNewsCard(TechNewsModel n, bool isDark) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E2130) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? const Color(0xFF2D324A) : const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                "${n.source} • ${n.publishedAt}",
                style: const TextStyle(fontSize: 11, color: Colors.grey),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.deepPurple.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  n.category,
                  style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Colors.deepPurple),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            n.title,
            style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, fontSize: 13.5),
          ),
          const SizedBox(height: 4),
          Text(
            n.summary,
            style: TextStyle(fontSize: 12, color: isDark ? Colors.white70 : const Color(0xFF475569)),
          ),
          const SizedBox(height: 8),
          AppleBounceable(
            onTap: () => _launchExternalUrl(n.url),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: const [
                Text(
                  "Read Full Article",
                  style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: Color(0xFF4F46E5)),
                ),
                SizedBox(width: 4),
                Icon(Icons.arrow_forward_rounded, size: 12, color: Color(0xFF4F46E5)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(icon, size: 18, color: const Color(0xFF4F46E5)),
          const SizedBox(width: 6),
          Text(
            title,
            style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildBulletTile(String text, IconData icon, Color iconColor, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: iconColor),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(fontSize: 12.5, height: 1.35, color: isDark ? Colors.white70 : Colors.black87),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, bool isSelected, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: AppleBounceable(
        onTap: () {
          AppHaptics.selectionClick();
          onTap();
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFF4F46E5) : Colors.transparent,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isSelected ? const Color(0xFF4F46E5) : const Color(0xFFCBD5E1),
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
              color: isSelected ? Colors.white : Colors.grey[700],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMetaChip(IconData icon, String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color),
          ),
        ],
      ),
    );
  }
}
