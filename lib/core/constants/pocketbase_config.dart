class PocketBaseConfig {
  static const String _configuredUrl = String.fromEnvironment(
    'POCKETBASE_URL',
    defaultValue: 'http://127.0.0.1:8091',
  );

  static String get baseUrl => _configuredUrl.endsWith('/')
      ? _configuredUrl.substring(0, _configuredUrl.length - 1)
      : _configuredUrl;

  /// Superuser credentials are no longer hardcoded here. Pass them at build
  /// or run time instead, e.g.:
  ///   flutter run --dart-define=PB_SUPERUSER_EMAIL=azmat@pos.com --dart-define=PB_SUPERUSER_PASSWORD=your_new_password
  ///
  /// Add the same flags to your release build command (and to the CI/installer
  /// build step, if any) so the packaged app still has valid credentials to
  /// seed/repair the local superuser on first run.
  static const String superuserEmail = String.fromEnvironment(
    'PB_SUPERUSER_EMAIL',
    defaultValue: '',
  );

  static const String superuserPassword = String.fromEnvironment(
    'PB_SUPERUSER_PASSWORD',
    defaultValue: '',
  );

  /// Unique build signature to ensure fresh installations land on the Login Screen.
  static const String buildSignature = '1.2.0-beta.28+28';
}
