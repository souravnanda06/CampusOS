import 'package:flutter/material.dart';

import 'app_routes.dart';
import '../core/performance/performance.dart';
import '../screens/splash_screen.dart';
import '../screens/home_screen.dart';
import '../screens/history_screen.dart';
import '../auth/screens/onboarding_screen.dart';
import '../auth/screens/login_screen.dart';
import '../auth/screens/student_registration_screen.dart';
import '../auth/models/user_model.dart';
import '../shared/models/session_model.dart';
import '../student/screens/ready_screen.dart';
import '../student/screens/success_screen.dart';
import '../student/screens/timetable_screen.dart';
import '../student/screens/student_analytics_screen.dart';
import '../student/screens/profile_screen.dart';
import '../student/screens/mess_screen.dart';
import '../student/screens/campus_scanner_screen.dart';
import '../student/screens/settings_screen.dart';
import '../student/screens/student_emergency_screen.dart';
import '../student/screens/face_enrollment_screen.dart';
import '../student/screens/career_hub_screen.dart';
import '../teacher/screens/create_session_screen.dart';
import '../teacher/screens/broadcasting_screen.dart';
import '../teacher/screens/teacher_classes_screen.dart';
import '../teacher/screens/teacher_analytics_screen.dart';
import '../teacher/screens/teacher_profile_screen.dart';
import '../teacher/screens/session_attendance_screen.dart';
import '../teacher/screens/class_detail_screen.dart';
import '../teacher/screens/post_session_report_screen.dart';
import '../teacher/services/passport_teacher_attendance_service.dart';
import '../student/models/passport_attendance_model.dart';
import '../shared/models/attendance_model.dart';
import '../admin/screens/admin_shell_screen.dart';
import '../admin/screens/admin_complaints_screen.dart';
import '../shared/screens/notices/notice_management_screen.dart';
import '../shared/screens/notices/notice_composer_screen.dart';
import '../shared/screens/notices/notice_management_detail_screen.dart';
import '../shared/screens/mess/mess_management_screen.dart';
import '../shared/screens/mess/mess_composer_screen.dart';
import '../shared/screens/mess/mess_management_detail_screen.dart';
import '../shared/screens/mess/mess_feedback_analytics_screen.dart';
import '../student/models/mess_model.dart';
import '../student/screens/passport_verifier_screen.dart';
import '../mess/screens/mess_shell_screen.dart';
import '../mess/screens/mess_batch_verification_screen.dart';
import '../mess/screens/mess_qr_scanner_screen.dart';
import '../security/screens/security_shell_screen.dart';
import '../security/screens/security_verify_screen.dart';
import '../security/screens/security_passes_screen.dart';
import '../security/screens/security_activity_screen.dart';
import '../security/screens/security_profile_screen.dart';
import '../warden/screens/warden_leave_inbox_screen.dart';
import '../warden/screens/warden_shell_screen.dart';
import '../warden/screens/warden_leave_requests_screen.dart';
import '../warden/screens/warden_activity_screen.dart';
import '../warden/screens/warden_profile_screen.dart';
import '../warden/screens/warden_leave_detail_screen.dart';
import '../warden/models/warden_models.dart';
import '../core/mesh/campus_mesh_manager.dart';
import '../shared/screens/campus_mesh_hub_screen.dart';
import '../shared/screens/campus_mesh_chat_screen.dart';
import '../shared/screens/campus_mesh_emergency_screen.dart';
import '../shared/screens/campus_mesh_airdrop_screen.dart';
import '../shared/screens/campus_mesh_node_radar_screen.dart';
import '../shared/screens/campus_mesh_physical_validation_screen.dart';
import '../shared/screens/campus_mesh_stage_simulator_screen.dart';
import '../shared/screens/campus_mesh_emergency_dispatcher_screen.dart';

class AppRouter {
  AppRouter._();

