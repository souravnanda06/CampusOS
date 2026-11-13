import '../../core/database/app_database.dart';

class ComplaintModel {
  final String id;
  final String? localId;
  final String? serverId;
  final String? idempotencyKey;
  final String syncState; // 'pending', 'synced', 'failed'
  final String studentId;
  final String category;
  final String title;
  final String description;
  final String location;
  final String priority;
  final String status;
  final bool isRepeat;
  final String? assignedTo;
  final String? assignedToName;
  final String? resolutionRemarks;
  final DateTime? resolvedAt;
  final DateTime createdAt;
  final DateTime? updatedAt;

  // Feature 2: Proof-of-Fix OTP & Escalation Slingshot
  final String? closureOtp;
  final DateTime? otpVerifiedAt;
  final int escalationLevel;
  final DateTime? escalatedAt;
  final bool vendorPenaltyFlag;
  final double vendorPenaltyAmount;
  final int? studentRating;
  final String? studentFeedback;

  ComplaintModel({
    required this.id,
    this.localId,
    this.serverId,
    this.idempotencyKey,
    this.syncState = 'synced',
    required this.studentId,
    required this.category,
    required this.title,
    required this.description,
    required this.location,
    required this.priority,
    required this.status,
    this.isRepeat = false,
    this.assignedTo,
    this.assignedToName,
    this.resolutionRemarks,
    this.resolvedAt,
    required this.createdAt,
    this.updatedAt,
    this.closureOtp,
    this.otpVerifiedAt,
    this.escalationLevel = 1,
    this.escalatedAt,
    this.vendorPenaltyFlag = false,
    this.vendorPenaltyAmount = 0.0,
    this.studentRating,
    this.studentFeedback,
  });

  bool get isPending => status.toUpperCase() == 'PENDING';
  bool get isAssigned => status.toUpperCase() == 'ASSIGNED';
  bool get isInProgress => status.toUpperCase() == 'IN_PROGRESS';
  bool get isResolved => status.toUpperCase() == 'RESOLVED';
  bool get isClosed => status.toUpperCase() == 'CLOSED';
  bool get isReopened => status.toUpperCase() == 'REOPENED';
  bool get isRejected => status.toUpperCase() == 'REJECTED';

  // Escalation status getters
  bool get isTier2WardenAlert => escalationLevel == 2;
  bool get isTier3DeanSlingshot => escalationLevel == 3;
  bool get hasVendorPenalty => vendorPenaltyFlag;

  // Offline-first sync state getters
  bool get isSynced => syncState.toLowerCase() == 'synced';
  bool get isSyncPending => syncState.toLowerCase() == 'pending';
  bool get isSyncFailed => syncState.toLowerCase() == 'failed';

  factory ComplaintModel.fromMap(Map<String, dynamic> map, [String? id]) {
    final serverId = map['serverId']?.toString() ?? map['id']?.toString();
    final localId = map['localId']?.toString() ?? (id != null && id != serverId ? id : null);
    final effectiveId = (serverId != null && serverId.isNotEmpty && !serverId.startsWith('cached_'))
        ? serverId
        : (id ?? map['id'] ?? localId ?? '');
    return ComplaintModel(
      id: effectiveId,
      localId: localId,
      serverId: serverId,
      idempotencyKey: map['idempotencyKey']?.toString() ?? map['idempotency_key']?.toString(),
      syncState: map['syncState']?.toString() ?? 'synced',
      studentId: map['studentId'] ?? '',
      category: map['category'] ?? 'General',
      title: map['title'] ?? '',
      description: map['description'] ?? '',
      location: map['location'] ?? 'Campus',
      priority: (map['priority'] ?? 'MEDIUM').toString().toUpperCase(),
      status: (map['status'] ?? 'PENDING').toString().toUpperCase(),
      isRepeat: map['isRepeat'] == true,
      assignedTo: map['assignedTo'],
      assignedToName: map['assignedToName'],
      resolutionRemarks: map['resolutionRemarks'] ?? map['resolutionNotes'],
      resolvedAt: map['resolvedAt'] != null
          ? DateTime.tryParse(map['resolvedAt'])
          : null,
      createdAt: map['createdAt'] != null
          ? DateTime.tryParse(map['createdAt']) ?? DateTime.now()
          : DateTime.now(),
      updatedAt: map['updatedAt'] != null
          ? DateTime.tryParse(map['updatedAt'])
          : null,
      closureOtp: map['closureOtp']?.toString() ?? map['closure_otp']?.toString() ?? map['closurePin']?.toString(),
      otpVerifiedAt: (map['otpVerifiedAt'] ?? map['otp_verified_at']) != null
          ? DateTime.tryParse((map['otpVerifiedAt'] ?? map['otp_verified_at']).toString())
          : null,
      escalationLevel: (map['escalationLevel'] is int)
          ? map['escalationLevel']
          : int.tryParse(map['escalationLevel']?.toString() ?? '1') ?? 1,
      escalatedAt: map['escalatedAt'] != null
          ? DateTime.tryParse(map['escalatedAt'])
          : null,
      vendorPenaltyFlag: map['vendorPenaltyFlag'] == true,
      vendorPenaltyAmount: (map['vendorPenaltyAmount'] is num)
          ? (map['vendorPenaltyAmount'] as num).toDouble()
          : double.tryParse(map['vendorPenaltyAmount']?.toString() ?? '0.0') ?? 0.0,
      studentRating: map['studentRating'] is int
          ? map['studentRating']
          : int.tryParse(map['studentRating']?.toString() ?? ''),
      studentFeedback: map['studentFeedback']?.toString(),
    );
  }

