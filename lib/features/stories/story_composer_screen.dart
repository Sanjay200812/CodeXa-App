import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:video_player/video_player.dart';

import '../../core/api/api_client.dart';
import '../../core/theme/cx_theme.dart';
import '../../core/widgets/cx_components.dart';
import 'stories_tray.dart';

enum StoryMediaType { text, image, video }

class StoryComposerScreen extends ConsumerStatefulWidget {
  final XFile? mediaFile;
  final StoryMediaType mediaType;

  const StoryComposerScreen({
    super.key,
    this.mediaFile,
    required this.mediaType,
  });

  @override
  ConsumerState<StoryComposerScreen> createState() =>
      _StoryComposerScreenState();
}

class _StoryComposerScreenState extends ConsumerState<StoryComposerScreen> {
  final _captionController = TextEditingController();
  final List<String> _selectedMentionUserIds = [];
  String _selectedAudience = 'EVERYONE';
  bool _isUploading = false;
  double _uploadProgress = 0.0;
  String? _uploadStatusText;
  VideoPlayerController? _videoController;

  @override
  void initState() {
    super.initState();
    if (widget.mediaFile != null && widget.mediaType == StoryMediaType.video) {
      _videoController =
          VideoPlayerController.file(File(widget.mediaFile!.path))
            ..initialize().then((_) {
              if (mounted) setState(() {});
              _videoController?.setLooping(true);
              _videoController?.play();
            });
    }
  }

  @override
  void dispose() {
    _videoController?.pause();
    _videoController?.dispose();
    _captionController.dispose();
    super.dispose();
  }

