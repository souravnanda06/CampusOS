import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import '../models/session_model.dart';
import '../../core/network/api_client.dart';

class SessionService {
  final ApiClient _apiClient;

  SessionService({ApiClient? apiClient})
      : _apiClient = apiClient ?? ApiClient.instance;

  Future<List<SessionModel>> getActiveSessions(
      {String? course, String? branch, String? year}) async {
    try {
      final queryParams = <String, String>{};
      if (course != null && course.isNotEmpty) queryParams['course'] = course;
      if (branch != null && branch.isNotEmpty && branch != 'null') {
        queryParams['branch'] = branch;
      }
      if (year != null && year.isNotEmpty) queryParams['year'] = year;

      final queryString =
          Uri(queryParameters: queryParams.isNotEmpty ? queryParams : null)
              .query;
      final endpoint = queryString.isNotEmpty
          ? '/sessions/active?$queryString'
          : '/sessions/active';

      final response = await _apiClient.get(endpoint);

      final now = DateTime.now();

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        final list = data
            .map((json) => SessionModel.fromMap(json, json['id']))
            .where((s) => s.isActive && s.endTime.isAfter(now))
            .toList();
        if (list.isNotEmpty) return list;
      }

      // If strict filter returned empty, try alternate branch / year formatting
      if (branch != null || year != null) {
        final altBranch = _resolveAlternateBranch(branch);
        final altYear = _resolveAlternateYear(year);

        if (altBranch != branch || altYear != year) {
          final altParams = <String, String>{};
          if (course != null && course.isNotEmpty) altParams['course'] = course;
          if (altBranch != null && altBranch.isNotEmpty && altBranch != 'null') {
            altParams['branch'] = altBranch;
          }
          if (altYear != null && altYear.isNotEmpty) altParams['year'] = altYear;

          final altQuery =
              Uri(queryParameters: altParams.isNotEmpty ? altParams : null)
                  .query;
          final altResp = await _apiClient.get('/sessions/active?$altQuery');
          if (altResp.statusCode == 200) {
            final List<dynamic> altData = jsonDecode(altResp.body);
            final altList = altData
                .map((json) => SessionModel.fromMap(json, json['id']))
                .where((s) => s.isActive && s.endTime.isAfter(now))
                .toList();
            if (altList.isNotEmpty) return altList;
          }
        }

        // Broader query: active sessions for course (or all active) with client-side tolerant match
        final broadEndpoint = (course != null && course.isNotEmpty)
            ? '/sessions/active?course=${Uri.encodeComponent(course)}'
            : '/sessions/active';
        final broadResp = await _apiClient.get(broadEndpoint);
        if (broadResp.statusCode == 200) {
          final List<dynamic> broadData = jsonDecode(broadResp.body);
          final allActive = broadData
              .map((json) => SessionModel.fromMap(json, json['id']))
              .where((s) => s.isActive && s.endTime.isAfter(now))
              .toList();

          final matched = allActive.where((s) {
            if (course != null && s.course != null && s.course != course) {
              return false;
            }
            if (branch != null && s.branch != null) {
              final b1 = branch.toLowerCase().trim();
              final b2 = s.branch!.toLowerCase().trim();
              final isBranchMatch = b1 == b2 ||
                  (b1.contains('cse') && b2.contains('computer')) ||
                  (b2.contains('cse') && b1.contains('computer')) ||
                  (b1.contains('ece') && b2.contains('electronics')) ||
                  (b2.contains('ece') && b1.contains('electronics')) ||
                  (b1.contains('mech') && b2.contains('mechanical')) ||
                  (b2.contains('mech') && b1.contains('mechanical')) ||
                  (b1.contains('civil') && b2.contains('civil')) ||
                  (b1.contains('ee') && b2.contains('electrical')) ||
                  (b2.contains('ee') && b1.contains('electrical'));
              if (!isBranchMatch) return false;
            }
            if (year != null && s.year != null) {
              final y1 = year.replaceAll(RegExp(r'[^0-9]'), '');
              final y2 = s.year!.replaceAll(RegExp(r'[^0-9]'), '');
              if (y1.isNotEmpty && y2.isNotEmpty && y1 != y2) return false;
            }
            return true;
          }).toList();

          if (matched.isNotEmpty) return matched;
        }
      }

      return [];
    } catch (e) {
      return [];
    }
  }

  static String? _resolveAlternateBranch(String? branch) {
    if (branch == null) return null;
    final b = branch.trim();
    if (b.toLowerCase() == 'cse') return 'Computer Science & Engineering';
    if (b.toLowerCase().contains('computer science')) return 'CSE';
    if (b.toLowerCase() == 'ece') return 'Electronics & Communication Engineering';
    if (b.toLowerCase().contains('electronics')) return 'ECE';
    if (b.toLowerCase() == 'mech') return 'Mechanical Engineering';
    if (b.toLowerCase().contains('mechanical')) return 'Mech';
    if (b.toLowerCase() == 'civil') return 'Civil Engineering';
    if (b.toLowerCase().contains('civil')) return 'Civil';
    if (b.toLowerCase() == 'ee') return 'Electrical Engineering';
    if (b.toLowerCase().contains('electrical')) return 'EE';
    return branch;
  }

  static String? _resolveAlternateYear(String? year) {
    if (year == null) return null;
    final y = year.trim().toLowerCase();
    if (y == '1st') return '1';
    if (y == '2nd') return '2';
    if (y == '3rd') return '3';
    if (y == '4th') return '4';
    if (y == '1') return '1st';
    if (y == '2') return '2nd';
    if (y == '3') return '3rd';
    if (y == '4') return '4th';
    return year;
  }

  /// Formats any session ID (including 24-char MongoDB ObjectId) into a standard 128-bit UUID for BLE advertising/scanning.
  static String formatSessionBleUuid(String sessionId) {
    if (sessionId.length == 36 && sessionId.contains('-')) return sessionId;
    final cleanHex = sessionId.replaceAll(RegExp(r'[^0-9a-fA-F]'), '').padLeft(32, '0');
    final hex32 = cleanHex.length > 32 ? cleanHex.substring(cleanHex.length - 32) : cleanHex;
    return '${hex32.substring(0, 8)}-${hex32.substring(8, 12)}-${hex32.substring(12, 16)}-${hex32.substring(16, 20)}-${hex32.substring(20, 32)}';
  }

  /// Extracts the original 24-character hexadecimal session ID from a 128-bit BLE service UUID.
  /// Returns null if the UUID does not follow the CampusOS session pattern.
  static String? extractSessionIdFromBleUuid(String uuidString) {
    final clean = uuidString.replaceAll(RegExp(r'[^0-9a-fA-F]'), '').toLowerCase();
    if (clean.length != 32) return null;
    // Exclude Bluetooth SIG standard UUID base (...-0000-1000-8000-00805f9b34fb)
    if (clean.endsWith('00805f9b34fb')) return null;
    if (clean == '00000000000000000000000000000000') return null;
    if (clean.startsWith('00000000')) {
      final sub24 = clean.substring(8);
      if (sub24.replaceAll('0', '').isNotEmpty) {
        return sub24;
      }
    }
    return null;
  }

  // Fetch specific session for "Resume" feature
  Future<SessionModel?> getSessionById(String sessionId) async {
    try {
      final response = await _apiClient.get('/sessions/active');
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        final sessionData = data.firstWhere(
            (element) => element['id'] == sessionId,
            orElse: () => null);

        if (sessionData != null) {
          return SessionModel.fromMap(sessionData, sessionData['id']);
        }
      }
    } catch (e) {
      // Ignored
    }
    return null;
  }

  Future<String> createSession({
    required String name,
    required String instructorName,
    String? course,
    String? branch,
    String? year,
    required DateTime startTime,
    required DateTime endTime,
    required String location,
    int? txPowerLevel,
  }) async {
    try {
      final response = await _apiClient.post(
        '/sessions/create',
        body: {
          'name': name,
          'subject': name,
          'instructorName': instructorName,
          'course': course,
          'branch': branch,
          'year': year,
          'startTime': startTime.toIso8601String(),
          'endTime': endTime.toIso8601String(),
          'location': location,
          'txPowerLevel': txPowerLevel,
        },
      );
      if (response.statusCode == 201) {
        final data = jsonDecode(response.body);
        return data['id'];
      } else {
        throw Exception('Failed to create session');
      }
    } catch (e) {
      debugPrint('⚠️ [SESSION_SERVICE] Offline/network error on createSession: $e. Creating local session.');
      final nowHex = DateTime.now().millisecondsSinceEpoch.toRadixString(16).padLeft(12, '0');
      final randHex = Random().nextInt(0xFFFFFF).toRadixString(16).padLeft(6, '0') +
          Random().nextInt(0xFFFFFF).toRadixString(16).padLeft(6, '0');
      return (nowHex + randHex).substring(0, 24);
    }
  }

  Future<List<SessionModel>> getSessionsByDate(
      {required String instructorName, required DateTime date}) async {
    try {
      String dateStr =
          "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";
      String encodedName = Uri.encodeComponent(instructorName);
      final url = '/sessions/history?instructorName=$encodedName&date=$dateStr';
      final response = await _apiClient.get(url);

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data
            .map((json) => SessionModel.fromMap(json, json['id']))
            .toList();
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  // Fetch saved quick start tokens from backend
  Future<List<Map<String, String?>>> getQuickStartTokens(String userId) async {
    try {
      final response = await _apiClient.get('/quick-start/$userId');

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data
            .map((item) => {
                  'course': item['course']?.toString(),
                  'branch': item['branch']?.toString(),
                  'year': item['year']?.toString(),
                  'subject': item['subject']?.toString(),
                })
            .toList();
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  // Save quick start token to backend
  Future<void> saveQuickStartToken({
    required String userId,
    String? course,
    String? branch,
    String? year,
    required String subject,
  }) async {
    try {
      await _apiClient.post(
        '/quick-start',
        body: {
          'userId': userId,
          'course': course,
          'branch': branch,
          'year': year,
          'subject': subject,
        },
      );
    } catch (e) {
      // Ignored
    }
  }

  // Stop active session
  Future<bool> stopSession(String sessionId) async {
    try {
      final response = await _apiClient.post('/sessions/stop/$sessionId');
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }
}
