class PocketBaseConfig {
  static const String _configuredUrl = String.fromEnvironment(
    'POCKETBASE_URL',
    defaultValue: 'http://127.0.0.1:8090',
  );

  static String get baseUrl => _configuredUrl.endsWith('/')
      ? _configuredUrl.substring(0, _configuredUrl.length - 1)
      : _configuredUrl;

  static const String superuserEmail = 'azmat@pos.com';
  static const String superuserPassword = 'REMOVED';

  /// Unique build signature to ensure fresh installations land on the Login Screen.
  static const String buildSignature = '1.2.0-beta.19+19';
}
