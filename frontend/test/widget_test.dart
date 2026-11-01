import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:attendance_app/main.dart';
import 'package:attendance_app/auth/providers/user_provider.dart';
import 'package:attendance_app/shared/providers/attendance_provider.dart';
import 'package:firebase_core_platform_interface/firebase_core_platform_interface.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    // Mock SharedPreferences
    SharedPreferences.setMockInitialValues({});

    // Mock Firebase Platform
    FirebasePlatform.instance = MockFirebasePlatform();
    await Firebase.initializeApp();
  });

  testWidgets('App smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => UserProvider()..loadUser()),
          ChangeNotifierProvider(create: (_) => AttendanceProvider()),
        ],
        child: const MyApp(),
      ),
    );

    // Verify that splash screen or app title appears
    expect(find.byType(MaterialApp), findsOneWidget);

    // Handle SplashScreen timers
    await tester.pump(const Duration(milliseconds: 400)); // Tagline
    await tester.pump(const Duration(milliseconds: 400)); // Loader
    await tester.pump(const Duration(milliseconds: 2000)); // Auth check delay

    // Trigger navigation
    await tester.pump();

    // Wait for transition to PremiumOnboardingScreen
    await tester.pump(const Duration(milliseconds: 1000));

    // Verify we are on the login screen
    expect(find.text('Welcome Back'), findsOneWidget);
  });
}

class MockFirebasePlatform extends FirebasePlatform {
  @override
  FirebaseAppPlatform app([String name = defaultFirebaseAppName]) {
    return FirebaseAppPlatform(
      name,
      const FirebaseOptions(
        apiKey: 'test',
        appId: 'test',
        messagingSenderId: 'test',
        projectId: 'test',
      ),
    );
  }

  @override
  Future<FirebaseAppPlatform> initializeApp({
    String? name,
    FirebaseOptions? options,
  }) async {
    return FirebaseAppPlatform(
      name ?? defaultFirebaseAppName,
      options ??
          const FirebaseOptions(
            apiKey: 'test',
            appId: 'test',
            messagingSenderId: 'test',
            projectId: 'test',
          ),
    );
  }
}
