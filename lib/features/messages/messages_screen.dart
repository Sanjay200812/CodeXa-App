import 'dart:io';

import 'group_details_screen.dart';
import 'view_once_media_viewer.dart';
import 'chat_media_preview_screen.dart';
import '../../core/utils/cx_time_format.dart';

import 'package:flutter/services.dart';

import '../profile/coworker_profile_screen.dart';

import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';

import '../../core/api/api_client.dart';
import '../../core/models/models.dart';
import '../../core/providers/app_providers.dart';
import '../../core/theme/cx_theme.dart';
import '../../core/widgets/cx_components.dart';
import '../../core/widgets/cx_in_app_browser.dart';
import '../../core/services/cx_notification_service.dart';
import '../assistant/ai_chat_screen.dart';
import '../stickers/data/local_sticker_repository.dart';
import '../stickers/presentation/sticker_picker_sheet.dart';
import '../stickers/presentation/sticker_image.dart';
import 'notes_row.dart';

// --- CHAT CONVERSATIONS PROVIDER ---
final chatConversationsProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
      final api = CxApiClient();
      try {
        final res = await api.dio.get('/api/chat/conversations');
        if (res.data != null &&
            (res.data['ok'] == true || res.data['success'] == true)) {
          return (res.data['conversations'] as List<dynamic>?)
                  ?.map((c) => Map<String, dynamic>.from(c))
                  .toList() ??
              [];
        }
      } catch (_) {}
      return [];
    });

// --- AUTHORITATIVE IDENTITY RESOLVERS (NEVER FALLBACK TO "Chat") ---
String resolveConversationName(
  Map<String, dynamic> item,
  String currentUserId,
) {
  final type = item['type'] ?? 'DIRECT';
  if (type == 'GROUP') {
    final title = item['title'] ?? item['name'];
    if (title != null &&
        title.toString().trim().isNotEmpty &&
        title.toString().trim() != 'Chat') {
      return title.toString().trim();
    }
    return 'Team Group';
  }

  // Check all possible direct participant fields
  final directName =
      item['otherParticipantDisplayName'] ??
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
        final n =
            m['fullName'] ?? m['displayName'] ?? m['name'] ?? m['username'];
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
    return memberCount != null && memberCount > 0
        ? '$memberCount members'
        : 'Team Group';
  }
  return item['otherParticipantRole'] ??
      item['recipientUser']?['role'] ??
      item['peer']?['role'] ??
      'Active';
}

class MessagesScreen extends ConsumerStatefulWidget {
  final String? initialConversationId;
  const MessagesScreen({super.key, this.initialConversationId});

  @override
  ConsumerState<MessagesScreen> createState() => _MessagesScreenState();
}

class _MessagesScreenState extends ConsumerState<MessagesScreen> {
  final _searchController = TextEditingController();
  String _searchQuery = '';
  String _selectedTab = 'ALL';

