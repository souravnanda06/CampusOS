import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../../core/haptics/app_haptics.dart';
import '../../../auth/providers/user_provider.dart';
import '../../../core/models/expansion_models.dart';
import '../../../core/services/expansion_api_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/motion/apple_bounceable.dart';
import '../../../shared/widgets/motion/apple_spring_scroll_physics.dart';

class HostelRequestsSection extends StatefulWidget {
  const HostelRequestsSection({Key? key}) : super(key: key);

  @override
  State<HostelRequestsSection> createState() => _HostelRequestsSectionState();
}

class _HostelRequestsSectionState extends State<HostelRequestsSection> {
  final ExpansionApiService _api = ExpansionApiService.instance;
  HostelAllocationModel? _room;
  List<HostelRequestModel> _requests = [];
  List<AssetIssueModel> _assetIssues = [];
  bool _isLoading = true;
  String? _error;
  int _activeView = 0; // 0: Requests, 1: Asset Issues

  @override
  void initState() {
    super.initState();
    _loadHostelData();
  }

  Future<void> _loadHostelData() async {
    final studentId =
        Provider.of<UserProvider>(context, listen: false).user?.id;
    if (studentId == null || studentId.isEmpty) {
      setState(() => _isLoading = false);
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final results = await Future.wait([
        _api.getMyRoom(studentId),
        _api.getMyHostelRequests(studentId),
        _api.getMyAssetIssues(studentId),
      ]);

      if (mounted) {
        setState(() {
          _room = results[0] as HostelAllocationModel?;
          _requests = results[1] as List<HostelRequestModel>;
          _assetIssues = results[2] as List<AssetIssueModel>;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString().replaceAll('Exception: ', '');
          _isLoading = false;
        });
      }
    }
  }

