import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../domain/sticker_asset.dart';

class ImportPackResult {
  final int importedCount;
  final int duplicateCount;
  final int rejectedCount;
  final String packName;
  final String? error;

  const ImportPackResult({
    required this.importedCount,
    required this.duplicateCount,
    required this.rejectedCount,
    required this.packName,
    this.error,
  });

  bool get success => error == null;
}

class LocalStickerRepository {
  static final LocalStickerRepository _instance =
      LocalStickerRepository._internal();
  factory LocalStickerRepository() => _instance;
  LocalStickerRepository._internal();

  bool _initialized = false;
  String _catalogVersion = 'dc2b33d4d6824a0ff7a0';
  final Map<String, StickerAsset> _stickersMap = {};
  final Map<String, StickerPack> _packsMap = {};
  final List<String> _favoriteIds = [];
  final List<String> _recentIds = [];

  bool get isInitialized => _initialized;
  String get catalogVersion => _catalogVersion;

  List<StickerAsset> get allStickers => _stickersMap.values.toList();
  List<StickerPack> get packs => _packsMap.values.toList();

  List<StickerAsset> get favorites {
    final list = <StickerAsset>[];
    for (final id in _favoriteIds) {
      final s = _stickersMap[id];
      if (s != null) list.add(s);
    }
    return list;
  }

  List<StickerAsset> get recent {
    final list = <StickerAsset>[];
    for (final id in _recentIds) {
      final s = _stickersMap[id];
      if (s != null) list.add(s);
    }
    return list;
  }

  Future<void> initialize() async {
    if (_initialized) return;

    try {
      // 1. Load bundled catalog from Flutter assets
      final catalogString = await rootBundle.loadString(
        'assets/stickers/catalog.json',
      );
      final catalogJson = jsonDecode(catalogString) as Map<String, dynamic>;

      _catalogVersion =
          catalogJson['catalogVersion'] as String? ?? _catalogVersion;

      final stickersList = (catalogJson['stickers'] as List<dynamic>?) ?? [];
      for (final item in stickersList) {
        if (item is Map<String, dynamic>) {
          final asset = StickerAsset.fromJson(item);
          _stickersMap[asset.id] = asset;
        }
      }

      final packsList = (catalogJson['packs'] as List<dynamic>?) ?? [];
      for (final item in packsList) {
        if (item is Map<String, dynamic>) {
          final pack = StickerPack.fromJson(item);
          _packsMap[pack.id] = pack;
        }
      }

      // Map pack details to stickers
      for (final pack in _packsMap.values) {
        for (final stickerId in pack.stickerIds) {
          final existing = _stickersMap[stickerId];
          if (existing != null && existing.packId == null) {
            _stickersMap[stickerId] = existing.copyWith(
              packId: pack.id,
              packName: pack.displayName,
            );
          }
        }
      }
    } catch (e) {
      debugPrint('[LocalStickerRepository] Bundled catalog load error: $e');
    }

    // 2. Load custom / installed packs from app-private storage
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final stickersDir = Directory('${appDir.path}/stickers');
      if (await stickersDir.exists()) {
        final customCatalogFile = File(
          '${stickersDir.path}/custom_catalog.json',
        );
        if (await customCatalogFile.exists()) {
          final customJson = jsonDecode(
            await customCatalogFile.readAsString(),
          ) as Map<String, dynamic>;
          final customStickers =
              (customJson['stickers'] as List<dynamic>?) ?? [];
          for (final item in customStickers) {
            if (item is Map<String, dynamic>) {
              final asset = StickerAsset.fromJson(item);
              final file = File(asset.assetPath);
              if (await file.exists()) {
                _stickersMap[asset.id] = asset;
              }
            }
          }

          final customPacks = (customJson['packs'] as List<dynamic>?) ?? [];
          for (final item in customPacks) {
            if (item is Map<String, dynamic>) {
              final pack = StickerPack.fromJson(item);
              _packsMap[pack.id] = pack;
            }
          }
        }
      }
    } catch (e) {
      debugPrint('[LocalStickerRepository] Custom catalog load error: $e');
    }

