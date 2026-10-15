import 'dart:async';

import 'chat_api.dart';
import 'models/chat_models.dart';

enum RealtimeConnectionState {
  connecting,
  connected,
  reconnecting,
  offline,
  failed,
}

class CxChatRealtimeService {
  final CxChatApi _api;
  RealtimeConnectionState _state = RealtimeConnectionState.offline;
  final _stateController =
      StreamController<RealtimeConnectionState>.broadcast();
  final _messageController = StreamController<ChatMessage>.broadcast();
  final _typingController = StreamController<Map<String, dynamic>>.broadcast();

  String? _currentToken;
  String? _currentCoreUserId;
  Timer? _heartbeatTimer;

  CxChatRealtimeService([CxChatApi? api]) : _api = api ?? CxChatApi();

  Stream<RealtimeConnectionState> get stateStream => _stateController.stream;
  Stream<ChatMessage> get messageStream => _messageController.stream;
  Stream<Map<String, dynamic>> get typingStream => _typingController.stream;

  RealtimeConnectionState get currentState => _state;
  String? get currentToken => _currentToken;
  String? get currentCoreUserId => _currentCoreUserId;

  Future<void> initialize() async {
    _setState(RealtimeConnectionState.connecting);
    try {
      final config = await _api.getChatToken();
      if (config != null && config['token'] != null) {
        _currentToken = config['token'] as String;
        _currentCoreUserId = config['coreUserId'] as String;
        _setState(RealtimeConnectionState.connected);

        // Start heartbeat to maintain online status and renew token
        _startHeartbeat();
      } else {
        _setState(RealtimeConnectionState.offline);
      }
    } catch (_) {
      _setState(RealtimeConnectionState.failed);
    }
  }

  void _setState(RealtimeConnectionState newState) {
    if (_state != newState) {
      _state = newState;
      _stateController.add(newState);
    }
  }

  void _startHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(const Duration(minutes: 45), (
      timer,
    ) async {
      // Renew token before 1-hour expiration
      try {
        final config = await _api.getChatToken();
        if (config != null && config['token'] != null) {
          _currentToken = config['token'] as String;
        }
      } catch (_) {}
    });
  }

  void subscribeToConversation(String conversationId) {
    // When connected to Supabase Realtime channel
    // In mobile client, listens for incoming messages broadcasted via server
  }

  void broadcastTyping({
    required String conversationId,
    required bool isTyping,
  }) {
    _typingController.add({
      'conversationId': conversationId,
      'userId': _currentCoreUserId,
      'isTyping': isTyping,
    });
  }

  void notifyIncomingMessage(ChatMessage message) {
    _messageController.add(message);
  }

  void dispose() {
    _heartbeatTimer?.cancel();
    _stateController.close();
    _messageController.close();
    _typingController.close();
  }
}
