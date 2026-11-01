import 'dart:convert';

/// Document / Certificate Request Model
class DocumentRequestModel {
  final String id;
  final String studentId;
  final String documentType;
  final String documentTypeName;
  final String purpose;
  final String status;
  final String? adminNotes;
  final String? approvedBy;
  final String? documentNumber;
  final String? fileUrl;
  final String? documentDataJson;
  final String? issuedAt;
  final String? expiresAt;
  final bool storedInWallet;
  final String? walletAddedAt;
  final String createdAt;

  // Additional joined fields
  final String? studentName;
  final String? registrationNumber;
  final String? branch;
  final String? year;

  DocumentRequestModel({
    required this.id,
    required this.studentId,
    required this.documentType,
    required this.documentTypeName,
    required this.purpose,
    required this.status,
    this.adminNotes,
    this.approvedBy,
    this.documentNumber,
    this.fileUrl,
    this.documentDataJson,
    this.issuedAt,
    this.expiresAt,
    required this.storedInWallet,
    this.walletAddedAt,
    required this.createdAt,
    this.studentName,
    this.registrationNumber,
    this.branch,
    this.year,
  });

  factory DocumentRequestModel.fromJson(Map<String, dynamic> json) {
    return DocumentRequestModel(
      id: json['id'] ?? '',
      studentId: json['studentId'] ?? '',
      documentType: json['documentType'] ?? 'BONAFIDE_CERTIFICATE',
      documentTypeName: json['documentTypeName'] ?? json['documentType'] ?? 'Bonafide Certificate',
      purpose: json['purpose'] ?? '',
      status: json['status'] ?? 'PENDING',
      adminNotes: json['adminNotes'],
      approvedBy: json['approvedBy'],
      documentNumber: json['documentNumber'],
      fileUrl: json['fileUrl'],
      documentDataJson: json['documentDataJson'],
      issuedAt: json['issuedAt'],
      expiresAt: json['expiresAt'],
      storedInWallet: json['storedInWallet'] == true,
      walletAddedAt: json['walletAddedAt'],
      createdAt: json['createdAt'] ?? '',
      studentName: json['studentName'],
      registrationNumber: json['registrationNumber'],
      branch: json['branch'],
      year: json['year']?.toString(),
    );
  }

  String? get certificateNumber => documentNumber;
  DateTime get requestedAt => DateTime.tryParse(createdAt) ?? DateTime.now();
}

/// Fees & Dues Record Model
class FeeRecordModel {
  final String id;
  final String studentId;
  final String title;
  final String category;
  final double amount;
  final double amountPaid;
  final double balanceDue;
  final String dueDate;
  final String status;
  final String? receiptNumber;
  final String? paidAt;
  final String? breakdownJson;
  final String academicYear;
  final int? semester;
  final String? studentName;
  final String? registrationNumber;

  FeeRecordModel({
    required this.id,
    required this.studentId,
    required this.title,
    required this.category,
    required this.amount,
    required this.amountPaid,
    required this.balanceDue,
    required this.dueDate,
    required this.status,
    this.receiptNumber,
    this.paidAt,
    this.breakdownJson,
    required this.academicYear,
    this.semester,
    this.studentName,
    this.registrationNumber,
  });

  factory FeeRecordModel.fromJson(Map<String, dynamic> json) {
    return FeeRecordModel(
      id: json['id'] ?? '',
      studentId: json['studentId'] ?? '',
      title: json['title'] ?? '',
      category: json['category'] ?? 'TUITION',
      amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
      amountPaid: (json['amountPaid'] as num?)?.toDouble() ?? 0.0,
      balanceDue: (json['balanceDue'] as num?)?.toDouble() ?? 0.0,
      dueDate: json['dueDate'] ?? '',
      status: json['status'] ?? 'DUE',
      receiptNumber: json['receiptNumber'],
      paidAt: json['paidAt'],
      breakdownJson: json['breakdownJson'],
      academicYear: json['academicYear'] ?? '2025-2026',
      semester: json['semester'],
      studentName: json['studentName'],
      registrationNumber: json['registrationNumber'],
    );
  }

