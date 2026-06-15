class UserModel {
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

  String get fullName => '$firstName $lastName'.trim();
  bool get isMentor => role == UserRole.mentor;
  bool get isStudent => role == UserRole.student;

  const UserModel({
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

  factory UserModel.fromJson(
    Map<String, dynamic> json, {
    String? token,
    String? refreshToken,
  }) {
    final rawId = json['_id'] ?? json['id']?.toString() ?? '';
    return UserModel(
      id: rawId.toString(),
      email: json['email'] ?? '',
      firstName: json['first_name'] ?? '',
      lastName: json['last_name'] ?? '',
      token: token ?? json['token'],
      refreshToken: refreshToken ?? json['refreshToken'],
      phone: json['phone'],
      avatarUrl: json['avatar_url'],
      city: json['city'],
      role: json['role'] is int
          ? (json['role'] == 1 ? UserRole.mentor : UserRole.student)
          : json['role'] is String
          ? (json['role'] == 'MENTOR' ? UserRole.mentor : UserRole.student)
          : null,
      emailVerified: json['email_verified'],
      phoneVerified: json['phone_verified'],
    );
  }

  UserModel copyWith({
    String? id,
    String? email,
    String? firstName,
    String? lastName,
    String? token,
    String? refreshToken,
    String? phone,
    String? avatarUrl,
    String? city,
    UserRole? role,
    bool? emailVerified,
    bool? phoneVerified,
  }) {
    return UserModel(
      id: id ?? this.id,
      email: email ?? this.email,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      token: token ?? this.token,
      refreshToken: refreshToken ?? this.refreshToken,
      phone: phone ?? this.phone,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      city: city ?? this.city,
      role: role ?? this.role,
      emailVerified: emailVerified ?? this.emailVerified,
      phoneVerified: phoneVerified ?? this.phoneVerified,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      '_id': id,
      'email': email,
      'first_name': firstName,
      'last_name': lastName,
      'token': token,
      'refreshToken': refreshToken,
      'phone': phone,
      'avatar_url': avatarUrl,
      'city': city,
      'role': role?.name.toUpperCase(),
      'email_verified': emailVerified,
      'phone_verified': phoneVerified,
    };
  }
}

enum UserRole { student, mentor }
