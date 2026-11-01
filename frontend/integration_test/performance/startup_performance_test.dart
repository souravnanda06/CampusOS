import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:attendance_app/core/theme/campus_os_theme.dart';
import 'package:attendance_app/router/app_router.dart';
import 'package:attendance_app/router/app_routes.dart';
import 'performance_config.dart';
import 'performance_helpers.dart';
import 'performance_reporter.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('CampusOS Startup & First-Frame Benchmarks', () {
    testWidgets('Cold & Warm Startup Frame Benchmarking', (tester) async {
      // Set target physical device resolution (Samsung Galaxy A55: 1080x2340 @ DPR 2.8125 -> 384x832 dp)
      await tester.binding.setSurfaceSize(const Size(384, 832));

      // 1. Cold Startup Measurement
      final startupResult = await PerformanceHelpers.measureStartup(tester);

      // Verify and record cold startup metrics
      expect(startupResult.flutterBindingInitMs, greaterThanOrEqualTo(0.0));
      expect(startupResult.firstFrameMs, greaterThan(0.0));
      expect(startupResult.firstMeaningfulFrameMs, greaterThan(0.0));

      PerformanceReporter.instance.recordStartup(startupResult);

      // 2. Warm Startup / Route Re-initialization Measurement
      final warmSw = Stopwatch()..start();
      await tester.pumpWidget(
        MaterialApp(
          title: 'CampusOS Warm Harness',
          theme: CampusOSTheme.lightTheme,
          initialRoute: AppRoutes.splash,
          onGenerateRoute: AppRouter.generateRoute,
        ),
      );
      await tester.pump();
      warmSw.stop();

      final warmStartupMs = warmSw.elapsedMilliseconds.toDouble();
      expect(warmStartupMs, lessThan(PerformanceConfig.coldStartupWarningMs));

      // Record first-frame action benchmark
      PerformanceReporter.instance.recordFrameBenchmark(
        FrameBenchmarkResult(
          actionName: 'App Startup: Cold Splash Launch',
          totalFrames: 1,
          averageFrameMs: startupResult.firstFrameMs,
          peakFrameMs: startupResult.firstFrameMs,
          framesOverBudget: startupResult.firstFrameMs > PerformanceConfig.frameBudget120HzMs ? 1 : 0,
          severeStalls: startupResult.firstFrameMs > PerformanceConfig.criticalFrameThresholdMs ? 1 : 0,
          jankRatePercent: 0.0,
          status: startupResult.status,
          frameDurationsMs: [startupResult.firstFrameMs],
        ),
      );
    });
  });
}
