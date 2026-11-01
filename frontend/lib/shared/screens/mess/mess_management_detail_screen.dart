import 'package:flutter/material.dart';
import 'package:attendance_app/core/haptics/app_haptics.dart';

import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../../auth/models/user_model.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/text_styles.dart';
import '../../../router/app_routes.dart';
import '../../../student/widgets/mess/meal_card.dart';
import '../../models/mess_model.dart';
import '../../services/mess_service.dart';

class MessManagementDetailScreen extends StatefulWidget {
  final UserModel user;
  final MessMenu menu;
  final MessService? messService;

  const MessManagementDetailScreen({
    Key? key,
    required this.user,
    required this.menu,
    this.messService,
  }) : super(key: key);

  @override
  State<MessManagementDetailScreen> createState() =>
      _MessManagementDetailScreenState();
}

class _MessManagementDetailScreenState
    extends State<MessManagementDetailScreen> {
  late final MessService _messService;

  late MessMenu _menu;
  bool _isLoading = false;
  bool _hasModified = false;

  @override
  void initState() {
    super.initState();
    _messService = widget.messService ?? MessService();
    _menu = widget.menu;
    _refreshMenu();
  }

  Future<void> _refreshMenu() async {
    setState(() => _isLoading = true);
    try {
      final updated = await _messService.getAdminMenuById(
        _menu.id,
        requesterId: widget.user.id,
      );
      if (mounted) {
        setState(() {
          _menu = updated;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _publishMenu() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Publish Menu?',
          style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold),
        ),
        content: Text(
          'This will publish the menu for ${_menu.formattedDate} and make it immediately visible to students.\n\nOnly one menu can be active per date.',
          style: GoogleFonts.plusJakartaSans(fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text('Publish'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isLoading = true);

    try {
      final updated = await _messService.publishMenu(
        _menu.id,
        requesterId: widget.user.id,
      );
      if (mounted) {
        AppHaptics.mediumImpact();
        setState(() {
          _menu = updated;
          _hasModified = true;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Menu published successfully!'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        AppHaptics.heavyImpact();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(MessService.sanitizeError(e)),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _archiveMenu() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Archive Mess Menu?',
          style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold),
        ),
        content: Text(
          'Archiving this menu removes it from the active student feed. It becomes an immutable historical record and cannot be edited or published again.',
          style: GoogleFonts.plusJakartaSans(fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.danger,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text('Archive'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isLoading = true);

    try {
      final updated = await _messService.archiveMenu(
        _menu.id,
        requesterId: widget.user.id,
      );
      if (mounted) {
        AppHaptics.mediumImpact();
        setState(() {
          _menu = updated;
          _hasModified = true;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Menu archived.'),
            backgroundColor: AppColors.textPrimary,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        AppHaptics.heavyImpact();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(MessService.sanitizeError(e)),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Widget _buildStatusChip(String status) {
    Color color;
    IconData icon;
    String text;

    switch (status.toUpperCase()) {
      case 'PUBLISHED':
        color = AppColors.success;
        icon = Icons.check_circle_outline_rounded;
        text = 'Published';
        break;
      case 'DRAFT':
        color = AppColors.warning;
        icon = Icons.edit_note_rounded;
        text = 'Draft';
        break;
      case 'ARCHIVED':
      default:
        color = AppColors.textSecondary;
        icon = Icons.archive_outlined;
        text = 'Archived';
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 5),
          Text(
            text,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        Navigator.pop(context, _hasModified);
      },
      child: Scaffold(
        backgroundColor: AppColors.bg,
        appBar: AppBar(
          title: Text('Menu Detail', style: AppTextStyles.h3),
          backgroundColor: AppColors.surface,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded,
                color: AppColors.textPrimary, size: 20),
            onPressed: () => Navigator.pop(context, _hasModified),
          ),
          actions: [
            if (_menu.isDraft)
              IconButton(
                icon: const Icon(Icons.edit_outlined, color: AppColors.primary),
                tooltip: 'Edit Draft',
                onPressed: () async {
                  final result = await Navigator.pushNamed(
                    context,
                    AppRoutes.messComposer,
                    arguments: {
                      'user': widget.user,
                      'menu': _menu,
                    },
                  );
                  if (result == true) {
                    _hasModified = true;
                    _refreshMenu();
                  }
                },
              ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded,
                color: AppColors.textSecondary),
            tooltip: 'Refresh',
            onPressed: _refreshMenu,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primary))
          : SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header card with date and status
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: AppColors.border),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.02),
                          blurRadius: 10,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              "Date",
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textSecondary,
                              ),
                            ),
                            _buildStatusChip(_menu.status),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _menu.formattedDate,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 12),
                        const Divider(height: 1, color: AppColors.border),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            const Icon(Icons.access_time_rounded,
                                size: 14, color: AppColors.textSecondary),
                            const SizedBox(width: 6),
                            Text(
                              _menu.updatedAt != null
                                  ? "Last Modified: ${DateFormat('d MMM yyyy, h:mm a').format(_menu.updatedAt!)}"
                                  : "Created: ${_menu.createdAt != null ? DateFormat('d MMM yyyy, h:mm a').format(_menu.createdAt!) : _menu.menuDate}",
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 12,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Status info notice
                  if (_menu.isPublished)
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppColors.success.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                            color: AppColors.success.withValues(alpha: 0.25)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.info_outline_rounded,
                              size: 18, color: AppColors.success),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              "This menu is currently PUBLISHED and active in student feeds.",
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: AppColors.success,
                              ),
                            ),
                          ),
                        ],
                      ),
                    )
                  else if (_menu.isArchived)
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceAlt,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.archive_outlined,
                              size: 18, color: AppColors.textSecondary),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              "Archived menus are immutable historical records. They cannot be edited or published.",
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 12,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                  const SizedBox(height: 20),

                  // Section Title
                  Text(
                    "Configured Meals (${_menu.meals.length})",
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Meal Cards
                  if (_menu.meals.isNotEmpty)
                    ..._menu.meals.map((meal) {
                      return MealCard(meal: meal);
                    }).toList()
                  else
                    Container(
                      padding: const EdgeInsets.all(24),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Text(
                        "No meals configured in this menu.",
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 14,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),

                  const SizedBox(height: 24),

                  // Lifecycle Action Buttons
                  if (_menu.isDraft) ...[
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () async {
                              final result = await Navigator.pushNamed(
                                context,
                                AppRoutes.messComposer,
                                arguments: {
                                  'user': widget.user,
                                  'menu': _menu,
                                },
                              );
                              if (result == true) {
                                _hasModified = true;
                                _refreshMenu();
                              }
                            },
                            icon: const Icon(Icons.edit_outlined, size: 16),
                            label: const Text("Edit Draft"),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.primary,
                              side: const BorderSide(color: AppColors.primary),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _publishMenu,
                            icon: const Icon(Icons.publish_rounded, size: 16),
                            label: const Text("Publish"),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              elevation: 0,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: TextButton.icon(
                        onPressed: _archiveMenu,
                        icon: const Icon(Icons.archive_outlined,
                            size: 16, color: AppColors.danger),
                        label: Text(
                          "Archive Draft",
                          style: GoogleFonts.plusJakartaSans(
                            color: AppColors.danger,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ] else if (_menu.isPublished) ...[
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _archiveMenu,
                        icon: const Icon(Icons.archive_outlined, size: 18),
                        label: const Text("Archive Menu"),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.danger,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 0,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
      ),
    );
  }
}