  @override
  void initState() {
    super.initState();
    CxNotificationService.onForegroundChatMessageReceived = (_) {
      if (mounted) {
        ref.invalidate(chatConversationsProvider);
      }
    };
    CxNotificationService.onIncomingShareReceived = (data) {
      if (mounted) {
        final text = data['text']?.toString();
        final mediaUris = (data['mediaUris'] as List?)
            ?.map((e) => e.toString())
            .toList();
        _handleIncomingShare(text, mediaUris);
      }
    };
    if (widget.initialConversationId != null &&
        widget.initialConversationId!.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _openChatById(widget.initialConversationId!);
      });
    }
  }

  void _handleIncomingShare(String? text, List<String>? mediaUris) {
    final conversations =
        ref.read(chatConversationsProvider).asData?.value ?? [];
    if (conversations.isEmpty) {
      if (text != null && text.isNotEmpty) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Received shared link: $text')));
      }
      return;
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: CxColors.cardElevated,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(CxSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.share_rounded,
                  color: CxColors.brightRed,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  'SHARE TO CODEXA',
                  style: GoogleFonts.orbitron(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: CxColors.textPrimary,
                    letterSpacing: 1.0,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            if (text != null && text.isNotEmpty)
              Text(
                'Sharing: $text',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: CxColors.textSecondary,
                ),
              ),
            const SizedBox(height: CxSpacing.md),
            Text(
              'SELECT CONVERSATION',
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: CxColors.textMuted,
              ),
            ),
            const SizedBox(height: 8),
            ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.4,
              ),
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: conversations.length,
                itemBuilder: (c, idx) {
                  final conv = conversations[idx];
                  final currentUserId = ref.read(authProvider).user?.id ?? '';
                  final name = resolveConversationName(conv, currentUserId);
                  final avatar = resolveConversationAvatar(conv);
                  return ListTile(
                    dense: true,
                    leading: CxAvatar(name: name, imageUrl: avatar, radius: 16),
                    title: Text(
                      name,
                      style: GoogleFonts.inter(
                        color: CxColors.textPrimary,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    onTap: () {
                      Navigator.pop(ctx);
                      final targetConv = Map<String, dynamic>.from(conv);
                      if (text != null) targetConv['initialText'] = text;
                      _openChat(targetConv);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _openChatById(String convId) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ChatConversationScreen(
          conversation: {
            'id': convId,
            'name': 'Direct Message',
            'title': 'Direct Message',
          },
        ),
      ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    CxNotificationService.onForegroundChatMessageReceived = null;
    CxNotificationService.onIncomingShareReceived = null;
    super.dispose();
  }

  void _openChat(Map<String, dynamic> conversation) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ChatConversationScreen(conversation: conversation),
      ),
    );
  }

  Widget _buildFilterTab(String label) {
    final isSelected = _selectedTab == label;
    return InkWell(
      onTap: () => setState(() => _selectedTab = label),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? CxColors.brightRed : CxColors.cardElevated,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? CxColors.brightRed : CxColors.borderSubtle,
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.orbitron(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: isSelected ? Colors.white : CxColors.textSecondary,
            letterSpacing: 0.8,
          ),
        ),
      ),
    );
  }

  void _openNewChatDialog(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: CxColors.cardElevated,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Consumer(
        builder: (ctx, ref, _) {
          final peopleAsync = ref.watch(peopleListProvider);
          final searchCtrl = TextEditingController();
          final groupNameCtrl = TextEditingController();
          String localQuery = '';
          String activeMode = 'DIRECT'; // DIRECT or GROUP
          final selectedMembers = <String>{};

          return StatefulBuilder(
            builder: (ctx, setSheetState) => Container(
              height: MediaQuery.of(context).size.height * 0.82,
              padding: const EdgeInsets.all(CxSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        activeMode == 'DIRECT'
                            ? 'NEW DIRECT MESSAGE'
                            : 'CREATE NEW GROUP',
                        style: GoogleFonts.orbitron(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: CxColors.textPrimary,
                          letterSpacing: 1.0,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(
                          Icons.close,
                          color: CxColors.textMuted,
                          size: 20,
                        ),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // Mode Toggle
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            backgroundColor: activeMode == 'DIRECT'
                                ? CxColors.brightRed.withOpacity(0.15)
                                : Colors.transparent,
                            side: BorderSide(
                              color: activeMode == 'DIRECT'
                                  ? CxColors.brightRed
                                  : CxColors.borderSubtle,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          onPressed: () =>
                              setSheetState(() => activeMode = 'DIRECT'),
                          child: Text(
                            'DIRECT CHAT',
                            style: GoogleFonts.orbitron(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: activeMode == 'DIRECT'
                                  ? CxColors.brightRed
                                  : CxColors.textSecondary,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            backgroundColor: activeMode == 'GROUP'
                                ? CxColors.brightRed.withOpacity(0.15)
                                : Colors.transparent,
                            side: BorderSide(
                              color: activeMode == 'GROUP'
                                  ? CxColors.brightRed
                                  : CxColors.borderSubtle,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          onPressed: () =>
                              setSheetState(() => activeMode = 'GROUP'),
                          child: Text(
                            'CREATE GROUP',
                            style: GoogleFonts.orbitron(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: activeMode == 'GROUP'
                                  ? CxColors.brightRed
                                  : CxColors.textSecondary,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: CxSpacing.sm),

                  if (activeMode == 'GROUP') ...[
                    CxTextField(
                      hint: 'Group Name (e.g. Frontend Core, Project Alpha)',
                      controller: groupNameCtrl,
                    ),
                    const SizedBox(height: CxSpacing.sm),
                    Text(
                      'Select Members (${selectedMembers.length} selected):',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        color: CxColors.textSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                  ],

                  CxTextField(
                    hint: 'Search coworkers by name, role...',
                    controller: searchCtrl,
                    prefixIcon: const Icon(
                      Icons.search,
                      size: 18,
                      color: CxColors.textSecondary,
                    ),
                    onChanged: (val) => setSheetState(
                      () => localQuery = val.trim().toLowerCase(),
                    ),
                  ),
                  const SizedBox(height: CxSpacing.sm),

                  Expanded(
                    child: peopleAsync.when(
                      loading: () => const Center(
                        child: CircularProgressIndicator(
                          color: CxColors.brightRed,
                        ),
                      ),
                      error: (err, _) => Center(
                        child: Text(
                          'Unable to load team directory',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: CxColors.textMuted,
                          ),
                        ),
                      ),
                      data: (people) {
                        final currentUser = ref.read(authProvider).user;
                        final filtered = people.where((p) {
                          if (p.id == currentUser?.id) return false;
                          if (localQuery.isEmpty) return true;
                          return p.fullName.toLowerCase().contains(
                                localQuery,
                              ) ||
                              p.username.toLowerCase().contains(localQuery) ||
                              p.role.toLowerCase().contains(localQuery) ||
                              (p.department?.toLowerCase().contains(
                                    localQuery,
                                  ) ??
                                  false);
                        }).toList();

                        if (filtered.isEmpty) {
                          return const Center(
                            child: CxEmptyState(
                              icon: Icons.person_search,
                              title: 'NO MEMBERS FOUND',
                              message: 'No coworkers match your search query.',
                            ),
                          );
                        }

                        return ListView.separated(
                          itemCount: filtered.length,
                          separatorBuilder: (_, __) => const Divider(
                            color: CxColors.borderSubtle,
                            height: 1,
                            indent: 60,
                          ),
                          itemBuilder: (context, index) {
                            final coworker = filtered[index];
                            final isSelected = selectedMembers.contains(
                              coworker.id,
                            );

                            return ListTile(
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 4,
                                vertical: 2,
                              ),
                              leading: CxAvatar(
                                name: coworker.fullName,
                                imageUrl: coworker.profileMediaUrl,
                                radius: 20,
                              ),
                              title: Text(
                                coworker.fullName,
                                style: GoogleFonts.inter(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: CxColors.textPrimary,
                                ),
                              ),
                              subtitle: Text(
                                '${coworker.role.toUpperCase()} • ${coworker.designation ?? coworker.department ?? "Engineering"}',
                                style: GoogleFonts.inter(
                                  fontSize: 11,
                                  color: CxColors.textMuted,
                                ),
                              ),
                              trailing: activeMode == 'GROUP'
                                  ? Checkbox(
                                      value: isSelected,
                                      activeColor: CxColors.brightRed,
                                      onChanged: (val) {
                                        setSheetState(() {
                                          if (val == true) {
                                            selectedMembers.add(coworker.id);
                                          } else {
                                            selectedMembers.remove(coworker.id);
                                          }
                                        });
                                      },
                                    )
                                  : const Icon(
                                      Icons.arrow_forward_ios,
                                      size: 12,
                                      color: CxColors.textMuted,
                                    ),
                              onTap: () {
                                if (activeMode == 'GROUP') {
                                  setSheetState(() {
                                    if (isSelected) {
                                      selectedMembers.remove(coworker.id);
                                    } else {
                                      selectedMembers.add(coworker.id);
                                    }
                                  });
                                } else {
                                  Navigator.pop(ctx);
                                  _startDirectMessageWith(coworker);
                                }
                              },
                            );
                          },
                        );
                      },
                    ),
                  ),

                  if (activeMode == 'GROUP') ...[
                    const SizedBox(height: CxSpacing.sm),
                    CxButton(
                      label: 'CREATE GROUP (${selectedMembers.length} MEMBERS)',
                      icon: Icons.group_add_outlined,
                      onPressed: () async {
                        final gName = groupNameCtrl.text.trim();
                        if (gName.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Please enter a group name'),
                              backgroundColor: CxColors.error,
                            ),
                          );
                          return;
                        }
                        Navigator.pop(ctx);
                        final api = CxApiClient();
                        try {
                          final res = await api.dio.post(
                            '/api/chat/conversations',
                            data: {
                              'type': 'GROUP',
                              'title': gName,
                              'memberIds': selectedMembers.toList(),
                            },
                          );
                          if (res.data != null && res.data['ok'] == true) {
                            ref.invalidate(chatConversationsProvider);
                            final conv = res.data['conversation'];
                            if (mounted && conv != null) {
                              _openChat(Map<String, dynamic>.from(conv));
                            }
                          }
                        } catch (e) {
                          if (ctx.mounted) {
                            ScaffoldMessenger.of(ctx).showSnackBar(
                              SnackBar(
                                content: Text(CxApiClient.parseError(e)),
                                backgroundColor: CxColors.error,
                              ),
                            );
                          }
                        }
                      },
                    ),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _startDirectMessageWith(PeopleModel coworker) async {
    try {
      final api = CxApiClient();
      final res = await api.dio.post(
        '/api/mobile/chat/direct',
        data: {'targetUserId': coworker.id},
      );

      if (res.data != null && res.data['ok'] == true) {
        final convId = res.data['conversationId'];
        if (mounted) {
          _openChat({
            'id': convId,
            'type': 'DIRECT',
            'name': coworker.fullName,
            'title': coworker.fullName,
            'avatarUrl': coworker.profileMediaUrl,
            'recipientUser': {
              'id': coworker.id,
              'fullName': coworker.fullName,
              'username': coworker.username,
              'role': coworker.role,
              'profileMediaUrl': coworker.profileMediaUrl,
            },
            'peer': {
              'id': coworker.id,
              'name': coworker.fullName,
              'username': coworker.username,
              'role': coworker.role,
              'profileMediaUrl': coworker.profileMediaUrl,
            },
          });
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(CxApiClient.parseError(e)),
            backgroundColor: CxColors.error,
          ),
        );
      }
    }
  }

  Future<void> _startDirectMessageById(
    String userId,
    String name, [
    String? initialText,
  ]) async {
    try {
      final api = CxApiClient();
      final res = await api.dio.post(
        '/api/mobile/chat/direct',
        data: {'targetUserId': userId},
      );

      if (res.data != null && res.data['ok'] == true) {
        final convId = res.data['conversationId'];
        if (mounted) {
          _openChat({
            'id': convId,
            'type': 'DIRECT',
            'name': name,
            'title': name,
            'recipientUser': {'id': userId, 'fullName': name, 'username': name},
            'peer': {'id': userId, 'name': name},
            'initialText': initialText,
          });
        }
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final conversationsAsync = ref.watch(chatConversationsProvider);

    return Scaffold(
      backgroundColor: CxColors.background,
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: CxColors.brightRed,
        icon: const Icon(
          Icons.chat_bubble_outline,
          color: Colors.white,
          size: 18,
        ),
        label: Text(
          'NEW CHAT',
          style: GoogleFonts.orbitron(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: Colors.white,
            letterSpacing: 0.8,
          ),
        ),
        onPressed: () => _openNewChatDialog(context),
      ),
      body: Column(
        children: [
          // 1. Search Bar
          Padding(
            padding: const EdgeInsets.only(
              left: CxSpacing.lg,
              right: CxSpacing.lg,
              top: CxSpacing.lg,
            ),
            child: CxTextField(
              hint: 'Search conversations...',
              controller: _searchController,
              prefixIcon: const Icon(
                Icons.search,
                size: 20,
                color: CxColors.textSecondary,
              ),
              onChanged: (val) =>
                  setState(() => _searchQuery = val.toLowerCase()),
            ),
          ),
          const SizedBox(height: CxSpacing.xs),

          // 2. 24-Hour Notes Row
          NotesRow(
            onReplyNote: (targetUserId, targetName, initialText) {
              _startDirectMessageById(targetUserId, targetName, initialText);
            },
          ),
          const SizedBox(height: CxSpacing.xs),

          // 3. Filter Tabs
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: CxSpacing.lg),
            child: Row(
              children: [
                _buildFilterTab('ALL'),
                const SizedBox(width: 8),
                _buildFilterTab('DIRECT'),
                const SizedBox(width: 8),
                _buildFilterTab('GROUPS'),
                const SizedBox(width: 8),
                _buildFilterTab('UNREAD'),
              ],
            ),
          ),
          const SizedBox(height: CxSpacing.sm),

          // 4. Prominent CodeXa AI Card
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: CxSpacing.lg,
              vertical: 4,
            ),
            child: InkWell(
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const CodexaAiScreen()),
                );
              },
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: CxColors.cardElevated,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: CxColors.brightRed.withOpacity(0.35),
                  ),
                  boxShadow: CxShadows.subtle,
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: const BoxDecoration(
                        color: CxColors.brightRed,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.auto_awesome,
                        size: 18,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                'CODEXA AI',
                                style: GoogleFonts.orbitron(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: CxColors.brightRed,
                                  letterSpacing: 0.8,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 5,
                                  vertical: 1,
                                ),
                                decoration: BoxDecoration(
                                  color: CxColors.success.withOpacity(0.18),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  'ASSISTANT',
                                  style: GoogleFonts.inter(
                                    fontSize: 9,
                                    fontWeight: FontWeight.w700,
                                    color: CxColors.success,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Summarize tasks, draft standup updates & assistance',
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              color: CxColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(
                      Icons.arrow_forward_ios,
                      size: 12,
                      color: CxColors.textMuted,
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 4),

          // 5. Conversation Stream
          Expanded(
            child: conversationsAsync.when(
              loading: () => const Center(
                child: CircularProgressIndicator(color: CxColors.brightRed),
              ),
              error: (err, _) => CxEmptyState(
                icon: Icons.chat_bubble_outline,
                title: 'CONVERSATIONS',
                message: 'No active conversations found.',
                action: CxButton(
                  label: 'RELOAD',
                  width: 120,
                  onPressed: () => ref.invalidate(chatConversationsProvider),
                ),
              ),
              data: (conversations) {
                final filtered = conversations.where((c) {
                  final name =
                      (c['name'] ?? c['title'] ?? c['displayName'] ?? '')
                          .toString()
                          .toLowerCase();
                  if (_searchQuery.isNotEmpty && !name.contains(_searchQuery)) {
                    return false;
                  }
                  if (_selectedTab == 'DIRECT' && c['type'] != 'DIRECT')
                    return false;
                  if (_selectedTab == 'GROUPS' && c['type'] == 'DIRECT')
                    return false;
                  if (_selectedTab == 'UNREAD' && (c['unreadCount'] ?? 0) == 0)
                    return false;
                  return true;
                }).toList();

                if (filtered.isEmpty) {
                  return const Center(
                    child: CxEmptyState(
                      icon: Icons.chat_bubble_outline,
                      title: 'NO CONVERSATIONS',
                      message: 'Start a direct chat or create a group to begin messaging.',
                    ),
                  );
                }

                return RefreshIndicator(
                  color: CxColors.brightRed,
                  backgroundColor: CxColors.cardElevated,
                  onRefresh: () async {
                    ref.invalidate(chatConversationsProvider);
                  },
                  child: ListView.separated(
                    padding: const EdgeInsets.symmetric(
                      horizontal: CxSpacing.lg,
                      vertical: CxSpacing.sm,
                    ),
                    itemCount: filtered.length,
                    separatorBuilder: (_, __) => const Divider(
                      color: CxColors.borderSubtle,
                      height: 1,
                      indent: 64,
                    ),
                    itemBuilder: (context, index) {
                      final item = filtered[index];
                      final currentUserId =
                          ref.watch(authProvider).user?.id ?? '';
                      final name = resolveConversationName(item, currentUserId);
                      final type = item['type'] ?? 'DIRECT';

                      // Extract latest message from either latestMessage or lastMessage
                      final latestMap = item['latestMessage'] is Map
                          ? Map<String, dynamic>.from(item['latestMessage'])
                          : (item['lastMessage'] is Map
                                ? Map<String, dynamic>.from(item['lastMessage'])
                                : null);

                      String previewText = 'No messages yet';
                      String timeAgo = '';

                      if (latestMap != null) {
                        final mType =
                            (latestMap['message_type'] ??
                                    latestMap['type'] ??
                                    'TEXT')
                                .toString();
                        final rawText =
                            (latestMap['text'] ?? latestMap['message'] ?? '')
                                .toString();
                        final senderId =
                            (latestMap['sender_core_user_id'] ??
                                    latestMap['senderId'] ??
                                    '')
                                .toString();
                        final isMe =
                            senderId.isNotEmpty && senderId == currentUserId;
                        final prefix = isMe ? 'You: ' : '';

                        if (mType == 'IMAGE' ||
                            (rawText.startsWith('http') &&
                                rawText.contains('/uploads/chat/'))) {
                          previewText = '$prefix📷 Photo';
                        } else if (mType == 'FILE') {
                          previewText = '$prefix📎 Attachment';
                        } else if (mType == 'STICKER') {
                          previewText = '$prefix✨ Sticker';
                        } else if (rawText.isNotEmpty) {
                          previewText = '$prefix$rawText';
                        }

                        final createdAtStr =
                            latestMap['created_at'] ?? latestMap['createdAt'];
                        if (createdAtStr != null) {
                          final dt = DateTime.tryParse(createdAtStr.toString());
                          if (dt != null) {
                            timeAgo = CxTimeFormat.formatChatListRelative(dt);
                          }
                        }
                      } else if (item['lastMessage'] != null &&
                          item['lastMessage'].toString().isNotEmpty) {
                        previewText = item['lastMessage'].toString();
                      }

                      final unread = item['unreadCount'] ?? 0;
                      final avatarUrl = resolveConversationAvatar(item);

                      return ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 4,
                          vertical: 4,
                        ),
                        leading: CxAvatar(
                          name: name,
                          imageUrl: avatarUrl,
                          radius: 23,
                        ),
                        title: Row(
                          children: [
                            Expanded(
                              child: Text(
                                name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.inter(
                                  fontSize: 14,
                                  fontWeight: unread > 0
                                      ? FontWeight.w700
                                      : FontWeight.w600,
                                  color: CxColors.textPrimary,
                                ),
                              ),
                            ),
                            if (timeAgo.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(left: 6),
                                child: Text(
                                  timeAgo,
                                  style: GoogleFonts.inter(
                                    fontSize: 10,
                                    color: CxColors.textMuted,
                                  ),
                                ),
                              ),
                            if (type == 'GROUP')
                              Container(
                                margin: const EdgeInsets.only(left: 6),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 5,
                                  vertical: 1,
                                ),
                                decoration: BoxDecoration(
                                  color: CxColors.secondaryDark,
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(
                                    color: CxColors.borderSubtle,
                                  ),
                                ),
                                child: Text(
                                  'GRP',
                                  style: GoogleFonts.orbitron(
                                    fontSize: 8,
                                    color: CxColors.textMuted,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        subtitle: Text(
                          previewText,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: unread > 0
                                ? CxColors.textPrimary
                                : CxColors.textMuted,
                            fontWeight: unread > 0
                                ? FontWeight.w500
                                : FontWeight.normal,
                          ),
                        ),
                        trailing: unread > 0
                            ? Container(
                                padding: const EdgeInsets.all(6),
                                decoration: const BoxDecoration(
                                  color: CxColors.brightRed,
                                  shape: BoxShape.circle,
                                ),
                                child: Text(
                                  unread > 9 ? '9+' : '$unread',
                                  style: GoogleFonts.inter(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                  ),
                                ),
                              )
                            : null,
                        onTap: () => _openChat(item),
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// --- FULL REALTIME CHAT CONVERSATION SCREEN ---
class ChatConversationScreen extends ConsumerStatefulWidget {
  final Map<String, dynamic> conversation;
  final String? initialMessageId;

  const ChatConversationScreen({
    super.key,
    required this.conversation,
    this.initialMessageId,
  });

  @override
  ConsumerState<ChatConversationScreen> createState() =>
      _ChatConversationScreenState();
}

class _ChatConversationScreenState
    extends ConsumerState<ChatConversationScreen> {
  Map<String, dynamic>? _replyingToMessage;
  final ScrollController _scrollController = ScrollController();
  String? _highlightedMessageId;
  bool _hasScrolledToInitial = false;

  Future<void> _loadConversationDetails() async {
    final convId = widget.conversation['id'];
    if (convId == null) return;
    try {
      final api = CxApiClient();
      final res = await api.dio.get('/api/chat/conversations/$convId');
      if (res.data != null &&
          (res.data['ok'] == true || res.data['success'] == true)) {
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
      await api.dio.post(
        '/api/chat/messages/$messageId/reactions',
        data: {'reaction': emoji, 'emoji': emoji},
      );
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
            SnackBar(
              content: Text(res.data?['error'] ?? 'Media already opened'),
            ),
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

  final _messageController = TextEditingController();
  final List<Map<String, dynamic>> _messages = [];
  bool _isLoading = false;

  Timer? _pollTimer;

  @override
  void initState() {
    super.initState();
    // Track active conversation for smart notification suppression
    final convId = widget.conversation['id']?.toString();
    if (convId != null && convId.isNotEmpty) {
      CxNotificationService.setActiveConversation(convId);
    }
    _loadMessages();
    _loadConversationDetails();
    _pollTimer = Timer.periodic(const Duration(milliseconds: 2500), (_) {
      if (mounted) _pollNewMessages();
    });
    if (widget.conversation['initialText'] != null) {
      _messageController.text = widget.conversation['initialText'];
    }
  }

  @override
  void dispose() {
    // Clear active conversation on leaving screen
    CxNotificationService.setActiveConversation(null);
    _pollTimer?.cancel();
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadMessages() async {
    setState(() => _isLoading = true);
    final api = CxApiClient();
    final convId = widget.conversation['id'];
    if (convId == null) {
      setState(() => _isLoading = false);
      return;
    }

    try {
      final res = await api.dio.get(
        '/api/chat/messages?conversationId=$convId',
      );
      if (res.data != null &&
          (res.data['success'] == true || res.data['ok'] == true)) {
        final msgs =
            (res.data['messages'] as List<dynamic>?)
                ?.map((m) => Map<String, dynamic>.from(m))
                .toList() ??
            [];
        setState(() {
          _messages.clear();
          _messages.addAll(msgs);
        });
        if (msgs.isNotEmpty) {
          _markConversationRead(convId, msgs.first['id']);
        }
        // Deep link scroll & highlight target message
        if (widget.initialMessageId != null && !_hasScrolledToInitial) {
          final targetIndex = msgs.indexWhere(
            (m) => m['id']?.toString() == widget.initialMessageId,
          );
          if (targetIndex != -1) {
            _hasScrolledToInitial = true;
            _highlightedMessageId = widget.initialMessageId;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (_scrollController.hasClients) {
                _scrollController.animateTo(
                  (targetIndex * 70.0).clamp(
                    0.0,
                    _scrollController.position.maxScrollExtent,
                  ),
                  duration: const Duration(milliseconds: 500),
                  curve: Curves.easeOutCubic,
                );
              }
            });
            Future.delayed(const Duration(seconds: 3), () {
              if (mounted) setState(() => _highlightedMessageId = null);
            });
          }
        }
      }
    } catch (_) {}
    setState(() => _isLoading = false);
  }

  Future<void> _pollNewMessages() async {
    final convId = widget.conversation['id'];
    if (convId == null) return;

    try {
      final api = CxApiClient();
      final res = await api.dio.get(
        '/api/chat/messages?conversationId=$convId',
      );
      if (res.data != null &&
          (res.data['success'] == true || res.data['ok'] == true)) {
        final msgs =
            (res.data['messages'] as List<dynamic>?)
                ?.map((m) => Map<String, dynamic>.from(m))
                .toList() ??
            [];
        if (msgs.isNotEmpty && mounted) {
          setState(() {
            for (final m in msgs) {
              final idx = _messages.indexWhere(
                (existing) =>
                    existing['id'] == m['id'] ||
                    (existing['clientId'] != null &&
                        existing['clientId'] == m['client_message_id']),
              );
              if (idx != -1) {
                _messages[idx] = m;
              } else {
                _messages.insert(0, m);
              }
            }
            _messages.sort((a, b) {
              final da =
                  DateTime.tryParse(a['created_at'] ?? a['createdAt'] ?? '') ??
                  DateTime.now();
              final db =
                  DateTime.tryParse(b['created_at'] ?? b['createdAt'] ?? '') ??
                  DateTime.now();
              return db.compareTo(da);
            });
          });
          // Mark newest message read since screen is actively viewed
          _markConversationRead(convId, msgs.first['id']);
        }
      }
    } catch (_) {}
  }

  Future<void> _sendMessage([String? overrideText]) async {
    final text = (overrideText ?? _messageController.text).trim();
    if (text.isEmpty) return;

    final user = ref.read(authProvider).user;
    final convId = widget.conversation['id'];
    const uuid = Uuid();
    final clientId = uuid.v4();

    if (overrideText == null) {
      _messageController.clear();
    }

    // Optimistic local update
    final localMsg = {
      'id': clientId,
      'clientId': clientId,
      'senderId': user?.id ?? '',
      'sender_core_user_id': user?.id ?? '',
      'senderName': user?.fullName ?? user?.username ?? 'You',
      'message': text,
      'text': text,
      'createdAt': DateTime.now().toIso8601String(),
      'created_at': DateTime.now().toIso8601String(),
      'status': 'Sending',
      'reactions': <String>[],
    };

    final replyingId = _replyingToMessage?['id'];
    if (replyingId != null) {
      localMsg['reply_to_message_id'] = replyingId;
    }
    setState(() {
      _messages.insert(0, localMsg);
      _replyingToMessage = null;
    });

    final api = CxApiClient();
    try {
      final res = await api.dio.post(
        '/api/chat/messages',
        data: {
          'conversationId': convId,
          'message': text,
          'text': text,
          'clientId': clientId,
          'clientMessageId': clientId,
          'replyToMessageId': _replyingToMessage?['id'],
        },
      );

      if (res.data != null &&
          (res.data['success'] == true || res.data['ok'] == true)) {
        setState(() {
          localMsg['status'] = 'Sent';
          if (res.data['message']?['id'] != null) {
            localMsg['id'] = res.data['message']['id'];
          }
        });
        ref.invalidate(chatConversationsProvider);
      }
    } catch (_) {
      setState(() {
        localMsg['status'] = 'Failed';
      });
    }
  }

  Future<void> _sendSticker(String stickerId) async {
    final cleanId = stickerId.trim();
    if (cleanId.isEmpty) return;

    final user = ref.read(authProvider).user;
    final convId = widget.conversation['id'];
    const uuid = Uuid();
    final clientId = uuid.v4();
    final catalogVersion = LocalStickerRepository().catalogVersion;

    // Optimistic local update
    final localMsg = {
      'id': clientId,
      'clientId': clientId,
      'senderId': user?.id ?? '',
      'sender_core_user_id': user?.id ?? '',
      'senderName': user?.fullName ?? user?.username ?? 'You',
      'message': cleanId,
      'text': cleanId,
      'stickerId': cleanId,
      'catalogVersion': catalogVersion,
      'message_type': 'STICKER',
      'createdAt': DateTime.now().toIso8601String(),
      'created_at': DateTime.now().toIso8601String(),
      'status': 'Sending',
      'reactions': <String>[],
    };

    setState(() {
      _messages.insert(0, localMsg);
    });

    final api = CxApiClient();
    try {
      final res = await api.dio.post(
        '/api/chat/messages',
        data: {
          'conversationId': convId,
          'clientId': clientId,
          'clientMessageId': clientId,
          'messageType': 'STICKER',
          'stickerId': cleanId,
          'catalogVersion': catalogVersion,
          'text': cleanId,
        },
      );

      if (res.data != null &&
          (res.data['success'] == true || res.data['ok'] == true)) {
        setState(() {
          localMsg['status'] = 'Sent';
          if (res.data['message']?['id'] != null) {
            localMsg['id'] = res.data['message']['id'];
          }
        });
        ref.invalidate(chatConversationsProvider);
      }
    } catch (_) {
      setState(() {
        localMsg['status'] = 'Failed';
      });
    }
  }

  Future<void> _pickAndSendMedia(ImageSource source) async {
    final picker = ImagePicker();
    final file = await picker.pickImage(
      source: source,
      maxWidth: 1920,
      maxHeight: 1920,
      imageQuality: 85,
    );
    if (file == null || !mounted) return;

    Navigator.of(context).push(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => ChatMediaPreviewScreen(
          file: File(file.path),
          isVideo: false,
          onSend: (caption, isViewOnce) {
            _sendMediaMessage(File(file.path), false, caption, isViewOnce);
          },
        ),
      ),
    );
  }

  Future<void> _pickAndSendVideo(ImageSource source) async {
    final picker = ImagePicker();
    final file = await picker.pickVideo(
      source: source,
      maxDuration: const Duration(seconds: 120),
    );
    if (file == null || !mounted) return;

    Navigator.of(context).push(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => ChatMediaPreviewScreen(
          file: File(file.path),
          isVideo: true,
          onSend: (caption, isViewOnce) {
            _sendMediaMessage(File(file.path), true, caption, isViewOnce);
          },
        ),
      ),
    );
  }

  Future<void> _sendMediaMessage(
    File file,
    bool isVideo,
    String caption,
    bool isViewOnce,
  ) async {
    final bytes = await file.readAsBytes();
    final base64Media = base64Encode(bytes);
    final user = ref.read(authProvider).user;
    final convId = widget.conversation['id'];
    const uuid = Uuid();
    final clientId = uuid.v4();

    final messageType = isViewOnce
        ? (isVideo ? 'VIEW_ONCE_VIDEO' : 'VIEW_ONCE_IMAGE')
        : (isVideo ? 'VIDEO' : 'IMAGE');

    final displayLabel = isViewOnce
        ? (isVideo ? '[Video • View Once]' : '[Photo • View Once]')
        : (caption.isNotEmpty
              ? caption
              : (isVideo ? '[Video Attached]' : '[Image Attached]'));

    final localMsg = {
      'id': clientId,
      'clientId': clientId,
      'senderId': user?.id ?? '',
      'sender_core_user_id': user?.id ?? '',
      'senderName': user?.fullName ?? user?.username ?? 'You',
      'message': displayLabel,
      'message_type': messageType,
      'is_view_once': isViewOnce,
      'isViewOnce': isViewOnce,
      'mediaUrl': isVideo
          ? 'data:video/mp4;base64,$base64Media'
          : 'data:image/jpeg;base64,$base64Media',
      'createdAt': DateTime.now().toIso8601String(),
      'created_at': DateTime.now().toIso8601String(),
      'status': 'Sending',
      'reactions': <String>[],
    };

    setState(() {
      _messages.insert(0, localMsg);
    });

    final api = CxApiClient();
    try {
      final res = await api.dio.post(
        '/api/chat/messages',
        data: {
          'conversationId': convId,
          'message': displayLabel,
          'clientId': clientId,
          'clientMessageId': clientId,
          'messageType': messageType,
          'isViewOnce': isViewOnce,
          'mediaUrl': isVideo
              ? 'data:video/mp4;base64,$base64Media'
              : 'data:image/jpeg;base64,$base64Media',
        },
      );
      if (res.data != null &&
          (res.data['success'] == true || res.data['ok'] == true)) {
        setState(() {
          localMsg['status'] = 'Sent';
          if (res.data['message']?['mediaUrl'] != null) {
            localMsg['mediaUrl'] = res.data['message']['mediaUrl'];
          }
          if (res.data['message']?['id'] != null) {
            localMsg['id'] = res.data['message']['id'];
          }
        });
        ref.invalidate(chatConversationsProvider);
      }
    } catch (_) {
      setState(() {
        localMsg['status'] = 'Failed';
      });
    }
  }

  Future<void> _markConversationRead(String convId, String? lastReadId) async {
    try {
      final api = CxApiClient();
      await api.dio.post(
        '/api/chat/read',
        data: {'conversationId': convId, 'lastReadMessageId': lastReadId},
      );
    } catch (_) {}
  }

  Widget _buildStatusIndicator(Map<String, dynamic> msg, bool isMe, int index) {
    if (!isMe) return const SizedBox.shrink();
    final isGroup = widget.conversation['type'] == 'GROUP';
    final status = msg['status'] ?? 'Sent';

    if (status == 'Sending') {
      return Padding(
        padding: const EdgeInsets.only(top: 2, right: 4),
        child: Text(
          'Sending...',
          style: GoogleFonts.inter(fontSize: 10, color: CxColors.textMuted),
        ),
      );
    }
    if (status == 'Failed') {
      return Padding(
        padding: const EdgeInsets.only(top: 2, right: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.error_outline,
              size: 10,
              color: CxColors.brightRed,
            ),
            const SizedBox(width: 4),
            Text(
              'Failed • Tap to retry',
              style: GoogleFonts.inter(fontSize: 10, color: CxColors.brightRed),
            ),
          ],
        ),
      );
    }

    final readList =
        (msg['reads'] as List<dynamic>?) ??
        (msg['message_reads'] as List<dynamic>?) ??
        [];
    final senderId = (msg['senderId'] ?? msg['sender_core_user_id'])
        ?.toString();
    final recipientReads = readList
        .where(
          (r) =>
              r['core_user_id']?.toString() != senderId && r['read_at'] != null,
        )
        .toList();

    if (isGroup) {
      if (recipientReads.isNotEmpty) {
        return _buildGroupSeenByRow(recipientReads, msg);
      }
      if (index != 0) return const SizedBox.shrink();
      return _buildSentTimestamp(msg);
    }

    // Direct Message: show read receipt on latest message (index == 0)
    if (index != 0) return const SizedBox.shrink();

    final String? readAtStr = recipientReads.isNotEmpty
        ? recipientReads.first['read_at']?.toString()
        : null;

    if (readAtStr != null) {
      final readAt = DateTime.tryParse(readAtStr);
      if (readAt != null) {
        final diff = DateTime.now().difference(readAt);
        final seenText = diff.inSeconds < 60
            ? 'Seen just now'
            : diff.inMinutes < 60
            ? 'Seen ${diff.inMinutes}m ago'
            : 'Seen';
        return Padding(
          padding: const EdgeInsets.only(top: 2, right: 4),
          child: Text(
            seenText,
            style: GoogleFonts.inter(fontSize: 10, color: CxColors.textMuted),
          ),
        );
      }
    }

    return _buildSentTimestamp(msg);
  }

  Widget _buildSentTimestamp(Map<String, dynamic> msg) {
    final createdAt =
        DateTime.tryParse(
          msg['createdAt']?.toString() ?? msg['created_at']?.toString() ?? '',
        ) ??
        DateTime.now();
    final diff = DateTime.now().difference(createdAt);
    final sentText = diff.inSeconds < 60
        ? 'Sent just now'
        : diff.inMinutes < 60
        ? 'Sent ${diff.inMinutes}m ago'
        : 'Sent';

    return Padding(
      padding: const EdgeInsets.only(top: 2, right: 4),
      child: Text(
        sentText,
        style: GoogleFonts.inter(fontSize: 10, color: CxColors.textMuted),
      ),
    );
  }

  Widget _buildGroupSeenByRow(List<dynamic> readers, Map<String, dynamic> msg) {
    const double avatarRadius = 8.0;
    const double overlap = 11.0;
    final displayCount = readers.length > 3 ? 3 : readers.length;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _showSeenByDetailSheet(msg, readers),
      child: Padding(
        padding: const EdgeInsets.only(top: 3, right: 2),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: (displayCount * overlap) + (avatarRadius * 2) - overlap,
              height: avatarRadius * 2 + 2,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  for (int i = 0; i < displayCount; i++)
                    Positioned(
                      left: i * overlap,
                      child: Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: CxColors.background,
                            width: 1.5,
                          ),
                        ),
                        child: CxAvatar(
                          name:
                              (readers[i]['displayName'] ??
                                      readers[i]['fullName'] ??
                                      'Member')
                                  .toString(),
                          imageUrl: readers[i]['avatarUrl']?.toString(),
                          radius: avatarRadius,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 5),
            Text(
              'Seen by ${readers.length}',
              style: GoogleFonts.inter(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: CxColors.textMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showSeenByDetailSheet(Map<String, dynamic> msg, List<dynamic> readers) {
    final members = (widget.conversation['members'] as List<dynamic>?) ?? [];
    final senderId = (msg['senderId'] ?? msg['sender_core_user_id'])
        ?.toString();

    final readUserIds = readers
        .map((r) => r['core_user_id']?.toString())
        .toSet();
    final notYetSeenMembers = members.where((m) {
      final mId = (m is Map ? (m['id'] ?? m['userId'] ?? m['core_user_id']) : m)
          ?.toString();
      return mId != null && mId != senderId && !readUserIds.contains(mId);
    }).toList();

    showModalBottomSheet(
      context: context,
      backgroundColor: CxColors.cardElevated,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.55,
        minChildSize: 0.35,
        maxChildSize: 0.85,
        expand: false,
        builder: (_, scrollCtrl) => ListView(
          controller: scrollCtrl,
          padding: const EdgeInsets.all(CxSpacing.lg),
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: CxColors.borderSubtle,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                const Icon(
                  Icons.remove_red_eye_outlined,
                  size: 16,
                  color: CxColors.brightRed,
                ),
                const SizedBox(width: 8),
                Text(
                  'SEEN BY (${readers.length})',
                  style: GoogleFonts.orbitron(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: CxColors.textPrimary,
                    letterSpacing: 1.1,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...readers.map((r) {
              final name = (r['displayName'] ?? r['fullName'] ?? 'Member')
                  .toString();
              final avatarUrl = r['avatarUrl']?.toString();
              final role = r['role']?.toString();
              final readAtStr = r['read_at']?.toString();
              String timeText = '';
              if (readAtStr != null) {
                final dt = DateTime.tryParse(readAtStr)?.toLocal();
                if (dt != null) {
                  timeText =
                      '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
                }
              }
              return ListTile(
                contentPadding: EdgeInsets.zero,
                leading: CxAvatar(name: name, imageUrl: avatarUrl, radius: 18),
                title: Text(
                  name,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: CxColors.textPrimary,
                  ),
                ),
                subtitle: role != null && role.isNotEmpty
                    ? Text(
                        role,
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          color: CxColors.textSecondary,
                        ),
                      )
                    : null,
                trailing: timeText.isNotEmpty
                    ? Text(
                        timeText,
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          color: CxColors.textMuted,
                        ),
                      )
                    : null,
              );
            }),
            if (notYetSeenMembers.isNotEmpty) ...[
              const Divider(color: CxColors.borderSubtle, height: 28),
              Row(
                children: [
                  const Icon(
                    Icons.access_time_rounded,
                    size: 16,
                    color: CxColors.textSecondary,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'NOT YET SEEN (${notYetSeenMembers.length})',
                    style: GoogleFonts.orbitron(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: CxColors.textSecondary,
                      letterSpacing: 1.1,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ...notYetSeenMembers.map((m) {
                final mName =
                    (m is Map
                            ? (m['fullName'] ??
                                  m['name'] ??
                                  m['displayName'] ??
                                  'Member')
                            : 'Member')
                        .toString();
                final mAvatar = m is Map ? m['avatarUrl']?.toString() : null;
                final mRole = m is Map ? m['role']?.toString() : null;
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: CxAvatar(name: mName, imageUrl: mAvatar, radius: 18),
                  title: Text(
                    mName,
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: CxColors.textSecondary,
                    ),
                  ),
                  subtitle: mRole != null
                      ? Text(
                          mRole,
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            color: CxColors.textMuted,
                          ),
                        )
                      : null,
                  trailing: Text(
                    'Delivered',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      color: CxColors.textMuted,
                    ),
                  ),
                );
              }),
            ],
          ],
        ),
      ),
    );
  }

  void _showMessageOptions(Map<String, dynamic> msg) {
    final user = ref.read(authProvider).user;
    final isMe =
        msg['senderId'] == user?.id || msg['sender_core_user_id'] == user?.id;
    final isGroup = widget.conversation['type'] == 'GROUP';

    showModalBottomSheet(
      context: context,
      backgroundColor: CxColors.cardElevated,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(CxSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'REACTIONS',
              style: GoogleFonts.orbitron(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: CxColors.textSecondary,
              ),
            ),
            const SizedBox(height: CxSpacing.sm),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: ['❤️', '😂', '👍', '🔥', '😮', '😢', '✅'].map((emoji) {
                return InkWell(
                  onTap: () {
                    Navigator.pop(ctx);
                    _toggleReaction(msg['id']?.toString() ?? '', emoji);
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 4,
                      vertical: 2,
                    ),
                    child: Text(emoji, style: const TextStyle(fontSize: 26)),
                  ),
                );
              }).toList(),
            ),
            const Divider(color: CxColors.borderSubtle, height: 24),
            if (isGroup && isMe) ...[
              ListTile(
                dense: true,
                leading: const Icon(
                  Icons.remove_red_eye_outlined,
                  color: CxColors.brightRed,
                  size: 20,
                ),
                title: Text(
                  'Seen By',
                  style: GoogleFonts.inter(color: CxColors.textPrimary),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  final readList =
                      (msg['reads'] as List<dynamic>?) ??
                      (msg['message_reads'] as List<dynamic>?) ??
                      [];
                  final senderId =
                      (msg['senderId'] ?? msg['sender_core_user_id'])
                          ?.toString();
                  final recipientReads = readList
                      .where(
                        (r) =>
                            r['core_user_id']?.toString() != senderId &&
                            r['read_at'] != null,
                      )
                      .toList();
                  _showSeenByDetailSheet(msg, recipientReads);
                },
              ),
            ],
            ListTile(
              dense: true,
              leading: const Icon(
                Icons.reply_rounded,
                color: CxColors.brightRed,
                size: 20,
              ),
              title: Text(
                'Reply',
                style: GoogleFonts.inter(color: CxColors.textPrimary),
              ),
              onTap: () {
                Navigator.pop(ctx);
                setState(() => _replyingToMessage = msg);
              },
            ),
            ListTile(
              dense: true,
              leading: const Icon(
                Icons.info_outline,
                color: CxColors.brightRed,
                size: 20,
              ),
              title: Text(
                'Message Info',
                style: GoogleFonts.inter(color: CxColors.textPrimary),
              ),
              onTap: () {
                Navigator.pop(ctx);
                _showMessageInfoSheet(msg);
              },
            ),
            ListTile(
              dense: true,
              leading: const Icon(
                Icons.copy_rounded,
                color: CxColors.textMuted,
                size: 20,
              ),
              title: Text(
                'Copy Text',
                style: GoogleFonts.inter(color: CxColors.textPrimary),
              ),
              onTap: () {
                Navigator.pop(ctx);
                final textToCopy = (msg['message'] ?? msg['text'] ?? '')
                    .toString();
                if (textToCopy.isNotEmpty) {
                  Clipboard.setData(ClipboardData(text: textToCopy));
                }
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Copied to clipboard'),
                    duration: Duration(seconds: 1),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showMessageInfoSheet(Map<String, dynamic> msg) {
    final createdAtStr =
        msg['createdAt']?.toString() ?? msg['created_at']?.toString() ?? '';
    final createdAt = DateTime.tryParse(createdAtStr)?.toLocal();
    final body = (msg['message'] ?? msg['text'] ?? '').toString();

    // Check message reads
    final readList =
        (msg['reads'] as List<dynamic>?) ??
        (msg['message_reads'] as List<dynamic>?) ??
        [];
    final senderId = (msg['senderId'] ?? msg['sender_core_user_id'])
        ?.toString();
    final recipientReads = readList
        .where(
          (r) =>
              r['core_user_id']?.toString() != senderId && r['read_at'] != null,
        )
        .toList();

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF0F0F0F),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFF333333),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'MESSAGE INFO',
              style: GoogleFonts.orbitron(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: Colors.white,
                letterSpacing: 1.0,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF141414),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF262626)),
              ),
              child: Text(
                body.isNotEmpty ? body : 'Media message',
                style: GoogleFonts.inter(color: Colors.white70, fontSize: 13),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(height: 16),
            _buildInfoRowItem(
              Icons.done,
              'Sent',
              createdAt != null
                  ? '${createdAt.day} ${_monthName(createdAt.month)} ${createdAt.year}, ${CxTimeFormat.formatMessageTime(createdAt)}'
                  : 'Recorded on server',
            ),
            const Divider(color: Color(0xFF222222), height: 16),
            _buildInfoRowItem(
              Icons.done_all,
              'Delivered',
              createdAt != null
                  ? '${createdAt.day} ${_monthName(createdAt.month)} ${createdAt.year}, ${CxTimeFormat.formatMessageTime(createdAt)}'
                  : 'Delivered',
            ),
            const Divider(color: Color(0xFF222222), height: 16),
            if (recipientReads.isNotEmpty) ...[
              _buildInfoRowItem(
                Icons.done_all,
                'Read',
                'Read by ${recipientReads.length} recipient${recipientReads.length > 1 ? 's' : ''}',
                color: CxColors.brightRed,
              ),
            ] else ...[
              _buildInfoRowItem(
                Icons.done_all,
                'Read',
                msg['status'] == 'Seen' || msg['is_read'] == true
                    ? 'Read'
                    : 'Not yet read',
                color: (msg['status'] == 'Seen' || msg['is_read'] == true)
                    ? CxColors.brightRed
                    : CxColors.textMuted,
              ),
            ],
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRowItem(
    IconData icon,
    String label,
    String value, {
    Color? color,
  }) {
    return Row(
      children: [
        Icon(icon, size: 18, color: color ?? Colors.white70),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
            Text(
              value,
              style: GoogleFonts.inter(
                fontSize: 11,
                color: color ?? CxColors.textSecondary,
              ),
            ),
          ],
        ),
      ],
    );
  }

  String _monthName(int month) {
    const m = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return (month >= 1 && month <= 12) ? m[month - 1] : '$month';
  }

  Widget _buildDateSeparator(DateTime dateTime) {
    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 12),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
        decoration: BoxDecoration(
          color: const Color(0xFF161616).withOpacity(0.95),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.white.withOpacity(0.08)),
        ),
        child: Text(
          CxTimeFormat.formatChatDateSeparator(dateTime),
          style: GoogleFonts.inter(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: CxColors.textSecondary,
          ),
        ),
      ),
    );
  }

  void _openImagePreview(BuildContext context, String imageUrl) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(12),
        child: Stack(
          alignment: Alignment.topRight,
          children: [
            InteractiveViewer(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.network(
                  imageUrl,
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => const Center(
                    child: Icon(
                      Icons.broken_image,
                      color: Colors.white,
                      size: 60,
                    ),
                  ),
                ),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.close, color: Colors.white, size: 28),
              onPressed: () => Navigator.pop(ctx),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChatBackground() {
    return Positioned.fill(
      child: IgnorePointer(
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Layer 1: Deep black base background
            Container(color: const Color(0xFF070707)),
            // Layer 2: Subtle ambient crimson radial accent
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: const Alignment(0.0, -0.2),
                  radius: 1.1,
                  colors: [
                    CxColors.deepRed.withOpacity(0.08),
                    Colors.transparent,
                  ],
                  stops: const [0.0, 0.85],
                ),
              ),
            ),
            // Layer 3: Centered official CodeXa Agency logo watermark
            Center(
              child: Opacity(
                opacity: 0.07,
                child: Image.asset(
                  'assets/images/codexa_logo.png',
                  width: 220,
                  height: 220,
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => Image.asset(
                    'icon.png',
                    width: 160,
                    height: 160,
                    fit: BoxFit.contain,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider).user;
    final title = resolveConversationName(widget.conversation, user?.id ?? '');
    final isGroup =
        widget.conversation['type'] == 'GROUP' ||
        (widget.conversation['title'] ?? widget.conversation['name'] ?? '')
            .toString()
            .toUpperCase()
            .contains('CREW');

    return Scaffold(
      backgroundColor: CxColors.background,
      appBar: AppBar(
        backgroundColor: const Color(0xFF0C0C0C).withOpacity(0.95),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: CxColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: InkWell(
          onTap: () {
            if (isGroup) {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                      GroupDetailsScreen(conversation: widget.conversation),
                ),
              );
            } else {
              final recipient =
                  widget.conversation['recipientUser'] ??
                  widget.conversation['peer'];
              final username = (recipient?['username'] ?? '').toString();
              if (username.isNotEmpty) {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => CoworkerProfileScreen(username: username),
                  ),
                );
              }
            }
          },
          child: Row(
            children: [
              isGroup &&
                      (widget.conversation['avatarUrl'] == null ||
                          widget.conversation['avatarUrl'].toString().isEmpty)
                  ? Container(
                      width: 36,
                      height: 36,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: CxColors.cardElevated,
                      ),
                      child: const Center(
                        child: Icon(
                          Icons.group,
                          size: 20,
                          color: Colors.white70,
                        ),
                      ),
                    )
                  : CxAvatar(
                      name: title,
                      imageUrl:
                          widget
                              .conversation['recipientUser']?['profileMediaUrl'] ??
                          widget.conversation['avatarUrl'],
                      radius: 18,
                    ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: CxColors.textPrimary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      resolveConversationRole(widget.conversation),
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        color: CxColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          if (isGroup)
            IconButton(
              icon: const Icon(
                Icons.info_outline,
                color: CxColors.textSecondary,
              ),
              tooltip: 'Group Info',
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        GroupDetailsScreen(conversation: widget.conversation),
                  ),
                );
              },
            ),
        ],
      ),
      body: Stack(
        children: [
          // Subtle professional CodeXa watermark background (Layer 1-3)
          _buildChatBackground(),

          // Chat messages and bottom composer (Layer 4-5)
          Column(
            children: [
              Expanded(
                child: _isLoading && _messages.isEmpty
                    ? const Center(
                        child: CircularProgressIndicator(
                          color: CxColors.brightRed,
                        ),
                      )
                    : _messages.isEmpty
                    ? const Center(
                        child: CxEmptyState(
                          icon: Icons.chat_bubble_outline,
                          title: 'NO MESSAGES YET',
                          message: 'Send a message to begin the conversation.',
                        ),
                      )
                    : ListView.builder(
                        controller: _scrollController,
                        reverse: true,
                        padding: const EdgeInsets.all(CxSpacing.lg),
                        itemCount: _messages.length,
                        itemBuilder: (context, index) {
                          final msg = _messages[index];
                          final isMe =
                              msg['senderId'] == user?.id ||
                              msg['sender_core_user_id'] == user?.id;
                          final body = (msg['message'] ?? msg['text'] ?? '')
                              .toString();
                          final reactions =
                              (msg['reactions'] as List<dynamic>?)
                                  ?.map((e) => e.toString())
                                  .toList() ??
                              [];
                          final isUrl =
                              body.startsWith('http://') ||
                              body.startsWith('https://');

                          final isGroup =
                              widget.conversation['type'] == 'GROUP';
                          final senderName =
                              (msg['senderName'] ??
                                      (isMe ? 'You' : 'Colleague'))
                                  .toString();
                          final senderAvatar =
                              msg['senderAvatar'] ?? msg['sender_avatar'];
                          final bool isSameSenderAsOlder =
                              index < _messages.length - 1 &&
                              (_messages[index + 1]['senderId'] ==
                                      msg['senderId'] ||
                                  _messages[index + 1]['sender_core_user_id'] ==
                                      msg['sender_core_user_id']);

                          final rawMediaUrl = msg['mediaUrl']?.toString();
                          final isViewOnceMsg =
                              msg['message_type'] == 'VIEW_ONCE_IMAGE' ||
                              msg['message_type'] == 'VIEW_ONCE_VIDEO' ||
                              msg['is_view_once'] == true ||
                              msg['isViewOnce'] == true;
                          final isConsumed =
                              msg['viewOnceConsumed'] == true ||
                              msg['view_once_consumed'] == true ||
                              body == '[Photo Opened]' ||
                              body == '[Video Opened]';

                          final isImageMsg =
                              !isViewOnceMsg &&
                              (msg['message_type'] == 'IMAGE' ||
                                  (rawMediaUrl != null &&
                                      rawMediaUrl.isNotEmpty) ||
                                  (body.startsWith('http') &&
                                      (body.contains('/uploads/chat/') ||
                                          body.endsWith('.jpg') ||
                                          body.endsWith('.png') ||
                                          body.endsWith('.jpeg'))));
                          final isStickerMsg = msg['message_type'] == 'STICKER';
                          final stickerId =
                              (msg['stickerId'] ??
                                      msg['text'] ??
                                      msg['message'] ??
                                      '')
                                  .toString();

                          final displayMediaUrl =
                              (rawMediaUrl != null && rawMediaUrl.isNotEmpty)
                              ? rawMediaUrl
                              : (isImageMsg && body.startsWith('http')
                                    ? body
                                    : null);

                          // Check if replying to an earlier message
                          final replyToId =
                              msg['reply_to_message_id'] ??
                              msg['replyToMessageId'];
                          Map<String, dynamic>? quotedMsg;
                          if (replyToId != null) {
                            try {
                              quotedMsg = _messages.firstWhere(
                                (m) => m['id'] == replyToId,
                              );
                            } catch (_) {
                              quotedMsg = null;
                            }
                          }

                          final Widget rawBubbleContent;
                          if (isViewOnceMsg) {
                            rawBubbleContent = GestureDetector(
                              onTap: isConsumed
                                  ? null
                                  : () => _openViewOnceMedia(msg),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 10,
                                ),
                                decoration: BoxDecoration(
                                  color: isConsumed
                                      ? CxColors.card
                                      : (isMe
                                            ? CxColors.brightRed
                                            : CxColors.cardElevated),
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                    color: isConsumed
                                        ? CxColors.borderSubtle
                                        : CxColors.brightRed.withOpacity(0.7),
                                    width: 1.5,
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      isConsumed
                                          ? Icons.lock_clock_outlined
                                          : Icons.looks_one_rounded,
                                      color: isConsumed
                                          ? CxColors.textMuted
                                          : Colors.white,
                                      size: 20,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      isConsumed
                                          ? 'Opened'
                                          : (msg['message_type'] ==
                                                    'VIEW_ONCE_VIDEO'
                                                ? 'Video • View Once'
                                                : 'Photo • View Once'),
                                      style: GoogleFonts.inter(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        color: isConsumed
                                            ? CxColors.textMuted
                                            : Colors.white,
                                        fontStyle: isConsumed
                                            ? FontStyle.italic
                                            : FontStyle.normal,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      CxTimeFormat.formatMessageTime(
                                        DateTime.tryParse(
                                              msg['createdAt']?.toString() ??
                                                  msg['created_at']
                                                      ?.toString() ??
                                                  '',
                                            )?.toLocal() ??
                                            DateTime.now(),
                                      ),
                                      style: GoogleFonts.inter(
                                        fontSize: 10,
                                        color: isConsumed
                                            ? CxColors.textMuted
                                            : Colors.white70,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          } else if (isStickerMsg) {
                            rawBubbleContent = Container(
                              padding: const EdgeInsets.all(4),
                              decoration: const BoxDecoration(
                                color: Colors.transparent,
                              ),
                              child: StickerImage(
                                stickerId: stickerId,
                                width: 140,
                                height: 140,
                                fit: BoxFit.contain,
                                onInstallPack: () => StickerPickerSheet.show(
                                  context,
                                  onStickerSelected: (sid) => _sendSticker(sid),
                                ),
                              ),
                            );
                          } else {
                            rawBubbleContent = Container(
                              padding: isImageMsg
                                  ? const EdgeInsets.all(4)
                                  : const EdgeInsets.symmetric(
                                      horizontal: 14,
                                      vertical: 10,
                                    ),
                              decoration: BoxDecoration(
                                color: isMe
                                    ? CxColors.brightRed
                                    : CxColors.cardElevated,
                                borderRadius: BorderRadius.circular(14),
                                border: isMe
                                    ? null
                                    : Border.all(color: CxColors.borderSubtle),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (quotedMsg != null) ...[
                                    Container(
                                      margin: const EdgeInsets.only(bottom: 6),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.black.withOpacity(0.25),
                                        borderRadius: BorderRadius.circular(8),
                                        border: const Border(
                                          left: BorderSide(
                                            color: Colors.white70,
                                            width: 3,
                                          ),
                                        ),
                                      ),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            quotedMsg['senderName'] ??
                                                (quotedMsg['senderId'] ==
                                                        user?.id
                                                    ? 'You'
                                                    : 'Colleague'),
                                            style: GoogleFonts.inter(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w700,
                                              color: Colors.white,
                                            ),
                                          ),
                                          Text(
                                            (quotedMsg['message'] ??
                                                    quotedMsg['text'] ??
                                                    'Original message')
                                                .toString(),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: GoogleFonts.inter(
                                              fontSize: 11,
                                              color: Colors.white70,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                  if (isImageMsg &&
                                      displayMediaUrl != null) ...[
                                    GestureDetector(
                                      onTap: () => _openImagePreview(
                                        context,
                                        displayMediaUrl,
                                      ),
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(10),
                                        child: Image.network(
                                          displayMediaUrl,
                                          height: 180,
                                          width: double.infinity,
                                          fit: BoxFit.cover,
                                          loadingBuilder:
                                              (
                                                context,
                                                child,
                                                loadingProgress,
                                              ) {
                                                if (loadingProgress == null)
                                                  return child;
                                                return Container(
                                                  height: 180,
                                                  color: CxColors.card,
                                                  child: const Center(
                                                    child:
                                                        CircularProgressIndicator(
                                                          color: CxColors
                                                              .brightRed,
                                                          strokeWidth: 2,
                                                        ),
                                                  ),
                                                );
                                              },
                                          errorBuilder: (_, __, ___) =>
                                              Container(
                                                height: 100,
                                                color: CxColors.card,
                                                child: const Center(
                                                  child: Icon(
                                                    Icons.broken_image,
                                                    color: Colors.white70,
                                                  ),
                                                ),
                                              ),
                                        ),
                                      ),
                                    ),
                                    if (body.isNotEmpty &&
                                        body != '[Image Attached]' &&
                                        body != displayMediaUrl) ...[
                                      const SizedBox(height: 6),
                                      Padding(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 6,
                                          vertical: 2,
                                        ),
                                        child: Text(
                                          body,
                                          style: GoogleFonts.inter(
                                            fontSize: 13,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ] else if (isUrl)
                                    InkWell(
                                      onTap: () =>
                                          CxInAppBrowser.openUrl(context, body),
                                      child: Text(
                                        body,
                                        style: GoogleFonts.inter(
                                          fontSize: 13,
                                          color: Colors.white,
                                          decoration: TextDecoration.underline,
                                        ),
                                      ),
                                    )
                                  else
                                    Text(
                                      body,
                                      style: GoogleFonts.inter(
                                        fontSize: 13,
                                        color: Colors.white,
                                      ),
                                    ),
                                  const SizedBox(height: 3),
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    mainAxisAlignment: MainAxisAlignment.end,
                                    children: [
                                      Text(
                                        CxTimeFormat.formatMessageTime(
                                          DateTime.tryParse(
                                                msg['createdAt']?.toString() ??
                                                    msg['created_at']
                                                        ?.toString() ??
                                                    '',
                                              )?.toLocal() ??
                                              DateTime.now(),
                                        ),
                                        style: GoogleFonts.inter(
                                          fontSize: 10,
                                          color: isMe
                                              ? Colors.white70
                                              : CxColors.textMuted,
                                        ),
                                      ),
                                      if (isMe) ...[
                                        const SizedBox(width: 4),
                                        Icon(
                                          msg['status'] == 'Sending'
                                              ? Icons.access_time
                                              : msg['status'] == 'Failed'
                                              ? Icons.error_outline
                                              : Icons.done_all,
                                          size: 13,
                                          color:
                                              (msg['status'] == 'Seen' ||
                                                  msg['is_read'] == true)
                                              ? const Color(0xFFFF5964)
                                              : Colors.white70,
                                        ),
                                      ],
                                    ],
                                  ),
                                ],
                              ),
                            );
                          }

                          final isHighlighted =
                              msg['id']?.toString() == _highlightedMessageId;
                          final bubbleContent = AnimatedContainer(
                            duration: const Duration(milliseconds: 350),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(16),
                              border: isHighlighted
                                  ? Border.all(
                                      color: CxColors.brightRed,
                                      width: 2.5,
                                    )
                                  : null,
                              boxShadow: isHighlighted
                                  ? [
                                      BoxShadow(
                                        color: CxColors.brightRed.withOpacity(
                                          0.55,
                                        ),
                                        blurRadius: 14,
                                        spreadRadius: 2,
                                      ),
                                    ]
                                  : null,
                            ),
                            child: rawBubbleContent,
                          );

                          final msgDate =
                              DateTime.tryParse(
                                msg['createdAt']?.toString() ??
                                    msg['created_at']?.toString() ??
                                    '',
                              )?.toLocal() ??
                              DateTime.now();
                          final bool showDateSeparator;
                          if (index == _messages.length - 1) {
                            showDateSeparator = true;
                          } else {
                            final olderMsg = _messages[index + 1];
                            final olderDate =
                                DateTime.tryParse(
                                  olderMsg['createdAt']?.toString() ??
                                      olderMsg['created_at']?.toString() ??
                                      '',
                                )?.toLocal() ??
                                DateTime.now();
                            showDateSeparator =
                                msgDate.year != olderDate.year ||
                                msgDate.month != olderDate.month ||
                                msgDate.day != olderDate.day;
                          }

                          return Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (showDateSeparator)
                                _buildDateSeparator(msgDate),
                              Dismissible(
                                key: Key('msg_reply_${msg['id'] ?? index}'),
                                direction: DismissDirection.startToEnd,
                                confirmDismiss: (_) async {
                                  HapticFeedback.lightImpact();
                                  setState(() => _replyingToMessage = msg);
                                  return false;
                                },
                                background: Container(
                                  alignment: Alignment.centerLeft,
                                  padding: const EdgeInsets.only(left: 20),
                                  child: const Icon(
                                    Icons.reply_rounded,
                                    color: CxColors.brightRed,
                                    size: 24,
                                  ),
                                ),
                                child: GestureDetector(
                                  onDoubleTap: () => _toggleReaction(
                                    msg['id']?.toString() ?? '',
                                    '❤️',
                                  ),
                                  onLongPress: () => _showMessageOptions(msg),
                                  child: Container(
                                    margin: const EdgeInsets.only(bottom: 8),
                                    child: isMe
                                        ? Align(
                                            alignment: Alignment.centerRight,
                                            child: Container(
                                              constraints: BoxConstraints(
                                                maxWidth:
                                                    MediaQuery.of(context)
                                                        .size
                                                        .width *
                                                    0.78,
                                              ),
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.end,
                                                children: [
                                                  bubbleContent,
                                                  if (reactions.isNotEmpty)
                                                    Container(
                                                      margin:
                                                          const EdgeInsets.only(
                                                            top: 2,
                                                          ),
                                                      padding:
                                                          const EdgeInsets.symmetric(
                                                            horizontal: 6,
                                                            vertical: 2,
                                                          ),
                                                      decoration: BoxDecoration(
                                                        color: CxColors
                                                            .cardElevated,
                                                        borderRadius:
                                                            BorderRadius.circular(
                                                              10,
                                                            ),
                                                        border: Border.all(
                                                          color: CxColors
                                                              .borderSubtle,
                                                        ),
                                                      ),
                                                      child: Text(
                                                        reactions.join(' '),
                                                        style: const TextStyle(
                                                          fontSize: 11,
                                                        ),
                                                      ),
                                                    ),
                                                  _buildStatusIndicator(
                                                    msg,
                                                    isMe,
                                                    index,
                                                  ),
                                                ],
                                              ),
                                            ),
                                          )
                                        : Row(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.end,
                                            children: [
                                              if (isGroup) ...[
                                                if (!isSameSenderAsOlder)
                                                  CxAvatar(
                                                    name: senderName,
                                                    imageUrl: senderAvatar,
                                                    radius: 14,
                                                  )
                                                else
                                                  const SizedBox(width: 28),
                                                const SizedBox(width: 8),
                                              ],
                                              Container(
                                                constraints: BoxConstraints(
                                                  maxWidth:
                                                      MediaQuery.of(context)
                                                          .size
                                                          .width *
                                                      0.72,
                                                ),
                                                child: Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    if (isGroup &&
                                                        !isSameSenderAsOlder)
                                                      Padding(
                                                        padding:
                                                            const EdgeInsets.only(
                                                              left: 4,
                                                              bottom: 2,
                                                            ),
                                                        child: Text(
                                                          senderName,
                                                          style:
                                                              GoogleFonts.inter(
                                                                fontSize: 11,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .w700,
                                                                color: CxColors
                                                                    .brightRed,
                                                              ),
                                                        ),
                                                      ),
                                                    bubbleContent,
                                                    if (reactions.isNotEmpty)
                                                      Container(
                                                        margin:
                                                            const EdgeInsets.only(
                                                              top: 2,
                                                            ),
                                                        padding:
                                                            const EdgeInsets.symmetric(
                                                              horizontal: 6,
                                                              vertical: 2,
                                                            ),
                                                        decoration: BoxDecoration(
                                                          color: CxColors
                                                              .cardElevated,
                                                          borderRadius:
                                                              BorderRadius.circular(
                                                                10,
                                                              ),
                                                          border: Border.all(
                                                            color: CxColors
                                                                .borderSubtle,
                                                          ),
                                                        ),
                                                        child: Text(
                                                          reactions.join(' '),
                                                          style:
                                                              const TextStyle(
                                                                fontSize: 11,
                                                              ),
                                                        ),
                                                      ),
                                                  ],
                                                ),
                                              ),
                                            ],
                                          ),
                                  ),
                                ),
                              ),
                            ],
                          );
                        },
                      ),
              ),

              // Enhanced Chat Composer
              Container(
                padding: EdgeInsets.only(
                  left: CxSpacing.sm,
                  right: CxSpacing.sm,
                  top: CxSpacing.xs,
                  bottom:
                      MediaQuery.of(context).viewInsets.bottom +
                      (MediaQuery.of(context).viewInsets.bottom > 0
                          ? CxSpacing.sm
                          : MediaQuery.of(context).padding.bottom +
                                CxSpacing.sm),
                ),
                decoration: const BoxDecoration(
                  color: CxColors.cardElevated,
                  border: Border(top: BorderSide(color: CxColors.borderSubtle)),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_replyingToMessage != null)
                      Container(
                        margin: const EdgeInsets.only(bottom: 6),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: CxColors.card,
                          borderRadius: BorderRadius.circular(10),
                          border: const Border(
                            left: BorderSide(
                              color: CxColors.brightRed,
                              width: 3.5,
                            ),
                          ),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    (_replyingToMessage!['senderName'] ??
                                            (_replyingToMessage!['senderId'] ==
                                                    user?.id
                                                ? 'You'
                                                : 'Colleague'))
                                        .toString(),
                                    style: GoogleFonts.inter(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: CxColors.brightRed,
                                    ),
                                  ),
                                  Text(
                                    (_replyingToMessage!['message'] ??
                                            _replyingToMessage!['text'] ??
                                            'Attachment')
                                        .toString(),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: GoogleFonts.inter(
                                      fontSize: 12,
                                      color: CxColors.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              icon: const Icon(
                                Icons.close,
                                size: 18,
                                color: CxColors.textMuted,
                              ),
                              onPressed: () =>
                                  setState(() => _replyingToMessage = null),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                            ),
                          ],
                        ),
                      ),
                    Row(
                      children: [
                        IconButton(
                          icon: const Icon(
                            Icons.camera_alt_outlined,
                            color: CxColors.textSecondary,
                            size: 22,
                          ),
                          tooltip: 'Take Photo',
                          onPressed: () =>
                              _pickAndSendMedia(ImageSource.camera),
                        ),
                        IconButton(
                          icon: const Icon(
                            Icons.photo_library_outlined,
                            color: CxColors.textSecondary,
                            size: 22,
                          ),
                          tooltip: 'Gallery',
                          onPressed: () =>
                              _pickAndSendMedia(ImageSource.gallery),
                        ),
                        IconButton(
                          icon: const Icon(
                            Icons.videocam_outlined,
                            color: CxColors.textSecondary,
                            size: 22,
                          ),
                          tooltip: 'Video',
                          onPressed: () =>
                              _pickAndSendVideo(ImageSource.gallery),
                        ),
                        IconButton(
                          icon: const Icon(
                            Icons.sticky_note_2_outlined,
                            color: CxColors.brightRed,
                            size: 22,
                          ),
                          tooltip: 'Stickers',
                          onPressed: () {
                            FocusScope.of(context).unfocus();
                            StickerPickerSheet.show(
                              context,
                              onStickerSelected: (stickerId) =>
                                  _sendSticker(stickerId),
                            );
                          },
                        ),
                        Expanded(
                          child: TextField(
                            controller: _messageController,
                            style: GoogleFonts.inter(
                              color: CxColors.textPrimary,
                              fontSize: 14,
                            ),
                            decoration: InputDecoration(
                              hintText: 'Type a message...',
                              hintStyle: GoogleFonts.inter(
                                color: CxColors.textMuted,
                                fontSize: 13,
                              ),
                              border: InputBorder.none,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 8,
                              ),
                            ),
                            onSubmitted: (_) => _sendMessage(),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(
                            Icons.send_rounded,
                            color: CxColors.brightRed,
                            size: 24,
                          ),
                          onPressed: () => _sendMessage(),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