  void _openCrewMentionPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF0F0F0F),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => _CrewMentionPickerSheet(
        onSelected: (member) {
          final username = member['username']?.toString() ?? '';
          final id = member['id']?.toString() ?? '';
          if (id.isNotEmpty && !_selectedMentionUserIds.contains(id)) {
            _selectedMentionUserIds.add(id);
          }
          final current = _captionController.text;
          _captionController.text = current.isEmpty
              ? '@$username '
              : '$current @$username ';
          setState(() {});
          Navigator.pop(ctx);
        },
      ),
    );
  }

  Future<void> _publishStory() async {
    final caption = _captionController.text.trim();
    if (widget.mediaType == StoryMediaType.text && caption.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please enter story text.')));
      return;
    }

    setState(() {
      _isUploading = true;
      _uploadProgress = 0.1;
      _uploadStatusText = 'Preparing media...';
    });

    final api = CxApiClient();

    try {
      if (widget.mediaFile != null) {
        setState(() {
          _uploadProgress = 0.3;
          _uploadStatusText = 'Uploading media...';
        });

        final file = File(widget.mediaFile!.path);
        final fileName = widget.mediaFile!.name;
        final isVideo = widget.mediaType == StoryMediaType.video;

        _videoController?.pause();

        final multipartFile = await MultipartFile.fromFile(
          file.path,
          filename: fileName.isNotEmpty
              ? fileName
              : (isVideo ? 'story_video.mp4' : 'story_image.jpg'),
          contentType: isVideo
              ? DioMediaType('video', 'mp4')
              : DioMediaType('image', 'jpeg'),
        );

        final formData = FormData.fromMap({
          'type': isVideo ? 'VIDEO' : 'IMAGE',
          'content': caption,
          'audience': _selectedAudience,
          'file': multipartFile,
          if (_selectedMentionUserIds.isNotEmpty)
            'mentions': jsonEncode(_selectedMentionUserIds),
        });

        final res = await api.dio.post(
          '/api/mobile/stories',
          data: formData,
          onSendProgress: (sent, total) {
            if (total > 0) {
              setState(() {
                _uploadProgress = 0.3 + 0.6 * (sent / total);
                _uploadStatusText =
                    'Uploading Story: ${((sent / total) * 100).toInt()}%';
              });
            }
          },
        );

        if (res.data != null && res.data['ok'] == true) {
          setState(() {
            _uploadProgress = 1.0;
            _uploadStatusText = 'Published!';
          });

          ref.invalidate(storiesFeedProvider);

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Story published successfully!'),
                backgroundColor: Colors.green,
              ),
            );
            Navigator.of(context).pop();
          }
        } else {
          throw Exception(res.data?['error']?['message'] ?? 'Upload failed');
        }
      } else {
        // Text-only story
        setState(() {
          _uploadProgress = 0.5;
          _uploadStatusText = 'Publishing story...';
        });

        final res = await api.dio.post(
          '/api/mobile/stories',
          data: {
            'type': 'TEXT',
            'content': caption,
            'audience': _selectedAudience,
            if (_selectedMentionUserIds.isNotEmpty)
              'mentions': _selectedMentionUserIds,
          },
        );

        if (res.data != null && res.data['ok'] == true) {
          ref.invalidate(storiesFeedProvider);

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Story published successfully!'),
                backgroundColor: Colors.green,
              ),
            );
            Navigator.of(context).pop();
          }
        } else {
          throw Exception(
            res.data?['error']?['message'] ?? 'Failed to publish',
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isUploading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Story upload failed: ${e.toString()}'),
            backgroundColor: CxColors.brightRed,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF070707),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: _isUploading ? null : () => Navigator.pop(context),
        ),
        title: Text(
          widget.mediaType == StoryMediaType.video
              ? 'VIDEO STORY'
              : widget.mediaType == StoryMediaType.image
              ? 'PHOTO STORY'
              : 'TEXT STORY',
          style: GoogleFonts.orbitron(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: Colors.white,
            letterSpacing: 1.0,
          ),
        ),
        actions: [
          if (!_isUploading) ...[
            IconButton(
              icon: const Icon(
                Icons.alternate_email_rounded,
                color: Colors.white,
              ),
              tooltip: 'Mention Crew Member',
              onPressed: _openCrewMentionPicker,
            ),
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: TextButton.icon(
                onPressed: _publishStory,
                icon: const Icon(
                  Icons.send_rounded,
                  color: CxColors.brightRed,
                  size: 18,
                ),
                label: Text(
                  'SHARE',
                  style: GoogleFonts.orbitron(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: CxColors.brightRed,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Canvas background or preview
                  if (widget.mediaFile != null &&
                      widget.mediaType == StoryMediaType.image)
                    Positioned.fill(
                      child: Container(
                        margin: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: CxColors.borderSubtle),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: Image.file(
                            File(widget.mediaFile!.path),
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                    )
                  else if (widget.mediaFile != null &&
                      widget.mediaType == StoryMediaType.video)
                    Positioned.fill(
                      child: Container(
                        margin: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFF111111),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: CxColors.borderSubtle),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              if (_videoController != null &&
                                  _videoController!.value.isInitialized)
                                Center(
                                  child: AspectRatio(
                                    aspectRatio:
                                        _videoController!.value.aspectRatio,
                                    child: VideoPlayer(_videoController!),
                                  ),
                                )
                              else
                                const Center(
                                  child: CircularProgressIndicator(
                                    color: CxColors.brightRed,
                                  ),
                                ),
                              Positioned(
                                top: 12,
                                right: 12,
                                child: GestureDetector(
                                  onTap: () {
                                    if (_videoController != null &&
                                        _videoController!.value.isInitialized) {
                                      setState(() {
                                        if (_videoController!.value.isPlaying) {
                                          _videoController!.pause();
                                        } else {
                                          _videoController!.play();
                                        }
                                      });
                                    }
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: Colors.black.withOpacity(0.6),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(
                                      (_videoController?.value.isPlaying ??
                                              false)
                                          ? Icons.pause
                                          : Icons.play_arrow,
                                      color: Colors.white,
                                      size: 20,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    )
                  else
                    Positioned.fill(
                      child: Container(
                        margin: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF63000F), Color(0xFF070707)],
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                          ),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: CxColors.borderSubtle),
                        ),
                        padding: const EdgeInsets.all(24),
                        child: Center(
                          child: TextField(
                            controller: _captionController,
                            style: GoogleFonts.inter(
                              fontSize: 18,
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 8,
                            textAlign: TextAlign.center,
                            decoration: const InputDecoration(
                              hintText: 'Type your story update here...',
                              hintStyle: TextStyle(color: Colors.white38),
                              border: InputBorder.none,
                            ),
                          ),
                        ),
                      ),
                    ),

                  // Overlay Caption Input (for photo & video)
                  if (widget.mediaFile != null)
                    Positioned(
                      bottom: 24,
                      left: 24,
                      right: 24,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withAlpha(180),
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(color: Colors.white24),
                        ),
                        child: TextField(
                          controller: _captionController,
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            color: Colors.white,
                          ),
                          decoration: const InputDecoration(
                            hintText: 'Add a caption...',
                            hintStyle: TextStyle(color: Colors.white60),
                            border: InputBorder.none,
                          ),
                        ),
                      ),
                    ),

                  // Upload Progress Overlay
                  if (_isUploading)
                    Positioned.fill(
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.black.withAlpha(200),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              SizedBox(
                                width: 64,
                                height: 64,
                                child: CircularProgressIndicator(
                                  value: _uploadProgress,
                                  strokeWidth: 6,
                                  color: CxColors.brightRed,
                                  backgroundColor: Colors.white12,
                                ),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                _uploadStatusText ?? 'Uploading...',
                                style: GoogleFonts.orbitron(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),

            // Audience & Publish Controls
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                color: Color(0xFF0C0C0C),
                border: Border(top: BorderSide(color: CxColors.borderSubtle)),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.public,
                    size: 16,
                    color: CxColors.textSecondary,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'AUDIENCE:',
                    style: GoogleFonts.orbitron(
                      fontSize: 10,
                      color: CxColors.textSecondary,
                    ),
                  ),
                  const SizedBox(width: 8),
                  DropdownButton<String>(
                    value: _selectedAudience,
                    dropdownColor: CxColors.cardElevated,
                    style: GoogleFonts.inter(fontSize: 12, color: Colors.white),
                    underline: const SizedBox(),
                    items: const [
                      DropdownMenuItem(
                        value: 'EVERYONE',
                        child: Text('Everyone in CodeXa'),
                      ),
                      DropdownMenuItem(value: 'TEAM', child: Text('My Team')),
                      DropdownMenuItem(
                        value: 'PROJECT',
                        child: Text('Project Members'),
                      ),
                    ],
                    onChanged: (val) {
                      if (val != null) setState(() => _selectedAudience = val);
                    },
                  ),
                  const Spacer(),
                  CxButton(
                    label: _isUploading ? 'UPLOADING...' : 'SHARE STORY',
                    icon: Icons.send,
                    onPressed: _isUploading ? null : _publishStory,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CrewMentionPickerSheet extends StatefulWidget {
  final ValueChanged<Map<String, dynamic>> onSelected;

  const _CrewMentionPickerSheet({required this.onSelected});

  @override
  State<_CrewMentionPickerSheet> createState() =>
      _CrewMentionPickerSheetState();
}

class _CrewMentionPickerSheetState extends State<_CrewMentionPickerSheet> {
  final TextEditingController _searchCtrl = TextEditingController();
  List<Map<String, dynamic>> _crewMembers = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchCrewMembers();
  }

  Future<void> _fetchCrewMembers([String query = '']) async {
    setState(() => _isLoading = true);
    try {
      final api = CxApiClient();
      final res = await api.dio.get(
        '/api/mobile/people',
        queryParameters: {if (query.isNotEmpty) 'q': query, 'limit': 50},
      );
      if (res.data != null && res.data['ok'] == true) {
        final list = (res.data['people'] as List<dynamic>?) ?? [];
        // 15. Restricted to CodeXa Crew members only
        const crewRoles = [
          'FOUNDER',
          'CO_FOUNDER',
          'CEO',
          'CTO',
          'COO',
          'HR',
          'CORE_TEAM',
          'TEAM_MEMBER',
          'EMPLOYEE',
          'INTERN',
          'ADMIN',
        ];
        _crewMembers = list
            .map((p) => Map<String, dynamic>.from(p))
            .where(
              (p) => crewRoles.contains(p['role']?.toString().toUpperCase()),
            )
            .toList();
      }
    } catch (_) {}
    if (mounted) setState(() => _isLoading = false);
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.7,
      ),
      padding: EdgeInsets.only(
        top: 16,
        left: 20,
        right: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 38,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFF333333),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              const Icon(
                Icons.alternate_email_rounded,
                color: CxColors.brightRed,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                'MENTION CREW MEMBER',
                style: GoogleFonts.orbitron(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  letterSpacing: 1.0,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              color: const Color(0xFF141414),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF262626)),
            ),
            child: TextField(
              controller: _searchCtrl,
              style: GoogleFonts.inter(color: Colors.white, fontSize: 13),
              decoration: const InputDecoration(
                icon: Icon(Icons.search, size: 18, color: Colors.white54),
                hintText: 'Search crew by name, username or role...',
                hintStyle: TextStyle(color: Colors.white38),
                border: InputBorder.none,
              ),
              onChanged: (val) => _fetchCrewMembers(val.trim()),
            ),
          ),
          const SizedBox(height: 14),
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 32),
              child: Center(
                child: CircularProgressIndicator(color: CxColors.brightRed),
              ),
            )
          else if (_crewMembers.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: Text(
                  'No matching CodeXa Crew members found.',
                  style: GoogleFonts.inter(color: Colors.white54, fontSize: 13),
                ),
              ),
            )
          else
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: _crewMembers.length,
                separatorBuilder: (_, __) =>
                    const Divider(color: Color(0xFF1E1E1E), height: 1),
                itemBuilder: (ctx, i) {
                  final member = _crewMembers[i];
                  final name =
                      member['fullName'] ??
                      member['name'] ??
                      member['username'] ??
                      'Crew';
                  final username = member['username'] ?? '';
                  final role = member['role'] ?? 'CREW';
                  final avatarUrl =
                      member['avatarUrl'] ?? member['profileMediaUrl'];

                  return ListTile(
                    contentPadding: const EdgeInsets.symmetric(vertical: 4),
                    leading: CxAvatar(
                      name: name,
                      imageUrl: avatarUrl,
                      radius: 20,
                    ),
                    title: Text(
                      name,
                      style: GoogleFonts.inter(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    subtitle: Text(
                      '@$username • $role',
                      style: GoogleFonts.inter(
                        color: Colors.white54,
                        fontSize: 11,
                      ),
                    ),
                    trailing: const Icon(
                      Icons.add,
                      color: CxColors.brightRed,
                      size: 18,
                    ),
                    onTap: () => widget.onSelected(member),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}