  static Route<dynamic> generateRoute(RouteSettings settings) {
    switch (settings.name) {
      case AppRoutes.splash:
        return _fadeRoute(const SplashScreen(), settings);

      case AppRoutes.onboarding:
        return _fadeRoute(const OnboardingScreen(), settings);

      case AppRoutes.login:
        return _fadeRoute(const LoginScreen(), settings);

      case AppRoutes.register:
        return _fadeRoute(const StudentRegistrationScreen(), settings);

      case AppRoutes.home:
        return _fadeRoute(const HomeScreen(), settings);

      case AppRoutes.history:
        return MaterialPageRoute(
          builder: (_) => const HistoryScreen(),
          settings: settings,
        );

      // Student Routes
      case AppRoutes.studentReady:
        return MaterialPageRoute(
          builder: (_) => const ReadyScreen(),
          settings: settings,
        );

      case AppRoutes.studentSuccess:
        final args = settings.arguments as Map<String, dynamic>? ?? {};
        return MaterialPageRoute(
          builder: (_) => SuccessScreen(
            userName: args['userName'] as String? ?? '',
            sessionName: args['sessionName'] as String? ?? '',
            couponEarned: args['couponEarned'] as bool? ?? false,
          ),
          settings: settings,
        );

      case AppRoutes.studentTimetable:
        return MaterialPageRoute(
          builder: (_) => const TimetableScreen(),
          settings: settings,
        );

      case AppRoutes.studentAnalytics:
        return MaterialPageRoute(
          builder: (_) => const StudentAnalyticsScreen(),
          settings: settings,
        );

      case AppRoutes.studentProfile:
        final user = settings.arguments as UserModel?;
        return MaterialPageRoute(
          builder: (_) => ProfileScreen(user: user),
          settings: settings,
        );

      case AppRoutes.studentMess:
        return MaterialPageRoute(
          builder: (_) => const MessScreen(),
          settings: settings,
        );

      case AppRoutes.studentScanner:
        final user = settings.arguments as UserModel?;
        return MaterialPageRoute(
          builder: (_) => CampusScannerScreen(user: user),
          settings: settings,
        );

      case AppRoutes.studentSettings:
        final args = settings.arguments;
        UserModel? user;
        Function(int)? onNavigateToTab;
        if (args is Map<String, dynamic>) {
          user = args['user'] as UserModel?;
          onNavigateToTab = args['onNavigateToTab'] as Function(int)?;
        } else if (args is UserModel) {
          user = args;
        }
        return MaterialPageRoute(
          builder: (_) => SettingsScreen(user: user, onNavigateToTab: onNavigateToTab),
          settings: settings,
        );

      case AppRoutes.studentEmergency:
        final user = settings.arguments as UserModel?;
        return MaterialPageRoute(
          builder: (_) => StudentEmergencyScreen(user: user),
          settings: settings,
        );

      case AppRoutes.careerHub:
        final tabIdx = settings.arguments is int ? settings.arguments as int : 0;
        return MaterialPageRoute(
          builder: (_) => CareerHubScreen(initialTabIndex: tabIdx),
          settings: settings,
        );

      case AppRoutes.faceEnrollment:
        final studentId = settings.arguments as String?;
        return MaterialPageRoute(
          builder: (_) => FaceEnrollmentScreen(studentId: studentId),
          settings: settings,
        );

      // Teacher Routes
      case AppRoutes.teacherCreateSession:
        return MaterialPageRoute(
          builder: (_) => const CreateSessionScreen(),
          settings: settings,
        );

      case AppRoutes.teacherBroadcasting:
        final args = settings.arguments as Map<String, dynamic>? ?? {};
        return MaterialPageRoute(
          builder: (_) => BroadcastingScreen(
            user: args['user'] as UserModel,
            session: args['session'] as SessionModel,
          ),
          settings: settings,
        );

      case AppRoutes.teacherClasses:
        return MaterialPageRoute(
          builder: (_) => const TeacherClassesScreen(),
          settings: settings,
        );

      case AppRoutes.teacherAnalytics:
        return MaterialPageRoute(
          builder: (_) => const TeacherAnalyticsScreen(),
          settings: settings,
        );

      case AppRoutes.teacherProfile:
        final user = settings.arguments as UserModel?;
        return MaterialPageRoute(
          builder: (_) => TeacherProfileScreen(user: user),
          settings: settings,
        );

      case AppRoutes.teacherSessionAttendance:
        final session = settings.arguments as SessionModel;
        return MaterialPageRoute(
          builder: (_) => SessionAttendanceScreen(session: session),
          settings: settings,
        );

      case AppRoutes.teacherClassDetail:
        final args = settings.arguments as Map<String, dynamic>? ?? {};
        final resolvedSubject = (args['subjectName'] ?? args['subject'] ?? args['name'] ?? 'Subject') as String;
        return MaterialPageRoute(
          builder: (_) => ClassDetailScreen(
            subjectName: resolvedSubject,
            course: args['course'] as String? ?? 'B.Tech',
            branch: args['branch'] as String? ?? 'CSE',
            year: args['year'] as String? ?? '3rd',
            room: args['room'] as String? ?? 'Room 204',
            user: args['user'] as UserModel?,
          ),
          settings: settings,
        );

      case AppRoutes.teacherPostSessionReport:
        final args = settings.arguments as Map<String, dynamic>? ?? {};
        return MaterialPageRoute(
          builder: (_) => PostSessionReportScreen(
            session: args['session'] as SessionModel,
            metrics: args['metrics'] as TeacherAttendanceMetrics? ??
                const TeacherAttendanceMetrics(),
            verifiedRecords: args['verifiedRecords']
                    as List<PassportAttendanceVerificationResult>? ??
                const [],
            legacyAttendees:
                args['legacyAttendees'] as List<AttendanceModel>? ?? const [],
          ),
          settings: settings,
        );

      case AppRoutes.adminDashboard:
        final adminUser = settings.arguments is UserModel
            ? settings.arguments as UserModel
            : (settings.arguments is Map
                ? (settings.arguments as Map)['user'] as UserModel?
                : null);
        return MaterialPageRoute(
          builder: (_) => AdminShellScreen(user: adminUser),
          settings: settings,
        );

      case AppRoutes.adminComplaints:
        final complaintsUser = settings.arguments is UserModel
            ? settings.arguments as UserModel
            : (settings.arguments is Map
                ? (settings.arguments as Map)['user'] as UserModel?
                : null);
        return MaterialPageRoute(
          builder: (_) => AdminComplaintsScreen(user: complaintsUser),
          settings: settings,
        );

      case AppRoutes.noticeManagement:
        final user = settings.arguments is UserModel
            ? settings.arguments as UserModel
            : (settings.arguments is Map
                ? (settings.arguments as Map)['user'] as UserModel?
                : null);
        if (user == null) {
          return MaterialPageRoute(
            builder: (_) => const Scaffold(
              body: Center(child: Text('User session required')),
            ),
          );
        }
        return MaterialPageRoute(
          builder: (_) => NoticeManagementScreen(user: user),
          settings: settings,
        );

      case AppRoutes.noticeComposer:
        final args = settings.arguments as Map<String, dynamic>? ?? {};
        final user = args['user'] as UserModel;
        final notice = args['notice']; // as NoticeModel?
        return MaterialPageRoute(
          builder: (_) => NoticeComposerScreen(user: user, notice: notice),
          settings: settings,
        );

      case AppRoutes.noticeDetail:
        final args = settings.arguments as Map<String, dynamic>? ?? {};
        final user = args['user'] as UserModel;
        final notice = args['notice']; // as NoticeModel
        return MaterialPageRoute(
          builder: (_) =>
              NoticeManagementDetailScreen(user: user, notice: notice),
          settings: settings,
        );

      case AppRoutes.messManagement:
        final messUser = settings.arguments is UserModel
            ? settings.arguments as UserModel
            : (settings.arguments is Map
                ? (settings.arguments as Map)['user'] as UserModel?
                : null);
        if (messUser == null) {
          return MaterialPageRoute(
            builder: (_) => const Scaffold(
              body: Center(child: Text('User session required')),
            ),
          );
        }
        return MaterialPageRoute(
          builder: (_) => MessManagementScreen(user: messUser),
          settings: settings,
        );

      case AppRoutes.messComposer:
        final args = settings.arguments as Map<String, dynamic>? ?? {};
        final user = args['user'] as UserModel;
        final menu = args['menu'] as MessMenu?;
        return MaterialPageRoute(
          builder: (_) => MessComposerScreen(user: user, menu: menu),
          settings: settings,
        );

      case AppRoutes.messDetail:
        final args = settings.arguments as Map<String, dynamic>? ?? {};
        final user = args['user'] as UserModel;
        final menu = args['menu'] as MessMenu;
        return MaterialPageRoute(
          builder: (_) => MessManagementDetailScreen(user: user, menu: menu),
          settings: settings,
        );

      case AppRoutes.messFeedback:
        final user = settings.arguments as UserModel?;
        return MaterialPageRoute(
          builder: (_) => MessFeedbackAnalyticsScreen(user: user),
          settings: settings,
        );

      case AppRoutes.passportVerify:
        final user = settings.arguments as UserModel?;
        return MaterialPageRoute(
          builder: (_) => PassportVerifierScreen(user: user),
          settings: settings,
        );

      case AppRoutes.messShell:
        final user = settings.arguments as UserModel?;
        return MaterialPageRoute(
          builder: (_) => MessShellScreen(user: user),
          settings: settings,
        );

      case AppRoutes.messBatch:
        final args = settings.arguments as Map<String, dynamic>? ?? {};
        return MaterialPageRoute(
          builder: (_) => MessBatchVerificationScreen(
            user: args['user'] as UserModel?,
            mealType: args['mealType'] as String? ?? 'LUNCH',
            date: args['date'] as String? ?? '',
          ),
          settings: settings,
        );

      case AppRoutes.messQrScanner:
        final args = settings.arguments as Map<String, dynamic>? ?? {};
        return MaterialPageRoute(
          builder: (_) => MessQrScannerScreen(
            user: args['user'] as UserModel?,
            mealType: args['mealType'] as String? ?? 'LUNCH',
            date: args['date'] as String? ?? '',
          ),
          settings: settings,
        );

      // Security Gate Routes
      case AppRoutes.securityShell:
        final user = settings.arguments as UserModel?;
        return MaterialPageRoute(
          builder: (_) => SecurityShellScreen(user: user),
          settings: settings,
        );

      case AppRoutes.securityVerify:
        final args = settings.arguments as Map<String, dynamic>? ?? {};
        return MaterialPageRoute(
          builder: (_) => SecurityVerifyScreen(
            user: args['user'] as UserModel? ??
                UserModel(id: 'security_guard', email: 'security@campusos.edu', name: 'Gate Officer', role: 'security'),
            gateName: args['gateName'] as String? ?? 'Main Gate',
            startWithQr: args['startWithQr'] as bool? ?? false,
          ),
          settings: settings,
        );

      case AppRoutes.securityPasses:
        final user = settings.arguments as UserModel? ??
            UserModel(id: 'security_guard', email: 'security@campusos.edu', name: 'Gate Officer', role: 'security');
        return MaterialPageRoute(
          builder: (_) => SecurityPassesScreen(user: user),
          settings: settings,
        );

      case AppRoutes.securityActivity:
        final user = settings.arguments as UserModel? ??
            UserModel(id: 'security_guard', email: 'security@campusos.edu', name: 'Gate Officer', role: 'security');
        return MaterialPageRoute(
          builder: (_) => SecurityActivityScreen(user: user),
          settings: settings,
        );

      case AppRoutes.securityProfile:
        final user = settings.arguments as UserModel? ??
            UserModel(id: 'security_guard', email: 'security@campusos.edu', name: 'Gate Officer', role: 'security');
        return MaterialPageRoute(
          builder: (_) => SecurityProfileScreen(user: user),
          settings: settings,
        );

      // Warden Routes
      case AppRoutes.wardenShell:
        final user = settings.arguments as UserModel?;
        return MaterialPageRoute(
          builder: (_) => WardenShellScreen(user: user),
          settings: settings,
        );

      case AppRoutes.wardenRequests:
        final user = settings.arguments as UserModel?;
        return MaterialPageRoute(
          builder: (_) => WardenLeaveRequestsScreen(
            user: user ??
                UserModel(
                  id: 'warden_officer',
                  email: 'warden@campusos.edu',
                  name: 'Chief Warden',
                  role: 'warden',
                ),
          ),
          settings: settings,
        );

      case AppRoutes.wardenActivity:
        final user = settings.arguments as UserModel?;
        return MaterialPageRoute(
          builder: (_) => WardenActivityScreen(
            user: user ??
                UserModel(
                  id: 'warden_officer',
                  email: 'warden@campusos.edu',
                  name: 'Chief Warden',
                  role: 'warden',
                ),
          ),
          settings: settings,
        );

      case AppRoutes.wardenProfile:
        final user = settings.arguments as UserModel?;
        return MaterialPageRoute(
          builder: (_) => WardenProfileScreen(
            user: user ??
                UserModel(
                  id: 'warden_officer',
                  email: 'warden@campusos.edu',
                  name: 'Chief Warden',
                  role: 'warden',
                ),
          ),
          settings: settings,
        );

      case AppRoutes.wardenDetail:
        final req = settings.arguments as WardenLeaveRequestModel;
        return MaterialPageRoute(
          builder: (_) => WardenLeaveDetailScreen(initialRequest: req),
          settings: settings,
        );

      case AppRoutes.wardenLeaveInbox:
        final user = settings.arguments as UserModel?;
        return MaterialPageRoute(
          builder: (_) => WardenLeaveInboxScreen(user: user),
          settings: settings,
        );

      // CampusOS Mesh routes (Phases M1–M7)
      case AppRoutes.meshHub:
        return MaterialPageRoute(
          builder: (_) => const CampusMeshHubScreen(),
          settings: settings,
        );

      case AppRoutes.meshChat:
        return MaterialPageRoute(
          builder: (_) => CampusMeshChatScreen(
            chatService: CampusMeshManager.instance.chatService,
          ),
          settings: settings,
        );

      case AppRoutes.meshEmergency:
        return MaterialPageRoute(
          builder: (_) => CampusMeshEmergencyScreen(
            emergencyService: CampusMeshManager.instance.emergencyService,
          ),
          settings: settings,
        );

      case AppRoutes.meshAirDrop:
        return MaterialPageRoute(
          builder: (_) => CampusMeshAirDropScreen(
            airdropService: CampusMeshManager.instance.airdropService,
          ),
          settings: settings,
        );

      case AppRoutes.meshRadar:
        return MaterialPageRoute(
          builder: (_) => CampusMeshNodeRadarScreen(
            radarService: CampusMeshManager.instance.radarService,
          ),
          settings: settings,
        );

      case AppRoutes.meshPhysicalTest:
        return MaterialPageRoute(
          builder: (_) => CampusMeshPhysicalValidationScreen(
            harnessService: CampusMeshManager.instance.physicalHarness,
          ),
          settings: settings,
        );

      case AppRoutes.meshSimulator:
        return MaterialPageRoute(
          builder: (_) => CampusMeshStageSimulatorScreen(
            controller: CampusMeshManager.instance.stageSimulatorController,
          ),
          settings: settings,
        );

      case AppRoutes.meshDispatcher:
        return MaterialPageRoute(
          builder: (_) => CampusMeshEmergencyDispatcherScreen(
            dispatcherService: CampusMeshManager.instance.dispatcherService,
          ),
          settings: settings,
        );

      default:
        return MaterialPageRoute(
          builder: (_) => const SplashScreen(),
          settings: settings,
        );
    }
  }

  static PageRouteBuilder<dynamic> _fadeRoute(
      Widget page, RouteSettings settings) {
    final reducedMotion =
        PerformanceEngine.instance.profile.animationProfile.reducedMotion;

    return PageRouteBuilder<dynamic>(
      settings: settings,
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        if (reducedMotion ||
            (MediaQuery.maybeOf(context)?.disableAnimations ?? false)) {
          return child;
        }
        return FadeTransition(
          opacity: CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutCubic,
          ),
          child: child,
        );
      },
      transitionDuration:
          reducedMotion ? Duration.zero : const Duration(milliseconds: 200),
      reverseTransitionDuration:
          reducedMotion ? Duration.zero : const Duration(milliseconds: 180),
    );
  }
}
