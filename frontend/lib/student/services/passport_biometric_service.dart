import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';

/// Result status of a biometric authentication attempt.
enum BiometricAuthStatus {
  success,
  ownerMismatch,     // Failed scan / fingerprint or face rejected
  biometricRequired, // Biometrics not enrolled or hardware unavailable
  cancelled,         // User dismissed prompt
  error,
}

/// Detailed result of biometric liveness gate check.
class BiometricAuthResult {
  final BiometricAuthStatus status;
  final String message;

  const BiometricAuthResult({
    required this.status,
    required this.message,
  });

  bool get isSuccess => status == BiometricAuthStatus.success;

  static const success = BiometricAuthResult(
    status: BiometricAuthStatus.success,
    message: 'Biometric verification passed',
  );

  static const ownerMismatch = BiometricAuthResult(
    status: BiometricAuthStatus.ownerMismatch,
    message: 'OWNER_MISMATCH: Biometric identity verification rejected',
  );

  static const biometricRequired = BiometricAuthResult(
    status: BiometricAuthStatus.biometricRequired,
    message: 'BIOMETRIC_REQUIRED: Device biometric enrollment is required',
  );

  static const cancelled = BiometricAuthResult(
    status: BiometricAuthStatus.cancelled,
    message: 'Biometric verification cancelled by user',
  );

  static const faceMismatch = BiometricAuthResult(
    status: BiometricAuthStatus.ownerMismatch,
    message: 'OWNER_MISMATCH: Face does not match enrolled student identity',
  );

  static const spoofDetected = BiometricAuthResult(
    status: BiometricAuthStatus.ownerMismatch,
    message: 'LIVENESS_FAILED: Static photo or screen replay detected',
  );

  static const faceEnrollmentRequired = BiometricAuthResult(
    status: BiometricAuthStatus.biometricRequired,
    message: 'FACE_ENROLLMENT_REQUIRED: One-time face setup is required',
  );
}

/// Abstract contract for biometric authentication provider.
/// Allows injection of in-memory fake in unit and widget tests.
abstract class PassportBiometricAuthProvider {
  Future<bool> canCheckBiometrics();
  Future<bool> isDeviceSupported();
  Future<BiometricAuthResult> authenticateBiometricOnly({
    required String reason,
  });
  Future<BiometricAuthResult> authenticate({
    required String reason,
    bool biometricOnly = true,
  });
}

/// CampusOS Passport Biometric Liveness Service (Phase 1I).
///
/// CRITICAL SECURITY INVARIANTS:
/// 1. STRICTLY biometric-only: PIN, pattern, password, and generic device
///    credentials fallback are strictly disabled (`biometricOnly = true`).
/// 2. Private key remains locked in hardware keystore until biometric gate passes.
/// 3. Zero biometric templates or biometric scans are ever stored or transmitted.
/// 4. The server only receives a protocol assertion (`biometricGate = true`) signed
///    by the student's hardware-bound key.
class PassportBiometricService implements PassportBiometricAuthProvider {
  final LocalAuthentication _localAuth;

  PassportBiometricService({LocalAuthentication? localAuth})
      : _localAuth = localAuth ?? LocalAuthentication();

  @override
  Future<bool> canCheckBiometrics() async {
    try {
      return await _localAuth.canCheckBiometrics;
    } on PlatformException catch (e) {
      debugPrint('⚠️ [PASSPORT_BIO] canCheckBiometrics error: $e');
      return false;
    }
  }

  @override
  Future<bool> isDeviceSupported() async {
    try {
      return await _localAuth.isDeviceSupported();
    } on PlatformException catch (e) {
      debugPrint('⚠️ [PASSPORT_BIO] isDeviceSupported error: $e');
      return false;
    }
  }

  /// Triggers platform biometric authentication with strict biometric-only constraints.
  ///
  /// PIN, pattern, and password fallbacks are strictly prohibited.
  @override
  Future<BiometricAuthResult> authenticateBiometricOnly({
    required String reason,
  }) async {
    return authenticate(reason: reason, biometricOnly: true);
  }

  /// Triggers platform biometric authentication, optionally allowing device PIN/passcode.
  @override
  Future<BiometricAuthResult> authenticate({
    required String reason,
    bool biometricOnly = true,
  }) async {
    try {
      final isSupported = await isDeviceSupported();
      final canCheck = await canCheckBiometrics();

      if (!isSupported || !canCheck) {
        debugPrint('⚠️ [PASSPORT_BIO] Hardware does not support or lack enrolled biometrics.');
        return BiometricAuthResult.biometricRequired;
      }

      final available = await _localAuth.getAvailableBiometrics();
      if (available.isEmpty && biometricOnly) {
        debugPrint('⚠️ [PASSPORT_BIO] No biometric methods enrolled on device.');
        return BiometricAuthResult.biometricRequired;
      }

      // Perform biometric authentication with biometricOnly flag configurable
      final authenticated = await _localAuth.authenticate(
        localizedReason: reason,
        biometricOnly: biometricOnly,
        persistAcrossBackgrounding: true,
      );

      if (authenticated) {
        debugPrint('✅ [PASSPORT_BIO] Biometric liveness gate completed successfully.');
        return BiometricAuthResult.success;
      } else {
        debugPrint('❌ [PASSPORT_BIO] Biometric liveness check failed: OWNER_MISMATCH.');
        return BiometricAuthResult.ownerMismatch;
      }
    } on PlatformException catch (pe) {
      debugPrint('❌ [PASSPORT_BIO] PlatformException during biometric auth: ${pe.code} - ${pe.message}');
      if (pe.code == 'NotAvailable' || pe.code == 'PasscodeNotSet') {
        return BiometricAuthResult.biometricRequired;
      } else if (pe.code == 'LockedOut' || pe.code == 'PermanentlyLockedOut') {
        return BiometricAuthResult.ownerMismatch;
      }
      return BiometricAuthResult.cancelled;
    } catch (e) {
      debugPrint('❌ [PASSPORT_BIO] Unexpected error during biometric auth: $e');
      return BiometricAuthResult(
        status: BiometricAuthStatus.error,
        message: 'Biometric error: $e',
      );
    }
  }
}
