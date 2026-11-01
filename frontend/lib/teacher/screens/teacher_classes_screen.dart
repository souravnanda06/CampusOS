import 'package:flutter/material.dart';
import 'package:attendance_app/core/haptics/app_haptics.dart';

import 'package:google_fonts/google_fonts.dart';

import '../../auth/models/user_model.dart';
import '../../core/theme/app_colors.dart';
import '../../data/syllabus/syllabus_data.dart';
import '../../router/app_routes.dart';
import '../../core/localization/app_localizations.dart';

/// CampusOS Teacher Classes Screen with Apple-grade Visual Hierarchy.
///
/// Displays the teacher's assigned subjects, timetable batches, and sections.
/// Tapping a class opens the comprehensive [ClassDetailScreen].
/// Includes quick-start triggers to launch attendance directly from any class card.
class TeacherClassesScreen extends StatefulWidget {
  final UserModel? user;

  const TeacherClassesScreen({Key? key, this.user}) : super(key: key);

  @override
  State<TeacherClassesScreen> createState() => _TeacherClassesScreenState();
}

class _TeacherClassesScreenState extends State<TeacherClassesScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _selectedFilter = 'All';
  late List<Map<String, dynamic>> _allClasses;

  @override
  void initState() {
    super.initState();
    _allClasses = _getTeacherClasses();
  }

  @override
  void didUpdateWidget(covariant TeacherClassesScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.user != widget.user) {
      _allClasses = _getTeacherClasses();
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> _getTeacherClasses() {
    final branch = widget.user?.branch ?? 'CSE';
    final course = widget.user?.course ?? 'B.Tech';

    // Build real classes from SyllabusData
    final List<Map<String, dynamic>> classes = [];

    final y3Subjects = SyllabusData.getSubjects(course, branch, '3rd');
    final y2Subjects = SyllabusData.getSubjects(course, branch, '2nd');
    final y1Subjects = SyllabusData.getSubjects(course, branch, '1st');

    // Primary assigned subject from curriculum
    if (y3Subjects.isNotEmpty) {
      classes.add({
        'id': 'cls_ds',
        'name': y3Subjects.contains('Data Structures')
            ? 'Data Structures'
            : y3Subjects.first,
        'course': course,
        'branch': branch,
        'year': '3rd Year',
        'room': 'Room 204',
        'sections': 2,
        'studentsCount': 45,
        'schedule': '09:00 AM - 10:00 AM',
        'isToday': true,
        'icon': Icons.account_tree_outlined,
      });
    }

    if (y3Subjects.length > 1) {
      classes.add({
        'id': 'cls_dbms',
        'name': y3Subjects.contains('DBMS') ? 'DBMS' : y3Subjects[1],
        'course': course,
        'branch': branch,
        'year': '3rd Year',
        'room': 'Room 301',
        'sections': 2,
        'studentsCount': 42,
        'schedule': '11:15 AM - 12:15 PM',
        'isToday': true,
        'icon': Icons.storage_outlined,
      });
    }

    if (y2Subjects.isNotEmpty) {
      classes.add({
        'id': 'cls_os',
        'name': y2Subjects.first,
        'course': course,
        'branch': branch,
        'year': '2nd Year',
        'room': 'Lab 2',
        'sections': 1,
        'studentsCount': 38,
        'schedule': '02:00 PM - 03:00 PM',
        'isToday': false,
        'icon': Icons.terminal_rounded,
      });
    }

    if (y1Subjects.isNotEmpty) {
      classes.add({
        'id': 'cls_prog',
        'name': y1Subjects.last,
        'course': course,
        'branch': branch,
        'year': '1st Year',
        'room': 'Room 105',
        'sections': 3,
        'studentsCount': 50,
        'schedule': 'Tomorrow, 10:00 AM',
        'isToday': false,
        'icon': Icons.code_rounded,
      });
    }

    return classes;
  }

  @override
  Widget build(BuildContext context) {
    final allClasses = _allClasses;
    final query = _searchController.text.trim().toLowerCase();

    final filtered = allClasses.where((c) {
      final matchesSearch = query.isEmpty ||
          c['name'].toString().toLowerCase().contains(query) ||
          c['room'].toString().toLowerCase().contains(query) ||
          c['year'].toString().toLowerCase().contains(query);

      if (!matchesSearch) return false;

      if (_selectedFilter == 'Today') {
        return c['isToday'] == true;
      }
      return true;
    }).toList();

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        bottom: false,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(
            parent: BouncingScrollPhysics(),
          ),
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Classes'.tr(context),
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 28,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary,
                                letterSpacing: -0.8,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Active teaching assignments'.tr(context),
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 13,
                                color: AppColors.textSecondary,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: AppColors.primary.withValues(alpha: 0.15),
                            ),
                          ),
                          child: Text(
                            '${allClasses.length} ${'Subjects'.tr(context)}',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppColors.primary,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    RepaintBoundary(
                      child: _buildSearchBar(),
                    ),
                    const SizedBox(height: 14),
                    _buildFilterPills(),
                  ],
                ),
              ),
            ),
            if (filtered.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: _buildEmptyState(),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 120),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final item = filtered[index];
                      return RepaintBoundary(
                        child: _buildClassCard(item),
                      );
                    },
                    childCount: filtered.length,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: [
          const Icon(Icons.search_rounded, size: 20, color: AppColors.textSecondary),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: _searchController,
              onChanged: (_) => setState(() {}),
              style: GoogleFonts.plusJakartaSans(
                fontSize: 14,
                color: AppColors.textPrimary,
              ),
              decoration: InputDecoration(
                hintText: 'Search subjects, rooms, years...'.tr(context),
                hintStyle: GoogleFonts.plusJakartaSans(
                  fontSize: 14,
                  color: AppColors.textSecondary.withValues(alpha: 0.8),
                ),
                border: InputBorder.none,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
          if (_searchController.text.isNotEmpty)
            GestureDetector(
              onTap: () {
                _searchController.clear();
                setState(() {});
              },
              child: const Icon(Icons.close_rounded, size: 18, color: AppColors.textSecondary),
            ),
        ],
      ),
    );
  }

  Widget _buildFilterPills() {
    final filters = ['All', 'Today', 'Upcoming'];

    return Row(
      children: filters.map((f) {
        final isSelected = _selectedFilter == f;
        return Padding(
          padding: const EdgeInsets.only(right: 8),
          child: GestureDetector(
            onTap: () {
              AppHaptics.selectionClick();
              setState(() => _selectedFilter = f);
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
              decoration: BoxDecoration(
                color: isSelected ? AppColors.textPrimary : AppColors.surface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isSelected ? AppColors.textPrimary : AppColors.border,
                ),
              ),
              child: Text(
                f.tr(context),
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                  color: isSelected ? Colors.white : AppColors.textSecondary,
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildClassCard(Map<String, dynamic> item) {
    final isToday = item['isToday'] == true;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isToday ? AppColors.primary.withValues(alpha: 0.25) : AppColors.border,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () {
            AppHaptics.lightImpact();
            Navigator.pushNamed(
              context,
              AppRoutes.teacherClassDetail,
              arguments: {
                'subject': item['name'],
                'subjectName': item['name'],
                'name': item['name'],
                'course': item['course'],
                'branch': item['branch'],
                'year': item['year'],
                'room': item['room'],
                'user': widget.user,
              },
            );
          },
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        item['icon'] as IconData? ?? Icons.class_outlined,
                        size: 20,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item['name'] as String,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                              letterSpacing: -0.3,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${item['course']} ${item['branch']} · ${item['year']}',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (isToday)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.success.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          'TODAY',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: AppColors.success,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppColors.bg,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.meeting_room_outlined, size: 14, color: AppColors.textSecondary),
                      const SizedBox(width: 4),
                      Text(
                        item['room'] as String,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(width: 14),
                      const Icon(Icons.schedule_rounded, size: 14, color: AppColors.textSecondary),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          item['schedule'] as String,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: AppColors.textSecondary,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '${item['sections']} Sections · ~${item['studentsCount']} Students',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    ElevatedButton(
                      onPressed: () {
                        AppHaptics.lightImpact();
                        Navigator.pushNamed(
                          context,
                          AppRoutes.teacherCreateSession,
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        textStyle: GoogleFonts.plusJakartaSans(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('Start Attendance'),
                          SizedBox(width: 4),
                          Icon(Icons.arrow_forward_rounded, size: 14),
                        ],
                      ),
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

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: AppColors.surface,
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.border),
              ),
              child: const Icon(
                Icons.menu_book_outlined,
                size: 36,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'No classes found'.tr(context),
              style: GoogleFonts.plusJakartaSans(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Try adjusting your search query or filter.'.tr(context),
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
