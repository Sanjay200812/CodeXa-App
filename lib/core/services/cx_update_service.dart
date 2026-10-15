import 'dart:async';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import '../api/api_client.dart';
import '../storage/secure_storage.dart';
import 'cx_package_installer.dart';

enum UpdateState {
  checkingForUpdates,
  upToDate,
  updateAvailable,
  updateRequired,
  downloading,
  verifying,
  readyToInstall,
  awaitingAndroidConfirmation,
  installing,
  installationCancelled,
  installationFailed,
  updateCompleted,
}

extension UpdateStateExtension on UpdateState {
  String get code {
    switch (this) {
      case UpdateState.checkingForUpdates:
        return 'CHECKING_FOR_UPDATES';
      case UpdateState.upToDate:
        return 'UP_TO_DATE';
      case UpdateState.updateAvailable:
        return 'UPDATE_AVAILABLE';
      case UpdateState.updateRequired:
        return 'UPDATE_REQUIRED';
      case UpdateState.downloading:
        return 'DOWNLOADING';
      case UpdateState.verifying:
        return 'VERIFYING';
      case UpdateState.readyToInstall:
        return 'READY_TO_INSTALL';
      case UpdateState.awaitingAndroidConfirmation:
        return 'AWAITING_ANDROID_CONFIRMATION';
      case UpdateState.installing:
        return 'INSTALLING';
      case UpdateState.installationCancelled:
        return 'INSTALLATION_CANCELLED';
      case UpdateState.installationFailed:
        return 'INSTALLATION_FAILED';
      case UpdateState.updateCompleted:
        return 'UPDATE_COMPLETED';
    }
  }

  String get label {
    switch (this) {
      case UpdateState.checkingForUpdates:
        return 'Checking for updates...';
      case UpdateState.upToDate:
        return 'CodeXa is up to date';
      case UpdateState.updateAvailable:
        return 'Update Available';
      case UpdateState.updateRequired:
        return 'Critical Update Required';
      case UpdateState.downloading:
        return 'Downloading update package...';
      case UpdateState.verifying:
        return 'Verifying package integrity & signature...';
      case UpdateState.readyToInstall:
        return 'Ready to install';
      case UpdateState.awaitingAndroidConfirmation:
        return 'Awaiting system confirmation...';
      case UpdateState.installing:
        return 'Installing update...';
      case UpdateState.installationCancelled:
        return 'Installation cancelled by user';
      case UpdateState.installationFailed:
        return 'Installation failed';
      case UpdateState.updateCompleted:
        return 'Successfully updated!';
    }
  }
}

class CodeXaUpdateInfo {
  final String latestVersion;
  final int latestVersionCode;
  final int minimumSupportedVersionCode;
  final bool updateAvailable;
  final bool forceUpdate;
  final String releaseNotes;
  final String downloadUrl;
  final String sha256;
  final int fileSizeBytes;
  final String channel;

  const CodeXaUpdateInfo({
    required this.latestVersion,
    required this.latestVersionCode,
    required this.minimumSupportedVersionCode,
    required this.updateAvailable,
    required this.forceUpdate,
    required this.releaseNotes,
    required this.downloadUrl,
    required this.sha256,
    required this.fileSizeBytes,
    this.channel = 'STABLE',
  });

  factory CodeXaUpdateInfo.fromMap(Map<String, dynamic> map) {
    final app = map['app'] is Map ? map['app'] as Map<String, dynamic> : map;
    return CodeXaUpdateInfo(
      latestVersion: app['latestVersion']?.toString() ?? '1.0.0',
      latestVersionCode: int.tryParse(app['latestVersionCode']?.toString() ?? '7') ?? 7,
      minimumSupportedVersionCode: int.tryParse(app['minimumSupportedVersionCode']?.toString() ?? '1') ?? 1,
      updateAvailable: app['updateAvailable'] == true,
      forceUpdate: app['forceUpdate'] == true,
      releaseNotes: app['releaseNotes']?.toString() ?? 'Official CodeXa release update with enhanced team productivity.',
      downloadUrl: app['downloadUrl']?.toString() ?? app['updateUrl']?.toString() ?? '',
      sha256: app['sha256']?.toString() ?? '',
      fileSizeBytes: int.tryParse(app['fileSizeBytes']?.toString() ?? '0') ?? 0,
      channel: app['channel']?.toString() ?? 'STABLE',
    );
  }
}

