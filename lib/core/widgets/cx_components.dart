import 'dart:ui';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../theme/cx_theme.dart';
export 'cx_glass.dart';

/// CodeXa Base Scaffold with optional cyber grid styling
class CxScaffold extends StatelessWidget {
  final Widget body;
  final PreferredSizeWidget? appBar;
  final Widget? bottomNavigationBar;
  final Widget? floatingActionButton;
  final bool showCyberBackground;

  const CxScaffold({
    super.key,
    required this.body,
    this.appBar,
    this.bottomNavigationBar,
    this.floatingActionButton,
    this.showCyberBackground = false,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: CxColors.background,
      appBar: appBar,
      body: Stack(
        children: [
          if (showCyberBackground)
            Positioned.fill(child: CustomPaint(painter: _CyberGridPainter())),
          SafeArea(child: body),
        ],
      ),
      bottomNavigationBar: bottomNavigationBar,
      floatingActionButton: floatingActionButton,
    );
  }
}

class _CyberGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0x08D90429)
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

/// Standard CodeXa Header / AppBar
class CxAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final List<Widget>? actions;
  final Widget? leading;
  final bool centerTitle;
  final String? subtitle;

  const CxAppBar({
    super.key,
    required this.title,
    this.actions,
    this.leading,
    this.centerTitle = false,
    this.subtitle,
  });

  @override
  Size get preferredSize => const Size.fromHeight(60.0);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor: CxColors.background.withOpacity(0.85),
      elevation: 0,
      centerTitle: centerTitle,
      leading: leading,
      title: Column(
        crossAxisAlignment: centerTitle
            ? CrossAxisAlignment.center
            : CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            title,
            style: GoogleFonts.orbitron(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: CxColors.textPrimary,
              letterSpacing: 0.5,
            ),
          ),
          if (subtitle != null)
            Text(
              subtitle!,
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.w400,
                color: CxColors.textSecondary,
              ),
            ),
        ],
      ),
      actions: actions,
    );
  }
}

/// Cyber Card with subtle border and optional glow
class CxCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final bool isActive;
  final Color? backgroundColor;
  final Color? borderColor;
  final double? width;
  final double? height;

  const CxCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(CxSpacing.lg),
    this.onTap,
    this.isActive = false,
    this.backgroundColor,
    this.borderColor,
    this.width,
    this.height,
  });

  @override
  Widget build(BuildContext context) {
    final border =
        borderColor ??
        (isActive ? CxColors.borderActive : CxColors.borderDefault);
    final shadows = isActive ? CxShadows.neonGlow : CxShadows.subtleCard;

    final content = AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width: width,
      height: height,
      padding: padding,
      decoration: BoxDecoration(
        color: backgroundColor ?? CxColors.card,
        borderRadius: BorderRadius.circular(CxSpacing.cardRadius),
        border: Border.all(color: border, width: 1.0),
        boxShadow: shadows,
      ),
      child: child,
    );

    if (onTap != null) {
      return Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(CxSpacing.cardRadius),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(CxSpacing.cardRadius),
          splashColor: CxColors.crimson.withOpacity(0.12),
          highlightColor: CxColors.crimson.withOpacity(0.06),
          child: content,
        ),
      );
    }
    return content;
  }
}

/// Glassmorphism Card
class CxGlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final double blur;

  const CxGlassCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(CxSpacing.lg),
    this.onTap,
    this.blur = 10.0,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(CxSpacing.cardRadius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            gradient: CxColors.glassGradient,
            borderRadius: BorderRadius.circular(CxSpacing.cardRadius),
            border: Border.all(color: CxColors.borderDefault, width: 1.0),
          ),
          child: child,
        ),
      ),
    );
  }
}

/// CodeXa Primary & Secondary Buttons
class CxButton extends StatefulWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;
  final bool isSecondary;
  final bool isDestructive;
  final dynamic icon;
  final double? width;
  final double height;
  final Color? backgroundColor;
  final Color? textColor;

  const CxButton({
    super.key,
    required this.label,
    this.onPressed,
    this.isLoading = false,
    this.isSecondary = false,
    this.isDestructive = false,
    this.icon,
    this.width,
    this.height = CxSpacing.primaryButtonHeight,
    this.backgroundColor,
    this.textColor,
  });

  @override
  State<CxButton> createState() => _CxButtonState();
}

