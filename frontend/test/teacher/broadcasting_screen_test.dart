import 'dart:async';
import 'dart:convert';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';

import 'package:attendance_app/auth/models/user_model.dart';
import 'package:attendance_app/auth/providers/user_provider.dart';
import 'package:attendance_app/core/network/connectivity_service.dart';
import 'package:attendance_app/student/models/passport_attendance_model.dart';
import 'package:attendance_app/student/models/passport_proximity_observation.dart';
import 'package:attendance_app/teacher/screens/broadcasting_screen.dart';
import 'package:attendance_app/teacher/services/passport_teacher_attendance_service.dart';
import 'package:attendance_app/shared/models/session_model.dart';

class _FakeConnectivity implements Connectivity {
  List<ConnectivityResult> _current;
  final StreamController<List<ConnectivityResult>> _controller =
      StreamController<List<ConnectivityResult>>.broadcast();

  _FakeConnectivity(this._current);

  void emit(List<ConnectivityResult> results) {
    _current = results;
    _controller.add(results);
  }

  @override
  Future<List<ConnectivityResult>> checkConnectivity() async => _current;

  @override
  Stream<List<ConnectivityResult>> get onConnectivityChanged =>
      _controller.stream;

  void dispose() => _controller.close();
}

class _FakeHttpClient extends http.BaseClient {
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    return http.StreamedResponse(
      Stream.value(utf8.encode('{"status":"ok"}')),
      200,
    );
  }
}

class _FakeTeacherService extends PassportTeacherAttendanceService {
  final StreamController<TeacherAttendanceMetrics> _metricsCtrl =
      StreamController<TeacherAttendanceMetrics>.broadcast();

  PassportTeacherBeaconModel? fakeBeacon;
  String? fakeAdvertisingError;
  bool fakeAdvertisingSupported = true;
  bool fakeBroadcasting = true;
  bool fakeHotspotActive = false;
  int fakeHotspotRemaining = 0;
  String? fakeHotspotSsid;
  String? fakeHotspotPassword;
  bool fakeLanDetected = true;
  String? fakeLanIp = '192.168.1.42';
  String fakePin = '9076';
  int fakePinRemaining = 12;
  double fakePinProgress = 0.8;

  int pauseCalls = 0;
  int resumeCalls = 0;
  int retryCalls = 0;
  int startHotspotCalls = 0;
  int stopHotspotCalls = 0;

  _FakeTeacherService({
    this.fakeBeacon,
    this.fakeAdvertisingError,
  });

  void emitMetrics(TeacherAttendanceMetrics metrics) {
    _metricsCtrl.add(metrics);
  }

  @override
  Stream<TeacherAttendanceMetrics> get metricsStream => _metricsCtrl.stream;

  @override
  PassportTeacherBeaconModel? get activeBeacon => fakeBeacon;

  @override
  String? get advertisingError => fakeAdvertisingError;

  @override
  bool get isAdvertisingSupported => fakeAdvertisingSupported;

  @override
  bool get isBroadcasting => fakeBroadcasting;

  @override
  String get currentRollingPin => fakePin;

  @override
  int get rollingPinRemainingSeconds => fakePinRemaining;

  @override
  double get rollingPinProgress => fakePinProgress;

  @override
  bool get isHotspotActive => fakeHotspotActive;

  @override
  int get hotspotRemainingSeconds => fakeHotspotRemaining;

  @override
  String? get hotspotSsid => fakeHotspotSsid;

  @override
  String? get hotspotPassword => fakeHotspotPassword;

  @override
  bool get isLanWifiDetected => fakeLanDetected;

  @override
  String? get lanWifiIp => fakeLanIp;

  @override
  Future<void> pauseBeaconAdvertising() async {
    pauseCalls++;
    fakeBroadcasting = false;
  }

  @override
  Future<void> resumeBeaconAdvertising() async {
    resumeCalls++;
    fakeBroadcasting = true;
  }

  @override
  Future<void> retryBeaconAdvertising() async {
    retryCalls++;
    fakeAdvertisingError = null;
    fakeBroadcasting = true;
  }

  @override
  Future<void> startHotspotBurst({bool tryNativeFirst = true}) async {
    startHotspotCalls++;
    fakeHotspotActive = true;
    fakeHotspotRemaining = 60;
    fakeHotspotSsid = 'CampusOS_Room204';
    fakeHotspotPassword = 'pass123456';
  }

  @override
  void stopHotspotBurst() {
    stopHotspotCalls++;
    fakeHotspotActive = false;
    fakeHotspotRemaining = 0;
  }