  List<Map<String, dynamic>> get breakdownItems {
    if (breakdownJson == null || breakdownJson!.isEmpty) return [];
    try {
      final decoded = jsonDecode(breakdownJson!);
      if (decoded is List) {
        return List<Map<String, dynamic>>.from(decoded);
      }
    } catch (_) {}
    return [];
  }
}

/// Student Fee Summary Model for Wallet Card
class FeeSummaryModel {
  final double totalDue;
  final String status;
  final String nextDueDate;
  final String primaryCategory;
  final int recordsCount;

  FeeSummaryModel({
    required this.totalDue,
    required this.status,
    required this.nextDueDate,
    required this.primaryCategory,
    required this.recordsCount,
  });

  factory FeeSummaryModel.fromJson(Map<String, dynamic> json) {
    return FeeSummaryModel(
      totalDue: (json['totalDue'] as num?)?.toDouble() ?? 0.0,
      status: json['status'] ?? 'PAID',
      nextDueDate: json['nextDueDate'] ?? 'None',
      primaryCategory: json['primaryCategory'] ?? 'All Cleared',
      recordsCount: json['recordsCount'] ?? 0,
    );
  }
}

/// Class Update / Cancellation Model
class ClassUpdateModel {
  final String id;
  final String teacherId;
  final String courseCode;
  final String courseName;
  final String updateType;
  final String originalDate;
  final String? originalTime;
  final String? originalRoom;
  final String? newDate;
  final String? newTime;
  final String? newRoom;
  final String message;
  final String? affectedBranch;
  final int? affectedYear;
  final String status;
  final String createdAt;
  final String? teacherName;

  ClassUpdateModel({
    required this.id,
    required this.teacherId,
    required this.courseCode,
    required this.courseName,
    required this.updateType,
    required this.originalDate,
    this.originalTime,
    this.originalRoom,
    this.newDate,
    this.newTime,
    this.newRoom,
    required this.message,
    this.affectedBranch,
    this.affectedYear,
    required this.status,
    required this.createdAt,
    this.teacherName,
  });

  factory ClassUpdateModel.fromJson(Map<String, dynamic> json) {
    return ClassUpdateModel(
      id: json['id'] ?? '',
      teacherId: json['teacherId'] ?? '',
      courseCode: json['courseCode'] ?? '',
      courseName: json['courseName'] ?? '',
      updateType: json['updateType'] ?? 'ANNOUNCEMENT',
      originalDate: json['originalDate'] ?? '',
      originalTime: json['originalTime'],
      originalRoom: json['originalRoom'],
      newDate: json['newDate'],
      newTime: json['newTime'],
      newRoom: json['newRoom'],
      message: json['message'] ?? '',
      affectedBranch: json['affectedBranch'],
      affectedYear: json['affectedYear'],
      status: json['status'] ?? 'ACTIVE',
      createdAt: json['createdAt'] ?? '',
      teacherName: json['teacherName'],
    );
  }
}

/// Hostel & Room Allocation Model
class HostelAllocationModel {
  final String id;
  final String studentId;
  final String hostelName;
  final String block;
  final String roomNumber;
  final String bedNumber;
  final String occupancyType;
  final String allocatedAt;
  final String status;
  final String notes;
  final bool hasAllocation;
  final List<Map<String, dynamic>> roommates;

  HostelAllocationModel({
    required this.id,
    required this.studentId,
    required this.hostelName,
    required this.block,
    required this.roomNumber,
    required this.bedNumber,
    required this.occupancyType,
    required this.allocatedAt,
    required this.status,
    required this.notes,
    required this.hasAllocation,
    required this.roommates,
  });

  factory HostelAllocationModel.fromJson(Map<String, dynamic> json) {
    final rawRoommates = json['roommates'];
    List<Map<String, dynamic>> parsedRoommates = [];
    if (rawRoommates is List) {
      parsedRoommates = List<Map<String, dynamic>>.from(rawRoommates);
    }

    return HostelAllocationModel(
      id: json['id'] ?? '',
      studentId: json['studentId'] ?? '',
      hostelName: json['hostelName'] ?? '',
      block: json['block'] ?? '',
      roomNumber: json['roomNumber'] ?? '',
      bedNumber: json['bedNumber'] ?? '',
      occupancyType: json['occupancyType'] ?? 'DOUBLE',
      allocatedAt: json['allocatedAt'] ?? '',
      status: json['status'] ?? 'ACTIVE',
      notes: json['notes'] ?? '',
      hasAllocation: json['hasAllocation'] == true,
      roommates: parsedRoommates,
    );
  }

