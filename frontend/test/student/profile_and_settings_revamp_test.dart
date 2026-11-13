import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:attendance_app/auth/models/user_model.dart';
import 'package:attendance_app/core/theme/theme_provider.dart';
import 'package:attendance_app/core/haptics/app_haptics.dart';
import 'package:attendance_app/core/haptics/haptics_provider.dart';
import 'package:attendance_app/core/performance/performance.dart';
import 'package:attendance_app/student/screens/profile_screen.dart';
import 'package:attendance_app/student/screens/settings_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final testUser = UserModel(
    id: 'student_101',
    name: 'Sourabh Patra',
    email: 'sourabh@campusos.edu',
    role: 'STUDENT',
    branch: 'Computer Science',
    course: 'B.Tech',
    year: '4th Year',
    registrationNumber: '2023CS0101',
    deviceId: 'DEV99887766',
  );

  group('Theme, Haptics & Motion Engine Providers', () {
    test('ThemeProvider changes mode, updates isDark and labels', () async {
      final provider = ThemeProvider.instance;

      await provider.setThemeMode(ThemeMode.dark);
      expect(provider.themeMode, equals(ThemeMode.dark));
      expect(provider.isDark, isTrue);
      expect(provider.themeModeLabel, equals('Dark'));

      await provider.setThemeMode(ThemeMode.light);
      expect(provider.themeMode, equals(ThemeMode.light));
      expect(provider.isDark, isFalse);
      expect(provider.themeModeLabel, equals('Light'));

      await provider.setThemeMode(ThemeMode.system);
      expect(provider.themeMode, equals(ThemeMode.system));
      expect(provider.themeModeLabel, equals('System Default'));
    });

    test('HapticsProvider toggles enabled state and AppHaptics respects it', () async {
      final provider = HapticsProvider.instance;

      await provider.setEnabled(false);
      expect(provider.isEnabled, isFalse);
      // Calling AppHaptics when disabled is completely silent and safe
      AppHaptics.lightImpact();
      AppHaptics.selectionClick();
      AppHaptics.mediumImpact();
      AppHaptics.heavyImpact();
      AppHaptics.vibrate();

      await provider.setEnabled(true);
      expect(provider.isEnabled, isTrue);
    });

    test('PerformanceEngine setReducedMotion zeroes out motion durations', () {
      final engine = PerformanceEngine.instance;

      engine.setReducedMotion(true);
      final motionReduced = engine.profile.animationProfile;
      expect(motionReduced.reducedMotion, isTrue);
      expect(motionReduced.fast, equals(Duration.zero));
      expect(motionReduced.standard, equals(Duration.zero));
      expect(motionReduced.deliberate, equals(Duration.zero));

      engine.setReducedMotion(false);
      final motionNormal = engine.profile.animationProfile;
      expect(motionNormal.reducedMotion, isFalse);
      expect(motionNormal.standard, isNot(equals(Duration.zero)));
    });
  });

  group('Profile Screen Identity Hub Tests', () {
    testWidgets('ProfileScreen renders as premium Student Identity Hub in Light and Dark mode', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.light(),
          darkTheme: ThemeData.dark(),
          home: ProfileScreen(
            user: testUser,
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // 1. Identity Header: name & avatar initial
      expect(find.text('Sourabh Patra'), findsWidgets);
      expect(find.text('S'), findsOneWidget);

      // 2. Student ID / Registration
      expect(find.text('Student ID'), findsOneWidget);
      expect(find.text('2023CS0101'), findsOneWidget);
      expect(find.text('sourabh@campusos.edu'), findsOneWidget);

      // 3. Academic Credentials
      expect(find.text('ACADEMIC CREDENTIALS'), findsOneWidget);
      expect(find.text('Computer Science'), findsOneWidget);
      expect(find.text('4th Year'), findsOneWidget);
      expect(find.text('B.Tech'), findsOneWidget);

      // 4. Device Binding & Security
      expect(find.text('DEVICE & SECURITY'), findsOneWidget);
      expect(find.text('Device Bound'), findsOneWidget);
      expect(find.text('ID ••••7766'), findsOneWidget);
      expect(find.text('Verified'), findsOneWidget);

      // 5. Quick Actions & Settings tile
      expect(find.text('Settings'), findsOneWidget);
      expect(find.text('My Requests'), findsOneWidget);
      expect(find.text('Logout'), findsOneWidget);
    });
  });

  group('Settings Screen Preference Tests', () {
    testWidgets('SettingsScreen displays Appearance, Interaction, Performance, and Language', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        MaterialApp(
          home: SettingsScreen(
            user: testUser,
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Verify sections
      expect(find.text('APPEARANCE'), findsOneWidget);
      expect(find.text('INTERACTION'), findsOneWidget);
      expect(find.text('PERFORMANCE'), findsOneWidget);
      expect(find.text('LANGUAGE'), findsOneWidget);
      expect(find.text('ABOUT'), findsOneWidget);

      // Verify Theme chips
      expect(find.text('Light'), findsOneWidget);
      expect(find.text('Dark'), findsOneWidget);
      expect(find.text('System'), findsOneWidget);

      // Verify Switches for Haptic & Reduce Motion
      expect(find.text('Haptic Feedback'), findsOneWidget);
      expect(find.text('Reduce Motion'), findsOneWidget);

      // Verify Logout in Settings
      expect(find.text('Logout'), findsOneWidget);
    });

    testWidgets('Tapping Dark theme chip sets ThemeMode.dark', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        MaterialApp(
          home: SettingsScreen(
            user: testUser,
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      await tester.tap(find.text('Dark'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(ThemeProvider.instance.themeMode, equals(ThemeMode.dark));
    });
  });
}
