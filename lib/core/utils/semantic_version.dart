/// Utility for parsing and comparing semantic versions (e.g. 1.0.0, v1.1.0, 1.2.0+1).
class SemanticVersion implements Comparable<SemanticVersion> {
  final int major;
  final int minor;
  final int patch;
  final String raw;

  const SemanticVersion({
    required this.major,
    required this.minor,
    required this.patch,
    required this.raw,
  });

  /// Parses a semantic version string.
  /// Handles prefixes like 'v' or 'V' and strips build metadata or pre-release tags.
  factory SemanticVersion.parse(String versionString) {
    final raw = versionString.trim();
    var cleaned = raw;
    final versionMatch = RegExp(r'(\d+)\.(\d+)\.(\d+)').firstMatch(cleaned);
    if (versionMatch != null) {
      cleaned = versionMatch.group(0)!;
    } else if (cleaned.startsWith('v') || cleaned.startsWith('V')) {
      cleaned = cleaned.substring(1).trim();
    }

    // Strip build metadata (+...)
    final buildIndex = cleaned.indexOf('+');
    if (buildIndex != -1) {
      cleaned = cleaned.substring(0, buildIndex);
    }

    // Strip pre-release suffix (-...)
    final preIndex = cleaned.indexOf('-');
    if (preIndex != -1) {
      cleaned = cleaned.substring(0, preIndex);
    }

    final parts = cleaned.split('.');
    final major = parts.isNotEmpty ? int.tryParse(parts[0]) ?? 0 : 0;
    final minor = parts.length > 1 ? int.tryParse(parts[1]) ?? 0 : 0;
    final patch = parts.length > 2 ? int.tryParse(parts[2]) ?? 0 : 0;

    return SemanticVersion(
      major: major,
      minor: minor,
      patch: patch,
      raw: raw,
    );
  }

  @override
  int compareTo(SemanticVersion other) {
    if (major != other.major) {
      return major.compareTo(other.major);
    }
    if (minor != other.minor) {
      return minor.compareTo(other.minor);
    }
    return patch.compareTo(other.patch);
  }

  bool operator <(SemanticVersion other) => compareTo(other) < 0;
  bool operator <=(SemanticVersion other) => compareTo(other) <= 0;
  bool operator >(SemanticVersion other) => compareTo(other) > 0;
  bool operator >=(SemanticVersion other) => compareTo(other) >= 0;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SemanticVersion &&
          runtimeType == other.runtimeType &&
          major == other.major &&
          minor == other.minor &&
          patch == other.patch;

  @override
  int get hashCode => Object.hash(major, minor, patch);

  @override
  String toString() => '$major.$minor.$patch';
}
