import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/network/api_client.dart';
import '../../core/network/api_exception.dart';
import '../models/mess_model.dart';

class MessService {
  final ApiClient _apiClient;

  MessService({ApiClient? apiClient})
      : _apiClient = apiClient ?? ApiClient.instance;

  static String _extractErrorMessage(http.Response response, String fallback) {
    try {
      final data = jsonDecode(response.body);
      if (data is Map && data['message'] != null) {
        return data['message'].toString();
      }
    } catch (_) {
      // Body is not JSON
    }
    switch (response.statusCode) {
      case 409:
        return 'Another published menu already exists for this date.';
      case 403:
        return "You don't have permission to perform this action.";
      case 404:
        return 'Menu or meal not found.';
      case 400:
        return 'Invalid request data.';
      case 500:
      case 502:
      case 503:
      case 504:
        return 'Server error. Please try again later.';
      default:
        return fallback;
    }
  }

  /// Sanitizes any caught error into a clean, human-readable UI message
  static String sanitizeError(dynamic error) {
    if (error == null) return 'An unexpected error occurred.';
    if (error is ApiException) {
      if (error.statusCode == 409) {
        if (error.message.toLowerCase().contains('already exists')) {
          return 'Another published menu already exists for this date.';
        }
        return error.message.isNotEmpty
            ? error.message
            : 'Another published menu already exists for this date.';
      }
      if (error.statusCode == 403) {
        return "You don't have permission to perform this action.";
      }
      if (error.statusCode == 404) {
        return 'Menu not found';
      }
      if (error.statusCode == 500) {
        return 'Unable to connect. Check your connection and try again.';
      }
      if (error.message.contains('timed out') ||
          error.message.contains('TimeoutException')) {
        return 'Unable to connect. Check your connection and try again.';
      }
      return error.message;
    }
    final s = error
        .toString()
        .replaceAll('Exception: ', '')
        .replaceAll('ApiException: ', '')
        .trim();
    if (s.contains('SocketException') ||
        s.contains('Connection refused') ||
        s.contains('Failed host lookup') ||
        s.contains('Network is unreachable') ||
        s.contains('timed out') ||
        s.contains('TimeoutException')) {
      return 'Unable to connect. Check your connection and try again.';
    }
    return s.isNotEmpty ? s : 'An unexpected error occurred.';
  }

  /// Retrieve published mess menus, optionally filtered by date or date range
  Future<List<MessMenu>> getMenus({
    String? date,
    String? startDate,
    String? endDate,
    String? requesterId,
  }) async {
    try {
      final queryParams = <String, String>{};
      if (date != null && date.isNotEmpty) {
        queryParams['date'] = date;
      }
      if (startDate != null && startDate.isNotEmpty) {
        queryParams['startDate'] = startDate;
      }
      if (endDate != null && endDate.isNotEmpty) {
        queryParams['endDate'] = endDate;
      }

      final queryString = queryParams.isNotEmpty
          ? '?${queryParams.entries.map((e) => '${e.key}=${Uri.encodeComponent(e.value)}').join('&')}'
          : '';

      final headers = <String, String>{};
      if (requesterId != null && requesterId.isNotEmpty) {
        headers['X-User-Id'] = requesterId;
      }

      final response = await _apiClient.get(
        '/mess/menus$queryString',
        headers: headers.isNotEmpty ? headers : null,
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data
            .whereType<Map<String, dynamic>>()
            .map((item) => MessMenu.fromMap(item))
            .toList();
      } else {
        throw _extractErrorMessage(response, 'Failed to load mess menus');
      }
    } catch (e) {
      debugPrint("❌ [MESS_SERVICE] getMenus error: $e");
      rethrow;
    }
  }

  /// Retrieve today's published menu. Returns null if 404 (no menu published for today)
  Future<MessMenu?> getTodayMenu({String? requesterId}) async {
    try {
      final headers = <String, String>{};
      if (requesterId != null && requesterId.isNotEmpty) {
        headers['X-User-Id'] = requesterId;
      }

      final response = await _apiClient.get(
        '/mess/menus/today',
        headers: headers.isNotEmpty ? headers : null,
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return MessMenu.fromMap(data as Map<String, dynamic>);
      } else if (response.statusCode == 404) {
        // 404 indicates no menu published for today; this is an operational state, not a crash
        return null;
      } else {
        throw _extractErrorMessage(response, "Failed to load today's menu");
      }
    } catch (e) {
      debugPrint("❌ [MESS_SERVICE] getTodayMenu error: $e");
      rethrow;
    }
  }

