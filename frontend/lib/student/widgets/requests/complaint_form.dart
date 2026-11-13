import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/haptics/app_haptics.dart';
import '../../../auth/providers/user_provider.dart';
import '../../services/complaint_service.dart';
import '../../../shared/widgets/motion/apple_bounceable.dart';
import '../../../shared/widgets/motion/apple_spring_scroll_physics.dart';

class ComplaintForm extends StatefulWidget {
  final VoidCallback? onRequestSubmitted;

  const ComplaintForm({Key? key, this.onRequestSubmitted}) : super(key: key);

  @override
  State<ComplaintForm> createState() => _ComplaintFormState();
}

class _ComplaintFormState extends State<ComplaintForm> {
  final _formKey = GlobalKey<FormState>();
  final ComplaintService _complaintService = ComplaintService();

  String? _category = 'Hostel/Room';
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

  Future<void> _submit() async {
    if (_isSubmitting) return;

    if (_formKey.currentState!.validate()) {
      if (_category == null) {
        AppHaptics.mediumImpact();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Please select a category.',
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
        final result = await _complaintService.createComplaint(
          studentId: studentId,
          category: _category!,
          title: _titleController.text.trim(),
          description: _descController.text.trim(),
          location: _locationController.text.trim(),
          priority: _priority,
        );

        if (!mounted) return;
        AppHaptics.lightImpact();
        widget.onRequestSubmitted?.call();
        Navigator.pop(context, true);

        final isSynced = result.isSynced;
        final hasPin = result.closureOtp != null && result.closureOtp!.isNotEmpty;
        final message = isSynced
            ? (hasPin
                ? "Complaint registered! Proof-of-Fix PIN: ${result.closureOtp}"
                : "Complaint submitted and synced")
            : (hasPin
                ? "Complaint saved locally. Proof-of-Fix PIN: ${result.closureOtp}"
                : "Complaint saved locally. Will sync when online.");
        final snackBg = isSynced ? AppColors.emerald : const Color(0xFFD97706);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            duration: Duration(seconds: hasPin ? 7 : 3),
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
            action: hasPin
                ? SnackBarAction(
                    label: 'COPY PIN',
                    textColor: Colors.amber,
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: result.closureOtp!));
                    },
                  )
                : null,
            backgroundColor: snackBg,
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
                          "Report an Issue",
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textPrimaryOf(context),
                            letterSpacing: -0.4,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          "Report campus grievance with Proof-of-Fix PIN",
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

                Text(
                  "CATEGORY",
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textSecondaryOf(context),
                    letterSpacing: 0.8,
                  ),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  initialValue: _category,
                  dropdownColor: AppColors.surfaceOf(context),
                  icon: const Icon(Icons.expand_more_rounded, color: AppColors.primary, size: 20),
                  decoration: _buildInputDecoration(context, "Select Grievance Category"),
                  items: _categories.map((cat) {
                    return DropdownMenuItem(
                      value: cat,
                      child: Text(
                        cat,
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
                    setState(() => _category = value);
                  },
                  validator: (value) => value == null ? 'Please select a category' : null,
                ),
                const SizedBox(height: 20),

                Text(
                  "ISSUE TITLE",
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textSecondaryOf(context),
                    letterSpacing: 0.8,
                  ),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _titleController,
                  style: GoogleFonts.plusJakartaSans(color: AppColors.textPrimaryOf(context), fontSize: 14),
                  decoration: _buildInputDecoration(
                    context,
                    "Brief Title",
                    hint: "e.g. Water leakage in bathroom, Wi-Fi down...",
                  ),
                  validator: (value) => (value == null || value.trim().isEmpty) ? 'Please enter a title' : null,
                ),
                const SizedBox(height: 20),

                Text(
                  "CAMPUS LOCATION",
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textSecondaryOf(context),
                    letterSpacing: 0.8,
                  ),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _locationController,
                  style: GoogleFonts.plusJakartaSans(color: AppColors.textPrimaryOf(context), fontSize: 14),
                  decoration: _buildInputDecoration(
                    context,
                    "Exact Location",
                    suffixIcon: Icons.location_on_outlined,
                    hint: "e.g. Block B, Room 204 or Lab 3",
                  ),
                  validator: (value) => (value == null || value.trim().isEmpty) ? 'Please enter location' : null,
                ),
                const SizedBox(height: 20),

                // Priority selector
                Text(
                  "URGENCY PRIORITY",
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textSecondaryOf(context),
                    letterSpacing: 0.8,
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
                      pColor = AppColors.textSecondaryOf(context);
                    }

                    return Expanded(
                      child: AppleBounceable(
                        scaleFactor: 0.94,
                        onTap: () {
                          AppHaptics.selectionClick();
                          setState(() => _priority = p);
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          margin: const EdgeInsets.symmetric(horizontal: 3),
                          padding: const EdgeInsets.symmetric(vertical: 9),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? pColor.withValues(alpha: 0.12)
                                : AppColors.surfaceAltOf(context),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isSelected
                                  ? pColor
                                  : AppColors.borderOf(context).withValues(alpha: 0.6),
                              width: isSelected ? 1.5 : 0.5,
                            ),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            p,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: isSelected ? pColor : AppColors.textSecondaryOf(context),
                              letterSpacing: 0.4,
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 20),

                Text(
                  "DETAILED DESCRIPTION",
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textSecondaryOf(context),
                    letterSpacing: 0.8,
                  ),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _descController,
                  maxLines: 4,
                  style: GoogleFonts.plusJakartaSans(
                    color: AppColors.textPrimaryOf(context),
                    fontSize: 14,
                    height: 1.4,
                  ),
                  decoration: _buildInputDecoration(
                    context,
                    "Description of the issue",
                    hint: "Provide specifics to help the maintenance team resolve promptly...",
                  ).copyWith(alignLabelWithHint: true),
                  validator: (value) => (value == null || value.trim().isEmpty) ? 'Please enter a description' : null,
                ),
                const SizedBox(height: 28),

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
                                strokeWidth: 2.2,
                                color: Colors.white,
                              ),
                            )
                          : Text(
                              "Submit Issue Report",
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
    _titleController.dispose();
    _descController.dispose();
    _locationController.dispose();
    super.dispose();
  }
}
