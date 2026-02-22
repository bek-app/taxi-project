import 'app_role.dart';

class UserProfile {
  const UserProfile({
    required this.id,
    required this.email,
    required this.role,
  });

  final String id;
  final String email;
  final AppRole role;

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      id: (json['id'] ?? '').toString(),
      email: (json['email'] ?? '').toString(),
      role: AppRoleX.fromBackend((json['role'] ?? 'CLIENT').toString()),
    );
  }
}
