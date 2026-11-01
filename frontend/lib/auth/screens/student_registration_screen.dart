import 'dart:io';
import 'package:attendance_app/core/haptics/app_haptics.dart';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:device_info_plus/device_info_plus.dart';

import '../../core/theme/app_colors.dart';
import '../../router/app_routes.dart';
import '../services/auth_service.dart';

/// Apple-grade dedicated Student Registration Screen for CampusOS.
///
/// Security constraints:
/// - Role is strictly pinned to 'student' (no public role selection or admin elevation).
/// - Device ID is bound to the student profile during registration.
/// - Validates passwords, academic fields, and handles duplicate email errors truthfully.
class StudentRegistrationScreen extends StatefulWidget {
  final AuthService? authService;

  const StudentRegistrationScreen({Key? key, this.authService}) : super(key: key);

  @override
  State<StudentRegistrationScreen> createState() => _StudentRegistrationScreenState();
}

class _StudentRegistrationScreenState extends State<StudentRegistrationScreen> {
  final _formKey = GlobalKey<FormState>();

  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _regNoController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _isLoading = false;

  String? _selectedCourse = 'B.Tech';
  String? _selectedBranch = 'CSE';
  String? _selectedYear = '1st';

  final List<String> _courses = ['B.Tech', 'Diploma', 'MCA', 'BCA'];
  final List<String> _branches = [
    'CSE',
    'CSE-AIML',
    'CSE-DS',
    'EE',
    'Civil',
    'Mech',
    'ECE',
  ];
  final List<String> _years = ['1st', '2nd', '3rd', '4th'];

  late final AuthService _authService;

  @override
  void initState() {
    super.initState();
    _authService = widget.authService ?? AuthService();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _regNoController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<String?> _getDeviceId() async {
    final deviceInfo = DeviceInfoPlugin();
    try {
      if (Platform.isAndroid) {
        final androidInfo = await deviceInfo.androidInfo;
        return androidInfo.id;
      } else if (Platform.isIOS) {
        final iosInfo = await deviceInfo.iosInfo;
        return iosInfo.identifierForVendor;
      }
    } catch (e) {
      debugPrint("Device ID discovery fallback: $e");
    }
    return null;
  }

  Future<void> _handleRegister() async {
    FocusScope.of(context).unfocus();

    if (!_formKey.currentState!.validate()) {
      AppHaptics.heavyImpact();
      return;
    }

    if (_passwordController.text != _confirmPasswordController.text) {
      AppHaptics.heavyImpact();
      _showErrorSnackBar("Passwords do not match. Please re-enter.");
      return;
    }

    setState(() => _isLoading = true);
    AppHaptics.lightImpact();

    try {
      final deviceId = await _getDeviceId();
      String? finalBranch = _selectedBranch;
      if (_selectedCourse == 'BCA' || _selectedCourse == 'MCA') {
        finalBranch = null;
      }

      final user = await _authService.signUp(
        name: _nameController.text.trim(),
        email: _emailController.text.trim(),
        password: _passwordController.text,
        role: 'student', // Strictly pinned to student role
        registrationNumber: _regNoController.text.trim(),
        course: _selectedCourse,
        branch: finalBranch,
        year: _selectedYear,
        deviceId: deviceId,
      );

      if (user != null && mounted) {
        AppHaptics.mediumImpact();
        Navigator.of(context).pushNamedAndRemoveUntil(
          AppRoutes.home,
          (route) => false,
        );
      } else if (mounted) {
        _showErrorSnackBar("Registration could not be completed.");
      }
    } catch (e) {
      if (mounted) {
        AppHaptics.heavyImpact();
        final rawMsg = e.toString().replaceAll('Exception: ', '').trim();
        if (rawMsg.toLowerCase().contains('already exists')) {
          _showErrorSnackBar("An account with this email already exists. Please sign in.");
        } else if (rawMsg.toLowerCase().contains('socket') || rawMsg.toLowerCase().contains('connection')) {
          _showErrorSnackBar("Unable to reach CampusOS servers. Please check your internet connection.");
        } else {
          _showErrorSnackBar(rawMsg.isNotEmpty ? rawMsg : "Registration failed. Please try again.");
        }
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline_rounded, color: Colors.white, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: GoogleFonts.plusJakartaSans(
                  color: Colors.white,
                  fontWeight: FontWeight.w500,
                  fontSize: 13,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: AppColors.danger,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool showBranch = _selectedCourse != 'BCA' && _selectedCourse != 'MCA';

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.bg,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppColors.textPrimary, size: 20),
          onPressed: () {
            AppHaptics.lightImpact();
            Navigator.of(context).pop();
          },
        ),
        title: Text(
          "Student Registration",
          style: GoogleFonts.plusJakartaSans(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header badge
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: const BoxDecoration(
                          color: AppColors.primaryLight,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.school_rounded, color: AppColors.primary, size: 22),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "Create Student Profile",
                              style: GoogleFonts.plusJakartaSans(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              "Profile is bound to this device for attendance & passport.",
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 12,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 18),

                // Form Container
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppColors.border),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.02),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Full Name
                      _buildFieldLabel("Full Name"),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _nameController,
                        style: GoogleFonts.plusJakartaSans(fontSize: 14, color: AppColors.textPrimary),
                        textInputAction: TextInputAction.next,
                        decoration: _buildInputDecoration(
                          hintText: "e.g. John Doe",
                          icon: Icons.person_outline_rounded,
                        ),
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) return "Name is required";
                          return null;
                        },
                      ),

                      const SizedBox(height: 16),

