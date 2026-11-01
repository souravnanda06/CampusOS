import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../auth/services/auth_service.dart';
import '../../core/network/api_client.dart';
import '../../student/models/gate_pass_model.dart';
import '../models/gate_security_models.dart';

/// Central Gate Security Service handling operational stats,
/// cryptographic HMAC Gate Pass verification, transit exit/return,
/// and offline queue/synchronization.
class SecurityGatePassService {
  static const String _offlineQueueKey = 'gate_security_offline_queue_v1';
  final ApiClient _apiClient;
  final AuthService _authService;

  SecurityGatePassService({ApiClient? apiClient, AuthService? authService})
      : _apiClient = apiClient ?? ApiClient.instance,
        _authService = authService ?? AuthService();

  Map<String, String> _authHeaders([String? guardId]) {
    final effectiveId = guardId ??
        _authService.currentUser?.id ??
        _authService.currentUser?.uid;
    if (effectiveId != null && effectiveId.isNotEmpty) {
      return {'X-User-Id': effectiveId};
    }
    return {};
  }

  /// Fetch gate command center summary metrics.
  Future<GateSummaryModel> fetchSummary() async {
    final pendingCount = await getPendingOfflineCount();
    try {
      final response = await _apiClient.get(
        '/security/gate-pass/summary',
        headers: _authHeaders(),
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return GateSummaryModel.fromMap(data, pendingOffline: pendingCount);
      }
      return GateSummaryModel.empty(pendingOffline: pendingCount);
    } catch (e) {
      debugPrint("⚠️ [SECURITY_GATE_SERVICE] fetchSummary offline/error: $e");
      return GateSummaryModel.empty(pendingOffline: pendingCount);
    }
  }

  /// Fetch operational list of gate passes.
  Future<List<GatePassModel>> fetchGatePasses({
    String? status,
    String? search,
    int limit = 100,
  }) async {
    try {
      final queryParams = <String, String>{
        'limit': limit.toString(),
      };
      if (status != null && status.isNotEmpty) {
        queryParams['status'] = status;
      }
      if (search != null && search.isNotEmpty) {
        queryParams['search'] = search;
      }

      final uri = Uri(
        path: '/security/gate-passes',
        queryParameters: queryParams,
      );

      final response = await _apiClient.get(
        uri.toString(),
        headers: _authHeaders(),
      );
      if (response.statusCode == 200) {
        final List<dynamic> list = jsonDecode(response.body);
        return list.map((item) => GatePassModel.fromMap(item as Map<String, dynamic>)).toList();
      }
      return [];
    } catch (e) {
      debugPrint("⚠️ [SECURITY_GATE_SERVICE] fetchGatePasses error: $e");
      return [];
    }
  }

  /// Fetch gate audit activity timeline.
  Future<List<GateActivityItem>> fetchActivity({
    String filter = 'ALL',
    int limit = 50,
  }) async {
    try {
      final uri = Uri(
        path: '/security/gate-pass/activity',
        queryParameters: {
          'filter': filter,
          'limit': limit.toString(),
        },
      );

      final response = await _apiClient.get(
        uri.toString(),
        headers: _authHeaders(),
      );
      if (response.statusCode == 200) {
        final List<dynamic> list = jsonDecode(response.body);
        return list.map((item) => GateActivityItem.fromMap(item as Map<String, dynamic>)).toList();
      }
      return [];
    } catch (e) {
      debugPrint("⚠️ [SECURITY_GATE_SERVICE] fetchActivity error: $e");
      return [];
    }
  }

