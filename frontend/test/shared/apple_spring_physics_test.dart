import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:attendance_app/shared/widgets/motion/apple_spring_scroll_physics.dart';
import 'package:attendance_app/shared/widgets/motion/apple_spring_curve.dart';
import 'package:attendance_app/shared/widgets/motion/apple_bounceable.dart';

void main() {
  group('AppleSpringScrollPhysics Tests', () {
    test('Configured with authentic iOS UIScrollView spring description', () {
      const physics = AppleSpringScrollPhysics();
      expect(physics.spring.mass, equals(0.8));
      expect(physics.spring.stiffness, equals(165.0));
      expect(physics.spring.damping, equals(25.0));
    });

    test('AppleSpringScrollPhysics.always sets up AlwaysScrollable with spring parent', () {
      const always = AppleSpringScrollPhysics.always;
      expect(always, isA<AlwaysScrollableScrollPhysics>());
      expect(always.parent, isA<AppleSpringScrollPhysics>());
    });

    test('Friction factor produces exponential rubber-band resistance', () {
      const physics = AppleSpringScrollPhysics();
      final frictionAtZero = physics.frictionFactor(0.0);
      final frictionAtOverscroll = physics.frictionFactor(0.5);
      final frictionAtHighOverscroll = physics.frictionFactor(1.0);

      expect(frictionAtZero, closeTo(0.52, 0.01));
      expect(frictionAtOverscroll, lessThan(frictionAtZero));
      expect(frictionAtHighOverscroll, lessThan(frictionAtOverscroll));
    });

    test('applyTo creates equivalent physics instance', () {
      const physics = AppleSpringScrollPhysics();
      final applied = physics.applyTo(null);
      expect(applied, isA<AppleSpringScrollPhysics>());
      expect(applied.spring.mass, equals(0.8));
    });
  });

  group('AppleSpringCurve Tests', () {
    test('Boundary conditions: transform(0.0) is 0 and transform(1.0) is 1.0', () {
      const standard = AppleSpringCurve.standard;
      const bouncy = AppleSpringCurve.bouncy;
      const smooth = AppleSpringCurve.smooth;

      expect(standard.transform(0.0), equals(0.0));
      expect(standard.transform(1.0), equals(1.0));

      expect(bouncy.transform(0.0), equals(0.0));
      expect(bouncy.transform(1.0), equals(1.0));

      expect(smooth.transform(0.0), equals(0.0));
      expect(smooth.transform(1.0), equals(1.0));
    });

    test('AppleSpringCurve.standard settles smoothly without massive oscillation', () {
      const standard = AppleSpringCurve.standard;
      final midVal = standard.transform(0.5);
      expect(midVal, greaterThan(0.5));
      expect(midVal, lessThanOrEqualTo(1.05));
    });

    test('AppleSpringCurve.bouncy exhibits subtle iOS tactile overshoot before 1.0', () {
      const bouncy = AppleSpringCurve.bouncy;
      bool hasOvershot = false;
      for (double t = 0.3; t < 0.95; t += 0.05) {
        if (bouncy.transform(t) > 1.0) {
          hasOvershot = true;
          break;
        }
      }
      expect(hasOvershot, isTrue, reason: 'Bouncy curve should exhibit subtle natural overshoot');
    });
  });

  group('AppleBounceable Widget Tests', () {
    testWidgets('Renders child and responds to tap gesture', (tester) async {
      bool tapped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: AppleBounceable(
                onTap: () => tapped = true,
                child: const Text('Bounce Me'),
              ),
            ),
          ),
        ),
      );

      expect(find.text('Bounce Me'), findsOneWidget);

      await tester.tap(find.text('Bounce Me'));
      await tester.pumpAndSettle();

      expect(tapped, isTrue);
    });

    testWidgets('Widget extension .bounceable() wraps child properly', (tester) async {
      bool tapped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: const Text('Extension Button').bounceable(
                onTap: () => tapped = true,
                scaleFactor: 0.95,
              ),
            ),
          ),
        ),
      );

      expect(find.text('Extension Button'), findsOneWidget);
      expect(find.byType(AppleBounceable), findsOneWidget);

      await tester.tap(find.text('Extension Button'));
      await tester.pumpAndSettle();

      expect(tapped, isTrue);
    });

    testWidgets('AppleBounceable responds to tap and executes callback', (tester) async {
      int tapCount = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: AppleBounceable(
                scaleFactor: 0.90,
                onTap: () => tapCount++,
                child: const Text('Bounce Target'),
              ),
            ),
          ),
        ),
      );

      final finder = find.text('Bounce Target');
      expect(finder, findsOneWidget);

      await tester.tap(finder);
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 200));

      expect(tapCount, equals(1));
    });

    testWidgets('Respects reduce motion: scale stays 1.0 when disableAnimations is true', (tester) async {
      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: MaterialApp(
            home: Scaffold(
              body: Center(
                child: AppleBounceable(
                  scaleFactor: 0.80,
                  onTap: () {},
                  child: const Text('Accessible Button'),
                ),
              ),
            ),
          ),
        ),
      );

      final transformFinder = find.ancestor(
        of: find.text('Accessible Button'),
        matching: find.byType(Transform),
      );
      final Transform transform = tester.widget(transformFinder.first);
      expect(transform.transform.getMaxScaleOnAxis(), equals(1.0));

      await tester.tap(find.text('Accessible Button'));
      await tester.pump(const Duration(milliseconds: 50));

      final Transform transformAfter = tester.widget(transformFinder.first);
      expect(transformAfter.transform.getMaxScaleOnAxis(), equals(1.0));
    });
  });
}
