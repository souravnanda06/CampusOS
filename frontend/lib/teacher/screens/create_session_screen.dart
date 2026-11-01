import 'package:flutter/material.dart';
import 'package:attendance_app/core/haptics/app_haptics.dart';

import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../auth/providers/user_provider.dart';
import '../../auth/models/user_model.dart';
import '../../shared/models/session_model.dart';
import '../../auth/services/auth_service.dart';
import '../../shared/services/session_service.dart';
import '../../router/app_routes.dart';
import '../../data/syllabus/syllabus_data.dart';

class CreateSessionScreen extends StatefulWidget {
  const CreateSessionScreen({Key? key}) : super(key: key);

  @override
  State<CreateSessionScreen> createState() => _CreateSessionScreenState();
}

class _CreateSessionScreenState extends State<CreateSessionScreen> {
  final _formKey = GlobalKey<FormState>();
  final _sessionService = SessionService();
  final _authService = AuthService();

  final TextEditingController _locationController = TextEditingController();

  String? _selectedCourse;
  String? _selectedBranch;
  String? _selectedYear;
  String? _selectedSubject;
  int _selectedPower = 3; // Default to Long Range

  final List<String> _courses = ['B.Tech', 'Diploma', 'MCA', 'BCA'];
  final List<String> _branches = [
    'CSE',
    'CSE-AIML',
    'CSE-DS',
    'EE',
    'Civil',
    'Mech',
    'ECE'
  ];
  final List<String> _years = ['1st', '2nd', '3rd', '4th'];

