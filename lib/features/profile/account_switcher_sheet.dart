import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/motion/cx_motion.dart';
import '../../core/providers/app_providers.dart';
import '../../core/theme/cx_theme.dart';
import '../../core/widgets/cx_components.dart';

const String _googleSvg = '''
<svg viewBox="0 0 24 24" width="24" height="24" xmlns="http://www.w3.org/2000/svg">
  <path fill="#4285F4" d="M23.745 12.27c0-.7-.06-1.4-.19-2.07H12v4.51h6.6c-.29 1.52-1.14 2.82-2.4 3.68v3.05h3.88c2.27-2.09 3.66-5.17 3.66-9.17z"/>
  <path fill="#34A853" d="M12 24c3.24 0 5.95-1.08 7.93-2.91l-3.88-3.05c-1.08.72-2.45 1.16-4.05 1.16-3.12 0-5.77-2.1-6.72-4.93H1.28v3.15C3.27 21.36 7.35 24 12 24z"/>
  <path fill="#FBBC05" d="M5.28 14.27c-.25-.72-.38-1.49-.38-2.27s.13-1.55.38-2.27V6.58H1.28C.46 8.21 0 10.05 0 12s.46 3.79 1.28 5.42l4-3.15z"/>
  <path fill="#EA4335" d="M12 4.75c1.77 0 3.35.61 4.6 1.8l3.42-3.42C17.95 1.19 15.24 0 12 0 7.35 0 3.27 2.64 1.28 6.58l4 3.15c.95-2.83 3.6-4.98 6.72-4.98z"/>
</svg>
''';

class AccountSwitcherSheet extends ConsumerWidget {
  const AccountSwitcherSheet({super.key});

