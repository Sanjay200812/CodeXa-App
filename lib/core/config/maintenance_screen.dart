import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../theme/cx_theme.dart';
import '../widgets/cx_components.dart';

class MaintenanceScreen extends StatelessWidget {
  final String title;
  final String message;
  final String? expectedEndAt;
  final VoidCallback onRetry;
  final bool isRetrying;

  const MaintenanceScreen({
    super.key,
    required this.title,
    required this.message,
    this.expectedEndAt,
    required this.onRetry,
    this.isRetrying = false,
  });

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
                width: 76,
                height: 76,
                decoration: BoxDecoration(
                  color: CxColors.crimson.withAlpha(25),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: CxColors.crimson.withAlpha(120),
                    width: 1.5,
                  ),
                ),
                child: const Icon(
                  Icons.build_circle_outlined,
                  color: CxColors.crimson,
                  size: 40,
                ),
              ),
              const SizedBox(height: CxSpacing.xl),
              Text(
                title.toUpperCase(),
                style: GoogleFonts.orbitron(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 2.0,
                  color: CxColors.textPrimary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: CxSpacing.sm),
              Text(
                message,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  color: CxColors.textSecondary,
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
              if (expectedEndAt != null && expectedEndAt!.isNotEmpty) ...[
                const SizedBox(height: CxSpacing.lg),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: CxColors.card,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: CxColors.borderSubtle),
                  ),
                  child: Text(
                    'EXPECTED RESTORATION: $expectedEndAt',
                    style: GoogleFonts.orbitron(
                      fontSize: 10,
                      color: CxColors.accent,
                      letterSpacing: 0.8,
                    ),
                  ),
                ),
              ],
              const Spacer(),
              CxButton(
                label: 'TRY AGAIN',
                icon: Icons.refresh_rounded,
                isLoading: isRetrying,
                onPressed: onRetry,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
