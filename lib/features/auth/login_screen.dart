import 'dart:math' as math;

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

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen>
    with SingleTickerProviderStateMixin {
  final _identifierController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;

  late AnimationController _entranceCtrl;
  late Animation<double> _fractureLines;
  late Animation<double> _logoResolve;
  late Animation<double> _scanSweep;
  late Animation<double> _formEntrance;

  @override
  void initState() {
    super.initState();
    _entranceCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 950),
    );

    // 1. Fracture lines converge (0ms - 300ms)
    _fractureLines = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _entranceCtrl,
        curve: const Interval(0.0, 0.35, curve: Curves.easeInCubic),
      ),
    );

    // 2. Logo sharp resolve (250ms - 650ms)
    _logoResolve = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _entranceCtrl,
        curve: const Interval(0.25, 0.65, curve: Curves.easeOutBack),
      ),
    );

    // 3. Scan line sweep (450ms - 750ms)
    _scanSweep = Tween<double>(begin: -0.5, end: 1.5).animate(
      CurvedAnimation(
        parent: _entranceCtrl,
        curve: const Interval(0.45, 0.75, curve: Curves.easeInOut),
      ),
    );

    // 4. Form entrance fade + slide (600ms - 950ms)
    _formEntrance = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _entranceCtrl,
        curve: const Interval(0.60, 1.0, curve: Curves.easeOutCubic),
      ),
    );

    _entranceCtrl.forward();
  }

  @override
  void dispose() {
    _entranceCtrl.dispose();
    _identifierController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleGoogleLogin() async {
    final success = await ref.read(authProvider.notifier).loginWithGoogle();
    if (!mounted) return;

    final auth = ref.read(authProvider);

    if (auth.mustChangePassword) {
      context.go('/password-change');
    } else if (success) {
      CxToast.show(
        context,
        message:
            'Welcome to CodeXa, ${auth.user?.fullName ?? auth.user?.username ?? "Workspace"}!',
        type: CxToastType.success,
      );
      context.go('/home');
    } else if (auth.errorMessage != null) {
      CxToast.show(
        context,
        message: auth.errorMessage!,
        type: CxToastType.error,
      );
    }
  }

  Future<void> _handleLogin() async {
    final identifier = _identifierController.text.trim();
    final password = _passwordController.text;

    if (identifier.isEmpty || password.isEmpty) {
      CxToast.show(
        context,
        message: 'Please enter your identifier and password.',
        type: CxToastType.warning,
      );
      return;
    }

    final success = await ref
        .read(authProvider.notifier)
        .login(identifier, password);
    if (!mounted) return;

    final auth = ref.read(authProvider);

    if (auth.mustChangePassword) {
      context.go('/password-change');
    } else if (success) {
      CxToast.show(
        context,
        message:
            'Welcome back, ${auth.user?.fullName ?? auth.user?.username ?? "User"}!',
        type: CxToastType.success,
      );
      context.go('/home');
    } else if (auth.errorMessage != null) {
      CxToast.show(
        context,
        message: auth.errorMessage!,
        type: CxToastType.error,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);

    return Scaffold(
      backgroundColor: const Color(0xFF070707),
      body: SafeArea(
        child: AnimatedBuilder(
          animation: _entranceCtrl,
          builder: (context, child) {
            return Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 16,
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Convergence / Fracture Animation Layer + Logo
                    Center(
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          // Converging fracture lines
                          if (_fractureLines.value > 0.05)
                            CustomPaint(
                              size: const Size(120, 120),
                              painter: _FractureLinesPainter(
                                amount: _fractureLines.value,
                              ),
                            ),

                          // Real CodeXa Logo Emblem
                          Transform.scale(
                            scale: 0.85 + (0.15 * _logoResolve.value),
                            child: Opacity(
                              opacity: _logoResolve.value.clamp(0.0, 1.0),
                              child: Container(
                                width: 76,
                                height: 76,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: const Color(0xFF0D0D0D),
                                  border: Border.all(
                                    color: CxColors.brightRed.withOpacity(0.7),
                                    width: 1.5,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: CxColors.crimson.withOpacity(
                                        0.4 * _logoResolve.value,
                                      ),
                                      blurRadius: 24,
                                      spreadRadius: 2,
                                    ),
                                  ],
                                ),
                                child: ClipOval(
                                  child: Stack(
                                    fit: StackFit.expand,
                                    children: [
                                      Padding(
                                        padding: const EdgeInsets.all(10.0),
                                        child: Image.asset(
                                          'assets/images/codexa_logo.png',
                                          fit: BoxFit.contain,
                                          errorBuilder: (_, __, ___) =>
                                              Image.asset(
                                                'icon.png',
                                                fit: BoxFit.contain,
                                              ),
                                        ),
                                      ),
                                      // Laser scan line
                                      if (_scanSweep.value >= 0.0 &&
                                          _scanSweep.value <= 1.0)
                                        Positioned(
                                          top: _scanSweep.value * 76,
                                          left: 0,
                                          right: 0,
                                          child: Container(
                                            height: 2,
                                            decoration: const BoxDecoration(
                                              color: CxColors.brightRed,
                                              boxShadow: [
                                                BoxShadow(
                                                  color: CxColors.brightRed,
                                                  blurRadius: 6,
                                                  spreadRadius: 1,
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Branding Header
                    Opacity(
                      opacity: _logoResolve.value.clamp(0.0, 1.0),
                      child: Column(
                        children: [
                          Text(
                            'CODEXA',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.orbitron(
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              color: CxColors.textPrimary,
                              letterSpacing: 3.0,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'TEAM WORKSPACE',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.inter(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: CxColors.textSecondary,
                              letterSpacing: 2.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 28),

                    // Staggered Form Entrance
                    Transform.translate(
                      offset: Offset(0, 16 * (1.0 - _formEntrance.value)),
                      child: Opacity(
                        opacity: _formEntrance.value.clamp(0.0, 1.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // Welcome Copy
                            Text(
                              'Welcome back',
                              style: GoogleFonts.orbitron(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: CxColors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Sign in to access your daily enterprise workspace.',
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                color: CxColors.textSecondary,
                              ),
                            ),
                            const SizedBox(height: 20),

                            // Continue with Google Button
                            CxScaleTap(
                              onTap: auth.isLoading ? null : _handleGoogleLogin,
                              child: Container(
                                height: 50,
                                decoration: BoxDecoration(
                                  color: const Color(0xFF111111),
                                  borderRadius: BorderRadius.circular(
                                    CxSpacing.buttonRadius,
                                  ),
                                  border: Border.all(
                                    color: const Color(0xFF262626),
                                    width: 1.2,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.4),
                                      blurRadius: 10,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: Center(
                                  child: auth.isLoading
                                      ? const CxSignalLoader(size: 20)
                                      : Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            SvgPicture.string(
                                              _googleSvg,
                                              width: 18,
                                              height: 18,
                                            ),
                                            const SizedBox(width: 12),
                                            Text(
                                              'Continue with Google',
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
                            const SizedBox(height: 20),

                            // Divider
                            Row(
                              children: [
                                Expanded(
                                  child: Container(
                                    height: 1,
                                    color: const Color(0xFF222222),
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                  ),
                                  child: Text(
                                    'OR WITH CODEXA ID',
                                    style: GoogleFonts.orbitron(
                                      fontSize: 9,
                                      fontWeight: FontWeight.w600,
                                      color: const Color(0xFF666666),
                                      letterSpacing: 1.2,
                                    ),
                                  ),
                                ),
                                Expanded(
                                  child: Container(
                                    height: 1,
                                    color: const Color(0xFF222222),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 20),

                            // Input Card
                            Container(
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                color: const Color(0xFF0C0C0C),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: CxColors.crimson.withOpacity(0.18),
                                  width: 1.2,
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  // Identifier
                                  CxTextField(
                                    label: 'IDENTIFIER',
                                    hint: 'Email / Username / Employee ID / Intern ID',
                                    controller: _identifierController,
                                    prefixIcon: const Icon(
                                      Icons.person_outline,
                                      size: 18,
                                      color: CxColors.textSecondary,
                                    ),
                                  ),
                                  const SizedBox(height: 16),

                                  // Password
                                  CxTextField(
                                    label: 'PASSWORD',
                                    hint: 'Enter your password',
                                    controller: _passwordController,
                                    obscureText: _obscurePassword,
                                    prefixIcon: const Icon(
                                      Icons.lock_outline,
                                      size: 18,
                                      color: CxColors.textSecondary,
                                    ),
                                    suffixIcon: IconButton(
                                      icon: Icon(
                                        _obscurePassword
                                            ? Icons.visibility_outlined
                                            : Icons.visibility_off_outlined,
                                        size: 18,
                                        color: CxColors.textSecondary,
                                      ),
                                      onPressed: () => setState(
                                        () => _obscurePassword =
                                            !_obscurePassword,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 22),

                                  // Login CTA Button
                                  CxScaleTap(
                                    onTap: auth.isLoading ? null : _handleLogin,
                                    child: Container(
                                      height: 48,
                                      decoration: BoxDecoration(
                                        color: CxColors.crimson,
                                        borderRadius: BorderRadius.circular(
                                          CxSpacing.buttonRadius,
                                        ),
                                        boxShadow: [
                                          BoxShadow(
                                            color: CxColors.crimson.withOpacity(
                                              0.4,
                                            ),
                                            blurRadius: 14,
                                            offset: const Offset(0, 4),
                                          ),
                                        ],
                                      ),
                                      child: Center(
                                        child: auth.isLoading
                                            ? const CxSignalLoader(size: 20)
                                            : Text(
                                                'LOGIN',
                                                style: GoogleFonts.orbitron(
                                                  fontSize: 13,
                                                  fontWeight: FontWeight.w700,
                                                  letterSpacing: 2.0,
                                                  color: Colors.white,
                                                ),
                                              ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 24),

                            // Footer note
                            Center(
                              child: Text(
                                'CodeXa Native Security • Zero Trust Architecture',
                                style: GoogleFonts.inter(
                                  fontSize: 10,
                                  color: const Color(0xFF555555),
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                          ],
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
    );
  }
}

/// Canvas painter for thin crimson geometric fracture lines converging to center
class _FractureLinesPainter extends CustomPainter {
  final double amount; // 1.0 (scattered) to 0.0 (converged)

  _FractureLinesPainter({required this.amount});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = CxColors.brightRed.withOpacity((amount * 0.45).clamp(0.0, 1.0))
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;

    final cx = size.width / 2;
    final cy = size.height / 2;
    final radius = 55.0 * amount;

    // Draw 4 cyber shard lines converging
    for (int i = 0; i < 4; i++) {
      final angle = (i * math.pi / 2) + (math.pi / 4);
      final p1 = Offset(
        cx + math.cos(angle) * radius,
        cy + math.sin(angle) * radius,
      );
      final p2 = Offset(
        cx + math.cos(angle) * (radius + 20 * amount),
        cy + math.sin(angle) * (radius + 20 * amount),
      );
      canvas.drawLine(p1, p2, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _FractureLinesPainter oldDelegate) =>
      oldDelegate.amount != amount;
}
