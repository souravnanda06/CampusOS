class SessionModel {
  final String id;
  final String name;
  final String instructorName;
  final String? course;
  final String? branch;
  final String? year;
  final DateTime startTime;
  final DateTime endTime;
  final String location;
  final bool isActive;
  final int attendanceCount;
  final int? txPowerLevel; // Stores the range setting (0=Short, 1=Medium, etc.)
  final double? latitude;
  final double? longitude;
  final double? radiusMeters;

  SessionModel({
    required this.id,
    required this.name,
    required this.instructorName,
    this.course,
    this.branch,
    this.year,
    required this.startTime,
    required this.endTime,
    required this.location,
    required this.isActive,
    this.attendanceCount = 0,
    this.txPowerLevel,
    this.latitude,
    this.longitude,
    this.radiusMeters = 20.0,
  });

  factory SessionModel.fromMap(Map<String, dynamic> map, String id) {
    double? parseCoord(dynamic val) {
      if (val == null) return null;
      if (val is num) return val.toDouble();
      return double.tryParse(val.toString());
    }

    return SessionModel(
      id: id,
      name: map['name'] ?? '',
      instructorName: map['instructorName'] ?? '',
      course: map['course'],
      branch: map['branch'],
      year: map['year'],
      startTime:
          DateTime.parse(map['startTime'] ?? DateTime.now().toIso8601String()),
      endTime:
          DateTime.parse(map['endTime'] ?? DateTime.now().toIso8601String()),
      location: map['location'] ?? '',
      isActive: map['isActive'] ?? false,
      attendanceCount: map['attendanceCount'] ?? 0,
      latitude: parseCoord(map['latitude']),
      longitude: parseCoord(map['longitude']),
      radiusMeters: parseCoord(map['radiusMeters']) ?? 20.0,
      // We don't strictly need to map txPowerLevel from DB for this local feature,
      // but we keep it in the model for passing data between screens.
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'instructorName': instructorName,
      'course': course,
      'branch': branch,
      'year': year,
      'startTime': startTime.toIso8601String(),
      'endTime': endTime.toIso8601String(),
      'location': location,
      'isActive': isActive,
      'attendanceCount': attendanceCount,
      if (latitude != null) 'latitude': latitude,
      if (longitude != null) 'longitude': longitude,
      if (radiusMeters != null) 'radiusMeters': radiusMeters,
    };
  }
}