class _CxButtonState extends State<CxButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 120),
    );
    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 0.97,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDisabled = widget.onPressed == null || widget.isLoading;

    Color bg;
    Color border;
    Color textColor;

    if (widget.backgroundColor != null) {
      bg = widget.backgroundColor!;
      border = widget.backgroundColor!;
      textColor = widget.textColor ?? Colors.white;
    } else if (widget.isSecondary) {
      bg = CxColors.cardElevated;
      border = CxColors.borderSubtle;
      textColor = CxColors.textPrimary;
    } else if (widget.isDestructive) {
      bg = CxColors.deepRed;
      border = CxColors.error.withOpacity(0.5);
      textColor = CxColors.textPrimary;
    } else {
      bg = CxColors.crimson;
      border = CxColors.brightRed;
      textColor = CxColors.textPrimary;
    }

    if (isDisabled) {
      bg = bg.withOpacity(0.4);
      border = border.withOpacity(0.2);
      textColor = textColor.withOpacity(0.5);
    }

    return ScaleTransition(
      scale: _scaleAnimation,
      child: Container(
        width: widget.width ?? double.infinity,
        height: widget.height,
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(CxSpacing.buttonRadius),
          border: Border.all(color: border, width: 1.0),
          boxShadow: (!widget.isSecondary && !isDisabled)
              ? CxShadows.neonGlow
              : null,
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTapDown: (_) => !isDisabled ? _controller.forward() : null,
            onTapUp: (_) => !isDisabled ? _controller.reverse() : null,
            onTapCancel: () => !isDisabled ? _controller.reverse() : null,
            onTap: widget.onPressed,
            borderRadius: BorderRadius.circular(CxSpacing.buttonRadius),
            child: Center(
              child: widget.isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (widget.icon != null) ...[
                          if (widget.icon is Widget)
                            widget.icon as Widget
                          else if (widget.icon is IconData)
                            Icon(
                              widget.icon as IconData,
                              size: 18,
                              color: textColor,
                            ),
                          const SizedBox(width: CxSpacing.sm),
                        ],
                        Text(
                          widget.label,
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.5,
                            color: textColor,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Icon Button with hover/tap border effect
class CxIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onPressed;
  final Color? color;
  final double size;
  final String? tooltip;
  final int? badgeCount;

  const CxIconButton({
    super.key,
    required this.icon,
    this.onPressed,
    this.color,
    this.size = 20.0,
    this.tooltip,
    this.badgeCount,
  });

  @override
  Widget build(BuildContext context) {
    final button = Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: CxColors.cardElevated,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: CxColors.borderSubtle),
          ),
          child: Center(
            child: Icon(icon, size: size, color: color ?? CxColors.textPrimary),
          ),
        ),
      ),
    );

    if (badgeCount != null && badgeCount! > 0) {
      return Stack(
        clipBehavior: Clip.none,
        children: [
          button,
          Positioned(
            top: -2,
            right: -2,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
              decoration: BoxDecoration(
                color: CxColors.brightRed,
                borderRadius: BorderRadius.circular(10),
                boxShadow: CxShadows.neonGlow,
              ),
              child: Text(
                badgeCount! > 99 ? '99+' : '$badgeCount',
                style: GoogleFonts.inter(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      );
    }

    return button;
  }
}

/// Cyber Input Field
class CxTextField extends StatelessWidget {
  final String? label;
  final String? hint;
  final TextEditingController? controller;
  final bool obscureText;
  final TextInputType keyboardType;
  final Widget? prefixIcon;
  final Widget? suffixIcon;
  final String? errorText;
  final ValueChanged<String>? onChanged;
  final int maxLines;
  final bool enabled;

  const CxTextField({
    super.key,
    this.label,
    this.hint,
    this.controller,
    this.obscureText = false,
    this.keyboardType = TextInputType.text,
    this.prefixIcon,
    this.suffixIcon,
    this.errorText,
    this.onChanged,
    this.maxLines = 1,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (label != null) ...[
          Text(
            label!,
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: CxColors.textSecondary,
              letterSpacing: 0.3,
            ),
          ),
          const SizedBox(height: CxSpacing.xs),
        ],
        Container(
          decoration: BoxDecoration(
            color: CxColors.card,
            borderRadius: BorderRadius.circular(CxSpacing.inputRadius),
            border: Border.all(
              color: errorText != null
                  ? CxColors.error
                  : CxColors.borderDefault,
              width: 1.0,
            ),
          ),
          child: TextField(
            controller: controller,
            obscureText: obscureText,
            keyboardType: keyboardType,
            enabled: enabled,
            maxLines: maxLines,
            onChanged: onChanged,
            style: GoogleFonts.inter(fontSize: 14, color: CxColors.textPrimary),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: GoogleFonts.inter(
                fontSize: 14,
                color: CxColors.textMuted,
              ),
              prefixIcon: prefixIcon,
              suffixIcon: suffixIcon,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: CxSpacing.lg,
                vertical: CxSpacing.md,
              ),
              border: InputBorder.none,
            ),
          ),
        ),
        if (errorText != null) ...[
          const SizedBox(height: 4),
          Text(
            errorText!,
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: CxColors.error,
            ),
          ),
        ],
      ],
    );
  }
}

