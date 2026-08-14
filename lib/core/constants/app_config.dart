class AppConfig {
  static const String appName = 'ShopFlow POS';
  
  /// Application version string (synchronize with pubspec.yaml and windows/installer.iss)
  static const String currentVersion = '1.1.0-beta.1';
  static const String buildSignature = '1.1.0-beta.1+1';

  /// GitHub repository information for update checks
  static const String githubOwner = 'orion-pk';
  static const String githubRepo = 'releases';
  
  /// Endpoint returning all releases including pre-release/beta versions
  static String get githubReleasesUrl =>
      'https://api.github.com/repos/$githubOwner/$githubRepo/releases';
      
  /// Backward compatible endpoint for latest stable release
  static String get githubLatestReleaseUrl =>
      'https://api.github.com/repos/$githubOwner/$githubRepo/releases/latest';
}
