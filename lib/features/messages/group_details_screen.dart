import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/api/api_client.dart';
import '../../core/providers/app_providers.dart';
import '../../core/theme/cx_theme.dart';
import '../../core/widgets/cx_components.dart';
import '../profile/coworker_profile_screen.dart';

class GroupDetailsScreen extends ConsumerStatefulWidget {
  final Map<String, dynamic> conversation;

  const GroupDetailsScreen({super.key, required this.conversation});

  @override
  ConsumerState<GroupDetailsScreen> createState() => _GroupDetailsScreenState();
}

class _GroupDetailsScreenState extends ConsumerState<GroupDetailsScreen> {
  bool _isLoading = true;
  Map<String, dynamic>? _groupData;
  List<dynamic> _members = [];
  bool _isMuted = false;
  String _selectedTheme = 'wallpaper'; // wallpaper | solid | classic

  @override
  void initState() {
    super.initState();
    _fetchGroupDetails();
  }

  Future<void> _fetchGroupDetails() async {
    final convId = widget.conversation['id'];
    if (convId == null) return;

    setState(() => _isLoading = true);

    try {
      final api = CxApiClient();
      final res = await api.dio.get('/api/chat/conversations/$convId');
      if (res.data != null && res.data['ok'] == true) {
        final conv = res.data['conversation'] as Map<String, dynamic>?;
        if (conv != null && mounted) {
          setState(() {
            _groupData = conv;
            _members = (conv['members'] as List<dynamic>?) ?? [];
            _isLoading = false;
          });
          return;
        }
      }
    } catch (_) {}

    if (mounted) {
      setState(() {
        _groupData = widget.conversation;
        _members = (widget.conversation['members'] as List<dynamic>?) ?? [];
        _isLoading = false;
      });
    }
  }

  Future<void> _pickAndUploadGroupIcon() async {
    final picker = ImagePicker();
    final file = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 800,
      maxHeight: 800,
      imageQuality: 85,
    );
    if (file == null) return;

