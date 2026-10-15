const fs = require('fs');
const path = require('path');

const targetFile = 'G:/AntiGravity IDE/codexa app/lib/features/messages/messages_screen.dart';
let code = fs.readFileSync(targetFile, 'utf8');

// 1. Ensure imports
const neededImports = [
  "import 'package:flutter/services.dart';",
  "import 'view_once_media_viewer.dart';",
];

for (const imp of neededImports) {
  if (!code.includes(imp)) {
    code = imp + '\n' + code;
  }
}

// 2. Add canonical identity resolver helpers above MessagesScreen if not present
if (!code.includes('String resolveConversationName(')) {
  const helpers = `
// --- AUTHORITATIVE IDENTITY RESOLVERS (NEVER FALLBACK TO "Chat") ---
String resolveConversationName(Map<String, dynamic> item, String currentUserId) {
  final type = item['type'] ?? 'DIRECT';
  if (type == 'GROUP') {
    final title = item['title'] ?? item['name'];
    if (title != null && title.toString().trim().isNotEmpty && title.toString().trim() != 'Chat') {
      return title.toString().trim();
    }
    return 'Team Group';
  }

  // Check all possible direct participant fields
  final directName = item['otherParticipantDisplayName'] ??
      item['recipientUser']?['fullName'] ??
      item['recipientUser']?['displayName'] ??
      item['recipientUser']?['name'] ??
      item['peer']?['fullName'] ??
      item['peer']?['displayName'] ??
      item['peer']?['name'] ??
      item['otherParticipantUsername'] ??
      item['recipientUser']?['username'] ??
      item['peer']?['username'];

  if (directName != null &&
      directName.toString().trim().isNotEmpty &&
      directName.toString().trim() != 'Chat' &&
      directName.toString().trim() != 'Direct Message') {
    return directName.toString().trim();
  }

  // Check members array if populated
  final members = item['members'] as List<dynamic>?;
  if (members != null) {
    for (final m in members) {
      if (m is Map && m['id'] != currentUserId) {
        final n = m['fullName'] ?? m['displayName'] ?? m['name'] ?? m['username'];
        if (n != null &&
            n.toString().trim().isNotEmpty &&
            n.toString().trim() != 'Chat' &&
            n.toString().trim() != 'Direct Message') {
          return n.toString().trim();
        }
      }
    }
  }

  final raw = item['name'] ?? item['title'];
  if (raw != null &&
      raw.toString().trim().isNotEmpty &&
      raw.toString().trim() != 'Chat' &&
      raw.toString().trim() != 'Direct Message') {
    return raw.toString().trim();
  }

  return 'CodeXa Colleague';
}

String? resolveConversationAvatar(Map<String, dynamic> item) {
  return item['avatarUrl'] ??
      item['otherParticipantAvatar'] ??
      item['recipientUser']?['profileMediaUrl'] ??
      item['recipientUser']?['avatarUrl'] ??
      item['peer']?['avatarUrl'] ??
      item['peer']?['profileMediaUrl'] ??
      item['metadata']?['iconUrl'];
}

String resolveConversationRole(Map<String, dynamic> item) {
  if (item['type'] == 'GROUP') {
    final memberCount = (item['members'] as List?)?.length;
    return memberCount != null && memberCount > 0 ? '$memberCount members' : 'Team Group';
  }
  return item['otherParticipantRole'] ??
      item['recipientUser']?['role'] ??
      item['peer']?['role'] ??
      'Active';
}
`;
  code = code.replace('class MessagesScreen extends ConsumerStatefulWidget {', helpers + '\nclass MessagesScreen extends ConsumerStatefulWidget {');
}

// 3. Update conversation name resolution in list tile
code = code.replace(
  "final name = item['name'] ?? item['title'] ?? 'Chat';",
  "final name = resolveConversationName(item, currentUserId);"
);
code = code.replace(
  "final avatarUrl = item['avatarUrl'] ?? item['recipientUser']?['profileMediaUrl'];",
  "final avatarUrl = resolveConversationAvatar(item);"
);

// 4. Update Chat header in ChatConversationScreen
code = code.replace(
  "final title = widget.conversation['name'] ?? widget.conversation['title'] ?? 'Chat';",
  "final title = resolveConversationName(widget.conversation, user?.id ?? '');"
);
code = code.replace(
  "widget.conversation['recipientUser']?['role'] ??\n                          (widget.conversation['type'] == 'GROUP' ? 'Group Info' : 'Active')",
  "resolveConversationRole(widget.conversation)"
);

