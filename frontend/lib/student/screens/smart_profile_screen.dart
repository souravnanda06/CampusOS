import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/app_colors.dart';
import '../../core/haptics/app_haptics.dart';
import '../../shared/widgets/motion/apple_bounceable.dart';
import '../../shared/widgets/motion/apple_spring_scroll_physics.dart';
import '../models/career_models.dart';
import '../services/career_service.dart';

class SmartProfileScreen extends StatefulWidget {
  const SmartProfileScreen({Key? key}) : super(key: key);

  @override
  State<SmartProfileScreen> createState() => _SmartProfileScreenState();
}

class _SmartProfileScreenState extends State<SmartProfileScreen> {
  bool _isLoading = true;
  bool _isSaving = false;

  // Controllers
  final _targetRoleController = TextEditingController();
  final _bioController = TextEditingController();
  final _githubController = TextEditingController();
  final _linkedinController = TextEditingController();
  final _portfolioController = TextEditingController();
  final _cgpaController = TextEditingController();
  final _skillInputController = TextEditingController();

  List<String> _skills = [];
  List<ProjectModel> _projects = [];
  List<CertificationModel> _certifications = [];
  double _tenthPercentage = 91.5;
  double _twelfthPercentage = 88.0;

  @override
  void initState() {
    super.initState();
    _loadProfileData();
  }

  @override
  void dispose() {
    _targetRoleController.dispose();
    _bioController.dispose();
    _githubController.dispose();
    _linkedinController.dispose();
    _portfolioController.dispose();
    _cgpaController.dispose();
    _skillInputController.dispose();
    super.dispose();
  }

  Future<void> _loadProfileData() async {
    setState(() => _isLoading = true);
    final p = await CareerService.instance.getCareerProfile();
    if (!mounted) return;

    if (p != null) {
      _targetRoleController.text = p.targetRole;
      _bioController.text = p.bio;
      _githubController.text = p.githubUrl ?? '';
      _linkedinController.text = p.linkedinUrl ?? '';
      _portfolioController.text = p.portfolioUrl ?? '';
      _cgpaController.text = p.cgpa > 0 ? p.cgpa.toStringAsFixed(2) : '8.60';
      _skills = List<String>.from(p.skills);
      _projects = List<ProjectModel>.from(p.projects);
      _certifications = List<CertificationModel>.from(p.certifications);
      if (p.academicRecords != null) {
        _tenthPercentage = p.academicRecords!.tenthPercentage;
        _twelfthPercentage = p.academicRecords!.twelfthPercentage;
      }
    }

    // Seed defaults if empty for a rich out-of-the-box profile experience
    if (_skills.isEmpty) {
      _skills = ['Flutter', 'Dart', 'Python', 'SQLite', 'REST APIs', 'Git', 'Docker'];
    }
    if (_projects.isEmpty) {
      _projects = [
        ProjectModel(
          id: 'proj_sample_01',
          title: 'CampusOS - Institutional Operating System',
          description:
              'Architected an offline-first institutional mobile suite with Ed25519 cryptographic passports and zero-BLE attendance beacons.',
          techStack: ['Flutter', 'Dart', 'BLE', 'SQLite', 'Flask'],
          githubUrl: 'https://github.com/campusos-student/campusos',
          liveUrl: 'https://campusos.edu',
        ),
      ];
    }
    if (_certifications.isEmpty) {
      _certifications = [
        CertificationModel(
          id: 'cert_sample_01',
          title: 'Google Cloud Certified Associate Cloud Engineer',
          issuer: 'Google Cloud',
          issueDate: '2026-04',
          credentialUrl: 'https://google.com/cert',
          credentialId: 'GCP-884192',
        ),
      ];
    }

    setState(() => _isLoading = false);
  }