  /// Verify HMAC Gate Pass credential.
  /// Falls back to structured offline payload inspection if network fails.
  Future<GateVerificationResult> verifyGatePass(
    String credential, {
    String gateName = 'Main Gate',
    String? guardId,
  }) async {
    final cleanCred = credential.trim();
    if (cleanCred.isEmpty) {
      return GateVerificationResult.error("Credential token is empty", "INVALID_CREDENTIAL");
    }

    try {
      final response = await _apiClient.post(
        '/security/gate-pass/verify',
        headers: _authHeaders(guardId),
        body: {
          'credential': cleanCred,
          'gateName': gateName,
          'securityGuardId': guardId,
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return GateVerificationResult.fromMap(data);
      } else {
        final data = jsonDecode(response.body) as Map<String, dynamic>?;
        return GateVerificationResult.error(
          data?['message'] ?? 'Verification failed (${response.statusCode})',
          data?['resultCode'] ?? 'FAILED',
        );
      }
    } catch (e) {
      debugPrint("⚠️ [SECURITY_GATE_SERVICE] Network error during verification, using local offline fallback: $e");
      return _verifyLocallyOffline(cleanCred, gateName: gateName);
    }
  }

  /// Local offline payload decode and structural integrity inspection.
  /// Used when gate is offline / network is down.
  GateVerificationResult _verifyLocallyOffline(String token, {String gateName = 'Main Gate'}) {
    try {
      final parts = token.split('.');
      if (parts.length != 3) {
        return GateVerificationResult.error(
          "Malformed token format (expected 3 compact parts)",
          "INVALID_CREDENTIAL",
        );
      }

      // Decode Header
      final headerJson = utf8.decode(base64Url.decode(base64Url.normalize(parts[0])));
      final header = jsonDecode(headerJson) as Map<String, dynamic>;
      if (header['alg'] != 'HS256' || header['typ'] != 'GATEPASS') {
        return GateVerificationResult.error(
          "Invalid token header (expected HS256 GATEPASS)",
          "INVALID_CREDENTIAL",
        );
      }

      // Decode Payload
      final payloadJson = utf8.decode(base64Url.decode(base64Url.normalize(parts[1])));
      final payload = jsonDecode(payloadJson) as Map<String, dynamic>;

      final gatePassId = payload['gatePassId'] as String?;
      final studentId = payload['studentId'] as String?;
      final expiresAtStr = payload['expiresAt'] as String?;
      final destination = payload['destination'] as String? ?? 'Campus Exit';

      if (gatePassId == null || studentId == null) {
        return GateVerificationResult.error(
          "Missing pass or student identity in credential payload",
          "INVALID_CREDENTIAL",
        );
      }

      // Check Expiration
      if (expiresAtStr != null) {
        try {
          final expiresAt = DateTime.parse(expiresAtStr);
          if (DateTime.now().isAfter(expiresAt.add(const Duration(minutes: 30)))) {
            return GateVerificationResult.error(
              "Gate pass expired at $expiresAtStr",
              "EXPIRED",
            );
          }
        } catch (_) {}
      }

      // Construct verified offline result
      final passModel = GatePassModel(
        id: gatePassId,
        studentId: studentId,
        destination: destination,
        reason: "Offline Verified",
        expectedExitTime: DateTime.now(),
        expectedReturnTime: expiresAtStr != null ? DateTime.tryParse(expiresAtStr) ?? DateTime.now() : DateTime.now(),
        status: 'ISSUED',
        createdAt: DateTime.now(),
        gateName: gateName,
        verificationMode: 'OFFLINE_VERIFIED',
      );

      return GateVerificationResult(
        valid: true,
        resultCode: 'VERIFIED',
        message: 'Locally Verified (Offline)',
        gatePassId: gatePassId,
        action: 'EXIT', // Default prompt in offline mode
        student: {
          'id': studentId,
          'name': 'Student ($studentId)',
          'registrationNumber': 'N/A (Offline)',
        },
        pass: passModel,
        isOfflineVerified: true,
      );
    } catch (e) {
      return GateVerificationResult.error(
        "Could not decode offline credential: $e",
        "INVALID_CREDENTIAL",
      );
    }
  }

  /// Record Student Exit (ISSUED -> EXITED).
  Future<GateVerificationResult> recordExit(
    String passId, {
    String? guardId,
    String gateName = 'Main Gate',
    String verificationMode = 'QR_FALLBACK',
    String? idempotencyKey,
    String? remarks,
  }) async {
    final effectiveIdemKey = idempotencyKey ?? 'exit_${passId}_${DateTime.now().millisecondsSinceEpoch}';

    try {
      final response = await _apiClient.post(
        '/security/gate-pass/$passId/exit',
        headers: _authHeaders(guardId),
        body: {
          'securityGuardId': guardId,
          'gateName': gateName,
          'verificationMode': verificationMode,
          'idempotencyKey': effectiveIdemKey,
          'remarks': remarks ?? '',
        },
      );

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      if (response.statusCode == 200) {
        return GateVerificationResult.fromMap(data);
      } else {
        return GateVerificationResult.error(
          data['message'] ?? 'Failed to record exit (${response.statusCode})',
          data['resultCode'] ?? 'FAILED',
        );
      }
    } catch (e) {
      debugPrint("⚠️ [SECURITY_GATE_SERVICE] Network offline. Queueing exit event: $e");
      await queueOfflineEvent({
        'passId': passId,
        'action': 'EXIT',
        'securityGuardId': guardId,
        'gateName': gateName,
        'verificationMode': 'OFFLINE_SYNC',
        'idempotencyKey': effectiveIdemKey,
        'timestamp': DateTime.now().toIso8601String(),
      });

      return GateVerificationResult(
        valid: true,
        resultCode: 'SYNC_PENDING',
        message: 'Exit recorded offline (Sync Pending)',
        gatePassId: passId,
        action: 'EXIT',
        isOfflineVerified: true,
      );
    }
  }

  /// Record Student Return (EXITED -> RETURNED).
  Future<GateVerificationResult> recordReturn(
    String passId, {
    String? guardId,
    String gateName = 'Main Gate',
    String verificationMode = 'QR_FALLBACK',
    String? idempotencyKey,
    String? remarks,
  }) async {
    final effectiveIdemKey = idempotencyKey ?? 'return_${passId}_${DateTime.now().millisecondsSinceEpoch}';

    try {
      final response = await _apiClient.post(
        '/security/gate-pass/$passId/return',
        headers: _authHeaders(guardId),
        body: {
          'securityGuardId': guardId,
          'gateName': gateName,
          'verificationMode': verificationMode,
          'idempotencyKey': effectiveIdemKey,
          'remarks': remarks ?? '',
        },
      );

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      if (response.statusCode == 200) {
        return GateVerificationResult.fromMap(data);
      } else {
        return GateVerificationResult.error(
          data['message'] ?? 'Failed to record return (${response.statusCode})',
          data['resultCode'] ?? 'FAILED',
        );
      }
    } catch (e) {
      debugPrint("⚠️ [SECURITY_GATE_SERVICE] Network offline. Queueing return event: $e");
      await queueOfflineEvent({
        'passId': passId,
        'action': 'RETURN',
        'securityGuardId': guardId,
        'gateName': gateName,
        'verificationMode': 'OFFLINE_SYNC',
        'idempotencyKey': effectiveIdemKey,
        'timestamp': DateTime.now().toIso8601String(),
      });

      return GateVerificationResult(
        valid: true,
        resultCode: 'SYNC_PENDING',
        message: 'Return recorded offline (Sync Pending)',
        gatePassId: passId,
        action: 'RETURN',
        isOfflineVerified: true,
      );
    }
  }

  // =========================================================================
  // OFFLINE QUEUE & SYNCHRONIZATION
  // =========================================================================

  /// Queue an offline event locally in SharedPreferences.
  Future<void> queueOfflineEvent(Map<String, dynamic> event) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final currentList = prefs.getStringList(_offlineQueueKey) ?? [];
      currentList.add(jsonEncode(event));
      await prefs.setStringList(_offlineQueueKey, currentList);
      debugPrint("📦 [SECURITY_GATE_SERVICE] Event queued. Total offline pending: ${currentList.length}");
    } catch (e) {
      debugPrint("❌ [SECURITY_GATE_SERVICE] Failed to queue offline event: $e");
    }
  }

  /// Get total count of pending offline events.
  Future<int> getPendingOfflineCount() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = prefs.getStringList(_offlineQueueKey);
      return list?.length ?? 0;
    } catch (_) {
      return 0;
    }
  }

  /// Get list of pending offline events.
  Future<List<Map<String, dynamic>>> getPendingOfflineEvents() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = prefs.getStringList(_offlineQueueKey) ?? [];
      return list.map((item) => jsonDecode(item) as Map<String, dynamic>).toList();
    } catch (_) {
      return [];
    }
  }

  /// Synchronize all queued offline events to the server.
  Future<Map<String, dynamic>> syncOfflineEvents() async {
    final events = await getPendingOfflineEvents();
    if (events.isEmpty) {
      return {'syncedCount': 0, 'message': 'No offline events to sync'};
    }

    try {
      final response = await _apiClient.post(
        '/security/gate-pass/batch-sync',
        headers: _authHeaders(),
        body: {'events': events},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        // Clear local queue upon successful server synchronization
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove(_offlineQueueKey);
        debugPrint("✅ [SECURITY_GATE_SERVICE] Batch sync completed: ${data['syncedCount']} synced.");
        return data;
      } else {
        throw "Server returned ${response.statusCode}";
      }
    } catch (e) {
      debugPrint("❌ [SECURITY_GATE_SERVICE] Offline sync failed: $e");
      rethrow;
    }
  }
}
