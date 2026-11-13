import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/haptics/app_haptics.dart';
import '../../../auth/providers/user_provider.dart';
import '../../services/leave_service.dart';
import '../../../shared/widgets/motion/apple_bounceable.dart';
import '../../../shared/widgets/motion/apple_spring_scroll_physics.dart';

class LeaveRequestForm extends StatefulWidget {
  final VoidCallback? onRequestSubmitted;

  const LeaveRequestForm({Key? key, this.onRequestSubmitted}) : super(key: key);

  @override
  State<LeaveRequestForm> createState() => _LeaveRequestFormState();
}

class _LeaveRequestFormState extends State<LeaveRequestForm> {
  final _formKey = GlobalKey<FormState>();
  String? _leaveType = 'Personal';
  DateTime? _startDate;
  DateTime? _endDate;
  final _reasonController = TextEditingController();
  bool _isSubmitting = false;

  final List<String> _leaveTypes = [
    'Personal',
    'Medical',
    'Family',
    'Academic',
    'Other'
  ];

  InputDecoration _buildInputDecoration(BuildContext context, String label, {IconData? suffixIcon, String? hint}) {
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
      suffixIcon: suffixIcon != null
          ? Icon(suffixIcon, color: AppColors.primary, size: 18)
          : null,
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
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: AppColors.danger, width: 1.0),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: AppColors.danger, width: 1.5),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    );
  }

  Future<void> _selectDate(BuildContext context, bool isStart) async {
    AppHaptics.selectionClick();
    final DateTime initialDate = isStart 
        ? (_startDate ?? DateTime.now()) 
        : (_endDate ?? _startDate ?? DateTime.now());
        
    final DateTime firstDate = isStart 
        ? DateTime.now() 
        : (_startDate ?? DateTime.now());

    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: firstDate,
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: AppColors.primary,
              onPrimary: Colors.white,
              surface: AppColors.surfaceOf(context),
              onSurface: AppColors.textPrimaryOf(context),
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      AppHaptics.lightImpact();
      setState(() {
        if (isStart) {
          _startDate = picked;
          if (_endDate != null && _endDate!.isBefore(_startDate!)) {
            _endDate = null;
          }
        } else {
          _endDate = picked;
        }
      });
    }
  }

  Future<void> _submit() async {
    if (_isSubmitting) return;

    if (_formKey.currentState!.validate()) {
      if (_startDate == null || _endDate == null) {
        AppHaptics.mediumImpact();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Please select start and end dates.',
              style: GoogleFonts.plusJakartaSans(color: Colors.white),
            ),
            backgroundColor: AppColors.danger,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
        return;
      }
      if (_leaveType == null) {
        AppHaptics.mediumImpact();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Please select a leave type.',
              style: GoogleFonts.plusJakartaSans(color: Colors.white),
            ),
            backgroundColor: AppColors.danger,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
        return;
      }

      final userProvider = Provider.of<UserProvider>(context, listen: false);
      final studentId = userProvider.user?.id;
      if (studentId == null || studentId.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'User profile not loaded. Please log in again.',
              style: GoogleFonts.plusJakartaSans(color: Colors.white),
            ),
            backgroundColor: AppColors.danger,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
        return;
      }

      AppHaptics.lightImpact();
      setState(() => _isSubmitting = true);

      try {
        final startStr = DateFormat('yyyy-MM-dd').format(_startDate!);
        final endStr = DateFormat('yyyy-MM-dd').format(_endDate!);

        await LeaveService().submitLeaveRequest(
          studentId: studentId,
          leaveType: _leaveType!,
          startDate: startStr,
          endDate: endStr,
          reason: _reasonController.text.trim(),
        );

        if (!mounted) return;
        AppHaptics.lightImpact();
        widget.onRequestSubmitted?.call();
        Navigator.pop(context, true);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    "Leave request submitted successfully",
                    style: GoogleFonts.plusJakartaSans(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            backgroundColor: AppColors.emerald,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      } catch (e) {
        if (!mounted) return;
        AppHaptics.mediumImpact();
        setState(() => _isSubmitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              e.toString().replaceAll('Exception: ', ''),
              style: GoogleFonts.plusJakartaSans(color: Colors.white),
            ),
            backgroundColor: AppColors.danger,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final durationDays = (_startDate != null && _endDate != null)
        ? _endDate!.difference(_startDate!).inDays + 1
        : null;

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
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
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            physics: AppleSpringScrollPhysics.always,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
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
                          "New Leave Request",
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textPrimaryOf(context),
                            letterSpacing: -0.4,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          "Formal transit permission away from campus",
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
                        Navigator.pop(context);
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
                const SizedBox(height: 24),

                // Section Label
                Text(
                  "LEAVE CATEGORY",
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textSecondaryOf(context),
                    letterSpacing: 0.8,
                  ),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  initialValue: _leaveType,
                  dropdownColor: AppColors.surfaceOf(context),
                  icon: const Icon(Icons.expand_more_rounded, color: AppColors.primary, size: 20),
                  decoration: _buildInputDecoration(context, "Type of Absence"),
                  items: _leaveTypes.map((type) {
                    return DropdownMenuItem(
                      value: type,
                      child: Text(
                        type,
                        style: GoogleFonts.plusJakartaSans(
                          color: AppColors.textPrimaryOf(context),
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                    );
                  }).toList(),
                  onChanged: (value) {
                    AppHaptics.selectionClick();
                    setState(() => _leaveType = value);
                  },
                  validator: (value) => value == null ? 'Please select a leave type' : null,
                ),
                const SizedBox(height: 20),

                // Section Label: Dates
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      "DURATION & TIMELINE",
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textSecondaryOf(context),
                        letterSpacing: 0.8,
                      ),
                    ),
                    if (durationDays != null && durationDays > 0)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          "$durationDays ${durationDays == 1 ? 'day' : 'days'}",
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: AppleBounceable(
                        scaleFactor: 0.98,
                        onTap: () => _selectDate(context, true),
                        child: InputDecorator(
                          decoration: _buildInputDecoration(
                            context,
                            "Start Date",
                            suffixIcon: Icons.calendar_today_rounded,
                          ),
                          child: Text(
                            _startDate != null
                                ? DateFormat('MMM dd, yyyy').format(_startDate!)
                                : 'Select date',
                            style: GoogleFonts.plusJakartaSans(
                              color: _startDate != null
                                  ? AppColors.textPrimaryOf(context)
                                  : AppColors.textTertiaryOf(context),
                              fontSize: 13.5,
                              fontWeight: _startDate != null ? FontWeight.w600 : FontWeight.w400,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: AppleBounceable(
                        scaleFactor: 0.98,
                        onTap: () => _selectDate(context, false),
                        child: InputDecorator(
                          decoration: _buildInputDecoration(
                            context,
                            "End Date",
                            suffixIcon: Icons.calendar_today_rounded,
                          ),
                          child: Text(
                            _endDate != null
                                ? DateFormat('MMM dd, yyyy').format(_endDate!)
                                : 'Select date',
                            style: GoogleFonts.plusJakartaSans(
                              color: _endDate != null
                                  ? AppColors.textPrimaryOf(context)
                                  : AppColors.textTertiaryOf(context),
                              fontSize: 13.5,
                              fontWeight: _endDate != null ? FontWeight.w600 : FontWeight.w400,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Section Label: Reason
                Text(
                  "PURPOSE / EXPLANATION",
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textSecondaryOf(context),
                    letterSpacing: 0.8,
                  ),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _reasonController,
                  maxLines: 3,
                  style: GoogleFonts.plusJakartaSans(
                    color: AppColors.textPrimaryOf(context),
                    fontSize: 14,
                    height: 1.4,
                  ),
                  decoration: _buildInputDecoration(
                    context,
                    "Reason for Absence",
                    hint: "e.g. Attending family function, medical appointment...",
                  ).copyWith(alignLabelWithHint: true),
                  validator: (value) => (value == null || value.trim().isEmpty)
                      ? 'Please enter a clear reason'
                      : null,
                ),
                const SizedBox(height: 28),

                // Action Button
                AppleBounceable(
                  scaleFactor: 0.96,
                  onTap: _isSubmitting ? null : _submit,
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
                      child: _isSubmitting
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2.2,
                              ),
                            )
                          : Text(
                              "Submit Leave Request",
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
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
        ),
      ),
    );
  }

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }
}
