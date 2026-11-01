class GatePassModel {
  final String id;
  final String studentId;
  final String? leaveRequestId;
  final String destination;
  final String reason;
  final DateTime expectedExitTime;
  final DateTime expectedReturnTime;
  final DateTime? actualExitTime;
  final DateTime? actualReturnTime;
  final String status;
  final String? qrNonce;
  final String? securityGuardId;
  final String? gateName;
  final String? verificationMode;
  final String? idempotencyKey;
  final DateTime createdAt;
  final String? credential;
  // Optional enriched student metadata
  final String? studentName;
  final String? registrationNumber;
  final String? course;
  final String? branch;
  final String? year;

  GatePassModel({
    required this.id,
    required this.studentId,
    this.leaveRequestId,
    required this.destination,
    required this.reason,
    required this.expectedExitTime,
    required this.expectedReturnTime,
    this.actualExitTime,
    this.actualReturnTime,
    required this.status,
    this.qrNonce,
    this.securityGuardId,
    this.gateName,
    this.verificationMode,
    this.idempotencyKey,
    required this.createdAt,
    this.credential,
    this.studentName,
    this.registrationNumber,
    this.course,
    this.branch,
    this.year,
  });

  bool get isPending => status.toUpperCase() == 'PENDING';
  bool get isApproved => status.toUpperCase() == 'APPROVED';
  bool get isIssued => status.toUpperCase() == 'ISSUED';
  bool get isExited => status.toUpperCase() == 'EXITED';
  bool get isReturned => status.toUpperCase() == 'RETURNED';
  bool get isExpired => status.toUpperCase() == 'EXPIRED';
  bool get isRejected => status.toUpperCase() == 'REJECTED';
  bool get isActive => isIssued || isExited;

  factory GatePassModel.fromMap(Map<String, dynamic> map, [String? credentialToken]) {
    final studentMap = map['student'] as Map<String, dynamic>?;

    return GatePassModel(
      id: map['id'] ?? '',
      studentId: map['studentId'] ?? (studentMap?['id'] ?? ''),
      leaveRequestId: map['leaveRequestId'],
      destination: map['destination'] ?? '',
      reason: map['reason'] ?? '',
      expectedExitTime: map['expectedExitTime'] != null
          ? DateTime.tryParse(map['expectedExitTime']) ?? DateTime.now()
          : DateTime.now(),
      expectedReturnTime: map['expectedReturnTime'] != null
          ? DateTime.tryParse(map['expectedReturnTime']) ?? DateTime.now()
          : DateTime.now(),
      actualExitTime: map['actualExitTime'] != null
          ? DateTime.tryParse(map['actualExitTime'])
          : null,
      actualReturnTime: map['actualReturnTime'] != null
          ? DateTime.tryParse(map['actualReturnTime'])
          : null,
      status: (map['status'] ?? 'PENDING').toString().toUpperCase(),
      qrNonce: map['qrNonce'],
      securityGuardId: map['securityGuardId'],
      gateName: map['gateName'] ?? 'Main Gate',
      verificationMode: map['verificationMode'] ?? 'QR_FALLBACK',
      idempotencyKey: map['idempotencyKey'],
      createdAt: map['createdAt'] != null
          ? DateTime.tryParse(map['createdAt']) ?? DateTime.now()
          : DateTime.now(),
      credential: credentialToken ?? map['credential'],
      studentName: studentMap?['name'] ?? map['studentName'],
      registrationNumber: studentMap?['registrationNumber'] ?? map['registrationNumber'],
      course: studentMap?['course'] ?? map['course'],
      branch: studentMap?['branch'] ?? map['branch'],
      year: studentMap?['year'] ?? map['year'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'studentId': studentId,
      'leaveRequestId': leaveRequestId,
      'destination': destination,
      'reason': reason,
      'expectedExitTime': expectedExitTime.toIso8601String(),
      'expectedReturnTime': expectedReturnTime.toIso8601String(),
      'actualExitTime': actualExitTime?.toIso8601String(),
      'actualReturnTime': actualReturnTime?.toIso8601String(),
      'status': status,
      'qrNonce': qrNonce,
      'securityGuardId': securityGuardId,
      'gateName': gateName,
      'verificationMode': verificationMode,
      'idempotencyKey': idempotencyKey,
      'createdAt': createdAt.toIso8601String(),
      'credential': credential,
      'studentName': studentName,
      'registrationNumber': registrationNumber,
      'course': course,
      'branch': branch,
      'year': year,
    };
  }
}