  InputDecoration _buildSheetInputDecoration(BuildContext context, String label, {String? hint}) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      labelStyle: GoogleFonts.plusJakartaSans(
        color: AppColors.textSecondaryOf(context),
        fontSize: 13.5,
        fontWeight: FontWeight.w500,
      ),
      hintStyle: GoogleFonts.plusJakartaSans(
        color: AppColors.textTertiaryOf(context),
        fontSize: 13,
      ),
      filled: true,
      fillColor: AppColors.surfaceAltOf(context),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(
          color: AppColors.borderOf(context).withValues(alpha: 0.6),
          width: 0.5,
        ),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(
          color: AppColors.borderOf(context).withValues(alpha: 0.6),
          width: 0.5,
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
      ),
    );
  }

  void _showRoomChangeDialog() {
    final studentId =
        Provider.of<UserProvider>(context, listen: false).user?.id;
    if (studentId == null) return;

    final hostelController = TextEditingController();
    final blockController = TextEditingController();
    final reasonController = TextEditingController();
    String selectedRoomType = 'DOUBLE';
    bool isSubmitting = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setSheetState) {
          return Container(
            padding: EdgeInsets.only(
              left: 20,
              right: 20,
              top: 12,
              bottom: MediaQuery.of(context).viewInsets.bottom + 24,
            ),
            decoration: BoxDecoration(
              color: AppColors.surfaceOf(context),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.12),
                  blurRadius: 24,
                  offset: const Offset(0, -4),
                ),
              ],
            ),
            child: SingleChildScrollView(
              physics: const AppleSpringScrollPhysics(),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 36,
                      height: 5,
                      decoration: BoxDecoration(
                        color: AppColors.borderOf(context),
                        borderRadius: BorderRadius.circular(2.5),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Request Room Change",
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                              color: AppColors.textPrimaryOf(context),
                              letterSpacing: -0.4,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            "Submit relocation preferences for warden review",
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: AppColors.textSecondaryOf(context),
                            ),
                          ),
                        ],
                      ),
                      AppleBounceable(
                        scaleFactor: 0.90,
                        onTap: () {
                          AppHaptics.selectionClick();
                          Navigator.pop(ctx);
                        },
                        child: Container(
                          width: 34,
                          height: 34,
                          decoration: BoxDecoration(
                            color: AppColors.surfaceAltOf(context),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: AppColors.borderOf(context).withValues(alpha: 0.6),
                              width: 0.5,
                            ),
                          ),
                          child: Icon(
                            Icons.close_rounded,
                            size: 18,
                            color: AppColors.textSecondaryOf(context),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Text(
                    "PREFERRED HOSTEL & BLOCK",
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textSecondaryOf(context),
                      letterSpacing: 0.8,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: hostelController,
                          style: GoogleFonts.plusJakartaSans(color: AppColors.textPrimaryOf(context), fontSize: 13.5),
                          decoration: _buildSheetInputDecoration(context, "Hostel", hint: "e.g. Ganga Hostel"),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextField(
                          controller: blockController,
                          style: GoogleFonts.plusJakartaSans(color: AppColors.textPrimaryOf(context), fontSize: 13.5),
                          decoration: _buildSheetInputDecoration(context, "Block", hint: "e.g. Block B"),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  Text(
                    "ROOM SHARING TYPE",
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textSecondaryOf(context),
                      letterSpacing: 0.8,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: AppColors.borderOf(context).withValues(alpha: 0.6),
                        width: 0.5,
                      ),
                      borderRadius: BorderRadius.circular(16),
                      color: AppColors.surfaceAltOf(context),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: selectedRoomType,
                        isExpanded: true,
                        dropdownColor: AppColors.surfaceOf(context),
                        icon: const Icon(Icons.expand_more_rounded, color: AppColors.primary, size: 20),
                        items: const [
                          DropdownMenuItem(value: 'SINGLE', child: Text('Single Room')),
                          DropdownMenuItem(value: 'DOUBLE', child: Text('Double Sharing')),
                          DropdownMenuItem(value: 'TRIPLE', child: Text('Triple Sharing')),
                        ],
                        onChanged: (val) {
                          if (val != null) {
                            AppHaptics.selectionClick();
                            setSheetState(() => selectedRoomType = val);
                          }
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    "REASON FOR ROOM CHANGE",
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textSecondaryOf(context),
                      letterSpacing: 0.8,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: reasonController,
                    maxLines: 3,
                    style: GoogleFonts.plusJakartaSans(color: AppColors.textPrimaryOf(context), fontSize: 14, height: 1.4),
                    decoration: _buildSheetInputDecoration(
                      context,
                      "Reason",
                      hint: "e.g. Medical grounds, academic focus, roommate alignment...",
                    ),
                  ),
                  const SizedBox(height: 28),
                  AppleBounceable(
                    scaleFactor: 0.96,
                    onTap: isSubmitting
                        ? null
                        : () async {
                            final reason = reasonController.text.trim();
                            if (reason.isEmpty) {
                              AppHaptics.mediumImpact();
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    'Please provide a reason for the room change.',
                                    style: GoogleFonts.plusJakartaSans(color: Colors.white),
                                  ),
                                  backgroundColor: AppColors.danger,
                                  behavior: SnackBarBehavior.floating,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                              );
                              return;
                            }

                            final messenger = ScaffoldMessenger.of(context);
                            final navigator = Navigator.of(ctx);
                            AppHaptics.lightImpact();
                            setSheetState(() => isSubmitting = true);
                            try {
                              await _api.createHostelRequest(
                                studentId: studentId,
                                requestType: 'ROOM_CHANGE',
                                preferredHostel: hostelController.text.trim(),
                                preferredBlock: blockController.text.trim(),
                                preferredRoomType: selectedRoomType,
                                reason: reason,
                              );
                              if (mounted) {
                                AppHaptics.lightImpact();
                                navigator.pop();
                                _loadHostelData();
                                messenger.showSnackBar(
                                  SnackBar(
                                    content: Row(
                                      children: [
                                        const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: Text(
                                            'Room change request submitted to Warden',
                                            style: GoogleFonts.plusJakartaSans(color: Colors.white, fontWeight: FontWeight.w600),
                                          ),
                                        ),
                                      ],
                                    ),
                                    backgroundColor: AppColors.emerald,
                                    behavior: SnackBarBehavior.floating,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  ),
                                );
                              }
                            } catch (e) {
                              AppHaptics.mediumImpact();
                              setSheetState(() => isSubmitting = false);
                              messenger.showSnackBar(
                                SnackBar(
                                  content: Text('Error: $e'),
                                  backgroundColor: AppColors.danger,
                                  behavior: SnackBarBehavior.floating,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                              );
                            }
                          },
                    child: Container(
                      width: double.infinity,
                      height: 52,
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primary.withValues(alpha: 0.28),
                            blurRadius: 14,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Center(
                        child: isSubmitting
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(strokeWidth: 2.2, color: Colors.white),
                              )
                            : Text(
                                "Submit Room Change",
                                style: GoogleFonts.plusJakartaSans(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 15,
                                  color: Colors.white,
                                  letterSpacing: -0.2,
                                ),
                              ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _showReportAssetIssueDialog() {
    final studentId =
        Provider.of<UserProvider>(context, listen: false).user?.id;
    if (studentId == null) return;

    String selectedAssetType = 'STUDY_TABLE';
    String selectedIssue = 'BROKEN';
    String selectedUrgency = 'MEDIUM';
    final descController = TextEditingController();
    bool isSubmitting = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setSheetState) {
          return Container(
            padding: EdgeInsets.only(
              left: 20,
              right: 20,
              top: 12,
              bottom: MediaQuery.of(context).viewInsets.bottom + 24,
            ),
            decoration: BoxDecoration(
              color: AppColors.surfaceOf(context),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.12),
                  blurRadius: 24,
                  offset: const Offset(0, -4),
                ),
              ],
            ),
            child: SingleChildScrollView(
              physics: const AppleSpringScrollPhysics(),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 36,
                      height: 5,
                      decoration: BoxDecoration(
                        color: AppColors.borderOf(context),
                        borderRadius: BorderRadius.circular(2.5),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Report Asset Issue",
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                              color: AppColors.textPrimaryOf(context),
                              letterSpacing: -0.4,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            "Notify hostel warden of damaged inventory",
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: AppColors.textSecondaryOf(context),
                            ),
                          ),
                        ],
                      ),
                      AppleBounceable(
                        scaleFactor: 0.90,
                        onTap: () {
                          AppHaptics.selectionClick();
                          Navigator.pop(ctx);
                        },
                        child: Container(
                          width: 34,
                          height: 34,
                          decoration: BoxDecoration(
                            color: AppColors.surfaceAltOf(context),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: AppColors.borderOf(context).withValues(alpha: 0.6),
                              width: 0.5,
                            ),
                          ),
                          child: Icon(
                            Icons.close_rounded,
                            size: 18,
                            color: AppColors.textSecondaryOf(context),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Text(
                    "ROOM ASSET ITEM",
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textSecondaryOf(context),
                      letterSpacing: 0.8,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: AppColors.borderOf(context).withValues(alpha: 0.6),
                        width: 0.5,
                      ),
                      borderRadius: BorderRadius.circular(16),
                      color: AppColors.surfaceAltOf(context),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: selectedAssetType,
                        isExpanded: true,
                        dropdownColor: AppColors.surfaceOf(context),
                        icon: const Icon(Icons.expand_more_rounded, color: AppColors.primary, size: 20),
                        items: const [
                          DropdownMenuItem(value: 'STUDY_TABLE', child: Text('Study Table')),
                          DropdownMenuItem(value: 'CHAIR', child: Text('Chair')),
                          DropdownMenuItem(value: 'BED_FRAME', child: Text('Bed Frame / Cot')),
                          DropdownMenuItem(value: 'WARDROBE', child: Text('Almirah / Wardrobe')),
                          DropdownMenuItem(value: 'FAN', child: Text('Ceiling Fan')),
                          DropdownMenuItem(value: 'LIGHT_TUBE', child: Text('Room Lighting / Tube')),
                          DropdownMenuItem(value: 'SWITCH_BOARD', child: Text('Electrical Switchboard')),
                        ],
                        onChanged: (val) {
                          if (val != null) {
                            AppHaptics.selectionClick();
                            setSheetState(() => selectedAssetType = val);
                          }
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "ISSUE NATURE",
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textSecondaryOf(context),
                                letterSpacing: 0.8,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                              decoration: BoxDecoration(
                                border: Border.all(
                                  color: AppColors.borderOf(context).withValues(alpha: 0.6),
                                  width: 0.5,
                                ),
                                borderRadius: BorderRadius.circular(16),
                                color: AppColors.surfaceAltOf(context),
                              ),
                              child: DropdownButtonHideUnderline(
                                child: DropdownButton<String>(
                                  value: selectedIssue,
                                  isExpanded: true,
                                  dropdownColor: AppColors.surfaceOf(context),
                                  icon: const Icon(Icons.expand_more_rounded, color: AppColors.primary, size: 18),
                                  items: const [
                                    DropdownMenuItem(value: 'BROKEN', child: Text('Broken')),
                                    DropdownMenuItem(value: 'MALFUNCTIONING', child: Text('Malfunctioning')),
                                    DropdownMenuItem(value: 'MISSING', child: Text('Missing')),
                                  ],
                                  onChanged: (val) {
                                    if (val != null) {
                                      AppHaptics.selectionClick();
                                      setSheetState(() => selectedIssue = val);
                                    }
                                  },
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "SEVERITY",
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textSecondaryOf(context),
                                letterSpacing: 0.8,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                              decoration: BoxDecoration(
                                border: Border.all(
                                  color: AppColors.borderOf(context).withValues(alpha: 0.6),
                                  width: 0.5,
                                ),
                                borderRadius: BorderRadius.circular(16),
                                color: AppColors.surfaceAltOf(context),
                              ),
                              child: DropdownButtonHideUnderline(
                                child: DropdownButton<String>(
                                  value: selectedUrgency,
                                  isExpanded: true,
                                  dropdownColor: AppColors.surfaceOf(context),
                                  icon: const Icon(Icons.expand_more_rounded, color: AppColors.primary, size: 18),
                                  items: const [
                                    DropdownMenuItem(value: 'LOW', child: Text('Low')),
                                    DropdownMenuItem(value: 'MEDIUM', child: Text('Medium')),
                                    DropdownMenuItem(value: 'HIGH', child: Text('High')),
                                    DropdownMenuItem(value: 'CRITICAL', child: Text('Critical')),
                                  ],
                                  onChanged: (val) {
                                    if (val != null) {
                                      AppHaptics.selectionClick();
                                      setSheetState(() => selectedUrgency = val);
                                    }
                                  },
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  Text(
                    "DESCRIPTION OF PROBLEM",
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textSecondaryOf(context),
                      letterSpacing: 0.8,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: descController,
                    maxLines: 3,
                    style: GoogleFonts.plusJakartaSans(color: AppColors.textPrimaryOf(context), fontSize: 14, height: 1.4),
                    decoration: _buildSheetInputDecoration(
                      context,
                      "Description",
                      hint: "Describe the damage or dysfunction...",
                    ),
                  ),
                  const SizedBox(height: 28),
                  AppleBounceable(
                    scaleFactor: 0.96,
                    onTap: isSubmitting
                        ? null
                        : () async {
                            final desc = descController.text.trim();
                            if (desc.isEmpty) {
                              AppHaptics.mediumImpact();
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    'Please describe the asset issue.',
                                    style: GoogleFonts.plusJakartaSans(color: Colors.white),
                                  ),
                                  backgroundColor: AppColors.danger,
                                  behavior: SnackBarBehavior.floating,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                              );
                              return;
                            }

                            final messenger = ScaffoldMessenger.of(context);
                            final navigator = Navigator.of(ctx);
                            AppHaptics.lightImpact();
                            setSheetState(() => isSubmitting = true);
                            try {
                              await _api.reportAssetIssue(
                                studentId: studentId,
                                assetName: selectedAssetType,
                                issueType: selectedIssue,
                                description: desc,
                                urgency: selectedUrgency,
                              );
                              if (mounted) {
                                AppHaptics.lightImpact();
                                navigator.pop();
                                _loadHostelData();
                                messenger.showSnackBar(
                                  SnackBar(
                                    content: Row(
                                      children: [
                                        const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: Text(
                                            'Asset issue reported to Warden & Maintenance',
                                            style: GoogleFonts.plusJakartaSans(color: Colors.white, fontWeight: FontWeight.w600),
                                          ),
                                        ),
                                      ],
                                    ),
                                    backgroundColor: AppColors.emerald,
                                    behavior: SnackBarBehavior.floating,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  ),
                                );
                              }
                            } catch (e) {
                              AppHaptics.mediumImpact();
                              setSheetState(() => isSubmitting = false);
                              messenger.showSnackBar(
                                SnackBar(
                                  content: Text('Error: $e'),
                                  backgroundColor: AppColors.danger,
                                  behavior: SnackBarBehavior.floating,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                              );
                            }
                          },
                    child: Container(
                      width: double.infinity,
                      height: 52,
                      decoration: BoxDecoration(
                        color: const Color(0xFFD97706),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFD97706).withValues(alpha: 0.28),
                            blurRadius: 14,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Center(
                        child: isSubmitting
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(strokeWidth: 2.2, color: Colors.white),
                              )
                            : Text(
                                "Submit Asset Report",
                                style: GoogleFonts.plusJakartaSans(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 15,
                                  color: Colors.white,
                                  letterSpacing: -0.2,
                                ),
                              ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadHostelData,
      color: AppColors.primary,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
        physics: AppleSpringScrollPhysics.always,
        children: [
          _buildCurrentRoomCard(),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: AppleBounceable(
                  scaleFactor: 0.95,
                  onTap: () {
                    AppHaptics.lightImpact();
                    _showRoomChangeDialog();
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 11),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceOf(context),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: AppColors.primary.withValues(alpha: 0.4),
                        width: 1.0,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.02),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.swap_horiz_rounded, size: 16, color: AppColors.primary),
                        const SizedBox(width: 6),
                        Text(
                          "Room Change",
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                            color: AppColors.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: AppleBounceable(
                  scaleFactor: 0.95,
                  onTap: () {
                    AppHaptics.lightImpact();
                    _showReportAssetIssueDialog();
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 11),
                    decoration: BoxDecoration(
                      color: const Color(0xFFD97706),
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFD97706).withValues(alpha: 0.25),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.handyman_rounded, size: 16, color: Colors.white),
                        const SizedBox(width: 6),
                        Text(
                          "Report Asset",
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),

          // Sliding capsule segmented switcher
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: AppColors.surfaceAltOf(context),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: AppColors.borderOf(context).withValues(alpha: 0.6),
                width: 0.5,
              ),
            ),
            child: Row(
              children: [
                Expanded(child: _buildViewTab(0, "Room Requests", _requests.length)),
                Expanded(child: _buildViewTab(1, "Asset Issues", _assetIssues.length)),
              ],
            ),
          ),
          const SizedBox(height: 16),
          if (_error != null)
            Container(
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: AppColors.danger.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppColors.danger.withValues(alpha: 0.3),
                  width: 0.5,
                ),
              ),
              child: Text(
                _error!,
                style: GoogleFonts.plusJakartaSans(
                  color: AppColors.danger,
                  fontSize: 13,
                ),
              ),
            ),
          if (_activeView == 0) ...[
            if (_requests.isEmpty)
              _buildEmptyHostelState(
                "No Room Requests",
                "You have no pending or past room change or allocation requests.",
              )
            else
              ..._requests.map((r) => _buildRequestCard(r)),
          ] else ...[
            if (_assetIssues.isEmpty)
              _buildEmptyHostelState(
                "No Reported Asset Issues",
                "All your room inventory is in verified working condition.",
              )
            else
              ..._assetIssues.map((issue) => _buildAssetIssueCard(issue)),
          ],
        ],
      ),
    );
  }

  Widget _buildViewTab(int index, String title, int count) {
    final isSelected = _activeView == index;
    return AppleBounceable(
      scaleFactor: 0.96,
      onTap: () {
        AppHaptics.selectionClick();
        setState(() => _activeView = index);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.surfaceOf(context) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: isSelected
              ? Border.all(
                  color: AppColors.borderOf(context).withValues(alpha: 0.4),
                  width: 0.5,
                )
              : null,
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              title,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12.5,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                color: isSelected ? AppColors.textPrimaryOf(context) : AppColors.textSecondaryOf(context),
              ),
            ),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1.5),
              decoration: BoxDecoration(
                color: isSelected
                    ? AppColors.primary.withValues(alpha: 0.12)
                    : AppColors.borderOf(context).withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                "$count",
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: isSelected ? AppColors.primary : AppColors.textSecondaryOf(context),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCurrentRoomCard() {
    if (_room == null) {
      return Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: AppColors.surfaceOf(context),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: AppColors.borderOf(context).withValues(alpha: 0.7),
            width: 0.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.surfaceAltOf(context),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(Icons.hotel_rounded, size: 28, color: AppColors.textSecondaryOf(context)),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "No Hostel Room Allocated",
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimaryOf(context),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    "Contact the hostel warden or administration office for room allocation.",
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12,
                      color: AppColors.textSecondaryOf(context),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1E1B4B), Color(0xFF312E81)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1E1B4B).withValues(alpha: 0.28),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
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
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.apartment_rounded, color: Color(0xFF818CF8), size: 18),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    _room!.hostelName,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 16.5,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      letterSpacing: -0.3,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3.5),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.2),
                    width: 0.5,
                  ),
                ),
                child: Text(
                  _room!.status,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    letterSpacing: 0.3,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _buildRoomMetaPill("Block", _room!.block),
              const SizedBox(width: 8),
              _buildRoomMetaPill("Room", _room!.roomNumber),
              const SizedBox(width: 8),
              _buildRoomMetaPill("Bed", _room!.bedLabel),
              const SizedBox(width: 8),
              _buildRoomMetaPill("Sharing", _room!.roomType),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRoomMetaPill(String label, String value) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.08),
            width: 0.5,
          ),
        ),
        child: Column(
          children: [
            Text(
              label,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 10,
                color: Colors.white.withValues(alpha: 0.7),
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              value,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyHostelState(String title, String subtitle) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 20),
      decoration: BoxDecoration(
        color: AppColors.surfaceOf(context),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppColors.borderOf(context).withValues(alpha: 0.7),
          width: 0.5,
        ),
      ),
      child: Column(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Center(
              child: Icon(Icons.inbox_outlined, size: 32, color: AppColors.primary),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            title,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimaryOf(context),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 12.5,
              color: AppColors.textSecondaryOf(context),
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRequestCard(HostelRequestModel req) {
    Color statusColor;
    switch (req.status.toUpperCase()) {
      case 'APPROVED':
        statusColor = AppColors.emerald;
        break;
      case 'REJECTED':
        statusColor = AppColors.danger;
        break;
      case 'IN_REVIEW':
        statusColor = AppColors.warning;
        break;
      default:
        statusColor = const Color(0xFF6B7280);
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surfaceOf(context),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppColors.borderOf(context).withValues(alpha: 0.7),
          width: 0.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 3),
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
                req.requestType.replaceAll('_', ' '),
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimaryOf(context),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3.5),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  req.status,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: statusColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            req.reason,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 13,
              color: AppColors.textSecondaryOf(context),
              height: 1.4,
            ),
          ),
          if (req.wardenRemarks != null && req.wardenRemarks!.isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: statusColor.withValues(alpha: 0.2),
                  width: 0.5,
                ),
              ),
              child: Row(
                children: [
                  Icon(Icons.rate_review_outlined, size: 14, color: statusColor),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      "Warden: ${req.wardenRemarks}",
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: statusColor,
                      ),
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

  Widget _buildAssetIssueCard(AssetIssueModel issue) {
    Color urgencyColor;
    switch (issue.urgency.toUpperCase()) {
      case 'CRITICAL':
      case 'HIGH':
        urgencyColor = AppColors.danger;
        break;
      case 'MEDIUM':
        urgencyColor = const Color(0xFFD97706);
        break;
      default:
        urgencyColor = const Color(0xFF6B7280);
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surfaceOf(context),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppColors.borderOf(context).withValues(alpha: 0.7),
          width: 0.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
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
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: const Color(0xFFD97706).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.build_circle_outlined, color: Color(0xFFD97706), size: 16),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    (issue.assetName ?? 'Asset').replaceAll('_', ' '),
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimaryOf(context),
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3.5),
                decoration: BoxDecoration(
                  color: urgencyColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  issue.urgency,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w800,
                    color: urgencyColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            issue.description,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 13,
              color: AppColors.textSecondaryOf(context),
              height: 1.4,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Text(
                "Issue: ${issue.issueType}",
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondaryOf(context),
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: (issue.status == 'RESOLVED' ? AppColors.emerald : AppColors.primary).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  issue.status,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: issue.status == 'RESOLVED'
                        ? AppColors.emerald
                        : AppColors.primary,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
