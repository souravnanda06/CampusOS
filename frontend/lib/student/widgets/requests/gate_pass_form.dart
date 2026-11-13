import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/haptics/app_haptics.dart';
import '../../../auth/providers/user_provider.dart';
import '../../models/leave_request_model.dart';
import '../../services/leave_service.dart';
import '../../services/gate_pass_service.dart';
import '../../../shared/widgets/motion/apple_bounceable.dart';
import '../../../shared/widgets/motion/apple_spring_scroll_physics.dart';

class GatePassForm extends StatefulWidget {
  final VoidCallback? onRequestSubmitted;
  final String? initialLeaveRequestId;

  const GatePassForm({
    Key? key,
    this.onRequestSubmitted,
    this.initialLeaveRequestId,
  }) : super(key: key);

  @override
  State<GatePassForm> createState() => _GatePassFormState();
}

class _GatePassFormState extends State<GatePassForm> {
  final _formKey = GlobalKey<FormState>();
  final _destinationController = TextEditingController();
  final _reasonController = TextEditingController();
  final GatePassService _gatePassService = GatePassService();
  final LeaveService _leaveService = LeaveService();

  List<LeaveRequestModel> _approvedLeaves = [];
  String? _selectedLeaveId;
  bool _isLoadingLeaves = true;
  bool _isSubmitting = false;
  String? _leaveLoadError;

  DateTime? _exitDate;
  TimeOfDay? _exitTime;
  DateTime? _returnDate;
  TimeOfDay? _returnTime;

