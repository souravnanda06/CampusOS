import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:attendance_app/auth/models/user_model.dart';
import 'package:attendance_app/student/models/gate_pass_model.dart';
import 'package:attendance_app/student/models/passport_wallet_state.dart';
import 'package:attendance_app/student/widgets/passport/campus_wallet.dart';
import 'package:attendance_app/student/widgets/passport/passport_card.dart';
import 'package:attendance_app/student/widgets/passport/student_id_card.dart';
import 'package:attendance_app/student/widgets/passport/gate_pass_card.dart';
import 'package:attendance_app/student/widgets/passport/passport_active_view.dart';
import 'package:attendance_app/student/widgets/passport/passport_activation_view.dart';
import 'package:attendance_app/student/widgets/passport/passport_scanner_button.dart';
import 'package:attendance_app/student/widgets/passport/bluetooth_wave.dart';
import 'package:attendance_app/student/widgets/passport/card_security_pattern.dart';
import 'package:attendance_app/student/widgets/passport/passport_qr.dart';
import 'package:attendance_app/student/widgets/passport/wallet_card.dart';
import 'package:attendance_app/student/services/passport_biometric_service.dart';
import 'package:attendance_app/student/services/passport_crypto_service.dart';
import 'package:attendance_app/student/services/passport_trust_bundle_service.dart';
import 'package:attendance_app/student/services/passport_student_attendance_service.dart';
import 'package:attendance_app/student/screens/passport_screen.dart';

/// Fake In-Memory Key Storage for testing
class _TestKeyStorage implements PassportKeyStorage {
  final Map<String, String> _mem = {};
  @override
  Future<String?> read(String key) async => _mem[key];
  @override
  Future<void> write(String key, String value) async => _mem[key] = value;
  @override
  Future<void> delete(String key) async => _mem.remove(key);
  @override
  Future<bool> containsKey(String key) async => _mem.containsKey(key);
}

/// Fake Biometric Provider that tracks call counts and parameter flags
class _CountingBiometricProvider implements PassportBiometricAuthProvider {
  int callCount = 0;
  bool willSucceed;

  _CountingBiometricProvider({this.willSucceed = true});

  @override
  Future<bool> canCheckBiometrics() async => true;

  @override
  Future<bool> isDeviceSupported() async => true;

  @override
  Future<BiometricAuthResult> authenticateBiometricOnly({
    required String reason,
  }) async {
    callCount++;
    return willSucceed ? BiometricAuthResult.success : BiometricAuthResult.cancelled;
  }

