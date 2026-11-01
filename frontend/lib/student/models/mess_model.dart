import 'dart:convert';
import 'package:intl/intl.dart';

class MessMenu {
  final String id;
  final String menuDate;
  final String status;
  final String? createdBy;
  final String? updatedBy;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final List<MessMeal> meals;

  MessMenu({
    required this.id,
    required this.menuDate,
    required this.status,
    this.createdBy,
    this.updatedBy,
    this.createdAt,
    this.updatedAt,
    this.meals = const [],
  });

  bool get isDraft => status.toUpperCase() == 'DRAFT';
  bool get isPublished => status.toUpperCase() == 'PUBLISHED';
  bool get isArchived => status.toUpperCase() == 'ARCHIVED';

  DateTime get date => DateTime.tryParse(menuDate) ?? DateTime.now();

  String get formattedDate {
    try {
      final parsed = DateTime.tryParse(menuDate);
      if (parsed != null) {
        return DateFormat('EEEE, d MMMM yyyy').format(parsed);
      }
    } catch (_) {}
    return menuDate;
  }

  factory MessMenu.fromMap(Map<String, dynamic> map, [String? id]) {
    final rawMeals = map['meals'];
    List<MessMeal> parsedMeals = [];
    if (rawMeals is List) {
      parsedMeals = rawMeals
          .whereType<Map<String, dynamic>>()
          .map((m) => MessMeal.fromMap(m))
          .toList();
      parsedMeals.sort((a, b) => a.displayOrder.compareTo(b.displayOrder));
    }

    return MessMenu(
      id: id ?? map['id']?.toString() ?? '',
      menuDate: map['menuDate']?.toString() ?? '',
      status: (map['status']?.toString() ?? 'DRAFT').toUpperCase(),
      createdBy: map['createdBy']?.toString(),
      updatedBy: map['updatedBy']?.toString(),
      createdAt: map['createdAt'] != null
          ? DateTime.tryParse(map['createdAt'].toString())
          : null,
      updatedAt: map['updatedAt'] != null
          ? DateTime.tryParse(map['updatedAt'].toString())
          : null,
      meals: parsedMeals,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'menuDate': menuDate,
      'status': status,
      'createdBy': createdBy,
      'updatedBy': updatedBy,
      'createdAt': createdAt?.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
      'meals': meals.map((m) => m.toMap()).toList(),
    };
  }
}

class MessMeal {
  final String id;
  final String menuId;
  final String mealType;
  final String title;
  final String description;
  final List<String> items;
  final String availability;
  final int displayOrder;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  MessMeal({
    required this.id,
    required this.menuId,
    required this.mealType,
    required this.title,
    this.description = '',
    this.items = const [],
    this.availability = 'AVAILABLE',
    this.displayOrder = 1,
    this.createdAt,
    this.updatedAt,
  });

  bool get isBreakfast => mealType.toUpperCase() == 'BREAKFAST';
  bool get isLunch => mealType.toUpperCase() == 'LUNCH';
  bool get isSnacks => mealType.toUpperCase() == 'SNACKS';
  bool get isDinner => mealType.toUpperCase() == 'DINNER';

  bool get isAvailable => availability.toUpperCase() == 'AVAILABLE';
  bool get isLimited => availability.toUpperCase() == 'LIMITED';
  bool get isUnavailable => availability.toUpperCase() == 'UNAVAILABLE';

