class UserModel {
  final String id;
  final String email;
  final String name;
  final String role;
  final String? registrationNumber;
  final String? course;
  final String? branch;
  final String? year;
  final String? deviceId;
  
  // --- ADDED THIS FIELD ---
  double? attendancePercentage; 

  UserModel({
    required this.id,
    required this.email,
    required this.name,
    required this.role,
    this.registrationNumber,
    this.course,
    this.branch,
    this.year,
    this.deviceId,
    this.attendancePercentage, // Optional in constructor
  });

  // Alias 'id' as 'uid' for compatibility
  String get uid => id;

  factory UserModel.fromMap(Map<String, dynamic> map) {
    return UserModel(
      id: map['id'] ?? '',
      email: map['email'] ?? '',
      name: map['name'] ?? '',
      role: map['role'] ?? 'student',
      registrationNumber: map['registrationNumber'],
      course: map['course'],
      branch: map['branch'],
      year: map['year'],
      deviceId: map['deviceId'],
      // We don't map attendancePercentage here usually, 
      // as it comes from a separate calculation, but we allow it to be set later.
    );
  }

  factory UserModel.fromJson(Map<String, dynamic> json) => UserModel.fromMap(json);
}
