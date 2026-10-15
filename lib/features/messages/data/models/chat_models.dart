class ChatConversation {
  final String id;
  final String type; // DIRECT | GROUP | PROJECT
  final String? title;
  final String? projectId;
  final String createdByCoreUserId;
  final String? directPairKey;
  final Map<String, dynamic>? recipientUser;
  final ChatMessage? latestMessage;
  final bool isMuted;
  final DateTime updatedAt;

  ChatConversation({
    required this.id,
    required this.type,
    this.title,
    this.projectId,
    required this.createdByCoreUserId,
    this.directPairKey,
    this.recipientUser,
    this.latestMessage,
    this.isMuted = false,
    required this.updatedAt,
  });

  String get displayName {
    if (type == 'DIRECT' && recipientUser != null) {
      return recipientUser!['fullName'] ??
          recipientUser!['username'] ??
          'Colleague';
    }
    return title ?? 'Conversation';
  }

  String? get displayAvatar => recipientUser?['profileMediaUrl'];

  bool get isDirect => type == 'DIRECT';

  factory ChatConversation.fromJson(Map<String, dynamic> json) {
    return ChatConversation(
      id: json['id'] as String,
      type: json['type'] as String? ?? 'DIRECT',
      title: json['title'] as String?,
      projectId: json['project_id'] as String?,
      createdByCoreUserId: json['created_by_core_user_id'] as String? ?? '',
      directPairKey: json['direct_pair_key'] as String?,
      recipientUser: json['recipientUser'] != null
          ? Map<String, dynamic>.from(json['recipientUser'])
          : null,
      latestMessage: json['latestMessage'] != null
          ? ChatMessage.fromJson(
              Map<String, dynamic>.from(json['latestMessage']),
            )
          : null,
      isMuted: json['isMuted'] as bool? ?? false,
      updatedAt: json['updated_at'] != null
          ? DateTime.tryParse(json['updated_at'] as String) ?? DateTime.now()
          : DateTime.now(),
    );
  }
}

class ChatMessage {
  final String id;
  final String conversationId;
  final String senderCoreUserId;
  final String clientMessageId;
  final String messageType; // TEXT | IMAGE | FILE | SYSTEM
  final String text;
  final String? replyToMessageId;
  final DateTime createdAt;
  final String status; // sending | sent | delivered | seen | failed
  final List<dynamic> reactions;
  final List<dynamic> reads;

  ChatMessage({
    required this.id,
    required this.conversationId,
    required this.senderCoreUserId,
    required this.clientMessageId,
    this.messageType = 'TEXT',
    required this.text,
    this.replyToMessageId,
    required this.createdAt,
    this.status = 'sent',
    this.reactions = const [],
    this.reads = const [],
  });

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      id: json['id'] as String,
      conversationId: json['conversation_id'] as String? ?? '',
      senderCoreUserId: json['sender_core_user_id'] as String? ?? '',
      clientMessageId: json['client_message_id'] as String? ?? '',
      messageType: json['message_type'] as String? ?? 'TEXT',
      text: json['text'] as String? ?? '',
      replyToMessageId: json['reply_to_message_id'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'] as String) ?? DateTime.now()
          : DateTime.now(),
      status: json['status'] as String? ?? 'sent',
      reactions: json['message_reactions'] as List<dynamic>? ?? [],
      reads: json['message_reads'] as List<dynamic>? ?? [],
    );
  }

  ChatMessage copyWith({String? status, String? text}) {
    return ChatMessage(
      id: id,
      conversationId: conversationId,
      senderCoreUserId: senderCoreUserId,
      clientMessageId: clientMessageId,
      messageType: messageType,
      text: text ?? this.text,
      replyToMessageId: replyToMessageId,
      createdAt: createdAt,
      status: status ?? this.status,
      reactions: reactions,
      reads: reads,
    );
  }
}