  String get bedLabel => bedNumber.isNotEmpty ? 'Bed $bedNumber' : 'Bed Assigned';
  String get roomType => occupancyType;
}

/// Hostel Request Model
class HostelRequestModel {
  final String id;
  final String studentId;
  final String requestType;
  final String? preferredHostel;
  final String? preferredRoom;
  final String reason;
  final String status;
  final String? wardenId;
  final String? wardenRemarks;
  final String createdAt;
  final String? studentName;
  final String? registrationNumber;
  final String? branch;

  HostelRequestModel({
    required this.id,
    required this.studentId,
    required this.requestType,
    this.preferredHostel,
    this.preferredRoom,
    required this.reason,
    required this.status,
    this.wardenId,
    this.wardenRemarks,
    required this.createdAt,
    this.studentName,
    this.registrationNumber,
    this.branch,
  });

  factory HostelRequestModel.fromJson(Map<String, dynamic> json) {
    return HostelRequestModel(
      id: json['id'] ?? '',
      studentId: json['studentId'] ?? '',
      requestType: json['requestType'] ?? 'ROOM_CHANGE',
      preferredHostel: json['preferredHostel'],
      preferredRoom: json['preferredRoom'],
      reason: json['reason'] ?? '',
      status: json['status'] ?? 'PENDING',
      wardenId: json['wardenId'],
      wardenRemarks: json['wardenRemarks'],
      createdAt: json['createdAt'] ?? '',
      studentName: json['studentName'],
      registrationNumber: json['registrationNumber'],
      branch: json['branch'],
    );
  }

  String? get preferredBlock => preferredHostel;
  String? get preferredRoomType => preferredRoom;
}

/// Hostel Asset Model
class HostelAssetModel {
  final String id;
  final String hostelName;
  final String roomNumber;
  final String assetCode;
  final String assetName;
  final String condition;
  final String? assignedStudentId;
  final String? installedDate;

  HostelAssetModel({
    required this.id,
    required this.hostelName,
    required this.roomNumber,
    required this.assetCode,
    required this.assetName,
    required this.condition,
    this.assignedStudentId,
    this.installedDate,
  });

  factory HostelAssetModel.fromJson(Map<String, dynamic> json) {
    return HostelAssetModel(
      id: json['id'] ?? '',
      hostelName: json['hostelName'] ?? '',
      roomNumber: json['roomNumber'] ?? '',
      assetCode: json['assetCode'] ?? '',
      assetName: json['assetName'] ?? '',
      condition: json['condition'] ?? 'GOOD',
      assignedStudentId: json['assignedStudentId'],
      installedDate: json['installedDate'],
    );
  }
}

/// Asset Issue Model
class AssetIssueModel {
  final String id;
  final String assetId;
  final String studentId;
  final String issueType;
  final String description;
  final String status;
  final String? resolutionNotes;
  final String reportedAt;
  final String? assetName;
  final String? assetCode;
  final String? roomNumber;
  final String? studentName;

  AssetIssueModel({
    required this.id,
    required this.assetId,
    required this.studentId,
    required this.issueType,
    required this.description,
    required this.status,
    this.resolutionNotes,
    required this.reportedAt,
    this.assetName,
    this.assetCode,
    this.roomNumber,
    this.studentName,
  });

  factory AssetIssueModel.fromJson(Map<String, dynamic> json) {
    return AssetIssueModel(
      id: json['id'] ?? '',
      assetId: json['assetId'] ?? '',
      studentId: json['studentId'] ?? '',
      issueType: json['issueType'] ?? 'DAMAGED',
      description: json['description'] ?? '',
      status: json['status'] ?? 'REPORTED',
      resolutionNotes: json['resolutionNotes'],
      reportedAt: json['reportedAt'] ?? '',
      assetName: json['assetName'],
      assetCode: json['assetCode'],
      roomNumber: json['roomNumber'],
      studentName: json['studentName'],
    );
  }

