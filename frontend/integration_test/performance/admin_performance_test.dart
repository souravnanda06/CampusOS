import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:provider/provider.dart';

import 'package:attendance_app/auth/models/user_model.dart';
import 'package:attendance_app/auth/providers/user_provider.dart';
import 'package:attendance_app/core/theme/campus_os_theme.dart';
import 'package:attendance_app/router/app_router.dart';
import 'package:attendance_app/shared/providers/attendance_provider.dart';
import 'package:attendance_app/admin/screens/admin_shell_screen.dart';
import 'package:attendance_app/admin/screens/admin_operations_screen.dart';
import 'package:attendance_app/admin/screens/admin_complaints_screen.dart';
import 'performance_config.dart';
import 'performance_helpers.dart';
import 'performance_reporter.dart';

Widget _createWrapper(Widget child, {UserModel? user}) {
  final userProvider = UserProvider();
  userProvider.setUser(user ?? PerformanceTestUsers.admin);

  return MultiProvider(
    providers: [
      ChangeNotifierProvider<UserProvider>.value(value: userProvider),
      ChangeNotifierProvider<AttendanceProvider>(create: (_) => AttendanceProvider()),
    ],
    child: MaterialApp(
      title: 'Admin Performance Audit',
      debugShowCheckedModeBanner: false,
      theme: CampusOSTheme.lightTheme,
      onGenerateRoute: AppRouter.generateRoute,
      home: child,
    ),
  );
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('CampusOS Admin Role Performance Benchmarks', () {
    testWidgets('1. Admin Shell 4-Tab Dock Switching', (tester) async {
      await tester.binding.setSurfaceSize(const Size(384, 832));

      await tester.pumpWidget(
        _createWrapper(
          AdminShellScreen(user: PerformanceTestUsers.admin),
        ),
      );
      await tester.pumpAndSettle();

      final collector = FrameTimingCollector();
      collector.start();

      // Tab 1: Operations
      final swOps = Stopwatch()..start();
      await tester.tap(find.text('Operations'));
      await tester.pumpAndSettle();
      swOps.stop();
      collector.recordPump(swOps.elapsed);

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
        actionName: 'Admin: Shell 4-Tab Dock Switching',
        targetBudgetMs: PerformanceConfig.frameBudget120HzMs,
      );

      PerformanceReporter.instance.recordFrameBenchmark(result);
      expect(result.status, isNot(PerformanceStatus.critical));
    });

    testWidgets('2. Admin Operations Hub Scroll Benchmark', (tester) async {
      await tester.binding.setSurfaceSize(const Size(384, 832));

      await tester.pumpWidget(
        _createWrapper(
          AdminOperationsScreen(user: PerformanceTestUsers.admin),
        ),
      );
      await tester.pumpAndSettle();

      final scrollableFinder = find.byType(Scrollable);
      if (scrollableFinder.evaluate().isNotEmpty) {
        final result = await PerformanceHelpers.measureScrollPerformance(
          tester,
          scrollableFinder.first,
          actionName: 'Admin: Operations Grid Scroll',
          totalScrollDistance: 400.0,
          steps: 12,
        );
        PerformanceReporter.instance.recordFrameBenchmark(result);
        expect(result.status, isNot(PerformanceStatus.critical));
      }
    });

    testWidgets('3. Admin Complaints Search Input Benchmark', (tester) async {
      await tester.binding.setSurfaceSize(const Size(384, 832));

      await tester.pumpWidget(
        _createWrapper(
          AdminComplaintsScreen(user: PerformanceTestUsers.admin),
        ),
      );
      await tester.pumpAndSettle();

      final searchField = find.byType(TextField);
      if (searchField.evaluate().isNotEmpty) {
        final inputResult = await PerformanceHelpers.measureInputPerformance(
          tester,
          searchField.first,
          'Water leakage',
          actionName: 'Admin: Complaints Search Query Input',
        );
        PerformanceReporter.instance.recordFrameBenchmark(inputResult);
        expect(inputResult.status, isNot(PerformanceStatus.critical));
      }
    });

    testWidgets('4. Admin Repeated Navigation Memory Benchmark', (tester) async {
      await tester.binding.setSurfaceSize(const Size(384, 832));

      final memResult = await PerformanceHelpers.measureRepeatedNavigationMemory(
        tester,
        screenName: 'Admin: Complaints Re-Navigation Cycle',
        iterations: 5,
        navigateIn: () async {
          await tester.pumpWidget(
            _createWrapper(
              AdminComplaintsScreen(user: PerformanceTestUsers.admin),
            ),
          );
        },
        navigateBack: () async {
          await tester.pumpWidget(
            _createWrapper(
              AdminShellScreen(user: PerformanceTestUsers.admin),
            ),
          );
        },
      );

      PerformanceReporter.instance.recordMemoryBenchmark(memResult);
      expect(memResult.status, isNot(PerformanceStatus.critical));
    });
  });
}
