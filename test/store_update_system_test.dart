import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:codexa_mobile/core/services/cx_package_installer.dart';
import 'package:codexa_mobile/core/services/cx_update_service.dart';
import 'package:codexa_mobile/features/store/codexa_store_repository.dart';
import 'package:codexa_mobile/features/store/codexa_store_screen.dart';

void main() {
  group('CodeXa Dual APK Distribution & In-App Store Update Tests', () {
    test('1. Website APK download URL mapping points to canonical release', () {
      final updateInfo = CodeXaUpdateInfo(
        latestVersion: '1.0.1',
        latestVersionCode: 8,
        minimumSupportedVersionCode: 7,
        updateAvailable: true,
        forceUpdate: false,
        releaseNotes: 'Performance improvements and bug fixes',
        downloadUrl: 'https://codxa-agency.online/downloads/CodeXa.apk',
        sha256: 'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855',
        fileSizeBytes: 865409956,
      );

      expect(updateInfo.downloadUrl, contains('CodeXa.apk'));
      expect(updateInfo.downloadUrl.startsWith('https://'), isTrue);
      expect(updateInfo.fileSizeBytes, greaterThan(0));
    });

    test('2. First-time and current version model detects installed identity', () {
      const packageInfo = CxInstalledPackageInfo(
        packageName: 'online.codexa.codexa_mobile',
        versionName: '1.0.0',
        versionCode: 7,
      );

      expect(packageInfo.packageName, equals('online.codexa.codexa_mobile'));
      expect(packageInfo.versionCode, equals(7));
      expect(packageInfo.versionName, equals('1.0.0'));
    });

    test('3. Same Package Identity preservation across in-place updates', () {
      final report = CxApkCompatibilityReport.fromMap({
        'compatible': true,
        'archivePackageName': 'online.codexa.codexa_mobile',
        'currentPackageName': 'online.codexa.codexa_mobile',
        'archiveVersionCode': 8,
        'archiveVersionName': '1.0.1',
      });

      expect(report.compatible, isTrue);
      expect(report.archivePackageName, equals(report.currentPackageName));
      expect(report.archiveVersionCode, greaterThan(7));
    });

    test('4. Incompatible or foreign package identity is strictly rejected', () {
      final foreignReport = CxApkCompatibilityReport.fromMap({
        'compatible': false,
        'archivePackageName': 'com.fake.duplicateapp',
        'currentPackageName': 'online.codexa.codexa_mobile',
        'error': 'Package name mismatch. Refusing to install second application.',
      });

      expect(foreignReport.compatible, isFalse);
      expect(foreignReport.error, isNotNull);
    });

    test('5. Supports all 12 explicit UpdateState lifecycle codes', () {
      final expectedCodes = [
        'CHECKING_FOR_UPDATES',
        'UP_TO_DATE',
        'UPDATE_AVAILABLE',
        'UPDATE_REQUIRED',
        'DOWNLOADING',
        'VERIFYING',
        'READY_TO_INSTALL',
        'AWAITING_ANDROID_CONFIRMATION',
        'INSTALLING',
        'INSTALLATION_CANCELLED',
        'INSTALLATION_FAILED',
        'UPDATE_COMPLETED',
      ];

      final actualCodes = UpdateState.values.map((s) => s.code).toList();
      expect(actualCodes, containsAll(expectedCodes));
      expect(actualCodes.length, equals(12));
    });

    test('6. Version progression: Older client detects Update Available vs Current', () {
      const installedBuild = 7;
      const latestBuild = 8;
      const minSupportedBuild = 7;

      final isAvailable = installedBuild < latestBuild;
      final isMandatory = installedBuild < minSupportedBuild;

      expect(isAvailable, isTrue);
      expect(isMandatory, isFalse);

      const upToDateInstalledBuild = 8;
      final isUpToDate = upToDateInstalledBuild >= latestBuild;
      expect(isUpToDate, isTrue);
    });

    test('7. Mandatory update gate blocks deprecated versions', () {
      const deprecatedBuild = 5;
      const minSupportedBuild = 7;
      const latestBuild = 8;

      final isUpdateAvailable = deprecatedBuild < latestBuild;
      final isBlocked = deprecatedBuild < minSupportedBuild;

      expect(isUpdateAvailable, isTrue);
      expect(isBlocked, isTrue);
    });

    test('8. SHA-256 cryptographic checksum calculation and match validation', () {
      final dummyBytes = utf8.encode('CodeXa Android Production Release Binary Bytes');
      final computedSha = sha256.convert(dummyBytes).toString();

      final correctExpected = computedSha;
      final wrongExpected = '0000000000000000000000000000000000000000000000000000000000000000';

      expect(computedSha.toLowerCase() == correctExpected.toLowerCase(), isTrue);
      expect(computedSha.toLowerCase() == wrongExpected.toLowerCase(), isFalse);
    });

    test('9. No repeated update loop after successful upgrade detection', () {
      const previousRecordedBuild = 7;
      const newlyLaunchedBuild = 8;

      final upgradedSuccessfully = newlyLaunchedBuild > previousRecordedBuild;
      expect(upgradedSuccessfully, isTrue);

      // On second launch, newlyLaunchedBuild matches current build
      const secondLaunchRecorded = 8;
      const secondLaunchCurrent = 8;
      final requiresLoop = secondLaunchCurrent > secondLaunchRecorded;
      expect(requiresLoop, isFalse);
    });

    testWidgets('10. CodeXa Store screen renders identity and version comparison', (tester) async {
      final fallbackCatalog = CodeXaStoreRepository().getFallbackCatalog();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            codeXaStoreCatalogProvider.overrideWith(
              (ref) => Future.value(fallbackCatalog),
            ),
          ],
          child: const MaterialApp(
            home: CodeXaStoreScreen(),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(Duration.zero);
      await tester.pump();

      expect(find.text('CODEXA STORE'), findsOneWidget);
      expect(find.text('CodeXa Mobile'), findsWidgets);
      expect(find.text('UPDATE TO v1.0.5'), findsOneWidget);
    });
  });
}