  /// Retrieve full detail for a published menu by id
  Future<MessMenu> getMenuById(String id, {String? requesterId}) async {
    try {
      final headers = <String, String>{};
      if (requesterId != null && requesterId.isNotEmpty) {
        headers['X-User-Id'] = requesterId;
      }

      final response = await _apiClient.get(
        '/mess/menus/$id',
        headers: headers.isNotEmpty ? headers : null,
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return MessMenu.fromMap(data as Map<String, dynamic>);
      } else {
        throw _extractErrorMessage(response, 'Failed to load mess menu');
      }
    } catch (e) {
      debugPrint("❌ [MESS_SERVICE] getMenuById error: $e");
      rethrow;
    }
  }

  // ===========================================================================
  // --- ADMIN / STAFF MANAGEMENT METHODS ---
  // ===========================================================================

  /// Retrieve all mess menus (including drafts and archived) for authorized staff/admin
  Future<List<MessMenu>> getAdminMenus({
    String? status,
    String? date,
    String? startDate,
    String? endDate,
    String? requesterId,
  }) async {
    try {
      final queryParams = <String, String>{};
      if (status != null &&
          status.isNotEmpty &&
          status.toUpperCase() != 'ALL') {
        queryParams['status'] = status.toUpperCase();
      }
      if (date != null && date.isNotEmpty) {
        queryParams['date'] = date;
      }
      if (startDate != null && startDate.isNotEmpty) {
        queryParams['startDate'] = startDate;
      }
      if (endDate != null && endDate.isNotEmpty) {
        queryParams['endDate'] = endDate;
      }

      final queryString = queryParams.isNotEmpty
          ? '?${queryParams.entries.map((e) => '${e.key}=${Uri.encodeComponent(e.value)}').join('&')}'
          : '';

      final headers = <String, String>{};
      if (requesterId != null && requesterId.isNotEmpty) {
        headers['X-User-Id'] = requesterId;
      }

      final response = await _apiClient.get(
        '/mess/admin/menus$queryString',
        headers: headers.isNotEmpty ? headers : null,
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data
            .whereType<Map<String, dynamic>>()
            .map((item) => MessMenu.fromMap(item))
            .toList();
      } else {
        throw _extractErrorMessage(response, 'Failed to load admin mess menus');
      }
    } catch (e) {
      debugPrint("❌ [MESS_SERVICE] getAdminMenus error: $e");
      rethrow;
    }
  }

  /// Retrieve full detail for any menu (draft, published, or archived) for staff/admin
  Future<MessMenu> getAdminMenuById(String id, {String? requesterId}) async {
    try {
      final headers = <String, String>{};
      if (requesterId != null && requesterId.isNotEmpty) {
        headers['X-User-Id'] = requesterId;
      }

      final response = await _apiClient.get(
        '/mess/admin/menus/$id',
        headers: headers.isNotEmpty ? headers : null,
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return MessMenu.fromMap(data as Map<String, dynamic>);
      } else {
        throw _extractErrorMessage(response, 'Failed to load admin menu details');
      }
    } catch (e) {
      debugPrint("❌ [MESS_SERVICE] getAdminMenuById error: $e");
      rethrow;
    }
  }

  /// Create a new mess menu (draft or published)
  Future<MessMenu> createMenu({
    required String menuDate,
    String status = 'DRAFT',
    required List<Map<String, dynamic>> meals,
    required String requesterId,
  }) async {
    try {
      final headers = <String, String>{
        'X-User-Id': requesterId,
      };

      final payload = {
        'menuDate': menuDate,
        'status': status.toUpperCase(),
        'meals': meals,
      };

      final response = await _apiClient.post(
        '/mess/menus',
        headers: headers,
        body: payload,
      );

      if (response.statusCode == 201) {
        final data = jsonDecode(response.body);
        return MessMenu.fromMap(data as Map<String, dynamic>);
      } else {
        throw _extractErrorMessage(response, 'Failed to create menu');
      }
    } catch (e) {
      debugPrint("❌ [MESS_SERVICE] createMenu error: $e");
      rethrow;
    }
  }

