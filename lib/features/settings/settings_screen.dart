import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/api/api_client.dart';
import '../../core/theme/cx_theme.dart';
import '../../core/widgets/cx_components.dart';
import '../store/codexa_store_screen.dart';

final sessionsListProvider = FutureProvider.autoDispose<Map<String, dynamic>>((
  ref,
) async {
  final api = CxApiClient();
  try {
    final res = await api.dio.get('/api/mobile/security');
    if (res.data != null && res.data['ok'] == true) {
      return Map<String, dynamic>.from(res.data);
    }
  } catch (_) {}
  return {'sessions': [], 'mobileDevices': []};
});

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessionsAsync = ref.watch(sessionsListProvider);

    return Scaffold(
      backgroundColor: CxColors.background,
      appBar: CxAppBar(
        title: 'SETTINGS & SECURITY',
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: CxColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(CxSpacing.lg),
        children: [
          // App Version & Status Card
          CxCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'CODEXA MOBILE CLIENT',
                      style: GoogleFonts.orbitron(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: CxColors.textPrimary,
                      ),
                    ),
                    const CxStatusChip(label: 'OFFICIAL APK'),
                  ],
                ),
                const SizedBox(height: CxSpacing.sm),
                Text(
                  'Version 1.0.0 (Build 100) • Android Production Build',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: CxColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Security Status: Encrypted session storage active.',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    color: CxColors.success,
                  ),
                ),
                const SizedBox(height: CxSpacing.md),
                InkWell(
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (ctx) => const CodeXaStoreScreen()),
                  ),
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: CxColors.crimson.withAlpha(25),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: CxColors.crimson.withAlpha(80)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.storefront_rounded, color: CxColors.crimson, size: 18),
                            const SizedBox(width: 10),
                            Text(
                              'CodeXa Store & Updates',
                              style: GoogleFonts.orbitron(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: CxColors.textPrimary,
                              ),
                            ),
                          ],
                        ),
                        const Icon(Icons.chevron_right_rounded, color: CxColors.textSecondary, size: 18),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: CxSpacing.xl),

          // Active Sessions & Devices
          const CxSectionHeader(title: 'ACTIVE SESSIONS & DEVICES'),
          const SizedBox(height: CxSpacing.sm),
          sessionsAsync.when(
            loading: () => const Center(
              child: CircularProgressIndicator(color: CxColors.brightRed),
            ),
            error: (_, __) => const SizedBox(),
            data: (secData) {
              final mobileDevices =
                  (secData['mobileDevices'] as List<dynamic>?) ?? [];

              return Column(
                children: [
                  ...mobileDevices.map((d) {
                    final deviceName = d['deviceName'] ?? 'Android Device';
                    final lastActive = d['lastActive'] ?? 'Active now';

                    return Padding(
                      padding: const EdgeInsets.only(bottom: CxSpacing.sm),
                      child: CxCard(
                        padding: const EdgeInsets.all(CxSpacing.md),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.phone_android,
                              color: CxColors.brightRed,
                              size: 22,
                            ),
                            const SizedBox(width: CxSpacing.md),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    deviceName,
                                    style: GoogleFonts.inter(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                      color: CxColors.textPrimary,
                                    ),
                                  ),
                                  Text(
                                    'Last active: $lastActive',
                                    style: GoogleFonts.inter(
                                      fontSize: 11,
                                      color: CxColors.textMuted,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const CxStatusChip(
                              label: 'THIS DEVICE',
                              isSmall: true,
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
                  const SizedBox(height: CxSpacing.md),
                  CxButton(
                    label: 'TERMINATE ALL OTHER SESSIONS',
                    isSecondary: true,
                    onPressed: () async {
                      final api = CxApiClient();
                      try {
                        await api.dio.post(
                          '/api/mobile/security',
                          data: {'action': 'logout_all_others'},
                        );
                        ref.invalidate(sessionsListProvider);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'All other remote device sessions revoked.',
                              ),
                              backgroundColor: CxColors.success,
                            ),
                          );
                        }
                      } catch (_) {}
                    },
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: CxSpacing.xxl),
        ],
      ),
    );
  }
}
