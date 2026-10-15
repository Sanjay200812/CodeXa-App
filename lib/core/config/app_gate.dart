import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'force_update_screen.dart';
import 'maintenance_screen.dart';
import 'mobile_config_provider.dart';

class AppGate extends ConsumerStatefulWidget {
  final Widget child;

  const AppGate({super.key, required this.child});

  @override
  ConsumerState<AppGate> createState() => _AppGateState();
}

class _AppGateState extends ConsumerState<AppGate> with WidgetsBindingObserver {
  DateTime _lastResumeFetch = DateTime.now();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      final now = DateTime.now();
      // Debounce resume refresh to at most once every 5 seconds
      if (now.difference(_lastResumeFetch).inSeconds >= 5) {
        _lastResumeFetch = now;
        ref.read(mobileConfigProvider.notifier).checkPublicConfig();
        ref.read(mobileConfigProvider.notifier).refreshAuthenticatedConfig();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final configState = ref.watch(mobileConfigProvider);

    // 1. Maintenance Gate
    if (configState.isMaintenance) {
      return MaintenanceScreen(
        title: configState.config?.maintenanceTitle ?? 'CODEXA MAINTENANCE',
        message:
            configState.config?.maintenanceMessage ??
            'CodeXa is temporarily unavailable while we make improvements.',
        expectedEndAt: configState.config?.maintenanceExpectedEndAt
            ?.toIso8601String(),
        isRetrying: configState.isLoading,
        onRetry: () =>
            ref.read(mobileConfigProvider.notifier).checkPublicConfig(),
      );
    }

    // 2. Force Update Gate
    if (configState.isForceUpdate) {
      return ForceUpdateScreen(
        installedVersion: configState.installedVersion,
        requiredVersion: configState.config?.minimumSupportedVersion ?? '1.0.0',
        updateUrl:
            configState.config?.updateUrl ??
            'https://codxa-agency.online/downloads/CodeXa.apk',
        releaseNotes: configState.config?.releaseNotes,
      );
    }

    // 3. Normal Application Tree
    return widget.child;
  }
}
