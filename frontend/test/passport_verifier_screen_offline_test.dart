import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import 'package:attendance_app/auth/models/user_model.dart';
import 'package:attendance_app/student/models/passport_proximity_observation.dart';
import 'package:attendance_app/student/models/passport_verification_result.dart';
import 'package:attendance_app/student/screens/passport_verifier_screen.dart';
import 'package:attendance_app/student/services/passport_crypto_service.dart';
import 'package:attendance_app/student/services/passport_offline_verifier_service.dart';
import 'package:attendance_app/student/services/passport_trust_bundle_service.dart';
import 'package:attendance_app/student/services/passport_verifier_service.dart';

class FakePassportKeyStorage implements PassportKeyStorage {
  final Map<String, String> _data = {};

  @override
  Future<String?> read(String key) async => _data[key];

  @override
  Future<void> write(String key, String value) async => _data[key] = value;

  @override
  Future<void> delete(String key) async => _data.remove(key);

  @override
  Future<bool> containsKey(String key) async => _data.containsKey(key);
}

class FakeVerifierService extends PassportVerifierService {
  int verifyCallCount = 0;
  PassportVerificationResult? nextResult;

  @override
  Future<PassportVerificationResult> verifyQrString(
    String qrString, {
    PassportProximityObservation? proximityObservation,
  }) async {
    verifyCallCount++;
    return nextResult ??
        const PassportVerificationResult(
          valid: true,
          reason: 'VALID',
          verificationSource: 'ONLINE',
        );
  }
}

class FakeOfflineVerifierService extends PassportOfflineVerifierService {
  int offlineVerifyCallCount = 0;
  PassportVerificationResult? nextResult;

  FakeOfflineVerifierService({PassportTrustBundleService? bundleService})
      : super(bundleService: bundleService);

