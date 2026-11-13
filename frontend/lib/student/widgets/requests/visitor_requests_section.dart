import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../auth/providers/user_provider.dart';
import '../../../core/models/expansion_models.dart';
import '../../../core/services/expansion_api_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/haptics/app_haptics.dart';
import '../../../shared/widgets/motion/apple_bounceable.dart';
import '../../../shared/widgets/motion/apple_spring_scroll_physics.dart';
import '../passport/visitor_pass_sheet.dart';

class VisitorRequestsSection extends StatefulWidget {
  const VisitorRequestsSection({Key? key}) : super(key: key);

  @override
  State<VisitorRequestsSection> createState() => _VisitorRequestsSectionState();
}

class _VisitorRequestsSectionState extends State<VisitorRequestsSection> {
  final ExpansionApiService _api = ExpansionApiService.instance;
  List<VisitorRequestModel> _passes = [];
  VisitorRequestModel? _activePass;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadVisitorData();
  }

  Future<void> _loadVisitorData() async {
    final studentId =
        Provider.of<UserProvider>(context, listen: false).user?.id;
    if (studentId == null || studentId.isEmpty) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    if (mounted) {
      setState(() {
        _isLoading = true;
        _error = null;
      });
    }

    try {
      final results = await Future.wait([
        _api.getMyVisitorRequests(studentId),
        _api.getActiveVisitorPass(studentId),
      ]);

      if (mounted) {
        setState(() {
          _passes = results[0] as List<VisitorRequestModel>;
          _activePass = results[1] as VisitorRequestModel?;
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

  void _showNewVisitorPassDialog() {
    AppHaptics.lightImpact();
    final studentId =
        Provider.of<UserProvider>(context, listen: false).user?.id;
    if (studentId == null) return;

    final nameController = TextEditingController();
    final phoneController = TextEditingController();
    final purposeController = TextEditingController();
    String selectedRelation = 'Parent';
    DateTime selectedDate = DateTime.now();
    TimeOfDay entryTime = const TimeOfDay(hour: 16, minute: 0);
    TimeOfDay exitTime = const TimeOfDay(hour: 20, minute: 0);
    bool isSubmitting = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setSheetState) {
          final isDark = Theme.of(context).brightness == Brightness.dark;
          final surfaceColor = AppColors.surfaceOf(context);
          final bgColor = AppColors.bgOf(context);
          final borderColor = AppColors.borderOf(context);
          final textColor = AppColors.textPrimaryOf(context);
          final textSec = AppColors.textSecondaryOf(context);

          return Container(
            padding: EdgeInsets.only(
              left: 20,
              right: 20,
              top: 14,
              bottom: MediaQuery.of(context).viewInsets.bottom + 28,
            ),
            decoration: BoxDecoration(
              color: surfaceColor,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.4 : 0.12),
                  blurRadius: 24,
                  offset: const Offset(0, -6),
                ),
              ],
            ),
            child: SingleChildScrollView(
              physics: AppleSpringScrollPhysics.always,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // iOS Grabber pill
                  Center(
                    child: Container(
                      width: 36,
                      height: 5,
                      decoration: BoxDecoration(
                        color: borderColor,
                        borderRadius: BorderRadius.circular(2.5),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Header with dismiss button
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "Request Visitor Pass",
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: textColor,
                                letterSpacing: -0.4,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              "Gate access credentials verified by campus security.",
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 13,
                                color: textSec,
                              ),
                            ),
                          ],
                        ),
                      ),
                      AppleBounceable(
                        onTap: () => Navigator.pop(ctx),
                        child: Container(
                          width: 34,
                          height: 34,
                          decoration: BoxDecoration(
                            color: bgColor,
                            shape: BoxShape.circle,
                            border: Border.all(color: borderColor, width: 0.6),
                          ),
                          child: Icon(Icons.close_rounded,
                              size: 18, color: textSec),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Group: Visitor Details
                  _buildFormSectionHeader("VISITOR DETAILS", textSec),
                  const SizedBox(height: 8),

                  TextField(
                    controller: nameController,
                    style: GoogleFonts.plusJakartaSans(
                        fontSize: 14, color: textColor),
                    decoration: InputDecoration(
                      labelText: "Visitor Full Name",
                      hintText: "e.g. Ramesh Kumar Sharma",
                      labelStyle: GoogleFonts.plusJakartaSans(
                          fontSize: 13, color: textSec),
                      hintStyle: GoogleFonts.plusJakartaSans(
                          fontSize: 13, color: textSec.withValues(alpha: 0.6)),
                      prefixIcon: const Icon(Icons.person_outline_rounded,
                          size: 20, color: Color(0xFFD97706)),
                      filled: true,
                      fillColor: bgColor,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide(color: borderColor, width: 0.6),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide(color: borderColor, width: 0.6),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: const BorderSide(
                            color: Color(0xFFD97706), width: 1.5),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 14),
                    ),
                  ),
                  const SizedBox(height: 12),

                  Row(
                    children: [
                      Expanded(
                        flex: 6,
                        child: TextField(
                          controller: phoneController,
                          keyboardType: TextInputType.phone,
                          style: GoogleFonts.plusJakartaSans(
                              fontSize: 14, color: textColor),
                          decoration: InputDecoration(
                            labelText: "Phone Number",
                            hintText: "9876543210",
                            labelStyle: GoogleFonts.plusJakartaSans(
                                fontSize: 13, color: textSec),
                            hintStyle: GoogleFonts.plusJakartaSans(
                                fontSize: 13,
                                color: textSec.withValues(alpha: 0.6)),
                            prefixIcon: const Icon(Icons.phone_outlined,
                                size: 18, color: Color(0xFFD97706)),
                            filled: true,
                            fillColor: bgColor,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide:
                                  BorderSide(color: borderColor, width: 0.6),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide:
                                  BorderSide(color: borderColor, width: 0.6),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: const BorderSide(
                                  color: Color(0xFFD97706), width: 1.5),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 14),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        flex: 5,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 4),
                          decoration: BoxDecoration(
                            border: Border.all(color: borderColor, width: 0.6),
                            borderRadius: BorderRadius.circular(16),
                            color: bgColor,
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value: selectedRelation,
                              isExpanded: true,
                              dropdownColor: surfaceColor,
                              icon: Icon(Icons.keyboard_arrow_down_rounded,
                                  size: 20, color: textSec),
                              items: const [
                                DropdownMenuItem(
                                    value: 'Parent', child: Text('Parent')),
                                DropdownMenuItem(
                                    value: 'Guardian',
                                    child: Text('Guardian')),
                                DropdownMenuItem(
                                    value: 'Sibling', child: Text('Sibling')),
                                DropdownMenuItem(
                                    value: 'Relative',
                                    child: Text('Relative')),
                                DropdownMenuItem(
                                    value: 'Friend', child: Text('Friend')),
                              ],
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: textColor,
                              ),
                              onChanged: (val) {
                                if (val != null) {
                                  AppHaptics.selectionClick();
                                  setSheetState(() => selectedRelation = val);
                                }
                              },
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),

                  // Group: Schedule & Time Window
                  _buildFormSectionHeader("VISIT DATE & TIME WINDOW", textSec),
                  const SizedBox(height: 8),

                  AppleBounceable(
                    onTap: () async {
                      AppHaptics.selectionClick();
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: selectedDate,
                        firstDate: DateTime.now(),
                        lastDate:
                            DateTime.now().add(const Duration(days: 30)),
                        builder: (ctx, child) {
                          return Theme(
                            data: Theme.of(ctx).copyWith(
                              colorScheme: ColorScheme.fromSeed(
                                seedColor: const Color(0xFFD97706),
                                brightness: Theme.of(ctx).brightness,
                              ),
                            ),
                            child: child!,
                          );
                        },
                      );
                      if (picked != null) {
                        setSheetState(() => selectedDate = picked);
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 14),
                      decoration: BoxDecoration(
                        color: bgColor,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: borderColor, width: 0.6),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: const Color(0xFFD97706)
                                  .withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(Icons.calendar_today_rounded,
                                size: 16, color: Color(0xFFD97706)),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  "Visit Date",
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 11,
                                    color: textSec,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                Text(
                                  DateFormat('EEEE, dd MMMM yyyy')
                                      .format(selectedDate),
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: textColor,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Icon(Icons.chevron_right_rounded,
                              size: 18, color: textSec),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),

                  Row(
                    children: [
                      Expanded(
                        child: AppleBounceable(
                          onTap: () async {
                            AppHaptics.selectionClick();
                            final t = await showTimePicker(
                              context: context,
                              initialTime: entryTime,
                            );
                            if (t != null) {
                              setSheetState(() => entryTime = t);
                            }
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 12),
                            decoration: BoxDecoration(
                              color: bgColor,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: borderColor, width: 0.6),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  "EXPECTED ENTRY",
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 0.6,
                                    color: textSec,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    const Icon(Icons.login_rounded,
                                        size: 16, color: Color(0xFF059669)),
                                    const SizedBox(width: 6),
                                    Text(
                                      entryTime.format(context),
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                        color: textColor,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: AppleBounceable(
                          onTap: () async {
                            AppHaptics.selectionClick();
                            final t = await showTimePicker(
                              context: context,
                              initialTime: exitTime,
                            );
                            if (t != null) {
                              setSheetState(() => exitTime = t);
                            }
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 12),
                            decoration: BoxDecoration(
                              color: bgColor,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: borderColor, width: 0.6),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  "EXPECTED EXIT",
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 0.6,
                                    color: textSec,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    const Icon(Icons.logout_rounded,
                                        size: 16, color: Color(0xFFD97706)),
                                    const SizedBox(width: 6),
                                    Text(
                                      exitTime.format(context),
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                        color: textColor,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),

                  // Group: Purpose
                  _buildFormSectionHeader("PURPOSE OF VISIT", textSec),
                  const SizedBox(height: 8),

                  TextField(
                    controller: purposeController,
                    maxLines: 2,
                    style: GoogleFonts.plusJakartaSans(
                        fontSize: 14, color: textColor),
                    decoration: InputDecoration(
                      hintText: "e.g. Delivering luggage, parent consultation...",
                      hintStyle: GoogleFonts.plusJakartaSans(
                          fontSize: 13, color: textSec.withValues(alpha: 0.6)),
                      filled: true,
                      fillColor: bgColor,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide(color: borderColor, width: 0.6),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide(color: borderColor, width: 0.6),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: const BorderSide(
                            color: Color(0xFFD97706), width: 1.5),
                      ),
                      contentPadding: const EdgeInsets.all(14),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Submit button
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: AppleBounceable(
                      onTap: isSubmitting
                          ? null
                          : () async {
                              final name = nameController.text.trim();
                              final phone = phoneController.text.trim();
                              final purpose = purposeController.text.trim();
                              if (name.isEmpty ||
                                  phone.isEmpty ||
                                  purpose.isEmpty) {
                                AppHaptics.vibrate();
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                      content: Text('Please fill all fields')),
                                );
                                return;
                              }

                              AppHaptics.mediumImpact();
                              final messenger = ScaffoldMessenger.of(context);
                              final navigator = Navigator.of(ctx);
                              final formattedEntry =
                                  entryTime.format(context);
                              final formattedExit =
                                  exitTime.format(context);
                              setSheetState(() => isSubmitting = true);
                              try {
                                await _api.submitVisitorRequest(
                                  studentId: studentId,
                                  visitorName: name,
                                  visitorPhone: phone,
                                  relation: selectedRelation,
                                  purpose: purpose,
                                  visitDate: DateFormat('yyyy-MM-dd')
                                      .format(selectedDate),
                                  expectedEntryTime: formattedEntry,
                                  expectedExitTime: formattedExit,
                                );
                                if (mounted) {
                                  AppHaptics.mediumImpact();
                                  navigator.pop();
                                  _loadVisitorData();
                                  messenger.showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                          'Visitor pass request submitted for Warden approval'),
                                      backgroundColor: AppColors.success,
                                    ),
                                  );
                                }
                              } catch (e) {
                                AppHaptics.vibrate();
                                setSheetState(() => isSubmitting = false);
                                messenger.showSnackBar(
                                  SnackBar(
                                    content: Text('Error: $e'),
                                    backgroundColor: AppColors.danger,
                                  ),
                                );
                              }
                            },
                      child: Container(
                        height: 52,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFFD97706), Color(0xFFB45309)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFFD97706)
                                  .withValues(alpha: 0.35),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        alignment: Alignment.center,
                        child: isSubmitting
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                    color: Colors.white, strokeWidth: 2.5),
                              )
                            : Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(Icons.qr_code_2_rounded,
                                      size: 19, color: Colors.white),
                                  const SizedBox(width: 8),
                                  Text(
                                    "Issue Campus Pass",
                                    style: GoogleFonts.plusJakartaSans(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 15,
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
            ),
          );
        },
      ),
    );
  }

  Widget _buildFormSectionHeader(String title, Color textColor) {
    return Text(
      title,
      style: GoogleFonts.plusJakartaSans(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.8,
        color: textColor,
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

    final textColor = AppColors.textPrimaryOf(context);
    final textSec = AppColors.textSecondaryOf(context);

    return RefreshIndicator(
      onRefresh: _loadVisitorData,
      color: const Color(0xFFD97706),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
        physics: AppleSpringScrollPhysics.always,
        children: [
          // Header Row with Title & Apple Pill Button
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Visitor Passes",
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: textColor,
                      letterSpacing: -0.3,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    "Campus gate access credentials",
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12,
                      color: textSec,
                    ),
                  ),
                ],
              ),
              AppleBounceable(
                onTap: _showNewVisitorPassDialog,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFD97706), Color(0xFFB45309)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color:
                            const Color(0xFFD97706).withValues(alpha: 0.28),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.add_rounded,
                          size: 17, color: Colors.white),
                      const SizedBox(width: 6),
                      Text(
                        "New Pass",
                        style: GoogleFonts.plusJakartaSans(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),

          // Active Pass Ticket Banner
          if (_activePass != null) ...[
            _buildActivePassBanner(_activePass!),
            const SizedBox(height: 22),
          ],

          // Error Banner
          if (_error != null)
            Container(
              padding: const EdgeInsets.all(14),
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: AppColors.danger.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                    color: AppColors.danger.withValues(alpha: 0.25),
                    width: 0.6),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error_outline_rounded,
                      size: 18, color: AppColors.danger),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _error!,
                      style: GoogleFonts.plusJakartaSans(
                        color: AppColors.danger,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),

          // Section Header for Pass History
          Row(
            children: [
              Text(
                "PASS HISTORY",
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8,
                  color: textSec,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.borderOf(context),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  "${_passes.length}",
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: textSec,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          if (_passes.isEmpty)
            _buildEmptyVisitorState()
          else
            ..._passes.map((p) => _buildVisitorPassCard(p)),
        ],
      ),
    );
  }

  Widget _buildActivePassBanner(VisitorRequestModel pass) {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF78350F), Color(0xFF92400E), Color(0xFFB45309)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.18),
          width: 0.8,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF78350F).withValues(alpha: 0.35),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Subtle background decorative watermark
          Positioned(
            right: -14,
            bottom: -14,
            child: Icon(
              Icons.qr_code_2_rounded,
              size: 130,
              color: Colors.white.withValues(alpha: 0.06),
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Tagline & Status Pill
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 26,
                          height: 26,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.18),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.shield_rounded,
                              color: Color(0xFFFDE68A), size: 15),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          "ACTIVE GATE PASS",
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.8,
                            color: const Color(0xFFFDE68A),
                          ),
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.22),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.2),
                          width: 0.5,
                        ),
                      ),
                      child: Text(
                        pass.status,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // Visitor Name & Relation
                Text(
                  pass.visitorName,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.16),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        pass.relation,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      pass.visitorPhone,
                      style: GoogleFonts.jetBrainsMono(
                        fontSize: 12,
                        color: Colors.white70,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // Schedule visualizer
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.access_time_filled_rounded,
                          size: 16, color: Color(0xFFFDE68A)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          "${pass.visitDate}  •  ${pass.expectedEntryTime} – ${pass.expectedExitTime}",
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Action: Present QR Pass
                AppleBounceable(
                  onTap: () {
                    AppHaptics.lightImpact();
                    showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      backgroundColor: Colors.transparent,
                      builder: (context) => VisitorPassSheet(pass: pass),
                    );
                  },
                  child: Container(
                    width: double.infinity,
                    height: 46,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.12),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.qr_code_rounded,
                            size: 18, color: Color(0xFF78350F)),
                        const SizedBox(width: 8),
                        Text(
                          "Present QR at Main Gate",
                          style: GoogleFonts.plusJakartaSans(
                            fontWeight: FontWeight.bold,
                            fontSize: 13.5,
                            color: const Color(0xFF78350F),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVisitorPassCard(VisitorRequestModel pass) {
    Color statusColor;
    Color statusBg;
    IconData statusIcon;

    switch (pass.status.toUpperCase()) {
      case 'APPROVED':
        statusColor = const Color(0xFFD97706);
        statusBg = const Color(0xFFD97706).withValues(alpha: 0.1);
        statusIcon = Icons.check_circle_outline_rounded;
        break;
      case 'CHECKED_IN':
        statusColor = AppColors.success;
        statusBg = AppColors.success.withValues(alpha: 0.1);
        statusIcon = Icons.login_rounded;
        break;
      case 'CHECKED_OUT':
        statusColor = const Color(0xFF6B7280);
        statusBg = const Color(0xFF6B7280).withValues(alpha: 0.1);
        statusIcon = Icons.logout_rounded;
        break;
      case 'REJECTED':
      case 'EXPIRED':
        statusColor = AppColors.danger;
        statusBg = AppColors.danger.withValues(alpha: 0.1);
        statusIcon = Icons.cancel_outlined;
        break;
      default:
        statusColor = const Color(0xFF6B7280);
        statusBg = const Color(0xFF6B7280).withValues(alpha: 0.1);
        statusIcon = Icons.schedule_rounded;
    }

    final canViewQR =
        pass.status == 'APPROVED' || pass.status == 'CHECKED_IN';
    final surfaceColor = AppColors.surfaceOf(context);
    final borderColor = AppColors.borderOf(context);
    final textColor = AppColors.textPrimaryOf(context);
    final textSec = AppColors.textSecondaryOf(context);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderColor, width: 0.6),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Row: Visitor Name & Status Capsule
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: const Color(0xFFD97706)
                              .withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.person_rounded,
                            size: 19, color: Color(0xFFD97706)),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              pass.visitorName,
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: textColor,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              "${pass.relation} • ${pass.visitorPhone}",
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 12,
                                color: textSec,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusBg,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(statusIcon, size: 12, color: statusColor),
                      const SizedBox(width: 4),
                      Text(
                        pass.status,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: statusColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Visit Date & Purpose Block
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.bgOf(context),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: borderColor, width: 0.5),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.calendar_month_outlined,
                          size: 14, color: textSec),
                      const SizedBox(width: 6),
                      Text(
                        "${pass.visitDate}  •  ${pass.expectedEntryTime} – ${pass.expectedExitTime}",
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: textColor,
                        ),
                      ),
                    ],
                  ),
                  if (pass.purpose.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.format_quote_rounded,
                            size: 14, color: textSec),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            pass.purpose,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 12,
                              color: textSec,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 10),

            // Bottom row: Token Chip & View Pass Action
            Row(
              children: [
                if (pass.passCode != null)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFFD97706).withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: const Color(0xFFD97706)
                            .withValues(alpha: 0.25),
                        width: 0.5,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.key_rounded,
                            size: 12, color: Color(0xFFD97706)),
                        const SizedBox(width: 4),
                        Text(
                          pass.passCode!,
                          style: GoogleFonts.jetBrainsMono(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFFD97706),
                          ),
                        ),
                      ],
                    ),
                  ),
                const Spacer(),
                if (canViewQR)
                  AppleBounceable(
                    onTap: () {
                      AppHaptics.lightImpact();
                      showModalBottomSheet(
                        context: context,
                        isScrollControlled: true,
                        backgroundColor: Colors.transparent,
                        builder: (context) => VisitorPassSheet(pass: pass),
                      );
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFD97706)
                            .withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.qr_code_rounded,
                              size: 15, color: Color(0xFFD97706)),
                          const SizedBox(width: 6),
                          Text(
                            "View QR Pass",
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFFD97706),
                            ),
                          ),
                        ],
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

  Widget _buildEmptyVisitorState() {
    final surfaceColor = AppColors.surfaceOf(context);
    final borderColor = AppColors.borderOf(context);
    final textColor = AppColors.textPrimaryOf(context);
    final textSec = AppColors.textSecondaryOf(context);

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: borderColor, width: 0.6),
      ),
      child: Column(
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: const Color(0xFFD97706).withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.badge_outlined,
                size: 34, color: Color(0xFFD97706)),
          ),
          const SizedBox(height: 14),
          Text(
            "No Visitor Passes",
            style: GoogleFonts.plusJakartaSans(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: textColor,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            "Invite parents or guests by issuing an attested gate pass with anti-replay QR verified by security.",
            textAlign: TextAlign.center,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 13,
              color: textSec,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 18),
          AppleBounceable(
            onTap: _showNewVisitorPassDialog,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFD97706).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.add_rounded,
                      size: 16, color: Color(0xFFD97706)),
                  const SizedBox(width: 6),
                  Text(
                    "Create First Pass",
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFFD97706),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
