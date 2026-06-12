class PocketBaseConfig {
  static const String _configuredUrl = String.fromEnvironment(
    'POCKETBASE_URL',
    defaultValue: 'http://127.0.0.1:8090',
  );

  static String get baseUrl => _configuredUrl.endsWith('/')
      ? _configuredUrl.substring(0, _configuredUrl.length - 1)
      : _configuredUrl;
}
