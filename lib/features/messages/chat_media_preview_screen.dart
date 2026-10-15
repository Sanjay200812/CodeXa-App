import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:video_player/video_player.dart';

import '../../core/theme/cx_theme.dart';

/// WhatsApp-style Media Preview Sheet with ephemeral "① View Once" toggle
class ChatMediaPreviewScreen extends StatefulWidget {
  final File file;
  final bool isVideo;
  final void Function(String caption, bool isViewOnce) onSend;

  const ChatMediaPreviewScreen({
    super.key,
    required this.file,
    this.isVideo = false,
    required this.onSend,
  });

  @override
  State<ChatMediaPreviewScreen> createState() => _ChatMediaPreviewScreenState();
}

class _ChatMediaPreviewScreenState extends State<ChatMediaPreviewScreen> {
  final TextEditingController _captionController = TextEditingController();
  bool _isViewOnce = false;
  VideoPlayerController? _videoController;

  @override
  void initState() {
    super.initState();
    if (widget.isVideo) {
      _videoController = VideoPlayerController.file(widget.file)
        ..initialize().then((_) {
          if (mounted) setState(() {});
          _videoController?.setLooping(true);
          _videoController?.play();
        });
    }
  }

  @override
  void dispose() {
    _videoController?.pause();
    _videoController?.dispose();
    _captionController.dispose();
    super.dispose();
  }

  void _toggleViewOnce() {
    HapticFeedback.selectionClick();
    setState(() {
      _isViewOnce = !_isViewOnce;
    });

    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          _isViewOnce
              ? 'View Once enabled: Recipient can open once'
              : 'Normal media: Will be saved in chat',
          style: const TextStyle(color: Colors.white, fontSize: 13),
        ),
        backgroundColor: const Color(0xFF1E1E1E),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _handleSend() {
    final caption = _captionController.text.trim();
    Navigator.of(context).pop();
    widget.onSend(caption, _isViewOnce);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            // Top Bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(
                      Icons.close,
                      color: Colors.white,
                      size: 26,
                    ),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF141414),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white12),
                    ),
                    child: Text(
                      widget.isVideo ? 'VIDEO PREVIEW' : 'PHOTO PREVIEW',
                      style: GoogleFonts.orbitron(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: Colors.white70,
                        letterSpacing: 1.0,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Media Preview Center
            Expanded(
              child: Center(
                child: widget.isVideo
                    ? (_videoController != null &&
                              _videoController!.value.isInitialized
                          ? AspectRatio(
                              aspectRatio: _videoController!.value.aspectRatio,
                              child: VideoPlayer(_videoController!),
                            )
                          : const CircularProgressIndicator(
                              color: CxColors.brightRed,
                            ))
                    : InteractiveViewer(
                        minScale: 0.8,
                        maxScale: 3.5,
                        child: Image.file(widget.file, fit: BoxFit.contain),
                      ),
              ),
            ),

            // Bottom Input with Caption, WhatsApp-style ① View Once, and Send
            Container(
              padding: EdgeInsets.only(
                left: 14,
                right: 14,
                top: 10,
                bottom: MediaQuery.of(context).viewInsets.bottom > 0
                    ? 10
                    : MediaQuery.of(context).padding.bottom + 10,
              ),
              decoration: BoxDecoration(
                color: const Color(0xFF0A0A0A).withOpacity(0.95),
                border: const Border(top: BorderSide(color: Color(0xFF1E1E1E))),
              ),
              child: Row(
                children: [
                  // Caption input
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      decoration: BoxDecoration(
                        color: const Color(0xFF141414),
                        borderRadius: BorderRadius.circular(22),
                        border: Border.all(color: const Color(0xFF262626)),
                      ),
                      child: TextField(
                        controller: _captionController,
                        style: GoogleFonts.inter(
                          color: Colors.white,
                          fontSize: 14,
                        ),
                        decoration: const InputDecoration(
                          hintText: 'Add a caption...',
                          hintStyle: TextStyle(
                            color: Colors.white38,
                            fontSize: 13,
                          ),
                          border: InputBorder.none,
                          isDense: true,
                          contentPadding: EdgeInsets.symmetric(vertical: 10),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),

                  // 20 & 21. WhatsApp-style View Once ① Toggle Button
                  GestureDetector(
                    onTap: _toggleViewOnce,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _isViewOnce
                            ? CxColors.crimson
                            : const Color(0xFF181818),
                        border: Border.all(
                          color: _isViewOnce
                              ? CxColors.brightRed
                              : Colors.white24,
                          width: _isViewOnce ? 2.0 : 1.2,
                        ),
                        boxShadow: _isViewOnce
                            ? [
                                BoxShadow(
                                  color: CxColors.crimson.withOpacity(0.5),
                                  blurRadius: 10,
                                  spreadRadius: 1,
                                ),
                              ]
                            : null,
                      ),
                      child: Center(
                        child: Text(
                          '①',
                          style: GoogleFonts.orbitron(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: _isViewOnce ? Colors.white : Colors.white60,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),

                  // Send Action Button
                  GestureDetector(
                    onTap: _handleSend,
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: CxColors.crimson,
                        boxShadow: [
                          BoxShadow(
                            color: CxColors.crimson.withOpacity(0.4),
                            blurRadius: 12,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: const Center(
                        child: Icon(
                          Icons.send_rounded,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