  /// Update an existing menu (draft or published)
  Future<MessMenu> updateMenu(
    String id, {
    String? menuDate,
    String? status,
    List<Map<String, dynamic>>? meals,
    required String requesterId,
  }) async {
    try {
      final headers = <String, String>{
        'X-User-Id': requesterId,
      };

      final payload = <String, dynamic>{};
      if (menuDate != null) payload['menuDate'] = menuDate;
      if (status != null) payload['status'] = status.toUpperCase();
      if (meals != null) payload['meals'] = meals;

      final response = await _apiClient.put(
        '/mess/menus/$id',
        headers: headers,
        body: payload,
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return MessMenu.fromMap(data as Map<String, dynamic>);
      } else {
        throw _extractErrorMessage(response, 'Failed to update menu');
      }
    } catch (e) {
      debugPrint("❌ [MESS_SERVICE] updateMenu error: $e");
      rethrow;
    }
  }

  /// Publish a draft menu
  Future<MessMenu> publishMenu(String id, {required String requesterId}) async {
    try {
      final headers = <String, String>{
        'X-User-Id': requesterId,
      };

      final response = await _apiClient.post(
        '/mess/menus/$id/publish',
        headers: headers,
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return MessMenu.fromMap(data as Map<String, dynamic>);
      } else {
        throw _extractErrorMessage(response, 'Failed to publish menu');
      }
    } catch (e) {
      debugPrint("❌ [MESS_SERVICE] publishMenu error: $e");
      rethrow;
    }
  }

  /// Archive a menu
  Future<MessMenu> archiveMenu(String id, {required String requesterId}) async {
    try {
      final headers = <String, String>{
        'X-User-Id': requesterId,
      };

      final response = await _apiClient.post(
        '/mess/menus/$id/archive',
        headers: headers,
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return MessMenu.fromMap(data as Map<String, dynamic>);
      } else {
        throw _extractErrorMessage(response, 'Failed to archive menu');
      }
    } catch (e) {
      debugPrint("❌ [MESS_SERVICE] archiveMenu error: $e");
      rethrow;
    }
  }

  // ===========================================================================
  // --- STEP 22D: MESS FEEDBACK & ANALYTICS METHODS ---
  // ===========================================================================

  /// Student: Submit feedback for a meal in a published menu
  Future<MessFeedback> submitFeedback({
    required String menuId,
    required String mealId,
    required int rating,
    String? category,
    String? comment,
    required String requesterId,
  }) async {
    try {
      final headers = {'X-User-Id': requesterId};
      final payload = {
        'menuId': menuId,
        'mealId': mealId,
        'rating': rating,
        if (category != null && category.isNotEmpty) 'category': category,
        if (comment != null && comment.isNotEmpty) 'comment': comment,
      };

      final response = await _apiClient.post(
        '/mess/feedback',
        headers: headers,
        body: payload,
      );

      if (response.statusCode == 201) {
        final data = jsonDecode(response.body);
        return MessFeedback.fromMap(data as Map<String, dynamic>);
      } else {
        throw _extractErrorMessage(response, 'Failed to submit feedback');
      }
    } catch (e) {
      debugPrint("❌ [MESS_SERVICE] submitFeedback error: $e");
      rethrow;
    }
  }

  /// Student: Get my submitted feedback (optionally filtered by menuId, mealId, or date)
  Future<List<MessFeedback>> getMyFeedback({
    String? menuId,
    String? mealId,
    String? date,
    required String requesterId,
  }) async {
    try {
      final queryParams = <String, String>{};
      if (menuId != null && menuId.isNotEmpty) queryParams['menuId'] = menuId;
      if (mealId != null && mealId.isNotEmpty) queryParams['mealId'] = mealId;
      if (date != null && date.isNotEmpty) queryParams['date'] = date;

      final queryString = queryParams.isNotEmpty
          ? '?${queryParams.entries.map((e) => '${e.key}=${Uri.encodeComponent(e.value)}').join('&')}'
          : '';

      final headers = {'X-User-Id': requesterId};

      final response = await _apiClient.get(
        '/mess/feedback/my$queryString',
        headers: headers,
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data
            .whereType<Map<String, dynamic>>()
            .map((item) => MessFeedback.fromMap(item))
            .toList();
      } else {
        throw _extractErrorMessage(response, 'Failed to load feedback');
      }
    } catch (e) {
      debugPrint("❌ [MESS_SERVICE] getMyFeedback error: $e");
      rethrow;
    }
  }

