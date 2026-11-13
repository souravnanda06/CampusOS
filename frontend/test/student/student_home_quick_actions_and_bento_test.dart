import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:attendance_app/auth/models/user_model.dart';
import 'package:attendance_app/auth/providers/user_provider.dart';
import 'package:attendance_app/student/widgets/student_home_content.dart';
import 'package:attendance_app/student/screens/timetable_screen.dart';
import 'package:attendance_app/student/widgets/timetable/apple_next_class_expanded_view.dart';

void main() {
  final testUser = UserModel(
    id: 'std_test_01',
    name: 'Aarav Sharma',
    email: 'aarav@campusos.edu',
    role: 'STUDENT',
    branch: 'CSE',
    course: 'B.Tech',
    year: '3rd',
  );

  Widget createWidget({
    required void Function(int, {int? requestTab, int? requestSubTab}) onNavigate,
    Map<String, dynamic>? analytics,
  }) {
    return ChangeNotifierProvider<UserProvider>(
      create: (_) {
        final up = UserProvider();
        up.setUser(testUser);
        return up;
      },
      child: MaterialApp(
        home: Scaffold(
          body: StudentHomeContent(
            user: testUser,
            overallAttendance: 85.0,
            recentAttendance: const [],
            attendanceAnalytics: analytics ?? {
              'attendedClasses': 18,
              'totalClasses': 20,
              'streak': 6,
            },
            loading: false,
            onNavigateToTab: onNavigate,
          ),
        ),
      ),
    );
  }

  group('Student Home Quick Actions & Bento Grid Tests', () {
    testWidgets('Quick Actions does NOT contain Passport shortcut and contains Complaint, Notices, Timetable', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      int navigatedIndex = -1;
      int? navigatedRequestTab;
      int? navigatedSubTab;

      await tester.pumpWidget(
        createWidget(
          onNavigate: (index, {requestTab, requestSubTab}) {
            navigatedIndex = index;
            navigatedRequestTab = requestTab;
            navigatedSubTab = requestSubTab;
          },
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // 1. Verify Passport shortcut is removed from Quick Actions
      // (The only Passport widget is the large CTA banner, not in Quick Actions)
      final quickActionPassport = find.widgetWithText(GestureDetector, 'Passport');
      expect(quickActionPassport, findsNothing);

      // 2. Verify all 6 Quick Action items exist
      expect(find.text('Leave'), findsOneWidget);
      expect(find.text('Gate Pass'), findsOneWidget);
      expect(find.text('Complaint'), findsOneWidget);
      expect(find.text('Notices'), findsOneWidget);
      expect(find.text('Timetable'), findsOneWidget);
      expect(find.text('Mess'), findsOneWidget);

      // 3. Tapping Complaint routes to Request tab 2 with requestTab 4 (Complaints)
      await tester.tap(find.text('Complaint'));
      await tester.pump();
      expect(navigatedIndex, equals(2));
      expect(navigatedRequestTab, equals(4));

      // 4. Tapping Notices routes to Request tab 2 with requestTab 5 (Notices)
      await tester.tap(find.text('Notices'));
      await tester.pump();
      expect(navigatedIndex, equals(2));
      expect(navigatedRequestTab, equals(5));

      // 5. Tapping Leave routes to Request tab 2 with requestTab 0, subTab 0
      await tester.tap(find.text('Leave'));
      await tester.pump();
      expect(navigatedIndex, equals(2));
      expect(navigatedRequestTab, equals(0));
      expect(navigatedSubTab, equals(0));
    });

    testWidgets('Bento Grid displays calculated Streak and Next Class card navigates to Timetable', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        createWidget(
          analytics: {
            'attendedClasses': 18,
            'totalClasses': 20,
            'streak': 6,
          },
          onNavigate: (_, {requestTab, requestSubTab}) {},
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 800));

      // 1. Streak is displayed with 6 Days
      expect(find.text('Streak'), findsOneWidget);
      expect(find.text('6 Days'), findsOneWidget);
      expect(find.text('🔥 In a row'), findsOneWidget);

      // 2. Next Class card is displayed
      expect(find.text('Next Class'), findsOneWidget);
      expect(find.text('TIMETABLE'), findsOneWidget);

      // 3. Tapping Next Class triggers continuous expansion into AppleNextClassExpandedView
      await tester.tap(find.text('Next Class'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.byType(AppleNextClassExpandedView), findsOneWidget);

      // 4. Tapping "Open Weekly Timetable" navigates to TimetableScreen
      await tester.tap(find.text('Open Weekly Timetable'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.byType(TimetableScreen), findsOneWidget);

      Navigator.of(tester.element(find.byType(TimetableScreen))).pop();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
    });
  });
}
