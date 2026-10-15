class StoreApplication {
  final String name;
  final String tagline;
  final String badgeText;
  final String platform;
  final String packageName;
  final String developer;
  final String distribution;
  final String officialWebsiteUrl;
  final String compatibility;
  final String supportEmail;
  final String supportPhone;
  final String shortDescription;
  final String fullDescription;

  const StoreApplication({
    required this.name,
    required this.tagline,
    required this.badgeText,
    required this.platform,
    required this.packageName,
    required this.developer,
    required this.distribution,
    required this.officialWebsiteUrl,
    required this.compatibility,
    required this.supportEmail,
    required this.supportPhone,
    required this.shortDescription,
    required this.fullDescription,
  });

  factory StoreApplication.fromMap(Map<String, dynamic> map) {
    return StoreApplication(
      name: map['name']?.toString() ?? 'CodeXa Mobile',
      tagline: map['tagline']?.toString() ?? 'Official CodeXa Agency Workspace',
      badgeText: map['badgeText']?.toString() ?? 'Available Exclusively on Our Official Website',
      platform: map['platform']?.toString() ?? 'android',
      packageName: map['packageName']?.toString() ?? 'online.codexa.codexa_mobile',
      developer: map['developer']?.toString() ?? 'CodeXa Agency',
      distribution: map['distribution']?.toString() ?? 'official_website',
      officialWebsiteUrl: map['officialWebsiteUrl']?.toString() ?? 'https://codxa-agency.online',
      compatibility: map['compatibility']?.toString() ?? 'Android 8.0 (Oreo) or later • SDK 26+',
      supportEmail: map['supportEmail']?.toString() ?? 'contact@codxa-agency.online',
      supportPhone: map['supportPhone']?.toString() ?? '+91 7075920852',
      shortDescription: map['shortDescription']?.toString() ?? '',
      fullDescription: map['fullDescription']?.toString() ?? '',
    );
  }
}

class StoreScreenshot {
  final String id;
  final String title;
  final String? caption;
  final String? altText;
  final String url;
  final String thumbnailUrl;
  final int displayOrder;
  final String featureCategory;
  final bool isCover;
  final int fileSize;
  final int width;
  final int height;

  const StoreScreenshot({
    required this.id,
    required this.title,
    this.caption,
    this.altText,
    required this.url,
    required this.thumbnailUrl,
    required this.displayOrder,
    required this.featureCategory,
    required this.isCover,
    required this.fileSize,
    required this.width,
    required this.height,
  });

  factory StoreScreenshot.fromMap(Map<String, dynamic> map) {
    return StoreScreenshot(
      id: map['id']?.toString() ?? '',
      title: map['title']?.toString() ?? 'CodeXa Mobile Screenshot',
      caption: map['caption']?.toString(),
      altText: map['altText']?.toString(),
      url: map['url']?.toString() ?? '',
      thumbnailUrl: map['thumbnailUrl']?.toString() ?? map['url']?.toString() ?? '',
      displayOrder: (map['displayOrder'] as num?)?.toInt() ?? 0,
      featureCategory: map['featureCategory']?.toString() ?? 'General',
      isCover: map['isCover'] == true,
      fileSize: (map['fileSize'] as num?)?.toInt() ?? 0,
      width: (map['width'] as num?)?.toInt() ?? 941,
      height: (map['height'] as num?)?.toInt() ?? 1672,
    );
  }
}

class StoreVideo {
  final String id;
  final String title;
  final String? description;
  final String url;
  final String thumbnailUrl;
  final double durationSeconds;
  final int displayOrder;
  final bool isFeatured;
  final String mimeType;
  final int width;
  final int height;
  final int fileSize;

  const StoreVideo({
    required this.id,
    required this.title,
    this.description,
    required this.url,
    required this.thumbnailUrl,
    required this.durationSeconds,
    required this.displayOrder,
    required this.isFeatured,
    required this.mimeType,
    required this.width,
    required this.height,
    required this.fileSize,
  });

  factory StoreVideo.fromMap(Map<String, dynamic> map) {
    return StoreVideo(
      id: map['id']?.toString() ?? '',
      title: map['title']?.toString() ?? 'CodeXa Mobile Demo Video',
      description: map['description']?.toString(),
      url: map['url']?.toString() ?? '',
      thumbnailUrl: map['thumbnailUrl']?.toString() ?? '',
      durationSeconds: (map['durationSeconds'] as num?)?.toDouble() ?? 30.0,
      displayOrder: (map['displayOrder'] as num?)?.toInt() ?? 0,
      isFeatured: map['isFeatured'] == true,
      mimeType: map['mimeType']?.toString() ?? 'video/mp4',
      width: (map['width'] as num?)?.toInt() ?? 1080,
      height: (map['height'] as num?)?.toInt() ?? 1920,
      fileSize: (map['fileSize'] as num?)?.toInt() ?? 0,
    );
  }
}

