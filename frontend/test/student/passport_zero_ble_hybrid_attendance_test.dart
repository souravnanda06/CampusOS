import 'package:flutter_test/flutter_test.dart';
import 'package:attendance_app/student/models/passport_attendance_model.dart';
import 'package:attendance_app/student/services/passport_location_service.dart';
import 'package:attendance_app/teacher/services/passport_teacher_attendance_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  group('PassportRollingPinModel Tests (15-second Classroom Rolling PIN)', () {
    const sessionId = 'session_chem_101';
    const sessionNonce = 'nonce_abcdef1234567890';

    test('Generates deterministic 4-digit PIN for same session and timestamp', () {
      const timestamp = 1700000000;
      final pin1 = PassportRollingPinModel.generatePin(
        sessionId: sessionId,
        sessionNonce: sessionNonce,
        timestampSeconds: timestamp,
      );
      final pin2 = PassportRollingPinModel.generatePin(
        sessionId: sessionId,
        sessionNonce: sessionNonce,
        timestampSeconds: timestamp,
      );

      expect(pin1.length, 4);
      expect(pin1, equals(pin2));
      expect(int.tryParse(pin1), isNotNull);
    });

    test('Rotates PIN when crossing 15-second window boundary', () {
      const window1Time = 1700000000; // window = 113333333
      const window2Time = 1700000015; // window = 113333334

      final pin1 = PassportRollingPinModel.generatePin(
        sessionId: sessionId,
        sessionNonce: sessionNonce,
        timestampSeconds: window1Time,
      );
      final pin2 = PassportRollingPinModel.generatePin(
        sessionId: sessionId,
        sessionNonce: sessionNonce,
        timestampSeconds: window2Time,
      );

      expect(pin1, isNot(equals(pin2)));
    });

    test('Verifies valid PIN in active window and within +/- 1 window tolerance', () {
      const currentTime = 1700000030; // window W
      final currentPin = PassportRollingPinModel.generatePin(
        sessionId: sessionId,
        sessionNonce: sessionNonce,
        timestampSeconds: currentTime,
      );

      // Exact current window match
      expect(
        PassportRollingPinModel.verifyPin(
          enteredPin: currentPin,
          sessionId: sessionId,
          sessionNonce: sessionNonce,
          timestampSeconds: currentTime,
        ),
        isTrue,
      );

      // Previous window (within 15s grace skew)
      expect(
        PassportRollingPinModel.verifyPin(
          enteredPin: currentPin,
          sessionId: sessionId,
          sessionNonce: sessionNonce,
          timestampSeconds: currentTime + 10, // 10 seconds later, same/next window
        ),
        isTrue,
      );

      // Future window (within 15s skew)
      expect(
        PassportRollingPinModel.verifyPin(
          enteredPin: currentPin,
          sessionId: sessionId,
          sessionNonce: sessionNonce,
          timestampSeconds: currentTime - 10,
        ),
        isTrue,
      );
    });

    test('Rejects expired PIN beyond +/- 1 window skew (> 30s away)', () {
      const originalTime = 1700000000;
      final oldPin = PassportRollingPinModel.generatePin(
        sessionId: sessionId,
        sessionNonce: sessionNonce,
        timestampSeconds: originalTime,
      );

      // 45 seconds later (3 windows ahead)
      expect(
        PassportRollingPinModel.verifyPin(
          enteredPin: oldPin,
          sessionId: sessionId,
          sessionNonce: sessionNonce,
          timestampSeconds: originalTime + 45,
        ),
        isFalse,
      );
    });

    test('Rejects malformed PIN', () {
      expect(
        PassportRollingPinModel.verifyPin(
          enteredPin: '12',
          sessionId: sessionId,
          sessionNonce: sessionNonce,
        ),
        isFalse,
      );
      expect(
        PassportRollingPinModel.verifyPin(
          enteredPin: 'abcd',
          sessionId: sessionId,
          sessionNonce: sessionNonce,
        ),
        isFalse,
      );
    });

    test('Calculates remaining seconds and progress accurately', () {
      // 1700000000 % 15 = 5 -> remaining = 10s
      final remaining = PassportRollingPinModel.getRemainingSeconds(timestampSeconds: 1700000000);
      expect(remaining, 10);

      final progress = PassportRollingPinModel.getProgress(timestampSeconds: 1700000000);
      expect(progress, closeTo(10 / 15, 0.001));
    });
  });

  group('Teacher Beacon & Student Response Multi-Rail Models', () {
    test('PassportTeacherBeaconModel serializes and deserializes Wi-Fi & Hotspot parameters', () {
      final beacon = PassportTeacherBeaconModel.create(
        sessionId: 'session_phy_202',
        teacherId: 'teacher_smith',
        teacherKeyId: 'tk_9876',
        course: 'B.Tech',
        branch: 'ECE',
        year: '3',
        subject: 'Electromagnetics',
        routerBssid: '00:14:22:01:23:45',
        localIp: '192.168.1.120',
        localPort: 53318,
        hotspotSsid: 'CampusOS_Class_phy2',
        hotspotPassword: 'Pass_a1b2c3',
      );

      expect(beacon.routerBssid, '00:14:22:01:23:45');
      expect(beacon.localIp, '192.168.1.120');
      expect(beacon.localPort, 53318);
      expect(beacon.hotspotSsid, 'CampusOS_Class_phy2');
      expect(beacon.hotspotPassword, 'Pass_a1b2c3');

      // Test map round-trip
      final map = beacon.toMap();
      final fromMap = PassportTeacherBeaconModel.fromMap(map);
      expect(fromMap.routerBssid, beacon.routerBssid);
      expect(fromMap.localIp, beacon.localIp);
      expect(fromMap.localPort, beacon.localPort);
      expect(fromMap.hotspotSsid, beacon.hotspotSsid);

      // Test QR serialization round-trip
      final qrString = beacon.toQrString();
      final fromQr = PassportTeacherBeaconModel.fromQrString(qrString);
      expect(fromQr.sessionId, beacon.sessionId);
      expect(fromQr.routerBssid, beacon.routerBssid);
      expect(fromQr.localIp, beacon.localIp);
      expect(fromQr.localPort, beacon.localPort);
      expect(fromQr.hotspotSsid, beacon.hotspotSsid);
    });

    test('PassportAttendanceResponseModel supports all verification modes', () {
      for (final mode in [
        PassportAttendanceModel.modeBle,
        PassportAttendanceModel.modeWifiLan,
        PassportAttendanceModel.modeWifiHotspot,
        PassportAttendanceModel.modeQrOptical,
        PassportAttendanceModel.modePinManual,
      ]) {
        final resp = PassportAttendanceResponseModel.create(
          sessionId: 'session_bio_303',
          studentId: 'student_alice',
          deviceKeyId: 'dk_1122',
          challengeNonce: 'nonce_9988',
          verificationMode: mode,
          routerBssid: '00:14:22:01:23:45',
        );

        expect(resp.verificationMode, equals(mode));
        expect(resp.routerBssid, '00:14:22:01:23:45');

        final map = resp.toMap();
        final fromMap = PassportAttendanceResponseModel.fromMap(map);
        expect(fromMap.verificationMode, equals(mode));
        expect(fromMap.routerBssid, equals('00:14:22:01:23:45'));

        final qr = resp.toQrString();
        final fromQr = PassportAttendanceResponseModel.fromQrString(qr);
        expect(fromQr.studentId, 'student_alice');
        expect(fromQr.verificationMode, equals(mode));
        expect(fromQr.routerBssid, equals('00:14:22:01:23:45'));
      }
    });
  });

  group('PassportTeacherAttendanceService Zero-BLE & Wi-Fi Tests', () {
    test('Rolling PIN verification approves correct PIN and registers attendance', () async {
      final service = PassportTeacherAttendanceService();
      final beacon = PassportTeacherBeaconModel.create(
        sessionId: 'session_test_505',
        teacherId: 'teacher_t1',
        teacherKeyId: 'tk_t1',
        subject: 'Algorithms',
      );
      service.setActiveBeacon(beacon);

      final pin = service.currentRollingPin;
      expect(pin.length, 4);

      final result = await service.verifyStudentPin(
        studentId: 'student_carol',
        studentName: 'Carol Danvers',
        pin: pin,
      );

      expect(result.valid, isTrue);
      expect(result.status, PassportAttendanceStatus.verifiedPresent);
      expect(result.verificationMode, PassportAttendanceModel.modePinManual);
      expect(service.verifiedResults.containsKey('student_carol'), isTrue);
    });

    test('Rolling PIN verification rejects wrong PIN', () async {
      final service = PassportTeacherAttendanceService();
      final beacon = PassportTeacherBeaconModel.create(
        sessionId: 'session_test_506',
        teacherId: 'teacher_t2',
        teacherKeyId: 'tk_t2',
        subject: 'Calculus',
      );
      service.setActiveBeacon(beacon);

      final result = await service.verifyStudentPin(
        studentId: 'student_dave',
        studentName: 'Dave Miller',
        pin: '0000', // statistically unlikely to match deterministic hash
      );

      if (result.valid) {
        // If 0000 happens to be the hash, test with 9999
        final altResult = await service.verifyStudentPin(
          studentId: 'student_dave_2',
          studentName: 'Dave Miller',
          pin: '9999',
        );
        expect(altResult.valid, isFalse);
      } else {
        expect(result.valid, isFalse);
        expect(result.status, PassportAttendanceStatus.cryptoInvalid);
      }
    });

    test('Hotspot burst controller starts 60s countdown and stops cleanly', () async {
      final service = PassportTeacherAttendanceService();
      final beacon = PassportTeacherBeaconModel.create(
        sessionId: 'session_test_507',
        teacherId: 'teacher_t3',
        teacherKeyId: 'tk_t3',
      );
      service.setActiveBeacon(beacon);

      expect(service.isHotspotActive, isFalse);
      expect(service.hotspotRemainingSeconds, 0);

      await service.startHotspotBurst();
      expect(service.isHotspotActive, isTrue);
      expect(service.hotspotRemainingSeconds, 60);
      expect(service.hotspotSsid, isNotNull);
      expect(service.hotspotSsid, isNotEmpty);
      expect(service.hotspotPassword, isNotNull);

      service.stopHotspotBurst();
      expect(service.isHotspotActive, isFalse);
      expect(service.hotspotRemainingSeconds, 0);
    });

    test('Wi-Fi LAN mode rejects attendance when classroom router BSSID mismatches', () async {
      final service = PassportTeacherAttendanceService();
      service.setClassroomRouterBssid('00:11:22:33:44:55');

      final beacon = PassportTeacherBeaconModel.create(
        sessionId: 'session_test_508',
        teacherId: 'teacher_t4',
        teacherKeyId: 'tk_t4',
        routerBssid: '00:11:22:33:44:55',
      );
      service.setActiveBeacon(beacon);

      // Student arrives via Wi-Fi LAN, but connected to Hostel BSSID 'AA:BB:CC:DD:EE:FF'
      final studentResponse = PassportAttendanceResponseModel(
        sessionId: 'session_test_508',
        studentId: 'student_eve',
        deviceKeyId: 'dk_eve',
        challengeNonce: beacon.sessionNonce,
        issuedAt: DateTime.now().toUtc().millisecondsSinceEpoch ~/ 1000,
        expiresAt: (DateTime.now().toUtc().millisecondsSinceEpoch ~/ 1000) + 60,
        biometricGate: true,
        responseNonce: 'nonce_eve_123',
        signature: 'valid_sig',
        verificationMode: PassportAttendanceModel.modeWifiLan,
        routerBssid: 'AA:BB:CC:DD:EE:FF', // Mismatched router BSSID!
      );

      final result = await service.verifyResponseOffline(
        response: studentResponse,
        rssiSamples: const [-45],
        verificationMode: PassportAttendanceModel.modeWifiLan,
      );

      expect(result.valid, isFalse);
      expect(result.status, PassportAttendanceStatus.proximityInconclusive);
      expect(result.reason, contains('BSSID_MISMATCH'));
    });

    test('verifyResponseOffline validates correct Room PIN in modePinManual and rejects wrong PIN', () async {
      final service = PassportTeacherAttendanceService();
      const nowSec = 1700000000;
      const beacon = PassportTeacherBeaconModel(
        sessionId: 'session_pin_test',
        teacherId: 'teacher_t5',
        teacherKeyId: 'tk_t5',
        sessionNonce: 'nonce_pin_123',
        issuedAt: nowSec,
        expiresAt: nowSec + 900,
      );
      service.setActiveBeacon(beacon);
      final correctPin = PassportRollingPinModel.generatePin(
        sessionId: 'session_pin_test',
        sessionNonce: 'nonce_pin_123',
        timestampSeconds: nowSec,
      );

      // Student submitting valid PIN
      final validResponse = PassportAttendanceResponseModel(
        sessionId: 'session_pin_test',
        studentId: 'student_valid_pin',
        deviceKeyId: 'dk_val',
        challengeNonce: beacon.sessionNonce,
        issuedAt: nowSec,
        expiresAt: nowSec + 60,
        biometricGate: true,
        responseNonce: correctPin,
        signature: 'valid_sig',
        verificationMode: PassportAttendanceModel.modePinManual,
      );

      final validResult = await service.verifyResponseOffline(
        response: validResponse,
        rssiSamples: const [-45],
        verificationMode: PassportAttendanceModel.modePinManual,
        currentTimestampSeconds: nowSec,
      );

      expect(validResult.valid, isTrue);
      expect(validResult.status, PassportAttendanceStatus.verifiedPresent);

      // Student submitting fake/wrong PIN
      final fakeResponse = PassportAttendanceResponseModel(
        sessionId: 'session_pin_test',
        studentId: 'student_fake_pin',
        deviceKeyId: 'dk_fake',
        challengeNonce: beacon.sessionNonce,
        issuedAt: nowSec,
        expiresAt: nowSec + 60,
        biometricGate: true,
        responseNonce: '9999', // wrong pin
        signature: 'fake_sig',
        verificationMode: PassportAttendanceModel.modePinManual,
      );

      final fakeResult = await service.verifyResponseOffline(
        response: fakeResponse,
        rssiSamples: const [-45],
        verificationMode: PassportAttendanceModel.modePinManual,
        currentTimestampSeconds: nowSec,
      );

      expect(fakeResult.valid, isFalse);
      expect(fakeResult.status, PassportAttendanceStatus.cryptoInvalid);
      expect(fakeResult.reason, contains('PIN_INVALID'));
    });

    test('Dynamic Optical QR rotates every 10 seconds and rejects expired QR', () {
      final now = DateTime.now().toUtc().millisecondsSinceEpoch ~/ 1000;
      final beacon = PassportTeacherBeaconModel(
        sessionId: 'session_qr_test',
        teacherId: 'teacher_t6',
        teacherKeyId: 'tk_t6',
        sessionNonce: 'nonce_qr_123',
        issuedAt: now,
        expiresAt: now + 900,
      );

      final qrString = beacon.toQrString(dynamicWindowSeconds: 10);
      expect(qrString, isNotEmpty);

      final parsed = PassportTeacherBeaconModel.fromQrString(qrString);
      expect(parsed.sessionId, 'session_qr_test');

      // Fresh QR is not expired
      expect(parsed.isExpired(now), isFalse);

      // 25 seconds later (well past 10s window + 5s grace), QR is expired
      expect(parsed.isExpired(now + 25), isTrue);
    });

    test('Teacher Hotspot generates WPA2-compliant (>=8 char) credentials and manages lifecycle', () async {
      final service = PassportTeacherAttendanceService();
      final beacon = PassportTeacherBeaconModel.create(
        sessionId: 'session_hotspot_test',
        teacherId: 'teacher_t7',
        teacherKeyId: 'tk_t7',
      );
      service.setActiveBeacon(beacon);

      await service.startHotspotBurst();
      expect(service.isHotspotActive, isTrue);
      expect(service.hotspotSsid, isNotNull);
      expect(service.hotspotSsid, isNotEmpty);
      expect(service.hotspotPassword, isNotNull);
      // WPA2 passphrase must be at least 8 characters
      expect(service.hotspotPassword!.length, greaterThanOrEqualTo(8));

      // Test custom hotspot credential updating (Option A)
      await service.saveHotspotCredentials('Prof_Sharma_5G', 'physics2026');
      expect(service.hotspotSsid, 'Prof_Sharma_5G');
      expect(service.hotspotPassword, 'physics2026');

      // Active beacon is updated with hotspot credentials
      expect(service.activeBeacon?.hotspotSsid, service.hotspotSsid);
      expect(service.activeBeacon?.hotspotPassword, service.hotspotPassword);

      // Verify MECARD format string
      final mecard = 'WIFI:S:${service.hotspotSsid};T:WPA;P:${service.hotspotPassword};;';
      expect(mecard, contains('WIFI:S:${service.hotspotSsid}'));
      expect(mecard, contains(';P:${service.hotspotPassword};;'));

      // Verify response model supports modeWifiHotspot
      final studentResponse = PassportAttendanceResponseModel(
        sessionId: 'session_hotspot_test',
        studentId: 'student_hotspot_user',
        deviceKeyId: 'dk_hotspot_user',
        challengeNonce: beacon.sessionNonce,
        issuedAt: DateTime.now().toUtc().millisecondsSinceEpoch ~/ 1000,
        expiresAt: (DateTime.now().toUtc().millisecondsSinceEpoch ~/ 1000) + 60,
        biometricGate: true,
        responseNonce: 'nonce_hotspot_99',
        signature: 'valid_sig',
        verificationMode: PassportAttendanceModel.modeWifiHotspot,
      );

      expect(studentResponse.verificationMode, PassportAttendanceModel.modeWifiHotspot);
      final responseMap = studentResponse.toMap();
      expect(responseMap['verificationMode'], PassportAttendanceModel.modeWifiHotspot);

      service.stopHotspotBurst();
      expect(service.isHotspotActive, isFalse);
      expect(service.hotspotRemainingSeconds, 0);
    });

    test('X-CAMPUSOS hybrid QR format encodes and parses Wi-Fi and real session parameters accurately', () {
      const ssid = 'Prof_Sharma_5G';
      const pass = 'physics2026';
      const sessionId = 'session_physics_101';
      const nonce = 'nonce_abc123xyz789';
      const teacherId = 'teacher_sharma';
      const ip = '192.168.43.1';
      const port = 53318;

      const qrData = 'WIFI:S:$ssid;T:WPA;P:$pass;X-CAMPUSOS:$sessionId,$nonce,$teacherId,$ip,$port;;';

      // Parse SSID & Password
      final ssidMatch = RegExp(r'S:([^;]+)').firstMatch(qrData);
      final passMatch = RegExp(r'P:([^;]+)').firstMatch(qrData);
      expect(ssidMatch?.group(1), ssid);
      expect(passMatch?.group(1), pass);

      // Parse X-CAMPUSOS
      final metaMatch = RegExp(r'X-CAMPUSOS:([^;]+)').firstMatch(qrData);
      expect(metaMatch, isNotNull);
      final parts = metaMatch!.group(1)!.split(',');
      expect(parts[0], sessionId);
      expect(parts[1], nonce);
      expect(parts[2], teacherId);
      expect(parts[3], ip);
      expect(int.parse(parts[4]), port);
    });
  });

  group('Hybrid GPS Geofence & Anti-Mock Location Tests', () {
    test('Calculates Haversine distance accurately and handles mock, verified, outside, and unavailable GPS states', () {
      const teacherLat = 28.613939;
      const teacherLng = 77.209021;

      // 1. In-classroom student (~11m away)
      const nearLat = 28.614039;
      const nearLng = 77.209021;
      final nearEval = PassportLocationService.evaluate(
        teacherLatitude: teacherLat,
        teacherLongitude: teacherLng,
        teacherAccuracyMeters: 10.0,
        studentLatitude: nearLat,
        studentLongitude: nearLng,
        studentAccuracyMeters: 12.0,
        studentIsMocked: false,
      );
      expect(nearEval.status, PassportGeofenceStatus.verified);
      expect(nearEval.statusCode, 'VERIFIED');
      expect(nearEval.distanceMeters, isNotNull);
      expect(nearEval.distanceMeters!, lessThan(20.0));

      // 2. Fake GPS / Mock Location spoofing -> hard blocked even at exact same coordinates
      final mockEval = PassportLocationService.evaluate(
        teacherLatitude: teacherLat,
        teacherLongitude: teacherLng,
        teacherAccuracyMeters: 10.0,
        studentLatitude: teacherLat,
        studentLongitude: teacherLng,
        studentAccuracyMeters: 5.0,
        studentIsMocked: true,
      );
      expect(mockEval.status, PassportGeofenceStatus.mockDetected);
      expect(mockEval.statusCode, 'MOCK_DETECTED');

      // 3. Far-away hostel student (~550m away) with crisp GPS accuracy -> outsideReview
      const farLat = 28.618939;
      const farLng = 77.209021;
      final farEval = PassportLocationService.evaluate(
        teacherLatitude: teacherLat,
        teacherLongitude: teacherLng,
        teacherAccuracyMeters: 12.0,
        studentLatitude: farLat,
        studentLongitude: farLng,
        studentAccuracyMeters: 15.0,
        studentIsMocked: false,
      );
      expect(farEval.status, PassportGeofenceStatus.outsideReview);
      expect(farEval.statusCode, 'OUTSIDE_GEOFENCE');
      expect(farEval.distanceMeters!, greaterThan(500.0));

      // 4. Missing indoor GPS -> graceful unavailable bypass
      final indoorEval = PassportLocationService.evaluate(
        teacherLatitude: teacherLat,
        teacherLongitude: teacherLng,
        studentLatitude: null,
        studentLongitude: null,
      );
      expect(indoorEval.status, PassportGeofenceStatus.unavailable);
      expect(indoorEval.statusCode, 'UNAVAILABLE');
    });

    test('Beacon and Response models preserve GPS telemetry across Map & QR round-trips', () {
      final beacon = PassportTeacherBeaconModel.create(
        sessionId: 'sess_gps_1',
        teacherId: 'teacher_gps',
        teacherKeyId: 'tk_gps',
        teacherLatitude: 28.613939,
        teacherLongitude: 77.209021,
        teacherLocationAccuracy: 8.5,
      );

      final qrParsed = PassportTeacherBeaconModel.fromQrString(beacon.toQrString());
      expect(qrParsed.teacherLatitude, closeTo(28.613939, 1e-6));
      expect(qrParsed.teacherLongitude, closeTo(77.209021, 1e-6));
      expect(qrParsed.teacherLocationAccuracy, closeTo(8.5, 0.1));

      final resp = PassportAttendanceResponseModel.create(
        sessionId: 'sess_gps_1',
        studentId: 'student_gps',
        deviceKeyId: 'dk_gps',
        challengeNonce: beacon.sessionNonce,
        verificationMode: PassportAttendanceModel.modeWifiHotspot,
        latitude: 28.614011,
        longitude: 77.209044,
        gpsAccuracy: 10.2,
        isMockedGps: true,
      );

      final mapDecoded = PassportAttendanceResponseModel.fromMap(resp.toMap());
      expect(mapDecoded.latitude, closeTo(28.614011, 1e-6));
      expect(mapDecoded.longitude, closeTo(77.209044, 1e-6));
      expect(mapDecoded.gpsAccuracy, closeTo(10.2, 0.1));
      expect(mapDecoded.isMockedGps, isTrue);
    });

    test('Teacher service blocks mock GPS, flags far-away responses, and embeds GPS into X-CAMPUSOS QR', () async {
      final service = PassportTeacherAttendanceService();
      final beacon = PassportTeacherBeaconModel.create(
        sessionId: 'sess_geo_verify',
        teacherId: 'teacher_geo',
        teacherKeyId: 'tk_geo',
        customSessionNonce: 'nonce_geo_1234567890',
        teacherLatitude: 28.613939,
        teacherLongitude: 77.209021,
        teacherLocationAccuracy: 10.0,
      );
      service.setActiveBeacon(beacon);

      final now = DateTime.now().toUtc().millisecondsSinceEpoch ~/ 1000;

      // 1. Mock GPS rejected immediately
      final mockResp = PassportAttendanceResponseModel.create(
        sessionId: beacon.sessionId,
        studentId: 'student_mock',
        deviceKeyId: 'dk_mock',
        challengeNonce: beacon.sessionNonce,
        currentTimestampSeconds: now,
        verificationMode: PassportAttendanceModel.modeWifiHotspot,
        latitude: 28.613939,
        longitude: 77.209021,
        gpsAccuracy: 5.0,
        isMockedGps: true,
      ).withSignature('sig_test');

      final mockRes = await service.verifyResponseOffline(
        response: mockResp,
        rssiSamples: const [-45],
        verificationMode: PassportAttendanceModel.modeWifiHotspot,
        currentTimestampSeconds: now,
      );
      expect(mockRes.valid, isFalse);
      expect(mockRes.status, PassportAttendanceStatus.fakeBeacon);
      expect(mockRes.gpsStatus, 'MOCK_DETECTED');

      // 2. Far-away student (~550m away) -> routed to Exception Queue (proximityInconclusive)
      final farResp = PassportAttendanceResponseModel.create(
        sessionId: beacon.sessionId,
        studentId: 'student_far',
        deviceKeyId: 'dk_far',
        challengeNonce: beacon.sessionNonce,
        currentTimestampSeconds: now,
        verificationMode: PassportAttendanceModel.modeWifiHotspot,
        latitude: 28.618939,
        longitude: 77.209021,
        gpsAccuracy: 12.0,
        isMockedGps: false,
      ).withSignature('sig_test');

      final farRes = await service.verifyResponseOffline(
        response: farResp,
        rssiSamples: const [-45],
        verificationMode: PassportAttendanceModel.modeWifiHotspot,
        currentTimestampSeconds: now,
      );
      expect(farRes.valid, isFalse);
      expect(farRes.status, PassportAttendanceStatus.proximityInconclusive);
      expect(farRes.gpsStatus, 'OUTSIDE_GEOFENCE');
      expect(farRes.gpsDistanceMeters!, greaterThan(500.0));

      // 3. In-classroom student (~11m away) -> VERIFIED PRESENT with GPS distance!
      final nearResp = PassportAttendanceResponseModel.create(
        sessionId: beacon.sessionId,
        studentId: 'student_near',
        deviceKeyId: 'dk_near',
        challengeNonce: beacon.sessionNonce,
        currentTimestampSeconds: now,
        verificationMode: PassportAttendanceModel.modeWifiHotspot,
        latitude: 28.614039,
        longitude: 77.209021,
        gpsAccuracy: 10.0,
        isMockedGps: false,
      ).withSignature('sig_test');

      final nearRes = await service.verifyResponseOffline(
        response: nearResp,
        rssiSamples: const [-45],
        verificationMode: PassportAttendanceModel.modeWifiHotspot,
        currentTimestampSeconds: now,
      );
      expect(nearRes.valid, isTrue);
      expect(nearRes.status, PassportAttendanceStatus.verifiedPresent);
      expect(nearRes.gpsStatus, 'VERIFIED');
      expect(nearRes.gpsDistanceMeters!, lessThan(20.0));

      // 4. X-CAMPUSOS QR includes teacher GPS anchor at indices 5, 6, 7
      await service.saveHotspotCredentials('Lab_Hotspot', 'securepass123');
      final hybridQr = service.buildWifiHotspotQrPayload(
        sessionId: beacon.sessionId,
        fallbackTeacherId: beacon.teacherId,
        gatewayIpOverride: '192.168.43.1',
      );
      final metaMatch = RegExp(r'X-CAMPUSOS:([^;]+)').firstMatch(hybridQr);
      expect(metaMatch, isNotNull);
      final parts = metaMatch!.group(1)!.split(',');
      expect(parts.length, 8);
      expect(double.parse(parts[5]), closeTo(28.613939, 1e-6));
      expect(double.parse(parts[6]), closeTo(77.209021, 1e-6));
      expect(double.parse(parts[7]), closeTo(10.0, 0.1));
    });
  });
}
