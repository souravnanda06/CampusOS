import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';

import 'package:attendance_app/auth/models/user_model.dart';
import 'package:attendance_app/auth/services/auth_service.dart';
import 'package:attendance_app/auth/screens/login_screen.dart';
import 'package:attendance_app/auth/screens/student_registration_screen.dart';
import 'package:attendance_app/screens/home_screen.dart';
import 'package:attendance_app/auth/providers/user_provider.dart';
import 'package:attendance_app/student/screens/student_shell_screen.dart';
import 'package:attendance_app/teacher/screens/teacher_shell_screen.dart';
import 'package:attendance_app/admin/screens/admin_shell_screen.dart';
import 'package:attendance_app/router/app_routes.dart';

class MockAuthService extends AuthService {
  UserModel? mockUser;
  bool shouldFail = false;
  String failureMessage = 'Invalid credentials';
  Completer<UserModel?>? pendingSignIn;

  String? lastRegisteredRole;
  Map<String, dynamic>? lastRegisteredPayload;

  @override
  UserModel? get currentUser => mockUser;

  @override
  Future<UserModel?> signIn({
    required String email,
    required String password,
    String? deviceId,
  }) async {
    if (pendingSignIn != null) {
      return pendingSignIn!.future;
    }
    if (shouldFail) {
      throw failureMessage;
    }
    return mockUser;
  }

