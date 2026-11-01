import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../core/services/expansion_api_service.dart';
import '../../core/theme/app_colors.dart';

class PostClassUpdateDialog extends StatefulWidget {
  final String teacherId;
  final String? initialCourseCode;
  final String? initialCourseName;
  final String? initialRoom;
  final String? initialBranch;
  final int? initialYear;
  final VoidCallback? onUpdatePublished;

  const PostClassUpdateDialog({
    Key? key,
    required this.teacherId,
    this.initialCourseCode,
    this.initialCourseName,
    this.initialRoom,
    this.initialBranch,
    this.initialYear,
    this.onUpdatePublished,
  }) : super(key: key);

  static Future<void> show(
    BuildContext context, {
    required String teacherId,
    String? initialCourseCode,
    String? initialCourseName,
    String? initialRoom,
    String? initialBranch,
    int? initialYear,
    VoidCallback? onUpdatePublished,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => PostClassUpdateDialog(
        teacherId: teacherId,
        initialCourseCode: initialCourseCode,
        initialCourseName: initialCourseName,
        initialRoom: initialRoom,
        initialBranch: initialBranch,
        initialYear: initialYear,
        onUpdatePublished: onUpdatePublished,
      ),
    );
  }

  @override
  State<PostClassUpdateDialog> createState() => _PostClassUpdateDialogState();
}

class _PostClassUpdateDialogState extends State<PostClassUpdateDialog> {
  final ExpansionApiService _api = ExpansionApiService.instance;
  late final TextEditingController _codeController;
  late final TextEditingController _nameController;
  late final TextEditingController _msgController;
  late final TextEditingController _newRoomController;
  late final TextEditingController _newTimeController;

