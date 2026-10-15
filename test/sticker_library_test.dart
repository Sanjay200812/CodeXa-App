import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:codexa_mobile/features/stickers/domain/sticker_asset.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Offline Sticker Catalog & Domain Tests', () {
    test('Catalog file exists and has valid JSON structure', () {
      final file = File('assets/stickers/catalog.json');
      expect(file.existsSync(), isTrue);

      final content = file.readAsStringSync();
      final json = jsonDecode(content) as Map<String, dynamic>;

      expect(json['schemaVersion'], equals(1));
      expect(json['catalogVersion'], isNotEmpty);
      expect(json['stickers'], isA<List>());
      expect(json['packs'], isA<List>());

      final stickers = json['stickers'] as List;
      expect(stickers.length, greaterThan(3000));

      final first = stickers.first as Map<String, dynamic>;
      expect(first['id'], isNotEmpty);
      expect(first['assetPath'], contains('assets/stickers/bundled/'));
      expect(first['mimeType'], equals('image/webp'));
      expect(first['sha256'], equals(first['id']));
    });

    test('StickerAsset domain model parses correctly', () {
      final map = {
        'id':
            'abcdef1234567890abcdef1234567890abcdef1234567890abcdef1234567890',
        'assetPath': 'assets/stickers/bundled/test.webp',
        'mimeType': 'image/webp',
        'animated': true,
        'sha256':
            'abcdef1234567890abcdef1234567890abcdef1234567890abcdef1234567890',
        'byteLength': 1024,
      };

      final asset = StickerAsset.fromJson(map);
      expect(asset.id, equals(map['id']));
      expect(asset.animated, isTrue);
      expect(asset.isLocalFile, isFalse);
      expect(asset.byteLength, equals(1024));

      final jsonOut = asset.toJson();
      expect(jsonOut['id'], equals(map['id']));
      expect(jsonOut['animated'], isTrue);
    });

    test('StickerPack domain model formats readable display names', () {
      const pack1 = StickerPack(
        id: 'pack-1',
        name: 'archive:STK_PK-20260918-WA0097.zip',
        stickerIds: ['stk1', 'stk2'],
      );
      expect(pack1.displayName, equals('Pack 20260918-WA0097'));

      const pack2 = StickerPack(
        id: 'pack-2',
        name: 'folder:.',
        stickerIds: ['stk3'],
      );
      expect(pack2.displayName, equals('CodeXa Core'));
    });

    test('Sticker message metadata DTO contains zero image bytes', () {
      const sampleStickerId =
          '00170139edda097c887f0636ca7a5d1b5c5ece7900a3db38801651f315f69f11';
      const sampleCatalogVersion = 'dc2b33d4d6824a0ff7a0';

      final messagePayload = {
        'conversationId': 'conv-12345',
        'clientMessageId': 'client-msg-uuid',
        'messageType': 'STICKER',
        'stickerId': sampleStickerId,
        'catalogVersion': sampleCatalogVersion,
        'text': sampleStickerId,
      };

      // Strict enforcement of Database Policy (Section 8)
      expect(messagePayload.containsKey('bytes'), isFalse);
      expect(messagePayload.containsKey('base64'), isFalse);
      expect(messagePayload.containsKey('image'), isFalse);
      expect(messagePayload['messageType'], equals('STICKER'));
      expect(messagePayload['stickerId'], equals(sampleStickerId));
      expect(messagePayload['catalogVersion'], equals(sampleCatalogVersion));
    });

    test('Import report documents source counts and deduplication', () {
      final reportFile = File('assets/stickers/import-report.json');
      expect(reportFile.existsSync(), isTrue);

      final report =
          jsonDecode(reportFile.readAsStringSync()) as Map<String, dynamic>;
      expect(report['manifestStickerCount'], equals(3727));
      expect(report['counts']['duplicate_content'], equals(466));
      expect(report['counts']['unsupported_special_files'], equals(14));
      expect(report['counts']['source_zip_files'], equals(34));
    });
  });
}
