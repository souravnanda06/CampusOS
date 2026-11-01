import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../models/expansion_models.dart';
import '../network/api_client.dart';

class ExpansionApiService {
  final ApiClient _client;

  static ExpansionApiService? _instance;
  static ExpansionApiService get instance =>
      _instance ??= ExpansionApiService();

  ExpansionApiService({ApiClient? client})
      : _client = client ?? ApiClient.instance;

  // ---------------------------------------------------------------------------
  // 1. DOCUMENTS
  // ---------------------------------------------------------------------------

  Future<List<Map<String, String>>> getDocumentTypes() async {
    try {
      final res = await _client.get('/documents/types');
      if (res.statusCode == 200) {
        final List list = jsonDecode(res.body);
        return list.map((e) => Map<String, String>.from(e)).toList();
      }
      return [];
    } catch (e) {
      debugPrint("❌ [ExpansionApiService] getDocumentTypes error: $e");
      return [];
    }
  }

  Future<DocumentRequestModel> createDocumentRequest({
    required String studentId,
    required String documentType,
    required String purpose,
  }) async {
    final res = await _client.post(
      '/documents/requests',
      headers: {'X-User-Id': studentId},
      body: {
        'documentType': documentType,
        'purpose': purpose,
      },
    );
    final data = jsonDecode(res.body);
    if (res.statusCode == 201) {
      return DocumentRequestModel.fromJson(data['request']);
    }
    throw data['message'] ?? 'Failed to submit document request';
  }

  Future<List<DocumentRequestModel>> getMyDocuments(String studentId) async {
    try {
      final res = await _client.get(
        '/documents/requests/my',
        headers: {'X-User-Id': studentId},
      );
      if (res.statusCode == 200) {
        final List list = jsonDecode(res.body);
        return list.map((e) => DocumentRequestModel.fromJson(e)).toList();
      }
      return [];
    } catch (e) {
      debugPrint("❌ [ExpansionApiService] getMyDocuments error: $e");
      return [];
    }
  }

  Future<DocumentRequestModel> toggleWalletStorage({
    required String documentId,
    required String studentId,
    required bool storedInWallet,
  }) async {
    final res = await _client.post(
      '/documents/requests/$documentId/wallet',
      headers: {'X-User-Id': studentId},
      body: {'storedInWallet': storedInWallet},
    );
    final data = jsonDecode(res.body);
    if (res.statusCode == 200) {
      return DocumentRequestModel.fromJson(data['document']);
    }
    throw data['message'] ?? 'Failed to update wallet storage';
  }

  Future<List<DocumentRequestModel>> getPendingDocuments(String adminId) async {
    try {
      final res = await _client.get(
        '/documents/requests/pending',
        headers: {'X-User-Id': adminId},
      );
      if (res.statusCode == 200) {
        final List list = jsonDecode(res.body);
        return list.map((e) => DocumentRequestModel.fromJson(e)).toList();
      }
      return [];
    } catch (e) {
      debugPrint("❌ [ExpansionApiService] getPendingDocuments error: $e");
      return [];
    }
  }

  Future<DocumentRequestModel> actionDocument({
    required String documentId,
    required String adminId,
    required String action, // APPROVE, REJECT, ISSUE
    String? remarks,
  }) async {
    final res = await _client.post(
      '/documents/requests/$documentId/action',
      headers: {'X-User-Id': adminId},
      body: {
        'action': action,
        'remarks': remarks,
      },
    );
    final data = jsonDecode(res.body);
    if (res.statusCode == 200) {
      return DocumentRequestModel.fromJson(data['document']);
    }
    throw data['message'] ?? 'Failed to action document request';
  }

  Future<DocumentRequestModel> actionDocumentRequest({
    required String documentId,
    required String adminId,
    required String action, // APPROVE, REJECT, ISSUE
    String? remarks,
    String? certificateNumber,
  }) =>
      actionDocument(
        documentId: documentId,
        adminId: adminId,
        action: action,
        remarks: remarks,
      );

  // ---------------------------------------------------------------------------
  // 2. FEES & DUES
  // ---------------------------------------------------------------------------

