import 'performance_config.dart';

enum ScreenRole {
  auth('AUTH / ONBOARDING'),
  student('STUDENT'),
  teacher('TEACHER'),
  admin('ADMIN'),
  warden('WARDEN'),
  messStaff('MESS STAFF'),
  security('SECURITY'),
  shared('SHARED'),
  modal('MODALS / BOTTOM SHEETS / FORMS');

  final String displayName;
  const ScreenRole(this.displayName);
}

class ScreenPerformanceMetadata {
  final String id;
  final ScreenRole role;
  final String screenName;
  final String route;
  final String filePath;
  final String? requiredRole;
  final bool requiresNetwork;
  final bool requiresCamera;
  final bool requiresBle;
  final bool requiresBiometrics;
  final bool hasList;
  final bool hasCharts;
  final bool hasAnimations;
  final bool supportsScrollBenchmarking;
  final bool supportsMemoryBenchmarking;
  final ValidationMode validationMode;
  final String? hardwareNotes;

  const ScreenPerformanceMetadata({
    required this.id,
    required this.role,
    required this.screenName,
    required this.route,
    required this.filePath,
    this.requiredRole,
    this.requiresNetwork = false,
    this.requiresCamera = false,
    this.requiresBle = false,
    this.requiresBiometrics = false,
    this.hasList = false,
    this.hasCharts = false,
    this.hasAnimations = false,
    this.supportsScrollBenchmarking = false,
    this.supportsMemoryBenchmarking = true,
    this.validationMode = ValidationMode.automatedSoftware,
    this.hardwareNotes,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'role': role.displayName,
        'screenName': screenName,
        'route': route,
        'filePath': filePath,
        'requiredRole': requiredRole,
        'requiresNetwork': requiresNetwork,
        'requiresCamera': requiresCamera,
        'requiresBle': requiresBle,
        'requiresBiometrics': requiresBiometrics,
        'hasList': hasList,
        'hasCharts': hasCharts,
        'hasAnimations': hasAnimations,
        'supportsScrollBenchmarking': supportsScrollBenchmarking,
        'supportsMemoryBenchmarking': supportsMemoryBenchmarking,
        'validationMode': validationMode.name,
        'hardwareNotes': hardwareNotes,
      };
}

class ScreenPerformanceRegistry {
  ScreenPerformanceRegistry._();

