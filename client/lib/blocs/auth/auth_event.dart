abstract class AuthEvent {}

class CheckAuthStatus extends AuthEvent {}

class LoginRequested extends AuthEvent {
  final String email;
  final String password;

  LoginRequested({required this.email, required this.password});
}

class SignupRequested extends AuthEvent {
  final String email;
  final String password;

  SignupRequested({required this.email, required this.password});
}

class SignupWithGarudIdRequested extends AuthEvent {
  final String email;
  final String password;
  final String garudId;
  final String name;
  final String phoneNumber;
  final bool enableAlerts;

  SignupWithGarudIdRequested({
    required this.email,
    required this.password,
    required this.garudId,
    required this.name,
    required this.phoneNumber,
    required this.enableAlerts,
  });
}

class LogoutRequested extends AuthEvent {}