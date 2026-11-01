import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:attendance_app/student/screens/timetable_screen.dart';

void main() {
  Widget buildTestableWidget(Widget child) {
    return MaterialApp(
      home: Scaffold(
        body: child,
      ),
    );
  }

  group('TimetableScreen Tests', () {
    testWidgets('Renders dedicated empty state when no classes scheduled',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        buildTestableWidget(
          const TimetableScreen(
            initialClasses: [],
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('No classes scheduled'), findsOneWidget);
      expect(find.byIcon(Icons.calendar_today_outlined), findsOneWidget);
    });

    testWidgets('Renders populated class items for the selected day',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final testClasses = [
        const ClassScheduleItem(
          title: 'Algorithms & Complexity',
          room: 'Room 301',
          prof: 'Dr. Alan Turing',
          time: '10:00 AM - 11:30 AM',
          dayIndex: 1, // Tuesday (default active tab)
          isNow: true,
        ),
        const ClassScheduleItem(
          title: 'Compiler Design',
          room: 'Lab 4',
          prof: 'Prof. Grace Hopper',
          time: '02:00 PM - 03:30 PM',
          dayIndex: 1,
        ),
        const ClassScheduleItem(
          title: 'Linear Algebra',
          room: 'Room 102',
          prof: 'Dr. Gauss',
          time: '09:00 AM - 10:00 AM',
          dayIndex: 2, // Wednesday
        ),
      ];

      await tester.pumpWidget(
        buildTestableWidget(
          TimetableScreen(
            initialClasses: testClasses,
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Algorithms & Complexity'), findsOneWidget);
      expect(find.text('Compiler Design'), findsOneWidget);
      expect(find.textContaining('Dr. Alan Turing'), findsOneWidget);
      expect(find.text('Linear Algebra'), findsNothing); // Wednesday, not shown on Tue
    });

    testWidgets('Tapping a class card opens the class details modal',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final testClasses = [
        const ClassScheduleItem(
          title: 'Machine Learning',
          room: 'Auditorium 1',
          prof: 'Prof. Andrew Ng',
          time: '11:00 AM - 12:30 PM',
          dayIndex: 1,
        ),
      ];

      await tester.pumpWidget(
        buildTestableWidget(
          TimetableScreen(
            initialClasses: testClasses,
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      await tester.tap(find.text('Machine Learning'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Modal details sheet should be displayed
      expect(find.text('Instructor: Prof. Andrew Ng'), findsOneWidget);
      expect(find.text('Auditorium 1'), findsWidgets);
      expect(find.text('Close'), findsOneWidget);
    });

    testWidgets('Displays loading indicator when isLoading is true',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        buildTestableWidget(
          const TimetableScreen(
            isLoading: true,
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('Displays error message when errorMessage is present',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        buildTestableWidget(
          const TimetableScreen(
            errorMessage: 'Network timeout loading timetable',
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Network timeout loading timetable'), findsOneWidget);
      expect(find.byIcon(Icons.error_outline_rounded), findsOneWidget);
    });

    testWidgets('Switching day filter tab updates displayed classes',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final testClasses = [
        const ClassScheduleItem(
          title: 'Tuesday Subject',
          room: 'Room A',
          prof: 'Prof. A',
          time: '09:00 AM',
          dayIndex: 1, // Tue
        ),
        const ClassScheduleItem(
          title: 'Wednesday Subject',
          room: 'Room B',
          prof: 'Prof. B',
          time: '10:00 AM',
          dayIndex: 2, // Wed
        ),
      ];

      await tester.pumpWidget(
        buildTestableWidget(
          TimetableScreen(
            initialClasses: testClasses,
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Tuesday Subject'), findsOneWidget);
      expect(find.text('Wednesday Subject'), findsNothing);

      // Tap Wednesday tab (index 2)
      await tester.tap(find.text('Wed'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Tuesday Subject'), findsNothing);
      expect(find.text('Wednesday Subject'), findsOneWidget);
    });
  });
}
