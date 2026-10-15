import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class CxInstalledPackageInfo {
  final String packageName;
  final String versionName;
  final int versionCode;
  final int? firstInstallTime;
  final int? lastUpdateTime;

  const CxInstalledPackageInfo({
    required this.packageName,
    required this.versionName,
    required this.versionCode,
    this.firstInstallTime,
    this.lastUpdateTime,
  });

  factory CxInstalledPackageInfo.fromMap(Map<dynamic, dynamic> map) {
    return CxInstalledPackageInfo(
      packageName: map['packageName']?.toString() ?? 'online.codexa.codexa_mobile',
      versionName: map['versionName']?.toString() ?? '1.0.0',
      versionCode: int.tryParse(map['versionCode']?.toString() ?? '7') ?? 7,
      firstInstallTime: int.tryParse(map['firstInstallTime']?.toString() ?? ''),
      lastUpdateTime: int.tryParse(map['lastUpdateTime']?.toString() ?? ''),
    );
  }
}

class CxApkCompatibilityReport {
  final bool compatible;
  final String? archivePackageName;
  final String? currentPackageName;
  final int? archiveVersionCode;
  final String? archiveVersionName;
  final int? fileSizeBytes;
  final String? error;

  const CxApkCompatibilityReport({
    required this.compatible,
    this.archivePackageName,
    this.currentPackageName,
    this.archiveVersionCode,
    this.archiveVersionName,
    this.fileSizeBytes,
    this.error,
  });

  factory CxApkCompatibilityReport.fromMap(Map<dynamic, dynamic> map) {
    return CxApkCompatibilityReport(
      compatible: map['compatible'] == true,
      archivePackageName: map['archivePackageName']?.toString(),
      currentPackageName: map['currentPackageName']?.toString(),
      archiveVersionCode: int.tryParse(map['archiveVersionCode']?.toString() ?? ''),
      archiveVersionName: map['archiveVersionName']?.toString(),
      fileSizeBytes: int.tryParse(map['fileSizeBytes']?.toString() ?? ''),
      error: map['error']?.toString(),
    );
  }
}

class CxPackageInstaller {
  static const MethodChannel _channel = MethodChannel('online.codexa/package_installer');

  /// Checks if Android allows installing packages from this app without prompt
  static Future<bool> canRequestPackageInstalls() async {
    if (!Platform.isAndroid) return true;
    try {
      final res = await _channel.invokeMethod<bool>('canRequestPackageInstalls');
      return res ?? false;
    } catch (e) {
      debugPrint('[CxPackageInstaller] canRequestPackageInstalls error: $e');
      return true;
    }
  }

  /// Opens the system "Install Unknown Apps" permission screen for CodeXa
  static Future<bool> openInstallPermissionSettings() async {
    if (!Platform.isAndroid) return true;
    try {
      final res = await _channel.invokeMethod<bool>('openInstallPermissionSettings');
      return res ?? false;
    } catch (e) {
      debugPrint('[CxPackageInstaller] openInstallPermissionSettings error: $e');
      return false;
    }
  }

  /// Fetches installed package details directly from Android PackageManager
  static Future<CxInstalledPackageInfo> getPackageInfo() async {
    if (!Platform.isAndroid) {
      return const CxInstalledPackageInfo(
        packageName: 'online.codexa.codexa_mobile',
        versionName: '1.0.0',
        versionCode: 7,
      );
    }
    try {
      final res = await _channel.invokeMethod<Map<dynamic, dynamic>>('getPackageInfo');
      if (res != null) {
        return CxInstalledPackageInfo.fromMap(res);
      }
    } catch (e) {
      debugPrint('[CxPackageInstaller] getPackageInfo fallback: $e');
    }
    return const CxInstalledPackageInfo(
      packageName: 'online.codexa.codexa_mobile',
      versionName: '1.0.0',
      versionCode: 7,
    );
  }

  /// Cryptographically and structurally parses the downloaded APK on disk
  static Future<CxApkCompatibilityReport> verifyApkCompatibility(String filePath) async {
    if (!Platform.isAndroid) {
      return const CxApkCompatibilityReport(
        compatible: true,
        archivePackageName: 'online.codexa.codexa_mobile',
        currentPackageName: 'online.codexa.codexa_mobile',
        archiveVersionCode: 8,
        archiveVersionName: '1.0.1',
      );
    }
    try {
      final res = await _channel.invokeMethod<Map<dynamic, dynamic>>(
        'verifyApkCompatibility',
        {'filePath': filePath},
      );
      if (res != null) {
        return CxApkCompatibilityReport.fromMap(res);
      }
    } catch (e) {
      debugPrint('[CxPackageInstaller] verifyApkCompatibility error: $e');
      return CxApkCompatibilityReport(compatible: false, error: e.toString());
    }
    return const CxApkCompatibilityReport(compatible: false, error: 'Failed to verify APK');
  }

  /// Launches Android PackageInstaller Intent via FileProvider
  static Future<bool> installApk(String filePath) async {
    if (!Platform.isAndroid) {
      debugPrint('[CxPackageInstaller] installApk simulated on non-Android platform: $filePath');
      return true;
    }
    try {
      final res = await _channel.invokeMethod<Map<dynamic, dynamic>>(
        'installApk',
        {'filePath': filePath},
      );
      return res != null && res['initiated'] == true;
    } catch (e) {
      debugPrint('[CxPackageInstaller] installApk failed: $e');
      rethrow;
    }
  }
}
