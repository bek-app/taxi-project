import 'app_role.dart';

class AuthSession {
  const AuthSession({
    required this.token,
    required this.userId,
    required this.email,
    required this.role,
  });

  final String token;
  final String userId;
  final String email;
  final AppRole role;

  AuthSession copyWith({
    String? token,
    String? userId,
    String? email,
    AppRole? role,
  }) {
    return AuthSession(
      token: token ?? this.token,
      userId: userId ?? this.userId,
      email: email ?? this.email,
      role: role ?? this.role,
    );
  }
}
