import 'package:flutter/material.dart';
import 'package:attendance_app/core/haptics/app_haptics.dart';

import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../auth/models/user_model.dart';
import '../../core/config/app_config.dart';
import '../../core/theme/app_colors.dart';
import '../../data/syllabus/syllabus_data.dart';
import '../services/teacher_analytics_service.dart';
import '../../core/localization/app_localizations.dart';

/// CampusOS Teacher Analytics Screen with Apple Health-grade Precision.
///
/// Features:
/// - Real student cohort analytics filtered by course, branch, and year.
/// - Apple Health summary cards: Avg Attendance, High Performers (>=90%), At Risk (<75%).
/// - Student roster with attendance percentages and one-tap device ID reset.
/// - Attendance history heatmap dialog per student and subject.
/// - One-tap Excel export via backend API.
class TeacherAnalyticsScreen extends StatefulWidget {
  const TeacherAnalyticsScreen({super.key});

  @override
  State<TeacherAnalyticsScreen> createState() => _TeacherAnalyticsScreenState();
}

class _TeacherAnalyticsScreenState extends State<TeacherAnalyticsScreen> {
  // Filter State
  String _selectedCourse = 'B.Tech';
  String? _selectedBranch = 'CSE';
  String _selectedYear = '1st';
  final TextEditingController _searchController = TextEditingController();

  // Data Options
  final List<String> _courses = ['B.Tech', 'Diploma', 'MCA', 'BCA'];
  final List<String> _branches = [
    'CSE',
    'CSE-AIML',
    'CSE-DS',
    'EE',
    'Civil',
    'Mech',
    'ECE'
  ];
  final List<String> _years = ['1st', '2nd', '3rd', '4th'];