  @override
  void dispose() {
    _metricsCtrl.close();
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

  SessionModel makeSession({
    String name = 'Data Structures',
    String location = 'Room 204',
    int txPowerLevel = 2,
  }) {
    return SessionModel(
      id: 'sess_test_101',
      name: name,
      instructorName: 'Prof. Sourav Nanda',
      course: 'B.Tech',
      branch: 'CSE',
      year: '3rd',
      startTime: DateTime.now().subtract(const Duration(seconds: 7)),
      endTime: DateTime.now().add(const Duration(minutes: 55)),
      location: location,
      isActive: true,
      txPowerLevel: txPowerLevel,
    );
  }

  PassportTeacherBeaconModel makeBeacon() {
    return PassportTeacherBeaconModel.create(
      sessionId: 'sess_test_101',
      teacherId: 't_prof_sourav',
      teacherKeyId: 'teacher_key_1',
      subject: 'Data Structures',
      localIp: '192.168.1.42',
    );
  }

  late _FakeConnectivity fakeConnectivity;

  setUp(() async {
    fakeConnectivity = _FakeConnectivity([ConnectivityResult.wifi]);
    ConnectivityService.initialize(
      connectivity: fakeConnectivity,
      httpClient: _FakeHttpClient(),
      minProbeInterval: Duration.zero,
    );
    await Future<void>.delayed(const Duration(milliseconds: 20));
    await ConnectivityService.instance.checkReachability(force: true);
  });

  tearDown(() {
    ConnectivityService.reset();
    fakeConnectivity.dispose();
  });

  Widget wrapScreen({
    required _FakeTeacherService service,
    SessionModel? session,
    Size surfaceSize = const Size(390, 844),
    double textScale = 1.0,
    bool disableAnimations = false,
  }) {
    return ChangeNotifierProvider<UserProvider>(
      create: (_) {
        final p = UserProvider();
        p.setUser(testTeacher);
        return p;
      },
      child: MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(
            size: surfaceSize,
            padding: const EdgeInsets.only(top: 44, bottom: 34),
            textScaler: TextScaler.linear(textScale),
            disableAnimations: disableAnimations,
          ),
          child: BroadcastingScreen(
            user: testTeacher,
            session: session ?? makeSession(),
            teacherServiceOverride: service,
            autoStartServices: false,
          ),
        ),
      ),
    );
  }

  group('BroadcastingScreen Redesign', () {
    testWidgets('1. Renders live mode layout, binds data, and hides BLE notice when no error',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final service = _FakeTeacherService(fakeBeacon: makeBeacon());
      addTearDown(service.dispose);

      await tester.pumpWidget(wrapScreen(service: service));
      await tester.pump(const Duration(milliseconds: 1100));

      // Header
      expect(find.text('Data Structures'), findsOneWidget);
      expect(find.text('ROOM 204'), findsOneWidget);

      // Orb
      expect(find.text('0'), findsWidgets);
      expect(find.text('/ 45'), findsOneWidget);
      expect(find.text('students detected'), findsOneWidget);

      // Status
      expect(find.text('Scanning for passports'), findsOneWidget);
      expect(find.text('Online · Synced'), findsOneWidget);
      expect(find.text('High · Lecture Hall'), findsOneWidget);
      expect(find.text('QR Challenge'), findsOneWidget);

      // BLE Notice hidden when error is null
      expect(find.text('BLE Notice'), findsNothing);

      // Check-in methods
      expect(find.text('ZERO-BLE & SUB-NET SYNC'), findsOneWidget);
      expect(find.text('LAN active'), findsOneWidget);
      expect(find.text('ROOM PIN'), findsOneWidget);
      expect(find.text('9076'), findsOneWidget);
      expect(find.text('Rotates in 12s'), findsOneWidget);
      expect(find.text('OPTICAL QR'), findsOneWidget);
      expect(find.text('10s'), findsOneWidget);
      expect(find.text('Loop'), findsOneWidget);
      expect(find.text('Tap for screen'), findsOneWidget);
      expect(find.text('HOTSPOT'), findsOneWidget);
      expect(find.text('60s'), findsOneWidget);
      expect(find.text('Burst'), findsOneWidget);
      expect(find.text('Tap to Start'), findsOneWidget);

      // Attendees row & controls
      expect(find.text('Verified Attendees'), findsOneWidget);
      expect(find.text('BLE Radio Active'), findsOneWidget);
      expect(find.text('Scan QR'), findsOneWidget);
      expect(find.text('QR code'), findsOneWidget);
      expect(find.text('Pause'), findsOneWidget);
      expect(find.text('End session'), findsOneWidget);
    });

    testWidgets('2. Shows BLE Notice on error and wires Retry button',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      const bleErr =
          'PlatformException(error, null, null, java.lang.NullPointerException)';
      final service = _FakeTeacherService(
        fakeBeacon: makeBeacon(),
        fakeAdvertisingError: bleErr,
      );
      addTearDown(service.dispose);

      await tester.pumpWidget(wrapScreen(service: service));
      await tester.pump(const Duration(milliseconds: 1100));

      expect(find.text('BLE Notice'), findsOneWidget);
      expect(find.text(bleErr), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);

      await tester.tap(find.text('Retry'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));

      expect(service.retryCalls, 1);
      expect(find.text('BLE Notice'), findsNothing);
    });

    testWidgets('3. Pause/Resume swaps control state and respects reduced motion',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final service = _FakeTeacherService(fakeBeacon: makeBeacon());
      addTearDown(service.dispose);

      await tester.pumpWidget(
        wrapScreen(service: service, disableAnimations: true),
      );
      await tester.pump();

      expect(find.text('Pause'), findsOneWidget);
      await tester.tap(find.text('Pause'));
      await tester.pump();

      expect(service.pauseCalls, 1);
      expect(find.text('Resume'), findsOneWidget);
      expect(find.text('Paused'), findsOneWidget);
      expect(find.text('BLE Radio Paused'), findsOneWidget);

      await tester.tap(find.text('Resume'));
      await tester.pump();

      expect(service.resumeCalls, 1);
      expect(find.text('Pause'), findsOneWidget);
      expect(find.text('Scanning for passports'), findsOneWidget);
    });

    testWidgets('4. Reflects Offline state cleanly', (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final offlineConnectivity = _FakeConnectivity([ConnectivityResult.none]);
      addTearDown(offlineConnectivity.dispose);
      ConnectivityService.initialize(
        connectivity: offlineConnectivity,
        httpClient: _FakeHttpClient(),
        minProbeInterval: Duration.zero,
      );
      await ConnectivityService.instance.checkReachability(force: true);
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));

      final service = _FakeTeacherService(fakeBeacon: makeBeacon());
      addTearDown(service.dispose);

      await tester.pumpWidget(wrapScreen(service: service));
      await tester.pump(const Duration(milliseconds: 1100));

      expect(ConnectivityService.instance.hasNetworkInterface, isFalse);
      expect(find.text('Offline · Saved locally'), findsOneWidget);
      expect(find.text('Verifying Locally (Offline)'), findsOneWidget);
    });

    testWidgets('5. Opens Verified Attendees sheet for empty and populated states',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final service = _FakeTeacherService(fakeBeacon: makeBeacon());
      addTearDown(service.dispose);

      await tester.pumpWidget(wrapScreen(service: service));
      await tester.pump(const Duration(milliseconds: 1100));

      // Tap Verified Attendees -> empty state
      await tester.tap(find.text('Verified Attendees'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text('No students verified yet'), findsOneWidget);

      // Close sheet
      await tester.tap(find.bySemanticsLabel('Close attendees list'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      // Emit verified & inconclusive students
      service.emitMetrics(
        TeacherAttendanceMetrics(
          verifiedCount: 2,
          inconclusiveCount: 1,
          totalRoster: 3,
          verifiedStudents: [
            PassportAttendanceVerificationResult(
              valid: true,
              status: PassportAttendanceStatus.verifiedPresent,
              reason: 'OK',
              studentId: 's1',
              studentName: 'Ananya Das',
              proximityTier: PassportProximityTier.near,
              medianRssi: -48,
              verificationMode: PassportAttendanceModel.modeBle,
              verifiedAt: DateTime(2026, 11, 12, 10, 5, 1),
            ),
            PassportAttendanceVerificationResult(
              valid: true,
              status: PassportAttendanceStatus.verifiedPresent,
              reason: 'OK',
              studentId: 's2',
              studentName: 'Deepak Roy',
              proximityTier: PassportProximityTier.near,
              verificationMode: PassportAttendanceModel.modeWifiLan,
              verifiedAt: DateTime(2026, 11, 12, 10, 5, 12),
            ),
          ],
          inconclusiveStudents: [
            PassportAttendanceVerificationResult(
              valid: false,
              status: PassportAttendanceStatus.proximityInconclusive,
              reason: 'Far',
              studentId: 's3',
              studentName: 'Rohan Sharma',
              proximityTier: PassportProximityTier.far,
              medianRssi: -88,
              verificationMode: PassportAttendanceModel.modeBle,
              verifiedAt: DateTime(2026, 11, 12, 10, 5, 20),
            ),
          ],
        ),
      );
      await tester.pump();

      expect(find.bySemanticsLabel('2 of 3 students detected'), findsOneWidget);
      expect(find.text('/ 3'), findsOneWidget);

      // Swipe up on Verified Attendees row to open sheet
      await tester.fling(
        find.text('Verified Attendees'),
        const Offset(0, -250),
        900,
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.text('Verified Attendees (2)'), findsOneWidget);
      expect(find.text('Ananya Das'), findsOneWidget);
      expect(find.text('Deepak Roy'), findsOneWidget);
      expect(find.text('Wi-Fi LAN'), findsOneWidget);
      expect(find.text('EXCEPTION QUEUE (1)'), findsOneWidget);
      expect(find.text('Rohan Sharma'), findsOneWidget);
      expect(find.text('Resolve'), findsOneWidget);
    });

    testWidgets('6. Check-in method tiles open PIN dialog, Optical QR sheet, and Hotspot sheet',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final service = _FakeTeacherService(fakeBeacon: makeBeacon());
      addTearDown(service.dispose);

      await tester.pumpWidget(wrapScreen(service: service));
      await tester.pump(const Duration(milliseconds: 1100));

      // Room PIN tap
      await tester.tap(find.text('ROOM PIN'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text('CLASSROOM ROLLING PIN'), findsOneWidget);
      Navigator.of(tester.element(find.text('CLASSROOM ROLLING PIN'))).pop();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      // Optical QR tap
      await tester.tap(find.text('OPTICAL QR'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text('Dynamic Optical QR'), findsOneWidget);
      await tester.tap(find.bySemanticsLabel('Close optical QR sheet'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      // Hotspot tap
      await tester.tap(find.text('HOTSPOT'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(service.startHotspotCalls, 1);
      expect(find.text('PHONE HOTSPOT IS OFF'), findsOneWidget);
      expect(find.text('Hotspot burst'), findsOneWidget);

      await tester.tap(find.text('Stop Hotspot Burst'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(service.stopHotspotCalls, 1);
      expect(find.text('Tap to Start'), findsOneWidget);
    });

    testWidgets('7. End session and Back button show confirmation dialog',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final service = _FakeTeacherService(fakeBeacon: makeBeacon());
      addTearDown(service.dispose);

      await tester.pumpWidget(wrapScreen(service: service));
      await tester.pump(const Duration(milliseconds: 1100));

      await tester.tap(find.text('End session'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text('End Attendance Session?'), findsOneWidget);

      await tester.tap(find.text('Continue Session'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text('End Attendance Session?'), findsNothing);

      await tester.tap(find.bySemanticsLabel('Back and end session'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text('End Attendance Session?'), findsOneWidget);
    });

    testWidgets('8. Survives 360px small screen, 1.3x font scale, long course name, and BLE error without overflow',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(360, 640));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final service = _FakeTeacherService(
        fakeBeacon: makeBeacon(),
        fakeAdvertisingError:
            'PlatformException(error, null, null, java.lang.NullPointerException)',
      );
      addTearDown(service.dispose);

      await tester.pumpWidget(
        wrapScreen(
          service: service,
          session: makeSession(
            name: 'Advanced Distributed Systems and Cloud Infrastructure Engineering',
          ),
          surfaceSize: const Size(360, 640),
          textScale: 1.3,
          disableAnimations: true,
        ),
      );
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(find.text('ROOM PIN'), findsOneWidget);
      expect(find.text('OPTICAL QR'), findsOneWidget);
      expect(find.text('HOTSPOT'), findsOneWidget);
    });

    testWidgets('9. Accessibility tap targets are >= 44x44 logical pixels',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final service = _FakeTeacherService(
        fakeBeacon: makeBeacon(),
        fakeAdvertisingError: 'BLE slot busy',
      );
      addTearDown(service.dispose);

      await tester.pumpWidget(wrapScreen(service: service));
      await tester.pump(const Duration(milliseconds: 1100));

      for (final label in [
        'Back and end session',
        'Retry BLE broadcast',
        'Open QR Challenge',
        'Scan student QR code',
        'Show optical QR code',
        'Pause session',
        'End attendance session',
      ]) {
        final finder = find.bySemanticsLabel(label);
        expect(finder, findsOneWidget, reason: 'Missing semantics: $label');
        final size = tester.getSize(finder);
        expect(size.width >= 44.0, isTrue, reason: '$label width ${size.width} < 44');
        expect(size.height >= 44.0, isTrue, reason: '$label height ${size.height} < 44');
      }
    });
  });
}
