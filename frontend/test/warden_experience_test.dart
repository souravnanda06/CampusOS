import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:attendance_app/auth/models/user_model.dart';
import 'package:attendance_app/warden/models/warden_models.dart';
import 'package:attendance_app/warden/widgets/warden_dock_item.dart';
import 'package:attendance_app/warden/widgets/warden_summary_card.dart';
import 'package:attendance_app/warden/widgets/warden_request_card.dart';
import 'package:attendance_app/warden/screens/warden_shell_screen.dart';
import 'package:attendance_app/warden/screens/warden_leave_detail_screen.dart';

void main() {
  final testWarden = UserModel(
    id: 'warden-001',
    name: 'Dr. Suresh Jena',
    email: 'warden@campusos.edu',
    role: 'warden',
  );

  const testRequest = WardenLeaveRequestModel(
    id: 'leave-req-123',
    studentId: 'student-456',
    studentName: 'Amit Pattnaik',
    registrationNumber: '2101289045',
    course: 'B.Tech',
    branch: 'Computer Science',
    year: '3',
    leaveType: 'OUTING',
    startDate: '2026-09-28',
    endDate: '2026-09-29',
    reason: 'Attending regional robotics conference',
    destination: 'Bhubaneswar IT Park',
    status: 'PENDING',
    previousRequestsCount: 2,
    createdAt: '2026-09-27T10:00:00',
    updatedAt: '2026-09-27T10:00:00',
    studentPhone: '9876543210',
  );

  group('CampusOS Warden Models & State Tests', () {
    test('WardenSummaryModel parses JSON correctly', () {
      final jsonMap = {
        'pendingRequests': 4,
        'approvedToday': 12,
        'activeGatePasses': 7,
        'recentActivityCount': 25,
        'pendingPreview': [
          {
            'id': 'req-1',
            'studentId': 'st-1',
            'studentName': 'Priya Das',
            'registrationNumber': '2101289099',
            'course': 'B.Tech',
            'branch': 'ECE',
            'year': '2',
            'leaveType': 'HOME',
            'startDate': '2026-09-28',
            'endDate': '2026-09-30',
            'reason': 'Festival holiday',
            'destination': 'Cuttack',
            'status': 'PENDING',
            'previousRequestsCount': 1,
            'createdAt': '2026-09-27T12:00:00',
            'updatedAt': '2026-09-27T12:00:00',
          }
        ],
      };

      final summary = WardenSummaryModel.fromJson(jsonMap);
      expect(summary.pendingRequests, 4);
      expect(summary.pendingVisitors, 0);
      expect(summary.approvedToday, 12);
      expect(summary.activeGatePasses, 7);
      expect(summary.recentActivityCount, 25);
      expect(summary.pendingPreview.length, 1);
      expect(summary.pendingPreview.first.studentName, 'Priya Das');
    });

    test('WardenSummaryModel parses pendingVisitors correctly', () {
      final jsonMap = {
        'pendingRequests': 3,
        'pendingVisitors': 2,
        'approvedToday': 5,
        'activeGatePasses': 4,
        'recentActivityCount': 10,
        'pendingPreview': [],
      };
      final summary = WardenSummaryModel.fromJson(jsonMap);
      expect(summary.pendingVisitors, 2);
    });

    test('WardenSummaryModel empty provides zero defaults', () {
      final empty = WardenSummaryModel.empty();
      expect(empty.pendingRequests, 0);
      expect(empty.pendingVisitors, 0);
      expect(empty.approvedToday, 0);
      expect(empty.activeGatePasses, 0);
      expect(empty.recentActivityCount, 0);
      expect(empty.pendingPreview, isEmpty);
    });

    test('WardenLeaveRequestModel state properties behave correctly', () {
      expect(testRequest.isPending, isTrue);
      expect(testRequest.isApproved, isFalse);
      expect(testRequest.isRejected, isFalse);

      const approved = WardenLeaveRequestModel(
        id: '2',
        studentId: 'st-2',
        studentName: 'Rahul',
        registrationNumber: 'REG-2',
        course: 'B.Tech',
        branch: 'EE',
        year: '4',
        leaveType: 'OUTING',
        startDate: '2026-09-28',
        endDate: '2026-09-28',
        reason: 'Medical checkup',
        destination: 'AIIMS',
        status: 'APPROVED',
        previousRequestsCount: 0,
        createdAt: '2026-09-27T08:00:00',
        updatedAt: '2026-09-27T08:30:00',
      );
      expect(approved.isApproved, isTrue);
      expect(approved.isPending, isFalse);
    });

    test('WardenActivityModel parses timeline JSON correctly', () {
      final json = {
        'id': 'act-1',
        'entityType': 'LEAVE',
        'entityId': 'req-1',
        'actorId': 'warden-1',
        'actorName': 'Dr. Jena',
        'actorRole': 'WARDEN',
        'action': 'APPROVE',
        'remarks': 'Approved for conference',
        'timestamp': '2026-09-27T10:15:00',
        'studentName': 'Amit Pattnaik',
        'registrationNumber': '2101289045',
        'destination': 'Bhubaneswar IT Park',
      };

      final activity = WardenActivityModel.fromJson(json);
      expect(activity.id, 'act-1');
      expect(activity.action, 'APPROVE');
      expect(activity.actorName, 'Dr. Jena');
      expect(activity.studentName, 'Amit Pattnaik');
    });
  });

  group('CampusOS Warden UI & Widget Tests', () {
    testWidgets('WardenDockItem highlights active tab with label and icon', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            bottomNavigationBar: Row(
              children: [
                WardenDockItem(
                  index: 0,
                  currentIndex: 0,
                  label: 'Home',
                  icon: Icons.dashboard_outlined,
                  activeIcon: Icons.dashboard_rounded,
                  onTap: () {},
                ),
                WardenDockItem(
                  index: 1,
                  currentIndex: 0,
                  label: 'Requests',
                  icon: Icons.assignment_outlined,
                  activeIcon: Icons.assignment_rounded,
                  onTap: () {},
                ),
              ],
            ),
          ),
        ),
      );

      expect(find.text('Home'), findsOneWidget);
      expect(find.text('Requests'), findsOneWidget);
      expect(find.byIcon(Icons.dashboard_rounded), findsOneWidget);
      expect(find.byIcon(Icons.assignment_outlined), findsOneWidget);
    });

    testWidgets('WardenSummaryCard renders metrics and title correctly', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: WardenSummaryCard(
              title: 'Pending Reviews',
              value: '8',
              subtitle: 'Awaiting decision',
              icon: Icons.hourglass_top_rounded,
              color: Colors.orange,
              onTap: () {},
            ),
          ),
        ),
      );

      expect(find.text('8'), findsOneWidget);
      expect(find.text('Pending Reviews'), findsOneWidget);
      expect(find.text('Awaiting decision'), findsOneWidget);
      expect(find.byIcon(Icons.hourglass_top_rounded), findsOneWidget);
    });

    testWidgets('WardenRequestCard renders without ANY parent consent chip', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: WardenRequestCard(
              request: testRequest,
              onAction: (_) {},
            ),
          ),
        ),
      );

      // Student and request details
      expect(find.text('Amit Pattnaik'), findsOneWidget);
      expect(find.text('Bhubaneswar IT Park'), findsOneWidget);
      expect(find.text('PENDING'), findsOneWidget);
      expect(find.text('Approve'), findsOneWidget);
      expect(find.text('Reject'), findsOneWidget);

      // CRITICAL CONSTRAINT: ZERO parent/guardian consent anywhere
      expect(find.textContaining('Parent'), findsNothing);
      expect(find.textContaining('parent'), findsNothing);
      expect(find.textContaining('Guardian'), findsNothing);
      expect(find.textContaining('guardian'), findsNothing);
      expect(find.textContaining('Consent'), findsNothing);
      expect(find.textContaining('consent'), findsNothing);
    });

    testWidgets('WardenLeaveDetailScreen renders detailed review without parent consent', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: WardenLeaveDetailScreen(
            initialRequest: testRequest,
            user: testWarden,
          ),
        ),
      );

      expect(find.text('Leave Request Review'), findsOneWidget);
      expect(find.text('Student Academic Profile'), findsOneWidget);
      expect(find.text('Amit Pattnaik'), findsOneWidget);
      expect(find.text('2101289045'), findsOneWidget);
      expect(find.text('Computer Science'), findsOneWidget);
      expect(find.text('Bhubaneswar IT Park'), findsOneWidget);
      expect(find.text('Gate Pass Lifecycle Status'), findsOneWidget);

      // Verify action buttons
      expect(find.text('Approve Leave'), findsOneWidget);
      expect(find.text('Reject Request'), findsOneWidget);

      // CRITICAL CONSTRAINT: ZERO parent/guardian consent anywhere
      expect(find.textContaining('Parent'), findsNothing);
      expect(find.textContaining('parent'), findsNothing);
      expect(find.textContaining('Guardian'), findsNothing);
      expect(find.textContaining('guardian'), findsNothing);
      expect(find.textContaining('Consent'), findsNothing);
      expect(find.textContaining('consent'), findsNothing);
    });

    testWidgets('WardenShellScreen mounts 4 navigation destinations', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: WardenShellScreen(user: testWarden),
        ),
      );

      // 4 Navigation Dock destinations
      expect(find.text('Home'), findsOneWidget);
      expect(find.text('Requests'), findsOneWidget);
      expect(find.text('Activity'), findsOneWidget);
      expect(find.text('Profile'), findsOneWidget);

      // Initially on Home Screen
      expect(find.text('Dr. Suresh Jena'), findsOneWidget);
      expect(find.text('INSTITUTIONAL WARDEN'), findsOneWidget);
      expect(find.text('Operational Overview'), findsOneWidget);

      // Tap 'Requests' tab
      await tester.tap(find.text('Requests'));
      await tester.pumpAndSettle();
      expect(find.text('Leave Requests Management'), findsOneWidget);

      // Tap 'Activity' tab
      await tester.tap(find.text('Activity'));
      await tester.pumpAndSettle();
      expect(find.text('Warden Audit & Activity Log'), findsOneWidget);

      // Tap 'Profile' tab
      await tester.tap(find.text('Profile'));
      await tester.pumpAndSettle();
      expect(find.text('Warden Profile'), findsOneWidget);
      expect(find.text('Sign Out of Command Center'), findsOneWidget);
    });
  });
}
