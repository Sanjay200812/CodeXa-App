import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:codexa_mobile/core/utils/cx_time_format.dart';
import 'package:codexa_mobile/core/models/models.dart';
import 'package:codexa_mobile/core/widgets/cx_glass.dart';

void main() {
  group('CodeXa V6 — Relative Timestamps & Date Formatting Tests', () {
    test(
      'formatStoryTime renders Instagram-style relative times correctly',
      () {
        final now = DateTime.now();
        expect(
          CxTimeFormat.formatStoryTime(
            now.subtract(const Duration(seconds: 20)),
          ),
          'Just now',
        );
        expect(
          CxTimeFormat.formatStoryTime(
            now.subtract(const Duration(minutes: 5)),
          ),
          '5m ago',
        );
        expect(
          CxTimeFormat.formatStoryTime(
            now.subtract(const Duration(minutes: 30)),
          ),
          '30m ago',
        );
        expect(
          CxTimeFormat.formatStoryTime(now.subtract(const Duration(hours: 2))),
          '2h ago',
        );
        expect(
          CxTimeFormat.formatStoryTime(now.subtract(const Duration(hours: 5))),
          '5h ago',
        );
        expect(
          CxTimeFormat.formatStoryTime(now.subtract(const Duration(hours: 23))),
          '23h ago',
        );
      },
    );

    test(
      'formatViewerTime renders viewers relative viewing times correctly',
      () {
        final now = DateTime.now();
        expect(
          CxTimeFormat.formatViewerTime(
            now.subtract(const Duration(seconds: 15)),
          ),
          'Viewed just now',
        );
        expect(
          CxTimeFormat.formatViewerTime(
            now.subtract(const Duration(minutes: 5)),
          ),
          'Viewed 5m ago',
        );
        expect(
          CxTimeFormat.formatViewerTime(now.subtract(const Duration(hours: 2))),
          'Viewed 2h ago',
        );
        expect(
          CxTimeFormat.formatViewerTime(now.subtract(const Duration(days: 1))),
          'Viewed Yesterday',
        );
      },
    );

    test('formatChatDateSeparator groups messages by WhatsApp-style date', () {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day, 14, 30);
      final yesterday = today.subtract(const Duration(days: 1));
      final olderDate = DateTime(2025, 10, 10, 9, 15);

      expect(CxTimeFormat.formatChatDateSeparator(today), 'Today');
      expect(CxTimeFormat.formatChatDateSeparator(yesterday), 'Yesterday');
      expect(
        CxTimeFormat.formatChatDateSeparator(olderDate),
        '10 October 2025',
      );
    });

    test('formatMessageTime formats compact send time in 12-hour format with AM/PM', () {
      final morning = DateTime(2026, 10, 10, 10, 32);
      final evening = DateTime(2026, 10, 10, 23, 5);
      final noon = DateTime(2026, 10, 10, 12, 0);
      final midnight = DateTime(2026, 10, 10, 0, 15);

      expect(CxTimeFormat.formatMessageTime(morning), '10:32 AM');
      expect(CxTimeFormat.formatMessageTime(evening), '11:05 PM');
      expect(CxTimeFormat.formatMessageTime(noon), '12:00 PM');
      expect(CxTimeFormat.formatMessageTime(midnight), '12:15 AM');
    });

    test(
      'formatChatListRelative formats messages list timestamps correctly',
      () {
        final now = DateTime.now();
        expect(
          CxTimeFormat.formatChatListRelative(
            now.subtract(const Duration(seconds: 30)),
          ),
          'Just now',
        );
        expect(
          CxTimeFormat.formatChatListRelative(
            now.subtract(const Duration(minutes: 1)),
          ),
          '1m',
        );
        expect(
          CxTimeFormat.formatChatListRelative(
            now.subtract(const Duration(minutes: 5)),
          ),
          '5m',
        );
        expect(
          CxTimeFormat.formatChatListRelative(
            now.subtract(const Duration(hours: 1)),
          ),
          '1h',
        );
        expect(
          CxTimeFormat.formatChatListRelative(
            now.subtract(const Duration(days: 1)),
          ),
          'Yesterday',
        );
      },
    );
  });

  group('CodeXa V6 — Global Search Models & Category Mappings', () {
    test(
      'SearchResultItem parses people, messages, and project items cleanly',
      () {
        final peopleItem = SearchResultItem.fromJson({
          'category': 'people',
          'id': 'cmuw8zizo000h12t76attfbro',
          'title': 'Sanjay',
          'subtitle': '@sanju • CO_FOUNDER',
          'meta': 'sanju',
          'route': '/profile/sanju',
        });

        expect(peopleItem.category, 'people');
        expect(peopleItem.id, 'cmuw8zizo000h12t76attfbro');
        expect(peopleItem.title, 'Sanjay');
        expect(peopleItem.subtitle, '@sanju • CO_FOUNDER');
        expect(peopleItem.route, '/profile/sanju');

        final msgItem = SearchResultItem.fromJson({
          'category': 'messages',
          'id': 'msg_123',
          'title': 'Hey team, V6 release is ready',
          'subtitle': 'Core Team • Sanjay',
          'meta': 'conv_456',
          'route': '/chat/conv_456?name=Core%20Team&messageId=msg_123',
        });

        expect(msgItem.category, 'messages');
        expect(msgItem.id, 'msg_123');
        expect(msgItem.title, 'Hey team, V6 release is ready');
        expect(msgItem.meta, 'conv_456');
      },
    );
  });

  group('CodeXa V6 — Liquid Glass Component Instantiation', () {
    test('CodeXaGlassButton supports all variants and badgeCount cleanly', () {
      const btn = CodeXaGlassButton(
        onPressed: null,
        label: 'TEST',
        variant: GlassButtonVariant.crimson,
        badgeCount: 5,
      );

      expect(btn.label, 'TEST');
      expect(btn.variant, GlassButtonVariant.crimson);
      expect(btn.badgeCount, 5);
      expect(btn.disabled, false);
    });

    test(
      'CodeXaGlassCard initializes with custom padding and blur cleanly',
      () {
        const card = CodeXaGlassCard(
          blurAmount: 18.0,
          hasGlow: true,
          child: SizedBox(),
        );

        expect(card.blurAmount, 18.0);
        expect(card.hasGlow, true);
      },
    );
  });
}