  factory MessMeal.fromMap(Map<String, dynamic> map, [String? id]) {
    List<String> parsedItems = [];
    final rawItems = map['items'];
    if (rawItems is List) {
      parsedItems = rawItems
          .map((e) => e?.toString().trim() ?? '')
          .where((e) => e.isNotEmpty)
          .toList();
    } else if (rawItems is String) {
      if (rawItems.trim().startsWith('[') && rawItems.trim().endsWith(']')) {
        try {
          final decoded = jsonDecode(rawItems);
          if (decoded is List) {
            parsedItems = decoded
                .map((e) => e?.toString().trim() ?? '')
                .where((e) => e.isNotEmpty)
                .toList();
          }
        } catch (_) {
          parsedItems = rawItems
              .replaceAll('[', '')
              .replaceAll(']', '')
              .replaceAll('"', '')
              .split(',')
              .map((e) => e.trim())
              .where((e) => e.isNotEmpty)
              .toList();
        }
      } else {
        parsedItems = rawItems
            .split(',')
            .map((e) => e.trim())
            .where((e) => e.isNotEmpty)
            .toList();
      }
    }

    final rawType = (map['mealType'] ?? map['meal_type'] ?? 'BREAKFAST')
        .toString()
        .toUpperCase();
    final rawTitle = map['title']?.toString().trim();
    final title = (rawTitle != null && rawTitle.isNotEmpty)
        ? rawTitle
        : (rawType.isNotEmpty
            ? rawType[0] + rawType.substring(1).toLowerCase()
            : 'Meal');

    return MessMeal(
      id: id ?? map['id']?.toString() ?? '',
      menuId: (map['menuId'] ?? map['menu_id'] ?? '').toString(),
      mealType: rawType,
      title: title,
      description: map['description']?.toString() ?? '',
      items: parsedItems,
      availability:
          (map['availability']?.toString() ?? 'AVAILABLE').toUpperCase(),
      displayOrder: int.tryParse(map['displayOrder']?.toString() ??
              map['display_order']?.toString() ??
              '') ??
          1,
      createdAt: map['createdAt'] != null
          ? DateTime.tryParse(map['createdAt'].toString())
          : null,
      updatedAt: map['updatedAt'] != null
          ? DateTime.tryParse(map['updatedAt'].toString())
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'menuId': menuId,
      'mealType': mealType,
      'title': title,
      'description': description,
      'items': items,
      'availability': availability,
      'displayOrder': displayOrder,
      'createdAt': createdAt?.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
    };
  }
}

// ==============================================================================
// --- STEP 22D: MESS FEEDBACK & ANALYTICS MODELS ---
// ==============================================================================

class MessFeedback {
  final String id;
  final String menuId;
  final String mealId;
  final String? studentId;
  final int rating;
  final String? category;
  final String comment;
  final String? mealType;
  final String? mealTitle;
  final String? menuDate;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  MessFeedback({
    required this.id,
    required this.menuId,
    required this.mealId,
    this.studentId,
    required this.rating,
    this.category,
    this.comment = '',
    this.mealType,
    this.mealTitle,
    this.menuDate,
    this.createdAt,
    this.updatedAt,
  });

  String get categoryLabel {
    switch (category?.toUpperCase()) {
      case 'FOOD_QUALITY':
        return 'Food Quality';
      case 'TASTE':
        return 'Taste';
      case 'VARIETY':
        return 'Variety';
      case 'PORTION':
        return 'Portion Size';
      case 'CLEANLINESS':
        return 'Cleanliness';
      case 'TIMING':
        return 'Timing';
      case 'AVAILABILITY':
        return 'Availability';
      case 'OTHER':
        return 'Other';
      default:
        return category ?? 'General';
    }
  }

  factory MessFeedback.fromMap(Map<String, dynamic> map, [String? id]) {
    return MessFeedback(
      id: id ?? map['id']?.toString() ?? '',
      menuId: (map['menuId'] ?? map['menu_id'] ?? '').toString(),
      mealId: (map['mealId'] ?? map['meal_id'] ?? '').toString(),
      studentId: (map['studentId'] ?? map['student_id'])?.toString(),
      rating: int.tryParse(map['rating']?.toString() ?? '') ?? 5,
      category: map['category']?.toString(),
      comment: map['comment']?.toString() ?? '',
      mealType: (map['mealType'] ?? map['meal_type'])?.toString(),
      mealTitle: (map['mealTitle'] ?? map['meal_title'])?.toString(),
      menuDate: (map['menuDate'] ?? map['menu_date'])?.toString(),
      createdAt: map['createdAt'] != null
          ? DateTime.tryParse(map['createdAt'].toString())
          : null,
      updatedAt: map['updatedAt'] != null
          ? DateTime.tryParse(map['updatedAt'].toString())
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'menuId': menuId,
      'mealId': mealId,
      if (studentId != null) 'studentId': studentId,
      'rating': rating,
      'category': category,
      'comment': comment,
      'mealType': mealType,
      'mealTitle': mealTitle,
      'menuDate': menuDate,
      'createdAt': createdAt?.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
    };
  }
}

