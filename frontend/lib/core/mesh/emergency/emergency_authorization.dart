import 'emergency_alert.dart';

/// Exception thrown when an unauthorized role attempts to issue an emergency alert
/// or when an issuer attempts to broadcast beyond their permitted institutional scope.
class EmergencyUnauthorizedException implements Exception {
  final String role;
  final String scope;
  final String reason;

  EmergencyUnauthorizedException({
    required this.role,
    required this.scope,
    required this.reason,
  });

  @override
  String toString() =>
      'EmergencyUnauthorizedException: Role "$role" is not authorized for emergency scope "$scope". $reason';
}

/// Evaluator enforcing institutional authority and geographic scope delegation rules
/// for CampusOS Mesh Emergency Disaster Flares.
class EmergencyAuthorization {
  /// Validates whether a given [role] is institutionally authorized to originate
  /// an emergency disaster flare for the specified [scope].
  ///
  /// Rules:
  /// - [STUDENT]: Never authorized to originate any emergency alert.
  /// - [TEACHER] / [FACULTY]: Authorized only for academic/departmental scopes. Never campus-wide.
  /// - [WARDEN]: Authorized only for hostel scopes (e.g. 'hostel', 'hostel:block-b'). Never campus-wide.
  /// - [ADMIN], [DEAN], [DIRECTOR]: Authorized for campus-wide and all subordinate scopes.
  static bool isAuthorizedToOriginate({
    required String role,
    required String scope,
    String? assignedHostel,
    String? assignedDepartment,
  }) {
    final normalizedRole = role.trim().toLowerCase();
    final normalizedScope = scope.trim().toLowerCase();

    if (normalizedRole.isEmpty || normalizedScope.isEmpty) {
      return false;
    }

    // 1. Students are strictly prohibited from originating emergency alerts
    if (normalizedRole == 'student') {
      return false;
    }

    // 2. High-level institutional leadership holds full campus-wide emergency authority
    if (normalizedRole == 'admin' ||
        normalizedRole == 'dean' ||
        normalizedRole == 'director') {
      return true;
    }

    // 3. Wardens may originate hostel emergency alerts
    if (normalizedRole == 'warden') {
      if (normalizedScope == EmergencyScope.campus ||
          normalizedScope == EmergencyScope.academic ||
          normalizedScope == EmergencyScope.administrative) {
        return false;
      }

      if (normalizedScope == EmergencyScope.hostel) {
        return true;
      }

      if (normalizedScope.startsWith('hostel:')) {
        if (assignedHostel != null && assignedHostel.trim().isNotEmpty) {
          final targetBlock = normalizedScope.substring('hostel:'.length).trim();
          final authorizedBlock = assignedHostel.trim().toLowerCase();
          return targetBlock == authorizedBlock || authorizedBlock == 'all';
        }
        return true;
      }

      return false;
    }

    // 4. Faculty / Teachers may originate academic or department-specific emergency alerts
    if (normalizedRole == 'teacher' || normalizedRole == 'faculty') {
      if (normalizedScope == EmergencyScope.campus ||
          normalizedScope == EmergencyScope.hostel ||
          normalizedScope.startsWith('hostel:') ||
          normalizedScope == EmergencyScope.administrative) {
        return false;
      }

      if (normalizedScope == EmergencyScope.academic) {
        return true;
      }

      if (normalizedScope.startsWith('department:')) {
        if (assignedDepartment != null && assignedDepartment.trim().isNotEmpty) {
          final targetDept = normalizedScope.substring('department:'.length).trim();
          final authorizedDept = assignedDepartment.trim().toLowerCase();
          return targetDept == authorizedDept || authorizedDept == 'all';
        }
        return true;
      }

      return false;
    }

    // Any unrecognized role is rejected by default
    return false;
  }

  /// Returns the list of permitted emergency scopes available to an institutional [role].
  static List<String> getAvailableScopesForRole({
    required String role,
    String? assignedHostel,
    String? assignedDepartment,
  }) {
    final normalizedRole = role.trim().toLowerCase();

    if (normalizedRole == 'admin' ||
        normalizedRole == 'dean' ||
        normalizedRole == 'director') {
      return const [
        EmergencyScope.campus,
        EmergencyScope.hostel,
        EmergencyScope.academic,
        EmergencyScope.administrative,
      ];
    }

    if (normalizedRole == 'warden') {
      if (assignedHostel != null && assignedHostel.trim().isNotEmpty) {
        return [
          EmergencyScope.hostel,
          EmergencyScope.hostelBlock(assignedHostel),
        ];
      }
      return const [EmergencyScope.hostel];
    }

    if (normalizedRole == 'teacher' || normalizedRole == 'faculty') {
      if (assignedDepartment != null && assignedDepartment.trim().isNotEmpty) {
        return [
          EmergencyScope.academic,
          EmergencyScope.department(assignedDepartment),
        ];
      }
      return const [EmergencyScope.academic];
    }

    return const [];
  }
}
