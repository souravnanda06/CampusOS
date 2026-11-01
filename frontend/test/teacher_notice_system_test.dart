import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:attendance_app/auth/models/user_model.dart';
import 'package:attendance_app/auth/providers/user_provider.dart';
import 'package:attendance_app/core/theme/app_colors.dart';
import 'package:attendance_app/student/models/notice_model.dart';
import 'package:attendance_app/teacher/widgets/teacher_home_content.dart';
import 'package:attendance_app/shared/screens/notices/notice_management_screen.dart';
import 'package:attendance_app/shared/screens/notices/notice_composer_screen.dart';
import 'package:attendance_app/shared/screens/notices/notice_management_detail_screen.dart';

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

  final testAdmin = UserModel(
    id: 'admin_1',
    email: 'admin@campusos.edu',
    name: 'Campus Director',
    role: 'admin',
  );

  final testNotice = NoticeModel(
    id: 'notif_101',
    title: 'Mid-Sem Examination Schedule',
    body: 'The mid-semester examination for CSE 3rd Year will commence from October 15th in Hall B.',
    createdBy: 't_prof_sourav',
    publishedBy: 'Prof. Sourav Nanda',
    priority: 'HIGH',
    category: 'ACADEMIC',
    targetType: 'BRANCH',
    targetValue: 'CSE',
    status: 'PUBLISHED',
    createdAt: DateTime.now().subtract(const Duration(hours: 2)),
    totalDeliveries: 142,
    readDeliveries: 105,
    recipientCount: 142,
  );

  final testDraftNotice = NoticeModel(
    id: 'notif_102',
    title: 'Lab Submission Deadline Extension',
    body: 'Data Structures lab assignments can be submitted until Friday 5 PM.',
    createdBy: 't_prof_sourav',
    publishedBy: 'Prof. Sourav Nanda',
    priority: 'NORMAL',
    category: 'ACADEMIC',
    targetType: 'YEAR',
    targetValue: '3rd',
    status: 'DRAFT',
    createdAt: DateTime.now().subtract(const Duration(hours: 5)),
    totalDeliveries: 0,
    readDeliveries: 0,
    recipientCount: 45,
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

  group('CampusOS Teacher Notice System — Apple-grade UI & Scoped Management', () {
    testWidgets('1. TeacherHomeContent displays notification bell and Quick Actions with Notices tile', (tester) async {
      await tester.pumpWidget(
        createTestWrapper(
          TeacherHomeContent(
            user: testTeacher,
            activeSessions: const [],
            onRefreshSessions: () {},
            onNavigateToTab: (_) {},
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Verify notification bell icon in header
      expect(find.byIcon(Icons.notifications_none_rounded), findsOneWidget);

      // Verify Quick Actions section exists
      expect(find.text('Quick Actions'), findsOneWidget);

      // Verify Notices quick action tile
      expect(find.text('Notices'), findsWidgets);
      expect(find.text('Student announcements'), findsOneWidget);
    });

    testWidgets('2. NoticeManagementScreen renders Apple-grade header, segmented pills, search bar, and empty state', (tester) async {
      await tester.pumpWidget(
        createTestWrapper(
          NoticeManagementScreen(user: testTeacher),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Verify Header
      expect(find.text('My Notices'), findsOneWidget);
      expect(find.text('Announcements & circulars for your students'), findsOneWidget);
      expect(find.text('New'), findsOneWidget);

      // Verify Search field
      expect(find.byType(TextField), findsOneWidget);

      // Verify Apple segmented pills
      expect(find.text('All'), findsOneWidget);
      expect(find.text('Published'), findsOneWidget);
      expect(find.text('Drafts'), findsOneWidget);
      expect(find.text('Archived'), findsOneWidget);
    });

    testWidgets('3. NoticeComposerScreen strictly enforces Teacher scope (no ALL option)', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        createTestWrapper(
          NoticeComposerScreen(user: testTeacher),
        ),
      );
      await tester.pumpAndSettle();

      // Verify Screen title
      expect(find.text('Create Notice'), findsOneWidget);
      expect(find.text('NOTICE DETAILS'), findsOneWidget);
      expect(find.text('CLASSIFICATION'), findsOneWidget);
      expect(find.text('TARGET AUDIENCE'), findsOneWidget);

      // Verify teacher CANNOT see 'All Students (Global)'
      expect(find.text('All Students (Global)'), findsNothing);

      // Verify teacher can see allowed scopes
      expect(find.text('Department / Branch'), findsOneWidget);
      expect(find.text('Academic Year'), findsOneWidget);
      expect(find.text('Specific Student'), findsOneWidget);

      // Verify preview button exists
      expect(find.text('Preview'), findsOneWidget);
    });

    testWidgets('4. NoticeComposerScreen allows Admin to access All Students (Global) scope', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        createTestWrapper(
          NoticeComposerScreen(user: testAdmin),
        ),
      );
      await tester.pumpAndSettle();

      // Admin CAN see global option
      expect(find.text('All Students (Global)'), findsOneWidget);
    });

    testWidgets('5. NoticeComposerScreen opens interactive Student View Preview sheet', (tester) async {
      await tester.pumpWidget(
        createTestWrapper(
          NoticeComposerScreen(user: testTeacher, notice: testNotice),
        ),
      );
      await tester.pumpAndSettle();

      // Tap Preview button in app bar
      await tester.tap(find.text('Preview'));
      await tester.pumpAndSettle();

      // Verify Preview modal opened
      expect(find.text('Notice Preview'), findsOneWidget);
      expect(find.text('Student View'), findsOneWidget);
      expect(find.text('Mid-Sem Examination Schedule'), findsWidgets);
      expect(find.textContaining('Prof. Sourav Nanda'), findsWidgets);
      expect(find.text('Back to Edit'), findsOneWidget);

      // Dismiss preview
      await tester.tap(find.text('Back to Edit'));
      await tester.pumpAndSettle();
      expect(find.text('Student View'), findsNothing);
    });

    testWidgets('6. NoticeManagementDetailScreen renders Apple delivery metrics grid and archive confirmation', (tester) async {
      await tester.pumpWidget(
        createTestWrapper(
          NoticeManagementDetailScreen(user: testTeacher, notice: testNotice),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Verify Notice Title & Message
      expect(find.text('Notice Details'), findsOneWidget);
      expect(find.text('Mid-Sem Examination Schedule'), findsOneWidget);
      expect(find.textContaining('Hall B'), findsOneWidget);

      // Verify Delivery Metrics header & tiles
      expect(find.text('DELIVERY & ENGAGEMENT'), findsOneWidget);
      expect(find.text('Recipients'), findsOneWidget);
      expect(find.text('Delivered'), findsOneWidget);
      expect(find.text('Read'), findsOneWidget);
      expect(find.text('Unread'), findsOneWidget);
      expect(find.text('Read Rate'), findsOneWidget);

      // Verify Archive button and confirmation modal
      expect(find.text('Archive Notice'), findsOneWidget);
      await tester.ensureVisible(find.text('Archive Notice'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Archive Notice'));
      await tester.pumpAndSettle();

      expect(find.text('Archive Notice?'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);
      expect(find.text('Archive'), findsOneWidget);
    });

    testWidgets('7. NoticeManagementDetailScreen renders Draft explanation and Publish Now button for drafts', (tester) async {
      await tester.pumpWidget(
        createTestWrapper(
          NoticeManagementDetailScreen(user: testTeacher, notice: testDraftNotice),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Verify draft status
      expect(find.text('DRAFT'), findsOneWidget);
      expect(find.textContaining('saved as a draft'), findsOneWidget);
      expect(find.text('Publish Now'), findsOneWidget);
    });
  });
}
