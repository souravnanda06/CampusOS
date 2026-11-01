import 'package:flutter/material.dart';
import 'package:attendance_app/core/haptics/app_haptics.dart';

import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../../auth/models/user_model.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/text_styles.dart';
import '../../../router/app_routes.dart';
import '../../models/mess_model.dart';
import '../../services/mess_service.dart';

class MessManagementScreen extends StatefulWidget {
  final UserModel user;
  final MessService? messService;

  const MessManagementScreen({Key? key, required this.user, this.messService})
      : super(key: key);

  @override
  State<MessManagementScreen> createState() => _MessManagementScreenState();
}

class _MessManagementScreenState extends State<MessManagementScreen>
    with SingleTickerProviderStateMixin {
  late final MessService _messService;

  late TabController _tabController;
  List<MessMenu> _menus = [];
  bool _isLoading = true;
  String? _error;
  DateTime? _filterDate;

  bool get _isAuthorized {
    final role = widget.user.role.toLowerCase().trim();
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
    if (_isAuthorized) {
      _loadMenus();
    } else {
      _isLoading = false;
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadMenus() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final dateStr = _filterDate != null
          ? DateFormat('yyyy-MM-dd').format(_filterDate!)
          : null;

      final menus = await _messService.getAdminMenus(
        date: dateStr,
        requesterId: widget.user.id,
      );

      // Deterministic sort: newest menuDate first
      menus.sort((a, b) {
        final dateA = DateTime.tryParse(a.menuDate) ?? DateTime(1970);
        final dateB = DateTime.tryParse(b.menuDate) ?? DateTime(1970);
        final cmp = dateB.compareTo(dateA);
        if (cmp != 0) return cmp;
        return (b.createdAt ?? DateTime(1970))
            .compareTo(a.createdAt ?? DateTime(1970));
      });

      if (mounted) {
        setState(() {
          _menus = menus;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = MessService.sanitizeError(e);
          _isLoading = false;
        });
      }
    }
  }

  List<MessMenu> _getFilteredMenus(int tabIndex) {
    switch (tabIndex) {
      case 0:
        return _menus; // All
      case 1:
        return _menus.where((m) => m.isDraft).toList(); // Drafts
      case 2:
        return _menus.where((m) => m.isPublished).toList(); // Published
      case 3:
        return _menus.where((m) => m.isArchived).toList(); // Archived
      default:
        return _menus;
    }
  }

  Future<void> _pickFilterDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _filterDate ?? DateTime.now(),
      firstDate: DateTime(2025, 1, 1),
      lastDate: DateTime(2030, 12, 31),
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
        _filterDate = picked;
      });
      _loadMenus();
    }
  }

  void _clearFilterDate() {
    setState(() {
      _filterDate = null;
    });
    _loadMenus();
  }

  Widget _buildStatusBadge(String status) {
    Color badgeColor;
    IconData badgeIcon;
    String badgeText;

    switch (status.toUpperCase()) {
      case 'PUBLISHED':
        badgeColor = AppColors.success;
        badgeIcon = Icons.check_circle_outline_rounded;
        badgeText = 'Published';
        break;
      case 'DRAFT':
        badgeColor = AppColors.warning;
        badgeIcon = Icons.edit_note_rounded;
        badgeText = 'Draft';
        break;
      case 'ARCHIVED':
      default:
        badgeColor = AppColors.textSecondary;
        badgeIcon = Icons.archive_outlined;
        badgeText = 'Archived';
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: badgeColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: badgeColor.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(badgeIcon, size: 12, color: badgeColor),
          const SizedBox(width: 4),
          Text(
            badgeText,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: badgeColor,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_isAuthorized) {
      return Scaffold(
        backgroundColor: AppColors.bg,
        appBar: AppBar(
          title: Text('Mess Management', style: AppTextStyles.h3),
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
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: AppColors.danger.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.security_rounded,
                      size: 40, color: AppColors.danger),
                ),
                const SizedBox(height: 20),
                Text(
                  "Access Restricted",
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  "Mess management requires Staff, Warden, or Administrator privileges. Teachers and students are not permitted to manage menus.",
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
                  child: const Text("Go Back"),
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
        title: Text('Mess Management', style: AppTextStyles.h3),
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
            icon: const Icon(Icons.analytics_outlined,
                color: AppColors.primary, size: 24),
            tooltip: 'Feedback Analytics',
            onPressed: () {
              Navigator.pushNamed(
                context,
                AppRoutes.messFeedback,
                arguments: widget.user,
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.calendar_today_rounded,
                color: AppColors.textSecondary, size: 20),
            tooltip: 'Filter by Date',
            onPressed: _pickFilterDate,
          ),
          IconButton(
            icon: const Icon(Icons.add_rounded,
                color: AppColors.primary, size: 26),
            tooltip: 'Create Menu',
            onPressed: () async {
              AppHaptics.lightImpact();
              final result = await Navigator.pushNamed(
                context,
                AppRoutes.messComposer,
                arguments: {'user': widget.user},
              );
              if (result == true) {
                _loadMenus();
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded,
                color: AppColors.textSecondary),
            tooltip: 'Refresh',
            onPressed: _loadMenus,
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
            Tab(text: 'All'),
            Tab(text: 'Drafts'),
            Tab(text: 'Published'),
            Tab(text: 'Archived'),
          ],
        ),
      ),
      body: Column(
        children: [
          if (_filterDate != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: AppColors.surface,
              child: Row(
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.primaryLight,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Text(
                          "Date: ${DateFormat('d MMM yyyy').format(_filterDate!)}",
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppColors.primary,
                          ),
                        ),
                        const SizedBox(width: 6),
                        GestureDetector(
                          onTap: _clearFilterDate,
                          child: const Icon(Icons.close_rounded,
                              size: 14, color: AppColors.primary),
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: _clearFilterDate,
                    child: Text(
                      "Clear Filter",
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(color: AppColors.primary))
                : _error != null
                    ? _buildErrorView()
                    : TabBarView(
                        controller: _tabController,
                        children: [
                          _buildMenuList(_getFilteredMenus(0)),
                          _buildMenuList(_getFilteredMenus(1)),
                          _buildMenuList(_getFilteredMenus(2)),
                          _buildMenuList(_getFilteredMenus(3)),
                        ],
                      ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          AppHaptics.lightImpact();
          final result = await Navigator.pushNamed(
            context,
            AppRoutes.messComposer,
            arguments: {'user': widget.user},
          );
          if (result == true) {
            _loadMenus();
          }
        },
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded),
        label: Text(
          "New Menu",
          style: GoogleFonts.plusJakartaSans(
            fontWeight: FontWeight.bold,
            letterSpacing: 0.2,
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
            const SizedBox(height: 16),
            Text(
              "Failed to Load Menus",
              style: GoogleFonts.plusJakartaSans(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _error ?? 'An unexpected error occurred.',
              textAlign: TextAlign.center,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 13,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 18),
            ElevatedButton(
              onPressed: _loadMenus,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: const Text("Retry"),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuList(List<MessMenu> menus) {
    if (menus.isEmpty) {
      return RefreshIndicator(
        onRefresh: _loadMenus,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            SizedBox(height: MediaQuery.of(context).size.height * 0.15),
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.border),
                    ),
                    child: const Icon(Icons.restaurant_menu_rounded,
                        size: 32, color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    "No Menus Found",
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _filterDate != null
                        ? "No menus match the selected date."
                        : "Tap 'New Menu' to create your first mess menu.",
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: _loadMenus,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 88),
        itemCount: menus.length,
        itemBuilder: (context, index) {
          final menu = menus[index];
          return _buildMenuManagementCard(menu);
        },
      ),
    );
  }

  Widget _buildMenuManagementCard(MessMenu menu) {
    final mealTypes = menu.meals.map((m) => m.mealType).join(' • ');

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: () async {
            AppHaptics.lightImpact();
            final result = await Navigator.pushNamed(
              context,
              AppRoutes.messDetail,
              arguments: {
                'user': widget.user,
                'menu': menu,
              },
            );
            if (result == true) {
              _loadMenus();
            }
          },
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      menu.formattedDate,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    _buildStatusBadge(menu.status),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.dining_outlined,
                        size: 15, color: AppColors.textSecondary),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        menu.meals.isNotEmpty
                            ? "${menu.meals.length} Meals: $mealTypes"
                            : "No meals configured",
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: menu.meals.isNotEmpty
                              ? AppColors.textPrimary
                              : AppColors.danger,
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
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      menu.updatedAt != null
                          ? "Updated: ${DateFormat('d MMM, h:mm a').format(menu.updatedAt!)}"
                          : "Created: ${menu.createdAt != null ? DateFormat('d MMM').format(menu.createdAt!) : menu.menuDate}",
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    Row(
                      children: [
                        Text(
                          "Manage",
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primary,
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Icon(Icons.arrow_forward_ios_rounded,
                            size: 11, color: AppColors.primary),
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
