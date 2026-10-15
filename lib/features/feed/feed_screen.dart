import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/api/api_client.dart';
import '../../core/providers/app_providers.dart';
import '../../core/theme/cx_theme.dart';
import '../../core/widgets/cx_components.dart';

// --- FEED POSTS PROVIDER ---
final feedPostsProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
      final api = CxApiClient();
      try {
        final res = await api.dio.get('/api/mobile/posts');
        if (res.data != null && res.data['ok'] == true) {
          return (res.data['posts'] as List<dynamic>?)
                  ?.map((p) => Map<String, dynamic>.from(p))
                  .toList() ??
              [];
        }
      } catch (_) {}
      return [];
    });

class FeedScreen extends ConsumerStatefulWidget {
  const FeedScreen({super.key});

  @override
  ConsumerState<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends ConsumerState<FeedScreen> {
  void _openCreatePostSheet() {
    final textController = TextEditingController();
    bool isAnnouncement = false;
    final user = ref.read(authProvider).user;
    final role = user?.role ?? 'EMPLOYEE';
    final canAnnounce = [
      'FOUNDER',
      'CO_FOUNDER',
      'CEO',
      'CTO',
      'HR',
      'OWNER',
      'ADMIN',
    ].contains(role);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: CxColors.cardElevated,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setSheetState) => Padding(
          padding: EdgeInsets.only(
            left: CxSpacing.lg,
            right: CxSpacing.lg,
            top: CxSpacing.lg,
            bottom: MediaQuery.of(context).viewInsets.bottom + CxSpacing.lg,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'CREATE POST',
                style: GoogleFonts.orbitron(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: CxColors.textPrimary,
                ),
              ),
              const SizedBox(height: CxSpacing.md),
              CxTextField(
                hint: 'What\'s happening at CodeXa?',
                controller: textController,
                maxLines: 4,
              ),
              if (canAnnounce) ...[
                const SizedBox(height: CxSpacing.sm),
                Row(
                  children: [
                    Checkbox(
                      value: isAnnouncement,
                      activeColor: CxColors.brightRed,
                      onChanged: (val) =>
                          setSheetState(() => isAnnouncement = val ?? false),
                    ),
                    Text(
                      'Official Announcement',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: CxColors.textPrimary,
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: CxSpacing.lg),
              CxButton(
                label: 'PUBLISH POST',
                onPressed: () async {
                  final content = textController.text.trim();
                  if (content.isEmpty) return;

                  Navigator.pop(ctx);
                  final api = CxApiClient();
                  try {
                    await api.dio.post(
                      '/api/mobile/posts',
                      data: {
                        'content': content,
                        'isAnnouncement': isAnnouncement,
                      },
                    );
                    ref.invalidate(feedPostsProvider);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Post published successfully!'),
                          backgroundColor: CxColors.success,
                        ),
                      );
                    }
                  } catch (_) {}
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _openCommentsSheet(String postId, List<dynamic> comments) {
    final commentController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: CxColors.cardElevated,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setCommentState) => Container(
          padding: EdgeInsets.only(
            left: CxSpacing.lg,
            right: CxSpacing.lg,
            top: CxSpacing.lg,
            bottom: MediaQuery.of(context).viewInsets.bottom + CxSpacing.lg,
          ),
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.75,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'COMMENTS',
                style: GoogleFonts.orbitron(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: CxColors.textPrimary,
                ),
              ),
              const SizedBox(height: CxSpacing.md),
              Expanded(
                child: comments.isEmpty
                    ? Center(
                        child: Text(
                          'No comments yet. Be the first to comment!',
                          style: GoogleFonts.inter(
                            color: CxColors.textMuted,
                            fontSize: 13,
                          ),
                        ),
                      )
                    : ListView.builder(
                        itemCount: comments.length,
                        itemBuilder: (context, idx) {
                          final c = comments[idx];
                          return ListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text(
                              c['authorName'] ?? 'Member',
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: CxColors.textPrimary,
                              ),
                            ),
                            subtitle: Text(
                              c['content'] ?? '',
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                color: CxColors.textSecondary,
                              ),
                            ),
                          );
                        },
                      ),
              ),
              const Divider(color: CxColors.borderSubtle),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: commentController,
                      style: GoogleFonts.inter(
                        color: CxColors.textPrimary,
                        fontSize: 13,
                      ),
                      decoration: const InputDecoration(
                        hintText: 'Add a comment...',
                        hintStyle: TextStyle(color: CxColors.textMuted),
                        border: InputBorder.none,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.send, color: CxColors.brightRed),
                    onPressed: () async {
                      final text = commentController.text.trim();
                      if (text.isEmpty) return;

                      final api = CxApiClient();
                      try {
                        await api.dio.post(
                          '/api/mobile/posts/$postId/comments',
                          data: {'content': text},
                        );
                        if (ctx.mounted) {
                          Navigator.pop(ctx);
                        }
                        ref.invalidate(feedPostsProvider);
                      } catch (_) {}
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _toggleLike(String postId) async {
    final api = CxApiClient();
    try {
      await api.dio.post('/api/mobile/posts/$postId/like');
      ref.invalidate(feedPostsProvider);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final postsAsync = ref.watch(feedPostsProvider);

    return Scaffold(
      backgroundColor: CxColors.background,
      floatingActionButton: FloatingActionButton(
        backgroundColor: CxColors.crimson,
        onPressed: _openCreatePostSheet,
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: RefreshIndicator(
        color: CxColors.brightRed,
        backgroundColor: CxColors.cardElevated,
        onRefresh: () async => ref.invalidate(feedPostsProvider),
        child: postsAsync.when(
          loading: () => const Center(
            child: CircularProgressIndicator(color: CxColors.brightRed),
          ),
          error: (err, _) => CxEmptyState(
            icon: Icons.dynamic_feed,
            title: 'FEED UNAVAILABLE',
            message: 'Could not load internal company posts.',
            action: CxButton(
              label: 'RELOAD',
              width: 120,
              onPressed: () => ref.invalidate(feedPostsProvider),
            ),
          ),
          data: (posts) {
            if (posts.isEmpty) {
              return const CxEmptyState(
                icon: Icons.dynamic_feed,
                title: 'CODEXA FEED',
                message:
                    'No posts yet. Tap + to share an update with the team.',
              );
            }

            return ListView.separated(
              padding: const EdgeInsets.all(CxSpacing.lg),
              itemCount: posts.length,
              separatorBuilder: (_, __) => const SizedBox(height: CxSpacing.md),
              itemBuilder: (context, index) {
                final post = posts[index];
                final author = post['author'] ?? {};
                final authorName =
                    author['name'] ?? author['username'] ?? 'Team Member';
                final authorRole =
                    author['primaryRole'] ?? author['role'] ?? 'Engineer';
                final isAnnouncement = post['isAnnouncement'] == true;
                final content = post['content'] ?? '';
                final likesCount = post['likesCount'] ?? 0;
                final hasLiked = post['hasLiked'] == true;
                final comments = post['comments'] as List<dynamic>? ?? [];

                return CxCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header: Avatar, Name, Role Badge, Announcement Tag
                      Row(
                        children: [
                          CxAvatar(
                            name: authorName,
                            imageUrl: author['avatarUrl'],
                            radius: 18,
                          ),
                          const SizedBox(width: CxSpacing.sm),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  authorName,
                                  style: GoogleFonts.inter(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: CxColors.textPrimary,
                                  ),
                                ),
                                Text(
                                  authorRole,
                                  style: GoogleFonts.inter(
                                    fontSize: 11,
                                    color: CxColors.textMuted,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (isAnnouncement)
                            const CxStatusChip(
                              label: 'ANNOUNCEMENT',
                              isSmall: true,
                            ),
                        ],
                      ),
                      const SizedBox(height: CxSpacing.md),

                      // Post Content
                      Text(
                        content,
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          color: CxColors.textPrimary,
                          height: 1.45,
                        ),
                      ),
                      const SizedBox(height: CxSpacing.md),

                      // Actions: Like Heart & Comments
                      Row(
                        children: [
                          InkWell(
                            onTap: () => _toggleLike(post['id']),
                            borderRadius: BorderRadius.circular(12),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 4,
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    hasLiked
                                        ? Icons.favorite
                                        : Icons.favorite_border,
                                    size: 18,
                                    color: hasLiked
                                        ? CxColors.brightRed
                                        : CxColors.textSecondary,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    '$likesCount',
                                    style: GoogleFonts.inter(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: hasLiked
                                          ? CxColors.brightRed
                                          : CxColors.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: CxSpacing.lg),
                          InkWell(
                            onTap: () =>
                                _openCommentsSheet(post['id'], comments),
                            borderRadius: BorderRadius.circular(12),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 4,
                              ),
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.chat_bubble_outline,
                                    size: 18,
                                    color: CxColors.textSecondary,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    '${comments.length}',
                                    style: GoogleFonts.inter(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: CxColors.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}
