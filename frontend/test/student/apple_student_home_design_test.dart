import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:attendance_app/auth/models/user_model.dart';
import 'package:attendance_app/auth/providers/user_provider.dart';
import 'package:attendance_app/student/widgets/student_home_content.dart';
import 'package:attendance_app/student/widgets/attendance/attendance_card.dart';
import 'package:attendance_app/shared/widgets/motion/apple_bounceable.dart';
import 'package:attendance_app/shared/widgets/dock/apple_glass_dock.dart';

void main() {
  final testUser = UserModel(
    id: 'std_test_apple_01',
    name: 'Sourav Nanda',
    email: 'sourav@campusos.edu',
    role: 'STUDENT',
    branch: 'CSE',
    course: 'B.Tech',
    year: '3rd',
  );

  Widget createWidget({
    required void Function(int, {int? requestTab, int? requestSubTab}) onNavigate,
    double overallAttendance = 0.0,
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
            overallAttendance: overallAttendance,
            recentAttendance: const [],
            attendanceAnalytics: const {
              'attendedClasses': 0,
              'totalClasses': 10,
              'streak': 0,
            },
            loading: false,
            onNavigateToTab: onNavigate,
          ),
        ),
      ),
    );
  }

  group('Apple Motion & Student Dashboard Design Verification', () {
    testWidgets('Renders all Apple design elements from specification', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      int navigatedIndex = -1;

      await tester.pumpWidget(
        createWidget(
          onNavigate: (index, {requestTab, requestSubTab}) {
            navigatedIndex = index;
          },
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));

      // 1. Header greeting and Sourav name
      expect(find.text('Sourav'), findsOneWidget);

      // 2. Attendance Card with 0%, Low badge, and status strip
      expect(find.byType(AttendanceCard), findsOneWidget);
      expect(find.text('Attendance'), findsOneWidget);
      expect(find.text('Low'), findsOneWidget);
      expect(find.text('0'), findsWidgets);
      expect(find.text('All lectures and labs are on schedule today.'), findsOneWidget);

      // 3. Bento Grid: Streak and Next class
      expect(find.text('Streak'), findsOneWidget);
      expect(find.text('days'), findsWidgets);
      expect(find.text('Next Class'), findsOneWidget);

      // 4. Campus Passport CTA
      expect(find.text('Campus Passport'), findsOneWidget);
      expect(find.text('View your digital credential'), findsOneWidget);

      // 5. Quick Actions 8 items
      expect(find.text('Quick Actions'), findsOneWidget);
      expect(find.text('Leave'), findsOneWidget);
      expect(find.text('Gate Pass'), findsOneWidget);
      expect(find.text('Complaint'), findsOneWidget);
      expect(find.text('Notices'), findsOneWidget);
      expect(find.text('Timetable'), findsOneWidget);
      expect(find.text('Mess'), findsOneWidget);
      expect(find.text('Mesh Chat'), findsOneWidget);
      expect(find.text('AirDrop'), findsOneWidget);

      // 6. Recent Activity section
      expect(find.text('Recent Activity'), findsOneWidget);
      expect(find.text('No activity yet'), findsOneWidget);
      expect(find.text('Start your first class to see updates here.'), findsOneWidget);

      // 7. Verify RefreshIndicator presence
      expect(find.byType(RefreshIndicator), findsOneWidget);

      // 8. Verify AppleBounceable spring interactions
      expect(find.byType(AppleBounceable), findsWidgets);

      // Tap Campus Passport CTA triggers navigation to Passport (tab 1)
      await tester.tap(find.text('Campus Passport'));
      await tester.pump();
      expect(navigatedIndex, equals(1));
    });

    testWidgets('AppleGlassDock renders floating pill with fluid sliding indicator and icon pop', (tester) async {
      int selectedTab = 0;
      final dockItems = [
        const AppleDockItem(
          icon: Icons.home_outlined,
          activeIcon: Icons.home_rounded,
          label: 'Home',
        ),
        const AppleDockItem(
          icon: Icons.account_balance_wallet_outlined,
          activeIcon: Icons.account_balance_wallet_rounded,
          label: 'Wallet',
        ),
        const AppleDockItem(
          icon: Icons.inbox_outlined,
          activeIcon: Icons.inbox_rounded,
          label: 'Requests',
          hasDot: true,
        ),
        const AppleDockItem(
          icon: Icons.person_outline_rounded,
          activeIcon: Icons.person_rounded,
          label: 'Profile',
        ),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: StatefulBuilder(
            builder: (context, setState) {
              return Scaffold(
                bottomNavigationBar: AppleGlassDock(
                  items: dockItems,
                  currentIndex: selectedTab,
                  onTap: (idx) {
                    setState(() => selectedTab = idx);
                  },
                ),
              );
            },
          ),
        ),
      );

      // Verify all 4 destinations from user screenshot
      expect(find.text('Home'), findsOneWidget);
      expect(find.text('Wallet'), findsOneWidget);
      expect(find.text('Requests'), findsOneWidget);
      expect(find.text('Profile'), findsOneWidget);

      // Home starts with active icon
      expect(find.byIcon(Icons.home_rounded), findsOneWidget);

      // Tap Wallet -> triggers fluid sliding and icon pop
      await tester.tap(find.text('Wallet'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 150));

      expect(selectedTab, equals(1));
      expect(find.byIcon(Icons.account_balance_wallet_rounded), findsOneWidget);

      await tester.pumpAndSettle();
    });
  });
}
