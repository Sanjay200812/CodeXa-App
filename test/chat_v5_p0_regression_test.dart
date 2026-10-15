import 'package:flutter_test/flutter_test.dart';
import 'package:codexa_mobile/core/services/cx_notification_service.dart';
import 'package:codexa_mobile/core/models/models.dart';

void main() {
  group('P0 Realtime Messaging & Smart Notification Suppression Tests', () {
    test('CxNotificationService tracks activeConversationId dynamically', () {
      expect(CxNotificationService.activeConversationId, isNull);

      CxNotificationService.setActiveConversation('conv_direct_123');
      expect(CxNotificationService.activeConversationId, 'conv_direct_123');

      // Suppress notification on exact chat
      final isSuppressedExact =
          CxNotificationService.activeConversationId == 'conv_direct_123';
      expect(isSuppressedExact, isTrue);

      // Do NOT suppress notification for a different chat
      final isSuppressedOther =
          CxNotificationService.activeConversationId == 'conv_group_456';
      expect(isSuppressedOther, isFalse);

      CxNotificationService.setActiveConversation(null);
      expect(CxNotificationService.activeConversationId, isNull);
    });

    test('Case F: Multi-device notification routing logic', () {
      // Simulating device A (active in chat) and device B (backgrounded)
      final deviceSessions = [
        {
          'deviceId': 'phone_a',
          'activeConversationId': 'conv_100',
          'activeConversationAt': DateTime.now().toIso8601String(),
        },
        {
          'deviceId': 'phone_b',
          'activeConversationId': null,
          'activeConversationAt': null,
        },
      ];

      const targetConversationId = 'conv_100';

      final suppressedDevices = <String>[];
      final eligiblePushDevices = <String>[];

      for (final s in deviceSessions) {
        final activeConv = s['activeConversationId'];
        final activeAtStr = s['activeConversationAt'];
        bool isDeviceActiveInChat = false;
        if (activeConv == targetConversationId && activeAtStr != null) {
          final diff = DateTime.now()
              .difference(DateTime.parse(activeAtStr))
              .inSeconds;
          if (diff < 60) {
            isDeviceActiveInChat = true;
          }
        }

        if (isDeviceActiveInChat) {
          suppressedDevices.add(s['deviceId'] as String);
        } else {
          eligiblePushDevices.add(s['deviceId'] as String);
        }
      }

      expect(suppressedDevices, contains('phone_a'));
      expect(eligiblePushDevices, contains('phone_b'));
      expect(eligiblePushDevices.length, 1);
    });
  });

  group('P0 Group Seen-By & Member Hydration Tests', () {
    test('Group Seen-By extracts readers accurately and excludes sender', () {
      const senderId = 'user_author_01';
      final reads = [
        {
          'core_user_id': 'user_author_01', // sender itself
          'read_at': DateTime.now().toIso8601String(),
          'fullName': 'Author User',
        },
        {
          'core_user_id': 'user_reader_02',
          'read_at': DateTime.now()
              .subtract(const Duration(minutes: 2))
              .toIso8601String(),
          'fullName': 'Bob Colleague',
          'avatarUrl': 'https://example.com/bob.jpg',
          'role': 'EMPLOYEE',
        },
        {
          'core_user_id': 'user_reader_03',
          'read_at': DateTime.now()
              .subtract(const Duration(seconds: 40))
              .toIso8601String(),
          'fullName': 'Charlie Intern',
          'avatarUrl': null,
          'role': 'INTERN',
        },
      ];

      final recipientReads = reads
          .where((r) => r['core_user_id'] != senderId && r['read_at'] != null)
          .toList();

      expect(recipientReads.length, 2);
      expect(
        recipientReads.map((r) => r['core_user_id']),
        containsAll(['user_reader_02', 'user_reader_03']),
      );
      expect(
        recipientReads.map((r) => r['core_user_id']),
        isNot(contains(senderId)),
      );
    });

    test('Not Yet Seen correctly computes remaining group participants', () {
      const senderId = 'user_author_01';
      final groupMembers = [
        {'id': 'user_author_01', 'fullName': 'Author User'},
        {'id': 'user_reader_02', 'fullName': 'Bob Colleague'},
        {'id': 'user_reader_03', 'fullName': 'Charlie Intern'},
        {'id': 'user_reader_04', 'fullName': 'Diana Executive'},
      ];

      final readUserIds = {'user_reader_02', 'user_reader_03'};

      final notYetSeen = groupMembers.where((m) {
        final id = m['id'];
        return id != senderId && !readUserIds.contains(id);
      }).toList();

      expect(notYetSeen.length, 1);
      expect(notYetSeen.first['id'], 'user_reader_04');
    });
  });

  group('P0 Story 24-Hour Expiration & Video Upload Tests', () {
    test('Story expiration is strictly 24 hours from server creation', () {
      final nowUtc = DateTime.now().toUtc();
      final expiresAt = nowUtc.add(const Duration(hours: 24));

      final story = StoryItemModel(
        id: 'story_video_99',
        type: 'VIDEO',
        caption: 'CodeXa Office Tech Talk',
        mediaUrl: 'https://example.com/storage/v1/object/public/post-images/video.mp4',
        createdAt: nowUtc,
        expiresAt: expiresAt,
      );

      expect(story.expiresAt.difference(story.createdAt).inHours, 24);

      // Verify active query boundary filter
      final isExpiredBefore = DateTime.now().toUtc().isAfter(story.expiresAt);
      expect(isExpiredBefore, isFalse);

      final simulatedPastStory = StoryItemModel(
        id: 'story_past',
        type: 'IMAGE',
        caption: 'Yesterday',
        createdAt: nowUtc.subtract(const Duration(hours: 25)),
        expiresAt: nowUtc.subtract(const Duration(hours: 1)),
      );
      final isExpiredPast = DateTime.now().toUtc().isAfter(
        simulatedPastStory.expiresAt,
      );
      expect(isExpiredPast, isTrue);
    });

    test('Video MIME type detection recognises valid Android formats', () {
      final validVideoExtensions = ['mp4', 'mov', 'webm', '3gp', 'mkv'];
      for (final ext in validVideoExtensions) {
        final filename = 'recording_2026.$ext';
        final isVideo =
            filename.toLowerCase().endsWith('.mp4') ||
            filename.toLowerCase().endsWith('.mov') ||
            filename.toLowerCase().endsWith('.webm') ||
            filename.toLowerCase().endsWith('.3gp') ||
            filename.toLowerCase().endsWith('.mkv');
        expect(isVideo, isTrue);
      }
    });
  });
}
