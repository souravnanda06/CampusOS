import '../../student/models/gate_pass_model.dart';

/// Operational gate metrics summary model for Security Command Center.
class GateSummaryModel {
  final String gateStatus;
  final DateTime currentTime;
  final String activeShift;
  final int passesAwaitingVerification;
  final int studentsOutside;
  final int recentlyExited;
  final int recentlyReturned;
  final int failedAttempts;
  final int offlineSyncPendingCount;

  GateSummaryModel({
    required this.gateStatus,
    required this.currentTime,
    required this.activeShift,
    required this.passesAwaitingVerification,
    required this.studentsOutside,
    required this.recentlyExited,
    required this.recentlyReturned,
    required this.failedAttempts,
    required this.offlineSyncPendingCount,
  });

  factory GateSummaryModel.fromMap(Map<String, dynamic> map, {int pendingOffline = 0}) {
    return GateSummaryModel(
      gateStatus: map['gateStatus'] ?? 'ONLINE',
      currentTime: map['currentTime'] != null
          ? DateTime.tryParse(map['currentTime']) ?? DateTime.now()
          : DateTime.now(),
      activeShift: map['activeShift'] ?? 'Active Shift',
      passesAwaitingVerification: map['passesAwaitingVerification'] ?? 0,
      studentsOutside: map['studentsOutside'] ?? 0,
      recentlyExited: map['recentlyExited'] ?? 0,
      recentlyReturned: map['recentlyReturned'] ?? 0,
      failedAttempts: map['failedAttempts'] ?? 0,
      offlineSyncPendingCount: pendingOffline,
    );
  }

  factory GateSummaryModel.empty({int pendingOffline = 0}) {
    return GateSummaryModel(
      gateStatus: 'OFFLINE',
      currentTime: DateTime.now(),
      activeShift: 'Shift Offline',
      passesAwaitingVerification: 0,
      studentsOutside: 0,
      recentlyExited: 0,
      recentlyReturned: 0,
      failedAttempts: 0,
      offlineSyncPendingCount: pendingOffline,
    );
  }
}

/// Verification result following HMAC or BLE verification.
class GateVerificationResult {
  final bool valid;
  final String resultCode; // VERIFIED, ALREADY_PROCESSED, EXPIRED, INVALID_STATE, INVALID_CREDENTIAL, NOT_FOUND
  final String message;
  final String? gatePassId;
  final String? action; // 'EXIT' or 'RETURN'
  final Map<String, dynamic>? student;
  final GatePassModel? pass;
  final bool isOfflineVerified;

  GateVerificationResult({
    required this.valid,
    required this.resultCode,
    required this.message,
    this.gatePassId,
    this.action,
    this.student,
    this.pass,
    this.isOfflineVerified = false,
  });

  factory GateVerificationResult.fromMap(Map<String, dynamic> map, {bool offline = false}) {
    GatePassModel? passModel;
    if (map['pass'] != null) {
      passModel = GatePassModel.fromMap(map['pass']);
    }

    return GateVerificationResult(
      valid: map['valid'] ?? false,
      resultCode: map['resultCode'] ?? (map['valid'] == true ? 'VERIFIED' : 'INVALID_CREDENTIAL'),
      message: map['message'] ?? '',
      gatePassId: map['gatePassId'],
      action: map['action'],
      student: map['student'] as Map<String, dynamic>?,
      pass: passModel,
      isOfflineVerified: offline,
    );
  }

  factory GateVerificationResult.error(String message, [String code = 'INVALID_CREDENTIAL']) {
    return GateVerificationResult(
      valid: false,
      resultCode: code,
      message: message,
    );
  }
}

/// Audit activity timeline item for Gate Security.
class GateActivityItem {
  final String id;
  final String? passId;
  final String operation; // EXIT, RETURN, VERIFY
  final String result; // SUCCESS, FAILED, DUPLICATE
  final String verificationMode; // BLE, QR_FALLBACK, OFFLINE
  final DateTime timestamp;
  final String remarks;
  final String studentName;
  final String registrationNumber;
  final String staffName;

  GateActivityItem({
    required this.id,
    this.passId,
    required this.operation,
    required this.result,
    required this.verificationMode,
    required this.timestamp,
    required this.remarks,
    required this.studentName,
    required this.registrationNumber,
    required this.staffName,
  });

  factory GateActivityItem.fromMap(Map<String, dynamic> map) {
    final student = map['student'] as Map<String, dynamic>?;
    final staff = map['securityStaff'] as Map<String, dynamic>?;

    return GateActivityItem(
      id: map['id'] ?? '',
      passId: map['passId'],
      operation: map['operation'] ?? 'VERIFY',
      result: map['result'] ?? 'SUCCESS',
      verificationMode: map['verificationMode'] ?? 'QR_FALLBACK',
      timestamp: map['timestamp'] != null
          ? DateTime.tryParse(map['timestamp']) ?? DateTime.now()
          : DateTime.now(),
      remarks: map['remarks'] ?? '',
      studentName: student?['name'] ?? 'Unknown Student',
      registrationNumber: student?['registrationNumber'] ?? 'N/A',
      staffName: staff?['name'] ?? 'Gate Security',
    );
  }
}
