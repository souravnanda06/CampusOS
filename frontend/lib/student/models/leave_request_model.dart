class LeaveRequestModel {
  final String id;
  final String studentId;
  final String leaveType;
  final DateTime startDate;
  final DateTime endDate;
  final String reason;
  final String status;
  final String? reviewedBy;
  final String? reviewRemarks;
  final DateTime createdAt;
  final DateTime? updatedAt;

  LeaveRequestModel({
    required this.id,
    required this.studentId,
    required this.leaveType,
    required this.startDate,
    required this.endDate,
    required this.reason,
    required this.status,
    this.reviewedBy,
    this.reviewRemarks,
    required this.createdAt,
    this.updatedAt,
  });

  bool get isPending => status.toUpperCase() == 'PENDING';
  bool get isApproved => status.toUpperCase() == 'APPROVED';
  bool get isRejected => status.toUpperCase() == 'REJECTED';
  bool get isCancelled => status.toUpperCase() == 'CANCELLED';

  factory LeaveRequestModel.fromMap(Map<String, dynamic> map, [String? id]) {
    return LeaveRequestModel(
      id: id ?? map['id'] ?? '',
      studentId: map['studentId'] ?? '',
      leaveType: map['leaveType'] ?? 'General',
      startDate: map['startDate'] != null
          ? DateTime.tryParse(map['startDate']) ?? DateTime.now()
          : DateTime.now(),
      endDate: map['endDate'] != null
          ? DateTime.tryParse(map['endDate']) ?? DateTime.now()
          : DateTime.now(),
      reason: map['reason'] ?? '',
      status: (map['status'] ?? 'PENDING').toString().toUpperCase(),
      reviewedBy: map['reviewedBy'],
      reviewRemarks: map['reviewRemarks'],
      createdAt: map['createdAt'] != null
          ? DateTime.tryParse(map['createdAt']) ?? DateTime.now()
          : DateTime.now(),
      updatedAt: map['updatedAt'] != null
          ? DateTime.tryParse(map['updatedAt'])
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'studentId': studentId,
      'leaveType': leaveType,
      'startDate': startDate.toIso8601String().split('T')[0],
      'endDate': endDate.toIso8601String().split('T')[0],
      'reason': reason,
      'status': status,
      'reviewedBy': reviewedBy,
      'reviewRemarks': reviewRemarks,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
    };
  }
}
