import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_ble_peripheral/flutter_ble_peripheral.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:attendance_app/auth/models/user_model.dart';
import 'package:attendance_app/auth/providers/user_provider.dart';
import 'package:attendance_app/core/network/api_client.dart';
import 'package:attendance_app/router/app_routes.dart';
import 'package:attendance_app/shared/models/session_model.dart';
import 'package:attendance_app/teacher/screens/broadcasting_screen.dart';
import 'package:attendance_app/teacher/services/passport_teacher_attendance_service.dart';

import 'package:attendance_app/shared/services/session_service.dart';

class _FakeHttpClient extends http.BaseClient {
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    return http.StreamedResponse(
      Stream.value(utf8.encode('{"status":"ok"}')),
      200,
    );
  }
}

class _MockSessionService extends SessionService {
  bool stopSessionCalled = false;

  @override
  Future<bool> stopSession(String sessionId) async {
    stopSessionCalled = true;
    return true;
  }
}

class _TestTeacherService extends PassportTeacherAttendanceService {
  final StreamController<TeacherAttendanceMetrics> _metricsCtrl =
      StreamController<TeacherAttendanceMetrics>.broadcast();

  String? fakeAdvertisingError;
  bool stopSessionCalled = false;

  _TestTeacherService({
    FlutterBlePeripheral? blePeripheral,
    this.fakeAdvertisingError,
  }) : super(blePeripheral: blePeripheral);

  @override
  Stream<TeacherAttendanceMetrics> get metricsStream => _metricsCtrl.stream;

  @override
  String? get advertisingError => fakeAdvertisingError;

  @override
  bool get isAdvertisingSupported => true;

  @override
  bool get isBroadcasting => false;

  @override
  Future<void> stopSession() async {
    stopSessionCalled = true;
    await super.stopSession();
  }

  @override
  void dispose() {
    _metricsCtrl.close();
    super.dispose();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final testTeacher = UserModel(
    id: 't_prof_sourav',
    email: 'sourav.faculty@campusos.edu',
    name: 'Prof. Sourav Nanda',
    role: 'teacher',
    course: 'B.Tech',
    branch: 'CSE',
    year: '3rd',
    registrationNumber: 'FAC-2024-042',
    deviceId: 'DEV-HW-101',
  );

  SessionModel makeSession() {
    return SessionModel(
      id: 'sess_distributed_systems_304',
      name: 'Distributed Systems',
      course: 'B.Tech',
      branch: 'CSE',
      year: '3rd',
      startTime: DateTime.now().subtract(const Duration(seconds: 32)),
      endTime: DateTime.now().add(const Duration(minutes: 50)),
      location: 'Room 204',
      instructorName: 'Prof. Sourav Nanda',
      isActive: true,
      txPowerLevel: 1,
    );
  }

  const channel = MethodChannel('dev.steenbakker.flutter_ble_peripheral/ble_state');

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    ApiClient.instance = ApiClient(
      client: _FakeHttpClient(),
      defaultTimeout: const Duration(milliseconds: 50),
    );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
      if (methodCall.method == 'stop' || methodCall.method == 'start') {
        throw PlatformException(
          code: 'error',
          message: null,
          details: null,
          stacktrace: 'java.lang.NullPointerException\n\tat Y3.c.onMethodCall(SourceFile:1593)',
        );
      }
      if (methodCall.method == 'isSupported') {
        return true;
      }
      if (methodCall.method == 'isAdvertising') {
        return false;
      }
      return null;
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  group('Teacher BLE Permission Denial & End Session Stabilization Tests', () {
    test('1. PassportTeacherAttendanceService.stopSession() succeeds cleanly even if BLE peripheral throws NPE',
        () async {
      final service = PassportTeacherAttendanceService();

      // Must complete without throwing unhandled PlatformException
      await expectLater(service.stopSession(), completes);
    });

    testWidgets('2. BroadcastingScreen ending session navigates cleanly to post-session report when BLE stop throws NPE',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final testService = _TestTeacherService(
        fakeAdvertisingError: 'Bluetooth permissions denied. Enable Nearby Devices in Settings.',
      );
      addTearDown(testService.dispose);

      bool navigatedToReport = false;

      final userProvider = UserProvider()..setUser(testTeacher);

      final mockSessionService = _MockSessionService();

      await tester.pumpWidget(
        ChangeNotifierProvider<UserProvider>.value(
          value: userProvider,
          child: MaterialApp(
            routes: {
              AppRoutes.teacherPostSessionReport: (ctx) {
                navigatedToReport = true;
                return const Scaffold(body: Text('POST_SESSION_REPORT_SCREEN'));
              },
            },
            home: MediaQuery(
              data: const MediaQueryData(
                size: Size(390, 844),
                padding: EdgeInsets.only(top: 44, bottom: 34),
                disableAnimations: true,
              ),
              child: BroadcastingScreen(
                user: testTeacher,
                session: makeSession(),
                teacherServiceOverride: testService,
                sessionServiceOverride: mockSessionService,
                autoStartServices: false,
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Verify the friendly BLE Notice is displayed without raw Java stack traces
      expect(find.text('BLE Notice'), findsOneWidget);
      expect(find.text('Bluetooth permissions denied. Enable Nearby Devices in Settings.'), findsOneWidget);
      expect(find.textContaining('java.lang.NullPointerException'), findsNothing);

      // Tap End Session button
      await tester.ensureVisible(find.text('End session'));
      await tester.tap(find.text('End session'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      // Dialog appears
      expect(find.text('End Attendance Session?'), findsOneWidget);

      // Confirm ending session
      final endBtn = find.widgetWithText(ElevatedButton, 'End Session');
      expect(endBtn, findsOneWidget);
      await tester.tap(endBtn);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text('End Attendance Session?'), findsNothing);

      // Verify service was told to stop
      expect(testService.stopSessionCalled, isTrue);

      // Verify user was NOT blocked by snackbar and navigated to report screen
      expect(navigatedToReport, isTrue);
      expect(find.text('POST_SESSION_REPORT_SCREEN'), findsOneWidget);
      expect(find.textContaining('Failed to stop session'), findsNothing);
    });
  });
}
