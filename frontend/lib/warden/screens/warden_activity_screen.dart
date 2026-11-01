import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../auth/models/user_model.dart';
import '../../core/theme/app_colors.dart';
import '../models/warden_models.dart';
import '../services/warden_service.dart';

class WardenActivityScreen extends StatefulWidget {
  final UserModel user;

  const WardenActivityScreen({Key? key, required this.user}) : super(key: key);

  @override
  State<WardenActivityScreen> createState() => _WardenActivityScreenState();
}

class _WardenActivityScreenState extends State<WardenActivityScreen> {
  final WardenService _wardenService = WardenService();
  List<WardenActivityModel> _activities = [];
  bool _isLoading = true;
  String _selectedFilter = 'ALL';

  final List<String> _filters = ['ALL', 'LEAVE', 'GATE_PASS'];

  @override
  void initState() {
    super.initState();
    _loadActivity();
  }

  Future<void> _loadActivity() async {
    setState(() => _isLoading = true);
    final list = await _wardenService.fetchActivity(
      filter: _selectedFilter == 'ALL' ? null : _selectedFilter,
      wardenId: widget.user.id,
    );
    if (mounted) {
      setState(() {
        _activities = list;
        _isLoading = false;
      });
    }
  }

  Color _getActionColor(String action) {
    switch (action.toUpperCase()) {
      case 'APPROVE':
      case 'APPROVED':
      case 'ISSUED':
        return AppColors.success;
      case 'REJECT':
      case 'REJECTED':
      case 'CANCELLED':
        return AppColors.error;
      case 'EXITED':
      case 'EXIT':
        return const Color(0xFF007AFF);
      case 'RETURNED':
      case 'RETURN':
        return const Color(0xFF34C759);
      default:
        return AppColors.primary;
    }
  }

  IconData _getActionIcon(String entityType, String action) {
    if (entityType == 'GATE_PASS') {
      if (action.contains('EXIT')) return Icons.output_rounded;
      if (action.contains('RETURN')) return Icons.input_rounded;
      return Icons.shield_outlined;
    } else {
      if (action.contains('APPROVE')) return Icons.check_circle_rounded;
      if (action.contains('REJECT')) return Icons.cancel_rounded;
      return Icons.assignment_outlined;
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
          'Warden Audit & Activity Log',
          style: GoogleFonts.plusJakartaSans(
            fontWeight: FontWeight.bold,
            fontSize: 17,
            color: AppColors.textPrimary,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: AppColors.textSecondary),
            onPressed: _loadActivity,
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: Container(
            height: 48,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _filters.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final filter = _filters[index];
                final isSelected = filter == _selectedFilter;
                return ChoiceChip(
                  label: Text(
                    filter == 'ALL'
                        ? 'All Events'
                        : filter == 'LEAVE'
                            ? 'Leave Reviews'
                            : 'Gate Transit',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                      color: isSelected ? Colors.white : AppColors.textPrimary,
                    ),
                  ),
                  selected: isSelected,
                  selectedColor: AppColors.primary,
                  backgroundColor: AppColors.bg,
                  side: BorderSide(
                    color: isSelected ? AppColors.primary : AppColors.border,
                  ),
                  onSelected: (selected) {
                    if (selected) {
                      setState(() => _selectedFilter = filter);
                      _loadActivity();
                    }
                  },
                );
              },
            ),
          ),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _loadActivity,
        color: AppColors.primary,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _activities.isEmpty
                ? ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(32),
                    children: [
                      const SizedBox(height: 60),
                      Center(
                        child: Icon(
                          Icons.history_toggle_off_rounded,
                          size: 48,
                          color: AppColors.textSecondary.withValues(alpha: 0.4),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Center(
                        child: Text(
                          'No Activity Recorded Yet',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                    ],
                  )
                : ListView.builder(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(16),
                    itemCount: _activities.length + 1,
                    itemBuilder: (context, index) {
                      if (index == _activities.length) {
                        return const SizedBox(height: 80);
                      }
                      final act = _activities[index];
                      final color = _getActionColor(act.action);
                      final icon = _getActionIcon(act.entityType, act.action);

                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: color.withValues(alpha: 0.1),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(icon, size: 20, color: color),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        "${act.entityType}: ${act.action}",
                                        style: GoogleFonts.plusJakartaSans(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14,
                                          color: color,
                                        ),
                                      ),
                                      Text(
                                        act.timestamp.split('T').first,
                                        style: GoogleFonts.plusJakartaSans(
                                          fontSize: 11,
                                          color: AppColors.textSecondary,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  if (act.studentName != null) ...[
                                    Text(
                                      "Student: ${act.studentName} (${act.registrationNumber ?? 'N/A'})",
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.textPrimary,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                  ],
                                  if (act.destination != null) ...[
                                    Text(
                                      "Destination: ${act.destination}",
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 12,
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                  ],
                                  if (act.remarks.isNotEmpty)
                                    Text(
                                      "Remarks: ${act.remarks}",
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 12,
                                        fontStyle: FontStyle.italic,
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      const Icon(Icons.person_outline, size: 12, color: AppColors.textSecondary),
                                      const SizedBox(width: 4),
                                      Text(
                                        "Actor: ${act.actorName} (${act.actorRole})",
                                        style: GoogleFonts.plusJakartaSans(
                                          fontSize: 11,
                                          color: AppColors.textSecondary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
      ),
    );
  }
}
