import 'dart:io';

class StickerAsset {
  final String id;
  final String assetPath;
  final String mimeType;
  final bool animated;
  final String sha256;
  final int byteLength;
  final bool isLocalFile;
  final String? localFilePath;
  final String? packId;
  final String? packName;

  const StickerAsset({
    required this.id,
    required this.assetPath,
    this.mimeType = 'image/webp',
    this.animated = false,
    required this.sha256,
    this.byteLength = 0,
    this.isLocalFile = false,
    this.localFilePath,
    this.packId,
    this.packName,
  });

  File? get file => localFilePath != null ? File(localFilePath!) : null;

  factory StickerAsset.fromJson(
    Map<String, dynamic> json, {
    String? packId,
    String? packName,
  }) {
    final assetPath = json['assetPath'] as String? ?? '';
    final isDiskFile =
        json['isLocalFile'] == true || !assetPath.startsWith('assets/');
    return StickerAsset(
      id: json['id'] as String? ?? json['sha256'] as String? ?? '',
      assetPath: assetPath,
      mimeType: json['mimeType'] as String? ?? 'image/webp',
      animated: json['animated'] == true,
      sha256: json['sha256'] as String? ?? json['id'] as String? ?? '',
      byteLength: (json['byteLength'] as num?)?.toInt() ?? 0,
      isLocalFile: isDiskFile,
      localFilePath: isDiskFile
          ? (json['localFilePath'] as String? ?? assetPath)
          : null,
      packId: packId ?? json['packId'] as String?,
      packName: packName ?? json['packName'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'assetPath': assetPath,
      'mimeType': mimeType,
      'animated': animated,
      'sha256': sha256,
      'byteLength': byteLength,
      'isLocalFile': isLocalFile,
      'localFilePath': localFilePath,
      if (packId != null) 'packId': packId,
      if (packName != null) 'packName': packName,
    };
  }

  StickerAsset copyWith({
    String? id,
    String? assetPath,
    String? mimeType,
    bool? animated,
    String? sha256,
    int? byteLength,
    bool? isLocalFile,
    String? localFilePath,
    String? packId,
    String? packName,
  }) {
    return StickerAsset(
      id: id ?? this.id,
      assetPath: assetPath ?? this.assetPath,
      mimeType: mimeType ?? this.mimeType,
      animated: animated ?? this.animated,
      sha256: sha256 ?? this.sha256,
      byteLength: byteLength ?? this.byteLength,
      isLocalFile: isLocalFile ?? this.isLocalFile,
      localFilePath: localFilePath ?? this.localFilePath,
      packId: packId ?? this.packId,
      packName: packName ?? this.packName,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is StickerAsset &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}

class StickerPack {
  final String id;
  final String name;
  final List<String> stickerIds;
  final bool isImported;

  const StickerPack({
    required this.id,
    required this.name,
    required this.stickerIds,
    this.isImported = false,
  });

  String get displayName {
    if (name.startsWith('archive:')) {
      final base = name.replaceFirst('archive:', '');
      return base.replaceAll('.zip', '').replaceAll('STK_PK-', 'Pack ');
    }
    if (name == 'folder:.') {
      return 'CodeXa Core';
    }
    if (name.startsWith('folder:')) {
      return name.replaceFirst('folder:', '');
    }
    return name;
  }

  factory StickerPack.fromJson(Map<String, dynamic> json) {
    return StickerPack(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? 'Sticker Pack',
      stickerIds:
          (json['stickerIds'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      isImported: json['isImported'] == true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'stickerIds': stickerIds,
      'isImported': isImported,
    };
  }
}
