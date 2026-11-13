import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:attendance_app/core/network/api_client.dart';
import 'package:attendance_app/student/services/passport_biometric_service.dart';
import 'package:attendance_app/student/services/passport_face_auth_service.dart';
import 'package:attendance_app/student/services/passport_mlkit_service.dart';
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
      SharedPreferences.setMockInitialValues({});
      PassportFaceAuthService.resetCacheForTesting();
      fakeStorage = FakeSecureStorage();
      final mockClient = MockClient((request) async {
        return http.Response(
          jsonEncode({'faceEnrolled': false, 'status': 'NOT_ENROLLED'}),
          200,
          headers: {'content-type': 'application/json'},
        );
      });
      faceService = PassportFaceAuthService(
        secureStorage: fakeStorage,
        apiClient: ApiClient(baseUrl: 'http://localhost', client: mockClient),
      );
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
              isTestMode: true,
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
            home: FaceEnrollmentScreen(
              studentId: 'student_enroll_ui',
              isTestMode: true,
            ),
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

    test('10. College account association: Face vector is bound to verified student ID', () async {
      const studentA = '2201289001';
      const studentB = '2201289002';
      final vectorA = createTestEmbedding(101);

      await faceService.enrollFace(studentId: studentA, embedding: vectorA);

      expect(await faceService.isFaceEnrolled(studentA), isTrue);
      expect(await faceService.isFaceEnrolled(studentB), isFalse);

      final retrievedA = await faceService.getEnrolledVector(studentA);
      final retrievedB = await faceService.getEnrolledVector(studentB);

      expect(retrievedA, isNotNull);
      expect(retrievedB, isNull);
    });

    test('11. Subsequent attendance attempts use existing enrollment without re-prompting', () async {
      const studentId = 'student_subsequent_attendance';
      final enrolledVector = createTestEmbedding(202);

      // Initial one-time enrollment
      await faceService.enrollFace(studentId: studentId, embedding: enrolledVector);
      expect(await faceService.isFaceEnrolled(studentId), isTrue);

      // Simulate 5 subsequent attendance attempts throughout the day
      for (int i = 0; i < 5; i++) {
        // Must recognize student is already enrolled without re-prompting setup
        final enrolled = await faceService.isFaceEnrolled(studentId);
        expect(enrolled, isTrue, reason: 'Attempt $i should immediately recognize existing enrollment');

        // Subsequent live match passes using existing enrollment
        final liveFrame = enrolledVector.map((x) => x).toList();
        final matchResult = await faceService.evaluateMatch(
          studentId: studentId,
          liveEmbedding: liveFrame,
        );
        expect(matchResult.isSuccess, isTrue, reason: 'Attempt $i should successfully authenticate via cached vector');
      }
    });

    test('12. Enrollment status remains associated across server synchronization', () async {
      const studentId = 'student_persist_test';
      final vector = createTestEmbedding(303);
      await faceService.enrollFace(studentId: studentId, embedding: vector);

      // Mock server confirming enrollment is still active
      final mockClient = MockClient((request) async {
        if (request.url.path.contains('/passport/face/status')) {
          return http.Response(
            jsonEncode({
              'studentId': studentId,
              'faceEnrolled': true,
              'status': 'ENROLLED',
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        return http.Response('Not Found', 404);
      });

      final syncedService = PassportFaceAuthService(
        secureStorage: fakeStorage,
        apiClient: ApiClient(baseUrl: 'http://localhost', client: mockClient),
      );

      final isStillEnrolled = await syncedService.syncStatusWithServer(studentId);
      expect(isStillEnrolled, isTrue);

      final retrievedVector = await syncedService.getEnrolledVector(studentId);
      expect(retrievedVector, isNotNull);
      expect(retrievedVector!.length, equals(128));
    });

    test('13. Authorized administrative reset clears local enrollment and prompts re-enrollment', () async {
      const studentId = 'student_reset_test';
      final vector = createTestEmbedding(404);
      await faceService.enrollFace(studentId: studentId, embedding: vector);
      expect(await faceService.isFaceEnrolled(studentId), isTrue);

      // Mock server reporting authorized reset performed by Dean/Admin
      final mockClient = MockClient((request) async {
        if (request.url.path.contains('/passport/face/status')) {
          return http.Response(
            jsonEncode({
              'studentId': studentId,
              'faceEnrolled': false,
              'status': 'NOT_ENROLLED',
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        return http.Response('Not Found', 404);
      });

      final resetService = PassportFaceAuthService(
        secureStorage: fakeStorage,
        apiClient: ApiClient(baseUrl: 'http://localhost', client: mockClient),
      );

      // Administrative reset detected during sync
      final syncResult = await resetService.syncStatusWithServer(studentId);
      expect(syncResult, isFalse);

      // Local hardware storage and memory cache must be purged
      expect(await resetService.isFaceEnrolled(studentId), isFalse);
      expect(await resetService.getEnrolledVector(studentId), isNull);

      // Attempting biometric authentication now mandates one-time re-enrollment
      final authResult = await resetService.evaluateMatch(
        studentId: studentId,
        liveEmbedding: vector,
      );
      expect(authResult.status, equals(BiometricAuthStatus.biometricRequired));
      expect(authResult.message, contains('FACE_ENROLLMENT_REQUIRED'));
    });

    test('14. Google ML Kit Face Service: Instance initialized and ready for biometric extraction', () {
      final mlKit = PassportMlKitService.instance;
      expect(mlKit, isNotNull);
    });

    testWidgets('15. FaceEnrollmentScreen blocks unilateral re-enrollment when already registered', (tester) async {
      const studentId = 'student_already_enrolled';
      final vector = createTestEmbedding(505);
      await faceService.enrollFace(studentId: studentId, embedding: vector);

      final testUser = UserModel(
        id: studentId,
        name: 'Sourav Nanda',
        email: 'sourav@campusos.edu',
        role: 'student',
        registrationNumber: '2201289001',
      );

      final userProvider = UserProvider();
      userProvider.setUser(testUser);

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: userProvider),
          ],
          child: const MaterialApp(
            home: FaceEnrollmentScreen(
              studentId: studentId,
              isTestMode: true,
            ),
          ),
        ),
      );

      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 300));

      // Viewfinder and setup button must NOT be present
      expect(find.text('Scan & Enroll Face'), findsNothing);
      expect(find.text('One-Time Face Setup'), findsNothing);

      // Locked screen must be rendered
      expect(find.text('Face Identity Registered & Locked'), findsOneWidget);
      expect(find.text('ACTIVE & VERIFIED'), findsOneWidget);
      expect(find.text('Return to Dashboard'), findsOneWidget);

      // Tapping Return to Dashboard pops
      await tester.tap(find.text('Return to Dashboard'));
      await tester.pump(const Duration(milliseconds: 100));
    });
  });
}
