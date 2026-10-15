import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

enum GlassButtonVariant { primary, secondary, crimson, ghost }

/// 1. Base Liquid Glass Surface with controllable frosted backdrop blur & subtle border
class CodeXaGlassSurface extends StatelessWidget {
  final Widget child;
  final double borderRadius;
  final double blurAmount;
  final Color? backgroundColor;
  final Color? borderColor;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry margin;
  final bool hasGlow;
  final Color? glowColor;
  final double borderWidth;

  const CodeXaGlassSurface({
    super.key,
    required this.child,
    this.borderRadius = 16.0,
    this.blurAmount = 14.0,
    this.backgroundColor,
    this.borderColor,
    this.padding = EdgeInsets.zero,
    this.margin = EdgeInsets.zero,
    this.hasGlow = false,
    this.glowColor,
    this.borderWidth = 1.0,
  });

  @override
  Widget build(BuildContext context) {
    final bg = backgroundColor ?? const Color(0xFF0C0C0C).withOpacity(0.72);
    final border = borderColor ?? Colors.white.withOpacity(0.10);
    final glow = glowColor ?? const Color(0xFFD90429).withOpacity(0.20);

    Widget content = ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blurAmount, sigmaY: blurAmount),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(borderRadius),
            border: Border.all(color: border, width: borderWidth),
            boxShadow: hasGlow
                ? [BoxShadow(color: glow, blurRadius: 18, spreadRadius: 1)]
                : [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.35),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
          ),
          child: child,
        ),
      ),
    );

    if (margin != EdgeInsets.zero) {
      content = Padding(padding: margin, child: content);
    }

    return content;
  }
}

/// 2. Premium Liquid Glass Button with pressed spring animation & badge support
class CodeXaGlassButton extends StatefulWidget {
  final VoidCallback? onPressed;
  final String? label;
  final IconData? icon;
  final Widget? customChild;
  final GlassButtonVariant variant;
  final bool loading;
  final bool disabled;
  final bool selected;
  final double? width;
  final double height;
  final double borderRadius;
  final double blurAmount;
  final String? accessibilityLabel;
  final EdgeInsetsGeometry padding;
  final int? badgeCount;

  const CodeXaGlassButton({
    super.key,
    required this.onPressed,
    this.label,
    this.icon,
    this.customChild,
    this.variant = GlassButtonVariant.secondary,
    this.loading = false,
    this.disabled = false,
    this.selected = false,
    this.width,
    this.height = 46,
    this.borderRadius = 14,
    this.blurAmount = 12.0,
    this.accessibilityLabel,
    this.padding = const EdgeInsets.symmetric(horizontal: 16),
    this.badgeCount,
  });

  @override
  State<CodeXaGlassButton> createState() => _CodeXaGlassButtonState();
}