class MealRatingSummary {
  final int count;
  final double averageRating;

  MealRatingSummary({required this.count, required this.averageRating});

  factory MealRatingSummary.fromMap(Map<String, dynamic> map) {
    return MealRatingSummary(
      count: int.tryParse(map['count']?.toString() ?? '') ?? 0,
      averageRating: (map['averageRating'] is num)
          ? (map['averageRating'] as num).toDouble()
          : 0.0,
    );
  }
}

class FeedbackSummary {
  final int totalRatings;
  final int feedbackCount;
  final double averageRating;
  final int totalComments;
  final Map<int, int> ratingDistribution;
  final Map<String, MealRatingSummary> mealBreakdown;

  FeedbackSummary({
    required this.totalRatings,
    required this.feedbackCount,
    required this.averageRating,
    required this.totalComments,
    required this.ratingDistribution,
    required this.mealBreakdown,
  });

  factory FeedbackSummary.fromMap(Map<String, dynamic> map) {
    final distMap = <int, int>{1: 0, 2: 0, 3: 0, 4: 0, 5: 0};
    if (map['ratingDistribution'] is Map) {
      (map['ratingDistribution'] as Map).forEach((k, v) {
        final star = int.tryParse(k.toString());
        final count = int.tryParse(v.toString()) ?? 0;
        if (star != null && star >= 1 && star <= 5) {
          distMap[star] = count;
        }
      });
    }

    final breakdownMap = <String, MealRatingSummary>{};
    if (map['mealBreakdown'] is Map) {
      (map['mealBreakdown'] as Map).forEach((k, v) {
        if (v is Map<String, dynamic>) {
          breakdownMap[k.toString().toUpperCase()] =
              MealRatingSummary.fromMap(v);
        } else if (v is Map) {
          breakdownMap[k.toString().toUpperCase()] =
              MealRatingSummary.fromMap(Map<String, dynamic>.from(v));
        }
      });
    }

    return FeedbackSummary(
      totalRatings: int.tryParse(map['totalRatings']?.toString() ?? '') ?? 0,
      feedbackCount: int.tryParse(map['feedbackCount']?.toString() ?? '') ?? 0,
      averageRating: (map['averageRating'] is num)
          ? (map['averageRating'] as num).toDouble()
          : 0.0,
      totalComments: int.tryParse(map['totalComments']?.toString() ?? '') ?? 0,
      ratingDistribution: distMap,
      mealBreakdown: breakdownMap,
    );
  }
}

class FeedbackTrend {
  final String date;
  final int ratingCount;
  final double averageRating;
  final Map<String, MealRatingSummary> mealBreakdown;

  FeedbackTrend({
    required this.date,
    required this.ratingCount,
    required this.averageRating,
    required this.mealBreakdown,
  });

  factory FeedbackTrend.fromMap(Map<String, dynamic> map) {
    final breakdownMap = <String, MealRatingSummary>{};
    if (map['mealBreakdown'] is Map) {
      (map['mealBreakdown'] as Map).forEach((k, v) {
        if (v is Map<String, dynamic>) {
          breakdownMap[k.toString().toUpperCase()] =
              MealRatingSummary.fromMap(v);
        } else if (v is Map) {
          breakdownMap[k.toString().toUpperCase()] =
              MealRatingSummary.fromMap(Map<String, dynamic>.from(v));
        }
      });
    }

    return FeedbackTrend(
      date: map['date']?.toString() ?? '',
      ratingCount: int.tryParse(map['ratingCount']?.toString() ?? '') ?? 0,
      averageRating: (map['averageRating'] is num)
          ? (map['averageRating'] as num).toDouble()
          : 0.0,
      mealBreakdown: breakdownMap,
    );
  }
}