  List<Map<String, String?>> _savedTokens = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadSavedTokens();
  }

  @override
  void dispose() {
    _locationController.dispose();
    super.dispose();
  }

  Future<void> _loadSavedTokens() async {
    final user = Provider.of<UserProvider>(context, listen: false).user;
    if (user == null) return;

    final tokens = await _sessionService.getQuickStartTokens(user.id);
    if (mounted) {
      setState(() {
        _savedTokens = tokens;
      });
    }
  }

  Future<void> _saveToken() async {
    final user = Provider.of<UserProvider>(context, listen: false).user;
    if (user == null) return;

    Map<String, String?> newToken = {
      'course': _selectedCourse,
      'branch': _selectedBranch,
      'year': _selectedYear,
      'subject': _selectedSubject,
      'location': _locationController.text.trim(),
    };

    bool exists = _savedTokens.any((t) =>
        t['course'] == newToken['course'] &&
        t['branch'] == newToken['branch'] &&
        t['year'] == newToken['year'] &&
        t['subject'] == newToken['subject']);

    if (!exists) {
      setState(() {
        _savedTokens.insert(0, newToken);
        if (_savedTokens.length > 5) _savedTokens.removeLast();
      });
    }

    await _sessionService.saveQuickStartToken(
      userId: user.id,
      course: _selectedCourse,
      branch: _selectedBranch,
      year: _selectedYear,
      subject: _selectedSubject!,
    );
  }

  void _useToken(Map<String, String?> token) {
    AppHaptics.lightImpact();
    setState(() {
      _selectedCourse = token['course'];
      _selectedBranch = token['branch'];
      _selectedYear = token['year'];
      _selectedSubject = token['subject'];
      if (token['location'] != null && token['location']!.isNotEmpty) {
        _locationController.text = token['location']!;
      } else if (_locationController.text.isEmpty) {
        _locationController.text = "Classroom";
      }
    });
  }

  Future<void> _startAttendance() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    AppHaptics.mediumImpact();

    try {
      UserModel? teacher = _authService.currentUser;

      String sessionId = await _sessionService.createSession(
        name: _selectedSubject!,
        instructorName: teacher?.name ?? "Unknown Teacher",
        course: _selectedCourse,
        branch: _selectedBranch,
        year: _selectedYear,
        location: _locationController.text.trim(),
        startTime: DateTime.now(),
        endTime: DateTime.now().add(const Duration(minutes: 60)),
        txPowerLevel: _selectedPower,
      );

      await _saveToken();

      if (mounted) {
        await context.read<UserProvider>().setSessionId(sessionId);
      }

      SessionModel newSession = SessionModel(
        id: sessionId,
        name: _selectedSubject!,
        instructorName: teacher?.name ?? "Unknown",
        course: _selectedCourse,
        branch: _selectedBranch,
        year: _selectedYear,
        startTime: DateTime.now(),
        endTime: DateTime.now().add(const Duration(minutes: 60)),
        location: _locationController.text.trim(),
        isActive: true,
        txPowerLevel: _selectedPower,
      );

      if (!mounted) return;

      Navigator.pushReplacementNamed(
        context,
        AppRoutes.teacherBroadcasting,
        arguments: {
          'user': teacher!,
          'session': newSession,
        },
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FB),
      body: Column(
        children: [
          _buildHeader(),
          Expanded(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 40),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_savedTokens.isNotEmpty) ...[
                      _buildQuickStartSection(),
                      const SizedBox(height: 24),
                    ],
                    const SizedBox(height: 4), // Added extra spacing
                    _buildClassDetailsCard(),
                    const SizedBox(height: 24),
                    _buildAttendanceRangeSection(),
                    const SizedBox(height: 32),
                    _buildStartButton(),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding:
          const EdgeInsets.fromLTRB(28, 60, 20, 20), // Increased left padding
      decoration: BoxDecoration(
        color: Colors.white,
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            const Color(0xFF0F172A).withValues(alpha: 0.05),
            Colors.white.withValues(alpha: 0),
          ],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Row(
              children: [
                const Icon(Icons.arrow_back_ios_new_rounded,
                    size: 20, color: Color(0xFF1E293B)),
                const SizedBox(width: 8),
                Text(
                  "Start New Session",
                  style: GoogleFonts.outfit(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF1E293B),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.only(left: 28),
            child: Text(
              "Begin a new attendance session quickly.",
              style: GoogleFonts.outfit(
                fontSize: 14,
                color: const Color(0xFF64748B),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickStartSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Quick Start",
          style: GoogleFonts.outfit(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: const Color(0xFF1E293B),
          ),
        ),
        Text(
          "Recent classes you taught",
          style: GoogleFonts.outfit(
            fontSize: 13,
            color: const Color(0xFF64748B),
          ),
        ),
        const SizedBox(height: 8), // Reduced spacing
        SizedBox(
          height: 86, // Increased height
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            itemCount: _savedTokens.length,
            clipBehavior: Clip.none,
            itemBuilder: (context, index) {
              final token = _savedTokens[index];
              return _buildQuickStartCard(token);
            },
          ),
        ),
      ],
    )
        .animate()
        .slideX(begin: -0.1, end: 0, duration: 400.ms, curve: Curves.easeOut);
  }

  Widget _buildQuickStartCard(Map<String, String?> token) {
    return Container(
      width: 240,
      margin: const EdgeInsets.only(right: 12),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _useToken(token),
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey.shade200),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04), // Micro shadow
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF3B82F6).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.book_rounded,
                      color: Color(0xFF3B82F6),
                      size: 23), // Increased icon size
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        token['subject'] ?? 'Subject',
                        style: GoogleFonts.outfit(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF1E293B),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        "${token['course']} • ${token['year']}",
                        style: GoogleFonts.outfit(
                          fontSize: 12,
                          color: const Color(0xFF64748B),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildClassDetailsCard() {
    bool showBranch = _selectedCourse != 'BCA' && _selectedCourse != 'MCA';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Class Details",
          style: GoogleFonts.outfit(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: const Color(0xFF1E293B),
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: const Color(0xFFE7E9EC)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: _buildDropdown(
                      label: "Course",
                      value: _selectedCourse,
                      items: _courses,
                      onChanged: (v) => setState(() {
                        _selectedCourse = v;
                        _selectedBranch = null;
                        _selectedSubject = null;
                      }),
                    ),
                  ),
                  if (showBranch) ...[
                    const SizedBox(width: 16),
                    Expanded(
                      child: _buildDropdown(
                        label: "Branch",
                        value: _selectedBranch,
                        items: _branches,
                        onChanged: (v) => setState(() {
                          _selectedBranch = v;
                          _selectedSubject = null;
                        }),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _buildDropdown(
                      label: "Year",
                      value: _selectedYear,
                      items: _years,
                      onChanged: (v) => setState(() {
                        _selectedYear = v;
                        _selectedSubject = null;
                      }),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildTextField(
                      controller: _locationController,
                      label: "Room / Lab",
                      icon: Icons.location_on_outlined,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _buildSubjectDropdown(),
            ],
          ),
        ),
      ],
    ).animate().fadeIn(delay: 200.ms).slideY(begin: 0.1, end: 0);
  }

  Widget _buildDropdown({
    required String label,
    required String? value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.outfit(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: const Color(0xFF64748B),
          ),
        ),
        const SizedBox(height: 6),
        DropdownButtonFormField<String>(
          initialValue: value,
          isExpanded: true,
          decoration: InputDecoration(
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide:
                  const BorderSide(color: Color(0xFF3B82F6), width: 1.5),
            ),
            filled: true,
            fillColor: const Color(0xFFF8F9FB),
          ),
          items: items
              .map((item) => DropdownMenuItem(
                    value: item,
                    child: Text(
                      item,
                      style: GoogleFonts.outfit(
                          fontSize: 14, color: const Color(0xFF1E293B)),
                    ),
                  ))
              .toList(),
          onChanged: onChanged,
          validator: (v) => v == null ? 'Required' : null,
          icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 20),
        ),
      ],
    );
  }

  Widget _buildSubjectDropdown() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Subject",
          style: GoogleFonts.outfit(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: const Color(0xFF64748B),
          ),
        ),
        const SizedBox(height: 6),
        DropdownButtonFormField<String>(
          initialValue: _selectedSubject,
          isExpanded: true,
          hint: Text("Select Subject",
              style: GoogleFonts.outfit(color: Colors.grey.shade400)),
          decoration: InputDecoration(
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide:
                  const BorderSide(color: Color(0xFF3B82F6), width: 1.5),
            ),
            filled: true,
            fillColor: const Color(0xFFF8F9FB),
          ),
          items: SyllabusData.getSubjects(
                  _selectedCourse, _selectedBranch, _selectedYear)
              .map((s) => DropdownMenuItem(
                    value: s,
                    child: Text(
                      s,
                      style: GoogleFonts.outfit(
                          fontSize: 14, color: const Color(0xFF1E293B)),
                    ),
                  ))
              .toList(),
          onChanged: (val) => setState(() => _selectedSubject = val),
          validator: (val) => val == null ? 'Required' : null,
          icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 20),
        ),
      ],
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.outfit(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: const Color(0xFF64748B),
          ),
        ),
        const SizedBox(height: 6),
        RepaintBoundary(
          child: TextFormField(
            controller: controller,
            style:
                GoogleFonts.outfit(fontSize: 14, color: const Color(0xFF1E293B)),
            decoration: InputDecoration(
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide:
                    const BorderSide(color: Color(0xFF3B82F6), width: 1.5),
              ),
              filled: true,
              fillColor: const Color(0xFFF8F9FB),
              prefixIcon: Icon(icon, size: 18, color: Colors.grey.shade400),
            ),
            validator: (v) => v!.isEmpty ? 'Required' : null,
          ),
        ),
      ],
    );
  }

  Widget _buildAttendanceRangeSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Attendance Range",
          style: GoogleFonts.outfit(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: const Color(0xFF1E293B),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildRangeChip(
                label: "Short Range (1ft)",
                icon: Icons.signal_wifi_0_bar_rounded,
                isSelected: _selectedPower == 0,
                onTap: () => setState(() => _selectedPower = 0),
                color: const Color(0xFFF59E0B),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildRangeChip(
                label: "Long Range (10m)",
                icon: Icons.wifi_tethering,
                isSelected: _selectedPower == 3,
                onTap: () => setState(() => _selectedPower = 3),
                color: const Color(0xFF3B82F6),
              ),
            ),
          ],
        ).animate().slideY(begin: 0.2, end: 0, delay: 300.ms), // Slide up
        const SizedBox(height: 6), // Reduced spacing
        Container(
          padding: const EdgeInsets.symmetric(
              horizontal: 12, vertical: 8), // More compact
          decoration: BoxDecoration(
            color: const Color(0xFFF5F7FA), // Slight tint
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Icon(Icons.info_outline_rounded,
                  size: 16, color: Colors.grey.shade500), // Soft gray icon
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _selectedPower == 0
                      ? "Strict proximity mode. Best for small rooms."
                      : "For labs, large rooms, or flexible seating.",
                  style: GoogleFonts.outfit(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                  ),
                ),
              ),
            ],
          ),
        ).animate().fadeIn(delay: 400.ms),
      ],
    );
  }

  Widget _buildRangeChip({
    required String label,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
    required Color color,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18), // Increased radius
        child: AnimatedContainer(
          duration: 200.ms,
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            color: isSelected ? color.withValues(alpha: 0.1) : Colors.white,
            borderRadius: BorderRadius.circular(18), // Increased radius
            border: Border.all(
              color: isSelected
                  ? color
                  : const Color(0xFFDADCE0), // Darker inactive border
              width: isSelected ? 1.5 : 1,
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: color.withValues(alpha: 0.25), // Stronger shadow
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    )
                  ]
                : [],
          ),
          child: Column(
            children: [
              Icon(icon,
                  color: isSelected
                      ? color
                      : color.withValues(alpha: 0.8)), // Increased opacity
              const SizedBox(height: 8),
              Text(
                label,
                style: GoogleFonts.outfit(
                  fontSize: 13,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                  color: isSelected ? color : const Color(0xFF64748B),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStartButton() {
    return Container(
      width: double.infinity,
      height: 58,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16), // Reduced radius
        gradient: const LinearGradient(
          colors: [Color(0xFF2563EB), Color(0xFF4F46E5)],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF2563EB).withValues(alpha: 0.3),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _isLoading ? null : _startAttendance,
          borderRadius: BorderRadius.circular(16),
          child: Center(
            child: _isLoading
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2.5,
                    ),
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        "Start Session",
                        style: GoogleFonts.outfit(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Icon(Icons.arrow_forward_rounded,
                          color: Colors.white, size: 20),
                    ],
                  ),
          ),
        ),
      ),
    )
        .animate()
        .fadeIn(delay: 500.ms)
        .slideY(begin: 0.2, end: 0)
        .shimmer(delay: 1000.ms, duration: 1500.ms); // Added shimmer glow
  }
}