    // 3. Load favorites and recent from SharedPreferences
    try {
      final prefs = await SharedPreferences.getInstance();
      final favs = prefs.getStringList('codexa_sticker_favorites');
      if (favs != null) {
        _favoriteIds.clear();
        _favoriteIds.addAll(favs);
      }
      final rec = prefs.getStringList('codexa_sticker_recent');
      if (rec != null) {
        _recentIds.clear();
        _recentIds.addAll(rec);
      }
    } catch (e) {
      debugPrint('[LocalStickerRepository] SharedPreferences error: $e');
    }

    _initialized = true;
    debugPrint(
      '[LocalStickerRepository] Initialized with ${_stickersMap.length} stickers and ${_packsMap.length} packs.',
    );
  }

  StickerAsset? resolveSticker(String stickerId) {
    if (stickerId.isEmpty) return null;
    final sticker = _stickersMap[stickerId];
    if (sticker == null) return null;

    if (sticker.isLocalFile) {
      final f = File(sticker.assetPath);
      if (!f.existsSync()) return null;
    }
    return sticker;
  }

  bool isInstalled(String stickerId) {
    return resolveSticker(stickerId) != null;
  }

  List<StickerAsset> getStickersForPack(String packId) {
    final pack = _packsMap[packId];
    if (pack == null) return [];
    final list = <StickerAsset>[];
    for (final id in pack.stickerIds) {
      final s = resolveSticker(id);
      if (s != null) list.add(s);
    }
    return list;
  }

  bool isFavorite(String stickerId) {
    return _favoriteIds.contains(stickerId);
  }

  Future<void> toggleFavorite(String stickerId) async {
    if (_favoriteIds.contains(stickerId)) {
      _favoriteIds.remove(stickerId);
    } else {
      _favoriteIds.insert(0, stickerId);
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList('codexa_sticker_favorites', _favoriteIds);
    } catch (_) {}
  }

  Future<void> addRecent(String stickerId) async {
    _recentIds.remove(stickerId);
    _recentIds.insert(0, stickerId);
    if (_recentIds.length > 50) {
      _recentIds.removeRange(50, _recentIds.length);
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList('codexa_sticker_recent', _recentIds);
    } catch (_) {}
  }

  List<StickerAsset> searchStickers(String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return allStickers;
    return allStickers.where((s) {
      if (s.id.toLowerCase().contains(q)) return true;
      if (s.packName != null && s.packName!.toLowerCase().contains(q))
        return true;
      return false;
    }).toList();
  }

  /// Explicit offline sticker pack installation from local ZIP file
  Future<ImportPackResult> importPackFromZip(File zipFile) async {
    if (!await zipFile.exists()) {
      return ImportPackResult(
        importedCount: 0,
        duplicateCount: 0,
        rejectedCount: 0,
        packName: zipFile.path,
        error: 'Pack file does not exist',
      );
    }

    try {
      final bytes = await zipFile.readAsBytes();
      final archive = ZipDecoder().decodeBytes(bytes);

      final appDir = await getApplicationDocumentsDirectory();
      final stickersDir = Directory('${appDir.path}/stickers');
      if (!await stickersDir.exists()) {
        await stickersDir.create(recursive: true);
      }

      int imported = 0;
      int duplicates = 0;
      int rejected = 0;
      int totalUnpackedBytes = 0;
      const maxUnpackedBytes = 150 * 1024 * 1024; // 150 MB safety limit
      const maxPerFileBytes = 20 * 1024 * 1024; // 20 MB limit

      final packFileName = zipFile.uri.pathSegments.last;
      final packLabel = packFileName.replaceAll('.zip', '');
      final packId = sha256
          .convert(utf8.encode(packLabel))
          .toString()
          .substring(0, 24);
      final List<String> packStickerIds = [];

      for (final entry in archive) {
        if (!entry.isFile) continue;

        // Path traversal check
        final safeName = entry.name.replaceAll('\\', '/');
        if (safeName.startsWith('/') ||
            safeName.contains('..') ||
            safeName.contains(':')) {
          rejected++;
          continue;
        }

        final entryBytes = entry.content as List<int>;
        if (entryBytes.isEmpty || entryBytes.length > maxPerFileBytes) {
          rejected++;
          continue;
        }

        totalUnpackedBytes += entryBytes.length;
        if (totalUnpackedBytes > maxUnpackedBytes) {
          return ImportPackResult(
            importedCount: imported,
            duplicateCount: duplicates,
            rejectedCount: rejected,
            packName: packLabel,
            error: 'Decompression size limit exceeded (safety check)',
          );
        }

        // Validate image signature (WebP, PNG, GIF)
        final isWebP =
            entryBytes.length >= 12 &&
            entryBytes[0] == 0x52 &&
            entryBytes[1] == 0x49 &&
            entryBytes[2] == 0x46 &&
            entryBytes[3] == 0x46 &&
            entryBytes[8] == 0x57 &&
            entryBytes[9] == 0x45 &&
            entryBytes[10] == 0x42 &&
            entryBytes[11] == 0x50;

        final isPng =
            entryBytes.length >= 8 &&
            entryBytes[0] == 0x89 &&
            entryBytes[1] == 0x50 &&
            entryBytes[2] == 0x4E &&
            entryBytes[3] == 0x47;

        if (!isWebP && !isPng) {
          rejected++;
          continue;
        }

        // Compute stable content digest
        final digest = sha256.convert(entryBytes).toString();
        final ext = isWebP ? '.webp' : '.png';
        final outFilePath = '${stickersDir.path}/$digest$ext';
        final outFile = File(outFilePath);

        // Detect animation in WebP
        bool isAnimated = false;
        if (isWebP) {
          final str = String.fromCharCodes(
            entryBytes.sublist(
              0,
              entryBytes.length > 200 ? 200 : entryBytes.length,
            ),
          );
          isAnimated = str.contains('ANIM') || str.contains('ANMF');
        }

        packStickerIds.add(digest);

        if (!await outFile.exists()) {
          await outFile.writeAsBytes(entryBytes);
          imported++;
        } else {
          duplicates++;
        }

        final stickerAsset = StickerAsset(
          id: digest,
          assetPath: outFilePath,
          mimeType: isWebP ? 'image/webp' : 'image/png',
          animated: isAnimated,
          sha256: digest,
          byteLength: entryBytes.length,
          isLocalFile: true,
          localFilePath: outFilePath,
          packId: packId,
          packName: packLabel,
        );

        _stickersMap[digest] = stickerAsset;
      }

      // Add to packs
      final newPack = StickerPack(
        id: packId,
        name: packLabel,
        stickerIds: packStickerIds,
        isImported: true,
      );
      _packsMap[packId] = newPack;

      // Save custom catalog to disk
      await _persistCustomCatalog(stickersDir);

      return ImportPackResult(
        importedCount: imported,
        duplicateCount: duplicates,
        rejectedCount: rejected,
        packName: packLabel,
      );
    } catch (e) {
      debugPrint('[LocalStickerRepository] Import ZIP error: $e');
      return ImportPackResult(
        importedCount: 0,
        duplicateCount: 0,
        rejectedCount: 0,
        packName: zipFile.path,
        error: e.toString(),
      );
    }
  }

  Future<void> _persistCustomCatalog(Directory stickersDir) async {
    try {
      final customStickers = _stickersMap.values
          .where((s) => s.isLocalFile)
          .map((s) => s.toJson())
          .toList();
      final customPacks = _packsMap.values
          .where((p) => p.isImported)
          .map((p) => p.toJson())
          .toList();

      final payload = {
        'schemaVersion': 1,
        'stickers': customStickers,
        'packs': customPacks,
        'updatedAt': DateTime.now().toIso8601String(),
      };

      final customCatalogFile = File('${stickersDir.path}/custom_catalog.json');
      await customCatalogFile.writeAsString(jsonEncode(payload));
    } catch (e) {
      debugPrint('[LocalStickerRepository] Persist custom catalog error: $e');
    }
  }
}

final stickerRepositoryProvider = Provider<LocalStickerRepository>((ref) {
  return LocalStickerRepository();
});
