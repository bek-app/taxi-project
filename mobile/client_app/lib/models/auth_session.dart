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
}
