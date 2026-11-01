import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../auth/providers/user_provider.dart';
import '../../services/leave_service.dart';

class LeaveRequestForm extends StatefulWidget {
  final VoidCallback? onRequestSubmitted;

  const LeaveRequestForm({Key? key, this.onRequestSubmitted}) : super(key: key);

  @override
  State<LeaveRequestForm> createState() => _LeaveRequestFormState();
}

class _LeaveRequestFormState extends State<LeaveRequestForm> {
  final _formKey = GlobalKey<FormState>();
  String? _leaveType;
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

  Future<void> _selectDate(BuildContext context, bool isStart) async {
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
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select start and end dates.')),
        );
        return;
      }
      if (_leaveType == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select a leave type.')),
        );
        return;
      }

      final userProvider = Provider.of<UserProvider>(context, listen: false);
      final studentId = userProvider.user?.id;
      if (studentId == null || studentId.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('User profile not loaded. Please log in again.')),
        );
        return;
      }

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
        widget.onRequestSubmitted?.call();
        Navigator.pop(context, true);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              "Leave request submitted successfully",
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
                      "New Leave Request",
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
                const SizedBox(height: 32),
                DropdownButtonFormField<String>(
                  initialValue: _leaveType,
                  dropdownColor: AppColors.surface,
                  icon: const Icon(Icons.expand_more_rounded, color: AppColors.textSecondary),
                  decoration: _buildInputDecoration("Leave Type"),
                  items: _leaveTypes.map((type) {
                    return DropdownMenuItem(
                      value: type,
                      child: Text(type, style: GoogleFonts.plusJakartaSans(color: AppColors.textPrimary)),
                    );
                  }).toList(),
                  onChanged: (value) => setState(() => _leaveType = value),
                  validator: (value) => value == null ? 'Please select a leave type' : null,
                ).animate().fadeIn(delay: 50.ms).slideY(begin: 0.1),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: () => _selectDate(context, true),
                        borderRadius: BorderRadius.circular(16),
                        child: InputDecorator(
                          decoration: _buildInputDecoration("Start Date", suffixIcon: Icons.calendar_today_rounded),
                          child: Text(
                            _startDate != null ? DateFormat('MMM dd, yyyy').format(_startDate!) : 'Select Date',
                            style: GoogleFonts.plusJakartaSans(
                              color: _startDate != null ? AppColors.textPrimary : AppColors.textSecondary,
                            ),
                          ),
                        ),
                      ),
                    ).animate().fadeIn(delay: 100.ms).slideY(begin: 0.1),
                    const SizedBox(width: 16),
                    Expanded(
                      child: InkWell(
                        onTap: () => _selectDate(context, false),
                        borderRadius: BorderRadius.circular(16),
                        child: InputDecorator(
                          decoration: _buildInputDecoration("End Date", suffixIcon: Icons.calendar_today_rounded),
                          child: Text(
                            _endDate != null ? DateFormat('MMM dd, yyyy').format(_endDate!) : 'Select Date',
                            style: GoogleFonts.plusJakartaSans(
                              color: _endDate != null ? AppColors.textPrimary : AppColors.textSecondary,
                            ),
                          ),
                        ),
                      ),
                    ).animate().fadeIn(delay: 150.ms).slideY(begin: 0.1),
                  ],
                ),
                const SizedBox(height: 20),
                TextFormField(
                  controller: _reasonController,
                  maxLines: 4,
                  style: GoogleFonts.plusJakartaSans(color: AppColors.textPrimary),
                  decoration: _buildInputDecoration("Reason").copyWith(alignLabelWithHint: true),
                  validator: (value) => (value == null || value.trim().isEmpty) ? 'Please enter a reason' : null,
                ).animate().fadeIn(delay: 200.ms).slideY(begin: 0.1),
                const SizedBox(height: 40),
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: _isSubmitting ? null : _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
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
                              color: Colors.white,
                              strokeWidth: 2.5,
                            ),
                          )
                        : Text(
                            "Submit Request",
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                ).animate().fadeIn(delay: 250.ms).slideY(begin: 0.1),
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
    _reasonController.dispose();
    super.dispose();
  }
}
