import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../../core/network/api_client.dart';
import '../models/gate_pass_model.dart';

class GatePassService {
  final ApiClient _apiClient;

  GatePassService({ApiClient? apiClient})
      : _apiClient = apiClient ?? ApiClient.instance;

  /// Submit a new gate pass request tied to an approved leave request
  Future<GatePassModel> createGatePass({
    required String studentId,
    required String leaveRequestId,
    required String destination,
    required String reason,
    required String expectedExitTime,
    required String expectedReturnTime,
  }) async {
    try {
      final response = await _apiClient.post(
        '/requests/gate-pass',
        body: {
          'studentId': studentId,
          'leaveRequestId': leaveRequestId,
          'destination': destination,
          'reason': reason,
          'expectedExitTime': expectedExitTime,
          'expectedReturnTime': expectedReturnTime,
        },
      );

      final data = jsonDecode(response.body);
      if (response.statusCode == 201) {
        return GatePassModel.fromMap(data['gatePass']);
      } else {
        throw data['message'] ?? 'Failed to submit gate pass request';
      }
    } catch (e) {
      debugPrint("❌ [GATE_PASS_SERVICE] createGatePass error: $e");
      rethrow;
    }
  }

  /// Fetch all gate passes for a student (newest first)
  Future<List<GatePassModel>> getStudentGatePasses(String studentId) async {
    try {
      final response = await _apiClient.get('/requests/gate-pass/$studentId');
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data
            .map((item) => GatePassModel.fromMap(item as Map<String, dynamic>))
            .toList();
      } else if (response.statusCode == 404) {
        return [];
      } else {
        final data = jsonDecode(response.body);
        throw data['message'] ?? 'Failed to load gate passes';
      }
    } catch (e) {
      debugPrint("❌ [GATE_PASS_SERVICE] getStudentGatePasses error: $e");
      rethrow;
    }
  }

  /// Fetch active gate pass and signed security credential for a student
  Future<GatePassModel?> getActiveGatePass(String studentId) async {
    try {
      final response = await _apiClient.get('/requests/gate-pass/active/$studentId');
      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(response.body);
        if (data['hasActive'] == true && data['gatePass'] != null) {
          final credential = data['credential'] as String?;
          return GatePassModel.fromMap(data['gatePass'], credential);
        }
        return null;
      } else {
        return null;
      }
    } catch (e) {
      debugPrint("❌ [GATE_PASS_SERVICE] getActiveGatePass error: $e");
      return null;
    }
  }

  /// Retrieve the signed credential token for an issued/exited pass
  Future<Map<String, dynamic>?> getGatePassCredential(String passId, {String? studentId}) async {
    try {
      final queryParam = studentId != null ? '?studentId=$studentId' : '';
      final response = await _apiClient.get('/requests/gate-pass/$passId/credential$queryParam');
      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      } else {
        final data = jsonDecode(response.body);
        throw data['message'] ?? 'Failed to retrieve credential';
      }
    } catch (e) {
      debugPrint("❌ [GATE_PASS_SERVICE] getGatePassCredential error: $e");
      rethrow;
    }
  }
}
