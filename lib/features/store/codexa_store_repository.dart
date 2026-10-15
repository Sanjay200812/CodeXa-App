import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/api/api_client.dart';
import 'codexa_store_models.dart';

class CodeXaStoreRepository {
  final CxApiClient _api = CxApiClient();
  static const String _cacheKey = 'codexa_store_catalog_cache_v2';

  Future<StoreCatalog> fetchCatalog({bool forceRefresh = false}) async {
    SharedPreferences? prefs;
    try {
      prefs = await SharedPreferences.getInstance();
    } catch (e) {
      debugPrint('[StoreRepo] SharedPreferences error: $e');
    }

    try {
      final res = await _api.dio.get(
        '/api/mobile/store/catalog',
        queryParameters: forceRefresh ? {'_t': DateTime.now().millisecondsSinceEpoch} : null,
      );

      if (res.data != null && res.data['ok'] == true) {
        final data = res.data as Map<String, dynamic>;
        if (prefs != null) {
          try {
            await prefs.setString(_cacheKey, jsonEncode(data));
          } catch (cacheErr) {
            debugPrint('[StoreRepo] Cache write warning: $cacheErr');
          }
        }
        return StoreCatalog.fromMap(data);
      }
    } catch (e) {
      debugPrint('[StoreRepo] Remote fetch failed: $e. Attempting cache fallback.');
    }

    // Try cache
    if (prefs != null) {
      final cachedJson = prefs.getString(_cacheKey);
      if (cachedJson != null && cachedJson.isNotEmpty) {
        try {
          final data = jsonDecode(cachedJson) as Map<String, dynamic>;
          debugPrint('[StoreRepo] Returning cached catalog.');
          return StoreCatalog.fromMap(data);
        } catch (parseErr) {
          debugPrint('[StoreRepo] Cache parse failed: $parseErr');
        }
      }
    }

    // Return authoritative canonical fallback
    debugPrint('[StoreRepo] Returning canonical fallback catalog.');
    return getFallbackCatalog();
  }

