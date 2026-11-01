import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:attendance_app/core/network/api_client.dart';
import 'package:attendance_app/student/models/passport_verification_result.dart';
import 'package:attendance_app/student/services/passport_verifier_service.dart';

/// Mock HTTP client for isolated unit testing
class FakeHttpClient extends http.BaseClient {
  http.Response Function(http.Request request)? handler;
  int callCount = 0;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    callCount++;
    if (handler != null && request is http.Request) {
      final res = handler!(request);
      return http.StreamedResponse(
        Stream.value(res.bodyBytes),
        res.statusCode,
        headers: res.headers,
      );
    }
    return http.StreamedResponse(
      Stream.value(utf8.encode('{"valid":false,"reason":"DEFAULT_MOCK"}')),
      200,
    );
  }
}

void main() {
  group('CampusOS Passport 1E: Verification Result Model Tests', () {
    test('1. Valid result parses accurately with student user information', () {
      final jsonMap = {
        'valid': true,
        'reason': 'VALID',
        'userId': 'usr-1234',
        'keyId': 'key-5678',
        'certificateId': 'cert-9012',
        'expiresAt': 1774483230,
        'user': {
          'name': 'Sourav Nanda',
          'branch': 'Computer Science & Engineering',
          'year': '5th Semester',
          'course': 'B.Tech',
          'registrationNumber': 'BPUT-2023-0042',
        }
      };

      final result = PassportVerificationResult.fromMap(jsonMap);
      expect(result.isValid, isTrue);
      expect(result.reason, equals('VALID'));
      expect(result.userId, equals('usr-1234'));
      expect(result.keyId, equals('key-5678'));
      expect(result.certificateId, equals('cert-9012'));
      expect(result.expiresAt, equals(1774483230));
      expect(result.user, isNotNull);
      expect(result.user!.name, equals('Sourav Nanda'));
      expect(result.user!.branch, equals('Computer Science & Engineering'));
      expect(result.displayTitle, equals('PASSPORT VALID'));
    });

    test('2. Missing user info is handled safely without crashing', () {
      final jsonMap = {
        'valid': true,
        'reason': 'VALID',
        'userId': 'usr-1234',
        'keyId': 'key-5678',
        'certificateId': 'cert-9012',
        'expiresAt': 1774483230,
      };

      final result = PassportVerificationResult.fromMap(jsonMap);
      expect(result.isValid, isTrue);
      expect(result.user, isNull);
    });

    test('3. Invalid signature reason is parsed and formatted cleanly', () {
      final jsonMap = {
        'valid': false,
        'reason': 'INVALID_SIGNATURE',
      };

      final result = PassportVerificationResult.fromMap(jsonMap);
      expect(result.isValid, isFalse);
      expect(result.isInvalidSignature, isTrue);
      expect(result.displayTitle, equals('Passport Could Not Be Verified'));
      expect(result.displayMessage, contains('Signature is invalid'));
    });

    test('4. Expired presentation reason is parsed and formatted cleanly', () {
      final jsonMap = {
        'valid': false,
        'reason': 'PRESENTATION_EXPIRED',
      };

      final result = PassportVerificationResult.fromMap(jsonMap);
      expect(result.isValid, isFalse);
      expect(result.isExpired, isTrue);
      expect(result.displayTitle, equals('Passport Presentation Expired'));
      expect(result.displayMessage, contains('refresh their Passport QR'));
    });

    test('5. Revoked key reason is parsed and formatted cleanly', () {
      final jsonMap = {
        'valid': false,
        'reason': 'REVOKED_KEY',
      };

      final result = PassportVerificationResult.fromMap(jsonMap);
      expect(result.isValid, isFalse);
      expect(result.isRevoked, isTrue);
      expect(result.displayTitle, equals('Passport Identity Revoked'));
      expect(result.displayMessage, contains('no longer active'));
    });

    test('6. Network error factory separates transport failure from invalid signature', () {
      final result = PassportVerificationResult.networkError('Connection refused');
      expect(result.isValid, isFalse);
      expect(result.isNetworkError, isTrue);
      expect(result.displayTitle, equals('Verification Unavailable'));
      expect(result.displayMessage, contains('Connect to the CampusOS server'));
    });

    test('7. Unknown future reason gracefully falls back to neutral message', () {
      final jsonMap = {
        'valid': false,
        'reason': 'FUTURE_UNRECOGNIZED_POLICY',
      };

      final result = PassportVerificationResult.fromMap(jsonMap);
      expect(result.isValid, isFalse);
      expect(result.displayTitle, equals('Unable to Verify Passport'));
    });
  });

  group('CampusOS Passport 1E: Verifier Service Online & Offline Checks', () {
    late FakeHttpClient fakeHttp;
    late ApiClient testApiClient;
    late PassportVerifierService service;

    setUp(() {
      fakeHttp = FakeHttpClient();
      testApiClient = ApiClient(baseUrl: 'http://127.0.0.1:5000', client: fakeHttp);
      service = PassportVerifierService(apiClient: testApiClient);
    });

    test('8. Malformed QR string rejected locally without making network calls', () async {
      final malformedStrings = [
        '',
        '   ',
        'not a json string',
        '{"plain": "hello"}',
        '{"p": {}}', // Missing signature
        '{"p": {"version": 1}, "s": "sig"}', // Missing required keys
        '{"p": {"version": 2, "type": "PASSPORT_PRESENTATION", "keyId": "k", "userId": "u", "certificateId": "c", "issuerKeyId": "i", "issuedAt": 1, "expiresAt": 2, "nonce": "n"}, "s": "sig"}', // Unsupported version
      ];

      for (final bad in malformedStrings) {
        final result = await service.verifyQrString(bad);
        expect(result.isValid, isFalse, reason: 'Failed for: $bad');
        expect(result.isInvalidFormat, isTrue, reason: 'Failed for: $bad');
      }

      // Zero network calls made!
      expect(fakeHttp.callCount, equals(0));
    });

    test('9. Valid QR payload triggers online POST /passport/verify and parses response', () async {
      final validEnvelope = jsonEncode({
        'p': {
          'version': 1,
          'type': 'PASSPORT_PRESENTATION',
          'keyId': 'k1',
          'userId': 'u1',
          'certificateId': 'c1',
          'issuerKeyId': 'i1',
          'issuedAt': 1774483200,
          'expiresAt': 1774483230,
          'nonce': 'randomnonce1234567890',
        },
        's': 'mockBase64Signature==',
      });

      fakeHttp.handler = (req) {
        expect(req.url.path, endsWith('/passport/verify'));
        final body = jsonDecode(req.body);
        expect(body['payload']['keyId'], equals('k1'));
        expect(body['signature'], equals('mockBase64Signature=='));

        return http.Response(
          jsonEncode({
            'valid': true,
            'reason': 'VALID',
            'userId': 'u1',
            'keyId': 'k1',
            'certificateId': 'c1',
            'expiresAt': 1774483230,
            'user': {
              'name': 'Sourav Nanda',
              'branch': 'CSE',
              'year': '5th Sem',
            }
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      };

      final result = await service.verifyQrString(validEnvelope);
      expect(result.isValid, isTrue);
      expect(result.reason, equals('VALID'));
      expect(result.user?.name, equals('Sourav Nanda'));
      expect(fakeHttp.callCount, equals(1));
    });

    test('10. Backend rejection reason (e.g. REVOKED_KEY) is accurately captured', () async {
      final validEnvelope = jsonEncode({
        'p': {
          'version': 1,
          'type': 'PASSPORT_PRESENTATION',
          'keyId': 'k-revoked',
          'userId': 'u1',
          'certificateId': 'c1',
          'issuerKeyId': 'i1',
          'issuedAt': 1774483200,
          'expiresAt': 1774483230,
          'nonce': 'randomnonce1234567890',
        },
        's': 'mockBase64Signature==',
      });

      fakeHttp.handler = (req) {
        return http.Response(
          jsonEncode({
            'valid': false,
            'reason': 'REVOKED_KEY',
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      };

      final result = await service.verifyQrString(validEnvelope);
      expect(result.isValid, isFalse);
      expect(result.isRevoked, isTrue);
      expect(result.reason, equals('REVOKED_KEY'));
      expect(fakeHttp.callCount, equals(1));
    });

    test('11. Network exception maps to isNetworkError instead of invalid credential', () async {
      final validEnvelope = jsonEncode({
        'p': {
          'version': 1,
          'type': 'PASSPORT_PRESENTATION',
          'keyId': 'k1',
          'userId': 'u1',
          'certificateId': 'c1',
          'issuerKeyId': 'i1',
          'issuedAt': 1774483200,
          'expiresAt': 1774483230,
          'nonce': 'randomnonce1234567890',
        },
        's': 'mockBase64Signature==',
      });

      fakeHttp.handler = (req) {
        throw Exception('SocketException: Connection refused');
      };

      final result = await service.verifyQrString(validEnvelope);
      expect(result.isValid, isFalse);
      expect(result.isNetworkError, isTrue);
      expect(result.isInvalidSignature, isFalse);
      expect(result.displayTitle, equals('Verification Unavailable'));
    });
  });
}