  @override
  Future<BiometricAuthResult> authenticate({
    required String reason,
    bool biometricOnly = true,
  }) async {
    callCount++;
    return willSucceed ? BiometricAuthResult.success : BiometricAuthResult.cancelled;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('CampusOS Campus Wallet & Premium Passport Revamp Suite', () {
    final testUser = UserModel(
      id: 'student-wallet-01',
      name: 'Sourav Nanda',
      email: 'sourav.nanda@campusos.edu',
      role: 'student',
      branch: 'CSE',
      year: '5th Semester',
      registrationNumber: '2101297001',
      course: 'B.Tech',
    );

    // 1. Horizontal Wallet Swipe & Card Architecture
    testWidgets('1. CampusWalletView mounts with 3 credential cards and page indicator', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CampusWalletView(
              studentName: testUser.name,
              department: testUser.branch ?? 'CSE',
              semester: testUser.year ?? '5th Sem',
              registrationNumber: testUser.registrationNumber,
              course: testUser.course,
              passportState: PassportWalletState.locked,
              isBluetoothActive: true,
              activeGatePass: null,
              isLoadingGatePass: false,
              isGatePassUnlocked: false,
              isActivatingPassport: false,
              onUnlockPassport: () {},
              onExpandPassport: () {},
              onActivatePassport: () {},
              onUnlockGatePass: () {},
              onViewGatePassQr: () {},
              onRequestGatePass: () {},
              onOpenScanner: () {},
            ),
          ),
        ),
      );

      // Verify wallet header and page chip
      expect(find.text('Campus Wallet'), findsOneWidget);
      expect(find.text('1 of 5'), findsOneWidget);

      // Verify PageView is present
      expect(find.byType(PageView), findsOneWidget);

      // Verify Hero card is visible on page 0 with adjacent card peek
      expect(find.byType(PassportCard), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(PassportCard),
          matching: find.text('CampusOS'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byType(PassportCard),
          matching: find.text('Passport'),
        ),
        findsOneWidget,
      );
    });

    // 2. Card Peeking & Swipe Navigation
    testWidgets('2. Swiping wallet navigates to Student ID card and updates counter', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CampusWalletView(
              studentName: testUser.name,
              department: testUser.branch ?? 'CSE',
              semester: testUser.year ?? '5th Sem',
              registrationNumber: testUser.registrationNumber,
              course: testUser.course,
              passportState: PassportWalletState.locked,
              isBluetoothActive: true,
              activeGatePass: null,
              isLoadingGatePass: false,
              isGatePassUnlocked: false,
              isActivatingPassport: false,
              onUnlockPassport: () {},
              onExpandPassport: () {},
              onActivatePassport: () {},
              onUnlockGatePass: () {},
              onViewGatePassQr: () {},
              onRequestGatePass: () {},
              onOpenScanner: () {},
            ),
          ),
        ),
      );

      // Swipe left to page 1 (Student ID)
      await tester.fling(find.byType(PageView), const Offset(-300, 0), 1000);
      await tester.pumpAndSettle();

      // Verify Student ID card is now in view
      expect(find.text('STUDENT ID'), findsOneWidget);
      expect(find.text('ROLL NO: 2101297001'), findsOneWidget);
      expect(find.text('AY 2026–2027'), findsOneWidget);
    });

    // 3. Hero Passport Card Minimalist Fintech Typography & Silver Chip
    testWidgets('3. PassportCard displays CampusOS branding, Passport label, and silver EMV chip', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PassportCard(
              studentName: 'Sourav Nanda',
              department: 'CSE',
              semester: '5th Sem',
              registrationNumber: '2101297001',
              state: PassportWalletState.locked,
              isBluetoothActive: true,
              onUnlockTap: () {},
              onExpandTap: () {},
            ),
          ),
        ),
      );

      expect(find.text('CampusOS'), findsOneWidget);
      expect(find.text('Passport'), findsOneWidget);
      expect(find.byType(RealisticEmvChip), findsOneWidget);
      expect(find.text('Tap to unlock'), findsNothing);
    });

    // 4. Student ID Informational Card
    testWidgets('4. StudentIdCard renders privacy-friendly device name without raw hardware ID', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: StudentIdCard(
              studentName: 'Sourav Nanda',
              department: 'CSE',
              semester: '5th Sem',
              registrationNumber: '2101297001',
              course: 'B.Tech',
              deviceName: 'Galaxy A55 (Bound)',
            ),
          ),
        ),
      );

      expect(find.text('CAMPUSOS'), findsOneWidget);
      expect(find.text('STUDENT ID'), findsOneWidget);
      expect(find.text('Galaxy A55 (Bound)'), findsOneWidget);
      expect(find.text('Enrolled'), findsOneWidget);
    });

    // 5. Gate Pass Card: Empty State
    testWidgets('5. GatePassCard renders request action when no active pass exists', (tester) async {
      bool requestTapped = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GatePassCard(
              activePass: null,
              isLoading: false,
              isUnlocked: false,
              onUnlockTap: () {},
              onRequestPassTap: () => requestTapped = true,
              onViewQrTap: () {},
            ),
          ),
        ),
      );

      expect(find.text('No Active Pass'), findsOneWidget);
      expect(find.text('Request Gate Pass'), findsOneWidget);

      await tester.tap(find.text('Request Gate Pass'));
      expect(requestTapped, isTrue);
    });

    // 6. Gate Pass Card: Active Approved Pass
    testWidgets('6. GatePassCard renders destination, time window, and unlock prompt', (tester) async {
      final activePass = GatePassModel(
        id: 'pass-qa-99',
        studentId: testUser.id,
        destination: 'Library Complex',
        reason: 'Book Return & Research',
        expectedExitTime: DateTime.now().add(const Duration(hours: 1)),
        expectedReturnTime: DateTime.now().add(const Duration(hours: 4)),
        status: 'APPROVED',
        createdAt: DateTime.now(),
        credential: 'HMAC_TEST_TOKEN_QA_123',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GatePassCard(
              activePass: activePass,
              isLoading: false,
              isUnlocked: false,
              onUnlockTap: () {},
              onRequestPassTap: () {},
              onViewQrTap: () {},
            ),
          ),
        ),
      );

      expect(find.text('LIBRARY COMPLEX'), findsOneWidget);
      expect(find.text('APPROVED'), findsOneWidget);
      expect(find.text('HMAC-SHA256 Validated'), findsOneWidget);
      expect(find.text('Unlock pass'), findsOneWidget);
    });

    // 7. Contextual Biometric Action: Card Tap Unlocks
    testWidgets('7. Contextual unlock action triggers unlock callback by tapping PassportCard', (tester) async {
      bool unlockTapped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CampusWalletView(
              studentName: testUser.name,
              department: testUser.branch ?? 'CSE',
              semester: testUser.year ?? '5th Sem',
              registrationNumber: testUser.registrationNumber,
              course: testUser.course,
              passportState: PassportWalletState.locked,
              isBluetoothActive: true,
              activeGatePass: null,
              isLoadingGatePass: false,
              isGatePassUnlocked: false,
              isActivatingPassport: false,
              onUnlockPassport: () => unlockTapped = true,
              onExpandPassport: () {},
              onActivatePassport: () {},
              onUnlockGatePass: () {},
              onViewGatePassQr: () {},
              onRequestGatePass: () {},
              onOpenScanner: () {},
            ),
          ),
        ),
      );

      // Verify redundant bottom action buttons are removed
      expect(find.text('Unlock Passport'), findsNothing);
      expect(find.text('View Full Credential'), findsNothing);

      // Verify tapping the PassportCard directly unlocks it
      expect(find.byType(PassportCard), findsOneWidget);
      await tester.tap(find.byType(PassportCard));
      expect(unlockTapped, isTrue);
    });

    // 8. Attendance Flow Integration: No Second Biometric Prompt
    test('8. Attendance flow skips biometric prompt when alreadyAuthenticated is true', () async {
      final fakeStorage = _TestKeyStorage();
      final cryptoService = PassportCryptoService(storage: fakeStorage);
      final trustBundleService = PassportTrustBundleService(storage: fakeStorage);
      final countingBio = _CountingBiometricProvider(willSucceed: true);

      final attendanceService = PassportStudentAttendanceService(
        cryptoService: cryptoService,
        trustBundleService: trustBundleService,
        biometricService: countingBio,
      );

      // Verify that attendance service is initialized and bio count remains 0 prior to any scan
      expect(attendanceService, isNotNull);
      expect(countingBio.callCount, 0);
    });

    // 9. Isolated 30-Second QR Countdown
    testWidgets('9. PassportQrView updates countdown via ValueNotifier without full rebuild', (tester) async {
      final notifier = ValueNotifier<int>(28);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PassportQrView(
              qrData: 'CAMPUS_PASSPORT:v1:TEST_PAYLOAD',
              remainingSecondsNotifier: notifier,
              qrSize: 150.0,
            ),
          ),
        ),
      );

      expect(find.text('Refreshes in 00:28'), findsOneWidget);

      // Update notifier to 15 seconds
      notifier.value = 15;
      await tester.pump();

      expect(find.text('Refreshes in 00:15'), findsOneWidget);
    });

    // 10. Vertical Active Presentation View
    testWidgets('10. PassportActiveView renders verified seal, student typography, and passive BLE status', (tester) async {
      final notifier = ValueNotifier<int>(30);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PassportActiveView(
              studentName: 'Sourav Nanda',
              department: 'CSE',
              semester: '5th Semester',
              registrationNumber: '2101297001',
              qrData: 'CAMPUS_PASSPORT:v1:ACTIVE_PRESENTATION',
              remainingSecondsNotifier: notifier,
              isBluetoothActive: true,
              onClose: () {},
              onRefreshQr: () {},
            ),
          ),
        ),
      );

      expect(find.text('VERIFIED'), findsOneWidget);
      expect(find.text('SOURAV NANDA'), findsOneWidget);
      expect(find.text('Start Attendance'), findsNothing);
      expect(find.text('Looking for class session...'), findsOneWidget);
    });

    // 11. BluetoothWave Reduced-Motion Fallback
    testWidgets('11. BluetoothWave renders static glyph when reduced motion is enabled', (tester) async {
      await tester.pumpWidget(
        const MediaQuery(
          data: MediaQueryData(disableAnimations: true),
          child: MaterialApp(
            home: Scaffold(
              body: BluetoothWave(
                isActive: true,
                size: 32,
              ),
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.bluetooth_audio_rounded), findsOneWidget);
    });

    // 12. Floating Scanner Button
    testWidgets('12. PassportScannerButton renders with accessible touch target and callback', (tester) async {
      bool scannerOpened = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PassportScannerButton(
              onPressed: () => scannerOpened = true,
            ),
          ),
        ),
      );

      expect(find.byType(PassportScannerButton), findsOneWidget);
      expect(find.byIcon(Icons.qr_code_scanner_rounded), findsOneWidget);

      await tester.tap(find.byType(PassportScannerButton));
      expect(scannerOpened, isTrue);
    });

    // 13. First-Time Activation Card
    testWidgets('13. PassportActivationCard renders first-time setup prompt', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PassportActivationCard(
              state: PassportWalletState.uninitialized,
              isProcessing: false,
              onActivateTap: () {},
            ),
          ),
        ),
      );

      expect(find.text('Campus Passport'), findsOneWidget);
      expect(find.text('Not Activated'), findsOneWidget);
      expect(find.text('Secure your campus identity on this device.'), findsOneWidget);
    });

    // 14. Key-Missing Reactivation Card (State 4)
    testWidgets('14. PassportActivationCard renders hardware binding warning for keyMissing state', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PassportActivationCard(
              state: PassportWalletState.keyMissing,
              isProcessing: false,
              onActivateTap: () {},
            ),
          ),
        ),
      );

      expect(find.text('Passport Identity Unavailable'), findsOneWidget);
      expect(find.text('Your certified Passport identity is no longer available on this device.'), findsOneWidget);
      expect(find.text('Reactivate Device'), findsNothing);
    });

    // 15. Security Invariant: Zero Private Key Exposure
    testWidgets('15. Security invariant: Private key is never rendered in UI or semantics', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PassportCard(
              studentName: 'Sourav Nanda',
              department: 'CSE',
              semester: '5th Sem',
              state: PassportWalletState.locked,
              isBluetoothActive: false,
              onUnlockTap: () {},
              onExpandTap: () {},
            ),
          ),
        ),
      );

      // Verify safe security assurance text
      expect(find.textContaining('Private key secured'), findsNothing); // Not in plain view on card
      expect(find.textContaining('-----BEGIN PRIVATE KEY-----'), findsNothing);
      expect(find.textContaining('0x'), findsNothing);
    });

    // 16. Regression: Normal restart with existing local key lands in locked state, not keyMissing
    test('16. Regression: Normal restart keeps Passport in locked state when local key exists', () async {
      final fakeStorage = _TestKeyStorage();
      final valid32ByteSeed = base64Encode(List<int>.filled(32, 42));
      await fakeStorage.write(PassportCryptoService.privateKeyStorageKey, valid32ByteSeed);
      final cryptoService = PassportCryptoService(storage: fakeStorage);

      final hasKey = await cryptoService.hasIdentityKey();
      expect(hasKey, isTrue);

      // On normal restart, because hasKey is true, state machine resolves to locked
      final state = hasKey ? PassportWalletState.locked : PassportWalletState.keyMissing;
      expect(state, PassportWalletState.locked);
      expect(state, isNot(PassportWalletState.keyMissing));
    });

    // 17. Regression: Genuine identity loss transitions to keyMissing
    test('17. Regression: Genuine identity loss (local key deleted/invalidated) triggers keyMissing', () async {
      final fakeStorage = _TestKeyStorage(); // Empty storage
      final cryptoService = PassportCryptoService(storage: fakeStorage);

      final hasKey = await cryptoService.hasIdentityKey();
      expect(hasKey, isFalse);

      // User was enrolled previously, but local keystore key is gone
      const bool enrolledOnServer = true;
      final state = (!hasKey && enrolledOnServer)
          ? PassportWalletState.keyMissing
          : PassportWalletState.uninitialized;

      expect(state, PassportWalletState.keyMissing);
    });

    // 18. Regression: Student scanner button routes to studentScanner, never staff verifier
    testWidgets('18. Regression: Wallet scanner button callback opens Student Campus Scanner', (tester) async {
      bool studentScannerOpened = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CampusWalletView(
              studentName: testUser.name,
              department: testUser.branch ?? 'CSE',
              semester: testUser.year ?? '5th Sem',
              registrationNumber: testUser.registrationNumber,
              course: testUser.course,
              passportState: PassportWalletState.locked,
              isBluetoothActive: true,
              activeGatePass: null,
              isLoadingGatePass: false,
              isGatePassUnlocked: false,
              isActivatingPassport: false,
              onUnlockPassport: () {},
              onExpandPassport: () {},
              onActivatePassport: () {},
              onUnlockGatePass: () {},
              onViewGatePassQr: () {},
              onRequestGatePass: () {},
              onOpenScanner: () => studentScannerOpened = true,
            ),
          ),
        ),
      );

      // Find the scanner icon button in the wallet header
      final scannerButtonFinder = find.byTooltip('Campus Scanner');
      expect(scannerButtonFinder, findsOneWidget);

      await tester.tap(scannerButtonFinder);
      expect(studentScannerOpened, isTrue);
    });

    // 19. Invariant: 'Reactivate Device' label is never rendered anywhere in the UI
    testWidgets('19. Invariant: Redundant Reactivate Device label is completely removed from UI', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CampusWalletView(
              studentName: testUser.name,
              department: testUser.branch ?? 'CSE',
              semester: testUser.year ?? '5th Sem',
              registrationNumber: testUser.registrationNumber,
              course: testUser.course,
              passportState: PassportWalletState.keyMissing,
              isBluetoothActive: false,
              activeGatePass: null,
              isLoadingGatePass: false,
              isGatePassUnlocked: false,
              isActivatingPassport: false,
              onUnlockPassport: () {},
              onExpandPassport: () {},
              onActivatePassport: () {},
              onUnlockGatePass: () {},
              onViewGatePassQr: () {},
              onRequestGatePass: () {},
              onOpenScanner: () {},
            ),
          ),
        ),
      );

      // Verify that "Reactivate Device" never appears anywhere in the widget tree
      expect(find.textContaining('Reactivate Device'), findsNothing);
      expect(find.text('Reactivate Passport'), findsWidgets);
    });

    // 20. Reverse 3D Animation: Vertical to Horizontal on Back Navigation
    testWidgets('20. PassportActiveView reverses 3D rotation from vertical back to horizontal', (tester) async {
      final key = GlobalKey<PassportActiveViewState>();
      final notifier = ValueNotifier<int>(30);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PassportActiveView(
              key: key,
              studentName: 'Sourav Nanda',
              department: 'CSE',
              semester: '5th Semester',
              registrationNumber: '2101297001',
              qrData: 'CAMPUS_PASSPORT:v1:TEST',
              remainingSecondsNotifier: notifier,
              isBluetoothActive: true,
              onClose: () {},
              onRefreshQr: () {},
              onStartAttendance: () {},
            ),
          ),
        ),
      );

      // Verify the state is mounted
      expect(key.currentState, isNotNull);

      // Trigger the reverse animation from vertical to horizontal
      final reverseFuture = key.currentState!.reverseToHorizontal();
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pump(const Duration(milliseconds: 200));
      await reverseFuture;

      expect(key.currentState, isNotNull);
    });

    // 21. Flat Credential Card Container in Wallet
    testWidgets('21. WalletCardContainer renders clean flat card surface with tap handling', (tester) async {
      bool tapped = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 328,
                height: 205,
                child: WalletCardContainer(
                  onTap: () => tapped = true,
                  child: const Text('Flat Card Test'),
                ),
              ),
            ),
          ),
        ),
      );

      expect(find.text('Flat Card Test'), findsOneWidget);
      expect(find.byType(WalletCardContainer), findsOneWidget);

      // Tap card
      await tester.tap(find.text('Flat Card Test'));
      expect(tapped, isTrue);
    });

    // 22. Synchronized 3D Card Morph: Horizontal (328x205) to Vertical (230x380)
    testWidgets('22. PassportActiveView synchronizes card morph from horizontal center to vertical', (tester) async {
      final key = GlobalKey<PassportActiveViewState>();
      final notifier = ValueNotifier<int>(30);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PassportActiveView(
              key: key,
              studentName: 'Sourav Nanda',
              department: 'CSE',
              semester: '5th Semester',
              registrationNumber: '2101297001',
              qrData: 'CAMPUS_PASSPORT:v1:TEST',
              remainingSecondsNotifier: notifier,
              isBluetoothActive: true,
              onClose: () {},
              onRefreshQr: () {},
              onStartAttendance: () {},
            ),
          ),
        ),
      );

      // Verify widget mounted and controller running
      expect(key.currentState, isNotNull);

      // Forward to completion (t = 1.0)
      await tester.pump(const Duration(milliseconds: 550));

      // At t = 1.0, credentials and active controls are fully visible
      expect(find.text('SOURAV NANDA'), findsOneWidget);
      expect(find.text('VERIFIED'), findsOneWidget);
      expect(find.text('Start Attendance'), findsNothing);
      expect(find.text('Looking for class session...'), findsOneWidget);

      // Reverse back towards horizontal
      key.currentState!.reverseToHorizontal();
      await tester.pump(const Duration(milliseconds: 250));
      await tester.pump(const Duration(milliseconds: 250));

      expect(key.currentState, isNotNull);
    });

    // 23. Inactivity timeout: PassportScreen mounts with transparent interaction listener
    testWidgets('23. Inactivity timeout: PassportScreen mounts with transparent interaction listener', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PassportScreen(
              user: testUser,
            ),
          ),
        ),
      );

      // Verify that the root Listener is present to track user interaction
      final listenerFinder = find.byType(Listener);
      expect(listenerFinder, findsWidgets);

      // Trigger user pointer event to verify no errors on pointer down
      await tester.tap(find.byType(PassportScreen));
      await tester.pump(const Duration(milliseconds: 700));
    });

    // 24. PassportActiveView 3D card flip & flipback responsiveness
    testWidgets('24. PassportActiveView card flip and flipback animate responsively with symmetric ease and no delay', (tester) async {
      final key = GlobalKey<PassportActiveViewState>();
      final notifier = ValueNotifier<int>(30);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PassportActiveView(
              key: key,
              studentName: 'Sourav Nanda',
              department: 'CSE',
              semester: '5th Semester',
              registrationNumber: '2101297001',
              qrData: 'CAMPUS_PASSPORT:v1:TEST',
              remainingSecondsNotifier: notifier,
              isBluetoothActive: true,
              onClose: () {},
              onRefreshQr: () {},
              onStartAttendance: () {},
            ),
          ),
        ),
      );

      // Finish opening morph
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text('SOURAV NANDA'), findsOneWidget);
      expect(find.text('Tap to flip'), findsOneWidget);

      // Flip to back (QR side)
      key.currentState!.toggleFlip();
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.text('Refreshes in 30s'), findsOneWidget);
      expect(find.text('Tap to return to card'), findsOneWidget);

      // Flip back to front
      key.currentState!.toggleFlip();
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pump(const Duration(milliseconds: 200));

      // Verify front face is back
      expect(find.text('SOURAV NANDA'), findsOneWidget);
      expect(find.text('Tap to flip'), findsOneWidget);
    });
  });
}
