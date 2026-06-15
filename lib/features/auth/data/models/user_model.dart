import '../../data/entities/user_entity.dart';

class UserModel extends UserEntity {
  const UserModel({
    required super.id,
    required super.email,
    required super.firstName,
    required super.lastName,
    super.token,
    super.refreshToken,
    super.phone,
    super.avatarUrl,
    super.city,
    super.role,
    super.emailVerified,
    super.phoneVerified,
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
