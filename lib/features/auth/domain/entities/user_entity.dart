class UserEntity {
  final String uid;
  final String fullName;
  final String email;
  final String role;
  final String? photoUrl;
  final bool isEmailVerified;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isActive;
  final String? mobile;
  final String? address;
  final String? emergencyContact;
  final String? prn;
  final String? collegeId;
  final String? department;
  final String? course;
  final String? year;
  final String? semester;

  const UserEntity({
    required this.uid,
    required this.fullName,
    required this.email,
    required this.role,
    this.photoUrl,
    required this.isEmailVerified,
    required this.createdAt,
    required this.updatedAt,
    this.isActive = true,
    this.mobile,
    this.address,
    this.emergencyContact,
    this.prn,
    this.collegeId,
    this.department,
    this.course,
    this.year,
    this.semester,
  });

  /// Canonical role normalization helper.
  /// Maps case-insensitive variants (e.g. 'admin', 'administrator', 'staff', 'student')
  /// to the application's canonical role strings ('Admin', 'Staff', 'Engineering Student', etc.).
  static String normalizeRole(String? raw) {
    if (raw == null) return '';
    final trimmed = raw.trim();
    final lower = trimmed.toLowerCase();
    if (lower == 'admin' || lower == 'administrator') return 'Admin';
    if (lower == 'staff') return 'Staff';
    if (lower == 'engineering student' || lower == 'engineering') return 'Engineering Student';
    if (lower == 'bca student' || lower == 'bca') return 'BCA Student';
    if (lower == 'mca student' || lower == 'mca') return 'MCA Student';
    if (lower == 'student') return 'Engineering Student';
    return trimmed;
  }

  /// Checks whether a given role string belongs to an eligible student.
  static bool isStudentRole(String? role) {
    if (role == null || role.trim().isEmpty) return false;
    final lower = role.trim().toLowerCase();
    if (lower == 'admin' ||
        lower == 'administrator' ||
        lower == 'staff' ||
        lower == 'driver' ||
        lower == 'conductor' ||
        lower == 'operator') {
      return false;
    }
    final normalized = normalizeRole(role);
    if (normalized == 'Engineering Student' ||
        normalized == 'BCA Student' ||
        normalized == 'MCA Student') {
      return true;
    }
    return lower.contains('student');
  }

  /// Determines whether a Firestore user record represents an eligible student.
  static bool isStudentUser(Map<String, dynamic> data) {
    final role = data['role']?.toString().trim().toLowerCase() ?? '';
    // 1. Explicitly reject known non-student roles
    if (role == 'admin' ||
        role == 'administrator' ||
        role == 'staff' ||
        role == 'driver' ||
        role == 'conductor' ||
        role == 'operator') {
      return false;
    }

    // 2. Reject admin emails
    final email = data['email']?.toString().trim().toLowerCase() ?? '';
    if (email.startsWith('admin@') || email == 'admin@gmail.com') {
      return false;
    }

    // 3. Positively identify student roles
    if (isStudentRole(data['role']?.toString())) {
      return true;
    }

    // 4. Academic attributes indicative of student profiles
    final prn = data['prn']?.toString().trim() ?? '';
    final collegeId = data['collegeId']?.toString().trim() ?? '';
    final course = data['course']?.toString().trim() ?? '';
    if (prn.isNotEmpty || collegeId.isNotEmpty || course.isNotEmpty) {
      return true;
    }

    // 5. Default fallback: only consider student if not admin/staff/driver
    return role.isEmpty || role.contains('student');
  }
}
