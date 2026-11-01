import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../auth/providers/user_provider.dart';
import '../../services/complaint_service.dart';

class ComplaintForm extends StatefulWidget {
  final VoidCallback? onRequestSubmitted;

  const ComplaintForm({Key? key, this.onRequestSubmitted}) : super(key: key);

  @override
  State<ComplaintForm> createState() => _ComplaintFormState();
}

class _ComplaintFormState extends State<ComplaintForm> {
  final _formKey = GlobalKey<FormState>();
  final ComplaintService _complaintService = ComplaintService();

  String? _category;
  String _priority = 'MEDIUM';
  final _titleController = TextEditingController();
  final _descController = TextEditingController();
  final _locationController = TextEditingController();
  bool _isSubmitting = false;

  final List<String> _categories = [
    'Hostel/Room',
    'Hostel Asset',
    'Mess',
    'Classroom',
    'Electrical/Plumbing',
    'Cleanliness',
    'Infrastructure',
    'Technical',
    'Other'
  ];

  final List<String> _priorities = ['LOW', 'MEDIUM', 'HIGH', 'URGENT'];

  InputDecoration _buildInputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: GoogleFonts.plusJakartaSans(color: AppColors.textSecondary, fontSize: 14),
      filled: true,
      fillColor: AppColors.bg,
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

  Future<void> _submit() async {
    if (_isSubmitting) return;

    if (_formKey.currentState!.validate()) {
      if (_category == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select a category.')),
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
        final result = await _complaintService.createComplaint(
          studentId: studentId,
          category: _category!,
          title: _titleController.text.trim(),
          description: _descController.text.trim(),
          location: _locationController.text.trim(),
          priority: _priority,
        );

        if (!mounted) return;
        widget.onRequestSubmitted?.call();
        Navigator.pop(context, true);

        final isSynced = result.isSynced;
        final hasPin = result.closureOtp != null;
        final message = isSynced
            ? (hasPin
                ? "Complaint registered! Proof-of-Fix PIN: ${result.closureOtp}"
                : "Complaint submitted and synced")
            : "Complaint saved locally. Will sync when online.";
        final snackBg = isSynced ? AppColors.success : const Color(0xFFD97706);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            duration: Duration(seconds: hasPin ? 6 : 3),
            content: Row(
              children: [
                Icon(
                  hasPin ? Icons.shield_rounded : (isSynced ? Icons.check_circle_outline_rounded : Icons.cloud_upload_outlined),
                  color: Colors.white,
                  size: 20,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    message,
                    style: GoogleFonts.plusJakartaSans(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            backgroundColor: snackBg,
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
                      "Report an Issue",
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
                DropdownButtonFormField<String>(
                  initialValue: _category,
                  dropdownColor: AppColors.surface,
                  icon: const Icon(Icons.expand_more_rounded, color: AppColors.textSecondary),
                  decoration: _buildInputDecoration("Category"),
                  items: _categories.map((cat) {
                    return DropdownMenuItem(
                      value: cat,
                      child: Text(cat, style: GoogleFonts.plusJakartaSans(color: AppColors.textPrimary)),
                    );
                  }).toList(),
                  onChanged: (value) => setState(() => _category = value),
                  validator: (value) => value == null ? 'Please select a category' : null,
                ).animate().fadeIn(delay: 50.ms).slideY(begin: 0.1),
                const SizedBox(height: 20),
                TextFormField(
                  controller: _titleController,
                  style: GoogleFonts.plusJakartaSans(color: AppColors.textPrimary),
                  decoration: _buildInputDecoration("Issue Title"),
                  validator: (value) => (value == null || value.trim().isEmpty) ? 'Please enter a title' : null,
                ).animate().fadeIn(delay: 100.ms).slideY(begin: 0.1),
                const SizedBox(height: 20),
                TextFormField(
                  controller: _locationController,
                  style: GoogleFonts.plusJakartaSans(color: AppColors.textPrimary),
                  decoration: _buildInputDecoration("Location (e.g. Room B-204)"),
                  validator: (value) => (value == null || value.trim().isEmpty) ? 'Please enter location' : null,
                ).animate().fadeIn(delay: 150.ms).slideY(begin: 0.1),
                const SizedBox(height: 20),
                // Priority selector
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Priority Level",
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: _priorities.map((p) {
                        final isSelected = _priority == p;
                        Color pColor;
                        if (p == 'URGENT') {
                          pColor = AppColors.danger;
                        } else if (p == 'HIGH') {
                          pColor = Colors.deepOrange;
                        } else if (p == 'MEDIUM') {
                          pColor = AppColors.primary;
                        } else {
                          pColor = AppColors.textSecondary;
                        }

                        return Expanded(
                          child: GestureDetector(
                            onTap: () => setState(() => _priority = p),
                            child: Container(
                              margin: const EdgeInsets.symmetric(horizontal: 3),
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              decoration: BoxDecoration(
                                color: isSelected ? pColor.withValues(alpha: 0.12) : AppColors.bg,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: isSelected ? pColor : AppColors.border,
                                  width: isSelected ? 1.5 : 1.0,
                                ),
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                p,
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: isSelected ? pColor : AppColors.textSecondary,
                                ),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ).animate().fadeIn(delay: 180.ms).slideY(begin: 0.1),
                const SizedBox(height: 20),
                TextFormField(
                  controller: _descController,
                  maxLines: 4,
                  style: GoogleFonts.plusJakartaSans(color: AppColors.textPrimary),
                  decoration: _buildInputDecoration("Description").copyWith(alignLabelWithHint: true),
                  validator: (value) => (value == null || value.trim().isEmpty) ? 'Please enter a description' : null,
                ).animate().fadeIn(delay: 200.ms).slideY(begin: 0.1),
                const SizedBox(height: 32),
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
                              strokeWidth: 2.5,
                              color: Colors.white,
                            ),
                          )
                        : Text(
                            "Submit Complaint",
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
    _titleController.dispose();
    _descController.dispose();
    _locationController.dispose();
    super.dispose();
  }
}
