import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../auth/models/user_model.dart';
import '../../core/theme/app_colors.dart';
import '../../student/models/gate_pass_model.dart';
import '../services/security_gate_pass_service.dart';
import '../widgets/visitor_pass_verify_sheet.dart';
import '../../core/localization/app_localizations.dart';

/// Operational Gate Passes List Screen.
/// Filters: All, Issued (Active), Exited (Outside Campus), Returned, Expired.
/// Allows inspection of transit details.
/// Strictly blocks leave approval/rejection.
class SecurityPassesScreen extends StatefulWidget {
  final UserModel user;

  const SecurityPassesScreen({Key? key, required this.user}) : super(key: key);

  @override
  State<SecurityPassesScreen> createState() => _SecurityPassesScreenState();
}

class _SecurityPassesScreenState extends State<SecurityPassesScreen> {
  final SecurityGatePassService _gateService = SecurityGatePassService();

  String _selectedFilter = 'ALL';
  String _searchQuery = '';
  List<GatePassModel> _passes = [];
  bool _isLoading = true;

  final List<Map<String, String>> _filters = [
    {'label': 'All', 'value': 'ALL'},
    {'label': 'Active / Issued', 'value': 'ISSUED'},
    {'label': 'Outside Campus', 'value': 'EXITED'},
    {'label': 'Returned', 'value': 'RETURNED'},
    {'label': 'Expired', 'value': 'EXPIRED'},
  ];

  @override
  void initState() {
    super.initState();
    _loadPasses();
  }

