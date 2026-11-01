import 'dart:convert';
import '../../core/network/api_client.dart';
import '../../auth/models/user_model.dart';

class TeacherAnalyticsService {
  final ApiClient _apiClient;

  TeacherAnalyticsService({ApiClient? apiClient})
      : _apiClient = apiClient ?? ApiClient.instance;

  /// Fetch students with attendance stats, filtered by course/branch/year.
  Future<List<UserModel>> getStudentsWithStats({
    required String course,
    String? branch,
    String? year,
  }) async {
    String query = "course=$course";
    if (year != null) query += "&year=$year";
    if (course != 'BCA' && course != 'MCA' && branch != null) {
      query += "&branch=$branch";
    }

    final res = await _apiClient.get('/students-with-stats?$query');
    if (res.statusCode == 200) {
      final List data = jsonDecode(res.body);
      return data.map((e) {
        var user = UserModel.fromMap(e);
        user.attendancePercentage =
            (e['attendancePercentage'] as num).toDouble();
        return user;
      }).toList();
    }
    return [];
  }

  /// Reset a student's device ID.
  Future<bool> resetStudentDeviceId(String studentId) async {
    final res = await _apiClient.post(
      '/teacher/reset-device-id',
      body: {'studentId': studentId},
    );
    return res.statusCode == 200;
  }

  /// Fetch a student's per-subject attendance heatmap.
  Future<Map<String, dynamic>?> getStudentSubjectAnalytics({
    required String studentId,
    required String subject,
  }) async {
    final encodedSubject = Uri.encodeComponent(subject);
    final res = await _apiClient
        .get('/analytics/student/$studentId?subject=$encodedSubject');
    if (res.statusCode == 200) {
      final dynamic decoded = jsonDecode(res.body);
      if (decoded is Map<String, dynamic>) {
        return decoded;
      } else if (decoded is List) {
        return {'sessions': decoded};
      }
    }
    return null;
  }
}
