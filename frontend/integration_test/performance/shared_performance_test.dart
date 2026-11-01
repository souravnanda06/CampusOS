import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:provider/provider.dart';

import 'package:attendance_app/auth/models/user_model.dart';
import 'package:attendance_app/auth/providers/user_provider.dart';
import 'package:attendance_app/core/theme/campus_os_theme.dart';
import 'package:attendance_app/router/app_router.dart';
import 'package:attendance_app/shared/providers/attendance_provider.dart';
import 'package:attendance_app/shared/screens/notices/notice_management_screen.dart';
import 'package:attendance_app/shared/screens/notices/notice_composer_screen.dart';
import 'package:attendance_app/student/screens/passport_verifier_screen.dart';
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
      title: 'Shared Performance Audit',
      debugShowCheckedModeBanner: false,
      theme: CampusOSTheme.lightTheme,
      onGenerateRoute: AppRouter.generateRoute,
      home: child,
    ),
  );
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('CampusOS Shared & Modal Performance Benchmarks', () {
    testWidgets('1. Notice Management Screen Scroll Benchmark', (tester) async {
      await tester.binding.setSurfaceSize(const Size(384, 832));

      await tester.pumpWidget(
        _createWrapper(
          NoticeManagementScreen(user: PerformanceTestUsers.teacher),
        ),
      );
      await tester.pumpAndSettle();

      final scrollableFinder = find.byType(Scrollable);
      if (scrollableFinder.evaluate().isNotEmpty) {
        final result = await PerformanceHelpers.measureScrollPerformance(
          tester,
          scrollableFinder.first,
          actionName: 'Shared: Notice Management Feed Scroll',
          totalScrollDistance: 450.0,
          steps: 12,
        );
        PerformanceReporter.instance.recordFrameBenchmark(result);
        expect(result.status, isNot(PerformanceStatus.critical));
      }
    });

    testWidgets('2. Notice Composer Title Input Benchmark', (tester) async {
      await tester.binding.setSurfaceSize(const Size(384, 832));

      await tester.pumpWidget(
        _createWrapper(
          NoticeComposerScreen(user: PerformanceTestUsers.teacher),
        ),
      );
      await tester.pumpAndSettle();

      final textFields = find.byType(TextField);
      if (textFields.evaluate().isNotEmpty) {
        final inputResult = await PerformanceHelpers.measureInputPerformance(
          tester,
          textFields.first,
          'Annual Campus Hackathon Announcement',
          actionName: 'Shared: Notice Composer Title Input',
        );
        PerformanceReporter.instance.recordFrameBenchmark(inputResult);
        expect(inputResult.status, isNot(PerformanceStatus.critical));
      }
    });

    testWidgets('3. Standard Bottom Sheet Modal Presentation Benchmark', (tester) async {
      await tester.binding.setSurfaceSize(const Size(384, 832));

      await tester.pumpWidget(
        _createWrapper(
          Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  key: const Key('open_sheet_btn'),
                  onPressed: () {
                    showModalBottomSheet(
                      context: context,
                      builder: (sheetContext) => Container(
                        height: 300,
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          children: [
                            const Text('CampusOS Action Sheet'),
                            const SizedBox(height: 20),
                            ElevatedButton(
                              key: const Key('close_sheet_btn'),
                              onPressed: () => Navigator.pop(sheetContext),
                              child: const Text('Dismiss'),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                  child: const Text('Open Modal'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final modalResult = await PerformanceHelpers.measureModalPerformance(
        tester,
        openTrigger: find.byKey(const Key('open_sheet_btn')),
        closeTrigger: find.byKey(const Key('close_sheet_btn')),
        actionName: 'Modal: Action BottomSheet Presentation & Dismiss',
      );

      PerformanceReporter.instance.recordFrameBenchmark(modalResult);
      expect(modalResult.status, isNot(PerformanceStatus.critical));
    });

    testWidgets('4. Passport Offline Verifier Mount Benchmark', (tester) async {
      await tester.binding.setSurfaceSize(const Size(384, 832));

      final collector = FrameTimingCollector();
      collector.start();

      final sw = Stopwatch()..start();
      await tester.pumpWidget(
        _createWrapper(
          PassportVerifierScreen(user: PerformanceTestUsers.security),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      sw.stop();
      collector.recordPump(sw.elapsed);

      final result = collector.stop(
        actionName: 'Shared: Passport Offline Verifier Mount',
      );
      PerformanceReporter.instance.recordFrameBenchmark(result);
      expect(result.status, isNot(PerformanceStatus.critical));
    });

    testWidgets('5. Notice Composer Repeated Navigation Memory Benchmark', (tester) async {
      await tester.binding.setSurfaceSize(const Size(384, 832));

      final memResult = await PerformanceHelpers.measureRepeatedNavigationMemory(
        tester,
        screenName: 'Shared: Notice Composer Re-Navigation Cycle',
        iterations: 5,
        navigateIn: () async {
          await tester.pumpWidget(
            _createWrapper(
              NoticeComposerScreen(user: PerformanceTestUsers.teacher),
            ),
          );
        },
        navigateBack: () async {
          await tester.pumpWidget(
            _createWrapper(
              NoticeManagementScreen(user: PerformanceTestUsers.teacher),
            ),
          );
        },
      );

      PerformanceReporter.instance.recordMemoryBenchmark(memResult);
      expect(memResult.status, isNot(PerformanceStatus.critical));
    });
  });
}