class FeedbackCategoryStat {
  final String category;
  final int feedbackCount;
  final double averageRating;
  final int negativeCount;
  final int positiveCount;
  final double negativePercentage;

  FeedbackCategoryStat({
    required this.category,
    required this.feedbackCount,
    required this.averageRating,
    required this.negativeCount,
    required this.positiveCount,
    required this.negativePercentage,
  });

  String get label {
    switch (category.toUpperCase()) {
      case 'FOOD_QUALITY':
        return 'Food Quality';
      case 'TASTE':
        return 'Taste';
      case 'VARIETY':
        return 'Variety';
      case 'PORTION':
        return 'Portion Size';
      case 'CLEANLINESS':
        return 'Cleanliness';
      case 'TIMING':
        return 'Timing';
      case 'AVAILABILITY':
        return 'Availability';
      case 'OTHER':
        return 'Other';
      default:
        return category;
    }
  }

  factory FeedbackCategoryStat.fromMap(Map<String, dynamic> map) {
    return FeedbackCategoryStat(
      category: map['category']?.toString() ?? '',
      feedbackCount: int.tryParse(map['feedbackCount']?.toString() ?? '') ?? 0,
      averageRating: (map['averageRating'] is num)
          ? (map['averageRating'] as num).toDouble()
          : 0.0,
      negativeCount: int.tryParse(map['negativeCount']?.toString() ?? '') ?? 0,
      positiveCount: int.tryParse(map['positiveCount']?.toString() ?? '') ?? 0,
      negativePercentage: (map['negativePercentage'] is num)
          ? (map['negativePercentage'] as num).toDouble()
          : 0.0,
    );
  }
}

class FeedbackSignal {
  final String category;
  final int feedbackCount;
  final double averageRating;
  final int negativeCount;
  final double negativePercentage;
  final bool flagged;
  final String flagReason;

  FeedbackSignal({
    required this.category,
    required this.feedbackCount,
    required this.averageRating,
    required this.negativeCount,
    required this.negativePercentage,
    required this.flagged,
    required this.flagReason,
  });

  String get label {
    switch (category.toUpperCase()) {
      case 'FOOD_QUALITY':
        return 'Food Quality';
      case 'TASTE':
        return 'Taste';
      case 'VARIETY':
        return 'Variety';
      case 'PORTION':
        return 'Portion Size';
      case 'CLEANLINESS':
        return 'Cleanliness';
      case 'TIMING':
        return 'Timing';
      case 'AVAILABILITY':
        return 'Availability';
      case 'OTHER':
        return 'Other';
      default:
        return category;
    }
  }

  factory FeedbackSignal.fromMap(Map<String, dynamic> map) {
    return FeedbackSignal(
      category: map['category']?.toString() ?? '',
      feedbackCount: int.tryParse(map['feedbackCount']?.toString() ?? '') ?? 0,
      averageRating: (map['averageRating'] is num)
          ? (map['averageRating'] as num).toDouble()
          : 0.0,
      negativeCount: int.tryParse(map['negativeCount']?.toString() ?? '') ?? 0,
      negativePercentage: (map['negativePercentage'] is num)
          ? (map['negativePercentage'] as num).toDouble()
          : 0.0,
      flagged: map['flagged'] == true,
      flagReason: map['flagReason']?.toString() ?? '',
    );
  }
}

class FeedbackCommentItem {
  final String id;
  final String menuDate;
  final String mealType;
  final String mealTitle;
  final int rating;
  final String? category;
  final String comment;
  final DateTime? createdAt;

