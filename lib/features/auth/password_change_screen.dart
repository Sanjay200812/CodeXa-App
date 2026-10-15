import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/providers/app_providers.dart';
import '../../core/theme/cx_theme.dart';
import '../../core/widgets/cx_components.dart';

class PasswordChangeScreen extends ConsumerStatefulWidget {
  const PasswordChangeScreen({super.key});

  @override
  ConsumerState<PasswordChangeScreen> createState() =>
      _PasswordChangeScreenState();
}

class _PasswordChangeScreenState extends ConsumerState<PasswordChangeScreen> {
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _obscurePassword = true;

  @override
  void dispose() {
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _handlePasswordUpdate() async {
    final newPass = _newPasswordController.text;
    final confirmPass = _confirmPasswordController.text;

    if (newPass.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Password must be at least 6 characters.'),
          backgroundColor: CxColors.error,
        ),
      );
      return;
    }

    if (newPass != confirmPass) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Passwords do not match.'),
          backgroundColor: CxColors.error,
        ),
      );
      return;
    }

    final success = await ref
        .read(authProvider.notifier)
        .changePassword(newPass, confirmPass);
    if (!mounted) return;

    if (success) {
      context.go('/home');
    } else {
      final auth = ref.read(authProvider);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(auth.errorMessage ?? 'Failed to update password.'),
          backgroundColor: CxColors.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);

    return CxScaffold(
      showCyberBackground: true,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: CxSpacing.xl),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Icon(Icons.security, size: 48, color: CxColors.brightRed),
              const SizedBox(height: CxSpacing.md),
              Text(
                'SET YOUR NEW PASSWORD',
                textAlign: TextAlign.center,
                style: GoogleFonts.orbitron(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: CxColors.textPrimary,
                  letterSpacing: 0.8,
                ),
              ),
              const SizedBox(height: CxSpacing.xs),
              Text(
                'Your account requires a new personal password before you can proceed to the workspace.',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  color: CxColors.textSecondary,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: CxSpacing.xxl),
              CxCard(
                padding: const EdgeInsets.all(CxSpacing.xl),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    CxTextField(
                      label: 'NEW PASSWORD',
                      hint: 'Minimum 6 characters',
                      controller: _newPasswordController,
                      obscureText: _obscurePassword,
                      prefixIcon: const Icon(
                        Icons.lock_outline,
                        size: 20,
                        color: CxColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: CxSpacing.lg),
                    CxTextField(
                      label: 'CONFIRM NEW PASSWORD',
                      hint: 'Re-enter your new password',
                      controller: _confirmPasswordController,
                      obscureText: _obscurePassword,
                      prefixIcon: const Icon(
                        Icons.lock_reset,
                        size: 20,
                        color: CxColors.textSecondary,
                      ),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscurePassword
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                          size: 20,
                          color: CxColors.textSecondary,
                        ),
                        onPressed: () => setState(
                          () => _obscurePassword = !_obscurePassword,
                        ),
                      ),
                    ),
                    const SizedBox(height: CxSpacing.xl),
                    CxButton(
                      label: 'UPDATE PASSWORD & PROCEED',
                      isLoading: auth.isLoading,
                      onPressed: auth.isLoading ? null : _handlePasswordUpdate,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
