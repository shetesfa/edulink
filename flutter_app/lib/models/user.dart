import '../core/api_config.dart';

class AppUser {
  final int id;
  final String firstName;
  final String lastName;
  final String email;
  final String? username;
  final String? profilePhoto;
  final String? coverPhoto;
  final String? bio;
  final String roleName;
  final bool isActive;

  AppUser({
    required this.id,
    required this.firstName,
    required this.lastName,
    required this.email,
    this.username,
    this.profilePhoto,
    this.coverPhoto,
    this.bio,
    required this.roleName,
    required this.isActive,
  });

  String get fullName => '$firstName $lastName'.trim();

  /// Display handle — @username if available, otherwise first part of email
  String get displayUsername {
    if (username != null && username!.isNotEmpty) return '@$username';
    return '@${email.split('@')[0]}';
  }

  String? get fullProfilePhotoUrl => ApiConfig.resolveMediaUrl(profilePhoto);

  String? get fullCoverPhotoUrl => ApiConfig.resolveMediaUrl(coverPhoto);

  factory AppUser.fromJson(Map<String, dynamic> json) {
    String roleStr = 'student';
    if (json['role'] is String) {
      roleStr = json['role'];
    } else if (json['role'] is Map && json['role']['name'] is String) {
      roleStr = json['role']['name'];
    }

    return AppUser(
      id: json['id'] is int ? json['id'] : int.tryParse(json['id']?.toString() ?? '0') ?? 0,
      firstName: json['first_name'] ?? '',
      lastName: json['last_name'] ?? '',
      email: json['email'] ?? '',
      username: json['username'],
      profilePhoto: json['profile_photo'],
      coverPhoto: json['cover_photo'],
      bio: json['bio'],
      roleName: roleStr,
      isActive: json['is_active'] == true || json['is_active'] == 1 || json['is_active'] == '1',
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'first_name': firstName,
        'last_name': lastName,
        'email': email,
        'username': username,
        'profile_photo': profilePhoto,
        'cover_photo': coverPhoto,
        'bio': bio,
        'role': {'name': roleName},
        'is_active': isActive,
      };

  AppUser copyWith({
    String? firstName,
    String? lastName,
    String? email,
    String? username,
    String? profilePhoto,
    String? coverPhoto,
    String? bio,
    String? roleName,
    bool? isActive,
  }) {
    return AppUser(
      id: id,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      email: email ?? this.email,
      username: username ?? this.username,
      profilePhoto: profilePhoto ?? this.profilePhoto,
      coverPhoto: coverPhoto ?? this.coverPhoto,
      bio: bio ?? this.bio,
      roleName: roleName ?? this.roleName,
      isActive: isActive ?? this.isActive,
    );
  }
}
