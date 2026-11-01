import 'dart:async';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:drift/drift.dart' as drift;

import 'package:attendance_app/core/database/database.dart';
import 'package:attendance_app/core/network/api_client.dart';
import 'package:attendance_app/core/network/connectivity_service.dart';
import 'package:attendance_app/student/models/complaint_model.dart';
import 'package:attendance_app/student/services/complaint_service.dart';

class FakeConnectivity implements Connectivity {
  List<ConnectivityResult> current;
  final StreamController<List<ConnectivityResult>> controller =
      StreamController<List<ConnectivityResult>>.broadcast();

  FakeConnectivity(this.current);

  @override
  Future<List<ConnectivityResult>> checkConnectivity() async => current;

  @override
  Stream<List<ConnectivityResult>> get onConnectivityChanged => controller.stream;
}

class FakeHttpClient extends http.BaseClient {
  Future<http.Response> Function(http.BaseRequest request)? handler;

  FakeHttpClient([this.handler]);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    if (handler != null) {
      final response = await handler!(request);
      return http.StreamedResponse(
        Stream.value(response.bodyBytes),
        response.statusCode,
        headers: response.headers,
      );
    }
    return http.StreamedResponse(Stream.value(utf8.encode('{"status":"ok"}')), 200);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    drift.driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  });

  group('Feature 2: Proof-of-Fix 2-Way OTP & Slingshot Model Tests', () {
    test('Parses closureOtp, escalation levels, and vendor penalty correctly', () {
      final map = {
        'id': 'comp_101',
        'studentId': 'stud_01',
        'category': 'Hostel/Room',
        'title': 'Broken Geyser',
        'description': 'Geyser water not heating',
        'location': 'Hostel B, Room 204',
        'priority': 'HIGH',
        'status': 'IN_PROGRESS',
        'closureOtp': '4819',
        'escalationLevel': 3,
        'vendorPenaltyFlag': true,
        'vendorPenaltyAmount': 500.0,
        'studentRating': 5,
        'studentFeedback': 'Fixed permanently by electrician',
        'createdAt': '2026-10-06T10:00:00.000Z',
      };

      final model = ComplaintModel.fromMap(map);
      expect(model.id, 'comp_101');
      expect(model.closureOtp, '4819');
      expect(model.escalationLevel, 3);
      expect(model.isTier3DeanSlingshot, isTrue);
      expect(model.isTier2WardenAlert, isFalse);
      expect(model.hasVendorPenalty, isTrue);
      expect(model.vendorPenaltyAmount, 500.0);
      expect(model.studentRating, 5);
      expect(model.studentFeedback, 'Fixed permanently by electrician');
    });

    test('Tier 2 Warden Alert getters function correctly', () {
      final map = {
        'id': 'comp_102',
        'studentId': 'stud_01',
        'category': 'Plumbing',
        'title': 'Leaking Tap',
        'description': 'Continuous leak in bathroom',
        'location': 'Hostel B, Room 102',
        'priority': 'MEDIUM',
        'status': 'ASSIGNED',
        'closureOtp': '1234',
        'escalationLevel': 2,
        'vendorPenaltyFlag': false,
        'createdAt': '2026-10-06T10:00:00.000Z',
      };

      final model = ComplaintModel.fromMap(map);
      expect(model.isTier2WardenAlert, isTrue);
      expect(model.isTier3DeanSlingshot, isFalse);
      expect(model.hasVendorPenalty, isFalse);
    });
  });

  group('Feature 2: ComplaintService verifyResolve and submitFeedback Tests', () {
    late AppDatabase db;
    late DatabaseService dbService;
    late ConnectivityService connectivityService;
    late FakeConnectivity fakeConnectivity;
    late FakeHttpClient fakeHttpClient;
    late ApiClient apiClient;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      db = AppDatabase.inMemory();
      dbService = DatabaseService.forTesting(db);
      fakeConnectivity = FakeConnectivity([ConnectivityResult.wifi]);
      fakeHttpClient = FakeHttpClient((req) async {
        if (req.url.path == '/health') {
          return http.Response('{"status":"ok"}', 200);
        }
        if (req.url.path.contains('/verify-resolve') && req.method == 'POST') {
          return http.Response(
            jsonEncode({
              'message': 'Complaint verified and resolved successfully',
              'complaint': {
                'id': 'comp_101',
                'studentId': 'stud_01',
                'category': 'Hostel/Room',
                'title': 'Broken Geyser',
                'description': 'Geyser water not heating',
                'location': 'Hostel B, Room 204',
                'priority': 'HIGH',
                'status': 'RESOLVED',
                'closureOtp': '4819',
                'otpVerifiedAt': '2026-10-07T12:00:00.000Z',
                'createdAt': '2026-10-06T10:00:00.000Z',
              }
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        if (req.url.path.contains('/feedback') && req.method == 'POST') {
          return http.Response(
            jsonEncode({
              'message': 'Feedback recorded successfully',
              'complaint': {
                'id': 'comp_101',
                'studentId': 'stud_01',
                'category': 'Hostel/Room',
                'title': 'Broken Geyser',
                'description': 'Geyser water not heating',
                'location': 'Hostel B, Room 204',
                'priority': 'HIGH',
                'status': 'RESOLVED',
                'studentRating': 5,
                'studentFeedback': 'Superb service, verified by me',
                'createdAt': '2026-10-06T10:00:00.000Z',
              }
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        return http.Response('{"message": "Not Found"}', 404);
      });

      connectivityService = ConnectivityService.forTesting(
        connectivity: fakeConnectivity,
        httpClient: fakeHttpClient,
        baseUrl: 'http://127.0.0.1:5000',
      );
      await connectivityService.checkReachability();

      apiClient = ApiClient(
        baseUrl: 'http://127.0.0.1:5000',
        client: fakeHttpClient,
      );
    });

    test('verifyResolve calls /complaints/:id/verify-resolve with OTP and returns resolved model', () async {
      final service = ComplaintService(
        apiClient: apiClient,
        dbService: dbService,
        connectivityService: connectivityService,
      );

      final result = await service.verifyResolve(
        complaintId: 'comp_101',
        actorId: 'staff_01',
        otp: '4819',
        remarks: 'Fixed heating element',
      );

      expect(result.status, 'RESOLVED');
      expect(result.isResolved, isTrue);
      expect(result.otpVerifiedAt, isNotNull);
    });

    test('submitFeedback calls /complaints/:id/feedback with rating and returns updated model', () async {
      final service = ComplaintService(
        apiClient: apiClient,
        dbService: dbService,
        connectivityService: connectivityService,
      );

      final result = await service.submitFeedback(
        complaintId: 'comp_101',
        studentId: 'stud_01',
        rating: 5,
        feedback: 'Superb service, verified by me',
      );

      expect(result.studentRating, 5);
      expect(result.studentFeedback, 'Superb service, verified by me');
    });
  });
}