  StoreCatalog getFallbackCatalog() {
    return const StoreCatalog(
      application: StoreApplication(
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
        shortDescription: 'The unified production workspace for CodeXa Agency workforce, interns, and leadership.',
        fullDescription: 'Manage real-time agency workflows, collaborative chat rooms, live training sessions, project milestones, verified geo-attendance, and instant push updates — all within one synchronized interface.',
      ),
      release: {
        'versionName': '1.0.5',
        'versionCode': 105,
        'downloadUrl': 'https://codxa-agency.online/downloads/CodeXa.apk',
        'apkSizeBytes': 148582251,
        'apkSizeFormatted': '141.7 MB',
        'sha256': '5b4d72fccebb3503344b8c1f2afac88c42951cc9c4f04053c362df19c068db0f',
        'minAndroidVersion': 'Android 8.0 (API 26)',
        'releaseNotes': 'Official CodeXa Agency Android Release v1.0.5 with high-performance real-time features, portrait screenshot catalog, 1080p demo walkthrough, and enhanced security.',
        'publishedAt': '2026-10-10T17:45:00.000Z',
      },
      revision: 2,
      updatedAt: '2026-10-10T18:00:00.000Z',
      screenshots: [
        StoreScreenshot(
          id: 'sc-1',
          title: 'Secure Authentication & Modern Access',
          caption: 'Biometric and token-backed sign-in with enterprise multi-account session management.',
          altText: 'CodeXa Mobile login and credentials authentication screen',
          url: 'https://codxa-agency.online/appstore/screenshot-1.png',
          thumbnailUrl: 'https://codxa-agency.online/appstore/screenshot-1.png',
          displayOrder: 1,
          featureCategory: 'Authentication',
          isCover: true,
          fileSize: 421680,
          width: 941,
          height: 1672,
        ),
        StoreScreenshot(
          id: 'sc-2',
          title: 'Realtime Team & Intern Chat',
          caption: 'Instant messaging with typing indicators, presence, and multimedia attachments.',
          altText: 'CodeXa Mobile team chat channels and direct messages interface',
          url: 'https://codxa-agency.online/appstore/screenshot-2.png',
          thumbnailUrl: 'https://codxa-agency.online/appstore/screenshot-2.png',
          displayOrder: 2,
          featureCategory: 'Communication',
          isCover: false,
          fileSize: 395120,
          width: 941,
          height: 1672,
        ),
        StoreScreenshot(
          id: 'sc-3',
          title: 'Interactive Class & Session Hub',
          caption: 'Live curriculum schedule, video room links, and recorded archives.',
          altText: 'CodeXa Mobile scheduled classes, modules, and training curriculum',
          url: 'https://codxa-agency.online/appstore/screenshot-3.png',
          thumbnailUrl: 'https://codxa-agency.online/appstore/screenshot-3.png',
          displayOrder: 3,
          featureCategory: 'Training',
          isCover: false,
          fileSize: 452810,
          width: 941,
          height: 1672,
        ),
        StoreScreenshot(
          id: 'sc-4',
          title: 'Dynamic Project Workspaces',
          caption: 'Task management with agile Kanban boards, milestones, and deliverables.',
          altText: 'CodeXa Mobile active projects, client milestones, and task boards',
          url: 'https://codxa-agency.online/appstore/screenshot-4.png',
          thumbnailUrl: 'https://codxa-agency.online/appstore/screenshot-4.png',
          displayOrder: 4,
          featureCategory: 'Projects',
          isCover: false,
          fileSize: 489340,
          width: 941,
          height: 1672,
        ),
        StoreScreenshot(
          id: 'sc-5',
          title: 'Assignment Submission & Review',
          caption: 'Turn in assignments with real-time feedback, grading, and supervisor comments.',
          altText: 'CodeXa Mobile intern assignment submission and automated review pipeline',
          url: 'https://codxa-agency.online/appstore/screenshot-5.png',
          thumbnailUrl: 'https://codxa-agency.online/appstore/screenshot-5.png',
          displayOrder: 5,
          featureCategory: 'Assignments',
          isCover: false,
          fileSize: 412030,
          width: 941,
          height: 1672,
        ),
        StoreScreenshot(
          id: 'sc-6',
          title: 'Smart Attendance & QR Geofencing',
          caption: 'Daily check-in and checkout with geofence validation and audit logging.',
          altText: 'CodeXa Mobile location-verified attendance check-in system',
          url: 'https://codxa-agency.online/appstore/screenshot-6.png',
          thumbnailUrl: 'https://codxa-agency.online/appstore/screenshot-6.png',
          displayOrder: 6,
          featureCategory: 'Attendance',
          isCover: false,
          fileSize: 378450,
          width: 941,
          height: 1672,
        ),
        StoreScreenshot(
          id: 'sc-7',
          title: 'Enterprise Identity & Role Center',
          caption: 'Granular permissions covering Admins, Founders, Team Leads, and Interns.',
          altText: 'CodeXa Mobile user profile, credentials, and workforce status badge',
          url: 'https://codxa-agency.online/appstore/screenshot-7.png',
          thumbnailUrl: 'https://codxa-agency.online/appstore/screenshot-7.png',
          displayOrder: 7,
          featureCategory: 'Workforce',
          isCover: false,
          fileSize: 362910,
          width: 941,
          height: 1672,
        ),
        StoreScreenshot(
          id: 'sc-8',
          title: 'Performance Metrics & Analytics',
          caption: 'Track personal and team KPIs, learning velocity, and milestone completion.',
          altText: 'CodeXa Mobile real-time progress dashboard and KPI charts',
          url: 'https://codxa-agency.online/appstore/screenshot-8.png',
          thumbnailUrl: 'https://codxa-agency.online/appstore/screenshot-8.png',
          displayOrder: 8,
          featureCategory: 'Analytics',
          isCover: false,
          fileSize: 471200,
          width: 941,
          height: 1672,
        ),
        StoreScreenshot(
          id: 'sc-9',
          title: 'Realtime Push Notifications & VAPID',
          caption: 'Instant alerts for announcements, task assignments, and direct messages.',
          altText: 'CodeXa Mobile live activity feed and priority notification center',
          url: 'https://codxa-agency.online/appstore/screenshot-9.png',
          thumbnailUrl: 'https://codxa-agency.online/appstore/screenshot-9.png',
          displayOrder: 9,
          featureCategory: 'Notifications',
          isCover: false,
          fileSize: 405670,
          width: 941,
          height: 1672,
        ),
        StoreScreenshot(
          id: 'sc-10',
          title: 'Official CodeXa Store & Release Center',
          caption: 'Built-in direct updater, SHA-256 verification, and official website distribution.',
          altText: 'CodeXa Mobile in-app store, release notes, and SHA-256 verification center',
          url: 'https://codxa-agency.online/appstore/screenshot-10.png',
          thumbnailUrl: 'https://codxa-agency.online/appstore/screenshot-10.png',
          displayOrder: 10,
          featureCategory: 'Store',
          isCover: false,
          fileSize: 438190,
          width: 941,
          height: 1672,
        ),
      ],
      videos: [
        StoreVideo(
          id: 'vid-1',
          title: 'CodeXa Mobile — Complete Feature Walkthrough',
          description: 'Official 1080p high-definition walkthrough of CodeXa Mobile capabilities.',
          url: 'https://codxa-agency.online/appstore/codexa-demo-1080p.mp4',
          thumbnailUrl: 'https://codxa-agency.online/appstore/codexa-demo-poster.jpg',
          durationSeconds: 30.02,
          displayOrder: 1,
          isFeatured: true,
          mimeType: 'video/mp4',
          width: 1080,
          height: 1920,
          fileSize: 31876710,
        ),
      ],
      features: [
        StoreFeature(
          id: 'f-1',
          title: 'Realtime Team & Intern Chat',
          description: 'Low-latency messaging with channels, direct DMs, unread indicators, and secure uploads.',
          icon: 'MessageSquare',
          status: 'Active',
          category: 'Communication',
        ),
        StoreFeature(
          id: 'f-2',
          title: 'Attendance & QR Geofencing',
          description: 'Precision GPS geofencing with cryptographic QR check-in and monthly attendance audits.',
          icon: 'QrCode',
          status: 'Active',
          category: 'Operations',
        ),
        StoreFeature(
          id: 'f-3',
          title: 'Classes & Live Curriculum',
          description: 'Curated modules, schedule synchronizer, assignment links, and archived training resources.',
          icon: 'GraduationCap',
          status: 'Active',
          category: 'Learning',
        ),
        StoreFeature(
          id: 'f-4',
          title: 'Project & Sprint Tracking',
          description: 'Kanban boards, deliverables, milestones, and supervisor approvals in one workflow.',
          icon: 'Kanban',
          status: 'Active',
          category: 'Projects',
        ),
        StoreFeature(
          id: 'f-5',
          title: 'Realtime Push Notifications',
          description: 'Direct VAPID WebPush and Firebase cloud messages for emergency announcements and chat.',
          icon: 'Bell',
          status: 'Active',
          category: 'Alerts',
        ),
        StoreFeature(
          id: 'f-6',
          title: 'Role-Based Access Control',
          description: 'Strict authorization tiers: Founder, Co-Founder, Admin, Team Lead, and Intern.',
          icon: 'ShieldCheck',
          status: 'Active',
          category: 'Security',
        ),
      ],
      installationSteps: [
        StoreInstallStep(
          stepNumber: 1,
          title: 'Download Official APK',
          description: 'Download the verified CodeXa.apk build directly from our secure website.',
          tip: 'Always verify SHA-256 matches the official hash published above.',
        ),
        StoreInstallStep(
          stepNumber: 2,
          title: 'Allow Unknown Sources',
          description: 'When prompted by Android, enable "Allow from this source" for your browser or file manager.',
          tip: 'This is standard for apps distributed directly outside Google Play Store.',
        ),
        StoreInstallStep(
          stepNumber: 3,
          title: 'Install & Launch',
          description: 'Tap Install, open CodeXa Mobile, and sign in with your workforce or intern credentials.',
          tip: 'In-app auto-update will handle all future updates seamlessly.',
        ),
      ],
      troubleshooting: [
        StoreFaq(
          q: 'Why is CodeXa Mobile not on Google Play Store?',
          a: 'CodeXa Mobile is proprietary internal agency software distributed exclusively through our official website (codxa-agency.online) to maintain end-to-end security, rapid release cycles, and complete privacy for our workforce.',
          category: 'Distribution',
        ),
        StoreFaq(
          q: 'Is this APK safe to install on my Android phone?',
          a: 'Yes, 100%. Every APK is cryptographically signed and SHA-256 hashed. You can verify the checksum before installation. No adware, tracking, or third-party telemetry is included.',
          category: 'Security',
        ),
        StoreFaq(
          q: 'How do I receive app updates?',
          a: 'The app includes an automated release updater. When a new version is published, you will receive an in-app prompt with a one-tap update option.',
          category: 'Updates',
        ),
        StoreFaq(
          q: 'What Android version is required?',
          a: 'Android 8.0 (API Level 26) or higher. Works smoothly on Android 8, 9, 10, 11, 12, 13, 14, and 15.',
          category: 'Compatibility',
        ),
      ],
    );
  }
}

final codeXaStoreRepositoryProvider = Provider<CodeXaStoreRepository>((ref) {
  return CodeXaStoreRepository();
});

final codeXaStoreCatalogProvider = FutureProvider.autoDispose<StoreCatalog>((ref) async {
  final repo = ref.watch(codeXaStoreRepositoryProvider);
  return repo.fetchCatalog();
});
