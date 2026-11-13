import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

/// Immutable GPS fix captured during attendance broadcast or submission.
class PassportLocationSnapshot {
  final double latitude;
  final double longitude;
  final double accuracyMeters;
  final bool isMocked;
  final DateTime capturedAt;

  const PassportLocationSnapshot({
    required this.latitude,
    required this.longitude,
    required this.accuracyMeters,
    this.isMocked = false,
    required this.capturedAt,
  });

  static double roundCoord(double value) =>
      double.parse(value.toStringAsFixed(6));
}

/// Result category of evaluating student vs. teacher GPS proximity.
enum PassportGeofenceStatus {
  verified,
  mockDetected,
  outsideReview,
  unavailable,
}

/// Evaluation outcome produced by [PassportLocationService.evaluate].
class PassportGeofenceEvaluation {
  final PassportGeofenceStatus status;
  final double? distanceMeters;
  final String statusCode;
  final String summary;

  const PassportGeofenceEvaluation({
    required this.status,
    this.distanceMeters,
    required this.statusCode,
    required this.summary,
  });
}

/// Lightweight geolocation & anti-mock geofence helper for Passport attendance.
///
/// Designed as a non-blocking, indoor-safe hybrid layer:
/// - Hard-blocks Android/iOS mock location spoofing (`isMocked`).
/// - Gracefully degrades to `unavailable` when indoor/offline GPS times out
///   so legitimate students sitting inside concrete rooms are never locked out.
/// - Flags high-confidence far-away coordinates (>150m with <=30m GPS error)
///   for teacher Exception Queue review.
class PassportLocationService {
  static const double defaultAllowedRadiusMeters = 60.0;
  static const double defaultReviewThresholdMeters = 150.0;
  static const double maxCombinedAccuracyBufferMeters = 60.0;

  final Future<PassportLocationSnapshot?> Function({Duration timeout})?
      _overrideCapture;

  const PassportLocationService({
    Future<PassportLocationSnapshot?> Function({Duration timeout})?
        overrideCapture,
  }) : _overrideCapture = overrideCapture;

  /// Pure-Dart WGS84 Haversine distance in meters between two coordinates.
  static double distanceBetweenMeters(
    double lat1,
    double lng1,
    double lat2,
    double lng2,
  ) {
    const double earthRadiusMeters = 6371000.0;
    final double dLat = _degToRad(lat2 - lat1);
    final double dLng = _degToRad(lng2 - lng1);
    final double rLat1 = _degToRad(lat1);
    final double rLat2 = _degToRad(lat2);

    final double a = sin(dLat / 2) * sin(dLat / 2) +
        cos(rLat1) * cos(rLat2) * sin(dLng / 2) * sin(dLng / 2);
    final double c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return earthRadiusMeters * c;
  }

  static double _degToRad(double deg) => deg * (pi / 180.0);

  /// Captures current GPS position without blocking or throwing on offline/headless hosts.
  Future<PassportLocationSnapshot?> captureSnapshot({
    Duration timeout = const Duration(seconds: 3),
  }) async {
    if (_overrideCapture != null) {
      return _overrideCapture!(timeout: timeout);
    }

    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        return null;
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever ||
          permission == LocationPermission.unableToDetermine) {
        return null;
      }

      Position? pos;
      try {
        pos = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
        ).timeout(timeout);
      } catch (_) {
        pos = await Geolocator.getLastKnownPosition();
      }

      if (pos == null) return null;

      return PassportLocationSnapshot(
        latitude: PassportLocationSnapshot.roundCoord(pos.latitude),
        longitude: PassportLocationSnapshot.roundCoord(pos.longitude),
        accuracyMeters: double.parse(pos.accuracy.toStringAsFixed(1)),
        isMocked: pos.isMocked,
        capturedAt: pos.timestamp,
      );
    } catch (e) {
      debugPrint('ℹ️ [PASSPORT_GPS] Location capture note: $e');
      return null;
    }
  }

  /// Evaluates hybrid GPS geofence & mock-provider rules.
  static PassportGeofenceEvaluation evaluate({
    double? teacherLatitude,
    double? teacherLongitude,
    double? teacherAccuracyMeters,
    double? studentLatitude,
    double? studentLongitude,
    double? studentAccuracyMeters,
    bool studentIsMocked = false,
    double allowedRadiusMeters = defaultAllowedRadiusMeters,
    double reviewThresholdMeters = defaultReviewThresholdMeters,
  }) {
    if (studentIsMocked) {
      return const PassportGeofenceEvaluation(
        status: PassportGeofenceStatus.mockDetected,
        statusCode: 'MOCK_DETECTED',
        summary: 'MOCK_GPS_DETECTED: Fake GPS / Mock Location provider blocked.',
      );
    }

    if (teacherLatitude == null ||
        teacherLongitude == null ||
        studentLatitude == null ||
        studentLongitude == null) {
      return const PassportGeofenceEvaluation(
        status: PassportGeofenceStatus.unavailable,
        statusCode: 'UNAVAILABLE',
        summary: 'Indoor GPS unavailable; verified via classroom radio/optical token.',
      );
    }

    final rawDistance = distanceBetweenMeters(
      teacherLatitude,
      teacherLongitude,
      studentLatitude,
      studentLongitude,
    );
    final roundedDistance = double.parse(rawDistance.toStringAsFixed(1));

    final combinedAccuracy =
        (teacherAccuracyMeters ?? 0.0).clamp(0.0, 100.0) +
        (studentAccuracyMeters ?? 0.0).clamp(0.0, 100.0);
    final accuracyBuffer = min(combinedAccuracy, maxCombinedAccuracyBufferMeters);
    final effectiveAllowed = allowedRadiusMeters + accuracyBuffer;
    final effectiveReviewCutoff = max(reviewThresholdMeters, effectiveAllowed);

    if (rawDistance <= effectiveAllowed) {
      return PassportGeofenceEvaluation(
        status: PassportGeofenceStatus.verified,
        distanceMeters: roundedDistance,
        statusCode: 'VERIFIED',
        summary: 'GPS verified (${roundedDistance.round()}m from classroom)',
      );
    }

    final bool highConfidenceTeacher = (teacherAccuracyMeters ?? 15.0) <= 35.0;
    final bool highConfidenceStudent = (studentAccuracyMeters ?? 15.0) <= 30.0;

    if (rawDistance > effectiveReviewCutoff &&
        highConfidenceTeacher &&
        highConfidenceStudent) {
      return PassportGeofenceEvaluation(
        status: PassportGeofenceStatus.outsideReview,
        distanceMeters: roundedDistance,
        statusCode: 'OUTSIDE_GEOFENCE',
        summary:
            'GPS_OUTSIDE_GEOFENCE: Student appears ${roundedDistance.round()}m away from classroom.',
      );
    }

    return PassportGeofenceEvaluation(
      status: PassportGeofenceStatus.unavailable,
      distanceMeters: roundedDistance,
      statusCode: 'INDOOR_DRIFT',
      summary:
          'Indoor GPS drift (${roundedDistance.round()}m, ±${studentAccuracyMeters?.round() ?? 0}m); deferred to radio/optical check.',
    );
  }
}
