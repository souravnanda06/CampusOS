import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:attendance_app/auth/models/user_model.dart';
import 'package:attendance_app/admin/screens/admin_shell_screen.dart';
import 'package:attendance_app/admin/screens/admin_dashboard_screen.dart';
import 'package:attendance_app/admin/widgets/admin_home_content.dart';
import 'package:attendance_app/admin/screens/admin_operations_screen.dart';
import 'package:attendance_app/admin/screens/admin_analytics_screen.dart';
import 'package:attendance_app/admin/screens/admin_profile_screen.dart';
import 'package:attendance_app/admin/screens/admin_complaints_screen.dart';

void main() {
  final testAdminUser = UserModel(
    id: 'admin_test_1',
    email: 'admin@campusos.internal',
    name: 'Dr. Robert Vance',
    role: 'admin',
    branch: 'Campus Administration',
  );

  Widget createTestWidget(Widget child) {
    return MaterialApp(
      theme: ThemeData(
        fontFamily: 'Plus Jakarta Sans',
      ),
      home: child,
    );
  }

  group('CampusOS Admin: Apple-grade UI & Product Structure', () {
    testWidgets('1. AdminShellScreen displays exactly 4-item bottom dock (Home, Operations, Analytics, Profile)', (tester) async {
      await tester.binding.setSurfaceSize(const Size(400, 850));

      await tester.pumpWidget(
        createTestWidget(
          AdminShellScreen(user: testAdminUser),
        ),
      );
      await tester.pump();

      // Verify Exactly 4 primary dock destinations
      expect(find.text('Home'), findsOneWidget);
      expect(find.text('Operations'), findsOneWidget);
      expect(find.text('Analytics'), findsOneWidget);
      expect(find.text('Profile'), findsOneWidget);

      // Verify Home is active first
      expect(find.byType(AdminHomeContent), findsOneWidget);

      // Tap Operations tab (index 1)
      await tester.tap(find.text('Operations'));
      await tester.pumpAndSettle();
      expect(find.byType(AdminOperationsScreen), findsOneWidget);

      // Tap Analytics tab (index 2)
      await tester.tap(find.text('Analytics'));
      await tester.pumpAndSettle();
      expect(find.byType(AdminAnalyticsScreen), findsOneWidget);

      // Tap Profile tab (index 3)
      await tester.tap(find.text('Profile'));
      await tester.pumpAndSettle();
      expect(find.byType(AdminProfileScreen), findsOneWidget);
    });

    testWidgets('2. AdminHomeContent displays real admin name, campus status, and Command Center metrics', (tester) async {
      await tester.binding.setSurfaceSize(const Size(400, 850));

      await tester.pumpWidget(
        createTestWidget(
          AdminHomeContent(
            user: testAdminUser,
            onNavigateToTab: (_) {},
          ),
        ),
      );
      await tester.pump();

      // Top calm greeting and campus status
      expect(find.textContaining('Dr. Robert'), findsOneWidget);
      expect(find.text('CAMPUS ONLINE'), findsOneWidget);

      // Command Center metric cards
      expect(find.text('CAMPUS OPERATIONS'), findsOneWidget);
      expect(find.text('Needs Attention'), findsOneWidget);
      expect(find.text('Ageing >48h'), findsOneWidget);
      expect(find.text('Recurring Issues'), findsOneWidget);
      expect(find.text('High Priority'), findsOneWidget);

      // Quick Actions
      expect(find.text('QUICK ACTIONS'), findsOneWidget);
      expect(find.text('Complaints'), findsOneWidget);
      expect(find.text('Notices'), findsOneWidget);
      expect(find.text('Mess'), findsOneWidget);
      expect(find.text('Attendance'), findsOneWidget);
      expect(find.text('Passport'), findsOneWidget);

      // Recent Activity
      expect(find.text('RECENT ACTIVITY'), findsOneWidget);
    });

    testWidgets('3. AdminOperationsScreen displays all 6 operational oversight cards', (tester) async {
      await tester.binding.setSurfaceSize(const Size(400, 850));

      await tester.pumpWidget(
        createTestWidget(
          AdminOperationsScreen(user: testAdminUser),
        ),
      );
      await tester.pumpAndSettle();

      // Header
      expect(find.text('Operations'), findsOneWidget);
      expect(find.text('Campus services management & active oversight'), findsOneWidget);

      // Cards
      expect(find.text('Complaints'), findsOneWidget);
      expect(find.text('Notices'), findsOneWidget);
      expect(find.text('Mess Operations'), findsOneWidget);
      expect(find.text('Attendance Oversight'), findsOneWidget);
      expect(find.text('Gate & Security Oversight'), findsOneWidget);
      expect(find.text('Passport Verification'), findsOneWidget);

      // Primary Action buttons
      expect(find.text('Open Queue'), findsOneWidget);
      expect(find.text('Manage Notices'), findsOneWidget);
      expect(find.text('Manage Menus'), findsOneWidget);
      expect(find.text('View Active Sessions'), findsOneWidget);
      expect(find.text('Open Verifier'), findsOneWidget);
    });

    testWidgets('4. AdminComplaintsScreen displays search bar, status chips, priority chips, and ageing toggle', (tester) async {
      await tester.binding.setSurfaceSize(const Size(400, 850));

      await tester.pumpWidget(
        createTestWidget(
          AdminComplaintsScreen(user: testAdminUser),
        ),
      );
      await tester.pumpAndSettle();

      // Title
      expect(find.text('Complaint Queue'), findsOneWidget);

      // Search hint
      expect(find.text('Search complaints by title, room, ID...'), findsOneWidget);

      // Ageing toggle chip
      expect(find.text('Ageing >48h'), findsOneWidget);

      // Status Choice Chips
      expect(find.text('All Status'), findsOneWidget);
      expect(find.text('PENDING'), findsOneWidget);
      expect(find.text('IN PROGRESS'), findsOneWidget);
      expect(find.text('RESOLVED'), findsOneWidget);

      // Priority Chips
      expect(find.text('All Priority'), findsOneWidget);
      expect(find.text('URGENT'), findsOneWidget);
      expect(find.text('HIGH'), findsOneWidget);
    });

    testWidgets('5. AdminAnalyticsScreen displays resolution performance, ageing brackets, and workload', (tester) async {
      await tester.binding.setSurfaceSize(const Size(400, 850));

      await tester.pumpWidget(
        createTestWidget(
          AdminAnalyticsScreen(user: testAdminUser),
        ),
      );
      await tester.pumpAndSettle();

      // Title & subtitle
      expect(find.text('Analytics'), findsOneWidget);
      expect(find.text('Institutional resolution rates, ageing & recurring patterns'), findsOneWidget);

      // Core sections
      expect(find.text('RESOLUTION PERFORMANCE'), findsOneWidget);
      expect(find.text('average resolution time'), findsOneWidget);

      expect(find.text('COMPLAINT AGEING ANALYSIS'), findsOneWidget);
      expect(find.text('< 24h'), findsOneWidget);
      expect(find.text('1–3 days'), findsOneWidget);
      expect(find.text('3–7 days'), findsOneWidget);
      expect(find.text('7+ days'), findsOneWidget);

      expect(find.text('RECURRING ISSUES (DETERMINISTIC)'), findsOneWidget);
      expect(find.text('STAFF WORKLOAD'), findsOneWidget);
      expect(find.text('CATEGORY DISTRIBUTION'), findsOneWidget);
    });

    testWidgets('6. AdminProfileScreen displays admin credentials, security status, and opens logout dialog', (tester) async {
      await tester.binding.setSurfaceSize(const Size(400, 850));

      await tester.pumpWidget(
        createTestWidget(
          AdminProfileScreen(user: testAdminUser),
        ),
      );
      await tester.pumpAndSettle();

      // Admin Identity Hero
      expect(find.text('Dr. Robert Vance'), findsOneWidget);
      expect(find.text('admin@campusos.internal'), findsOneWidget);
      expect(find.text('FULL CAMPUS ADMIN'), findsOneWidget);

      // Department & Privileges
      expect(find.text('Campus Administration'), findsOneWidget);
      expect(find.text('Super Administrator'), findsOneWidget);

      // Engine Status
      expect(find.text('Passport 1I Engine'), findsOneWidget);
      expect(find.text('Online & Enforcing'), findsOneWidget);

      // Logout button & Modal
      final logoutFinder = find.text('Log Out of Admin Console');
      expect(logoutFinder, findsOneWidget);
      await tester.ensureVisible(logoutFinder);
      await tester.pumpAndSettle();
      await tester.tap(logoutFinder);
      await tester.pumpAndSettle();

      expect(find.text('Log Out of CampusOS?'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);
      expect(find.text('Log Out'), findsOneWidget);
    });

    testWidgets('7. AdminDashboardScreen delegates cleanly to AdminShellScreen', (tester) async {
      await tester.binding.setSurfaceSize(const Size(400, 850));

      await tester.pumpWidget(
        createTestWidget(
          AdminDashboardScreen(user: testAdminUser),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byType(AdminShellScreen), findsOneWidget);
    });
  });
}
