class AppRoutes {
  AppRoutes._();

  static const splash = '/';
  static const onboarding = '/onboarding';
  static const login = '/login';
  static const register = '/register';
  static const home = '/home';
  static const history = '/history';

  // Student routes
  static const studentReady = '/student/ready';
  static const studentSuccess = '/student/success';
  static const studentTimetable = '/student/timetable';
  static const studentAnalytics = '/student/analytics';
  static const studentProfile = '/student/profile';
  static const studentMess = '/student/mess';
  static const studentScanner = '/student/scanner';
  static const studentSettings = '/student/settings';
  static const studentEmergency = '/student/emergency';
  static const faceEnrollment = '/student/face-enroll';
  static const careerHub = '/student/career-hub';

  // Teacher routes
  static const teacherCreateSession = '/teacher/create-session';
  static const teacherBroadcasting = '/teacher/broadcasting';
  static const teacherClasses = '/teacher/classes';
  static const teacherClassDetail = '/teacher/class-detail';
  static const teacherAnalytics = '/teacher/analytics';
  static const teacherProfile = '/teacher/profile';
  static const teacherSessionAttendance = '/teacher/session-attendance';
  static const teacherPostSessionReport = '/teacher/post-session-report';

  // Admin routes
  static const adminDashboard = '/admin/dashboard';
  static const adminComplaints = '/admin/complaints';

  // Shared Management routes
  static const noticeManagement = '/shared/notices/management';
  static const noticeComposer = '/shared/notices/composer';
  static const noticeDetail = '/shared/notices/detail';

  // Shared Mess Management routes
  static const messManagement = '/shared/mess/management';
  static const messComposer = '/shared/mess/composer';
  static const messDetail = '/shared/mess/detail';
  static const messFeedback = '/shared/mess/feedback';

  // Passport Verifier terminal route
  static const passportVerify = '/passport/verify';

  // Mess Staff routes
  static const messShell = '/mess/shell';
  static const messBatch = '/mess/batch';
  static const messQrScanner = '/mess/qr-scanner';

  // Security Gate routes
  static const securityShell = '/security/shell';
  static const securityVerify = '/security/verify';
  static const securityPasses = '/security/passes';
  static const securityActivity = '/security/activity';
  static const securityProfile = '/security/profile';

  // Warden routes
  static const wardenLeaveInbox = '/warden/leave-inbox';
  static const wardenShell = '/warden/shell';
  static const wardenRequests = '/warden/requests';
  static const wardenActivity = '/warden/activity';
  static const wardenProfile = '/warden/profile';
  static const wardenDetail = '/warden/detail';

  // CampusOS Mesh routes (Phases M1–M7)
  static const meshHub = '/mesh/hub';
  static const meshChat = '/mesh/chat';
  static const meshEmergency = '/mesh/emergency';
  static const meshAirDrop = '/mesh/airdrop';
  static const meshRadar = '/mesh/radar';
  static const meshPhysicalTest = '/mesh/physical-test';
  static const meshSimulator = '/mesh/simulator';
  static const meshDispatcher = '/mesh/dispatcher';
}
