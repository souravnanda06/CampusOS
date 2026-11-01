import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../../core/network/api_client.dart';
import '../models/leave_request_model.dart';

class LeaveService {
  final ApiClient _apiClient;

  LeaveService({ApiClient? apiClient})
      : _apiClient = apiClient ?? ApiClient.instance;

  /// Submit a new leave request
  Future<LeaveRequestModel> submitLeaveRequest({
    required String studentId,
    required String leaveType,
    required String startDate,
    required String endDate,
    required String reason,
  }) async {
    try {
      final response = await _apiClient.post(
        '/requests/leave',
        body: {
          'studentId': studentId,
          'leaveType': leaveType,
          'startDate': startDate,
          'endDate': endDate,
          'reason': reason,
        },
      );

      final data = jsonDecode(response.body);
      if (response.statusCode == 201) {
        return LeaveRequestModel.fromMap(data['request']);
      } else {
        throw data['message'] ?? 'Failed to submit leave request';
      }
    } catch (e) {
      debugPrint("❌ [LEAVE_SERVICE] submitLeaveRequest error: $e");
      rethrow;
    }
  }

  /// Fetch all leave requests for a given student, newest first
  Future<List<LeaveRequestModel>> getStudentLeaveRequests(
      String studentId) async {
    try {
      final response = await _apiClient.get('/requests/leave/$studentId');
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data
            .map((item) => LeaveRequestModel.fromMap(item as Map<String, dynamic>))
            .toList();
      } else if (response.statusCode == 404) {
        return [];
      } else {
        final data = jsonDecode(response.body);
        throw data['message'] ?? 'Failed to load leave requests';
      }
    } catch (e) {
      debugPrint("❌ [LEAVE_SERVICE] getStudentLeaveRequests error: $e");
      rethrow;
    }
  }

  /// Cancel a pending leave request
  Future<bool> cancelLeaveRequest({
    required String requestId,
    required String studentId,
    String? remarks,
  }) async {
    try {
      final response = await _apiClient.post(
        '/requests/leave/$requestId/cancel',
        body: {
          'studentId': studentId,
          if (remarks != null) 'remarks': remarks,
        },
      );

      if (response.statusCode == 200) {
        return true;
      } else {
        final data = jsonDecode(response.body);
        throw data['message'] ?? 'Failed to cancel leave request';
      }
    } catch (e) {
      debugPrint("❌ [LEAVE_SERVICE] cancelLeaveRequest error: $e");
      rethrow;
    }
  }
}
