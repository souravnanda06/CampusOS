class AttendanceModel {
  final String id;
  final String userId;
  final String studentName;
  final String sessionId;
  final String sessionName;
  final DateTime checkInTime;
  final String location;
  final String status;
  final bool couponEarned;
  final double? distanceMeters;
  final double? latitude;
  final double? longitude;

  AttendanceModel({
    required this.id,
    required this.userId,
    required this.studentName,
    required this.sessionId,
    required this.sessionName,
    required this.checkInTime,
    required this.location,
    required this.status,
    this.couponEarned = false,
    this.distanceMeters,
    this.latitude,
    this.longitude,
  });

  factory AttendanceModel.fromMap(Map<String, dynamic> map, String id) {
    return AttendanceModel(
      id: id,
      userId: map['userId'] ?? '',
      studentName: map['studentName'] ?? '',
      sessionId: map['sessionId'] ?? '',
      sessionName: map['sessionName'] ?? '',
      checkInTime: DateTime.parse(
        map['checkInTime'] ?? DateTime.now().toIso8601String(),
      ),
      location: map['location'] ?? '',
      status: map['status'] ?? 'present',
      couponEarned: map['couponEarned'] ?? false,
      distanceMeters: map['distanceMeters'] != null ? (map['distanceMeters'] as num).toDouble() : null,
      latitude: map['latitude'] != null ? (map['latitude'] as num).toDouble() : null,
      longitude: map['longitude'] != null ? (map['longitude'] as num).toDouble() : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'studentName': studentName,
      'sessionId': sessionId,
      'sessionName': sessionName,
      'checkInTime': checkInTime.toIso8601String(),
      'location': location,
      'status': status,
      'couponEarned': couponEarned,
      if (distanceMeters != null) 'distanceMeters': distanceMeters,
      if (latitude != null) 'latitude': latitude,
      if (longitude != null) 'longitude': longitude,
    };
  }
}
