import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:attendance_app/student/widgets/face/face_auth_gate_sheet.dart';
import 'package:attendance_app/student/services/passport_biometric_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Apple Face ID Gate Sheet Design & Interaction Tests', () {
    const studentId = 'student_test_apple_design';
    final dummyVector = List<double>.generate(128, (i) => (i % 2 == 0 ? 0.08 : -0.08));

    testWidgets('Renders all Apple HIG components matching user design mockup', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FaceAuthGateSheet(
              studentId: studentId,
              enrolledVector: dummyVector,
              promptReason: 'Verify face to unlock Campus Passport',
              isTestMode: true,
            ),
          ),
        ),
      );

      // Verify Header Badge, Title and Subtitle
      expect(find.text('CampusOS Face ID'), findsOneWidget);
      expect(find.text('Verify face to unlock Campus Passport'), findsOneWidget);

      // Verify Status Capsule
      expect(find.text('Verifying identity & liveness...'), findsOneWidget);

      // Verify Privacy & Hardware Enclave Footnote
      expect(find.byIcon(Icons.lock_rounded), findsOneWidget);
      expect(find.textContaining('100% On-Device · Hardware Enclave Protected'), findsOneWidget);
      expect(find.textContaining('Zero Photos Stored'), findsOneWidget);

      // Verify HIG 44pt Cancel Action
      expect(find.text('Cancel'), findsOneWidget);

      // Tap Cancel button
      await tester.tap(find.text('Cancel'));
      await tester.pump(const Duration(milliseconds: 100));
    });

    testWidgets('Tapping Cancel pops with BiometricAuthResult.cancelled', (tester) async {
      BiometricAuthResult? poppedResult;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (ctx) => ElevatedButton(
                onPressed: () async {
                  poppedResult = await showModalBottomSheet<BiometricAuthResult>(
                    context: ctx,
                    isScrollControlled: true,
                    backgroundColor: Colors.transparent,
                    builder: (modalCtx) => FaceAuthGateSheet(
                      studentId: studentId,
                      enrolledVector: dummyVector,
                      isTestMode: true,
                    ),
                  );
                },
                child: const Text('Open Sheet'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Sheet'));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('CampusOS Face ID'), findsOneWidget);

      await tester.tap(find.text('Cancel'));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

      expect(poppedResult, equals(BiometricAuthResult.cancelled));
    });
  });
}
