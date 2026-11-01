import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../auth/providers/user_provider.dart';
import '../../models/leave_request_model.dart';
import '../../services/leave_service.dart';
import '../../services/gate_pass_service.dart';

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

  InputDecoration _buildInputDecoration(String label, {IconData? suffixIcon}) {
    return InputDecoration(
      labelText: label,
      labelStyle: GoogleFonts.plusJakartaSans(color: AppColors.textSecondary, fontSize: 14),
      filled: true,
      fillColor: AppColors.bg,
      suffixIcon: suffixIcon != null ? Icon(suffixIcon, color: AppColors.textSecondary, size: 20) : null,
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: AppColors.border.withValues(alpha: 0.5)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: AppColors.danger),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: AppColors.danger, width: 1.5),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    );
  }

  Future<void> _selectDateTime(BuildContext context, bool isExit) async {
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

    if (pickedDate != null) {
      if (!context.mounted) return;
      final TimeOfDay? pickedTime = await showTimePicker(
        context: context,
        initialTime: isExit ? (_exitTime ?? TimeOfDay.now()) : (_returnTime ?? TimeOfDay.now()),
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

      if (pickedTime != null) {
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
    if (date == null || time == null) return 'Select Time';
    final dt = DateTime(date.year, date.month, date.day, time.hour, time.minute);
    return DateFormat('MMM dd, hh:mm a').format(dt);
  }

  Future<void> _submit() async {
    if (_isSubmitting) return;

    if (_formKey.currentState!.validate()) {
      if (_selectedLeaveId == null || _selectedLeaveId!.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select an approved leave request.')),
        );
        return;
      }

      if (_exitDate == null || _exitTime == null || _returnDate == null || _returnTime == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select both exit and return dates and times.')),
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
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Return time must be strictly after exit time.')),
        );
        return;
      }

      final studentId = Provider.of<UserProvider>(context, listen: false).user?.id;
      if (studentId == null || studentId.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Student profile not loaded. Please log in again.')),
        );
        return;
      }

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
        widget.onRequestSubmitted?.call();
        Navigator.pop(context, true);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              "Gate pass request submitted successfully",
              style: GoogleFonts.plusJakartaSans(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      } catch (e) {
        if (!mounted) return;
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
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Center(
                  child: Container(
                    width: 48,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.border,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      "New Gate Pass",
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, color: AppColors.textSecondary),
                      onPressed: () => Navigator.pop(context),
                      style: IconButton.styleFrom(
                        backgroundColor: AppColors.bg,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ],
                ).animate().fadeIn().slideX(begin: -0.05),
                const SizedBox(height: 24),

                // Approved leave request requirement section
                if (_isLoadingLeaves)
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.bg,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      children: [
                        const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          "Checking approved leave records...",
                          style: GoogleFonts.plusJakartaSans(
                            color: AppColors.textSecondary,
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
                      border: Border.all(color: (_leaveLoadError != null ? AppColors.danger : AppColors.warning).withValues(alpha: 0.3)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              _leaveLoadError != null ? Icons.error_outline_rounded : Icons.warning_amber_rounded,
                              color: _leaveLoadError != null ? AppColors.danger : AppColors.warning,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              _leaveLoadError != null ? "Failed to Load Leaves" : "Approved Leave Required",
                              style: GoogleFonts.plusJakartaSans(
                                fontWeight: FontWeight.bold,
                                color: AppColors.textPrimary,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          _leaveLoadError ??
                              "Campus security policy requires an APPROVED leave request before a Gate Pass can be issued. You currently have no approved leaves.",
                          style: GoogleFonts.plusJakartaSans(
                            color: AppColors.textSecondary,
                            fontSize: 12.5,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  DropdownButtonFormField<String>(
                    initialValue: _selectedLeaveId,
                    decoration: _buildInputDecoration("Linked Approved Leave", suffixIcon: Icons.verified_outlined),
                    dropdownColor: AppColors.surface,
                    style: GoogleFonts.plusJakartaSans(color: AppColors.textPrimary, fontSize: 14),
                    items: _approvedLeaves.map((leave) {
                      final dates = "${DateFormat('MMM dd').format(leave.startDate)} - ${DateFormat('MMM dd').format(leave.endDate)}";
                      return DropdownMenuItem<String>(
                        value: leave.id,
                        child: Text(
                          "${leave.leaveType} ($dates)",
                          style: GoogleFonts.plusJakartaSans(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      );
                    }).toList(),
                    onChanged: (val) {
                      setState(() => _selectedLeaveId = val);
                    },
                    validator: (val) => val == null || val.isEmpty ? 'Please select a leave record' : null,
                  ).animate().fadeIn(delay: 50.ms).slideY(begin: 0.1),

                const SizedBox(height: 20),
                TextFormField(
                  controller: _destinationController,
                  style: GoogleFonts.plusJakartaSans(color: AppColors.textPrimary),
                  decoration: _buildInputDecoration("Destination", suffixIcon: Icons.location_on_outlined),
                  validator: (value) => (value == null || value.trim().isEmpty) ? 'Please enter destination' : null,
                ).animate().fadeIn(delay: 100.ms).slideY(begin: 0.1),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: () => _selectDateTime(context, true),
                        borderRadius: BorderRadius.circular(16),
                        child: InputDecorator(
                          decoration: _buildInputDecoration("Exit Time", suffixIcon: Icons.access_time_rounded).copyWith(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          ),
                          child: Text(
                            _formatDateTime(_exitDate, _exitTime),
                            style: GoogleFonts.plusJakartaSans(
                              color: _exitDate != null ? AppColors.textPrimary : AppColors.textSecondary,
                            ),
                          ),
                        ),
                      ),
                    ).animate().fadeIn(delay: 150.ms).slideY(begin: 0.1),
                    const SizedBox(width: 16),
                    Expanded(
                      child: InkWell(
                        onTap: () => _selectDateTime(context, false),
                        borderRadius: BorderRadius.circular(16),
                        child: InputDecorator(
                          decoration: _buildInputDecoration("Return Time", suffixIcon: Icons.access_time_rounded).copyWith(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          ),
                          child: Text(
                            _formatDateTime(_returnDate, _returnTime),
                            style: GoogleFonts.plusJakartaSans(
                              color: _returnDate != null ? AppColors.textPrimary : AppColors.textSecondary,
                            ),
                          ),
                        ),
                      ),
                    ).animate().fadeIn(delay: 200.ms).slideY(begin: 0.1),
                  ],
                ),
                const SizedBox(height: 20),
                TextFormField(
                  controller: _reasonController,
                  maxLines: 3,
                  style: GoogleFonts.plusJakartaSans(color: AppColors.textPrimary),
                  decoration: _buildInputDecoration("Reason for Gate Exit").copyWith(alignLabelWithHint: true),
                  validator: (value) => (value == null || value.trim().isEmpty) ? 'Please enter a reason' : null,
                ).animate().fadeIn(delay: 250.ms).slideY(begin: 0.1),
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: (_isSubmitting || _approvedLeaves.isEmpty) ? null : _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: AppColors.textSecondary.withValues(alpha: 0.3),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: 0,
                    ),
                    child: _isSubmitting
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              color: Colors.white,
                            ),
                          )
                        : Text(
                            "Submit Gate Pass Request",
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                ).animate().fadeIn(delay: 300.ms).slideY(begin: 0.1),
                const SizedBox(height: 16),
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