  // State
  List<UserModel> _students = [];
  List<UserModel> _filteredStudents = [];
  bool _isLoading = false;
  bool _hasSearched = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchStudents() async {
    AppHaptics.lightImpact();
    setState(() {
      _isLoading = true;
      _hasSearched = true;
    });

    try {
      final loadedStudents = await TeacherAnalyticsService().getStudentsWithStats(
        course: _selectedCourse,
        branch: _selectedBranch,
        year: _selectedYear,
      );
      if (mounted) {
        setState(() {
          _students = loadedStudents;
          _filteredStudents = loadedStudents;
        });
        _filterStudents();
      }
    } catch (e) {
      debugPrint("TeacherAnalytics error: $e");
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _filterStudents() {
    final query = _searchController.text.trim().toLowerCase();
    if (query.isEmpty) {
      setState(() => _filteredStudents = _students);
    } else {
      setState(() {
        _filteredStudents = _students.where((s) {
          return s.name.toLowerCase().contains(query) ||
              (s.registrationNumber?.toLowerCase().contains(query) ?? false);
        }).toList();
      });
    }
  }

  Future<void> _resetDeviceId(String studentId) async {
    AppHaptics.mediumImpact();
    try {
      final success = await TeacherAnalyticsService().resetStudentDeviceId(studentId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              success ? "Device ID reset successfully." : "Failed to reset device ID.",
              style: GoogleFonts.plusJakartaSans(color: Colors.white),
            ),
            backgroundColor: success ? AppColors.success : AppColors.danger,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Error resetting ID: $e", style: GoogleFonts.plusJakartaSans(color: Colors.white)),
            backgroundColor: AppColors.danger,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _exportData() async {
    AppHaptics.lightImpact();
    final url = '${AppConfig.baseUrl}/export/attendance?course=$_selectedCourse&year=$_selectedYear';
    final uri = Uri.parse(url);

    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Could not open export URL: $url', style: GoogleFonts.plusJakartaSans()),
              backgroundColor: AppColors.danger,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Export error: $e', style: GoogleFonts.plusJakartaSans()),
            backgroundColor: AppColors.danger,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        bottom: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 120),
          physics: const AlwaysScrollableScrollPhysics(
            parent: BouncingScrollPhysics(),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(),
              const SizedBox(height: 16),
              _buildFilterCard(),
              if (_hasSearched && !_isLoading) ...[
                const SizedBox(height: 20),
                _buildAnalyticsSummary(),
                const SizedBox(height: 20),
                _buildStudentListHeader(),
                const SizedBox(height: 12),
                _buildStudentList(),
              ] else if (_isLoading) ...[
                const SizedBox(height: 60),
                const Center(
                  child: CircularProgressIndicator(
                    color: AppColors.primary,
                    strokeWidth: 2.5,
                  ),
                ),
              ] else ...[
                const SizedBox(height: 40),
                _buildEmptyState(),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Analytics".tr(context),
              style: GoogleFonts.plusJakartaSans(
                fontSize: 28,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
                letterSpacing: -0.8,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              "Cohort attendance & student risk tracking".tr(context),
              style: GoogleFonts.plusJakartaSans(
                fontSize: 13,
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.primary.withValues(alpha: 0.15)),
          ),
          child: const Icon(
            Icons.analytics_outlined,
            color: AppColors.primary,
            size: 22,
          ),
        ),
      ],
    );
  }

  Widget _buildFilterCard() {
    bool showBranch = _selectedCourse != 'BCA' && _selectedCourse != 'MCA';

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "FILTER COHORT".tr(context),
            style: GoogleFonts.plusJakartaSans(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: AppColors.textSecondary,
              letterSpacing: 1.0,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                flex: 2,
                child: _buildDropdown(
                  value: _selectedCourse,
                  items: _courses,
                  label: "Course".tr(context),
                  onChanged: (v) => setState(() => _selectedCourse = v!),
                ),
              ),
              const SizedBox(width: 8),
              if (showBranch) ...[
                Expanded(
                  flex: 2,
                  child: _buildDropdown(
                    value: _selectedBranch,
                    items: _branches,
                    label: "Branch".tr(context),
                    onChanged: (v) => setState(() => _selectedBranch = v!),
                  ),
                ),
                const SizedBox(width: 8),
              ],
              Expanded(
                flex: 2,
                child: _buildDropdown(
                  value: _selectedYear,
                  items: _years,
                  label: "Year".tr(context),
                  onChanged: (v) => setState(() => _selectedYear = v!),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            decoration: BoxDecoration(
              color: AppColors.bg,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                const Icon(Icons.search_rounded, size: 18, color: AppColors.textSecondary),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    onChanged: (val) => _filterStudents(),
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 13,
                      color: AppColors.textPrimary,
                    ),
                    decoration: InputDecoration(
                      hintText: "Search by student, reg no, or destination...".tr(context),
                      hintStyle: GoogleFonts.plusJakartaSans(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                      ),
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(vertical: 11),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _fetchStudents,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
              ),
              child: Text(
                "Apply Filters".tr(context),
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDropdown({
    required String? value,
    required List<String> items,
    required String label,
    required Function(String?) onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.bg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          isExpanded: true,
          dropdownColor: Colors.white,
          borderRadius: BorderRadius.circular(12),
          elevation: 4,
          icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 18, color: AppColors.textSecondary),
          style: GoogleFonts.plusJakartaSans(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w600,
            fontSize: 13,
          ),
          items: items.map((item) {
            return DropdownMenuItem(
              value: item,
              child: Text(
                item,
                style: GoogleFonts.plusJakartaSans(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            );
          }).toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }

  Widget _buildAnalyticsSummary() {
    if (_filteredStudents.isEmpty) return const SizedBox.shrink();

    double totalPerc = 0;
    int atRiskCount = 0;
    int highPerformersCount = 0;

    for (var s in _filteredStudents) {
      double p = s.attendancePercentage ?? 0.0;
      totalPerc += p;
      if (p < 75) atRiskCount++;
      if (p >= 90) highPerformersCount++;
    }

    double avg = totalPerc / _filteredStudents.length;

    return Row(
      children: [
        Expanded(
          child: _buildSummaryCard(
            "Average".tr(context),
            "${avg.toStringAsFixed(1)}%",
            Icons.speed_rounded,
            AppColors.primary,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _buildSummaryCard(
            ">= 90% High",
            "$highPerformersCount",
            Icons.verified_outlined,
            AppColors.success,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _buildSummaryCard(
            "< 75% At-Risk",
            "$atRiskCount",
            Icons.warning_amber_rounded,
            AppColors.danger,
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryCard(
      String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.2)),
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
                  fontSize: 11,
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Icon(icon, color: color, size: 16),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
              letterSpacing: -0.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStudentListHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          "${'Students'.tr(context)} (${_filteredStudents.length})",
          style: GoogleFonts.plusJakartaSans(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        GestureDetector(
          onTap: _exportData,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              children: [
                const Icon(Icons.file_download_outlined, size: 14, color: AppColors.primary),
                const SizedBox(width: 4),
                Text(
                  "Export Excel".tr(context),
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStudentList() {
    if (_filteredStudents.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 40),
          child: Column(
            children: [
              const Icon(Icons.search_off_rounded, size: 36, color: AppColors.textSecondary),
              const SizedBox(height: 8),
              Text(
                "No students match criteria",
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _filteredStudents.length,
      itemBuilder: (context, index) {
        final student = _filteredStudents[index];
        return _buildStudentCard(student, index);
      },
    );
  }

  Widget _buildStudentCard(UserModel student, int index) {
    final double attendance = student.attendancePercentage ?? 0.0;
    final bool isAtRisk = attendance < 75;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => _showStudentDetails(student),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 16,
                  backgroundColor: AppColors.primary.withValues(alpha: 0.08),
                  child: Text(
                    student.name.isNotEmpty ? student.name[0].toUpperCase() : '?',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        student.name,
                        style: GoogleFonts.plusJakartaSans(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      Text(
                        student.registrationNumber ?? "No Reg No",
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 11,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: (isAtRisk ? AppColors.danger : AppColors.success).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    "${attendance.toStringAsFixed(1)}%",
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: isAtRisk ? AppColors.danger : AppColors.success,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.phonelink_erase_rounded, size: 18, color: Colors.orange),
                  tooltip: "Reset Device ID",
                  onPressed: () => _confirmReset(student),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _confirmReset(UserModel student) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          "Reset Device ID?".tr(context),
          style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, fontSize: 16),
        ),
        content: Text(
          "Allow ${student.name} to bind and verify from a new mobile device?",
          style: GoogleFonts.plusJakartaSans(fontSize: 13, color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text("Cancel".tr(context), style: GoogleFonts.plusJakartaSans(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              _resetDeviceId(student.id);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.danger,
              foregroundColor: Colors.white,
              elevation: 0,
            ),
            child: Text("Reset".tr(context)),
          ),
        ],
      ),
    );
  }

  void _showStudentDetails(UserModel student) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            CircleAvatar(
              backgroundColor: AppColors.primary.withValues(alpha: 0.1),
              child: Text(
                student.name.isNotEmpty ? student.name[0].toUpperCase() : '?',
                style: GoogleFonts.plusJakartaSans(
                  color: AppColors.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    student.name,
                    style: GoogleFonts.plusJakartaSans(
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  Text(
                    student.registrationNumber ?? "N/A",
                    style: GoogleFonts.plusJakartaSans(fontSize: 12, color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildDialogStatRow("Attendance", "${student.attendancePercentage?.toStringAsFixed(1) ?? '0.0'}%"),
            const SizedBox(height: 8),
            _buildDialogStatRow("Course", "${student.course ?? '-'} • ${student.branch ?? '-'}"),
            const SizedBox(height: 16),
            const Divider(color: AppColors.border),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.phonelink_erase_rounded, size: 16, color: Colors.orange),
                    label: Text("Reset ID", style: GoogleFonts.plusJakartaSans(color: Colors.orange, fontSize: 12)),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Colors.orange),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: () {
                      Navigator.pop(context);
                      _confirmReset(student);
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.analytics_rounded, size: 16, color: Colors.white),
                    label: Text("History", style: GoogleFonts.plusJakartaSans(color: Colors.white, fontSize: 12)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: () {
                      Navigator.pop(context);
                      _showStudentHeatmap(student);
                    },
                  ),
                ),
              ],
            )
          ],
        ),
      ),
    );
  }

  void _showStudentHeatmap(UserModel student) {
    String? selectedSubject;
    List<dynamic>? heatmapData;
    bool isLoadingHeatmap = false;
    int totalClasses = 0;
    int attendedClasses = 0;
    bool hasSearched = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          Future<void> fetchHeatmap() async {
            if (selectedSubject == null) return;

            setDialogState(() {
              isLoadingHeatmap = true;
              hasSearched = true;
            });

            try {
              final data = await TeacherAnalyticsService().getStudentSubjectAnalytics(
                studentId: student.id,
                subject: selectedSubject!,
              );
              if (data != null) {
                setDialogState(() {
                  heatmapData = data['history'];
                  totalClasses = data['totalClasses'] ?? 0;
                  attendedClasses = data['attendedClasses'] ?? 0;
                });
              }
            } catch (e) {
              debugPrint(e.toString());
            }
            setDialogState(() => isLoadingHeatmap = false);
          }

          double percentage =
              totalClasses > 0 ? (attendedClasses / totalClasses) * 100 : 0.0;

          return AlertDialog(
            backgroundColor: AppColors.surface,
            surfaceTintColor: Colors.transparent,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  student.name,
                  style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                ),
                Text(
                  "Reg: ${student.registrationNumber ?? 'N/A'}",
                  style: GoogleFonts.plusJakartaSans(fontSize: 12, color: AppColors.textSecondary),
                ),
              ],
            ),
            content: SizedBox(
              width: double.maxFinite,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<String>(
                    initialValue: selectedSubject,
                    hint: Text("Select Subject", style: GoogleFonts.plusJakartaSans(color: AppColors.textSecondary)),
                    dropdownColor: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    style: GoogleFonts.plusJakartaSans(color: AppColors.textPrimary, fontWeight: FontWeight.w600, fontSize: 13),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: AppColors.bg,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    ),
                    isExpanded: true,
                    items: SyllabusData.getSubjects(_selectedCourse, _selectedBranch, _selectedYear)
                        .map((s) => DropdownMenuItem(
                              value: s,
                              child: Text(
                                s,
                                style: GoogleFonts.plusJakartaSans(
                                  color: AppColors.textPrimary,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                ),
                              ),
                            ))
                        .toList(),
                    onChanged: (val) {
                      setDialogState(() {
                        selectedSubject = val;
                        heatmapData = null;
                        hasSearched = false;
                      });
                    },
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: selectedSubject == null ? null : fetchHeatmap,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        elevation: 0,
                      ),
                      child: Text("Load Analytics", style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600)),
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (isLoadingHeatmap)
                    const Center(child: CircularProgressIndicator(color: AppColors.primary, strokeWidth: 2))
                  else if (heatmapData != null) ...[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildDialogStatCard("Total", totalClasses.toString(), AppColors.textPrimary),
                        _buildDialogStatCard("Attended", attendedClasses.toString(), AppColors.success),
                        _buildDialogStatCard(
                          "Rate",
                          "${percentage.toStringAsFixed(1)}%",
                          percentage < 75 ? AppColors.danger : AppColors.success,
                        ),
                      ],
                    ),
                  ] else if (hasSearched && heatmapData == null)
                    Text("Could not load data.", style: GoogleFonts.plusJakartaSans(color: AppColors.danger))
                  else
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Text(
                        "Select a subject and tap 'Load Analytics'",
                        textAlign: TextAlign.center,
                        style: GoogleFonts.plusJakartaSans(color: AppColors.textSecondary, fontSize: 12),
                      ),
                    ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text("Close", style: GoogleFonts.plusJakartaSans(color: AppColors.textSecondary)),
              )
            ],
          );
        },
      ),
    );
  }

  Widget _buildDialogStatCard(String title, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            title,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 11,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDialogStatRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: GoogleFonts.plusJakartaSans(
            color: AppColors.textSecondary,
            fontWeight: FontWeight.w500,
            fontSize: 13,
          ),
        ),
        Text(
          value,
          style: GoogleFonts.plusJakartaSans(
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
            fontSize: 13,
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.surface,
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.border),
            ),
            child: const Icon(
              Icons.analytics_outlined,
              size: 40,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            "Select Filters to Analyze".tr(context),
            style: GoogleFonts.plusJakartaSans(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            "Filter by course, branch, and year above\nto view student attendance percentages and risk indicators.",
            textAlign: TextAlign.center,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 13,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