  String _updateType = 'CANCELLED';
  String _selectedBranch = 'CSE';
  int _selectedYear = 3;
  final DateTime _newDate = DateTime.now();
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _codeController =
        TextEditingController(text: widget.initialCourseCode ?? 'CS301');
    _nameController = TextEditingController(
        text: widget.initialCourseName ?? 'Data Structures & Algorithms');
    _msgController = TextEditingController();
    _newRoomController = TextEditingController();
    _newTimeController = TextEditingController(text: '10:00 AM');
    _selectedBranch = widget.initialBranch ?? 'CSE';
    _selectedYear = widget.initialYear ?? 3;
  }

  @override
  void dispose() {
    _codeController.dispose();
    _nameController.dispose();
    _msgController.dispose();
    _newRoomController.dispose();
    _newTimeController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final msg = _msgController.text.trim();
    if (msg.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter an update message or reason')),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      await _api.createClassUpdate(
        teacherId: widget.teacherId,
        courseCode: _codeController.text.trim(),
        courseName: _nameController.text.trim(),
        updateType: _updateType,
        message: msg,
        originalDate: DateFormat('yyyy-MM-dd').format(DateTime.now()),
        originalRoom: widget.initialRoom ?? 'Room 204',
        newDate: _updateType == 'RESCHEDULED'
            ? DateFormat('yyyy-MM-dd').format(_newDate)
            : null,
        newTime: _updateType == 'RESCHEDULED' ? _newTimeController.text : null,
        newRoom: (_updateType == 'ROOM_CHANGED' || _updateType == 'RESCHEDULED')
            ? _newRoomController.text.trim()
            : null,
        affectedBranch: _selectedBranch,
        affectedYear: _selectedYear,
      );

      if (mounted) {
        Navigator.pop(context);
        widget.onUpdatePublished?.call();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              "Class update published to targeted students and displays",
              style: GoogleFonts.plusJakartaSans(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSubmitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed: $e'),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                const Icon(Icons.edit_calendar_rounded,
                    color: AppColors.warning, size: 24),
                const SizedBox(width: 10),
                Text(
                  "Post Class Update",
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              "Notify enrolled students instantly of cancellations, room swaps, or reschedule notices.",
              style: GoogleFonts.plusJakartaSans(
                fontSize: 13,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 18),
            Text(
              "Update Type",
              style: GoogleFonts.plusJakartaSans(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                border: Border.all(color: AppColors.border),
                borderRadius: BorderRadius.circular(14),
                color: AppColors.bg,
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _updateType,
                  isExpanded: true,
                  dropdownColor: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  elevation: 4,
                  items: const [
                    DropdownMenuItem(
                      value: 'CANCELLED',
                      child: Text('Class Cancelled'),
                    ),
                    DropdownMenuItem(
                      value: 'ROOM_CHANGED',
                      child: Text('Room Change'),
                    ),
                    DropdownMenuItem(
                      value: 'RESCHEDULED',
                      child: Text('Rescheduled'),
                    ),
                    DropdownMenuItem(
                      value: 'NOTICE',
                      child: Text('Announcement / Instructions'),
                    ),
                  ],
                  onChanged: (val) {
                    if (val != null) setState(() => _updateType = val);
                  },
                ),
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Course Code",
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 6),
                      TextField(
                        controller: _codeController,
                        decoration: InputDecoration(
                          hintText: "CS301",
                          filled: true,
                          fillColor: AppColors.bg,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide:
                                const BorderSide(color: AppColors.border),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 3,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Course Name",
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 6),
                      TextField(
                        controller: _nameController,
                        decoration: InputDecoration(
                          hintText: "Operating Systems",
                          filled: true,
                          fillColor: AppColors.bg,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide:
                                const BorderSide(color: AppColors.border),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Target Branch",
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          border: Border.all(color: AppColors.border),
                          borderRadius: BorderRadius.circular(14),
                          color: AppColors.bg,
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: _selectedBranch,
                            isExpanded: true,
                            dropdownColor: Colors.white,
                            borderRadius: BorderRadius.circular(14),
                            elevation: 4,
                            items: const [
                              DropdownMenuItem(value: 'CSE', child: Text('CSE')),
                              DropdownMenuItem(value: 'ECE', child: Text('ECE')),
                              DropdownMenuItem(value: 'EE', child: Text('EE')),
                              DropdownMenuItem(value: 'MECH', child: Text('MECH')),
                              DropdownMenuItem(value: 'CIVIL', child: Text('CIVIL')),
                            ],
                            onChanged: (val) {
                              if (val != null) {
                                setState(() => _selectedBranch = val);
                              }
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Target Year",
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          border: Border.all(color: AppColors.border),
                          borderRadius: BorderRadius.circular(14),
                          color: AppColors.bg,
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<int>(
                            value: _selectedYear,
                            isExpanded: true,
                            dropdownColor: Colors.white,
                            borderRadius: BorderRadius.circular(14),
                            elevation: 4,
                            items: const [
                              DropdownMenuItem(value: 1, child: Text('1st Year')),
                              DropdownMenuItem(value: 2, child: Text('2nd Year')),
                              DropdownMenuItem(value: 3, child: Text('3rd Year')),
                              DropdownMenuItem(value: 4, child: Text('4th Year')),
                            ],
                            onChanged: (val) {
                              if (val != null) {
                                setState(() => _selectedYear = val);
                              }
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (_updateType == 'ROOM_CHANGED' ||
                _updateType == 'RESCHEDULED') ...[
              const SizedBox(height: 14),
              Text(
                "New Room / Venue",
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: _newRoomController,
                decoration: InputDecoration(
                  hintText: "e.g. Lab 3 / Audi 2",
                  filled: true,
                  fillColor: AppColors.bg,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: AppColors.border),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 14),
            Text(
              "Reason / Instructions",
              style: GoogleFonts.plusJakartaSans(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            TextField(
              controller: _msgController,
              maxLines: 3,
              decoration: InputDecoration(
                hintText:
                    "e.g. Faculty attending BPUT symposium today. Class cancelled; makeup schedule will follow.",
                filled: true,
                fillColor: AppColors.bg,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: AppColors.border),
                ),
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 52,
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
                    ? const CircularProgressIndicator(color: Colors.white)
                    : Text(
                        "Broadcast Update",
                        style: GoogleFonts.plusJakartaSans(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
