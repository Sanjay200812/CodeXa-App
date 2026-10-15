import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/motion/cx_motion.dart';
import '../../core/providers/app_providers.dart';
import '../../core/theme/cx_theme.dart';
import '../../core/widgets/cx_components.dart';

class FounderOtpScreen extends ConsumerStatefulWidget {
  const FounderOtpScreen({super.key});

  @override
  ConsumerState<FounderOtpScreen> createState() => _FounderOtpScreenState();
}

class _FounderOtpScreenState extends ConsumerState<FounderOtpScreen> {
  final TextEditingController _otpController = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  Timer? _countdownTimer;
  int _secondsRemaining = 600; // 10 minutes
  int _resendCooldown = 45;
  Timer? _resendTimer;
  bool _canResend = false;

  @override
  void initState() {
    super.initState();
    _startCountdown();
    _startResendCooldown();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
  }

  void _startCountdown() {
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_secondsRemaining > 0) {
        if (mounted) setState(() => _secondsRemaining--);
      } else {
        timer.cancel();
      }
    });
  }

  void _startResendCooldown() {
    setState(() {
      _canResend = false;
      _resendCooldown = 45;
    });
    _resendTimer?.cancel();
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_resendCooldown > 0) {
        if (mounted) setState(() => _resendCooldown--);
      } else {
        if (mounted) setState(() => _canResend = true);
        timer.cancel();
      }
    });
  }

  String _formatTimer(int totalSeconds) {
    final minutes = totalSeconds ~/ 60;
    final seconds = totalSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _resendTimer?.cancel();
    _otpController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _handleVerify() async {
    final otp = _otpController.text.trim();
    if (otp.length != 6) {
      CxToast.show(
        context,
        message: 'Please enter the complete 6-digit verification code.',
        type: CxToastType.warning,
      );
      return;
    }

    final success = await ref
        .read(authProvider.notifier)
        .verifyAddAccountOtp(otp);
    if (!mounted) return;

    if (success) {
      CxToast.show(
        context,
        message: 'Account added successfully!',
        type: CxToastType.success,
      );
      context.go('/home');
    } else {
      final auth = ref.read(authProvider);
      CxToast.show(
        context,
        message: auth.errorMessage ?? 'Verification failed.',
        type: CxToastType.error,
      );
    }
  }

  Future<void> _handleResend() async {
    if (!_canResend) return;
    final success = await ref.read(authProvider.notifier).resendFounderOtp();
    if (!mounted) return;

    if (success) {
      CxToast.show(
        context,
        message: 'A fresh verification code was sent to your verified email.',
        type: CxToastType.info,
      );
      _startResendCooldown();
    } else {
      final auth = ref.read(authProvider);
      CxToast.show(
        context,
        message: auth.errorMessage ?? 'Could not resend verification code.',
        type: CxToastType.error,
      );
    }
  }

  void _handleCancel() {
    ref.read(authProvider.notifier).cancelFounderOtp();
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    } else {
      context.go('/home');
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);
    final candidate = auth.candidateUser;
    final maskedEmail = auth.maskedFounderEmail ?? 'your verified email';

    return CxScaffold(
      showCyberBackground: true,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // CodeXa Emblem
              Center(
                child: Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFF0F0F0F),
                    border: Border.all(
                      color: CxColors.brightRed.withOpacity(0.6),
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: CxColors.crimson.withOpacity(0.35),
                        blurRadius: 18,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: ClipOval(
                    child: Image.asset(
                      'assets/images/codexa_logo.png',
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) =>
                          Image.asset('icon.png', fit: BoxFit.cover),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              Text(
                'ACCOUNT VERIFICATION',
                textAlign: TextAlign.center,
                style: GoogleFonts.orbitron(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 2.0,
                  color: CxColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),

              Text(
                'Enter the 6-digit verification code sent to this account\'s verified email address.',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  color: CxColors.textSecondary,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 24),

              // Candidate Account Card
              if (candidate != null) ...[
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F0F0F),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFF222222)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: CxColors.cardElevated,
                          border: Border.all(
                            color: CxColors.crimson.withOpacity(0.4),
                          ),
                        ),
                        child: Center(
                          child: Text(
                            (candidate['fullName'] ??
                                    candidate['username'] ??
                                    'U')[0]
                                .toUpperCase(),
                            style: GoogleFonts.orbitron(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: CxColors.brightRed,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              candidate['fullName'] ??
                                  candidate['username'] ??
                                  '',
                              style: GoogleFonts.inter(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: CxColors.textPrimary,
                              ),
                            ),
                            Text(
                              '@${candidate['username'] ?? ''} • ${candidate['role'] ?? 'MEMBER'}',
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                color: CxColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // Sent to notification
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: CxColors.crimson.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: CxColors.crimson.withOpacity(0.25)),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.mark_email_read_outlined,
                      size: 18,
                      color: CxColors.brightRed,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Verification code dispatched to:\n$maskedEmail',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: CxColors.textPrimary,
                          height: 1.3,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // 6-Digit OTP Field
              GestureDetector(
                onTap: () => _focusNode.requestFocus(),
                child: AnimatedBuilder(
                  animation: _otpController,
                  builder: (context, _) {
                    final text = _otpController.text;
                    return Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: List.generate(6, (index) {
                        final isFilled = index < text.length;
                        final isCurrent = index == text.length;
                        final char = isFilled ? text[index] : '';

                        return Container(
                          width: 48,
                          height: 54,
                          decoration: BoxDecoration(
                            color: const Color(0xFF111111),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: isCurrent
                                  ? CxColors.brightRed
                                  : isFilled
                                  ? CxColors.crimson.withOpacity(0.6)
                                  : const Color(0xFF2A2A2A),
                              width: isCurrent ? 2.0 : 1.2,
                            ),
                            boxShadow: isCurrent
                                ? [
                                    BoxShadow(
                                      color: CxColors.brightRed.withOpacity(
                                        0.3,
                                      ),
                                      blurRadius: 8,
                                    ),
                                  ]
                                : null,
                          ),
                          child: Center(
                            child: Text(
                              char,
                              style: GoogleFonts.orbitron(
                                fontSize: 22,
                                fontWeight: FontWeight.w700,
                                color: CxColors.textPrimary,
                              ),
                            ),
                          ),
                        );
                      }),
                    );
                  },
                ),
              ),

              // Invisible real text field for keyboard handling
              Opacity(
                opacity: 0.0,
                child: SizedBox(
                  height: 1,
                  child: TextField(
                    controller: _otpController,
                    focusNode: _focusNode,
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(6),
                    ],
                    onChanged: (val) {
                      setState(() {});
                      if (val.length == 6) {
                        _handleVerify();
                      }
                    },
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Timer
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.timer_outlined,
                    size: 16,
                    color: CxColors.textSecondary,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Code expires in ${_formatTimer(_secondsRemaining)}',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: _secondsRemaining < 60
                          ? CxColors.brightRed
                          : CxColors.textSecondary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Verify CTA
              CxScaleTap(
                onTap: auth.isLoading ? null : _handleVerify,
                child: Container(
                  height: 52,
                  decoration: BoxDecoration(
                    color: CxColors.crimson,
                    borderRadius: BorderRadius.circular(CxSpacing.buttonRadius),
                    boxShadow: [
                      BoxShadow(
                        color: CxColors.crimson.withOpacity(0.4),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Center(
                    child: auth.isLoading
                        ? const CxSignalLoader(size: 20)
                        : Text(
                            'VERIFY & ADD ACCOUNT',
                            style: GoogleFonts.orbitron(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1.5,
                              color: Colors.white,
                            ),
                          ),
                  ),
                ),
              ),
              const SizedBox(height: 14),

              // Resend & Cancel
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TextButton(
                    onPressed: _handleCancel,
                    child: Text(
                      'Cancel',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: CxColors.textSecondary,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: _canResend ? _handleResend : null,
                    child: Text(
                      _canResend
                          ? 'Resend Code'
                          : 'Resend in ${_resendCooldown}s',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: _canResend
                            ? CxColors.brightRed
                            : const Color(0xFF666666),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
