import 'package:flutter_test/flutter_test.dart';
import 'package:attendance_app/security/models/gate_security_models.dart';
import 'package:attendance_app/security/services/security_ble_verification_service.dart';
import 'package:attendance_app/student/models/gate_pass_model.dart';

void main() {
  group('CampusOS Gate Security Model & State Machine Tests', () {
    test('GateSummaryModel fromMap parses API response correctly', () {
      final jsonMap = {
        'gateStatus': 'ONLINE',
        'currentTime': '2026-09-27T14:30:00',
        'activeShift': 'Evening Shift (14:00 - 22:00)',
        'passesAwaitingVerification': 5,
        'studentsOutside': 12,
        'recentlyExited': 8,
        'recentlyReturned': 4,
        'failedAttempts': 1,
        'offlineSyncPendingCount': 0,
      };

      final summary = GateSummaryModel.fromMap(jsonMap, pendingOffline: 2);
      expect(summary.gateStatus, 'ONLINE');
      expect(summary.activeShift, 'Evening Shift (14:00 - 22:00)');
      expect(summary.passesAwaitingVerification, 5);
      expect(summary.studentsOutside, 12);
      expect(summary.recentlyExited, 8);
      expect(summary.recentlyReturned, 4);
      expect(summary.failedAttempts, 1);
      expect(summary.offlineSyncPendingCount, 2);
    });

    test('GateSummaryModel empty generates fallback metrics', () {
      final empty = GateSummaryModel.empty(pendingOffline: 3);
      expect(empty.gateStatus, 'OFFLINE');
      expect(empty.passesAwaitingVerification, 0);
      expect(empty.offlineSyncPendingCount, 3);
    });

    test('GateVerificationResult parses verified exit response', () {
      final jsonMap = {
        'valid': true,
        'resultCode': 'VERIFIED',
        'gatePassId': 'gp-test-123',
        'action': 'EXIT',
        'message': 'Gate Pass Verified',
        'student': {
          'id': 'st-1',
          'name': 'Rohan Verma',
          'registrationNumber': 'REG-001',
          'course': 'B.Tech',
          'branch': 'CSE',
          'year': '3',
        },
        'pass': {
          'id': 'gp-test-123',
          'studentId': 'st-1',
          'leaveRequestId': 'lr-456',
          'destination': 'Home',
          'reason': 'Family function',
          'expectedExitTime': '2026-09-27T15:00:00',
          'expectedReturnTime': '2026-09-28T18:00:00',
          'status': 'ISSUED',
          'createdAt': '2026-09-27T10:00:00',
        }
      };

      final result = GateVerificationResult.fromMap(jsonMap);
      expect(result.valid, isTrue);
      expect(result.resultCode, 'VERIFIED');
      expect(result.action, 'EXIT');
      expect(result.gatePassId, 'gp-test-123');
      expect(result.student?['name'], 'Rohan Verma');
      expect(result.pass, isNotNull);
      expect(result.pass?.status, 'ISSUED');
      expect(result.pass?.destination, 'Home');
    });

    test('GateVerificationResult error factory sets valid to false', () {
      final err = GateVerificationResult.error('Pass expired', 'EXPIRED');
      expect(err.valid, isFalse);
      expect(err.resultCode, 'EXPIRED');
      expect(err.message, 'Pass expired');
    });

    test('GateActivityItem maps audit record correctly', () {
      final jsonMap = {
        'id': 'audit-001',
        'passId': 'gp-001',
        'operation': 'EXIT',
        'result': 'SUCCESS',
        'verificationMode': 'QR_FALLBACK',
        'timestamp': '2026-09-27T16:00:00',
        'remarks': 'Exited towards Home',
        'student': {
          'id': 'st-001',
          'name': 'Rohan Verma',
          'registrationNumber': 'REG-001',
        },
        'securityStaff': {
          'id': 'sec-001',
          'name': 'Officer Vikram',
        },
      };

      final activity = GateActivityItem.fromMap(jsonMap);
      expect(activity.id, 'audit-001');
      expect(activity.operation, 'EXIT');
      expect(activity.result, 'SUCCESS');
      expect(activity.verificationMode, 'QR_FALLBACK');
      expect(activity.studentName, 'Rohan Verma');
      expect(activity.staffName, 'Officer Vikram');
    });

    test('GateBleState defines all 12 explicit states', () {
      const states = GateBleState.values;
      expect(states.length, 12);
      expect(GateBleState.idle.displayName, 'IDLE');
      expect(GateBleState.starting.displayName, 'STARTING');
      expect(GateBleState.active.displayName, 'ACTIVE');
      expect(GateBleState.processing.displayName, 'PROCESSING');
      expect(GateBleState.verified.displayName, 'VERIFIED');
      expect(GateBleState.duplicate.displayName, 'DUPLICATE');
      expect(GateBleState.invalid.displayName, 'INVALID');
      expect(GateBleState.unavailable.displayName, 'UNAVAILABLE');
      expect(GateBleState.failed.displayName, 'FAILED');
      expect(GateBleState.qrFallback.displayName, 'QR_FALLBACK');
      expect(GateBleState.offline.displayName, 'OFFLINE');
      expect(GateBleState.syncPending.displayName, 'SYNC_PENDING');
    });
  });

  group('GatePassModel & Cryptographic Credential Tests', () {
    test('GatePassModel parses with attached HMAC credential token', () {
      const mockCredential = 'eyJhbGciOiJIUzI1NiJ9.eyJnYXRlUGFzc0lkIjoiZ3AtMSJ9.sig123';
      final jsonMap = {
        'id': 'gp-1',
        'studentId': 'st-1',
        'destination': 'Delhi',
        'reason': 'Medical',
        'expectedExitTime': '2026-09-27T12:00:00',
        'expectedReturnTime': '2026-09-28T12:00:00',
        'status': 'ISSUED',
        'createdAt': '2026-09-27T08:00:00',
      };

      final model = GatePassModel.fromMap(jsonMap, mockCredential);
      expect(model.id, 'gp-1');
      expect(model.status, 'ISSUED');
      expect(model.credential, mockCredential);
      expect(model.destination, 'Delhi');
    });
  });
}