class _CodeXaGlassButtonState extends State<CodeXaGlassButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 120),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.96).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeOutCubic),
    );
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  void _onTapDown(TapDownDetails _) {
    if (!widget.disabled && !widget.loading && widget.onPressed != null) {
      HapticFeedback.selectionClick();
      _animController.forward();
    }
  }

  void _onTapUp(TapUpDetails _) {
    _animController.reverse();
  }

  void _onTapCancel() {
    _animController.reverse();
  }

  @override
  Widget build(BuildContext context) {
    final isInteractive =
        !widget.disabled && !widget.loading && widget.onPressed != null;

    Color bg;
    Color borderColor;
    Color fgColor;
    List<BoxShadow> shadows = [];

    switch (widget.variant) {
      case GlassButtonVariant.crimson:
        bg = widget.selected
            ? const Color(0xFFD90429).withOpacity(0.9)
            : const Color(0xFFD90429).withOpacity(0.24);
        borderColor = widget.selected
            ? const Color(0xFFFF1E3C).withOpacity(0.8)
            : const Color(0xFFD90429).withOpacity(0.55);
        fgColor = Colors.white;
        shadows = [
          BoxShadow(
            color: const Color(0xFFD90429)
                .withOpacity(widget.selected ? 0.35 : 0.15),
            blurRadius: 16,
            spreadRadius: 1,
            offset: const Offset(0, 4),
          ),
        ];
        break;
      case GlassButtonVariant.primary:
        bg = const Color(0xFF1E1E1E).withOpacity(0.7);
        borderColor = Colors.white.withOpacity(0.2);
        fgColor = const Color(0xFFF7F7F7);
        break;
      case GlassButtonVariant.ghost:
        bg = Colors.transparent;
        borderColor = widget.selected
            ? const Color(0xFFD90429).withOpacity(0.6)
            : Colors.white.withOpacity(0.08);
        fgColor = widget.selected
            ? const Color(0xFFFF1E3C)
            : const Color(0xFFA5A5A5);
        break;
      case GlassButtonVariant.secondary:
        bg = widget.selected
            ? const Color(0xFF241517).withOpacity(0.7)
            : const Color(0xFF111111).withOpacity(0.65);
        borderColor = widget.selected
            ? const Color(0xFFD90429).withOpacity(0.65)
            : Colors.white.withOpacity(0.12);
        fgColor = widget.selected
            ? const Color(0xFFFF1E3C)
            : const Color(0xFFF7F7F7);
        if (widget.selected) {
          shadows = [
            BoxShadow(
              color: const Color(0xFFD90429).withOpacity(0.2),
              blurRadius: 12,
            ),
          ];
        }
        break;
    }

    if (widget.disabled) {
      bg = const Color(0xFF161616).withOpacity(0.4);
      borderColor = Colors.white.withOpacity(0.04);
      fgColor = const Color(0xFF555555);
      shadows = [];
    }

    final buttonWidget = Semantics(
      label: widget.accessibilityLabel ?? widget.label,
      button: true,
      enabled: isInteractive,
      child: GestureDetector(
        onTapDown: _onTapDown,
        onTapUp: _onTapUp,
        onTapCancel: _onTapCancel,
        onTap: isInteractive ? widget.onPressed : null,
        child: AnimatedBuilder(
          animation: _scaleAnimation,
          builder: (context, child) =>
              Transform.scale(scale: _scaleAnimation.value, child: child),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(widget.borderRadius),
            child: BackdropFilter(
              filter: ImageFilter.blur(
                sigmaX: widget.blurAmount,
                sigmaY: widget.blurAmount,
              ),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: widget.width,
                height: widget.height,
                padding: widget.padding,
                decoration: BoxDecoration(
                  color: bg,
                  borderRadius: BorderRadius.circular(widget.borderRadius),
                  border: Border.all(color: borderColor, width: 1.1),
                  boxShadow: shadows,
                ),
                child: Center(
                  child: widget.loading
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.white70,
                            ),
                          ),
                        )
                      : widget.customChild ??
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                if (widget.icon != null) ...[
                                  Icon(widget.icon, size: 18, color: fgColor),
                                  if (widget.label != null)
                                    const SizedBox(width: 8),
                                ],
                                if (widget.label != null)
                                  Text(
                                    widget.label!,
                                    style: GoogleFonts.inter(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      letterSpacing: 0.3,
                                      color: fgColor,
                                    ),
                                  ),
                              ],
                            ),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    if (widget.badgeCount != null && widget.badgeCount! > 0) {
      return Stack(
        clipBehavior: Clip.none,
        children: [
          buttonWidget,
          Positioned(
            top: -2,
            right: -2,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
              decoration: BoxDecoration(
                color: const Color(0xFFFF1E3C),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFF070707), width: 1.5),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFD90429).withOpacity(0.5),
                    blurRadius: 6,
                  ),
                ],
              ),
              constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
              child: Center(
                child: Text(
                  widget.badgeCount! > 99 ? '99+' : '${widget.badgeCount}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
        ],
      );
    }

    return buttonWidget;
  }
}

/// 3. Compact Liquid Glass Icon Button
class CodeXaGlassIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onPressed;
  final double size;
  final double iconSize;
  final Color? iconColor;
  final int? badgeCount;
  final String? tooltip;
  final bool isSelected;

  const CodeXaGlassIconButton({
    super.key,
    required this.icon,
    required this.onPressed,
    this.size = 40.0,
    this.iconSize = 19.0,
    this.iconColor,
    this.badgeCount,
    this.tooltip,
    this.isSelected = false,
  });

  @override
  Widget build(BuildContext context) {
    return CodeXaGlassButton(
      width: size,
      height: size,
      borderRadius: size / 2,
      padding: EdgeInsets.zero,
      selected: isSelected,
      variant: isSelected
          ? GlassButtonVariant.crimson
          : GlassButtonVariant.secondary,
      badgeCount: badgeCount,
      accessibilityLabel: tooltip,
      onPressed: onPressed,
      customChild: Icon(
        icon,
        size: iconSize,
        color:
            iconColor ??
            (isSelected ? const Color(0xFFFF1E3C) : const Color(0xFFF7F7F7)),
      ),
    );
  }
}