  @override
  Future<PassportVerificationResult> verifyOffline({
    required String qrPayload,
    int? currentTimestampSeconds,
    int maxClockSkewSeconds = 30,
  }) async {
    offlineVerifyCallCount++;
    return nextResult ??
        PassportVerificationResult(
          valid: true,
          reason: 'OFFLINE_VALID',
          verificationSource: 'OFFLINE',
          userId: 'u_student_123',
          keyId: 'dev_key_001',
          certificateId: 'cert_001',
          trustSnapshotTime: DateTime.now().toUtc().millisecondsSinceEpoch ~/ 1000 - 1080, // 18 mins ago
          user: const PassportVerifiedUser(
            name: 'Priya Sharma',
            registrationNumber: 'BPUT-2023-0042',
            branch: 'Computer Science & Engineering',
            year: '5th Semester',
          ),
        );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeVerifierService fakeOnlineService;
  late FakeOfflineVerifierService fakeOfflineService;
  late MobileScannerController fakeController;

  final authorizedStaff = UserModel(
    id: 'staff_1',
    email: 'staff@bput.ac.in',
    name: 'Gate Supervisor',
    role: 'staff',
  );

  setUp(() {
    fakeOnlineService = FakeVerifierService();
    fakeOfflineService = FakeOfflineVerifierService();
    fakeController = MobileScannerController(
      detectionSpeed: DetectionSpeed.noDuplicates,
      autoStart: false,
    );
  });

  tearDown(() {
    fakeController.dispose();
  });

  group('CampusOS Passport 1F: Verifier Screen Offline Tests', () {
    testWidgets('1. Switch between ONLINE and OFFLINE modes updates UI state and descriptions', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: PassportVerifierScreen(
            user: authorizedStaff,
            verifierService: fakeOnlineService,
            offlineVerifierService: fakeOfflineService,
            controller: fakeController,
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Initially ONLINE
      expect(find.text('ONLINE'), findsOneWidget);
      expect(find.text('OFFLINE'), findsOneWidget);
      expect(find.text('Connected verification'), findsOneWidget);

      // Tap OFFLINE segment
      await tester.tap(find.text('OFFLINE'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Uses last trusted campus snapshot'), findsOneWidget);
    });

    testWidgets('2. Offline valid scan executes with ZERO ApiClient calls and displays snapshot metadata and limitation', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: PassportVerifierScreen(
            user: authorizedStaff,
            verifierService: fakeOnlineService,
            offlineVerifierService: fakeOfflineService,
            controller: fakeController,
            initialOfflineMode: true,
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      final mobileScanner = tester.widget<MobileScanner>(find.byType(MobileScanner));
      mobileScanner.onDetect?.call(
        const BarcodeCapture(
          barcodes: [
            Barcode(rawValue: '{"p":{},"s":"offline_sig"}'),
          ],
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Offline service called, online service NEVER called
      expect(fakeOfflineService.offlineVerifyCallCount, equals(1));
      expect(fakeOnlineService.verifyCallCount, equals(0));

      // Valid presentation displayed with student details
      expect(find.text('PASSPORT VALID'), findsOneWidget);
      expect(find.text('OFFLINE VERIFICATION'), findsOneWidget);
      expect(find.text('PRIYA SHARMA'), findsOneWidget);
      expect(find.text('ID: BPUT-2023-0042'), findsOneWidget);
      expect(find.text('Computer Science & Engineering • 5th Semester'), findsOneWidget);

      // Snapshot time indicator
      expect(find.textContaining('updated 18 mins ago'), findsOneWidget);

      // Cryptographic guarantees
      expect(find.text('Cryptographic signature valid'), findsOneWidget);
      expect(find.text('Institution certificate valid'), findsOneWidget);
      expect(find.text('Identity key trusted'), findsOneWidget);

      // Explicit revocation limitation disclaimer
      expect(
        find.textContaining('Verified against CampusOS trust snapshot'),
        findsOneWidget,
      );
      expect(
        find.textContaining('Does not reflect real-time revocations occurring after snapshot'),
        findsOneWidget,
      );
    });

    testWidgets('3. Offline scan with expired trust data displays clear warning and download prompt', (tester) async {
      fakeOfflineService.nextResult = PassportVerificationResult.offlineTrustDataExpired();

      await tester.pumpWidget(
        MaterialApp(
          home: PassportVerifierScreen(
            user: authorizedStaff,
            verifierService: fakeOnlineService,
            offlineVerifierService: fakeOfflineService,
            controller: fakeController,
            initialOfflineMode: true,
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      final mobileScanner = tester.widget<MobileScanner>(find.byType(MobileScanner));
      mobileScanner.onDetect?.call(
        const BarcodeCapture(
          barcodes: [
            Barcode(rawValue: '{"p":{},"s":"expired_trust_sig"}'),
          ],
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('TRUST DATA EXPIRED'), findsOneWidget);
      expect(
        find.text('Offline verification data has expired. Connect to CampusOS to refresh.'),
        findsOneWidget,
      );
      expect(find.text('Download Trust Data'), findsOneWidget);
      expect(fakeOnlineService.verifyCallCount, equals(0));
    });

    testWidgets('4. Offline scan with missing trust bundle displays missing trust data card', (tester) async {
      fakeOfflineService.nextResult = PassportVerificationResult.offlineTrustDataMissing();

      await tester.pumpWidget(
        MaterialApp(
          home: PassportVerifierScreen(
            user: authorizedStaff,
            verifierService: fakeOnlineService,
            offlineVerifierService: fakeOfflineService,
            controller: fakeController,
            initialOfflineMode: true,
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      final mobileScanner = tester.widget<MobileScanner>(find.byType(MobileScanner));
      mobileScanner.onDetect?.call(
        const BarcodeCapture(
          barcodes: [
            Barcode(rawValue: '{"p":{},"s":"missing_trust_sig"}'),
          ],
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('TRUST DATA MISSING'), findsOneWidget);
      expect(
        find.text('No local trust bundle found. Connect to CampusOS to download verification data.'),
        findsOneWidget,
      );
      expect(find.text('Download Trust Data'), findsOneWidget);
    });

    testWidgets('5. Trust bundle bottom sheet displays bundle metadata and action buttons', (tester) async {
      final inMemoryStorage = FakePassportKeyStorage();
      final bundleService = PassportTrustBundleService(storage: inMemoryStorage);

      await tester.pumpWidget(
        MaterialApp(
          home: PassportVerifierScreen(
            user: authorizedStaff,
            verifierService: fakeOnlineService,
            offlineVerifierService: fakeOfflineService,
            trustBundleService: bundleService,
            controller: fakeController,
            initialOfflineMode: true,
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Tap Trust Bundle button in AppBar to open Trust Data sheet
      final trustButton = find.byTooltip('Trust Bundle');
      expect(trustButton, findsOneWidget);
      await tester.tap(trustButton);
      await tester.pump();
      await tester.pumpAndSettle();

      // Sheet is presented
      expect(find.text('Passport Trust Data'), findsOneWidget);
      expect(find.text('Refresh Trust Data'), findsOneWidget);
      expect(find.text('Verify Bundle'), findsOneWidget);
    });
  });
}
