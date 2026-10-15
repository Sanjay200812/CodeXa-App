import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'cx_navigation_controller.dart';

class CodeXaNavItemData {
  final IconData icon;
  final IconData activeIcon;
  final String label;

  const CodeXaNavItemData({
    required this.icon,
    required this.activeIcon,
    required this.label,
  });
}

/// iPhone-inspired Liquid Glass Bottom Navigation Bar with CodeXa Crimson/Black Styling.
/// Supports continuous press-and-drag scrubbing and synchronized full-screen swiping.
class CodeXaLiquidGlassBar extends StatelessWidget {
  final CodeXaNavigationController controller;

  static const List<CodeXaNavItemData> items = [
    CodeXaNavItemData(
      icon: Icons.home_outlined,
      activeIcon: Icons.home,
      label: 'Home',
    ),
    CodeXaNavItemData(
      icon: Icons.access_time,
      activeIcon: Icons.alarm_on,
      label: 'Attendance',
    ),
    CodeXaNavItemData(
      icon: Icons.chat_bubble_outline,
      activeIcon: Icons.chat_bubble,
      label: 'Messages',
    ),
    CodeXaNavItemData(
      icon: Icons.dynamic_feed_outlined,
      activeIcon: Icons.dynamic_feed,
      label: 'Feed',
    ),
    CodeXaNavItemData(
      icon: Icons.folder_outlined,
      activeIcon: Icons.folder,
      label: 'Projects',
    ),
  ];

  const CodeXaLiquidGlassBar({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    // 1. Android SafeArea & Three-Button Navigation Handling
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    final keyboardInset = MediaQuery.viewInsetsOf(context).bottom;

    // Disappear cleanly when soft keyboard is opened
    if (keyboardInset > 0) {
      return const SizedBox.shrink();
    }

    // Clearance for Android 3-button navigation (usually 48dp) vs gesture bar (16-24dp)
    final bottomClearance = bottomInset > 0 ? bottomInset + 8.0 : 12.0;

    return Padding(
      padding: EdgeInsets.only(
        left: 14.0,
        right: 14.0,
        top: 2.0,
        bottom: bottomClearance,
      ),
      child: AnimatedBuilder(
        animation: controller,
        builder: (context, _) {
          return LayoutBuilder(
            builder: (context, constraints) {
              final totalWidth = constraints.maxWidth;
              final tabWidth = totalWidth / items.length;
              final capsuleWidth = tabWidth - 8.0;
              final capsuleLeft =
                  (controller.fractionalIndex * tabWidth) +
                  (tabWidth - capsuleWidth) / 2;

              return Listener(
                onPointerDown: (e) =>
                    controller.onNavBarPointerDown(e, totalWidth),
                onPointerMove: (e) =>
                    controller.onNavBarPointerMove(e, totalWidth),
                onPointerUp: (e) => controller.onNavBarPointerUp(e, totalWidth),
                onPointerCancel: controller.onNavBarPointerCancel,
                child: Container(
                  height: 66.0,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(24.0),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.55),
                        blurRadius: 20.0,
                        spreadRadius: 2.0,
                        offset: const Offset(0, 8),
                      ),
                      BoxShadow(
                        color: const Color(0xFFD90429).withOpacity(0.08),
                        blurRadius: 16.0,
                        spreadRadius: 1.0,
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(24.0),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 18.0, sigmaY: 18.0),
                      child: Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFF0C0C0C).withOpacity(0.85),
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              const Color(0xFF161616).withOpacity(0.92),
                              const Color(0xFF090909).withOpacity(0.88),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(24.0),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.12),
                            width: 1.0,
                          ),
                        ),
                        child: Stack(
                          children: [
                            // 2. Active Liquid Glass Sliding Selection Capsule
                            Positioned(
                              left: capsuleLeft.clamp(
                                4.0,
                                totalWidth - capsuleWidth - 4.0,
                              ),
                              top: 6.0,
                              width: capsuleWidth,
                              height: 54.0,
                              child: Container(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(16.0),
                                  gradient: const LinearGradient(
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                    colors: [
                                      Color(0x3ED90429), // CodeXa Crimson
                                      Color(0x22FF1E3C), // Bright Accent Red
                                    ],
                                  ),
                                  border: Border.all(
                                    color: const Color(0x88FF1E3C),
                                    width: 1.2,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color(0xFFD90429)
                                          .withOpacity(0.35),
                                      blurRadius: 12.0,
                                      spreadRadius: 1.0,
                                      offset: const Offset(0, 2),
                                    ),
                                    BoxShadow(
                                      color: Colors.white.withOpacity(0.10),
                                      blurRadius: 4.0,
                                      offset: const Offset(0, -1),
                                    ),
                                  ],
                                ),
                              ),
                            ),

                            // 3. 5 Tab Targets with Continuous Interpolation
                            Row(
                              children: List.generate(items.length, (index) {
                                final item = items[index];
                                final distance =
                                    (controller.fractionalIndex - index).abs();
                                final selectionFactor = (1.0 - distance).clamp(
                                  0.0,
                                  1.0,
                                );

                                final iconColor = Color.lerp(
                                  const Color(0xFFA5A5A5),
                                  const Color(0xFFFF1E3C),
                                  selectionFactor,
                                )!;

                                final textColor = Color.lerp(
                                  const Color(0xFF7A7A7A),
                                  const Color(0xFFF7F7F7),
                                  selectionFactor,
                                )!;

                                final iconScale =
                                    1.0 + (0.14 * selectionFactor);
                                final iconLift = -2.0 * selectionFactor;

                                return Expanded(
                                  child: Material(
                                    color: Colors.transparent,
                                    child: InkWell(
                                      onTap: () =>
                                          controller.animateToTab(index),
                                      splashColor: Colors.transparent,
                                      highlightColor: Colors.transparent,
                                      child: Center(
                                        child: Column(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            Transform.translate(
                                              offset: Offset(0, iconLift),
                                              child: Transform.scale(
                                                scale: iconScale,
                                                child: Icon(
                                                  selectionFactor > 0.5
                                                      ? item.activeIcon
                                                      : item.icon,
                                                  color: iconColor,
                                                  size: 21.0,
                                                ),
                                              ),
                                            ),
                                            const SizedBox(height: 3.0),
                                            Text(
                                              item.label,
                                              style: GoogleFonts.inter(
                                                fontSize: 10.0,
                                                fontWeight:
                                                    selectionFactor > 0.5
                                                    ? FontWeight.w700
                                                    : FontWeight.w500,
                                                color: textColor,
                                                letterSpacing:
                                                    0.1 +
                                                    (0.25 * selectionFactor),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                );
                              }),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
