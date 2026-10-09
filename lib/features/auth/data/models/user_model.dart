import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:icem_bus/features/auth/domain/entities/user_entity.dart';

class UserModel extends UserEntity {
  const UserModel({
    required super.uid,
    required super.fullName,
    required super.email,
    required super.role,
    super.photoUrl,
    required super.isEmailVerified,
    required super.createdAt,
    required super.updatedAt,
    super.isActive = true,
    super.mobile,
    super.address,
    super.emergencyContact,
    super.prn,
    super.collegeId,
    super.department,
    super.course,
    super.year,
    super.semester,
  });

  /// Convert a Firestore Document Snapshot Map into a UserModel
  factory UserModel.fromMap(Map<String, dynamic> map) {
    return UserModel(
      uid: map['uid'] as String? ?? '',
      fullName: map['fullName'] as String? ?? '',
      email: map['email'] as String? ?? '',
      role: UserEntity.normalizeRole(map['role'] as String?),
      photoUrl: map['photoUrl'] as String?,
      isEmailVerified: map['isEmailVerified'] as bool? ?? false,
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (map['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      isActive: map['isActive'] as bool? ?? true,
      mobile: map['mobile'] as String?,
      address: map['address'] as String?,
      emergencyContact: map['emergencyContact'] as String?,
      prn: map['prn'] as String?,
      collegeId: map['collegeId'] as String?,
      department: map['department'] as String?,
      course: map['course'] as String?,
      year: map['year'] as String?,
      semester: map['semester'] as String?,
    );
  }

  /// Convert this UserModel into a Firestore Map
  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'fullName': fullName,
      'email': email,
      'role': role,
      'photoUrl': photoUrl,
      'isEmailVerified': isEmailVerified,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
      'isActive': isActive,
      'mobile': mobile,
      'address': address,
      'emergencyContact': emergencyContact,
      'prn': prn,
      'collegeId': collegeId,
      'department': department,
      'course': course,
      'year': year,
      'semester': semester,
    };
  }

  /// Create a copy of this UserModel with modified fields
  UserModel copyWith({
    String? uid,
    String? fullName,
    String? email,
    String? role,
    String? photoUrl,
    bool? isEmailVerified,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isActive,
    String? mobile,
    String? address,
    String? emergencyContact,
    String? prn,
    String? collegeId,
    String? department,
    String? course,
    String? year,
    String? semester,
  }) {
    return UserModel(
      uid: uid ?? this.uid,
      fullName: fullName ?? this.fullName,
      email: email ?? this.email,
      role: role ?? this.role,
      photoUrl: photoUrl ?? this.photoUrl,
      isEmailVerified: isEmailVerified ?? this.isEmailVerified,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isActive: isActive ?? this.isActive,
      mobile: mobile ?? this.mobile,
      address: address ?? this.address,
      emergencyContact: emergencyContact ?? this.emergencyContact,
      prn: prn ?? this.prn,
      collegeId: collegeId ?? this.collegeId,
      department: department ?? this.department,
      course: course ?? this.course,
      year: year ?? this.year,
      semester: semester ?? this.semester,
    );
  }
}
