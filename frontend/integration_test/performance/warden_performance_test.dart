import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:provider/provider.dart';

import 'package:attendance_app/auth/models/user_model.dart';
import 'package:attendance_app/auth/providers/user_provider.dart';
import 'package:attendance_app/core/theme/campus_os_theme.dart';
import 'package:attendance_app/router/app_router.dart';
import 'package:attendance_app/shared/providers/attendance_provider.dart';
import 'package:attendance_app/warden/screens/warden_shell_screen.dart';
import 'package:attendance_app/warden/screens/warden_leave_requests_screen.dart';
import 'package:attendance_app/warden/screens/warden_activity_screen.dart';
import 'package:attendance_app/warden/screens/warden_leave_inbox_screen.dart';
import 'performance_config.dart';
import 'performance_helpers.dart';
import 'performance_reporter.dart';

Widget _createWrapper(Widget child, {UserModel? user}) {
  final userProvider = UserProvider();
  userProvider.setUser(user ?? PerformanceTestUsers.warden);

  return MultiProvider(
    providers: [
      ChangeNotifierProvider<UserProvider>.value(value: userProvider),
      ChangeNotifierProvider<AttendanceProvider>(create: (_) => AttendanceProvider()),
    ],
    child: MaterialApp(
      title: 'Warden Performance Audit',
      debugShowCheckedModeBanner: false,
      theme: CampusOSTheme.lightTheme,
      onGenerateRoute: AppRouter.generateRoute,
      home: child,
    ),
  );
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('CampusOS Warden Role Performance Benchmarks', () {
    testWidgets('1. Warden Shell 4-Tab Dock Switching', (tester) async {
      await tester.binding.setSurfaceSize(const Size(384, 832));

      await tester.pumpWidget(
        _createWrapper(
          WardenShellScreen(user: PerformanceTestUsers.warden),
        ),
      );
      await tester.pumpAndSettle();

      final collector = FrameTimingCollector();
      collector.start();

      // Tab 1: Requests
      final swRequests = Stopwatch()..start();
      await tester.tap(find.text('Requests'));
      await tester.pumpAndSettle();
      swRequests.stop();
      collector.recordPump(swRequests.elapsed);

      // Tab 2: Activity
      final swActivity = Stopwatch()..start();
      await tester.tap(find.text('Activity'));
      await tester.pumpAndSettle();
      swActivity.stop();
      collector.recordPump(swActivity.elapsed);

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
        actionName: 'Warden: Shell 4-Tab Dock Switching',
        targetBudgetMs: PerformanceConfig.frameBudget120HzMs,
      );

      PerformanceReporter.instance.recordFrameBenchmark(result);
      expect(result.status, isNot(PerformanceStatus.critical));
    });

    testWidgets('2. Warden Leave Requests Scroll Benchmark', (tester) async {
      await tester.binding.setSurfaceSize(const Size(384, 832));

      await tester.pumpWidget(
        _createWrapper(
          WardenLeaveRequestsScreen(user: PerformanceTestUsers.warden),
        ),
      );
      await tester.pumpAndSettle();

      final scrollableFinder = find.byType(Scrollable);
      if (scrollableFinder.evaluate().isNotEmpty) {
        final result = await PerformanceHelpers.measureScrollPerformance(
          tester,
          scrollableFinder.first,
          actionName: 'Warden: Leave Requests List Scroll',
          totalScrollDistance: 450.0,
          steps: 12,
        );
        PerformanceReporter.instance.recordFrameBenchmark(result);
        expect(result.status, isNot(PerformanceStatus.critical));
      }
    });

    testWidgets('3. Warden Activity Timeline Scroll Benchmark', (tester) async {
      await tester.binding.setSurfaceSize(const Size(384, 832));

      await tester.pumpWidget(
        _createWrapper(
          WardenActivityScreen(user: PerformanceTestUsers.warden),
        ),
      );
      await tester.pumpAndSettle();

      final scrollableFinder = find.byType(Scrollable);
      if (scrollableFinder.evaluate().isNotEmpty) {
        final result = await PerformanceHelpers.measureScrollPerformance(
          tester,
          scrollableFinder.first,
          actionName: 'Warden: Gate Activity Audit Scroll',
          totalScrollDistance: 400.0,
          steps: 10,
        );
        PerformanceReporter.instance.recordFrameBenchmark(result);
        expect(result.status, isNot(PerformanceStatus.critical));
      }
    });

    testWidgets('4. Warden Repeated Navigation Memory Benchmark', (tester) async {
      await tester.binding.setSurfaceSize(const Size(384, 832));

      final memResult = await PerformanceHelpers.measureRepeatedNavigationMemory(
        tester,
        screenName: 'Warden: Leave Inbox Re-Navigation Cycle',
        iterations: 5,
        navigateIn: () async {
          await tester.pumpWidget(
            _createWrapper(
              WardenLeaveInboxScreen(user: PerformanceTestUsers.warden),
            ),
          );
        },
        navigateBack: () async {
          await tester.pumpWidget(
            _createWrapper(
              WardenShellScreen(user: PerformanceTestUsers.warden),
            ),
          );
        },
      );

      PerformanceReporter.instance.recordMemoryBenchmark(memResult);
      expect(memResult.status, isNot(PerformanceStatus.critical));
    });
  });
}
