import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../../auth/models/user_model.dart';
import '../../core/network/api_client.dart';
import '../models/admin_dashboard_models.dart';

class AdminDashboardService {
  final ApiClient _apiClient;

  AdminDashboardService({ApiClient? apiClient})
      : _apiClient = apiClient ?? ApiClient.instance;

  Map<String, String>? _headers(String? requesterId) {
    if (requesterId == null || requesterId.isEmpty) return null;
    return {'X-User-Id': requesterId};
  }

  Future<AdminDashboardSummaryModel> getDashboardSummary({String? requesterId}) async {
    try {
      final response = await _apiClient.get(
        '/admin/dashboard/summary',
        headers: _headers(requesterId),
      );

      final data = jsonDecode(response.body);
      if (response.statusCode == 200) {
        return AdminDashboardSummaryModel.fromMap(data);
      } else {
        throw data['message'] ?? 'Failed to load dashboard summary';
      }
    } catch (e) {
      debugPrint("❌ [ADMIN_SERVICE] getDashboardSummary error: $e");
      rethrow;
    }
  }

  Future<List<AdminComplaintItemModel>> getComplaints({
    String? status,
    String? priority,
    String? category,
    String? assignedTo,
    bool? ageing,
    String? search,
    String? order,
    String? requesterId,
  }) async {
    try {
      final queryParams = <String, dynamic>{};
      if (status != null && status.isNotEmpty) queryParams['status'] = status;
      if (priority != null && priority.isNotEmpty) queryParams['priority'] = priority;
      if (category != null && category.isNotEmpty) queryParams['category'] = category;
      if (assignedTo != null && assignedTo.isNotEmpty) queryParams['assignedTo'] = assignedTo;
      if (ageing == true) queryParams['ageing'] = 'true';
      if (search != null && search.isNotEmpty) queryParams['search'] = search;
      if (order != null && order.isNotEmpty) queryParams['order'] = order;

      final response = await _apiClient.get(
        '/admin/complaints',
        queryParameters: queryParams,
        headers: _headers(requesterId),
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data.map((item) => AdminComplaintItemModel.fromMap(item as Map<String, dynamic>)).toList();
      } else {
        final data = jsonDecode(response.body);
        throw data['message'] ?? 'Failed to load complaints queue';
      }
    } catch (e) {
      debugPrint("❌ [ADMIN_SERVICE] getComplaints error: $e");
      rethrow;
    }
  }

  Future<List<AdminAgeingComplaintModel>> getAgeingComplaints({String? requesterId}) async {
    try {
      final response = await _apiClient.get(
        '/admin/complaints/ageing',
        headers: _headers(requesterId),
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data.map((item) => AdminAgeingComplaintModel.fromMap(item as Map<String, dynamic>)).toList();
      } else {
        final data = jsonDecode(response.body);
        throw data['message'] ?? 'Failed to load ageing complaints';
      }
    } catch (e) {
      debugPrint("❌ [ADMIN_SERVICE] getAgeingComplaints error: $e");
      rethrow;
    }
  }

  Future<List<StaffWorkloadModel>> getWorkload({String? requesterId}) async {
    try {
      final response = await _apiClient.get(
        '/admin/complaints/workload',
        headers: _headers(requesterId),
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data.map((item) => StaffWorkloadModel.fromMap(item as Map<String, dynamic>)).toList();
      } else {
        final data = jsonDecode(response.body);
        throw data['message'] ?? 'Failed to load staff workload';
      }
    } catch (e) {
      debugPrint("❌ [ADMIN_SERVICE] getWorkload error: $e");
      rethrow;
    }
  }

  Future<List<CategoryDistributionModel>> getCategoriesDistribution({String? requesterId}) async {
    try {
      final response = await _apiClient.get(
        '/admin/complaints/categories',
        headers: _headers(requesterId),
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data.map((item) => CategoryDistributionModel.fromMap(item as Map<String, dynamic>)).toList();
      } else {
        final data = jsonDecode(response.body);
        throw data['message'] ?? 'Failed to load category counts';
      }
    } catch (e) {
      debugPrint("❌ [ADMIN_SERVICE] getCategoriesDistribution error: $e");
      rethrow;
    }
  }

  Future<List<StaffUserModel>> getStaffList({String? requesterId}) async {
    try {
      final response = await _apiClient.get(
        '/admin/staff',
        headers: _headers(requesterId),
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data.map((item) => StaffUserModel.fromMap(item as Map<String, dynamic>)).toList();
      } else {
        final data = jsonDecode(response.body);
        throw data['message'] ?? 'Failed to load staff list';
      }
    } catch (e) {
      debugPrint("❌ [ADMIN_SERVICE] getStaffList error: $e");
      rethrow;
    }
  }

  Future<AdminComplaintDetailModel> getComplaintDetail(String id, {String? requesterId}) async {
    try {
      final response = await _apiClient.get(
        '/admin/complaints/$id',
        headers: _headers(requesterId),
      );

      final data = jsonDecode(response.body);
      if (response.statusCode == 200) {
        return AdminComplaintDetailModel.fromMap(data);
      } else {
        throw data['message'] ?? 'Failed to load complaint details';
      }
    } catch (e) {
      debugPrint("❌ [ADMIN_SERVICE] getComplaintDetail error: $e");
      rethrow;
    }
  }

