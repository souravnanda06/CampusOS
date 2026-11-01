import 'dart:convert';
import '../models/passport_presentation_model.dart';
import '../models/passport_proximity_observation.dart';
import '../models/passport_verification_result.dart';
import '../../core/network/api_client.dart';

/// CampusOS Passport Verifier Service (Phase 1E & 1H).
///
/// Responsibilities:
/// 1. Parse and validate scanned QR envelope locally before invoking network.
/// 2. Post presentation payload and signature to backend POST /passport/verify.
/// 3. Map authoritative backend cryptographic decisions to [PassportVerificationResult].
/// 4. Gracefully handle network failures without false "invalid presentation" assertions.
/// 5. Bind Phase 1H BLE proximity observation to verification result.
class PassportVerifierService {
  final ApiClient _apiClient;

  PassportVerifierService({ApiClient? apiClient})
      : _apiClient = apiClient ?? ApiClient.instance;

  /// Validates a raw scanned QR string and, if structured properly, verifies it online with the backend.
  Future<PassportVerificationResult> verifyQrString(
    String qrString, {
    PassportProximityObservation? proximityObservation,
  }) async {
    final clean = qrString.trim();
    if (clean.isEmpty) {
      final res = PassportVerificationResult.invalidFormat('Scanned QR code is empty.');
      return proximityObservation != null
          ? res.copyWith(
              proximityObservation: proximityObservation,
              proximityTier: proximityObservation.proximityTier.code,
              medianRssi: proximityObservation.medianRssi,
              proximityConfidence: proximityObservation.confidence.code,
            )
          : res;
    }

    // 1. Local syntax and envelope validation
    PassportPresentationModel presentation;
    try {
      final decoded = jsonDecode(clean);
      if (decoded is! Map<String, dynamic>) {
        return PassportVerificationResult.invalidFormat('Invalid QR format: expected JSON object.');
      }

      final payload = decoded['p'] is Map<String, dynamic>
          ? decoded['p'] as Map<String, dynamic>
          : (decoded['payload'] is Map<String, dynamic> ? decoded['payload'] as Map<String, dynamic> : null);

      final signature = decoded['s']?.toString() ?? decoded['signature']?.toString();

      if (payload == null || signature == null || signature.isEmpty) {
        return PassportVerificationResult.invalidFormat('Missing presentation payload or signature.');
      }

      // Check required logical payload fields
      final requiredKeys = ['version', 'type', 'keyId', 'userId', 'certificateId', 'issuerKeyId', 'issuedAt', 'expiresAt', 'nonce'];
      for (final key in requiredKeys) {
        if (payload[key] == null) {
          return PassportVerificationResult.invalidFormat('Missing required field: $key.');
        }
      }

      if (payload['type'] != PassportPresentationModel.presentationType) {
        return PassportVerificationResult.invalidFormat('Unsupported credential type: ${payload['type']}.');
      }

      if (payload['version'] != PassportPresentationModel.currentVersion && payload['version'] != 1) {
        return PassportVerificationResult.invalidFormat('Unsupported presentation version: ${payload['version']}.');
      }

      presentation = PassportPresentationModel.fromQrPayload(clean);
    } on FormatException {
      final res = PassportVerificationResult.invalidFormat('QR payload is not valid JSON.');
      return proximityObservation != null
          ? res.copyWith(
              proximityObservation: proximityObservation,
              proximityTier: proximityObservation.proximityTier.code,
              medianRssi: proximityObservation.medianRssi,
              proximityConfidence: proximityObservation.confidence.code,
            )
          : res;
    } catch (e) {
      final res = PassportVerificationResult.invalidFormat('Malformed presentation: ${e.toString()}');
      return proximityObservation != null
          ? res.copyWith(
              proximityObservation: proximityObservation,
              proximityTier: proximityObservation.proximityTier.code,
              medianRssi: proximityObservation.medianRssi,
              proximityConfidence: proximityObservation.confidence.code,
            )
          : res;
    }

    // 2. Online authoritative verification
    return await verifyPresentation(
      presentation,
      proximityObservation: proximityObservation,
    );
  }

  /// Sends a validated [PassportPresentationModel] to POST /passport/verify
  Future<PassportVerificationResult> verifyPresentation(
    PassportPresentationModel presentation, {
    PassportProximityObservation? proximityObservation,
  }) async {
    PassportVerificationResult result;
    try {
      final response = await _apiClient.post(
        '/passport/verify',
        body: {
          'payload': presentation.toPayloadMap(),
          'signature': presentation.signature,
        },
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(response.body);
        result = PassportVerificationResult.fromMap(data);
      } else {
        try {
          final Map<String, dynamic> errorData = jsonDecode(response.body);
          result = PassportVerificationResult.fromMap(errorData);
        } catch (_) {
          result = PassportVerificationResult.networkError(
            'Verification server returned HTTP ${response.statusCode}',
          );
        }
      }
    } catch (e) {
      result = PassportVerificationResult.networkError(
        'Connect to the CampusOS server and try again (${e.toString().replaceAll('Exception: ', '')}).',
      );
    }

    if (proximityObservation != null) {
      return result.copyWith(
        proximityObservation: proximityObservation,
        proximityTier: proximityObservation.proximityTier.code,
        medianRssi: proximityObservation.medianRssi,
        proximityConfidence: proximityObservation.confidence.code,
      );
    }
    return result;
  }
}
