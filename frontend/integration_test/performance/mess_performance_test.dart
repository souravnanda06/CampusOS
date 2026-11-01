import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:provider/provider.dart';

import 'package:attendance_app/auth/models/user_model.dart';
import 'package:attendance_app/auth/providers/user_provider.dart';
import 'package:attendance_app/core/theme/campus_os_theme.dart';
import 'package:attendance_app/router/app_router.dart';
import 'package:attendance_app/shared/providers/attendance_provider.dart';
import 'package:attendance_app/mess/screens/mess_shell_screen.dart';
import 'package:attendance_app/shared/screens/mess/mess_management_screen.dart';
import 'package:attendance_app/shared/screens/mess/mess_composer_screen.dart';
import 'package:attendance_app/mess/screens/mess_batch_verification_screen.dart';
import 'performance_config.dart';
import 'performance_helpers.dart';
import 'performance_reporter.dart';

Widget _createWrapper(Widget child, {UserModel? user}) {
  final userProvider = UserProvider();
  userProvider.setUser(user ?? PerformanceTestUsers.messStaff);

  return MultiProvider(
    providers: [
      ChangeNotifierProvider<UserProvider>.value(value: userProvider),
      ChangeNotifierProvider<AttendanceProvider>(create: (_) => AttendanceProvider()),
    ],
    child: MaterialApp(
      title: 'Mess Performance Audit',
      debugShowCheckedModeBanner: false,
      theme: CampusOSTheme.lightTheme,
      onGenerateRoute: AppRouter.generateRoute,
      home: child,
    ),
  );
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('CampusOS Mess Staff Role Performance Benchmarks', () {
    testWidgets('1. Mess Shell 4-Tab Dock Switching', (tester) async {
      await tester.binding.setSurfaceSize(const Size(384, 832));

      await tester.pumpWidget(
        _createWrapper(
          MessShellScreen(user: PerformanceTestUsers.messStaff),
        ),
      );
      await tester.pumpAndSettle();

      final collector = FrameTimingCollector();
      collector.start();

      // Tab 1: Menus
      final swMenus = Stopwatch()..start();
      await tester.tap(find.text('Menus'));
      await tester.pumpAndSettle();
      swMenus.stop();
      collector.recordPump(swMenus.elapsed);

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

      // Back to Tab 0: Today
      final swToday = Stopwatch()..start();
      await tester.tap(find.text('Today'));
      await tester.pumpAndSettle();
      swToday.stop();
      collector.recordPump(swToday.elapsed);

      final result = collector.stop(
        actionName: 'Mess: Shell 4-Tab Dock Switching',
        targetBudgetMs: PerformanceConfig.frameBudget120HzMs,
      );

      PerformanceReporter.instance.recordFrameBenchmark(result);
      expect(result.status, isNot(PerformanceStatus.critical));
    });

    testWidgets('2. Mess Management Menu List Scroll Benchmark', (tester) async {
      await tester.binding.setSurfaceSize(const Size(384, 832));

      await tester.pumpWidget(
        _createWrapper(
          MessManagementScreen(user: PerformanceTestUsers.messStaff),
        ),
      );
      await tester.pumpAndSettle();

      final scrollableFinder = find.byType(Scrollable);
      if (scrollableFinder.evaluate().isNotEmpty) {
        final result = await PerformanceHelpers.measureScrollPerformance(
          tester,
          scrollableFinder.first,
          actionName: 'Mess: Menu Management List Scroll',
          totalScrollDistance: 400.0,
          steps: 12,
        );
        PerformanceReporter.instance.recordFrameBenchmark(result);
        expect(result.status, isNot(PerformanceStatus.critical));
      }
    });

    testWidgets('3. Mess Composer Screen Form Input Benchmark', (tester) async {
      await tester.binding.setSurfaceSize(const Size(384, 832));

      await tester.pumpWidget(
        _createWrapper(
          MessComposerScreen(user: PerformanceTestUsers.messStaff),
        ),
      );
      await tester.pumpAndSettle();

      final textFields = find.byType(TextField);
      if (textFields.evaluate().isNotEmpty) {
        final inputResult = await PerformanceHelpers.measureInputPerformance(
          tester,
          textFields.first,
          'Deluxe Thali Special',
          actionName: 'Mess: Composer Menu Title Input',
        );
        PerformanceReporter.instance.recordFrameBenchmark(inputResult);
        expect(inputResult.status, isNot(PerformanceStatus.critical));
      }
    });

    testWidgets('4. Mess Batch Verification Lifecycle Benchmark', (tester) async {
      await tester.binding.setSurfaceSize(const Size(384, 832));

      final collector = FrameTimingCollector();
      collector.start();

      final sw = Stopwatch()..start();
      await tester.pumpWidget(
        _createWrapper(
          MessBatchVerificationScreen(
            user: PerformanceTestUsers.messStaff,
            mealType: 'LUNCH',
            date: '2026-09-27',
          ),
        ),
      );
      await tester.pumpAndSettle();
      sw.stop();
      collector.recordPump(sw.elapsed);

      final result = collector.stop(
        actionName: 'Mess: Batch Verification Lifecycle Render',
      );
      PerformanceReporter.instance.recordFrameBenchmark(result);
      expect(result.status, isNot(PerformanceStatus.critical));
    });

    testWidgets('5. Mess Repeated Navigation Memory Benchmark', (tester) async {
      await tester.binding.setSurfaceSize(const Size(384, 832));

      final memResult = await PerformanceHelpers.measureRepeatedNavigationMemory(
        tester,
        screenName: 'Mess: Composer Re-Navigation Cycle',
        iterations: 5,
        navigateIn: () async {
          await tester.pumpWidget(
            _createWrapper(
              MessComposerScreen(user: PerformanceTestUsers.messStaff),
            ),
          );
        },
        navigateBack: () async {
          await tester.pumpWidget(
            _createWrapper(
              MessShellScreen(user: PerformanceTestUsers.messStaff),
            ),
          );
        },
      );

      PerformanceReporter.instance.recordMemoryBenchmark(memResult);
      expect(memResult.status, isNot(PerformanceStatus.critical));
    });
  });
}