/// 4. High-Value Liquid Glass Card with subtle border and crimson glow
class CodeXaGlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry margin;
  final double borderRadius;
  final double blurAmount;
  final Color? backgroundColor;
  final Color? borderColor;
  final bool hasGlow;
  final Color? glowColor;
  final VoidCallback? onTap;

  const CodeXaGlassCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.margin = EdgeInsets.zero,
    this.borderRadius = 18,
    this.blurAmount = 14.0,
    this.backgroundColor,
    this.borderColor,
    this.hasGlow = false,
    this.glowColor,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final bg = backgroundColor ?? const Color(0xFF0C0C0C).withOpacity(0.72);
    final border = borderColor ?? Colors.white.withOpacity(0.09);
    final glow = glowColor ?? const Color(0xFFD90429).withOpacity(0.12);

    Widget card = ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blurAmount, sigmaY: blurAmount),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(borderRadius),
            border: Border.all(color: border, width: 1.1),
            boxShadow: hasGlow
                ? [BoxShadow(color: glow, blurRadius: 20, spreadRadius: 2)]
                : [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.35),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
          ),
          child: child,
        ),
      ),
    );

    if (margin != EdgeInsets.zero) {
      card = Padding(padding: margin, child: card);
    }

    if (onTap != null) {
      return GestureDetector(
        onTap: () {
          HapticFeedback.lightImpact();
          onTap!();
        },
        child: card,
      );
    }

    return card;
  }
}

/// 5. Frosted Glass Bottom Navigation Bar with Safe-Area insets
class CodeXaGlassNavigationBar extends StatelessWidget {
  final Widget child;
  final double height;
  final double blurAmount;

  const CodeXaGlassNavigationBar({
    super.key,
    required this.child,
    this.height = 68.0,
    this.blurAmount = 16.0,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF070707),
      child: SafeArea(
        top: false,
        bottom: true,
        child: ClipRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: blurAmount, sigmaY: blurAmount),
            child: Container(
              height: height,
              decoration: BoxDecoration(
                color: const Color(0xFF0C0C0C).withOpacity(0.88),
                border: Border(
                  top: BorderSide(
                    color: Colors.white.withOpacity(0.12),
                    width: 0.8,
                  ),
                ),
              ),
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}

/// 6. Glass Bottom Sheet container with frosted drag handle
class CodeXaGlassBottomSheet extends StatelessWidget {
  final Widget child;
  final String? title;
  final EdgeInsetsGeometry padding;

  const CodeXaGlassBottomSheet({
    super.key,
    required this.child,
    this.title,
    this.padding = const EdgeInsets.all(20),
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20.0, sigmaY: 20.0),
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xFF0C0C0C).withOpacity(0.92),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            border: Border(
              top: BorderSide(
                color: Colors.white.withOpacity(0.14),
                width: 1.2,
              ),
            ),
          ),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 12),
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.25),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                if (title != null) ...[
                  const SizedBox(height: 14),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Text(
                      title!,
                      style: GoogleFonts.orbitron(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.2,
                        color: const Color(0xFFF7F7F7),
                      ),
                    ),
                  ),
                ],
                Padding(padding: padding, child: child),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 7. Glass Search Bar component with clear button & icon
class CodeXaGlassSearchBar extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<String>? onChanged;
  final VoidCallback? onClear;
  final String hintText;

  const CodeXaGlassSearchBar({
    super.key,
    required this.controller,
    this.onChanged,
    this.onClear,
    this.hintText = 'Search CodeXa...',
  });

  @override
  Widget build(BuildContext context) {
    return CodeXaGlassSurface(
      borderRadius: 14,
      blurAmount: 10,
      backgroundColor: const Color(0xFF111111).withOpacity(0.70),
      borderColor: Colors.white.withOpacity(0.12),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
      child: Row(
        children: [
          Icon(Icons.search, size: 19, color: Colors.white.withOpacity(0.6)),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: controller,
              onChanged: onChanged,
              style: GoogleFonts.inter(color: Colors.white, fontSize: 14),
              cursorColor: const Color(0xFFFF1E3C),
              decoration: InputDecoration(
                hintText: hintText,
                hintStyle: GoogleFonts.inter(
                  color: const Color(0xFFA5A5A5),
                  fontSize: 13,
                ),
                border: InputBorder.none,
              ),
            ),
          ),
          if (controller.text.isNotEmpty)
            GestureDetector(
              onTap: () {
                controller.clear();
                onClear?.call();
              },
              child: Icon(
                Icons.clear,
                size: 18,
                color: Colors.white.withOpacity(0.6),
              ),
            ),
        ],
      ),
    );
  }
}

/// 8. Glass Floating Action Button
class CodeXaGlassFloatingAction extends StatelessWidget {
  final IconData icon;
  final VoidCallback onPressed;
  final String? label;

  const CodeXaGlassFloatingAction({
    super.key,
    required this.icon,
    required this.onPressed,
    this.label,
  });

  @override
  Widget build(BuildContext context) {
    return CodeXaGlassButton(
      height: 52,
      borderRadius: 26,
      variant: GlassButtonVariant.crimson,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      onPressed: onPressed,
      icon: icon,
      label: label,
    );
  }
}

