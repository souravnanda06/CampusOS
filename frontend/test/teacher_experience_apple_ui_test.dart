import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:attendance_app/auth/models/user_model.dart';
import 'package:attendance_app/auth/providers/user_provider.dart';
import 'package:attendance_app/core/theme/app_colors.dart';
import 'package:attendance_app/shared/models/attendance_model.dart';
import 'package:attendance_app/shared/models/session_model.dart';
import 'package:attendance_app/student/models/passport_attendance_model.dart';
import 'package:attendance_app/student/models/passport_proximity_observation.dart';
import 'package:attendance_app/teacher/screens/teacher_shell_screen.dart';
import 'package:attendance_app/teacher/widgets/teacher_home_content.dart';
import 'package:attendance_app/teacher/screens/teacher_classes_screen.dart';
import 'package:attendance_app/teacher/screens/class_detail_screen.dart';
import 'package:attendance_app/teacher/screens/teacher_profile_screen.dart';
import 'package:attendance_app/teacher/screens/post_session_report_screen.dart';
import 'package:attendance_app/teacher/services/passport_teacher_attendance_service.dart';
import 'package:attendance_app/router/app_router.dart';

void main() {
  final testTeacher = UserModel(
    id: 't_prof_sourav',
    email: 'sourav.faculty@campusos.edu',
    name: 'Prof. Sourav Nanda',
    role: 'teacher',
    course: 'B.Tech',
    branch: 'CSE',
    year: '3rd',
    registrationNumber: 'FAC-2024-042',
    deviceId: 'DEV-HW-101',
  );

  final testSession = SessionModel(
    id: 'sess_test_101',
    name: 'Data Structures',
    instructorName: 'Prof. Sourav Nanda',
    course: 'B.Tech',
    branch: 'CSE',
    year: '3rd',
    startTime: DateTime.now().subtract(const Duration(minutes: 45)),
    endTime: DateTime.now().add(const Duration(minutes: 15)),
    location: 'Room 204',
    isActive: true,
    txPowerLevel: 2,
  );

  Widget createTestWrapper(Widget child) {
    return ChangeNotifierProvider<UserProvider>(
      create: (_) {
        final provider = UserProvider();
        provider.setUser(testTeacher);
        return provider;
      },
      child: MaterialApp(
        theme: ThemeData(
          scaffoldBackgroundColor: AppColors.bg,
          colorScheme: ColorScheme.fromSeed(seedColor: AppColors.primary),
        ),
        home: child,
      ),
    );
  }

  group('CampusOS Teacher: Apple-grade UI & Navigation Dock', () {
    testWidgets('1. TeacherShellScreen displays exactly 4-item bottom dock (Home, Classes, Analytics, Profile)', (tester) async {
      await tester.pumpWidget(
        createTestWrapper(
          TeacherShellScreen(
            user: testTeacher,
            activeSessions: const [],
            onRefreshSessions: () {},
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Verify bottom dock labels
      expect(find.text('Home'), findsOneWidget);
      expect(find.text('Classes'), findsWidgets);
      expect(find.text('Analytics'), findsWidgets);
      expect(find.text('Profile'), findsOneWidget);

      // Verify Home content is initially rendered
      expect(find.textContaining('Prof. Sourav Nanda'), findsOneWidget);
      expect(find.text('QUICK START'), findsOneWidget);

      // Tap Classes tab in bottom dock
      await tester.tap(find.text('Classes').last);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Active teaching assignments'), findsOneWidget);

      // Tap Analytics tab in bottom dock
      await tester.tap(find.text('Analytics').last);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Cohort attendance & student risk tracking'), findsOneWidget);

      // Tap Profile tab in bottom dock
      await tester.tap(find.text('Profile'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Faculty identity & classroom settings'), findsOneWidget);
    });

    testWidgets('2. TeacherHomeContent displays real teacher name, Quick Start hero, and Tx Power controls', (tester) async {
      await tester.pumpWidget(
        createTestWrapper(
          TeacherHomeContent(
            user: testTeacher,
            activeSessions: [testSession],
            onRefreshSessions: () {},
            onNavigateToTab: (_) {},
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Verify header and teacher name
      expect(find.textContaining('Prof. Sourav Nanda'), findsOneWidget);
      expect(find.text('Faculty'), findsOneWidget);

      // Verify live session resume banner
      expect(find.textContaining('Session Live:'), findsOneWidget);
      expect(find.text('Resume'), findsOneWidget);

      // Verify Quick Start Hero
      expect(find.text('QUICK START'), findsOneWidget);
      expect(find.text('Start Attendance'), findsWidgets);

      // Verify Tx Power segmented selector
      expect(find.text('Low'), findsOneWidget);
      expect(find.text('Medium'), findsOneWidget);
      expect(find.text('High'), findsOneWidget);

      // Verify Today's Classes section
      expect(find.text("Assigned Classes"), findsOneWidget);
    });

    testWidgets('3. TeacherClassesScreen displays assigned curriculum and filter pills', (tester) async {
      await tester.pumpWidget(
        createTestWrapper(
          TeacherClassesScreen(user: testTeacher),
        ),
      );
      await tester.pumpAndSettle();

      // Verify header
      expect(find.text('Classes'), findsOneWidget);
      expect(find.text('Active teaching assignments'), findsOneWidget);

      // Verify filter pills
      expect(find.text('All'), findsOneWidget);
      expect(find.text('Today'), findsOneWidget);
      expect(find.text('Upcoming'), findsOneWidget);

      // Verify search field exists
      expect(find.byType(TextField), findsOneWidget);

      // Verify subject cards rendered
      expect(find.text('Start Attendance'), findsWidgets);
    });

    testWidgets('4. ClassDetailScreen renders class metadata and start button', (tester) async {
      await tester.pumpWidget(
        createTestWrapper(
          ClassDetailScreen(
            subjectName: 'Data Structures',
            course: 'B.Tech',
            branch: 'CSE',
            year: '3rd',
            room: 'Room 204',
            user: testTeacher,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Data Structures'), findsOneWidget);
      expect(find.textContaining('Room 204'), findsWidgets);
      expect(find.text('Prof. Sourav Nanda'), findsOneWidget);
      expect(find.text('Start Attendance Session'), findsOneWidget);
    });

    testWidgets('5. TeacherProfileScreen renders faculty identity, 1I security status, and logout modal', (tester) async {
      await tester.pumpWidget(
        createTestWrapper(
          TeacherProfileScreen(user: testTeacher),
        ),
      );
      await tester.pumpAndSettle();

      // Verify identity header
      expect(find.text('Prof. Sourav Nanda'), findsOneWidget);
      expect(find.text('sourav.faculty@campusos.edu'), findsOneWidget);
      expect(find.text('CSE Department'), findsOneWidget);

      // Verify academic assignment
      expect(find.text('Academic Credentials'), findsOneWidget);
      expect(find.text('FAC-2024-042'), findsOneWidget);

      // Verify 1I Attendance & Security Protocol
      expect(find.text('Security Protocol'), findsOneWidget);
      expect(find.text('Hardware-gated BLE Active'), findsOneWidget);
      expect(find.text('Ed25519 & Trust Bundle Verified'), findsOneWidget);

      // Ensure Log Out button is scrolled into view before tapping
      await tester.ensureVisible(find.text('Log Out'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Log Out'));
      await tester.pumpAndSettle();

      expect(find.text('Log Out of CampusOS?'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);
    });

    testWidgets('6. PostSessionReportScreen displays verified breakdown, audit roster, and export button', (tester) async {
      final verifiedRecords = [
        PassportAttendanceVerificationResult(
          valid: true,
          status: PassportAttendanceStatus.verifiedPresent,
          reason: 'Verified',
          studentId: 'stud_1',
          studentName: 'Ananya Das',
          proximityTier: PassportProximityTier.near,
          medianRssi: -52,
          verificationMode: 'BLE_BATCH',
          verifiedAt: DateTime.now().subtract(const Duration(minutes: 10)),
        ),
        PassportAttendanceVerificationResult(
          valid: true,
          status: PassportAttendanceStatus.verifiedPresent,
          reason: 'QR Verified',
          studentId: 'stud_2',
          studentName: 'Deepak Roy',
          proximityTier: PassportProximityTier.near,
          medianRssi: -65,
          verificationMode: 'QR_FALLBACK',
          verifiedAt: DateTime.now().subtract(const Duration(minutes: 5)),
        ),
      ];

      await tester.pumpWidget(
        createTestWrapper(
          PostSessionReportScreen(
            session: testSession,
            metrics: const TeacherAttendanceMetrics(
              verifiedCount: 2,
              inconclusiveCount: 1,
              missingCount: 0,
              totalRoster: 3,
            ),
            verifiedRecords: verifiedRecords,
            legacyAttendees: [
              AttendanceModel(
                id: 'att_3',
                userId: 'stud_3',
                studentName: 'Rohan Sharma',
                sessionId: testSession.id,
                sessionName: testSession.name,
                checkInTime: DateTime.now().subtract(const Duration(minutes: 8)),
                location: 'Room 204',
                status: 'present',
              ),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify Session Header
      expect(find.text('Attendance Report'), findsOneWidget);
      expect(find.text('Data Structures'), findsOneWidget);
      expect(find.text('CONCLUDED'), findsOneWidget);

      // Verify Summary Counts
      expect(find.text('PRESENT'), findsOneWidget);
      expect(find.text('INCONCLUSIVE'), findsOneWidget);

      // Verify Verification Breakdown
      expect(find.text('Verification Method Breakdown'), findsOneWidget);
      expect(find.text('Batch BLE'), findsOneWidget);
      expect(find.text('QR Fallback'), findsOneWidget);

      // Verify Audit Roster students
      expect(find.text('Ananya Das'), findsOneWidget);
      expect(find.text('Deepak Roy'), findsOneWidget);

      // Verify Excel Export button exists
      expect(find.text('Export Excel'), findsOneWidget);
    });

    testWidgets('7. TeacherClassesScreen navigation to ClassDetailScreen passes and displays subject name', (tester) async {
      await tester.pumpWidget(
        ChangeNotifierProvider<UserProvider>(
          create: (_) {
            final provider = UserProvider();
            provider.setUser(testTeacher);
            return provider;
          },
          child: MaterialApp(
            theme: ThemeData(
              scaffoldBackgroundColor: AppColors.bg,
              colorScheme: ColorScheme.fromSeed(seedColor: AppColors.primary),
            ),
            onGenerateRoute: AppRouter.generateRoute,
            home: TeacherClassesScreen(user: testTeacher),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Find the first class card ('Algorithms')
      expect(find.text('Algorithms'), findsWidgets);

      // Tap the card to trigger navigation to AppRoutes.teacherClassDetail
      await tester.tap(find.text('Algorithms').first);
      await tester.pumpAndSettle();

      // Verify we are on Class Details and subject name 'Algorithms' is displayed, not default 'Subject'
      expect(find.text('Class Details'), findsOneWidget);
      expect(find.text('Algorithms'), findsWidgets);
      expect(find.text('Subject'), findsNothing);
    });
  });
}
