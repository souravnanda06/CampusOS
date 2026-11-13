import 'dart:io';
import 'dart:typed_data';
import 'package:attendance_app/core/haptics/app_haptics.dart';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/theme/app_colors.dart';
import '../../router/app_routes.dart';
import '../models/user_model.dart';
import '../services/auth_service.dart';

/// Apple-grade dedicated Student Registration Screen for CampusOS.
///
/// Security constraints:
/// - Role is strictly pinned to 'student' (no public role selection or admin elevation).
/// - Student photo upload is mandatory during registration for admin identity review.
/// - Account starts in PENDING state until verified and activated by an administrator.
/// - Device ID is bound to the student profile during registration.
class StudentRegistrationScreen extends StatefulWidget {
  final AuthService? authService;
  final Future<({Uint8List bytes, String filename})?> Function()? photoPickerOverride;

  const StudentRegistrationScreen({
    Key? key,
    this.authService,
    this.photoPickerOverride,
  }) : super(key: key);

  @override
  State<StudentRegistrationScreen> createState() => _StudentRegistrationScreenState();
}

class _StudentRegistrationScreenState extends State<StudentRegistrationScreen> {
  final _formKey = GlobalKey<FormState>();

  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _regNoController = TextEditingController();
  final _phoneController = TextEditingController();
  final _parentPhoneController = TextEditingController();
  final _parentNameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _isLoading = false;

  Uint8List? _photoBytes;
  String? _photoFilename;
  bool _photoError = false;
  final ImagePicker _imagePicker = ImagePicker();

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
    _phoneController.dispose();
    _parentPhoneController.dispose();
    _parentNameController.dispose();
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

  Future<void> _pickPhoto(ImageSource source) async {
    try {
      final XFile? picked = await _imagePicker.pickImage(
        source: source,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );
      if (picked == null) return;
      final bytes = await picked.readAsBytes();
      if (!mounted) return;
      setState(() {
        _photoBytes = bytes;
        _photoFilename = picked.name.isNotEmpty ? picked.name : 'student_photo.jpg';
        _photoError = false;
      });
    } catch (e) {
      if (mounted) {
        _showErrorSnackBar("Unable to select photo. Please check camera or gallery permissions.");
      }
    }
  }

