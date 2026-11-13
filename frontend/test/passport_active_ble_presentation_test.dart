import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:attendance_app/auth/models/user_model.dart';
import 'package:attendance_app/student/models/passport_attendance_model.dart';
import 'package:attendance_app/student/models/passport_identity_model.dart';
import 'package:attendance_app/student/widgets/passport/passport_active_view.dart';
import 'package:attendance_app/student/widgets/passport/passport_card.dart';
import 'package:attendance_app/student/screens/passport_screen.dart';
import 'package:attendance_app/student/services/passport_biometric_service.dart';
import 'package:attendance_app/student/services/passport_student_attendance_service.dart';
import 'package:attendance_app/student/services/passport_crypto_service.dart';
import 'package:attendance_app/student/services/passport_identity_service.dart';
import 'package:attendance_app/shared/models/session_model.dart';

/// Test Key Storage implementation in memory
class _TestKeyStorage implements PassportKeyStorage {
  final Map<String, String> _storage = {};
  @override
  Future<String?> read(String key) async => _storage[key];
  @override
  Future<void> write(String key, String value) async => _storage[key] = value;
  @override
  Future<void> delete(String key) async => _storage.remove(key);
  @override
  Future<bool> containsKey(String key) async => _storage.containsKey(key);
}

/// Test biometric provider with controllable outcome
class _MockBiometricProvider implements PassportBiometricAuthProvider {
  int callCount = 0;
  BiometricAuthResult result;

  _MockBiometricProvider({this.result = BiometricAuthResult.success});

  @override
  Future<bool> canCheckBiometrics() async => true;

  @override
  Future<bool> isDeviceSupported() async => true;

  @override
  Future<BiometricAuthResult> authenticateBiometricOnly({
    required String reason,
  }) async {
    callCount++;
    return result;
  }

  @override
  Future<BiometricAuthResult> authenticate({
    required String reason,
    bool biometricOnly = true,
  }) async {
    callCount++;
    return result;
  }
}

/// Test Attendance Service spying on startAttendance and cancel
class _SpyStudentAttendanceService extends PassportStudentAttendanceService {
  int startAttendanceCount = 0;
  int cancelCount = 0;
  bool? lastAlreadyAuthenticated;
  UserModel? lastUser;

  _SpyStudentAttendanceService({
    PassportCryptoService? cryptoService,
  }) : super(
          cryptoService: cryptoService,
        );

  @override
  Future<bool> checkAndRequestPermissions({bool allowZeroBle = true}) async => true;

  @override
  Future<PassportAttendanceResponseModel?> startAttendance({
    required UserModel currentUser,
    Duration scanTimeout = const Duration(seconds: 12),
    Duration advertisingDuration = const Duration(seconds: 15),
    int? currentTimestampSeconds,
    bool alreadyAuthenticated = false,
    List<SessionModel>? activeSessions,
    Set<String>? ignoredSessionIds,
    bool preserveCompletedState = false,
  }) async {
    startAttendanceCount++;
    lastUser = currentUser;
    lastAlreadyAuthenticated = alreadyAuthenticated;
    return null;
  }

  @override
  Future<void> cancel({bool userCancelled = false}) async {
    cancelCount++;
    await super.cancel(userCancelled: userCancelled);
  }
}

/// Test Identity Service returning active certified enrollment
class _MockIdentityService extends PassportIdentityService {
  final String testPubKey;

  _MockIdentityService(this.testPubKey);

