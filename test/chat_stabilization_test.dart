import 'package:flutter_test/flutter_test.dart';
import 'package:dio/dio.dart';
import 'package:codexa_mobile/core/api/api_client.dart';
import 'package:codexa_mobile/features/messages/data/models/chat_models.dart';

void main() {
  group('Chat Stabilization & Error Sanitization Tests', () {
    test(
      'CxApiClient.parseError never returns null or raw exception traces',
      () {
        final dioExcNull = DioException(
          requestOptions: RequestOptions(path: '/api/chat/conversations/123'),
          type: DioExceptionType.badResponse,
          response: Response(
            requestOptions: RequestOptions(path: '/api/chat/conversations/123'),
            statusCode: 500,
          ),
        );

        final errorMsg = CxApiClient.parseError(dioExcNull);
        expect(errorMsg, isNotEmpty);
        expect(errorMsg, isNot(contains('null')));
        expect(errorMsg, 'CodeXa encountered a server error.');
      },
    );

    test(
      'CxApiClient.parseError handles 503 database unavailability cleanly',
      () {
        final dioExc503 = DioException(
          requestOptions: RequestOptions(path: '/api/chat/messages'),
          type: DioExceptionType.badResponse,
          response: Response(
            requestOptions: RequestOptions(path: '/api/chat/messages'),
            statusCode: 503,
          ),
        );

        final errorMsg = CxApiClient.parseError(dioExc503);
        expect(
          errorMsg,
          'CodeXa is temporarily unable to connect to its database.',
        );
      },
    );

    test('CxApiClient.parseError handles 401 session expiration cleanly', () {
      final dioExc401 = DioException(
        requestOptions: RequestOptions(path: '/api/chat/messages'),
        type: DioExceptionType.badResponse,
        response: Response(
          requestOptions: RequestOptions(path: '/api/chat/messages'),
          statusCode: 401,
        ),
      );

      final errorMsg = CxApiClient.parseError(dioExc401);
      expect(errorMsg, 'Incorrect login details.');
    });

    test(
      'CxApiClient.parseError sanitizes unknown exceptions to user-safe string',
      () {
        final errorMsg = CxApiClient.parseError(
          Exception('DioException [bad response]: null'),
        );
        expect(errorMsg, 'CodeXa encountered a server error.');
      },
    );
  });

  group('Chat Models & Conversation Metadata Tests', () {
    test('ChatConversation parses latestMessage and type cleanly', () {
      final conv = ChatConversation.fromJson({
        'id': 'conv-uuid-1',
        'type': 'DIRECT',
        'title': 'Sanjay B.',
        'metadata': {
          'iconUrl': 'https://codxa-agency.online/uploads/avatar.jpg',
        },
        'latestMessage': {
          'id': 'msg-uuid-1',
          'text': 'Hello world',
          'sender_core_user_id': 'user-1',
          'created_at': DateTime.now().toIso8601String(),
        },
      });

      expect(conv.id, 'conv-uuid-1');
      expect(conv.type, 'DIRECT');
      expect(conv.isDirect, isTrue);
    });

    test('ChatMessage parses attachment and sender information cleanly', () {
      final msg = ChatMessage.fromJson({
        'id': 'msg-uuid-2',
        'conversation_id': 'conv-uuid-1',
        'sender_core_user_id': 'user-2',
        'client_message_id': 'client-2',
        'message_type': 'IMAGE',
        'text': 'https://codxa-agency.online/uploads/chat/image.jpg',
        'created_at': DateTime.now().toIso8601String(),
      });

      expect(msg.id, 'msg-uuid-2');
      expect(msg.messageType, 'IMAGE');
      expect(msg.text, contains('/uploads/chat/image.jpg'));
    });
  });
}
