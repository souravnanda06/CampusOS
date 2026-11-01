import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../models/passport_identity_model.dart';
import '../../auth/services/auth_service.dart';
import '../../core/network/api_client.dart';
import 'passport_crypto_service.dart';

/// CampusOS Passport Backend Identity Service (Phase 1C).
///
/// Communicates with the backend Passport Key Registry and Certification endpoints.
/// Propagates the canonical student user ID (users.id) via the `X-User-Id` header
/// as required by the backend authentication layer.
///
/// Features offline identity restoration via local secure storage.
class PassportIdentityService {
  static const String enrollmentStatusStorageKey = 'campus_os.passport.enrollment_status';

  final ApiClient _apiClient;
  final AuthService _authService;
  final PassportKeyStorage _storage;

  PassportIdentityService({
    ApiClient? apiClient,
    AuthService? authService,
    PassportKeyStorage? storage,
  })  : _apiClient = apiClient ?? ApiClient.instance,
        _authService = authService ?? AuthService(),
        _storage = storage ?? SecurePassportKeyStorage();

  /// Reads locally cached enrollment status from secure storage.
  Future<PassportEnrollmentStatus?> getCachedIdentity() async {
    try {
      final jsonStr = await _storage.read(enrollmentStatusStorageKey);
      if (jsonStr != null && jsonStr.isNotEmpty) {
        return PassportEnrollmentStatus.fromJson(jsonStr);
      }
      return null;
    } catch (e) {
      debugPrint('⚠️ [PASSPORT_IDENTITY] Failed to read cached identity: $e');
      return null;
    }
  }

  /// Persists enrollment status to secure storage for offline restoration.
  Future<void> saveCachedIdentity(PassportEnrollmentStatus status) async {
    try {
      await _storage.write(enrollmentStatusStorageKey, status.toJson());
      debugPrint('💾 [PASSPORT_IDENTITY] Cached enrollment status locally.');
    } catch (e) {
      debugPrint('⚠️ [PASSPORT_IDENTITY] Failed to cache enrollment status: $e');
    }
  }

  /// Clears locally cached enrollment status.
  Future<void> clearCachedIdentity() async {
    try {
      await _storage.delete(enrollmentStatusStorageKey);
      debugPrint('🗑️ [PASSPORT_IDENTITY] Cleared local cached enrollment.');
    } catch (e) {
      debugPrint('⚠️ [PASSPORT_IDENTITY] Failed to clear cached enrollment: $e');
    }
  }

  /// Resolves the canonical authenticated user ID (users.id) from:
  /// 1. Explicit userId if provided and non-empty
  /// 2. AuthService in-memory currentUser.id
  /// 3. AuthService persistent storage (user_data in SharedPreferences)
  Future<String?> _resolveUserId([String? explicitUserId]) async {
    if (explicitUserId != null && explicitUserId.trim().isNotEmpty) {
      return explicitUserId.trim();
    }
    final inMemory = _authService.currentUser?.id;
    if (inMemory != null && inMemory.trim().isNotEmpty) {
      return inMemory.trim();
    }
    final storedUser = await _authService.getUserDataFromStorage();
    if (storedUser != null && storedUser.id.trim().isNotEmpty) {
      return storedUser.id.trim();
    }
    return null;
  }

