import 'dart:convert';
import '../models/attendance_model.dart';
import '../../core/network/api_client.dart';

class AttendanceService {
  final ApiClient _apiClient;

  AttendanceService({ApiClient? apiClient})
      : _apiClient = apiClient ?? ApiClient.instance;

  Future<AttendanceModel> markAttendance({
    required String sessionId,
    required String studentId,
    required String studentName,
    String? couponCode,
    String? idempotencyKey,
    String? deviceKeyId,
    String? responseNonce,
    String? verificationMode,
    String? proximityTier,
    double? latitude,
    double? longitude,
  }) async {
    final response = await _apiClient.post(
      '/attendance/mark',
      body: {
        'sessionId': sessionId,
        'studentId': studentId,
        'studentName': studentName,
        'couponCode': couponCode,
        'idempotencyKey': idempotencyKey,
        'deviceKeyId': deviceKeyId,
        'responseNonce': responseNonce,
        'verificationMode': verificationMode ?? 'LEGACY',
        'proximityTier': proximityTier,
        if (latitude != null) 'latitude': latitude,
        if (longitude != null) 'longitude': longitude,
      },
    );
    if (response.statusCode == 200 || response.statusCode == 201) {
      final data = jsonDecode(response.body);
      return AttendanceModel.fromMap(data, data['id']);
    } else {
      final errorMap = jsonDecode(response.body);
      throw Exception(errorMap['message'] ?? 'Failed');
    }
  }

  /// CampusOS Passport 1I: Idempotent batch synchronization of locally verified attendance records.
  Future<Map<String, dynamic>> batchSync({
    required String sessionId,
    required List<Map<String, dynamic>> records,
  }) async {
    final response = await _apiClient.post(
      '/attendance/batch-sync',
      body: {
        'sessionId': sessionId,
        'records': records,
      },
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    } else {
      final errorMap = jsonDecode(response.body);
      throw Exception(errorMap['message'] ?? 'Batch sync failed');
    }
  }

  Future<List<AttendanceModel>> getStudentAttendance(String studentId) async {
    try {
      final response = await _apiClient.get('/attendance/student/$studentId');
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data
            .map((json) => AttendanceModel.fromMap(json, json['id']))
            .toList();
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  Future<List<AttendanceModel>> getSessionAttendance(String sessionId) async {
    final response = await _apiClient.get('/attendance/session/$sessionId');
    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return data
          .map((json) => AttendanceModel.fromMap(json, json['id']))
          .toList();
    }
    return [];
  }

  Future<Map<String, dynamic>?> getStudentComprehensiveAnalytics(
      String uid) async {
    try {
      final response =
          await _apiClient.get('/analytics/student-comprehensive/$uid');
      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
    } catch (e) {
      // Ignored
    }
    return null;
  }
}
