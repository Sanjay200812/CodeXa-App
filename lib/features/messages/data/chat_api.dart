import 'package:dio/dio.dart';

import '../../../core/api/api_client.dart';
import 'models/chat_models.dart';

class CxChatApi {
  final CxApiClient _client;

  CxChatApi([CxApiClient? client]) : _client = client ?? CxApiClient();

  Dio get _dio => _client.dio;

  Future<Map<String, dynamic>?> getChatToken() async {
    try {
      final res = await _dio.get('/api/chat/token');
      if (res.data != null && res.data['ok'] == true) {
        return Map<String, dynamic>.from(res.data);
      }
    } catch (_) {}
    return null;
  }

  Future<List<ChatConversation>> getConversations() async {
    try {
      final res = await _dio.get('/api/chat/conversations');
      if (res.data != null && res.data['ok'] == true) {
        final list = res.data['conversations'] as List<dynamic>? ?? [];
        return list
            .map((c) => ChatConversation.fromJson(Map<String, dynamic>.from(c)))
            .toList();
      }
    } catch (_) {}
    return [];
  }

  Future<ChatConversation?> startDirectConversation(String targetUserId) async {
    try {
      final res = await _dio.post(
        '/api/chat/conversations',
        data: {'type': 'DIRECT', 'targetUserId': targetUserId},
      );
      if (res.data != null &&
          res.data['ok'] == true &&
          res.data['conversation'] != null) {
        return ChatConversation.fromJson(
          Map<String, dynamic>.from(res.data['conversation']),
        );
      }
    } catch (_) {}
    return null;
  }

  Future<List<ChatMessage>> getMessages(
    String conversationId, {
    String? before,
    int limit = 30,
  }) async {
    try {
      final query = <String, dynamic>{'limit': limit};
      if (before != null) query['before'] = before;

      final res = await _dio.get(
        '/api/chat/conversations/$conversationId/messages',
        queryParameters: query,
      );
      if (res.data != null && res.data['ok'] == true) {
        final list = res.data['messages'] as List<dynamic>? ?? [];
        return list
            .map((m) => ChatMessage.fromJson(Map<String, dynamic>.from(m)))
            .toList();
      }
    } catch (_) {}
    return [];
  }

  Future<ChatMessage?> sendMessage({
    required String conversationId,
    required String text,
    required String clientMessageId,
    String messageType = 'TEXT',
  }) async {
    try {
      final res = await _dio.post(
        '/api/chat/conversations/$conversationId/messages',
        data: {
          'text': text,
          'clientMessageId': clientMessageId,
          'messageType': messageType,
        },
      );
      if (res.data != null &&
          res.data['ok'] == true &&
          res.data['message'] != null) {
        return ChatMessage.fromJson(
          Map<String, dynamic>.from(res.data['message']),
        );
      }
    } catch (_) {}
    return null;
  }

  Future<bool> markRead(String messageId) async {
    try {
      final res = await _dio.post('/api/chat/messages/$messageId/read');
      return res.data != null && res.data['ok'] == true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> toggleReaction(String messageId, String reaction) async {
    try {
      final res = await _dio.post(
        '/api/chat/messages/$messageId/reactions',
        data: {'reaction': reaction},
      );
      return res.data != null && res.data['ok'] == true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> deleteMessage(String messageId) async {
    try {
      final res = await _dio.delete('/api/chat/messages/$messageId');
      return res.data != null && res.data['ok'] == true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> reportMessage({
    required String messageId,
    required String reason,
    String? details,
  }) async {
    try {
      final res = await _dio.post(
        '/api/chat/reports',
        data: {'messageId': messageId, 'reason': reason, 'details': details},
      );
      return res.data != null && res.data['ok'] == true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> blockUser(String targetUserId) async {
    try {
      final res = await _dio.post(
        '/api/chat/blocks',
        data: {'targetUserId': targetUserId},
      );
      return res.data != null && res.data['ok'] == true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> muteConversation(
    String conversationId, {
    String? mutedUntil,
  }) async {
    try {
      final res = await _dio.post(
        '/api/chat/mutes',
        data: {'conversationId': conversationId, 'mutedUntil': mutedUntil},
      );
      return res.data != null && res.data['ok'] == true;
    } catch (_) {
      return false;
    }
  }
}
