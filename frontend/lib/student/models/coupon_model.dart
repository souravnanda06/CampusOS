class CouponModel {
  final String id;
  final String userId;
  final String code;
  final String description;
  final DateTime earnedDate;
  final DateTime expiryDate;
  final bool isUsed;

  CouponModel({
    required this.id,
    required this.userId,
    required this.code,
    required this.description,
    required this.earnedDate,
    required this.expiryDate,
    this.isUsed = false,
  });

  factory CouponModel.fromMap(Map<String, dynamic> map, String id) {
    return CouponModel(
      id: id,
      userId: map['userId'] ?? '',
      code: map['code'] ?? '',
      description: map['description'] ?? '',
      earnedDate: map['earnedDate'] != null
          ? DateTime.tryParse(map['earnedDate']) ?? DateTime.now()
          : DateTime.now(),
      expiryDate: map['expiryDate'] != null
          ? DateTime.tryParse(map['expiryDate']) ?? DateTime.now().add(const Duration(days: 30))
          : DateTime.now().add(const Duration(days: 30)),
      isUsed: map['isUsed'] ?? false,
    );
  }
}