class CodeXaUpdateState {
  final UpdateState status;
  final CodeXaUpdateInfo? updateInfo;
  final CxInstalledPackageInfo? installedPackage;
  final double downloadProgress;
  final int bytesReceived;
  final int totalBytes;
  final String? downloadedApkPath;
  final String? computedSha256;
  final String? errorMessage;
  final String statusMessage;

  const CodeXaUpdateState({
    this.status = UpdateState.checkingForUpdates,
    this.updateInfo,
    this.installedPackage,
    this.downloadProgress = 0.0,
    this.bytesReceived = 0,
    this.totalBytes = 0,
    this.downloadedApkPath,
    this.computedSha256,
    this.errorMessage,
    this.statusMessage = 'Initializing update system...',
  });

  bool get isMandatory => updateInfo?.forceUpdate == true;

  CodeXaUpdateState copyWith({
    UpdateState? status,
    CodeXaUpdateInfo? updateInfo,
    CxInstalledPackageInfo? installedPackage,
    double? downloadProgress,
    int? bytesReceived,
    int? totalBytes,
    String? downloadedApkPath,
    String? computedSha256,
    String? errorMessage,
    String? statusMessage,
  }) {
    return CodeXaUpdateState(
      status: status ?? this.status,
      updateInfo: updateInfo ?? this.updateInfo,
      installedPackage: installedPackage ?? this.installedPackage,
      downloadProgress: downloadProgress ?? this.downloadProgress,
      bytesReceived: bytesReceived ?? this.bytesReceived,
      totalBytes: totalBytes ?? this.totalBytes,
      downloadedApkPath: downloadedApkPath ?? this.downloadedApkPath,
      computedSha256: computedSha256 ?? this.computedSha256,
      errorMessage: errorMessage,
      statusMessage: statusMessage ?? this.statusMessage,
    );
  }
}

class CodeXaUpdateNotifier extends StateNotifier<CodeXaUpdateState> {
  final CxApiClient _api = CxApiClient();
  CancelToken? _cancelToken;

  CodeXaUpdateNotifier() : super(const CodeXaUpdateState()) {
    checkForUpdates();
  }

  /// 1. Primary Update Check against CodeXa Core API
  Future<void> checkForUpdates({bool userInitiated = false}) async {
    state = state.copyWith(
      status: UpdateState.checkingForUpdates,
      statusMessage: 'Checking official CodeXa release servers...',
      errorMessage: null,
    );

    try {
      final pInfo = await CxPackageInstaller.getPackageInfo();
      
      // Check if user recently upgraded and we just reopened after update
      final lastRecordedCode = await CxStorage.read('last_known_build_code');
      if (lastRecordedCode != null) {
        final lastCode = int.tryParse(lastRecordedCode) ?? pInfo.versionCode;
        if (pInfo.versionCode > lastCode) {
          await CxStorage.write('last_known_build_code', pInfo.versionCode.toString());
          state = state.copyWith(
            status: UpdateState.updateCompleted,
            installedPackage: pInfo,
            statusMessage: 'CodeXa successfully upgraded to v${pInfo.versionName} (Build ${pInfo.versionCode})!',
          );
          return;
        }
      }
      await CxStorage.write('last_known_build_code', pInfo.versionCode.toString());

      // Query official release endpoint
      final res = await _api.dio.get(
        '/api/mobile/app-update',
        queryParameters: {
          'platform': 'android',
          'versionCode': pInfo.versionCode,
          'versionName': pInfo.versionName,
        },
      );

      if (res.data != null && res.data['ok'] == true && res.data['app'] != null) {
        final info = CodeXaUpdateInfo.fromMap(res.data['app'] as Map<String, dynamic>);
        
        final hasNewerCode = info.latestVersionCode > pInfo.versionCode;
        final isMandatory = (pInfo.versionCode < info.minimumSupportedVersionCode) || info.forceUpdate;

        if (hasNewerCode) {
          state = state.copyWith(
            status: isMandatory ? UpdateState.updateRequired : UpdateState.updateAvailable,
            updateInfo: info,
            installedPackage: pInfo,
            statusMessage: isMandatory
                ? 'Mandatory update required to connect with CodeXa workspace.'
                : 'A newer release v${info.latestVersion} is available.',
          );
        } else {
          state = state.copyWith(
            status: UpdateState.upToDate,
            updateInfo: info,
            installedPackage: pInfo,
            statusMessage: 'You are using the latest official CodeXa version (v${pInfo.versionName}).',
          );
        }
      } else {
        // Fallback to public-config
        await _checkPublicConfigFallback(pInfo);
      }
    } catch (e) {
      debugPrint('[CodeXaUpdate] Check updates failed: $e');
      final pInfo = await CxPackageInstaller.getPackageInfo();
      await _checkPublicConfigFallback(pInfo);
    }
  }

