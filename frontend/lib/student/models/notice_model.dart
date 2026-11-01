import 'package:intl/intl.dart';

class NoticeModel {
  final String id;
  final String title;
  final String body;
  final String? createdBy;
  final String? publishedBy;
  final String priority;
  final String category;
  final String targetType;
  final String? targetValue;
  final String? targetRole;
  final String? targetCourse;
  final String? targetBranch;
  final String? targetYear;
  final String? actionType;
  final dynamic actionPayload;
  final String status;
  final DateTime? expiresAt;
  final DateTime createdAt;
  final bool isRead;
  final String? deliveryStatus;
  final DateTime? deliveredAt;
  final DateTime? readAt;
  final DateTime? actionAt;
  final int totalDeliveries;
  final int readDeliveries;
  final int recipientCount;
  NoticeModel({
    required this.id,
    required this.title,
    required this.body,
    this.createdBy,
    this.publishedBy,
    required this.priority,
    required this.category,
    required this.targetType,
    this.targetValue,
    this.targetRole,
    this.targetCourse,
    this.targetBranch,
    this.targetYear,
    this.actionType,
    this.actionPayload,
    required this.status,
    this.expiresAt,
    required this.createdAt,
    this.isRead = false,
    this.deliveryStatus,
    this.deliveredAt,
    this.readAt,
    this.actionAt,
    this.totalDeliveries = 0,
    this.readDeliveries = 0,
    this.recipientCount = 0,
  });

  bool get isUrgent => priority.toUpperCase() == 'URGENT';
  bool get isHigh => priority.toUpperCase() == 'HIGH';
  bool get isNormal => priority.toUpperCase() == 'NORMAL';

  bool get isPublished => status.toUpperCase() == 'PUBLISHED';
  bool get isArchived => status.toUpperCase() == 'ARCHIVED';
  bool get isDraft => status.toUpperCase() == 'DRAFT';

  bool get hasAction => actionType != null && actionType!.trim().isNotEmpty && actionType!.toUpperCase() != 'NONE';
  bool get isOpenUrlAction => actionType?.toUpperCase() == 'OPEN_URL';
  bool get isViewComplaintAction => actionType?.toUpperCase() == 'VIEW_COMPLAINT';

  bool get isExpired {
    if (status.toUpperCase() == 'EXPIRED') return true;
    if (expiresAt != null && DateTime.now().isAfter(expiresAt!)) return true;
    return false;
  }

  String get relativeTime {
    final now = DateTime.now();
    final difference = now.difference(createdAt);

    if (difference.inDays > 7) {
      return DateFormat('MMM dd, yyyy').format(createdAt);
    } else if (difference.inDays >= 1) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours >= 1) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes >= 1) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }

  factory NoticeModel.fromMap(Map<String, dynamic> map, [String? id]) {
    // Defensive body / content extraction
    final rawBody = map['body'] ?? map['content'] ?? '';

    DateTime parsedCreatedAt;
    try {
      final rawCreated = map['createdAt'] ?? map['created_at'];
      parsedCreatedAt = rawCreated != null ? DateTime.parse(rawCreated.toString()) : DateTime.now();
    } catch (_) {
      parsedCreatedAt = DateTime.now();
    }

    DateTime? parsedExpiresAt;
    try {
      final rawExpires = map['expiresAt'] ?? map['expires_at'];
      if (rawExpires != null && rawExpires.toString().trim().isNotEmpty) {
        parsedExpiresAt = DateTime.parse(rawExpires.toString());
      }
    } catch (_) {
      parsedExpiresAt = null;
    }

    DateTime? parsedDeliveredAt;
    try {
      final rawDelivered = map['deliveredAt'] ?? map['delivered_at'];
      if (rawDelivered != null) parsedDeliveredAt = DateTime.parse(rawDelivered.toString());
    } catch (_) {
      parsedDeliveredAt = null;
    }

    DateTime? parsedReadAt;
    try {
      final rawRead = map['readAt'] ?? map['read_at'];
      if (rawRead != null) parsedReadAt = DateTime.parse(rawRead.toString());
    } catch (_) {
      parsedReadAt = null;
    }

    DateTime? parsedActionAt;
    try {
      final rawAction = map['actionAt'] ?? map['action_at'];
      if (rawAction != null) parsedActionAt = DateTime.parse(rawAction.toString());
    } catch (_) {
      parsedActionAt = null;
    }

    final readFlag = map['isRead'] == true ||
        map['is_read'] == true ||
        (map['deliveryStatus'] != null && map['deliveryStatus'].toString().toUpperCase() == 'READ') ||
        (map['status'] != null && map['status'].toString().toUpperCase() == 'READ');

    return NoticeModel(
      id: id ?? map['id']?.toString() ?? '',
      title: (map['title'] ?? '').toString().trim(),
      body: rawBody.toString().trim(),
      createdBy: map['createdBy'] ?? map['created_by'] ?? map['publishedBy'] ?? map['published_by'],
      publishedBy: map['publishedBy'] ?? map['published_by'] ?? map['createdBy'] ?? map['created_by'],
      priority: (map['priority'] ?? 'NORMAL').toString().toUpperCase().trim(),
      category: (map['category'] ?? 'GENERAL').toString().toUpperCase().trim(),
      targetType: (map['targetType'] ?? map['target_type'] ?? 'ALL').toString().toUpperCase().trim(),
      targetValue: map['targetValue'] ?? map['target_value'],
      targetRole: map['targetRole'] ?? map['target_role'],
      targetCourse: map['targetCourse'] ?? map['target_course'],
      targetBranch: map['targetBranch'] ?? map['target_branch'],
      targetYear: map['targetYear'] ?? map['target_year'],
      actionType: map['actionType'] ?? map['action_type'],
      actionPayload: map['actionPayload'] ?? map['action_payload'],
      status: (map['status'] ?? 'PUBLISHED').toString().toUpperCase().trim(),
      expiresAt: parsedExpiresAt,
      createdAt: parsedCreatedAt,
      isRead: readFlag,
      deliveryStatus: map['deliveryStatus'] ?? map['delivery_status'],
      deliveredAt: parsedDeliveredAt,
      readAt: parsedReadAt,
      actionAt: parsedActionAt,
      totalDeliveries: map['totalDeliveries'] ?? 0,
      readDeliveries: map['readDeliveries'] ?? 0,
      recipientCount: map['recipientCount'] ?? 0,
    );
  }

  NoticeModel copyWith({
    bool? isRead,
    DateTime? readAt,
    String? deliveryStatus,
  }) {
    return NoticeModel(
      id: id,
      title: title,
      body: body,
      createdBy: createdBy,
      publishedBy: publishedBy,
      priority: priority,
      category: category,
      targetType: targetType,
      targetValue: targetValue,
      targetRole: targetRole,
      targetCourse: targetCourse,
      targetBranch: targetBranch,
      targetYear: targetYear,
      actionType: actionType,
      actionPayload: actionPayload,
      status: status,
      expiresAt: expiresAt,
      createdAt: createdAt,
      isRead: isRead ?? this.isRead,
      deliveryStatus: deliveryStatus ?? this.deliveryStatus,
      deliveredAt: deliveredAt,
      readAt: readAt ?? this.readAt,
      actionAt: actionAt,
      totalDeliveries: totalDeliveries,
      readDeliveries: readDeliveries,
      recipientCount: recipientCount,
    );
  }
}