  factory ComplaintModel.fromLocal(LocalComplaint local) {
    return ComplaintModel(
      id: local.serverId ?? local.localId,
      localId: local.localId,
      serverId: local.serverId,
      idempotencyKey: local.idempotencyKey,
      syncState: local.syncState,
      studentId: local.studentId,
      category: local.category,
      title: local.title,
      description: local.description,
      location: local.location,
      priority: local.priority,
      status: local.status,
      isRepeat: local.isRepeat,
      assignedTo: local.assignedTo,
      assignedToName: local.assignedToName,
      resolutionRemarks: local.resolutionRemarks,
      resolvedAt: local.resolvedAt,
      createdAt: local.createdAt,
      updatedAt: local.updatedAt,
    );
  }

  ComplaintModel copyWith({
    String? id,
    String? localId,
    String? serverId,
    String? idempotencyKey,
    String? syncState,
    String? studentId,
    String? category,
    String? title,
    String? description,
    String? location,
    String? priority,
    String? status,
    bool? isRepeat,
    String? assignedTo,
    String? assignedToName,
    String? resolutionRemarks,
    DateTime? resolvedAt,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? closureOtp,
    DateTime? otpVerifiedAt,
    int? escalationLevel,
    DateTime? escalatedAt,
    bool? vendorPenaltyFlag,
    double? vendorPenaltyAmount,
    int? studentRating,
    String? studentFeedback,
  }) {
    return ComplaintModel(
      id: id ?? this.id,
      localId: localId ?? this.localId,
      serverId: serverId ?? this.serverId,
      idempotencyKey: idempotencyKey ?? this.idempotencyKey,
      syncState: syncState ?? this.syncState,
      studentId: studentId ?? this.studentId,
      category: category ?? this.category,
      title: title ?? this.title,
      description: description ?? this.description,
      location: location ?? this.location,
      priority: priority ?? this.priority,
      status: status ?? this.status,
      isRepeat: isRepeat ?? this.isRepeat,
      assignedTo: assignedTo ?? this.assignedTo,
      assignedToName: assignedToName ?? this.assignedToName,
      resolutionRemarks: resolutionRemarks ?? this.resolutionRemarks,
      resolvedAt: resolvedAt ?? this.resolvedAt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      closureOtp: closureOtp ?? this.closureOtp,
      otpVerifiedAt: otpVerifiedAt ?? this.otpVerifiedAt,
      escalationLevel: escalationLevel ?? this.escalationLevel,
      escalatedAt: escalatedAt ?? this.escalatedAt,
      vendorPenaltyFlag: vendorPenaltyFlag ?? this.vendorPenaltyFlag,
      vendorPenaltyAmount: vendorPenaltyAmount ?? this.vendorPenaltyAmount,
      studentRating: studentRating ?? this.studentRating,
      studentFeedback: studentFeedback ?? this.studentFeedback,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'localId': localId,
      'serverId': serverId,
      'idempotencyKey': idempotencyKey,
      'syncState': syncState,
      'studentId': studentId,
      'category': category,
      'title': title,
      'description': description,
      'location': location,
      'priority': priority,
      'status': status,
      'isRepeat': isRepeat,
      'assignedTo': assignedTo,
      'assignedToName': assignedToName,
      'resolutionRemarks': resolutionRemarks,
      'resolvedAt': resolvedAt?.toIso8601String(),
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
      'closureOtp': closureOtp,
      'otpVerifiedAt': otpVerifiedAt?.toIso8601String(),
      'escalationLevel': escalationLevel,
      'escalatedAt': escalatedAt?.toIso8601String(),
      'vendorPenaltyFlag': vendorPenaltyFlag,
      'vendorPenaltyAmount': vendorPenaltyAmount,
      'studentRating': studentRating,
      'studentFeedback': studentFeedback,
    };
  }
}

