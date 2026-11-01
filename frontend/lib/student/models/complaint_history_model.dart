class ComplaintHistoryModel {
  final String id;
  final String complaintId;
  final String changedBy;
  final String? actorName;
  final String? actorRole;
  final String? oldStatus;
  final String newStatus;
  final String? remarks;
  final DateTime timestamp;

  ComplaintHistoryModel({
    required this.id,
    required this.complaintId,
    required this.changedBy,
    this.actorName,
    this.actorRole,
    this.oldStatus,
    required this.newStatus,
    this.remarks,
    required this.timestamp,
  });

  factory ComplaintHistoryModel.fromMap(Map<String, dynamic> map) {
    return ComplaintHistoryModel(
      id: map['id'] ?? '',
      complaintId: map['complaintId'] ?? '',
      changedBy: map['changedBy'] ?? '',
      actorName: map['actorName'],
      actorRole: map['actorRole'],
      oldStatus: map['oldStatus'],
      newStatus: (map['newStatus'] ?? '').toString().toUpperCase(),
      remarks: map['remarks'] ?? map['comment'],
      timestamp: map['timestamp'] != null
          ? DateTime.tryParse(map['timestamp']) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'complaintId': complaintId,
      'changedBy': changedBy,
      'actorName': actorName,
      'actorRole': actorRole,
      'oldStatus': oldStatus,
      'newStatus': newStatus,
      'remarks': remarks,
      'timestamp': timestamp.toIso8601String(),
    };
  }
}
