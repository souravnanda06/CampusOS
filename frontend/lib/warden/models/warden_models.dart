/// CampusOS Warden Experience Models.
/// Strictly institutional - No parent consent.

class WardenSummaryModel {
  final int pendingRequests;
  final int pendingVisitors;
  final int approvedToday;
  final int activeGatePasses;
  final int recentActivityCount;
  final List<WardenLeaveRequestModel> pendingPreview;

  const WardenSummaryModel({
    required this.pendingRequests,
    this.pendingVisitors = 0,
    required this.approvedToday,
    required this.activeGatePasses,
    required this.recentActivityCount,
    required this.pendingPreview,
  });

  factory WardenSummaryModel.fromJson(Map<String, dynamic> json) {
    final previewList = (json['pendingPreview'] as List<dynamic>?) ?? [];
    return WardenSummaryModel(
      pendingRequests: json['pendingRequests'] is int
          ? json['pendingRequests']
          : int.tryParse('${json['pendingRequests']}') ?? 0,
      pendingVisitors: json['pendingVisitors'] is int
          ? json['pendingVisitors']
          : int.tryParse('${json['pendingVisitors']}') ?? 0,
      approvedToday: json['approvedToday'] is int
          ? json['approvedToday']
          : int.tryParse('${json['approvedToday']}') ?? 0,
      activeGatePasses: json['activeGatePasses'] is int
          ? json['activeGatePasses']
          : int.tryParse('${json['activeGatePasses']}') ?? 0,
      recentActivityCount: json['recentActivityCount'] is int
          ? json['recentActivityCount']
          : int.tryParse('${json['recentActivityCount']}') ?? 0,
      pendingPreview: previewList
          .map((item) => WardenLeaveRequestModel.fromJson(item as Map<String, dynamic>))
          .toList(),
    );
  }

  factory WardenSummaryModel.empty() {
    return const WardenSummaryModel(
      pendingRequests: 0,
      pendingVisitors: 0,
      approvedToday: 0,
      activeGatePasses: 0,
      recentActivityCount: 0,
      pendingPreview: [],
    );
  }
}

class WardenLeaveRequestModel {
  final String id;
  final String studentId;
  final String studentName;
  final String registrationNumber;
  final String course;
  final String branch;
  final String year;
  final String leaveType;
  final String startDate;
  final String endDate;
  final String reason;
  final String destination;
  final String status;
  final String? reviewedBy;
  final String? reviewRemarks;
  final int previousRequestsCount;
  final String createdAt;
  final String updatedAt;
  final String? studentPhone;
  final Map<String, dynamic>? gatePass;

  const WardenLeaveRequestModel({
    required this.id,
    required this.studentId,
    required this.studentName,
    required this.registrationNumber,
    required this.course,
    required this.branch,
    required this.year,
    required this.leaveType,
    required this.startDate,
    required this.endDate,
    required this.reason,
    required this.destination,
    required this.status,
    this.reviewedBy,
    this.reviewRemarks,
    required this.previousRequestsCount,
    required this.createdAt,
    required this.updatedAt,
    this.studentPhone,
    this.gatePass,
  });

  factory WardenLeaveRequestModel.fromJson(Map<String, dynamic> json) {
    return WardenLeaveRequestModel(
      id: json['id']?.toString() ?? '',
      studentId: json['studentId']?.toString() ?? '',
      studentName: json['studentName']?.toString() ?? 'Unknown Student',
      registrationNumber: json['registrationNumber']?.toString() ?? 'N/A',
      course: json['course']?.toString() ?? 'B.Tech',
      branch: json['branch']?.toString() ?? 'General',
      year: json['year']?.toString() ?? '1',
      leaveType: json['leaveType']?.toString() ?? 'LEAVE',
      startDate: json['startDate']?.toString() ?? '',
      endDate: json['endDate']?.toString() ?? '',
      reason: json['reason']?.toString() ?? '',
      destination: json['destination']?.toString() ?? 'Local',
      status: (json['status']?.toString() ?? 'PENDING').toUpperCase(),
      reviewedBy: json['reviewedBy']?.toString(),
      reviewRemarks: json['reviewRemarks']?.toString(),
      previousRequestsCount: json['previousRequestsCount'] is int
          ? json['previousRequestsCount']
          : int.tryParse('${json['previousRequestsCount']}') ?? 0,
      createdAt: json['createdAt']?.toString() ?? '',
      updatedAt: json['updatedAt']?.toString() ?? '',
      studentPhone: json['studentPhone']?.toString(),
      gatePass: json['gatePass'] is Map<String, dynamic>
          ? json['gatePass'] as Map<String, dynamic>
          : null,
    );
  }

  bool get isPending => status == 'PENDING';
  bool get isApproved => status == 'APPROVED';
  bool get isRejected => status == 'REJECTED';
}

class WardenActivityModel {
  final String id;
  final String entityType;
  final String entityId;
  final String actorId;
  final String actorName;
  final String actorRole;
  final String action;
  final String remarks;
  final String timestamp;
  final String? studentName;
  final String? registrationNumber;
  final String? destination;

  const WardenActivityModel({
    required this.id,
    required this.entityType,
    required this.entityId,
    required this.actorId,
    required this.actorName,
    required this.actorRole,
    required this.action,
    required this.remarks,
    required this.timestamp,
    this.studentName,
    this.registrationNumber,
    this.destination,
  });

  factory WardenActivityModel.fromJson(Map<String, dynamic> json) {
    return WardenActivityModel(
      id: json['id']?.toString() ?? '',
      entityType: json['entityType']?.toString() ?? 'LEAVE',
      entityId: json['entityId']?.toString() ?? '',
      actorId: json['actorId']?.toString() ?? '',
      actorName: json['actorName']?.toString() ?? 'System',
      actorRole: json['actorRole']?.toString() ?? 'WARDEN',
      action: json['action']?.toString() ?? 'ACTION',
      remarks: json['remarks']?.toString() ?? '',
      timestamp: json['timestamp']?.toString() ?? '',
      studentName: json['studentName']?.toString(),
      registrationNumber: json['registrationNumber']?.toString(),
      destination: json['destination']?.toString(),
    );
  }
}
