class AppConfig {
  static const String appName = 'ShopFlow POS';
  
  /// Application version string (synchronize with pubspec.yaml and windows/installer.iss)
  static const String currentVersion = '1.1.7';
  static const String buildSignature = '1.1.7+60';

  /// GitHub repository information for update checks
  static const String githubOwner = 'muzammil608';
  static const String githubRepo = 'pos_mobile';
  
  /// Endpoint returning all releases including pre-release/beta versions
  static String get githubReleasesUrl =>
      'https://api.github.com/repos/$githubOwner/$githubRepo/releases';
      
  /// Backward compatible endpoint for latest stable release
  static String get githubLatestReleaseUrl =>
      'https://api.github.com/repos/$githubOwner/$githubRepo/releases/latest';
}
