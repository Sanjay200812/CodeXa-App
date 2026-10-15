import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../theme/cx_theme.dart';

/// Centralized CodeXa Motion Tokens
class CxMotion {
  static const Duration fast = Duration(milliseconds: 120);
  static const Duration normal = Duration(milliseconds: 180);
  static const Duration medium = Duration(milliseconds: 240);
  static const Duration page = Duration(milliseconds: 300);
  static const Duration loaderLoop = Duration(milliseconds: 1400);

  static const Curve standard = Curves.easeOutCubic;
  static const Curve emphasis = Curves.easeOutBack;
  static const Curve exit = Curves.easeInCubic;
}

/// Subtle Fade + Slide entrance animation
class CxFadeSlide extends StatefulWidget {
  final Widget child;
  final Duration duration;
  final Duration delay;
  final double offsetY;

  const CxFadeSlide({
    super.key,
    required this.child,
    this.duration = CxMotion.medium,
    this.delay = Duration.zero,
    this.offsetY = 8.0,
  });

  @override
  State<CxFadeSlide> createState() => _CxFadeSlideState();
}

class _CxFadeSlideState extends State<CxFadeSlide>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _opacity;
  late Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: widget.duration);

    _opacity = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _ctrl, curve: CxMotion.standard));

    _slide = Tween<Offset>(
      begin: Offset(0, widget.offsetY / 100),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _ctrl, curve: CxMotion.standard));

    if (widget.delay == Duration.zero) {
      _ctrl.forward();
    } else {
      Future.delayed(widget.delay, () {
        if (mounted) _ctrl.forward();
      });
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _opacity,
      child: SlideTransition(position: _slide, child: widget.child),
    );
  }
}

/// Scale-on-tap wrapper for interactive buttons & cards
class CxScaleTap extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final double scaleFactor;
  final bool enableHaptics;

  const CxScaleTap({
    super.key,
    required this.child,
    this.onTap,
    this.scaleFactor = 0.97,
    this.enableHaptics = true,
  });

  @override
  State<CxScaleTap> createState() => _CxScaleTapState();
}

class _CxScaleTapState extends State<CxScaleTap>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: CxMotion.fast,
      reverseDuration: CxMotion.normal,
    );
    _scale = Tween<double>(
      begin: 1.0,
      end: widget.scaleFactor,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _onTapDown(TapDownDetails _) {
    if (widget.onTap != null) {
      if (widget.enableHaptics) HapticFeedback.selectionClick();
      _ctrl.forward();
    }
  }

  void _onTapUp(TapUpDetails _) {
    if (widget.onTap != null) {
      _ctrl.reverse();
    }
  }

  void _onTapCancel() {
    if (widget.onTap != null) {
      _ctrl.reverse();
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: _onTapDown,
      onTapUp: _onTapUp,
      onTapCancel: _onTapCancel,
      onTap: widget.onTap,
      child: ScaleTransition(scale: _scale, child: widget.child),
    );
  }
}

/// Signature CodeXa Signal Loader
/// Four horizontal crimson nodes with a sequential cyber pulse traversing them
class CxSignalLoader extends StatefulWidget {
  final double size;
  final Color? color;
  final String? label;

  const CxSignalLoader({super.key, this.size = 28.0, this.color, this.label});

  @override
  State<CxSignalLoader> createState() => _CxSignalLoaderState();
}

class _CxSignalLoaderState extends State<CxSignalLoader>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: CxMotion.loaderLoop)
      ..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final activeColor = widget.color ?? CxColors.brightRed;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedBuilder(
          animation: _ctrl,
          builder: (context, child) {
            return Row(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(4, (index) {
                // Staggered node activation wave
                final progress = (_ctrl.value - (index * 0.18)) % 1.0;
                final isActive = progress >= 0.0 && progress <= 0.35;
                final factor = isActive
                    ? (1.0 - ((progress / 0.35 - 0.5).abs() * 2))
                    : 0.0;

                final nodeWidth = 6.0 + (factor * 10.0);
                final opacity = 0.25 + (factor * 0.75);

                return Container(
                  margin: const EdgeInsets.symmetric(horizontal: 3.0),
                  width: nodeWidth,
                  height: 4.0,
                  decoration: BoxDecoration(
                    color: activeColor.withOpacity(opacity.clamp(0.15, 1.0)),
                    borderRadius: BorderRadius.circular(2.0),
                    boxShadow: factor > 0.3
                        ? [
                            BoxShadow(
                              color: activeColor.withOpacity(0.6 * factor),
                              blurRadius: 8.0 * factor,
                              spreadRadius: 1.0,
                            ),
                          ]
                        : null,
                  ),
                );
              }),
            );
          },
        ),
        if (widget.label != null) ...[
          const SizedBox(height: 12),
          Text(
            widget.label!,
            style: GoogleFonts.orbitron(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              letterSpacing: 2.0,
              color: CxColors.textSecondary,
            ),
          ),
        ],
      ],
    );
  }
}

