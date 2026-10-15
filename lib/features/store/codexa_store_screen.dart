import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/services/cx_update_service.dart';
import '../../core/theme/cx_theme.dart';
import 'codexa_store_models.dart';
import 'codexa_store_repository.dart';
import 'codexa_video_player_widget.dart';
import 'screenshot_viewer_screen.dart';

class CodeXaStoreScreen extends ConsumerStatefulWidget {
  final bool isMandatoryModal;

  const CodeXaStoreScreen({
    super.key,
    this.isMandatoryModal = false,
  });

  @override
  ConsumerState<CodeXaStoreScreen> createState() => _CodeXaStoreScreenState();
}

class _CodeXaStoreScreenState extends ConsumerState<CodeXaStoreScreen> {
  Future<void> _openExternalUrl(String url) async {
    final uri = Uri.parse(url.isNotEmpty ? url : 'https://codxa-agency.online/downloads/CodeXa.apk');
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not open link: $e'),
            backgroundColor: CxColors.crimson,
          ),
        );
      }
    }
  }

  void _copyToClipboard(String text, String label) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
            const SizedBox(width: 8),
            Text('$label copied to clipboard', style: GoogleFonts.inter(color: Colors.white)),
          ],
        ),
        backgroundColor: const Color(0xFF16A34A),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  IconData _getFeatureIcon(String iconName) {
    switch (iconName.toLowerCase()) {
      case 'messagesquare':
      case 'message':
      case 'chat':
        return Icons.chat_bubble_outline_rounded;
      case 'qrcode':
      case 'qr':
        return Icons.qr_code_scanner_rounded;
      case 'graduationcap':
      case 'education':
      case 'training':
        return Icons.school_outlined;
      case 'kanban':
      case 'project':
        return Icons.dashboard_outlined;
      case 'bell':
      case 'notifications':
        return Icons.notifications_active_outlined;
      case 'shieldcheck':
      case 'shield':
      case 'security':
        return Icons.verified_user_outlined;
      default:
        return Icons.auto_awesome_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final updateState = ref.watch(codeXaUpdateProvider);
    final updateNotifier = ref.read(codeXaUpdateProvider.notifier);
    final catalogAsync = ref.watch(codeXaStoreCatalogProvider);

    final info = updateState.updateInfo;
    final installed = updateState.installedPackage;

    final currentVer = installed?.versionName ?? '1.0.0';
    final currentCode = installed?.versionCode ?? 7;
    final latestVer = info?.latestVersion ?? (catalogAsync.value?.release?['versionName'] ?? '1.0.5');
    final latestCode = info?.latestVersionCode ?? (catalogAsync.value?.release?['versionCode'] ?? 105);

    return PopScope(
      canPop: !updateState.isMandatory && !widget.isMandatoryModal,
      child: Scaffold(
        backgroundColor: CxColors.background,
        appBar: AppBar(
          backgroundColor: const Color(0xFF0C0C0C),
          elevation: 0,
          leading: (!updateState.isMandatory && !widget.isMandatoryModal)
              ? IconButton(
                  icon: const Icon(Icons.arrow_back, color: CxColors.textPrimary),
                  onPressed: () => Navigator.of(context).pop(),
                )
              : null,
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: CxColors.crimson.withAlpha(40),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.storefront_rounded,
                  color: CxColors.crimson,
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'CODEXA STORE',
                    style: GoogleFonts.orbitron(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.5,
                      color: CxColors.textPrimary,
                    ),
                  ),
                  Text(
                    'Official Agency Distribution',
                    style: GoogleFonts.inter(
                      fontSize: 10,
                      color: CxColors.textMuted,
                    ),
                  ),
                ],
              ),
            ],
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh_rounded, color: CxColors.textSecondary),
              tooltip: 'Refresh Store & Update Info',
              onPressed: () {
                ref.invalidate(codeXaStoreCatalogProvider);
                updateNotifier.checkForUpdates(userInitiated: true);
              },
            ),
          ],
        ),
        body: catalogAsync.when(
          loading: () => const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(color: CxColors.crimson),
                SizedBox(height: 16),
                Text(
                  'Loading CodeXa Store Catalog...',
                  style: TextStyle(color: CxColors.textSecondary, fontSize: 13),
                ),
              ],
            ),
          ),
          error: (err, stack) => Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.cloud_off_rounded, color: CxColors.crimson, size: 56),
                  const SizedBox(height: 16),
                  Text(
                    'Could not load live store catalog',
                    style: GoogleFonts.inter(color: CxColors.textPrimary, fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '$err',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(color: CxColors.textMuted, fontSize: 12),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton.icon(
                    onPressed: () => ref.invalidate(codeXaStoreCatalogProvider),
                    icon: const Icon(Icons.refresh),
                    label: const Text('Try Again'),
                    style: ElevatedButton.styleFrom(backgroundColor: CxColors.crimson, foregroundColor: Colors.white),
                  ),
                ],
              ),
            ),
          ),
          data: (catalog) {
            return RefreshIndicator(
              color: CxColors.crimson,
              backgroundColor: CxColors.cardElevated,
              onRefresh: () async {
                ref.invalidate(codeXaStoreCatalogProvider);
                await updateNotifier.checkForUpdates(userInitiated: true);
              },
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.only(bottom: 40),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // 1. Mandatory Update Notice (if critical)
                    if (updateState.isMandatory || widget.isMandatoryModal)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        color: CxColors.crimson.withAlpha(220),
                        child: Row(
                          children: [
                            const Icon(Icons.warning_amber_rounded, color: Colors.white, size: 22),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'A critical security update is required to continue using CodeXa Mobile.',
                                style: GoogleFonts.inter(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                    // 2. App Hero Showcase Card
                    _buildHeroCard(
                      context: context,
                      catalog: catalog,
                      updateState: updateState,
                      updateNotifier: updateNotifier,
                      currentVer: currentVer,
                      currentCode: currentCode,
                      latestVer: latestVer.toString(),
                      latestCode: latestCode is int ? latestCode : int.tryParse(latestCode.toString()) ?? 105,
                    ),

                    const SizedBox(height: 24),

                    // 2b. Dual Distribution Methods (Website Direct & In-App Auto-Installer)
                    Container(
                      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0F0F0F),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: CxColors.borderDefault),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: CxColors.crimson.withAlpha(40),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(Icons.language_rounded, color: CxColors.brightRed, size: 16),
                              ),
                              const SizedBox(width: 10),
                              Text(
                                'METHOD 1: DOWNLOAD FROM CODEXA WEBSITE',
                                style: GoogleFonts.orbitron(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.8,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Direct canonical APK download hosted at codxa-agency.online/downloads/CodeXa.apk with SHA-256 verification.',
                            style: GoogleFonts.inter(
                              color: CxColors.textSecondary,
                              fontSize: 11,
                              height: 1.35,
                            ),
                          ),
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton.icon(
                              onPressed: () => _openExternalUrl(
                                catalog.release?['downloadUrl']?.toString() ?? 'https://codxa-agency.online/downloads/CodeXa.apk',
                              ),
                              icon: const Icon(Icons.open_in_browser_rounded, size: 16),
                              label: Text(
                                'Download APK from Website (v${catalog.release?['versionName'] ?? '1.0.5'})',
                                style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600),
                              ),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: CxColors.textPrimary,
                                side: const BorderSide(color: CxColors.borderDefault),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 14),

                    // 3. Screenshots Carousel Section
                    if (catalog.screenshots.isNotEmpty)
                      _buildScreenshotsSection(context, catalog.screenshots),

                    const SizedBox(height: 28),

                    // 4. Video Player Walkthrough Section
                    if (catalog.videos.isNotEmpty)
                      _buildVideoSection(context, catalog.videos.first),

                    const SizedBox(height: 28),

                    // 5. Core Features Grid
                    if (catalog.features.isNotEmpty)
                      _buildFeaturesSection(context, catalog.features),

                    const SizedBox(height: 28),

                    // 6. Technical Specifications & Release Notes
                    _buildTechSpecsSection(context, catalog, currentVer, currentCode),

                    const SizedBox(height: 28),

                    // 7. Installation Guide Steps
                    if (catalog.installationSteps.isNotEmpty)
                      _buildInstallStepsSection(context, catalog.installationSteps),

                    const SizedBox(height: 28),

                    // 8. Troubleshooting & FAQ Section
                    if (catalog.troubleshooting.isNotEmpty)
                      _buildFaqSection(context, catalog.troubleshooting),

                    const SizedBox(height: 28),

                    // 9. Official Website & Support Links
                    _buildFooterSection(context, catalog),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  // --- COMPONENT BUILDERS ---

  Widget _buildHeroCard({
    required BuildContext context,
    required StoreCatalog catalog,
    required CodeXaUpdateState updateState,
    required CodeXaUpdateNotifier updateNotifier,
    required String currentVer,
    required int currentCode,
    required String latestVer,
    required int latestCode,
  }) {
    final hasNewerUpdate = latestCode > currentCode;
    final downloadUrl = catalog.release?['downloadUrl']?.toString() ?? 'https://codxa-agency.online/downloads/CodeXa.apk';
    final formattedSize = catalog.release?['apkSizeFormatted']?.toString() ?? '825.9 MB';

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF0E0E0E),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: CxColors.borderDefault),
        boxShadow: CxShadows.subtle,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // App Icon with glowing neon accent
              Container(
                width: 76,
                height: 76,
                decoration: BoxDecoration(
                  gradient: const RadialGradient(
                    colors: [Color(0xFF26050A), Color(0xFF0A0A0A)],
                  ),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: CxColors.borderActive, width: 1.5),
                  boxShadow: const [
                    BoxShadow(color: Color(0x40FF1E3C), blurRadius: 14, spreadRadius: -2),
                  ],
                ),
                padding: const EdgeInsets.all(12),
                child: Image.asset(
                  'assets/images/codexa_logo.png',
                  errorBuilder: (context, error, stackTrace) => const Icon(
                    Icons.terminal_rounded,
                    color: CxColors.brightRed,
                    size: 38,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      catalog.application.name,
                      style: GoogleFonts.orbitron(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.8,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      catalog.application.developer,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: CxColors.textSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 6),
                    // Verified Badge
                    Row(
                      children: [
                        const Icon(Icons.verified_rounded, color: CxColors.brightRed, size: 14),
                        const SizedBox(width: 4),
                        Text(
                          'Official Enterprise Release',
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            color: CxColors.brightRed,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Official Website Distribution Banner
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.black.withAlpha(120),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: CxColors.borderSubtle),
            ),
            child: Row(
              children: [
                const Icon(Icons.lock_outline_rounded, color: Color(0xFF10B981), size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    catalog.application.badgeText,
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      color: const Color(0xFFD1D5DB),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Quick Specs Metrics
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildMetricChip(
                label: 'Installed',
                value: 'v$currentVer',
                subValue: 'Build $currentCode',
              ),
              _buildMetricChip(
                label: 'Latest',
                value: 'v$latestVer',
                subValue: 'Build $latestCode',
                isHighlight: hasNewerUpdate,
              ),
              _buildMetricChip(
                label: 'Download Size',
                value: formattedSize,
                subValue: 'Official APK',
              ),
            ],
          ),

          const SizedBox(height: 20),

          // CTA Action Buttons
          _buildActionButton(
            context: context,
            updateState: updateState,
            updateNotifier: updateNotifier,
            hasNewerUpdate: hasNewerUpdate,
            downloadUrl: downloadUrl,
            latestVer: latestVer,
          ),
        ],
      ),
    );
  }

  Widget _buildMetricChip({
    required String label,
    required String value,
    required String subValue,
    bool isHighlight = false,
  }) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        decoration: BoxDecoration(
          color: isHighlight ? CxColors.crimson.withAlpha(25) : const Color(0xFF141414),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isHighlight ? CxColors.borderActive : CxColors.borderSubtle,
          ),
        ),
        child: Column(
          children: [
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 10,
                color: CxColors.textMuted,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: GoogleFonts.orbitron(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: isHighlight ? CxColors.brightRed : CxColors.textPrimary,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              subValue,
              style: GoogleFonts.inter(
                fontSize: 9,
                color: CxColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required BuildContext context,
    required CodeXaUpdateState updateState,
    required CodeXaUpdateNotifier updateNotifier,
    required bool hasNewerUpdate,
    required String downloadUrl,
    required String latestVer,
  }) {
    // 1. Downloading state
    if (updateState.status == UpdateState.downloading) {
      final progress = updateState.downloadProgress;
      final percentStr = (progress * 100).toStringAsFixed(0);
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: progress > 0 ? progress : null,
              minHeight: 12,
              backgroundColor: Colors.white12,
              color: CxColors.brightRed,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Downloading CodeXa Mobile v$latestVer... $percentStr%',
                style: GoogleFonts.inter(color: CxColors.textSecondary, fontSize: 12),
              ),
              IconButton(
                icon: const Icon(Icons.cancel_rounded, color: CxColors.crimson, size: 20),
                onPressed: () => updateNotifier.cancelDownload(),
                tooltip: 'Cancel Download',
              ),
            ],
          ),
        ],
      );
    }

    // 2. Verifying checksum
    if (updateState.status == UpdateState.verifying) {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        alignment: Alignment.center,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2, color: CxColors.brightRed),
            ),
            const SizedBox(width: 12),
            Text(
              'Verifying SHA-256 Checksum...',
              style: GoogleFonts.inter(color: Colors.white, fontSize: 13),
            ),
          ],
        ),
      );
    }

    // 3. Ready to install
    if (updateState.status == UpdateState.readyToInstall ||
        updateState.status == UpdateState.awaitingAndroidConfirmation) {
      return SizedBox(
        width: double.infinity,
        height: 48,
        child: ElevatedButton.icon(
          onPressed: () => updateNotifier.launchSystemInstaller(),
          icon: const Icon(Icons.system_update_rounded, color: Colors.white),
          label: Text(
            'INSTALL UPDATE NOW (v$latestVer)',
            style: GoogleFonts.orbitron(fontSize: 13, fontWeight: FontWeight.w700, letterSpacing: 0.8),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF16A34A),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            elevation: 4,
          ),
        ),
      );
    }

    // 4. Update Available
    if (hasNewerUpdate) {
      return Column(
        children: [
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton.icon(
              onPressed: () => updateNotifier.startDownloadAndUpdate(),
              icon: const Icon(Icons.download_rounded, color: Colors.white),
              label: Text(
                'UPDATE TO v$latestVer',
                style: GoogleFonts.orbitron(fontSize: 13, fontWeight: FontWeight.w700, letterSpacing: 0.8),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: CxColors.brightRed,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 4,
                shadowColor: const Color(0x60FF1E3C),
              ),
            ),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: () => _openExternalUrl(downloadUrl),
            icon: const Icon(Icons.open_in_browser_rounded, size: 16),
            label: Text(
              'Download APK via Browser',
              style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600),
            ),
            style: OutlinedButton.styleFrom(
              foregroundColor: CxColors.textSecondary,
              side: const BorderSide(color: CxColors.borderSubtle),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
        ],
      );
    }

    // 5. Up to date
    return Row(
      children: [
        Expanded(
          child: Container(
            height: 44,
            decoration: BoxDecoration(
              color: const Color(0xFF10B981).withAlpha(30),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF10B981).withAlpha(100)),
            ),
            alignment: Alignment.center,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.check_circle_rounded, color: Color(0xFF10B981), size: 18),
                const SizedBox(width: 8),
                Text(
                  'CodeXa is Up to Date',
                  style: GoogleFonts.inter(
                    color: const Color(0xFF10B981),
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 10),
        IconButton(
          onPressed: () => _openExternalUrl(downloadUrl),
          icon: const Icon(Icons.download_rounded, color: CxColors.textSecondary),
          tooltip: 'Re-download APK',
          style: IconButton.styleFrom(
            backgroundColor: const Color(0xFF141414),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
      ],
    );
  }

  Widget _buildScreenshotsSection(BuildContext context, List<StoreScreenshot> screenshots) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            children: [
              Text(
                'APP SCREENSHOTS',
                style: GoogleFonts.orbitron(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2,
                  color: CxColors.textPrimary,
                ),
              ),
              const SizedBox(width: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: CxColors.crimson.withAlpha(40),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '${screenshots.length} Screens',
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    color: CxColors.brightRed,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const Spacer(),
              Text(
                'Tap to zoom',
                style: GoogleFonts.inter(
                  fontSize: 11,
                  color: CxColors.textMuted,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        SizedBox(
          height: 290,
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            scrollDirection: Axis.horizontal,
            itemCount: screenshots.length,
            separatorBuilder: (context, index) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
              final sc = screenshots[index];
              return GestureDetector(
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (ctx) => ScreenshotViewerScreen(
                        screenshots: screenshots,
                        initialIndex: index,
                      ),
                    ),
                  );
                },
                child: Container(
                  width: 164,
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F0F0F),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: CxColors.borderDefault),
                    boxShadow: CxShadows.subtle,
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Hero(
                        tag: 'store_screenshot_${sc.id}',
                        child: CachedNetworkImage(
                          imageUrl: sc.thumbnailUrl,
                          fit: BoxFit.cover,
                          placeholder: (context, url) => Container(
                            color: const Color(0xFF141414),
                            alignment: Alignment.center,
                            child: const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(strokeWidth: 2, color: CxColors.crimson),
                            ),
                          ),
                          errorWidget: (context, url, error) => Container(
                            color: const Color(0xFF141414),
                            alignment: Alignment.center,
                            child: const Icon(Icons.broken_image_rounded, color: CxColors.textMuted),
                          ),
                        ),
                      ),
                      // Top gradient with category chip
                      Positioned(
                        top: 8,
                        left: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: Colors.black.withAlpha(200),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: CxColors.borderSubtle),
                          ),
                          child: Text(
                            sc.featureCategory,
                            style: GoogleFonts.inter(
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                      // Bottom gradient with title
                      Positioned(
                        bottom: 0,
                        left: 0,
                        right: 0,
                        child: Container(
                          padding: const EdgeInsets.fromLTRB(8, 20, 8, 8),
                          decoration: const BoxDecoration(
                            gradient: LinearGradient(
                              colors: [Colors.transparent, Colors.black87],
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                            ),
                          ),
                          child: Text(
                            sc.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.inter(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildVideoSection(BuildContext context, StoreVideo video) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Row(
              children: [
                Text(
                  'WATCH CODEXA IN ACTION',
                  style: GoogleFonts.orbitron(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.2,
                    color: CxColors.textPrimary,
                  ),
                ),
                const SizedBox(width: 8),
                const Icon(Icons.movie_filter_rounded, color: CxColors.brightRed, size: 16),
              ],
            ),
          ),
          const SizedBox(height: 12),
          CodexaVideoPlayerWidget(
            videoUrl: video.url,
            posterUrl: video.thumbnailUrl,
            title: video.title,
            durationSeconds: video.durationSeconds,
          ),
        ],
      ),
    );
  }

  Widget _buildFeaturesSection(BuildContext context, List<StoreFeature> features) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text(
              'EVERYTHING YOU NEED, IN ONE APP',
              style: GoogleFonts.orbitron(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.2,
                color: CxColors.textPrimary,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text(
              'Designed specifically for CodeXa Agency workforce and interns.',
              style: GoogleFonts.inter(
                fontSize: 11,
                color: CxColors.textSecondary,
              ),
            ),
          ),
          const SizedBox(height: 14),
          ListView.separated(
            physics: const NeverScrollableScrollPhysics(),
            shrinkWrap: true,
            itemCount: features.length,
            separatorBuilder: (context, index) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final feat = features[index];
              return Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFF0D0D0D),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: CxColors.borderDefault),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: CxColors.crimson.withAlpha(35),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: CxColors.borderDefault),
                      ),
                      child: Icon(
                        _getFeatureIcon(feat.icon),
                        color: CxColors.brightRed,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                feat.title,
                                style: GoogleFonts.inter(
                                  color: Colors.white,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const Spacer(),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.black,
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: CxColors.borderSubtle),
                                ),
                                child: Text(
                                  feat.category,
                                  style: GoogleFonts.inter(
                                    fontSize: 9,
                                    color: CxColors.textMuted,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            feat.description,
                            style: GoogleFonts.inter(
                              color: CxColors.textSecondary,
                              fontSize: 11,
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildTechSpecsSection(
    BuildContext context,
    StoreCatalog catalog,
    String currentVer,
    int currentCode,
  ) {
    final release = catalog.release;
    final sha256 = release?['sha256']?.toString() ?? '56a03e10b4f7f33f633e26a31ac77a9fe2a405a179f12bd0b58a872fc5372a95';
    final notes = release?['releaseNotes']?.toString() ?? 'Production update';
    final minSdk = release?['minAndroidVersion']?.toString() ?? 'Android 8.0 (API 26)';

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF0C0C0C),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: CxColors.borderDefault),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.security_rounded, color: CxColors.brightRed, size: 20),
              const SizedBox(width: 10),
              Text(
                'SECURITY & SPECIFICATIONS',
                style: GoogleFonts.orbitron(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2,
                  color: CxColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Release Notes
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF141414),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: CxColors.borderSubtle),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'What\'s New in This Release:',
                  style: GoogleFonts.inter(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  notes,
                  style: GoogleFonts.inter(
                    color: CxColors.textSecondary,
                    fontSize: 11,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 14),

          // Specs key-values
          _buildSpecRow('Package Name', catalog.application.packageName),
          _buildSpecRow('Installed Build', 'v$currentVer (Code $currentCode)'),
          _buildSpecRow('Minimum OS', minSdk),
          _buildSpecRow('Distribution', 'Official Website Only (codxa-agency.online)'),

          const SizedBox(height: 14),

          // SHA-256 Card with Copy
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.black,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: CxColors.borderDefault),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.fingerprint_rounded, color: CxColors.brightRed, size: 16),
                        const SizedBox(width: 6),
                        Text(
                          'SHA-256 Checksum',
                          style: GoogleFonts.orbitron(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                    GestureDetector(
                      onTap: () => _copyToClipboard(sha256, 'SHA-256 Hash'),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: CxColors.crimson.withAlpha(50),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: CxColors.borderDefault),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.copy_rounded, color: CxColors.brightRed, size: 12),
                            const SizedBox(width: 4),
                            Text(
                              'Copy',
                              style: GoogleFonts.inter(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: CxColors.brightRed,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  sha256,
                  style: GoogleFonts.spaceMono(
                    color: CxColors.textMuted,
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSpecRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: GoogleFonts.inter(
              color: CxColors.textMuted,
              fontSize: 11,
            ),
          ),
          Text(
            value,
            style: GoogleFonts.inter(
              color: CxColors.textPrimary,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInstallStepsSection(BuildContext context, List<StoreInstallStep> steps) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text(
              'INSTALLATION GUIDE',
              style: GoogleFonts.orbitron(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.2,
                color: CxColors.textPrimary,
              ),
            ),
          ),
          const SizedBox(height: 12),
          ...steps.map((s) => Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFF0D0D0D),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: CxColors.borderSubtle),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: CxColors.crimson.withAlpha(50),
                        shape: BoxShape.circle,
                        border: Border.all(color: CxColors.borderDefault),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        '${s.stepNumber}',
                        style: GoogleFonts.orbitron(
                          color: CxColors.brightRed,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            s.title,
                            style: GoogleFonts.inter(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            s.description,
                            style: GoogleFonts.inter(
                              color: CxColors.textSecondary,
                              fontSize: 11,
                              height: 1.35,
                            ),
                          ),
                          if (s.tip.isNotEmpty) ...[
                            const SizedBox(height: 6),
                            Text(
                              'Tip: ${s.tip}',
                              style: GoogleFonts.inter(
                                color: const Color(0xFFF59E0B),
                                fontSize: 10,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              )),
        ],
      ),
    );
  }

  Widget _buildFaqSection(BuildContext context, List<StoreFaq> faqs) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text(
              'FREQUENTLY ASKED QUESTIONS',
              style: GoogleFonts.orbitron(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.2,
                color: CxColors.textPrimary,
              ),
            ),
          ),
          const SizedBox(height: 12),
          ...faqs.map((faq) => Container(
                margin: const EdgeInsets.only(bottom: 8),
                child: Material(
                  color: const Color(0xFF0D0D0D),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: const BorderSide(color: CxColors.borderSubtle),
                  ),
                  child: Theme(
                    data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                    child: ExpansionTile(
                    tilePadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
                    iconColor: CxColors.brightRed,
                    collapsedIconColor: CxColors.textMuted,
                    title: Text(
                      faq.q,
                      style: GoogleFonts.inter(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                        child: Text(
                          faq.a,
                          style: GoogleFonts.inter(
                            color: CxColors.textSecondary,
                            fontSize: 11,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              )),
        ],
      ),
    );
  }

  Widget _buildFooterSection(BuildContext context, StoreCatalog catalog) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF090909),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: CxColors.borderSubtle),
      ),
      child: Column(
        children: [
          Text(
            'CodeXa Agency Production Workspace',
            style: GoogleFonts.orbitron(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Proprietary software • All rights reserved',
            style: GoogleFonts.inter(color: CxColors.textMuted, fontSize: 10),
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              OutlinedButton.icon(
                onPressed: () => _openExternalUrl('https://codxa-agency.online/mobile'),
                icon: const Icon(Icons.language_rounded, size: 14),
                label: const Text('Website'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: const BorderSide(color: CxColors.borderDefault),
                  textStyle: GoogleFonts.inter(fontSize: 11),
                ),
              ),
              const SizedBox(width: 12),
              OutlinedButton.icon(
                onPressed: () => _openExternalUrl('mailto:contact@codxa-agency.online'),
                icon: const Icon(Icons.email_outlined, size: 14),
                label: const Text('Support'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: const BorderSide(color: CxColors.borderDefault),
                  textStyle: GoogleFonts.inter(fontSize: 11),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
