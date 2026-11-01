import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../../auth/services/auth_service.dart';
import '../../core/network/api_client.dart';
import '../models/warden_models.dart';

/// Institutional Warden Service for leave review, gate pass issuance integration,
/// command center analytics, and audit logging.
class WardenService {
  final ApiClient _apiClient;
  final AuthService _authService;

  WardenService({ApiClient? apiClient, AuthService? authService})
      : _apiClient = apiClient ?? ApiClient.instance,
        _authService = authService ?? AuthService();

  Map<String, String> _authHeaders([String? wardenId]) {
    final effectiveId = wardenId ??
        _authService.currentUser?.id ??
        _authService.currentUser?.uid;
    if (effectiveId != null && effectiveId.isNotEmpty) {
      return {'X-User-Id': effectiveId};
    }
    return {};
  }

  /// Fetch Warden command center summary metrics.
  Future<WardenSummaryModel> fetchSummary([String? wardenId]) async {
    try {
      final response = await _apiClient.get(
        '/warden/summary',
        headers: _authHeaders(wardenId),
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return WardenSummaryModel.fromJson(data);
      }
      return WardenSummaryModel.empty();
    } catch (e) {
      debugPrint("⚠️ [WARDEN_SERVICE] fetchSummary error: $e");
      return WardenSummaryModel.empty();
    }
  }

  /// Fetch operational leave requests list with optional status and search filter.
  Future<List<WardenLeaveRequestModel>> fetchLeaveRequests({
    String? status,
    String? search,
    String? wardenId,
  }) async {
    try {
      final queryParams = <String, String>{};
      if (status != null && status.isNotEmpty) {
        queryParams['status'] = status;
      }
      if (search != null && search.isNotEmpty) {
        queryParams['search'] = search;
      }

      final queryString = Uri(queryParameters: queryParams).query;
      final endpoint = queryString.isEmpty
          ? '/warden/leave-requests'
          : '/warden/leave-requests?$queryString';

      final response = await _apiClient.get(
        endpoint,
        headers: _authHeaders(wardenId),
      );

      if (response.statusCode == 200) {
        final List<dynamic> list = jsonDecode(response.body);
        return list
            .map((item) => WardenLeaveRequestModel.fromJson(item as Map<String, dynamic>))
            .toList();
      }
      return [];
    } catch (e) {
      debugPrint("⚠️ [WARDEN_SERVICE] fetchLeaveRequests error: $e");
      return [];
    }
  }

  /// Fetch pending leave requests for the inbox.
  Future<List<WardenLeaveRequestModel>> fetchPendingLeaves([String? wardenId]) async {
    try {
      final response = await _apiClient.get(
        '/warden/leave-requests/pending',
        headers: _authHeaders(wardenId),
      );

      if (response.statusCode == 200) {
        final List<dynamic> list = jsonDecode(response.body);
        return list
            .map((item) => WardenLeaveRequestModel.fromJson(item as Map<String, dynamic>))
            .toList();
      }
      return [];
    } catch (e) {
      debugPrint("⚠️ [WARDEN_SERVICE] fetchPendingLeaves error: $e");
      return [];
    }
  }

  /// Fetch single leave request detail by ID.
  Future<WardenLeaveRequestModel?> fetchLeaveDetail(String requestId, [String? wardenId]) async {
    try {
      final response = await _apiClient.get(
        '/warden/leave-requests/$requestId',
        headers: _authHeaders(wardenId),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return WardenLeaveRequestModel.fromJson(data);
      }
      return null;
    } catch (e) {
      debugPrint("⚠️ [WARDEN_SERVICE] fetchLeaveDetail error: $e");
      return null;
    }
  }

  /// Process Warden action on a leave request (APPROVE, REJECT, ASK_STUDENT).
  Future<Map<String, dynamic>> processAction(
    String requestId, {
    required String action,
    String remarks = '',
    String? wardenId,
  }) async {
    final effectiveWardenId = wardenId ??
        _authService.currentUser?.id ??
        _authService.currentUser?.uid ??
        'warden_id';

    try {
      final response = await _apiClient.post(
        '/warden/leave-requests/$requestId/action',
        headers: _authHeaders(effectiveWardenId),
        body: {
          'reviewerId': effectiveWardenId,
          'action': action,
          'remarks': remarks,
        },
      );

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      if (response.statusCode == 200) {
        return {
          'success': true,
          'message': data['message'] ?? 'Action completed successfully',
          'request': data['request'],
        };
      } else {
        return {
          'success': false,
          'message': data['message'] ?? 'Action failed (${response.statusCode})',
        };
      }
    } catch (e) {
      debugPrint("⚠️ [WARDEN_SERVICE] processAction error: $e");
      return {
        'success': false,
        'message': 'Network error: Unable to process request',
      };
    }
  }

  /// Fetch activity audit log for Warden feed.
  Future<List<WardenActivityModel>> fetchActivity({
    String? filter,
    String? wardenId,
  }) async {
    try {
      final endpoint = filter != null && filter.isNotEmpty
          ? '/warden/activity?filter=$filter'
          : '/warden/activity';

      final response = await _apiClient.get(
        endpoint,
        headers: _authHeaders(wardenId),
      );

      if (response.statusCode == 200) {
        final List<dynamic> list = jsonDecode(response.body);
        return list
            .map((item) => WardenActivityModel.fromJson(item as Map<String, dynamic>))
            .toList();
      }
      return [];
    } catch (e) {
      debugPrint("⚠️ [WARDEN_SERVICE] fetchActivity error: $e");
      return [];
    }
  }
}
