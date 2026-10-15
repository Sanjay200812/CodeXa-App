import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/cx_theme.dart';
import '../data/local_sticker_repository.dart';
import '../domain/sticker_asset.dart';
import 'sticker_image.dart';

class StickerPickerSheet extends StatefulWidget {
  final ValueChanged<String> onStickerSelected;

  const StickerPickerSheet({super.key, required this.onStickerSelected});

  static Future<void> show(
    BuildContext context, {
    required ValueChanged<String> onStickerSelected,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) =>
          StickerPickerSheet(onStickerSelected: onStickerSelected),
    );
  }

  @override
  State<StickerPickerSheet> createState() => _StickerPickerSheetState();
}

class _StickerPickerSheetState extends State<StickerPickerSheet>
    with SingleTickerProviderStateMixin {
  final LocalStickerRepository _repo = LocalStickerRepository();
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();

  String _searchQuery = '';
  String? _selectedPackId;
  bool _isImporting = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _tabController.addListener(() {
      if (mounted) setState(() {});
    });
    if (!_repo.isInitialized) {
      _repo.initialize().then((_) {
        if (mounted) setState(() {});
      });
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _handleImportPack() async {
    setState(() => _isImporting = true);
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['zip'],
      );

      if (result != null && result.files.single.path != null) {
        final file = File(result.files.single.path!);
        final importResult = await _repo.importPackFromZip(file);

        if (mounted) {
          if (importResult.success) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                backgroundColor: const Color(0xFF13151B),
                content: Text(
                  'Imported ${importResult.importedCount} stickers from "${importResult.packName}"',
                  style: GoogleFonts.inter(color: Colors.white, fontSize: 13),
                ),
              ),
            );
            setState(() {});
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                backgroundColor: CxColors.brightRed,
                content: Text(
                  'Import failed: ${importResult.error}',
                  style: GoogleFonts.inter(color: Colors.white, fontSize: 13),
                ),
              ),
            );
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: CxColors.brightRed,
            content: Text(
              'Failed to pick pack: $e',
              style: GoogleFonts.inter(color: Colors.white),
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isImporting = false);
    }
  }

  void _showStickerPreview(StickerAsset sticker) {
    showDialog(
      context: context,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final isFav = _repo.isFavorite(sticker.id);

            return Dialog(
              backgroundColor: const Color(0xFF0D0F14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: const BorderSide(color: CxColors.borderSubtle, width: 1),
              ),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Top header: pack info & favorite button
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            sticker.packName ?? 'CodeXa Sticker',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.orbitron(
                              fontSize: 12,
                              color: CxColors.textSecondary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        IconButton(
                          icon: Icon(
                            isFav
                                ? Icons.star_rounded
                                : Icons.star_outline_rounded,
                            color: isFav ? Colors.amber : CxColors.textMuted,
                            size: 26,
                          ),
                          onPressed: () async {
                            await _repo.toggleFavorite(sticker.id);
                            setDialogState(() {});
                            if (mounted) setState(() {});
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Preview Sticker (large display)
                    Container(
                      width: 180,
                      height: 180,
                      alignment: Alignment.center,
                      child: StickerImage(
                        sticker: sticker,
                        width: 170,
                        height: 170,
                        fit: BoxFit.contain,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Animation tag if animated
                    if (sticker.animated)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 3,
                        ),
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: CxColors.brightRed.withAlpha(30),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: CxColors.brightRed,
                            width: 0.8,
                          ),
                        ),
                        child: Text(
                          'ANIMATED',
                          style: GoogleFonts.orbitron(
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                            color: CxColors.brightRed,
                            letterSpacing: 1,
                          ),
                        ),
                      ),

                    // Send Button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: CxColors.brightRed,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        icon: const Icon(Icons.send_rounded, size: 18),
                        label: Text(
                          'SEND STICKER',
                          style: GoogleFonts.orbitron(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1,
                          ),
                        ),
                        onPressed: () {
                          Navigator.pop(dialogCtx);
                          Navigator.pop(context);
                          _repo.addRecent(sticker.id);
                          widget.onStickerSelected(sticker.id);
                        },
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      height: MediaQuery.of(context).size.height * 0.65 + bottomInset,
      decoration: const BoxDecoration(
        color: Color(0xFF090A0E),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        border: Border(top: BorderSide(color: Color(0xFF1E222B), width: 1.5)),
      ),
      child: Column(
        children: [
          // Drag Handle
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 10, bottom: 6),
              width: 38,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white.withAlpha(50),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            'CODEXA STICKERS',
                            style: GoogleFonts.orbitron(
                              fontSize: 14,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                              letterSpacing: 1.2,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: CxColors.brightRed.withAlpha(30),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              '${_repo.allStickers.length}',
                              style: GoogleFonts.orbitron(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: CxColors.brightRed,
                              ),
                            ),
                          ),
                        ],
                      ),
                      Text(
                        'Device-local WhatsApp library',
                        style: GoogleFonts.inter(
                          fontSize: 10,
                          color: CxColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                // Offline Pack Import Button
                InkWell(
                  onTap: _isImporting ? null : _handleImportPack,
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF151821),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: CxColors.borderSubtle),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _isImporting
                            ? const SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: CxColors.brightRed,
                                ),
                              )
                            : const Icon(
                                Icons.file_upload_outlined,
                                size: 15,
                                color: CxColors.brightRed,
                              ),
                        const SizedBox(width: 6),
                        Text(
                          'IMPORT PACK',
                          style: GoogleFonts.orbitron(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Search input
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: Container(
              height: 38,
              decoration: BoxDecoration(
                color: const Color(0xFF13151D),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: CxColors.borderSubtle),
              ),
              child: TextField(
                controller: _searchController,
                style: GoogleFonts.inter(color: Colors.white, fontSize: 12),
                decoration: InputDecoration(
                  hintText: 'Search stickers or packs...',
                  hintStyle: GoogleFonts.inter(
                    color: CxColors.textMuted,
                    fontSize: 12,
                  ),
                  prefixIcon: const Icon(
                    Icons.search,
                    size: 18,
                    color: CxColors.textMuted,
                  ),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(
                            Icons.clear,
                            size: 16,
                            color: CxColors.textMuted,
                          ),
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _searchQuery = '');
                          },
                        )
                      : null,
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 9),
                ),
                onChanged: (val) => setState(() => _searchQuery = val),
              ),
            ),
          ),

          // Tabs: All, Packs, Recent, Favorites
          Container(
            height: 36,
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFF12141C),
              borderRadius: BorderRadius.circular(10),
            ),
            child: TabBar(
              controller: _tabController,
              indicator: BoxDecoration(
                color: CxColors.brightRed,
                borderRadius: BorderRadius.circular(8),
              ),
              indicatorSize: TabBarIndicatorSize.tab,
              dividerColor: Colors.transparent,
              labelColor: Colors.white,
              unselectedLabelColor: CxColors.textMuted,
              labelStyle: GoogleFonts.orbitron(
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
              unselectedLabelStyle: GoogleFonts.orbitron(fontSize: 10),
              tabs: const [
                Tab(text: 'ALL'),
                Tab(text: 'PACKS'),
                Tab(text: 'RECENT'),
                Tab(text: 'FAVORITES'),
              ],
            ),
          ),

          // Tab Content
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildAllTab(),
                _buildPacksTab(),
                _buildRecentTab(),
                _buildFavoritesTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAllTab() {
    final list = _searchQuery.isNotEmpty
        ? _repo.searchStickers(_searchQuery)
        : _repo.allStickers;

    if (list.isEmpty) {
      return _buildEmptyState(
        'No stickers found',
        Icons.sentiment_dissatisfied_outlined,
      );
    }

    return _buildStickerGrid(list);
  }

  Widget _buildPacksTab() {
    final packs = _repo.packs;
    if (packs.isEmpty) {
      return _buildEmptyState(
        'No sticker packs available',
        Icons.inventory_2_outlined,
      );
    }

    final activePackId = _selectedPackId ?? packs.first.id;
    final activePackStickers = _repo.getStickersForPack(activePackId);

    return Column(
      children: [
        // Horizontal Pack Pill Bar
        Container(
          height: 38,
          margin: const EdgeInsets.symmetric(vertical: 6),
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: packs.length,
            itemBuilder: (context, index) {
              final pack = packs[index];
              final isSelected = pack.id == activePackId;

              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: Text(
                    pack.displayName,
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: isSelected
                          ? FontWeight.w700
                          : FontWeight.w500,
                      color: isSelected ? Colors.white : CxColors.textSecondary,
                    ),
                  ),
                  selected: isSelected,
                  selectedColor: CxColors.brightRed,
                  backgroundColor: const Color(0xFF151821),
                  side: BorderSide(
                    color: isSelected
                        ? CxColors.brightRed
                        : CxColors.borderSubtle,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  onSelected: (val) {
                    if (val) setState(() => _selectedPackId = pack.id);
                  },
                ),
              );
            },
          ),
        ),

        // Grid for Active Pack
        Expanded(child: _buildStickerGrid(activePackStickers)),
      ],
    );
  }

  Widget _buildRecentTab() {
    final recents = _repo.recent;
    if (recents.isEmpty) {
      return _buildEmptyState(
        'No recently sent stickers',
        Icons.history_rounded,
      );
    }
    return _buildStickerGrid(recents);
  }

  Widget _buildFavoritesTab() {
    final favs = _repo.favorites;
    if (favs.isEmpty) {
      return _buildEmptyState(
        'No favorite stickers starred yet',
        Icons.star_border_rounded,
      );
    }
    return _buildStickerGrid(favs);
  }

  Widget _buildStickerGrid(List<StickerAsset> stickers) {
    return GridView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 5,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
        childAspectRatio: 1.0,
      ),
      itemCount: stickers.length,
      itemBuilder: (context, index) {
        final sticker = stickers[index];

        return InkWell(
          onTap: () {
            Navigator.pop(context);
            _repo.addRecent(sticker.id);
            widget.onStickerSelected(sticker.id);
          },
          onLongPress: () => _showStickerPreview(sticker),
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: Colors.transparent, // Transparent sticker artwork
              borderRadius: BorderRadius.circular(8),
            ),
            child: StickerImage(
              sticker: sticker,
              cacheWidth: 150,
              cacheHeight: 150,
              fit: BoxFit.contain,
            ),
          ),
        );
      },
    );
  }

  Widget _buildEmptyState(String message, IconData icon) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 36, color: CxColors.textMuted),
          const SizedBox(height: 8),
          Text(
            message,
            style: GoogleFonts.inter(fontSize: 12, color: CxColors.textMuted),
          ),
        ],
      ),
    );
  }
}
