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
import 'package:flutter/services.dart';
import 'package:attendance_app/student/services/passport_crypto_service.dart';
import 'package:attendance_app/student/services/passport_identity_service.dart';
import 'package:attendance_app/shared/models/session_model.dart';

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

class _SpyStudentAttendanceService extends PassportStudentAttendanceService {
  int startAttendanceCount = 0;

  _SpyStudentAttendanceService({PassportCryptoService? cryptoService})
      : super(cryptoService: cryptoService);

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
    return null;
  }
}

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
    Function(PassportCryptoService, _MockIdentityService, _SpyStudentAttendanceService) callback,
  ) async {
    await storage.write(PassportCryptoService.privateKeyStorageKey, validKeyBase64);
    final crypto = PassportCryptoService(storage: storage);
    final pubKey = await crypto.getPublicKeyBase64();
    final identity = _MockIdentityService(pubKey!);
    final attendance = _SpyStudentAttendanceService(cryptoService: crypto);
    callback(crypto, identity, attendance);
  }

  group('Passport Bluetooth Denied & Wi-Fi Attendance Flow Suite', () {
    testWidgets('1. Face auth unlocks and admits student into Active Passport even when Bluetooth is inactive', (tester) async {
      final storage = _TestKeyStorage();
      late PassportCryptoService crypto;
      late _MockIdentityService identity;
      late _SpyStudentAttendanceService attendance;

      await setupEnrolledServices(storage, (c, i, a) {
        crypto = c;
        identity = i;
        attendance = a;
      });

      final mockBio = _MockBiometricProvider(result: BiometricAuthResult.success);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PassportScreen(
              user: testUser,
              cryptoService: crypto,
              identityService: identity,
              studentAttendanceService: attendance,
              biometricService: mockBio,
            ),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Initially shows locked card in wallet
      expect(find.byType(PassportCard), findsOneWidget);
      expect(find.byType(PassportActiveView), findsNothing);

      // Student taps the Passport card in the wallet
      await tester.tap(find.byType(PassportCard));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Face auth succeeded and student is let in to the active passport view
      expect(mockBio.callCount, 1);
      expect(find.byType(PassportActiveView), findsOneWidget);
      expect(find.text('SOURAV NANDA'), findsWidgets);
    });

    testWidgets('2. System dialog pause/inactive lifecycle does not lock student out of Active Passport', (tester) async {
      final storage = _TestKeyStorage();
      late PassportCryptoService crypto;
      late _MockIdentityService identity;
      late _SpyStudentAttendanceService attendance;

      await setupEnrolledServices(storage, (c, i, a) {
        crypto = c;
        identity = i;
        attendance = a;
      });

      final mockBio = _MockBiometricProvider(result: BiometricAuthResult.success);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PassportScreen(
              user: testUser,
              cryptoService: crypto,
              identityService: identity,
              studentAttendanceService: attendance,
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

      expect(find.byType(PassportActiveView), findsOneWidget);

      // Simulate system dialog appearing (e.g. Android Bluetooth turn-on prompt: inactive -> paused)
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      await tester.pump();
      expect(find.byType(PassportActiveView), findsOneWidget);

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump();
      expect(find.byType(PassportActiveView), findsOneWidget);

      // Student taps "Deny" on Bluetooth turn-on prompt -> app resumes
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Student must still be inside Active Passport
      expect(find.byType(PassportActiveView), findsOneWidget);
    });

    testWidgets('3. Active Passport displays Wi-Fi Hotspot button and fallback when Bluetooth is unavailable', (tester) async {
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
              isBluetoothActive: false, // Bluetooth turned off / denied
              attendanceState: StudentAttendanceFlowState.idle,
              onClose: () {},
              onRefreshQr: () {},
              onScanWifiHotspot: () {},
            ),
          ),
        ),
      );

      await tester.pump();

      // Displays fallback text indicating Bluetooth is off and QR / fallback is active
      expect(find.text('Bluetooth unavailable · QR fallback active'), findsOneWidget);
      expect(find.byIcon(Icons.bluetooth_disabled_rounded), findsOneWidget);

      // Wi-Fi Hotspot button is rendered and visible
      expect(find.text('Wi-Fi Hotspot'), findsOneWidget);
      expect(find.byIcon(Icons.wifi_tethering_rounded), findsOneWidget);
    });

    testWidgets('4. Tapping Wi-Fi Hotspot button triggers onScanWifiHotspot callback', (tester) async {
      final notifier = ValueNotifier<int>(30);
      bool wifiScanned = false;

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
              onScanWifiHotspot: () {
                wifiScanned = true;
              },
            ),
          ),
        ),
      );

      await tester.pump();
      await tester.tap(find.text('Wi-Fi Hotspot'));
      await tester.pump();

      expect(wifiScanned, isTrue);
    });

    test('5. checkAndRequestPermissions with allowZeroBle=true returns true even when Bluetooth is denied', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
        const MethodChannel('flutter.baseflow.com/permissions/methods'),
        (call) async => <int, int>{},
      );
      final service = PassportStudentAttendanceService();

      final result = await service.checkAndRequestPermissions(allowZeroBle: true);
      expect(result, isTrue);

      service.resetBluetoothDeclinedSession();
      expect(await service.isBluetoothAvailable(), isTrue);
    });
  });
}