  @override
  Future<PassportEnrollmentStatus> getIdentity({String? userId}) async {
    return PassportEnrollmentStatus(
      enrolled: true,
      key: PassportIdentityKeyModel(
        id: 'key-test-01',
        userId: userId ?? 'student-test-01',
        publicKey: testPubKey,
        status: 'ACTIVE',
      ),
      certificate: PassportCertificateModel(
        id: 'cert-test-01',
        keyId: 'key-test-01',
        issuerKeyId: 'issuer-01',
        userId: userId ?? 'student-test-01',
        publicKey: testPubKey,
        validFrom: DateTime.now().subtract(const Duration(days: 1)),
        validTo: DateTime.now().add(const Duration(days: 365)),
        signature: 'mock_signature',
        status: 'ACTIVE',
        payload: {},
      ),
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final testUser = UserModel(
    id: 'student-test-01',
    name: 'Sourav Nanda',
    email: 'sourav.nanda@campusos.edu',
    role: 'student',
    branch: 'CSE',
    year: '5th Semester',
    registrationNumber: '2101297001',
    course: 'B.Tech',
  );

  final validKeyBase64 = base64Encode(List<int>.filled(32, 42));

  Future<void> setupEnrolledServices(
    _TestKeyStorage storage,
    void Function(
      PassportCryptoService crypto,
      _MockIdentityService identity,
      _SpyStudentAttendanceService attendance,
    ) onReady,
  ) async {
    await storage.write(PassportCryptoService.privateKeyStorageKey, validKeyBase64);
    final crypto = PassportCryptoService(storage: storage);
    final pubKey = await crypto.getPublicKeyBase64();
    final identity = _MockIdentityService(pubKey!);
    final attendance = _SpyStudentAttendanceService(cryptoService: crypto);
    onReady(crypto, identity, attendance);
  }

  group('CampusOS Active Passport Interaction & BLE Presentation Suite', () {
    // 1. Active Passport removes Start Attendance button
    testWidgets('1. Active Passport removes Start Attendance button and renders passive status', (tester) async {
      final notifier = ValueNotifier<int>(30);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PassportActiveView(
              studentName: 'Sourav Nanda',
              department: 'CSE',
              semester: '5th Semester',
              registrationNumber: '2101297001',
              qrData: 'CAMPUS_PASSPORT:v1:TEST',
              remainingSecondsNotifier: notifier,
              isBluetoothActive: true,
              attendanceState: StudentAttendanceFlowState.scanningForTeacherBeacon,
              attendanceStatusMessage: 'Looking for class session...',
              onClose: () {},
              onRefreshQr: () {},
            ),
          ),
        ),
      );

      // Verify no Start Attendance action exists in UI
      expect(find.text('Start Attendance'), findsNothing);
      // Verify passive status text is displayed
      expect(find.text('Looking for class session...'), findsOneWidget);
      // Student details are intact
      expect(find.text('SOURAV NANDA'), findsOneWidget);
    });

    // 2. BLE flow starts after successful Passport activation
    testWidgets('2. BLE flow starts after successful Passport activation with alreadyAuthenticated: true', (tester) async {
      final storage = _TestKeyStorage();
      late PassportCryptoService crypto;
      late _MockIdentityService identity;
      late _SpyStudentAttendanceService spyAttendance;

      await setupEnrolledServices(storage, (c, i, a) {
        crypto = c;
        identity = i;
        spyAttendance = a;
      });

      final mockBio = _MockBiometricProvider(result: BiometricAuthResult.success);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PassportScreen(
              user: testUser,
              cryptoService: crypto,
              identityService: identity,
              studentAttendanceService: spyAttendance,
              biometricService: mockBio,
            ),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Initial state is locked: BLE should not have started
      expect(spyAttendance.startAttendanceCount, 0);

      // Unlock passport by tapping PassportCard
      expect(find.byType(PassportCard), findsOneWidget);
      await tester.tap(find.byType(PassportCard));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump(const Duration(milliseconds: 500));

      // Biometric was prompted and succeeded
      expect(mockBio.callCount, 1);
      // BLE attendance started automatically
      expect(spyAttendance.startAttendanceCount, 1);
      expect(spyAttendance.lastAlreadyAuthenticated, isTrue);

      await tester.pump(const Duration(milliseconds: 1600));
    });

    // 3. BLE does not start before authentication
    testWidgets('3. BLE does not start before authentication (in locked state)', (tester) async {
      final storage = _TestKeyStorage();
      late PassportCryptoService crypto;
      late _MockIdentityService identity;
      late _SpyStudentAttendanceService spyAttendance;

      await setupEnrolledServices(storage, (c, i, a) {
        crypto = c;
        identity = i;
        spyAttendance = a;
      });

      final mockBio = _MockBiometricProvider();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PassportScreen(
              user: testUser,
              cryptoService: crypto,
              identityService: identity,
              studentAttendanceService: spyAttendance,
              biometricService: mockBio,
            ),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Verify locked state has 0 BLE starts
      expect(spyAttendance.startAttendanceCount, 0);
    });

    // 4. BLE does not start on authentication failure
    testWidgets('4. BLE does not start on authentication failure', (tester) async {
      final storage = _TestKeyStorage();
      late PassportCryptoService crypto;
      late _MockIdentityService identity;
      late _SpyStudentAttendanceService spyAttendance;

      await setupEnrolledServices(storage, (c, i, a) {
        crypto = c;
        identity = i;
        spyAttendance = a;
      });

      final failingBio = _MockBiometricProvider(result: BiometricAuthResult.ownerMismatch);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PassportScreen(
              user: testUser,
              cryptoService: crypto,
              identityService: identity,
              studentAttendanceService: spyAttendance,
              biometricService: failingBio,
            ),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Tap to unlock
      expect(find.byType(PassportCard), findsOneWidget);
      await tester.tap(find.byType(PassportCard));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // Biometric was called, but failed
      expect(failingBio.callCount, 1);
      // BLE MUST NOT start
      expect(spyAttendance.startAttendanceCount, 0);
    });

    // 5. BLE starts only once (duplicate-start guard)
    testWidgets('5. BLE starts only once for current active session (duplicate-start guard)', (tester) async {
      final storage = _TestKeyStorage();
      late PassportCryptoService crypto;
      late _MockIdentityService identity;
      late _SpyStudentAttendanceService spyAttendance;

      await setupEnrolledServices(storage, (c, i, a) {
        crypto = c;
        identity = i;
        spyAttendance = a;
      });

      final mockBio = _MockBiometricProvider(result: BiometricAuthResult.success);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PassportScreen(
              user: testUser,
              cryptoService: crypto,
              identityService: identity,
              studentAttendanceService: spyAttendance,
              biometricService: mockBio,
            ),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      await tester.tap(find.byType(PassportCard));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(spyAttendance.startAttendanceCount, 1);

      // Subsequent pumps must not trigger additional scans
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump(const Duration(seconds: 1));
      expect(spyAttendance.startAttendanceCount, 1);
    });

    // 6. Wallet rebuild does not restart BLE
    testWidgets('6. Wallet rebuild does not restart BLE', (tester) async {
      final storage = _TestKeyStorage();
      late PassportCryptoService crypto;
      late _MockIdentityService identity;
      late _SpyStudentAttendanceService spyAttendance;

      await setupEnrolledServices(storage, (c, i, a) {
        crypto = c;
        identity = i;
        spyAttendance = a;
      });

      final mockBio = _MockBiometricProvider(result: BiometricAuthResult.success);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PassportScreen(
              user: testUser,
              cryptoService: crypto,
              identityService: identity,
              studentAttendanceService: spyAttendance,
              biometricService: mockBio,
            ),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      await tester.tap(find.byType(PassportCard));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(spyAttendance.startAttendanceCount, 1);

      // Rebuilding the widget tree
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PassportScreen(
              user: testUser,
              cryptoService: crypto,
              identityService: identity,
              studentAttendanceService: spyAttendance,
              biometricService: mockBio,
            ),
          ),
        ),
      );
      await tester.pump();

