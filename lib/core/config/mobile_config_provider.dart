import '../services/cx_package_installer.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/api_client.dart';
import '../models/models.dart';
import 'version_utils.dart';

class MobileConfigState {
  final MobileRemoteConfigModel? config;
  final String installedVersion;
  final bool isLoading;
  final String? error;

  MobileConfigState({
    this.config,
    this.installedVersion = '1.0.0',
    this.isLoading = false,
    this.error,
  });

  bool get isMaintenance => config?.maintenanceEnabled ?? false;

  bool get isForceUpdate {
    if (config == null) return false;
    if (config!.forceUpdate) return true;
    return VersionUtils.isVersionBelow(
      installedVersion,
      config!.minimumSupportedVersion,
    );
  }

  bool isFeatureEnabled(String flagKey, {bool defaultValue = true}) {
    if (config == null) return defaultValue;
    if (!config!.featureFlags.containsKey(flagKey)) return defaultValue;
    return config!.featureFlags[flagKey] == true;
  }

  MobileConfigState copyWith({
    MobileRemoteConfigModel? config,
    String? installedVersion,
    bool? isLoading,
    String? error,
  }) {
    return MobileConfigState(
      config: config ?? this.config,
      installedVersion: installedVersion ?? this.installedVersion,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

class MobileConfigNotifier extends StateNotifier<MobileConfigState> {
  final CxApiClient _api = CxApiClient();

  MobileConfigNotifier() : super(MobileConfigState()) {
    checkPublicConfig();
  }

  Future<void> checkPublicConfig() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final pInfo = await CxPackageInstaller.getPackageInfo();
      state = state.copyWith(installedVersion: pInfo.versionName);
    } catch (_) {}
    try {
      final res = await _api.dio.get('/api/mobile/public-config');
      if (res.data != null && res.data['ok'] == true) {
        final parsed = MobileRemoteConfigModel.fromJson(res.data);
        state = state.copyWith(config: parsed, isLoading: false);
      } else {
        state = state.copyWith(isLoading: false);
      }
    } catch (_) {
      // Don't crash on initial public config failure; keep default/cached
      state = state.copyWith(isLoading: false);
    }
  }

  Future<void> refreshAuthenticatedConfig() async {
    try {
      final res = await _api.dio.get('/api/mobile/config');
      if (res.data != null &&
          (res.data['ok'] == true || res.data['success'] == true)) {
        final raw = res.data['data'] ?? res.data;
        final parsed = MobileRemoteConfigModel.fromJson(raw);
        state = state.copyWith(config: parsed);
      }
    } catch (e) {
      // If server returns 503 with MAINTENANCE_MODE
      checkPublicConfig();
    }
  }
}

final mobileConfigProvider =
    StateNotifierProvider<MobileConfigNotifier, MobileConfigState>((ref) {
      return MobileConfigNotifier();
    });