                      // Registration Number
                      _buildFieldLabel("Registration / Roll Number"),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _regNoController,
                        style: GoogleFonts.plusJakartaSans(fontSize: 14, color: AppColors.textPrimary),
                        textInputAction: TextInputAction.next,
                        decoration: _buildInputDecoration(
                          hintText: "e.g. 21BCSE042",
                          icon: Icons.badge_outlined,
                        ),
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) return "Registration number is required";
                          return null;
                        },
                      ),

                      const SizedBox(height: 16),

                      // Course & Year row
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildFieldLabel("Course"),
                                const SizedBox(height: 6),
                                _buildDropdown(
                                  value: _selectedCourse,
                                  items: _courses,
                                  onChanged: (v) {
                                    setState(() {
                                      _selectedCourse = v;
                                      if (v == 'BCA' || v == 'MCA') {
                                        _selectedBranch = null;
                                      } else {
                                        _selectedBranch ??= 'CSE';
                                      }
                                    });
                                  },
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildFieldLabel("Year"),
                                const SizedBox(height: 6),
                                _buildDropdown(
                                  value: _selectedYear,
                                  items: _years,
                                  onChanged: (v) => setState(() => _selectedYear = v),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),

                      if (showBranch) ...[
                        const SizedBox(height: 16),
                        _buildFieldLabel("Branch / Department"),
                        const SizedBox(height: 6),
                        _buildDropdown(
                          value: _selectedBranch,
                          items: _branches,
                          onChanged: (v) => setState(() => _selectedBranch = v),
                        ),
                      ],

                      const SizedBox(height: 16),

                      // Email Address
                      _buildFieldLabel("Institutional Email"),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _emailController,
                        style: GoogleFonts.plusJakartaSans(fontSize: 14, color: AppColors.textPrimary),
                        keyboardType: TextInputType.emailAddress,
                        textInputAction: TextInputAction.next,
                        autofillHints: const [AutofillHints.email],
                        decoration: _buildInputDecoration(
                          hintText: "e.g. student@campus.edu",
                          icon: Icons.alternate_email_rounded,
                        ),
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) return "Email is required";
                          if (!v.contains('@') || !v.contains('.')) return "Enter a valid email address";
                          return null;
                        },
                      ),

                      const SizedBox(height: 16),

                      // Password
                      _buildFieldLabel("Password"),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _passwordController,
                        obscureText: _obscurePassword,
                        style: GoogleFonts.plusJakartaSans(fontSize: 14, color: AppColors.textPrimary),
                        textInputAction: TextInputAction.next,
                        autofillHints: const [AutofillHints.newPassword],
                        decoration: _buildInputDecoration(
                          hintText: "Minimum 6 characters",
                          icon: Icons.lock_outline_rounded,
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                              color: AppColors.textSecondary,
                              size: 20,
                            ),
                            onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                          ),
                        ),
                        validator: (v) {
                          if (v == null || v.isEmpty) return "Password is required";
                          if (v.length < 6) return "Password must be at least 6 characters";
                          return null;
                        },
                      ),

                      const SizedBox(height: 16),

                      // Confirm Password
                      _buildFieldLabel("Confirm Password"),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _confirmPasswordController,
                        obscureText: _obscureConfirmPassword,
                        style: GoogleFonts.plusJakartaSans(fontSize: 14, color: AppColors.textPrimary),
                        textInputAction: TextInputAction.done,
                        autofillHints: const [AutofillHints.newPassword],
                        decoration: _buildInputDecoration(
                          hintText: "Re-enter password",
                          icon: Icons.lock_outline_rounded,
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscureConfirmPassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                              color: AppColors.textSecondary,
                              size: 20,
                            ),
                            onPressed: () => setState(() => _obscureConfirmPassword = !_obscureConfirmPassword),
                          ),
                        ),
                        validator: (v) {
                          if (v == null || v.isEmpty) return "Please confirm password";
                          if (v != _passwordController.text) return "Passwords do not match";
                          return null;
                        },
                      ),

                      const SizedBox(height: 24),

                      // Submit Button
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _handleRegister,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            disabledBackgroundColor: AppColors.primary.withValues(alpha: 0.5),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            elevation: 0,
                          ),
                          child: _isLoading
                              ? const SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2,
                                  ),
                                )
                              : Text(
                                  "Create Account",
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // Return to login link
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      "Already have an account? ",
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 14,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    GestureDetector(
                      onTap: () {
                        AppHaptics.lightImpact();
                        Navigator.of(context).pop();
                      },
                      child: Text(
                        "Sign In",
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 30),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFieldLabel(String label) {
    return Text(
      label,
      style: GoogleFonts.plusJakartaSans(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: AppColors.textPrimary,
      ),
    );
  }

  InputDecoration _buildInputDecoration({
    required String hintText,
    required IconData icon,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      hintText: hintText,
      hintStyle: GoogleFonts.plusJakartaSans(
        fontSize: 13,
        color: AppColors.textTertiary,
      ),
      prefixIcon: Icon(icon, color: AppColors.textSecondary, size: 19),
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: AppColors.bg,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.danger),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.danger, width: 1.5),
      ),
    );
  }

  Widget _buildDropdown({
    required String? value,
    required List<String> items,
    required Function(String?) onChanged,
  }) {
    return DropdownButtonFormField<String>(
      initialValue: value,
      items: items
          .map((item) => DropdownMenuItem(
                value: item,
                child: Text(
                  item,
                  style: GoogleFonts.plusJakartaSans(fontSize: 13, color: AppColors.textPrimary),
                ),
              ))
          .toList(),
      dropdownColor: AppColors.surface,
      onChanged: onChanged,
      decoration: InputDecoration(
        filled: true,
        fillColor: AppColors.bg,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
        ),
      ),
    );
  }
}
