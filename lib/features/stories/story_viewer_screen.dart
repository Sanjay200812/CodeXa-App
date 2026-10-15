import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:video_player/video_player.dart';

import '../../core/api/api_client.dart';
import '../../core/models/models.dart';
import '../../core/theme/cx_theme.dart';
import '../../core/utils/cx_time_format.dart';
import '../../core/widgets/cx_components.dart';
import 'stories_tray.dart';
import 'story_composer_screen.dart';

class StoryViewerScreen extends ConsumerStatefulWidget {
  final StoryGroupModel group;
  final int initialIndex;

  const StoryViewerScreen({
    super.key,
    required this.group,
    this.initialIndex = 0,
  });

  @override
  ConsumerState<StoryViewerScreen> createState() => _StoryViewerScreenState();
}

class _StoryViewerScreenState extends ConsumerState<StoryViewerScreen>
    with SingleTickerProviderStateMixin {
  late int _currentIndex;
  late AnimationController _progressController;
  final Set<String> _viewedIds = {};
  final Map<String, bool> _likedStories = {};
  final Map<String, int> _likeCounts = {};
  VideoPlayerController? _videoController;

  @override
  void initState() {
    super.initState();
    _currentIndex =
        (widget.initialIndex >= 0 &&
            widget.initialIndex < widget.group.items.length)
        ? widget.initialIndex
        : 0;

    _progressController =
        AnimationController(vsync: this, duration: const Duration(seconds: 6))
          ..addStatusListener((status) {
            if (status == AnimationStatus.completed) {
              _nextStory();
            }
          });

    _recordCurrentStoryView();
    _setupStoryMedia();
  }

  @override
  void dispose() {
    _videoController?.pause();
    _videoController?.dispose();
    _progressController.dispose();
    super.dispose();
  }

  void _setupStoryMedia() {
    _videoController?.pause();
    _videoController?.dispose();
    _videoController = null;

    if (widget.group.items.isEmpty) return;
    final currentStory = widget.group.items[_currentIndex];
    final isVideo =
        currentStory.type == 'VIDEO' ||
        (currentStory.mediaUrl != null &&
            (currentStory.mediaUrl!.toLowerCase().endsWith('.mp4') ||
                currentStory.mediaUrl!.toLowerCase().endsWith('.mov') ||
                currentStory.mediaUrl!.toLowerCase().endsWith('.webm') ||
                currentStory.mediaUrl!.toLowerCase().contains('video')));

    if (isVideo &&
        currentStory.mediaUrl != null &&
        currentStory.mediaUrl!.isNotEmpty) {
      _progressController.stop();
      final targetIndex = _currentIndex;
      _videoController =
          VideoPlayerController.networkUrl(Uri.parse(currentStory.mediaUrl!))
            ..initialize()
                .then((_) {
                  if (mounted && _currentIndex == targetIndex) {
                    final duration = _videoController!.value.duration;
                    if (duration.inMilliseconds > 1000) {
                      _progressController.duration = duration;
                    }
                    _videoController!.play();
                    _progressController.forward(from: 0.0);
                    setState(() {});
                  }
                })
                .catchError((_) {
                  if (mounted && _currentIndex == targetIndex) {
                    _progressController.duration = const Duration(seconds: 6);
                    _progressController.forward(from: 0.0);
                  }
                });
    } else {
      _progressController.duration = const Duration(seconds: 6);
      _progressController.forward(from: 0.0);
    }
  }

  void _recordCurrentStoryView() {
    if (widget.group.items.isEmpty) return;
    final storyId = widget.group.items[_currentIndex].id;
    if (_viewedIds.contains(storyId)) return;
    _viewedIds.add(storyId);

    // 2. Story owner preview must NOT increment external unique viewer count!
    if (widget.group.isOwnStory) return;

    // Call server to record unique view receipt
    try {
      final api = CxApiClient();
      api.dio.post('/api/mobile/stories/$storyId/view').ignore();
    } catch (_) {}
  }

  void _nextStory() {
    if (_currentIndex < widget.group.items.length - 1) {
      setState(() => _currentIndex++);
      _progressController.reset();
      _recordCurrentStoryView();
      _setupStoryMedia();
    } else {
      _videoController?.pause();
      _videoController?.dispose();
      _videoController = null;
      ref.invalidate(storiesFeedProvider);
      Navigator.of(context).pop();
    }
  }

  void _previousStory() {
    if (_currentIndex > 0) {
      setState(() => _currentIndex--);
      _progressController.reset();
      _recordCurrentStoryView();
      _setupStoryMedia();
    }
  }

  Future<void> _toggleLike(String storyId) async {
    final currentLiked = _likedStories[storyId] ?? false;
    final currentCount = _likeCounts[storyId] ?? 0;

    setState(() {
      _likedStories[storyId] = !currentLiked;
      _likeCounts[storyId] = !currentLiked
          ? currentCount + 1
          : (currentCount > 0 ? currentCount - 1 : 0);
    });

    try {
      final api = CxApiClient();
      final res = await api.dio.post('/api/mobile/stories/$storyId/like');
      if (res.data != null && res.data['ok'] == true) {
        setState(() {
          _likedStories[storyId] = res.data['liked'] == true;
          _likeCounts[storyId] = res.data['likesCount'] ?? _likeCounts[storyId];
        });
      }
    } catch (_) {}
  }

  void _openAddStory() {
    _progressController.stop();
    _videoController?.pause();

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            const StoryComposerScreen(mediaType: StoryMediaType.text),
      ),
    ).then((_) {
      if (mounted) {
        _progressController.forward();
        _videoController?.play();
      }
    });
  }

  Future<void> _deleteStory(String storyId) async {
    _progressController.stop();
    _videoController?.pause();

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF141414),
        title: Text(
          'DELETE STORY',
          style: GoogleFonts.orbitron(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        content: Text(
          'Are you sure you want to delete this story? It will be removed immediately.',
          style: GoogleFonts.inter(fontSize: 13, color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text(
              'Cancel',
              style: TextStyle(color: Colors.white60),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              'Delete',
              style: TextStyle(
                color: CxColors.brightRed,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirm != true) {
      if (mounted) {
        _progressController.forward();
        _videoController?.play();
      }
      return;
    }

    try {
      final api = CxApiClient();
      final res = await api.dio.delete('/api/mobile/stories/$storyId');
      if (res.data != null && res.data['ok'] == true) {
        ref.invalidate(storiesFeedProvider);
        if (mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(const SnackBar(content: Text('Story deleted')));
          Navigator.pop(context);
        }
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Failed to delete story')));
        _progressController.forward();
        _videoController?.play();
      }
    }
  }

  void _showStoryActivity(BuildContext context, String storyId) {
    _progressController.stop();
    _videoController?.pause();

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF0F0F0F),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return FutureBuilder(
          future: CxApiClient().dio.get(
            '/api/mobile/stories/$storyId/activity',
          ),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const SizedBox(
                height: 250,
                child: Center(
                  child: CircularProgressIndicator(color: CxColors.brightRed),
                ),
              );
            }

            final data = snapshot.data?.data;
            final viewers = (data?['viewers'] as List?) ?? [];
            final likers = (data?['likers'] as List?) ?? [];
            final totalViewers = data?['totalViewers'] ?? viewers.length;
            final totalLikes = data?['totalLikes'] ?? likers.length;

            return SafeArea(
              child: Container(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.65,
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 16,
                ),
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
                    const SizedBox(height: 14),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'STORY ACTIVITY',
                              style: GoogleFonts.orbitron(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            Text(
                              'Posted ${CxTimeFormat.formatStoryTime(widget.group.items[_currentIndex].createdAt)}',
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                color: CxColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                        Row(
                          children: [
                            const Icon(
                              Icons.visibility_outlined,
                              size: 16,
                              color: Colors.white70,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '$totalViewers',
                              style: GoogleFonts.inter(
                                color: Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(width: 14),
                            const Icon(
                              Icons.favorite,
                              size: 16,
                              color: CxColors.brightRed,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '$totalLikes',
                              style: GoogleFonts.inter(
                                color: Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const Divider(color: Color(0xFF222222), height: 24),
                    if (viewers.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 24),
                        child: Center(
                          child: Text(
                            'No viewers yet.\nViewer activity will show here once colleagues watch your story.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.white54,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      )
                    else
                      Flexible(
                        child: ListView.separated(
                          shrinkWrap: true,
                          itemCount: viewers.length,
                          separatorBuilder: (_, __) => const Divider(
                            color: Color(0xFF1E1E1E),
                            height: 1,
                          ),
                          itemBuilder: (_, i) {
                            final v = viewers[i];
                            final viewedAtStr = v['viewedAt']?.toString() ?? '';
                            final viewedAt =
                                DateTime.tryParse(viewedAtStr) ??
                                DateTime.now();
                            final relativeTime = CxTimeFormat.formatViewerTime(
                              viewedAt,
                            );
                            final hasLiked = v['hasLiked'] == true;

                            return ListTile(
                              contentPadding: const EdgeInsets.symmetric(
                                vertical: 4,
                              ),
                              leading: CxAvatar(
                                name: v['name'] ?? 'Colleague',
                                imageUrl: v['avatarUrl'],
                                radius: 20,
                              ),
                              title: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      v['name'] ?? 'Colleague',
                                      style: GoogleFonts.inter(
                                        color: Colors.white,
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                  if (hasLiked)
                                    const Padding(
                                      padding: EdgeInsets.only(left: 6),
                                      child: Icon(
                                        Icons.favorite,
                                        size: 14,
                                        color: CxColors.brightRed,
                                      ),
                                    ),
                                ],
                              ),
                              subtitle: Text(
                                '@${v['username'] ?? 'member'} • $relativeTime',
                                style: GoogleFonts.inter(
                                  color: Colors.white54,
                                  fontSize: 11,
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                  ],
                ),
              ),
            );
          },
        );
      },
    ).whenComplete(() {
      if (mounted) {
        _progressController.forward();
        _videoController?.play();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (widget.group.items.isEmpty) {
      return const Scaffold(backgroundColor: Colors.black);
    }

    final currentStory = widget.group.items[_currentIndex];
    final isLiked = _likedStories[currentStory.id] ?? false;
    final isOwnStory = widget.group.isOwnStory;
    final isVideo =
        currentStory.type == 'VIDEO' ||
        (currentStory.mediaUrl != null &&
            (currentStory.mediaUrl!.toLowerCase().endsWith('.mp4') ||
                currentStory.mediaUrl!.toLowerCase().endsWith('.mov') ||
                currentStory.mediaUrl!.toLowerCase().endsWith('.webm') ||
                currentStory.mediaUrl!.toLowerCase().contains('video')));

    return WillPopScope(
      onWillPop: () async {
        _videoController?.pause();
        _videoController?.dispose();
        _videoController = null;
        ref.invalidate(storiesFeedProvider);
        return true;
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: SafeArea(
          child: GestureDetector(
            onLongPressStart: (_) {
              _progressController.stop();
              _videoController?.pause();
            },
            onLongPressEnd: (_) {
              _progressController.forward();
              _videoController?.play();
            },
            onTapDown: (details) {
              final screenWidth = MediaQuery.of(context).size.width;
              if (details.globalPosition.dx < screenWidth / 3) {
                _previousStory();
              } else {
                _nextStory();
              }
            },
            child: Stack(
              children: [
                // 1. Story Content Background
                Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: CxSpacing.xl,
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (isVideo &&
                            currentStory.mediaUrl != null &&
                            currentStory.mediaUrl!.isNotEmpty)
                          if (_videoController != null &&
                              _videoController!.value.isInitialized)
                            ClipRRect(
                              borderRadius: BorderRadius.circular(16),
                              child: AspectRatio(
                                aspectRatio:
                                    _videoController!.value.aspectRatio,
                                child: VideoPlayer(_videoController!),
                              ),
                            )
                          else
                            Container(
                              height: 380,
                              width: double.infinity,
                              decoration: BoxDecoration(
                                color: const Color(0xFF111111),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: CxColors.borderSubtle,
                                ),
                              ),
                              child: const Center(
                                child: CircularProgressIndicator(
                                  color: CxColors.brightRed,
                                ),
                              ),
                            )
                        else if (currentStory.mediaUrl != null &&
                            currentStory.mediaUrl!.isNotEmpty)
                          ClipRRect(
                            borderRadius: BorderRadius.circular(16),
                            child: Image.network(
                              currentStory.mediaUrl!,
                              fit: BoxFit.cover,
                              height: 380,
                              width: double.infinity,
                              errorBuilder: (_, __, ___) => const SizedBox(),
                            ),
                          ),
                        if (currentStory.mediaUrl != null &&
                            currentStory.mediaUrl!.isNotEmpty)
                          const SizedBox(height: CxSpacing.lg),
                        if (currentStory.caption.isNotEmpty)
                          Container(
                            padding: const EdgeInsets.all(CxSpacing.lg),
                            decoration: BoxDecoration(
                              color: CxColors.cardElevated.withOpacity(0.85),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: CxColors.borderSubtle),
                            ),
                            child: Text(
                              currentStory.caption,
                              textAlign: TextAlign.center,
                              style: GoogleFonts.inter(
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                                color: CxColors.textPrimary,
                                height: 1.4,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),

                // 2. Top Progress Bars
                Positioned(
                  top: 8,
                  left: 12,
                  right: 12,
                  child: Row(
                    children: List.generate(widget.group.items.length, (index) {
                      return Expanded(
                        child: Container(
                          margin: const EdgeInsets.symmetric(horizontal: 2),
                          height: 3,
                          decoration: BoxDecoration(
                            color: Colors.white24,
                            borderRadius: BorderRadius.circular(2),
                          ),
                          child: index < _currentIndex
                              ? Container(color: CxColors.brightRed)
                              : index == _currentIndex
                              ? AnimatedBuilder(
                                  animation: _progressController,
                                  builder: (_, __) => FractionallySizedBox(
                                    alignment: Alignment.centerLeft,
                                    widthFactor: _progressController.value,
                                    child: Container(color: CxColors.brightRed),
                                  ),
                                )
                              : const SizedBox(),
                        ),
                      );
                    }),
                  ),
                ),

                // 3. Author Info Header
                Positioned(
                  top: 24,
                  left: 16,
                  right: 16,
                  child: Row(
                    children: [
                      CxAvatar(
                        name: widget.group.authorName,
                        imageUrl: widget.group.avatarUrl,
                        radius: 18,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.group.authorName,
                              style: GoogleFonts.inter(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                            Row(
                              children: [
                                Text(
                                  widget.group.role,
                                  style: GoogleFonts.inter(
                                    fontSize: 11,
                                    color: Colors.white70,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  '• ${CxTimeFormat.formatStoryTime(currentStory.createdAt)}',
                                  style: GoogleFonts.inter(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w500,
                                    color: CxColors.brightRed,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      if (isOwnStory) ...[
                        IconButton(
                          icon: const Icon(
                            Icons.add_circle_outline,
                            color: Colors.white,
                          ),
                          tooltip: 'Add Story',
                          onPressed: _openAddStory,
                        ),
                        IconButton(
                          icon: const Icon(
                            Icons.delete_outline,
                            color: Colors.white70,
                          ),
                          tooltip: 'Delete Story',
                          onPressed: () => _deleteStory(currentStory.id),
                        ),
                        IconButton(
                          icon: const Icon(
                            Icons.bar_chart_rounded,
                            color: Colors.white,
                          ),
                          tooltip: 'Story Activity',
                          onPressed: () =>
                              _showStoryActivity(context, currentStory.id),
                        ),
                      ],
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.white),
                        onPressed: () {
                          ref.invalidate(storiesFeedProvider);
                          Navigator.of(context).pop();
                        },
                      ),
                    ],
                  ),
                ),

                // 4. Bottom Interaction Bar
                Positioned(
                  bottom: 16,
                  left: 16,
                  right: 16,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      if (isOwnStory) ...[
                        CodeXaGlassButton(
                          icon: Icons.visibility_outlined,
                          label: 'Story Activity',
                          variant: GlassButtonVariant.crimson,
                          onPressed: () =>
                              _showStoryActivity(context, currentStory.id),
                        ),
                        const SizedBox(width: 10),
                        CodeXaGlassButton(
                          icon: Icons.add,
                          label: 'Add Story',
                          variant: GlassButtonVariant.secondary,
                          onPressed: _openAddStory,
                        ),
                      ] else ...[
                        const Spacer(),
                        Row(
                          children: [
                            IconButton(
                              icon: Icon(
                                isLiked
                                    ? Icons.favorite
                                    : Icons.favorite_border,
                                color: isLiked
                                    ? CxColors.brightRed
                                    : Colors.white,
                                size: 28,
                              ),
                              onPressed: () => _toggleLike(currentStory.id),
                            ),
                            if ((_likeCounts[currentStory.id] ?? 0) > 0)
                              Text(
                                '${_likeCounts[currentStory.id]}',
                                style: GoogleFonts.inter(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
