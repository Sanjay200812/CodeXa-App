import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/theme/cx_theme.dart';

/// Secure View-Once media viewer for ephemeral photos and videos
class ViewOnceMediaViewer extends StatefulWidget {
  final String mediaUrl;
  final bool isVideo;

  const ViewOnceMediaViewer({
    super.key,
    required this.mediaUrl,
    this.isVideo = false,
  });

  @override
  State<ViewOnceMediaViewer> createState() => _ViewOnceMediaViewerState();
}

class _ViewOnceMediaViewerState extends State<ViewOnceMediaViewer> {
  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async => true,
      child: Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          backgroundColor: Colors.black.withOpacity(0.6),
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.close, color: Colors.white),
            onPressed: () => Navigator.of(context).pop(),
          ),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: CxColors.brightRed.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: CxColors.brightRed),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.looks_one,
                      size: 14,
                      color: CxColors.brightRed,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'VIEW ONCE',
                      style: GoogleFonts.orbitron(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        body: Center(
          child: InteractiveViewer(
            panEnabled: true,
            boundaryMargin: const EdgeInsets.all(20),
            minScale: 0.5,
            maxScale: 4.0,
            child: CachedNetworkImage(
              imageUrl: widget.mediaUrl,
              fit: BoxFit.contain,
              placeholder: (_, __) => const Center(
                child: CircularProgressIndicator(color: CxColors.brightRed),
              ),
              errorWidget: (_, __, ___) => Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.lock_clock,
                      size: 48,
                      color: CxColors.textMuted,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'This media is no longer available.',
                      style: GoogleFonts.inter(
                        color: Colors.white70,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
