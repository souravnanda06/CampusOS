import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:attendance_app/auth/models/user_model.dart';
import 'package:attendance_app/auth/services/auth_service.dart';
import 'package:attendance_app/core/network/api_client.dart';
import 'package:attendance_app/student/models/passport_identity_model.dart';
import 'package:attendance_app/student/services/passport_crypto_service.dart';
import 'package:attendance_app/student/services/passport_presentation_service.dart';
import 'package:attendance_app/student/services/passport_identity_service.dart';

/// Fake in-memory key storage for testing offline restoration
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

  void clear() => _data.clear();
}

/// Mock HTTP client for PassportIdentityService unit testing
class FakeHttpClient extends http.BaseClient {
  http.Response Function(http.Request request)? handler;
  final List<http.Request> recordedRequests = [];

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    if (request is http.Request) {
      recordedRequests.add(request);
      if (handler != null) {
        final res = handler!(request);
        return http.StreamedResponse(
          Stream.value(res.bodyBytes),
          res.statusCode,
          headers: res.headers,
        );
      }
    }
    return http.StreamedResponse(
      Stream.value(utf8.encode('{"message":"Default mock response"}')),
      200,
    );
  }
}

/// Fake AuthService to simulate authenticated and unauthenticated sessions
class FakeAuthService extends AuthService {
  final UserModel? _fakeUser;
  final UserModel? _fakeStorageUser;

  FakeAuthService({UserModel? currentUser, UserModel? storageUser})
      : _fakeUser = currentUser,
        _fakeStorageUser = storageUser;

  @override
  UserModel? get currentUser => _fakeUser;