  Future<Map<String, dynamic>> getMyFees(String studentId) async {
    try {
      final res = await _client.get(
        '/fees/my',
        headers: {'X-User-Id': studentId},
      );
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final List recordsJson = data['records'] ?? [];
        final records =
            recordsJson.map((e) => FeeRecordModel.fromJson(e)).toList();
        final summary = FeeSummaryModel.fromJson(data['summary'] ?? {});
        return {
          'records': records,
          'summary': summary,
        };
      }
      return {'records': <FeeRecordModel>[], 'summary': null};
    } catch (e) {
      debugPrint("❌ [ExpansionApiService] getMyFees error: $e");
      return {'records': <FeeRecordModel>[], 'summary': null};
    }
  }

  Future<FeeSummaryModel?> getMyFeeSummary(String studentId) async {
    try {
      final res = await _client.get(
        '/fees/my/summary',
        headers: {'X-User-Id': studentId},
      );
      if (res.statusCode == 200) {
        return FeeSummaryModel.fromJson(jsonDecode(res.body));
      }
      return null;
    } catch (e) {
      debugPrint("❌ [ExpansionApiService] getMyFeeSummary error: $e");
      return null;
    }
  }

  Future<FeeRecordModel> recordFeePayment({
    required String feeId,
    required String userId,
    double? amount,
  }) async {
    final res = await _client.post(
      '/fees/$feeId/record-payment',
      headers: {'X-User-Id': userId},
      body: {'amount': amount},
    );
    final data = jsonDecode(res.body);
    if (res.statusCode == 200) {
      return FeeRecordModel.fromJson(data['fee']);
    }
    throw data['message'] ?? 'Failed to record fee payment';
  }

  Future<Map<String, dynamic>> getFeeKPIs(String adminId) async {
    try {
      final res = await _client.get(
        '/fees/kpis',
        headers: {'X-User-Id': adminId},
      );
      if (res.statusCode == 200) {
        return jsonDecode(res.body);
      }
      return {};
    } catch (e) {
      debugPrint("❌ [ExpansionApiService] getFeeKPIs error: $e");
      return {};
    }
  }

  Future<Map<String, dynamic>> getAdminFeesOverview({String? adminId}) =>
      getFeeKPIs(adminId ?? 'admin');

  // ---------------------------------------------------------------------------
  // 3. CLASS UPDATES / CANCELLATION
  // ---------------------------------------------------------------------------

  Future<ClassUpdateModel> createClassUpdate({
    required String teacherId,
    required String courseCode,
    required String courseName,
    required String updateType,
    required String message,
    String? originalDate,
    String? originalTime,
    String? originalRoom,
    String? newDate,
    String? newTime,
    String? newRoom,
    String? affectedBranch,
    int? affectedYear,
  }) async {
    final res = await _client.post(
      '/academic-updates',
      headers: {'X-User-Id': teacherId},
      body: {
        'courseCode': courseCode,
        'courseName': courseName,
        'updateType': updateType,
        'message': message,
        'originalDate': originalDate,
        'originalTime': originalTime,
        'originalRoom': originalRoom,
        'newDate': newDate,
        'newTime': newTime,
        'newRoom': newRoom,
        'affectedBranch': affectedBranch,
        'affectedYear': affectedYear,
      },
    );
    final data = jsonDecode(res.body);
    if (res.statusCode == 201) {
      return ClassUpdateModel.fromJson(data['update']);
    }
    throw data['message'] ?? 'Failed to publish class update';
  }

  Future<List<ClassUpdateModel>> getMyClassUpdates(String studentId) async {
    try {
      final res = await _client.get(
        '/academic-updates/my',
        headers: {'X-User-Id': studentId},
      );
      if (res.statusCode == 200) {
        final List list = jsonDecode(res.body);
        return list.map((e) => ClassUpdateModel.fromJson(e)).toList();
      }
      return [];
    } catch (e) {
      debugPrint("❌ [ExpansionApiService] getMyClassUpdates error: $e");
      return [];
    }
  }

  Future<List<ClassUpdateModel>> getTeacherClassUpdates(String teacherId) async {
    try {
      final res = await _client.get(
        '/academic-updates/teacher',
        headers: {'X-User-Id': teacherId},
      );
      if (res.statusCode == 200) {
        final List list = jsonDecode(res.body);
        return list.map((e) => ClassUpdateModel.fromJson(e)).toList();
      }
      return [];
    } catch (e) {
      debugPrint("❌ [ExpansionApiService] getTeacherClassUpdates error: $e");
      return [];
    }
  }

  Future<Map<String, dynamic>> getTodayUpdatesSummary() async {
    try {
      final res = await _client.get('/academic-updates/today-summary');
      if (res.statusCode == 200) {
        return jsonDecode(res.body);
      }
      return {'todayTotal': 0, 'cancellationsCount': 0, 'rescheduledCount': 0};
    } catch (e) {
      debugPrint("❌ [ExpansionApiService] getTodayUpdatesSummary error: $e");
      return {'todayTotal': 0, 'cancellationsCount': 0, 'rescheduledCount': 0};
    }
  }

  // ---------------------------------------------------------------------------
  // 4. HOSTEL & ROOM & ASSETS
  // ---------------------------------------------------------------------------

  Future<HostelAllocationModel?> getMyRoom(String studentId) async {
    try {
      final res = await _client.get(
        '/hostel/my-room',
        headers: {'X-User-Id': studentId},
      );
      if (res.statusCode == 200) {
        return HostelAllocationModel.fromJson(jsonDecode(res.body));
      }
      return null;
    } catch (e) {
      debugPrint("❌ [ExpansionApiService] getMyRoom error: $e");
      return null;
    }
  }

  Future<List<HostelAssetModel>> getMyAssets(String studentId) async {
    try {
      final res = await _client.get(
        '/hostel/my-assets',
        headers: {'X-User-Id': studentId},
      );
      if (res.statusCode == 200) {
        final List list = jsonDecode(res.body);
        return list.map((e) => HostelAssetModel.fromJson(e)).toList();
      }
      return [];
    } catch (e) {
      debugPrint("❌ [ExpansionApiService] getMyAssets error: $e");
      return [];
    }
  }

  Future<HostelRequestModel> submitHostelRequest({
    required String studentId,
    required String requestType,
    required String reason,
    String? preferredHostel,
    String? preferredRoom,
  }) async {
    final res = await _client.post(
      '/hostel/requests',
      headers: {'X-User-Id': studentId},
      body: {
        'requestType': requestType,
        'reason': reason,
        'preferredHostel': preferredHostel,
        'preferredRoom': preferredRoom,
      },
    );
    final data = jsonDecode(res.body);
    if (res.statusCode == 201) {
      return HostelRequestModel.fromJson(data['request']);
    }
    throw data['message'] ?? 'Failed to submit hostel request';
  }

  Future<HostelRequestModel> createHostelRequest({
    required String studentId,
    required String requestType,
    required String reason,
    String? preferredHostel,
    String? preferredBlock,
    String? preferredRoom,
    String? preferredRoomType,
  }) async {
    final roomVal = preferredRoom ?? preferredRoomType;
    final hostelVal = preferredHostel ?? preferredBlock;
    return submitHostelRequest(
      studentId: studentId,
      requestType: requestType,
      reason: reason,
      preferredHostel: hostelVal,
      preferredRoom: roomVal,
    );
  }

  Future<List<HostelRequestModel>> getMyHostelRequests(String studentId) async {
    try {
      final res = await _client.get(
        '/hostel/requests/my',
        headers: {'X-User-Id': studentId},
      );
      if (res.statusCode == 200) {
        final List list = jsonDecode(res.body);
        return list.map((e) => HostelRequestModel.fromJson(e)).toList();
      }
      return [];
    } catch (e) {
      debugPrint("❌ [ExpansionApiService] getMyHostelRequests error: $e");
      return [];
    }
  }

  Future<AssetIssueModel> reportAssetIssue({
    required String studentId,
    String? assetId,
    String? assetName,
    required String issueType,
    required String description,
    String? urgency,
  }) async {
    String targetAssetId = assetId ?? '';
    if (targetAssetId.isEmpty) {
      final assets = await getMyAssets(studentId);
      final match = assets.firstWhere(
        (a) => a.assetName.toLowerCase() == (assetName ?? '').toLowerCase(),
        orElse: () => assets.isNotEmpty
            ? assets.first
            : HostelAssetModel(
                id: 'dummy',
                hostelName: '',
                roomNumber: '',
                assetCode: '',
                assetName: assetName ?? 'General',
                condition: 'GOOD'),
      );
      targetAssetId = match.id;
    }
    final res = await _client.post(
      '/hostel/assets/report-issue',
      headers: {'X-User-Id': studentId},
      body: {
        'assetId': targetAssetId,
        'issueType': issueType,
        'description': urgency != null ? '[$urgency] $description' : description,
      },
    );
    final data = jsonDecode(res.body);
    if (res.statusCode == 201) {
      return AssetIssueModel.fromJson(data['issue']);
    }
    throw data['message'] ?? 'Failed to report asset issue';
  }

  Future<List<AssetIssueModel>> getMyAssetIssues(String studentId) async {
    try {
      final res = await _client.get(
        '/hostel/assets/issues/my',
        headers: {'X-User-Id': studentId},
      );
      if (res.statusCode == 200) {
        final List list = jsonDecode(res.body);
        return list.map((e) => AssetIssueModel.fromJson(e)).toList();
      }
      return [];
    } catch (e) {
      debugPrint("❌ [ExpansionApiService] getMyAssetIssues error: $e");
      return [];
    }
  }

  Future<Map<String, dynamic>> getHostelOverview({String? adminId}) async {
    try {
      final res = await _client.get(
        '/hostel/admin/kpis',
        headers: {'X-User-Id': adminId ?? 'admin'},
      );
      if (res.statusCode == 200) {
        return jsonDecode(res.body);
      }
      return {};
    } catch (e) {
      debugPrint("❌ [ExpansionApiService] getHostelOverview error: $e");
      return {};
    }
  }

  Future<Map<String, dynamic>> getWardenOverview(String wardenId) async {
    try {
      final res = await _client.get(
        '/hostel/warden/overview',
        headers: {'X-User-Id': wardenId},
      );
      if (res.statusCode == 200) {
        return jsonDecode(res.body);
      }
      return {};
    } catch (e) {
      debugPrint("❌ [ExpansionApiService] getWardenOverview error: $e");
      return {};
    }
  }

  Future<List<HostelRequestModel>> getWardenHostelRequests(String wardenId) async {
    try {
      final res = await _client.get(
        '/hostel/warden/requests',
        headers: {'X-User-Id': wardenId},
      );
      if (res.statusCode == 200) {
        final List list = jsonDecode(res.body);
        return list.map((e) => HostelRequestModel.fromJson(e)).toList();
      }
      return [];
    } catch (e) {
      debugPrint("❌ [ExpansionApiService] getWardenHostelRequests error: $e");
      return [];
    }
  }

  Future<List<HostelRequestModel>> getWardenPendingRequests(String wardenId) =>
      getWardenHostelRequests(wardenId);

  Future<HostelRequestModel> actionHostelRequest({
    required String requestId,
    required String wardenId,
    required String action, // APPROVE, REJECT, COMPLETE
    String? remarks,
  }) async {
    final res = await _client.post(
      '/hostel/warden/requests/$requestId/action',
      headers: {'X-User-Id': wardenId},
      body: {'action': action, 'remarks': remarks},
    );
    final data = jsonDecode(res.body);
    if (res.statusCode == 200) {
      return HostelRequestModel.fromJson(data['request']);
    }
    throw data['message'] ?? 'Failed to action hostel request';
  }

  Future<List<AssetIssueModel>> getWardenAssetIssues(String wardenId) async {
    try {
      final res = await _client.get(
        '/hostel/warden/asset-issues',
        headers: {'X-User-Id': wardenId},
      );
      if (res.statusCode == 200) {
        final List list = jsonDecode(res.body);
        return list.map((e) => AssetIssueModel.fromJson(e)).toList();
      }
      return [];
    } catch (e) {
      debugPrint("❌ [ExpansionApiService] getWardenAssetIssues error: $e");
      return [];
    }
  }

  Future<List<AssetIssueModel>> getWardenPendingAssetIssues(String wardenId) =>
      getWardenAssetIssues(wardenId);

  Future<AssetIssueModel> actionAssetIssue({
    required String issueId,
    required String wardenId,
    required String status,
    String? resolutionNotes,
    String? remarks,
  }) async {
    final res = await _client.post(
      '/hostel/warden/asset-issues/$issueId/action',
      headers: {'X-User-Id': wardenId},
      body: {
        'status': status,
        'resolutionNotes': resolutionNotes ?? remarks,
      },
    );
    final data = jsonDecode(res.body);
    if (res.statusCode == 200) {
      return AssetIssueModel.fromJson(data['issue']);
    }
    throw data['message'] ?? 'Failed to update asset issue';
  }

  // ---------------------------------------------------------------------------
  // 5. VISITOR MANAGEMENT
  // ---------------------------------------------------------------------------

  Future<VisitorRequestModel> submitVisitorRequest({
    required String studentId,
    required String visitorName,
    required String visitorPhone,
    required String relation,
    required String purpose,
    required String visitDate,
    String? expectedEntryTime,
    String? expectedExitTime,
  }) async {
    final res = await _client.post(
      '/visitors/requests',
      headers: {'X-User-Id': studentId},
      body: {
        'visitorName': visitorName,
        'visitorPhone': visitorPhone,
        'relation': relation,
        'purpose': purpose,
        'visitDate': visitDate,
        'expectedEntryTime': expectedEntryTime ?? '04:00 PM',
        'expectedExitTime': expectedExitTime ?? '08:00 PM',
      },
    );
    final data = jsonDecode(res.body);
    if (res.statusCode == 201) {
      return VisitorRequestModel.fromJson(data['request']);
    }
    throw data['message'] ?? 'Failed to submit visitor request';
  }

  Future<List<VisitorRequestModel>> getMyVisitorRequests(String studentId) async {
    try {
      final res = await _client.get(
        '/visitors/requests/my',
        headers: {'X-User-Id': studentId},
      );
      if (res.statusCode == 200) {
        final List list = jsonDecode(res.body);
        return list.map((e) => VisitorRequestModel.fromJson(e)).toList();
      }
      return [];
    } catch (e) {
      debugPrint("❌ [ExpansionApiService] getMyVisitorRequests error: $e");
      return [];
    }
  }

  Future<VisitorRequestModel?> getActiveVisitorPass(String studentId) async {
    try {
      final res = await _client.get(
        '/visitors/active-pass',
        headers: {'X-User-Id': studentId},
      );
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data['hasActivePass'] == true && data['pass'] != null) {
          return VisitorRequestModel.fromJson(data['pass']);
        }
      }
      return null;
    } catch (e) {
      debugPrint("❌ [ExpansionApiService] getActiveVisitorPass error: $e");
      return null;
    }
  }

  Future<List<VisitorRequestModel>> getWardenPendingVisitors(String wardenId) async {
    try {
      final res = await _client.get(
        '/visitors/warden/pending',
        headers: {'X-User-Id': wardenId},
      );
      if (res.statusCode == 200) {
        final List list = jsonDecode(res.body);
        return list.map((e) => VisitorRequestModel.fromJson(e)).toList();
      }
      return [];
    } catch (e) {
      debugPrint("❌ [ExpansionApiService] getWardenPendingVisitors error: $e");
      return [];
    }
  }

  Future<VisitorRequestModel> actionVisitorRequest({
    required String requestId,
    required String wardenId,
    required String action, // APPROVE, REJECT
    String? remarks,
  }) async {
    final res = await _client.post(
      '/visitors/warden/requests/$requestId/action',
      headers: {'X-User-Id': wardenId},
      body: {'action': action, 'remarks': remarks},
    );
    final data = jsonDecode(res.body);
    if (res.statusCode == 200) {
      return VisitorRequestModel.fromJson(data['request']);
    }
    throw data['message'] ?? 'Failed to action visitor request';
  }

  Future<Map<String, dynamic>> verifyVisitorPass({
    required String passCode,
    required String guardId,
  }) async {
    final res = await _client.post(
      '/visitors/security/verify',
      headers: {'X-User-Id': guardId},
      body: {'passCode': passCode},
    );
    return jsonDecode(res.body);
  }

  Future<VisitorRequestModel> checkInVisitor({
    required String passCode,
    required String guardId,
    String? remarks,
  }) async {
    final res = await _client.post(
      '/visitors/security/check-in',
      headers: {'X-User-Id': guardId},
      body: {'passCode': passCode, 'remarks': remarks},
    );
    final data = jsonDecode(res.body);
    if (res.statusCode == 200) {
      return VisitorRequestModel.fromJson(data['pass']);
    }
    throw data['message'] ?? 'Check-in failed';
  }

  Future<VisitorRequestModel> checkOutVisitor({
    required String passCode,
    required String guardId,
    String? remarks,
  }) async {
    final res = await _client.post(
      '/visitors/security/check-out',
      headers: {'X-User-Id': guardId},
      body: {'passCode': passCode, 'remarks': remarks},
    );
    final data = jsonDecode(res.body);
    if (res.statusCode == 200) {
      return VisitorRequestModel.fromJson(data['pass']);
    }
    throw data['message'] ?? 'Check-out failed';
  }

  Future<Map<String, dynamic>> getSecurityVisitorSummary(String guardId) async {
    try {
      final res = await _client.get(
        '/visitors/security/summary',
        headers: {'X-User-Id': guardId},
      );
      if (res.statusCode == 200) {
        return jsonDecode(res.body);
      }
      return {'expectedToday': 0, 'currentlyInside': 0, 'checkedOutToday': 0};
    } catch (e) {
      debugPrint("❌ [ExpansionApiService] getSecurityVisitorSummary error: $e");
      return {'expectedToday': 0, 'currentlyInside': 0, 'checkedOutToday': 0};
    }
  }

  // ---------------------------------------------------------------------------
  // 6. NOTIFICATION CENTER
  // ---------------------------------------------------------------------------

  Future<Map<String, dynamic>> getNotifications(String userId,
      {bool unreadOnly = false}) async {
    try {
      final res = await _client.get(
        '/notifications?unread=${unreadOnly ? 'true' : 'false'}',
        headers: {'X-User-Id': userId},
      );
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final List notifsJson = data['notifications'] ?? [];
        final notifs =
            notifsJson.map((e) => NotificationItemModel.fromJson(e)).toList();
        return {
          'notifications': notifs,
          'unreadCount': data['unreadCount'] ?? 0,
        };
      }
      return {'notifications': <NotificationItemModel>[], 'unreadCount': 0};
    } catch (e) {
      debugPrint("❌ [ExpansionApiService] getNotifications error: $e");
      return {'notifications': <NotificationItemModel>[], 'unreadCount': 0};
    }
  }

  Future<int> getUnreadCount(String userId) async {
    try {
      final res = await _client.get(
        '/notifications/unread-count',
        headers: {'X-User-Id': userId},
      );
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        return data['unreadCount'] ?? 0;
      }
      return 0;
    } catch (e) {
      return 0;
    }
  }

  Future<bool> markNotificationAsRead(String id, String userId) async {
    try {
      final res = await _client.post(
        '/notifications/$id/read',
        headers: {'X-User-Id': userId},
      );
      return res.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  Future<bool> markAllNotificationsAsRead(String userId) async {
    try {
      final res = await _client.post(
        '/notifications/read-all',
        headers: {'X-User-Id': userId},
      );
      return res.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  // ---------------------------------------------------------------------------
  // 7. PERMISSION-AWARE GLOBAL SEARCH
  // ---------------------------------------------------------------------------

  Future<List<SearchResultModel>> search(String query, String userId) async {
    if (query.trim().length < 2) return [];
    try {
      final encodedQuery = Uri.encodeComponent(query.trim());
      final res = await _client.get(
        '/search?q=$encodedQuery',
        headers: {'X-User-Id': userId},
      );
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final List results = data['results'] ?? [];
        return results.map((e) => SearchResultModel.fromJson(e)).toList();
      }
      return [];
    } catch (e) {
      debugPrint("❌ [ExpansionApiService] search error: $e");
      return [];
    }
  }
}
