import 'dart:async';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:video_player/video_player.dart';

import '../../core/theme/cx_theme.dart';

class CodexaVideoPlayerWidget extends StatefulWidget {
  final String videoUrl;
  final String posterUrl;
  final String title;
  final double durationSeconds;
  final VoidCallback? onFullscreenRequested;

  const CodexaVideoPlayerWidget({
    super.key,
    required this.videoUrl,
    required this.posterUrl,
    this.title = 'CodeXa Mobile Demo Walkthrough',
    this.durationSeconds = 30.0,
    this.onFullscreenRequested,
  });

  @override
  State<CodexaVideoPlayerWidget> createState() => _CodexaVideoPlayerWidgetState();
}

class _CodexaVideoPlayerWidgetState extends State<CodexaVideoPlayerWidget> {
  VideoPlayerController? _controller;
  bool _isInitialized = false;
  bool _isLoading = false;
  bool _hasError = false;
  bool _showControls = true;
  bool _isMuted = false;
  Timer? _hideControlsTimer;

  @override
  void dispose() {
    _hideControlsTimer?.cancel();
    _controller?.removeListener(_onControllerUpdate);
    _controller?.dispose();
    super.dispose();
  }

  void _onControllerUpdate() {
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _startPlayback() async {
    if (_controller != null && _isInitialized) {
      if (_controller!.value.isPlaying) {
        _controller!.pause();
      } else {
        _controller!.play();
        _scheduleHideControls();
      }
      return;
    }

    setState(() {
      _isLoading = true;
      _hasError = false;
    });

    try {
      final uri = Uri.parse(widget.videoUrl);
      final controller = VideoPlayerController.networkUrl(uri);
      _controller = controller;

      await controller.initialize();
      controller.addListener(_onControllerUpdate);

      if (mounted) {
        setState(() {
          _isInitialized = true;
          _isLoading = false;
        });
        controller.play();
        _scheduleHideControls();
      }
    } catch (e) {
      debugPrint('[CodexaVideoPlayer] Initialization error: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _hasError = true;
        });
      }
    }
  }

  void _togglePlayPause() {
    if (_controller == null || !_isInitialized) {
      _startPlayback();
      return;
    }

    if (_controller!.value.isPlaying) {
      _controller!.pause();
      _hideControlsTimer?.cancel();
      setState(() => _showControls = true);
    } else {
      _controller!.play();
      _scheduleHideControls();
    }
  }

  void _toggleMute() {
    if (_controller == null) return;
    setState(() {
      _isMuted = !_isMuted;
      _controller!.setVolume(_isMuted ? 0.0 : 1.0);
    });
  }

  void _toggleControlsVisibility() {
    setState(() {
      _showControls = !_showControls;
    });
    if (_showControls && (_controller?.value.isPlaying ?? false)) {
      _scheduleHideControls();
    }
  }

  void _scheduleHideControls() {
    _hideControlsTimer?.cancel();
    _hideControlsTimer = Timer(const Duration(seconds: 3), () {
      if (mounted && (_controller?.value.isPlaying ?? false)) {
        setState(() => _showControls = false);
      }
    });
  }

  String _formatDuration(Duration d) {
    final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  void _openFullscreenModal() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (ctx) => Scaffold(
          backgroundColor: Colors.black,
          body: SafeArea(
            child: Stack(
              children: [
                Center(
                  child: _controller != null && _isInitialized
                      ? AspectRatio(
                          aspectRatio: _controller!.value.aspectRatio,
                          child: VideoPlayer(_controller!),
                        )
                      : const CircularProgressIndicator(color: CxColors.crimson),
                ),
                Positioned(
                  top: 16,
                  left: 16,
                  child: IconButton(
                    icon: const Icon(Icons.close_rounded, color: Colors.white, size: 28),
                    onPressed: () => Navigator.of(ctx).pop(),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0C0C0C),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: CxColors.borderDefault),
        boxShadow: CxShadows.subtle,
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Video Viewport Area (16:9 or 9:16 adaptable, optimized for video)
          AspectRatio(
            aspectRatio: 16 / 9,
            child: Stack(
              fit: StackFit.expand,
              children: [
                // 1. Poster Image (shown initially or when not initialized)
                if (!_isInitialized)
                  CachedNetworkImage(
                    imageUrl: widget.posterUrl,
                    fit: BoxFit.cover,
                    placeholder: (context, url) => Container(
                      color: const Color(0xFF141414),
                      alignment: Alignment.center,
                      child: const CircularProgressIndicator(
                        strokeWidth: 2,
                        color: CxColors.crimson,
                      ),
                    ),
                    errorWidget: (context, url, error) => Container(
                      color: const Color(0xFF141414),
                      alignment: Alignment.center,
                      child: const Icon(
                        Icons.videocam_off_rounded,
                        color: CxColors.textMuted,
                        size: 42,
                      ),
                    ),
                  ),

                // 2. Initialized Video Player
                if (_isInitialized && _controller != null)
                  GestureDetector(
                    onTap: _toggleControlsVisibility,
                    child: Center(
                      child: AspectRatio(
                        aspectRatio: _controller!.value.aspectRatio,
                        child: VideoPlayer(_controller!),
                      ),
                    ),
                  ),

                // 3. Dark Gradient Overlay for readibility
                if (!_isInitialized || _showControls)
                  IgnorePointer(
                    ignoring: true,
                    child: Container(
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.black45,
                            Colors.transparent,
                            Colors.black87,
                          ],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                        ),
                      ),
                    ),
                  ),

                // 4. Center Play/Pause / Loading / Error Overlay
                if (_isLoading)
                  const Center(
                    child: SizedBox(
                      width: 46,
                      height: 46,
                      child: CircularProgressIndicator(
                        strokeWidth: 3,
                        color: CxColors.brightRed,
                      ),
                    ),
                  )
                else if (_hasError)
                  Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.error_outline_rounded, color: CxColors.crimson, size: 40),
                        const SizedBox(height: 8),
                        Text(
                          'Playback Error',
                          style: GoogleFonts.inter(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 10),
                        ElevatedButton.icon(
                          onPressed: _startPlayback,
                          icon: const Icon(Icons.refresh, size: 16),
                          label: const Text('Retry'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: CxColors.crimson,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                            textStyle: GoogleFonts.inter(fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                  )
                else if (!_isInitialized || _showControls)
                  Center(
                    child: GestureDetector(
                      onTap: _togglePlayPause,
                      child: Container(
                        width: 58,
                        height: 58,
                        decoration: BoxDecoration(
                          color: CxColors.crimson.withAlpha(220),
                          shape: BoxShape.circle,
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x60FF1E3C),
                              blurRadius: 18,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: Icon(
                          (_controller?.value.isPlaying ?? false)
                              ? Icons.pause_rounded
                              : Icons.play_arrow_rounded,
                          color: Colors.white,
                          size: 34,
                        ),
                      ),
                    ),
                  ),

                // 5. Top Info Bar (1080p Badge & Mute Toggle)
                Positioned(
                  top: 10,
                  left: 10,
                  right: 10,
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.black.withAlpha(190),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: CxColors.borderSubtle),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.hd_rounded, color: CxColors.brightRed, size: 14),
                            const SizedBox(width: 4),
                            Text(
                              '1080p HD',
                              style: GoogleFonts.orbitron(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Spacer(),
                      if (_isInitialized) ...[
                        GestureDetector(
                          onTap: _toggleMute,
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: Colors.black.withAlpha(190),
                              shape: BoxShape.circle,
                              border: Border.all(color: CxColors.borderSubtle),
                            ),
                            child: Icon(
                              _isMuted ? Icons.volume_off_rounded : Icons.volume_up_rounded,
                              color: Colors.white,
                              size: 16,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        GestureDetector(
                          onTap: _openFullscreenModal,
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: Colors.black.withAlpha(190),
                              shape: BoxShape.circle,
                              border: Border.all(color: CxColors.borderSubtle),
                            ),
                            child: const Icon(
                              Icons.fullscreen_rounded,
                              color: Colors.white,
                              size: 16,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),

                // 6. Bottom Scrub Bar & Position Timer (when initialized and controls visible)
                if (_isInitialized && _controller != null && _showControls)
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: Container(
                      padding: const EdgeInsets.fromLTRB(10, 0, 10, 8),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          VideoProgressIndicator(
                            _controller!,
                            allowScrubbing: true,
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            colors: const VideoProgressColors(
                              playedColor: CxColors.brightRed,
                              bufferedColor: Colors.white24,
                              backgroundColor: Colors.white10,
                            ),
                          ),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                _formatDuration(_controller!.value.position),
                                style: GoogleFonts.orbitron(
                                  color: Colors.white70,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              Text(
                                _formatDuration(_controller!.value.duration),
                                style: GoogleFonts.orbitron(
                                  color: Colors.white70,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // Description & Details Footer
          Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: CxColors.crimson.withAlpha(35),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: CxColors.borderDefault),
                  ),
                  child: const Icon(
                    Icons.play_circle_outline_rounded,
                    color: CxColors.brightRed,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.title,
                        style: GoogleFonts.inter(
                          color: CxColors.textPrimary,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Full 1080p HD walkthrough showcasing real-time chat, attendance geofencing, tasks, and system architecture.',
                        style: GoogleFonts.inter(
                          color: CxColors.textSecondary,
                          fontSize: 11,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