class StoreFeature {
  final String id;
  final String title;
  final String description;
  final String icon;
  final String status;
  final String category;

  const StoreFeature({
    required this.id,
    required this.title,
    required this.description,
    required this.icon,
    required this.status,
    required this.category,
  });

  factory StoreFeature.fromMap(Map<String, dynamic> map) {
    return StoreFeature(
      id: map['id']?.toString() ?? '',
      title: map['title']?.toString() ?? '',
      description: map['description']?.toString() ?? '',
      icon: map['icon']?.toString() ?? 'Sparkles',
      status: map['status']?.toString() ?? 'Available',
      category: map['category']?.toString() ?? 'General',
    );
  }
}

class StoreInstallStep {
  final int stepNumber;
  final String title;
  final String description;
  final String tip;

  const StoreInstallStep({
    required this.stepNumber,
    required this.title,
    required this.description,
    required this.tip,
  });

  factory StoreInstallStep.fromMap(Map<String, dynamic> map) {
    return StoreInstallStep(
      stepNumber: (map['stepNumber'] as num?)?.toInt() ?? 1,
      title: map['title']?.toString() ?? '',
      description: map['description']?.toString() ?? '',
      tip: map['tip']?.toString() ?? '',
    );
  }
}

class StoreFaq {
  final String q;
  final String a;
  final String category;

  const StoreFaq({
    required this.q,
    required this.a,
    required this.category,
  });

  factory StoreFaq.fromMap(Map<String, dynamic> map) {
    return StoreFaq(
      q: map['q']?.toString() ?? '',
      a: map['a']?.toString() ?? '',
      category: map['category']?.toString() ?? 'General',
    );
  }
}

class StoreCatalog {
  final StoreApplication application;
  final Map<String, dynamic>? release;
  final int revision;
  final String updatedAt;
  final List<StoreScreenshot> screenshots;
  final List<StoreVideo> videos;
  final List<StoreFeature> features;
  final List<StoreInstallStep> installationSteps;
  final List<StoreFaq> troubleshooting;

  const StoreCatalog({
    required this.application,
    this.release,
    required this.revision,
    required this.updatedAt,
    required this.screenshots,
    required this.videos,
    required this.features,
    required this.installationSteps,
    required this.troubleshooting,
  });

  factory StoreCatalog.fromMap(Map<String, dynamic> map) {
    final app = map['application'] is Map
        ? StoreApplication.fromMap(map['application'] as Map<String, dynamic>)
        : const StoreApplication(
            name: 'CodeXa Mobile',
            tagline: 'Official CodeXa Agency Workspace',
            badgeText: 'Available Exclusively on Our Official Website',
            platform: 'android',
            packageName: 'online.codexa.codexa_mobile',
            developer: 'CodeXa Agency',
            distribution: 'official_website',
            officialWebsiteUrl: 'https://codxa-agency.online',
            compatibility: 'Android 8.0 (Oreo) or later • SDK 26+',
            supportEmail: 'contact@codxa-agency.online',
            supportPhone: '+91 7075920852',
            shortDescription: '',
            fullDescription: '',
          );

    final cat = map['catalog'] is Map ? map['catalog'] as Map<String, dynamic> : <String, dynamic>{};

    final rawScreenshots = cat['screenshots'] as List? ?? [];
    final screenshots = rawScreenshots
        .map((s) => StoreScreenshot.fromMap(s as Map<String, dynamic>))
        .toList();

    final rawVideos = cat['videos'] as List? ?? [];
    final videos = rawVideos
        .map((v) => StoreVideo.fromMap(v as Map<String, dynamic>))
        .toList();

    final rawFeatures = cat['features'] as List? ?? [];
    final features = rawFeatures
        .map((f) => StoreFeature.fromMap(f as Map<String, dynamic>))
        .toList();

    final rawSteps = cat['installationSteps'] as List? ?? [];
    final steps = rawSteps
        .map((s) => StoreInstallStep.fromMap(s as Map<String, dynamic>))
        .toList();

    final rawFaq = cat['troubleshooting'] as List? ?? [];
    final faq = rawFaq
        .map((q) => StoreFaq.fromMap(q as Map<String, dynamic>))
        .toList();

    return StoreCatalog(
      application: app,
      release: map['release'] is Map ? map['release'] as Map<String, dynamic> : null,
      revision: (cat['revision'] as num?)?.toInt() ?? 1,
      updatedAt: cat['updatedAt']?.toString() ?? DateTime.now().toIso8601String(),
      screenshots: screenshots,
      videos: videos,
      features: features,
      installationSteps: steps,
      troubleshooting: faq,
    );
  }
}