  FeedbackCommentItem({
    required this.id,
    required this.menuDate,
    required this.mealType,
    required this.mealTitle,
    required this.rating,
    this.category,
    required this.comment,
    this.createdAt,
  });

  factory FeedbackCommentItem.fromMap(Map<String, dynamic> map) {
    return FeedbackCommentItem(
      id: map['id']?.toString() ?? '',
      menuDate: map['menuDate']?.toString() ?? '',
      mealType: map['mealType']?.toString() ?? 'MEAL',
      mealTitle: map['mealTitle']?.toString() ?? 'Meal',
      rating: int.tryParse(map['rating']?.toString() ?? '') ?? 5,
      category: map['category']?.toString(),
      comment: map['comment']?.toString() ?? '',
      createdAt: map['createdAt'] != null
          ? DateTime.tryParse(map['createdAt'].toString())
          : null,
    );
  }
}

// =============================================================================
// --- MESS STAFF VERIFICATION, BATCH & OPERATIONAL MODELS ---
// =============================================================================

enum BatchSessionState {
  batchIdle,
  batchStarting,
  batchActive,
  batchProcessing,
  batchCompleted,
  batchUnavailable,
  batchFailed,
  qrFallback,
}

enum MealVerificationStatus {
  verified,
  alreadyUsed,
  invalid,
  notEligible,
  offlineVerified,
}

class MealEntryRecord {
  final String id;
  final String? menuId;
  final String? mealId;
  final String mealType;
  final String entryDate;
  final String studentId;
  final String studentName;
  final String? registrationNumber;
  final String verifiedBy;
  final String verificationMode; // 'BATCH' or 'QR_FALLBACK'
  final String? idempotencyKey;
  final String? deviceKeyId;
  final String? responseNonce;
  final String status;
  final DateTime? createdAt;
  final bool isOffline;

  MealEntryRecord({
    required this.id,
    this.menuId,
    this.mealId,
    required this.mealType,
    required this.entryDate,
    required this.studentId,
    required this.studentName,
    this.registrationNumber,
    required this.verifiedBy,
    this.verificationMode = 'BATCH',
    this.idempotencyKey,
    this.deviceKeyId,
    this.responseNonce,
    this.status = 'VERIFIED',
    this.createdAt,
    this.isOffline = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'menuId': menuId,
      'mealId': mealId,
      'mealType': mealType,
      'entryDate': entryDate,
      'studentId': studentId,
      'studentName': studentName,
      'registrationNumber': registrationNumber,
      'verifiedBy': verifiedBy,
      'verificationMode': verificationMode,
      'idempotencyKey': idempotencyKey,
      'deviceKeyId': deviceKeyId,
      'responseNonce': responseNonce,
      'status': status,
      'createdAt': createdAt?.toIso8601String(),
      'isOffline': isOffline,
    };
  }

  factory MealEntryRecord.fromMap(Map<String, dynamic> map) {
    return MealEntryRecord(
      id: map['id']?.toString() ?? '',
      menuId: map['menuId']?.toString(),
      mealId: map['mealId']?.toString(),
      mealType: map['mealType']?.toString() ?? 'LUNCH',
      entryDate: map['entryDate']?.toString() ?? '',
      studentId: map['studentId']?.toString() ?? '',
      studentName: map['studentName']?.toString() ?? 'Student',
      registrationNumber: map['registrationNumber']?.toString(),
      verifiedBy: map['verifiedBy']?.toString() ?? '',
      verificationMode: map['verificationMode']?.toString() ?? 'BATCH',
      idempotencyKey: map['idempotencyKey']?.toString(),
      deviceKeyId: map['deviceKeyId']?.toString(),
      responseNonce: map['responseNonce']?.toString(),
      status: map['status']?.toString() ?? 'VERIFIED',
      createdAt: map['createdAt'] != null
          ? DateTime.tryParse(map['createdAt'].toString())
          : null,
      isOffline: map['isOffline'] == true,
    );
  }
}

