import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:provider/provider.dart';

import 'package:attendance_app/auth/models/user_model.dart';
import 'package:attendance_app/auth/providers/user_provider.dart';
import 'package:attendance_app/core/theme/campus_os_theme.dart';
import 'package:attendance_app/router/app_router.dart';
import 'package:attendance_app/shared/providers/attendance_provider.dart';
import 'package:attendance_app/security/screens/security_shell_screen.dart';
import 'package:attendance_app/security/screens/security_passes_screen.dart';
import 'package:attendance_app/security/screens/security_activity_screen.dart';
import 'package:attendance_app/security/screens/security_verify_screen.dart';
import 'performance_config.dart';
import 'performance_helpers.dart';
import 'performance_reporter.dart';

Widget _createWrapper(Widget child, {UserModel? user}) {
  final userProvider = UserProvider();
  userProvider.setUser(user ?? PerformanceTestUsers.security);

  return MultiProvider(
    providers: [
      ChangeNotifierProvider<UserProvider>.value(value: userProvider),
      ChangeNotifierProvider<AttendanceProvider>(create: (_) => AttendanceProvider()),
    ],
    child: MaterialApp(
      title: 'Security Performance Audit',
      debugShowCheckedModeBanner: false,
      theme: CampusOSTheme.lightTheme,
      onGenerateRoute: AppRouter.generateRoute,
      home: child,
    ),
  );
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('CampusOS Gate Security Role Performance Benchmarks', () {
    testWidgets('1. Security Shell 4-Tab Dock Switching', (tester) async {
      await tester.binding.setSurfaceSize(const Size(384, 832));

      await tester.pumpWidget(
        _createWrapper(
          SecurityShellScreen(user: PerformanceTestUsers.security),
        ),
      );
      await tester.pumpAndSettle();

      final collector = FrameTimingCollector();
      collector.start();

      // Tab 1: Passes
      final swPasses = Stopwatch()..start();
      await tester.tap(find.text('Passes'));
      await tester.pumpAndSettle();
      swPasses.stop();
      collector.recordPump(swPasses.elapsed);

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
        actionName: 'Security: Shell 4-Tab Dock Switching',
        targetBudgetMs: PerformanceConfig.frameBudget120HzMs,
      );

      PerformanceReporter.instance.recordFrameBenchmark(result);
      expect(result.status, isNot(PerformanceStatus.critical));
    });

    testWidgets('2. Security Passes List Scroll Benchmark', (tester) async {
      await tester.binding.setSurfaceSize(const Size(384, 832));

      await tester.pumpWidget(
        _createWrapper(
          SecurityPassesScreen(user: PerformanceTestUsers.security),
        ),
      );
      await tester.pumpAndSettle();

      final scrollableFinder = find.byType(Scrollable);
      if (scrollableFinder.evaluate().isNotEmpty) {
        final result = await PerformanceHelpers.measureScrollPerformance(
          tester,
          scrollableFinder.first,
          actionName: 'Security: Passes Roster Scroll',
          totalScrollDistance: 400.0,
          steps: 12,
        );
        PerformanceReporter.instance.recordFrameBenchmark(result);
        expect(result.status, isNot(PerformanceStatus.critical));
      }
    });

    testWidgets('3. Security Activity Audit Log Scroll Benchmark', (tester) async {
      await tester.binding.setSurfaceSize(const Size(384, 832));

      await tester.pumpWidget(
        _createWrapper(
          SecurityActivityScreen(user: PerformanceTestUsers.security),
        ),
      );
      await tester.pumpAndSettle();

      final scrollableFinder = find.byType(Scrollable);
      if (scrollableFinder.evaluate().isNotEmpty) {
        final result = await PerformanceHelpers.measureScrollPerformance(
          tester,
          scrollableFinder.first,
          actionName: 'Security: Gate Activity Timeline Scroll',
          totalScrollDistance: 400.0,
          steps: 10,
        );
        PerformanceReporter.instance.recordFrameBenchmark(result);
        expect(result.status, isNot(PerformanceStatus.critical));
      }
    });

    testWidgets('4. Security Verify Screen Radar Lifecycle Benchmark', (tester) async {
      await tester.binding.setSurfaceSize(const Size(384, 832));

      final collector = FrameTimingCollector();
      collector.start();

      final sw = Stopwatch()..start();
      await tester.pumpWidget(
        _createWrapper(
          SecurityVerifyScreen(
            user: PerformanceTestUsers.security,
            gateName: 'Main Gate Terminal 1',
            startWithQr: false,
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      sw.stop();
      collector.recordPump(sw.elapsed);

      final result = collector.stop(
        actionName: 'Security: Verification Radar Launch',
      );
      PerformanceReporter.instance.recordFrameBenchmark(result);
      expect(result.status, isNot(PerformanceStatus.critical));
    });

    testWidgets('5. Security Repeated Navigation Memory Benchmark', (tester) async {
      await tester.binding.setSurfaceSize(const Size(384, 832));

      final memResult = await PerformanceHelpers.measureRepeatedNavigationMemory(
        tester,
        screenName: 'Security: Verify Radar Re-Navigation Cycle',
        iterations: 5,
        navigateIn: () async {
          await tester.pumpWidget(
            _createWrapper(
              SecurityVerifyScreen(
                user: PerformanceTestUsers.security,
                gateName: 'Main Gate Terminal 1',
                startWithQr: false,
              ),
            ),
          );
        },
        navigateBack: () async {
          await tester.pumpWidget(
            _createWrapper(
              SecurityShellScreen(user: PerformanceTestUsers.security),
            ),
          );
        },
      );

      PerformanceReporter.instance.recordMemoryBenchmark(memResult);
      expect(memResult.status, isNot(PerformanceStatus.critical));
    });
  });
}