  /// Checks whether the authenticated user has an enrolled Passport identity.
  ///
  /// Network availability DOES NOT determine whether an already-enrolled key exists.
  /// If the network is unavailable or returns an error, this method seamlessly falls
  /// back to the locally cached enrollment metadata stored securely on device.
  Future<PassportEnrollmentStatus> getIdentity({String? userId}) async {
    final effectiveUserId = await _resolveUserId(userId);
    try {
      if (effectiveUserId == null || effectiveUserId.isEmpty) {
        final cached = await getCachedIdentity();
        if (cached != null && cached.enrolled) {
          return cached;
        }
        return PassportEnrollmentStatus(enrolled: false);
      }

      final headers = {
        'X-User-Id': effectiveUserId,
      };

      final response = await _apiClient.get(
        '/passport/identity',
        headers: headers,
      );
      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(response.body);
        final status = PassportEnrollmentStatus.fromMap(data);
        if (status.enrolled) {
          await saveCachedIdentity(status);
        } else {
          await clearCachedIdentity();
        }
        return status;
      }

      // If server explicitly reports user is not enrolled (HTTP 404)
      if (response.statusCode == 404) {
        await clearCachedIdentity();
        return PassportEnrollmentStatus(enrolled: false);
      }

      // Server error (5xx) -> fallback to cached offline identity
      final cached = await getCachedIdentity();
      if (cached != null && cached.enrolled) {
        debugPrint('🔒 [PASSPORT_IDENTITY] Server error (${response.statusCode}). Restored identity from offline cache.');
        return cached;
      }
      return PassportEnrollmentStatus(enrolled: false);
    } catch (e) {
      // Network failure / offline -> fallback to locally cached identity
      final cached = await getCachedIdentity();
      if (cached != null && cached.enrolled) {
        debugPrint('🔒 [PASSPORT_IDENTITY] Network offline. Restored identity from offline cache.');
        return cached;
      }
      return PassportEnrollmentStatus(enrolled: false);
    }
  }

  /// Registers a public Ed25519 key for the authenticated user and receives an institutional certificate.
  /// CRITICAL: The private key is never sent. Only the Base64-encoded public key is registered.
  /// Authenticates using the canonical student ID via the X-User-Id header.
  Future<PassportIdentityKeyModel> registerKey({
    required String publicKey,
    String? userId,
    String keyType = 'ED25519',
  }) async {
    final effectiveUserId = await _resolveUserId(userId);
    if (effectiveUserId == null || effectiveUserId.isEmpty) {
      throw Exception('Authentication required: Missing X-User-Id header');
    }

    final payload = {
      'userId': effectiveUserId,
      'publicKey': publicKey,
      'keyType': keyType,
    };

    final headers = {
      'X-User-Id': effectiveUserId,
    };

    final response = await _apiClient.post(
      '/passport/keys/register',
      headers: headers,
      body: payload,
    );

    if (response.statusCode == 201) {
      final Map<String, dynamic> data = jsonDecode(response.body);
      final keyModel = PassportIdentityKeyModel.fromMap(data);
      // Persist newly registered identity for offline restoration
      final status = PassportEnrollmentStatus(
        enrolled: true,
        key: keyModel,
        certificate: keyModel.certificate,
      );
      await saveCachedIdentity(status);
      return keyModel;
    } else {
      final Map<String, dynamic> error = jsonDecode(response.body);
      throw Exception(error['message'] ?? 'Failed to register Passport key (HTTP ${response.statusCode})');
    }
  }

  /// Retrieves public key and institutional certificate metadata for a student.
  Future<PassportIdentityKeyModel?> getStudentIdentity(String studentId, {String? requesterId}) async {
    try {
      final effectiveRequesterId = await _resolveUserId(requesterId);
      final headers = <String, String>{
        if (effectiveRequesterId != null && effectiveRequesterId.isNotEmpty)
          'X-User-Id': effectiveRequesterId,
      };

      final response = await _apiClient.get(
        '/passport/keys/$studentId',
        headers: headers.isNotEmpty ? headers : null,
      );
      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(response.body);
        return PassportIdentityKeyModel.fromMap(data);
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  /// Revokes a device identity key and its associated certificates.
  Future<void> revokeKey(String keyId, {String? requesterId}) async {
    final effectiveRequesterId = await _resolveUserId(requesterId);
    final headers = <String, String>{
      if (effectiveRequesterId != null && effectiveRequesterId.isNotEmpty)
        'X-User-Id': effectiveRequesterId,
    };

    final response = await _apiClient.post(
      '/passport/keys/$keyId/revoke',
      headers: headers.isNotEmpty ? headers : null,
    );
    if (response.statusCode == 200) {
      await clearCachedIdentity();
    } else {
      final Map<String, dynamic> error = jsonDecode(response.body);
      throw Exception(error['message'] ?? 'Failed to revoke key (HTTP ${response.statusCode})');
    }
  }

  /// Verifies an institutional certificate against the 10 backend validation rules.
  Future<Map<String, dynamic>> verifyCertificate(Map<String, dynamic> certificateData) async {
    final response = await _apiClient.post(
      '/passport/verify-certificate',
      body: {'certificate': certificateData},
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    } else {
      final Map<String, dynamic> error = jsonDecode(response.body);
      throw Exception(error['message'] ?? 'Certificate verification failed');
    }
  }

  /// Retrieves the trusted institutional public key from the backend.
  Future<Map<String, dynamic>> getInstitutionPublicKey() async {
    final response = await _apiClient.get('/passport/institution/public-key');
    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    } else {
      throw Exception('Failed to fetch institutional public key');
    }
  }
}
