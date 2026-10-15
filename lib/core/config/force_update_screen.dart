import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

import '../theme/cx_theme.dart';
import '../widgets/cx_components.dart';
import '../../features/store/codexa_store_screen.dart';

class ForceUpdateScreen extends StatelessWidget {
  final String installedVersion;
  final String requiredVersion;
  final String updateUrl;
  final String? releaseNotes;

  const ForceUpdateScreen({
    super.key,
    required this.installedVersion,
    required this.requiredVersion,
    required this.updateUrl,
    this.releaseNotes,
  });

  Future<void> _launchUpdateUrl() async {
    final uri = Uri.parse(updateUrl);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: CxColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const Spacer(),
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: CxColors.crimson.withAlpha(30),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: CxColors.crimson.withAlpha(120),
                    width: 1.5,
                  ),
                ),
                child: const Icon(
                  Icons.system_update_alt_rounded,
                  color: CxColors.crimson,
                  size: 36,
                ),
              ),
              const SizedBox(height: CxSpacing.xl),
              Text(
                'UPDATE REQUIRED',
                style: GoogleFonts.orbitron(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 2.0,
                  color: CxColors.textPrimary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: CxSpacing.sm),
              Text(
                'A newer version of CodeXa is required to continue. Please update to stay connected with the workspace.',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  color: CxColors.textSecondary,
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: CxSpacing.xl),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: CxColors.card,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: CxColors.borderSubtle),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'INSTALLED VERSION',
                          style: GoogleFonts.orbitron(
                            fontSize: 11,
                            color: CxColors.textSecondary,
                          ),
                        ),
                        Text(
                          'v$installedVersion',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: CxColors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                    const Divider(color: CxColors.borderSubtle, height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'REQUIRED MINIMUM',
                          style: GoogleFonts.orbitron(
                            fontSize: 11,
                            color: CxColors.textSecondary,
                          ),
                        ),
                        Text(
                          'v$requiredVersion',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: CxColors.accent,
                          ),
                        ),
                      ],
                    ),
                    if (releaseNotes != null && releaseNotes!.isNotEmpty) ...[
                      const Divider(color: CxColors.borderSubtle, height: 20),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          releaseNotes!,
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            color: CxColors.textSecondary,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const Spacer(),
              CxButton(
                label: 'UPDATE VIA CODEXA STORE',
                icon: Icons.storefront_rounded,
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (ctx) => const CodeXaStoreScreen(isMandatoryModal: true),
                    ),
                  );
                },
              ),
              const SizedBox(height: CxSpacing.sm),
              OutlinedButton.icon(
                onPressed: _launchUpdateUrl,
                icon: const Icon(Icons.open_in_browser_rounded, size: 18),
                label: Text(
                  'DOWNLOAD FROM WEBSITE',
                  style: GoogleFonts.orbitron(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.8,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: CxColors.textSecondary,
                  side: const BorderSide(color: CxColors.borderSubtle),
                  minimumSize: const Size(double.infinity, 48),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
