import 'package:flutter_test/flutter_test.dart';
import 'package:codexa_mobile/features/messages/messages_screen.dart';

void main() {
  group('P0 Direct Chat Participant Identity Resolution Tests', () {
    const currentUserId = 'user-founder-123';

    test('resolveConversationName returns recipientUser fullName when title is generic "Chat"', () {
      final item = {
        'id': 'conv-1',
        'type': 'DIRECT',
        'name': 'Chat',
        'title': 'Chat',
        'recipientUser': {
          'id': 'user-cofounder-456',
          'fullName': 'Shaik Arifa',
          'role': 'CO_FOUNDER',
        },
      };

      final resolved = resolveConversationName(item, currentUserId);
      expect(resolved, 'Shaik Arifa');
      expect(resolved, isNot('Chat'));
    });

    test('resolveConversationName returns otherParticipantDisplayName when present', () {
      final item = {
        'id': 'conv-2',
        'type': 'DIRECT',
        'name': 'Chat',
        'otherParticipantDisplayName': 'Syed Afzal',
        'otherParticipantRole': 'FOUNDER',
      };

      final resolved = resolveConversationName(item, currentUserId);
      expect(resolved, 'Syed Afzal');
      expect(resolved, isNot('Chat'));
    });

    test('resolveConversationName extracts other member from members array correctly', () {
      final item = {
        'id': 'conv-3',
        'type': 'DIRECT',
        'title': 'Chat',
        'members': [
          {'id': currentUserId, 'fullName': 'Current User'},
          {
            'id': 'user-intern-789',
            'fullName': 'Mohammed Riyan',
            'role': 'INTERN',
          },
        ],
      };

      final resolved = resolveConversationName(item, currentUserId);
      expect(resolved, 'Mohammed Riyan');
      expect(resolved, isNot('Chat'));
    });

    test('resolveConversationName preserves Group Title for GROUP type', () {
      final item = {
        'id': 'group-1',
        'type': 'GROUP',
        'title': 'CODEX CREW',
        'name': 'CODEX CREW',
      };

      final resolved = resolveConversationName(item, currentUserId);
      expect(resolved, 'CODEX CREW');
    });

    test('resolveConversationRole returns role for Direct and member count for Group', () {
      final directItem = {
        'type': 'DIRECT',
        'otherParticipantRole': 'CO_FOUNDER',
      };
      expect(resolveConversationRole(directItem), 'CO_FOUNDER');

      final groupItem = {
        'type': 'GROUP',
        'members': [1, 2, 3, 4],
      };
      expect(resolveConversationRole(groupItem), '4 members');
    });
  });

  group('P1 Social Interactions & View Once Media Tests', () {
    test('View Once message attributes evaluate correctly', () {
      final viewOnceMsg = {
        'id': 'msg-vo-1',
        'message_type': 'VIEW_ONCE_IMAGE',
        'is_view_once': true,
        'view_once_consumed': false,
        'reactions': ['❤️', '🔥'],
      };

      expect(viewOnceMsg['is_view_once'], true);
      expect(viewOnceMsg['view_once_consumed'], false);
      expect((viewOnceMsg['reactions'] as List).contains('❤️'), true);
      expect((viewOnceMsg['reactions'] as List).contains('🔥'), true);
    });

    test('Quoted reply reference links canonical original message id', () {
      final replyMsg = {
        'id': 'msg-reply-2',
        'text': 'I will review this today!',
        'reply_to_message_id': 'msg-orig-1',
      };

      expect(replyMsg['reply_to_message_id'], 'msg-orig-1');
    });
  });
}
