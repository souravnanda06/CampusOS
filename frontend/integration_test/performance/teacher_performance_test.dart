import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:provider/provider.dart';

import 'package:attendance_app/auth/models/user_model.dart';
import 'package:attendance_app/auth/providers/user_provider.dart';
import 'package:attendance_app/core/theme/campus_os_theme.dart';
import 'package:attendance_app/router/app_router.dart';
import 'package:attendance_app/shared/providers/attendance_provider.dart';
import 'package:attendance_app/teacher/screens/teacher_shell_screen.dart';
import 'package:attendance_app/teacher/screens/teacher_classes_screen.dart';
import 'package:attendance_app/teacher/screens/create_session_screen.dart';
import 'package:attendance_app/teacher/screens/class_detail_screen.dart';
import 'performance_config.dart';
import 'performance_helpers.dart';
import 'performance_reporter.dart';

Widget _createWrapper(Widget child, {UserModel? user}) {
  final userProvider = UserProvider();
  userProvider.setUser(user ?? PerformanceTestUsers.teacher);

  return MultiProvider(
    providers: [
      ChangeNotifierProvider<UserProvider>.value(value: userProvider),
      ChangeNotifierProvider<AttendanceProvider>(create: (_) => AttendanceProvider()),
    ],
    child: MaterialApp(
      title: 'Teacher Performance Audit',
      debugShowCheckedModeBanner: false,
      theme: CampusOSTheme.lightTheme,
      onGenerateRoute: AppRouter.generateRoute,
      home: child,
    ),
  );
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('CampusOS Teacher Role Performance Benchmarks', () {
    testWidgets('1. Teacher Shell 4-Tab Dock Switching', (tester) async {
      await tester.binding.setSurfaceSize(const Size(384, 832));

      await tester.pumpWidget(
        _createWrapper(
          TeacherShellScreen(
            user: PerformanceTestUsers.teacher,
            activeSessions: const [],
            onRefreshSessions: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      final collector = FrameTimingCollector();
      collector.start();

      // Tab 1: Classes
      final swClasses = Stopwatch()..start();
      await tester.tap(find.text('Classes'));
      await tester.pumpAndSettle();
      swClasses.stop();
      collector.recordPump(swClasses.elapsed);

      // Tab 2: Analytics
      final swAnalytics = Stopwatch()..start();
      await tester.tap(find.text('Analytics'));
      await tester.pumpAndSettle();
      swAnalytics.stop();
      collector.recordPump(swAnalytics.elapsed);

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
        actionName: 'Teacher: Shell 4-Tab Dock Switching',
        targetBudgetMs: PerformanceConfig.frameBudget120HzMs,
      );

      PerformanceReporter.instance.recordFrameBenchmark(result);
      expect(result.status, isNot(PerformanceStatus.critical));
    });

    testWidgets('2. Teacher Classes List Scroll Benchmark', (tester) async {
      await tester.binding.setSurfaceSize(const Size(384, 832));

      await tester.pumpWidget(
        _createWrapper(
          TeacherClassesScreen(user: PerformanceTestUsers.teacher),
        ),
      );
      await tester.pumpAndSettle();

      final scrollableFinder = find.byType(Scrollable);
      if (scrollableFinder.evaluate().isNotEmpty) {
        final result = await PerformanceHelpers.measureScrollPerformance(
          tester,
          scrollableFinder.first,
          actionName: 'Teacher: Classes Roster Scroll',
          totalScrollDistance: 450.0,
          steps: 12,
        );
        PerformanceReporter.instance.recordFrameBenchmark(result);
        expect(result.status, isNot(PerformanceStatus.critical));
      }
    });

    testWidgets('3. Teacher Create Session Form Input Benchmark', (tester) async {
      await tester.binding.setSurfaceSize(const Size(384, 832));

      await tester.pumpWidget(_createWrapper(const CreateSessionScreen()));
      await tester.pumpAndSettle();

      final textFields = find.byType(TextField);
      if (textFields.evaluate().isNotEmpty) {
        final inputResult = await PerformanceHelpers.measureInputPerformance(
          tester,
          textFields.first,
          'Lab 302 Block C',
          actionName: 'Teacher: Create Session Location Input',
        );
        PerformanceReporter.instance.recordFrameBenchmark(inputResult);
        expect(inputResult.status, isNot(PerformanceStatus.critical));
      }
    });

    testWidgets('4. Teacher Class Detail Overview Render', (tester) async {
      await tester.binding.setSurfaceSize(const Size(384, 832));

      final collector = FrameTimingCollector();
      collector.start();

      final sw = Stopwatch()..start();
      await tester.pumpWidget(
        _createWrapper(
          ClassDetailScreen(
            subjectName: 'Computer Networks',
            course: 'B.Tech',
            branch: 'CSE',
            year: '3rd',
            room: 'Hall 101',
            user: PerformanceTestUsers.teacher,
          ),
        ),
      );
      await tester.pumpAndSettle();
      sw.stop();
      collector.recordPump(sw.elapsed);

      final result = collector.stop(
        actionName: 'Teacher: Class Detail Screen Render',
      );
      PerformanceReporter.instance.recordFrameBenchmark(result);
      expect(result.status, isNot(PerformanceStatus.critical));
    });

    testWidgets('5. Teacher Repeated Navigation Memory Benchmark', (tester) async {
      await tester.binding.setSurfaceSize(const Size(384, 832));

      final memResult = await PerformanceHelpers.measureRepeatedNavigationMemory(
        tester,
        screenName: 'Teacher: Create Session Re-Navigation Cycle',
        iterations: 5,
        navigateIn: () async {
          await tester.pumpWidget(_createWrapper(const CreateSessionScreen()));
        },
        navigateBack: () async {
          await tester.pumpWidget(
            _createWrapper(
              TeacherShellScreen(
                user: PerformanceTestUsers.teacher,
                activeSessions: const [],
                onRefreshSessions: () {},
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
