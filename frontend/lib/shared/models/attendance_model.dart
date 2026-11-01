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
    };
  }
}
