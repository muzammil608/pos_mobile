enum UpdateChannel {
  stable,
  beta,
}

extension UpdateChannelExtension on UpdateChannel {
  String get displayName {
    switch (this) {
      case UpdateChannel.stable:
        return 'Stable';
      case UpdateChannel.beta:
        return 'Beta';
    }
  }
}

class AppConfig {
  static const String appName = 'ShopFlow POS';
  
  /// Application version string (synchronize with pubspec.yaml and windows/installer.iss)
  static const String currentVersion = '1.2.0-beta.18';
  static const String buildSignature = '1.2.0-beta.18+80';

  /// Active update channel (defaults to beta channel for development builds)
  static UpdateChannel defaultChannel = UpdateChannel.beta;

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