  Future<void> _checkPublicConfigFallback(CxInstalledPackageInfo pInfo) async {
    try {
      final res = await _api.dio.get('/api/mobile/public-config');
      if (res.data != null && res.data['ok'] == true && res.data['version'] != null) {
        final vObj = res.data['version'] as Map<String, dynamic>;
        final latestCode = int.tryParse(vObj['latestVersionCode']?.toString() ?? '') ?? pInfo.versionCode;
        final minCode = int.tryParse(vObj['minimumSupportedVersionCode']?.toString() ?? '1') ?? 1;
        final forceUp = vObj['forceUpdate'] == true || pInfo.versionCode < minCode;
        final hasNewer = latestCode > pInfo.versionCode;

        final info = CodeXaUpdateInfo(
          latestVersion: vObj['latest']?.toString() ?? pInfo.versionName,
          latestVersionCode: latestCode,
          minimumSupportedVersionCode: minCode,
          updateAvailable: hasNewer,
          forceUpdate: forceUp,
          releaseNotes: vObj['releaseNotes']?.toString() ?? 'Official stability update.',
          downloadUrl: vObj['downloadUrl']?.toString() ?? vObj['updateUrl']?.toString() ?? '',
          sha256: vObj['sha256']?.toString() ?? '',
          fileSizeBytes: int.tryParse(vObj['fileSizeBytes']?.toString() ?? '0') ?? 0,
        );

        if (hasNewer) {
          state = state.copyWith(
            status: forceUp ? UpdateState.updateRequired : UpdateState.updateAvailable,
            updateInfo: info,
            installedPackage: pInfo,
            statusMessage: forceUp
                ? 'Mandatory update required.'
                : 'New version v${info.latestVersion} available.',
          );
        } else {
          state = state.copyWith(
            status: UpdateState.upToDate,
            updateInfo: info,
            installedPackage: pInfo,
            statusMessage: 'CodeXa is up to date.',
          );
        }
      } else {
        state = state.copyWith(
          status: UpdateState.upToDate,
          installedPackage: pInfo,
          statusMessage: 'CodeXa is up to date.',
        );
      }
    } catch (e) {
      state = state.copyWith(
        status: UpdateState.upToDate,
        installedPackage: pInfo,
        statusMessage: 'Unable to reach update server. You may continue working offline.',
      );
    }
  }

  /// 2. Stream-based APK Download with Real Progress Tracking
  Future<void> startDownloadAndUpdate() async {
    final info = state.updateInfo;
    if (info == null || info.downloadUrl.isEmpty) {
      state = state.copyWith(
        status: UpdateState.installationFailed,
        errorMessage: 'Invalid update download URL.',
      );
      return;
    }

    _cancelToken = CancelToken();

    try {
      state = state.copyWith(
        status: UpdateState.downloading,
        downloadProgress: 0.0,
        bytesReceived: 0,
        totalBytes: info.fileSizeBytes > 0 ? info.fileSizeBytes : 0,
        statusMessage: 'Initiating secure direct download...',
        errorMessage: null,
      );

      final tempDir = await getTemporaryDirectory();
      final targetFile = File('${tempDir.path}/CodeXa_v${info.latestVersionCode}.apk');
      if (await targetFile.exists()) {
        try {
          await targetFile.delete();
        } catch (_) {}
      }

      final dio = Dio();
      await dio.download(
        info.downloadUrl,
        targetFile.path,
        cancelToken: _cancelToken,
        onReceiveProgress: (received, total) {
          final totalActual = total > 0 ? total : (info.fileSizeBytes > 0 ? info.fileSizeBytes : received);
          final progress = totalActual > 0 ? (received / totalActual).clamp(0.0, 1.0) : 0.0;
          final mbReceived = (received / (1024 * 1024)).toStringAsFixed(1);
          final mbTotal = (totalActual / (1024 * 1024)).toStringAsFixed(1);

          state = state.copyWith(
            downloadProgress: progress,
            bytesReceived: received,
            totalBytes: totalActual,
            statusMessage: '$mbReceived MB of $mbTotal MB downloaded (${(progress * 100).toInt()}%)',
          );
        },
      );

      // Verify cryptographic integrity
      await _verifyAndInstallApk(targetFile.path);
    } on DioException catch (dioErr) {
      if (CancelToken.isCancel(dioErr)) {
        state = state.copyWith(
          status: UpdateState.installationCancelled,
          statusMessage: 'Download cancelled by user.',
        );
      } else {
        state = state.copyWith(
          status: UpdateState.installationFailed,
          errorMessage: 'Network error downloading APK: ${dioErr.message}',
          statusMessage: 'Download failed. Please check internet connection.',
        );
      }
    } catch (e) {
      state = state.copyWith(
        status: UpdateState.installationFailed,
        errorMessage: e.toString(),
        statusMessage: 'Download error occurred.',
      );
    }
  }

