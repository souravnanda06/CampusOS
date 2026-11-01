import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../../core/network/api_client.dart';
import '../models/notice_model.dart';

class NoticeService {
  final ApiClient _apiClient;

  NoticeService({ApiClient? apiClient})
      : _apiClient = apiClient ?? ApiClient.instance;

  /// Retrieve notices targeted to the requester (or staff overview)
  Future<List<NoticeModel>> getNotices({
    String? requesterId,
    bool includeExpired = false,
    String? category,
    String? priority,
  }) async {
    try {
      final queryParams = <String, String>{};
      if (requesterId != null && requesterId.isNotEmpty) {
        queryParams['requesterId'] = requesterId;
      }
      if (includeExpired) {
        queryParams['includeExpired'] = 'true';
      }
      if (category != null && category.isNotEmpty) {
        queryParams['category'] = category;
      }
      if (priority != null && priority.isNotEmpty) {
        queryParams['priority'] = priority;
      }

      final queryString = queryParams.isNotEmpty
          ? '?${queryParams.entries.map((e) => '${e.key}=${Uri.encodeComponent(e.value)}').join('&')}'
          : '';

      final headers = <String, String>{};
      if (requesterId != null && requesterId.isNotEmpty) {
        headers['X-User-Id'] = requesterId;
      }

      final response = await _apiClient.get(
        '/notices$queryString',
        headers: headers.isNotEmpty ? headers : null,
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data
            .map((item) => NoticeModel.fromMap(item as Map<String, dynamic>))
            .toList();
      } else {
        final data = jsonDecode(response.body);
        throw data['message'] ?? 'Failed to load notices';
      }
    } catch (e) {
      debugPrint("❌ [NOTICE_SERVICE] getNotices error: $e");
      rethrow;
    }
  }

  /// Retrieve full detail for a notice
  Future<NoticeModel> getNotice(String id, {String? requesterId}) async {
    try {
      final headers = <String, String>{};
      if (requesterId != null && requesterId.isNotEmpty) {
        headers['X-User-Id'] = requesterId;
      }

      final queryString = requesterId != null ? '?requesterId=$requesterId' : '';
      final response = await _apiClient.get(
        '/notices/$id$queryString',
        headers: headers.isNotEmpty ? headers : null,
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return NoticeModel.fromMap(data as Map<String, dynamic>);
      } else {
        final data = jsonDecode(response.body);
        throw data['message'] ?? 'Failed to load notice detail';
      }
    } catch (e) {
      debugPrint("❌ [NOTICE_SERVICE] getNotice error: $e");
      rethrow;
    }
  }

  /// Mark notice as read for the authenticated student/requester
  Future<bool> markNoticeRead(String id, {required String requesterId}) async {
    try {
      final headers = <String, String>{
        'X-User-Id': requesterId,
      };

      final response = await _apiClient.post(
        '/notices/$id/read',
        headers: headers,
        body: {'requesterId': requesterId},
      );

      if (response.statusCode == 200) {
        return true;
      } else {
        debugPrint("⚠️ [NOTICE_SERVICE] markNoticeRead non-200: ${response.statusCode} - ${response.body}");
        return false;
      }
    } catch (e) {
      debugPrint("⚠️ [NOTICE_SERVICE] markNoticeRead non-blocking error: $e");
      return false;
    }
  }

  Future<NoticeModel> createNotice(Map<String, dynamic> data, {required String requesterId}) async {
    try {
      final headers = {'X-User-Id': requesterId};
      final response = await _apiClient.post(
        '/notices',
        headers: headers,
        body: data,
      );

      if (response.statusCode == 201) {
        return NoticeModel.fromMap(jsonDecode(response.body) as Map<String, dynamic>);
      } else {
        final err = jsonDecode(response.body);
        throw err['message'] ?? 'Failed to create notice';
      }
    } catch (e) {
      debugPrint("❌ [NOTICE_SERVICE] createNotice error: $e");
      rethrow;
    }
  }

  Future<NoticeModel> updateNotice(String id, Map<String, dynamic> data, {required String requesterId}) async {
    try {
      final headers = {'X-User-Id': requesterId};
      final response = await _apiClient.patch(
        '/notices/$id',
        headers: headers,
        body: data,
      );

      if (response.statusCode == 200) {
        return NoticeModel.fromMap(jsonDecode(response.body) as Map<String, dynamic>);
      } else {
        final err = jsonDecode(response.body);
        throw err['message'] ?? 'Failed to update notice';
      }
    } catch (e) {
      debugPrint("❌ [NOTICE_SERVICE] updateNotice error: $e");
      rethrow;
    }
  }

  Future<NoticeModel> archiveNotice(String id, {required String requesterId}) async {
    try {
      final headers = {'X-User-Id': requesterId};
      final response = await _apiClient.post(
        '/notices/$id/archive',
        headers: headers,
      );

      if (response.statusCode == 200) {
        return NoticeModel.fromMap(jsonDecode(response.body) as Map<String, dynamic>);
      } else {
        final err = jsonDecode(response.body);
        throw err['message'] ?? 'Failed to archive notice';
      }
    } catch (e) {
      debugPrint("❌ [NOTICE_SERVICE] archiveNotice error: $e");
      rethrow;
    }
  }

  /// Retrieve authorized delivery metrics for notice owner/admin
  Future<Map<String, dynamic>> getDeliveryMetrics(String noticeId, {required String requesterId}) async {
    try {
      final headers = {'X-User-Id': requesterId};
      final response = await _apiClient.get(
        '/notices/$noticeId/delivery',
        headers: headers,
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      } else {
        final err = jsonDecode(response.body);
        throw err['message'] ?? 'Failed to load delivery metrics';
      }
    } catch (e) {
      debugPrint("❌ [NOTICE_SERVICE] getDeliveryMetrics error: $e");
      rethrow;
    }
  }

  /// Register or update device FCM token on the backend
  Future<bool> registerDeviceToken(String token, {String deviceType = 'android', required String requesterId}) async {
    try {
      final headers = {'X-User-Id': requesterId};
      final response = await _apiClient.post(
        '/notifications/device-token',
        headers: headers,
        body: {
          'token': token,
          'deviceType': deviceType,
        },
      );
      return response.statusCode == 200 || response.statusCode == 201;
    } catch (e) {
      debugPrint("⚠️ [NOTICE_SERVICE] registerDeviceToken non-fatal error: $e");
      return false;
    }
  }

  /// Remove/deactivate device token on backend logout
  Future<bool> removeDeviceToken(String token, {required String requesterId}) async {
    try {
      final headers = {'X-User-Id': requesterId};
      final response = await _apiClient.delete(
        '/notifications/device-token',
        headers: headers,
        body: {'token': token},
      );
      return response.statusCode == 200;
    } catch (e) {
      debugPrint("⚠️ [NOTICE_SERVICE] removeDeviceToken non-fatal error: $e");
      return false;
    }
  }
}