class MealTypeEntryCounts {
  final int total;
  final int batch;
  final int qr;

  MealTypeEntryCounts({
    this.total = 0,
    this.batch = 0,
    this.qr = 0,
  });

  factory MealTypeEntryCounts.fromMap(Map<String, dynamic>? map) {
    if (map == null) return MealTypeEntryCounts();
    return MealTypeEntryCounts(
      total: int.tryParse(map['total']?.toString() ?? '') ?? 0,
      batch: int.tryParse(map['batch']?.toString() ?? '') ?? 0,
      qr: int.tryParse(map['qr']?.toString() ?? '') ?? 0,
    );
  }
}

class TodayMealStats {
  final String date;
  final String activeMeal;
  final String mealTiming;
  final String menuStatus; // 'PUBLISHED', 'DRAFT', 'NONE'
  final String? todayMenuId;
  final int totalVerifiedToday;
  final Map<String, MealTypeEntryCounts> counts;
  final List<MealEntryRecord> recentEntries;

  TodayMealStats({
    required this.date,
    required this.activeMeal,
    required this.mealTiming,
    required this.menuStatus,
    this.todayMenuId,
    this.totalVerifiedToday = 0,
    required this.counts,
    required this.recentEntries,
  });

  factory TodayMealStats.fromMap(Map<String, dynamic> map) {
    final countsMap = <String, MealTypeEntryCounts>{};
    if (map['counts'] is Map) {
      (map['counts'] as Map).forEach((k, v) {
        if (v is Map<String, dynamic>) {
          countsMap[k.toString().toUpperCase()] = MealTypeEntryCounts.fromMap(v);
        } else if (v is Map) {
          countsMap[k.toString().toUpperCase()] =
              MealTypeEntryCounts.fromMap(Map<String, dynamic>.from(v));
        }
      });
    }

    final recentList = (map['recentEntries'] as List<dynamic>?)
            ?.whereType<Map<String, dynamic>>()
            .map((item) => MealEntryRecord.fromMap(item))
            .toList() ??
        [];

    return TodayMealStats(
      date: map['date']?.toString() ?? '',
      activeMeal: map['activeMeal']?.toString() ?? 'LUNCH',
      mealTiming: map['mealTiming']?.toString() ?? '12:00 PM – 3:00 PM',
      menuStatus: map['menuStatus']?.toString() ?? 'NONE',
      todayMenuId: map['todayMenuId']?.toString(),
      totalVerifiedToday: int.tryParse(map['totalVerifiedToday']?.toString() ?? '') ?? 0,
      counts: countsMap,
      recentEntries: recentList,
    );
  }
}

class MessOperationalAnalytics {
  final int totalEntries;
  final int batchEntries;
  final int qrEntries;
  final int todayEntries;
  final Map<String, int> mealBreakdown;

  MessOperationalAnalytics({
    this.totalEntries = 0,
    this.batchEntries = 0,
    this.qrEntries = 0,
    this.todayEntries = 0,
    required this.mealBreakdown,
  });

  factory MessOperationalAnalytics.fromMap(Map<String, dynamic> map) {
    final mb = <String, int>{};
    if (map['mealBreakdown'] is Map) {
      (map['mealBreakdown'] as Map).forEach((k, v) {
        mb[k.toString().toUpperCase()] = int.tryParse(v?.toString() ?? '') ?? 0;
      });
    }
    return MessOperationalAnalytics(
      totalEntries: int.tryParse(map['totalEntries']?.toString() ?? '') ?? 0,
      batchEntries: int.tryParse(map['batchEntries']?.toString() ?? '') ?? 0,
      qrEntries: int.tryParse(map['qrEntries']?.toString() ?? '') ?? 0,
      todayEntries: int.tryParse(map['todayEntries']?.toString() ?? '') ?? 0,
      mealBreakdown: mb,
    );
  }
}

