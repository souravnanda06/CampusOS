import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../auth/models/user_model.dart';
import '../../../auth/providers/user_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/text_styles.dart';
import '../../models/mess_model.dart';
import '../../services/mess_service.dart';

class MessFeedbackAnalyticsScreen extends StatefulWidget {
  final UserModel? user;
  final MessService? messService;

  const MessFeedbackAnalyticsScreen({
    Key? key,
    this.user,
    this.messService,
  }) : super(key: key);

  @override
  State<MessFeedbackAnalyticsScreen> createState() =>
      _MessFeedbackAnalyticsScreenState();
}

class _MessFeedbackAnalyticsScreenState
    extends State<MessFeedbackAnalyticsScreen>
    with SingleTickerProviderStateMixin {
  late final MessService _messService;
  late TabController _tabController;

  bool _isLoading = true;
  String? _error;

  // Filters
  String _dateFilterPreset = 'ALL'; // 'ALL', '7D', '30D', 'CUSTOM'
  DateTime? _startDate;
  DateTime? _endDate;
  String _selectedMealType =
      'ALL'; // 'ALL', 'BREAKFAST', 'LUNCH', 'SNACKS', 'DINNER'

  // Data
  FeedbackSummary? _summary;
  List<FeedbackTrend> _trends = [];
  List<FeedbackCategoryStat> _categories = [];
  List<FeedbackSignal> _signals = [];
  List<FeedbackCommentItem> _comments = [];

  UserModel? get _effectiveUser {
    return widget.user ??
        Provider.of<UserProvider>(context, listen: false).user;
  }

  bool get _isAuthorized {
    final role = (_effectiveUser?.role ?? '').toLowerCase().trim();
    return role == 'admin' ||
        role == 'staff' ||
        role == 'warden' ||
        role == 'mess_staff' ||
        role == 'mess';
  }

  @override
  void initState() {
    super.initState();
    _messService = widget.messService ?? MessService();
    _tabController = TabController(length: 4, vsync: this);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_isAuthorized) {
        _loadAnalytics();
      } else {
        setState(() {
          _isLoading = false;
        });
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _setDatePreset(String preset) {
    final now = DateTime.now();
    setState(() {
      _dateFilterPreset = preset;
      if (preset == '7D') {
        _startDate = now.subtract(const Duration(days: 7));
        _endDate = now;
      } else if (preset == '30D') {
        _startDate = now.subtract(const Duration(days: 30));
        _endDate = now;
      } else if (preset == 'ALL') {
        _startDate = null;
        _endDate = null;
      }
    });
    _loadAnalytics();
  }

  Future<void> _pickCustomDateRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2025, 1, 1),
      lastDate: DateTime(2030, 12, 31),
      initialDateRange: (_startDate != null && _endDate != null)
          ? DateTimeRange(start: _startDate!, end: _endDate!)
          : DateTimeRange(
              start: DateTime.now().subtract(const Duration(days: 7)),
              end: DateTime.now(),
            ),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppColors.primary,
              onPrimary: Colors.white,
              onSurface: AppColors.textPrimary,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _dateFilterPreset = 'CUSTOM';
        _startDate = picked.start;
        _endDate = picked.end;
      });
      _loadAnalytics();
    }
  }

  Future<void> _loadAnalytics() async {
    final requesterId = _effectiveUser?.id ?? '';
    if (requesterId.isEmpty && !_isAuthorized) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final startStr = _startDate != null
          ? DateFormat('yyyy-MM-dd').format(_startDate!)
          : null;
      final endStr =
          _endDate != null ? DateFormat('yyyy-MM-dd').format(_endDate!) : null;
      final mealTypeParam =
          _selectedMealType == 'ALL' ? null : _selectedMealType;

      final results = await Future.wait([
        _messService.getFeedbackSummary(
          startDate: startStr,
          endDate: endStr,
          mealType: mealTypeParam,
          requesterId: requesterId,
        ),
        _messService.getFeedbackTrends(
          startDate: startStr,
          endDate: endStr,
          mealType: mealTypeParam,
          requesterId: requesterId,
        ),
        _messService.getFeedbackCategories(
          startDate: startStr,
          endDate: endStr,
          mealType: mealTypeParam,
          requesterId: requesterId,
        ),
        _messService.getFeedbackComments(
          startDate: startStr,
          endDate: endStr,
          mealType: mealTypeParam,
          requesterId: requesterId,
        ),
      ]);

      if (!mounted) return;

      final summary = results[0] as FeedbackSummary;
      final trends = results[1] as List<FeedbackTrend>;
      final catSig = results[2] as Map<String, dynamic>;
      final comments = results[3] as List<FeedbackCommentItem>;

      setState(() {
        _summary = summary;
        _trends = trends;
        _categories = (catSig['categories'] as List<dynamic>?)
                ?.cast<FeedbackCategoryStat>() ??
            [];
        _signals =
            (catSig['signals'] as List<dynamic>?)?.cast<FeedbackSignal>() ?? [];
        _comments = comments;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = MessService.sanitizeError(e);
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_isAuthorized) {
      return Scaffold(
        backgroundColor: AppColors.bg,
        appBar: AppBar(
          title: Text('Mess Feedback Analytics', style: AppTextStyles.h3),
          backgroundColor: AppColors.surface,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded,
                color: AppColors.textPrimary, size: 20),
            onPressed: () => Navigator.maybePop(context),
          ),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppColors.danger.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.lock_person_rounded,
                      size: 48, color: AppColors.danger),
                ),
                const SizedBox(height: 16),
                Text('Access Restricted', style: AppTextStyles.h2),
                const SizedBox(height: 8),
                Text(
                  'Mess feedback analytics requires Staff, Warden, or Administrator privileges. Teachers and students are not permitted to access feedback analytics.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 14,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () => Navigator.maybePop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text('Go Back'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        title: Text('Feedback Analytics', style: AppTextStyles.h3),
        backgroundColor: AppColors.surface,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              color: AppColors.textPrimary, size: 20),
          onPressed: () => Navigator.maybePop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded,
                color: AppColors.textSecondary),
            tooltip: 'Refresh Analytics',
            onPressed: _loadAnalytics,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.textSecondary,
          indicatorColor: AppColors.primary,
          indicatorWeight: 3,
          labelStyle: GoogleFonts.plusJakartaSans(
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
          unselectedLabelStyle: GoogleFonts.plusJakartaSans(
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
          tabs: const [
            Tab(text: 'Overview'),
            Tab(text: 'Trends'),
            Tab(text: 'Categories'),
            Tab(text: 'Comments'),
          ],
        ),
      ),
      body: Column(
        children: [
          _buildFilterBar(),
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(color: AppColors.primary))
                : _error != null
                    ? _buildErrorView()
                    : TabBarView(
                        controller: _tabController,
                        children: [
                          _buildOverviewTab(),
                          _buildTrendsTab(),
                          _buildCategoriesTab(),
                          _buildCommentsTab(),
                        ],
                      ),
          ),
        ],
      ),
    );
  }

  // --- FILTER BAR ---
  Widget _buildFilterBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Column(
        children: [
          // Row 1: Date Range Presets
          Row(
            children: [
              Text(
                'Period: ',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(width: 6),
              _buildPresetChip('All Time', 'ALL'),
              const SizedBox(width: 6),
              _buildPresetChip('7 Days', '7D'),
              const SizedBox(width: 6),
              _buildPresetChip('30 Days', '30D'),
              const SizedBox(width: 6),
              InkWell(
                onTap: _pickCustomDateRange,
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: _dateFilterPreset == 'CUSTOM'
                        ? AppColors.primary
                        : AppColors.surfaceAlt,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: _dateFilterPreset == 'CUSTOM'
                          ? AppColors.primary
                          : AppColors.border,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.calendar_month_outlined,
                        size: 13,
                        color: _dateFilterPreset == 'CUSTOM'
                            ? Colors.white
                            : AppColors.textSecondary,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _dateFilterPreset == 'CUSTOM' &&
                                _startDate != null &&
                                _endDate != null
                            ? '${DateFormat('MM/dd').format(_startDate!)}-${DateFormat('MM/dd').format(_endDate!)}'
                            : 'Custom',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: _dateFilterPreset == 'CUSTOM'
                              ? Colors.white
                              : AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Row 2: Meal Type Chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                Text(
                  'Meal: ',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(width: 6),
                _buildMealTypeChip('All Meals', 'ALL'),
                const SizedBox(width: 6),
                _buildMealTypeChip('Breakfast', 'BREAKFAST'),
                const SizedBox(width: 6),
                _buildMealTypeChip('Lunch', 'LUNCH'),
                const SizedBox(width: 6),
                _buildMealTypeChip('Snacks', 'SNACKS'),
                const SizedBox(width: 6),
                _buildMealTypeChip('Dinner', 'DINNER'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPresetChip(String label, String preset) {
    final isSelected = _dateFilterPreset == preset;
    return InkWell(
      onTap: () => _setDatePreset(preset),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : AppColors.surfaceAlt,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.border,
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: isSelected ? Colors.white : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }

  Widget _buildMealTypeChip(String label, String mealType) {
    final isSelected = _selectedMealType == mealType;
    return InkWell(
      onTap: () {
        setState(() {
          _selectedMealType = mealType;
        });
        _loadAnalytics();
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primary.withValues(alpha: 0.12)
              : AppColors.surfaceAlt,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.border,
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 11,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            color: isSelected ? AppColors.primary : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }

  Widget _buildErrorView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline_rounded,
                size: 48, color: AppColors.danger),
            const SizedBox(height: 12),
            Text('Failed to load analytics', style: AppTextStyles.h4),
            const SizedBox(height: 6),
            Text(
              _error ?? 'An unexpected error occurred.',
              textAlign: TextAlign.center,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 13,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 18),
            ElevatedButton.icon(
              onPressed: _loadAnalytics,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Retry'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
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

  // --- TAB 1: OVERVIEW & MEAL BREAKDOWN ---
  Widget _buildOverviewTab() {
    final summary = _summary;
    if (summary == null || summary.totalRatings == 0) {
      return _buildEmptyState(
        icon: Icons.star_border_rounded,
        title: 'No Ratings Recorded',
        message:
            'No student meal ratings have been submitted for the selected filter criteria.',
      );
    }

    return RefreshIndicator(
      onRefresh: _loadAnalytics,
      color: AppColors.primary,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Stat Cards Grid
          Row(
            children: [
              Expanded(
                child: _buildMetricCard(
                  title: 'Average Rating',
                  value: summary.averageRating.toStringAsFixed(1),
                  subtitle: 'out of 5.0',
                  icon: Icons.star_rounded,
                  iconColor: Colors.amber,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildMetricCard(
                  title: 'Total Ratings',
                  value: '${summary.totalRatings}',
                  subtitle: 'submissions',
                  icon: Icons.rate_review_outlined,
                  iconColor: AppColors.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildMetricCard(
                  title: 'Feedback Count',
                  value: '${summary.feedbackCount}',
                  subtitle: 'verified meals',
                  icon: Icons.inventory_2_outlined,
                  iconColor: AppColors.info,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildMetricCard(
                  title: 'Student Comments',
                  value: '${summary.totalComments}',
                  subtitle: 'written notes',
                  icon: Icons.chat_bubble_outline_rounded,
                  iconColor: AppColors.success,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Rating Distribution Card
          _buildRatingDistributionCard(summary),
          const SizedBox(height: 20),

          // Meal Breakdown Section
          _buildMealBreakdownSection(summary.mealBreakdown),
        ],
      ),
    );
  }

  Widget _buildMetricCard({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color iconColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                ),
              ),
              Icon(icon, size: 20, color: iconColor),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 11,
              color: AppColors.textTertiary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRatingDistributionCard(FeedbackSummary summary) {
    final total = summary.totalRatings;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Rating Distribution', style: AppTextStyles.h4),
              Text(
                '$total total',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          for (int star = 5; star >= 1; star--) ...[
            _buildDistributionRow(
              star: star,
              count: summary.ratingDistribution[star] ?? 0,
              total: total,
            ),
            if (star > 1) const SizedBox(height: 8),
          ],
        ],
      ),
    );
  }

  Widget _buildDistributionRow({
    required int star,
    required int count,
    required int total,
  }) {
    final pct = total > 0 ? (count / total) : 0.0;
    Color barColor;
    if (star >= 4) {
      barColor = AppColors.success;
    } else if (star == 3) {
      barColor = AppColors.warning;
    } else {
      barColor = AppColors.danger;
    }

    return Row(
      children: [
        SizedBox(
          width: 32,
          child: Row(
            children: [
              Text(
                '$star',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const Icon(Icons.star_rounded, size: 14, color: Colors.amber),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: pct,
              minHeight: 8,
              backgroundColor: AppColors.surfaceAlt,
              valueColor: AlwaysStoppedAnimation<Color>(barColor),
            ),
          ),
        ),
        const SizedBox(width: 12),
        SizedBox(
          width: 55,
          child: Text(
            '$count (${(pct * 100).toStringAsFixed(0)}%)',
            textAlign: TextAlign.end,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMealBreakdownSection(
      Map<String, MealRatingSummary> mealBreakdown) {
    const mealTypes = ['BREAKFAST', 'LUNCH', 'SNACKS', 'DINNER'];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Meal Breakdown', style: AppTextStyles.h4),
        const SizedBox(height: 12),
        Row(
          children: [
            for (int i = 0; i < 2; i++) ...[
              if (i > 0) const SizedBox(width: 12),
              Expanded(
                child: _buildMealTypeCard(
                  type: mealTypes[i],
                  summary: mealBreakdown[mealTypes[i]],
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            for (int i = 2; i < 4; i++) ...[
              if (i > 2) const SizedBox(width: 12),
              Expanded(
                child: _buildMealTypeCard(
                  type: mealTypes[i],
                  summary: mealBreakdown[mealTypes[i]],
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }

  Widget _buildMealTypeCard({
    required String type,
    MealRatingSummary? summary,
  }) {
    IconData icon;
    Color iconColor;
    String title;

    switch (type) {
      case 'BREAKFAST':
        icon = Icons.wb_sunny_outlined;
        iconColor = Colors.orange;
        title = 'Breakfast';
        break;
      case 'LUNCH':
        icon = Icons.lunch_dining_rounded;
        iconColor = Colors.green;
        title = 'Lunch';
        break;
      case 'SNACKS':
        icon = Icons.coffee_rounded;
        iconColor = Colors.brown;
        title = 'Snacks';
        break;
      case 'DINNER':
      default:
        icon = Icons.nightlight_round;
        iconColor = Colors.indigo;
        title = 'Dinner';
        break;
    }

    final hasRatings = summary != null && summary.count > 0;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, size: 16, color: iconColor),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (hasRatings) ...[
            Row(
              children: [
                const Icon(Icons.star_rounded, size: 16, color: Colors.amber),
                const SizedBox(width: 4),
                Text(
                  summary.averageRating.toStringAsFixed(1),
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
                Text(
                  ' / 5.0',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              '${summary.count} ratings',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 11,
                color: AppColors.textSecondary,
              ),
            ),
          ] else ...[
            Text(
              'No ratings',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.textTertiary,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              '0 submissions',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 11,
                color: AppColors.textTertiary,
              ),
            ),
          ],
        ],
      ),
    );
  }

  // --- TAB 2: TRENDS OVER TIME ---
  Widget _buildTrendsTab() {
    if (_trends.isEmpty) {
      return _buildEmptyState(
        icon: Icons.trending_up_rounded,
        title: 'No Trend Data',
        message:
            'Trend records will appear once feedback entries are submitted across dates.',
      );
    }

    return RefreshIndicator(
      onRefresh: _loadAnalytics,
      color: AppColors.primary,
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: _trends.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final item = _trends[index];
          return Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.calendar_today_rounded,
                            size: 16, color: AppColors.primary),
                        const SizedBox(width: 8),
                        Text(
                          item.date,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.primaryLight,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '${item.ratingCount} ${item.ratingCount == 1 ? 'rating' : 'ratings'}',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppColors.primaryDark,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Icon(Icons.star_rounded,
                        size: 20, color: Colors.amber),
                    const SizedBox(width: 4),
                    Text(
                      item.averageRating.toStringAsFixed(1),
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    Text(
                      ' / 5.0 avg',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
                if (item.mealBreakdown.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  const Divider(height: 1),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 12,
                    runSpacing: 6,
                    children: item.mealBreakdown.entries.map((e) {
                      return Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '${e.key.substring(0, 1)}${e.key.substring(1).toLowerCase()}: ',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          const Icon(Icons.star_rounded,
                              size: 13, color: Colors.amber),
                          Text(
                            '${e.value.averageRating.toStringAsFixed(1)} (${e.value.count})',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ],
                      );
                    }).toList(),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  // --- TAB 3: CATEGORIES & RECURRING SIGNALS ---
  Widget _buildCategoriesTab() {
    final flaggedSignals = _signals.where((s) => s.flagged).toList();

    return RefreshIndicator(
      onRefresh: _loadAnalytics,
      color: AppColors.primary,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Recurring Signals Section Header
          _buildSignalsBanner(flaggedSignals),
          const SizedBox(height: 20),

          // Categories Breakdown List
          Text('Categories Performance', style: AppTextStyles.h4),
          const SizedBox(height: 12),
          if (_categories.isEmpty)
            _buildEmptyState(
              icon: Icons.category_outlined,
              title: 'No Category Feedback',
              message:
                  'Categorized student feedback will be aggregated here once submitted.',
            )
          else
            ..._categories.map((cat) => _buildCategoryCard(cat)),
        ],
      ),
    );
  }

  Widget _buildSignalsBanner(List<FeedbackSignal> flaggedSignals) {
    final hasFlags = flaggedSignals.isNotEmpty;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: hasFlags
            ? AppColors.danger.withValues(alpha: 0.08)
            : AppColors.success.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: hasFlags
              ? AppColors.danger.withValues(alpha: 0.3)
              : AppColors.success.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                hasFlags
                    ? Icons.warning_amber_rounded
                    : Icons.check_circle_outline_rounded,
                color: hasFlags ? AppColors.danger : AppColors.success,
                size: 22,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  hasFlags
                      ? 'Recurring Feedback Signals (${flaggedSignals.length} Flagged)'
                      : 'Recurring Feedback Signals: All Normal',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: hasFlags ? AppColors.danger : AppColors.success,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Rule: A category is flagged when feedback count ≥ 2 and (average rating < 3.0 or negative share ≥ 35%).',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 11,
              color: AppColors.textSecondary,
            ),
          ),
          if (hasFlags) ...[
            const SizedBox(height: 12),
            for (final sig in flaggedSignals) ...[
              Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppColors.danger.withValues(alpha: 0.2),
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            sig.label,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            sig.flagReason,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 11,
                              color: AppColors.danger,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.star_rounded,
                                size: 14, color: Colors.amber),
                            Text(
                              sig.averageRating.toStringAsFixed(1),
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ],
                        ),
                        Text(
                          '${sig.negativeCount}/${sig.feedbackCount} negative',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 10,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }

  Widget _buildCategoryCard(FeedbackCategoryStat cat) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                cat.label,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              Row(
                children: [
                  const Icon(Icons.star_rounded, size: 16, color: Colors.amber),
                  const SizedBox(width: 4),
                  Text(
                    cat.averageRating.toStringAsFixed(1),
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  Text(
                    ' / 5.0',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 11,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Ratio progress bar: Green for positive, Red for negative
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: Row(
              children: [
                Expanded(
                  flex: cat.positiveCount,
                  child: Container(
                    height: 8,
                    color: AppColors.success,
                  ),
                ),
                if (cat.negativeCount > 0)
                  Expanded(
                    flex: cat.negativeCount,
                    child: Container(
                      height: 8,
                      color: AppColors.danger,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Total: ${cat.feedbackCount} feedback',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 11,
                  color: AppColors.textSecondary,
                ),
              ),
              Row(
                children: [
                  Text(
                    '${cat.positiveCount} positive (4-5★)',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: AppColors.success,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${cat.negativeCount} negative (1-2★)',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: AppColors.danger,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  // --- TAB 4: COMMENTS (ANONYMIZED) ---
  Widget _buildCommentsTab() {
    if (_comments.isEmpty) {
      return _buildEmptyState(
        icon: Icons.chat_bubble_outline_rounded,
        title: 'No Comments Yet',
        message:
            'Written student notes and feedback will be listed here anonymously to preserve privacy.',
      );
    }

    return RefreshIndicator(
      onRefresh: _loadAnalytics,
      color: AppColors.primary,
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: _comments.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final item = _comments[index];
          return Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border),
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
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: AppColors.primaryLight,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            item.mealType,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: AppColors.primaryDark,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          item.mealTitle,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        for (int i = 1; i <= 5; i++)
                          Icon(
                            i <= item.rating
                                ? Icons.star_rounded
                                : Icons.star_border_rounded,
                            size: 15,
                            color: i <= item.rating
                                ? (item.rating >= 4
                                    ? Colors.amber
                                    : (item.rating == 3
                                        ? AppColors.warning
                                        : AppColors.danger))
                                : AppColors.border,
                          ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  item.comment,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 13,
                    color: AppColors.textPrimary,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    if (item.category != null && item.category!.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceAlt,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Text(
                          item.category!,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      )
                    else
                      const SizedBox.shrink(),
                    Text(
                      item.menuDate,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11,
                        color: AppColors.textTertiary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildEmptyState({
    required IconData icon,
    required String title,
    required String message,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: const BoxDecoration(
                color: AppColors.surfaceAlt,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 40, color: AppColors.textTertiary),
            ),
            const SizedBox(height: 16),
            Text(title, style: AppTextStyles.h4),
            const SizedBox(height: 6),
            Text(
              message,
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
}
