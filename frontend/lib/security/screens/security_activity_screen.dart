import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../auth/models/user_model.dart';
import '../../core/theme/app_colors.dart';
import '../models/gate_security_models.dart';
import '../services/security_gate_pass_service.dart';

/// Gate Security Activity Timeline.
/// Displays audit events with filtering by operation and result.
class SecurityActivityScreen extends StatefulWidget {
  final UserModel user;

  const SecurityActivityScreen({Key? key, required this.user}) : super(key: key);

  @override
  State<SecurityActivityScreen> createState() => _SecurityActivityScreenState();
}

class _SecurityActivityScreenState extends State<SecurityActivityScreen> {
  final SecurityGatePassService _gateService = SecurityGatePassService();

  String _selectedFilter = 'ALL';
  String _searchQuery = '';
  List<GateActivityItem> _activities = [];
  bool _isLoading = true;

  final List<Map<String, String>> _filters = [
    {'label': 'All', 'value': 'ALL'},
    {'label': 'Exits', 'value': 'EXITS'},
    {'label': 'Returns', 'value': 'RETURNS'},
    {'label': 'Failed', 'value': 'FAILED'},
    {'label': 'Duplicate', 'value': 'DUPLICATE'},
    {'label': 'Offline', 'value': 'OFFLINE'},
  ];

  @override
  void initState() {
    super.initState();
    _loadActivity();
  }

  Future<void> _loadActivity() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final list = await _gateService.fetchActivity(filter: _selectedFilter);
      if (mounted) {
        setState(() {
          _activities = list;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  List<GateActivityItem> get _filteredActivities {
    if (_searchQuery.isEmpty) return _activities;
    final q = _searchQuery.toLowerCase();
    return _activities.where((a) {
      return a.studentName.toLowerCase().contains(q) ||
          a.registrationNumber.toLowerCase().contains(q) ||
          (a.passId?.toLowerCase().contains(q) ?? false) ||
          a.remarks.toLowerCase().contains(q);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final displayList = _filteredActivities;

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text(
          "Gate Transit Activity",
          style: GoogleFonts.plusJakartaSans(
            fontSize: 17,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
      ),
      body: Column(
        children: [
          // Filter Chips & Search
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: Column(
              children: [
                TextField(
                  onChanged: (val) {
                    setState(() {
                      _searchQuery = val.trim();
                    });
                  },
                  decoration: InputDecoration(
                    hintText: "Search student, reg no, pass ID...",
                    hintStyle: GoogleFonts.plusJakartaSans(fontSize: 13, color: AppColors.textSecondary),
                    prefixIcon: const Icon(Icons.search_rounded, size: 20, color: AppColors.textSecondary),
                    filled: true,
                    fillColor: AppColors.surface,
                    contentPadding: const EdgeInsets.symmetric(vertical: 10),
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
                const SizedBox(height: 12),
                SizedBox(
                  height: 36,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: _filters.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 8),
                    itemBuilder: (ctx, i) {
                      final f = _filters[i];
                      final isSelected = _selectedFilter == f['value'];
                      return ChoiceChip(
                        label: Text(f['label']!),
                        selected: isSelected,
                        labelStyle: GoogleFonts.plusJakartaSans(
                          fontSize: 12,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                          color: isSelected ? Colors.white : AppColors.textPrimary,
                        ),
                        selectedColor: AppColors.primary,
                        backgroundColor: AppColors.surface,
                        side: BorderSide(
                          color: isSelected ? AppColors.primary : AppColors.border,
                        ),
                        onSelected: (selected) {
                          if (selected) {
                            setState(() {
                              _selectedFilter = f['value']!;
                            });
                            _loadActivity();
                          }
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),

          // Timeline List
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : displayList.isEmpty
                    ? Center(
                        child: Text(
                          "No gate activity found for this filter.",
                          style: GoogleFonts.plusJakartaSans(
                            color: AppColors.textSecondary,
                            fontSize: 14,
                          ),
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _loadActivity,
                        child: ListView.separated(
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
                          itemCount: displayList.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 10),
                          itemBuilder: (ctx, i) {
                            final act = displayList[i];
                            return _buildActivityCard(act);
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildActivityCard(GateActivityItem act) {
    Color iconColor;
    IconData iconData;

    if (act.operation == 'EXIT') {
      iconColor = AppColors.success;
      iconData = Icons.logout_rounded;
    } else if (act.operation == 'RETURN') {
      iconColor = const Color(0xFF8B5CF6);
      iconData = Icons.login_rounded;
    } else if (act.result == 'FAILED') {
      iconColor = AppColors.error;
      iconData = Icons.cancel_rounded;
    } else if (act.result == 'DUPLICATE') {
      iconColor = const Color(0xFFF59E0B);
      iconData = Icons.replay_rounded;
    } else {
      iconColor = AppColors.primary;
      iconData = Icons.shield_outlined;
    }

    return Container(
      padding: const EdgeInsets.all(16),
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
              color: iconColor.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(iconData, color: iconColor, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      act.studentName,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    Text(
                      DateFormat('hh:mm a').format(act.timestamp),
                      style: GoogleFonts.jetBrainsMono(
                        fontSize: 11,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  "Reg: ${act.registrationNumber} • Pass: #${act.passId?.substring(0, 8) ?? 'N/A'}",
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
                if (act.remarks.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    act.remarks,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
                const SizedBox(height: 8),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Text(
                        act.verificationMode,
                        style: GoogleFonts.jetBrainsMono(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      "Staff: ${act.staffName}",
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
  }
}