  Future<void> _showPhotoSourceSheet() async {
    AppHaptics.selectionClick();
    if (widget.photoPickerOverride != null) {
      final result = await widget.photoPickerOverride!();
      if (result != null && mounted) {
        setState(() {
          _photoBytes = result.bytes;
          _photoFilename = result.filename;
          _photoError = false;
        });
      }
      return;
    }

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Text(
                "Upload Student Photo",
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                "A clear portrait photo is required for admin identity verification.",
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 16),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: const BoxDecoration(
                    color: AppColors.primaryLight,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.camera_alt_rounded, color: AppColors.primary),
                ),
                title: Text(
                  "Take Photo",
                  style: GoogleFonts.plusJakartaSans(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    color: AppColors.textPrimary,
                  ),
                ),
                subtitle: Text(
                  "Use camera to capture a live portrait",
                  style: GoogleFonts.plusJakartaSans(fontSize: 12, color: AppColors.textSecondary),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickPhoto(ImageSource.camera);
                },
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: const BoxDecoration(
                    color: AppColors.primaryLight,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.photo_library_rounded, color: AppColors.primary),
                ),
                title: Text(
                  "Choose from Gallery",
                  style: GoogleFonts.plusJakartaSans(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    color: AppColors.textPrimary,
                  ),
                ),
                subtitle: Text(
                  "Select an existing JPG or PNG photo",
                  style: GoogleFonts.plusJakartaSans(fontSize: 12, color: AppColors.textSecondary),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickPhoto(ImageSource.gallery);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showPendingApprovalDialog(UserModel user) async {
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.hourglass_top_rounded, color: AppColors.primary, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                "Pending Admin Approval",
                style: GoogleFonts.plusJakartaSans(
                  fontWeight: FontWeight.bold,
                  fontSize: 17,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
          ],
        ),
        content: Text(
          "Thank you, ${user.name}. Your registration and photo have been submitted.\n\n"
          "An administrator must review and approve your profile before your student account is activated. You will be able to sign in once approved.",
          style: GoogleFonts.plusJakartaSans(
            fontSize: 13.5,
            height: 1.5,
            color: AppColors.textSecondary,
          ),
        ),
        actions: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                Navigator.of(ctx).pop();
                Navigator.of(context).pop();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              child: Text(
                "Back to Sign In",
                style: GoogleFonts.plusJakartaSans(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _handleRegister() async {
    FocusScope.of(context).unfocus();

    final bool formValid = _formKey.currentState!.validate();
    final bool hasPhoto = _photoBytes != null && _photoBytes!.isNotEmpty;

    if (!hasPhoto) {
      setState(() => _photoError = true);
    }

    if (!formValid || !hasPhoto) {
      AppHaptics.heavyImpact();
      if (!hasPhoto && formValid) {
        _showErrorSnackBar("Please upload your photo to complete registration.");
      }
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
        phone: _phoneController.text.trim(),
        parentPhone: _parentPhoneController.text.trim(),
        parentName: _parentNameController.text.trim(),
        photoBytes: _photoBytes,
        photoFilename: _photoFilename,
      );

      if (user != null && mounted) {
        AppHaptics.mediumImpact();
        if (user.isPendingApproval) {
          setState(() => _isLoading = false);
          await _showPendingApprovalDialog(user);
        } else {
          Navigator.of(context).pushNamedAndRemoveUntil(
            AppRoutes.home,
            (route) => false,
          );
        }
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
                              "Upload your photo. Account activates after admin approval.",
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
                      // Student Photo Upload (Required)
                      _buildFieldLabel("Student Photo (Required)"),
                      const SizedBox(height: 8),
                      InkWell(
                        onTap: _isLoading ? null : _showPhotoSourceSheet,
                        borderRadius: BorderRadius.circular(16),
                        child: Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: AppColors.bg,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: _photoError
                                  ? AppColors.danger
                                  : (_photoBytes != null ? AppColors.primary : AppColors.border),
                              width: _photoError || _photoBytes != null ? 1.4 : 1.0,
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 64,
                                height: 64,
                                decoration: BoxDecoration(
                                  color: AppColors.primaryLight,
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(color: AppColors.border),
                                ),
                                clipBehavior: Clip.antiAlias,
                                child: _photoBytes != null
                                    ? Image.memory(_photoBytes!, fit: BoxFit.cover)
                                    : const Icon(
                                        Icons.add_a_photo_rounded,
                                        color: AppColors.primary,
                                        size: 26,
                                      ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _photoBytes != null ? "Photo Selected" : "Upload Portrait Photo",
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.textPrimary,
                                      ),
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      _photoBytes != null
                                          ? (_photoFilename ?? "Tap to change photo")
                                          : "Tap to take a photo or choose from gallery",
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 12,
                                        color: _photoError ? AppColors.danger : AppColors.textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              Icon(
                                _photoBytes != null ? Icons.edit_rounded : Icons.chevron_right_rounded,
                                color: AppColors.textSecondary,
                                size: 20,
                              ),
                            ],
                          ),
                        ),
                      ),
                      if (_photoError) ...[
                        const SizedBox(height: 6),
                        Padding(
                          padding: const EdgeInsets.only(left: 12),
                          child: Text(
                            "Photo is required for admin verification",
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 12,
                              color: AppColors.danger,
                            ),
                          ),
                        ),
                      ],

                      const SizedBox(height: 18),

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

                      const SizedBox(height: 16),

                      // Student WhatsApp Number
                      _buildFieldLabel("Student WhatsApp Number"),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _phoneController,
                        style: GoogleFonts.plusJakartaSans(fontSize: 14, color: AppColors.textPrimary),
                        keyboardType: TextInputType.phone,
                        textInputAction: TextInputAction.next,
                        decoration: _buildInputDecoration(
                          hintText: "e.g. 9876543210 (10 digits)",
                          icon: Icons.phone_android_rounded,
                        ),
                        validator: (v) {
                          if (v != null && v.trim().isNotEmpty) {
                            final digits = v.replaceAll(RegExp(r'\D'), '');
                            if (digits.length < 10) return "Enter a valid 10-digit number";
                          }
                          return null;
                        },
                      ),

                      const SizedBox(height: 16),

                      // Parent / Guardian Name
                      _buildFieldLabel("Parent / Guardian Name (Optional)"),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _parentNameController,
                        style: GoogleFonts.plusJakartaSans(fontSize: 14, color: AppColors.textPrimary),
                        textInputAction: TextInputAction.next,
                        decoration: _buildInputDecoration(
                          hintText: "e.g. Ramesh Sharma",
                          icon: Icons.family_restroom_rounded,
                        ),
                      ),

                      const SizedBox(height: 16),

                      // Parent WhatsApp Number
                      _buildFieldLabel("Parent WhatsApp (Optional - For Gate Pass & Attendance Alerts)"),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _parentPhoneController,
                        style: GoogleFonts.plusJakartaSans(fontSize: 14, color: AppColors.textPrimary),
                        keyboardType: TextInputType.phone,
                        textInputAction: TextInputAction.done,
                        decoration: _buildInputDecoration(
                          hintText: "e.g. 9123456789",
                          icon: Icons.notifications_active_outlined,
                        ),
                        validator: (v) {
                          if (v != null && v.trim().isNotEmpty) {
                            final digits = v.replaceAll(RegExp(r'\D'), '');
                            if (digits.length < 10) return "Enter a valid 10-digit number";
                          }
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
