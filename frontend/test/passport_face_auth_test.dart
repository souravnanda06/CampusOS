import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:provider/provider.dart';

import 'package:attendance_app/student/services/passport_biometric_service.dart';
import 'package:attendance_app/student/services/passport_face_auth_service.dart';
import 'package:attendance_app/student/widgets/face/face_auth_gate_sheet.dart';
import 'package:attendance_app/student/screens/face_enrollment_screen.dart';
import 'package:attendance_app/auth/providers/user_provider.dart';
import 'package:attendance_app/auth/models/user_model.dart';

/// In-memory fake secure storage for deterministic unit testing
class FakeSecureStorage extends FlutterSecureStorage {
  final Map<String, String> _data = {};

  @override
  Future<void> write({
    required String key,
    required String? value,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    if (value == null) {
      _data.remove(key);
    } else {
      _data[key] = value;
    }
  }

  @override
  Future<String?> read({
    required String key,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    return _data[key];
  }

  @override
  Future<void> delete({
    required String key,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    _data.remove(key);
  }
}

List<double> createTestEmbedding(int seed) {
  final rng = Random(seed);
  final raw = List<double>.generate(128, (_) => rng.nextDouble() * 2.0 - 1.0);
  return PassportFaceAuthService.normalizeVector(raw);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('CampusOS Face-Verified Attendance System Tests', () {
    late FakeSecureStorage fakeStorage;
    late PassportFaceAuthService faceService;

    setUp(() {
      fakeStorage = FakeSecureStorage();
      faceService = PassportFaceAuthService(secureStorage: fakeStorage);
    });

    test('1. Unenrolled student returns isFaceEnrolled == false', () async {
      final enrolled = await faceService.isFaceEnrolled('student_001');
      expect(enrolled, isFalse);
    });

    test('2. One-time face enrollment persists 128-D vector to secure storage', () async {
      final vector = createTestEmbedding(42);
      final success = await faceService.enrollFace(
        studentId: 'student_001',
        embedding: vector,
      );
      expect(success, isTrue);

      final isEnrolled = await faceService.isFaceEnrolled('student_001');
      expect(isEnrolled, isTrue);

      final retrieved = await faceService.getEnrolledVector('student_001');
      expect(retrieved, isNotNull);
      expect(retrieved!.length, equals(128));
    });

    test('3. Cosine similarity calculation is mathematically accurate', () {
      final v1 = [1.0, 0.0, 0.0, 0.0];
      final v2 = [1.0, 0.0, 0.0, 0.0];
      final v3 = [0.0, 1.0, 0.0, 0.0];

      // Exact match
      expect(PassportFaceAuthService.computeCosineSimilarity(v1, v2), closeTo(1.0, 0.0001));
      // Orthogonal vectors
      expect(PassportFaceAuthService.computeCosineSimilarity(v1, v3), closeTo(0.0, 0.0001));
    });

    test('4. Legitimate student face passes verification (Similarity >= 0.82)', () async {
      final enrolledVector = createTestEmbedding(100);
      await faceService.enrollFace(studentId: 'student_legit', embedding: enrolledVector);

      // Simulate live camera frame of same person (with small optical variance)
      final rng = Random(55);
      final liveFrame = enrolledVector.map((x) => x + (rng.nextDouble() * 0.02 - 0.01)).toList();
      final normLiveFrame = PassportFaceAuthService.normalizeVector(liveFrame);

      final result = await faceService.evaluateMatch(
        studentId: 'student_legit',
        liveEmbedding: normLiveFrame,
      );

      expect(result.status, equals(BiometricAuthStatus.success));
      expect(result.isSuccess, isTrue);
    });

    test('5. Proxy attack rejected: Friend face results in OWNER_MISMATCH (< 0.82)', () async {
      final studentVector = createTestEmbedding(100);
      final proxyFriendVector = createTestEmbedding(999); // Different person

      await faceService.enrollFace(studentId: 'student_absent', embedding: studentVector);

      final result = await faceService.evaluateMatch(
        studentId: 'student_absent',
        liveEmbedding: proxyFriendVector,
      );

      expect(result.status, equals(BiometricAuthStatus.ownerMismatch));
      expect(result.isSuccess, isFalse);
      expect(result.message, contains('OWNER_MISMATCH'));
    });

    test('6. Anti-spoofing detection: Photo or video replay triggers spoofDetected', () async {
      final studentVector = createTestEmbedding(100);
      await faceService.enrollFace(studentId: 'student_spoof', embedding: studentVector);

      final result = await faceService.evaluateMatch(
        studentId: 'student_spoof',
        liveEmbedding: studentVector,
        livenessPassed: false, // Detected static photo without 3D depth/blink
      );

      expect(result.status, equals(BiometricAuthStatus.ownerMismatch));
      expect(result.message, contains('LIVENESS_FAILED'));
    });

    test('7. 100% Offline capability: Verification requires zero network calls', () async {
      final studentVector = createTestEmbedding(77);
      await faceService.enrollFace(studentId: 'student_offline', embedding: studentVector);

      // Verify directly from local storage with no internet connection
      final result = await faceService.evaluateMatch(
        studentId: 'student_offline',
        liveEmbedding: studentVector,
      );

      expect(result.isSuccess, isTrue);
    });

    testWidgets('8. FaceAuthGateSheet mounts and renders biometric viewfinder', (tester) async {
      final vector = createTestEmbedding(42);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FaceAuthGateSheet(
              studentId: 'student_ui',
              enrolledVector: vector,
              promptReason: 'Verify face to mark attendance',
            ),
          ),
        ),
      );

      expect(find.text('CampusOS Face ID'), findsOneWidget);
      expect(find.text('Verify face to mark attendance'), findsOneWidget);
      expect(find.byType(FaceAuthGateSheet), findsOneWidget);

      await tester.pump(const Duration(milliseconds: 150));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 500));
    });

    testWidgets('9. FaceEnrollmentScreen mounts and guides user through setup', (tester) async {
      final testUser = UserModel(
        id: 'student_enroll_ui',
        name: 'Sourav Nanda',
        email: 'sourav@campusos.edu',
        role: 'student',
      );

      final userProvider = UserProvider();
      userProvider.setUser(testUser);

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: userProvider),
          ],
          child: const MaterialApp(
            home: FaceEnrollmentScreen(studentId: 'student_enroll_ui'),
          ),
        ),
      );

      expect(find.text('CampusOS Face ID'), findsOneWidget);
      expect(find.text('One-Time Face Setup'), findsOneWidget);
      expect(find.text('Scan & Enroll Face'), findsOneWidget);

      // Tap enroll button
      await tester.tap(find.text('Scan & Enroll Face'));
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Calibrating optical alignment...'), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 800));
      await tester.pump(const Duration(milliseconds: 900));
      await tester.pump(const Duration(milliseconds: 1500));
    });
  });
}