  static const List<ScreenPerformanceMetadata> entries = [
    // -------------------------------------------------------------------------
    // A. Authentication & Onboarding
    // -------------------------------------------------------------------------
    ScreenPerformanceMetadata(
      id: 'auth_splash',
      role: ScreenRole.auth,
      screenName: 'SplashScreen',
      route: '/',
      filePath: 'lib/screens/splash_screen.dart',
      hasAnimations: true,
      supportsScrollBenchmarking: false,
      supportsMemoryBenchmarking: false,
      validationMode: ValidationMode.automatedSoftware,
    ),
    ScreenPerformanceMetadata(
      id: 'auth_onboarding',
      role: ScreenRole.auth,
      screenName: 'OnboardingScreen',
      route: '/onboarding',
      filePath: 'lib/auth/screens/onboarding_screen.dart',
      hasCharts: true,
      hasAnimations: true,
      supportsScrollBenchmarking: true,
    ),
    ScreenPerformanceMetadata(
      id: 'auth_login',
      role: ScreenRole.auth,
      screenName: 'LoginScreen',
      route: '/login',
      filePath: 'lib/auth/screens/login_screen.dart',
      hasAnimations: true,
      supportsScrollBenchmarking: false,
    ),
    ScreenPerformanceMetadata(
      id: 'auth_register',
      role: ScreenRole.auth,
      screenName: 'StudentRegistrationScreen',
      route: '/register',
      filePath: 'lib/auth/screens/student_registration_screen.dart',
      supportsScrollBenchmarking: true,
    ),
    ScreenPerformanceMetadata(
      id: 'auth_home_dispatcher',
      role: ScreenRole.auth,
      screenName: 'HomeScreen',
      route: '/home',
      filePath: 'lib/screens/home_screen.dart',
      requiresNetwork: true,
    ),
    ScreenPerformanceMetadata(
      id: 'auth_history',
      role: ScreenRole.auth,
      screenName: 'HistoryScreen',
      route: '/history',
      filePath: 'lib/screens/history_screen.dart',
      requiredRole: 'student',
      hasList: true,
      supportsScrollBenchmarking: true,
    ),

    // -------------------------------------------------------------------------
    // B. Student Role
    // -------------------------------------------------------------------------
    ScreenPerformanceMetadata(
      id: 'student_shell',
      role: ScreenRole.student,
      screenName: 'StudentShellScreen',
      route: '/home',
      filePath: 'lib/student/screens/student_shell_screen.dart',
      requiredRole: 'student',
      hasAnimations: true,
    ),
    ScreenPerformanceMetadata(
      id: 'student_home',
      role: ScreenRole.student,
      screenName: 'StudentHomeContent',
      route: 'tab_0_home',
      filePath: 'lib/student/widgets/student_home_content.dart',
      requiredRole: 'student',
      hasList: true,
      hasCharts: true,
      supportsScrollBenchmarking: true,
    ),
    ScreenPerformanceMetadata(
      id: 'student_passport',
      role: ScreenRole.student,
      screenName: 'PassportScreen',
      route: 'tab_1_passport',
      filePath: 'lib/student/screens/passport_screen.dart',
      requiredRole: 'student',
      requiresBle: true,
      hasAnimations: true,
      validationMode: ValidationMode.manualHardwareValidation,
      hardwareNotes: 'Requires physical BLE peripheral advertising and camera QR presentation',
    ),
    ScreenPerformanceMetadata(
      id: 'student_requests',
      role: ScreenRole.student,
      screenName: 'RequestsScreen',
      route: 'tab_2_requests',
      filePath: 'lib/student/screens/requests_screen.dart',
      requiredRole: 'student',
      hasList: true,
      supportsScrollBenchmarking: true,
    ),
    ScreenPerformanceMetadata(
      id: 'student_profile',
      role: ScreenRole.student,
      screenName: 'ProfileScreen',
      route: '/student/profile',
      filePath: 'lib/student/screens/profile_screen.dart',
      requiredRole: 'student',
      supportsScrollBenchmarking: true,
    ),
    ScreenPerformanceMetadata(
      id: 'student_ready',
      role: ScreenRole.student,
      screenName: 'ReadyScreen',
      route: '/student/ready',
      filePath: 'lib/student/screens/ready_screen.dart',
      requiredRole: 'student',
      requiresBle: true,
      hasAnimations: true,
      validationMode: ValidationMode.manualHardwareValidation,
      hardwareNotes: 'Requires nearby BLE class beacon hardware transmission',
    ),
    ScreenPerformanceMetadata(
      id: 'student_success',
      role: ScreenRole.student,
      screenName: 'SuccessScreen',
      route: '/student/success',
      filePath: 'lib/student/screens/success_screen.dart',
      requiredRole: 'student',
      hasAnimations: true,
    ),
    ScreenPerformanceMetadata(
      id: 'student_timetable',
      role: ScreenRole.student,
      screenName: 'TimetableScreen',
      route: '/student/timetable',
      filePath: 'lib/student/screens/timetable_screen.dart',
      requiredRole: 'student',
      hasList: true,
      supportsScrollBenchmarking: true,
    ),
    ScreenPerformanceMetadata(
      id: 'student_analytics',
      role: ScreenRole.student,
      screenName: 'StudentAnalyticsScreen',
      route: '/student/analytics',
      filePath: 'lib/student/screens/student_analytics_screen.dart',
      requiredRole: 'student',
      hasCharts: true,
      supportsScrollBenchmarking: true,
    ),
    ScreenPerformanceMetadata(
      id: 'student_mess',
      role: ScreenRole.student,
      screenName: 'StudentMessScreen',
      route: '/student/mess',
      filePath: 'lib/student/screens/mess_screen.dart',
      requiredRole: 'student',
      hasList: true,
      supportsScrollBenchmarking: true,
    ),

    // -------------------------------------------------------------------------
    // C. Teacher Role
    // -------------------------------------------------------------------------
    ScreenPerformanceMetadata(
      id: 'teacher_shell',
      role: ScreenRole.teacher,
      screenName: 'TeacherShellScreen',
      route: '/home',
      filePath: 'lib/teacher/screens/teacher_shell_screen.dart',
      requiredRole: 'teacher',
      hasAnimations: true,
    ),
    ScreenPerformanceMetadata(
      id: 'teacher_home',
      role: ScreenRole.teacher,
      screenName: 'TeacherHomeContent',
      route: 'tab_0_home',
      filePath: 'lib/teacher/widgets/teacher_home_content.dart',
      requiredRole: 'teacher',
      hasList: true,
      supportsScrollBenchmarking: true,
    ),
    ScreenPerformanceMetadata(
      id: 'teacher_classes',
      role: ScreenRole.teacher,
      screenName: 'TeacherClassesScreen',
      route: '/teacher/classes',
      filePath: 'lib/teacher/screens/teacher_classes_screen.dart',
      requiredRole: 'teacher',
      hasList: true,
      supportsScrollBenchmarking: true,
    ),
    ScreenPerformanceMetadata(
      id: 'teacher_analytics',
      role: ScreenRole.teacher,
      screenName: 'TeacherAnalyticsScreen',
      route: '/teacher/analytics',
      filePath: 'lib/teacher/screens/teacher_analytics_screen.dart',
      requiredRole: 'teacher',
      hasCharts: true,
      supportsScrollBenchmarking: true,
    ),
    ScreenPerformanceMetadata(
      id: 'teacher_profile',
      role: ScreenRole.teacher,
      screenName: 'TeacherProfileScreen',
      route: '/teacher/profile',
      filePath: 'lib/teacher/screens/teacher_profile_screen.dart',
      requiredRole: 'teacher',
      supportsScrollBenchmarking: true,
    ),
    ScreenPerformanceMetadata(
      id: 'teacher_create_session',
      role: ScreenRole.teacher,
      screenName: 'CreateSessionScreen',
      route: '/teacher/create-session',
      filePath: 'lib/teacher/screens/create_session_screen.dart',
      requiredRole: 'teacher',
      supportsScrollBenchmarking: true,
    ),
    ScreenPerformanceMetadata(
      id: 'teacher_broadcasting',
      role: ScreenRole.teacher,
      screenName: 'BroadcastingScreen',
      route: '/teacher/broadcasting',
      filePath: 'lib/teacher/screens/broadcasting_screen.dart',
      requiredRole: 'teacher',
      requiresBle: true,
      hasList: true,
      hasCharts: true,
      hasAnimations: true,
      validationMode: ValidationMode.manualHardwareValidation,
      hardwareNotes: 'Requires physical BLE peripheral advertising stack',
    ),
    ScreenPerformanceMetadata(
      id: 'teacher_class_detail',
      role: ScreenRole.teacher,
      screenName: 'ClassDetailScreen',
      route: '/teacher/class-detail',
      filePath: 'lib/teacher/screens/class_detail_screen.dart',
      requiredRole: 'teacher',
      hasList: true,
      supportsScrollBenchmarking: true,
    ),
    ScreenPerformanceMetadata(
      id: 'teacher_session_attendance',
      role: ScreenRole.teacher,
      screenName: 'SessionAttendanceScreen',
      route: '/teacher/session-attendance',
      filePath: 'lib/teacher/screens/session_attendance_screen.dart',
      requiredRole: 'teacher',
      hasList: true,
      supportsScrollBenchmarking: true,
    ),
    ScreenPerformanceMetadata(
      id: 'teacher_post_session_report',
      role: ScreenRole.teacher,
      screenName: 'PostSessionReportScreen',
      route: '/teacher/post-session-report',
      filePath: 'lib/teacher/screens/post_session_report_screen.dart',
      requiredRole: 'teacher',
      hasList: true,
      supportsScrollBenchmarking: true,
    ),

    // -------------------------------------------------------------------------
    // D. Admin Role
    // -------------------------------------------------------------------------
    ScreenPerformanceMetadata(
      id: 'admin_shell',
      role: ScreenRole.admin,
      screenName: 'AdminShellScreen',
      route: '/admin/dashboard',
      filePath: 'lib/admin/screens/admin_shell_screen.dart',
      requiredRole: 'admin',
      hasAnimations: true,
    ),
    ScreenPerformanceMetadata(
      id: 'admin_home',
      role: ScreenRole.admin,
      screenName: 'AdminHomeContent',
      route: 'tab_0_home',
      filePath: 'lib/admin/widgets/admin_home_content.dart',
      requiredRole: 'admin',
      hasList: true,
      hasCharts: true,
      supportsScrollBenchmarking: true,
    ),
    ScreenPerformanceMetadata(
      id: 'admin_operations',
      role: ScreenRole.admin,
      screenName: 'AdminOperationsScreen',
      route: 'tab_1_operations',
      filePath: 'lib/admin/screens/admin_operations_screen.dart',
      requiredRole: 'admin',
      supportsScrollBenchmarking: true,
    ),
    ScreenPerformanceMetadata(
      id: 'admin_analytics',
      role: ScreenRole.admin,
      screenName: 'AdminAnalyticsScreen',
      route: 'tab_2_analytics',
      filePath: 'lib/admin/screens/admin_analytics_screen.dart',
      requiredRole: 'admin',
      hasCharts: true,
      supportsScrollBenchmarking: true,
    ),
    ScreenPerformanceMetadata(
      id: 'admin_profile',
      role: ScreenRole.admin,
      screenName: 'AdminProfileScreen',
      route: 'tab_3_profile',
      filePath: 'lib/admin/screens/admin_profile_screen.dart',
      requiredRole: 'admin',
      supportsScrollBenchmarking: true,
    ),
    ScreenPerformanceMetadata(
      id: 'admin_complaints',
      role: ScreenRole.admin,
      screenName: 'AdminComplaintsScreen',
      route: '/admin/complaints',
      filePath: 'lib/admin/screens/admin_complaints_screen.dart',
      requiredRole: 'admin',
      hasList: true,
      supportsScrollBenchmarking: true,
    ),
    ScreenPerformanceMetadata(
      id: 'admin_dashboard',
      role: ScreenRole.admin,
      screenName: 'AdminDashboardScreen',
      route: 'legacy_dashboard',
      filePath: 'lib/admin/screens/admin_dashboard_screen.dart',
      requiredRole: 'admin',
    ),

    // -------------------------------------------------------------------------
    // E. Warden Role
    // -------------------------------------------------------------------------
    ScreenPerformanceMetadata(
      id: 'warden_shell',
      role: ScreenRole.warden,
      screenName: 'WardenShellScreen',
      route: '/warden/shell',
      filePath: 'lib/warden/screens/warden_shell_screen.dart',
      requiredRole: 'warden',
      hasAnimations: true,
    ),
    ScreenPerformanceMetadata(
      id: 'warden_home',
      role: ScreenRole.warden,
      screenName: 'WardenHomeScreen',
      route: 'tab_0_home',
      filePath: 'lib/warden/screens/warden_home_screen.dart',
      requiredRole: 'warden',
      hasList: true,
      supportsScrollBenchmarking: true,
    ),
    ScreenPerformanceMetadata(
      id: 'warden_requests',
      role: ScreenRole.warden,
      screenName: 'WardenLeaveRequestsScreen',
      route: '/warden/requests',
      filePath: 'lib/warden/screens/warden_leave_requests_screen.dart',
      requiredRole: 'warden',
      hasList: true,
      supportsScrollBenchmarking: true,
    ),
    ScreenPerformanceMetadata(
      id: 'warden_activity',
      role: ScreenRole.warden,
      screenName: 'WardenActivityScreen',
      route: '/warden/activity',
      filePath: 'lib/warden/screens/warden_activity_screen.dart',
      requiredRole: 'warden',
      hasList: true,
      supportsScrollBenchmarking: true,
    ),
    ScreenPerformanceMetadata(
      id: 'warden_profile',
      role: ScreenRole.warden,
      screenName: 'WardenProfileScreen',
      route: '/warden/profile',
      filePath: 'lib/warden/screens/warden_profile_screen.dart',
      requiredRole: 'warden',
      supportsScrollBenchmarking: true,
    ),
    ScreenPerformanceMetadata(
      id: 'warden_detail',
      role: ScreenRole.warden,
      screenName: 'WardenLeaveDetailScreen',
      route: '/warden/detail',
      filePath: 'lib/warden/screens/warden_leave_detail_screen.dart',
      requiredRole: 'warden',
      supportsScrollBenchmarking: true,
    ),
    ScreenPerformanceMetadata(
      id: 'warden_inbox',
      role: ScreenRole.warden,
      screenName: 'WardenLeaveInboxScreen',
      route: '/warden/leave-inbox',
      filePath: 'lib/warden/screens/warden_leave_inbox_screen.dart',
      requiredRole: 'warden',
      hasList: true,
      supportsScrollBenchmarking: true,
    ),

    // -------------------------------------------------------------------------
    // F. Mess Staff Role
    // -------------------------------------------------------------------------
    ScreenPerformanceMetadata(
      id: 'mess_shell',
      role: ScreenRole.messStaff,
      screenName: 'MessShellScreen',
      route: '/mess/shell',
      filePath: 'lib/mess/screens/mess_shell_screen.dart',
      requiredRole: 'mess_staff',
      hasAnimations: true,
    ),
    ScreenPerformanceMetadata(
      id: 'mess_today',
      role: ScreenRole.messStaff,
      screenName: 'MessTodayScreen',
      route: 'tab_0_today',
      filePath: 'lib/mess/screens/mess_today_screen.dart',
      requiredRole: 'mess_staff',
      hasList: true,
      supportsScrollBenchmarking: true,
    ),
    ScreenPerformanceMetadata(
      id: 'mess_management',
      role: ScreenRole.messStaff,
      screenName: 'MessManagementScreen',
      route: '/shared/mess/management',
      filePath: 'lib/shared/screens/mess/mess_management_screen.dart',
      requiredRole: 'mess_staff',
      hasList: true,
      supportsScrollBenchmarking: true,
    ),
    ScreenPerformanceMetadata(
      id: 'mess_analytics',
      role: ScreenRole.messStaff,
      screenName: 'MessAnalyticsScreen',
      route: 'tab_2_analytics',
      filePath: 'lib/mess/screens/mess_analytics_screen.dart',
      requiredRole: 'mess_staff',
      hasCharts: true,
      supportsScrollBenchmarking: true,
    ),
    ScreenPerformanceMetadata(
      id: 'mess_profile',
      role: ScreenRole.messStaff,
      screenName: 'MessProfileScreen',
      route: 'tab_3_profile',
      filePath: 'lib/mess/screens/mess_profile_screen.dart',
      requiredRole: 'mess_staff',
      supportsScrollBenchmarking: true,
    ),
    ScreenPerformanceMetadata(
      id: 'mess_batch_verification',
      role: ScreenRole.messStaff,
      screenName: 'MessBatchVerificationScreen',
      route: '/mess/batch',
      filePath: 'lib/mess/screens/mess_batch_verification_screen.dart',
      requiredRole: 'mess_staff',
      requiresBle: true,
      validationMode: ValidationMode.manualHardwareValidation,
      hardwareNotes: 'Requires physical student BLE broadcast chirps',
    ),
    ScreenPerformanceMetadata(
      id: 'mess_qr_scanner',
      role: ScreenRole.messStaff,
      screenName: 'MessQrScannerScreen',
      route: '/mess/qr-scanner',
      filePath: 'lib/mess/screens/mess_qr_scanner_screen.dart',
      requiredRole: 'mess_staff',
      requiresCamera: true,
      validationMode: ValidationMode.manualHardwareValidation,
      hardwareNotes: 'Requires physical camera feed and student QR codes',
    ),
    ScreenPerformanceMetadata(
      id: 'mess_composer',
      role: ScreenRole.messStaff,
      screenName: 'MessComposerScreen',
      route: '/shared/mess/composer',
      filePath: 'lib/shared/screens/mess/mess_composer_screen.dart',
      requiredRole: 'mess_staff',
      supportsScrollBenchmarking: true,
    ),
    ScreenPerformanceMetadata(
      id: 'mess_detail',
      role: ScreenRole.messStaff,
      screenName: 'MessManagementDetailScreen',
      route: '/shared/mess/detail',
      filePath: 'lib/shared/screens/mess/mess_management_detail_screen.dart',
      requiredRole: 'mess_staff',
      hasList: true,
      supportsScrollBenchmarking: true,
    ),
    ScreenPerformanceMetadata(
      id: 'mess_feedback',
      role: ScreenRole.messStaff,
      screenName: 'MessFeedbackAnalyticsScreen',
      route: '/shared/mess/feedback',
      filePath: 'lib/shared/screens/mess/mess_feedback_analytics_screen.dart',
      requiredRole: 'mess_staff',
      hasCharts: true,
      hasList: true,
      supportsScrollBenchmarking: true,
    ),

    // -------------------------------------------------------------------------
    // G. Gate Security Role
    // -------------------------------------------------------------------------
    ScreenPerformanceMetadata(
      id: 'security_shell',
      role: ScreenRole.security,
      screenName: 'SecurityShellScreen',
      route: '/security/shell',
      filePath: 'lib/security/screens/security_shell_screen.dart',
      requiredRole: 'security',
      hasAnimations: true,
    ),
    ScreenPerformanceMetadata(
      id: 'security_home',
      role: ScreenRole.security,
      screenName: 'SecurityHomeScreen',
      route: 'tab_0_home',
      filePath: 'lib/security/screens/security_home_screen.dart',
      requiredRole: 'security',
      hasList: true,
      supportsScrollBenchmarking: true,
    ),
    ScreenPerformanceMetadata(
      id: 'security_passes',
      role: ScreenRole.security,
      screenName: 'SecurityPassesScreen',
      route: '/security/passes',
      filePath: 'lib/security/screens/security_passes_screen.dart',
      requiredRole: 'security',
      hasList: true,
      supportsScrollBenchmarking: true,
    ),
    ScreenPerformanceMetadata(
      id: 'security_activity',
      role: ScreenRole.security,
      screenName: 'SecurityActivityScreen',
      route: '/security/activity',
      filePath: 'lib/security/screens/security_activity_screen.dart',
      requiredRole: 'security',
      hasList: true,
      supportsScrollBenchmarking: true,
    ),
    ScreenPerformanceMetadata(
      id: 'security_profile',
      role: ScreenRole.security,
      screenName: 'SecurityProfileScreen',
      route: '/security/profile',
      filePath: 'lib/security/screens/security_profile_screen.dart',
      requiredRole: 'security',
      supportsScrollBenchmarking: true,
    ),
    ScreenPerformanceMetadata(
      id: 'security_verify',
      role: ScreenRole.security,
      screenName: 'SecurityVerifyScreen',
      route: '/security/verify',
      filePath: 'lib/security/screens/security_verify_screen.dart',
      requiredRole: 'security',
      requiresCamera: true,
      requiresBle: true,
      hasAnimations: true,
      validationMode: ValidationMode.manualHardwareValidation,
      hardwareNotes: 'Requires dual-mode hardware: BLE scan radar and camera barcode scanner',
    ),

    // -------------------------------------------------------------------------
    // H. Shared Terminals & Notices
    // -------------------------------------------------------------------------
    ScreenPerformanceMetadata(
      id: 'shared_passport_verifier',
      role: ScreenRole.shared,
      screenName: 'PassportVerifierScreen',
      route: '/passport/verify',
      filePath: 'lib/student/screens/passport_verifier_screen.dart',
      requiresCamera: true,
      validationMode: ValidationMode.manualHardwareValidation,
      hardwareNotes: 'Requires physical camera feed and QR tokens',
    ),
    ScreenPerformanceMetadata(
      id: 'shared_notice_management',
      role: ScreenRole.shared,
      screenName: 'NoticeManagementScreen',
      route: '/shared/notices/management',
      filePath: 'lib/shared/screens/notices/notice_management_screen.dart',
      hasList: true,
      supportsScrollBenchmarking: true,
    ),
    ScreenPerformanceMetadata(
      id: 'shared_notice_composer',
      role: ScreenRole.shared,
      screenName: 'NoticeComposerScreen',
      route: '/shared/notices/composer',
      filePath: 'lib/shared/screens/notices/notice_composer_screen.dart',
      supportsScrollBenchmarking: true,
    ),
    ScreenPerformanceMetadata(
      id: 'shared_notice_detail',
      role: ScreenRole.shared,
      screenName: 'NoticeManagementDetailScreen',
      route: '/shared/notices/detail',
      filePath: 'lib/shared/screens/notices/notice_management_detail_screen.dart',
      hasList: true,
      supportsScrollBenchmarking: true,
    ),

    // -------------------------------------------------------------------------
    // I. Modals, Bottom Sheets & Forms
    // -------------------------------------------------------------------------
    ScreenPerformanceMetadata(
      id: 'modal_leave_request_form',
      role: ScreenRole.modal,
      screenName: 'LeaveRequestForm',
      route: 'modal_leave_form',
      filePath: 'lib/student/widgets/requests/leave_request_form.dart',
      requiredRole: 'student',
      hasAnimations: true,
    ),
    ScreenPerformanceMetadata(
      id: 'modal_gate_pass_form',
      role: ScreenRole.modal,
      screenName: 'GatePassForm',
      route: 'modal_gate_pass_form',
      filePath: 'lib/student/widgets/requests/gate_pass_form.dart',
      requiredRole: 'student',
      hasAnimations: true,
    ),
    ScreenPerformanceMetadata(
      id: 'modal_complaint_form',
      role: ScreenRole.modal,
      screenName: 'ComplaintForm',
      route: 'modal_complaint_form',
      filePath: 'lib/student/widgets/requests/complaint_form.dart',
      requiredRole: 'student',
      hasAnimations: true,
    ),
    ScreenPerformanceMetadata(
      id: 'modal_complaint_detail_sheet',
      role: ScreenRole.modal,
      screenName: 'ComplaintDetailSheet',
      route: 'sheet_complaint_detail',
      filePath: 'lib/student/widgets/requests/complaint_detail_sheet.dart',
      requiredRole: 'student',
      hasList: true,
      hasAnimations: true,
    ),
    ScreenPerformanceMetadata(
      id: 'modal_notice_detail_sheet',
      role: ScreenRole.modal,
      screenName: 'NoticeDetailSheet',
      route: 'sheet_notice_detail',
      filePath: 'lib/student/widgets/requests/notice_detail_sheet.dart',
      requiredRole: 'student',
      hasAnimations: true,
    ),
    ScreenPerformanceMetadata(
      id: 'modal_meal_detail_sheet',
      role: ScreenRole.modal,
      screenName: 'MealDetailSheet',
      route: 'sheet_meal_detail',
      filePath: 'lib/student/widgets/mess/meal_detail_sheet.dart',
      requiredRole: 'student',
      hasList: true,
      hasAnimations: true,
    ),
    ScreenPerformanceMetadata(
      id: 'modal_meal_feedback_sheet',
      role: ScreenRole.modal,
      screenName: 'MealFeedbackSheet',
      route: 'sheet_meal_feedback',
      filePath: 'lib/student/widgets/mess/meal_feedback_sheet.dart',
      requiredRole: 'student',
      hasAnimations: true,
    ),
    ScreenPerformanceMetadata(
      id: 'modal_admin_complaint_detail_sheet',
      role: ScreenRole.modal,
      screenName: 'AdminComplaintDetailSheet',
      route: 'sheet_admin_complaint_detail',
      filePath: 'lib/admin/widgets/admin_complaint_detail_sheet.dart',
      requiredRole: 'admin',
      hasList: true,
      hasAnimations: true,
    ),
    ScreenPerformanceMetadata(
      id: 'modal_recurring_issue_detail_sheet',
      role: ScreenRole.modal,
      screenName: 'RecurringIssueDetailSheet',
      route: 'sheet_recurring_issue_detail',
      filePath: 'lib/admin/widgets/recurring_issue_detail_sheet.dart',
      requiredRole: 'admin',
      hasAnimations: true,
    ),
  ];

  static List<ScreenPerformanceMetadata> getByRole(ScreenRole role) =>
      entries.where((e) => e.role == role).toList();

  static List<ScreenPerformanceMetadata> getAutomatedScreens() =>
      entries.where((e) => e.validationMode == ValidationMode.automatedSoftware).toList();

  static List<ScreenPerformanceMetadata> getHardwareBoundScreens() =>
      entries.where((e) => e.validationMode == ValidationMode.manualHardwareValidation).toList();

  static List<ScreenPerformanceMetadata> getScrollableScreens() =>
      entries.where((e) => e.supportsScrollBenchmarking).toList();

  static ScreenPerformanceMetadata? findById(String id) {
    try {
      return entries.firstWhere((e) => e.id == id);
    } catch (_) {
      return null;
    }
  }
}
