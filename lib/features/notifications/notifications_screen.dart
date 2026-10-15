import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import '../../core/api/api_client.dart';
import '../../core/providers/app_providers.dart';
import '../../core/theme/cx_theme.dart';
import '../../core/widgets/cx_components.dart';
import '../messages/messages_screen.dart';

final notificationsListProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
      final api = CxApiClient();
      try {
        final res = await api.dio.get('/api/mobile/notifications');
        if (res.data != null && res.data['ok'] == true) {
          return (res.data['notifications'] as List<dynamic>?)
                  ?.map((n) => Map<String, dynamic>.from(n))
                  .toList() ??
              [];
        }
      } catch (_) {}
      return [];
    });

class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key});

  @override
  ConsumerState<NotificationsScreen> createState() =>
      _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen> {
  String _selectedFilter = 'ALL';

  String? _extractConversationId(Map<String, dynamic> notif) {
    final route = notif['route']?.toString() ?? '';
    if (route.contains('/messages/')) {
      final parts = route.split('/messages/');
      if (parts.length > 1) {
        return parts[1].split('?').first.trim();
      }
    }
    if (route.contains('/chat/')) {
      final parts = route.split('/chat/');
      if (parts.length > 1) {
        return parts[1].split('?').first.trim();
      }
    }
    return notif['conversationId']?.toString();
  }

  String? _extractPaymentId(Map<String, dynamic> notif) {
    final route = notif['route']?.toString() ?? '';
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
    return notif['paymentId']?.toString();
  }

  bool _isChatMessage(Map<String, dynamic> notif) {
    final cat = (notif['category'] ?? '').toString().toUpperCase();
    final title = (notif['title'] ?? '').toString().toLowerCase();
    final route = (notif['route'] ?? '').toString();
    return cat.contains('MESSAGE') ||
        cat.contains('CHAT') ||
        title.contains('message from') ||
        route.contains('/messages/') ||
        route.contains('/chat/');
  }

  bool _isPaymentNotification(Map<String, dynamic> notif) {
    final cat = (notif['category'] ?? '').toString().toUpperCase();
    final title = (notif['title'] ?? '').toString().toLowerCase();
    final route = (notif['route'] ?? '').toString();
    return cat.contains('PAYMENT') ||
        title.contains('payment') ||
        route.contains('/admin/payments') ||
        route.contains('/payments');
  }

  Future<void> _markNotificationRead(String notificationId) async {
    final api = CxApiClient();
    try {
      await api.dio.post(
        '/api/mobile/notifications',
        data: {'notificationId': notificationId},
      );
      ref.invalidate(notificationsListProvider);
      ref.invalidate(bootstrapProvider);
    } catch (_) {}
  }

  void _openChatScreen(String conversationId, String senderTitle) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ChatConversationScreen(
          conversation: {
            'id': conversationId,
            'name': senderTitle,
            'title': senderTitle,
          },
        ),
      ),
    );
  }

  void _showQuickReplySheet(Map<String, dynamic> notif, String conversationId) {
    final replyController = TextEditingController();
    final notifId = notif['id']?.toString() ?? '';
    final rawTitle = notif['title']?.toString() ?? 'Message';
    final senderName = rawTitle
        .replaceFirst(RegExp(r'Message from\s*', caseSensitive: false), '')
        .trim();
    final originalBody = notif['body']?.toString() ?? '';

    final quickChips = [
      'Got it, on it! 👍',
      'I\'ll check and update you.',
      'Sounds good! 🚀',
      'Can we discuss this on a call?',
      'Working on this right now 💻',
      'Thank you!',
    ];

    bool isSending = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            final bottomInset = MediaQuery.of(ctx).viewInsets.bottom;

            Future<void> sendReply([String? prefilledText]) async {
              final text = (prefilledText ?? replyController.text).trim();
              if (text.isEmpty || isSending) return;

              setSheetState(() => isSending = true);

              final api = CxApiClient();
              const uuid = Uuid();
              final clientId = uuid.v4();

              try {
                final res = await api.dio.post(
                  '/api/chat/messages',
                  data: {
                    'conversationId': conversationId,
                    'message': text,
                    'text': text,
                    'clientId': clientId,
                    'client_message_id': clientId,
                  },
                );

                if (res.data != null &&
                    (res.data['ok'] == true || res.data['success'] == true)) {
                  // Mark this notification as read automatically
                  if (notifId.isNotEmpty) {
                    _markNotificationRead(notifId);
                  }

                  if (sheetContext.mounted) {
                    Navigator.pop(sheetContext);
                  }
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        backgroundColor: CxColors.cardElevated,
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                          side: const BorderSide(
                            color: CxColors.brightRed,
                            width: 1,
                          ),
                        ),
                        content: Row(
                          children: [
                            const Icon(
                              Icons.check_circle,
                              color: CxColors.success,
                              size: 20,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'Reply sent to $senderName!',
                                style: GoogleFonts.inter(
                                  color: CxColors.textPrimary,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                        duration: const Duration(seconds: 3),
                      ),
                    );
                    ref.invalidate(notificationsListProvider);
                  }
                  return;
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      backgroundColor: CxColors.cardElevated,
                      content: Text(
                        'Failed to send reply. Please try opening the chat.',
                        style: GoogleFonts.inter(color: CxColors.error),
                      ),
                    ),
                  );
                }
              }

              if (ctx.mounted) {
                setSheetState(() => isSending = false);
              }
            }

            return Container(
              padding: EdgeInsets.only(bottom: bottomInset),
              decoration: const BoxDecoration(
                color: CxColors.surface,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                border: Border(
                  top: BorderSide(color: CxColors.borderSubtle, width: 1.5),
                  left: BorderSide(color: CxColors.borderSubtle, width: 1.5),
                  right: BorderSide(color: CxColors.borderSubtle, width: 1.5),
                ),
              ),
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 16,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Handle drag pill
                      Center(
                        child: Container(
                          width: 40,
                          height: 4,
                          decoration: BoxDecoration(
                            color: Colors.white24,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),

                      // Header: Quick Reply + Recipient
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(7),
                                decoration: BoxDecoration(
                                  color: CxColors.brightRed.withOpacity(0.15),
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: CxColors.brightRed,
                                    width: 1,
                                  ),
                                ),
                                child: const Icon(
                                  Icons.reply_rounded,
                                  color: CxColors.brightRed,
                                  size: 16,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'QUICK REPLY',
                                    style: GoogleFonts.orbitron(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w800,
                                      color: CxColors.brightRed,
                                      letterSpacing: 1.2,
                                    ),
                                  ),
                                  Text(
                                    senderName.isNotEmpty
                                        ? senderName
                                        : 'Colleague',
                                    style: GoogleFonts.inter(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                      color: CxColors.textPrimary,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          TextButton.icon(
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            icon: const Icon(
                              Icons.open_in_new,
                              size: 13,
                              color: CxColors.textSecondary,
                            ),
                            label: Text(
                              'OPEN CHAT',
                              style: GoogleFonts.inter(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: CxColors.textSecondary,
                              ),
                            ),
                            onPressed: () {
                              Navigator.pop(sheetContext);
                              _openChatScreen(conversationId, senderName);
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Original message quote box
                      if (originalBody.isNotEmpty)
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: CxColors.cardElevated,
                            borderRadius: BorderRadius.circular(10),
                            border: const Border(
                              left: BorderSide(
                                color: CxColors.brightRed,
                                width: 3,
                              ),
                            ),
                          ),
                          child: Text(
                            originalBody,
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              color: CxColors.textSecondary,
                              fontStyle: FontStyle.italic,
                              height: 1.3,
                            ),
                          ),
                        ),
                      const SizedBox(height: 12),

                      // Quick chip suggestions
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: quickChips.map((chipText) {
                            return Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: InkWell(
                                onTap: isSending
                                    ? null
                                    : () => sendReply(chipText),
                                borderRadius: BorderRadius.circular(16),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: CxColors.cardElevated,
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(
                                      color: CxColors.borderSubtle,
                                    ),
                                  ),
                                  child: Text(
                                    chipText,
                                    style: GoogleFonts.inter(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w500,
                                      color: CxColors.textPrimary,
                                    ),
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                      const SizedBox(height: 14),

                      // Text input & Send button
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Expanded(
                            child: Container(
                              decoration: BoxDecoration(
                                color: CxColors.cardElevated,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: CxColors.borderSubtle,
                                ),
                              ),
                              child: TextField(
                                controller: replyController,
                                autofocus: true,
                                maxLines: 4,
                                minLines: 1,
                                style: GoogleFonts.inter(
                                  fontSize: 13,
                                  color: CxColors.textPrimary,
                                ),
                                decoration: InputDecoration(
                                  hintText: 'Type your reply...',
                                  hintStyle: GoogleFonts.inter(
                                    fontSize: 13,
                                    color: CxColors.textSecondary,
                                  ),
                                  border: InputBorder.none,
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                    vertical: 10,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            height: 44,
                            width: 44,
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [CxColors.brightRed, Color(0xFFB00020)],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(14),
                              boxShadow: [
                                BoxShadow(
                                  color: CxColors.brightRed.withOpacity(0.3),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: isSending
                                ? const Center(
                                    child: SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        color: Colors.white,
                                        strokeWidth: 2,
                                      ),
                                    ),
                                  )
                                : IconButton(
                                    icon: const Icon(
                                      Icons.send_rounded,
                                      color: Colors.white,
                                      size: 20,
                                    ),
                                    onPressed: () => sendReply(),
                                  ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final notifsAsync = ref.watch(notificationsListProvider);

    return Scaffold(
      backgroundColor: CxColors.background,
      appBar: CxAppBar(
        title: 'NOTIFICATIONS',
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: CxColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          TextButton(
            onPressed: () async {
              final api = CxApiClient();
              try {
                await api.dio.post(
                  '/api/mobile/notifications',
                  data: {'markAll': true},
                );
                ref.invalidate(notificationsListProvider);
                ref.invalidate(bootstrapProvider);
              } catch (_) {}
            },
            child: Text(
              'MARK ALL READ',
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: CxColors.brightRed,
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // Filter Tabs (ALL / MESSAGES / PAYMENTS / GENERAL)
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: CxSpacing.md,
              vertical: 8,
            ),
            color: CxColors.surface,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildFilterTab('ALL', Icons.all_inbox),
                  const SizedBox(width: 8),
                  _buildFilterTab('MESSAGES', Icons.chat_bubble_outline),
                  const SizedBox(width: 8),
                  _buildFilterTab('PAYMENTS', Icons.shield_outlined),
                  const SizedBox(width: 8),
                  _buildFilterTab('ATTENDANCE', Icons.alarm_on),
                ],
              ),
            ),
          ),

          // Notification List
          Expanded(
            child: RefreshIndicator(
              color: CxColors.brightRed,
              backgroundColor: CxColors.cardElevated,
              onRefresh: () async => ref.invalidate(notificationsListProvider),
              child: notifsAsync.when(
                loading: () => const Center(
                  child: CircularProgressIndicator(color: CxColors.brightRed),
                ),
                error: (_, __) => const CxEmptyState(
                  icon: Icons.notifications_off_outlined,
                  title: 'NOTIFICATIONS',
                  message: 'No notifications available.',
                ),
                data: (notifications) {
                  // Apply category filter
                  final filtered = notifications.where((n) {
                    if (_selectedFilter == 'ALL') return true;
                    if (_selectedFilter == 'MESSAGES') return _isChatMessage(n);
                    if (_selectedFilter == 'PAYMENTS')
                      return _isPaymentNotification(n);
                    if (_selectedFilter == 'ATTENDANCE') {
                      final cat = (n['category'] ?? '')
                          .toString()
                          .toUpperCase();
                      return cat.contains('ATTENDANCE');
                    }
                    return true;
                  }).toList();

                  if (filtered.isEmpty) {
                    return const CxEmptyState(
                      icon: Icons.notifications_none,
                      title: 'ALL CAUGHT UP',
                      message: 'You have no notifications in this category.',
                    );
                  }

                  return ListView.separated(
                    padding: const EdgeInsets.all(CxSpacing.md),
                    itemCount: filtered.length,
                    separatorBuilder: (_, __) =>
                        const SizedBox(height: CxSpacing.sm),
                    itemBuilder: (context, index) {
                      final n = filtered[index];
                      final notifId = n['id']?.toString() ?? '';
                      final title = n['title'] ?? 'Notification';
                      final body = n['body'] ?? '';
                      final category = (n['category'] ?? 'GENERAL')
                          .toString()
                          .toUpperCase();
                      final isRead = n['isRead'] == true;
                      final route = n['route']?.toString() ?? '';
                      final createdAt = n['createdAt'] != null
                          ? DateTime.tryParse(n['createdAt'].toString())
                          : null;

                      final isChat = _isChatMessage(n);
                      final isPayment = _isPaymentNotification(n);
                      final convId = isChat ? _extractConversationId(n) : null;
                      final paymentId = isPayment ? _extractPaymentId(n) : null;

                      IconData icon = Icons.notifications;
                      Color iconColor = CxColors.brightRed;

                      if (isChat) {
                        icon = Icons.chat_bubble_outline;
                        iconColor = CxColors.info;
                      } else if (isPayment) {
                        icon = Icons.shield_outlined;
                        iconColor = CxColors.brightRed;
                      } else if (category.contains('ATTENDANCE')) {
                        icon = Icons.alarm_on;
                        iconColor = CxColors.warning;
                      } else if (category.contains('HR') ||
                          category.contains('LEAVE')) {
                        icon = Icons.event_available;
                        iconColor = CxColors.success;
                      }

                      return InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () {
                          if (!isRead && notifId.isNotEmpty) {
                            _markNotificationRead(notifId);
                          }
                          if (isChat && convId != null && convId.isNotEmpty) {
                            _openChatScreen(convId, title);
                          } else if (isPayment &&
                              paymentId != null &&
                              paymentId.isNotEmpty) {
                            context.push('/payments?paymentId=$paymentId');
                          } else if (route.isNotEmpty) {
                            context.push(route);
                          }
                        },
                        child: CxCard(
                          backgroundColor: isRead
                              ? CxColors.card
                              : CxColors.cardElevated,
                          padding: const EdgeInsets.all(CxSpacing.md),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    width: 38,
                                    height: 38,
                                    decoration: BoxDecoration(
                                      color: CxColors.secondaryDark,
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: iconColor.withOpacity(0.5),
                                      ),
                                    ),
                                    child: Icon(
                                      icon,
                                      color: iconColor,
                                      size: 18,
                                    ),
                                  ),
                                  const SizedBox(width: CxSpacing.md),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.spaceBetween,
                                          children: [
                                            Text(
                                              category,
                                              style: GoogleFonts.inter(
                                                fontSize: 10,
                                                fontWeight: FontWeight.w700,
                                                color: iconColor,
                                                letterSpacing: 0.5,
                                              ),
                                            ),
                                            Row(
                                              children: [
                                                if (createdAt != null)
                                                  Text(
                                                    DateFormat('h:mm a').format(
                                                      createdAt.toLocal(),
                                                    ),
                                                    style: GoogleFonts.inter(
                                                      fontSize: 10,
                                                      color: CxColors
                                                          .textSecondary,
                                                    ),
                                                  ),
                                                const SizedBox(width: 6),
                                                if (!isRead)
                                                  Container(
                                                    width: 7,
                                                    height: 7,
                                                    decoration:
                                                        const BoxDecoration(
                                                          color: CxColors
                                                              .brightRed,
                                                          shape:
                                                              BoxShape.circle,
                                                        ),
                                                  ),
                                              ],
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          title,
                                          style: GoogleFonts.inter(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w700,
                                            color: CxColors.textPrimary,
                                          ),
                                        ),
                                        const SizedBox(height: 3),
                                        Text(
                                          body,
                                          style: GoogleFonts.inter(
                                            fontSize: 12,
                                            color: CxColors.textSecondary,
                                            height: 1.35,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),

                              // Interactive Action Row
                              if (isChat || isPayment || route.isNotEmpty) ...[
                                const SizedBox(height: 12),
                                Container(
                                  padding: const EdgeInsets.only(top: 8),
                                  decoration: const BoxDecoration(
                                    border: Border(
                                      top: BorderSide(
                                        color: CxColors.borderSubtle,
                                        width: 0.8,
                                      ),
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.end,
                                    children: [
                                      // Chat Quick Reply & Open Options
                                      if (isChat) ...[
                                        if (convId != null && convId.isNotEmpty)
                                          ElevatedButton.icon(
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor:
                                                  CxColors.brightRed,
                                              foregroundColor: Colors.white,
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 14,
                                                    vertical: 6,
                                                  ),
                                              minimumSize: Size.zero,
                                              tapTargetSize:
                                                  MaterialTapTargetSize
                                                      .shrinkWrap,
                                              shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                              ),
                                            ),
                                            icon: const Icon(
                                              Icons.reply_rounded,
                                              size: 14,
                                            ),
                                            label: Text(
                                              'REPLY',
                                              style: GoogleFonts.inter(
                                                fontSize: 11,
                                                fontWeight: FontWeight.w700,
                                                letterSpacing: 0.5,
                                              ),
                                            ),
                                            onPressed: () =>
                                                _showQuickReplySheet(n, convId),
                                          ),
                                        const SizedBox(width: 8),
                                        OutlinedButton.icon(
                                          style: OutlinedButton.styleFrom(
                                            foregroundColor:
                                                CxColors.textPrimary,
                                            side: const BorderSide(
                                              color: CxColors.borderSubtle,
                                            ),
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 12,
                                              vertical: 6,
                                            ),
                                            minimumSize: Size.zero,
                                            tapTargetSize: MaterialTapTargetSize
                                                .shrinkWrap,
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                            ),
                                          ),
                                          icon: const Icon(
                                            Icons.chat_bubble_outline,
                                            size: 13,
                                          ),
                                          label: Text(
                                            'OPEN CHAT',
                                            style: GoogleFonts.inter(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                          onPressed: () {
                                            if (!isRead && notifId.isNotEmpty) {
                                              _markNotificationRead(notifId);
                                            }
                                            if (convId != null &&
                                                convId.isNotEmpty) {
                                              _openChatScreen(convId, title);
                                            }
                                          },
                                        ),
                                      ],

                                      // Payment Review Option
                                      if (isPayment)
                                        ElevatedButton.icon(
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: CxColors.brightRed,
                                            foregroundColor: Colors.white,
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 14,
                                              vertical: 6,
                                            ),
                                            minimumSize: Size.zero,
                                            tapTargetSize: MaterialTapTargetSize
                                                .shrinkWrap,
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                            ),
                                          ),
                                          icon: const Icon(
                                            Icons.rate_review_outlined,
                                            size: 14,
                                          ),
                                          label: Text(
                                            'REVIEW PAYMENT',
                                            style: GoogleFonts.inter(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                          onPressed: () {
                                            if (!isRead && notifId.isNotEmpty) {
                                              _markNotificationRead(notifId);
                                            }
                                            context.push(
                                              '/payments?paymentId=${paymentId ?? ''}',
                                            );
                                          },
                                        ),

                                      // General View Option
                                      if (!isChat &&
                                          !isPayment &&
                                          route.isNotEmpty)
                                        OutlinedButton.icon(
                                          style: OutlinedButton.styleFrom(
                                            foregroundColor: CxColors.brightRed,
                                            side: const BorderSide(
                                              color: CxColors.brightRed,
                                            ),
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 12,
                                              vertical: 6,
                                            ),
                                            minimumSize: Size.zero,
                                            tapTargetSize: MaterialTapTargetSize
                                                .shrinkWrap,
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                            ),
                                          ),
                                          icon: const Icon(
                                            Icons.arrow_forward,
                                            size: 13,
                                          ),
                                          label: Text(
                                            'VIEW',
                                            style: GoogleFonts.inter(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                          onPressed: () {
                                            if (!isRead && notifId.isNotEmpty) {
                                              _markNotificationRead(notifId);
                                            }
                                            context.push(route);
                                          },
                                        ),
                                    ],
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterTab(String label, IconData icon) {
    final isSelected = _selectedFilter == label;
    return InkWell(
      onTap: () => setState(() => _selectedFilter = label),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? CxColors.brightRed : CxColors.cardElevated,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? CxColors.brightRed : CxColors.borderSubtle,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 13,
              color: isSelected ? Colors.white : CxColors.textSecondary,
            ),
            const SizedBox(width: 5),
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected ? Colors.white : CxColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