// 5. In _ChatConversationScreenState, ensure _loadConversationDetails, _replyingToMessage, _isViewOnceSelected, _toggleReaction, _openViewOnceMedia are present
if (!code.includes('Map<String, dynamic>? _replyingToMessage;')) {
  const stateVars = `
  Map<String, dynamic>? _replyingToMessage;
  bool _isViewOnceSelected = false;

  Future<void> _loadConversationDetails() async {
    final convId = widget.conversation['id'];
    if (convId == null) return;
    try {
      final api = CxApiClient();
      final res = await api.dio.get('/api/chat/conversations/$convId');
      if (res.data != null && (res.data['ok'] == true || res.data['success'] == true)) {
        final conv = res.data['conversation'];
        if (conv is Map && mounted) {
          setState(() {
            widget.conversation.addAll(Map<String, dynamic>.from(conv));
          });
        }
      }
    } catch (_) {}
  }

  Future<void> _toggleReaction(String messageId, String emoji) async {
    final user = ref.read(authProvider).user;
    if (user == null) return;

    HapticFeedback.lightImpact();

    setState(() {
      final idx = _messages.indexWhere((m) => m['id'] == messageId);
      if (idx != -1) {
        final reactions = List<String>.from(_messages[idx]['reactions'] ?? []);
        if (reactions.contains(emoji)) {
          reactions.remove(emoji);
        } else {
          reactions.add(emoji);
        }
        _messages[idx]['reactions'] = reactions;
      }
    });

    try {
      final api = CxApiClient();
      await api.dio.post('/api/chat/messages/$messageId/reactions', data: {
        'reaction': emoji,
        'emoji': emoji,
      });
    } catch (_) {}
  }

  Future<void> _openViewOnceMedia(Map<String, dynamic> msg) async {
    final msgId = msg['id']?.toString();
    if (msgId == null) return;

    try {
      final api = CxApiClient();
      final res = await api.dio.post('/api/chat/messages/$msgId/view-once');
      if (res.data != null && res.data['ok'] == true) {
        final mediaUrl = res.data['mediaUrl']?.toString();
        if (mediaUrl != null && mediaUrl.isNotEmpty && mounted) {
          await Navigator.of(context).push(
            MaterialPageRoute(
              fullscreenDialog: true,
              builder: (_) => ViewOnceMediaViewer(
                mediaUrl: mediaUrl,
                isVideo: msg['message_type'] == 'VIEW_ONCE_VIDEO',
              ),
            ),
          );

          setState(() {
            final idx = _messages.indexWhere((m) => m['id'] == msgId);
            if (idx != -1) {
              _messages[idx]['viewOnceConsumed'] = true;
              _messages[idx]['text'] = '[Photo Opened]';
              _messages[idx]['message'] = '[Photo Opened]';
            }
          });
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(res.data?['error'] ?? 'Media already opened')),
          );
        }
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open view-once media')),
        );
      }
    }
  }
`;
  code = code.replace(
    'class _ChatConversationScreenState extends ConsumerState<ChatConversationScreen> {',
    'class _ChatConversationScreenState extends ConsumerState<ChatConversationScreen> {' + stateVars
  );
}

// 6. In initState of _ChatConversationScreenState, call _loadConversationDetails()
if (!code.includes('_loadConversationDetails();')) {
  code = code.replace(
    '_loadMessages();',
    '_loadMessages();\n    _loadConversationDetails();'
  );
}

// 7. Update _sendMessage to include replyToMessageId
code = code.replace(
  `          'conversationId': convId,
          'message': text,
          'text': text,
          'clientId': clientId,
          'clientMessageId': clientId,`,
  `          'conversationId': convId,
          'message': text,
          'text': text,
          'clientId': clientId,
          'clientMessageId': clientId,
          'replyToMessageId': _replyingToMessage?['id'],`
);

// Clear _replyingToMessage after send
code = code.replace(
  `    setState(() {
      _messages.insert(0, localMsg);
    });`,
  `    final replyingId = _replyingToMessage?['id'];
    if (replyingId != null) {
      localMsg['reply_to_message_id'] = replyingId;
    }
    setState(() {
      _messages.insert(0, localMsg);
      _replyingToMessage = null;
    });`
);

// 8. Update _pickAndSendMedia to support _isViewOnceSelected
code = code.replace(
  `          'conversationId': convId,
          'message': '[Image Attached]',
          'clientId': clientId,
          'clientMessageId': clientId,
          'messageType': 'IMAGE',
          'mediaUrl': 'data:image/jpeg;base64,$base64Image',`,
  `          'conversationId': convId,
          'message': _isViewOnceSelected ? '[View Once Photo]' : '[Image Attached]',
          'clientId': clientId,
          'clientMessageId': clientId,
          'messageType': _isViewOnceSelected ? 'VIEW_ONCE_IMAGE' : 'IMAGE',
          'isViewOnce': _isViewOnceSelected,
          'mediaUrl': 'data:image/jpeg;base64,$base64Image',`
);

// 9. Update composer padding to respect 3-button system navigation
code = code.replace(
  "bottom: MediaQuery.of(context).viewInsets.bottom + CxSpacing.sm,",
  "bottom: MediaQuery.of(context).viewInsets.bottom + (MediaQuery.of(context).viewInsets.bottom > 0 ? CxSpacing.sm : MediaQuery.of(context).padding.bottom + CxSpacing.sm),"
);

fs.writeFileSync(targetFile, code, 'utf8');
console.log('Successfully patched messages_screen.dart!');