/// Profile Avatar with fallback initials and intelligent local/network image loading
class CxAvatar extends StatelessWidget {
  final String? imageUrl;
  final String name;
  final double radius;
  final bool isOnline;

  const CxAvatar({
    super.key,
    this.imageUrl,
    required this.name,
    this.radius = 22.0,
    this.isOnline = false,
  });

  String _getInitials(String input) {
    final parts = input.trim().split(' ');
    if (parts.isEmpty || parts[0].isEmpty) return 'CX';
    if (parts.length == 1) {
      return parts[0].substring(0, parts[0].length >= 2 ? 2 : 1).toUpperCase();
    }
    return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
  }

  /// Extracts the bundled asset path if this URL maps to a local Flutter asset
  static String? getLocalAssetPath(String? raw) {
    if (raw == null) return null;
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return null;

    if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
      final uri = Uri.tryParse(trimmed);
      if (uri != null) {
        final decodedPath = Uri.decodeFull(uri.path);
        if (decodedPath.startsWith('/assets/')) {
          return decodedPath.substring(1); // e.g. "assets/pfp/blue strike.jpg"
        }
      }
      return null;
    }

    final clean = trimmed.startsWith('/') ? trimmed.substring(1) : trimmed;
    if (clean.startsWith('assets/')) {
      return clean;
    }
    return null;
  }

  /// Normalizes any relative or unencoded URL into an absolute HTTPS URL
  static String? resolveNetworkUrl(String? raw) {
    if (raw == null) return null;
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return null;

    if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
      return Uri.encodeFull(trimmed);
    }

    final clean = trimmed.startsWith('/') ? trimmed : '/$trimmed';
    return 'https://codxa-agency.online${Uri.encodeFull(clean)}';
  }

  Widget _buildInitials() {
    return Container(
      width: radius * 2,
      height: radius * 2,
      color: CxColors.secondaryDark,
      alignment: Alignment.center,
      child: Text(
        _getInitials(name),
        style: GoogleFonts.orbitron(
          fontSize: radius * 0.7,
          fontWeight: FontWeight.w700,
          color: CxColors.brightRed,
        ),
      ),
    );
  }

  Widget _buildImage() {
    final localAsset = getLocalAssetPath(imageUrl);
    final netUrl = resolveNetworkUrl(imageUrl);

    if (localAsset != null) {
      return Image.asset(
        localAsset,
        width: radius * 2,
        height: radius * 2,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          if (netUrl != null) {
            return CachedNetworkImage(
              imageUrl: netUrl,
              width: radius * 2,
              height: radius * 2,
              fit: BoxFit.cover,
              placeholder: (_, __) => _buildInitials(),
              errorWidget: (_, __, ___) => _buildInitials(),
            );
          }
          return _buildInitials();
        },
      );
    }

    if (netUrl != null) {
      return CachedNetworkImage(
        imageUrl: netUrl,
        width: radius * 2,
        height: radius * 2,
        fit: BoxFit.cover,
        placeholder: (_, __) => _buildInitials(),
        errorWidget: (_, __, ___) => _buildInitials(),
      );
    }

    return _buildInitials();
  }

  @override
  Widget build(BuildContext context) {
    final avatar = ClipOval(
      child: SizedBox(
        width: radius * 2,
        height: radius * 2,
        child: _buildImage(),
      ),
    );

    if (isOnline) {
      return Stack(
        clipBehavior: Clip.none,
        children: [
          avatar,
          Positioned(
            right: 0,
            bottom: 0,
            child: Container(
              width: radius * 0.5,
              height: radius * 0.5,
              decoration: BoxDecoration(
                color: CxColors.success,
                shape: BoxShape.circle,
                border: Border.all(color: CxColors.background, width: 2),
              ),
            ),
          ),
        ],
      );
    }

    return avatar;
  }
}

