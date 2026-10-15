/// SemVer comparison utility for CodeXa Mobile
class VersionUtils {
  static List<int> parseSemver(String versionStr) {
    try {
      final clean = versionStr.trim().split('+')[0].split('-')[0];
      final parts = clean.split('.');
      final major = parts.isNotEmpty ? int.tryParse(parts[0]) ?? 0 : 0;
      final minor = parts.length > 1 ? int.tryParse(parts[1]) ?? 0 : 0;
      final patch = parts.length > 2 ? int.tryParse(parts[2]) ?? 0 : 0;
      return [major, minor, patch];
    } catch (_) {
      return [0, 0, 0];
    }
  }

  /// Returns true if installedVersion < targetVersion
  static bool isVersionBelow(String installedVersion, String targetVersion) {
    final inst = parseSemver(installedVersion);
    final targ = parseSemver(targetVersion);

    if (inst[0] != targ[0]) {
      return inst[0] < targ[0];
    }
    if (inst[1] != targ[1]) {
      return inst[1] < targ[1];
    }
    return inst[2] < targ[2];
  }
}