/// CodeXa Toast Notification System
enum CxToastType { success, error, warning, info }

class CxToast {
  static void show(
    BuildContext context, {
    required String message,
    CxToastType type = CxToastType.info,
    Duration duration = const Duration(seconds: 3),
  }) {
    final overlay = Overlay.of(context);
    late OverlayEntry entry;

    Color accentColor;
    IconData iconData;

    switch (type) {
      case CxToastType.success:
        accentColor = const Color(0xFF00E676);
        iconData = Icons.check_circle_outline;
        break;
      case CxToastType.error:
        accentColor = CxColors.brightRed;
        iconData = Icons.error_outline;
        break;
      case CxToastType.warning:
        accentColor = const Color(0xFFFFB300);
        iconData = Icons.warning_amber_rounded;
        break;
      case CxToastType.info:
        accentColor = CxColors.crimson;
        iconData = Icons.info_outline;
        break;
    }

    entry = OverlayEntry(
      builder: (context) => _CxToastWidget(
        message: message,
        accentColor: accentColor,
        iconData: iconData,
        duration: duration,
        onDismiss: () {
          if (entry.mounted) entry.remove();
        },
      ),
    );

    overlay.insert(entry);
  }
}

class _CxToastWidget extends StatefulWidget {
  final String message;
  final Color accentColor;
  final IconData iconData;
  final Duration duration;
  final VoidCallback onDismiss;

  const _CxToastWidget({
    required this.message,
    required this.accentColor,
    required this.iconData,
    required this.duration,
    required this.onDismiss,
  });

  @override
  State<_CxToastWidget> createState() => _CxToastWidgetState();
}

class _CxToastWidgetState extends State<_CxToastWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _opacity;
  late Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: CxMotion.normal,
      reverseDuration: CxMotion.fast,
    );

    _opacity = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _ctrl, curve: CxMotion.standard));

    _slide = Tween<Offset>(
      begin: const Offset(0, -0.4),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _ctrl, curve: CxMotion.standard));

    _ctrl.forward();

    Future.delayed(widget.duration, () {
      if (mounted) {
        _ctrl.reverse().then((_) => widget.onDismiss());
      }
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: MediaQuery.of(context).padding.top + 16,
      left: 20,
      right: 20,
      child: Material(
        color: Colors.transparent,
        child: FadeTransition(
          opacity: _opacity,
          child: SlideTransition(
            position: _slide,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFF111111),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: widget.accentColor.withOpacity(0.35),
                  width: 1.2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.6),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                  BoxShadow(
                    color: widget.accentColor.withOpacity(0.12),
                    blurRadius: 10,
                  ),
                ],
              ),
              child: Row(
                children: [
                  Icon(widget.iconData, color: widget.accentColor, size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      widget.message,
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: CxColors.textPrimary,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
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

/// CodeXa Confirmation Dialog
class CxConfirmDialog extends StatelessWidget {
  final String title;
  final String message;
  final String confirmLabel;
  final String cancelLabel;
  final bool isDestructive;
  final VoidCallback onConfirm;

  const CxConfirmDialog({
    super.key,
    required this.title,
    required this.message,
    this.confirmLabel = 'CONFIRM',
    this.cancelLabel = 'CANCEL',
    this.isDestructive = false,
    required this.onConfirm,
  });

  static Future<bool?> show(
    BuildContext context, {
    required String title,
    required String message,
    String confirmLabel = 'CONFIRM',
    String cancelLabel = 'CANCEL',
    bool isDestructive = false,
  }) {
    return showDialog<bool>(
      context: context,
      barrierColor: Colors.black.withOpacity(0.75),
      builder: (ctx) => CxConfirmDialog(
        title: title,
        message: message,
        confirmLabel: confirmLabel,
        cancelLabel: cancelLabel,
        isDestructive: isDestructive,
        onConfirm: () => Navigator.of(ctx).pop(true),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: const Color(0xFF0F0F0F),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isDestructive
                ? CxColors.brightRed.withOpacity(0.4)
                : const Color(0xFF262626),
            width: 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.8),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              title,
              style: GoogleFonts.orbitron(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: isDestructive
                    ? CxColors.brightRed
                    : CxColors.textPrimary,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              message,
              style: GoogleFonts.inter(
                fontSize: 13,
                height: 1.4,
                color: CxColors.textSecondary,
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Color(0xFF333333)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    onPressed: () => Navigator.of(context).pop(false),
                    child: Text(
                      cancelLabel,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: CxColors.textSecondary,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isDestructive
                          ? CxColors.brightRed
                          : CxColors.crimson,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    onPressed: () {
                      Navigator.of(context).pop(true);
                      onConfirm();
                    },
                    child: Text(
                      confirmLabel,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
