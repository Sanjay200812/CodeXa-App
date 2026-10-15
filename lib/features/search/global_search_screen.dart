import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/models/models.dart';
import '../../core/providers/app_providers.dart';
import '../../core/theme/cx_theme.dart';
import '../../core/widgets/cx_components.dart';

class GlobalSearchScreen extends ConsumerStatefulWidget {
  const GlobalSearchScreen({super.key});

  @override
  ConsumerState<GlobalSearchScreen> createState() => _GlobalSearchScreenState();
}

class _GlobalSearchScreenState extends ConsumerState<GlobalSearchScreen>
    with SingleTickerProviderStateMixin {
  final TextEditingController _searchController = TextEditingController();
  late TabController _tabController;
  Timer? _debounceTimer;

  final List<String> _categories = [
    'ALL',
    'PEOPLE',
    'MESSAGES',
    'PROJECTS',
    'CLASSES',
    'ASSIGNMENTS',
    'DOCUMENTS',
    'POSTS',
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _categories.length, vsync: this);
    _tabController.addListener(_onTabChanged);
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _onTabChanged() {
    if (_tabController.indexIsChanging) return;
    final cat = _categories[_tabController.index].toLowerCase();
    ref
        .read(globalSearchQueryProvider.notifier)
        .update((s) => GlobalSearchQuery(query: s.query, category: cat));
  }

  void _onQueryChanged(String query) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 300), () {
      final cat = _categories[_tabController.index].toLowerCase();
      ref
          .read(globalSearchQueryProvider.notifier)
          .update((s) => GlobalSearchQuery(query: query, category: cat));
    });
  }

  @override
  Widget build(BuildContext context) {
    final searchResultsAsync = ref.watch(globalSearchResultsProvider);
    final sq = ref.watch(globalSearchQueryProvider);

    return Scaffold(
      backgroundColor: CxColors.background,
      appBar: CxAppBar(
        title: 'GLOBAL SEARCH',
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: CxColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        children: [
          // Search Input Bar
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: CxSpacing.lg,
              vertical: CxSpacing.sm,
            ),
            decoration: const BoxDecoration(
              color: CxColors.background,
              border: Border(
                bottom: BorderSide(color: CxColors.borderSubtle, width: 1),
              ),
            ),
            child: Container(
              decoration: BoxDecoration(
                color: CxColors.card,
                borderRadius: BorderRadius.circular(CxSpacing.inputRadius),
                border: Border.all(color: CxColors.borderDefault),
              ),
              child: TextField(
                controller: _searchController,
                autofocus: true,
                onChanged: _onQueryChanged,
                style: GoogleFonts.inter(
                  color: CxColors.textPrimary,
                  fontSize: 14,
                ),
                cursorColor: CxColors.brightRed,
                decoration: InputDecoration(
                  hintText: 'Search people, projects, posts, documents...',
                  hintStyle: GoogleFonts.inter(
                    color: CxColors.textMuted,
                    fontSize: 13,
                  ),
                  prefixIcon: const Icon(
                    Icons.search,
                    color: CxColors.textSecondary,
                    size: 20,
                  ),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(
                            Icons.clear,
                            color: CxColors.textSecondary,
                            size: 18,
                          ),
                          onPressed: () {
                            _searchController.clear();
                            _onQueryChanged('');
                          },
                        )
                      : null,
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ),

          // Categories Tab Bar
          TabBar(
            controller: _tabController,
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            indicatorColor: CxColors.brightRed,
            indicatorWeight: 2,
            labelColor: CxColors.brightRed,
            unselectedLabelColor: CxColors.textSecondary,
            labelStyle: GoogleFonts.orbitron(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
            ),
            unselectedLabelStyle: GoogleFonts.orbitron(
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
            tabs: _categories.map((c) => Tab(text: c)).toList(),
          ),

          const Divider(color: CxColors.borderSubtle, height: 1),

          // Results Area
          Expanded(
            child: sq.query.trim().isEmpty
                ? const CxEmptyState(
                    icon: Icons.search,
                    title: 'SEARCH CODEXA',
                    message: 'Type a name, project title, topic, or document name to search.',
                  )
                : searchResultsAsync.when(
                    loading: () => ListView.separated(
                      padding: const EdgeInsets.all(CxSpacing.lg),
                      itemCount: 5,
                      separatorBuilder: (_, __) =>
                          const SizedBox(height: CxSpacing.md),
                      itemBuilder: (_, __) => const CxLoadingSkeleton(
                        width: double.infinity,
                        height: 72,
                        borderRadius: 14,
                      ),
                    ),
                    error: (e, _) => CxEmptyState(
                      icon: Icons.cloud_off,
                      title: 'SEARCH FAILED',
                      message: 'Could not execute search on CodeXa servers.',
                      action: CxButton(
                        label: 'RETRY',
                        width: 140,
                        onPressed: () =>
                            ref.invalidate(globalSearchResultsProvider),
                      ),
                    ),
                    data: (results) {
                      if (results.isEmpty) {
                        return const CxEmptyState(
                          icon: Icons.search_off,
                          title: 'NO RESULTS FOUND',
                          message:
                              'No matches found. Try refining your keywords.',
                        );
                      }

                      return ListView.separated(
                        padding: const EdgeInsets.all(CxSpacing.lg),
                        itemCount: results.length,
                        separatorBuilder: (_, __) =>
                            const SizedBox(height: CxSpacing.md),
                        itemBuilder: (context, index) {
                          final item = results[index];
                          return _SearchResultCard(item: item);
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _SearchResultCard extends StatelessWidget {
  final SearchResultItem item;

  const _SearchResultCard({required this.item});

  IconData _getIconForCategory(String category) {
    switch (category.toLowerCase()) {
      case 'people':
        return Icons.person_outline;
      case 'messages':
        return Icons.chat_bubble_outline;
      case 'projects':
        return Icons.folder_outlined;
      case 'classes':
      case 'topics':
        return Icons.school_outlined;
      case 'assignments':
        return Icons.assignment_outlined;
      case 'documents':
        return Icons.description_outlined;
      case 'posts':
        return Icons.dynamic_feed_outlined;
      default:
        return Icons.search;
    }
  }

  void _onTap(BuildContext context) {
    if (item.route != null && item.route!.isNotEmpty) {
      context.push(item.route!);
    } else {
      switch (item.category.toLowerCase()) {
        case 'people':
          if (item.meta != null && item.meta!.isNotEmpty) {
            context.push('/profile/${item.meta}');
          } else {
            context.push('/people');
          }
          break;
        case 'messages':
          if (item.meta != null && item.meta!.isNotEmpty) {
            context.push('/chat/${item.meta}');
          } else {
            context.go('/messages');
          }
          break;
        case 'projects':
          context.go('/projects');
          break;
        case 'classes':
        case 'topics':
          context.push('/topics');
          break;
        case 'assignments':
          context.push('/assignments');
          break;
        case 'documents':
          context.push('/documents');
          break;
        case 'posts':
          context.go('/feed');
          break;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return CxCard(
      onTap: () => _onTap(context),
      padding: const EdgeInsets.all(CxSpacing.md),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: CxColors.secondaryDark,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: CxColors.borderSubtle),
            ),
            child: Icon(
              _getIconForCategory(item.category),
              color: CxColors.brightRed,
              size: 20,
            ),
          ),
          const SizedBox(width: CxSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        item.title,
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: CxColors.textPrimary,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: CxColors.cardElevated,
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: CxColors.borderSubtle),
                      ),
                      child: Text(
                        item.category.toUpperCase(),
                        style: GoogleFonts.orbitron(
                          fontSize: 8,
                          fontWeight: FontWeight.w700,
                          color: CxColors.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
                if (item.subtitle != null && item.subtitle!.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    item.subtitle!,
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      color: CxColors.textSecondary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
          const Icon(
            Icons.arrow_forward_ios,
            size: 14,
            color: CxColors.textMuted,
          ),
        ],
      ),
    );
  }
}
