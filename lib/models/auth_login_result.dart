class AuthLoginResult {
  final String? emailError;
  final String? passwordError;

  const AuthLoginResult({
    this.emailError,
    this.passwordError,
  });
}