  static void show(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => const AccountSwitcherSheet(),
    );
  }

  void _openAddAccountSheet(BuildContext context, WidgetRef ref) {
    Navigator.of(context).pop(); // Close switcher

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => const _AddAccountModalSheet(),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authProvider);
    final savedAccounts = auth.savedAccounts;
    final activeId = auth.activeAccountId;

    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF0F0F0F),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        border: Border(top: BorderSide(color: Color(0xFF262626), width: 1.2)),
      ),
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 14,
        bottom: MediaQuery.of(context).padding.bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 38,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFF333333),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'SWITCH ACCOUNT',
                style: GoogleFonts.orbitron(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.5,
                  color: CxColors.textPrimary,
                ),
              ),
              IconButton(
                icon: const Icon(
                  Icons.close,
                  color: CxColors.textSecondary,
                  size: 20,
                ),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Accounts List
          if (savedAccounts.isEmpty) ...[
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Text(
                'No additional saved accounts on this device.',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  color: CxColors.textSecondary,
                ),
              ),
            ),
          ] else ...[
            ...savedAccounts.map((account) {
              final isActive = account.id == activeId;

              return Padding(
                padding: const EdgeInsets.only(bottom: 8.0),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: isActive
                        ? null
                        : () async {
                            Navigator.pop(context);
                            await ref
                                .read(authProvider.notifier)
                                .switchAccount(account.id);
                            ref.invalidate(bootstrapProvider);
                            if (!context.mounted) return;
                            CxToast.show(
                              context,
                              message: 'Switched to @${account.username}',
                              type: CxToastType.success,
                            );
                          },
                    borderRadius: BorderRadius.circular(14),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isActive
                            ? const Color(0xFF161616)
                            : const Color(0xFF0C0C0C),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: isActive
                              ? CxColors.crimson.withOpacity(0.5)
                              : const Color(0xFF222222),
                          width: isActive ? 1.5 : 1.0,
                        ),
                      ),
                      child: Row(
                        children: [
                          CxAvatar(
                            name: account.fullName,
                            imageUrl: account.profileMediaUrl,
                            radius: 20,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(
                                      account.fullName,
                                      style: GoogleFonts.inter(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        color: CxColors.textPrimary,
                                      ),
                                    ),
                                    if (isActive) ...[
                                      const SizedBox(width: 6),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 6,
                                          vertical: 2,
                                        ),
                                        decoration: BoxDecoration(
                                          color: CxColors.crimson.withOpacity(
                                            0.2,
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            4,
                                          ),
                                        ),
                                        child: Text(
                                          'ACTIVE',
                                          style: GoogleFonts.orbitron(
                                            fontSize: 8,
                                            fontWeight: FontWeight.bold,
                                            color: CxColors.brightRed,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '@${account.username} • ${account.role}',
                                  style: GoogleFonts.inter(
                                    fontSize: 11,
                                    color: CxColors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (isActive)
                            const Icon(
                              Icons.check_circle,
                              color: CxColors.brightRed,
                              size: 20,
                            )
                          else
                            IconButton(
                              icon: const Icon(
                                Icons.remove_circle_outline,
                                color: Color(0xFF666666),
                                size: 18,
                              ),
                              onPressed: () async {
                                final confirmed = await CxConfirmDialog.show(
                                  context,
                                  title: 'REMOVE ACCOUNT',
                                  message:
                                      'Remove @${account.username} from this device?',
                                  confirmLabel: 'REMOVE',
                                  isDestructive: true,
                                );
                                if (confirmed == true) {
                                  await ref
                                      .read(authProvider.notifier)
                                      .removeAccount(account.id);
                                }
                              },
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            }),
          ],
          const SizedBox(height: 16),

          // Add Account Button
          CxScaleTap(
            onTap: () => _openAddAccountSheet(context, ref),
            child: Container(
              height: 48,
              decoration: BoxDecoration(
                color: const Color(0xFF141414),
                borderRadius: BorderRadius.circular(CxSpacing.buttonRadius),
                border: Border.all(
                  color: CxColors.crimson.withOpacity(0.4),
                  width: 1.2,
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.add, color: CxColors.brightRed, size: 18),
                  const SizedBox(width: 8),
                  Text(
                    'ADD CODEXA ACCOUNT',
                    style: GoogleFonts.orbitron(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.0,
                      color: CxColors.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AddAccountModalSheet extends ConsumerStatefulWidget {
  const _AddAccountModalSheet();

  @override
  ConsumerState<_AddAccountModalSheet> createState() =>
      _AddAccountModalSheetState();
}

class _AddAccountModalSheetState extends ConsumerState<_AddAccountModalSheet> {
  final _identifierCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _obscure = true;

  @override
  void dispose() {
    _identifierCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _handleStartAdd() async {
    final identifier = _identifierCtrl.text.trim();
    final password = _passwordCtrl.text;

    if (identifier.isEmpty || password.isEmpty) {
      CxToast.show(
        context,
        message: 'Please enter identifier and password.',
        type: CxToastType.warning,
      );
      return;
    }

    final success = await ref
        .read(authProvider.notifier)
        .startAddAccount(identifier, password);
    if (!mounted) return;

    if (success) {
      Navigator.pop(context); // Close add sheet
      context.push('/founder-otp');
    } else {
      final auth = ref.read(authProvider);
      CxToast.show(
        context,
        message: auth.errorMessage ?? 'Unable to add account.',
        type: CxToastType.error,
      );
    }
  }

  Future<void> _handleStartGoogleAdd() async {
    final success = await ref
        .read(authProvider.notifier)
        .startAddAccountWithGoogle();
    if (!mounted) return;

    if (success) {
      Navigator.pop(context); // Close add sheet
      context.push('/founder-otp');
    } else {
      final auth = ref.read(authProvider);
      if (auth.errorMessage != null) {
        CxToast.show(
          context,
          message: auth.errorMessage!,
          type: CxToastType.error,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);

    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF0F0F0F),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        border: Border(top: BorderSide(color: Color(0xFF262626), width: 1.2)),
      ),
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 14,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 38,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFF333333),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'ADD CODEXA ACCOUNT',
                  style: GoogleFonts.orbitron(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.2,
                    color: CxColors.textPrimary,
                  ),
                ),
                IconButton(
                  icon: const Icon(
                    Icons.close,
                    color: CxColors.textSecondary,
                    size: 20,
                  ),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 6),

            Text(
              'A 6-digit verification code will be dispatched to the verified email for this account.',
              style: GoogleFonts.inter(
                fontSize: 12,
                color: CxColors.textSecondary,
              ),
            ),
            const SizedBox(height: 18),

            // Google Option
            CxScaleTap(
              onTap: auth.isLoading ? null : _handleStartGoogleAdd,
              child: Container(
                height: 48,
                decoration: BoxDecoration(
                  color: const Color(0xFF141414),
                  borderRadius: BorderRadius.circular(CxSpacing.buttonRadius),
                  border: Border.all(color: const Color(0xFF2A2A2A)),
                ),
                child: Center(
                  child: auth.isLoading
                      ? const CxSignalLoader(size: 18)
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            SvgPicture.string(
                              _googleSvg,
                              width: 16,
                              height: 16,
                            ),
                            const SizedBox(width: 10),
                            Text(
                              'Add via Google Sign-In',
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: CxColors.textPrimary,
                              ),
                            ),
                          ],
                        ),
                ),
              ),
            ),
            const SizedBox(height: 16),

            Row(
              children: [
                Expanded(
                  child: Container(height: 1, color: const Color(0xFF222222)),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: Text(
                    'OR',
                    style: GoogleFonts.orbitron(
                      fontSize: 9,
                      color: const Color(0xFF666666),
                    ),
                  ),
                ),
                Expanded(
                  child: Container(height: 1, color: const Color(0xFF222222)),
                ),
              ],
            ),
            const SizedBox(height: 16),

            CxTextField(
              label: 'IDENTIFIER',
              hint: 'Email / Username / ID',
              controller: _identifierCtrl,
              prefixIcon: const Icon(
                Icons.person_outline,
                size: 18,
                color: CxColors.textSecondary,
              ),
            ),
            const SizedBox(height: 12),

            CxTextField(
              label: 'PASSWORD',
              hint: 'Account password',
              controller: _passwordCtrl,
              obscureText: _obscure,
              prefixIcon: const Icon(
                Icons.lock_outline,
                size: 18,
                color: CxColors.textSecondary,
              ),
              suffixIcon: IconButton(
                icon: Icon(
                  _obscure
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                  size: 18,
                  color: CxColors.textSecondary,
                ),
                onPressed: () => setState(() => _obscure = !_obscure),
              ),
            ),
            const SizedBox(height: 20),

            CxScaleTap(
              onTap: auth.isLoading ? null : _handleStartAdd,
              child: Container(
                height: 48,
                decoration: BoxDecoration(
                  color: CxColors.crimson,
                  borderRadius: BorderRadius.circular(CxSpacing.buttonRadius),
                ),
                child: Center(
                  child: auth.isLoading
                      ? const CxSignalLoader(size: 18)
                      : Text(
                          'CONTINUE TO VERIFICATION',
                          style: GoogleFonts.orbitron(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.0,
                            color: Colors.white,
                          ),
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