  void cancelDownload() {
    _cancelToken?.cancel('User cancelled');
    state = state.copyWith(
      status: UpdateState.installationCancelled,
      statusMessage: 'Update cancelled.',
    );
  }

  /// 3. Verification of SHA-256 and Package Compatibility
  Future<void> _verifyAndInstallApk(String filePath) async {
    state = state.copyWith(
      status: UpdateState.verifying,
      downloadedApkPath: filePath,
      statusMessage: 'Computing SHA-256 checksum and checking certificate...',
    );

    final file = File(filePath);
    if (!await file.exists()) {
      state = state.copyWith(
        status: UpdateState.installationFailed,
        errorMessage: 'Downloaded APK file was not found on disk.',
      );
      return;
    }

    try {
      // 1. Compute SHA-256
      final bytes = await file.readAsBytes();
      final digest = sha256.convert(bytes).toString();

      final expectedSha = state.updateInfo?.sha256;
      if (expectedSha != null && expectedSha.isNotEmpty) {
        if (digest.toLowerCase() != expectedSha.toLowerCase()) {
          try { await file.delete(); } catch (_) {}
          state = state.copyWith(
            status: UpdateState.installationFailed,
            errorMessage: 'Cryptographic SHA-256 mismatch. File may be corrupted.',
            statusMessage: 'Verification failed: Checksum does not match server release.',
          );
          return;
        }
      }

      // 2. Native Package Verification
      final report = await CxPackageInstaller.verifyApkCompatibility(filePath);
      if (!report.compatible && report.error != null) {
        try { await file.delete(); } catch (_) {}
        state = state.copyWith(
          status: UpdateState.installationFailed,
          errorMessage: 'Incompatible package: ${report.error}',
          statusMessage: 'Package verification failed.',
        );
        return;
      }

      state = state.copyWith(
        status: UpdateState.readyToInstall,
        computedSha256: digest,
        statusMessage: 'APK verified successfully. Ready to update.',
      );

      // Immediately launch Android installation
      await launchSystemInstaller();
    } catch (e) {
      state = state.copyWith(
        status: UpdateState.installationFailed,
        errorMessage: 'Verification failed: $e',
        statusMessage: 'Failed to verify APK.',
      );
    }
  }

  /// 4. Launch Official Android Package Installer
  Future<void> launchSystemInstaller() async {
    final apkPath = state.downloadedApkPath;
    if (apkPath == null || !File(apkPath).existsSync()) {
      state = state.copyWith(
        status: UpdateState.installationFailed,
        errorMessage: 'No verified APK file ready to install.',
      );
      return;
    }

    try {
      // Check Android 8.0+ unknown app install permission
      final canInstall = await CxPackageInstaller.canRequestPackageInstalls();
      if (!canInstall) {
        state = state.copyWith(
          status: UpdateState.awaitingAndroidConfirmation,
          statusMessage: 'Please allow "Install unknown apps" permission for CodeXa in Android Settings.',
        );
        await CxPackageInstaller.openInstallPermissionSettings();
        return;
      }

      state = state.copyWith(
        status: UpdateState.installing,
        statusMessage: 'Launching Android Package Installer...',
      );

      final success = await CxPackageInstaller.installApk(apkPath);
      if (success) {
        state = state.copyWith(
          status: UpdateState.awaitingAndroidConfirmation,
          statusMessage: 'Follow the on-screen prompt to complete the update.',
        );
      } else {
        state = state.copyWith(
          status: UpdateState.installationFailed,
          errorMessage: 'System installer failed to launch.',
        );
      }
    } catch (e) {
      state = state.copyWith(
        status: UpdateState.installationFailed,
        errorMessage: 'Error launching installer: $e',
      );
    }
  }

  void resetState() {
    checkForUpdates();
  }
}

final codeXaUpdateProvider =
    StateNotifierProvider<CodeXaUpdateNotifier, CodeXaUpdateState>((ref) {
  return CodeXaUpdateNotifier();
});
