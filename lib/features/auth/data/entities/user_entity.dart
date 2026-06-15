enum UserRole { student, mentor }

/// Represents the Authenticated User in the domain layer.
class UserEntity {
  final String id;
  final String email;
  final String firstName;
  final String lastName;
  final String? token;
  final String? refreshToken;
  final String? phone;
  final String? avatarUrl;
  final String? city;
  final UserRole? role;
  final bool? emailVerified;
  final bool? phoneVerified;

  const UserEntity({
    required this.id,
    required this.email,
    required this.firstName,
    required this.lastName,
    this.token,
    this.refreshToken,
    this.phone,
    this.avatarUrl,
    this.city,
    this.role,
    this.emailVerified,
    this.phoneVerified,
  });

  /// Helper to get full name
  String get fullName => '$firstName $lastName'.trim();

  /// Returns `true` if the user's role is MENTOR.
  bool get isMentor => role == UserRole.mentor;

  /// Returns `true` if the user's role is STUDENT.
  bool get isStudent => role == UserRole.student;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is UserEntity &&
          id == other.id &&
          email == other.email &&
          firstName == other.firstName &&
          lastName == other.lastName &&
          token == other.token &&
          refreshToken == other.refreshToken &&
          phone == other.phone &&
          avatarUrl == other.avatarUrl &&
          city == other.city &&
          role == other.role &&
          emailVerified == other.emailVerified &&
          phoneVerified == other.phoneVerified;

  @override
  int get hashCode =>
      Object.hash(
        id,
        email,
        firstName,
        lastName,
        token,
        refreshToken,
        phone,
        avatarUrl,
        city,
        role,
        emailVerified,
        phoneVerified,
      );
}
