import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:provider/provider.dart';

import 'package:attendance_app/auth/models/user_model.dart';
import 'package:attendance_app/auth/providers/user_provider.dart';
import 'package:attendance_app/core/theme/campus_os_theme.dart';
import 'package:attendance_app/router/app_router.dart';
import 'package:attendance_app/shared/providers/attendance_provider.dart';
import 'package:attendance_app/student/screens/student_shell_screen.dart';
import 'package:attendance_app/student/screens/timetable_screen.dart';
import 'package:attendance_app/student/screens/student_analytics_screen.dart';
import 'package:attendance_app/student/screens/mess_screen.dart';
import 'performance_config.dart';
import 'performance_helpers.dart';
import 'performance_reporter.dart';

Widget _createWrapper(Widget child, {UserModel? user}) {
  final userProvider = UserProvider();
  userProvider.setUser(user ?? PerformanceTestUsers.student);

  return MultiProvider(
    providers: [
      ChangeNotifierProvider<UserProvider>.value(value: userProvider),
      ChangeNotifierProvider<AttendanceProvider>(create: (_) => AttendanceProvider()),
    ],
    child: MaterialApp(
      title: 'Student Performance Audit',
      debugShowCheckedModeBanner: false,
      theme: CampusOSTheme.lightTheme,
      onGenerateRoute: AppRouter.generateRoute,
      home: child,
    ),
  );
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('CampusOS Student Role Performance Benchmarks', () {
    testWidgets('1. Student Shell Dock Switching & Frame Fluidity', (tester) async {
      await tester.binding.setSurfaceSize(const Size(384, 832));

      await tester.pumpWidget(
        _createWrapper(
          StudentShellScreen(
            user: PerformanceTestUsers.student,
            overallAttendance: 85.5,
            recentAttendance: const [],
            loading: false,
          ),
        ),
      );
      await tester.pumpAndSettle();

      final collector = FrameTimingCollector();

      // Benchmark switching across all 4 dock tabs
      collector.start();

      // Tab 1: Passport
      final swPassport = Stopwatch()..start();
      await tester.tap(find.text('Passport'));
      await tester.pumpAndSettle();
      swPassport.stop();
      collector.recordPump(swPassport.elapsed);

      // Tab 2: Requests
      final swRequests = Stopwatch()..start();
      await tester.tap(find.text('Requests'));
      await tester.pumpAndSettle();
      swRequests.stop();
      collector.recordPump(swRequests.elapsed);

      // Tab 3: Profile
      final swProfile = Stopwatch()..start();
      await tester.tap(find.text('Profile'));
      await tester.pumpAndSettle();
      swProfile.stop();
      collector.recordPump(swProfile.elapsed);

      // Back to Tab 0: Home
      final swHome = Stopwatch()..start();
      await tester.tap(find.text('Home'));
      await tester.pumpAndSettle();
      swHome.stop();
      collector.recordPump(swHome.elapsed);

      final result = collector.stop(
        actionName: 'Student: Shell 4-Tab Dock Switching',
        targetBudgetMs: PerformanceConfig.frameBudget120HzMs,
      );

      PerformanceReporter.instance.recordFrameBenchmark(result);
      expect(result.status, isNot(PerformanceStatus.critical));
    });

    testWidgets('2. Student Home Scroll Performance', (tester) async {
      await tester.binding.setSurfaceSize(const Size(384, 832));

      await tester.pumpWidget(
        _createWrapper(
          StudentShellScreen(
            user: PerformanceTestUsers.student,
            overallAttendance: 88.0,
            recentAttendance: const [],
            loading: false,
          ),
        ),
      );
      await tester.pumpAndSettle();

      final scrollable = find.byType(Scrollable).first;
      final result = await PerformanceHelpers.measureScrollPerformance(
        tester,
        scrollable,
        actionName: 'Student: Home Feed Scroll Benchmark',
        totalScrollDistance: 600.0,
        steps: 15,
        targetBudgetMs: PerformanceConfig.frameBudget120HzMs,
      );

      PerformanceReporter.instance.recordFrameBenchmark(result);
      expect(result.status, isNot(PerformanceStatus.critical));
    });

    testWidgets('3. Student Timetable Scroll Benchmark', (tester) async {
      await tester.binding.setSurfaceSize(const Size(384, 832));

      await tester.pumpWidget(_createWrapper(const TimetableScreen()));
      await tester.pumpAndSettle();

      final scrollableFinder = find.byType(Scrollable);
      if (scrollableFinder.evaluate().isNotEmpty) {
        final result = await PerformanceHelpers.measureScrollPerformance(
          tester,
          scrollableFinder.first,
          actionName: 'Student: Timetable Scroll Benchmark',
          totalScrollDistance: 400.0,
          steps: 12,
        );
        PerformanceReporter.instance.recordFrameBenchmark(result);
        expect(result.status, isNot(PerformanceStatus.critical));
      }
    });

    testWidgets('4. Student Analytics Chart & Render Benchmark', (tester) async {
      await tester.binding.setSurfaceSize(const Size(384, 832));

      final collector = FrameTimingCollector();
      collector.start();

      final sw = Stopwatch()..start();
      await tester.pumpWidget(_createWrapper(const StudentAnalyticsScreen()));
      await tester.pumpAndSettle();
      sw.stop();
      collector.recordPump(sw.elapsed);

      final result = collector.stop(
        actionName: 'Student: Analytics Dashboard Render',
      );
      PerformanceReporter.instance.recordFrameBenchmark(result);
      expect(result.status, isNot(PerformanceStatus.critical));
    });

    testWidgets('5. Student Mess Menu Render & Interaction', (tester) async {
      await tester.binding.setSurfaceSize(const Size(384, 832));

      await tester.pumpWidget(_createWrapper(const MessScreen()));
      await tester.pumpAndSettle();

      final scrollableFinder = find.byType(Scrollable);
      if (scrollableFinder.evaluate().isNotEmpty) {
        final result = await PerformanceHelpers.measureScrollPerformance(
          tester,
          scrollableFinder.first,
          actionName: 'Student: Mess Menu Daily View Scroll',
          totalScrollDistance: 350.0,
          steps: 10,
        );
        PerformanceReporter.instance.recordFrameBenchmark(result);
        expect(result.status, isNot(PerformanceStatus.critical));
      }
    });

    testWidgets('6. Student Repeated Navigation Memory Benchmark', (tester) async {
      await tester.binding.setSurfaceSize(const Size(384, 832));

      final memResult = await PerformanceHelpers.measureRepeatedNavigationMemory(
        tester,
        screenName: 'Student: Timetable Re-Navigation Cycle',
        iterations: 5,
        navigateIn: () async {
          await tester.pumpWidget(_createWrapper(const TimetableScreen()));
        },
        navigateBack: () async {
          await tester.pumpWidget(
            _createWrapper(
              StudentShellScreen(
                user: PerformanceTestUsers.student,
                overallAttendance: 85.0,
                recentAttendance: const [],
                loading: false,
              ),
            ),
          );
        },
      );

      PerformanceReporter.instance.recordMemoryBenchmark(memResult);
      expect(memResult.status, isNot(PerformanceStatus.critical));
    });
  });
}