  @override
  Future<UserModel?> signUp({
    required String email,
    required String password,
    required String name,
    required String role,
    String? registrationNumber,
    String? course,
    String? branch,
    String? year,
    String? deviceId,
  }) async {
    lastRegisteredRole = role;
    lastRegisteredPayload = {
      'email': email,
      'password': password,
      'name': name,
      'role': role,
      'registrationNumber': registrationNumber,
      'course': course,
      'branch': branch,
      'year': year,
      'deviceId': deviceId,
    };

    if (shouldFail) {
      throw failureMessage;
    }
    return mockUser;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final testStudent = UserModel(
    id: 'student_123',
    email: 'student@campus.edu',
    name: 'Alice Student',
    role: 'student',
    registrationNumber: '21BCSE001',
    course: 'B.Tech',
    branch: 'CSE',
    year: '3rd',
  );

  Widget createTestWidget(Widget child, {Map<String, WidgetBuilder>? routes}) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => UserProvider()),
      ],
      child: MaterialApp(
        routes: routes ??
            {
              AppRoutes.home: (_) => const Scaffold(body: Text('Home Destination')),
              AppRoutes.register: (_) => const Scaffold(body: Text('Register Destination')),
              AppRoutes.login: (_) => const Scaffold(body: Text('Login Destination')),
            },
        home: child,
      ),
    );
  }

  group('CampusOS Authentication & Onboarding Suite', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
      AuthService.setCurrentUserForTesting(null);
    });

    testWidgets('1. LoginScreen renders correctly with Apple UI elements and provisioned notice', (tester) async {
      await tester.pumpWidget(createTestWidget(const LoginScreen()));
      await tester.pumpAndSettle();

      expect(find.text('CampusOS'), findsOneWidget);
      expect(find.text('Welcome Back'), findsOneWidget);
      expect(find.text('Sign in with your campus credentials to continue'), findsOneWidget);
      expect(find.text('Institutional Email or ID'), findsOneWidget);
      expect(find.text('Password'), findsOneWidget);
      expect(find.text('Sign In'), findsOneWidget);
      expect(find.text('Forgot password?'), findsOneWidget);
      expect(find.text('Create student account'), findsOneWidget);
      expect(find.textContaining('Staff & Admin accounts are provisioned institutionally'), findsOneWidget);
    });

    testWidgets('2. Password visibility toggle alternates obscureText', (tester) async {
      await tester.pumpWidget(createTestWidget(const LoginScreen()));
      await tester.pumpAndSettle();

      TextField getPasswordField() => tester.widget<TextField>(find.byType(TextField).at(1));

      expect(getPasswordField().obscureText, isTrue);

      final toggleButton = find.byIcon(Icons.visibility_outlined);
      expect(toggleButton, findsOneWidget);

      await tester.tap(toggleButton);
      await tester.pumpAndSettle();

      expect(getPasswordField().obscureText, isFalse);
      expect(find.byIcon(Icons.visibility_off_outlined), findsOneWidget);
    });

    testWidgets('3. Empty-field validation flags missing credentials', (tester) async {
      await tester.pumpWidget(createTestWidget(const LoginScreen()));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Sign In'));
      await tester.pumpAndSettle();

      expect(find.text('Email or ID is required'), findsOneWidget);
      expect(find.text('Password is required'), findsOneWidget);
    });

    testWidgets('4. Invalid credentials triggers error feedback', (tester) async {
      final mockAuth = MockAuthService()
        ..shouldFail = true
        ..failureMessage = 'Invalid credentials. Please verify your email and password.';

      await tester.pumpWidget(createTestWidget(LoginScreen(authService: mockAuth)));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextFormField).at(0), 'unknown@campus.edu');
      await tester.enterText(find.byType(TextFormField).at(1), 'wrongpass');
      await tester.tap(find.text('Sign In'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Invalid credentials'), findsOneWidget);
    });

    testWidgets('5. Loading state disables submit and displays spinner', (tester) async {
      final completer = Completer<UserModel?>();
      final mockAuth = MockAuthService()..pendingSignIn = completer;

      await tester.pumpWidget(createTestWidget(LoginScreen(authService: mockAuth)));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextFormField).at(0), 'student@campus.edu');
      await tester.enterText(find.byType(TextFormField).at(1), 'password123');
      await tester.tap(find.text('Sign In'));
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      completer.complete(testStudent);
      await tester.pumpAndSettle();
    });

    testWidgets('6. Student registration screen renders all fields without role selection', (tester) async {
      tester.view.physicalSize = const Size(1200, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(createTestWidget(const StudentRegistrationScreen()));
      await tester.pumpAndSettle();

      expect(find.text('Student Registration'), findsOneWidget);
      expect(find.text('Full Name'), findsOneWidget);
      expect(find.text('Registration / Roll Number'), findsOneWidget);
      expect(find.text('Course'), findsOneWidget);
      expect(find.text('Year'), findsOneWidget);
      expect(find.text('Branch / Department'), findsOneWidget);
      expect(find.text('Institutional Email'), findsOneWidget);
      expect(find.text('Password'), findsOneWidget);
      expect(find.text('Confirm Password'), findsOneWidget);
      expect(find.text('Create Account'), findsOneWidget);

      // Verify that there is NO role dropdown or admin privilege selector
      expect(find.text('Admin'), findsNothing);
      expect(find.text('Teacher'), findsNothing);
      expect(find.text('Role'), findsNothing);
    });

    testWidgets('7. Student registration validation enforces mandatory fields and matching passwords', (tester) async {
      tester.view.physicalSize = const Size(1200, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(createTestWidget(const StudentRegistrationScreen()));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Create Account'));
      await tester.pumpAndSettle();

      expect(find.text('Name is required'), findsOneWidget);
      expect(find.text('Registration number is required'), findsOneWidget);
      expect(find.text('Email is required'), findsOneWidget);
      expect(find.text('Password is required'), findsOneWidget);

      // Test password mismatch
      await tester.enterText(find.byType(TextFormField).at(0), 'Bob Test');
      await tester.enterText(find.byType(TextFormField).at(1), '21BCSE099');
      await tester.enterText(find.byType(TextFormField).at(2), 'bob@campus.edu');
      await tester.enterText(find.byType(TextFormField).at(3), 'secret123');
      await tester.enterText(find.byType(TextFormField).at(4), 'differentpass');

      await tester.tap(find.text('Create Account'));
      await tester.pumpAndSettle();

      expect(find.text('Passwords do not match'), findsOneWidget);
    });

    testWidgets('8. Successful authentication routes to Home Destination', (tester) async {
      final mockAuth = MockAuthService()..mockUser = testStudent;

      await tester.pumpWidget(createTestWidget(LoginScreen(authService: mockAuth)));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextFormField).at(0), 'student@campus.edu');
      await tester.enterText(find.byType(TextFormField).at(1), 'password123');
      await tester.tap(find.text('Sign In'));
      await tester.pumpAndSettle();

      expect(find.text('Home Destination'), findsOneWidget);
    });

    testWidgets('9. Student routing renders StudentShellScreen', (tester) async {
      SharedPreferences.setMockInitialValues({
        'auth_token': 'test-token',
        'user_data': jsonEncode({
          'id': 's1',
          'email': 'student@campus.edu',
          'name': 'Student Alice',
          'role': 'student',
          'registrationNumber': '21B001',
          'course': 'B.Tech',
          'branch': 'CSE',
          'year': '2nd',
        }),
      });

      await tester.pumpWidget(createTestWidget(const HomeScreen()));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byType(StudentShellScreen), findsOneWidget);
    });

    testWidgets('10. Teacher routing renders TeacherShellScreen', (tester) async {
      SharedPreferences.setMockInitialValues({
        'auth_token': 'test-token',
        'user_data': jsonEncode({
          'id': 't1',
          'email': 'teacher@campus.edu',
          'name': 'Prof. John',
          'role': 'teacher',
          'branch': 'CSE',
        }),
      });

      await tester.pumpWidget(createTestWidget(const HomeScreen()));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byType(TeacherShellScreen), findsOneWidget);
    });

    testWidgets('11. Admin routing renders AdminShellScreen', (tester) async {
      SharedPreferences.setMockInitialValues({
        'auth_token': 'test-token',
        'user_data': jsonEncode({
          'id': 'a1',
          'email': 'admin@campus.edu',
          'name': 'Dr. Robert',
          'role': 'admin',
          'branch': 'Administration',
        }),
      });

      await tester.pumpWidget(createTestWidget(const HomeScreen()));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byType(AdminShellScreen), findsOneWidget);
    });

    testWidgets('12. Logout clears auth session and resets currentUser', (tester) async {
      SharedPreferences.setMockInitialValues({
        'auth_token': 'valid-auth-token',
        'user_data': jsonEncode({
          'id': 'u1',
          'email': 'u1@test.com',
          'name': 'User 1',
          'role': 'student',
        }),
        'current_hosting_session_id': 'session_abc',
      });

      final auth = AuthService();
      final user = await auth.getUserDataFromStorage();
      expect(user, isNotNull);

      await AuthService.signOut();

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('auth_token'), isNull);
      expect(prefs.getString('user_data'), isNull);
      expect(prefs.getString('current_hosting_session_id'), isNull);
      expect(auth.currentUser, isNull);
    });

    testWidgets('13. Session restoration validates valid token and user data', (tester) async {
      SharedPreferences.setMockInitialValues({
        'auth_token': 'valid-token-123',
        'user_data': jsonEncode({
          'id': 'restored_user',
          'email': 'restored@test.com',
          'name': 'Restored User',
          'role': 'student',
        }),
      });

      final auth = AuthService();
      final isRestored = await auth.tryAutoLogin();

      expect(isRestored, isTrue);
      expect(auth.currentUser?.name, 'Restored User');
    });

    testWidgets('14. Invalid or corrupted session safely purges auth tokens and returns false', (tester) async {
      AuthService.setCurrentUserForTesting(null);
      SharedPreferences.setMockInitialValues({
        'auth_token': 'token-with-corrupted-user',
        'user_data': '{corrupted-json-data}',
      });

      final auth = AuthService();
      final canLogin = await auth.tryAutoLogin();

      expect(canLogin, isFalse);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('auth_token'), isNull);
      expect(prefs.getString('user_data'), isNull);
    });

    testWidgets('15. Admin role cannot be publicly registered (strictly pinned to student)', (tester) async {
      tester.view.physicalSize = const Size(1200, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final mockAuth = MockAuthService()..mockUser = testStudent;

      await tester.pumpWidget(createTestWidget(StudentRegistrationScreen(authService: mockAuth)));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextFormField).at(0), 'Charlie Student');
      await tester.enterText(find.byType(TextFormField).at(1), '21BCSE055');
      await tester.enterText(find.byType(TextFormField).at(2), 'charlie@campus.edu');
      await tester.enterText(find.byType(TextFormField).at(3), 'secret123');
      await tester.enterText(find.byType(TextFormField).at(4), 'secret123');

      await tester.tap(find.text('Create Account'));
      await tester.pumpAndSettle();

      // Ensure the registered role passed to backend is strictly 'student'
      expect(mockAuth.lastRegisteredRole, equals('student'));
      expect(mockAuth.lastRegisteredRole, isNot(equals('admin')));
      expect(mockAuth.lastRegisteredRole, isNot(equals('teacher')));
    });

    testWidgets('16. Passport and device attendance queue survive normal logout', (tester) async {
      SharedPreferences.setMockInitialValues({
        'auth_token': 'auth_token_to_remove',
        'user_data': jsonEncode({'id': 'u1', 'email': 'u1@test.com', 'name': 'U1', 'role': 'student'}),
        'passport_queue_session_777': ['ledger_record_entry_1', 'ledger_record_entry_2'],
        'app_dark_mode_preference': 'true',
      });

      await AuthService.signOut();

      final prefs = await SharedPreferences.getInstance();
      // Auth session is removed
      expect(prefs.getString('auth_token'), isNull);
      expect(prefs.getString('user_data'), isNull);

      // Non-auth preferences and local offline attendance queues remain intact
      expect(prefs.getStringList('passport_queue_session_777'), isNotNull);
      expect(prefs.getStringList('passport_queue_session_777')!.length, equals(2));
      expect(prefs.getString('app_dark_mode_preference'), equals('true'));
    });
  });
}
