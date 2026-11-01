import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:attendance_app/auth/models/user_model.dart';
import 'package:attendance_app/student/models/passport_proximity_observation.dart';
import 'package:attendance_app/student/models/passport_verification_result.dart';
import 'package:attendance_app/student/screens/passport_verifier_screen.dart';
import 'package:attendance_app/student/services/passport_verifier_service.dart';

/// Fake verifier service with controllable outcome and call counter.
class FakePassportVerifierService extends PassportVerifierService {
  PassportVerificationResult? nextResult;
  Completer<PassportVerificationResult>? completer;
  int verifyCallCount = 0;

  @override
  Future<PassportVerificationResult> verifyQrString(
    String qrString, {
    PassportProximityObservation? proximityObservation,
  }) async {
    verifyCallCount++;
    if (completer != null) {
      return completer!.future;
    }
    return nextResult ?? PassportVerificationResult.invalidFormat('Mock invalid');
  }
}

void main() {
  group('CampusOS Passport 1E: Verifier Screen Widget Tests', () {
    late FakePassportVerifierService fakeService;
    late MobileScannerController fakeController;

    setUp(() {
      fakeService = FakePassportVerifierService();
      fakeController = MobileScannerController(
        detectionSpeed: DetectionSpeed.noDuplicates,
        autoStart: false,
      );
    });

    tearDown(() {
      fakeController.dispose();
    });

    testWidgets('1. Student role is blocked with Access Restricted view', (tester) async {
      final studentUser = UserModel(
        id: 's1',
        email: 'student@test.com',
        name: 'Student User',
        role: 'student',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: PassportVerifierScreen(
            user: studentUser,
            verifierService: fakeService,
            controller: fakeController,
          ),
        ),
      );

      expect(find.text('Staff & Authority Access Only'), findsOneWidget);
      expect(find.textContaining('Students cannot verify other passports'), findsOneWidget);
      expect(find.byType(MobileScanner), findsNothing);
    });

    testWidgets('2. Staff/Admin role is authorized and displays camera scanner view', (tester) async {
      final adminUser = UserModel(
        id: 'a1',
        email: 'admin@test.com',
        name: 'Admin User',
        role: 'admin',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: PassportVerifierScreen(
            user: adminUser,
            verifierService: fakeService,
            controller: fakeController,
          ),
        ),
      );

      expect(find.text('Verify Passport'), findsOneWidget);
      expect(find.text('Scan a student\'s CampusOS Passport'), findsOneWidget);
      expect(find.text('Point the camera at the Passport QR'), findsOneWidget);
      expect(find.byType(MobileScanner), findsOneWidget);
    });

    testWidgets('3. Valid presentation scan displays green success card with student identity', (tester) async {
      final staffUser = UserModel(
        id: 'st1',
        email: 'staff@test.com',
        name: 'Staff Operator',
        role: 'staff',
      );

      fakeService.nextResult = const PassportVerificationResult(
        valid: true,
        reason: 'VALID',
        userId: 'student-42',
        keyId: 'k1',
        certificateId: 'c1',
        expiresAt: 1774483230,
        user: PassportVerifiedUser(
          name: 'Sourav Nanda',
          branch: 'Computer Science & Engineering',
          year: '5th Semester',
          registrationNumber: 'BPUT-2023-0042',
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: PassportVerifierScreen(
            user: staffUser,
            verifierService: fakeService,
            controller: fakeController,
          ),
        ),
      );

      // Call the internal detection callback
      final mobileScanner = tester.widget<MobileScanner>(find.byType(MobileScanner));
      mobileScanner.onDetect?.call(
        const BarcodeCapture(
          barcodes: [
            Barcode(rawValue: '{"p":{"valid":true},"s":"sig"}'),
          ],
        ),
      );

      await tester.pump(); // Start async verification
      await tester.pump(const Duration(milliseconds: 300)); // Finish animations

      expect(find.text('PASSPORT VALID'), findsOneWidget);
      expect(find.text('SOURAV NANDA'), findsOneWidget);
      expect(find.text('Computer Science & Engineering • 5th Semester'), findsOneWidget);
      expect(find.text('ID: BPUT-2023-0042'), findsOneWidget);
      expect(find.text('KEY ACTIVE'), findsOneWidget);
      expect(find.text('CERTIFICATE ACTIVE'), findsOneWidget);
      expect(find.text('Scan Another Passport'), findsOneWidget);
      expect(fakeService.verifyCallCount, equals(1));
    });

    testWidgets('4. Invalid signature scan displays authoritative error card', (tester) async {
      final wardenUser = UserModel(
        id: 'w1',
        email: 'warden@test.com',
        name: 'Hostel Warden',
        role: 'warden',
      );

      fakeService.nextResult = const PassportVerificationResult(
        valid: false,
        reason: 'INVALID_SIGNATURE',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: PassportVerifierScreen(
            user: wardenUser,
            verifierService: fakeService,
            controller: fakeController,
          ),
        ),
      );

      final mobileScanner = tester.widget<MobileScanner>(find.byType(MobileScanner));
      mobileScanner.onDetect?.call(
        const BarcodeCapture(
          barcodes: [
            Barcode(rawValue: '{"p":{},"s":"bad_sig"}'),
          ],
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('PASSPORT COULD NOT BE VERIFIED'), findsOneWidget);
      expect(find.text('Signature is invalid.'), findsOneWidget);
      expect(find.text('STATUS: INVALID_SIGNATURE'), findsOneWidget);
      expect(find.text('Scan Again'), findsOneWidget);
    });

    testWidgets('5. Expired presentation scan displays expired error card', (tester) async {
      final teacherUser = UserModel(
        id: 't1',
        email: 'teacher@test.com',
        name: 'Teacher 1',
        role: 'teacher',
      );

      fakeService.nextResult = const PassportVerificationResult(
        valid: false,
        reason: 'PRESENTATION_EXPIRED',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: PassportVerifierScreen(
            user: teacherUser,
            verifierService: fakeService,
            controller: fakeController,
          ),
        ),
      );

      final mobileScanner = tester.widget<MobileScanner>(find.byType(MobileScanner));
      mobileScanner.onDetect?.call(
        const BarcodeCapture(
          barcodes: [
            Barcode(rawValue: '{"p":{},"s":"expired_sig"}'),
          ],
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('PASSPORT PRESENTATION EXPIRED'), findsOneWidget);
      expect(find.text('Ask the student to refresh their Passport QR.'), findsOneWidget);
      expect(find.text('STATUS: PRESENTATION_EXPIRED'), findsOneWidget);
    });

    testWidgets('6. Revoked key presentation displays revoked error card', (tester) async {
      final staffUser = UserModel(
        id: 'st1',
        email: 'staff@test.com',
        name: 'Staff Operator',
        role: 'staff',
      );

      fakeService.nextResult = const PassportVerificationResult(
        valid: false,
        reason: 'REVOKED_KEY',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: PassportVerifierScreen(
            user: staffUser,
            verifierService: fakeService,
            controller: fakeController,
          ),
        ),
      );

      final mobileScanner = tester.widget<MobileScanner>(find.byType(MobileScanner));
      mobileScanner.onDetect?.call(
        const BarcodeCapture(
          barcodes: [
            Barcode(rawValue: '{"p":{},"s":"revoked_sig"}'),
          ],
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('PASSPORT IDENTITY REVOKED'), findsOneWidget);
      expect(find.text('This identity is no longer active.'), findsOneWidget);
      expect(find.text('STATUS: REVOKED_KEY'), findsOneWidget);
    });

    testWidgets('7. Network error displays verification unavailable without false invalid claims', (tester) async {
      final staffUser = UserModel(
        id: 'st1',
        email: 'staff@test.com',
        name: 'Staff Operator',
        role: 'staff',
      );

      fakeService.nextResult = PassportVerificationResult.networkError();

      await tester.pumpWidget(
        MaterialApp(
          home: PassportVerifierScreen(
            user: staffUser,
            verifierService: fakeService,
            controller: fakeController,
          ),
        ),
      );

      final mobileScanner = tester.widget<MobileScanner>(find.byType(MobileScanner));
      mobileScanner.onDetect?.call(
        const BarcodeCapture(
          barcodes: [
            Barcode(rawValue: '{"p":{},"s":"net_sig"}'),
          ],
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('VERIFICATION UNAVAILABLE'), findsOneWidget);
      expect(find.text('Connect to the CampusOS server and try again.'), findsOneWidget);
      expect(find.text('STATUS: NETWORK_ERROR'), findsOneWidget);
    });

    testWidgets('8. Scan Again resets result and restores camera scanner view cleanly', (tester) async {
      final adminUser = UserModel(
        id: 'a1',
        email: 'admin@test.com',
        name: 'Admin User',
        role: 'admin',
      );

      fakeService.nextResult = const PassportVerificationResult(
        valid: false,
        reason: 'INVALID_SIGNATURE',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: PassportVerifierScreen(
            user: adminUser,
            verifierService: fakeService,
            controller: fakeController,
          ),
        ),
      );

      final mobileScanner = tester.widget<MobileScanner>(find.byType(MobileScanner));
      mobileScanner.onDetect?.call(
        const BarcodeCapture(
          barcodes: [
            Barcode(rawValue: '{"p":{},"s":"bad_sig"}'),
          ],
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Scan Again'), findsOneWidget);

      // Tap Scan Again
      await tester.tap(find.text('Scan Again'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Restores scanner view!
      expect(find.text('Point the camera at the Passport QR'), findsOneWidget);
      expect(find.byType(MobileScanner), findsOneWidget);
    });

    testWidgets('9. Duplicate scan callbacks while verification is underway are suppressed', (tester) async {
      final adminUser = UserModel(
        id: 'a1',
        email: 'admin@test.com',
        name: 'Admin User',
        role: 'admin',
      );

      final completer = Completer<PassportVerificationResult>();
      fakeService.completer = completer;

      await tester.pumpWidget(
        MaterialApp(
          home: PassportVerifierScreen(
            user: adminUser,
            verifierService: fakeService,
            controller: fakeController,
          ),
        ),
      );

      final mobileScanner = tester.widget<MobileScanner>(find.byType(MobileScanner));

      // Trigger multiple rapid detections
      mobileScanner.onDetect?.call(
        const BarcodeCapture(
          barcodes: [
            Barcode(rawValue: '{"p":{},"s":"sig1"}'),
          ],
        ),
      );
      mobileScanner.onDetect?.call(
        const BarcodeCapture(
          barcodes: [
            Barcode(rawValue: '{"p":{},"s":"sig2"}'),
          ],
        ),
      );
      mobileScanner.onDetect?.call(
        const BarcodeCapture(
          barcodes: [
            Barcode(rawValue: '{"p":{},"s":"sig3"}'),
          ],
        ),
      );

      await tester.pump();
      expect(find.text('Verifying Passport...'), findsOneWidget);

      // Complete async verification
      completer.complete(const PassportVerificationResult(valid: true, reason: 'VALID'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Only ONE network verification call was initiated!
      expect(fakeService.verifyCallCount, equals(1));

      // Cleanly unmount widget
      await tester.pumpWidget(const SizedBox());
    });
  });
}