/// 9. Glass Segmented Control pill tab bar
class CodeXaGlassSegmentedControl extends StatelessWidget {
  final List<String> segments;
  final int selectedIndex;
  final ValueChanged<int> onSegmentSelected;

  const CodeXaGlassSegmentedControl({
    super.key,
    required this.segments,
    required this.selectedIndex,
    required this.onSegmentSelected,
  });

  @override
  Widget build(BuildContext context) {
    return CodeXaGlassSurface(
      borderRadius: 12,
      blurAmount: 10,
      backgroundColor: const Color(0xFF0F0F0F).withOpacity(0.65),
      borderColor: Colors.white.withOpacity(0.10),
      padding: const EdgeInsets.all(4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(segments.length, (index) {
          final isSelected = index == selectedIndex;
          return GestureDetector(
            onTap: () {
              HapticFeedback.selectionClick();
              onSegmentSelected(index);
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: isSelected
                    ? const Color(0xFFD90429).withOpacity(0.35)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(8),
                border: isSelected
                    ? Border.all(
                        color: const Color(0xFFFF1E3C).withOpacity(0.6),
                        width: 1,
                      )
                    : null,
              ),
              child: Text(
                segments[index],
                style: GoogleFonts.orbitron(
                  fontSize: 11,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  color: isSelected ? Colors.white : const Color(0xFFA5A5A5),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}

/// 10. Glass Profile Summary Card
class CodeXaGlassProfileCard extends StatelessWidget {
  final String fullName;
  final String username;
  final String role;
  final String? profileMediaUrl;
  final VoidCallback? onTap;

  const CodeXaGlassProfileCard({
    super.key,
    required this.fullName,
    required this.username,
    required this.role,
    this.profileMediaUrl,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return CodeXaGlassCard(
      onTap: onTap,
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFF1E1E1E),
              border: Border.all(
                color: const Color(0xFFD90429).withOpacity(0.5),
              ),
            ),
            child: ClipOval(
              child: profileMediaUrl != null && profileMediaUrl!.isNotEmpty
                  ? Image.network(
                      profileMediaUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Center(
                        child: Text(
                          fullName.isNotEmpty ? fullName[0].toUpperCase() : 'C',
                          style: GoogleFonts.orbitron(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    )
                  : Center(
                      child: Text(
                        fullName.isNotEmpty ? fullName[0].toUpperCase() : 'C',
                        style: GoogleFonts.orbitron(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
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
                  fullName,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFFF7F7F7),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  '@$username • $role',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: const Color(0xFFA5A5A5),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const Icon(
            Icons.arrow_forward_ios,
            size: 14,
            color: Color(0xFFA5A5A5),
          ),
        ],
      ),
    );
  }
}

/// 11. Glass Action Tray for message actions or quick options
class CodeXaGlassActionTray extends StatelessWidget {
  final List<Widget> children;
  final EdgeInsetsGeometry padding;

  const CodeXaGlassActionTray({
    super.key,
    required this.children,
    this.padding = const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
  });

  @override
  Widget build(BuildContext context) {
    return CodeXaGlassSurface(
      borderRadius: 20,
      blurAmount: 14,
      backgroundColor: const Color(0xFF0C0C0C).withOpacity(0.85),
      borderColor: Colors.white.withOpacity(0.12),
      padding: padding,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: children,
      ),
    );
  }
}

/// 12. Glass Modal Dialog
class CodeXaGlassModal extends StatelessWidget {
  final String title;
  final String message;
  final String confirmLabel;
  final String cancelLabel;
  final VoidCallback onConfirm;
  final VoidCallback? onCancel;

  const CodeXaGlassModal({
    super.key,
    required this.title,
    required this.message,
    required this.confirmLabel,
    this.cancelLabel = 'Cancel',
    required this.onConfirm,
    this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28),
        child: CodeXaGlassCard(
          borderRadius: 20,
          blurAmount: 20,
          backgroundColor: const Color(0xFF0C0C0C).withOpacity(0.92),
          borderColor: Colors.white.withOpacity(0.16),
          hasGlow: true,
          padding: const EdgeInsets.all(22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                title,
                textAlign: TextAlign.center,
                style: GoogleFonts.orbitron(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                message,
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  color: const Color(0xFFA5A5A5),
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 22),
              Row(
                children: [
                  Expanded(
                    child: CodeXaGlassButton(
                      label: cancelLabel,
                      variant: GlassButtonVariant.ghost,
                      onPressed: () {
                        Navigator.pop(context);
                        onCancel?.call();
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: CodeXaGlassButton(
                      label: confirmLabel,
                      variant: GlassButtonVariant.crimson,
                      onPressed: () {
                        Navigator.pop(context);
                        onConfirm();
                      },
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