  String get urgency {
    if (description.startsWith('[') && description.contains(']')) {
      final tag = description.substring(1, description.indexOf(']'));
      if (['CRITICAL', 'HIGH', 'MEDIUM', 'LOW'].contains(tag.toUpperCase())) {
        return tag.toUpperCase();
      }
    }
    if (issueType == 'DAMAGED' || issueType == 'REPLACEMENT_REQUESTED') {
      return 'HIGH';
    }
    return 'MEDIUM';
  }
}

/// Visitor Request & Pass Model
class VisitorRequestModel {
  final String id;
  final String studentId;
  final String visitorName;
  final String visitorPhone;
  final String relation;
  final String purpose;
  final String visitDate;
  final String expectedEntryTime;
  final String expectedExitTime;
  final String status;
  final String? passCode;
  final String? enteredAt;
  final String? exitedAt;
  final String? studentName;
  final String? registrationNumber;

  VisitorRequestModel({
    required this.id,
    required this.studentId,
    required this.visitorName,
    required this.visitorPhone,
    required this.relation,
    required this.purpose,
    required this.visitDate,
    required this.expectedEntryTime,
    required this.expectedExitTime,
    required this.status,
    this.passCode,
    this.enteredAt,
    this.exitedAt,
    this.studentName,
    this.registrationNumber,
  });

  factory VisitorRequestModel.fromJson(Map<String, dynamic> json) {
    return VisitorRequestModel(
      id: json['id'] ?? '',
      studentId: json['studentId'] ?? '',
      visitorName: json['visitorName'] ?? '',
      visitorPhone: json['visitorPhone'] ?? '',
      relation: json['relation'] ?? 'Relative',
      purpose: json['purpose'] ?? '',
      visitDate: json['visitDate'] ?? '',
      expectedEntryTime: json['expectedEntryTime'] ?? '04:00 PM',
      expectedExitTime: json['expectedExitTime'] ?? '08:00 PM',
      status: json['status'] ?? 'PENDING',
      passCode: json['passCode'],
      enteredAt: json['enteredAt'],
      exitedAt: json['exitedAt'],
      studentName: json['studentName'],
      registrationNumber: json['registrationNumber'],
    );
  }
}

/// Notification Item Model
class NotificationItemModel {
  final String id;
  final String title;
  final String body;
  final String notificationType;
  final String? referenceId;
  final String status;
  final bool isRead;
  final String? deliveredAt;
  final String? readAt;
  final String createdAt;
  final String deepLinkRoute;
  final String actionLabel;

  NotificationItemModel({
    required this.id,
    required this.title,
    required this.body,
    required this.notificationType,
    this.referenceId,
    required this.status,
    required this.isRead,
    this.deliveredAt,
    this.readAt,
    required this.createdAt,
    required this.deepLinkRoute,
    required this.actionLabel,
  });

  factory NotificationItemModel.fromJson(Map<String, dynamic> json) {
    return NotificationItemModel(
      id: json['id'] ?? '',
      title: json['title'] ?? '',
      body: json['body'] ?? '',
      notificationType: json['notificationType'] ?? 'NOTICE',
      referenceId: json['referenceId'],
      status: json['status'] ?? 'PENDING',
      isRead: json['isRead'] == true,
      deliveredAt: json['deliveredAt'],
      readAt: json['readAt'],
      createdAt: json['createdAt'] ?? '',
      deepLinkRoute: json['deepLinkRoute'] ?? '/student/notices',
      actionLabel: json['actionLabel'] ?? 'View',
    );
  }
}

/// Global Search Result Model
class SearchResultModel {
  final String category;
  final String title;
  final String subtitle;
  final String id;
  final String deepLink;
  final String relevance;

  SearchResultModel({
    required this.category,
    required this.title,
    required this.subtitle,
    required this.id,
    required this.deepLink,
    required this.relevance,
  });

  factory SearchResultModel.fromJson(Map<String, dynamic> json) {
    return SearchResultModel(
      category: json['category'] ?? 'General',
      title: json['title'] ?? '',
      subtitle: json['subtitle'] ?? '',
      id: json['id'] ?? '',
      deepLink: json['deepLink'] ?? '',
      relevance: json['relevance'] ?? 'Medium',
    );
  }
}
