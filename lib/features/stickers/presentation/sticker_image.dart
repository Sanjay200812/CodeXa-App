import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/cx_theme.dart';
import '../data/local_sticker_repository.dart';
import '../domain/sticker_asset.dart';

class StickerImage extends StatelessWidget {
  final String? stickerId;
  final StickerAsset? sticker;
  final double? width;
  final double? height;
  final BoxFit fit;
  final int? cacheWidth;
  final int? cacheHeight;
  final VoidCallback? onInstallPack;

  const StickerImage({
    super.key,
    this.stickerId,
    this.sticker,
    this.width,
    this.height,
    this.fit = BoxFit.contain,
    this.cacheWidth,
    this.cacheHeight,
    this.onInstallPack,
  });

  @override
  Widget build(BuildContext context) {
    final repo = LocalStickerRepository();
    final asset =
        sticker ?? (stickerId != null ? repo.resolveSticker(stickerId!) : null);

    if (asset == null) {
      return _buildMissingFallback(context);
    }

    if (asset.isLocalFile && asset.file != null) {
      return Image.file(
        asset.file!,
        width: width,
        height: height,
        fit: fit,
        cacheWidth: cacheWidth,
        cacheHeight: cacheHeight,
        errorBuilder: (context, error, stackTrace) =>
            _buildMissingFallback(context),
      );
    }

    return Image.asset(
      asset.assetPath,
      width: width,
      height: height,
      fit: fit,
      cacheWidth: cacheWidth,
      cacheHeight: cacheHeight,
      errorBuilder: (context, error, stackTrace) =>
          _buildMissingFallback(context),
    );
  }

  Widget _buildMissingFallback(BuildContext context) {
    return Container(
      width: width ?? 140,
      height: height ?? 140,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: const Color(0xFF13151B),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: CxColors.brightRed.withAlpha(80), width: 1),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(
            Icons.extension_off_outlined,
            color: CxColors.brightRed.withAlpha(200),
            size: 26,
          ),
          const SizedBox(height: 6),
          Text(
            'Sticker pack not installed',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
          if (onInstallPack != null) ...[
            const SizedBox(height: 6),
            InkWell(
              onTap: onInstallPack,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: CxColors.brightRed.withAlpha(30),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: CxColors.brightRed, width: 0.8),
                ),
                child: Text(
                  'Install Pack',
                  style: GoogleFonts.orbitron(
                    fontSize: 8,
                    fontWeight: FontWeight.bold,
                    color: CxColors.brightRed,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
