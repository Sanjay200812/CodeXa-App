import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/motion/cx_motion.dart';
import '../../core/providers/app_providers.dart';
import '../../core/theme/cx_theme.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _glowAnimation;
  late Animation<double> _scaleAnimation;
  late Animation<double> _opacityAnimation;
  late Animation<double> _cyberLinesAnimation;
  late Animation<double> _sweepAnimation;

  bool _isNavigating = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );

    // Phase 1 & 2: Cyber lines trace outward
    _cyberLinesAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.35, curve: Curves.easeOutCubic),
      ),
    );

    // Phase 3: Logo convergence and reveal (scale 0.82 -> 1.0, opacity 0 -> 1)
    _opacityAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.2, 0.7, curve: Curves.easeIn),
      ),
    );

    _scaleAnimation = Tween<double>(begin: 0.82, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.25, 0.8, curve: Curves.easeOutCubic),
      ),
    );

    // Phase 4: Controlled glow & sweep
    _glowAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.4, 0.9, curve: Curves.easeInOut),
      ),
    );

    _sweepAnimation = Tween<double>(begin: -1.0, end: 2.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.55, 1.0, curve: Curves.easeInOutCubic),
      ),
    );

    _controller.forward();
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    // Wait for minimum aesthetic transition (at least 1200ms)
    // while running real session validation
    final animationFuture = Future.delayed(const Duration(milliseconds: 1300));
    final sessionFuture = ref.read(authProvider.notifier).checkInitialSession();

    await Future.wait([animationFuture, sessionFuture]);

    if (!mounted || _isNavigating) return;
    _isNavigating = true;

    final auth = ref.read(authProvider);

    if (auth.mustChangePassword) {
      context.go('/password-change');
    } else if (auth.isAuthenticated) {
      context.go('/home');
    } else {
      context.go('/login');
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF070707),
      body: Stack(
        children: [
          // Subtle Cyber Grid
          Positioned.fill(
            child: CustomPaint(painter: _SplashCyberGridPainter()),
          ),

          // Central Cinematic Sequence
          Center(
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, child) {
                return Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Convergence Ring & Logo Emblem
                    Stack(
                      alignment: Alignment.center,
                      children: [
                        // Cyber geometric tracer lines
                        CustomPaint(
                          size: const Size(180, 180),
                          painter: _CyberTracerPainter(
                            progress: _cyberLinesAnimation.value,
                            glow: _glowAnimation.value,
                          ),
                        ),

                        // Logo Container
                        Opacity(
                          opacity: _opacityAnimation.value,
                          child: Transform.scale(
                            scale: _scaleAnimation.value,
                            child: Container(
                              width: 100,
                              height: 100,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: const Color(0xFF0C0C0C),
                                border: Border.all(
                                  color: CxColors.brightRed.withOpacity(
                                    (_glowAnimation.value * 0.85).clamp(
                                      0.2,
                                      1.0,
                                    ),
                                  ),
                                  width: 2.0,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: CxColors.crimson.withOpacity(
                                      (_glowAnimation.value * 0.45).clamp(
                                        0.0,
                                        1.0,
                                      ),
                                    ),
                                    blurRadius: 32 * _glowAnimation.value,
                                    spreadRadius: 2,
                                  ),
                                ],
                              ),
                              child: ClipOval(
                                child: Stack(
                                  fit: StackFit.expand,
                                  children: [
                                    // High-resolution real CodeXa logo
                                    Padding(
                                      padding: const EdgeInsets.all(12.0),
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

                                    // Crimson Energy Sweep Overlay
                                    if (_sweepAnimation.value >= 0.0 &&
                                        _sweepAnimation.value <= 1.0)
                                      Positioned.fill(
                                        child: Transform.rotate(
                                          angle: math.pi / 4,
                                          child: FractionallySizedBox(
                                            widthFactor: 0.35,
                                            child: Container(
                                              decoration: BoxDecoration(
                                                gradient: LinearGradient(
                                                  colors: [
                                                    Colors.transparent,
                                                    CxColors.brightRed
                                                        .withOpacity(0.4),
                                                    Colors.transparent,
                                                  ],
                                                ),
                                              ),
                                            ),
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
                    const SizedBox(height: 28),

                    // CodeXa Wordmark Title
                    Opacity(
                      opacity: _opacityAnimation.value,
                      child: Column(
                        children: [
                          Text(
                            'CODEXA',
                            style: GoogleFonts.orbitron(
                              fontSize: 26,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 4.5,
                              color: CxColors.textPrimary,
                              shadows: [
                                Shadow(
                                  color: CxColors.crimson.withOpacity(
                                    _glowAnimation.value * 0.4,
                                  ),
                                  blurRadius: 16,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'TEAM WORKSPACE',
                            style: GoogleFonts.inter(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 3.5,
                              color: CxColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 48),

                    // Unique CodeXa Signal Loader
                    Opacity(
                      opacity: (_opacityAnimation.value * 0.9).clamp(0.0, 1.0),
                      child: const CxSignalLoader(
                        size: 24,
                        label: 'INITIALIZING CODEXA',
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// Geometric cyber line painter that traces outward
class _CyberTracerPainter extends CustomPainter {
  final double progress;
  final double glow;

  _CyberTracerPainter({required this.progress, required this.glow});

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0) return;

    final center = Offset(size.width / 2, size.height / 2);
    final paint = Paint()
      ..color = CxColors.crimson.withOpacity(0.35 * progress)
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke;

    final glowPaint = Paint()
      ..color = CxColors.brightRed.withOpacity(0.2 * glow)
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;

    final radius = (size.width / 2) * progress;

    // Corner targeting lines
    const double lineLen = 16.0;
    canvas.drawLine(
      Offset(center.dx - radius, center.dy),
      Offset(center.dx - radius + lineLen, center.dy),
      paint,
    );
    canvas.drawLine(
      Offset(center.dx + radius, center.dy),
      Offset(center.dx + radius - lineLen, center.dy),
      paint,
    );
    canvas.drawLine(
      Offset(center.dx, center.dy - radius),
      Offset(center.dx, center.dy - radius + lineLen),
      paint,
    );
    canvas.drawLine(
      Offset(center.dx, center.dy + radius),
      Offset(center.dx, center.dy + radius - lineLen),
      paint,
    );

    // Subtle framing circle
    canvas.drawCircle(center, radius * 0.85, glowPaint);
  }

  @override
  bool shouldRepaint(covariant _CyberTracerPainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.glow != glow;
}

class _SplashCyberGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0x07D90429)
      ..strokeWidth = 1.0;

    const double step = 32.0;
    for (double x = 0; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
