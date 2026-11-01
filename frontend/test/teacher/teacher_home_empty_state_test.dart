import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:attendance_app/auth/models/user_model.dart';
import 'package:attendance_app/auth/providers/user_provider.dart';
import 'package:attendance_app/core/theme/app_colors.dart';
import 'package:attendance_app/teacher/widgets/teacher_home_content.dart';

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

  group('TeacherHomeContent Empty State & Classes Tests', () {
    testWidgets('Renders dedicated empty state when no classes are assigned today',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        createTestWrapper(
          TeacherHomeContent(
            user: testTeacher,
            activeSessions: const [],
            onRefreshSessions: () {},
            onNavigateToTab: (_) {},
            initialPresets: const [], // Empty presets
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      // Verify the dedicated empty state is displayed
      expect(find.byKey(const Key('teacher_empty_classes_container')), findsOneWidget);
      expect(find.text('No classes assigned today'), findsOneWidget);
      expect(
        find.text('You have no scheduled class sessions for today.'),
        findsOneWidget,
      );

      // Verify no hardcoded mock fallback classes are rendered in assigned classes!
      expect(find.text('Database Management Systems'), findsNothing);
      expect(find.text('Computer Networks'), findsNothing);
    });

    testWidgets('Renders populated class sessions when assigned',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final assignedClasses = [
        {
          'subject': 'Operating Systems',
          'course': 'B.Tech',
          'branch': 'CSE',
          'year': '3rd',
          'time': '10:00 AM',
          'room': 'Lab 1',
        },
        {
          'subject': 'Software Engineering',
          'course': 'B.Tech',
          'branch': 'CSE',
          'year': '3rd',
          'time': '01:00 PM',
          'room': 'Room 105',
        },
      ];

      await tester.pumpWidget(
        createTestWrapper(
          TeacherHomeContent(
            user: testTeacher,
            activeSessions: const [],
            onRefreshSessions: () {},
            onNavigateToTab: (_) {},
            initialPresets: assignedClasses,
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      // Quick Start smart-default matches first preset, and card list displays it too
      expect(find.text('Operating Systems'), findsWidgets);
      expect(find.text('Software Engineering'), findsOneWidget);
      expect(find.byKey(const Key('teacher_empty_classes_container')), findsNothing);
    });

    testWidgets('Displays loading indicator while loading presets',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        createTestWrapper(
          TeacherHomeContent(
            user: testTeacher,
            activeSessions: const [],
            onRefreshSessions: () {},
            onNavigateToTab: (_) {},
            initialPresets: const [],
            isLoadingPresets: true,
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.byKey(const Key('teacher_classes_loading')), findsOneWidget);
    });

    testWidgets('Displays error state when preset loading fails',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        createTestWrapper(
          TeacherHomeContent(
            user: testTeacher,
            activeSessions: const [],
            onRefreshSessions: () {},
            onNavigateToTab: (_) {},
            initialPresets: const [],
            presetsErrorMessage: 'Failed to sync academic schedule',
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.byKey(const Key('teacher_classes_error')), findsOneWidget);
      expect(find.text('Failed to sync academic schedule'), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);
    });
  });
}
