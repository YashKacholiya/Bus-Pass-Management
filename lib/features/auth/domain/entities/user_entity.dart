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
}