  /// Student: Get my feedback for a specific meal
  Future<MessFeedback?> getMealFeedback(
    String mealId, {
    required String requesterId,
  }) async {
    try {
      final headers = {'X-User-Id': requesterId};
      final response = await _apiClient.get(
        '/mess/meals/$mealId/feedback',
        headers: headers,
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['feedback'] != null) {
          return MessFeedback.fromMap(data['feedback'] as Map<String, dynamic>);
        }
        return null;
      } else {
        throw _extractErrorMessage(response, 'Failed to load meal feedback');
      }
    } catch (e) {
      debugPrint("❌ [MESS_SERVICE] getMealFeedback error: $e");
      rethrow;
    }
  }

  /// Student: Update own feedback
  Future<MessFeedback> updateFeedback(
    String feedbackId, {
    required int rating,
    String? category,
    String? comment,
    required String requesterId,
  }) async {
    try {
      final headers = {'X-User-Id': requesterId};
      final payload = {
        'rating': rating,
        'category': category,
        'comment': comment ?? '',
      };

      final response = await _apiClient.put(
        '/mess/feedback/$feedbackId',
        headers: headers,
        body: payload,
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return MessFeedback.fromMap(data as Map<String, dynamic>);
      } else {
        throw _extractErrorMessage(response, 'Failed to update feedback');
      }
    } catch (e) {
      debugPrint("❌ [MESS_SERVICE] updateFeedback error: $e");
      rethrow;
    }
  }

  // --- ADMIN / STAFF ANALYTICS METHODS ---

  /// Admin/Staff: Get summary analytics
  Future<FeedbackSummary> getFeedbackSummary({
    String? startDate,
    String? endDate,
    String? mealType,
    String? menuId,
    String? mealId,
    required String requesterId,
  }) async {
    try {
      final queryParams = <String, String>{};
      if (startDate != null && startDate.isNotEmpty) {
        queryParams['startDate'] = startDate;
      }
      if (endDate != null && endDate.isNotEmpty) {
        queryParams['endDate'] = endDate;
      }
      if (mealType != null &&
          mealType.isNotEmpty &&
          mealType.toUpperCase() != 'ALL') {
        queryParams['mealType'] = mealType.toUpperCase();
      }
      if (menuId != null && menuId.isNotEmpty) queryParams['menuId'] = menuId;
      if (mealId != null && mealId.isNotEmpty) queryParams['mealId'] = mealId;

      final queryString = queryParams.isNotEmpty
          ? '?${queryParams.entries.map((e) => '${e.key}=${Uri.encodeComponent(e.value)}').join('&')}'
          : '';

      final headers = {'X-User-Id': requesterId};
      final response = await _apiClient.get(
        '/mess/admin/feedback/summary$queryString',
        headers: headers,
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return FeedbackSummary.fromMap(data as Map<String, dynamic>);
      } else {
        throw _extractErrorMessage(response, 'Failed to load feedback summary');
      }
    } catch (e) {
      debugPrint("❌ [MESS_SERVICE] getFeedbackSummary error: $e");
      rethrow;
    }
  }

  /// Admin/Staff: Get trends analytics over time
  Future<List<FeedbackTrend>> getFeedbackTrends({
    String? startDate,
    String? endDate,
    String? mealType,
    required String requesterId,
  }) async {
    try {
      final queryParams = <String, String>{};
      if (startDate != null && startDate.isNotEmpty) {
        queryParams['startDate'] = startDate;
      }
      if (endDate != null && endDate.isNotEmpty) {
        queryParams['endDate'] = endDate;
      }
      if (mealType != null &&
          mealType.isNotEmpty &&
          mealType.toUpperCase() != 'ALL') {
        queryParams['mealType'] = mealType.toUpperCase();
      }

      final queryString = queryParams.isNotEmpty
          ? '?${queryParams.entries.map((e) => '${e.key}=${Uri.encodeComponent(e.value)}').join('&')}'
          : '';

      final headers = {'X-User-Id': requesterId};
      final response = await _apiClient.get(
        '/mess/admin/feedback/trends$queryString',
        headers: headers,
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final List<dynamic> trendsList = data['trends'] ?? [];
        return trendsList
            .whereType<Map<String, dynamic>>()
            .map((item) => FeedbackTrend.fromMap(item))
            .toList();
      } else {
        throw _extractErrorMessage(response, 'Failed to load feedback trends');
      }
    } catch (e) {
      debugPrint("❌ [MESS_SERVICE] getFeedbackTrends error: $e");
      rethrow;
    }
  }

  /// Admin/Staff: Get categories & recurring signals analytics
  Future<Map<String, dynamic>> getFeedbackCategories({
    String? startDate,
    String? endDate,
    String? mealType,
    required String requesterId,
  }) async {
    try {
      final queryParams = <String, String>{};
      if (startDate != null && startDate.isNotEmpty) {
        queryParams['startDate'] = startDate;
      }
      if (endDate != null && endDate.isNotEmpty) {
        queryParams['endDate'] = endDate;
      }
      if (mealType != null &&
          mealType.isNotEmpty &&
          mealType.toUpperCase() != 'ALL') {
        queryParams['mealType'] = mealType.toUpperCase();
      }

      final queryString = queryParams.isNotEmpty
          ? '?${queryParams.entries.map((e) => '${e.key}=${Uri.encodeComponent(e.value)}').join('&')}'
          : '';

      final headers = {'X-User-Id': requesterId};
      final response = await _apiClient.get(
        '/mess/admin/feedback/categories$queryString',
        headers: headers,
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final List<dynamic> catList = data['categories'] ?? [];
        final List<dynamic> sigList = data['signals'] ?? [];

        return {
          'categories': catList
              .whereType<Map<String, dynamic>>()
              .map((item) => FeedbackCategoryStat.fromMap(item))
              .toList(),
          'signals': sigList
              .whereType<Map<String, dynamic>>()
              .map((item) => FeedbackSignal.fromMap(item))
              .toList(),
        };
      } else {
        throw _extractErrorMessage(response, 'Failed to load feedback categories');
      }
    } catch (e) {
      debugPrint("❌ [MESS_SERVICE] getFeedbackCategories error: $e");
      rethrow;
    }
  }

  /// Admin/Staff: Get feedback comments
  Future<List<FeedbackCommentItem>> getFeedbackComments({
    String? startDate,
    String? endDate,
    String? mealType,
    String? category,
    int limit = 50,
    required String requesterId,
  }) async {
    try {
      final queryParams = <String, String>{};
      if (startDate != null && startDate.isNotEmpty) {
        queryParams['startDate'] = startDate;
      }
      if (endDate != null && endDate.isNotEmpty) {
        queryParams['endDate'] = endDate;
      }
      if (mealType != null &&
          mealType.isNotEmpty &&
          mealType.toUpperCase() != 'ALL') {
        queryParams['mealType'] = mealType.toUpperCase();
      }
      if (category != null &&
          category.isNotEmpty &&
          category.toUpperCase() != 'ALL') {
        queryParams['category'] = category.toUpperCase();
      }
      queryParams['limit'] = limit.toString();

      final queryString =
          '?${queryParams.entries.map((e) => '${e.key}=${Uri.encodeComponent(e.value)}').join('&')}';

      final headers = {'X-User-Id': requesterId};
      final response = await _apiClient.get(
        '/mess/admin/feedback/comments$queryString',
        headers: headers,
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data
            .whereType<Map<String, dynamic>>()
            .map((item) => FeedbackCommentItem.fromMap(item))
            .toList();
      } else {
        throw _extractErrorMessage(response, 'Failed to load feedback comments');
      }
    } catch (e) {
      debugPrint("❌ [MESS_SERVICE] getFeedbackComments error: $e");
      rethrow;
    }
  }

  // ===========================================================================
  // --- MESS STAFF VERIFICATION, BATCH SYNC & OPERATIONAL METHODS ---
  // ===========================================================================

  static const String _offlineQueueKey = 'mess_offline_entry_queue';

  /// Verifies a single student's dining eligibility and records a meal entry.
  /// Used for individual QR Fallback scanning or direct verification.
  Future<Map<String, dynamic>> verifyMealEntry({
    required String studentId,
    String? studentName,
    String? registrationNumber,
    required String mealType,
    String? date,
    String? mealId,
    String? menuId,
    String verificationMode = 'QR_FALLBACK',
    String? idempotencyKey,
    String? qrPayload,
    String? signature,
    String? requesterId,
  }) async {
    try {
      final headers = <String, String>{};
      if (requesterId != null && requesterId.isNotEmpty) {
        headers['X-User-Id'] = requesterId;
      }

      final body = <String, dynamic>{
        'studentId': studentId,
        'mealType': mealType,
        'verificationMode': verificationMode,
      };
      if (studentName != null) body['studentName'] = studentName;
      if (registrationNumber != null) {
        body['registrationNumber'] = registrationNumber;
      }
      if (date != null) body['date'] = date;
      if (mealId != null) body['mealId'] = mealId;
      if (menuId != null) body['menuId'] = menuId;
      if (idempotencyKey != null) body['idempotencyKey'] = idempotencyKey;
      if (qrPayload != null) body['qrPayload'] = qrPayload;
      if (signature != null) body['signature'] = signature;

      final response = await _apiClient.post(
        '/mess/entries/verify',
        body: body,
        headers: headers.isNotEmpty ? headers : null,
      );

      final data = jsonDecode(response.body);
      if (response.statusCode == 201 || response.statusCode == 200) {
        return {
          'status': 'VERIFIED',
          'message': data['message'] ?? 'Student verified successfully',
          'entry': data['entry'] != null
              ? MealEntryRecord.fromMap(data['entry'])
              : null,
          'isReplay': data['isReplay'] == true,
        };
      } else if (response.statusCode == 409) {
        return {
          'status': 'ALREADY_USED',
          'message': data['message'] ?? 'Student already checked in for this meal',
          'existingEntry': data['existingEntry'] != null
              ? MealEntryRecord.fromMap(data['existingEntry'])
              : null,
        };
      } else if (response.statusCode == 403) {
        return {
          'status': 'NOT_ELIGIBLE',
          'message': data['message'] ?? 'Student is not eligible for this meal',
        };
      } else {
        return {
          'status': 'INVALID',
          'message': data['message'] ?? 'Verification failed',
        };
      }
    } catch (e) {
      debugPrint("❌ [MESS_SERVICE] verifyMealEntry error: $e");
      rethrow;
    }
  }

  /// Batch syncs verified meal entry records to backend idempotently.
  Future<Map<String, dynamic>> batchSyncMealEntries({
    required String mealType,
    required String date,
    required List<Map<String, dynamic>> records,
    String? requesterId,
  }) async {
    try {
      final headers = <String, String>{};
      if (requesterId != null && requesterId.isNotEmpty) {
        headers['X-User-Id'] = requesterId;
      }

      final response = await _apiClient.post(
        '/mess/entries/batch-sync',
        body: {
          'mealType': mealType,
          'date': date,
          'records': records,
        },
        headers: headers.isNotEmpty ? headers : null,
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final list = (data['records'] as List<dynamic>?)
                ?.whereType<Map<String, dynamic>>()
                .map((r) => MealEntryRecord.fromMap(r))
                .toList() ??
            [];
        return {
          'newSynced': data['newSynced'] ?? 0,
          'duplicates': data['duplicates'] ?? 0,
          'totalRecords': data['totalRecords'] ?? 0,
          'records': list,
        };
      } else {
        throw _extractErrorMessage(response, 'Failed to batch sync meal entries');
      }
    } catch (e) {
      debugPrint("❌ [MESS_SERVICE] batchSyncMealEntries error: $e");
      rethrow;
    }
  }

  /// Retrieves today's operational stats, current meal window, and counts.
  Future<TodayMealStats> getTodayMealStats({String? requesterId}) async {
    try {
      final headers = <String, String>{};
      if (requesterId != null && requesterId.isNotEmpty) {
        headers['X-User-Id'] = requesterId;
      }

      final response = await _apiClient.get(
        '/mess/entries/today',
        headers: headers.isNotEmpty ? headers : null,
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return TodayMealStats.fromMap(data as Map<String, dynamic>);
      } else {
        throw _extractErrorMessage(response, "Failed to load today's meal stats");
      }
    } catch (e) {
      debugPrint("❌ [MESS_SERVICE] getTodayMealStats error: $e");
      rethrow;
    }
  }

  /// Retrieves aggregate dining operational metrics for analytics screen.
  Future<MessOperationalAnalytics> getMessOperationalAnalytics({
    String? requesterId,
  }) async {
    try {
      final headers = <String, String>{};
      if (requesterId != null && requesterId.isNotEmpty) {
        headers['X-User-Id'] = requesterId;
      }

      final response = await _apiClient.get(
        '/mess/entries/analytics',
        headers: headers.isNotEmpty ? headers : null,
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return MessOperationalAnalytics.fromMap(data as Map<String, dynamic>);
      } else {
        throw _extractErrorMessage(response, 'Failed to load mess operational analytics');
      }
    } catch (e) {
      debugPrint("❌ [MESS_SERVICE] getMessOperationalAnalytics error: $e");
      rethrow;
    }
  }

  // ===========================================================================
  // --- OFFLINE VERIFICATION QUEUE & IDEMPOTENCY LEDGER ---
  // ===========================================================================

  /// Persists a verified meal entry locally when verifier is offline.
  Future<void> queueOfflineMealEntry(MealEntryRecord record) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final currentQueue = prefs.getStringList(_offlineQueueKey) ?? [];
      final recordJson = jsonEncode(record.toMap());
      currentQueue.add(recordJson);
      await prefs.setStringList(_offlineQueueKey, currentQueue);
    } catch (e) {
      debugPrint("❌ [MESS_SERVICE] queueOfflineMealEntry error: $e");
    }
  }

  /// Retrieves all pending offline meal entries.
  Future<List<MealEntryRecord>> getQueuedOfflineMealEntries() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final currentQueue = prefs.getStringList(_offlineQueueKey) ?? [];
      final records = <MealEntryRecord>[];
      for (final raw in currentQueue) {
        try {
          final decoded = jsonDecode(raw);
          if (decoded is Map<String, dynamic>) {
            records.add(MealEntryRecord.fromMap(decoded));
          }
        } catch (_) {}
      }
      return records;
    } catch (e) {
      debugPrint("❌ [MESS_SERVICE] getQueuedOfflineMealEntries error: $e");
      return [];
    }
  }

  /// Clears the local offline queue after successful synchronization.
  Future<int> clearQueuedOfflineMealEntries() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final current = prefs.getStringList(_offlineQueueKey) ?? [];
      final count = current.length;
      await prefs.remove(_offlineQueueKey);
      return count;
    } catch (e) {
      debugPrint("❌ [MESS_SERVICE] clearQueuedOfflineMealEntries error: $e");
      return 0;
    }
  }

  /// Synchronizes all locally queued offline entries to the backend idempotently.
  Future<Map<String, dynamic>> syncQueuedOfflineMealEntries({
    String? requesterId,
  }) async {
    final queued = await getQueuedOfflineMealEntries();
    if (queued.isEmpty) {
      return {'synced': 0, 'duplicates': 0, 'total': 0};
    }

    final recordsMap = queued.map((r) => r.toMap()).toList();
    final firstRecord = queued.first;

    final result = await batchSyncMealEntries(
      mealType: firstRecord.mealType,
      date: firstRecord.entryDate,
      records: recordsMap,
      requesterId: requesterId,
    );

    // After successful batch sync, clear the queue
    await clearQueuedOfflineMealEntries();
    return {
      'synced': result['newSynced'] ?? 0,
      'duplicates': result['duplicates'] ?? 0,
      'total': result['totalRecords'] ?? 0,
    };
  }
}

