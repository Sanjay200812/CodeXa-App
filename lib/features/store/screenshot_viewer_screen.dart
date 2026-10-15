import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/theme/cx_theme.dart';
import 'codexa_store_models.dart';

class ScreenshotViewerScreen extends StatefulWidget {
  final List<StoreScreenshot> screenshots;
  final int initialIndex;

  const ScreenshotViewerScreen({
    super.key,
    required this.screenshots,
    this.initialIndex = 0,
  });

  @override
  State<ScreenshotViewerScreen> createState() => _ScreenshotViewerScreenState();
}

class _ScreenshotViewerScreenState extends State<ScreenshotViewerScreen> {
  late PageController _pageController;
  late int _currentIndex;
  final TransformationController _transController = TransformationController();

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex.clamp(0, widget.screenshots.isNotEmpty ? widget.screenshots.length - 1 : 0);
    _pageController = PageController(initialPage: _currentIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    _transController.dispose();
    super.dispose();
  }

  void _onDoubleTap() {
    if (_transController.value != Matrix4.identity()) {
      _transController.value = Matrix4.identity();
    } else {
      _transController.value = Matrix4.identity()..scale(2.5);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.screenshots.isEmpty) {
      return Scaffold(
        backgroundColor: CxColors.background,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          leading: IconButton(
            icon: const Icon(Icons.close, color: CxColors.textPrimary),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ),
        body: const Center(
          child: Text(
            'No screenshots available',
            style: TextStyle(color: CxColors.textSecondary),
          ),
        ),
      );
    }

    final currentItem = widget.screenshots[_currentIndex];

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            // Main Interactive PageView
            GestureDetector(
              onDoubleTap: _onDoubleTap,
              child: PageView.builder(
                controller: _pageController,
                itemCount: widget.screenshots.length,
                onPageChanged: (index) {
                  setState(() {
                    _currentIndex = index;
                    _transController.value = Matrix4.identity();
                  });
                },
                itemBuilder: (context, index) {
                  final sc = widget.screenshots[index];
                  return InteractiveViewer(
                    transformationController: _transController,
                    minScale: 1.0,
                    maxScale: 4.0,
                    child: Center(
                      child: Hero(
                        tag: 'store_screenshot_${sc.id}',
                        child: CachedNetworkImage(
                          imageUrl: sc.url,
                          fit: BoxFit.contain,
                          placeholder: (context, url) => Container(
                            alignment: Alignment.center,
                            child: const SizedBox(
                              width: 36,
                              height: 36,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                color: CxColors.crimson,
                              ),
                            ),
                          ),
                          errorWidget: (context, url, error) => Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.broken_image_rounded, color: CxColors.crimson, size: 52),
                              const SizedBox(height: 12),
                              Text(
                                'Could not load screenshot',
                                style: GoogleFonts.inter(color: CxColors.textSecondary, fontSize: 13),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),

            // Top Header Bar
            Positioned(
              top: 8,
              left: 12,
              right: 12,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.black.withAlpha(180),
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(color: CxColors.borderSubtle),
                ),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.close_rounded, color: Colors.white, size: 24),
                      onPressed: () => Navigator.of(context).pop(),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                    const SizedBox(width: 14),
                    Text(
                      '${_currentIndex + 1} / ${widget.screenshots.length}',
                      style: GoogleFonts.orbitron(
                        color: CxColors.textPrimary,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: CxColors.crimson.withAlpha(50),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: CxColors.borderDefault),
                      ),
                      child: Text(
                        currentItem.featureCategory,
                        style: GoogleFonts.inter(
                          color: CxColors.brightRed,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Navigation Arrows (Left / Right)
            if (_currentIndex > 0)
              Positioned(
                left: 12,
                top: 0,
                bottom: 0,
                child: Center(
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.black.withAlpha(150),
                      shape: BoxShape.circle,
                      border: Border.all(color: CxColors.borderSubtle),
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.chevron_left_rounded, color: Colors.white, size: 28),
                      onPressed: () {
                        _pageController.previousPage(
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeOutCubic,
                        );
                      },
                    ),
                  ),
                ),
              ),

            if (_currentIndex < widget.screenshots.length - 1)
              Positioned(
                right: 12,
                top: 0,
                bottom: 0,
                child: Center(
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.black.withAlpha(150),
                      shape: BoxShape.circle,
                      border: Border.all(color: CxColors.borderSubtle),
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.chevron_right_rounded, color: Colors.white, size: 28),
                      onPressed: () {
                        _pageController.nextPage(
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeOutCubic,
                        );
                      },
                    ),
                  ),
                ),
              ),

            // Bottom Caption & Info Card
            Positioned(
              bottom: 12,
              left: 12,
              right: 12,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF0F0F0F).withAlpha(235),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: CxColors.borderDefault),
                  boxShadow: CxShadows.subtle,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      currentItem.title,
                      style: GoogleFonts.inter(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: CxColors.textPrimary,
                        letterSpacing: 0.3,
                      ),
                    ),
                    if (currentItem.caption != null && currentItem.caption!.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        currentItem.caption!,
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: CxColors.textSecondary,
                          height: 1.4,
                        ),
                      ),
                    ],
                    const SizedBox(height: 12),
                    // Mini Indicators
                    Center(
                      child: Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        alignment: WrapAlignment.center,
                        children: List.generate(widget.screenshots.length, (idx) {
                          final isSelected = idx == _currentIndex;
                          return GestureDetector(
                            onTap: () {
                              _pageController.animateToPage(
                                idx,
                                duration: const Duration(milliseconds: 300),
                                curve: Curves.easeOutCubic,
                              );
                            },
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              width: isSelected ? 22 : 6,
                              height: 6,
                              decoration: BoxDecoration(
                                color: isSelected ? CxColors.brightRed : CxColors.textMuted.withAlpha(100),
                                borderRadius: BorderRadius.circular(3),
                              ),
                            ),
                          );
                        }),
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
  }
}