  Future<void> _loadPasses() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final list = await _gateService.fetchGatePasses(
        status: _selectedFilter == 'ALL' ? null : _selectedFilter,
        search: _searchQuery.isEmpty ? null : _searchQuery,
      );
      if (mounted) {
        setState(() {
          _passes = list;
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

  void _showPassDetails(GatePassModel pass) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          padding: EdgeInsets.only(
            left: 24,
            right: 24,
            top: 24,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 28,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 44,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    "Pass Inspection",
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  _buildStatusBadge(pass.status),
                ],
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  children: [
                    _buildInspectionRow("Student Name", pass.studentName ?? "Student (${pass.studentId.substring(0, 8)})"),
                    const Divider(height: 14, color: AppColors.border),
                    _buildInspectionRow("Registration No", pass.registrationNumber ?? "N/A"),
                    const Divider(height: 14, color: AppColors.border),
                    _buildInspectionRow("Pass ID", pass.id),
                    const Divider(height: 14, color: AppColors.border),
                    _buildInspectionRow("Destination", pass.destination),
                    const Divider(height: 14, color: AppColors.border),
                    _buildInspectionRow("Reason", pass.reason),
                    const Divider(height: 14, color: AppColors.border),
                    _buildInspectionRow("Valid From", DateFormat('MMM dd, hh:mm a').format(pass.expectedExitTime)),
                    const Divider(height: 14, color: AppColors.border),
                    _buildInspectionRow("Valid Until", DateFormat('MMM dd, hh:mm a').format(pass.expectedReturnTime)),
                    if (pass.actualExitTime != null) ...[
                      const Divider(height: 14, color: AppColors.border),
                      _buildInspectionRow("Actual Exit", DateFormat('MMM dd, hh:mm a').format(pass.actualExitTime!)),
                    ],
                    if (pass.actualReturnTime != null) ...[
                      const Divider(height: 14, color: AppColors.border),
                      _buildInspectionRow("Actual Return", DateFormat('MMM dd, hh:mm a').format(pass.actualReturnTime!)),
                    ],
                    const Divider(height: 14, color: AppColors.border),
                    _buildInspectionRow("Gate Terminal", pass.gateName ?? 'Main Gate'),
                    const Divider(height: 14, color: AppColors.border),
                    _buildInspectionRow("Verification Mode", pass.verificationMode ?? 'QR_FALLBACK'),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.surface,
                  foregroundColor: AppColors.textPrimary,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  elevation: 0,
                  side: const BorderSide(color: AppColors.border),
                ),
                onPressed: () => Navigator.pop(ctx),
                child: const Text("Close"),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildInspectionRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 12.5,
            color: AppColors.textSecondary,
          ),
        ),
        const Spacer(),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 12.5,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStatusBadge(String status) {
    Color bg;
    Color text;

    switch (status.toUpperCase()) {
      case 'ISSUED':
        bg = AppColors.success.withValues(alpha: 0.12);
        text = AppColors.success;
        break;
      case 'EXITED':
        bg = const Color(0xFFF59E0B).withValues(alpha: 0.12);
        text = const Color(0xFFD97706);
        break;
      case 'RETURNED':
        bg = const Color(0xFF8B5CF6).withValues(alpha: 0.12);
        text = const Color(0xFF7C3AED);
        break;
      case 'EXPIRED':
        bg = AppColors.error.withValues(alpha: 0.12);
        text = AppColors.error;
        break;
      default:
        bg = AppColors.textSecondary.withValues(alpha: 0.12);
        text = AppColors.textSecondary;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        status.toUpperCase(),
        style: GoogleFonts.jetBrainsMono(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: text,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text(
          "Operational Gate Passes".tr(context),
          style: GoogleFonts.plusJakartaSans(
            fontSize: 17,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
        actions: [
          TextButton.icon(
            onPressed: () {
              VisitorPassVerifySheet.show(context, guardId: widget.user.id);
            },
            icon: const Icon(Icons.badge_rounded, color: Color(0xFFD97706), size: 18),
            label: Text(
              "Visitor Pass".tr(context),
              style: GoogleFonts.plusJakartaSans(
                fontWeight: FontWeight.bold,
                color: const Color(0xFFD97706),
                fontSize: 13,
              ),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          // Search & Filter Bar
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: Column(
              children: [
                TextField(
                  onChanged: (val) {
                    _searchQuery = val.trim();
                    _loadPasses();
                  },
                  decoration: InputDecoration(
                    hintText: "Search by student, reg no, or destination...".tr(context),
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
                        label: Text((f['label']!).tr(context)),
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
                            _loadPasses();
                          }
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),

          // Passes List
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _passes.isEmpty
                    ? Center(
                        child: Text(
                          "No gate passes found for this filter.",
                          style: GoogleFonts.plusJakartaSans(
                            color: AppColors.textSecondary,
                            fontSize: 14,
                          ),
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _loadPasses,
                        child: ListView.separated(
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
                          itemCount: _passes.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 10),
                          itemBuilder: (ctx, i) {
                            final pass = _passes[i];
                            return InkWell(
                              onTap: () => _showPassDetails(pass),
                              borderRadius: BorderRadius.circular(16),
                              child: Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: Colors.white,
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
                                          pass.studentName ?? "Student (${pass.studentId.substring(0, 8)})",
                                          style: GoogleFonts.plusJakartaSans(
                                            fontSize: 15,
                                            fontWeight: FontWeight.bold,
                                            color: AppColors.textPrimary,
                                          ),
                                        ),
                                        _buildStatusBadge(pass.status),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      "Reg: ${pass.registrationNumber ?? 'N/A'} • #${pass.id.substring(0, 8)}",
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 12,
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Row(
                                      children: [
                                        const Icon(Icons.location_on_outlined, size: 16, color: AppColors.primary),
                                        const SizedBox(width: 4),
                                        Expanded(
                                          child: Text(
                                            pass.destination,
                                            style: GoogleFonts.plusJakartaSans(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w600,
                                              color: AppColors.textPrimary,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 6),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          "Return by: ${DateFormat('MMM dd, hh:mm a').format(pass.expectedReturnTime)}",
                                          style: GoogleFonts.plusJakartaSans(
                                            fontSize: 11.5,
                                            color: AppColors.textSecondary,
                                          ),
                                        ),
                                        const Icon(
                                          Icons.arrow_forward_ios_rounded,
                                          size: 14,
                                          color: AppColors.textSecondary,
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          VisitorPassVerifySheet.show(context, guardId: widget.user.id);
        },
        backgroundColor: const Color(0xFFD97706),
        foregroundColor: Colors.white,
        icon: const Icon(Icons.qr_code_scanner_rounded),
        label: Text(
          "Verify Visitor",
          style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}