  @override
  Future<UserModel?> getUserDataFromStorage() async {
    return _fakeUser ?? _fakeStorageUser;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('CampusOS Passport — Enrollment Authentication & X-User-Id Tests', () {
    late FakeHttpClient fakeHttp;
    late ApiClient apiClient;
    late FakePassportKeyStorage storage;

    final testStudent = UserModel(
      id: 'student-canonical-uuid-42',
      email: 'student42@campusos.edu',
      name: 'Sourav Nanda',
      role: 'student',
      registrationNumber: 'REG-2023-CS-042',
      course: 'B.Tech',
      branch: 'CSE',
      year: '3rd Year',
    );

    const testPublicKeyB64 = 'u8i87w3eWzN6eO8qP0rT4uV2wX1yZ3aB5cD7eF9gH1j=';

    setUp(() {
      fakeHttp = FakeHttpClient();
      storage = FakePassportKeyStorage();
      apiClient = ApiClient(
        baseUrl: 'http://127.0.0.1:5000',
        client: fakeHttp,
      );
    });

    test('1. activate Passport sends correct X-User-Id header and canonical body userId', () async {
      final fakeAuth = FakeAuthService(currentUser: testStudent);
      final service = PassportIdentityService(
        apiClient: apiClient,
        authService: fakeAuth,
        storage: storage,
      );

      fakeHttp.handler = (request) {
        if (request.url.path == '/passport/keys/register' && request.method == 'POST') {
          // Verify authentication header
          expect(request.headers['X-User-Id'], equals('student-canonical-uuid-42'));
          expect(request.headers['Content-Type'], contains('application/json'));

          // Verify body contains canonical user id and public key
          final body = jsonDecode(request.body);
          expect(body['userId'], equals('student-canonical-uuid-42'));
          expect(body['publicKey'], equals(testPublicKeyB64));
          expect(body['keyType'], equals('ED25519'));

          return http.Response(
            jsonEncode({
              'keyId': 'key-uuid-101',
              'status': 'ACTIVE',
              'publicKey': testPublicKeyB64,
              'keyType': 'ED25519',
              'certificate': {
                'id': 'cert-uuid-202',
                'keyId': 'key-uuid-101',
                'userId': 'student-canonical-uuid-42',
                'publicKey': testPublicKeyB64,
                'status': 'ACTIVE',
                'validFrom': '2026-09-26T00:00:00Z',
                'validTo': '2027-09-26T00:00:00Z',
                'issuer': 'CampusOS',
                'issuerKeyId': 'institution-root-key-1',
                'signature': 'test-sig-b64',
                'payload': {
                  'subject': {'userId': 'student-canonical-uuid-42'},
                }
              }
            }),
            201,
            headers: {'content-type': 'application/json'},
          );
        }
        return http.Response('{"message":"Not Found"}', 404);
      };

      final result = await service.registerKey(
        publicKey: testPublicKeyB64,
        userId: testStudent.id,
      );

      expect(result.id, equals('key-uuid-101'));
      expect(result.status, equals('ACTIVE'));
      expect(result.isActive, isTrue);
      expect(result.certificate, isNotNull);
      expect(result.certificate!.userId, equals('student-canonical-uuid-42'));
      expect(result.certificate!.status, equals('ACTIVE'));
      expect(result.certificate!.isActive, isTrue);
      expect(fakeHttp.recordedRequests.length, equals(1));
    });

    test('2. getIdentity sends X-User-Id header and returns enrolled status', () async {
      final fakeAuth = FakeAuthService(currentUser: testStudent);
      final service = PassportIdentityService(
        apiClient: apiClient,
        authService: fakeAuth,
        storage: storage,
      );

      fakeHttp.handler = (request) {
        if (request.url.path == '/passport/identity' && request.method == 'GET') {
          expect(request.headers['X-User-Id'], equals('student-canonical-uuid-42'));

          return http.Response(
            jsonEncode({
              'enrolled': true,
              'key': {
                'id': 'key-uuid-101',
                'userId': 'student-canonical-uuid-42',
                'publicKey': testPublicKeyB64,
                'keyType': 'ED25519',
                'status': 'ACTIVE',
              },
              'certificate': {
                'id': 'cert-uuid-202',
                'keyId': 'key-uuid-101',
                'userId': 'student-canonical-uuid-42',
                'publicKey': testPublicKeyB64,
                'status': 'ACTIVE',
                'validFrom': '2026-09-26T00:00:00Z',
                'validTo': '2027-09-26T00:00:00Z',
                'issuer': 'CampusOS',
                'issuerKeyId': 'institution-root-key-1',
                'signature': 'test-sig-b64',
              }
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        return http.Response('{"message":"Not Found"}', 404);
      };

      final status = await service.getIdentity(userId: testStudent.id);

      expect(status.enrolled, isTrue);
      expect(status.key, isNotNull);
      expect(status.key!.isActive, isTrue);
      expect(status.certificate, isNotNull);
      expect(status.certificate!.isActive, isTrue);
      expect(fakeHttp.recordedRequests.length, equals(1));
    });

    test('3. missing session throws authentication error and blocks unauthenticated enrollment', () async {
      // Empty auth service — no user in memory, no user in storage
      final fakeAuth = FakeAuthService(currentUser: null, storageUser: null);
      final service = PassportIdentityService(
        apiClient: apiClient,
        authService: fakeAuth,
        storage: storage,
      );

      // registerKey without session must fail immediately without making unauthenticated request
      expect(
        () => service.registerKey(publicKey: testPublicKeyB64),
        throwsA(isA<Exception>().having(
          (e) => e.toString(),
          'message',
          contains('Authentication required: Missing X-User-Id header'),
        )),
      );

      // No request should be made to the network
      expect(fakeHttp.recordedRequests.isEmpty, isTrue);

      // getIdentity without session must return enrolled=false safely
      final status = await service.getIdentity();
      expect(status.enrolled, isFalse);
      expect(fakeHttp.recordedRequests.isEmpty, isTrue);
    });

    test('4. automatic resolution from AuthService storage when currentUser is not in memory', () async {
      // User is stored in persistent storage (e.g. after app cold start)
      final fakeAuth = FakeAuthService(currentUser: null, storageUser: testStudent);
      final service = PassportIdentityService(
        apiClient: apiClient,
        authService: fakeAuth,
        storage: storage,
      );

      fakeHttp.handler = (request) {
        if (request.url.path == '/passport/keys/register') {
          expect(request.headers['X-User-Id'], equals('student-canonical-uuid-42'));
          return http.Response(
            jsonEncode({
              'keyId': 'key-from-storage',
              'status': 'ACTIVE',
              'publicKey': testPublicKeyB64,
              'keyType': 'ED25519',
              'certificate': null,
            }),
            201,
            headers: {'content-type': 'application/json'},
          );
        }
        return http.Response('{"message":"Not Found"}', 404);
      };

      // Call registerKey with null userId — should auto-resolve from storage
      final result = await service.registerKey(publicKey: testPublicKeyB64);
      expect(result.id, equals('key-from-storage'));
      expect(fakeHttp.recordedRequests.first.headers['X-User-Id'], equals('student-canonical-uuid-42'));
    });

    test('5. backend rejects student attempting to register for another user with 403', () async {
      final fakeAuth = FakeAuthService(currentUser: testStudent);
      final service = PassportIdentityService(
        apiClient: apiClient,
        authService: fakeAuth,
        storage: storage,
      );

      fakeHttp.handler = (request) {
        if (request.url.path == '/passport/keys/register') {
          // Backend detects mismatch and returns 403
          return http.Response(
            jsonEncode({'message': 'Forbidden: You are not authorized to register a key for another user'}),
            403,
            headers: {'content-type': 'application/json'},
          );
        }
        return http.Response('{"message":"Not Found"}', 404);
      };

      expect(
        () => service.registerKey(
          publicKey: testPublicKeyB64,
          userId: 'some-other-student-id',
        ),
        throwsA(isA<Exception>().having(
          (e) => e.toString(),
          'message',
          contains('Forbidden: You are not authorized to register a key for another user'),
        )),
      );
    });

    test('6. repeated activation when already active returns 409 conflict handled correctly', () async {
      final fakeAuth = FakeAuthService(currentUser: testStudent);
      final service = PassportIdentityService(
        apiClient: apiClient,
        authService: fakeAuth,
        storage: storage,
      );

      fakeHttp.handler = (request) {
        if (request.url.path == '/passport/keys/register') {
          return http.Response(
            jsonEncode({'message': 'Conflict: User already has an active Passport identity key'}),
            409,
            headers: {'content-type': 'application/json'},
          );
        }
        return http.Response('{"message":"Not Found"}', 404);
      };

      expect(
        () => service.registerKey(
          publicKey: testPublicKeyB64,
          userId: testStudent.id,
        ),
        throwsA(isA<Exception>().having(
          (e) => e.toString(),
          'message',
          contains('Conflict: User already has an active Passport identity key'),
        )),
      );
    });

    test('7. getStudentIdentity and revokeKey propagate X-User-Id header', () async {
      final fakeAuth = FakeAuthService(currentUser: testStudent);
      final service = PassportIdentityService(
        apiClient: apiClient,
        authService: fakeAuth,
        storage: storage,
      );

      fakeHttp.handler = (request) {
        expect(request.headers['X-User-Id'], equals('student-canonical-uuid-42'));
        if (request.url.path.contains('/passport/keys/student-target')) {
          return http.Response(
            jsonEncode({
              'keyId': 'key-target-1',
              'userId': 'student-target',
              'publicKey': testPublicKeyB64,
              'keyType': 'ED25519',
              'status': 'ACTIVE',
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        if (request.url.path.contains('/revoke')) {
          return http.Response(
            jsonEncode({'message': 'Key and associated certificates revoked successfully'}),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        return http.Response('{"message":"Not Found"}', 404);
      };

      final keyModel = await service.getStudentIdentity('student-target');
      expect(keyModel, isNotNull);
      expect(keyModel!.id, equals('key-target-1'));

      await service.revokeKey('key-uuid-101');
      expect(fakeHttp.recordedRequests.length, equals(2));
    });

    test('8. existing enrolled Passport remains functional and reports correct enrolled state', () async {
      final fakeAuth = FakeAuthService(currentUser: testStudent);
      final service = PassportIdentityService(
        apiClient: apiClient,
        authService: fakeAuth,
        storage: storage,
      );

      fakeHttp.handler = (request) {
        if (request.url.path == '/passport/identity') {
          return http.Response(
            jsonEncode({
              'enrolled': true,
              'key': {
                'id': 'key-uuid-101',
                'userId': 'student-canonical-uuid-42',
                'publicKey': testPublicKeyB64,
                'keyType': 'ED25519',
                'status': 'ACTIVE',
              },
              'certificate': {
                'id': 'cert-uuid-202',
                'keyId': 'key-uuid-101',
                'userId': 'student-canonical-uuid-42',
                'publicKey': testPublicKeyB64,
                'status': 'ACTIVE',
                'validFrom': '2026-09-26T00:00:00Z',
                'validTo': '2027-09-26T00:00:00Z',
                'issuer': 'CampusOS',
                'issuerKeyId': 'institution-root-key-1',
                'signature': 'test-sig-b64',
              }
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        return http.Response('{"message":"Not Found"}', 404);
      };

      final status = await service.getIdentity();
      expect(status.enrolled, isTrue);
      expect(status.key!.isActive, isTrue);
      expect(status.certificate!.isActive, isTrue);
      expect(status.certificate!.isExpired, isFalse);
    });
  });

  group('CampusOS Passport — Offline Restoration & Lifecycle State Machine Tests', () {
    late FakeHttpClient fakeHttp;
    late ApiClient apiClient;
    late FakePassportKeyStorage storage;

    final testStudent = UserModel(
      id: 'student-offline-uuid-99',
      email: 'student99@campusos.edu',
      name: 'Priya Sharma',
      role: 'student',
      registrationNumber: 'REG-2023-CS-099',
      course: 'B.Tech',
      branch: 'CSE',
      year: '3rd Year',
    );

    setUp(() {
      fakeHttp = FakeHttpClient();
      apiClient = ApiClient(
        baseUrl: 'http://127.0.0.1:5000',
        client: fakeHttp,
      );
      storage = FakePassportKeyStorage();
    });

    test('9. clean startup: no key and no cache reports enrolled=false without throwing', () async {
      final fakeAuth = FakeAuthService(currentUser: testStudent);
      final identityService = PassportIdentityService(
        apiClient: apiClient,
        authService: fakeAuth,
        storage: storage,
      );
      final cryptoService = PassportCryptoService(storage: storage);

      fakeHttp.handler = (req) => http.Response('{"message":"Not enrolled"}', 404);

      final hasKey = await cryptoService.hasIdentityKey();
      expect(hasKey, isFalse);

      final status = await identityService.getIdentity();
      expect(status.enrolled, isFalse);
      expect(status.key, isNull);
    });

    test('10. online startup: key registration automatically caches enrollment metadata locally', () async {
      final fakeAuth = FakeAuthService(currentUser: testStudent);
      final identityService = PassportIdentityService(
        apiClient: apiClient,
        authService: fakeAuth,
        storage: storage,
      );
      final cryptoService = PassportCryptoService(storage: storage);
      final pubKeyB64 = await cryptoService.getOrCreatePublicKey();

      fakeHttp.handler = (req) {
        if (req.url.path == '/passport/keys/register') {
          return http.Response(
            jsonEncode({
              'id': 'key-online-101',
              'userId': 'student-offline-uuid-99',
              'publicKey': pubKeyB64,
              'keyType': 'ED25519',
              'status': 'ACTIVE',
              'certificate': {
                'id': 'cert-online-202',
                'keyId': 'key-online-101',
                'userId': 'student-offline-uuid-99',
                'publicKey': pubKeyB64,
                'status': 'ACTIVE',
                'validFrom': '2026-09-01T00:00:00Z',
                'validTo': '2027-09-01T00:00:00Z',
                'issuer': 'CampusOS',
                'issuerKeyId': 'inst-root-key',
                'signature': 'test-sig-online',
              }
            }),
            201,
          );
        }
        return http.Response('{"message":"Not Found"}', 404);
      };

      await identityService.registerKey(publicKey: pubKeyB64);

      // Verify that local storage now contains the cached status
      final cached = await identityService.getCachedIdentity();
      expect(cached, isNotNull);
      expect(cached!.enrolled, isTrue);
      expect(cached.key!.id, equals('key-online-101'));
      expect(cached.certificate!.id, equals('cert-online-202'));
    });

    test('11. cold boot / process death offline: restores enrolled state from cache without network', () async {
      final fakeAuth = FakeAuthService(currentUser: testStudent);
      final cryptoService = PassportCryptoService(storage: storage);
      final pubKeyB64 = await cryptoService.getOrCreatePublicKey();

      // Preload local storage as would happen after a previous successful enrollment
      final enrolledStatus = PassportEnrollmentStatus(
        enrolled: true,
        key: PassportIdentityKeyModel(
          id: 'key-coldboot-101',
          userId: 'student-offline-uuid-99',
          publicKey: pubKeyB64,
          status: 'ACTIVE',
        ),
        certificate: PassportCertificateModel(
          id: 'cert-coldboot-202',
          keyId: 'key-coldboot-101',
          issuerKeyId: 'inst-root',
          userId: 'student-offline-uuid-99',
          publicKey: pubKeyB64,
          validFrom: DateTime.now().subtract(const Duration(days: 10)),
          validTo: DateTime.now().add(const Duration(days: 300)),
          signature: 'sig-coldboot',
          payload: {},
        ),
      );
      await storage.write(
        PassportIdentityService.enrollmentStatusStorageKey,
        enrolledStatus.toJson(),
      );

      // Network is completely dead (throws exception)
      fakeHttp.handler = (req) => throw http.ClientException('No route to host / Device Offline');

      final freshIdentityService = PassportIdentityService(
        apiClient: apiClient,
        authService: fakeAuth,
        storage: storage,
      );

      final restoredStatus = await freshIdentityService.getIdentity();
      expect(restoredStatus.enrolled, isTrue);
      expect(restoredStatus.key, isNotNull);
      expect(restoredStatus.key!.id, equals('key-coldboot-101'));
      expect(restoredStatus.certificate, isNotNull);
      expect(restoredStatus.certificate!.isValidNow, isTrue);
    });

    test('12. phone reboot offline: presentation generated and signed completely offline', () async {
      final fakeAuth = FakeAuthService(currentUser: testStudent);
      final cryptoService = PassportCryptoService(storage: storage);
      final pubKeyB64 = await cryptoService.getOrCreatePublicKey();

      // Persist enrollment in storage
      final enrolledStatus = PassportEnrollmentStatus(
        enrolled: true,
        key: PassportIdentityKeyModel(
          id: 'key-reboot-101',
          userId: 'student-offline-uuid-99',
          publicKey: pubKeyB64,
          status: 'ACTIVE',
        ),
        certificate: PassportCertificateModel(
          id: 'cert-reboot-202',
          keyId: 'key-reboot-101',
          issuerKeyId: 'inst-root',
          userId: 'student-offline-uuid-99',
          publicKey: pubKeyB64,
          validFrom: DateTime.now().subtract(const Duration(days: 5)),
          validTo: DateTime.now().add(const Duration(days: 200)),
          signature: 'sig-reboot',
          payload: {},
        ),
      );
      await storage.write(
        PassportIdentityService.enrollmentStatusStorageKey,
        enrolledStatus.toJson(),
      );

      // Simulate device reboot: brand new service instances with no network
      fakeHttp.handler = (req) => throw http.ClientException('Airplane mode');

      final freshCrypto = PassportCryptoService(storage: storage);
      final freshIdentity = PassportIdentityService(
        apiClient: apiClient,
        authService: fakeAuth,
        storage: storage,
      );

      final presentationService = PassportPresentationService(
        cryptoService: freshCrypto,
        identityService: freshIdentity,
      );

      // Presentation creation must succeed 100% offline
      final presentation = await presentationService.createPresentation();
      expect(presentation, isNotNull);
      expect(presentation.userId, equals('student-offline-uuid-99'));
      expect(presentation.keyId, equals('key-reboot-101'));
      expect(presentation.signature, isNotEmpty);

      // Verify the generated presentation is cryptographically valid
      final isValid = await freshCrypto.verifySignature(
        publicKey: pubKeyB64,
        challenge: presentation.toCanonicalJson(),
        signature: presentation.signature,
      );
      expect(isValid, isTrue, reason: 'Offline signed presentation must be cryptographically valid');
    });

    test('13. temporary network outage: rotation continues uninterrupted', () async {
      final fakeAuth = FakeAuthService(currentUser: testStudent);
      final cryptoService = PassportCryptoService(storage: storage);
      final pubKeyB64 = await cryptoService.getOrCreatePublicKey();

      final enrolledStatus = PassportEnrollmentStatus(
        enrolled: true,
        key: PassportIdentityKeyModel(
          id: 'key-rot-101',
          userId: 'student-offline-uuid-99',
          publicKey: pubKeyB64,
          status: 'ACTIVE',
        ),
        certificate: PassportCertificateModel(
          id: 'cert-rot-202',
          keyId: 'key-rot-101',
          issuerKeyId: 'inst-root',
          userId: 'student-offline-uuid-99',
          publicKey: pubKeyB64,
          validFrom: DateTime.now().subtract(const Duration(days: 1)),
          validTo: DateTime.now().add(const Duration(days: 100)),
          signature: 'sig-rot',
          payload: {},
        ),
      );
      await storage.write(
        PassportIdentityService.enrollmentStatusStorageKey,
        enrolledStatus.toJson(),
      );

      final identityService = PassportIdentityService(
        apiClient: apiClient,
        authService: fakeAuth,
        storage: storage,
      );
      final presentationService = PassportPresentationService(
        cryptoService: cryptoService,
        identityService: identityService,
      );

      // First rotation with network down
      fakeHttp.handler = (req) => throw http.ClientException('DNS failure');
      final p1 = await presentationService.createPresentation(cachedStatus: enrolledStatus);
      expect(p1.nonce, isNotEmpty);

      // Second rotation with network down
      final p2 = await presentationService.createPresentation(cachedStatus: enrolledStatus);
      expect(p2.nonce, isNotEmpty);
      expect(p1.nonce, isNot(equals(p2.nonce)));
    });

    test('14. expired enrollment offline: certificate expiration detected without server', () async {
      final fakeAuth = FakeAuthService(currentUser: testStudent);
      final cryptoService = PassportCryptoService(storage: storage);
      final pubKeyB64 = await cryptoService.getOrCreatePublicKey();

      final expiredStatus = PassportEnrollmentStatus(
        enrolled: true,
        key: PassportIdentityKeyModel(
          id: 'key-exp-101',
          userId: 'student-offline-uuid-99',
          publicKey: pubKeyB64,
          status: 'ACTIVE',
        ),
        certificate: PassportCertificateModel(
          id: 'cert-exp-202',
          keyId: 'key-exp-101',
          issuerKeyId: 'inst-root',
          userId: 'student-offline-uuid-99',
          publicKey: pubKeyB64,
          validFrom: DateTime.now().subtract(const Duration(days: 400)),
          validTo: DateTime.now().subtract(const Duration(days: 10)), // Expired 10 days ago!
          signature: 'sig-exp',
          payload: {},
        ),
      );
      await storage.write(
        PassportIdentityService.enrollmentStatusStorageKey,
        expiredStatus.toJson(),
      );

      final identityService = PassportIdentityService(
        apiClient: apiClient,
        authService: fakeAuth,
        storage: storage,
      );
      final presentationService = PassportPresentationService(
        cryptoService: cryptoService,
        identityService: identityService,
      );

      // Simulate device is completely offline
      fakeHttp.handler = (req) => throw http.ClientException('Device offline');

      // Attempting to present expired identity throws PassportIdentityInactiveException
      expect(
        () => presentationService.createPresentation(),
        throwsA(isA<PassportIdentityInactiveException>()),
      );
    });

    test('15. genuine key loss: private key missing while cache has status -> throws PassportKeyMissingException', () async {
      final fakeAuth = FakeAuthService(currentUser: testStudent);
      final emptyStorage = FakePassportKeyStorage();

      // Enrollment is cached, but private key was deleted from storage
      final enrolledStatus = PassportEnrollmentStatus(
        enrolled: true,
        key: PassportIdentityKeyModel(
          id: 'key-lost-101',
          userId: 'student-offline-uuid-99',
          publicKey: 'some-public-key',
          status: 'ACTIVE',
        ),
        certificate: PassportCertificateModel(
          id: 'cert-lost-202',
          keyId: 'key-lost-101',
          issuerKeyId: 'inst-root',
          userId: 'student-offline-uuid-99',
          publicKey: 'some-public-key',
          validFrom: DateTime.now().subtract(const Duration(days: 1)),
          validTo: DateTime.now().add(const Duration(days: 100)),
          signature: 'sig-lost',
          payload: {},
        ),
      );
      await emptyStorage.write(
        PassportIdentityService.enrollmentStatusStorageKey,
        enrolledStatus.toJson(),
      );

      final cryptoService = PassportCryptoService(storage: emptyStorage);
      final identityService = PassportIdentityService(
        apiClient: apiClient,
        authService: fakeAuth,
        storage: emptyStorage,
      );
      final presentationService = PassportPresentationService(
        cryptoService: cryptoService,
        identityService: identityService,
      );

      // Simulate device is completely offline
      fakeHttp.handler = (req) => throw http.ClientException('Device offline');

      expect(
        () => presentationService.createPresentation(),
        throwsA(isA<PassportKeyMissingException>()),
      );
    });

    test('16. key mismatch: local key does not match certified key -> throws PassportKeyMismatchException', () async {
      final fakeAuth = FakeAuthService(currentUser: testStudent);
      final cryptoService = PassportCryptoService(storage: storage);
      await cryptoService.getOrCreatePublicKey();

      // Certificate has DIFFERENT public key than local hardware key
      final mismatchedStatus = PassportEnrollmentStatus(
        enrolled: true,
        key: PassportIdentityKeyModel(
          id: 'key-mismatch-101',
          userId: 'student-offline-uuid-99',
          publicKey: 'DIFFERENT_PUBLIC_KEY_B64==',
          status: 'ACTIVE',
        ),
        certificate: PassportCertificateModel(
          id: 'cert-mismatch-202',
          keyId: 'key-mismatch-101',
          issuerKeyId: 'inst-root',
          userId: 'student-offline-uuid-99',
          publicKey: 'DIFFERENT_PUBLIC_KEY_B64==',
          validFrom: DateTime.now().subtract(const Duration(days: 1)),
          validTo: DateTime.now().add(const Duration(days: 100)),
          signature: 'sig-mismatch',
          payload: {},
        ),
      );

      final identityService = PassportIdentityService(
        apiClient: apiClient,
        authService: fakeAuth,
        storage: storage,
      );
      final presentationService = PassportPresentationService(
        cryptoService: cryptoService,
        identityService: identityService,
      );

      expect(
        () => presentationService.createPresentation(cachedStatus: mismatchedStatus),
        throwsA(isA<PassportKeyMismatchException>()),
      );
    });

    test('17. key revocation clears cached enrollment immediately', () async {
      final fakeAuth = FakeAuthService(currentUser: testStudent);
      final identityService = PassportIdentityService(
        apiClient: apiClient,
        authService: fakeAuth,
        storage: storage,
      );

      // Preload cache
      await storage.write(
        PassportIdentityService.enrollmentStatusStorageKey,
        '{"enrolled":true}',
      );
      expect(await storage.read(PassportIdentityService.enrollmentStatusStorageKey), isNotNull);

      fakeHttp.handler = (req) => http.Response('{"message":"Key revoked"}', 200);

      await identityService.revokeKey('key-to-revoke-101');

      // Verify cache was cleared
      expect(await storage.read(PassportIdentityService.enrollmentStatusStorageKey), isNull);
    });

    test('18. network failure never silently generates a new identity key', () async {
      final emptyStorage = FakePassportKeyStorage();
      final cryptoService = PassportCryptoService(storage: emptyStorage);

      // Ensure no key exists yet
      expect(await cryptoService.hasIdentityKey(), isFalse);

      final fakeAuth = FakeAuthService(currentUser: testStudent);
      fakeHttp.handler = (req) => throw http.ClientException('Network down');

      final identityService = PassportIdentityService(
        apiClient: apiClient,
        authService: fakeAuth,
        storage: emptyStorage,
      );

      // Querying identity offline when not enrolled must NOT generate key
      final status = await identityService.getIdentity();
      expect(status.enrolled, isFalse);
      expect(await cryptoService.hasIdentityKey(), isFalse,
          reason: 'Network failure must never silently generate an identity key');
    });
  });
}
