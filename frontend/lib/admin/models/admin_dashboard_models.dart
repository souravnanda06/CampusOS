import '../../student/models/complaint_history_model.dart';

class AdminDashboardSummaryModel {
  final int totalComplaints;
  final int pendingComplaints;
  final int assignedComplaints;
  final int inProgressComplaints;
  final int resolvedComplaints;
  final int closedComplaints;
  final int reopenedComplaints;
  final int rejectedComplaints;
  final int ageingComplaints;
  final double averageResolutionHours;

  AdminDashboardSummaryModel({
    required this.totalComplaints,
    required this.pendingComplaints,
    required this.assignedComplaints,
    required this.inProgressComplaints,
    required this.resolvedComplaints,
    required this.closedComplaints,
    required this.reopenedComplaints,
    required this.rejectedComplaints,
    required this.ageingComplaints,
    required this.averageResolutionHours,
  });

  factory AdminDashboardSummaryModel.fromMap(Map<String, dynamic> map) {
    return AdminDashboardSummaryModel(
      totalComplaints: (map['totalComplaints'] as num?)?.toInt() ?? 0,
      pendingComplaints: (map['pendingComplaints'] as num?)?.toInt() ?? 0,
      assignedComplaints: (map['assignedComplaints'] as num?)?.toInt() ?? 0,
      inProgressComplaints: (map['inProgressComplaints'] as num?)?.toInt() ?? 0,
      resolvedComplaints: (map['resolvedComplaints'] as num?)?.toInt() ?? 0,
      closedComplaints: (map['closedComplaints'] as num?)?.toInt() ?? 0,
      reopenedComplaints: (map['reopenedComplaints'] as num?)?.toInt() ?? 0,
      rejectedComplaints: (map['rejectedComplaints'] as num?)?.toInt() ?? 0,
      ageingComplaints: (map['ageingComplaints'] as num?)?.toInt() ?? 0,
      averageResolutionHours: (map['averageResolutionHours'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

class AdminComplaintItemModel {
  final String id;
  final String studentId;
  final String studentName;
  final String? studentEmail;
  final String? registrationNumber;
  final String? branch;
  final String? year;
  final String category;
  final String title;
  final String description;
  final String location;
  final String priority;
  final String status;
  final String? assignedTo;
  final String? assignedToName;
  final String? resolutionRemarks;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final double ageHours;
  final bool isAgeing;

  AdminComplaintItemModel({
    required this.id,
    required this.studentId,
    required this.studentName,
    this.studentEmail,
    this.registrationNumber,
    this.branch,
    this.year,
    required this.category,
    required this.title,
    required this.description,
    required this.location,
    required this.priority,
    required this.status,
    this.assignedTo,
    this.assignedToName,
    this.resolutionRemarks,
    required this.createdAt,
    this.updatedAt,
    required this.ageHours,
    required this.isAgeing,
  });

  factory AdminComplaintItemModel.fromMap(Map<String, dynamic> map) {
    return AdminComplaintItemModel(
      id: map['id'] ?? '',
      studentId: map['studentId'] ?? '',
      studentName: map['studentName'] ?? 'Student',
      studentEmail: map['studentEmail'],
      registrationNumber: map['registrationNumber'],
      branch: map['branch'],
      year: map['year'],
      category: map['category'] ?? 'General',
      title: map['title'] ?? '',
      description: map['description'] ?? '',
      location: map['location'] ?? 'Campus',
      priority: (map['priority'] ?? 'MEDIUM').toString().toUpperCase(),
      status: (map['status'] ?? 'PENDING').toString().toUpperCase(),
      assignedTo: map['assignedTo'],
      assignedToName: map['assignedToName'],
      resolutionRemarks: map['resolutionRemarks'] ?? map['resolutionNotes'],
      createdAt: map['createdAt'] != null
          ? DateTime.tryParse(map['createdAt']) ?? DateTime.now()
          : DateTime.now(),
      updatedAt: map['updatedAt'] != null
          ? DateTime.tryParse(map['updatedAt'])
          : null,
      ageHours: (map['ageHours'] as num?)?.toDouble() ?? 0.0,
      isAgeing: map['isAgeing'] == true,
    );
  }
}

class AdminAgeingComplaintModel {
  final String id;
  final String title;
  final String category;
  final String priority;
  final String status;
  final DateTime createdAt;
  final double ageHours;
  final String? assignedTo;
  final String? assignedToName;
  final int thresholdHours;

  AdminAgeingComplaintModel({
    required this.id,
    required this.title,
    required this.category,
    required this.priority,
    required this.status,
    required this.createdAt,
    required this.ageHours,
    this.assignedTo,
    this.assignedToName,
    required this.thresholdHours,
  });

  factory AdminAgeingComplaintModel.fromMap(Map<String, dynamic> map) {
    return AdminAgeingComplaintModel(
      id: map['id'] ?? map['complaintId'] ?? '',
      title: map['title'] ?? '',
      category: map['category'] ?? 'General',
      priority: (map['priority'] ?? 'MEDIUM').toString().toUpperCase(),
      status: (map['status'] ?? 'PENDING').toString().toUpperCase(),
      createdAt: map['createdAt'] != null
          ? DateTime.tryParse(map['createdAt']) ?? DateTime.now()
          : DateTime.now(),
      ageHours: (map['ageHours'] as num?)?.toDouble() ?? 0.0,
      assignedTo: map['assignedTo'],
      assignedToName: map['assignedToName'],
      thresholdHours: (map['thresholdHours'] as num?)?.toInt() ?? 48,
    );
  }
}

class StaffWorkloadModel {
  final String staffId;
  final String staffName;
  final String? staffRole;
  final int assignedCount;
  final int inProgressCount;
  final int resolvedCount;
  final int totalActive;

  StaffWorkloadModel({
    required this.staffId,
    required this.staffName,
    this.staffRole,
    required this.assignedCount,
    required this.inProgressCount,
    required this.resolvedCount,
    required this.totalActive,
  });

  factory StaffWorkloadModel.fromMap(Map<String, dynamic> map) {
    return StaffWorkloadModel(
      staffId: map['staffId'] ?? '',
      staffName: map['staffName'] ?? 'Staff',
      staffRole: map['staffRole'],
      assignedCount: (map['assignedCount'] as num?)?.toInt() ?? 0,
      inProgressCount: (map['inProgressCount'] as num?)?.toInt() ?? 0,
      resolvedCount: (map['resolvedCount'] as num?)?.toInt() ?? 0,
      totalActive: (map['totalActive'] as num?)?.toInt() ?? 0,
    );
  }
}

class CategoryDistributionModel {
  final String category;
  final int count;

  CategoryDistributionModel({
    required this.category,
    required this.count,
  });

  factory CategoryDistributionModel.fromMap(Map<String, dynamic> map) {
    return CategoryDistributionModel(
      category: map['category'] ?? 'General',
      count: (map['count'] as num?)?.toInt() ?? 0,
    );
  }
}

class StaffUserModel {
  final String id;
  final String name;
  final String email;
  final String role;
  final String? branch;
  final String? course;

  StaffUserModel({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    this.branch,
    this.course,
  });

  factory StaffUserModel.fromMap(Map<String, dynamic> map) {
    return StaffUserModel(
      id: map['id'] ?? '',
      name: map['name'] ?? '',
      email: map['email'] ?? '',
      role: map['role'] ?? 'teacher',
      branch: map['branch'],
      course: map['course'],
    );
  }
}

class ComplaintAuditModel {
  final String id;
  final String entityType;
  final String entityId;
  final String actorId;
  final String? actorName;
  final String? actorRole;
  final String action;
  final String? remarks;
  final String? timestamp;

  ComplaintAuditModel({
    required this.id,
    required this.entityType,
    required this.entityId,
    required this.actorId,
    this.actorName,
    this.actorRole,
    required this.action,
    this.remarks,
    this.timestamp,
  });

  factory ComplaintAuditModel.fromMap(Map<String, dynamic> map) {
    return ComplaintAuditModel(
      id: map['id'] ?? '',
      entityType: map['entityType'] ?? '',
      entityId: map['entityId'] ?? '',
      actorId: map['actorId'] ?? '',
      actorName: map['actorName'],
      actorRole: map['actorRole'],
      action: map['action'] ?? '',
      remarks: map['remarks'],
      timestamp: map['timestamp'],
    );
  }
}

class AdminComplaintDetailModel {
  final AdminComplaintItemModel complaint;
  final Map<String, dynamic>? student;
  final StaffUserModel? assignedStaff;
  final List<ComplaintHistoryModel> statusHistory;
  final List<ComplaintAuditModel> auditHistory;

  AdminComplaintDetailModel({
    required this.complaint,
    this.student,
    this.assignedStaff,
    required this.statusHistory,
    required this.auditHistory,
  });

  factory AdminComplaintDetailModel.fromMap(Map<String, dynamic> map) {
    final complaintData = map['complaint'] as Map<String, dynamic>? ?? {};
    final studentData = map['student'] as Map<String, dynamic>?;
    final staffData = map['assignedStaff'] as Map<String, dynamic>?;
    final historyList = (map['statusHistory'] as List<dynamic>? ?? [])
        .map((h) => ComplaintHistoryModel.fromMap(h as Map<String, dynamic>))
        .toList();
    final auditList = (map['auditHistory'] as List<dynamic>? ?? [])
        .map((a) => ComplaintAuditModel.fromMap(a as Map<String, dynamic>))
        .toList();

    return AdminComplaintDetailModel(
      complaint: AdminComplaintItemModel.fromMap(complaintData),
      student: studentData,
      assignedStaff: staffData != null ? StaffUserModel.fromMap(staffData) : null,
      statusHistory: historyList,
      auditHistory: auditList,
    );
  }
}

class RecurringIssueModel {
  final String recurrenceId;
  final String category;
  final String location;
  final int complaintCount;
  final DateTime firstComplaintAt;
  final DateTime latestComplaintAt;
  final int windowDays;
  final List<String> complaintIds;
  final int activeComplaintCount;
  final int resolvedComplaintCount;
  final double averageResolutionHours;
  final String highestPriority;
  final String escalationLevel;
  final String recurrenceStatus;

  RecurringIssueModel({
    required this.recurrenceId,
    required this.category,
    required this.location,
    required this.complaintCount,
    required this.firstComplaintAt,
    required this.latestComplaintAt,
    required this.windowDays,
    required this.complaintIds,
    required this.activeComplaintCount,
    required this.resolvedComplaintCount,
    required this.averageResolutionHours,
    required this.highestPriority,
    required this.escalationLevel,
    required this.recurrenceStatus,
  });

  bool get isActive => recurrenceStatus.toUpperCase() == 'ACTIVE';
  bool get isElevated => escalationLevel.toUpperCase() == 'ELEVATED';
  bool get isHigh => escalationLevel.toUpperCase() == 'HIGH';

  factory RecurringIssueModel.fromMap(Map<String, dynamic> map) {
    return RecurringIssueModel(
      recurrenceId: map['recurrenceId'] ?? '',
      category: map['category'] ?? '',
      location: map['location'] ?? '',
      complaintCount: (map['complaintCount'] as num?)?.toInt() ?? 0,
      firstComplaintAt: map['firstComplaintAt'] != null
          ? DateTime.tryParse(map['firstComplaintAt']) ?? DateTime.now()
          : DateTime.now(),
      latestComplaintAt: map['latestComplaintAt'] != null
          ? DateTime.tryParse(map['latestComplaintAt']) ?? DateTime.now()
          : DateTime.now(),
      windowDays: (map['windowDays'] as num?)?.toInt() ?? 14,
      complaintIds: (map['complaintIds'] as List<dynamic>? ?? [])
          .map((e) => e.toString())
          .toList(),
      activeComplaintCount: (map['activeComplaintCount'] as num?)?.toInt() ?? 0,
      resolvedComplaintCount: (map['resolvedComplaintCount'] as num?)?.toInt() ?? 0,
      averageResolutionHours: (map['averageResolutionHours'] as num?)?.toDouble() ?? 0.0,
      highestPriority: (map['highestPriority'] ?? 'MEDIUM').toString().toUpperCase(),
      escalationLevel: (map['escalationLevel'] ?? 'NORMAL').toString().toUpperCase(),
      recurrenceStatus: (map['recurrenceStatus'] ?? 'ACTIVE').toString().toUpperCase(),
    );
  }
}

class RecurringIssueDetailModel {
  final RecurringIssueModel recurrence;
  final List<AdminComplaintItemModel> complaints;

  RecurringIssueDetailModel({
    required this.recurrence,
    required this.complaints,
  });

  factory RecurringIssueDetailModel.fromMap(Map<String, dynamic> map) {
    final recData = map['recurrence'] as Map<String, dynamic>? ?? {};
    final compList = (map['complaints'] as List<dynamic>? ?? [])
        .map((e) => AdminComplaintItemModel.fromMap(e as Map<String, dynamic>))
        .toList();

    return RecurringIssueDetailModel(
      recurrence: RecurringIssueModel.fromMap(recData),
      complaints: compList,
    );
  }
}