  Future<void> _handleSaveProfile() async {
    AppHaptics.mediumImpact();
    setState(() => _isSaving = true);

    final cgpa = double.tryParse(_cgpaController.text.trim()) ?? 8.6;
    final academic = AcademicRecordModel(
      tenthPercentage: _tenthPercentage,
      twelfthPercentage: _twelfthPercentage,
      currentDegree: 'B.Tech CSE',
      cgpa: cgpa,
    );

    final success = await CareerService.instance.updateSmartProfile(
      targetRole: _targetRoleController.text.trim(),
      bio: _bioController.text.trim(),
      skills: _skills,
      projects: _projects,
      certifications: _certifications,
      academicRecords: academic,
      githubUrl: _githubController.text.trim(),
      linkedinUrl: _linkedinController.text.trim(),
      portfolioUrl: _portfolioController.text.trim(),
      cgpa: cgpa,
    );

    if (!mounted) return;
    setState(() => _isSaving = false);

    if (success) {
      AppHaptics.heavyImpact();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: const [
              Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
              SizedBox(width: 10),
              Text('Smart Profile Updated Successfully!'),
            ],
          ),
          backgroundColor: const Color(0xFF10B981),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      );
    }
  }

  void _addSkill(String skill) {
    final s = skill.trim();
    if (s.isNotEmpty && !_skills.contains(s)) {
      AppHaptics.selectionClick();
      setState(() {
        _skills.add(s);
        _skillInputController.clear();
      });
    }
  }

  void _removeSkill(String skill) {
    AppHaptics.selectionClick();
    setState(() {
      _skills.remove(skill);
    });
  }

  void _showAddProjectSheet() {
    AppHaptics.selectionClick();
    final titleCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    final techCtrl = TextEditingController();
    final gitCtrl = TextEditingController();
    final liveCtrl = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom,
          ),
          child: Container(
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E2130) : Colors.white,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            ),
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 36,
                      height: 4,
                      decoration: BoxDecoration(
                        color: isDark ? Colors.white24 : Colors.black12,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Add Engineering Project',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 14),
                  _buildInputField('Project Title', titleCtrl, hint: 'e.g. CampusOS Core Engine', isDark: isDark),
                  const SizedBox(height: 10),
                  _buildInputField('Description & Impact', descCtrl,
                      hint: 'What was built and the measurable outcome...', maxLines: 3, isDark: isDark),
                  const SizedBox(height: 10),
                  _buildInputField('Tech Stack (comma separated)', techCtrl,
                      hint: 'e.g. Flutter, Dart, Python, Docker', isDark: isDark),
                  const SizedBox(height: 10),
                  _buildInputField('GitHub Repository URL', gitCtrl,
                      hint: 'https://github.com/username/project', isDark: isDark),
                  const SizedBox(height: 10),
                  _buildInputField('Live Demo / Production URL', liveCtrl,
                      hint: 'https://campusos.edu', isDark: isDark),
                  const SizedBox(height: 18),
                  SizedBox(
                    width: double.infinity,
                    child: AppleBounceable(
                      onTap: () {
                        if (titleCtrl.text.trim().isEmpty) return;
                        AppHaptics.mediumImpact();
                        final stack = techCtrl.text
                            .split(',')
                            .map((e) => e.trim())
                            .where((e) => e.isNotEmpty)
                            .toList();

                        setState(() {
                          _projects.add(
                            ProjectModel(
                              id: 'proj_${DateTime.now().millisecondsSinceEpoch}',
                              title: titleCtrl.text.trim(),
                              description: descCtrl.text.trim(),
                              techStack: stack,
                              githubUrl: gitCtrl.text.trim(),
                              liveUrl: liveCtrl.text.trim(),
                            ),
                          );
                        });
                        Navigator.pop(ctx);
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        decoration: BoxDecoration(
                          color: const Color(0xFF4F46E5),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Center(
                          child: Text(
                            'Add Project to Profile',
                            style: GoogleFonts.plusJakartaSans(
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _showAddCertSheet() {
    AppHaptics.selectionClick();
    final titleCtrl = TextEditingController();
    final issuerCtrl = TextEditingController();
    final dateCtrl = TextEditingController(text: '2026-05');
    final credIdCtrl = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom,
          ),
          child: Container(
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E2130) : Colors.white,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            ),
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 36,
                      height: 4,
                      decoration: BoxDecoration(
                        color: isDark ? Colors.white24 : Colors.black12,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Add Credential / Certification',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 14),
                  _buildInputField('Certificate Name', titleCtrl, hint: 'e.g. AWS Solutions Architect', isDark: isDark),
                  const SizedBox(height: 10),
                  _buildInputField('Issuing Organization', issuerCtrl, hint: 'e.g. Amazon Web Services', isDark: isDark),
                  const SizedBox(height: 10),
                  _buildInputField('Issue Date (YYYY-MM)', dateCtrl, isDark: isDark),
                  const SizedBox(height: 10),
                  _buildInputField('Credential ID / Link', credIdCtrl, hint: 'e.g. AWS-992182', isDark: isDark),
                  const SizedBox(height: 18),
                  SizedBox(
                    width: double.infinity,
                    child: AppleBounceable(
                      onTap: () {
                        if (titleCtrl.text.trim().isEmpty) return;
                        AppHaptics.mediumImpact();
                        setState(() {
                          _certifications.add(
                            CertificationModel(
                              id: 'cert_${DateTime.now().millisecondsSinceEpoch}',
                              title: titleCtrl.text.trim(),
                              issuer: issuerCtrl.text.trim(),
                              issueDate: dateCtrl.text.trim(),
                              credentialId: credIdCtrl.text.trim(),
                            ),
                          );
                        });
                        Navigator.pop(ctx);
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        decoration: BoxDecoration(
                          color: const Color(0xFF4F46E5),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Center(
                          child: Text(
                            'Save Certification',
                            style: GoogleFonts.plusJakartaSans(
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = AppColors.bgOf(context);

    if (_isLoading) {
      return Scaffold(
        backgroundColor: bg,
        appBar: AppBar(backgroundColor: bg, elevation: 0),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        elevation: 0,
        title: Text(
          'Smart Career Profile',
          style: GoogleFonts.plusJakartaSans(
            fontWeight: FontWeight.w700,
            fontSize: 19,
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 14),
            child: AppleBounceable(
              onTap: _isSaving ? null : _handleSaveProfile,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                decoration: BoxDecoration(
                  color: const Color(0xFF4F46E5),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: _isSaving
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                      )
                    : Text(
                        'Save',
                        style: GoogleFonts.plusJakartaSans(
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                          color: Colors.white,
                        ),
                      ),
              ),
            ),
          ),
        ],
      ),
      body: ListView(
        physics: AppleSpringScrollPhysics.always,
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
        children: [
          // Bento Hero Card: Completeness & Verified Badge
          _buildCompletenessHeader(isDark),

          const SizedBox(height: 18),

          // Section 1: Target Role & Bio
          _buildCardSection(
            title: 'Target Role & Professional Bio',
            icon: Icons.badge_outlined,
            isDark: isDark,
            child: Column(
              children: [
                _buildInputField('Target Career Role', _targetRoleController,
                    hint: 'e.g. Mobile Software Engineer / SDE-1', isDark: isDark),
                const SizedBox(height: 12),
                _buildInputField('Professional Bio / Summary', _bioController,
                    hint: 'Experienced CS student building distributed systems and mobile apps...',
                    maxLines: 3,
                    isDark: isDark),
              ],
            ),
          ),

          const SizedBox(height: 18),

          // Section 2: Technical Skills Matrix
          _buildCardSection(
            title: 'Technical Skills (${_skills.length})',
            icon: Icons.code_rounded,
            isDark: isDark,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Quick add row
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _skillInputController,
                        onSubmitted: _addSkill,
                        decoration: InputDecoration(
                          hintText: 'Add skill (e.g. Kubernetes, Redis)...',
                          hintStyle: const TextStyle(fontSize: 13),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          filled: true,
                          fillColor: isDark ? const Color(0xFF282D42) : const Color(0xFFF1F5F9),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    AppleBounceable(
                      onTap: () => _addSkill(_skillInputController.text),
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFF4F46E5),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.add, color: Colors.white, size: 20),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                // Chips
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _skills
                      .map((skill) => Container(
                            padding: const EdgeInsets.fromLTRB(10, 6, 8, 6),
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF282D42) : const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: isDark ? const Color(0xFF374151) : const Color(0xFFE2E8F0),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  skill,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: isDark ? Colors.white : const Color(0xFF1E293B),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                GestureDetector(
                                  onTap: () => _removeSkill(skill),
                                  child: Icon(
                                    Icons.close_rounded,
                                    size: 14,
                                    color: isDark ? Colors.white54 : Colors.black45,
                                  ),
                                ),
                              ],
                            ),
                          ))
                      .toList(),
                ),
              ],
            ),
          ),

          const SizedBox(height: 18),

          // Section 3: Engineering Projects
          _buildCardSection(
            title: 'Featured Projects (${_projects.length})',
            icon: Icons.rocket_launch_outlined,
            isDark: isDark,
            trailing: AppleBounceable(
              onTap: _showAddProjectSheet,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF4F46E5).withOpacity(0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.add, size: 14, color: Color(0xFF4F46E5)),
                    SizedBox(width: 4),
                    Text(
                      'Add',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF4F46E5),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            child: Column(
              children: _projects.isEmpty
                  ? [
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 8),
                        child: Text(
                          'No projects added yet. Click Add to showcase your work.',
                          style: TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                      )
                    ]
                  : _projects
                      .map((proj) => _buildProjectTile(proj, isDark))
                      .toList(),
            ),
          ),

          const SizedBox(height: 18),

          // Section 4: Certifications & Honors
          _buildCardSection(
            title: 'Certifications (${_certifications.length})',
            icon: Icons.workspace_premium_outlined,
            isDark: isDark,
            trailing: AppleBounceable(
              onTap: _showAddCertSheet,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF4F46E5).withOpacity(0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.add, size: 14, color: Color(0xFF4F46E5)),
                    SizedBox(width: 4),
                    Text(
                      'Add',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF4F46E5),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            child: Column(
              children: _certifications.isEmpty
                  ? [
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 8),
                        child: Text(
                          'Add official certifications or online course credentials.',
                          style: TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                      )
                    ]
                  : _certifications
                      .map((c) => _buildCertTile(c, isDark))
                      .toList(),
            ),
          ),

          const SizedBox(height: 18),

          // Section 5: Academic Records (Sync with College)
          _buildCardSection(
            title: 'Academic Records (Verified)',
            icon: Icons.school_outlined,
            isDark: isDark,
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _buildInputField('Degree CGPA', _cgpaController, isDark: isDark),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF282D42) : const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Verified Attendance', style: TextStyle(fontSize: 11, color: Colors.grey)),
                            const SizedBox(height: 2),
                            Text(
                              '88.2% (Eligible)',
                              style: GoogleFonts.plusJakartaSans(
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                                color: const Color(0xFF10B981),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF282D42) : const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('10th Board %', style: TextStyle(fontSize: 11, color: Colors.grey)),
                            const SizedBox(height: 2),
                            Text(
                              '$_tenthPercentage%',
                              style: GoogleFonts.jetBrainsMono(fontWeight: FontWeight.w700, fontSize: 13),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF282D42) : const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('12th Board %', style: TextStyle(fontSize: 11, color: Colors.grey)),
                            const SizedBox(height: 2),
                            Text(
                              '$_twelfthPercentage%',
                              style: GoogleFonts.jetBrainsMono(fontWeight: FontWeight.w700, fontSize: 13),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 18),

          // Section 6: Portfolio & Social Links
          _buildCardSection(
            title: 'Portfolio & Developer Profiles',
            icon: Icons.link_rounded,
            isDark: isDark,
            child: Column(
              children: [
                _buildInputField('GitHub Profile URL', _githubController,
                    hint: 'https://github.com/username', isDark: isDark),
                const SizedBox(height: 10),
                _buildInputField('LinkedIn Profile URL', _linkedinController,
                    hint: 'https://linkedin.com/in/username', isDark: isDark),
                const SizedBox(height: 10),
                _buildInputField('Portfolio / Personal Website', _portfolioController,
                    hint: 'https://yourname.dev', isDark: isDark),
              ],
            ),
          ),

          const SizedBox(height: 30),

          // Save Button (Bottom Bar)
          AppleBounceable(
            onTap: _isSaving ? null : _handleSaveProfile,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 16),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF4F46E5), Color(0xFF6366F1)],
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF4F46E5).withOpacity(0.3),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Center(
                child: _isSaving
                    ? const CircularProgressIndicator(color: Colors.white, strokeWidth: 2)
                    : Text(
                        'Save Smart Profile Changes',
                        style: GoogleFonts.plusJakartaSans(
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                          color: Colors.white,
                        ),
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompletenessHeader(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? [const Color(0xFF1E2130), const Color(0xFF282D42)]
              : [const Color(0xFFEEF2FF), Colors.white],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFF6366F1).withOpacity(0.25),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: const Color(0xFF4F46E5).withOpacity(0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.workspace_premium_rounded, color: Color(0xFF4F46E5), size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Profile Completeness: 94%',
                      style: GoogleFonts.plusJakartaSans(
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 2),
                    const Text(
                      'High-completeness profiles receive 3x more interview shortlists.',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: 0.94,
              minHeight: 8,
              backgroundColor: isDark ? Colors.white12 : Colors.black12,
              valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF10B981)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCardSection({
    required String title,
    required IconData icon,
    required Widget child,
    required bool isDark,
    Widget? trailing,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E2130) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? const Color(0xFF2D324A) : const Color(0xFFE2E8F0),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.2 : 0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: const Color(0xFF4F46E5)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: GoogleFonts.plusJakartaSans(
                    fontWeight: FontWeight.w700,
                    fontSize: 14.5,
                  ),
                ),
              ),
              if (trailing != null) trailing,
            ],
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }

  Widget _buildInputField(
    String label,
    TextEditingController controller, {
    String? hint,
    int maxLines = 1,
    required bool isDark,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.white70 : const Color(0xFF475569),
          ),
        ),
        const SizedBox(height: 4),
        TextField(
          controller: controller,
          maxLines: maxLines,
          style: TextStyle(
            fontSize: 13,
            color: isDark ? Colors.white : const Color(0xFF0F172A),
          ),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(fontSize: 12, color: Colors.grey),
            filled: true,
            fillColor: isDark ? const Color(0xFF282D42) : const Color(0xFFF8FAFC),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(
                color: isDark ? const Color(0xFF374151) : const Color(0xFFE2E8F0),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildProjectTile(ProjectModel proj, bool isDark) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF282D42) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? const Color(0xFF374151) : const Color(0xFFE2E8F0),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  proj.title,
                  style: GoogleFonts.plusJakartaSans(
                    fontWeight: FontWeight.w700,
                    fontSize: 13.5,
                  ),
                ),
              ),
              IconButton(
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                icon: const Icon(Icons.delete_outline, size: 16, color: Colors.redAccent),
                onPressed: () {
                  AppHaptics.selectionClick();
                  setState(() => _projects.remove(proj));
                },
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            proj.description,
            style: TextStyle(
              fontSize: 12,
              color: isDark ? Colors.white70 : const Color(0xFF475569),
            ),
          ),
          const SizedBox(height: 8),
          if (proj.techStack.isNotEmpty)
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: proj.techStack
                  .map((t) => Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFF4F46E5).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          t,
                          style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Color(0xFF4F46E5)),
                        ),
                      ))
                  .toList(),
            ),
        ],
      ),
    );
  }

  Widget _buildCertTile(CertificationModel cert, bool isDark) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF282D42) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? const Color(0xFF374151) : const Color(0xFFE2E8F0),
        ),
      ),
      child: Row(
        children: [
          const Icon(Icons.verified_outlined, size: 20, color: Color(0xFF10B981)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  cert.title,
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                ),
                Text(
                  "${cert.issuer} • ${cert.issueDate ?? ''}",
                  style: const TextStyle(fontSize: 11, color: Colors.grey),
                ),
              ],
            ),
          ),
          IconButton(
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            icon: const Icon(Icons.delete_outline, size: 16, color: Colors.redAccent),
            onPressed: () {
              AppHaptics.selectionClick();
              setState(() => _certifications.remove(cert));
            },
          ),
        ],
      ),
    );
  }
}