/// Status Chip (Active, Pending, Approved, etc.)
class CxStatusChip extends StatelessWidget {
  final String label;
  final Color? color;
  final bool isSmall;

  const CxStatusChip({
    super.key,
    required this.label,
    this.color,
    this.isSmall = false,
  });

  @override
  Widget build(BuildContext context) {
    Color chipColor = color ?? CxColors.crimson;
    final upper = label.toUpperCase();

    if (upper == 'ACTIVE' ||
        upper == 'PRESENT' ||
        upper == 'APPROVED' ||
        upper == 'SUCCESSFUL') {
      chipColor = CxColors.success;
    } else if (upper == 'PENDING' ||
        upper == 'UPCOMING' ||
        upper == 'COMING_SOON' ||
        upper == 'LATE') {
      chipColor = CxColors.warning;
    } else if (upper == 'CLOSED' ||
        upper == 'ABSENT' ||
        upper == 'REJECTED' ||
        upper == 'FAILED') {
      chipColor = CxColors.error;
    }

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isSmall ? 6 : 10,
        vertical: isSmall ? 2 : 4,
      ),
      decoration: BoxDecoration(
        color: chipColor.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: chipColor.withOpacity(0.4), width: 1),
      ),
      child: Text(
        label,
        style: GoogleFonts.inter(
          fontSize: isSmall ? 10 : 11,
          fontWeight: FontWeight.w700,
          color: chipColor,
          letterSpacing: 0.4,
        ),
      ),
    );
  }
}

/// Section Header
class CxSectionHeader extends StatelessWidget {
  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;

  const CxSectionHeader({
    super.key,
    required this.title,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: CxSpacing.sm),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title.toUpperCase(),
            style: GoogleFonts.orbitron(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: CxColors.textSecondary,
              letterSpacing: 1.0,
            ),
          ),
          if (actionLabel != null)
            GestureDetector(
              onTap: onAction,
              child: Text(
                actionLabel!,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: CxColors.brightRed,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Empty State Display
class CxEmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final Widget? action;

  const CxEmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(CxSpacing.xxl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: CxColors.secondaryDark,
                shape: BoxShape.circle,
                border: Border.all(color: CxColors.borderDefault),
              ),
              child: Icon(icon, size: 28, color: CxColors.textSecondary),
            ),
            const SizedBox(height: CxSpacing.lg),
            Text(
              title,
              textAlign: TextAlign.center,
              style: GoogleFonts.orbitron(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: CxColors.textPrimary,
              ),
            ),
            const SizedBox(height: CxSpacing.xs),
            Text(
              message,
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 13,
                color: CxColors.textSecondary,
                height: 1.4,
              ),
            ),
            if (action != null) ...[
              const SizedBox(height: CxSpacing.lg),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}

/// Loading Skeleton Placeholder
class CxLoadingSkeleton extends StatefulWidget {
  final double width;
  final double height;
  final double borderRadius;

  const CxLoadingSkeleton({
    super.key,
    required this.width,
    required this.height,
    this.borderRadius = 8.0,
  });

  @override
  State<CxLoadingSkeleton> createState() => _CxLoadingSkeletonState();
}

class _CxLoadingSkeletonState extends State<CxLoadingSkeleton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _animation = Tween<double>(begin: 0.08, end: 0.22).animate(_controller);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(_animation.value),
            borderRadius: BorderRadius.circular(widget.borderRadius),
          ),
        );
      },
    );
  }
}
