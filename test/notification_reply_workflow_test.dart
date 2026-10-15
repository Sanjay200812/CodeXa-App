import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Notification Reply & Route Extraction Tests', () {
    test('extracts conversationId correctly from chat notification route', () {
      final notif = {
        'id': 'notif-123',
        'category': 'CHAT',
        'title': 'Message from Alice',
        'body': 'Hey, are you free for a standup?',
        'route': '/messages/conv_abc_987?user=alice',
      };

      String? extractConversationId(Map<String, dynamic> n) {
        final route = n['route']?.toString() ?? '';
        if (route.contains('/messages/')) {
          final parts = route.split('/messages/');
          if (parts.length > 1) {
            return parts[1].split('?').first.trim();
          }
        }
        return n['conversationId']?.toString();
      }

      final convId = extractConversationId(notif);
      expect(convId, equals('conv_abc_987'));
    });

    test(
      'extracts paymentId correctly from payment approval notification route',
      () {
        final notif = {
          'id': 'notif-456',
          'category': 'PAYMENT',
          'title': 'Payment Approval Required: John Doe',
          'body': 'Intern submitted ₹450 payment screenshot.',
          'route': '/admin/payments?review=pay_xyz_555',
        };

        String? extractPaymentId(Map<String, dynamic> n) {
          final route = n['route']?.toString() ?? '';
          if (route.contains('review=')) {
            final parts = route.split('review=');
            if (parts.length > 1) {
              return parts[1].split('&').first.trim();
            }
          }
          if (route.contains('paymentId=')) {
            final parts = route.split('paymentId=');
            if (parts.length > 1) {
              return parts[1].split('&').first.trim();
            }
          }
          return n['paymentId']?.toString();
        }

        final payId = extractPaymentId(notif);
        expect(payId, equals('pay_xyz_555'));
      },
    );

    test(
      'correctly identifies message notifications for quick reply option',
      () {
        bool isChatMessage(Map<String, dynamic> n) {
          final cat = (n['category'] ?? '').toString().toUpperCase();
          final title = (n['title'] ?? '').toString().toLowerCase();
          final route = (n['route'] ?? '').toString();
          return cat.contains('MESSAGE') ||
              cat.contains('CHAT') ||
              title.contains('message from') ||
              route.contains('/messages/') ||
              route.contains('/chat/');
        }

        expect(isChatMessage({'category': 'CHAT'}), isTrue);
        expect(
          isChatMessage({'category': 'GENERAL', 'title': 'Message from Bob'}),
          isTrue,
        );
        expect(
          isChatMessage({'category': 'GENERAL', 'route': '/messages/123'}),
          isTrue,
        );
        expect(
          isChatMessage({
            'category': 'ATTENDANCE',
            'title': 'Attendance slot open',
          }),
          isFalse,
        );
      },
    );
  });
}