  @override
  void initState() {
    super.initState();
    _selectedLeaveId = widget.initialLeaveRequestId;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadApprovedLeaves();
    });
  }

  Future<void> _loadApprovedLeaves() async {
    final studentId = Provider.of<UserProvider>(context, listen: false).user?.id;
    if (studentId == null || studentId.isEmpty) {
      if (mounted) {
        setState(() {
          _isLoadingLeaves = false;
          _leaveLoadError = "Student profile not found. Please log in again.";
        });
      }
      return;
    }

    try {
      final allLeaves = await _leaveService.getStudentLeaveRequests(studentId);
      final approved = allLeaves.where((l) => l.isApproved).toList();
      if (mounted) {
        setState(() {
          _approvedLeaves = approved;
          _isLoadingLeaves = false;
          if (_selectedLeaveId == null && approved.isNotEmpty) {
            _selectedLeaveId = approved.first.id;
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingLeaves = false;
          _leaveLoadError = e.toString().replaceAll('Exception: ', '');
        });
      }
    }
  }

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

  Future<void> _selectDateTime(BuildContext context, bool isExit) async {
    AppHaptics.selectionClick();
    final DateTime initialDate = isExit
        ? (_exitDate ?? DateTime.now())
        : (_returnDate ?? _exitDate ?? DateTime.now());

    final DateTime firstDate = isExit
        ? DateTime.now().subtract(const Duration(hours: 12))
        : (_exitDate ?? DateTime.now());

    final DateTime? pickedDate = await showDatePicker(
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

    if (pickedDate != null) {
      if (!context.mounted) return;
      AppHaptics.selectionClick();
      final TimeOfDay? pickedTime = await showTimePicker(
        context: context,
        initialTime: isExit ? (_exitTime ?? TimeOfDay.now()) : (_returnTime ?? TimeOfDay.now()),
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

      if (pickedTime != null) {
        AppHaptics.lightImpact();
        setState(() {
          if (isExit) {
            _exitDate = pickedDate;
            _exitTime = pickedTime;
            if (_returnDate != null && _returnDate!.isBefore(_exitDate!)) {
              _returnDate = null;
              _returnTime = null;
            }
          } else {
            _returnDate = pickedDate;
            _returnTime = pickedTime;
          }
        });
      }
    }
  }

  String _formatDateTime(DateTime? date, TimeOfDay? time) {
    if (date == null || time == null) return 'Select time';
    final dt = DateTime(date.year, date.month, date.day, time.hour, time.minute);
    return DateFormat('MMM dd, hh:mm a').format(dt);
  }

  Future<void> _submit() async {
    if (_isSubmitting) return;

    if (_formKey.currentState!.validate()) {
      if (_selectedLeaveId == null || _selectedLeaveId!.isEmpty) {
        AppHaptics.mediumImpact();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Please select an approved leave request.',
              style: GoogleFonts.plusJakartaSans(color: Colors.white),
            ),
            backgroundColor: AppColors.danger,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
        return;
      }

      if (_exitDate == null || _exitTime == null || _returnDate == null || _returnTime == null) {
        AppHaptics.mediumImpact();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Please select both exit and return dates and times.',
              style: GoogleFonts.plusJakartaSans(color: Colors.white),
            ),
            backgroundColor: AppColors.danger,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
        return;
      }

      final exitDt = DateTime(
        _exitDate!.year,
        _exitDate!.month,
        _exitDate!.day,
        _exitTime!.hour,
        _exitTime!.minute,
      );

      final returnDt = DateTime(
        _returnDate!.year,
        _returnDate!.month,
        _returnDate!.day,
        _returnTime!.hour,
        _returnTime!.minute,
      );

      if (!returnDt.isAfter(exitDt)) {
        AppHaptics.mediumImpact();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Return time must be strictly after exit time.',
              style: GoogleFonts.plusJakartaSans(color: Colors.white),
            ),
            backgroundColor: AppColors.danger,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
        return;
      }

      final studentId = Provider.of<UserProvider>(context, listen: false).user?.id;
      if (studentId == null || studentId.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Student profile not loaded. Please log in again.',
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
        await _gatePassService.createGatePass(
          studentId: studentId,
          leaveRequestId: _selectedLeaveId!,
          destination: _destinationController.text.trim(),
          reason: _reasonController.text.trim(),
          expectedExitTime: exitDt.toIso8601String(),
          expectedReturnTime: returnDt.toIso8601String(),
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
                    "Gate pass request submitted successfully",
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
                          "New Gate Pass",
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textPrimaryOf(context),
                            letterSpacing: -0.4,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          "Security clearance for campus exit & return",
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
                const SizedBox(height: 22),

                // Approved leave request requirement section
                if (_isLoadingLeaves)
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceAltOf(context),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: AppColors.borderOf(context).withValues(alpha: 0.5),
                        width: 0.5,
                      ),
                    ),
                    child: Row(
                      children: [
                        const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          "Checking approved leave records...",
                          style: GoogleFonts.plusJakartaSans(
                            color: AppColors.textSecondaryOf(context),
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  )
                else if (_approvedLeaves.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: (_leaveLoadError != null ? AppColors.danger : AppColors.warning).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: (_leaveLoadError != null ? AppColors.danger : AppColors.warning).withValues(alpha: 0.3),
                        width: 0.5,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              _leaveLoadError != null ? Icons.error_outline_rounded : Icons.warning_amber_rounded,
                              color: _leaveLoadError != null ? AppColors.danger : AppColors.warning,
                              size: 18,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              _leaveLoadError != null ? "Failed to Load Leaves" : "Approved Leave Required",
                              style: GoogleFonts.plusJakartaSans(
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimaryOf(context),
                                fontSize: 13.5,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          _leaveLoadError ??
                              "Campus security policy requires an APPROVED leave request before a Gate Pass can be issued. You currently have no approved leaves.",
                          style: GoogleFonts.plusJakartaSans(
                            color: AppColors.textSecondaryOf(context),
                            fontSize: 12.5,
                            height: 1.45,
                          ),
                        ),
                      ],
                    ),
                  )
                else ...[
                  Text(
                    "LINKED APPROVED LEAVE",
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textSecondaryOf(context),
                      letterSpacing: 0.8,
                    ),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    initialValue: _selectedLeaveId,
                    decoration: _buildInputDecoration(
                      context,
                      "Select Approved Leave",
                      suffixIcon: Icons.verified_outlined,
                    ),
                    dropdownColor: AppColors.surfaceOf(context),
                    style: GoogleFonts.plusJakartaSans(
                      color: AppColors.textPrimaryOf(context),
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                    ),
                    items: _approvedLeaves.map((leave) {
                      final dates = "${DateFormat('MMM dd').format(leave.startDate)} - ${DateFormat('MMM dd').format(leave.endDate)}";
                      return DropdownMenuItem<String>(
                        value: leave.id,
                        child: Text(
                          "${leave.leaveType} ($dates)",
                          style: GoogleFonts.plusJakartaSans(
                            color: AppColors.textPrimaryOf(context),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      );
                    }).toList(),
                    onChanged: (val) {
                      AppHaptics.selectionClick();
                      setState(() => _selectedLeaveId = val);
                    },
                    validator: (val) => val == null || val.isEmpty ? 'Please select a leave record' : null,
                  ),
                ],

                const SizedBox(height: 20),
                Text(
                  "DESTINATION",
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textSecondaryOf(context),
                    letterSpacing: 0.8,
                  ),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _destinationController,
                  style: GoogleFonts.plusJakartaSans(color: AppColors.textPrimaryOf(context), fontSize: 14),
                  decoration: _buildInputDecoration(
                    context,
                    "Destination Location",
                    suffixIcon: Icons.location_on_outlined,
                    hint: "e.g. Railway Station, City Market, Home...",
                  ),
                  validator: (value) => (value == null || value.trim().isEmpty) ? 'Please enter destination' : null,
                ),
                const SizedBox(height: 20),

                Text(
                  "TRANSIT WINDOW",
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
                      child: AppleBounceable(
                        scaleFactor: 0.98,
                        onTap: () => _selectDateTime(context, true),
                        child: InputDecorator(
                          decoration: _buildInputDecoration(
                            context,
                            "Exit Time",
                            suffixIcon: Icons.access_time_rounded,
                          ),
                          child: Text(
                            _formatDateTime(_exitDate, _exitTime),
                            style: GoogleFonts.plusJakartaSans(
                              color: _exitDate != null
                                  ? AppColors.textPrimaryOf(context)
                                  : AppColors.textTertiaryOf(context),
                              fontSize: 13,
                              fontWeight: _exitDate != null ? FontWeight.w600 : FontWeight.w400,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: AppleBounceable(
                        scaleFactor: 0.98,
                        onTap: () => _selectDateTime(context, false),
                        child: InputDecorator(
                          decoration: _buildInputDecoration(
                            context,
                            "Return Time",
                            suffixIcon: Icons.access_time_rounded,
                          ),
                          child: Text(
                            _formatDateTime(_returnDate, _returnTime),
                            style: GoogleFonts.plusJakartaSans(
                              color: _returnDate != null
                                  ? AppColors.textPrimaryOf(context)
                                  : AppColors.textTertiaryOf(context),
                              fontSize: 13,
                              fontWeight: _returnDate != null ? FontWeight.w600 : FontWeight.w400,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                Text(
                  "GATE EXIT REASON",
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
                    "Reason for Exit",
                    hint: "Short note on purpose of gate movement...",
                  ).copyWith(alignLabelWithHint: true),
                  validator: (value) => (value == null || value.trim().isEmpty) ? 'Please enter a reason' : null,
                ),
                const SizedBox(height: 28),

                AppleBounceable(
                  scaleFactor: 0.96,
                  onTap: (_isSubmitting || _approvedLeaves.isEmpty) ? null : _submit,
                  child: Container(
                    width: double.infinity,
                    height: 52,
                    decoration: BoxDecoration(
                      color: (_approvedLeaves.isEmpty)
                          ? AppColors.textSecondaryOf(context).withValues(alpha: 0.25)
                          : AppColors.primary,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: (_approvedLeaves.isNotEmpty)
                          ? [
                              BoxShadow(
                                color: AppColors.primary.withValues(alpha: 0.28),
                                blurRadius: 14,
                                offset: const Offset(0, 4),
                              ),
                            ]
                          : null,
                    ),
                    child: Center(
                      child: _isSubmitting
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.2,
                                color: Colors.white,
                              ),
                            )
                          : Text(
                              "Submit Gate Pass Request",
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: (_approvedLeaves.isEmpty)
                                    ? AppColors.textSecondaryOf(context)
                                    : Colors.white,
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
    _destinationController.dispose();
    _reasonController.dispose();
    super.dispose();
  }
}
