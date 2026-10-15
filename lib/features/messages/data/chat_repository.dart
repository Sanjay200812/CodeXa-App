import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'chat_api.dart';
import 'chat_realtime_service.dart';
import 'models/chat_models.dart';

final chatApiProvider = Provider<CxChatApi>((ref) => CxChatApi());

final chatRealtimeServiceProvider = Provider<CxChatRealtimeService>((ref) {
  final api = ref.watch(chatApiProvider);
  final service = CxChatRealtimeService(api);
  service.initialize();
  ref.onDispose(() => service.dispose());
  return service;
});

final chatConversationsProvider =
    FutureProvider.autoDispose<List<ChatConversation>>((ref) async {
      final api = ref.watch(chatApiProvider);
      return api.getConversations();
    });

final chatMessagesProvider = FutureProvider.family
    .autoDispose<List<ChatMessage>, String>((ref, conversationId) async {
      final api = ref.watch(chatApiProvider);
      return api.getMessages(conversationId);
    });

final chatConnectionStateProvider =
    StreamProvider.autoDispose<RealtimeConnectionState>((ref) {
      final service = ref.watch(chatRealtimeServiceProvider);
      return service.stateStream;
    });