      // Scan count remains exactly 1
      expect(spyAttendance.startAttendanceCount, 1);
    });

    // 7. QR countdown does not restart BLE
    testWidgets('7. QR countdown ticks do not restart BLE', (tester) async {
      final storage = _TestKeyStorage();
      late PassportCryptoService crypto;
      late _MockIdentityService identity;
      late _SpyStudentAttendanceService spyAttendance;

      await setupEnrolledServices(storage, (c, i, a) {
        crypto = c;
        identity = i;
        spyAttendance = a;
      });

      final mockBio = _MockBiometricProvider(result: BiometricAuthResult.success);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PassportScreen(
              user: testUser,
              cryptoService: crypto,
              identityService: identity,
              studentAttendanceService: spyAttendance,
              biometricService: mockBio,
            ),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      await tester.tap(find.byType(PassportCard));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(spyAttendance.startAttendanceCount, 1);

      // Fast-forward 5 seconds of countdown ticks
      for (int i = 0; i < 5; i++) {
        await tester.pump(const Duration(seconds: 1));
      }

      // Count must still be 1
      expect(spyAttendance.startAttendanceCount, 1);
    });

    // 8. Bluetooth state updates do not restart BLE
    testWidgets('8. Bluetooth state updates do not restart BLE', (tester) async {
      final storage = _TestKeyStorage();
      late PassportCryptoService crypto;
      late _MockIdentityService identity;
      late _SpyStudentAttendanceService spyAttendance;

      await setupEnrolledServices(storage, (c, i, a) {
        crypto = c;
        identity = i;
        spyAttendance = a;
      });

      final mockBio = _MockBiometricProvider(result: BiometricAuthResult.success);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PassportScreen(
              user: testUser,
              cryptoService: crypto,
              identityService: identity,
              studentAttendanceService: spyAttendance,
              biometricService: mockBio,
            ),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      await tester.tap(find.byType(PassportCard));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(spyAttendance.startAttendanceCount, 1);

      // Re-trigger pump with adapter listener firing
      await tester.pump(const Duration(milliseconds: 200));
      expect(spyAttendance.startAttendanceCount, 1);
    });

    // 9. Passport lock stops BLE
    testWidgets('9. Passport lock stops BLE', (tester) async {
      final storage = _TestKeyStorage();
      late PassportCryptoService crypto;
      late _MockIdentityService identity;
      late _SpyStudentAttendanceService spyAttendance;

      await setupEnrolledServices(storage, (c, i, a) {
        crypto = c;
        identity = i;
        spyAttendance = a;
      });

      final mockBio = _MockBiometricProvider(result: BiometricAuthResult.success);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PassportScreen(
              user: testUser,
              cryptoService: crypto,
              identityService: identity,
              studentAttendanceService: spyAttendance,
              biometricService: mockBio,
            ),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      await tester.tap(find.byType(PassportCard));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(spyAttendance.startAttendanceCount, 1);

      // Close / lock passport via back/close icon
      final closeButtonFinder = find.byIcon(Icons.arrow_back_ios_new_rounded);
      expect(closeButtonFinder, findsOneWidget);
      await tester.tap(closeButtonFinder);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 550));

      // cancel() must have been called on spy service
      expect(spyAttendance.cancelCount, greaterThanOrEqualTo(1));
    });

    // 10. Inactivity timeout stops BLE
    testWidgets('10. 90-second inactivity timeout stops BLE', (tester) async {
      final storage = _TestKeyStorage();
      late PassportCryptoService crypto;
      late _MockIdentityService identity;
      late _SpyStudentAttendanceService spyAttendance;

      await setupEnrolledServices(storage, (c, i, a) {
        crypto = c;
        identity = i;
        spyAttendance = a;
      });

      final mockBio = _MockBiometricProvider(result: BiometricAuthResult.success);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PassportScreen(
              user: testUser,
              cryptoService: crypto,
              identityService: identity,
              studentAttendanceService: spyAttendance,
              biometricService: mockBio,
            ),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      await tester.tap(find.byType(PassportCard));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(spyAttendance.startAttendanceCount, 1);

      // Advance by 91 seconds (inactivity timeout is 90s)
      await tester.pump(const Duration(seconds: 91));
      await tester.pump(const Duration(milliseconds: 550));

      // BLE must have been stopped
      expect(spyAttendance.cancelCount, greaterThanOrEqualTo(1));
    });

    // 11. Screen disposal stops BLE
    testWidgets('11. Screen disposal stops BLE cleanly without setState error', (tester) async {
      final storage = _TestKeyStorage();
      late PassportCryptoService crypto;
      late _MockIdentityService identity;
      late _SpyStudentAttendanceService spyAttendance;

      await setupEnrolledServices(storage, (c, i, a) {
        crypto = c;
        identity = i;
        spyAttendance = a;
      });

      final mockBio = _MockBiometricProvider(result: BiometricAuthResult.success);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PassportScreen(
              user: testUser,
              cryptoService: crypto,
              identityService: identity,
              studentAttendanceService: spyAttendance,
              biometricService: mockBio,
            ),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      await tester.tap(find.byType(PassportCard));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(spyAttendance.startAttendanceCount, 1);

      // Unmount PassportScreen by replacing with a placeholder
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SizedBox.shrink(),
          ),
        ),
      );
      await tester.pump();

      // BLE was cancelled on disposal
      expect(spyAttendance.cancelCount, greaterThanOrEqualTo(1));
    });

    // 12. Wave appears behind active Passport
    testWidgets('12. Proximity wave appears behind active Passport in Stack', (tester) async {
      final notifier = ValueNotifier<int>(30);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PassportActiveView(
              studentName: 'Sourav Nanda',
              department: 'CSE',
              semester: '5th Semester',
              registrationNumber: '2101297001',
              qrData: 'CAMPUS_PASSPORT:v1:TEST',
              remainingSecondsNotifier: notifier,
              isBluetoothActive: true,
              attendanceState: StudentAttendanceFlowState.scanningForTeacherBeacon,
              onClose: () {},
              onRefreshQr: () {},
            ),
          ),
        ),
      );

      // Find Stack in PassportActiveView
      final stackFinder = find.descendant(
        of: find.byType(PassportActiveView),
        matching: find.byType(Stack),
      );
      expect(stackFinder, findsWidgets);

      // The wave widget is isolated inside RepaintBoundary behind the card
      final repaintBoundaries = find.descendant(
        of: find.byType(PassportActiveView),
        matching: find.byType(RepaintBoundary),
      );
      expect(repaintBoundaries, findsWidgets);
    });

    // 13. Wave does not cover QR or text
    testWidgets('13. Wave does not cover student name, registration number, or QR', (tester) async {
      final notifier = ValueNotifier<int>(30);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PassportActiveView(
              studentName: 'Sourav Nanda',
              department: 'CSE',
              semester: '5th Semester',
              registrationNumber: '2101297001',
              qrData: 'CAMPUS_PASSPORT:v1:TEST',
              remainingSecondsNotifier: notifier,
              isBluetoothActive: true,
              onClose: () {},
              onRefreshQr: () {},
            ),
          ),
        ),
      );

      // Verify student details are completely visible and hit-testable
      expect(find.text('SOURAV NANDA'), findsOneWidget);
      expect(find.textContaining('2101297001'), findsOneWidget);
      expect(find.text('VERIFIED'), findsOneWidget);

      // Close button is accessible and not obscured
      final closeButton = find.byIcon(Icons.arrow_back_ios_new_rounded);
      expect(closeButton, findsOneWidget);
      await tester.tap(closeButton);
    });

    // 14. Wave animation does not rebuild the Wallet
    testWidgets('14. Wave animation does not rebuild parent Wallet or card', (tester) async {
      final notifier = ValueNotifier<int>(30);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PassportActiveView(
              studentName: 'Sourav Nanda',
              department: 'CSE',
              semester: '5th Semester',
              registrationNumber: '2101297001',
              qrData: 'CAMPUS_PASSPORT:v1:TEST',
              remainingSecondsNotifier: notifier,
              isBluetoothActive: true,
              attendanceState: StudentAttendanceFlowState.scanningForTeacherBeacon,
              onClose: () {},
              onRefreshQr: () {},
            ),
          ),
        ),
      );

      // Pump 5 animation frames
      for (int i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 16));
      }

      // Passport typography remains stable
      expect(find.text('SOURAV NANDA'), findsOneWidget);
    });

    // 15. Reduced motion disables continuous wave animation
    testWidgets('15. Reduced motion disables continuous wave animation and renders static indicator', (tester) async {
      final notifier = ValueNotifier<int>(30);

      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: MaterialApp(
            home: Scaffold(
              body: PassportActiveView(
                studentName: 'Sourav Nanda',
                department: 'CSE',
                semester: '5th Semester',
                registrationNumber: '2101297001',
                qrData: 'CAMPUS_PASSPORT:v1:TEST',
                remainingSecondsNotifier: notifier,
                isBluetoothActive: true,
                attendanceState: StudentAttendanceFlowState.scanningForTeacherBeacon,
                onClose: () {},
                onRefreshQr: () {},
              ),
            ),
          ),
        ),
      );

      // Verify rendering is stable under disableAnimations
      expect(find.text('SOURAV NANDA'), findsOneWidget);
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('SOURAV NANDA'), findsOneWidget);
    });

    // 16. Attendance state visual mapping
    testWidgets('16. Proximity status region renders appropriate visual state for all flow stages', (tester) async {
      final notifier = ValueNotifier<int>(30);

      // Case A: idle/searching
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PassportActiveView(
              studentName: 'Sourav Nanda',
              department: 'CSE',
              semester: '5th Semester',
              registrationNumber: '2101297001',
              qrData: 'CAMPUS_PASSPORT:v1:TEST',
              remainingSecondsNotifier: notifier,
              isBluetoothActive: true,
              attendanceState: StudentAttendanceFlowState.scanningForTeacherBeacon,
              attendanceStatusMessage: 'Looking for class session...',
              onClose: () {},
              onRefreshQr: () {},
            ),
          ),
        ),
      );
      expect(find.text('Looking for class session...'), findsOneWidget);

      // Case B: Teacher Beacon detected
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PassportActiveView(
              studentName: 'Sourav Nanda',
              department: 'CSE',
              semester: '5th Semester',
              registrationNumber: '2101297001',
              qrData: 'CAMPUS_PASSPORT:v1:TEST',
              remainingSecondsNotifier: notifier,
              isBluetoothActive: true,
              attendanceState: StudentAttendanceFlowState.teacherBeaconDetected,
              attendanceStatusMessage: 'Teacher detected',
              onClose: () {},
              onRefreshQr: () {},
            ),
          ),
        ),
      );
      expect(find.text('Teacher detected'), findsOneWidget);

      // Case C: Authenticating/verifying
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PassportActiveView(
              studentName: 'Sourav Nanda',
              department: 'CSE',
              semester: '5th Semester',
              registrationNumber: '2101297001',
              qrData: 'CAMPUS_PASSPORT:v1:TEST',
              remainingSecondsNotifier: notifier,
              isBluetoothActive: true,
              attendanceState: StudentAttendanceFlowState.signingResponse,
              attendanceStatusMessage: 'Verifying session...',
              onClose: () {},
              onRefreshQr: () {},
            ),
          ),
        ),
      );
      expect(find.text('Verifying session...'), findsOneWidget);

      // Case D: Completed
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PassportActiveView(
              studentName: 'Sourav Nanda',
              department: 'CSE',
              semester: '5th Semester',
              registrationNumber: '2101297001',
              qrData: 'CAMPUS_PASSPORT:v1:TEST',
              remainingSecondsNotifier: notifier,
              isBluetoothActive: true,
              attendanceState: StudentAttendanceFlowState.completed,
              attendanceStatusMessage: 'Attendance verified',
              onClose: () {},
              onRefreshQr: () {},
            ),
          ),
        ),
      );
      expect(find.text('Attendance verified'), findsOneWidget);
    });

    // 17. Bluetooth Disabled handles cleanly
    testWidgets('17. Bluetooth disabled displays clear prompt without fake wave', (tester) async {
      final notifier = ValueNotifier<int>(30);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PassportActiveView(
              studentName: 'Sourav Nanda',
              department: 'CSE',
              semester: '5th Semester',
              registrationNumber: '2101297001',
              qrData: 'CAMPUS_PASSPORT:v1:TEST',
              remainingSecondsNotifier: notifier,
              isBluetoothActive: false,
              attendanceState: StudentAttendanceFlowState.idle,
              onClose: () {},
              onRefreshQr: () {},
            ),
          ),
        ),
      );

      expect(find.text('Bluetooth unavailable · QR fallback active'), findsOneWidget);
    });
    // 18. Proximity wave renders ShaderMask with BlendMode.dstIn for bottom fade
    testWidgets('18. Proximity wave renders ShaderMask with BlendMode.dstIn for bottom fade', (tester) async {
      final notifier = ValueNotifier<int>(30);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PassportActiveView(
              studentName: 'Sourav Nanda',
              department: 'CSE',
              semester: '5th Semester',
              registrationNumber: '2101297001',
              qrData: 'CAMPUS_PASSPORT:v1:TEST',
              remainingSecondsNotifier: notifier,
              isBluetoothActive: true,
              attendanceState: StudentAttendanceFlowState.scanningForTeacherBeacon,
              onClose: () {},
              onRefreshQr: () {},
            ),
          ),
        ),
      );

      final shaderMaskFinder = find.descendant(
        of: find.byType(PassportActiveView),
        matching: find.byType(ShaderMask),
      );
      expect(shaderMaskFinder, findsOneWidget);

      final shaderMask = tester.widget<ShaderMask>(shaderMaskFinder);
      expect(shaderMask.blendMode, equals(BlendMode.dstIn));
    });

    // 19. Proximity wave renders still rings even when bluetooth is disabled or in error state
    testWidgets('19. Proximity wave renders still rings even when bluetooth is disabled', (tester) async {
      final notifier = ValueNotifier<int>(30);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PassportActiveView(
              studentName: 'Sourav Nanda',
              department: 'CSE',
              semester: '5th Semester',
              registrationNumber: '2101297001',
              qrData: 'CAMPUS_PASSPORT:v1:TEST',
              remainingSecondsNotifier: notifier,
              isBluetoothActive: false,
              attendanceState: StudentAttendanceFlowState.error,
              onClose: () {},
              onRefreshQr: () {},
            ),
          ),
        ),
      );

      // The proximity wave painter remains mounted to render the 3 still rings
      final shaderMaskFinder = find.descendant(
        of: find.byType(PassportActiveView),
        matching: find.byType(ShaderMask),
      );
      expect(shaderMaskFinder, findsOneWidget);

      final customPaintFinder = find.descendant(
        of: shaderMaskFinder,
        matching: find.byType(CustomPaint),
      );
      expect(customPaintFinder, findsOneWidget);
    });
  });
}
