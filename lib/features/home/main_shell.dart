import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/navigation/cx_liquid_glass_bar.dart';
import '../../core/navigation/cx_navigation_controller.dart';
import '../../core/navigation/cx_root_page_view.dart';
import '../../core/providers/app_providers.dart';
import '../../core/theme/cx_theme.dart';
import '../../core/widgets/cx_components.dart';

class MainShell extends ConsumerStatefulWidget {
  final Widget child;

  const MainShell({super.key, required this.child});

  @override
  ConsumerState<MainShell> createState() => _MainShellState();
}

class _MainShellState extends ConsumerState<MainShell> {
  late final CodeXaNavigationController _navigationController;

  final List<String> _routes = [
    '/home',
    '/attendance',
    '/messages',
    '/feed',
    '/projects',
  ];

  @override
  void initState() {
    super.initState();
    _navigationController = CodeXaNavigationController(
      initialIndex: 0,
      onTabCommitted: (index) {
        if (mounted) {
          context.go(_routes[index]);
        }
      },
    );
  }

  @override
  void dispose() {
    _navigationController.dispose();
    super.dispose();
  }

  int _calculateSelectedIndex(BuildContext context) {
    final location = GoRouterState.of(context).matchedLocation;
    if (location.startsWith('/home')) return 0;
    if (location.startsWith('/attendance')) return 1;
    if (location.startsWith('/messages')) return 2;
    if (location.startsWith('/feed')) return 3;
    if (location.startsWith('/projects')) return 4;
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final routeIndex = _calculateSelectedIndex(context);
    _navigationController.syncWithRouteIndex(routeIndex);

    final bootstrapAsync = ref.watch(bootstrapProvider);
    final unreadNotifs = bootstrapAsync.valueOrNull?.unreadNotifications ?? 0;
    final user =
        bootstrapAsync.valueOrNull?.user ?? ref.watch(authProvider).user;

    return Scaffold(
      backgroundColor: CxColors.background,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(60.0),
        child: Container(
          decoration: const BoxDecoration(
            color: Color(0xFF070707),
            border: Border(
              bottom: BorderSide(color: Color(0x22FFFFFF), width: 0.8),
            ),
          ),
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: CxSpacing.lg),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Brand Logo & Wordmark
                  Row(
                    children: [
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: CxColors.cardElevated,
                          border: Border.all(
                            color: CxColors.brightRed.withOpacity(0.6),
                            width: 1.2,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: CxColors.crimson.withOpacity(0.3),
                              blurRadius: 8,
                            ),
                          ],
                        ),
                        child: ClipOval(
                          child: Padding(
                            padding: const EdgeInsets.all(4.0),
                            child: Image.asset(
                              'assets/images/codexa_logo.png',
                              fit: BoxFit.contain,
                              errorBuilder: (_, __, ___) =>
                                  Image.asset('icon.png', fit: BoxFit.contain),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: CxSpacing.sm),
                      Text(
                        'CODEXA',
                        style: GoogleFonts.orbitron(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 2.0,
                          color: CxColors.textPrimary,
                        ),
                      ),
                    ],
                  ),

                  // Top Right: Liquid Glass Search, Notifications & Avatar
                  Row(
                    children: [
                      CodeXaGlassButton(
                        icon: Icons.search,
                        width: 40,
                        height: 40,
                        borderRadius: 12,
                        padding: EdgeInsets.zero,
                        onPressed: () => context.push('/search'),
                        accessibilityLabel: 'Global Search',
                      ),
                      const SizedBox(width: CxSpacing.xs),
                      CodeXaGlassButton(
                        icon: Icons.notifications_none,
                        width: 40,
                        height: 40,
                        borderRadius: 12,
                        padding: EdgeInsets.zero,
                        badgeCount: unreadNotifs,
                        onPressed: () => context.push('/notifications'),
                        accessibilityLabel: 'Notifications',
                      ),
                      const SizedBox(width: CxSpacing.sm),
                      GestureDetector(
                        onTap: () => context.push('/profile'),
                        child: CxAvatar(
                          name:
                              user?.fullName ?? user?.username ?? 'CodeXa User',
                          imageUrl: user?.profileMediaUrl,
                          radius: 17,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      // Synchronized 5-Tab Root PageView (Mode B full screen swipe + state preservation)
      body: CodeXaRootPageView(controller: _navigationController),
      // Frosted Liquid Glass Floating Navigation Bar (Mode A press-and-drag scrubbing + safe area)
      bottomNavigationBar: CodeXaLiquidGlassBar(
        controller: _navigationController,
      ),
    );
  }
}