  Future<void> assignComplaint({
    required String complaintId,
    required String actorId,
    required String assignedTo,
    String? remarks,
  }) async {
    try {
      final response = await _apiClient.post(
        '/complaints/$complaintId/assign',
        body: {
          'actorId': actorId,
          'assignedTo': assignedTo,
          if (remarks != null && remarks.isNotEmpty) 'remarks': remarks,
        },
      );

      final data = jsonDecode(response.body);
      if (response.statusCode != 200) {
        throw data['message'] ?? 'Failed to assign complaint';
      }
    } catch (e) {
      debugPrint("❌ [ADMIN_SERVICE] assignComplaint error: $e");
      rethrow;
    }
  }

  Future<void> takeComplaintAction({
    required String complaintId,
    required String actorId,
    required String action,
    String? remarks,
    String? assignedTo,
    String? otp,
  }) async {
    try {
      final response = await _apiClient.post(
        '/complaints/$complaintId/action',
        body: {
          'actorId': actorId,
          'action': action.toUpperCase(),
          if (remarks != null && remarks.isNotEmpty) 'remarks': remarks,
          if (assignedTo != null && assignedTo.isNotEmpty) 'assignedTo': assignedTo,
          if (otp != null && otp.isNotEmpty) 'otp': otp.trim(),
        },
      );

      final data = jsonDecode(response.body);
      if (response.statusCode != 200) {
        throw data['message'] ?? 'Failed to update complaint';
      }
    } catch (e) {
      debugPrint("❌ [ADMIN_SERVICE] takeComplaintAction error: $e");
      rethrow;
    }
  }

  /// Feature 2: Dedicated Proof-of-Fix 2-Way OTP Verification
  Future<void> verifyResolveComplaint({
    required String complaintId,
    required String actorId,
    required String otp,
    required String remarks,
  }) async {
    try {
      final response = await _apiClient.post(
        '/complaints/$complaintId/verify-resolve',
        body: {
          'actorId': actorId,
          'otp': otp.trim(),
          'remarks': remarks.trim(),
        },
      );

      final data = jsonDecode(response.body);
      if (response.statusCode != 200) {
        throw data['message'] ?? 'Failed to verify and resolve complaint';
      }
    } catch (e) {
      debugPrint("❌ [ADMIN_SERVICE] verifyResolveComplaint error: $e");
      rethrow;
    }
  }

  Future<List<RecurringIssueModel>> getRecurringIssues({
    String? category,
    String? location,
    String? status,
    String? order,
    String? requesterId,
  }) async {
    try {
      final queryParams = <String, dynamic>{};
      if (category != null && category.isNotEmpty) queryParams['category'] = category;
      if (location != null && location.isNotEmpty) queryParams['location'] = location;
      if (status != null && status.isNotEmpty) queryParams['status'] = status;
      if (order != null && order.isNotEmpty) queryParams['order'] = order;

      final response = await _apiClient.get(
        '/admin/complaints/recurring',
        queryParameters: queryParams,
        headers: _headers(requesterId),
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data.map((item) => RecurringIssueModel.fromMap(item as Map<String, dynamic>)).toList();
      } else {
        final data = jsonDecode(response.body);
        throw data['message'] ?? 'Failed to load recurring complaints';
      }
    } catch (e) {
      debugPrint("❌ [ADMIN_SERVICE] getRecurringIssues error: $e");
      rethrow;
    }
  }

  Future<RecurringIssueDetailModel> getRecurringIssueDetail(String recurrenceId, {String? requesterId}) async {
    try {
      final response = await _apiClient.get(
        '/admin/complaints/recurring/$recurrenceId',
        headers: _headers(requesterId),
      );

      final data = jsonDecode(response.body);
      if (response.statusCode == 200) {
        return RecurringIssueDetailModel.fromMap(data);
      } else {
        throw data['message'] ?? 'Failed to load recurring issue detail';
      }
    } catch (e) {
      debugPrint("❌ [ADMIN_SERVICE] getRecurringIssueDetail error: $e");
      rethrow;
    }
  }

  Future<List<UserModel>> getPendingStudents({String? requesterId}) async {
    try {
      final response = await _apiClient.get(
        '/admin/students/pending',
        headers: _headers(requesterId),
      );
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data.map((item) => UserModel.fromMap(item as Map<String, dynamic>)).toList();
      } else {
        final data = jsonDecode(response.body);
        throw data['message'] ?? 'Failed to load pending student registrations';
      }
    } catch (e) {
      debugPrint("❌ [ADMIN_SERVICE] getPendingStudents error: $e");
      rethrow;
    }
  }

  Future<UserModel> approveStudent(String studentId, {String? requesterId}) async {
    try {
      final response = await _apiClient.post(
        '/admin/students/$studentId/approve',
        headers: _headers(requesterId),
      );
      final data = jsonDecode(response.body);
      if (response.statusCode == 200) {
        return UserModel.fromMap(data['student'] as Map<String, dynamic>);
      } else {
        throw data['message'] ?? 'Failed to approve student account';
      }
    } catch (e) {
      debugPrint("❌ [ADMIN_SERVICE] approveStudent error: $e");
      rethrow;
    }
  }

  Future<UserModel> rejectStudent(String studentId, {String? reason, String? requesterId}) async {
    try {
      final response = await _apiClient.post(
        '/admin/students/$studentId/reject',
        headers: _headers(requesterId),
        body: {'reason': reason},
      );
      final data = jsonDecode(response.body);
      if (response.statusCode == 200) {
        return UserModel.fromMap(data['student'] as Map<String, dynamic>);
      } else {
        throw data['message'] ?? 'Failed to reject student registration';
      }
    } catch (e) {
      debugPrint("❌ [ADMIN_SERVICE] rejectStudent error: $e");
      rethrow;
    }
  }
}
