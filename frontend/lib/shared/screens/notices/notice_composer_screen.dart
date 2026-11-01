import 'package:flutter/material.dart';
import 'package:attendance_app/core/haptics/app_haptics.dart';

import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_colors.dart';
import '../../../auth/models/user_model.dart';
import '../../../student/models/notice_model.dart';
import '../../../student/services/notice_service.dart';

class NoticeComposerScreen extends StatefulWidget {
  final UserModel user;
  final NoticeModel? notice;

  const NoticeComposerScreen({Key? key, required this.user, this.notice})
      : super(key: key);

  @override
  State<NoticeComposerScreen> createState() => _NoticeComposerScreenState();
}

class _NoticeComposerScreenState extends State<NoticeComposerScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _bodyController = TextEditingController();
  final _targetValueController = TextEditingController();
  final _actionPayloadController = TextEditingController();

  String _category = 'ACADEMIC';
  String _priority = 'NORMAL';
  String _targetType = 'BRANCH';
  String _actionType = 'NONE';
  DateTime? _expiresAt;

  bool _isSubmitting = false;
  final NoticeService _noticeService = NoticeService();

  final List<String> _branchPresets = [
    'CSE',
    'ECE',
    'MECH',
    'CIVIL',
    'IT',
    'EE'
  ];
  final List<String> _yearPresets = ['1st', '2nd', '3rd', '4th'];

  @override
  void initState() {
    super.initState();
    final isTeacher = widget.user.role == 'teacher';

    if (isTeacher) {
      _targetType = 'BRANCH';
      _targetValueController.text = widget.user.branch ?? 'CSE';
    } else {
      _targetType = 'ALL';
    }

    if (widget.notice != null) {
      final n = widget.notice!;
      _titleController.text = n.title;
      _bodyController.text = n.body;
      _category = n.category.isNotEmpty ? n.category.toUpperCase() : 'ACADEMIC';
      _priority = n.priority.isNotEmpty ? n.priority.toUpperCase() : 'NORMAL';
      _targetType = n.targetType.isNotEmpty ? n.targetType.toUpperCase() : 'BRANCH';

      if (isTeacher && _targetType == 'ALL') {
        _targetType = 'BRANCH';
      }

      _targetValueController.text = n.targetValue ?? '';
      _actionType = n.actionType ?? 'NONE';
      if (_actionType.isEmpty) _actionType = 'NONE';
      _actionPayloadController.text = n.actionPayload?.toString() ?? '';
      _expiresAt = n.expiresAt;
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _bodyController.dispose();
    _targetValueController.dispose();
    _actionPayloadController.dispose();
    super.dispose();
  }

  Future<void> _selectExpiryDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _expiresAt ?? DateTime.now().add(const Duration(days: 7)),
      firstDate: DateTime.now(),
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
      if (!mounted) return;
      final time = await showTimePicker(
        context: context,
        initialTime: const TimeOfDay(hour: 23, minute: 59),
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
      if (time != null) {
        setState(() {
          _expiresAt = DateTime(
            picked.year,
            picked.month,
            picked.day,
            time.hour,
            time.minute,
          );
        });
      }
    }
  }

  void _showNoticePreview() {
    if (!_formKey.currentState!.validate()) return;

    if (['BRANCH', 'YEAR', 'STUDENT'].contains(_targetType) &&
        _targetValueController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select or specify a target value.'),
          backgroundColor: AppColors.warning,
        ),
      );
      return;
    }

    AppHaptics.mediumImpact();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _buildPreviewSheet(ctx),
    );
  }

  Widget _buildPreviewSheet(BuildContext ctx) {
    final title = _titleController.text.trim();
    final body = _bodyController.text.trim();
    final audienceFormatted = _getAudiencePreviewString();

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag handle
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
          const SizedBox(height: 16),

          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "Notice Preview",
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                  letterSpacing: -0.3,
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.primaryLight,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  "Student View",
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Rendered Student Notice Card
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: AppColors.bg,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        _category,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primary,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                    if (_priority != 'NORMAL') ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 3),
                        decoration: BoxDecoration(
                          color: _priority == 'URGENT'
                              ? AppColors.danger.withValues(alpha: 0.1)
                              : AppColors.warning.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          _priority,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: _priority == 'URGENT'
                                ? AppColors.danger
                                : AppColors.warning,
                          ),
                        ),
                      ),
                    ],
                    const Spacer(),
                    Text(
                      "Just now",
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11,
                        color: AppColors.textTertiary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  title,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(Icons.person_outline_rounded,
                        size: 13, color: AppColors.textSecondary),
                    const SizedBox(width: 4),
                    Text(
                      "By ${widget.user.name}",
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11,
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  body,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 13,
                    color: AppColors.textPrimary,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 14),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.groups_rounded,
                          size: 14, color: AppColors.primary),
                      const SizedBox(width: 6),
                      Text(
                        audienceFormatted,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Actions
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(ctx),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.textSecondary,
                    side: const BorderSide(color: AppColors.border),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: Text(
                    "Back to Edit",
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    _confirmAndPublish('PUBLISHED');
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: Text(
                    "Publish Notice",
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _getAudiencePreviewString() {
    if (_targetType == 'ALL') return "Entire Campus / All Students";
    if (_targetType == 'BRANCH') {
      return "${_targetValueController.text.trim()} Department";
    }
    if (_targetType == 'YEAR') {
      return "${_targetValueController.text.trim()} Year Students";
    }
    if (_targetType == 'STUDENT') {
      return "Student ID: ${_targetValueController.text.trim()}";
    }
    return _targetType;
  }

  Future<void> _confirmAndPublish(String status) async {
    if (!_formKey.currentState!.validate()) return;

    if (['BRANCH', 'YEAR', 'STUDENT'].contains(_targetType) &&
        _targetValueController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Target value is required for selected audience.'),
          backgroundColor: AppColors.warning,
        ),
      );
      return;
    }

    if (status == 'PUBLISHED') {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(
            "Publish Notice?",
            style: GoogleFonts.plusJakartaSans(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Audience: ${_getAudiencePreviewString()}",
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                "Students in this audience will receive push notifications and see this notice on their feeds.",
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                  height: 1.4,
                ),
              ),
            ],
          ),
          actionsPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(
                "Cancel",
                style: GoogleFonts.plusJakartaSans(
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: Text(
                "Publish",
                style: GoogleFonts.plusJakartaSans(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      );

      if (confirmed != true) return;
    }

    setState(() => _isSubmitting = true);

    final data = <String, dynamic>{
      'title': _titleController.text.trim(),
      'body': _bodyController.text.trim(),
      'category': _category,
      'priority': _priority,
      'target_type': _targetType,
      'status': status,
    };

    if (['BRANCH', 'YEAR', 'STUDENT'].contains(_targetType)) {
      data['target_value'] = _targetValueController.text.trim();
    }

    if (_actionType != 'NONE') {
      data['action_type'] = _actionType;
      data['action_payload'] = _actionPayloadController.text.trim();
    } else {
      data['action_type'] = null;
      data['action_payload'] = null;
    }

    if (_expiresAt != null) {
      data['expires_at'] = _expiresAt!.toIso8601String();
    } else {
      data['expires_at'] = null;
    }

    try {
      if (widget.notice != null) {
        await _noticeService.updateNotice(
          widget.notice!.id,
          data,
          requesterId: widget.user.id,
        );
      } else {
        await _noticeService.createNotice(
          data,
          requesterId: widget.user.id,
        );
      }

      if (mounted) {
        AppHaptics.mediumImpact();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              status == 'PUBLISHED'
                  ? 'Notice published successfully!'
                  : 'Notice saved as draft.',
            ),
            backgroundColor: AppColors.success,
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString()),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.notice != null;
    final isTeacher = widget.user.role == 'teacher';

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        title: Text(
          isEditing ? "Edit Notice" : "Create Notice",
          style: GoogleFonts.plusJakartaSans(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
        actions: [
          TextButton(
            onPressed: _isSubmitting ? null : _showNoticePreview,
            child: Text(
              "Preview",
              style: GoogleFonts.plusJakartaSans(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppColors.primary,
              ),
            ),
          ),
          const SizedBox(width: 8),
        ],
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(0.5),
          child: Divider(height: 0.5, color: AppColors.border),
        ),
      ),
      body: _isSubmitting
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primary))
          : Form(
              key: _formKey,
              child: ListView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
                children: [
                  // Section 1: Content
                  _buildSectionHeader("NOTICE DETAILS"),
                  const SizedBox(height: 8),
                  RepaintBoundary(
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Title",
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 6),
                          RepaintBoundary(
                            child: TextFormField(
                              controller: _titleController,
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textPrimary,
                              ),
                              decoration: InputDecoration(
                                hintText: "e.g. Mid-Sem Examination Schedule",
                                hintStyle: GoogleFonts.plusJakartaSans(
                                  fontSize: 13,
                                  color: AppColors.textTertiary,
                                ),
                                filled: true,
                                fillColor: AppColors.bg,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide:
                                      const BorderSide(color: AppColors.border),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide:
                                      const BorderSide(color: AppColors.border),
                                ),
                                contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 14, vertical: 12),
                              ),
                              validator: (v) => v == null || v.trim().isEmpty
                                  ? "Title is required"
                                  : null,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            "Message",
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 6),
                          RepaintBoundary(
                            child: TextFormField(
                              controller: _bodyController,
                              maxLines: 5,
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 13,
                                color: AppColors.textPrimary,
                                height: 1.4,
                              ),
                              decoration: InputDecoration(
                                hintText:
                                    "Write the announcement details for students...",
                                hintStyle: GoogleFonts.plusJakartaSans(
                                  fontSize: 13,
                                  color: AppColors.textTertiary,
                                ),
                                filled: true,
                                fillColor: AppColors.bg,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide:
                                      const BorderSide(color: AppColors.border),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide:
                                      const BorderSide(color: AppColors.border),
                                ),
                                contentPadding: const EdgeInsets.all(14),
                              ),
                              validator: (v) => v == null || v.trim().isEmpty
                                  ? "Message is required"
                                  : null,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Section 2: Classification
                  _buildSectionHeader("CLASSIFICATION"),
                  const SizedBox(height: 8),
                  RepaintBoundary(
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Category",
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              'ACADEMIC',
                              'EXAM',
                              'EVENT',
                              'GENERAL',
                              'FEE',
                              'OTHER'
                            ].map((cat) {
                              final isSel = _category == cat;
                              return ChoiceChip(
                                label: Text(cat),
                                selected: isSel,
                                selectedColor: AppColors.primary,
                                backgroundColor: AppColors.bg,
                                labelStyle: GoogleFonts.plusJakartaSans(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: isSel ? Colors.white : AppColors.textSecondary,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  side: BorderSide(
                                    color: isSel ? AppColors.primary : AppColors.border,
                                  ),
                                ),
                                onSelected: (_) => setState(() => _category = cat),
                              );
                            }).toList(),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            "Priority",
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: ['NORMAL', 'HIGH', 'URGENT'].map((p) {
                              final isSel = _priority == p;
                              Color activeColor = AppColors.primary;
                              if (p == 'HIGH') activeColor = AppColors.warning;
                              if (p == 'URGENT') activeColor = AppColors.danger;

                              return Expanded(
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 4),
                                  child: InkWell(
                                    onTap: () {
                                      AppHaptics.selectionClick();
                                      setState(() => _priority = p);
                                    },
                                    borderRadius: BorderRadius.circular(10),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(vertical: 8),
                                      alignment: Alignment.center,
                                      decoration: BoxDecoration(
                                        color: isSel
                                            ? activeColor
                                            : AppColors.bg,
                                        borderRadius: BorderRadius.circular(10),
                                        border: Border.all(
                                          color: isSel ? activeColor : AppColors.border,
                                        ),
                                      ),
                                      child: Text(
                                        p,
                                        style: GoogleFonts.plusJakartaSans(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w700,
                                          color: isSel ? Colors.white : AppColors.textSecondary,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Section 3: Target Audience (STRICT SCOPE)
                  _buildSectionHeader("TARGET AUDIENCE"),
                  const SizedBox(height: 8),
                  RepaintBoundary(
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Target Scope",
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 8),
                          // Scope selection options
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              if (!isTeacher)
                                _buildScopeChip('ALL', 'All Students (Global)'),
                              _buildScopeChip('BRANCH', 'Department / Branch'),
                              _buildScopeChip('YEAR', 'Academic Year'),
                              _buildScopeChip('STUDENT', 'Specific Student'),
                            ],
                          ),
                          const SizedBox(height: 16),

                          // Sub-selectors based on target type
                          if (_targetType == 'BRANCH') ...[
                            Text(
                              "Select Branch",
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textSecondary,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: _branchPresets.map((br) {
                                final isSel =
                                    _targetValueController.text.trim() == br;
                                return ChoiceChip(
                                  label: Text(br),
                                  selected: isSel,
                                  selectedColor: AppColors.primary,
                                  backgroundColor: AppColors.bg,
                                  labelStyle: GoogleFonts.plusJakartaSans(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: isSel ? Colors.white : AppColors.textPrimary,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    side: BorderSide(
                                      color: isSel
                                          ? AppColors.primary
                                          : AppColors.border,
                                    ),
                                  ),
                                  onSelected: (_) {
                                    setState(() => _targetValueController.text = br);
                                  },
                                );
                              }).toList(),
                            ),
                          ] else if (_targetType == 'YEAR') ...[
                            Text(
                              "Select Academic Year",
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textSecondary,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Row(
                              children: _yearPresets.map((yr) {
                                final isSel =
                                    _targetValueController.text.trim() == yr;
                                return Expanded(
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 4),
                                    child: ChoiceChip(
                                      label: Center(child: Text(yr)),
                                      selected: isSel,
                                      selectedColor: AppColors.primary,
                                      backgroundColor: AppColors.bg,
                                      labelStyle: GoogleFonts.plusJakartaSans(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                        color: isSel
                                            ? Colors.white
                                            : AppColors.textPrimary,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8),
                                        side: BorderSide(
                                          color: isSel
                                              ? AppColors.primary
                                              : AppColors.border,
                                        ),
                                      ),
                                      onSelected: (_) {
                                        setState(
                                            () => _targetValueController.text = yr);
                                      },
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                          ] else if (_targetType == 'STUDENT') ...[
                            Text(
                              "Student Registration ID / User ID",
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textSecondary,
                              ),
                            ),
                            const SizedBox(height: 6),
                            RepaintBoundary(
                              child: TextFormField(
                                controller: _targetValueController,
                                style: GoogleFonts.plusJakartaSans(fontSize: 13),
                                decoration: InputDecoration(
                                  hintText: "e.g. REG-2024-042 or stud_101",
                                  hintStyle: GoogleFonts.plusJakartaSans(
                                    fontSize: 12,
                                    color: AppColors.textTertiary,
                                  ),
                                  filled: true,
                                  fillColor: AppColors.bg,
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                    borderSide:
                                        const BorderSide(color: AppColors.border),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                    borderSide:
                                        const BorderSide(color: AppColors.border),
                                  ),
                                  contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 14, vertical: 12),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Section 4: Expiry (Optional)
                  _buildSectionHeader("EXPIRATION (OPTIONAL)"),
                  const SizedBox(height: 8),
                  RepaintBoundary(
                    child: InkWell(
                      onTap: _selectExpiryDate,
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 14),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: const BoxDecoration(
                                color: AppColors.primaryLight,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.calendar_today_rounded,
                                  size: 16, color: AppColors.primary),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    "Notice Expiry Date",
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                  Text(
                                    _expiresAt == null
                                        ? "No automatic expiry set"
                                        : "Expires on ${DateFormat('EEE, MMM d, yyyy · hh:mm a').format(_expiresAt!)}",
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 11,
                                      color: _expiresAt == null
                                          ? AppColors.textSecondary
                                          : AppColors.danger,
                                      fontWeight: _expiresAt != null
                                          ? FontWeight.w600
                                          : FontWeight.normal,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (_expiresAt != null)
                              IconButton(
                                icon: const Icon(Icons.close_rounded,
                                    size: 18, color: AppColors.textSecondary),
                                onPressed: () =>
                                    setState(() => _expiresAt = null),
                              )
                            else
                              const Icon(Icons.chevron_right_rounded,
                                  size: 20, color: AppColors.textTertiary),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 28),

                  // Buttons: Save Draft + Publish
                  RepaintBoundary(
                    child: Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: _isSubmitting
                                ? null
                                : () => _confirmAndPublish('DRAFT'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.textPrimary,
                              side: const BorderSide(color: AppColors.border),
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            child: Text(
                              "Save Draft",
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 2,
                          child: ElevatedButton(
                            onPressed: _isSubmitting
                                ? null
                                : () => _confirmAndPublish('PUBLISHED'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: Colors.white,
                              elevation: 0,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            child: Text(
                              isEditing ? "Update & Publish" : "Publish Notice",
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildScopeChip(String type, String label) {
    final isSel = _targetType == type;
    return ChoiceChip(
      label: Text(label),
      selected: isSel,
      selectedColor: AppColors.primary,
      backgroundColor: AppColors.bg,
      labelStyle: GoogleFonts.plusJakartaSans(
        fontSize: 12,
        fontWeight: FontWeight.w700,
        color: isSel ? Colors.white : AppColors.textPrimary,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(
          color: isSel ? AppColors.primary : AppColors.border,
        ),
      ),
      onSelected: (_) {
        setState(() {
          _targetType = type;
          if (type == 'BRANCH' && _targetValueController.text.trim().isEmpty) {
            _targetValueController.text = widget.user.branch ?? 'CSE';
          }
        });
      },
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: GoogleFonts.plusJakartaSans(
        fontSize: 11,
        fontWeight: FontWeight.w800,
        color: AppColors.textSecondary,
        letterSpacing: 0.8,
      ),
    );
  }
}