    final bytes = await file.readAsBytes();
    final base64Image = base64Encode(bytes);
    final convId = widget.conversation['id'];

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Updating group profile photo...'),
        backgroundColor: Color(0xFF1E1E1E),
        duration: Duration(seconds: 1),
      ),
    );

    try {
      final api = CxApiClient();
      final res = await api.dio.patch(
        '/api/chat/conversations/$convId',
        data: {'base64': base64Image},
      );

      if (res.data != null && res.data['ok'] == true) {
        final newUrl =
            res.data['iconUrl'] ?? res.data['conversation']?['avatarUrl'];
        if (mounted) {
          setState(() {
            if (_groupData != null) {
              _groupData!['avatarUrl'] = newUrl;
              _groupData!['icon_url'] = newUrl;
            }
            widget.conversation['avatarUrl'] = newUrl;
            widget.conversation['icon_url'] = newUrl;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Group profile picture updated successfully!'),
              backgroundColor: CxColors.crimson,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Failed to update group picture. Admin permission required.',
            ),
            backgroundColor: CxColors.crimson,
          ),
        );
      }
    }
  }

  Color _getRoleColor(String role) {
    switch (role.toUpperCase()) {
      case 'FOUNDER':
      case 'CO_FOUNDER':
        return CxColors.brightRed;
      case 'CEO':
      case 'CTO':
      case 'COO':
        return const Color(0xFF9D4EDD);
      case 'HR':
        return const Color(0xFF00B4D8);
      case 'EMPLOYEE':
        return CxColors.success;
      case 'INTERN':
      default:
        return const Color(0xFFF77F00);
    }
  }

  void _showThemeSelector() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => CodeXaGlassBottomSheet(
        title: 'CHAT THEME',
        child: Column(
          children: [
            _buildThemeOption(
              'wallpaper',
              'CodeXa Branded Wallpaper (Default)',
              Icons.wallpaper,
            ),
            _buildThemeOption('solid', 'Solid Dark Surface', Icons.dark_mode),
            _buildThemeOption(
              'classic',
              'Classic Messaging',
              Icons.chat_bubble,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildThemeOption(String key, String title, IconData icon) {
    final isSelected = _selectedTheme == key;
    return ListTile(
      leading: Icon(
        icon,
        color: isSelected ? CxColors.brightRed : Colors.white70,
      ),
      title: Text(
        title,
        style: GoogleFonts.inter(
          fontSize: 14,
          fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
          color: isSelected ? Colors.white : const Color(0xFFA5A5A5),
        ),
      ),
      trailing: isSelected
          ? const Icon(Icons.check_circle, color: CxColors.brightRed, size: 20)
          : null,
      onTap: () {
        setState(() => _selectedTheme = key);
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Chat theme set to: $title'),
            backgroundColor: const Color(0xFF1E1E1E),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider).user;
    final conv = _groupData ?? widget.conversation;
    final title = conv['name'] ?? conv['title'] ?? 'CODEX CREW';
    final avatarUrl =
        conv['avatarUrl'] ?? conv['icon_url'] ?? conv['metadata']?['iconUrl'];
    final description =
        conv['description'] ?? 'Official CodeXa Crew & Core Engineering Team';

    final isLeadershipOrAdmin = [
      'FOUNDER',
      'CO_FOUNDER',
      'CEO',
      'CTO',
      'HR',
      'COO',
      'ADMIN',
      'OWNER',
    ].contains(user?.role.toUpperCase());

    return Scaffold(
      backgroundColor: CxColors.background,
      appBar: CxAppBar(
        title: 'GROUP INFO',
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: CxColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: CxColors.brightRed),
            )
          : ListView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              children: [
                // 1. Group DP Hero Card
                Center(
                  child: Stack(
                    children: [
                      Container(
                        width: 96,
                        height: 96,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: const Color(0xFF161616),
                          border: Border.all(
                            color: CxColors.brightRed.withOpacity(0.7),
                            width: 2,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: CxColors.crimson.withOpacity(0.35),
                              blurRadius: 18,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: ClipOval(
                          child:
                              avatarUrl != null &&
                                  avatarUrl.toString().isNotEmpty
                              ? Image.network(
                                  avatarUrl.toString(),
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => const Center(
                                    child: Icon(
                                      Icons.group,
                                      size: 44,
                                      color: Colors.white70,
                                    ),
                                  ),
                                )
                              : const Center(
                                  child: Icon(
                                    Icons.group,
                                    size: 44,
                                    color: Colors.white70,
                                  ),
                                ),
                        ),
                      ),
                      if (isLeadershipOrAdmin)
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: GestureDetector(
                            onTap: _pickAndUploadGroupIcon,
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: const BoxDecoration(
                                color: CxColors.brightRed,
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black54,
                                    blurRadius: 6,
                                  ),
                                ],
                              ),
                              child: const Icon(
                                Icons.camera_alt,
                                size: 16,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                // Group Title & Description
                Center(
                  child: Text(
                    title,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.orbitron(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.2,
                      color: CxColors.textPrimary,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Center(
                  child: Text(
                    '${_members.length} Members • CodeXa Official Group',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: CxColors.textSecondary,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Text(
                      description,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: const Color(0xFFA5A5A5),
                        height: 1.4,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // 2. Quick Glass Action Bar
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildQuickAction(
                      icon: _isMuted
                          ? Icons.notifications_off
                          : Icons.notifications_none,
                      label: _isMuted ? 'Muted' : 'Mute',
                      onTap: () {
                        setState(() => _isMuted = !_isMuted);
                        HapticFeedback.lightImpact();
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              _isMuted
                                  ? 'Notifications muted'
                                  : 'Notifications unmuted',
                            ),
                            backgroundColor: const Color(0xFF1E1E1E),
                            duration: const Duration(seconds: 1),
                          ),
                        );
                      },
                    ),
                    _buildQuickAction(
                      icon: Icons.wallpaper,
                      label: 'Theme',
                      onTap: _showThemeSelector,
                    ),
                    _buildQuickAction(
                      icon: Icons.photo_library_outlined,
                      label: 'Media',
                      onTap: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Opening shared media...'),
                          ),
                        );
                      },
                    ),
                    _buildQuickAction(
                      icon: Icons.search,
                      label: 'Search',
                      onTap: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // 3. Members Section Header
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 4,
                    vertical: 6,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'MEMBERS (${_members.length})',
                        style: GoogleFonts.orbitron(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.0,
                          color: CxColors.textSecondary,
                        ),
                      ),
                      if (isLeadershipOrAdmin)
                        Text(
                          'ADMIN ACCESS',
                          style: GoogleFonts.orbitron(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: CxColors.brightRed,
                          ),
                        ),
                    ],
                  ),
                ),

                // Members List Cards
                if (_members.isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Center(
                      child: Text(
                        'No members loaded.',
                        style: GoogleFonts.inter(
                          color: CxColors.textMuted,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  )
                else
                  ..._members.map((m) {
                    final memberName =
                        (m['fullName'] ??
                                m['displayName'] ??
                                m['username'] ??
                                'Member')
                            .toString();
                    final username = (m['username'] ?? '').toString();
                    final orgRole = (m['orgRole'] ?? m['role'] ?? 'MEMBER')
                        .toString();
                    final groupRole =
                        (m['groupRole'] ??
                                ([
                                      'FOUNDER',
                                      'CO_FOUNDER',
                                      'CEO',
                                    ].contains(orgRole.toUpperCase())
                                    ? 'ADMIN'
                                    : 'MEMBER'))
                            .toString();
                    final avatar = m['profileMediaUrl']?.toString();

                    return CodeXaGlassCard(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      onTap: () {
                        if (username.isNotEmpty) {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  CoworkerProfileScreen(username: username),
                            ),
                          );
                        }
                      },
                      child: Row(
                        children: [
                          CxAvatar(
                            name: memberName,
                            imageUrl: avatar,
                            radius: 19,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Flexible(
                                      child: Text(
                                        memberName,
                                        style: GoogleFonts.inter(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.white,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    // Group Role Tag
                                    if (groupRole.toUpperCase() == 'ADMIN' ||
                                        groupRole.toUpperCase() == 'OWNER')
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 5,
                                          vertical: 1.5,
                                        ),
                                        decoration: BoxDecoration(
                                          color: CxColors.crimson.withOpacity(
                                            0.25,
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            4,
                                          ),
                                          border: Border.all(
                                            color: CxColors.brightRed
                                                .withOpacity(0.6),
                                            width: 0.8,
                                          ),
                                        ),
                                        child: Text(
                                          groupRole.toUpperCase(),
                                          style: GoogleFonts.orbitron(
                                            fontSize: 8,
                                            fontWeight: FontWeight.bold,
                                            color: CxColors.brightRed,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 2),
                                Row(
                                  children: [
                                    Text(
                                      '@$username',
                                      style: GoogleFonts.inter(
                                        fontSize: 11,
                                        color: CxColors.textMuted,
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Container(
                                      width: 3,
                                      height: 3,
                                      decoration: const BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: Color(0xFF555555),
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      orgRole.toUpperCase(),
                                      style: GoogleFonts.inter(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        color: _getRoleColor(orgRole),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const Icon(
                            Icons.arrow_forward_ios,
                            size: 13,
                            color: Color(0xFF555555),
                          ),
                        ],
                      ),
                    );
                  }),

                const SizedBox(height: 20),

                // 4. Group Options & Safety
                CodeXaGlassCard(
                  padding: const EdgeInsets.all(4),
                  child: Column(
                    children: [
                      ListTile(
                        leading: const Icon(
                          Icons.photo_library_outlined,
                          color: Colors.white70,
                        ),
                        title: Text(
                          'Shared Media & Documents',
                          style: GoogleFonts.inter(
                            color: Colors.white,
                            fontSize: 13,
                          ),
                        ),
                        trailing: const Icon(
                          Icons.arrow_forward_ios,
                          size: 13,
                          color: Color(0xFF555555),
                        ),
                        onTap: () {},
                      ),
                      const Divider(color: Color(0x1AFFFFFF), height: 1),
                      ListTile(
                        leading: const Icon(
                          Icons.wallpaper,
                          color: Colors.white70,
                        ),
                        title: Text(
                          'Chat Theme & Wallpaper',
                          style: GoogleFonts.inter(
                            color: Colors.white,
                            fontSize: 13,
                          ),
                        ),
                        trailing: const Icon(
                          Icons.arrow_forward_ios,
                          size: 13,
                          color: Color(0xFF555555),
                        ),
                        onTap: _showThemeSelector,
                      ),
                      const Divider(color: Color(0x1AFFFFFF), height: 1),
                      ListTile(
                        leading: const Icon(
                          Icons.exit_to_app,
                          color: CxColors.brightRed,
                        ),
                        title: Text(
                          'Leave Group',
                          style: GoogleFonts.inter(
                            color: CxColors.brightRed,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        onTap: () {
                          showDialog(
                            context: context,
                            builder: (ctx) => CodeXaGlassModal(
                              title: 'LEAVE GROUP',
                              message:
                                  'Are you sure you want to leave CODEX CREW?',
                              confirmLabel: 'LEAVE',
                              onConfirm: () => Navigator.pop(context),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 30),
              ],
            ),
    );
  }

  Widget _buildQuickAction({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          CodeXaGlassIconButton(
            icon: icon,
            size: 44,
            iconSize: 20,
            onPressed: onTap,
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 11,
              color: CxColors.textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
